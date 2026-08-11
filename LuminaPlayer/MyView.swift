import SwiftUI

struct FavoriteVideo: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let duration: String
    let progress: Double
    let coverImage: String
}

struct MyView: View {
    @State private var favorites: [FavoriteVideo] = [
        FavoriteVideo(
            title: "未来城市探索 (Neo-Tokyo Immersive)",
            description: "这是一段关于未来城市街景的沉浸式体验视频，捕捉了霓虹灯下的静谧与喧嚣，探索极简主义在赛博朋克环境中的表达。",
            duration: "12:45",
            progress: 0.65,
            coverImage: "photo.stack"
        ),
        FavoriteVideo(
            title: "极简架构解析 (Minimalist Architecture)",
            description: "深入探讨现代数字界面中的黑白极简主义设计原则，如何通过空间留白和微妙的色调对比来减轻认知负荷。",
            duration: "08:20",
            progress: 0.30,
            coverImage: "photo.stack"
        ),
        FavoriteVideo(
            title: "高效生产力工作流 (Workflow Optimization)",
            description: "构建专注于核心任务的沉浸式工作环境，告别干扰，利用极简工具提升日常效率与数字生活的纯净度。",
            duration: "22:15",
            progress: 0.90,
            coverImage: "photo.stack"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(favorites) { video in
                        VideoCardView(video: video)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 80)
            }
        }
        .background(LuminaColor.background)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        Text("Lumina Player")
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(LuminaColor.onSurface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(LuminaColor.outlineVariant).frame(height: 1)
            }
    }
}

// MARK: - Video Card

struct VideoCardView: View {
    let video: FavoriteVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area
            ZStack(alignment: .bottom) {
                // Placeholder image
                ZStack {
                    LuminaColor.surface
                    Image(systemName: video.coverImage)
                        .font(.system(size: 36))
                        .foregroundColor(LuminaColor.onSurface.opacity(0.15))
                }
                .aspectRatio(16/9, contentMode: .fit)

                // Play button overlay
                Color.black.opacity(0.001) // Makes entire area tappable
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(LuminaColor.primary.opacity(0.8))
                    }

                // Duration badge
                Text(video.duration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(LuminaColor.onSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(LuminaColor.border, lineWidth: 1)
                    )
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                // Progress bar
                VStack {
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 2)
                            Rectangle()
                                .fill(LuminaColor.primary)
                                .frame(width: geo.size.width * video.progress, height: 2)
                        }
                    }
                    .frame(height: 2)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LuminaColor.onSurface)
                    .lineLimit(1)

                Text(video.description)
                    .font(.system(size: 14))
                    .foregroundColor(LuminaColor.onSurfaceVariant)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                    Text("已收藏")
                        .font(.system(size: 11))
                }
                .foregroundColor(LuminaColor.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(LuminaColor.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(LuminaColor.primary.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 4)
            }
            .padding(16)
        }
        .luminaCard()
    }
}
