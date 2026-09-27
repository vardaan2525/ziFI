import Foundation
import UIKit

public struct MockDataService {
    public static func generateSimilarPhotos() -> [SimilarPhotoGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        // Group 1: Sunset at the beach burst (4 photos)
        let beach1 = PhotoItem(
            id: "beach-burst-1",
            creationDate: calendar.date(byAdding: .minute, value: -120, to: now)!,
            fileSize: 4_200_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            isFavorite: true,
            blurScore: 0.05,
            mockColorIndex: 0,
            mockTitle: "Golden Hour Ocean Peak"
        )
        let beach2 = PhotoItem(
            id: "beach-burst-2",
            creationDate: calendar.date(byAdding: .second, value: -7198, to: now)!,
            fileSize: 4_150_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            blurScore: 0.12,
            mockColorIndex: 1,
            mockTitle: "Golden Hour Ocean Frame 2"
        )
        let beach3 = PhotoItem(
            id: "beach-burst-3",
            creationDate: calendar.date(byAdding: .second, value: -7196, to: now)!,
            fileSize: 4_100_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            blurScore: 0.18,
            mockColorIndex: 2,
            mockTitle: "Golden Hour Ocean Frame 3"
        )
        let beach4 = PhotoItem(
            id: "beach-burst-4",
            creationDate: calendar.date(byAdding: .second, value: -7194, to: now)!,
            fileSize: 3_950_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            blurScore: 0.22,
            mockColorIndex: 3,
            mockTitle: "Golden Hour Ocean Frame 4"
        )
        let group1 = SimilarPhotoGroup(
            id: "group-beach",
            photos: [beach1, beach2, beach3, beach4],
            bestPhotoId: beach1.id,
            selectedPhotoIds: [],
            groupDate: beach1.creationDate,
            similarityScore: 0.96
        )
        
        // Group 2: Coffee & Laptop cafe session (3 photos)
        let cafe1 = PhotoItem(
            id: "cafe-1",
            creationDate: calendar.date(byAdding: .day, value: -1, to: now)!,
            fileSize: 3_800_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            blurScore: 0.08,
            mockColorIndex: 4,
            mockTitle: "Espresso & Workspace - Clear"
        )
        let cafe2 = PhotoItem(
            id: "cafe-2",
            creationDate: calendar.date(byAdding: .second, value: -86395, to: now)!,
            fileSize: 3_720_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            blurScore: 0.29,
            mockColorIndex: 5,
            mockTitle: "Espresso & Workspace - Alt"
        )
        let cafe3 = PhotoItem(
            id: "cafe-3",
            creationDate: calendar.date(byAdding: .second, value: -86390, to: now)!,
            fileSize: 3_680_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            blurScore: 0.35,
            mockColorIndex: 6,
            mockTitle: "Espresso & Workspace - Blurry"
        )
        let group2 = SimilarPhotoGroup(
            id: "group-cafe",
            photos: [cafe1, cafe2, cafe3],
            bestPhotoId: cafe1.id,
            selectedPhotoIds: [],
            groupDate: cafe1.creationDate,
            similarityScore: 0.92
        )
        
        // Group 3: Mountain hike panoramic (2 photos)
        let hike1 = PhotoItem(
            id: "hike-1",
            creationDate: calendar.date(byAdding: .day, value: -3, to: now)!,
            fileSize: 5_900_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            isFavorite: true,
            blurScore: 0.04,
            mockColorIndex: 7,
            mockTitle: "Alpine Ridge Vista 1"
        )
        let hike2 = PhotoItem(
            id: "hike-2",
            creationDate: calendar.date(byAdding: .second, value: -259197, to: now)!,
            fileSize: 5_750_000,
            pixelWidth: 4032,
            pixelHeight: 3024,
            blurScore: 0.14,
            mockColorIndex: 8,
            mockTitle: "Alpine Ridge Vista 2"
        )
        let group3 = SimilarPhotoGroup(
            id: "group-hike",
            photos: [hike1, hike2],
            bestPhotoId: hike1.id,
            selectedPhotoIds: [],
            groupDate: hike1.creationDate,
            similarityScore: 0.98
        )
        
        // Group 4: Cute Golden Retriever Puppy (3 photos)
        let dog1 = PhotoItem(
            id: "dog-1",
            creationDate: calendar.date(byAdding: .day, value: -5, to: now)!,
            fileSize: 4_500_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            isFavorite: true,
            blurScore: 0.03,
            mockColorIndex: 9,
            mockTitle: "Puppy Head Tilt"
        )
        let dog2 = PhotoItem(
            id: "dog-2",
            creationDate: calendar.date(byAdding: .second, value: -431998, to: now)!,
            fileSize: 4_350_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            blurScore: 0.25,
            mockColorIndex: 10,
            mockTitle: "Puppy Blink"
        )
        let dog3 = PhotoItem(
            id: "dog-3",
            creationDate: calendar.date(byAdding: .second, value: -431995, to: now)!,
            fileSize: 4_420_000,
            pixelWidth: 3024,
            pixelHeight: 4032,
            blurScore: 0.31,
            mockColorIndex: 11,
            mockTitle: "Puppy Motion"
        )
        let group4 = SimilarPhotoGroup(
            id: "group-dog",
            photos: [dog1, dog2, dog3],
            bestPhotoId: dog1.id,
            selectedPhotoIds: [],
            groupDate: dog1.creationDate,
            similarityScore: 0.94
        )
        
        return [group1, group2, group3, group4]
    }
    
