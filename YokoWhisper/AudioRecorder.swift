@preconcurrency import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError { case noInput, emptyRecording
    var errorDescription: String? { self == .noInput ? "No microphone input is available." : "No speech was recorded." }
}

/// Owns the audio file on the engine's real-time callback queue. AVAudioEngine
/// does not invoke taps on the main actor, so this boundary must be explicitly
/// synchronized instead of reaching into main-actor state from the tap.
private final class AudioFileSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?

    init(file: AVAudioFile) { self.file = file }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { try? file?.write(from: buffer) }
    }

    func close() {
        lock.withLock { file = nil }
    }
}

/// AVAudioEngine invokes its tap on a private real-time queue. Keep this type
/// nonisolated and protect state explicitly so Swift does not insert a main-
/// actor queue precondition around the tap closure.
final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var sink: AudioFileSink?
    private var outputURL: URL?
    private let levelLock = NSLock()
    private var storedLevel: Float = 0
    var level: Float { levelLock.withLock { storedLevel } }

    func start() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw AudioRecorderError.noInput }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yoko-\(UUID().uuidString).caf")
        let sink = AudioFileSink(file: try AVAudioFile(forWriting: url, settings: format.settings))
        self.sink = sink
        outputURL = url
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            sink.write(buffer)
            guard let data = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            let rms = sqrt((0..<count).reduce(Float.zero) { $0 + data[$1] * data[$1] } / Float(max(count, 1)))
            self?.levelLock.withLock { self?.storedLevel = min(1, rms * 8) }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() throws -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        sink?.close()
        sink = nil
        guard let url = outputURL,
              (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0 > 4096
        else { throw AudioRecorderError.emptyRecording }
        outputURL = nil
        return url
    }

    func cancel() {
        if engine.isRunning { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        sink?.close()
        outputURL = nil; sink = nil
        levelLock.withLock { storedLevel = 0 }
    }
}
