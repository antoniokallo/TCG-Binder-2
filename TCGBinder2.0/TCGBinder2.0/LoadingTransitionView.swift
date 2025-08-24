import SwiftUI

// FIX: Stable animation state - prevents clock resets
final class LoadingAnimationState: ObservableObject {
    @Published var logoScale: CGFloat = 0.3
    @Published var logoRotation: Double = 0
    @Published var logoOpacity: Double = 0
    @Published var titleOffset: CGFloat = 50
    @Published var titleOpacity: Double = 0
    @Published var progressValue: CGFloat = 0
    @Published var showParticles = false
    @Published var started = false
    
    // FIX: Clamp all values to ensure they're finite
    var safeLogoScale: CGFloat { logoScale.clampedFinite }
    var safeLogoRotation: Double { logoRotation.clampedFinite }
    var safeLogoOpacity: Double { logoOpacity.clampedFinite }
    var safeTitleOffset: CGFloat { titleOffset.clampedFinite }
    var safeTitleOpacity: Double { titleOpacity.clampedFinite }
    var safeProgressValue: CGFloat { max(0, min(1, progressValue.clampedFinite)) }
}

// FIX: Extension for finite value clamping
private extension CGFloat {
    var clampedFinite: CGFloat { isFinite ? self : 0 }
}

private extension Double {
    var clampedFinite: Double { isFinite ? self : 0 }
}

struct LoadingTransitionView: View {
    // FIX: Use stable @StateObject instead of @State to prevent clock resets
    @StateObject private var animState = LoadingAnimationState()
    
    // Completion handler to transition to main app
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Dynamic gradient background
            AnimatedGradientBackground()
                .ignoresSafeArea()
            
            // Particle effects
            // FIX: Use stable state for particle visibility
            if animState.showParticles {
                ParticleSystemView()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Main logo with bounce animation
                Image("tcg-binder-title")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    // FIX: Use safe values from stable state
                    .scaleEffect(animState.safeLogoScale)
                    .rotationEffect(.degrees(animState.safeLogoRotation))
                    .opacity(animState.safeLogoOpacity)
                
                // Welcome text with slide-up animation
                VStack(spacing: 16) {
                    Text("Welcome Back!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        // FIX: Use safe values from stable state
                        .offset(y: animState.safeTitleOffset)
                        .opacity(animState.safeTitleOpacity)
                    
                    Text("Loading your TCG collection...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .offset(y: animState.safeTitleOffset)
                        .opacity(animState.safeTitleOpacity)
                }
                
                // Animated progress bar
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.cyan, .purple, .pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            // FIX: Use safe clamped progress value
                            .frame(width: animState.safeProgressValue * 300, height: 8)
                            // FIX: Single animation source, no competing animations
                            .animation(.easeInOut(duration: 0.3), value: animState.safeProgressValue)
                    }
                    .frame(width: 300)
                    
                    Text("\(Int(animState.safeProgressValue * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }
                // FIX: Use safe value from stable state
                .opacity(animState.safeTitleOpacity)
                
                Spacer()
            }
        }
        .onAppear {
            // FIX: Guard against multiple animation starts using stable state
            guard !animState.started else { return }
            animState.started = true
            startLoadingSequence()
        }
    }
    
    // FIX: Controlled animation sequence - no overlapping animations
    private func startLoadingSequence() {
        // Step 1: Logo entrance
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            animState.logoScale = 1.2
            animState.logoOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard animState.started else { return }
            
            // Step 2: Logo settle and start controlled rotation loop
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animState.logoScale = 1.0
            }
            
            // FIX: Start controlled rotation loop (not .repeatForever)
            startRotationLoop()
            
