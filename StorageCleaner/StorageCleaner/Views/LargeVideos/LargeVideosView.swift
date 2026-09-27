import SwiftUI
import AVKit
import Photos

public struct LargeVideosView: View {
    @ObservedObject var storage = StorageManager.shared
    @ObservedObject var compressor = VideoCompressor.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var playingVideo: VideoItem?
    @State private var compressingVideo: VideoItem?
    @State private var showReviewScreen = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public init() {}
    
    private var totalSelectedCount: Int {
        storage.selectedVideoIds.count
    }
    
    private var totalSelectedSize: Int64 {
        storage.largeVideos
            .filter { storage.selectedVideoIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                headerBar
                
                if storage.largeVideos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(storage.largeVideos) { video in
                                videoGridCell(item: video)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 110)
                    }
                }
            }
            
            // Bottom bar
            if !storage.largeVideos.isEmpty {
                bottomBar
            }
        }
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playingVideo) { video in
            RealVideoPlayerSheet(video: video)
        }
        .sheet(item: $compressingVideo) { video in
            videoCompressSheet(video: video)
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
                    Text("\(storage.largeVideos.count) Heavy Videos")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Touch once to select • Hold to preview")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                
                if totalSelectedCount > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.purpleAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Video Grid Cell
    private func videoGridCell(item: VideoItem) -> some View {
        let isSelected = storage.selectedVideoIds.contains(item.id)
        let cellWidth = (UIScreen.main.bounds.width - 44) / 2
        
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Video thumbnail
                MockThumbnailView(
                    assetIdentifier: item.assetIdentifier,
                    colorIndex: item.mockColorIndex,
                    title: nil,
                    size: CGSize(width: cellWidth, height: 160),
                    isBest: false
                )
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.purple : Color.white.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.selection()
                    if isSelected {
                        storage.selectedVideoIds.remove(item.id)
                    } else {
                        storage.selectedVideoIds.insert(item.id)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.28) {
                    HapticManager.impact(style: .medium)
                    playingVideo = item
                }
                
                // Big Play Button in Center
                Button(action: {
                    HapticManager.impact(style: .medium)
                    playingVideo = item
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 44, height: 44)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Size Badge (Top-Left)
                VStack {
                    HStack {
                        Text(item.formattedSize)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(5)
                        Spacer()
                    }
                    .padding(8)
                    Spacer()
                }
                
                // Selection Checkbox (Top-Right)
                Button(action: {
                    HapticManager.selection()
                    if isSelected {
                        storage.selectedVideoIds.remove(item.id)
                    } else {
                        storage.selectedVideoIds.insert(item.id)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.purple : Color.black.opacity(0.6))
                            .frame(width: 26, height: 26)
                        Image(systemName: isSelected ? "checkmark" : "circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(8)
                
                // Duration & Maximize (Bottom-Right)
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            HapticManager.impact(style: .medium)
                            playingVideo = item
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.black.opacity(0.75)))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        
                        Spacer()
                        
                        HStack(spacing: 3) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 8))
                            Text(item.formattedDuration)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(5)
                    }
                    .padding(8)
                }
            }
            .frame(width: cellWidth, height: 160)
            
            // Cell Footer with Title and Big Clickable Compress Action
            VStack(alignment: .leading, spacing: 6) {
                Text(item.mockTitle ?? "Video")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Button(action: {
                    HapticManager.impact(style: .medium)
                    compressingVideo = item
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Compress")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(AppTheme.cyanAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.cyanAccent.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppTheme.cyanAccent.opacity(0.4), lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 4)
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
                        .foregroundColor(AppTheme.purpleAccent)
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.impact(style: .heavy)
                    let idsToDelete = Array(storage.selectedVideoIds)
                    Task {
                        await storage.deleteLargeVideos(ids: idsToDelete)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text(totalSelectedCount == 1 ? "Clean 1 Video" : "Clean (\(totalSelectedCount))")
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(totalSelectedCount > 0 ? Color(hex: "FF3B30") : Color.white.opacity(0.12))
                    )
                }
                .disabled(totalSelectedCount == 0)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            
            Text("No Heavy Videos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("No large videos consuming significant storage space found.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Video Compression Sheet
    private func videoCompressSheet(video: VideoItem) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 6) {
                        Text("Video Compressor")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.white)
                        Text(video.mockTitle ?? "Video File")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    // Comparison Card
                    GlassCard(cornerRadius: 18) {
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Size")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textMuted)
                                    Text(video.formattedSize)
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.cyan)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("After HEVC")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textMuted)
                                    Text(ByteCountFormatter.string(fromByteCount: video.estimatedCompressedSize, countStyle: .file))
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            HStack {
                                Text("Storage Saved")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("~\(ByteCountFormatter.string(fromByteCount: video.estimatedCompressionSavings, countStyle: .file)) (up to 70%)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 20)
                    
                    if compressor.isCompressing {
                        VStack(spacing: 10) {
                            ProgressView(value: compressor.compressionProgress)
                                .tint(.cyan)
                            Text("\(compressor.statusMessage) \(Int(compressor.compressionProgress * 100))%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            let success = await compressor.compressVideo(item: video, replaceOriginal: true)
                            if success {
                                compressingVideo = nil
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                            Text(compressor.isCompressing ? "Compressing Video..." : "Compress & Free Storage")
                                .font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.cyan)
                        )
                    }
                    .disabled(compressor.isCompressing)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Compress Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        compressingVideo = nil
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Real Video Player Sheet (Actually plays real video via AVPlayer)
public struct RealVideoPlayerSheet: View {
    public let video: VideoItem
    @Environment(\.dismiss) private var dismiss
    
    @State private var player: AVPlayer?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    public init(video: VideoItem) {
        self.video = video
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onAppear {
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                        Text("Loading video stream...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        Text(errorMessage ?? "Unable to play video")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Bottom Floating Info & Direct Delete Action
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(video.mockTitle ?? "Video")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(video.formattedSize) • \(video.formattedDuration)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(role: .destructive, action: {
                            HapticManager.impact(style: .heavy)
                            Task {
                                let ok = await StorageManager.shared.deleteLargeVideos(ids: [video.id])
                                if ok {
                                    player?.pause()
                                    dismiss()
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Delete Video")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.red))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(video.mockTitle ?? "Video Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive, action: {
                        HapticManager.impact(style: .heavy)
                        Task {
                            let ok = await StorageManager.shared.deleteLargeVideos(ids: [video.id])
                            if ok {
                                player?.pause()
                                dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text("Delete")
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 15, weight: .bold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                }
            }
            .task {
                await loadPlayer()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadPlayer() async {
        guard let id = video.assetIdentifier else {
            // Demo mode / fallback: sample preview
            self.isLoading = false
            self.errorMessage = "Demo video preview only"
            return
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else {
            self.isLoading = false
            self.errorMessage = "Video asset not found in Photos"
            return
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let playerItem: AVPlayerItem? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
                continuation.resume(returning: item)
            }
        }
        
        self.isLoading = false
        if let item = playerItem {
            self.player = AVPlayer(playerItem: item)
        } else {
            self.errorMessage = "Could not load video player stream"
        }
    }
}
