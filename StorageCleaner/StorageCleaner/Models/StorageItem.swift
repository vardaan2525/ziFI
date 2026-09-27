import Foundation
import UIKit
import Photos

// MARK: - Category Types (100% Photos & Videos)
public enum CleanCategory: String, CaseIterable, Identifiable {
    case similarPhotos = "Similar Photos"
    case screenshots = "Screenshots"
    case largeVideos = "Large Videos"
    case blurryPhotos = "Blurry Photos"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .screenshots: return "iphone"
        case .largeVideos: return "video.badge.waveform"
        case .blurryPhotos: return "camera.metering.matrix"
        }
    }
    
    public var colorName: String {
        switch self {
        case .similarPhotos: return "cleanIndigo"
        case .screenshots: return "cleanCyan"
        case .largeVideos: return "cleanPurple"
        case .blurryPhotos: return "cleanRose"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .similarPhotos: return "Find & keep best shots"
        case .screenshots: return "Bulk clean old captures"
        case .largeVideos: return "Compress or delete"
        case .blurryPhotos: return "Out of focus & shaky"
        }
    }
}


// MARK: - Cleanable Photo Item
public struct PhotoItem: Identifiable, Hashable, Codable {
    public let id: String
    public let assetIdentifier: String?
    public let creationDate: Date
    public let fileSize: Int64
    public let pixelWidth: Int
    public let pixelHeight: Int
    public var isFavorite: Bool
    public var isScreenshot: Bool
    public var blurScore: Double // 0 (sharp) to 1 (very blurry)
    public var mockColorIndex: Int
    public var mockTitle: String?
    
    public init(
        id: String = UUID().uuidString,
        assetIdentifier: String? = nil,
        creationDate: Date = Date(),
        fileSize: Int64,
        pixelWidth: Int = 3024,
        pixelHeight: Int = 4032,
        isFavorite: Bool = false,
        isScreenshot: Bool = false,
        blurScore: Double = 0.1,
        mockColorIndex: Int = 0,
        mockTitle: String? = nil
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.creationDate = creationDate
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isFavorite = isFavorite
        self.isScreenshot = isScreenshot
        self.blurScore = blurScore
        self.mockColorIndex = mockColorIndex
        self.mockTitle = mockTitle
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var resolutionString: String {
        "\(pixelWidth) × \(pixelHeight)"
    }
}

// MARK: - Similar Photo Group
public struct SimilarPhotoGroup: Identifiable, Hashable {
    public let id: String
    public var photos: [PhotoItem]
    public var bestPhotoId: String
    public var selectedPhotoIds: Set<String>
    public var groupDate: Date
    public var similarityScore: Double // e.g. 0.95
    
    public init(
        id: String = UUID().uuidString,
        photos: [PhotoItem],
        bestPhotoId: String,
        selectedPhotoIds: Set<String> = [],
        groupDate: Date = Date(),
        similarityScore: Double = 0.94
    ) {
        self.id = id
        self.photos = photos
        self.bestPhotoId = bestPhotoId
        self.selectedPhotoIds = selectedPhotoIds
        self.groupDate = groupDate
        self.similarityScore = similarityScore
    }
    
    public var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }
    
    public var selectedSize: Int64 {
        photos.filter { selectedPhotoIds.contains($0.id) }.reduce(0) { $0 + $1.fileSize }
    }
    
