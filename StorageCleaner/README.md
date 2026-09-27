# Cleanup Master: Storage Cleaner for iPhone 📱✨

Selection task for the **App Builder Intern** role  
*Reference App:* **Cleanup: Phone Storage Cleaner**

---

## 🌟 Executive Summary

**Cleanup Master** is a native iOS application built with **Swift and SwiftUI** targeting iOS 17+. It provides a fast, dependable core loop (**Scan ➔ Review ➔ Clean**) designed to help iPhone users safely recover gigabytes of valuable storage without risk of accidental data loss.

In accordance with the specification, all features are **100% free and unlocked**—there are no paywalls, subscriptions, or dark patterns.

---

## 🎯 Features Implemented

### 1. 📊 Storage Dashboard (Home Screen)
- **Real-Time Storage Gauge**: Displays used and available storage metrics using iOS file system APIs (`volumeTotalCapacityKey` and `volumeAvailableCapacityForImportantUsageKey`).
- **Dynamic Risk Coloring**: The circular gauge transitions from vibrant cyan to warning amber/rose when disk usage crosses 85%.
- **Scan Status & Animation**: Interactive "Scan Again" button with radar pulse animations and live stage progression text.
- **Recoverable Storage Metric**: Instantly surfaces total gigabytes/megabytes reclaimable across all categories.
- **Demo Mode vs. Device Mode Switcher**: A header toggle switch allowing instant simulation of 100+ sample items for quick simulator testing without requiring a populated photo library.

### 2. 📸 Similar Photos (Smart Duplicate Clustering)
- **Time-Proximity & Burst Clustering**: Groups photos captured in rapid succession (within 30 seconds or matching frame aspects).
- **Smart "Best Shot" Detection**:
  - Automatically identifies and flags the highest-quality photo in every cluster based on favorited status, highest pixel resolution, and sharpness score.
  - Automatically marks redundant extras for deletion while keeping the "Best Photo" safe.
- **Manual Control**:
  - Tap any photo to preview full-screen resolution and metadata.
  - One-tap "Make Best" button to swap the preferred photo in any group.
  - "Select Extras" / "Keep All" toggles per group and category-wide selection menu.

### 3. 📱 Screenshots Cleaner
- **Dedicated Capture Gallery**: Filters for `PHAssetMediaSubtypePhotoScreenshot`.
- **Organized Filtering**: Instant filtering by "All", "Older > 30 Days", or "Receipts & Notes".
- **Bulk Actions**: Quick "Select All" / "Deselect All" toolbar.
- **Full-Screen Inspection**: Tap to toggle deletion; tap the zoom button to inspect full-size boarding passes, receipts, or notes before deciding.

### 4. 🎬 Large Videos Cleaner & Compressor
- **Sorted by Size Descending**: Easily discover the heaviest 4K/1080p clips consuming the most space.
- **Quality & Duration Badges**: Clear visual tags for duration (`11:24`), resolution (`4K UHD`, `1080p FHD`), and file size (`1.45 GB`).
- **In-App Video Player**: Built-in preview player to verify clips prior to cleanup.
- **⚡️ Built-in Video Compressor (Bonus)**:
  - Compresses heavy videos using `AVAssetExportSession` (HEVC/Medium quality).
  - Shows estimated savings (typically saving **~70-75% storage** with virtually zero perceptible quality loss).

### 5. 👥 Duplicate Contacts Cleaner & Merger
- **Address Book Scanning**: Direct `CNContactStore` integration.
- **Multi-Vector Duplicate Detection**:
  - **Identical Names**: Matches exact full names and organization titles.
  - **Matching Phone Numbers**: Normalizes phone digits (ignoring symbols and spaces) to find duplicate entries with different naming conventions.
  - **Matching Email Addresses**: Finds cross-referenced email addresses.
  - **Ghost Contacts**: Detects empty cards with no phone number and no email.
- **Safe Contact Merger**: Merges all unique phone numbers, emails, and notes into the primary contact card and purges redundant duplicates via `CNSaveRequest`.
- **Merge Preview Modal**: Visual preview showing the final unified contact card before committing.

### 6. 🛡️ Review Before Delete (The Safety Gate)
- **Strict User Approval**: **Nothing is ever deleted without explicit user review and confirmation.**
- **Itemized Breakdown**:
  - Categorized list showing count and size for Similar Photos, Screenshots, Videos, Contacts, and Blurry Photos.
  - Horizontal thumbnail preview ribbon allowing users to visually inspect what is queued.
