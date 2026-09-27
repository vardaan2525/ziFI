import SwiftUI
import AVKit
import AVFoundation

@main
struct StorageCleanerApp: App {
    @StateObject private var storage = StorageManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showIntro: Bool = true
    @AppStorage("zifi_color_scheme") private var colorSchemePreference: String = "system"
    
    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                
                if showIntro {
                    AppIntroView(isPresented: $showIntro)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        ))
                        .zIndex(999)
                }
            }
            .preferredColorScheme(preferredColorScheme)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    storage.refreshDeviceStorage()
                    storage.checkPermissions()
                    if storage.photoAuthStatus == .authorized || storage.photoAuthStatus == .limited {
                        Task {
                            await PhotoScannerManager.shared.scanLivePhotos()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - App Intro with Centered Video
public struct AppIntroView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.92
    @State private var subtitleOpacity: Double = 0.0
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            AppTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 22) {
                // Small centered intro video
                LoopedVideoPlayerView(videoName: "video", videoExtension: "mov")
                    .frame(width: 140, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
                
                VStack(spacing: 6) {
                    Text("ziFI")
                        .font(.system(size: 38, weight: .black, design: .default))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("STORAGE CLEANER")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(4)
                        .foregroundColor(AppTheme.textMuted)
                        .opacity(subtitleOpacity)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear { runIntro() }
    }
    
    private func runIntro() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
            opacity = 1.0
            scale = 1.0
        }
        HapticManager.impact(style: .light)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.35)) {
                subtitleOpacity = 1.0
            }
        }
        
        // Auto-dismiss after 2.8 seconds, or tap anytime
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            dismiss()
        }
    }
    
    private func dismiss() {
        guard isPresented else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            opacity = 0.0
            isPresented = false
        }
    }
}

// MARK: - Native Looping Video Player
public struct LoopedVideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    
    public init(videoName: String = "video", videoExtension: String = "mov") {
        self.videoName = videoName
        self.videoExtension = videoExtension
    }
    
    public func makeUIView(context: Context) -> LoopedVideoUIView {
        LoopedVideoUIView(videoName: videoName, videoExtension: videoExtension)
    }
    
    public func updateUIView(_ uiView: LoopedVideoUIView, context: Context) {}
}

public class LoopedVideoUIView: UIView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    
    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)
        backgroundColor = .clear
        
        // Resolve video from bundle or fallback to Desktop copy
        let videoURL: URL = Bundle.main.url(forResource: videoName, withExtension: videoExtension)
            ?? Bundle.main.url(forResource: videoName, withExtension: "mp4")
            ?? URL(fileURLWithPath: "/Users/vardaanarora/Desktop/video.mov")
        
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        player.actionAtItemEnd = .none
        
        self.queuePlayer = player
        self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.backgroundColor = UIColor.clear.cgColor
        self.layer.addSublayer(layer)
        self.playerLayer = layer
        
        player.play()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    deinit {
        queuePlayer?.pause()
        queuePlayer = nil
        playerLooper = nil
    }
}
