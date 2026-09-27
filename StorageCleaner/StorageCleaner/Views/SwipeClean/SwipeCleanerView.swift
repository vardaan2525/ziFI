import SwiftUI
import Photos

public struct SwipeCleanerView: View {
    @ObservedObject var storage = StorageManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var deck: [PhotoItem] = []
    @State private var trashBin: [PhotoItem] = []
    @State private var kept: [PhotoItem] = []

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isAnimatingAway: Bool = false
    @State private var showTrashBin: Bool = false
    @State private var isDeletingTrash: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var calloutBounce: Bool = false
    @State private var isDeckLoaded: Bool = false
    @State private var showConfetti: Bool = false
    @State private var confettiTriggerId: Int = 0
    @State private var hasPlayedFinishedConfetti: Bool = false

    public var isPresentedAsSheet: Bool = false

    public init(isPresentedAsSheet: Bool = false) {
        self.isPresentedAsSheet = isPresentedAsSheet
    }

    private let swipeThreshold: CGFloat = 100
    private var cardWidth: CGFloat {
        min(UIScreen.main.bounds.width - 40, 360)
    }

    private var isNearDelete: Bool { dragOffset.width < -swipeThreshold * 0.6 }
    private var isNearKeep: Bool { dragOffset.width > swipeThreshold * 0.6 }

    private let keptPhotoIdsKey = "storage_cleaner_kept_photo_ids"
    private let trashedPhotoIdsKey = "storage_cleaner_trashed_photo_ids"

