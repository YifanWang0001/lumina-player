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
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var assetReader: AVAssetReader?
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
            DispatchQueue.global(qos: .userInitiated).async {
                self.beginRecognition(fileURL: fileURL, onSegment: onSegment)
            }
        }
    }

    private func beginRecognition(fileURL: URL, onSegment: @escaping (SubtitleSegment) -> Void) {
        let asset = AVAsset(url: fileURL)

        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            DispatchQueue.main.async {
                onSegment(SubtitleSegment(text: "[No audio track]", startTime: .zero, duration: .zero))
            }
            return
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            DispatchQueue.main.async {
                onSegment(SubtitleSegment(text: "[Cannot read asset]", startTime: .zero, duration: .zero))
            }
            return
        }
        assetReader = reader

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            DispatchQueue.main.async {
                onSegment(SubtitleSegment(text: "[Cannot start reading]", startTime: .zero, duration: .zero))
            }
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let recognitionRequest, let speechRecognizer else { return }

        lastEmittedIndex = 0

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self, let result else { return }

            let segments = result.bestTranscription.segments
            // All segments except the last are stable in partial results;
            // when isFinal, all are stable.
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

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                if reader.status == .completed { break }
                continue
            }
            if let pcmBuffer = createPCMBuffer(from: sampleBuffer) {
                recognitionRequest.append(pcmBuffer)
            }
            CMSampleBufferInvalidate(sampleBuffer)
        }

        recognitionRequest.endAudio()
    }

    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee
        let sampleRate = asbd?.mSampleRate ?? 16000
        let channels = asbd?.mChannelsPerFrame ?? 1

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        ) else { return nil }

        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var dataPointer: UnsafeMutablePointer<Int8>?
        var totalLength = 0
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        guard let dataPointer, totalLength > 0 else { return nil }

        guard let dst = pcmBuffer.int16ChannelData?.pointee else { return nil }
        let count = min(Int(pcmBuffer.frameLength), totalLength / MemoryLayout<Int16>.stride)
        dataPointer.withMemoryRebound(to: Int16.self, capacity: count) { src in
            dst.update(from: src, count: count)
        }

        return pcmBuffer
    }

    func stop() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        assetReader?.cancelReading()
        assetReader = nil
        speechRecognizer = nil
        lastEmittedIndex = 0
    }
}
