import Foundation
import AppKit
import SwiftUI

/// How the blur past the cards' edge fades out. Selectable live from Settings > Blur Lab.
public enum DockBlurMethod: String, CaseIterable, Sendable {
    /// Several blur layers of decreasing strength, each crossfading into the next.
    case bands
    /// One blur layer whose opacity eases out.
    case fade
    /// The system's variable-blur filter driven by a gradient mask.
    case variable
}

/// Live-tunable blur settings (Settings > Blur Lab). Stored in UserDefaults.
public enum DockBlurSettings {
    public static let methodKey = "blur_method"
    public static let radiusKey = "blur_radius"
    public static let fadeKey = "blur_fade_width"
    public static let hazeKey = "blur_haze"

    public static let defaultMethod: DockBlurMethod = .variable
    public static let defaultRadius: Double = 4
    public static let defaultFade: Double = 40
    public static let defaultHaze: Double = 0.0

    public static var method: DockBlurMethod {
        DockBlurMethod(rawValue: UserDefaults.standard.string(forKey: methodKey) ?? "") ?? defaultMethod
    }
    public static var radius: Double { value(radiusKey, defaultRadius, 0...40) }
    public static var fade: Double { value(fadeKey, defaultFade, 4...200) }
    public static var haze: Double { value(hazeKey, defaultHaze, 0...0.8) }

    private static func value(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return min(range.upperBound, max(range.lowerBound, UserDefaults.standard.double(forKey: key)))
    }
}

/// The see-through blur behind the dock, matched to macOS Notification Center.
///
/// Behind the cards the background is blurred at full strength. Past the cards' edge the blur
/// gets weaker until the screen is sharp again. `fadeStartX` is where the cards end.
public final class PureBackdropBlurView: NSView {
    public var method: DockBlurMethod = DockBlurSettings.defaultMethod { didSet { if method != oldValue { rebuildLayers() } } }
    /// Blur strength behind the cards.
    public var blurRadius: CGFloat = 12 { didSet { if blurRadius != oldValue { rebuildLayers() } } }
    /// Distance (points) over which the blur fades out, starting at `fadeStartX`.
    public var fadeWidth: CGFloat = 56 { didSet { needsLayout = true } }
    /// Where the fade begins (the cards' right edge), in this view's coordinates.
    public var fadeStartX: CGFloat = 0 { didSet { needsLayout = true } }
    /// Soft top edge, like Notification Center.
    public var topFadeHeight: CGFloat = 20 { didSet { needsLayout = true } }
    /// Light white wash next to the cards that fades out with the blur (0 = none).
    public var haze: CGFloat = 0 { didSet { needsLayout = true } }

    private let bandStrengths: [CGFloat] = [1.0, 0.62, 0.38, 0.22, 0.11, 0.04]

    private let stackLayer = CALayer()
    private let topFadeMask = CAGradientLayer()
    private let hazeLayer = CAGradientLayer()
    private var blurLayers: [CALayer] = []
    private var blurMasks: [CAGradientLayer] = []
    private var variableFilter: NSObject?

