import SwiftUI
import LocalAuthentication
import PhotosUI

public struct SecretVaultView: View {
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var selectedDetailPhoto: PhotoItem?
    @State private var photoToDelete: PhotoItem?
    @State private var showDeleteConfirmation: Bool = false
    
    public init() {}
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.appBackground.ignoresSafeArea()
                
                if vault.isUnlocked {
                    unlockedVaultContent
                } else {
                    lockedVaultContent
                }
            }
            .navigationTitle(vault.isUnlocked ? "Secret Vault" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        vault.lockVault()
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Back")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                if vault.isUnlocked {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticManager.impact(style: .medium)
                            vault.lockVault()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text("Lock")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.purpleAccent)
                        }
                    }
                }
            }
            .sheet(item: $selectedDetailPhoto) { (photo: PhotoItem) in
                VaultPhotoDetailSheet(photo: photo)
            }
            .confirmationDialog(
                "Remove Photo from Vault?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible,
                presenting: photoToDelete
            ) { (photo: PhotoItem) in
                Button("Remove from Vault", role: .destructive) {
                    vault.removePhoto(photo)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This photo will be permanently removed from your private vault.")
            }
        }
    }
    
    // MARK: - Locked State View (Apple Liquid Glass)
    private var lockedVaultContent: some View {
        VStack(spacing: 28) {
            Spacer()
            
            LiquidGlassCard(cornerRadius: 32, tintOpacity: 0.6) {
                VStack(spacing: 24) {
                    // Lock icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.purpleAccent.opacity(0.18))
                            .frame(width: 88, height: 88)
                        Circle()
                            .stroke(AppTheme.purpleAccent.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 88, height: 88)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(AppTheme.purpleAccent)
                    }
                    .padding(.top, 8)
                    
                    VStack(spacing: 8) {
                        Text("Private Vault")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.white)
                        Text("Protected with biometric hardware.\nNo unauthorized access.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let err = vault.authErrorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    
                    // Unlock button
                    Button(action: {
                        HapticManager.impact(style: .medium)
                        Task {
                            _ = await vault.authenticateWithDeviceOwner()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "faceid")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Unlock Vault")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "7C3AED"))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(28)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Unlocked State View
    private var unlockedVaultContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Status banner
                    LiquidGlassCard(cornerRadius: 16, tintOpacity: 0.5) {
                        HStack {
                            Image(systemName: "lock.open.fill")
                                .foregroundColor(.green)
                            Text("Vault Unlocked • Stored Securely")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(vault.vaultPhotos.count) saved")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(AppTheme.purpleAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    if vault.isImporting {
                        HStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text("Securing photos into vault...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    if vault.vaultPhotos.isEmpty {
                        emptyVaultView
                    } else {
                        // Photo Grid
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(vault.vaultPhotos) { item in
                                vaultGridCell(item: item)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            
            // Bottom Action Bar: PhotosPicker
            VStack {
                Divider().background(Color.white.opacity(0.08))
                
                PhotosPicker(
                    selection: $selectedPickerItems,
                    maxSelectionCount: 30,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add Photos from Gallery")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "7C3AED"))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial)
        }
        .onChange(of: selectedPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        _ = await vault.importImage(data: data, originalTitle: "Private Photo")
                    }
                }
                selectedPickerItems.removeAll()
            }
        }
    }
    
    private func vaultGridCell(item: PhotoItem) -> some View {
        let cellWidth = (UIScreen.main.bounds.width - 44) / 2
        
        return ZStack(alignment: .topTrailing) {
            Button(action: {
                HapticManager.impact(style: .light)
                selectedDetailPhoto = item
            }) {
                ZStack(alignment: .bottomLeading) {
                    MockThumbnailView(
                        assetIdentifier: item.assetIdentifier,
                        colorIndex: item.mockColorIndex,
                        title: item.mockTitle,
                        size: CGSize(width: cellWidth, height: 180),
                        isBest: false
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.mockTitle ?? "Private")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text(item.formattedSize)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.cyanAccent)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(6)
                    .padding(8)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Delete / Remove Button
            Button(action: {
                HapticManager.impact(style: .medium)
                photoToDelete = item
                showDeleteConfirmation = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 30, height: 30)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .padding(8)
        }
    }
    
    private var emptyVaultView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.purpleAccent.opacity(0.6))
            Text("No Photos in Vault")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Tap the button below to pick photos from your phone's gallery and keep them locked safely.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer(minLength: 60)
        }
    }
}

// MARK: - Vault Photo Detail Sheet (Preview & Removal)
public struct VaultPhotoDetailSheet: View {
    public let photo: PhotoItem
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportSuccess = false
    
    public init(photo: PhotoItem) {
        self.photo = photo
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    MockThumbnailView(
                        assetIdentifier: photo.assetIdentifier,
                        colorIndex: photo.mockColorIndex,
                        title: nil,
                        size: CGSize(width: UIScreen.main.bounds.width - 32, height: UIScreen.main.bounds.height * 0.6),
                        isBest: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    // Action controls
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                let ok = await vault.exportPhotoToLibrary(photo)
                                if ok { showingExportSuccess = true }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Save Back to Camera Roll")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.12))
                            )
                        }
                        
                        Button(role: .destructive, action: {
                            vault.removePhoto(photo)
                            dismiss()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                Text("Remove from Vault")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.85))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(photo.mockTitle ?? "Vault Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Exported to Photos", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This photo has been saved back to your Photo Library.")
            }
        }
    }
}