    public static func generateScreenshots() -> [PhotoItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            PhotoItem(
                id: "screen-1",
                creationDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
                fileSize: 2_800_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 12,
                mockTitle: "Receipt & Order Confirmation #892"
            ),
            PhotoItem(
                id: "screen-2",
                creationDate: calendar.date(byAdding: .hour, value: -5, to: now)!,
                fileSize: 3_100_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 13,
                mockTitle: "Flight Boarding Pass Seat 14A"
            ),
            PhotoItem(
                id: "screen-3",
                creationDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                fileSize: 2_400_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 14,
                mockTitle: "Twitter Tech Thread Bookmark"
            ),
            PhotoItem(
                id: "screen-4",
                creationDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                fileSize: 3_900_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 15,
                mockTitle: "Instagram Recipe Reel Screenshot"
            ),
            PhotoItem(
                id: "screen-5",
                creationDate: calendar.date(byAdding: .day, value: -4, to: now)!,
                fileSize: 2_150_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 16,
                mockTitle: "Wi-Fi Password & Hotel Booking"
            ),
            PhotoItem(
                id: "screen-6",
                creationDate: calendar.date(byAdding: .day, value: -8, to: now)!,
                fileSize: 4_200_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 17,
                mockTitle: "App Store Subscription Notice"
            ),
            PhotoItem(
                id: "screen-7",
                creationDate: calendar.date(byAdding: .day, value: -15, to: now)!,
                fileSize: 1_950_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 18,
                mockTitle: "Two-Factor Auth Backup Codes"
            ),
            PhotoItem(
                id: "screen-8",
                creationDate: calendar.date(byAdding: .day, value: -30, to: now)!,
                fileSize: 3_600_000,
                pixelWidth: 1179,
                pixelHeight: 2556,
                isScreenshot: true,
                mockColorIndex: 19,
                mockTitle: "Old Map Directions to Venue"
            )
        ]
    }
    
    public static func generateLargeVideos() -> [VideoItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            VideoItem(
                id: "video-1",
                creationDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                fileSize: 1_450_000_000, // 1.45 GB
                duration: 684, // 11m 24s
                pixelWidth: 3840,
                pixelHeight: 2160,
                mockColorIndex: 20,
                mockTitle: "Concert Live Performance 4K 60fps"
            ),
            VideoItem(
                id: "video-2",
                creationDate: calendar.date(byAdding: .day, value: -5, to: now)!,
                fileSize: 890_000_000, // 890 MB
                duration: 492, // 8m 12s
                pixelWidth: 3840,
                pixelHeight: 2160,
                mockColorIndex: 21,
                mockTitle: "Road Trip Coastal Drive 4K"
            ),
            VideoItem(
                id: "video-3",
                creationDate: calendar.date(byAdding: .day, value: -12, to: now)!,
                fileSize: 540_000_000, // 540 MB
                duration: 320, // 5m 20s
                pixelWidth: 1920,
                pixelHeight: 1080,
                mockColorIndex: 22,
                mockTitle: "Screen Recording: Demo & Walkthrough"
            ),
            VideoItem(
                id: "video-4",
                creationDate: calendar.date(byAdding: .day, value: -20, to: now)!,
                fileSize: 380_000_000, // 380 MB
                duration: 210, // 3m 30s
                pixelWidth: 1920,
                pixelHeight: 1080,
                mockColorIndex: 23,
                mockTitle: "Dog Agility Training Slow-Mo"
            ),
            VideoItem(
                id: "video-5",
                creationDate: calendar.date(byAdding: .day, value: -35, to: now)!,
                fileSize: 260_000_000, // 260 MB
                duration: 145, // 2m 25s
                pixelWidth: 1920,
                pixelHeight: 1080,
                mockColorIndex: 24,
                mockTitle: "Cooking Masterclass Tutorial"
            )
        ]
    }
    

    
    public static func generateBlurryPhotos() -> [PhotoItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            PhotoItem(
                id: "blur-1",
                creationDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                fileSize: 3_900_000,
                blurScore: 0.88,
                mockColorIndex: 25,
                mockTitle: "Pocket Accidental Shot (Black)"
            ),
            PhotoItem(
                id: "blur-2",
                creationDate: calendar.date(byAdding: .day, value: -3, to: now)!,
                fileSize: 4_100_000,
                blurScore: 0.74,
                mockColorIndex: 26,
                mockTitle: "Night Motion Blur Walking"
            ),
            PhotoItem(
                id: "blur-3",
                creationDate: calendar.date(byAdding: .day, value: -6, to: now)!,
                fileSize: 3_450_000,
                blurScore: 0.68,
                mockColorIndex: 27,
                mockTitle: "Out of Focus Car Plate"
            ),
            PhotoItem(
                id: "blur-4",
                creationDate: calendar.date(byAdding: .day, value: -10, to: now)!,
                fileSize: 4_600_000,
                blurScore: 0.82,
                mockColorIndex: 28,
                mockTitle: "Shaky Concert Fireworks"
            )
        ]
    }
    

    
    public static func generateDeviceStorage() -> DeviceStorageInfo {
        let total: Int64 = 128 * 1024 * 1024 * 1024 // 128 GB
        let used: Int64 = 94 * 1024 * 1024 * 1024  // 94 GB
        let free: Int64 = total - used              // 34 GB
        return DeviceStorageInfo(totalSpace: total, freeSpace: free, usedSpace: used)
    }
}