    public var potentialSavingsSize: Int64 {
        // Excludes the best photo from deletion count
        photos.filter { $0.id != bestPhotoId }.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Video Item
public struct VideoItem: Identifiable, Hashable {
    public let id: String
    public let assetIdentifier: String?
    public let creationDate: Date
    public let fileSize: Int64
    public let duration: TimeInterval
    public let pixelWidth: Int
    public let pixelHeight: Int
    public var mockColorIndex: Int
    public var mockTitle: String?
    
    public init(
        id: String = UUID().uuidString,
        assetIdentifier: String? = nil,
        creationDate: Date = Date(),
        fileSize: Int64,
        duration: TimeInterval,
        pixelWidth: Int = 1920,
        pixelHeight: Int = 1080,
        mockColorIndex: Int = 0,
        mockTitle: String? = nil
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.creationDate = creationDate
        self.fileSize = fileSize
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mockColorIndex = mockColorIndex
        self.mockTitle = mockTitle
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var resolutionString: String {
        if pixelWidth >= 3840 || pixelHeight >= 2160 {
            return "4K UHD"
        } else if pixelWidth >= 1920 || pixelHeight >= 1080 {
            return "1080p FHD"
        } else {
            return "720p HD"
        }
    }
    
    public var estimatedCompressedSize: Int64 {
        return Int64(Double(fileSize) * 0.28)
    }
    
    public var estimatedCompressionSavings: Int64 {
        return fileSize - estimatedCompressedSize
    }
}


// MARK: - Device Storage Info
public struct DeviceStorageInfo: Equatable {
    public var totalSpace: Int64
    public var freeSpace: Int64
    public var usedSpace: Int64
    
    public init(totalSpace: Int64, freeSpace: Int64, usedSpace: Int64) {
        self.totalSpace = totalSpace
        self.freeSpace = freeSpace
        self.usedSpace = usedSpace
    }
    
    public var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }
    
    public var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace)
    }
    
    public var formattedTotal: String {
        formatStorageCapacity(totalSpace, isTotal: true)
    }
    
    public var formattedFree: String {
        formatStorageCapacity(freeSpace)
    }
    
    public var formattedUsed: String {
        formatStorageCapacity(usedSpace)
    }
}

public func formatStorageCapacity(_ bytes: Int64, isTotal: Bool = false) -> String {
    let decimalGB = Double(bytes) / 1_000_000_000.0
    
    // Always format ~1 TB storage capacity as 1024 GB (instead of 1.02 TB)
    if isTotal && decimalGB >= 900 && decimalGB <= 1150 {
        return "1024 GB"
    } else if isTotal && decimalGB > 1150 {
        return "\(Int(round(decimalGB))) GB"
    }
    
    if decimalGB >= 1.0 {
        let formatted = String(format: "%.2f", decimalGB)
        if formatted.hasSuffix(".00") {
            return "\(Int(decimalGB)) GB"
        } else if formatted.hasSuffix("0") {
            return String(format: "%.1f GB", decimalGB)
        } else {
            return "\(formatted) GB"
        }
    } else if bytes >= 1_000_000 {
        let mb = Double(bytes) / 1_000_000.0
        return String(format: "%.1f MB", mb)
    } else if bytes >= 1_000 {
        let kb = Double(bytes) / 1_000.0
        return String(format: "%.1f KB", kb)
    } else {
        return "\(bytes) B"
    }
}

// MARK: - Unified Device Storage Calculator (Matches iOS Settings > iPhone Storage)
public struct DeviceStorageCalculator {
    public static let sharedSuiteName = "group.com.vardaan.StorageCleanerApp"
    
    /// Normalizes raw disk bytes to Apple's standard commercial hardware storage tiers
    public static func normalizeToCommercialTier(_ rawBytes: Int64) -> Int64 {
        let decimalGB = Double(rawBytes) / 1_000_000_000.0
        if decimalGB <= 20 {
            return 16 * 1_000_000_000
        } else if decimalGB <= 40 {
            return 32 * 1_000_000_000
        } else if decimalGB <= 80 {
            return 64 * 1_000_000_000
        } else if decimalGB <= 160 {
            return 128 * 1_000_000_000
        } else if decimalGB <= 320 {
            return 256 * 1_000_000_000
        } else if decimalGB <= 640 {
            return 512 * 1_000_000_000
        } else if decimalGB <= 1280 {
            return 1024 * 1_000_000_000 // 1024 GB (1 TB)
        } else {
            return 2048 * 1_000_000_000 // 2 TB
        }
    }
    
    /// Queries the real available capacity for important usage (matching iOS Settings free space)
    public static func getAvailableCapacity() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage,
           available > 0 {
            return available
        }
        