- **Safety Guarantee**: Clear notice explaining that media is relocated to the Apple Photos **"Recently Deleted"** album, allowing 30 days of recovery if needed.
- **Two-Step Confirmation**: Prevents accidental touches with confirmation haptics.

### 7. 🔒 Permissions Architecture & Graceful Fallbacks
- Comprehensive support for `PHAuthorizationStatus` and `CNAuthorizationStatus`:
  - **Authorized**: Full scanning capability.
  - **Limited Access (iOS 14+)**: Gracefully scans accessible assets with an informative banner.
  - **Denied / Restricted**: Clean empty state with instructions and a direct one-tap shortcut to iPhone Settings (`UIApplication.openSettingsURLString`).
- **Demo Mode**: Built-in sample generator guarantees an evaluator can test 100% of the app's functionality even if permissions are declined or when running in an empty iOS Simulator.

### 8. 🎁 Bonus Features Included
- 🏆 **Space Freed Celebration Screen**: High-energy celebratory screen with animated confetti particles, updated free storage stats, and lifetime cleanup counters.
- 🗂️ **Swipe-to-Clean Mode**: Tinder-style gesture deck. Swipe Right to Keep, Swipe Left to Trash, with instant Undo capability!
- 🌫️ **Blurry Photo Detector**: Scans library for out-of-focus or motion-blurred shots with numerical blur confidence scores.
- 🔐 **Private Secret Vault**: LocalAuthentication integration protecting private photos behind **Face ID, Touch ID, or 4-digit PIN**.
- 📅 **Calendar Clutter Cleaner**: Detects and purges expired calendar events and spam invites.

---

## 🛠️ How to Open & Run on Mac (for iPhone)

### Prerequisites
- macOS running Xcode 15 or Xcode 16/27.
- iOS 17.0+ Simulator or physical iPhone running iOS 17+.

### Step 1: Open in Xcode
In Terminal, navigate to the project directory and open the `.xcodeproj`:
```bash
cd StorageCleaner
open StorageCleaner.xcodeproj
```

### Step 2: Select iPhone Target & Scheme
1. In Xcode's top toolbar, click the scheme dropdown: ensure **`StorageCleaner`** is selected.
2. For the run destination, select any **iPhone Simulator** (e.g. `iPhone 16 Pro`, `iPhone 15`, `iPhone 14`) or your connected physical iPhone.

### Step 3: Build & Run
- Press `Cmd + R` (or click the **Play** button in Xcode).
- The app will compile and launch immediately in the iOS Simulator.



---

## 📐 Project Structure

```
StorageCleaner/
├── StorageCleaner.xcodeproj/       # Xcode project with StorageCleaner scheme
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/StorageCleaner.xcscheme
└── StorageCleaner/
    ├── StorageCleanerApp.swift     # Main @main App entrypoint
    ├── Info.plist                  # Privacy keys (Photos, Contacts, Face ID, Calendar)
    ├── Assets.xcassets/            # AppIcon & AccentColor asset catalogs
    ├── Core/
    │   ├── Theme.swift             # AppTheme (colors, gradients, haptics, GlassCard)
    │   ├── StorageManager.swift    # App-wide state coordinator & disk calculation
    │   ├── PhotoScannerManager.swift # PHPhotoLibrary scanning & deletion logic
    │   ├── ContactScannerManager.swift # CNContactStore duplicate detection & merger
    │   ├── VideoCompressor.swift   # AVAssetExportSession video compression service
    │   └── VaultManager.swift      # LocalAuthentication (Face ID / PIN) vault
    ├── Models/
    │   ├── StorageItem.swift       # PhotoItem, VideoItem, ContactItem, Groups
    │   └── MockDataService.swift   # Realistic simulation datasets
    └── Views/
        ├── Dashboard/              # DashboardView, StorageGaugeView, CategoryCardView
        ├── SimilarPhotos/          # SimilarPhotosView (best photo badge & grouping)
        ├── Screenshots/            # ScreenshotsCleanerView (grid & bulk select)
        ├── LargeVideos/            # LargeVideosView (player & compressor)
        ├── Contacts/               # DuplicateContactsView (merge detail preview)
        ├── Review/                 # ReviewBeforeDeleteView (the core safety gate)
        ├── Celebration/            # SpaceFreedCelebrationView (confetti & summary)
        ├── SwipeClean/             # SwipeCleanerView (gesture card deck)
        ├── BlurryPhotos/           # BlurryPhotosView (edge variance detection)
        ├── Vault/                  # SecretVaultView (biometric lock screen)
        ├── Calendar/               # CalendarCleanerView (expired clutter cleaner)
        └── Settings/               # SettingsView (permissions & privacy pledge)
```