    public override var isFlipped: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.addSublayer(stackLayer)
        stackLayer.mask = topFadeMask
        hazeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        hazeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        rebuildLayers()
    }

    // MARK: - Layers

    private func makeBackdrop() -> CALayer? {
        guard let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return nil }
        let backdrop = backdropClass.init()
        backdrop.setValue(true, forKey: "windowServerAware")
        // Never swap the blur for a flat substitute color: it must stay a see-through blur.
        backdrop.setValue(false, forKey: "allowsSubstituteColor")
        backdrop.setValue(false, forKey: "allowsInPlaceFiltering")
        backdrop.setValue(false, forKey: "disablesOccludedBackdropBlurs")
        return backdrop
    }

    private static func makeFilter(_ type: String, radius: CGFloat) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let filter = filterClass.perform(NSSelectorFromString("filterWithType:"), with: type)?
                .takeUnretainedValue() as? NSObject else { return nil }
        filter.setValue(radius, forKey: "inputRadius")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        return filter
    }

    private func rebuildLayers() {
        blurLayers.forEach { $0.removeFromSuperlayer() }
        hazeLayer.removeFromSuperlayer()
        blurLayers = []
        blurMasks = []
        variableFilter = nil

        switch method {
        case .bands:
            // Weakest band at the bottom, strongest on top.
            for strength in bandStrengths.reversed() {
                guard let backdrop = makeBackdrop() else { break }
                if let filter = Self.makeFilter("gaussianBlur", radius: blurRadius * strength) {
                    backdrop.setValue([filter], forKey: "filters")
                }
                let mask = makeHorizontalMask()
                backdrop.mask = mask
                stackLayer.addSublayer(backdrop)
                blurLayers.insert(backdrop, at: 0)
                blurMasks.insert(mask, at: 0)
            }
        case .fade:
            if let backdrop = makeBackdrop() {
                if let filter = Self.makeFilter("gaussianBlur", radius: blurRadius) {
                    backdrop.setValue([filter], forKey: "filters")
                }
                let mask = makeHorizontalMask()
                backdrop.mask = mask
                stackLayer.addSublayer(backdrop)
                blurLayers = [backdrop]
                blurMasks = [mask]
            }
        case .variable:
            if let backdrop = makeBackdrop() {
                let filter = Self.makeFilter("variableBlur", radius: blurRadius)
                    ?? Self.makeFilter("gaussianBlur", radius: blurRadius)
                if let filter = filter { backdrop.setValue([filter], forKey: "filters") }
                variableFilter = filter
                stackLayer.addSublayer(backdrop)
                blurLayers = [backdrop]
            }
        }
        stackLayer.addSublayer(hazeLayer)
        needsLayout = true
    }

    private func makeHorizontalMask() -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        return mask
    }

    // MARK: - Layout

    public override func layout() {
        super.layout()
        let w = bounds.width
        guard w > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stackLayer.frame = bounds
        layoutTopFade()

        let start = max(0, min(w, fadeStartX))
        let width = max(1, fadeWidth)
        blurLayers.forEach { $0.frame = bounds }

        switch method {
        case .bands:
            let count = blurMasks.count
            let slice = width / CGFloat(max(1, count))
            for (i, mask) in blurMasks.enumerated() {
                mask.frame = bounds
                let center = start + slice * (CGFloat(i) + 0.5)
                var stops: [(CGFloat, CGFloat)] = []
                if i == 0 {
                    stops.append((0, 1))
                } else {
                    stops.append((0, 0))
                    for s in 0...4 { let t = CGFloat(s) / 4; stops.append((center - slice + slice * t, Self.ease(t))) }
                }
                for s in 0...4 { let t = CGFloat(s) / 4; stops.append((center + slice * t, 1 - Self.ease(t))) }
                stops.append((w, 0))
                apply(stops, to: mask, width: w)
            }
        case .fade:
            if let mask = blurMasks.first {
                mask.frame = bounds
                var stops: [(CGFloat, CGFloat)] = [(0, 1)]
                for s in 0...16 { let t = CGFloat(s) / 16; stops.append((start + width * t, 1 - Self.ease(t))) }
                stops.append((w, 0))
                apply(stops, to: mask, width: w)
            }
        case .variable:
            variableFilter?.setValue(makeVariableMaskImage(start: start, width: width), forKey: "inputMaskImage")
        }

        // White haze: strongest at the cards' edge, fading out with the blur.
        hazeLayer.frame = bounds
        if haze > 0 {
            var colors: [CGColor] = [NSColor.white.withAlphaComponent(haze).cgColor]
            var locations: [NSNumber] = [0]
            for s in 0...12 {
                let t = CGFloat(s) / 12
                colors.append(NSColor.white.withAlphaComponent(haze * (1 - Self.ease(t))).cgColor)
                locations.append(NSNumber(value: Double(max(0, min(1, (start + width * t) / w)))))
            }
            hazeLayer.colors = colors
            hazeLayer.locations = locations
            hazeLayer.isHidden = false
        } else {
            hazeLayer.isHidden = true
        }
        CATransaction.commit()
    }

    private func apply(_ stops: [(CGFloat, CGFloat)], to mask: CAGradientLayer, width w: CGFloat) {
        mask.colors = stops.map { NSColor.black.withAlphaComponent(max(0, min(1, $0.1))).cgColor }
        mask.locations = stops.map { NSNumber(value: Double(max(0, min(1, $0.0 / w)))) }
    }

    private func layoutTopFade() {
        topFadeMask.frame = bounds
        let split = max(0, min(1, topFadeHeight / bounds.height))
        var colors: [CGColor] = []
        var locations: [NSNumber] = []
        for i in 0...8 {
            let t = CGFloat(i) / 8
            colors.append(NSColor.black.withAlphaComponent(Self.ease(t)).cgColor)
            locations.append(NSNumber(value: Double(split * t)))
        }
        colors.append(NSColor.black.cgColor)
        locations.append(1)
        topFadeMask.startPoint = CGPoint(x: 0.5, y: 0)
        topFadeMask.endPoint = CGPoint(x: 0.5, y: 1)
        topFadeMask.colors = colors
        topFadeMask.locations = locations
    }

    private func makeVariableMaskImage(start: CGFloat, width: CGFloat) -> CGImage? {
        let w = max(1, Int(bounds.width))
        guard let context = CGContext(
            data: nil, width: w, height: 1, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        for x in 0..<w {
            let t = max(0, min(1, (CGFloat(x) - start) / width))
            context.setFillColor(NSColor(white: 1, alpha: 1 - Self.ease(t)).cgColor)
            context.fill(CGRect(x: x, y: 0, width: 1, height: 1))
        }
        return context.makeImage()
    }

    private static func ease(_ t: CGFloat) -> CGFloat {
        return t * t * (3 - 2 * t)
    }
}