    private var persistedKeptIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: keptPhotoIdsKey) ?? [])
    }

    private var persistedTrashIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: trashedPhotoIdsKey) ?? [])
    }

    private func saveKeptId(_ id: String) {
        var current = persistedKeptIds
        current.insert(id)
        UserDefaults.standard.set(Array(current), forKey: keptPhotoIdsKey)
    }

    private func removeKeptId(_ id: String) {
        var current = persistedKeptIds
        current.remove(id)
        UserDefaults.standard.set(Array(current), forKey: keptPhotoIdsKey)
    }

    private func saveTrashId(_ id: String) {
        var current = persistedTrashIds
        current.insert(id)
        UserDefaults.standard.set(Array(current), forKey: trashedPhotoIdsKey)
    }

    private func removeTrashId(_ id: String) {
        var current = persistedTrashIds
        current.remove(id)
        UserDefaults.standard.set(Array(current), forKey: trashedPhotoIdsKey)
    }

    private func clearAllTrashIds() {
        UserDefaults.standard.removeObject(forKey: trashedPhotoIdsKey)
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppTheme.appBackground.ignoresSafeArea()

                if !isDeckLoaded {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if deck.isEmpty {
                    finishedView
                } else {
                    VStack(spacing: 0) {
                        // Header
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 16)

                        // Progress bar
                        progressBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        // Card stack
                        cardStack
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Bottom controls
                        controls
                            .padding(.bottom, isPresentedAsSheet ? 16 : 10)
                    }
                }

                // Trash bin overlay sheet
                if showTrashBin {
                    trashBinSheet
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Celebration Confetti Particle Burst
                if showConfetti {
                    ConfettiView()
                        .id(confettiTriggerId)
                }
            }

            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isPresentedAsSheet {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            HapticManager.selection()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.appleBlue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button(role: .destructive) {
                                UserDefaults.standard.removeObject(forKey: keptPhotoIdsKey)
                                buildDeck()
                                HapticManager.notification(type: .success)
                            } label: {
                                Label("Reset Kept History", systemImage: "arrow.counterclockwise")
                            }

                            if !trashBin.isEmpty {
                                Button {
                                    restoreAllPhotos()
                                    HapticManager.notification(type: .success)
                                } label: {
                                    Label("Restore All Trashed (\(trashBin.count))", systemImage: "arrow.uturn.backward")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showTrashBin.toggle()
                            }
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(trashBin.isEmpty ? .white.opacity(0.3) : .white)

                                if !trashBin.isEmpty {
                                    Text("\(trashBin.count)")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundColor(.black)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Circle().fill(Color.white))
                                        .offset(x: 7, y: -7)
                                }
                            }
                        }
                        .disabled(trashBin.isEmpty)
                    }
                }
            }
            .onAppear {
                if !isDeckLoaded {
                    buildDeck()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Swipe Clean")
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                Text("Swipe left to trash, right to keep")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer()
            Text("\(deck.count)")
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.12))
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        let total = deck.count + kept.count + trashBin.count
        let done = kept.count + trashBin.count
        let pct = total > 0 ? CGFloat(done) / CGFloat(total) : 0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.55))
                    .frame(width: geo.size.width * pct, height: 2)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: pct)
            }
        }
        .frame(height: 2)
    }

    // MARK: - Card Stack (Fixed: no duplicate top card, correct background layering)
    private var cardStack: some View {
        ZStack {
            // Bottom background card (index 2)
            if deck.count > 2 {
                cardView(item: deck[2], isTop: false, stackIndex: 2)
                    .id(deck[2].id)
            }

            // Middle background card (index 1)
            if deck.count > 1 {
                cardView(item: deck[1], isTop: false, stackIndex: 1)
                    .id(deck[1].id)
            }

            // Interactive top card (index 0)
            if let top = deck.first {
                cardView(item: top, isTop: true, stackIndex: 0)
                    .id(top.id)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { g in
                                guard !isAnimatingAway else { return }
                                isDragging = true
                                dragOffset = g.translation
                            }
                            .onEnded { g in
                                guard !isAnimatingAway else { return }
                                isDragging = false
                                resolveSwipe(for: top, translation: g.translation)
                            }
                    )
            }
        }
        .padding(.horizontal, 20)
    }

    private func cardView(item: PhotoItem, isTop: Bool, stackIndex: Int) -> some View {
        let scale: CGFloat = isTop ? 1.0 : max(0.88, 1.0 - CGFloat(stackIndex) * 0.04)
        let yOffset: CGFloat = isTop ? 0 : CGFloat(stackIndex) * 12
        let rotation = isTop ? Double(dragOffset.width / 24) : 0
        let cardOpacity: Double = isTop ? 1.0 : max(0.4, 1.0 - Double(stackIndex) * 0.25)

        return ZStack(alignment: .bottom) {
            // Photo thumbnail view
            MockThumbnailView(
                assetIdentifier: item.assetIdentifier,
                colorIndex: item.mockColorIndex,
                title: nil,
                size: CGSize(width: cardWidth, height: min(480, UIScreen.main.bounds.height * 0.55)),
                isBest: false
            )
            .cornerRadius(20)

            // Swipe label overlays
            if isTop {
                VStack {
                    HStack {
                        // KEEP label
                        swipeLabel(dragOffset.width > 200 ? "KEEP 20" : "KEEP", color: .green, show: isNearKeep, rotate: -8)
                        Spacer()
                        // TRASH label
                        swipeLabel(dragOffset.width < -200 ? "TRASH 20" : "TRASH", color: .red, show: isNearDelete, rotate: 8)
                    }
                    .padding(22)
                    Spacer()
                }
            }

            // Bottom metadata strip
            if isTop {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.mockTitle ?? "Photo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.formattedSize)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                        Text(item.creationDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Rectangle()
                        .fill(.black.opacity(0.55))
                )
                .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
            }

            // Tint overlay on drag
            if isTop && isDragging {
                let tintOpacity = min(0.25, abs(Double(dragOffset.width)) / 400.0)
                let tintColor: Color = isNearDelete ? .red : (isNearKeep ? .green : .clear)
                RoundedRectangle(cornerRadius: 20)
                    .fill(tintColor.opacity(tintOpacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: cardWidth)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .offset(x: isTop ? dragOffset.width : 0,
                y: isTop ? dragOffset.height * 0.25 : yOffset)
        .opacity(cardOpacity)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: stackIndex)
        .shadow(color: .black.opacity(isTop ? 0.28 : 0.12), radius: isTop ? 24 : 10, y: 8)
        .zIndex(isTop ? 10 : Double(10 - stackIndex))
    }

    private func swipeLabel(_ text: String, color: Color, show: Bool, rotate: Double) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .black))
            .tracking(2)
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
            )
            .rotationEffect(.degrees(rotate))
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.7)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: show)
    }

    // MARK: - Bottom Controls
    private var controls: some View {
        VStack(spacing: 14) {
            // Animated Pointing Instruction towards the Delete/Trash button
            if !trashBin.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showTrashBin = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.down.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                            .offset(y: calloutBounce ? -4 : 3)
                        
                        Text("Tap to Delete All (\(trashBin.count)) Trashed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "1F1215").opacity(0.95))
                            .overlay(
                                Capsule()
                                    .stroke(Color.red.opacity(0.65), lineWidth: 1.5)
                            )
                            .shadow(color: Color.red.opacity(0.4), radius: 10, y: 4)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        calloutBounce = true
                    }
                }
            }


            HStack(spacing: 0) {
                // Undo
                controlButton(icon: "arrow.uturn.left", label: "Undo", tint: .white.opacity(0.35)) {
                    undoLast()
                }
                .disabled(trashBin.isEmpty && kept.isEmpty)
                .opacity((trashBin.isEmpty && kept.isEmpty) ? 0.25 : 1)

                Spacer()

                // Trash (tap)
                controlButton(icon: "trash", label: "Trash", tint: .red.opacity(0.85), size: 22) {
                    if let top = deck.first {
                        animateSwipe(direction: -1) { swipeToTrash(top) }
                    }
                }

                Spacer()

                // Keep (tap)
                controlButton(icon: "checkmark", label: "Keep", tint: .green.opacity(0.9), size: 22) {
                    if let top = deck.first {
                        animateSwipe(direction: 1) { swipeToKeep(top) }
                    }
                }

                Spacer()

                // Trash count / view bin with prominent red tint when not empty
                controlButton(
                    icon: "trash.fill",
                    label: trashBin.isEmpty ? "Trash (0)" : "Delete (\(trashBin.count))",
                    tint: trashBin.isEmpty ? .white.opacity(0.2) : .red
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showTrashBin = true
                    }
                }
                .opacity(trashBin.isEmpty ? 0.3 : 1)
            }
            .padding(.horizontal, 32)
        }
    }

    private func controlButton(
        icon: String,
        label: String,
        tint: Color,
        size: CGFloat = 18,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.impact(style: .light)
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: size, weight: .medium))
                    .foregroundColor(tint)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .stroke(tint.opacity(0.2), lineWidth: 1)
                    )
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tint.opacity(0.7))
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Finished State
    private var finishedView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 6) {
                Text("All Done!")
                    .font(.system(size: 44, weight: .black, design: .default))
                    .foregroundColor(.white)

                Text("You sorted \(kept.count + trashBin.count) photos")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Stats row
            HStack(spacing: 0) {
                statPill(label: "Kept", value: "\(kept.count)", color: .green)
                    .frame(maxWidth: .infinity)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 40)
                statPill(label: "Trashed", value: "\(trashBin.count)", color: .red.opacity(0.8))
                    .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Actions
            VStack(spacing: 12) {
                if !trashBin.isEmpty {
                    Button(action: {
                        HapticManager.impact(style: .heavy)
                        executeDeleteTrashBin()
                    }) {
                        HStack(spacing: 10) {
                            if isDeletingTrash {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Delete \(trashBin.count) Trashed Photos")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(14)
                    }
                    .disabled(isDeletingTrash)
                    .padding(.horizontal, 24)
                    .buttonStyle(ScaleButtonStyle())
                } else if kept.count > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 15, weight: .semibold))
                        Text("All sorted photos processed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 8)
                }

                Button(action: { sortMorePhotos() }) {
                    Text("Sort More Photos")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                .buttonStyle(ScaleButtonStyle())
            }

            Spacer()
        }
        .onAppear {
            if !hasPlayedFinishedConfetti {
                hasPlayedFinishedConfetti = true
                triggerConfetti()
            }
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(color.opacity(0.6))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Trash Bin Sheet (Direct single deletion of ONLY swiped items)
    private var trashBinSheet: some View {
        VStack(spacing: 0) {
            // Sheet handle + title
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trash Bin")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(trashBin.count) photos chosen by you to delete")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showTrashBin = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.06))

            // Trash items list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(trashBin) { item in
                        HStack(spacing: 14) {
                            MockThumbnailView(
                                assetIdentifier: item.assetIdentifier,
                                colorIndex: item.mockColorIndex,
                                title: nil,
                                size: CGSize(width: 52, height: 52),
                                isBest: false
                            )
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.mockTitle ?? "Photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(item.formattedSize)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.35))
                            }

                            Spacer()

                            Button(action: {
                                restoreSinglePhoto(item)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Restore")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        Divider().background(Color.white.opacity(0.05)).padding(.leading, 86)
                    }
                }
            }
            .frame(maxHeight: 280)

            // Actions
            VStack(spacing: 10) {
                Button(action: {
                    HapticManager.impact(style: .heavy)
                    executeDeleteTrashBin()
                }) {
                    HStack(spacing: 8) {
                        if isDeletingTrash {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Delete \(trashBin.count) Photos (\(formattedTrashSize))")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(14)
                }
                .disabled(isDeletingTrash)
                .padding(.horizontal, 20)
                .buttonStyle(ScaleButtonStyle())

                Button(action: {
                    restoreAllPhotos()
                }) {
                    Text("Restore All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.bottom, 4)
            }
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(white: 0.08))
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.top, 80)
        .ignoresSafeArea(edges: .bottom)
        .onTapGesture {}
    }

    // MARK: - Swipe Logic
    private func resolveSwipe(for item: PhotoItem, translation: CGSize) {
        if translation.width > swipeThreshold {
            animateSwipe(direction: 1) { swipeToKeep(item) }
        } else if translation.width < -swipeThreshold {
            animateSwipe(direction: -1) { swipeToTrash(item) }
        } else {
            withAnimation(.interpolatingSpring(stiffness: 320, damping: 24)) {
                dragOffset = .zero
            }
        }
    }

    private func animateSwipe(direction: CGFloat, completion: @escaping () -> Void) {
        guard !isAnimatingAway else { return }
        isAnimatingAway = true
        let targetX = direction * (UIScreen.main.bounds.width * 1.5)
        let targetY = dragOffset.height * 0.25
        
        withAnimation(.interpolatingSpring(stiffness: 240, damping: 22)) {
            dragOffset = CGSize(width: targetX, height: targetY)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                completion()
                dragOffset = .zero
                isAnimatingAway = false
                isDragging = false
            }
        }
    }

    private var formattedTrashSize: String {
        let totalBytes = trashBin.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    private func swipeToTrash(_ item: PhotoItem) {
        HapticManager.impact(style: .rigid)
        trashBin.append(item)
        saveTrashId(item.id)
        if !deck.isEmpty {
            deck.removeFirst()
        }
        if deck.isEmpty {
            hasPlayedFinishedConfetti = true
            triggerConfetti()
        }
    }

    private func swipeToKeep(_ item: PhotoItem) {
        HapticManager.impact(style: .soft)
        kept.append(item)
        saveKeptId(item.id)
        removeTrashId(item.id)
        if !deck.isEmpty {
            deck.removeFirst()
        }
        if deck.isEmpty {
            hasPlayedFinishedConfetti = true
            triggerConfetti()
        }
    }

    private func triggerConfetti() {
        showConfetti = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            confettiTriggerId += 1
            showConfetti = true
            HapticManager.notification(type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                showConfetti = false
            }
        }
    }

    private func undoLast() {
        HapticManager.selection()
        if let last = trashBin.popLast() {
            removeTrashId(last.id)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                deck.insert(last, at: 0)
            }
        } else if let last = kept.popLast() {
            removeKeptId(last.id)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                deck.insert(last, at: 0)
            }
        }
    }

    private func restoreSinglePhoto(_ item: PhotoItem) {
        HapticManager.selection()
        removeTrashId(item.id)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            trashBin.removeAll { $0.id == item.id }
            deck.insert(item, at: 0)
        }
        if trashBin.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showTrashBin = false
            }
        }
    }

    private func restoreAllPhotos() {
        HapticManager.selection()
        clearAllTrashIds()
        deck.insert(contentsOf: trashBin, at: 0)
        trashBin.removeAll()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showTrashBin = false
        }
    }

    // MARK: - Direct Trash Deletion (with safe confirmation and Recently Deleted fallback)
    private func executeDeleteTrashBin() {
        guard !trashBin.isEmpty else { return }
        HapticManager.impact(style: .heavy)
        
        let idsToDelete = trashBin.compactMap { $0.assetIdentifier }
        
        Task { @MainActor in
            isDeletingTrash = true
            if !storage.isDemoMode && !idsToDelete.isEmpty {
                let success = await PhotoScannerManager.shared.deleteAssets(withIdentifiers: idsToDelete)
                guard success else {
                    isDeletingTrash = false
                    return
                }
            }
            
            // Remove deleted items from storage manager so dashboard/categories update
            let deletedIdSet = Set(trashBin.map { $0.id })
            storage.screenshots.removeAll { deletedIdSet.contains($0.id) }
            storage.blurryPhotos.removeAll { deletedIdSet.contains($0.id) }
            for i in 0..<storage.similarGroups.count {
                storage.similarGroups[i].photos.removeAll { deletedIdSet.contains($0.id) }
            }
            
            let freedBytes = trashBin.reduce(0) { $0 + $1.fileSize }
            storage.recordFreedStorage(freedBytes: freedBytes)
            
            clearAllTrashIds()
            trashBin.removeAll()
            showTrashBin = false
            isDeletingTrash = false
            HapticManager.notification(type: .success)
            triggerConfetti()
        }
    }

    // MARK: - Deck Builder (Chronological, newest first, supports continuous sorting)
    private func sortMorePhotos() {
        HapticManager.selection()
        trashBin.removeAll()
        clearAllTrashIds()
        buildDeck(forceResetKept: true)
    }

    private func buildDeck(forceResetKept: Bool = false) {
        if forceResetKept {
            UserDefaults.standard.removeObject(forKey: keptPhotoIdsKey)
        }
        var items: [PhotoItem] = []
        var trashedItems: [PhotoItem] = []
        var keptSet = persistedKeptIds
        let trashSet = persistedTrashIds
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if !storage.isDemoMode && (status == .authorized || status == .limited) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = 1000
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            
            assets.enumerateObjects { asset, _, stop in
                let id = asset.localIdentifier
                guard !keptSet.contains(id) else { return }
                
                let item = PhotoItem(
                    id: id,
                    assetIdentifier: id,
                    creationDate: asset.creationDate ?? Date(),
                    fileSize: 3_200_000,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    isFavorite: asset.isFavorite,
                    isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                    mockColorIndex: abs(id.hashValue) % 20,
                    mockTitle: asset.mediaSubtypes.contains(.photoScreenshot) ? "Screenshot" : "Photo"
                )
                
                if trashSet.contains(id) {
                    trashedItems.append(item)
                } else {
                    items.append(item)
                    if items.count >= 25 {
                        stop.pointee = true
                    }
                }
            }
            
            // If all photos in current window were previously kept, reset kept history to allow continuous sorting
            if items.isEmpty && assets.count > 0 {
                UserDefaults.standard.removeObject(forKey: keptPhotoIdsKey)
                keptSet = []
                assets.enumerateObjects { asset, _, stop in
                    let id = asset.localIdentifier
                    let item = PhotoItem(
                        id: id,
                        assetIdentifier: id,
                        creationDate: asset.creationDate ?? Date(),
                        fileSize: 3_200_000,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight,
                        isFavorite: asset.isFavorite,
                        isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                        mockColorIndex: abs(id.hashValue) % 20,
                        mockTitle: asset.mediaSubtypes.contains(.photoScreenshot) ? "Screenshot" : "Photo"
                    )
                    items.append(item)
                    if items.count >= 25 {
                        stop.pointee = true
                    }
                }
            }
        } else {
            // Fallback: orderly chronological sequence (never empty)
            var base = storage.screenshots + storage.blurryPhotos
            for g in storage.similarGroups {
                base.append(contentsOf: g.photos)
            }
            if base.isEmpty {
                base = MockDataService.generateScreenshots() + MockDataService.generateBlurryPhotos()
            }
            var candidateItems = base.filter { !keptSet.contains($0.id) }
            if candidateItems.isEmpty {
                UserDefaults.standard.removeObject(forKey: keptPhotoIdsKey)
                candidateItems = base
            }
            for item in candidateItems {
                if trashSet.contains(item.id) {
                    trashedItems.append(item)
                } else {
                    items.append(item)
                    if items.count >= 25 { break }
                }
            }
        }
        
        deck = items
        trashBin = trashedItems
        kept = []
        dragOffset = .zero
        isDeckLoaded = true
        hasPlayedFinishedConfetti = false
    }
}

