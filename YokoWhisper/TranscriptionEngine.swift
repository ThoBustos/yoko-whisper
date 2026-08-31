import Foundation
@preconcurrency import WhisperKit

enum EngineReadiness: Equatable, Sendable { case notDownloaded, downloading(Double), ready, failed(String) }

@MainActor
protocol TranscriptionEngine: AnyObject {
    var readiness: EngineReadiness { get }
    func prepare() async throws
    func transcribe(audioAt url: URL, language: String?) async throws -> String
}

@MainActor
final class WhisperKitEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private(set) var readiness: EngineReadiness = .notDownloaded
    private let model = "openai_whisper-small"

    func prepare() async throws {
        guard whisperKit == nil else { readiness = .ready; return }
        readiness = .downloading(0)
        do {
            let config = WhisperKitConfig(model: model, verbose: false, prewarm: true, load: true)
            whisperKit = try await WhisperKit(config)
            readiness = .ready
        } catch {
            readiness = .failed(error.localizedDescription)
            throw error
        }
    }

    func transcribe(audioAt url: URL, language: String?) async throws -> String {
        try await prepare()
        guard let whisperKit else { throw CocoaError(.featureUnsupported) }
        let options = DecodingOptions(language: language, skipSpecialTokens: true)
        let results = try await whisperKit.transcribe(audioPath: url.path, decodeOptions: options)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
