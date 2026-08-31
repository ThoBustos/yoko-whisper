import SwiftUI
import OSLog

@main
struct YokoWhisperApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Yoko Whisper", systemImage: "waveform") {
            MenuContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var state: DictationState = .idle {
        didSet {
            hud?.update(for: state)
            transientTask?.cancel()
            if case .success = state { scheduleIdle() }
            if case .failure = state { scheduleIdle(after: .seconds(5)) }
        }
    }
    var status: String { state.label }
    let recorder = AudioRecorder()
    let preferences = Preferences()
    let transcriptionEngine: any TranscriptionEngine
    private let shortcuts = ShortcutService()
    private let insertion = TextInsertionService()
    private var hud: HUDController?
    private var transientTask: Task<Void, Never>?
    private var focusTarget: FocusTarget?
    private let logger = Logger(subsystem: "ai.ideabench.yokowhisper", category: "dictation")
    var lastTranscript: String? { didSet { UserDefaults.standard.set(lastTranscript, forKey: "lastTranscript") } }
    let permissions = PermissionService()
    var onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")

    init(transcriptionEngine: (any TranscriptionEngine)? = nil) {
        self.transcriptionEngine = transcriptionEngine ?? WhisperKitEngine()
        self.lastTranscript = UserDefaults.standard.string(forKey: "lastTranscript")
    }

    func startIntegrations() {
        guard hud == nil else { return }
        hud = HUDController(model: self)
        shortcuts.onToggle = { [weak self] in self?.toggleRecording() }
        shortcuts.onCancel = { [weak self] in
            guard let self, case .recording = self.state else { return }
            self.cancel()
        }
        shortcuts.start(choice: preferences.shortcut)
    }

    func finishOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }

    func toggleRecording() {
        switch state {
        case .idle, .cancelled, .success, .failure:
            do { focusTarget = insertion.captureTarget(); try recorder.start(); state = .recording(startedAt: Date()); logger.info("Recording started") }
            catch { logger.error("Recording failed: \(error.localizedDescription, privacy: .public)"); state = .failure(error.localizedDescription, transcript: nil) }
        case .recording:
            do {
                let url = try recorder.stop(); state = .transcribing
                Task { await transcribe(url) }
            }
            catch { recorder.cancel(); state = .failure(error.localizedDescription, transcript: nil) }
        default: break
        }
    }

    func cancel() { recorder.cancel(); state = .cancelled }

    private func transcribe(_ url: URL) async {
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let language = preferences.language == "auto" ? nil : preferences.language
            let text = try await transcriptionEngine.transcribe(audioAt: url, language: language)
            guard !text.isEmpty else { state = .failure("No speech was detected.", transcript: nil); return }
            lastTranscript = text
            copyLastTranscript()
            state = .inserting
            do {
                try await insertion.insert(text, into: focusTarget)
                state = .success(text)
            } catch { state = .failure(error.localizedDescription, transcript: text) }
        } catch { logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)"); state = .failure("Transcription failed: \(error.localizedDescription)", transcript: nil) }
    }

    func copyLastTranscript() {
        guard let lastTranscript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
    }

    func applyShortcutPreference() {
        shortcuts.start(choice: preferences.shortcut)
    }

    private func scheduleIdle(after delay: Duration = .seconds(3)) {
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.state = .idle
        }
    }
}