/// Holds the cards' width so the SwiftUI content can sit on the left of a wider window.
public final class DockLayoutModel: ObservableObject {
    @Published public var contentWidth: CGFloat
    public init(contentWidth: CGFloat) { self.contentWidth = contentWidth }
}

/// Lays the dock content out at the cards' width, leaving the fading blur strip empty.
struct BleedLayoutView<Content: View>: View {
    @ObservedObject var model: DockLayoutModel
    let content: Content
    
    var body: some View {
        content
            .frame(width: model.contentWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

public final class GlassWindowController: NSObject, ObservableObject {
    public static let defaultWidth: CGFloat = 340.0
    
    /// Extra see-through space to the right of the cards where the blur fades into the screen,
    /// like Notification Center. Clicks in this strip pass straight through to whatever is behind.
    public static let blurBleed: CGFloat = 120.0

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

    // MARK: Slide engine
    // The window itself never moves. Moving an NSWindow frame every frame is slow (each move is a
    // round trip to the window server and redraws the whole SwiftUI tree). Instead the window sits
    // at its final spot and only the content view slides inside it, which the GPU composites cheaply.
    private var slideHostView: NSView?
    private var slideContentView: NSView?
    private let layoutModel = DockLayoutModel(contentWidth: GlassWindowController.defaultWidth)
    /// Fades everything to the right of the cards (blur, glass glow, shadows) out to fully clear
    /// at the window edge, so no layer can ever end in a visible line.
    private let edgeFadeMask = CAGradientLayer()
    private var mousePassThroughMonitors: [Any] = []
    private var motion = DockSlideMotion()
    private var drive: SlideDrive = .idle
    private var trackingTarget: Double = 0
    private var slideCompletion: (() -> Void)?
    private var stopFrameTimer: (() -> Void)?
    private var lastFrameTime: CFTimeInterval = 0

    private enum SlideDrive: Equatable {
        case idle
        case tracking
        case spring(target: Double, response: Double, dampingRatio: Double)
    }

    // Spring feel: opening has a hint of softness, closing is quick with no bounce.
    // Spring feel, using Apple's own two numbers (response + damping ratio). Critically damped
    // (1.0) so the panel never overshoots: it is pinned to the screen edge, so any bounce past
    // fully open would only show up as a stall. Your swipe speed still carries into the spring.
    private let presentResponse = 0.36
    private let presentDamping = 1.0
    private let dismissResponse = 0.30
    private let dismissDamping = 1.0
    
    // Accessibility: macOS Reduce Motion and Reduce Transparency settings.
    private var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    private weak var backdropBlurView: PureBackdropBlurView?
    private var accessibilityObserver: NSObjectProtocol?

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var currentMode: DockPresentationMode = .standardDock
    @Published public var isPinned: Bool = UserDefaults.standard.bool(forKey: "dock_is_pinned") {
        didSet {
            UserDefaults.standard.set(isPinned, forKey: "dock_is_pinned")
            if isPinned {
                stopOutsideClickMonitoring()
            } else if isVisible {
                startOutsideClickMonitoring()
            }
        }
    }

    public var onDismiss: (() -> Void)?

    public override init() {
        super.init()
        observeSettings()
        observeDisplayChanges()
    }
    
    /// A monitor was plugged in, unplugged, or changed resolution: keep the dock on a real screen
    /// and sized to it.
    private func observeDisplayChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let current = self.currentScreen, !NSScreen.screens.contains(current) {
                self.currentScreen = NSScreen.main
            }
            self.resizePanel(to: self.width(for: self.currentMode))
        }
    }

    private func observeSettings() {
        // This notification fires for EVERY UserDefaults write in the app (clipboard history,
        // checklist, media...). Only react when the dock width really changed, and never use a
        // blocking animated setFrame here, which used to freeze the UI on unrelated saves.
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Blur Lab sliders in Settings apply live.
            self?.applyBlurSettings()
            guard let self = self, let panel = self.panel, panel.isVisible else { return }
            let targetWidth = self.width(for: self.currentMode)
            guard abs(panel.frame.width - (targetWidth + Self.blurBleed)) >= 0.5 else { return }

            self.resizePanel(to: targetWidth)
            switch self.drive {
            case .idle where self.isVisible:
                self.motion = DockSlideMotion(position: Double(targetWidth + Self.blurBleed))
                self.applySlide()
            case .spring(let target, let response, let damping) where target > 0:
                self.drive = .spring(target: Double(targetWidth + Self.blurBleed), response: response, dampingRatio: damping)
            default:
                break
            }
        }
    }