            // Step 3: Title animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard animState.started else { return }
                
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    animState.titleOffset = 0
                    animState.titleOpacity = 1.0
                }
                
                // Step 4: Show particles and start progress
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard animState.started else { return }
                    
                    animState.showParticles = true
                    startProgressSequence()
                }
            }
        }
    }
    
    // FIX: Controlled rotation loop - prevents timeline conflicts
    private func startRotationLoop() {
        guard animState.started else { return }
        
        withAnimation(.easeInOut(duration: 2.0)) {
            animState.logoRotation = 5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard animState.started else { return }
            
            // FIX: Reset without animation to prevent backwards time jump
            withTransaction(Transaction(animation: nil)) {
                animState.logoRotation = -5
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                guard animState.started else { return }
                
                withAnimation(.easeInOut(duration: 2.0)) {
                    animState.logoRotation = 5
                }
                
                // Continue loop
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    startRotationLoop()
                }
            }
        }
    }
    
    // FIX: Sequential progress animation - no overlapping updates
    private func startProgressSequence() {
        guard animState.started else { return }
        
        // Animate to 30%
        withAnimation(.easeInOut(duration: 0.4)) {
            animState.progressValue = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard animState.started else { return }
            
            // Animate to 60%
            withAnimation(.easeInOut(duration: 0.4)) {
                animState.progressValue = 0.6
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard animState.started else { return }
                
                // Animate to 85%
                withAnimation(.easeInOut(duration: 0.4)) {
                    animState.progressValue = 0.85
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard animState.started else { return }
                    
                    // Final push to 100%
                    withAnimation(.easeInOut(duration: 0.4)) {
                        animState.progressValue = 1.0
                    }
                    
                    // Complete after final animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard animState.started else { return }
                        completeLoading()
                    }
                }
            }
        }
    }
    
    private func completeLoading() {
        // FIX: Stop all animations cleanly
        animState.started = false
        
        // Final bounce effect
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            animState.logoScale = 1.1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                animState.logoScale = 0.3
                animState.logoOpacity = 0
                animState.titleOpacity = 0
            }
            
            // Transition to main app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onComplete()
            }
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    // FIX: Add guard to prevent multiple animation starts
    @State private var gradientAnimationStarted = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: animateGradient ? 
                [.purple, .blue, .cyan, .pink] : 
                [.blue, .purple, .pink, .cyan]
            ),
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            // FIX: Guard against multiple gradient animation starts
            guard !gradientAnimationStarted else { return }
            gradientAnimationStarted = true
            
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Particle System
struct ParticleSystemView: View {
    @State private var particles: [Particle] = []
    // FIX: Add guards and timer management to prevent conflicts
    @State private var particleAnimationStarted = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            // FIX: Guard against multiple particle animation starts
            guard !particleAnimationStarted else { return }
            particleAnimationStarted = true
            
            createParticles()
            startParticleAnimation()
        }
        .onDisappear {
            // FIX: Clean up timer to prevent memory leaks and conflicts
            animationTimer?.invalidate()
            animationTimer = nil
            particleAnimationStarted = false
        }
    }
    
    private func createParticles() {
        let colors: [Color] = [.cyan, .purple, .pink, .yellow, .green]
        
        for _ in 0..<20 {
            let particle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                color: colors.randomElement() ?? .cyan,
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.3...0.8),
                scale: CGFloat.random(in: 0.5...1.5)
            )
            particles.append(particle)
        }
    }
    
    private func startParticleAnimation() {
        // FIX: Replace Timer with consolidated animation to prevent timeline conflicts
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            // FIX: Check if animation should continue
            guard particleAnimationStarted else {
                timer.invalidate()
                return
            }
            
            // FIX: Use consistent animation duration to prevent timeline conflicts
            withAnimation(.easeInOut(duration: 2.0)) {
                for index in particles.indices {
                    // FIX: Validate bounds and ensure finite values
                    let screenBounds = UIScreen.main.bounds
                    guard screenBounds.width.isFinite && screenBounds.height.isFinite else { continue }
                    
                    particles[index].position = CGPoint(
                        x: CGFloat.random(in: 0...screenBounds.width),
                        y: CGFloat.random(in: 0...screenBounds.height)
                    )
                    
                    // FIX: Clamp opacity and scale values to ensure they're finite
                    let opacity = Double.random(in: 0.1...0.9)
                    let scale = CGFloat.random(in: 0.3...1.8)
                    
                    guard opacity.isFinite && scale.isFinite else { continue }
                    
                    particles[index].opacity = opacity
                    particles[index].scale = scale
                }
            }
        }
    }
}

// MARK: - Particle Model
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    var scale: CGFloat
}

#Preview {
    LoadingTransitionView {
        print("Loading complete!")
    }
}