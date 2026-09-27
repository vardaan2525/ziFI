import SwiftUI

public struct StorageGaugeView: View {
    @ObservedObject var storage: StorageManager
    var onCleanNow: (() -> Void)?

    public init(storage: StorageManager, onCleanNow: (() -> Void)? = nil) {
        self.storage = storage
        self.onCleanNow = onCleanNow
    }

    private var isHighUsage: Bool { storage.deviceStorage.usedPercentage > 0.85 }
    private var gaugeColor: Color { isHighUsage ? AppTheme.destructive : AppTheme.accent }

    public var body: some View {
        ZStack {
            // Background track (vibrant yellow = remaining/free)
            Circle()
                .stroke(Color(hex: "FFD60A"), lineWidth: 14)
                .frame(width: 190, height: 190)

            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, storage.deviceStorage.usedPercentage))))
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 190, height: 190)
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: storage.deviceStorage.usedPercentage)

            // Inner disc
            Circle()
                .fill(AppTheme.cardBackground)
                .frame(width: 155, height: 155)

            // Center content
            if storage.isScanning {
                VStack(spacing: 4) {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.1)
                    Text("\(Int(storage.scanProgress * 100))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Scanning…")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                }
            } else {
                VStack(spacing: 4) {
                    Text("\(Int(storage.deviceStorage.usedPercentage * 100))%")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: storage.deviceStorage.usedPercentage)

                    Text("USED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(AppTheme.textMuted)

                    Text("\(storage.deviceStorage.formattedFree) free")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 1)

                    // Clean Now button inside the circle
                    Button(action: {
                        HapticManager.impact(style: .medium)
                        onCleanNow?()
                    }) {
                        Text("Clean Now")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(gaugeColor)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
