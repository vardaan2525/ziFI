import Foundation
import LocalAuthentication
import UIKit
import Photos

@MainActor
public class VaultManager: ObservableObject {
    public static let shared = VaultManager()
    
    @Published public var isUnlocked: Bool = false
    @Published public var vaultPhotos: [PhotoItem] = []
    @Published public var authErrorMessage: String?
    @Published public var isImporting: Bool = false
    
    public static var vaultStorageDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("zifi_vault", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.completeUnlessOpen
            ])
        }
        return dir
    }
    
    private var indexFileURL: URL {
        Self.vaultStorageDirectory.appendingPathComponent("vault_index.json")
    }
    
    private init() {
        loadSavedVaultPhotos()
    }
    
    private func loadSavedVaultPhotos() {
        if let data = try? Data(contentsOf: indexFileURL),
           let saved = try? JSONDecoder().decode([PhotoItem].self, from: data) {
            self.vaultPhotos = saved
        } else {
            self.vaultPhotos = []
        }
    }
    
    private func persistIndex() {
        if let data = try? JSONEncoder().encode(vaultPhotos) {
            try? data.write(to: indexFileURL, options: .atomic)
        }
    }
    
    /// Authenticates using Face ID, Touch ID, or device passcode as the native fallback.
    /// No custom PIN ever shown — iOS handles the entire auth flow.
    public func authenticateWithDeviceOwner() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // .deviceOwnerAuthentication = biometrics first, device passcode as fallback
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            self.authErrorMessage = "Authentication not available on this device."
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your private photo vault"
            )
            if success {
                self.isUnlocked = true
                self.authErrorMessage = nil
                HapticManager.notification(type: .success)
                return true
            }
        } catch let err as LAError {
            switch err.code {
            case .userCancel, .systemCancel, .appCancel:
                self.authErrorMessage = nil // User dismissed — no error shown
            case .biometryNotAvailable, .biometryNotEnrolled:
                self.authErrorMessage = "Biometrics not set up — use your device passcode."
            default:
                self.authErrorMessage = nil
            }
        } catch {
            self.authErrorMessage = nil
        }
        return false
    }
    
    public func lockVault() {
        self.isUnlocked = false
        self.authErrorMessage = nil
    }
    
    /// Imports a real photo from raw image data into encrypted vault storage
    public func importImage(data: Data, originalTitle: String? = nil) async -> Bool {
        isImporting = true
        defer { isImporting = false }
        
        guard let image = UIImage(data: data) else { return false }
        let photoId = UUID().uuidString
        let filename = "\(photoId).jpg"
        let fileURL = Self.vaultStorageDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            
            let item = PhotoItem(
                id: photoId,
                assetIdentifier: "vault:\(filename)",
                creationDate: Date(),
                fileSize: Int64(data.count),
                pixelWidth: Int(image.size.width * image.scale),
                pixelHeight: Int(image.size.height * image.scale),
                isFavorite: false,
                isScreenshot: false,
                blurScore: 0.0,
                mockColorIndex: Int.random(in: 0..<10),
                mockTitle: originalTitle ?? "Vault Photo"
            )
            
            vaultPhotos.insert(item, at: 0)
            persistIndex()
            HapticManager.notification(type: .success)
            return true
        } catch {
            print("Failed to save image to vault: \(error)")
            return false
        }
    }
    
    /// Removes photo from the secret vault and deletes its file
    public func removePhoto(_ photo: PhotoItem) {
        if let idx = vaultPhotos.firstIndex(where: { $0.id == photo.id }) {
            vaultPhotos.remove(at: idx)
            persistIndex()
            
            // Delete backing file if stored in vault
            if let assetId = photo.assetIdentifier, assetId.hasPrefix("vault:") {
                let filename = String(assetId.dropFirst("vault:".count))
                let fileURL = Self.vaultStorageDirectory.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: fileURL)
            }
            HapticManager.notification(type: .success)
        }
    }
    
    /// Restores/Exports photo back to the user's Camera Roll
    public func exportPhotoToLibrary(_ photo: PhotoItem) async -> Bool {
        guard let assetId = photo.assetIdentifier, assetId.hasPrefix("vault:") else { return false }
        let filename = String(assetId.dropFirst("vault:".count))
        let fileURL = Self.vaultStorageDirectory.appendingPathComponent(filename)
        guard let image = UIImage(contentsOfFile: fileURL.path) else { return false }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            HapticManager.notification(type: .success)
            return true
        } catch {
            print("Failed to export photo from vault to library: \(error)")
            HapticManager.notification(type: .error)
            return false
        }
    }
    
    public static func loadVaultImage(filename: String) -> UIImage? {
        let fileURL = vaultStorageDirectory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }
}
