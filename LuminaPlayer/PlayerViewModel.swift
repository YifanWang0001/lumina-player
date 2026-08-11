import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var currentOriginalText: String?
    @Published var currentTranslatedText: String?
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadError: String?
    @Published var playerError: String?

    @AppStorage("displayMode") private var displayModeRaw: String = DisplayMode.bilingual.rawValue

    private let recognizer = SpeechRecognizer()
    private let translator = TranslationService()
    private var cancellables = Set<AnyCancellable>()
    private var downloadTask: URLSessionDownloadTask?
    private var timeObserver: Any?
    private var segments: [SubtitleSegment] = []
    private var translatedSegments: [Int: String] = [:]
    private var currentSegmentIndex = -1

    // MARK: - Settings helpers

    private var videoLanguage: VideoLanguage {
        let raw = UserDefaults.standard.string(forKey: "videoLanguage") ?? ""
        return VideoLanguage(rawValue: raw) ?? .chinese
    }

    private var translationLanguage: TranslationLanguage {
        let raw = UserDefaults.standard.string(forKey: "translationLanguage") ?? ""
        return TranslationLanguage(rawValue: raw) ?? .chinese
    }

    var displayMode: DisplayMode {
        DisplayMode(rawValue: displayModeRaw) ?? .bilingual
    }

    // MARK: - Load

    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            downloadError = "无效链接"
            return
        }

        if url.isFileURL {
            startPlayback(localURL: url)
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        let delegate = DownloadDelegate(
            progress: { [weak self] p in
                Task { @MainActor in self?.downloadProgress = p }
            },
            completion: { [weak self] localURL in
                Task { @MainActor in self?.startPlayback(localURL: localURL) }
            },
            error: { [weak self] message in
                Task { @MainActor in
                    self?.isDownloading = false
                    self?.downloadError = message
                }
            }
        )

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    // MARK: - Playback

    private func startPlayback(localURL: URL) {
        isDownloading = false
        segments = []
        translatedSegments = [:]
        currentSegmentIndex = -1
        currentOriginalText = nil
        currentTranslatedText = nil

        let avPlayer = AVPlayer(url: localURL)
        self.player = avPlayer

        avPlayer.currentItem?.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .failed {
                    let baseError = avPlayer.currentItem?.error?.localizedDescription ?? ""
                    if baseError.isEmpty {
                        self.playerError = "无法播放\n\n链接可能不是直接的视频地址，请确认链接以 .mp4 / .m3u8 等格式结尾"
                    } else {
                        self.playerError = "\(baseError)\n\n链接可能不是直接的视频地址，请确认链接以 .mp4 / .m3u8 等格式结尾"
                    }
                }
            }
            .store(in: &cancellables)

        let sourceLang = videoLanguage.localeIdentifier
        let targetLang = translationLanguage.localeIdentifier
        let sourceLocale = Locale.Language(identifier: sourceLang)
        let targetLocale = Locale.Language(identifier: targetLang)
        translator.configure(source: sourceLocale, target: targetLocale)

        recognizer.start(fileURL: localURL, localeIdentifier: sourceLang) { [weak self] segment in
            guard let self else { return }

            let isStatus = segment.text.hasPrefix("[") && segment.text.hasSuffix("]")

            let index = self.segments.count
            self.segments.append(segment)

            if isStatus {
                // Show status message immediately
                self.currentOriginalText = segment.text
                self.currentTranslatedText = nil
            } else {
                self.translator.translate(segment.text) { [weak self] translated in
                    guard let self else { return }
                    self.translatedSegments[index] = translated
                    if self.currentSegmentIndex == index {
                        self.currentTranslatedText = translated
                    }
                }
            }
        }

        avPlayer.play()

        let interval = CMTime(value: 100, timescale: 1000)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated { self.updateCurrentSegment(at: time) }
        }

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.player?.seek(to: .zero)
            }
            .store(in: &cancellables)
    }

    private func updateCurrentSegment(at time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        var foundIndex = -1

        for (i, seg) in segments.enumerated() {
            let segStart = CMTimeGetSeconds(seg.startTime)
            let segEnd = segStart + CMTimeGetSeconds(seg.duration)
            if seconds >= segStart && seconds < segEnd {
                foundIndex = i
                break
            }
        }

        if foundIndex != currentSegmentIndex {
            currentSegmentIndex = foundIndex
            if foundIndex >= 0 {
                currentOriginalText = segments[foundIndex].text
                currentTranslatedText = translatedSegments[foundIndex]
            } else {
                currentOriginalText = nil
                currentTranslatedText = nil
            }
        }
    }

    // MARK: - Stop

    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        currentOriginalText = nil
        currentTranslatedText = nil
        segments = []
        translatedSegments = [:]
        currentSegmentIndex = -1
        isDownloading = false
        downloadProgress = 0
        downloadError = nil
        playerError = nil
        recognizer.stop()
        translator.cancel()
        downloadTask?.cancel()
        downloadTask = nil
        cancellables.removeAll()
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onCompletion: (URL) -> Void
    let onError: (String) -> Void
    private var hasKnownSize = false
    private var hasError = false

    init(progress: @escaping (Double) -> Void,
         completion: @escaping (URL) -> Void,
         error: @escaping (String) -> Void) {
        self.onProgress = progress
        self.onCompletion = completion
        self.onError = error
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            hasKnownSize = true
            onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        } else if !hasKnownSize {
            onProgress(-1)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if hasError { return }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dest = caches.appendingPathComponent("lumina_\(UUID().uuidString).mp4")
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            onCompletion(dest)
        } catch {
            onError("下载失败: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            hasError = true
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    onError("无网络连接")
                case NSURLErrorTimedOut:
                    onError("下载超时")
                case NSURLErrorCannotConnectToHost:
                    onError("无法连接服务器")
                default:
                    onError("下载失败: \(error.localizedDescription)")
                }
            } else {
                onError("下载失败: \(error.localizedDescription)")
            }
        }
    }
}
