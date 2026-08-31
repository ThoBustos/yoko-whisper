import AppKit
import SwiftUI

enum HUDLayout {
    static let recordingSize = CGSize(width: 84, height: 36)
    static let statusSize = CGSize(width: 148, height: 36)
    static let topInset: CGFloat = 10

    static func size(for state: DictationState) -> CGSize {
        if case .recording = state { return recordingSize }
        return statusSize
    }

    static func origin(panelSize: CGSize, visibleFrame: CGRect) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.maxY - panelSize.height - topInset
        )
    }
}

@MainActor
final class HUDController {
    private let panel: NSPanel
    private var displayScreen: NSScreen?

    init(model: AppModel) {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: HUDLayout.statusSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: DictationHUD(model: model))
    }

    func update(for state: DictationState) {
        panel.setContentSize(HUDLayout.size(for: state))
        switch state {
        case .recording:
            displayScreen = screenAtPointer() ?? NSScreen.main
            show()
        case .transcribing, .inserting, .success, .copied, .failure:
            show()
        default:
            panel.orderOut(nil)
            displayScreen = nil
        }
    }

    private func show() {
        guard let screen = displayScreen ?? screenAtPointer() ?? NSScreen.main else { return }
        panel.setFrameOrigin(HUDLayout.origin(panelSize: panel.frame.size, visibleFrame: screen.visibleFrame))
        panel.orderFrontRegardless()
    }

    private func screenAtPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) }
    }
}

private struct DictationHUD: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let model: AppModel
    @State private var isHovering = false

    var body: some View {
        Group {
            if case .recording = model.state {
                recordingControl
            } else {
                HStack(spacing: 9) {
                    stateIndicator
                        .frame(width: 18, height: 18)
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .padding(.horizontal, 13)
            }
        }
        .frame(width: HUDLayout.size(for: model.state).width, height: HUDLayout.statusSize.height)
        .foregroundStyle(.white)
        .background { hudBackground }
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.75))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var hudBackground: some View {
        if reduceTransparency {
            Capsule().fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        } else {
            HUDMaterialBackground()
                .overlay(Color.black.opacity(0.35))
                .clipShape(Capsule())
        }
    }

    private var recordingControl: some View {
        HStack(spacing: 8) {
            LiveWaveform(level: { model.recorder.level })
                .frame(width: 24, height: 18)
            if isHovering {
                Divider().overlay(.white.opacity(0.28)).frame(height: 16)
                Button { model.finishRecordingFromHUD() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and transcribe")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Capsule())
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch model.state {
        case .recording:
            LiveWaveform(level: { model.recorder.level })
        case .transcribing, .inserting:
            ProgressView()
                .controlSize(.mini)
                .tint(Brand.orange)
        case .success:
            Image(systemName: "checkmark")
                .fontWeight(.bold)
                .foregroundStyle(Brand.success)
        case .copied:
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(Brand.lavender)
        case .failure:
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(Brand.lavender)
        default:
            EmptyView()
        }
    }

    private var label: String {
        switch model.state {
        case .recording: "Recording. Hover to stop and transcribe."
        case .transcribing: "Transcribing"
        case .inserting: "Inserting"
        case .success: "Inserted"
        case .copied: "Copied"
        case .failure(_, let transcript): transcript == nil ? "Try again" : "Copied"
        default: "Yoko Whisper"
        }
    }
}

private struct HUDMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.state = .active
    }
}

private struct LiveWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: () -> Float

    var body: some View {
        if reduceMotion {
            bars(level: max(level(), 0.18))
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { _ in
                bars(level: level())
            }
        }
    }

    private func bars(level: Float) -> some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(WaveformLevels.samples(level: level).enumerated()), id: \.offset) { _, sample in
                Capsule()
                    .fill(Brand.orange)
                    .frame(width: 2.5, height: CGFloat(sample * 15 + 3))
            }
        }
        .frame(height: 18)
    }
}

enum WaveformLevels {
    private static let weights: [Float] = [0.45, 0.78, 1, 0.72, 0.42]

    static func samples(level: Float) -> [Float] {
        let clamped = min(1, max(0, level))
        return weights.map { max(0.08, clamped * $0) }
    }
}
