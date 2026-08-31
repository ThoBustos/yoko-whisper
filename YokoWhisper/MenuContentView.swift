import SwiftUI

struct MenuContentView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 18) {
                recordControl
                if case .recording = model.state {
                    ProgressView(value: Double(model.recorder.level)).tint(Brand.orange)
                    Button("Cancel Recording", role: .cancel) { model.cancel() }.controlSize(.small)
                }
                if model.permissions.microphone != .granted || model.permissions.accessibility != .granted {
                    permissionWarning
                }
                if let transcript = model.lastTranscript {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAST TRANSCRIPT").font(Brand.label).foregroundStyle(.secondary)
                        Text(transcript).font(.callout).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                        Button { model.copyLastTranscript() } label: { Label("Copy Again", systemImage: "doc.on.doc") }
                            .controlSize(.small)
                    }
                }
            }
            .padding(20)
            Divider()
            HStack {
                Text("Audio stays on this Mac").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Settings…") { openSettings() }.buttonStyle(.link)
            }
            .padding(.horizontal, 20)
            .frame(height: 42)
        }
        .frame(width: 320)
        .background(.background)
        .onAppear { model.startIntegrations() }
        .task {
            while !Task.isCancelled {
                model.permissions.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Yoko Whisper").font(.headline)
                Text("Local dictation").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(model.status.capitalized).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background(Brand.paper.opacity(0.45))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var recordControl: some View {
        VStack(spacing: 10) {
            Button { model.toggleRecordingFromMenu() } label: {
                Image(systemName: recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Brand.ink)
                    .frame(width: 48, height: 48)
                    .background(Brand.orange, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recording ? "Stop dictation" : "Start dictation")
            Text(recording ? "Listening…" : "Press \(model.preferences.shortcut.label) to dictate").font(.callout)
            Text(recording ? "Release to finish · Esc to cancel" : "Hold (model.preferences.shortcut.label) to dictate")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var permissionWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Brand.orange)
            VStack(alignment: .leading, spacing: 5) {
                Text("Setup required").font(.callout.weight(.medium))
                Text("Microphone and Accessibility access are required for dictation and cursor insertion.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Settings…") { openSettings() }.buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var recording: Bool {
        if case .recording = model.state { return true }
        return false
    }

    private var statusColor: Color {
        switch model.state {
        case .failure: .red
        case .recording, .transcribing, .inserting: Brand.orange
        default: Brand.success
        }
    }
}

struct SettingsView: View {
    let model: AppModel
    @State private var testText = ""

    var body: some View {
        Form {
            Section("Permissions") {
                permissionRow("Microphone", detail: "Records audio only while you dictate.", state: model.permissions.microphone) {
                    Task { _ = await model.permissions.requestMicrophone() }
                } openPrivacy: { model.permissions.openPrivacyPane("Microphone") }
                permissionRow("Accessibility", detail: "Inserts text at the original cursor.", state: model.permissions.accessibility) {
                    model.permissions.requestAccessibility()
                } openPrivacy: { model.permissions.openPrivacyPane("Accessibility") }
            }
            Section("Dictation") {
                Picker("Shortcut", selection: Binding(
                    get: { model.preferences.shortcut },
                    set: { model.preferences.shortcut = $0; model.applyShortcutPreference() }
                )) { ForEach(ShortcutChoice.allCases) { Text($0.label).tag($0) } }
                Picker("Language", selection: Bindable(model.preferences).language) {
                    Text("Automatic").tag("auto")
                    Text("English").tag("en")
                    Text("French").tag("fr")
                    Text("Spanish").tag("es")
                    Text("German").tag("de")
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { model.preferences.launchAtLogin },
                    set: { model.preferences.setLaunchAtLogin($0) }
                ))
                if let error = model.preferences.launchAtLoginError { Text(error).foregroundStyle(.red) }
            }
            Section("Test Dictation") {
                Text("Click the field, then use the global shortcut. Do not click the menu-bar microphone.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Transcript appears here", text: $testText)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 520, height: 430)
        .task {
            while !Task.isCancelled {
                model.permissions.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder
    private func permissionRow(
        _ title: String,
        detail: String,
        state: PermissionState,
        request: @escaping () -> Void,
        openPrivacy: @escaping () -> Void
    ) -> some View {
        LabeledContent {
            HStack {
                Label(state.rawValue.capitalized, systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(state == .granted ? Brand.success : Brand.orange)
                if state != .granted {
                    Button(state == .unknown ? "Allow" : "Open System Settings") {
                        state == .unknown ? request() : openPrivacy()
                    }
                }
            }
        } label: {
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
