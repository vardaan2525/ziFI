import SwiftUI

public struct SimilarPhotosView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showReviewScreen = false
    @State private var selectedPhotoForPreview: PhotoItem?
    
    public init() {}
    
    private var totalSelectedCount: Int {
        storage.similarGroups.reduce(0) { $0 + $1.selectedPhotoIds.count }
    }
    
    private var totalSelectedSize: Int64 {
        storage.similarGroups.reduce(0) { $0 + $1.selectedSize }
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Stats Bar
                headerStatsBar
                
                if storage.similarGroups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach($storage.similarGroups) { $group in
                                groupCard(for: $group)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 110)
                    }
                }
            }
            
            // Bottom Action Bar
            if !storage.similarGroups.isEmpty {
                bottomActionBar
            }
        }
        .navigationTitle("Similar Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhotoForPreview) { photo in
            photoDetailSheet(photo: photo)
        }
        .sheet(isPresented: $showReviewScreen) {
            ReviewBeforeDeleteView()
        }
        .onAppear {
            if storage.similarGroups.isEmpty {
                Task {
                    await PhotoScannerManager.shared.scanLivePhotos()
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var headerStatsBar: some View {
        GlassCard(cornerRadius: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(storage.similarGroups.count) Similar Groups")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        if totalSelectedSize > 0 {
                            Text("(\(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.indigoAccent)
                        }
                    }
                    Text("Touch once to select • Hold to preview")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                if !storage.similarGroups.isEmpty {
                    Button(action: {
                        if isAllRecommendedSelected {
                            deselectAll()
                        } else {
                            selectAllRecommended()
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: isAllRecommendedSelected ? "arrow.counterclockwise" : "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text(isAllRecommendedSelected ? "Deselect All" : "Select All Recommended")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isAllRecommendedSelected ? Color.white.opacity(0.15) : AppTheme.indigoAccent)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func groupCard(for group: Binding<SimilarPhotoGroup>) -> some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                // Group Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.wrappedValue.groupDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("• \(Int(group.wrappedValue.similarityScore * 100))% match")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("\(group.wrappedValue.photos.count) shots • \(ByteCountFormatter.string(fromByteCount: group.wrappedValue.totalSize, countStyle: .file))")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    // Quick Group Toggle
                    Button(action: {
                        toggleGroupSelection(group: group)
                    }) {
                        Text(group.wrappedValue.selectedPhotoIds.isEmpty ? "Select Extras" : "Keep All")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.indigoAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppTheme.indigoAccent.opacity(0.15)))
                    }
                }
                
                // Photo Thumbnails Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(group.wrappedValue.photos) { photo in
                            let isBest = photo.id == group.wrappedValue.bestPhotoId
                            let isSelected = group.wrappedValue.selectedPhotoIds.contains(photo.id)
                            
                            VStack(spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    MockThumbnailView(
                                        assetIdentifier: photo.assetIdentifier,
                                        colorIndex: photo.mockColorIndex,
                                        title: photo.mockTitle,
                                        size: CGSize(width: 110, height: 140),
                                        isBest: isBest
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                isBest ? Color.cyan : (isSelected ? Color.red : Color.clear),
                                                lineWidth: isBest ? 2 : (isSelected ? 2 : 0)
                                            )
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.selection()
                                        if !isBest {
                                            if isSelected {
                                                group.wrappedValue.selectedPhotoIds.remove(photo.id)
                                            } else {
                                                group.wrappedValue.selectedPhotoIds.insert(photo.id)
                                            }
                                        }
                                    }
                                    .onLongPressGesture(minimumDuration: 0.28) {
                                        HapticManager.impact(style: .medium)
                                        selectedPhotoForPreview = photo
                                    }
                                    
                                    // Selection checkbox (disabled on Best unless user changes best)
                                    if !isBest {
                                        Button(action: {
                                            HapticManager.selection()
                                            if isSelected {
                                                group.wrappedValue.selectedPhotoIds.remove(photo.id)
                                            } else {
                                                group.wrappedValue.selectedPhotoIds.insert(photo.id)
                                            }
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? Color.red : Color.black.opacity(0.5))
                                                    .frame(width: 24, height: 24)
                                                Image(systemName: isSelected ? "checkmark" : "circle")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(6)
                                    }
                                    // Maximize button on bottom-right of photo
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                HapticManager.selection()
                                                selectedPhotoForPreview = photo
                                            }) {
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Circle().fill(Color.black.opacity(0.7)))
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                        .padding(4)
                                    }
                                }
                                
                                // Best / Action button
                                if isBest {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.cyan)
                                        Text("KEEP")
                                            .font(.system(size: 10, weight: .heavy))
                                            .foregroundColor(.cyan)
                                    }
                                } else {
                                    Button(action: {
                                        HapticManager.selection()
                                        // Set this as best photo instead!
                                        group.wrappedValue.bestPhotoId = photo.id
                                        group.wrappedValue.selectedPhotoIds.remove(photo.id)
                                    }) {
                                        Text("Make Best")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
        }
    }
    
    private var bottomActionBar: some View {
        GlassCard(cornerRadius: 24) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalSelectedCount) photos selected")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Freed: \(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(style: .heavy)
                    var allSelectedIds: [String] = []
                    for g in storage.similarGroups {
                        allSelectedIds.append(contentsOf: g.selectedPhotoIds)
                    }
                    Task {
                        await storage.deleteSimilarPhotos(ids: allSelectedIds)
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
                        Capsule()
                            .fill(totalSelectedCount > 0 ? Color(hex: "FF3B30") : Color.white.opacity(0.12))
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No Similar Photos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("No redundant burst shots or duplicates detected.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private func photoDetailSheet(photo: PhotoItem) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    MockThumbnailView(
                        assetIdentifier: photo.assetIdentifier,
                        colorIndex: photo.mockColorIndex,
                        title: photo.mockTitle,
                        size: CGSize(width: 320, height: 420),
                        isBest: false
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(photo.mockTitle ?? "Photo Detail")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(photo.formattedSize)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        
                        Text("Resolution: \(photo.resolutionString)")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("Taken: \(photo.creationDate.formatted(date: .long, time: .standard))")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Button(role: .destructive, action: {
                        HapticManager.impact(style: .heavy)
                        Task {
                            let success = await storage.deleteSimilarPhotos(ids: [photo.id])
                            if success {
                                selectedPhotoForPreview = nil
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("Delete This Photo")
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
                .padding(.top, 16)
            }
            .navigationTitle("Photo Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedPhotoForPreview = nil
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func toggleGroupSelection(group: Binding<SimilarPhotoGroup>) {
        HapticManager.selection()
        if group.wrappedValue.selectedPhotoIds.isEmpty {
            // Select all non-best
            let nonBest = group.wrappedValue.photos.filter { $0.id != group.wrappedValue.bestPhotoId }.map { $0.id }
            group.wrappedValue.selectedPhotoIds = Set(nonBest)
        } else {
            // Keep all
            group.wrappedValue.selectedPhotoIds.removeAll()
        }
    }
    
    private func selectAllRecommended() {
        HapticManager.selection()
        for i in 0..<storage.similarGroups.count {
            let nonBest = storage.similarGroups[i].photos.filter { $0.id != storage.similarGroups[i].bestPhotoId }.map { $0.id }
            storage.similarGroups[i].selectedPhotoIds = Set(nonBest)
        }
    }
    
    private func deselectAll() {
        HapticManager.selection()
        for i in 0..<storage.similarGroups.count {
            storage.similarGroups[i].selectedPhotoIds.removeAll()
        }
    }
    
    private var isAllRecommendedSelected: Bool {
        guard !storage.similarGroups.isEmpty else { return false }
        for group in storage.similarGroups {
            let nonBestIds = group.photos.filter { $0.id != group.bestPhotoId }.map { $0.id }
            if !nonBestIds.isEmpty && !Set(nonBestIds).isSubset(of: group.selectedPhotoIds) {
                return false
            }
        }
        return true
    }
}
