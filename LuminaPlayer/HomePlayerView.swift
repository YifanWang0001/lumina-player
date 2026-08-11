import SwiftUI
import AVKit

struct HomePlayerView: View {
    let url: String
    let goBack: () -> Void

    @StateObject private var viewModel = PlayerViewModel()
    @State private var isBookmarked = false
    @AppStorage("subtitleSize") private var subtitleSize: Int = 18

    var body: some View {
        VStack(spacing: 0) {
            topBar
            scrollContent
        }
        .background(LuminaColor.background)
        .onAppear { viewModel.loadURL(url) }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(LuminaColor.onSurface)
                        .padding(8)
                }

                Spacer()
            }

            Text("Lumina Player")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(LuminaColor.onSurface)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LuminaColor.outlineVariant).frame(height: 1)
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                videoArea
                videoInfoSection
                descriptionSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .frame(maxWidth: 800)
    }

    // MARK: - Video Area

    private var videoArea: some View {
        ZStack {
            if let error = viewModel.playerError {
                playerErrorView(error)
            } else if let player = viewModel.player {
                VideoPlayerView(player: player)
            } else if viewModel.isDownloading {
                downloadingPlaceholder
            } else {
                videoPlaceholder
            }

            // Subtitle overlay
            if let original = viewModel.currentOriginalText {
                VStack {
                    Spacer()
                    subtitleOverlay(original: original, translated: viewModel.currentTranslatedText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .background(LuminaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: LuminaRadius.card)
                .stroke(LuminaColor.border, lineWidth: 1)
        )
    }

    private func playerErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(LuminaColor.primary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }

    private var videoPlaceholder: some View {
        ZStack {
            LuminaColor.surface
            Image(systemName: "play.arrow")
                .font(.system(size: 48))
                .foregroundColor(LuminaColor.onSurface.opacity(0.2))
        }
    }

    private var downloadingPlaceholder: some View {
        ZStack {
            LuminaColor.surface
            if let error = viewModel.downloadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(LuminaColor.primary)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(LuminaColor.primary)
                    Text(viewModel.downloadProgress < 0
                         ? "下载中..."
                         : "下载中 \(Int(viewModel.downloadProgress * 100))%")
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.onSurfaceVariant)
                }
            }
        }
    }

    private func subtitleOverlay(original: String, translated: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if viewModel.displayMode == .bilingual {
                Text(original)
                    .font(.system(size: CGFloat(subtitleSize) - 2))
                    .foregroundColor(LuminaColor.onSurface.opacity(0.7))
            }
            if let translated {
                Text(translated)
                    .font(.system(size: CGFloat(subtitleSize), weight: .medium))
                    .foregroundColor(LuminaColor.onSurface)
            } else {
                Text(original)
                    .font(.system(size: CGFloat(subtitleSize), weight: .medium))
                    .foregroundColor(LuminaColor.onSurface)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Video Info

    private var videoInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("视频名")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(LuminaColor.onSurface)

            HStack {
                Text("4K HDR · 60fps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LuminaColor.onSurfaceVariant)

                Spacer()

                Button {
                    isBookmarked.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15))
                        Text("收藏")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isBookmarked ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: LuminaRadius.card)
                            .stroke(isBookmarked ? LuminaColor.primary : LuminaColor.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(LuminaColor.onSurface)

            Text("这是一段关于未来城市街景的沉浸式体验视频。高楼林立，霓虹闪烁，雨水冲刷着合金街道，展现出一种独特的反乌托邦美学。视频采用最新的渲染技术，为您带来极致的视觉享受与宁静感。请戴上耳机，享受这片刻的赛博虚空。")
                .font(.system(size: 14))
                .foregroundColor(LuminaColor.secondary)
                .lineSpacing(4)
        }
    }
}
