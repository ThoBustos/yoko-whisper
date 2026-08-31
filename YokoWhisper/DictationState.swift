import Foundation

enum DictationState: Equatable, Sendable {
    case idle
    case recording(startedAt: Date)
    case transcribing
    case inserting
    case success(String)
    case copied(String)
    case cancelled
    case failure(String, transcript: String?)

    var label: String {
        switch self {
        case .idle: "READY"
        case .recording: "LISTENING"
        case .transcribing: "TRANSCRIBING"
        case .inserting: "INSERTING"
        case .success: "INSERTED"
        case .copied: "COPIED"
        case .cancelled: "CANCELLED"
        case .failure: "ERROR"
        }
    }

    var canBeginRecording: Bool {
        switch self {
        case .idle, .cancelled, .success, .copied, .failure: true
        default: false
        }
    }
}

enum DictationEvent: Sendable { case press, release, cancel, transcriptionFinished(String), insertionFinished, failed(String) }

struct DictationReducer {
    static func reduce(_ state: DictationState, _ event: DictationEvent) -> DictationState {
        switch (state, event) {
        case (.idle, .press): .recording(startedAt: Date())
        case (.recording, .release): .transcribing
        case (.recording, .cancel): .cancelled
        case (.transcribing, .transcriptionFinished): .inserting
        case (.inserting, .insertionFinished): .success("")
        case (_, .failed(let message)): .failure(message, transcript: nil)
        default: state
        }
    }
}
