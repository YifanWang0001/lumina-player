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
            Task { await self.beginRecognition(fileURL: fileURL, onSegment: onSegment) }
        }
    }

    private func beginRecognition(fileURL: URL, onSegment: @escaping (SubtitleSegment) -> Void) async {
        let asset = AVAsset(url: fileURL)

        guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            DispatchQueue.main.async {
                onSegment(SubtitleSegment(text: "[No audio track]", startTime: .zero, duration: .zero))
            }
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumina_audio_\(UUID().uuidString).caf")

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            try await extractAudio(track: audioTrack, asset: asset, to: tempURL, settings: outputSettings)
        } catch {
            DispatchQueue.main.async {
                onSegment(SubtitleSegment(text: "[Audio extraction failed]", startTime: .zero, duration: .zero))
            }
            return
        }

        recognitionTask?.cancel()
        lastEmittedIndex = 0

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = true

        guard let speechRecognizer else { return }

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

            if result.isFinal {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }

    private func extractAudio(track: AVAssetTrack, asset: AVAsset, to url: URL, settings: [String: Any]) async throws {
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create asset reader"])
        }

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(readerOutput)

        guard let writer = try? AVAssetWriter(url: url, fileType: .caf) else {
            throw NSError(domain: "SpeechRecognizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create asset writer"])
        }

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        writer.add(writerInput)

        guard reader.startReading() else {
            throw NSError(domain: "SpeechRecognizer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot start reading"])
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let startTime = Date()
        while reader.status == .reading || reader.status == .unknown {
            if Date().timeIntervalSince(startTime) > 30 { break }

            if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                if writerInput.isReadyForMoreMediaData {
                    writerInput.append(sampleBuffer)
                }
                CMSampleBufferInvalidate(sampleBuffer)
            } else {
                if reader.status == .completed { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }

        if writer.status != .completed {
            let errorDesc = writer.error?.localizedDescription ?? "unknown error"
            throw NSError(domain: "SpeechRecognizer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Audio export failed: \(errorDesc)"])
        }
    }

    deinit {
        recognitionTask?.cancel()
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil
        lastEmittedIndex = 0
    }
}
