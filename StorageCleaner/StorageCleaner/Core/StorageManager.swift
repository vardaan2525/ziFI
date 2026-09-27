import Foundation
import SwiftUI
import Combine
import Photos
import WidgetKit

@MainActor
public class StorageManager: ObservableObject {
    public static let shared = StorageManager()
    
    // MARK: - Published State
    @Published public var deviceStorage: DeviceStorageInfo
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var scanStatusText: String = "Ready to scan"
    
    // Demo Mode toggle for testing / simulator (Defaults to FALSE for real phone data)
    @Published public var isDemoMode: Bool = false
    
    // Data collections (Strictly Photos & Videos)
    @Published public var similarGroups: [SimilarPhotoGroup] = []
    @Published public var screenshots: [PhotoItem] = []
    @Published public var selectedScreenshotIds: Set<String> = []
    
    @Published public var largeVideos: [VideoItem] = []
    @Published public var selectedVideoIds: Set<String> = []
    
    @Published public var blurryPhotos: [PhotoItem] = []
    @Published public var selectedBlurryIds: Set<String> = []
    
    // User-kept photos (excluded from blurry cleanup)
    @Published public var keptPhotoIds: Set<String> = []
    
    // Total Space Freed In Lifetime / Current Session
    @Published public var totalSpaceFreedEver: Int64 = 0
    @Published public var lastFreedAmount: Int64 = 0
    @Published public var showCelebration: Bool = false
    
    // Permissions status (strictly Photo Library)
    @Published public var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    
    private init() {
        self.deviceStorage = MockDataService.generateDeviceStorage()
        self.totalSpaceFreedEver = UserDefaults.standard.object(forKey: "zifi_total_freed_ever") as? Int64 ?? 0
        self.keptPhotoIds = Set(UserDefaults.standard.stringArray(forKey: "zifi_kept_photo_ids") ?? [])
        refreshDeviceStorage()
        checkPermissions()
        loadInitialData()
    }
    
    /// Marks a blurry photo as explicitly kept by the user, removing it from blurry cleanup and persisting the choice
    public func keepBlurryPhoto(id: String) {
        keptPhotoIds.insert(id)
        UserDefaults.standard.set(Array(keptPhotoIds), forKey: "zifi_kept_photo_ids")
        withAnimation(.easeInOut(duration: 0.25)) {
            blurryPhotos.removeAll { $0.id == id }
            selectedBlurryIds.remove(id)
        }
        HapticManager.notification(type: .success)
    }
    
    // MARK: - Initial Data Load
    public func loadInitialData() {
        if isDemoMode {
            self.similarGroups = MockDataService.generateSimilarPhotos()
            self.screenshots = MockDataService.generateScreenshots()
            self.selectedScreenshotIds = []
            self.largeVideos = MockDataService.generateLargeVideos()
            self.blurryPhotos = MockDataService.generateBlurryPhotos()
            self.selectedBlurryIds = []
        } else {
            // Clear demo data and load live
            self.similarGroups = []
            self.screenshots = []
            self.largeVideos = []
            self.blurryPhotos = []
            self.selectedScreenshotIds = []
            self.selectedVideoIds = []
            self.selectedBlurryIds = []
            refreshDeviceStorage()
            checkPermissions()
            if photoAuthStatus == .authorized || photoAuthStatus == .limited {
                performFullScan()
            }
        }
    }
    
    // MARK: - Disk Storage Calculation
    public func refreshDeviceStorage() {
        let metrics = DeviceStorageCalculator.calculateLive()
        self.objectWillChange.send()
        self.deviceStorage = DeviceStorageInfo(
            totalSpace: metrics.total,
            freeSpace: metrics.free,
            usedSpace: metrics.used
        )
        syncWithWidget()
    }
    
    /// Records space freed from any clean action and immediately updates device storage & widget
    public func recordFreedStorage(freedBytes: Int64) {
        guard freedBytes > 0 else { return }
        self.lastFreedAmount = freedBytes
        self.totalSpaceFreedEver += freedBytes
        UserDefaults.standard.set(self.totalSpaceFreedEver, forKey: "zifi_total_freed_ever")
        
        let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName) ?? UserDefaults.standard
        let pending = (sharedDefaults.object(forKey: "zifi_pending_freed_bytes") as? Int64 ?? 0) + freedBytes
        sharedDefaults.set(pending, forKey: "zifi_pending_freed_bytes")
        
