import SwiftUI

public struct BlurryPhotosView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var previewPhoto: PhotoItem?
    @State private var showReviewScreen = false
    
    public init() {}
    
    private var totalSelectedCount: Int {
        storage.selectedBlurryIds.count
    }
    
    private var totalSelectedSize: Int64 {
        storage.blurryPhotos
            .filter { storage.selectedBlurryIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                headerBar
                
                if storage.blurryPhotos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(storage.blurryPhotos) { item in
                                blurryPhotoCell(item: item)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 110)
                    }
                    .refreshable {
                        await PhotoScannerManager.shared.scanLivePhotos()
                    }
                }
            }
            
            // Bottom bar
            if !storage.blurryPhotos.isEmpty {
                bottomBar
            }
        }
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if storage.blurryPhotos.isEmpty {
                Task {
                    await PhotoScannerManager.shared.scanLivePhotos()
                }
            }
        }
        .sheet(item: $previewPhoto) { item in
            blurryPreviewSheet(item: item)
        }
        .sheet(isPresented: $showReviewScreen) {
            ReviewBeforeDeleteView()
        }
    }
    
    // MARK: - Subviews
    private var headerBar: some View {
        GlassCard(cornerRadius: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(storage.blurryPhotos.count) Potential Blurry Photos")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Touch once to select • Hold to preview")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await PhotoScannerManager.shared.scanLivePhotos()
                            HapticManager.notification(type: .success)
                        }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(7)
                            .background(Circle().fill(Color.cyan.opacity(0.15)))
                    }
                    
                    if !storage.blurryPhotos.isEmpty {
                        Button(action: {
                            toggleSelectAll()
                        }) {
                            Text(isAllSelected ? "Deselect All" : "Select All")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.roseAccent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private var isAllSelected: Bool {
        storage.selectedBlurryIds.count == storage.blurryPhotos.count
    }
    
    private func toggleSelectAll() {
        HapticManager.selection()
        if isAllSelected {
            storage.selectedBlurryIds.removeAll()
        } else {
            storage.selectedBlurryIds = Set(storage.blurryPhotos.map { $0.id })
        }
    }
    
    private func blurryPhotoCell(item: PhotoItem) -> some View {
        let isSelected = storage.selectedBlurryIds.contains(item.id)
        
        return VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                MockThumbnailView(
                    assetIdentifier: item.assetIdentifier,
                    colorIndex: item.mockColorIndex,
                    title: item.mockTitle,
                    size: CGSize(width: (UIScreen.main.bounds.width - 56) / 2, height: 180),
                    isBest: false
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "FF3B30") : Color.white.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    if isSelected {
                        storage.selectedBlurryIds.remove(item.id)
                    } else {
                        storage.selectedBlurryIds.insert(item.id)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.28) {
                    HapticManager.impact(style: .medium)
                    previewPhoto = item
                }
                
                // Checkbox on top-right
                Button(action: {
                    HapticManager.selection()
                    if isSelected {
                        storage.selectedBlurryIds.remove(item.id)
                    } else {
                        storage.selectedBlurryIds.insert(item.id)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color(hex: "FF3B30") : Color.black.opacity(0.6))
                            .frame(width: 26, height: 26)
                        Image(systemName: isSelected ? "checkmark" : "circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(8)
                
                // Bottom bar inside thumbnail: blur badge + Maximize button
                VStack {
                    Spacer()
                    HStack {
                        Text("\(Int(item.blurScore * 100))% blur")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(Color(hex: "FF453A"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Button(action: {
                            HapticManager.selection()
                            previewPhoto = item
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
            .frame(height: 180)
            
            // "I want to keep it" Button
            Button(action: {
                storage.keepBlurryPhoto(id: item.id)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "30D158"))
                    Text("I want to keep it")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.12))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var bottomBar: some View {
        GlassCard(cornerRadius: 24) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalSelectedCount) marked")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.roseAccent)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(style: .heavy)
                    let idsToDelete = Array(storage.selectedBlurryIds)
                    Task {
                        await storage.deleteBlurryPhotos(ids: idsToDelete)
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

    private func blurryPreviewSheet(item: PhotoItem) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Spacer()
                    
                    MockThumbnailView(
                        assetIdentifier: item.assetIdentifier,
                        colorIndex: item.mockColorIndex,
                        title: item.mockTitle,
                        size: CGSize(width: min(UIScreen.main.bounds.width - 32, 340), height: 440),
                        isBest: false
                    )
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(Int(item.blurScore * 100))% Blur Detected")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "FF453A"))
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
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
                    
                    VStack(spacing: 10) {
                        // Keep button
                        Button(action: {
                            storage.keepBlurryPhoto(id: item.id)
                            previewPhoto = nil
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Keep This Photo")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        // Single photo clean button
                        Button(role: .destructive, action: {
                            HapticManager.impact(style: .heavy)
                            Task {
                                let success = await storage.deleteBlurryPhotos(ids: [item.id])
                                if success {
                                    previewPhoto = nil
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                Text("Delete Blurry Photo")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Blurry Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        previewPhoto = nil
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.metering.center.weighted")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No Blurry Photos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("All photos in your library are sharp and focused.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                Task {
                    await PhotoScannerManager.shared.scanLivePhotos()
                    HapticManager.notification(type: .success)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .bold))
                    Text("Rescan Photos")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
}
