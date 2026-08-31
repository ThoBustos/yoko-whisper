@preconcurrency import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError { case noInput, emptyRecording
    var errorDescription: String? { self == .noInput ? "No microphone input is available." : "No speech was recorded." }
}

private final class PendingAudioBuffer: @unchecked Sendable {
    let value: AVAudioPCMBuffer

    init(format: AVAudioFormat, capacity: AVAudioFrameCount) {
        value = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
    }
}

/// Copies into a bounded, preallocated pool on the real-time callback and does
/// potentially blocking file I/O on a dedicated serial queue.
private final class AudioFileSink: @unchecked Sendable {
    private let lock = NSLock()
    private let writerQueue = DispatchQueue(label: "ai.ideabench.yokowhisper.audio-writer")
    private var file: AVAudioFile?
    private var available: [PendingAudioBuffer]
    private var acceptingWrites = true

    init(file: AVAudioFile, format: AVAudioFormat, bufferCapacity: AVAudioFrameCount) {
        self.file = file
        available = (0..<8).map { _ in PendingAudioBuffer(format: format, capacity: bufferCapacity) }
    }

    func enqueue(_ source: AVAudioPCMBuffer) {
        guard let pending = lock.withLock({ acceptingWrites ? available.popLast() : nil }) else { return }
        copy(source, into: pending.value)
        writerQueue.async { [weak self] in
            guard let self else { return }
            try? self.file?.write(from: pending.value)
            self.lock.withLock { self.available.append(pending) }
        }
    }

    func close() {
        lock.withLock { acceptingWrites = false }
        writerQueue.sync { file = nil }
    }

    private func copy(_ source: AVAudioPCMBuffer, into destination: AVAudioPCMBuffer) {
        destination.frameLength = min(source.frameLength, destination.frameCapacity)
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        for (sourceBuffer, destinationBuffer) in zip(sourceBuffers, destinationBuffers) {
            guard let sourceData = sourceBuffer.mData, let destinationData = destinationBuffer.mData else { continue }
            memcpy(destinationData, sourceData, min(Int(sourceBuffer.mDataByteSize), Int(destinationBuffer.mDataByteSize)))
        }
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
    private var levelSmoother = AudioLevelSmoother()
    var level: Float { levelLock.withLock { levelSmoother.value } }

    func start() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw AudioRecorderError.noInput }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("yoko-\(UUID().uuidString).caf")
        let sink = AudioFileSink(
            file: try AVAudioFile(forWriting: url, settings: format.settings),
            format: format,
            bufferCapacity: 1024
        )
        self.sink = sink
        outputURL = url
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            sink.enqueue(buffer)
            guard let data = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sum: Float = 0
            for index in 0..<count { sum += data[index] * data[index] }
            let rms = sqrt(sum / Float(max(count, 1)))
            self?.levelLock.withLock { self?.levelSmoother.update(rawLevel: rms * 8) }
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
        levelLock.withLock { levelSmoother.reset() }
    }
}

struct AudioLevelSmoother: Sendable {
    private(set) var value: Float = 0

    mutating func update(rawLevel: Float) {
        let target = min(1, max(0, rawLevel))
        let coefficient: Float = target > value ? 0.5 : 0.16
        value += (target - value) * coefficient
    }

    mutating func reset() { value = 0 }
}
