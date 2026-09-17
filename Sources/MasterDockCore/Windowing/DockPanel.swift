import Foundation
import AppKit

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSSetWindowBackgroundBlurRadius")
private func CGSSetWindowBackgroundBlurRadius(_ cid: UInt32, _ wid: UInt32, _ blurRadius: UInt32) -> Int32

public final class DockPanel: NSPanel {
    public var onDismissRequested: (() -> Void)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isMovableByWindowBackground = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isReleasedWhenClosed = false
    }
    
    public func enablePureWindowBlur(radius: UInt32 = 64) {
        let cid = CGSMainConnectionID()
        _ = CGSSetWindowBackgroundBlurRadius(cid, UInt32(self.windowNumber), radius)
    }
    
    public override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
    }
    
    public override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func cancelOperation(_ sender: Any?) {
        // Handle Escape key
        onDismissRequested?()
    }
}
