# Contributing

Thanks for helping improve Yoko Whisper.

## Development

1. Use macOS 14 or newer on Apple Silicon with Xcode 16 or newer.
2. Open `YokoWhisper.xcodeproj` or regenerate it with `xcodegen generate` after changing `project.yml`.
3. For on-device permission testing, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your Apple Development Team ID. The local file is ignored by Git.
4. Run the complete test command from the README before opening a pull request.
5. Complete the relevant items in `docs/MANUAL-TEST-CHECKLIST.md` for changes involving audio, shortcuts, permissions, focus, or insertion.

Keep pull requests focused and keep every commit buildable. Add deterministic tests for state or policy changes; document system integrations that require manual verification.

## Privacy and security

- Do not commit recordings, transcripts, model files, credentials, signing identities, provisioning profiles, personal paths, or DerivedData.
- Do not log transcript or recording contents.
- Keep raw audio temporary and local.
- Do not introduce network transcription, telemetry, or persistent history without an explicit product and privacy review.
- Report vulnerabilities through GitHub private vulnerability reporting as described in `SECURITY.md`.
