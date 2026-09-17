import Foundation
import AppKit
import SwiftUI

public final class PureBackdropBlurView: NSView {
    private var backdropLayer: CALayer?
    private var blurFilter: NSObject?
    private var lastMaskWidth: CGFloat = 0
    private var lastMaskHeight: CGFloat = 0
    
    public override var isFlipped: Bool {
        return true
    }
    
    public var blurRadius: CGFloat = 4.0 {
        didSet {
            updateFilter()
        }
    }
    
    public var fadeWidth: CGFloat = 42.0 {
        didSet {
            lastMaskWidth = 0
            updateMaskImage()
        }
    }
    
    public var topFadeHeight: CGFloat = 20.0 {
        didSet {
            lastMaskHeight = 0
            updateMaskImage()
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
        self.layer?.isOpaque = false
        
        if let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type {
            let layer = backdropClass.init()
            layer.name = "pureBackdropBlur"
            layer.setValue(true, forKey: "windowServerAware")
            layer.setValue(true, forKey: "allowsSubstituteColor")
            layer.setValue(false, forKey: "allowsInPlaceFiltering")
            layer.setValue(true, forKey: "disablesOccludedBackdropBlurs")
            layer.setValue(true, forKey: "ignoresOffscreenGroups")
            self.backdropLayer = layer
            
            self.layer?.addSublayer(layer)
            createAndApplyFilter()
        }
    }
    
    private func createAndApplyFilter() {
        guard let backdropLayer = backdropLayer,
              let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return }
        
        let filter: NSObject?
        if let vblur = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur")?.takeUnretainedValue() as? NSObject {
            filter = vblur
        } else if let gblur = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")?.takeUnretainedValue() as? NSObject {
            filter = gblur
        } else {
            filter = nil
        }
        
        guard let filter = filter else { return }
        self.blurFilter = filter
        
        filter.setValue(blurRadius, forKey: "inputRadius")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        filter.setValue("default", forKey: "inputQuality")
        
        backdropLayer.setValue([filter], forKey: "filters")
        lastMaskWidth = 0
        lastMaskHeight = 0
        updateMaskImage()
    }
    
    private func updateFilter() {
        blurFilter?.setValue(blurRadius, forKey: "inputRadius")
    }
    
    private func updateMaskImage() {
        guard let filter = blurFilter, bounds.width > 0, bounds.height > 0 else { return }
        
        let w = max(1, Int(bounds.width))
        let h = max(1, Int(bounds.height))
        if abs(lastMaskWidth - bounds.width) < 1.0 && abs(lastMaskHeight - bounds.height) < 1.0 {
            return
        }
        lastMaskWidth = bounds.width
        lastMaskHeight = bounds.height
        
        if fadeWidth <= 0 && topFadeHeight <= 0 {
            filter.setValue(nil, forKey: "inputMaskImage")
            return
        }
        
        guard let context = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        
        // Match top-left flipped orientation
        context.translateBy(x: 0, y: CGFloat(h))
        context.scaleBy(x: 1.0, y: -1.0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Pass 1: Horizontal gradient (fade right edge to 0.0 blur)
        let hColors = [
            NSColor(red: 1, green: 1, blue: 1, alpha: 1.0).cgColor,
            NSColor(red: 1, green: 1, blue: 1, alpha: 1.0).cgColor,
            NSColor(red: 1, green: 1, blue: 1, alpha: 0.0).cgColor
        ] as CFArray
        let hSplit = max(0.0, min(1.0, CGFloat(w - Int(fadeWidth)) / CGFloat(w)))
        if let hGrad = CGGradient(colorsSpace: colorSpace, colors: hColors, locations: [0.0, hSplit, 1.0]) {
            context.drawLinearGradient(hGrad, start: .zero, end: CGPoint(x: w, y: 0), options: [])
        }
        
        // Pass 2: Vertical gradient (fade top edge from 0.0 to 1.0 blur, matching Notification Center)
        if topFadeHeight > 0 {
            context.setBlendMode(.destinationIn)
            let vColors = [
                NSColor(red: 1, green: 1, blue: 1, alpha: 0.0).cgColor,
                NSColor(red: 1, green: 1, blue: 1, alpha: 1.0).cgColor,
                NSColor(red: 1, green: 1, blue: 1, alpha: 1.0).cgColor
            ] as CFArray
            let vSplit = max(0.0, min(1.0, topFadeHeight / CGFloat(h)))
            if let vGrad = CGGradient(colorsSpace: colorSpace, colors: vColors, locations: [0.0, vSplit, 1.0]) {
                context.drawLinearGradient(vGrad, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            }
        }
        
        if let maskImage = context.makeImage() {
            filter.setValue(maskImage, forKey: "inputMaskImage")
        }
    }
    
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdropLayer?.frame = bounds
        updateMaskImage()
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
        panel.setValue(false, forKey: "shouldAutoFlattenLayerTree")
        panel.setValue(false, forKey: "canHostLayersInWindowServer")
        panel.setValue(true, forKey: "canHostLayersInWindowServer")
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: screenFrame.height))
        containerView.wantsLayer = true
        containerView.autoresizingMask = [.width, .height]
        
        let blurView = PureBackdropBlurView(frame: containerView.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blurRadius = 4.0
        blurView.fadeWidth = 42.0
        blurView.topFadeHeight = 20.0
        
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        
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
