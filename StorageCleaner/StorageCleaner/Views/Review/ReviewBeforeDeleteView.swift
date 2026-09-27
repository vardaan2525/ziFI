import SwiftUI

public struct ReviewBeforeDeleteView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    public var isPresentedAsSheet: Bool = true
    
    @State private var selectedFilter: ReviewFilter = .all
    @State private var isCleaningInProgress = false
    @State private var cleaningStepText = "Preparing..."
    @State private var cleaningProgress: Double = 0.0
    @State private var showConfirmAlert = false
    @State private var cachedItems: [ReviewItem] = []
    
    public init(isPresentedAsSheet: Bool = true) {
        self.isPresentedAsSheet = isPresentedAsSheet
    }
    
    public enum ReviewFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case screenshots = "Screenshots"
        case duplicates = "Duplicates"
        case blurry = "Blurry"
        case videos = "Videos"
        
        public var id: String { rawValue }
        
        public var iconName: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .screenshots: return "iphone"
            case .duplicates: return "photo.on.rectangle.angled"
            case .blurry: return "camera.metering.matrix"
            case .videos: return "video.fill"
            }
        }
    }
    
    public struct ReviewItem: Identifiable, Equatable {
        public let id: String
        public let assetIdentifier: String?
        public let category: CleanCategory
        public let fileSize: Int64
        public let formattedSize: String
        public let mockColorIndex: Int
        public let title: String
        public let subtitle: String?
        public let isVideo: Bool
        public let durationString: String?
    }
    
    // MARK: - Items Breakdown
    private var allCandidateItems: [ReviewItem] {
        if !cachedItems.isEmpty { return cachedItems }
        return buildCandidateItems()
    }
    
    private func buildCandidateItems() -> [ReviewItem] {
        var items: [ReviewItem] = []
        
        // 1. Duplicate candidates (exclude best photo)
        for group in storage.similarGroups {
            for photo in group.photos where photo.id != group.bestPhotoId {
                items.append(
                    ReviewItem(
                        id: photo.id,
                        assetIdentifier: photo.assetIdentifier,
                        category: .similarPhotos,
                        fileSize: photo.fileSize,
                        formattedSize: photo.formattedSize,
                        mockColorIndex: photo.mockColorIndex,
                        title: photo.mockTitle ?? "Duplicate Photo",
                        subtitle: "Duplicate",
                        isVideo: false,
                        durationString: nil
                    )
                )
            }
        }
        
        // 2. Screenshots
        for item in storage.screenshots {
            items.append(
                ReviewItem(
                    id: item.id,
                    assetIdentifier: item.assetIdentifier,
                    category: .screenshots,
                    fileSize: item.fileSize,
                    formattedSize: item.formattedSize,
                    mockColorIndex: item.mockColorIndex,
                    title: item.mockTitle ?? "Screenshot",
                    subtitle: item.resolutionString,
                    isVideo: false,
                    durationString: nil
                )
            )
        }
        
        // 3. Blurry Photos
        for item in storage.blurryPhotos {
            items.append(
                ReviewItem(
                    id: item.id,
                    assetIdentifier: item.assetIdentifier,
                    category: .blurryPhotos,
                    fileSize: item.fileSize,
                    formattedSize: item.formattedSize,
                    mockColorIndex: item.mockColorIndex,
                    title: item.mockTitle ?? "Blurry Photo",
                    subtitle: "\(Int(item.blurScore * 100))% blur",
                    isVideo: false,
                    durationString: nil
                )
            )
        }
        
        // 4. Large Videos
        for item in storage.largeVideos {
            items.append(
                ReviewItem(
                    id: item.id,
                    assetIdentifier: item.assetIdentifier,
                    category: .largeVideos,
                    fileSize: item.fileSize,
                    formattedSize: item.formattedSize,
                    mockColorIndex: item.mockColorIndex,
                    title: item.mockTitle ?? "Video",
                    subtitle: "\(item.formattedDuration) • \(item.resolutionString)",
                    isVideo: true,
                    durationString: item.formattedDuration
                )
            )
        }
        
        return items
    }
    
    private var filteredItems: [ReviewItem] {
        switch selectedFilter {
        case .all:
            return allCandidateItems
        case .screenshots:
            return allCandidateItems.filter { $0.category == .screenshots }
        case .duplicates:
            return allCandidateItems.filter { $0.category == .similarPhotos }
        case .blurry:
            return allCandidateItems.filter { $0.category == .blurryPhotos }
        case .videos:
            return allCandidateItems.filter { $0.category == .largeVideos }
        }
    }
    
    private var selectedFilteredCount: Int {
        filteredItems.filter { storage.isItemSelected(id: $0.id, category: $0.category) }.count
    }
    
    private var selectedFilteredBytes: Int64 {
        filteredItems
            .filter { storage.isItemSelected(id: $0.id, category: $0.category) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private var isAllFilterSelected: Bool {
        guard !filteredItems.isEmpty else { return false }
        return selectedFilteredCount == filteredItems.count
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()
                
                if isCleaningInProgress {
                    cleaningInProgressView
                } else if allCandidateItems.isEmpty {
                    emptyLibraryView
                } else {
                    VStack(spacing: 0) {
                        // Category Filter Tabs
                        categoryFilterTabs
                        
                        // Select All / Deselect All Action Bar
                        selectionHeaderBar
                        
                        // Interactive Grid
                        ScrollView {
                            let cellWidth = (UIScreen.main.bounds.width - 36) / 3
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 6),
                                    GridItem(.flexible(), spacing: 6),
                                    GridItem(.flexible(), spacing: 6)
                                ],
                                spacing: 6
                            ) {
                                ForEach(filteredItems) { item in
                                    ReviewGridCellView(
                                        item: item,
                                        isSelected: storage.isItemSelected(id: item.id, category: item.category),
                                        cellWidth: cellWidth,
                                        onToggle: {
                                            HapticManager.selection()
                                            storage.toggleItemSelection(id: item.id, category: item.category)
                                        }
                                    )
                                    .equatable()
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 120)
                        }
                    }
                    
                    // Floating Bottom Clean Button
                    VStack {
                        Spacer()
                        bottomActionBar
                    }
                }
            }
            .navigationTitle("Preview & Clean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresentedAsSheet {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            HapticManager.selection()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppTheme.appleBlue)
                        .disabled(isCleaningInProgress)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(storage.totalSelectedItemsCount) Selected")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.appleBlue)
                }
            }
            .alert("Delete \(storage.totalSelectedItemsCount) Selected Items?", isPresented: $showConfirmAlert) {
                Button("Delete", role: .destructive) {
                    startCleanExecution()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up \(storage.formattedRecoverableSpace). All items move to Recently Deleted in Photos where you can restore them within 30 days.")
            }
            .onAppear {
                cachedItems = buildCandidateItems()
                // Pre-select candidate items if nothing was selected yet
                if storage.totalSelectedItemsCount == 0 {
                    storage.selectAllCleanupItems()
                }
            }
        }
    }
    
    // MARK: - Category Filter Tabs
    private var categoryFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReviewFilter.allCases) { filter in
                    let count = count(for: filter)
                    Button(action: {
                        HapticManager.selection()
                        selectedFilter = filter
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: filter.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(filter.rawValue) (\(count))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(selectedFilter == filter ? .black : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter ? Color.white : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.black.opacity(0.3))
    }
    
    private func count(for filter: ReviewFilter) -> Int {
        switch filter {
        case .all: return allCandidateItems.count
        case .screenshots: return storage.screenshots.count
        case .duplicates:
            return storage.similarGroups.reduce(0) { $0 + max(0, $1.photos.count - 1) }
        case .blurry: return storage.blurryPhotos.count
        case .videos: return storage.largeVideos.count
        }
    }
    
    // MARK: - Selection Header Bar
    private var selectionHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedFilteredCount) of \(filteredItems.count) Selected")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text(ByteCountFormatter.string(fromByteCount: selectedFilteredBytes, countStyle: .file))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.cyanAccent)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    HapticManager.impact(style: .light)
                    selectCurrentFilter()
                }) {
                    Text("Select All")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isAllFilterSelected ? AppTheme.textMuted : .cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button(action: {
                    HapticManager.impact(style: .light)
                    deselectCurrentFilter()
                }) {
                    Text("Deselect All")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(selectedFilteredCount == 0 ? AppTheme.textMuted : AppTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
    }
    
    private func selectCurrentFilter() {
        switch selectedFilter {
        case .all:
            storage.selectAllCleanupItems()
        case .screenshots:
            storage.selectCategoryItems(category: .screenshots)
        case .duplicates:
            storage.selectCategoryItems(category: .similarPhotos)
        case .blurry:
            storage.selectCategoryItems(category: .blurryPhotos)
        case .videos:
            storage.selectCategoryItems(category: .largeVideos)
        }
    }
    
    private func deselectCurrentFilter() {
        switch selectedFilter {
        case .all:
            storage.deselectAllCleanupItems()
        case .screenshots:
            storage.deselectCategoryItems(category: .screenshots)
        case .duplicates:
            storage.deselectCategoryItems(category: .similarPhotos)
        case .blurry:
            storage.deselectCategoryItems(category: .blurryPhotos)
        case .videos:
            storage.deselectCategoryItems(category: .largeVideos)
        }
    }
    
    // MARK: - Interactive Grid Cell
    private struct ReviewGridCellView: View, Equatable {
        let item: ReviewItem
        let isSelected: Bool
        let cellWidth: CGFloat
        let onToggle: () -> Void

        static func == (lhs: ReviewGridCellView, rhs: ReviewGridCellView) -> Bool {
            lhs.item == rhs.item && lhs.isSelected == rhs.isSelected && lhs.cellWidth == rhs.cellWidth
        }

        var body: some View {
            Button(action: onToggle) {
                ZStack(alignment: .topTrailing) {
                    // Media Thumbnail
                    MockThumbnailView(
                        assetIdentifier: item.assetIdentifier,
                        colorIndex: item.mockColorIndex,
                        title: item.title,
                        size: CGSize(width: cellWidth, height: cellWidth),
                        isBest: false
                    )
                    .frame(width: cellWidth, height: cellWidth)
                    .clipped()
                    .opacity(isSelected ? 1.0 : 0.45)
                    
                    // Bottom Gradient Scrim & File Size
                    VStack {
                        Spacer()
                        HStack {
                            Text(item.formattedSize)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.65))
                                )
                            Spacer()
                        }
                        .padding(6)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Top-Left Category Badge (Video Duration / Blurry / Screenshot)
                    VStack {
                        HStack {
                            if item.isVideo {
                                HStack(spacing: 3) {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 9))
                                    if let duration = item.durationString {
                                        Text(duration)
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(Color.black.opacity(0.7)))
                            } else if item.category == .blurryPhotos {
                                Image(systemName: "camera.metering.matrix")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.7)))
                            } else if item.category == .screenshots {
                                Image(systemName: "iphone")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.7)))
                            }
                            Spacer()
                        }
                        .padding(6)
                        Spacer()
                    }
                    
                    // Top-Right Selection Indicator
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 22, height: 22)
                                .shadow(color: Color.black.opacity(0.4), radius: 3)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.black)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                                .background(Circle().fill(Color.black.opacity(0.35)))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.cyan : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Floating Bottom Action Bar
    private var bottomActionBar: some View {
        GlassCard(cornerRadius: 22) {
            VStack(spacing: 6) {
                Button(action: {
                    guard storage.totalSelectedItemsCount > 0 else { return }
                    HapticManager.impact(style: .heavy)
                    showConfirmAlert = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .bold))
                        
                        if storage.totalSelectedItemsCount > 0 {
                            Text("Delete Selected (\(storage.totalSelectedItemsCount)) • \(storage.formattedRecoverableSpace)")
                                .font(.system(size: 15, weight: .heavy))
                        } else {
                            Text("Select Items to Clean")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(
                                storage.totalSelectedItemsCount > 0 ?
                                    Color(hex: "FF3B30") :
                                    Color.white.opacity(0.12)
                            )
                    )
                }
                .disabled(storage.totalSelectedItemsCount == 0)
                .buttonStyle(ScaleButtonStyle())
                
                Text("Items move to Recently Deleted in Photos and can be restored for 30 days.")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty Library View
    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Library is Clean!")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("No duplicate photos, screenshots, blurry shots, or heavy videos detected to clean.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Done") {
                HapticManager.selection()
                if isPresentedAsSheet {
                    dismiss()
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Cleaning In-Progress View
    private var cleaningInProgressView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 130, height: 130)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(cleaningProgress))
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                    .animation(.easeInOut, value: cleaningProgress)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)
            }
            
            VStack(spacing: 8) {
                Text(cleaningStepText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(Int(cleaningProgress * 100))%")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.cyan)
            }
            
            Spacer()
        }
    }
    
    private func startCleanExecution() {
        HapticManager.impact(style: .heavy)
        isCleaningInProgress = true
        cleaningStepText = "Confirming deletion with iOS..."
        cleaningProgress = 0.35
        
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            cleaningStepText = "Cleaning selected items..."
            cleaningProgress = 0.75
            
            let freed = await storage.executeClean()
            cleaningProgress = 1.0
            
            if freed > 0 {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    storage.showCelebration = true
                }
            } else {
                isCleaningInProgress = false
            }
        }
    }
}
