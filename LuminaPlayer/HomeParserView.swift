import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import Photos

struct HomeParserView: View {
    @State private var urlText = ""
    @State private var showFilePicker = false
    @State private var showSourceSheet = false
    @State private var showPhotosPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showURLError = false
    @State private var urlErrorMessage = ""
    @State private var isProcessingPhoto = false
    let navigate: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            centerContent
        }
        .background(LuminaColor.background)
        .overlay {
            if isProcessingPhoto {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("正在加载视频...")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
                }
            }
        }
        .confirmationDialog("选择视频来源", isPresented: $showSourceSheet) {
            Button("从相册选择") { showPhotosPicker = true }
            Button("从文件选择") { showFilePicker = true }
            Button("取消", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .audiovisualContent],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                copyToCacheAndNavigate(url)
            }
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            isProcessingPhoto = true
            Task { await loadPhotoAsset(item) }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .videos)
        .alert("链接错误", isPresented: $showURLError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(urlErrorMessage)
        }
    }

    private func copyToCacheAndNavigate(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("lumina_local_\(UUID().uuidString).\(url.pathExtension)")
        if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
            navigate(dest.absoluteString)
        }
    }

    // MARK: - Photo Library (file-based, avoids loading into memory)

    private func loadPhotoAsset(_ item: PhotosPickerItem) async {
        defer {
            selectedPhoto = nil
            isProcessingPhoto = false
        }

        // 1) Try PHAsset — gets file URL directly, no memory overhead
        if let identifier = item.itemIdentifier {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = fetch.firstObject {
                if let url = await requestVideoURL(from: asset) {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    let dest = caches.appendingPathComponent("lumina_photo_\(UUID().uuidString).mp4")
                    if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                        navigate(dest.absoluteString)
                        return
                    }
                }
            }
        }

        // 2) Fallback: Data.self for videos that aren't accessible via file URL
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("lumina_photo_\(UUID().uuidString).mp4")
        try? data.write(to: dest)
        navigate(dest.absoluteString)
    }

    private func requestVideoURL(from asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
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

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Lumina Player")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(LuminaColor.onSurface)

                Text("输入链接以提取视频")
                    .font(.system(size: 16))
                    .foregroundColor(LuminaColor.onSurfaceVariant)
            }

            // Form
            VStack(spacing: 16) {
                // URL Input
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(LuminaColor.onSurfaceVariant)
                        .font(.system(size: 16))
                    TextField("输入链接...", text: $urlText)
                        .font(.system(size: 14))
                        .foregroundColor(LuminaColor.onSurface)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .luminaInput()

                // Parse Button
                Button {
                    let trimmed = urlText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else {
                        urlErrorMessage = "请输入链接"
                        showURLError = true
                        return
                    }
                    guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" else {
                        urlErrorMessage = "链接格式无效，请输入以 http:// 或 https:// 开头的链接"
                        showURLError = true
                        return
                    }
                    navigate(trimmed)
                } label: {
                    Text("解析")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LuminaColor.onSurface)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LuminaColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.button))
                }

                // Local File Button
                Button {
                    showSourceSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 14))
                        Text("选择本地视频")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(LuminaColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: LuminaRadius.button)
                            .stroke(LuminaColor.outlineVariant, lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
