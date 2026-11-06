import Foundation

public enum GestureDockState: Equatable, Sendable {
    case idle
    case trackingLeftSwipe(progress: Double, velocityX: Double)
    case trackingTopSwipe(progress: Double, velocityY: Double)
    case dockRevealed(mode: DockPresentationMode)
    case dockDismissed
    case voiceModeActive
    case cancelled
}

public enum DockPresentationMode: Equatable, Sendable {
    case standardDock
    case expandedVoice
}

public struct GestureConfiguration: Sendable {
    public var leftEdgeThreshold: Double
    public var topEdgeThreshold: Double
    public var dockCommitThreshold: Double
    public var voiceCommitThreshold: Double
    public var minSwipeVelocity: Double
    
    public static let `default` = GestureConfiguration(
        leftEdgeThreshold: 0.20,      // Leftmost finger within first 20% of trackpad X
        topEdgeThreshold: 0.90,       // Starts within top 10% of trackpad Y
        dockCommitThreshold: 0.18,    // 18% width swipe commits dock open/close
        voiceCommitThreshold: 0.52,   // 52% width swipe commits voice mode
        minSwipeVelocity: 0.15        // Minimum velocity required
    )
}

public final class GestureStateMachine: @unchecked Sendable {
    public private(set) var currentState: GestureDockState = .idle
    public var configuration: GestureConfiguration
    public var isDockOpen: Bool = false
    
    private var initialTouchX: Double = 0
    private var initialTouchY: Double = 0
    private var lastTouchX: Double = 0
    private var lastTouchY: Double = 0
    private var lastTimestamp: Double = 0
    private var isGestureActive = false
    /// Low-passed finger speed (trackpad widths per second). A single trackpad frame is noisy,
    /// especially the one where fingers lift, so the release decision uses this smoothed value.
    private var smoothedVelocityX: Double = 0
    private var smoothedVelocityY: Double = 0
    private var activeGestureType: GestureType = .none
    
    private enum GestureType {
        case none
        case leftToRightOpen
        case leftToRightClose
        case topToBottom
    }
    
    public var onStateChange: ((GestureDockState) -> Void)?
    
    public init(configuration: GestureConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func processTouches(
        fingerCount: Int,
        averageX: Double,
        averageY: Double,
        minX: Double? = nil,
        timestamp: Double
    ) {
        // Master Dock triggers specifically on two-finger gestures
        guard fingerCount == 2 else {
            if isGestureActive {
                finishGesture()
            }
            return
        }
        
        let effectiveLeftX = minX ?? averageX
        
        if !isGestureActive {
            // Touch began: check if starting at left edge
            if effectiveLeftX <= configuration.leftEdgeThreshold {
                isGestureActive = true
                if isDockOpen {
                    activeGestureType = .leftToRightClose
                } else {
                    activeGestureType = .leftToRightOpen
                }
                initialTouchX = averageX
                initialTouchY = averageY
                lastTouchX = averageX
                lastTouchY = averageY
                lastTimestamp = timestamp
                smoothedVelocityX = 0
                smoothedVelocityY = 0
                if !isDockOpen {
                    updateState(.trackingLeftSwipe(progress: 0.0, velocityX: 0.0))
                }
            } else if !isDockOpen && averageY >= configuration.topEdgeThreshold {
                isGestureActive = true
                activeGestureType = .topToBottom
                initialTouchX = averageX
                initialTouchY = averageY
                lastTouchX = averageX
                lastTouchY = averageY
                lastTimestamp = timestamp
                smoothedVelocityX = 0
                smoothedVelocityY = 0
                updateState(.trackingTopSwipe(progress: 0.0, velocityY: 0.0))
            }
            // If touch starts away from the left edge (e.g. effectiveLeftX > 0.20) while dock is open,
            // isGestureActive remains false, allowing completely free vertical scrolling!
            return
        }
        
        // Active gesture ongoing
        let dt = max(timestamp - lastTimestamp, 0.001)
        
        switch activeGestureType {
        case .leftToRightOpen:
            let deltaX = averageX - initialTouchX
            let currentVelocityX = (averageX - lastTouchX) / dt
            smoothedVelocityX = Self.smooth(smoothedVelocityX, toward: currentVelocityX, dt: dt)
            let progress = max(0.0, min(1.0, deltaX / 0.8))
            
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
            updateState(.trackingLeftSwipe(progress: progress, velocityX: smoothedVelocityX))
            
        case .leftToRightClose:
            // Tracking left-edge swipe while open to toggle close
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
        case .topToBottom:
            let deltaY = initialTouchY - averageY
            let currentVelocityY = (lastTouchY - averageY) / dt
            smoothedVelocityY = Self.smooth(smoothedVelocityY, toward: currentVelocityY, dt: dt)
            let progress = max(0.0, min(1.0, deltaY / 0.7))
            
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
            updateState(.trackingTopSwipe(progress: progress, velocityY: smoothedVelocityY))
            
        case .none:
            break
        }
    }
    
    public func finishGesture() {
        guard isGestureActive else { return }
        isGestureActive = false
        
        switch activeGestureType {
        case .leftToRightClose:
            // Swiping from left edge while dock is open immediately closes it!
            isDockOpen = false
            updateState(.dockDismissed)
            updateState(.idle)
            
        case .leftToRightOpen:
            if case .trackingLeftSwipe(let progress, let velocityX) = currentState {
                // Decide from where the swipe is GOING, not just where the fingers stopped
                // (Apple's momentum projection): a quick short flick opens the dock, and a swipe
                // pulled back toward the edge cancels even if it had travelled far.
                let projected = progress + Self.project(velocity: velocityX / 0.8)
                if progress >= configuration.voiceCommitThreshold && projected >= configuration.voiceCommitThreshold {
                    isDockOpen = true
                    updateState(.voiceModeActive)
                } else if projected >= configuration.dockCommitThreshold {
                    isDockOpen = true
                    updateState(.dockRevealed(mode: .standardDock))
                } else {
                    isDockOpen = false
                    updateState(.cancelled)
                    updateState(.idle)
                }
            } else {
                updateState(.idle)
            }
            
        case .topToBottom:
            if case .trackingTopSwipe(let progress, let velocityY) = currentState {
                let projected = progress + Self.project(velocity: velocityY / 0.7)
                if projected >= 0.15 {
                    isDockOpen = true
                    updateState(.voiceModeActive)
                } else {
                    isDockOpen = false
                    updateState(.cancelled)
                    updateState(.idle)
                }
            } else {
                updateState(.idle)
            }
            
        case .none:
            updateState(.idle)
        }
        
        activeGestureType = .none
    }
    
    public func resetToIdle() {
        isGestureActive = false
        isDockOpen = false
        activeGestureType = .none
        updateState(.idle)
    }
    
    public func triggerManual(mode: DockPresentationMode) {
        isDockOpen = true
        switch mode {
        case .standardDock:
            updateState(.dockRevealed(mode: .standardDock))
        case .expandedVoice:
            updateState(.voiceModeActive)
        }
    }
    
    /// Apple's projection from "Designing Fluid Interfaces": how far a motion with this release
    /// velocity would travel before coming to rest (same units as the velocity, per second).
    public static func project(velocity: Double, decelerationRate: Double = 0.998) -> Double {
        return (velocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }
    
    /// Frame-rate independent low-pass filter for the finger speed.
    static func smooth(_ current: Double, toward sample: Double, dt: Double) -> Double {
        let blend = 1.0 - exp(-dt / 0.035)
        return current + (sample - current) * blend
    }
    
    private func updateState(_ newState: GestureDockState) {
        currentState = newState
        onStateChange?(newState)
    }
}
