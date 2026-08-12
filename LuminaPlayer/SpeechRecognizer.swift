import Foundation
import AVFoundation
import Speech

struct SubtitleSegment {
    let text: String
    let startTime: CMTime
    let duration: CMTime
}

final class SpeechRecognizer {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastEmittedIndex = 0

    func start(fileURL: URL, localeIdentifier: String, onSegment: @escaping (SubtitleSegment) -> Void) {
        stop()

        let locale = Locale(identifier: localeIdentifier)
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else {
                DispatchQueue.main.async {
                    onSegment(SubtitleSegment(text: "[Speech recognition not authorized]", startTime: .zero, duration: .zero))
                }
                return
            }
            self.beginRecognition(fileURL: fileURL, onSegment: onSegment)
        }
    }

    private func beginRecognition(fileURL: URL, onSegment: @escaping (SubtitleSegment) -> Void) {
        recognitionTask?.cancel()
        lastEmittedIndex = 0

        guard let speechRecognizer else { return }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self, let result else { return }

            let segments = result.bestTranscription.segments
            let stableCount = result.isFinal ? segments.count : max(0, segments.count - 1)

            while self.lastEmittedIndex < stableCount {
                let seg = segments[self.lastEmittedIndex]
                let segment = SubtitleSegment(
                    text: seg.substring,
                    startTime: CMTime(seconds: seg.timestamp, preferredTimescale: 1000),
                    duration: CMTime(seconds: seg.duration, preferredTimescale: 1000)
                )
                DispatchQueue.main.async { onSegment(segment) }
                self.lastEmittedIndex += 1
            }
        }
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil
        lastEmittedIndex = 0
    }
}
