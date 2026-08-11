import Foundation
import AVFoundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var subtitleText = ""
    @Published var originalText: String?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0

    private let recognizer = SpeechRecognizer()
    private let translator = TranslationService()
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: URLSessionDownloadTask?

    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }

        isDownloading = true
        downloadProgress = 0

        let delegate = DownloadDelegate(
            progress: { [weak self] p in
                Task { @MainActor in self?.downloadProgress = p }
            },
            completion: { [weak self] localURL in
                Task { @MainActor in self?.startPlayback(localURL: localURL) }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func startPlayback(localURL: URL) {
        isDownloading = false

        let avPlayer = AVPlayer(url: localURL)
        self.player = avPlayer

        avPlayer.play()

        recognizer.start(fileURL: localURL) { [weak self] japaneseText in
            guard let self else { return }

            Task { @MainActor in
                self.originalText = japaneseText

                if !japaneseText.isEmpty {
                    self.translator.translate(japaneseText) { translated in
                        Task { @MainActor in
                            if let translated {
                                self.subtitleText = translated
                            }
                        }
                    }
                }
            }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.player?.seek(to: .zero)
            }
            .store(in: &cancellables)
    }

    func stop() {
        player?.pause()
        player = nil
        subtitleText = ""
        originalText = nil
        isDownloading = false
        downloadProgress = 0
        recognizer.stop()
        downloadTask?.cancel()
        downloadTask = nil
        cancellables.removeAll()
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onCompletion: (URL) -> Void

    init(progress: @escaping (Double) -> Void, completion: @escaping (URL) -> Void) {
        self.onProgress = progress
        self.onCompletion = completion
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("lumina_\(UUID().uuidString).mp4")
        try? FileManager.default.moveItem(at: location, to: dest)
        onCompletion(dest)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            print("[Lumina] Download error: \(error.localizedDescription)")
        }
    }
}
