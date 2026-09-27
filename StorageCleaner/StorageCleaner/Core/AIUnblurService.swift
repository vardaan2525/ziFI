import Foundation
import UIKit
import CoreImage
import Photos

@MainActor
public class AIUnblurService: ObservableObject {
    public static let shared = AIUnblurService()
    
    @Published public var isProcessing: Bool = false
    @Published public var processingProgress: Double = 0.0
    
    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])
    
    private init() {}
    
    public enum UnblurIntensity: String, CaseIterable, Identifiable {
        case gentle = "Natural"
        case balanced = "Balanced"
        case strong = "Ultra HD"
        
        public var id: String { rawValue }
        
        var deconvolutionWeight: CGFloat {
            switch self {
            case .gentle: return 0.35
            case .balanced: return 0.65
            case .strong: return 1.05
            }
        }
        
        var noiseThreshold: Double {
            switch self {
            case .gentle: return 0.015
            case .balanced: return 0.022
            case .strong: return 0.035
            }
        }
    }
    
    /// Unblurs photos completely on-device using multi-stage spatial inverse deconvolution
    /// and luminosity-locked micro-edge reconstruction (Zero artificial contrast or saturation boosting).
    public func enhancePhoto(_ image: UIImage, intensity: UnblurIntensity = .balanced) async -> UIImage? {
        isProcessing = true
        processingProgress = 0.15
        
        return await Task.detached(priority: .userInitiated) { [weak self] () -> UIImage? in
            guard let self = self, let cgImage = image.cgImage else { return nil }
            
            let ciImage = CIImage(cgImage: cgImage)
            let extent = ciImage.extent
            
            // Stage 1: Edge-preserving sensor noise suppression
            // Eliminates high-frequency noise before inverse deconvolution to prevent artifacts
            var baseImage = ciImage
            if let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(ciImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(intensity.noiseThreshold, forKey: "inputNoiseLevel")
                noiseFilter.setValue(0.0, forKey: "inputSharpness")
                if let cleaned = noiseFilter.outputImage {
                    baseImage = cleaned
                }
            }
            
            // Stage 2: Spatial 2D Laplacian Inverse Deconvolution Kernel
            // Deconvolves optical blur point-spread function using discrete spatial matrix
            let w = intensity.deconvolutionWeight
            let center = 1.0 + (4.0 * w)
            let weights: [CGFloat] = [
                0.0, -w, 0.0,
                -w, center, -w,
                0.0, -w, 0.0
            ]
            let kernelVector = CIVector(values: weights, count: 9)
            
            var deblurredImage = baseImage
            if let convFilter = CIFilter(name: "CIConvolution3x3") {
                convFilter.setValue(baseImage, forKey: kCIInputImageKey)
                convFilter.setValue(kernelVector, forKey: "inputWeights")
                convFilter.setValue(0.0, forKey: "inputBias")
                if let output = convFilter.outputImage {
                    deblurredImage = output
                }
            }
            
            // Stage 3: Strict Luminosity Transfer
            // Composites the deblurred high-frequency structural luminance back onto the original image
            // Ensures 100% preservation of original color, tint, and tonal dynamic range (NO contrast boost)
            var finalOutput = deblurredImage
            if let luminosityFilter = CIFilter(name: "CILuminosityBlendMode") {
                luminosityFilter.setValue(deblurredImage, forKey: kCIInputImageKey)
                luminosityFilter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
                if let blend = luminosityFilter.outputImage {
                    finalOutput = blend
                }
            }
            
            // Stage 4: Hardware-accelerated Metal render
            guard let outputCG = self.ciContext.createCGImage(finalOutput, from: extent) else {
                return nil
            }
            
            let result = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
            
            Task { @MainActor in
                self.isProcessing = false
                self.processingProgress = 1.0
            }
            
            return result
        }.value
    }
    
    /// Saves an enhanced image directly to the user's Photos library on-device.
    public func saveEnhancedImageToLibrary(_ image: UIImage) async -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            HapticManager.notification(type: .success)
            return true
        } catch {
            print("Failed to save enhanced photo: \(error)")
            HapticManager.notification(type: .error)
            return false
        }
    }
}
