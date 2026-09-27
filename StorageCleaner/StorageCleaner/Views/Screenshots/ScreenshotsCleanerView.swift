import SwiftUI

public struct ScreenshotsCleanerView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var filterMode: ScreenshotFilter = .all
    @State private var previewScreenshot: PhotoItem?
    @State private var showReviewScreen = false
    
    public init() {}
    
    enum ScreenshotFilter: String, CaseIterable {
        case all = "All"
        case olderThan30Days = "Older > 30d"
        case receipts = "Receipts & Notes"
    }
    
    private var filteredScreenshots: [PhotoItem] {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        switch filterMode {
        case .all:
            return storage.screenshots
        case .olderThan30Days:
            return storage.screenshots.filter { $0.creationDate < thirtyDaysAgo }
        case .receipts:
            return storage.screenshots.filter { ($0.mockTitle ?? "").contains("Receipt") || ($0.mockTitle ?? "").contains("Boarding") }
        }
    }
    
    private var totalSelectedCount: Int {
        storage.selectedScreenshotIds.count
    }
    
    private var totalSelectedSize: Int64 {
        storage.screenshots
            .filter { storage.selectedScreenshotIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Segment
                filterPickerSection
                
                // Select All Toolbar
                selectToolbarSection
                
                if storage.screenshots.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(filteredScreenshots) { item in
                                screenshotCell(item: item)
                            }
                        }
                        .padding(14)
                        .padding(.bottom, 110)
                    }
                }
            }
            
            // Bottom floating action bar
            if !storage.screenshots.isEmpty {
                bottomBar
            }
        }
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewScreenshot) { item in
            screenshotPreviewSheet(item: item)
        }
        .sheet(isPresented: $showReviewScreen) {
            ReviewBeforeDeleteView()
        }
    }
    
    // MARK: - Subviews
    private var filterPickerSection: some View {
        HStack(spacing: 8) {
            ForEach(ScreenshotFilter.allCases, id: \.self) { filter in
                Button(action: {
                    HapticManager.selection()
                    filterMode = filter
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(filterMode == filter ? .white : AppTheme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(filterMode == filter ? AppTheme.cyanAccent : Color.white.opacity(0.08))
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private var selectToolbarSection: some View {
        GlassCard(cornerRadius: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(filteredScreenshots.count) screenshots (\(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)) selected)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Touch once to select • Hold to preview")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.cyanAccent)
                }
                
                Spacer()
                
                Button(action: {
                    toggleSelectAll()
                }) {
                    Text(isAllSelected ? "Deselect All" : "Select All")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.cyanAccent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
    
    private var isAllSelected: Bool {
        let currentIds = Set(filteredScreenshots.map { $0.id })
        return !currentIds.isEmpty && currentIds.isSubset(of: storage.selectedScreenshotIds)
    }
    
    private func toggleSelectAll() {
        HapticManager.selection()
        let currentIds = filteredScreenshots.map { $0.id }
        if isAllSelected {
            currentIds.forEach { storage.selectedScreenshotIds.remove($0) }
        } else {
            currentIds.forEach { storage.selectedScreenshotIds.insert($0) }
        }
    }
    
    private func screenshotCell(item: PhotoItem) -> some View {
        let isSelected = storage.selectedScreenshotIds.contains(item.id)
        let cellWidth = (UIScreen.main.bounds.width - 48) / 3
        
        return ZStack(alignment: .topTrailing) {
            MockThumbnailView(
                assetIdentifier: item.assetIdentifier,
                colorIndex: item.mockColorIndex,
                title: item.mockTitle,
                size: CGSize(width: cellWidth, height: 180),
                isBest: false
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.red : Color.white.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                HapticManager.selection()
                if isSelected {
                    storage.selectedScreenshotIds.remove(item.id)
                } else {
                    storage.selectedScreenshotIds.insert(item.id)
                }
            }
            .onLongPressGesture(minimumDuration: 0.28) {
                HapticManager.impact(style: .medium)
                previewScreenshot = item
            }
            
            // Checkbox on top-right with large tap target
            Button(action: {
                HapticManager.selection()
                if isSelected {
                    storage.selectedScreenshotIds.remove(item.id)
                } else {
                    storage.selectedScreenshotIds.insert(item.id)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.red : Color.black.opacity(0.65))
                        .frame(width: 26, height: 26)
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
            }
            .padding(2)
            
            // Bottom info bar with Maximize button
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.selection()
                        previewScreenshot = item
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(6)
            }
        }
    }
    
    private var bottomBar: some View {
        GlassCard(cornerRadius: 24) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalSelectedCount) selected")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(style: .heavy)
                    let idsToDelete = Array(storage.selectedScreenshotIds)
                    Task {
                        await storage.deleteScreenshots(ids: idsToDelete)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(totalSelectedCount == 1 ? "Clean 1 Photo" : "Clean (\(totalSelectedCount))")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(totalSelectedCount > 0 ? Color(hex: "FF3B30") : Color.white.opacity(0.12))
                    )
                }
                .disabled(totalSelectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.cyan)
            
            Text("No Screenshots Found")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your screenshot gallery is empty. When you take screenshots, they will appear here for easy bulk cleaning.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private func screenshotPreviewSheet(item: PhotoItem) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 18) {
                    Spacer()
                    
                    MockThumbnailView(
                        assetIdentifier: item.assetIdentifier,
                        colorIndex: item.mockColorIndex,
                        title: item.mockTitle,
                        size: CGSize(width: min(UIScreen.main.bounds.width - 32, 340), height: 480),
                        isBest: false
                    )
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.mockTitle ?? "Screenshot")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        
                        HStack {
                            Text(item.creationDate.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text(item.resolutionString)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 28)
                    
                    Spacer()
                    
                    // Single photo clean button
                    Button(role: .destructive, action: {
                        HapticManager.impact(style: .heavy)
                        Task {
                            let success = await storage.deleteScreenshots(ids: [item.id])
                            if success {
                                previewScreenshot = nil
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Delete Screenshot")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        previewScreenshot = nil
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
