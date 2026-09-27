import SwiftUI
import UIKit
import Photos

// MARK: - Dashboard View (Stitch Apple Storage Design, Elevated)
public struct DashboardView: View {
    @ObservedObject var storage = StorageManager.shared
    @AppStorage("zifi_color_scheme") private var colorSchemePreference: String = "system"

    public enum DashboardSheet: Identifiable {
        case review, celebration, swipeCleaner, secretVault, calendar, contacts, settings

        public var id: Int {
            switch self {
            case .review:       return 1
            case .celebration:  return 2
            case .swipeCleaner: return 3
            case .secretVault:  return 4
            case .calendar:     return 5
            case .contacts:     return 6
            case .settings:     return 7
            }
        }
    }

    public var hideSettingsButton: Bool = false
    @State private var activeCategory: CleanCategory?
    @State private var activeSheet: DashboardSheet?

    public init(hideSettingsButton: Bool = false) {
        self.hideSettingsButton = hideSettingsButton
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Top App Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    // Hero Storage Capacity Card
                    heroCapacityCard
                        .padding(.horizontal, 16)

                    // Cleaned by ziFI
                    cleanedByZifiCard
                        .padding(.horizontal, 16)

                    // Clean Recommendations (Grouped Card)
                    cleanRecommendationsSection
                        .padding(.horizontal, 16)

                    // Quick Tools (2-Column Grid)
                    quickToolsSection
                        .padding(.horizontal, 16)

                    Spacer(minLength: 24)
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $activeSheet, onDismiss: {
                if storage.showCelebration { storage.showCelebration = false }
            }) { sheet in
                switch sheet {
                case .review:       ReviewBeforeDeleteView(isPresentedAsSheet: true)
                case .celebration:  SpaceFreedCelebrationView()
                case .swipeCleaner: NavigationStack { SwipeCleanerView(isPresentedAsSheet: true) }
                case .secretVault:  SecretVaultView()
                case .calendar:     NavigationStack { CalendarCleanerView() }
                case .contacts:     ContactsCleanerView()
                case .settings:     SettingsView()
                }
            }
            .navigationDestination(item: $activeCategory) { category in
                destinationView(for: category)
            }
            .onAppear {
                storage.refreshDeviceStorage()
                storage.checkPermissions()
                let authorized = storage.photoAuthStatus == .authorized || storage.photoAuthStatus == .limited
                if authorized && !storage.isScanning {
                    if storage.screenshots.isEmpty && storage.similarGroups.isEmpty && storage.largeVideos.isEmpty {
                        storage.performFullScan()
                    } else {
                        Task { await PhotoScannerManager.shared.scanLivePhotos() }
                    }
                } else if storage.photoAuthStatus == .notDetermined && !storage.isScanning {
                    storage.performFullScan()
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            Text("ziFI")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .tracking(-0.4)

            Spacer()

            HStack(spacing: 8) {
                if !hideSettingsButton {
                    Button(action: {
                        HapticManager.impact(style: .light)
                        activeSheet = .settings
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.cardSecondary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Hero Capacity Card (Stitch Component, Elevated)
    private var heroCapacityCard: some View {
        VStack(spacing: 16) {
            // Top Row: Device model & Free space badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(DeviceModelHelper.currentModelName.uppercased()) • \(storage.deviceStorage.formattedTotal)")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(usedGBFormatted)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .tracking(-0.5)
                        Text("GB Used")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                // Free space pill badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.appleVibrantYellow)
                        .frame(width: 7, height: 7)
                    Text("\(storage.deviceStorage.formattedFree) Free")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.cardSecondary)
                .clipShape(Capsule())
            }

            // Minimalist Segmented Storage Bar
            segmentedStorageBar

            // Clean 4-Column Legend Row
            legendRow
                .padding(.bottom, 4)

            Divider()
                .opacity(0.6)

            // Primary Action Button: "Smart Cleanup"
            Button(action: {
                HapticManager.impact(style: .medium)
                activeSheet = .review
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Smart Cleanup")
                            .font(.system(size: 15, weight: .bold))
                    }

                    Spacer()

                    Text("\(storage.formattedRecoverableSpace) Reclaimable")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.22))
                        .clipShape(Capsule())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accent)
                        .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - Apple Storage Bar (Used Space, Reclaimable Storage, Free Space)
    private var segmentedStorageBar: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalSpace = max(1.0, Double(storage.deviceStorage.totalSpace))
            let usedSpace = Double(storage.deviceStorage.usedSpace)
            
            // Reclaimable storage detected by ziFI
            let reclaimableBytes = Double(storage.totalRecoverableBytes > 0 ? storage.totalRecoverableBytes : storage.potentialTotalSavingsBytes)
            let actualReclaimable = min(usedSpace * 0.75, reclaimableBytes)
            let permanentUsed = max(0.0, usedSpace - actualReclaimable)
            
            let hasReclaimable = actualReclaimable > 0
            let spacingTotal: CGFloat = hasReclaimable ? 4 : 2
            let contentWidth = max(0, totalWidth - spacingTotal)
            
            let permanentFraction = CGFloat(permanentUsed / totalSpace)
            let reclaimableFraction = CGFloat(actualReclaimable / totalSpace)
            
            let minSegmentWidth: CGFloat = 8
            let usedWidth = max(minSegmentWidth, contentWidth * permanentFraction)
            let reclaimableWidth = hasReclaimable ? max(minSegmentWidth, contentWidth * reclaimableFraction) : 0
            let freeWidth = max(minSegmentWidth, contentWidth - usedWidth - reclaimableWidth)

            HStack(spacing: 2) {
                // Permanent Used Storage: Apple System Blue
                Capsule()
                    .fill(storage.deviceStorage.usedPercentage > 0.85 ? Color(hex: "FF3B30") : AppTheme.appleBlue)
                    .frame(width: usedWidth)

                // Reclaimable Storage: Apple Messages Purple (Distinct color matching the legend)
                if hasReclaimable {
                    Capsule()
                        .fill(AppTheme.appleMessagesPurple)
                        .frame(width: reclaimableWidth)
                }

                // Free Storage: Vibrant Apple Yellow
                Capsule()
                    .fill(AppTheme.appleVibrantYellow)
                    .frame(width: freeWidth)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: storage.deviceStorage.usedPercentage)
        }
        .frame(height: 12)
        .padding(2)
        .background(AppTheme.cardSecondary)
        .clipShape(Capsule())
    }

    // MARK: - Legend Row (Accurate Real Storage Metrics)
    private var legendRow: some View {
        HStack(spacing: 0) {
            legendItem(
                color: AppTheme.appleBlue,
                title: "Used Space",
                size: storage.deviceStorage.formattedUsed
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            legendItem(
                color: AppTheme.appleVibrantYellow,
                title: "Free Space",
                size: storage.deviceStorage.formattedFree
            )
            .frame(maxWidth: .infinity, alignment: .center)

            legendItem(
                color: AppTheme.appleMessagesPurple,
                title: "Reclaimable",
                size: storage.formattedRecoverableSpace
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func legendItem(color: Color, title: String, size: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                Text(size)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }

    // MARK: - Cleaned by ziFI Card
    private var cleanedByZifiCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "30D158"), Color(hex: "0A84FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Cleaned by ziFI")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("LIFETIME")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(storage.totalSpaceFreedEver > 0
                     ? "\(ByteCountFormatter.string(fromByteCount: storage.totalSpaceFreedEver, countStyle: .file)) reclaimed on this device"
                     : "Ready to recover space on this device")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            if storage.totalSpaceFreedEver > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(ByteCountFormatter.string(fromByteCount: storage.totalSpaceFreedEver, countStyle: .file))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                    Text("freed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green.opacity(0.8))
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Clean Recommendations
    private var cleanRecommendationsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("CLEAN RECOMMENDATIONS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Text("4 categories")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Recommendation 1: Duplicate & Similar Photos
                recommendationRow(
                    icon: "square.on.square.fill",
                    iconColor: AppTheme.applePhotosGreen,
                    title: "Duplicate Photos & Bursts",
                    subtitle: "\(storage.similarGroups.count) groups ready for review",
                    size: categorySizeText(for: .similarPhotos),
                    action: { activeCategory = .similarPhotos }
                )

                Divider().padding(.leading, 64)

                // Recommendation 2: Large Videos
                recommendationRow(
                    icon: "play.rectangle.fill",
                    iconColor: AppTheme.appleVideoOrange,
                    title: "Large Video Files",
                    subtitle: "\(storage.largeVideos.count) videos larger than 100 MB",
                    size: categorySizeText(for: .largeVideos),
                    action: { activeCategory = .largeVideos }
                )

                Divider().padding(.leading, 64)

                // Recommendation 3: Blurry Photos
                recommendationRow(
                    icon: "camera.metering.center.weighted",
                    iconColor: AppTheme.appleMessagesPurple,
                    title: "Blurry & Poor Focus",
                    subtitle: "\(storage.blurryPhotos.count) low quality shots found",
                    size: categorySizeText(for: .blurryPhotos),
                    action: { activeCategory = .blurryPhotos }
                )

                Divider().padding(.leading, 64)

                // Recommendation 4: Screenshots
                recommendationRow(
                    icon: "camera.viewfinder",
                    iconColor: AppTheme.appleBlue,
                    title: "Screenshots & Receipts",
                    subtitle: "\(storage.screenshots.count) screen captures",
                    size: categorySizeText(for: .screenshots),
                    action: { activeCategory = .screenshots }
                )
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.separator.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        }
    }

    private func recommendationRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        size: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            HStack(spacing: 14) {
                // Colored icon container with 15% opacity background
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(size)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Quick Tools (2-Column Grid)
    private var quickToolsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("QUICK TOOLS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.9)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                quickToolCard(
                    icon: "hand.draw.fill",
                    iconColor: AppTheme.appleBlue,
                    title: "Swipe Clean",
                    subtitle: "Photo sorter"
                ) { activeSheet = .swipeCleaner }

                quickToolCard(
                    icon: "arrow.down.right.and.arrow.up.left",
                    iconColor: AppTheme.appleVideoOrange,
                    title: "Compressor",
                    subtitle: "Shrink video files"
                ) { activeCategory = .largeVideos }

                quickToolCard(
                    icon: "calendar.badge.minus",
                    iconColor: AppTheme.appleMessagesPurple,
                    title: "Calendar",
                    subtitle: "Clean past events"
                ) { activeSheet = .calendar }

                quickToolCard(
                    icon: "lock.shield.fill",
                    iconColor: AppTheme.applePhotosGreen,
                    title: "Secret Vault",
                    subtitle: "Face ID protected"
                ) { activeSheet = .secretVault }

                quickToolCard(
                    icon: "person.2.fill",
                    iconColor: AppTheme.appleBlue,
                    title: "Contacts",
                    subtitle: "Merge duplicates"
                ) { activeSheet = .contacts }

                quickToolCard(
                    icon: "camera.filters",
                    iconColor: AppTheme.applePhotosGreen,
                    title: "Blurry Photos",
                    subtitle: "Clear blurry shots"
                ) { activeCategory = .blurryPhotos }
            }
        }
    }

    private func quickToolCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.separator.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Formatters & Computed Helpers
    private var usedGBFormatted: String {
        let gb = Double(storage.deviceStorage.usedSpace) / 1_000_000_000.0
        return String(format: "%.1f", gb)
    }

    private var photosCategorySize: String {
        let bytes = storage.categoryTotalSize(for: .similarPhotos) + storage.categoryTotalSize(for: .screenshots)
        if bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return storage.isScanning ? "Scanning…" : "0 MB"
    }

    private var videosCategorySize: String {
        let bytes = storage.categoryTotalSize(for: .largeVideos)
        if bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return storage.isScanning ? "Scanning…" : "0 MB"
    }

    private var otherCategorySize: String {
        let bytes = storage.categoryTotalSize(for: .blurryPhotos)
        if bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return storage.isScanning ? "Scanning…" : "0 MB"
    }

    private func categorySizeText(for category: CleanCategory) -> String {
        let bytes = storage.categoryTotalSize(for: category)
        if bytes > 0 {
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return storage.isScanning ? "Scanning…" : "0 MB"
    }

    @ViewBuilder
    private func destinationView(for category: CleanCategory) -> some View {
        switch category {
        case .similarPhotos:  SimilarPhotosView()
        case .screenshots:    ScreenshotsCleanerView()
        case .largeVideos:    LargeVideosView()
        case .blurryPhotos:   BlurryPhotosView()
        }
    }
}

// MARK: - Root App Shell with Native Apple Tab Bar
public struct RootView: View {
    @ObservedObject var storage = StorageManager.shared
    @AppStorage("zifi_color_scheme") private var colorSchemePreference: String = "system"
    @State private var selectedTab: Tab = .storage

    public enum Tab: Int, CaseIterable {
        case storage = 0
        case clean = 1
        case swipe = 2
        case tools = 3

        var label: String {
            switch self {
            case .storage: return "Storage"
            case .clean:   return "Clean"
            case .swipe:   return "Swipe"
            case .tools:   return "Tools"
            }
        }

        var icon: String {
            switch self {
            case .storage: return "internaldrive.fill"
            case .clean:   return "sparkles"
            case .swipe:   return "hand.draw.fill"
            case .tools:   return "slider.horizontal.3"
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(hideSettingsButton: false)
                .tabItem {
                    Label(Tab.storage.label, systemImage: Tab.storage.icon)
                }
                .tag(Tab.storage)

            ReviewBeforeDeleteView(isPresentedAsSheet: false)
                .tabItem {
                    Label(Tab.clean.label, systemImage: Tab.clean.icon)
                }
                .tag(Tab.clean)

            SwipeCleanerView(isPresentedAsSheet: false)
                .tabItem {
                    Label(Tab.swipe.label, systemImage: Tab.swipe.icon)
                }
                .tag(Tab.swipe)

            ToolsView()
                .tabItem {
                    Label(Tab.tools.label, systemImage: Tab.tools.icon)
                }
                .tag(Tab.tools)
        }
        .tint(AppTheme.appleBlue)
        .preferredColorScheme(preferredColorScheme)
    }
}

// MARK: - Tools Hub View
public struct ToolsView: View {
    @ObservedObject var storage = StorageManager.shared
    @State private var activeSheet: ToolSheet?
    @State private var activeCategory: CleanCategory?

    public enum ToolSheet: Identifiable {
        case calendar, contacts, secretVault, swipe
        public var id: Int {
            switch self {
            case .calendar:    return 1
            case .contacts:    return 2
            case .secretVault: return 3
            case .swipe:       return 4
            }
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header label
                    HStack {
                        Text("UTILITIES")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.9)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // 2-Column Grid of Tools
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        toolCard(icon: "hand.draw.fill", iconColor: AppTheme.appleBlue, title: "Swipe Clean", count: "Photo sorter") {
                            activeSheet = .swipe
                        }
                        toolCard(icon: "arrow.down.right.and.arrow.up.left", iconColor: AppTheme.appleVideoOrange, title: "Video Compressor", count: "Shrink files") {
                            activeCategory = .largeVideos
                        }
                        toolCard(icon: "calendar.badge.minus", iconColor: AppTheme.appleMessagesPurple, title: "Calendar Cleaner", count: "Remove past") {
                            activeSheet = .calendar
                        }
                        toolCard(icon: "lock.shield.fill", iconColor: AppTheme.applePhotosGreen, title: "Secret Vault", count: "Face ID safe") {
                            activeSheet = .secretVault
                        }
                        toolCard(icon: "person.2.fill", iconColor: AppTheme.appleBlue, title: "Contacts Cleaner", count: "Merge dupes") {
                            activeSheet = .contacts
                        }
                        toolCard(icon: "camera.filters", iconColor: AppTheme.applePhotosGreen, title: "Blurry Photos", count: "Clear blurry") {
                            activeCategory = .blurryPhotos
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 24)
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .swipe:       NavigationStack { SwipeCleanerView(isPresentedAsSheet: true) }
                case .calendar:    NavigationStack { CalendarCleanerView() }
                case .contacts:    ContactsCleanerView()
                case .secretVault: SecretVaultView()
                }
            }
            .navigationDestination(item: $activeCategory) { category in
                destinationView(for: category)
            }
        }
    }

    private func toolCard(icon: String, iconColor: Color, title: String, count: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(count)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(14)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.separator.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func destinationView(for category: CleanCategory) -> some View {
        switch category {
        case .similarPhotos:  SimilarPhotosView()
        case .screenshots:    ScreenshotsCleanerView()
        case .largeVideos:    LargeVideosView()
        case .blurryPhotos:   BlurryPhotosView()
        }
    }
}
