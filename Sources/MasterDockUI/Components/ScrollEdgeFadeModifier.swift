import SwiftUI
import AppKit

public struct ScrollEdgeFadeState: Equatable {
    public var startFadeProgress: CGFloat // top or leading
    public var endFadeProgress: CGFloat   // bottom or trailing
    
    public init(startFadeProgress: CGFloat = 0.0, endFadeProgress: CGFloat = 0.0) {
        self.startFadeProgress = startFadeProgress
        self.endFadeProgress = endFadeProgress
    }
    
    // Backwards compatibility aliases
    public var topFadeProgress: CGFloat { startFadeProgress }
    public var bottomFadeProgress: CGFloat { endFadeProgress }
}

public enum ScrollEdgeCalculator {
    /// Computes dynamic start and end fade progress based on current scroll position and overflow.
    /// - If user has not scrolled (offset <= 0), no fade is applied (0.0).
    /// - When scrolling (offset > 0), start edge smoothly fades up to 1.0 within `fadeThreshold`.
    /// - End edge fades if there is remaining scrollable content (distFromEnd > 0) AND user has initiated scroll.
    /// - When reaching end (distFromEnd <= 0), end fade returns to 0.0.
    public static func calculateFade(
        offset: CGFloat,
        distFromEnd: CGFloat,
        fadeThreshold: CGFloat = 16.0
    ) -> ScrollEdgeFadeState {
        guard fadeThreshold > 0 else {
            return ScrollEdgeFadeState(startFadeProgress: 0, endFadeProgress: 0)
        }
        
        let startProgress = min(1.0, max(0.0, offset / fadeThreshold))
        let endProgress = min(1.0, max(0.0, distFromEnd / fadeThreshold))
        
        return ScrollEdgeFadeState(
            startFadeProgress: startProgress,
            endFadeProgress: endProgress
        )
    }
    
    // Backwards compatibility overload
    public static func calculateFade(
        offsetY: CGFloat,
        distFromBottom: CGFloat,
        fadeThreshold: CGFloat = 16.0
    ) -> ScrollEdgeFadeState {
        calculateFade(offset: offsetY, distFromEnd: distFromBottom, fadeThreshold: fadeThreshold)
    }
}

public struct ScrollEdgeFadeObserver: NSViewRepresentable {
    public var axis: Axis
    public var fadeLength: CGFloat
    public var fadeThreshold: CGFloat
    public var onFadeChange: ((CGFloat, CGFloat) -> Void)?
    
    public init(
        axis: Axis = .vertical,
        fadeLength: CGFloat = 36.0,
        fadeThreshold: CGFloat = 16.0,
        onFadeChange: ((CGFloat, CGFloat) -> Void)? = nil
    ) {
        self.axis = axis
        self.fadeLength = fadeLength
        self.fadeThreshold = fadeThreshold
        self.onFadeChange = onFadeChange
    }
    
    public func makeNSView(context: Context) -> NSScrollEdgeFadingControllerView {
        let view = NSScrollEdgeFadingControllerView()
        view.axis = axis
        view.fadeLength = fadeLength
        view.fadeThreshold = fadeThreshold
        view.onFadeChange = onFadeChange
        return view
    }
    
    public func updateNSView(_ nsView: NSScrollEdgeFadingControllerView, context: Context) {
        nsView.axis = axis
        nsView.fadeLength = fadeLength
        nsView.fadeThreshold = fadeThreshold
        nsView.onFadeChange = onFadeChange
        nsView.handleScroll()
    }
}

public class NSScrollEdgeFadingControllerView: NSView {
    private let maskLayer = CAGradientLayer()
    private weak var observedScrollView: NSScrollView?
    private weak var observedClipView: NSClipView?
    
    public var axis: Axis = .vertical {
        didSet {
            updateGradientPoints()
        }
    }
    public var fadeLength: CGFloat = 36.0
    public var fadeThreshold: CGFloat = 16.0
    public var onFadeChange: ((CGFloat, CGFloat) -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateGradientPoints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateGradientPoints() {
        if axis == .vertical {
            maskLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            maskLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        } else {
            maskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            maskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        }
    }
    
    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        setupTracking()
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupTracking()
    }
    
