import Foundation
import AppKit
import SwiftUI

public final class PureBackdropBlurView: NSView {
    private var backdropLayer: CALayer?
    
    public var blurRadius: CGFloat = 20.0 {
        didSet {
            updateFilter()
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBackdrop()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBackdrop()
    }
    
    private func setupBackdrop() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let layer = backdropClass.init()
            layer.name = "pureBackdropBlur"
            self.backdropLayer = layer
            self.layer?.addSublayer(layer)
            updateFilter()
        }
    }
    
    private func updateFilter() {
        guard let backdropLayer = backdropLayer,
              let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return }
        
        let filter = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?.takeUnretainedValue() as? NSObject
        filter?.setValue(blurRadius, forKey: "inputRadius")
        filter?.setValue(true, forKey: "inputNormalizeEdges")
        if let filter = filter {
            backdropLayer.setValue([filter], forKey: "filters")
        }
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer?.frame = bounds
        CATransaction.commit()
    }
}

public final class GlassWindowController: NSObject, ObservableObject {
    public static let defaultWidth: CGFloat = 340.0
    
    public var currentDockWidth: CGFloat {
        let saved = UserDefaults.standard.double(forKey: "dock_width")
        return (saved >= 240 && saved <= 600) ? CGFloat(saved) : Self.defaultWidth
    }
    
    public var currentVoiceWidth: CGFloat {
        return currentDockWidth * 1.25
    }
    
    public private(set) var panel: DockPanel?
    private var outsideClickMonitor: Any?
    private var currentScreen: NSScreen?
    
    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var currentMode: DockPresentationMode = .standardDock
    
    public var onDismiss: (() -> Void)?
    
    public override init() {
        super.init()
        observeSettings()
    }
    
    private func observeSettings() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let panel = self.panel, self.isVisible else { return }
            let targetWidth = (self.currentMode == .expandedVoice) ? self.currentVoiceWidth : self.currentDockWidth
            let screenFrame = self.currentScreen?.visibleFrame ?? NSScreen.main!.visibleFrame
            let newRect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: targetWidth, height: screenFrame.height)
            panel.setFrame(newRect, display: true, animate: true)
        }
    }
    
    public func setup<Content: View>(with rootView: Content) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        self.currentScreen = screen
        
        let screenFrame = screen.visibleFrame
        let width = currentDockWidth
        let initialRect = NSRect(
            x: -width,
            y: screenFrame.origin.y,
            width: width,
            height: screenFrame.height
        )
        
        let panel = DockPanel(contentRect: initialRect)
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: screenFrame.height))
        containerView.wantsLayer = true
        containerView.autoresizingMask = [.width, .height]
        
        let visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.appearance = NSAppearance(named: .vibrantDark)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        
        let blurView = PureBackdropBlurView(frame: containerView.bounds)
        blurView.autoresizingMask = [.width, .height]
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        
        containerView.addSubview(visualEffectView)
        containerView.addSubview(blurView)
        containerView.addSubview(hostingView)
        panel.contentView = containerView
        
        panel.onDismissRequested = { [weak self] in
            self?.dismiss()
        }
        
        self.panel = panel
    }
    
    public func updateInteractiveProgress(_ progress: Double, mode: DockPresentationMode = .standardDock) {
        guard let panel = panel, let screen = currentScreen ?? NSScreen.main else { return }
        
        let targetWidth = (mode == .expandedVoice) ? currentVoiceWidth : currentDockWidth
        let screenFrame = screen.visibleFrame
        
        let clampedProgress = max(0.0, min(1.0, progress))
        let currentX = -targetWidth + (targetWidth * CGFloat(clampedProgress))
        
        panel.setFrame(
            NSRect(x: currentX, y: screenFrame.origin.y, width: targetWidth, height: screenFrame.height),
            display: true
        )
        
        if !panel.isVisible && clampedProgress > 0.02 {
            panel.orderFrontRegardless()
        }
    }
    
    public func present(mode: DockPresentationMode = .standardDock, animated: Bool = true) {
        guard let panel = panel, let screen = currentScreen ?? NSScreen.main else { return }
        
        self.currentMode = mode
        let targetWidth = (mode == .expandedVoice) ? currentVoiceWidth : currentDockWidth
        let screenFrame = screen.visibleFrame
        let finalRect = NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: targetWidth, height: screenFrame.height)
        
        panel.orderFrontRegardless()
        panel.makeKey()
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(finalRect, display: true)
            } completionHandler: { [weak self] in
                self?.isVisible = true
                self?.startOutsideClickMonitoring()
            }
        } else {
            panel.setFrame(finalRect, display: true)
            self.isVisible = true
            startOutsideClickMonitoring()
        }
    }
    
    public func dismiss(animated: Bool = true) {
        let width = currentDockWidth
        guard let panel = panel, isVisible || panel.frame.origin.x > -width else { return }
        
        stopOutsideClickMonitoring()
        let targetWidth = panel.frame.width
        let screenFrame = currentScreen?.visibleFrame ?? NSScreen.main!.visibleFrame
        let hiddenRect = NSRect(x: -targetWidth, y: screenFrame.origin.y, width: targetWidth, height: screenFrame.height)
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(hiddenRect, display: true)
            } completionHandler: { [weak self] in
                panel.orderOut(nil)
                self?.isVisible = false
                self?.onDismiss?()
            }
        } else {
            panel.setFrame(hiddenRect, display: true)
            panel.orderOut(nil)
            self.isVisible = false
            self.onDismiss?()
        }
    }
    
    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, self.isVisible else { return }
            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                self.dismiss()
            }
        }
    }
    
    private func stopOutsideClickMonitoring() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
    
    deinit {
        stopOutsideClickMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}
