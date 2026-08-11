import Foundation
import AVFoundation
import Speech

final class SpeechRecognizer {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var assetReader: AVAssetReader?

    func start(fileURL: URL, onResult: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { onResult("[Speech recognition not authorized]") }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.beginRecognition(fileURL: fileURL, onResult: onResult)
            }
        }
    }

    private func beginRecognition(fileURL: URL, onResult: @escaping (String) -> Void) {
        let asset = AVAsset(url: fileURL)

        let audioTrack = asset.tracks(withMediaType: .audio).first
        guard audioTrack != nil else {
            DispatchQueue.main.async { onResult("[No audio track]") }
            return
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            DispatchQueue.main.async { onResult("[Cannot read asset]") }
            return
        }
        self.assetReader = reader

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack!, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            DispatchQueue.main.async { onResult("[Cannot start reading]") }
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        guard let recognitionRequest else { return }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result {
                DispatchQueue.main.async { onResult(result.bestTranscription.formattedString) }
            }
            if error != nil || result?.isFinal == true {}
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
    }
}
