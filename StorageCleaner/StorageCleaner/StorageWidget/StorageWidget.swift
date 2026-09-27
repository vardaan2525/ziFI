import WidgetKit
import SwiftUI

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

// MARK: - Real Storage Model for Widget
public struct StorageInfo {
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let usedBytes: Int64
    public let usedPercentage: Double
    
    public static func current() -> StorageInfo {
        // Read directly from App Group if synced by the main app
        if let sharedDefaults = UserDefaults(suiteName: DeviceStorageCalculator.sharedSuiteName),
           let total = sharedDefaults.object(forKey: "shared_total_bytes") as? Int64, total > 0,
           let used = sharedDefaults.object(forKey: "shared_used_bytes") as? Int64,
           let free = sharedDefaults.object(forKey: "shared_free_bytes") as? Int64 {
            let pct = sharedDefaults.double(forKey: "shared_used_percentage")
            return StorageInfo(
                totalBytes: total,
                freeBytes: free,
                usedBytes: used,
                usedPercentage: pct
            )
        }
        
        let metrics = DeviceStorageCalculator.calculateLive()
        return StorageInfo(
            totalBytes: metrics.total,
            freeBytes: metrics.free,
            usedBytes: metrics.used,
            usedPercentage: metrics.pct
        )
    }
    
    private static func formatSize(_ bytes: Int64, isTotal: Bool = false) -> String {
        let decimalGB = Double(bytes) / 1_000_000_000.0
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

    public var formattedUsed: String {
        Self.formatSize(usedBytes)
    }
    
    public var formattedFree: String {
        Self.formatSize(freeBytes)
    }
    
    public var formattedTotal: String {
        Self.formatSize(totalBytes, isTotal: true)
    }
}

// MARK: - Timeline Entry
public struct StorageWidgetEntry: TimelineEntry {
    public let date: Date
    public let storage: StorageInfo
    
    public init(date: Date, storage: StorageInfo) {
        self.date = date
        self.storage = storage
    }
}

// MARK: - Timeline Provider
public struct StorageWidgetProvider: TimelineProvider {
    public init() {}
    
    public func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(date: Date(), storage: StorageInfo.current())
    }

    public func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let entry = StorageWidgetEntry(date: Date(), storage: StorageInfo.current())
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let current = StorageInfo.current()
        let entry = StorageWidgetEntry(date: Date(), storage: current)
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View
public struct StorageWidgetSmallView: View {
    public let entry: StorageWidgetEntry
    
    public init(entry: StorageWidgetEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("ziFI")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            // Gauge Ring
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 8)
                        .frame(width: 66, height: 66)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(entry.storage.usedPercentage))
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 66, height: 66)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(entry.storage.usedPercentage * 100))%")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("USED")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
            }
            
            Spacer(minLength: 0)
            
            // Footer stats
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("FREE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    Text(entry.storage.formattedFree)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("TOTAL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                    Text(entry.storage.formattedTotal)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget View
public struct StorageWidgetMediumView: View {
    public let entry: StorageWidgetEntry
    
    public init(entry: StorageWidgetEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        HStack(spacing: 18) {
            // Left: Gauge Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 10)
                    .frame(width: 86, height: 86)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(entry.storage.usedPercentage))
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 86, height: 86)
                
                VStack(spacing: 1) {
                    Text("\(Int(entry.storage.usedPercentage * 100))%")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("USED")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.leading, 4)
            
            // Right: Breakdown
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ziFI Storage")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(entry.storage.usedPercentage > 0.85 ? "Almost Full" : "Optimized")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(entry.storage.usedPercentage > 0.85 ? .orange : .cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, geo.size.width * CGFloat(entry.storage.usedPercentage)), height: 7)
                    }
                }
                .frame(height: 7)
                
                // Stats Row
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("USED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                        Text(entry.storage.formattedUsed)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FREE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                        Text(entry.storage.formattedFree)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.15))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                        Text(entry.storage.formattedTotal)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Entry View with Family Support
public struct StorageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: StorageWidgetEntry
    
    public init(entry: StorageWidgetEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        switch family {
        case .systemMedium:
            StorageWidgetMediumView(entry: entry)
        case .accessoryCircular:
            Gauge(value: entry.storage.usedPercentage) {
                Text("ziFI")
            } currentValueLabel: {
                Text("\(Int(entry.storage.usedPercentage * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive.fill")
                    Text("ziFI Storage")
                        .font(.headline)
                }
                Text("Free: \(entry.storage.formattedFree)")
                    .font(.caption)
                Gauge(value: entry.storage.usedPercentage) {}
                    .gaugeStyle(.accessoryLinear)
            }
        default:
            StorageWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Declaration
public struct StorageWidget: Widget {
    public let kind: String = "ziFIStorageWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StorageWidgetProvider()) { entry in
            StorageWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 16/255, green: 20/255, blue: 28/255), for: .widget)
        }
        .configurationDisplayName("ziFI Storage")
        .description("Track your iPhone's used and free storage space in real time.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
