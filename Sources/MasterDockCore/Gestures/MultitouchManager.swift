import Foundation
import AppKit
import Combine
import MasterDockMultitouchC

public final class MultitouchManager: ObservableObject {
    public static let shared = MultitouchManager()
    
    public let stateMachine: GestureStateMachine
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var isRunning = false
    
    @Published public private(set) var currentState: GestureDockState = .idle
    @Published public private(set) var isMultitouchSupported: Bool = false
    
    public init(configuration: GestureConfiguration = .default) {
        self.stateMachine = GestureStateMachine(configuration: configuration)
        self.stateMachine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.currentState = state
            }
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        isMultitouchSupported = MDMultitouchIsAvailable()
        
        if isMultitouchSupported {
            let context = Unmanaged.passUnretained(self).toOpaque()
            let started = MDMultitouchStartListening({ touches, count, timestamp, ctx in
                guard let ctx = ctx, count > 0, let touches = touches else { return }
                let manager = Unmanaged<MultitouchManager>.fromOpaque(ctx).takeUnretainedValue()
                
                // Count active touching fingers
                var activeTouches: [MTTouch] = []
                for i in 0..<Int(count) {
                    let touch = touches[i]
                    if touch.state == MTTouchStateTouching || touch.state == MTTouchStateMakeTouch {
                        activeTouches.append(touch)
                    }
                }
                
                if activeTouches.count == 2 {
                    let minX = Double(min(activeTouches[0].normalizedPosition.position.x, activeTouches[1].normalizedPosition.position.x))
                    let avgX = Double(activeTouches[0].normalizedPosition.position.x + activeTouches[1].normalizedPosition.position.x) / 2.0
                    let avgY = Double(activeTouches[0].normalizedPosition.position.y + activeTouches[1].normalizedPosition.position.y) / 2.0
                    manager.stateMachine.processTouches(
                        fingerCount: 2,
                        averageX: avgX,
                        averageY: avgY,
                        minX: minX,
                        timestamp: timestamp
                    )
                } else if activeTouches.isEmpty {
                    manager.stateMachine.finishGesture()
                }
            }, context)
            
            if !started {
                print("[MultitouchManager] Notice: Multitouch hardware callback initialization fell back to hotkeys.")
            }
        }
        
        setupHotkeyFallbacks()
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        
        MDMultitouchStopListening()
        
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    public static let shortcutsEnabledKey = "keyboard_shortcuts_enabled"
    
    /// Set by the app so shortcuts open and close the dock exactly like the menu bar icon.
    public var onToggleDock: (() -> Void)?
    public var onToggleVoice: (() -> Void)?
    
    public static var shortcutsEnabled: Bool {
        UserDefaults.standard.object(forKey: shortcutsEnabledKey) as? Bool ?? true
    }
    
    /// Keyboard shortcuts: Shift+Command+Space opens the dock, Option+Shift+Command+Space opens voice.
    /// (These replaced Option+Space, which macOS uses to type a special space character.)
    public func setupHotkeyFallbacks() {
        GlobalHotKeys.shared.unregisterAll()
        guard Self.shortcutsEnabled else { return }
        GlobalHotKeys.shared.register(id: 1, GlobalHotKeys.toggleDock) { [weak self] in
            guard let self else { return }
            if let toggle = self.onToggleDock { toggle(); return }
            if self.currentState == .dockRevealed(mode: .standardDock) {
                self.stateMachine.resetToIdle()
            } else {
                self.stateMachine.triggerManual(mode: .standardDock)
            }
        }
        GlobalHotKeys.shared.register(id: 2, GlobalHotKeys.voiceMode) { [weak self] in
            guard let self else { return }
            if let toggle = self.onToggleVoice { toggle(); return }
            if self.currentState == .voiceModeActive {
                self.stateMachine.resetToIdle()
            } else {
                self.stateMachine.triggerManual(mode: .expandedVoice)
            }
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Spacebar is keyCode 49
        guard event.keyCode == 49 else { return false }
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags == [.option] {
            // Option + Space -> Toggle standard dock
            DispatchQueue.main.async { [weak self] in
                if self?.currentState == .dockRevealed(mode: .standardDock) {
                    self?.stateMachine.resetToIdle()
                } else {
                    self?.stateMachine.triggerManual(mode: .standardDock)
                }
            }
            return true
        } else if flags == [.option, .shift] {
            // Option + Shift + Space -> Toggle AI Voice Mode
            DispatchQueue.main.async { [weak self] in
                if self?.currentState == .voiceModeActive {
                    self?.stateMachine.resetToIdle()
                } else {
                    self?.stateMachine.triggerManual(mode: .expandedVoice)
                }
            }
            return true
        }
        
        return false
    }
}
