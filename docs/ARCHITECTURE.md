# Architecture

Yoko Whisper is a native macOS menu-bar application with one bounded dictation pipeline:

`shortcut press → record → shortcut release → transcribe → insert or copy`

## Boundaries

- `ShortcutService` owns the consuming `CGEventTap`. Its callback performs only matching and press-state transitions before returning work to the main actor.
- `AudioRecorder` owns `AVAudioEngine` and the temporary audio file. The realtime callback uses lock-bounded synchronous work and never enters the main actor.
- `DictationCoordinator` owns the session state, focus snapshot, cancellation, transcription, cleanup, and final insertion outcome.
- `TranscriptionEngine` isolates WhisperKit so another local engine can be benchmarked without changing the workflow.
- `TextInsertionService` copies first, rejects secure or non-editable targets, prefers Accessibility selected-text insertion, and falls back to Command-V.
- `HUDController` owns a non-activating panel. SwiftUI renders only observable state and sampled microphone level.
- `AppModel` wires services to the menu-bar and Settings surfaces; it does not implement the dictation pipeline.

## Concurrency and privacy invariants

- AppKit and observable UI state remain on `MainActor`.
- Audio and event-tap callbacks stay synchronous, minimal, and outside actor-isolated application state.
- Only one recording/transcription session may be active.
- Temporary audio is removed after success, failure, or cancellation.
- Every valid transcript is placed on the clipboard before insertion is attempted.
- Only the latest transcript is retained in local preferences, and the user can clear it from the menu.
- Secure fields never receive synthetic or Accessibility insertion.
- Logs describe operations and failures without intentionally logging transcripts or recordings.

## Project structure

- `YokoWhisper/`: production sources and privacy manifest.
- `YokoWhisperTests/`: deterministic state, policy, layout, shortcut, and signal tests.
- `docs/`: architecture and manual system-integration coverage.
- `project.yml`: XcodeGen source of truth.
- `YokoWhisper.xcodeproj`: generated project committed for contributors who do not use XcodeGen.

Cross-application focus and insertion cannot be proven by unit tests. Complete the manual matrix before describing the path as verified.
