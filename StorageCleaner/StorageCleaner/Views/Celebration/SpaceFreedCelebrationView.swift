import SwiftUI

public struct SpaceFreedCelebrationView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var appearScale: CGFloat = 0.6
    @State private var appearOpacity: Double = 0.0
    @State private var animateParticles: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()
            
            // Celebration confetti particles effect
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(particleColor(for: i))
                    .frame(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 6...12))
                    .offset(
                        x: animateParticles ? CGFloat.random(in: -160...160) : 0,
                        y: animateParticles ? CGFloat.random(in: -300...300) : 0
                    )
                    .opacity(animateParticles ? 0.8 : 0)
                    .animation(
                        .spring(response: 1.2, dampingFraction: 0.7).delay(Double(i) * 0.03),
                        value: animateParticles
                    )
            }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Trophy badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundColor(.white)
                }
                .scaleEffect(appearScale)
                
                VStack(spacing: 8) {
                    Text("STORAGE FREED!")
                        .font(.system(size: 13, weight: .black))
                        .tracking(3)
                        .foregroundColor(.green)
                    
                    Text(ByteCountFormatter.string(fromByteCount: storage.lastFreedAmount, countStyle: .file))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Successfully reclaimed storage on your iPhone")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .opacity(appearOpacity)
                
                // Device Impact Card
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("New Free Storage")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text(storage.deviceStorage.formattedFree)
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total Saved Lifetime")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textMuted)
                                Text(ByteCountFormatter.string(fromByteCount: storage.totalSpaceFreedEver, countStyle: .file))
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    .padding(20)
                }
                .padding(.horizontal, 24)
                .opacity(appearOpacity)
                
                Spacer()
                
                // Done CTA Button
                Button(action: {
                    HapticManager.impact(style: .medium)
                    dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearScale = 1.0
                appearOpacity = 1.0
                animateParticles = true
            }
        }
    }
    
    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [.cyan, .green, .yellow, .pink, .purple, .blue]
        return colors[index % colors.count]
    }
}