    private func setupTracking() {
        NotificationCenter.default.removeObserver(self)
        guard let sv = enclosingScrollView else { return }
        self.observedScrollView = sv
        let clip = sv.contentView
        self.observedClipView = clip
        
        sv.wantsLayer = true
        sv.postsFrameChangedNotifications = true
        clip.wantsLayer = true
        clip.postsBoundsChangedNotifications = true
        clip.postsFrameChangedNotifications = true
        
        updateGradientPoints()
        sv.layer?.mask = maskLayer
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollNotification),
            name: NSView.boundsDidChangeNotification,
            object: clip
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollNotification),
            name: NSView.frameDidChangeNotification,
            object: clip
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollNotification),
            name: NSView.frameDidChangeNotification,
            object: sv
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.handleScroll()
        }
    }
    
    @objc private func handleScrollNotification() {
        handleScroll()
    }
    
    @objc public func handleScroll() {
        guard let sv = observedScrollView ?? enclosingScrollView else { return }
        let bounds = sv.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let visibleRect = sv.contentView.documentVisibleRect
        
        let offset: CGFloat
        let maxScroll: CGFloat
        let dimension: CGFloat
        
        if axis == .vertical {
            let docHeight = sv.documentView?.frame.height ?? 0
            let viewportHeight = visibleRect.height
            maxScroll = max(0, docHeight - viewportHeight)
            offset = max(0, visibleRect.origin.y)
            dimension = bounds.height
        } else {
            let docWidth = sv.documentView?.frame.width ?? 0
            let viewportWidth = visibleRect.width
            maxScroll = max(0, docWidth - viewportWidth)
            offset = max(0, visibleRect.origin.x)
            dimension = bounds.width
        }
        
        let distFromEnd = max(0, maxScroll - offset)
        
        let state = ScrollEdgeCalculator.calculateFade(
            offset: offset,
            distFromEnd: (maxScroll > 1 ? distFromEnd : 0),
            fadeThreshold: fadeThreshold
        )
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = bounds
        
        let startFraction = max(0.001, min(0.35, fadeLength / max(1.0, dimension)))
        let endFraction = max(0.001, min(0.35, fadeLength / max(1.0, dimension)))
        
        let startAlpha = 1.0 - state.startFadeProgress
        let endAlpha = 1.0 - state.endFadeProgress
        
        maskLayer.colors = [
            NSColor.black.withAlphaComponent(startAlpha).cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.black.withAlphaComponent(endAlpha).cgColor
        ]
        
        maskLayer.locations = [
            0.0,
            NSNumber(value: Double(startFraction)),
            NSNumber(value: Double(max(startFraction, 1.0 - endFraction))),
            1.0
        ]
        CATransaction.commit()
        
        if let callback = onFadeChange {
            DispatchQueue.main.async {
                callback(state.startFadeProgress, state.endFadeProgress)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

public struct DynamicScrollEdgeFadeModifier: ViewModifier {
    public var axis: Axis = .vertical
    public var fadeLength: CGFloat = 36.0
    public var fadeThreshold: CGFloat = 16.0
    
    public init(axis: Axis = .vertical, fadeLength: CGFloat = 36.0, fadeThreshold: CGFloat = 16.0) {
        self.axis = axis
        self.fadeLength = fadeLength
        self.fadeThreshold = fadeThreshold
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ScrollEdgeFadeObserver(axis: axis, fadeLength: fadeLength, fadeThreshold: fadeThreshold)
            )
    }
}

public extension View {
    func scrollEdgeFade(axis: Axis = .vertical, fadeLength: CGFloat = 36.0, fadeThreshold: CGFloat = 16.0) -> some View {
        self.modifier(DynamicScrollEdgeFadeModifier(axis: axis, fadeLength: fadeLength, fadeThreshold: fadeThreshold))
    }
}
