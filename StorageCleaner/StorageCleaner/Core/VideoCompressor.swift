import Foundation
import AVFoundation
import Photos

@MainActor
public class VideoCompressor: ObservableObject {
    public static let shared = VideoCompressor()
    
    @Published public var isCompressing: Bool = false
    @Published public var compressionProgress: Double = 0.0
    @Published public var currentVideoTitle: String = ""
    @Published public var statusMessage: String = ""
    
    private init() {}
    
    /// Compresses a video on-device. If `replaceOriginal` is true, replaces the heavy original in Photos to free up storage!
    public func compressVideo(item: VideoItem, replaceOriginal: Bool = true) async -> Bool {
        guard !isCompressing else { return false }
        isCompressing = true
        compressionProgress = 0.0
        currentVideoTitle = item.mockTitle ?? "Video"
        statusMessage = "Analyzing video stream..."
        
        // Demo mode fallback simulation
        if item.assetIdentifier == nil {
            for step in 1...10 {
                try? await Task.sleep(nanoseconds: 180_000_000)
                self.compressionProgress = Double(step) / 10.0
            }
            
            if let index = StorageManager.shared.largeVideos.firstIndex(where: { $0.id == item.id }) {
                let updated = VideoItem(
                    id: item.id,
                    assetIdentifier: item.assetIdentifier,
                    creationDate: item.creationDate,
                    fileSize: item.estimatedCompressedSize,
                    duration: item.duration,
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight,
                    mockColorIndex: item.mockColorIndex,
                    mockTitle: "\(item.mockTitle ?? "Video") (Compressed)"
                )
                StorageManager.shared.largeVideos[index] = updated
                StorageManager.shared.totalSpaceFreedEver += item.estimatedCompressionSavings
                StorageManager.shared.deviceStorage.freeSpace += item.estimatedCompressionSavings
            }
            self.isCompressing = false
            HapticManager.notification(type: .success)
            return true
        }
        
        guard let identifier = item.assetIdentifier else {
            self.isCompressing = false
            return false
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let phAsset = assets.firstObject else {
            self.isCompressing = false
            return false
        }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        statusMessage = "Loading video asset..."
        
        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, _ in
                continuation.resume(returning: asset)
            }
        }
        
        guard let asset = avAsset else {
            self.isCompressing = false
            statusMessage = "Failed to load video."
            return false
        }
        
        // Choose best compression preset compatible with asset
        let candidates = [
            AVAssetExportPresetHEVC1920x1080,
            AVAssetExportPreset1280x720,
            AVAssetExportPresetMediumQuality
        ]
        
        var selectedSession: AVAssetExportSession?
        for cand in candidates {
            if let session = AVAssetExportSession(asset: asset, presetName: cand) {
                selectedSession = session
                break
            }
        }
        
        guard let exportSession = selectedSession else {
            self.isCompressing = false
            statusMessage = "Could not initialize compressor."
            return false
        }
        
        // Choose compatible output file type (.mp4 or .mov)
        let supportedTypes = exportSession.supportedFileTypes
        let outputType: AVFileType
        let ext: String
        if supportedTypes.contains(.mp4) {
            outputType = .mp4
            ext = "mp4"
        } else if supportedTypes.contains(.mov) {
            outputType = .mov
            ext = "mov"
        } else if let first = supportedTypes.first {
            outputType = first
            ext = outputType == .mp4 ? "mp4" : "mov"
        } else {
            outputType = .mp4
            ext = "mp4"
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension(ext)
        
        exportSession.outputURL = tempURL
        exportSession.outputFileType = outputType
        exportSession.shouldOptimizeForNetworkUse = true
        
        statusMessage = "Compressing with hardware encoder..."
        
        // Progress polling task
        let progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    self.compressionProgress = Double(exportSession.progress)
                }
                if exportSession.status != .exporting && exportSession.status != .waiting {
                    break
                }
            }
        }
        
        await exportSession.export()
        progressTask.cancel()
        
        guard exportSession.status == .completed else {
            try? FileManager.default.removeItem(at: tempURL)
            self.isCompressing = false
            statusMessage = "Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")"
            return false
        }
        
        self.compressionProgress = 1.0
        statusMessage = "Saving compressed video..."
        
        // Check new file size
        var compressedFileSize: Int64 = item.fileSize / 3
        if let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
           let size = attrs[.size] as? Int64 {
            compressedFileSize = size
        }
        let savedBytes = max(0, item.fileSize - compressedFileSize)
        
        // Save to Photos & optionally delete heavy original
        var newLocalIdentifier: String?
        let saveSuccess: Bool = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
                newLocalIdentifier = req?.placeholderForCreatedAsset?.localIdentifier
                
                if replaceOriginal {
                    PHAssetChangeRequest.deleteAssets([phAsset] as NSArray)
                }
            } completionHandler: { success, error in
                try? FileManager.default.removeItem(at: tempURL)
                continuation.resume(returning: success)
            }
        }
        
        if saveSuccess {
            // Update storage manager collections
            if let index = StorageManager.shared.largeVideos.firstIndex(where: { $0.id == item.id }) {
                if replaceOriginal {
                    let updated = VideoItem(
                        id: newLocalIdentifier ?? item.id,
                        assetIdentifier: newLocalIdentifier,
                        creationDate: Date(),
                        fileSize: compressedFileSize,
                        duration: item.duration,
                        pixelWidth: item.pixelWidth,
                        pixelHeight: item.pixelHeight,
                        mockColorIndex: item.mockColorIndex,
                        mockTitle: "\(item.mockTitle ?? "Video") (Optimized)"
                    )
                    StorageManager.shared.largeVideos[index] = updated
                }
            }
            StorageManager.shared.totalSpaceFreedEver += savedBytes
            StorageManager.shared.deviceStorage.freeSpace += savedBytes
            StorageManager.shared.deviceStorage.usedSpace = max(0, StorageManager.shared.deviceStorage.usedSpace - savedBytes)
            
            self.isCompressing = false
            statusMessage = "Compression complete! Saved \(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file))"
            HapticManager.notification(type: .success)
            return true
        } else {
            self.isCompressing = false
            statusMessage = "Failed to save to Photos."
            return false
        }
    }
}
