import SwiftUI
import UIKit
import Photos

// MARK: - App Design System (Flat 2D, Adaptive Light/Dark)
public struct AppTheme {
    // Adaptive backgrounds (via UIColor for true light/dark adaptation)
    public static let appBackground      = Color(UIColor.systemGroupedBackground)
    public static let cardBackground     = Color(UIColor.secondarySystemGroupedBackground)
    public static let cardSecondary      = Color(UIColor.tertiarySystemGroupedBackground)

    // Text
    public static let textPrimary        = Color(UIColor.label)
    public static let textSecondary      = Color(UIColor.secondaryLabel)
    public static let textMuted          = Color(UIColor.tertiaryLabel)

    // Accents
    public static let accent             = Color(UIColor.systemBlue)
    public static let destructive        = Color(UIColor.systemRed)
    public static let success            = Color(UIColor.systemGreen)
    public static let separator          = Color(UIColor.separator)

    // Stitch / Apple System Palette
    public static let applePhotosGreen   = Color(hex: "34C759")
    public static let appleVideoOrange   = Color(hex: "FF9500")
    public static let appleMessagesPurple = Color(hex: "AF52DE")
    public static let appleSystemGray    = Color(hex: "8E8E93")
    public static let appleVibrantYellow = Color(hex: "FFD60A")
    public static let appleBlue          = Color(hex: "007AFF")
    public static let subBackground      = Color(UIColor.tertiarySystemGroupedBackground)

    // Legacy aliases kept so other files compile unchanged
    public static let cyanAccent         = Color(UIColor.systemBlue)
    public static let indigoAccent       = Color(UIColor.systemBlue)
    public static let purpleAccent       = Color(UIColor.systemBlue)
    public static let amberAccent        = Color(UIColor.systemOrange)
    public static let roseAccent         = Color(UIColor.systemRed)
    public static let emeraldAccent      = Color(UIColor.systemGreen)

    // Kept for compile compat — no longer used in new UI
    public static let primaryGradient = LinearGradient(
        colors: [Color(UIColor.systemBlue)],
        startPoint: .leading, endPoint: .trailing
    )
    public static let storageCyanGradient = LinearGradient(
        colors: [Color(UIColor.systemBlue)],
        startPoint: .leading, endPoint: .trailing
    )
    public static let storageWarningGradient = LinearGradient(
        colors: [Color(UIColor.systemRed)],
        startPoint: .leading, endPoint: .trailing
    )
    public static let successGradient = LinearGradient(
        colors: [Color(UIColor.systemGreen)],
        startPoint: .leading, endPoint: .trailing
    )

    public static func color(for category: CleanCategory) -> Color {
        return accent
    }
}

// MARK: - Color Hex Initializer
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback Manager
public struct HapticManager {
    public static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - Flat Card (replaces GlassCard / LiquidGlassCard)
public struct FlatCardModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separator, lineWidth: 0.5)
            )
    }
}

// Legacy modifiers redirect to FlatCardModifier
public typealias MinimalCardModifier = FlatCardModifier
public typealias AppleLiquidGlassModifier = FlatCardModifier

extension View {
    public func minimalCard(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(FlatCardModifier(cornerRadius: cornerRadius))
    }

    public func liquidGlass(cornerRadius: CGFloat = 16, tintOpacity: Double = 0.55) -> some View {
        self.modifier(FlatCardModifier(cornerRadius: cornerRadius))
    }
}

public struct GlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let content: Content

    public init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content.minimalCard(cornerRadius: cornerRadius)
    }
}

public struct LiquidGlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let content: Content

    public init(cornerRadius: CGFloat = 16, tintOpacity: Double = 0.55, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content.minimalCard(cornerRadius: cornerRadius)
    }
}