        let urlsToTry: [URL] = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
            URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        ].compactMap { $0 }
        
        for url in urlsToTry {
            if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
               let available = values.volumeAvailableCapacityForImportantUsage,
               available > 0 {
                return available
            }
        }
        return nil
    }
    
    /// Queries raw unallocated disk free bytes (systemFreeSize)
    public static func getRawFreeBytes() -> Int64 {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value, free > 0 {
            return free
        }
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let free = values.volumeAvailableCapacity, free > 0 {
            return Int64(free)
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value, free > 0 {
            return free
        }
        return 618 * 1_000_000_000
    }
    
    /// Queries the total hardware capacity of the device
    public static func getTotalCapacity() -> Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        if let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey]),
           let size = values.volumeTotalCapacity, size > 0 {
            return normalizeToCommercialTier(Int64(size))
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let size = (attrs[.systemSize] as? NSNumber)?.int64Value, size > 0 {
            return normalizeToCommercialTier(size)
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let size = (attrs[.systemSize] as? NSNumber)?.int64Value, size > 0 {
            return normalizeToCommercialTier(size)
        }
        return 1024 * 1_000_000_000
    }
    
    public static func calculateLive() -> (total: Int64, free: Int64, used: Int64, pct: Double) {
        let total = getTotalCapacity()
        let rawFree = getRawFreeBytes()
        
        let sharedDefaults = UserDefaults(suiteName: sharedSuiteName) ?? UserDefaults.standard
        
        // 1. Manual Calibration Check: if user calibrated an exact baseline in Settings
        if let calibratedUsed = sharedDefaults.object(forKey: "zifi_calibrated_used_bytes") as? Int64, calibratedUsed > 0 {
            let freedSince = sharedDefaults.object(forKey: "zifi_freed_since_calibration") as? Int64 ?? 0
            let effectiveUsed = max(0, calibratedUsed - freedSince)
            let effectiveFree = max(0, total - effectiveUsed)
            let pct = total > 0 ? min(1.0, max(0.0, Double(effectiveUsed) / Double(total))) : 0.0
            return (total, effectiveFree, effectiveUsed, pct)
        }
        
        // 2. Exact System Storage Calculation (Matching iOS Settings > iPhone Storage)
        // In iOS, volumeAvailableCapacityForImportantUsageKey reports the exact available space
        // that iOS Settings displays. Free space = available capacity, Used space = Total - Free space.
        var freeBytes: Int64 = 0
        if let available = getAvailableCapacity(), available > 0 {
            freeBytes = available
        } else {
            freeBytes = rawFree
        }
        
        // Respect any space freed in ziFI that is pending OS garbage collection
        let pendingFreed = sharedDefaults.object(forKey: "zifi_pending_freed_bytes") as? Int64 ?? 0
        let effectiveFree = min(total, max(0, freeBytes + pendingFreed))
        let effectiveUsed = max(0, total - effectiveFree)
        let pct = total > 0 ? min(1.0, max(0.0, Double(effectiveUsed) / Double(total))) : 0.0
        return (total, effectiveFree, effectiveUsed, pct)
    }
}

// MARK: - Device Model Identifier (e.g. iPhone 15 Pro, iPhone 14)
public struct DeviceModelHelper {
    public static var currentModelName: String {
        #if targetEnvironment(simulator)
        if let simModel = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return mapIdentifierToName(simModel)
        }
        #endif
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return mapIdentifierToName(identifier)
    }
    
    private static func mapIdentifierToName(_ identifier: String) -> String {
        switch identifier {
        // iPhone 16 Series
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        // iPhone 15 Series
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        // iPhone 14 Series
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        // iPhone 13 Series
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        // iPhone SE
        case "iPhone14,6": return "iPhone SE (3rd Gen)"
        case "iPhone12,8": return "iPhone SE (2nd Gen)"
        // iPhone 12 Series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        // iPhone 11 Series
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        // iPhone XS / XR / X
        case "iPhone11,2": return "iPhone XS"
        case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
        case "iPhone11,8": return "iPhone XR"
        case "iPhone10,3", "iPhone10,6": return "iPhone X"
        // iPhone 8 / 7
        case "iPhone10,1", "iPhone10,4": return "iPhone 8"
        case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
        case "iPhone9,1", "iPhone9,3": return "iPhone 7"
        case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
        default:
            if identifier.starts(with: "iPhone") {
                return "iPhone"
            } else if identifier.starts(with: "iPad") {
                return "iPad"
            }
            return UIDevice.current.model
        }
    }
}