    public func setup<Content: View>(with rootView: Content) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        self.currentScreen = screen

        let width = currentDockWidth
        let shownRect = self.shownRect(width: width, on: screen)
        let contentBounds = NSRect(origin: .zero, size: shownRect.size)

        let panel = DockPanel(contentRect: shownRect)
        panel.setValue(false, forKey: "shouldAutoFlattenLayerTree")
        panel.setValue(false, forKey: "canHostLayersInWindowServer")
        panel.setValue(true, forKey: "canHostLayersInWindowServer")
        panel.ignoresMouseEvents = true

        // Fixed host that fills the window and clips the sliding content at the window edge.
        let slideHost = NSView(frame: contentBounds)
        slideHost.wantsLayer = true
        slideHost.layer?.backgroundColor = NSColor.clear.cgColor
        slideHost.layer?.masksToBounds = true
        slideHost.autoresizingMask = [.width, .height]

        // Everything visible lives in here; applySlide() moves its origin.
        let containerView = NSView(frame: contentBounds)
        containerView.wantsLayer = true
        containerView.autoresizingMask = []

        let blurView = PureBackdropBlurView(frame: containerView.bounds)
        // Reduce Transparency: no see-through blur; the cards switch to a solid look on their own.
        blurView.isHidden = reduceTransparency
        self.backdropBlurView = blurView
        blurView.autoresizingMask = [.width, .height]
        blurView.topFadeHeight = 20.0