// MARK: - Celebration Confetti Particle View
public struct ConfettiView: View {
    @State private var animate = false
    @State private var fadeOut = false

    private struct ConfettiParticle: Identifiable {
        let id: Int
        let startRelX: CGFloat
        let startRelY: CGFloat
        let targetRelX: CGFloat
        let targetRelY: CGFloat
        let size: CGSize
        let color: Color
        let startRotation: Double
        let targetRotation: Double
        let delay: Double
        let isCircle: Bool
        let isRibbon: Bool
    }

    private let particles: [ConfettiParticle] = {
        let colors: [Color] = [
            Color(red: 0.15, green: 0.85, blue: 1.0),   // Electric Cyan
            Color(red: 1.0, green: 0.28, blue: 0.55),   // Hot Pink
            Color(red: 0.2, green: 0.9, blue: 0.45),    // Neon Green
            Color(red: 1.0, green: 0.78, blue: 0.15),   // Amber Gold
            Color(red: 0.72, green: 0.35, blue: 1.0),   // Violet
            Color(red: 1.0, green: 0.45, blue: 0.25),   // Bright Coral
            Color.white
        ]
        
        return (0..<75).map { i in
            let startRelX = 0.5 + CGFloat.random(in: -0.18...0.18)
            let startRelY = CGFloat.random(in: -0.05...0.06)
            
            let targetRelX = CGFloat.random(in: 0.05...0.95)
            let targetRelY = CGFloat.random(in: 0.4...0.98)
            
            let isCircle = (i % 4 == 0)
            let isRibbon = (i % 3 == 0)
            
            let width: CGFloat
            let height: CGFloat
            if isCircle {
                let diam = CGFloat.random(in: 7...12)
                width = diam
                height = diam
            } else if isRibbon {
                width = CGFloat.random(in: 6...8)
                height = CGFloat.random(in: 14...22)
            } else {
                width = CGFloat.random(in: 8...12)
                height = CGFloat.random(in: 8...12)
            }
            
            return ConfettiParticle(
                id: i,
                startRelX: startRelX,
                startRelY: startRelY,
                targetRelX: targetRelX,
                targetRelY: targetRelY,
                size: CGSize(width: width, height: height),
                color: colors[i % colors.count],
                startRotation: Double.random(in: 0...180),
                targetRotation: Double.random(in: 720...1440),
                delay: Double.random(in: 0.0...0.35),
                isCircle: isCircle,
                isRibbon: isRibbon
            )
        }
    }()

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                ForEach(particles) { p in
                    particleShape(p)
                        .frame(width: p.size.width, height: p.size.height)
                        .rotation3DEffect(
                            .degrees(animate ? p.targetRotation : p.startRotation),
                            axis: (x: 0.6, y: 0.8, z: 0.2)
                        )
                        .position(
                            x: animate ? p.targetRelX * w : p.startRelX * w,
                            y: animate ? p.targetRelY * h : p.startRelY * h
                        )
                        .animation(
                            .timingCurve(0.1, 0.9, 0.2, 1.0, duration: 2.6).delay(p.delay),
                            value: animate
                        )
                        .opacity(fadeOut ? 0.0 : 1.0)
                        .animation(
                            .easeIn(duration: 0.8),
                            value: fadeOut
                        )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                fadeOut = true
            }
        }
    }

    @ViewBuilder
    private func particleShape(_ p: ConfettiParticle) -> some View {
        if p.isCircle {
            Circle().fill(p.color)
        } else if p.isRibbon {
            Capsule().fill(p.color)
        } else {
            RoundedRectangle(cornerRadius: 2).fill(p.color)
        }
    }
}

// MARK: - Corner Radius Helper
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
