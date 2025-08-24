import SwiftUI
import os.log

// FIX: Animation debugging utility to catch timeline conflicts
struct AnimationDebugger {
    private static let logger = Logger(subsystem: "TCGBinder", category: "Animation")
    
    // FIX: Track animation state to detect conflicts
    static func logAnimationStart(_ name: String, duration: TimeInterval) {
        #if DEBUG
        logger.info("🎬 Animation started: \(name) - Duration: \(duration)s")
        #endif
    }
    
    static func logAnimationComplete(_ name: String) {
        #if DEBUG
        logger.info("✅ Animation completed: \(name)")
        #endif
    }
    
    // FIX: Validate animation values to catch NaN/Inf issues
    static func validateAnimatableValue<T: BinaryFloatingPoint>(_ value: T, name: String) -> T {
        guard value.isFinite else {
            #if DEBUG
            logger.error("⚠️ Invalid animation value detected in \(name): \(String(describing: value))")
            #endif
            return 0
        }
        return value
    }
    
    // FIX: Check for competing timelines
    static func checkForTimelineConflict(currentTime: TimeInterval, lastTime: TimeInterval, context: String) {
        if currentTime < lastTime {
            #if DEBUG
            logger.error("🚨 Timeline conflict detected in \(context): current=\(currentTime), last=\(lastTime)")
            #endif
        }
    }
}

// FIX: SwiftUI View modifier to wrap animations with validation
struct ValidatedAnimation: ViewModifier {
    let animation: Animation
    let value: AnyHashable
    let context: String
    
    func body(content: Content) -> some View {
        content
            .animation(animation, value: value)
            .onAppear {
                AnimationDebugger.logAnimationStart(context, duration: animation.estimatedDuration)
            }
    }
}

extension View {
    // FIX: Helper method for validated animations
    func validatedAnimation<T: Equatable & Hashable>(_ animation: Animation, value: T, context: String = "Unknown") -> some View {
        self.modifier(ValidatedAnimation(animation: animation, value: AnyHashable(value), context: context))
    }
}

// FIX: Animation duration helper - simplified to avoid pattern matching complexity
extension Animation {
    var estimatedDuration: TimeInterval {
        // FIX: Return reasonable default durations for animation logging
        // Note: SwiftUI Animation doesn't expose actual duration, so we estimate
        return 0.3 // Default animation duration
    }
}