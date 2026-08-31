import AppKit
import Foundation
import OSLog

/// Owns one complete push-to-talk session from focus capture through recovery.
@MainActor
@Observable
final class DictationCoordinator {
    static let minimumRecordingDuration: TimeInterval = 0.18

    var state: DictationState = .idle {
        didSet {
            onStateChange?(state)
            transientTask?.cancel()
            if case .success = state { scheduleIdle() }
            if case .copied = state { scheduleIdle() }
            if case .cancelled = state { scheduleIdle(after: .milliseconds(500)) }
            if case .failure = state { scheduleIdle(after: .seconds(5)) }
        }
    }
    var lastTranscript: String? {
        didSet { defaults.set(lastTranscript, forKey: "lastTranscript") }
    }
    let recorder: AudioRecorder
    var onStateChange: ((DictationState) -> Void)?

    private let transcriptionEngine: any TranscriptionEngine
    private let insertion: TextInsertionService
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "ai.ideabench.yokowhisper", category: "dictation")
    private var focusTarget: FocusTarget?
    private var transientTask: Task<Void, Never>?

    init(
        recorder: AudioRecorder = AudioRecorder(),
        transcriptionEngine: (any TranscriptionEngine)? = nil,
        insertion: TextInsertionService = TextInsertionService(),
        defaults: UserDefaults = .standard
    ) {
        self.recorder = recorder
        self.transcriptionEngine = transcriptionEngine ?? WhisperKitEngine()
        self.insertion = insertion
        self.defaults = defaults
        lastTranscript = defaults.string(forKey: "lastTranscript")
    }

    func beginRecording() {
        guard state.canBeginRecording else { return }
        do {
            focusTarget = insertion.captureTarget()
            try recorder.start()
            state = .recording(startedAt: Date())
            logger.info("Recording started")
        } catch {
            recorder.cancel()
            logger.error("Recording failed: \(error.localizedDescription, privacy: .private)")
            state = .failure(error.localizedDescription, transcript: nil)
        }
    }

    func finishRecording(language: String?) {
        guard case .recording(let startedAt) = state else { return }
        guard Date().timeIntervalSince(startedAt) >= Self.minimumRecordingDuration else {
            cancelRecording()
            return
        }
        do {
            let url = try recorder.stop()
            state = .transcribing
            Task { await transcribe(url, language: language) }
        } catch {
            recorder.cancel()
            state = .failure(error.localizedDescription, transcript: nil)
        }
    }

    func cancelRecording() {
        guard case .recording = state else { return }
        recorder.cancel()
        state = .cancelled
    }

    func copyLastTranscript() {
        guard let lastTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
    }

    private func transcribe(_ url: URL, language: String?) async {
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let text = try await transcriptionEngine.transcribe(audioAt: url, language: language)
            guard !text.isEmpty else {
                state = .failure("No speech was detected.", transcript: nil)
                return
            }
            lastTranscript = text
            copyLastTranscript()
            state = .inserting
            let result = await insertion.insert(text, into: focusTarget)
            switch result {
            case .insertedDirectly:
                state = .success(text)
            case .pasteRequested, .copiedOnly:
                state = .copied(text)
            }
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription, privacy: .private)")
            state = .failure("Transcription failed: \(error.localizedDescription)", transcript: nil)
        }
    }

    private func scheduleIdle(after delay: Duration = .seconds(3)) {
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.state = .idle
        }
    }
}