// MARK: - Scale Button Style
public struct ScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - Clean Action Button (legacy compat)
public struct CleanActionButton: View {
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let gradient: LinearGradient
    public let isDestructive: Bool
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String = "trash.fill",
        gradient: LinearGradient = AppTheme.primaryGradient,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.gradient = gradient
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            HapticManager.impact(style: isDestructive ? .heavy : .medium)
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .opacity(0.75)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.4)
            }
            .foregroundColor(isDestructive ? AppTheme.destructive : AppTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - In-Memory Image Cache
private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 300 * 1024 * 1024
        cache.countLimit = 800
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - High-Performance Real Photo Thumbnail
public struct AssetThumbnailView: View {
    public let assetIdentifier: String?
    public let colorIndex: Int
    public let title: String?
    public let size: CGSize
    public let isBest: Bool
    public let contentMode: ContentMode

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = false

    public init(
        assetIdentifier: String? = nil,
        colorIndex: Int = 0,
        title: String? = nil,
        size: CGSize = CGSize(width: 100, height: 100),
        isBest: Bool = false,
        contentMode: ContentMode = .fill
    ) {
        self.assetIdentifier = assetIdentifier
        self.colorIndex = colorIndex
        self.title = title
        self.size = size
        self.isBest = isBest
        self.contentMode = contentMode
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                placeholderView
            }

            if isBest {
                VStack {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 8))
                            Text("BEST")
                                .font(.system(size: 9, weight: .black))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.accent))
                        Spacer()
                    }
                    .padding(5)
                    Spacer()
                }
            }

            if let title = title, loadedImage == nil {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .padding(4)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: assetIdentifier) { _, _ in loadImage() }
    }

    private var placeholderView: some View {
        ZStack {
            Color(UIColor.secondarySystemGroupedBackground)
            if isLoading {
                ProgressView()
                    .tint(AppTheme.textMuted)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: min(size.width, size.height) * 0.25))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }

    private func loadImage() {
        guard let identifier = assetIdentifier, !identifier.isEmpty else { return }

        let targetPixelWidth = max(40, Int(size.width * UIScreen.main.scale))
        let targetPixelHeight = max(40, Int(size.height * UIScreen.main.scale))
        let cacheKey = "\(identifier)_\(targetPixelWidth)x\(targetPixelHeight)"

        if let cached = ThumbnailCache.shared.image(forKey: cacheKey) {
            self.loadedImage = cached
            return
        }

        if identifier.hasPrefix("vault:") {
            let filename = String(identifier.dropFirst("vault:".count))
            if let image = VaultManager.loadVaultImage(filename: filename) {
                let cost = Int(image.size.width * image.size.height * 4)
                ThumbnailCache.shared.setImage(image, forKey: cacheKey, cost: cost)
                self.loadedImage = image
            }
            return
        }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return }

        isLoading = true
        let targetSize = CGSize(width: targetPixelWidth, height: targetPixelHeight)

        DispatchQueue.global(qos: .userInteractive).async {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = assets.firstObject else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.isSynchronous = false

            PHCachingImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let image = image {
                        self.loadedImage = image
                        if !isDegraded {
                            let cost = Int(image.size.width * image.size.height * 4)
                            ThumbnailCache.shared.setImage(image, forKey: cacheKey, cost: cost)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail View
public struct MockThumbnailView: View {
    public let assetIdentifier: String?
    public let colorIndex: Int
    public let title: String?
    public let size: CGSize
    public let isBest: Bool

    public init(
        assetIdentifier: String? = nil,
        colorIndex: Int = 0,
        title: String? = nil,
        size: CGSize = CGSize(width: 100, height: 100),
        isBest: Bool = false
    ) {
        self.assetIdentifier = assetIdentifier
        self.colorIndex = colorIndex
        self.title = title
        self.size = size
        self.isBest = isBest
    }

    public var body: some View {
        AssetThumbnailView(
            assetIdentifier: assetIdentifier,
            colorIndex: colorIndex,
            title: title,
            size: size,
            isBest: isBest
        )
    }
}

// MARK: - Security & Privacy Guarantees
public enum SecurityGuarantees {
    public static let isOnDeviceOnly: Bool = true
    public static let doesCollectTelemetry: Bool = false
    public static let requiresSystemConfirmationForDeletion: Bool = true
    public static let isTrashRecoverableFor30Days: Bool = true
}