        let freedSince = (sharedDefaults.object(forKey: "zifi_freed_since_calibration") as? Int64 ?? 0) + freedBytes
        sharedDefaults.set(freedSince, forKey: "zifi_freed_since_calibration")
        
        let newFree = self.deviceStorage.freeSpace + freedBytes
        let newUsed = max(0, self.deviceStorage.usedSpace - freedBytes)
        
        self.objectWillChange.send()
        self.deviceStorage = DeviceStorageInfo(
            totalSpace: self.deviceStorage.totalSpace,
            freeSpace: newFree,
            usedSpace: newUsed
        )
        syncWithWidget()
    }
    
    /// Sets a calibrated used baseline (in bytes) to match iOS Settings exactly
    public func calibrateStorageBaseline(usedBytes: Int64) {
        let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName) ?? UserDefaults.standard
        sharedDefaults.set(usedBytes, forKey: "zifi_calibrated_used_bytes")
        sharedDefaults.set(0, forKey: "zifi_freed_since_calibration")
        refreshDeviceStorage()
    }
    
    /// Resets calibration to automatic APFS calculation
    public func resetStorageCalibration() {
        let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName) ?? UserDefaults.standard
        sharedDefaults.removeObject(forKey: "zifi_calibrated_used_bytes")
        sharedDefaults.removeObject(forKey: "zifi_freed_since_calibration")
        refreshDeviceStorage()
    }
    
    /// Returns true if a manual calibration is currently active
    public var isStorageCalibrated: Bool {
        let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName) ?? UserDefaults.standard
        return (sharedDefaults.object(forKey: "zifi_calibrated_used_bytes") as? Int64 ?? 0) > 0
    }
    
    /// Syncs device storage values to shared App Group and requests WidgetKit reload
    public func syncWithWidget() {
        if let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName) {
            sharedDefaults.set(self.deviceStorage.totalSpace, forKey: "shared_total_bytes")
            sharedDefaults.set(self.deviceStorage.freeSpace, forKey: "shared_free_bytes")
            sharedDefaults.set(self.deviceStorage.usedSpace, forKey: "shared_used_bytes")
            sharedDefaults.set(self.deviceStorage.usedPercentage, forKey: "shared_used_percentage")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "shared_last_updated")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Total Recoverable Storage
    public var totalRecoverableBytes: Int64 {
        let similar = similarGroups.reduce(0) { $0 + $1.selectedSize }
        let screen = screenshots.filter { selectedScreenshotIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        let video = largeVideos.filter { selectedVideoIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        let blurry = blurryPhotos.filter { selectedBlurryIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        return similar + screen + video + blurry
    }
    
    public var potentialTotalSavingsBytes: Int64 {
        let similar = similarGroups.reduce(0) { $0 + $1.potentialSavingsSize }
        let screen = screenshots.reduce(0) { $0 + $1.fileSize }
        let video = largeVideos.reduce(0) { $0 + $1.fileSize }
        let blurry = blurryPhotos.reduce(0) { $0 + $1.fileSize }
        return similar + screen + video + blurry
    }
    
    public var formattedRecoverableSpace: String {
        let bytes = totalRecoverableBytes > 0 ? totalRecoverableBytes : potentialTotalSavingsBytes
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    public var formattedPotentialSpace: String {
        ByteCountFormatter.string(fromByteCount: potentialTotalSavingsBytes, countStyle: .file)
    }
    
    // MARK: - Selected Count
    public var totalSelectedItemsCount: Int {
        let similar = similarGroups.reduce(0) { $0 + $1.selectedPhotoIds.count }
        let screen = selectedScreenshotIds.count
        let video = selectedVideoIds.count
        let blurry = selectedBlurryIds.count
        return similar + screen + video + blurry
    }
    
    // MARK: - Category Summaries (Actual Storage vs Selected Storage)
    
    /// Total actual storage occupied on disk by this category
    public func categoryTotalSize(for category: CleanCategory) -> Int64 {
        switch category {
        case .similarPhotos:
            return similarGroups.reduce(0) { $0 + $1.totalSize }
        case .screenshots:
            return screenshots.reduce(0) { $0 + $1.fileSize }
        case .largeVideos:
            return largeVideos.reduce(0) { $0 + $1.fileSize }
        case .blurryPhotos:
            return blurryPhotos.reduce(0) { $0 + $1.fileSize }
        }
    }
    
    /// Total storage of items currently selected by the user for deletion
    public func categorySelectedSize(for category: CleanCategory) -> Int64 {
        switch category {
        case .similarPhotos:
            return similarGroups.reduce(0) { $0 + $1.selectedSize }
        case .screenshots:
            return screenshots.filter { selectedScreenshotIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        case .largeVideos:
            return largeVideos.filter { selectedVideoIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        case .blurryPhotos:
            return blurryPhotos.filter { selectedBlurryIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
        }
    }
    
    /// Active category size for display: returns selected size if items are selected;
    /// otherwise returns the actual full storage consumed by that category.
    public func categorySize(for category: CleanCategory) -> Int64 {
        let selected = categorySelectedSize(for: category)
        if selected > 0 {
            return selected
        }
        return categoryTotalSize(for: category)
    }
    
    /// Total count of items in this category
    public func categoryItemCount(for category: CleanCategory) -> Int {
        switch category {
        case .similarPhotos:
            return similarGroups.count
        case .screenshots:
            return screenshots.count
        case .largeVideos:
            return largeVideos.count
        case .blurryPhotos:
            return blurryPhotos.count
        }
    }
    
    /// Count of selected items in this category
    public func categorySelectedItemCount(for category: CleanCategory) -> Int {
        switch category {
        case .similarPhotos:
            return similarGroups.reduce(0) { $0 + $1.selectedPhotoIds.count }
        case .screenshots:
            return selectedScreenshotIds.count
        case .largeVideos:
            return selectedVideoIds.count
        case .blurryPhotos:
            return selectedBlurryIds.count
        }
    }
    
    // MARK: - Batch Selection & Toggle Helpers
    public func selectAllCleanupItems() {
        // Select all screenshots
        selectedScreenshotIds = Set(screenshots.map { $0.id })
        
        // Select all blurry photos
        selectedBlurryIds = Set(blurryPhotos.map { $0.id })
        
        // Select all large videos
        selectedVideoIds = Set(largeVideos.map { $0.id })
        
        // Select all duplicate candidates (excluding best photo to protect original)
        for i in 0..<similarGroups.count {
            let candidateIds = similarGroups[i].photos
                .filter { $0.id != similarGroups[i].bestPhotoId }
                .map { $0.id }
            similarGroups[i].selectedPhotoIds = Set(candidateIds)
        }
    }
    
    public func deselectAllCleanupItems() {
        selectedScreenshotIds.removeAll()
        selectedBlurryIds.removeAll()
        selectedVideoIds.removeAll()
        for i in 0..<similarGroups.count {
            similarGroups[i].selectedPhotoIds.removeAll()
        }
    }
    
    public func selectCategoryItems(category: CleanCategory) {
        switch category {
        case .similarPhotos:
            for i in 0..<similarGroups.count {
                let candidateIds = similarGroups[i].photos
                    .filter { $0.id != similarGroups[i].bestPhotoId }
                    .map { $0.id }
                similarGroups[i].selectedPhotoIds = Set(candidateIds)
            }
        case .screenshots:
            selectedScreenshotIds = Set(screenshots.map { $0.id })
        case .blurryPhotos:
            selectedBlurryIds = Set(blurryPhotos.map { $0.id })
        case .largeVideos:
            selectedVideoIds = Set(largeVideos.map { $0.id })
        }
    }
    
    public func deselectCategoryItems(category: CleanCategory) {
        switch category {
        case .similarPhotos:
            for i in 0..<similarGroups.count {
                similarGroups[i].selectedPhotoIds.removeAll()
            }
        case .screenshots:
            selectedScreenshotIds.removeAll()
        case .blurryPhotos:
            selectedBlurryIds.removeAll()
        case .largeVideos:
            selectedVideoIds.removeAll()
        }
    }
    
    public func toggleItemSelection(id: String, category: CleanCategory) {
        switch category {
        case .similarPhotos:
            for i in 0..<similarGroups.count {
                if similarGroups[i].photos.contains(where: { $0.id == id }) {
                    if similarGroups[i].selectedPhotoIds.contains(id) {
                        similarGroups[i].selectedPhotoIds.remove(id)
                    } else {
                        similarGroups[i].selectedPhotoIds.insert(id)
                    }
                    break
                }
            }
        case .screenshots:
            if selectedScreenshotIds.contains(id) {
                selectedScreenshotIds.remove(id)
            } else {
                selectedScreenshotIds.insert(id)
            }
        case .blurryPhotos:
            if selectedBlurryIds.contains(id) {
                selectedBlurryIds.remove(id)
            } else {
                selectedBlurryIds.insert(id)
            }
        case .largeVideos:
            if selectedVideoIds.contains(id) {
                selectedVideoIds.remove(id)
            } else {
                selectedVideoIds.insert(id)
            }
        }
    }
    
    public func isItemSelected(id: String, category: CleanCategory) -> Bool {
        switch category {
        case .similarPhotos:
            for group in similarGroups {
                if group.selectedPhotoIds.contains(id) {
                    return true
                }
            }
            return false
        case .screenshots:
            return selectedScreenshotIds.contains(id)
        case .blurryPhotos:
            return selectedBlurryIds.contains(id)
        case .largeVideos:
            return selectedVideoIds.contains(id)
        }
    }
    
    // MARK: - Full Scan Animation / Execution
    public func performFullScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        scanStatusText = "Initializing analyzer..."
        
        Task {
            refreshDeviceStorage()
            checkPermissions()
            
            // If permissions not yet asked, request them gracefully
            if !self.isDemoMode && self.photoAuthStatus == .notDetermined {
                _ = await self.requestPhotoPermission()
            }
            
            // Stage 1: Photos & Duplicates
            self.scanProgress = 0.25
            self.scanStatusText = "Scanning photo library for duplicates..."
            
            if !self.isDemoMode && (self.photoAuthStatus == .authorized || self.photoAuthStatus == .limited) {
                await PhotoScannerManager.shared.scanLivePhotos()
            }
            
            // Stage 2: Screenshots
            self.scanProgress = 0.65
            self.scanStatusText = "Analyzing screenshots & burst captures..."
            
            // Stage 3: Large Videos
            self.scanProgress = 0.90
            self.scanStatusText = "Detecting heavy 4K videos & files..."
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.scanProgress = 1.0
            self.scanStatusText = "Scan complete!"
            self.isScanning = false
            HapticManager.notification(type: .success)
        }
    }

    // MARK: - Permissions Check (Photos Only)
    public func checkPermissions() {
        self.photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public func requestPhotoPermission() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.photoAuthStatus = status
        return status == .authorized || status == .limited
    }
    
    // MARK: - Clean Execution (The Safety Core Loop)
    public func executeClean() async -> Int64 {
        let freedAmount = totalRecoverableBytes
        
        // 1. Collect ALL assets to delete in a single batch
        var allAssetIdentifiersToDelete: [String] = []
        
        if !isDemoMode {
            for group in similarGroups {
                let ids = group.photos.filter { group.selectedPhotoIds.contains($0.id) }.compactMap { $0.assetIdentifier }
                allAssetIdentifiersToDelete.append(contentsOf: ids)
            }
            
            let screenshotAssets = screenshots.filter { selectedScreenshotIds.contains($0.id) }.compactMap { $0.assetIdentifier }
            allAssetIdentifiersToDelete.append(contentsOf: screenshotAssets)
            
            let videoAssets = largeVideos.filter { selectedVideoIds.contains($0.id) }.compactMap { $0.assetIdentifier }
            allAssetIdentifiersToDelete.append(contentsOf: videoAssets)
            
            let blurryAssets = blurryPhotos.filter { selectedBlurryIds.contains($0.id) }.compactMap { $0.assetIdentifier }
            allAssetIdentifiersToDelete.append(contentsOf: blurryAssets)
            
            // Deduplicate
            allAssetIdentifiersToDelete = Array(Set(allAssetIdentifiersToDelete))
            
            if !allAssetIdentifiersToDelete.isEmpty {
                // SINGLE delete call -> single system prompt!
                let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: allAssetIdentifiersToDelete)
                guard success else {
                    // User tapped "Cancel" or denied in the system dialog
                    return 0
                }
            }
        }
        
        // 2. Remove deleted items from memory collections
        for i in 0..<similarGroups.count {
            let selected = similarGroups[i].selectedPhotoIds
            similarGroups[i].photos.removeAll { selected.contains($0.id) }
            similarGroups[i].selectedPhotoIds.removeAll()
        }
        similarGroups.removeAll { $0.photos.count <= 1 }
        
        let screenshotIdsToRemove = selectedScreenshotIds
        screenshots.removeAll { screenshotIdsToRemove.contains($0.id) }
        selectedScreenshotIds.removeAll()
        
        let videoIdsToRemove = selectedVideoIds
        largeVideos.removeAll { videoIdsToRemove.contains($0.id) }
        selectedVideoIds.removeAll()
        
        let blurryIdsToRemove = selectedBlurryIds
        blurryPhotos.removeAll { blurryIdsToRemove.contains($0.id) }
        selectedBlurryIds.removeAll()
        
        // 3. Update stats immediately
        self.recordFreedStorage(freedBytes: freedAmount)
        HapticManager.notification(type: .success)
        return freedAmount
    }
    
    // MARK: - Direct Category Deletion Methods
    @discardableResult
    public func deleteScreenshots(ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return true }
        let itemsToDelete = screenshots.filter { ids.contains($0.id) }
        let assetIds = itemsToDelete.compactMap { $0.assetIdentifier }
        let freedBytes = itemsToDelete.reduce(0) { $0 + $1.fileSize }
        
        if !isDemoMode && !assetIds.isEmpty {
            let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: assetIds)
            guard success else { return false }
        }
        
        let idSet = Set(ids)
        screenshots.removeAll { idSet.contains($0.id) }
        selectedScreenshotIds.subtract(idSet)
        recordFreedStorage(freedBytes: freedBytes)
        HapticManager.notification(type: .success)
        return true
    }

    @discardableResult
    public func deleteBlurryPhotos(ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return true }
        let itemsToDelete = blurryPhotos.filter { ids.contains($0.id) }
        let assetIds = itemsToDelete.compactMap { $0.assetIdentifier }
        let freedBytes = itemsToDelete.reduce(0) { $0 + $1.fileSize }
        
        if !isDemoMode && !assetIds.isEmpty {
            let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: assetIds)
            guard success else { return false }
        }
        
        let idSet = Set(ids)
        blurryPhotos.removeAll { idSet.contains($0.id) }
        selectedBlurryIds.subtract(idSet)
        recordFreedStorage(freedBytes: freedBytes)
        HapticManager.notification(type: .success)
        return true
    }

    @discardableResult
    public func deleteSimilarPhotos(ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return true }
        var allAssetIds: [String] = []
        var freedBytes: Int64 = 0
        let idSet = Set(ids)
        
        for group in similarGroups {
            for photo in group.photos where idSet.contains(photo.id) {
                if let assetId = photo.assetIdentifier {
                    allAssetIds.append(assetId)
                }
                freedBytes += photo.fileSize
            }
        }
        
        if !isDemoMode && !allAssetIds.isEmpty {
            let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: allAssetIds)
            guard success else { return false }
        }
        
        for i in 0..<similarGroups.count {
            similarGroups[i].photos.removeAll { idSet.contains($0.id) }
            similarGroups[i].selectedPhotoIds.subtract(idSet)
        }
        similarGroups.removeAll { $0.photos.count <= 1 }
        recordFreedStorage(freedBytes: freedBytes)
        HapticManager.notification(type: .success)
        return true
    }

    @discardableResult
    public func deleteLargeVideos(ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return true }
        let itemsToDelete = largeVideos.filter { ids.contains($0.id) }
        let assetIds = itemsToDelete.compactMap { $0.assetIdentifier }
        let freedBytes = itemsToDelete.reduce(0) { $0 + $1.fileSize }
        
        if !isDemoMode && !assetIds.isEmpty {
            let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: assetIds)
            guard success else { return false }
        }
        
        let idSet = Set(ids)
        largeVideos.removeAll { idSet.contains($0.id) }
        selectedVideoIds.subtract(idSet)
        recordFreedStorage(freedBytes: freedBytes)
        HapticManager.notification(type: .success)
        return true
    }
}