        // The hosting view spans the whole window (so nothing it draws stops at the cards' edge);
        // the SwiftUI content itself is laid out at the cards' width on the left.
        layoutModel.contentWidth = width
        applyBlurSettings()
        let hostingView = NSHostingView(rootView: BleedLayoutView(model: layoutModel, content: rootView))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false

        containerView.addSubview(blurView)
        containerView.addSubview(hostingView)
        slideHost.addSubview(containerView)
        panel.contentView = slideHost

        panel.onDismissRequested = { [weak self] in
            self?.dismiss()
        }

        self.panel = panel
        self.slideHostView = slideHost
        self.slideContentView = containerView
        observeAccessibilitySettings()
        containerView.layer?.mask = edgeFadeMask
        updateEdgeFadeMask(contentWidth: width, totalWidth: contentBounds.width, height: contentBounds.height)
        startMousePassThrough()
        self.motion = DockSlideMotion()
        applySlide()
    }

    /// Called on every trackpad frame while the user is swiping.
    public func updateInteractiveProgress(_ progress: Double, mode: DockPresentationMode = .standardDock) {
        guard let panel = panel else { return }
        if !panel.isVisible { adoptCursorScreen() }

        let clampedProgress = max(0.0, min(1.0, progress))
        let width = self.width(for: mode)
        resizePanel(to: width)
        trackingTarget = Double(width + Self.blurBleed) * clampedProgress

        if !panel.isVisible {
            guard clampedProgress > 0.02 else { return }
            motion = DockSlideMotion()
            applySlide()
            panel.ignoresMouseEvents = true
            panel.orderFrontRegardless()
        }

        slideCompletion = nil
        drive = .tracking
        startFrameTimer()
    }

    public func present(mode: DockPresentationMode = .standardDock, animated: Bool = true) {
        guard let panel = panel else { return }
        if !panel.isVisible { adoptCursorScreen() }

        let modeChanged = mode != currentMode
        self.currentMode = mode
        let width = self.width(for: mode)
        resizePanel(to: width)
        let target = Double(width + Self.blurBleed)

        // Activating the app calls back into present(). If we are already open (or already
        // sliding open) in this mode, don't restart the animation, which caused a visible stutter.
        if isVisible && panel.isVisible && !modeChanged && isOpeningOrOpen(target: target) {
            focusPanel()
            return
        }

        isVisible = true
        if !panel.isVisible {
            motion = DockSlideMotion()
            applySlide()
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = false

        if animated {
            animateSlide(to: target, response: presentResponse, dampingRatio: presentDamping) { [weak self] in
                self?.startOutsideClickMonitoring()
            }
        } else {
            cancelSlideAnimation()
            motion = DockSlideMotion(position: target)
            applySlide()
            startOutsideClickMonitoring()
        }

        // Activate on the next run loop pass so app activation never delays the first frame.
        DispatchQueue.main.async { [weak self] in
            self?.focusPanel()
        }
    }

    public func dismiss(animated: Bool = true) {
        guard let panel = panel, panel.isVisible || motion.position > 0 else { return }

        stopOutsideClickMonitoring()
        isVisible = false
        panel.ignoresMouseEvents = true

        let finish: () -> Void = { [weak self] in
            panel.orderOut(nil)
            self?.onDismiss?()
        }

        if animated {
            animateSlide(to: 0, response: dismissResponse, dampingRatio: dismissDamping, completion: finish)
        } else {
            cancelSlideAnimation()
            motion = DockSlideMotion()
            applySlide()
            finish()
        }
    }

    // MARK: - Slide helpers

    private func width(for mode: DockPresentationMode) -> CGFloat {
        return (mode == .expandedVoice) ? currentVoiceWidth : currentDockWidth
    }

    private func shownRect(width: CGFloat, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        return NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: width + Self.blurBleed, height: screenFrame.height)
    }
    
    /// Fully visible over the cards, then an eased fade across the strip to clear at the window edge.
    private func updateEdgeFadeMask(contentWidth: CGFloat, totalWidth: CGFloat, height: CGFloat) {
        guard totalWidth > 0 else { return }
        // Keep everything fully visible until the outer 12% of the strip, so the blur gets to fade
        // out on its own (strong to sharp) before opacity takes away the last bit at the edge.
        let start = min(1, max(0, (contentWidth + GlassWindowController.blurBleed * 0.88) / totalWidth))
        var colors: [CGColor] = [NSColor.black.cgColor]
        var locations: [NSNumber] = [0]
        let steps = 20
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let eased = t * t * (3 - 2 * t)
            colors.append(NSColor.black.withAlphaComponent(1 - eased).cgColor)
            locations.append(NSNumber(value: Double(start + (1 - start) * t)))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeFadeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeFadeMask.endPoint = CGPoint(x: 1, y: 0.5)
        edgeFadeMask.colors = colors
        edgeFadeMask.locations = locations
        edgeFadeMask.frame = CGRect(x: 0, y: 0, width: totalWidth, height: height)
        CATransaction.commit()
    }
    
    /// Opens the dock on whichever display the mouse pointer is on (multi-monitor setups).
    /// Only switches while the dock is hidden, so it never jumps screens while you're using it.
    private func adoptCursorScreen() {
        let mouse = NSEvent.mouseLocation
        let target = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen = target, screen != currentScreen else { return }
        currentScreen = screen
        // resizePanel places the window on the new screen (its frame depends on currentScreen).
        resizePanel(to: width(for: currentMode))
    }
    
    /// The part of the window that holds the cards (excludes the fading blur strip).
    private var cardsFrame: NSRect {
        guard let panel = panel else { return .zero }
        var frame = panel.frame
        frame.size.width = max(0, frame.width - Self.blurBleed)
        return frame
    }

    private func resizePanel(to width: CGFloat) {
        guard let panel = panel, let screen = currentScreen ?? NSScreen.main else { return }
        let rect = shownRect(width: width, on: screen)
        guard panel.frame != rect else { return }
        panel.setFrame(rect, display: panel.isVisible)
        layoutModel.contentWidth = width
        backdropBlurView?.fadeStartX = max(0, width - 16)
        updateEdgeFadeMask(contentWidth: width, totalWidth: rect.width, height: rect.height)
        applySlide()
    }

    private func isOpeningOrOpen(target: Double) -> Bool {
        switch drive {
        case .idle:
            return motion.position >= target - 0.5
        case .spring(let springTarget, _, _):
            return abs(springTarget - target) < 0.5
        case .tracking:
            return false
        }
    }

    private func focusPanel() {
        guard let panel = panel, isVisible else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Places the content for the current motion position. Only the view's origin changes, so
    /// nothing is re-laid out or redrawn; Core Animation just moves the existing layers.
    private func applySlide() {
        guard let host = slideHostView, let content = slideContentView else { return }
        let size = host.bounds.size
        let fraction = CGFloat(max(0, min(1, motion.position / max(1, Double(size.width)))))
        
        // Reduce Motion: the same gesture and spring, but shown as a gentle fade in place instead
        // of a slide across the screen (Apple's guidance: cross-fade, don't move large surfaces).
        if reduceMotion {
            panel?.alphaValue = fraction
        } else if panel?.alphaValue != 1 {
            panel?.alphaValue = 1
        }
        let revealed = reduceMotion ? size.width : fraction * size.width
        // Snap to whole screen pixels. In-between positions make text and glass re-blur every
        // frame, which reads as stutter even when the animation itself runs at full speed.
        let scale = host.window?.backingScaleFactor ?? 2
        let x = ((revealed - size.width) * scale).rounded() / scale
        if content.frame.size != size {
            content.setFrameSize(size)
        }
        guard content.frame.origin.x != x || content.frame.origin.y != 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Moving only the origin is cheap: SwiftUI doesn't have to lay the dock out again each frame.
        content.setFrameOrigin(NSPoint(x: x, y: 0))
        CATransaction.commit()
    }

    private func animateSlide(to target: Double, response: Double, dampingRatio: Double, completion: (() -> Void)? = nil) {
        // Replacing a running spring keeps the current velocity, so reversing mid-slide is smooth.
        slideCompletion = completion
        drive = .spring(target: target, response: response, dampingRatio: dampingRatio)
        startFrameTimer()
    }

    private func cancelSlideAnimation() {
        drive = .idle
        slideCompletion = nil
        stopFrameTimerIfNeeded()
    }

    /// Ticks once per display refresh (120 Hz on ProMotion screens).
    private func startFrameTimer() {
        guard stopFrameTimer == nil else { return }
        lastFrameTime = 0

        if #available(macOS 14.0, *), let view = slideHostView, view.window != nil {
            let link = view.displayLink(target: self, selector: #selector(handleFrameTick(_:)))
            link.add(to: .main, forMode: .common)
            stopFrameTimer = { link.invalidate() }
        } else {
            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
                self?.handleFrameTick(timer)
            }
            RunLoop.main.add(timer, forMode: .common)
            stopFrameTimer = { timer.invalidate() }
        }
    }

    private func stopFrameTimerIfNeeded() {
        stopFrameTimer?()
        stopFrameTimer = nil
        lastFrameTime = 0
    }

    @objc private func handleFrameTick(_ sender: Any) {
        let now = CACurrentMediaTime()
        let dt = lastFrameTime == 0 ? 1.0 / 120.0 : now - lastFrameTime
        lastFrameTime = now

        switch drive {
        case .idle:
            stopFrameTimerIfNeeded()

        case .tracking:
            motion.follow(target: trackingTarget, dt: dt)
            applySlide()

        case .spring(let target, let response, let damping):
            let settled = motion.stepSpring(target: target, dt: dt, response: response, dampingRatio: damping)
            applySlide()
            if settled {
                drive = .idle
                stopFrameTimerIfNeeded()
                let completion = slideCompletion
                slideCompletion = nil
                completion?()
            }
        }
    }

    // MARK: - Outside click

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        guard !isPinned, isVisible else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, self.isVisible, !self.isPinned else { return }
            let clickLocation = NSEvent.mouseLocation
            if !self.cardsFrame.contains(clickLocation) {
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

    // MARK: - Blur settings
    
    /// Reads the Blur Lab values (Settings) and applies them. The fade starts at the cards' right
    /// edge, which sits 16pt in from the content edge.
    private func applyBlurSettings() {
        guard let blur = backdropBlurView else { return }
        blur.method = DockBlurSettings.method
        blur.blurRadius = CGFloat(DockBlurSettings.radius)
        blur.fadeWidth = CGFloat(DockBlurSettings.fade)
        blur.haze = CGFloat(DockBlurSettings.haze)
        blur.fadeStartX = max(0, layoutModel.contentWidth - 16)
    }
    
    // MARK: - Accessibility settings
    
    private func observeAccessibilitySettings() {
        guard accessibilityObserver == nil else { return }
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            self.reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            self.backdropBlurView?.isHidden = self.reduceTransparency
            self.applySlide()
        }
    }
    
    // MARK: - Click-through for the blur strip
    
    /// The fading blur strip is part of the window, but it should feel like empty screen: while the
    /// pointer is over it, the window ignores the mouse so clicks reach the app behind it.
    private func startMousePassThrough() {
        guard mousePassThroughMonitors.isEmpty else { return }
        let update: () -> Void = { [weak self] in self?.updateMousePassThrough() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { _ in update() }) {
            mousePassThroughMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { event in
            update()
            return event
        }) {
            mousePassThroughMonitors.append(local)
        }
    }
    
    private func updateMousePassThrough() {
        guard let panel = panel, isVisible, drive != .tracking else { return }
        let overCards = cardsFrame.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == overCards {
            panel.ignoresMouseEvents = !overCards
        }
    }
    
    deinit {
        if let observer = accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        mousePassThroughMonitors.forEach { NSEvent.removeMonitor($0) }
        stopFrameTimerIfNeeded()
        stopOutsideClickMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
}
