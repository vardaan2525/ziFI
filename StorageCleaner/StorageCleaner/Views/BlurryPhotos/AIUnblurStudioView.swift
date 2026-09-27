import SwiftUI
import Photos

public struct AIUnblurStudioView: View {
    public let photo: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var unblurService = AIUnblurService.shared
    @ObservedObject private var storage = StorageManager.shared
    
    @State private var originalImage: UIImage?
    @State private var enhancedImage: UIImage?
    @State private var selectedIntensity: AIUnblurService.UnblurIntensity = .balanced
    @State private var showOriginal: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveSuccessMessage: String?
    
    public init(photo: PhotoItem) {
        self.photo = photo
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Studio Header
                    studioHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    // Main Image Comparison View
                    imageCanvasView
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 16)
                    
                    // Controls & Actions
                    bottomControls
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .task {
                await loadAndEnhance()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Subviews
    private var studioHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("ON-DEVICE AI UNBLUR")
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(.cyan)
                }
                Text("AI Photo Enhancer")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)
            }
            Spacer()
            
            // Hold to Compare pill
            if enhancedImage != nil {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: showOriginal ? "eye.fill" : "eye")
                            .font(.system(size: 11))
                        Text(showOriginal ? "Showing Original" : "Hold: Original")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(showOriginal ? .yellow : .white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in showOriginal = true }
                        .onEnded { _ in showOriginal = false }
                )
            }
        }
    }
    
    private var imageCanvasView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            if let displayImage = showOriginal ? originalImage : (enhancedImage ?? originalImage) {
                Image(uiImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(18)
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(1.2)
                    Text("Loading full-res photo...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            // Badge Overlay
            VStack {
                HStack {
                    Text(showOriginal ? "BEFORE (BLURRY)" : "AFTER (AI UNBLURRED)")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundColor(showOriginal ? .red : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(16)
                Spacer()
            }
            
            if unblurService.isProcessing {
                ZStack {
                    Color.black.opacity(0.4)
                        .cornerRadius(20)
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.cyan)
                        Text("Sharpening on Apple Neural Engine...")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 14) {
            // Intensity Picker
            Picker("Sharpness", selection: $selectedIntensity) {
                ForEach(AIUnblurService.UnblurIntensity.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedIntensity) { _, _ in
                Task { await runEnhance() }
            }
            
            if let message = saveSuccessMessage {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Save to Camera Roll
                Button(action: {
                    guard let enhanced = enhancedImage else { return }
                    HapticManager.impact(style: .medium)
                    isSaving = true
                    Task {
                        let ok = await unblurService.saveEnhancedImageToLibrary(enhanced)
                        isSaving = false
                        if ok {
                            saveSuccessMessage = "Saved to Photos Library!"
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Save Unblurred")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                }
                .disabled(enhancedImage == nil || isSaving)
                .buttonStyle(ScaleButtonStyle())
                
                // Replace Blurry Original
                Button(action: {
                    replaceOriginal()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Replace Blurry")
                            .font(.system(size: 14, weight: .heavy))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.cyan))
                }
                .disabled(enhancedImage == nil || isSaving)
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
    
    // MARK: - Actions
    private func loadAndEnhance() async {
        guard let id = photo.assetIdentifier else {
            // Demo mode fallback: generate sample image
            self.originalImage = createFallbackImage()
            await runEnhance()
            return
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        
        let loaded: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1400, height: 1400),
                contentMode: .aspectFit,
                options: options
            ) { img, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let img = img, !isDegraded {
                    continuation.resume(returning: img)
                }
            }
        }
        
        self.originalImage = loaded ?? createFallbackImage()
        await runEnhance()
    }
    
    private func runEnhance() async {
        guard let orig = originalImage else { return }
        let enhanced = await unblurService.enhancePhoto(orig, intensity: selectedIntensity)
        self.enhancedImage = enhanced
    }
    
    private func replaceOriginal() {
        guard let enhanced = enhancedImage else { return }
        isSaving = true
        HapticManager.impact(style: .heavy)
        
        Task {
            // 1. Save new enhanced photo
            let saved = await unblurService.saveEnhancedImageToLibrary(enhanced)
            if saved {
                // 2. Delete original blurry photo
                if let assetId = photo.assetIdentifier {
                    _ = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: [assetId])
                }
                // 3. Remove from storage manager blurry list
                storage.blurryPhotos.removeAll { $0.id == photo.id }
                storage.selectedBlurryIds.remove(photo.id)
                dismiss()
            }
            isSaving = false
        }
    }
    
    private func createFallbackImage() -> UIImage {
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, true, 2.0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        let text = "Sample Photo Preview" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        text.draw(at: CGPoint(x: 70, y: 180), withAttributes: attrs)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}
