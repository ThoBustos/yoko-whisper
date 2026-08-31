import AppKit
import SwiftUI

enum HUDLayout {
    static let size = CGSize(width: 148, height: 36)
    static let topInset: CGFloat = 10

    static func origin(panelSize: CGSize = size, visibleFrame: CGRect) -> CGPoint {
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
            contentRect: CGRect(origin: .zero, size: HUDLayout.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: DictationHUD(model: model))
    }

    func update(for state: DictationState) {
        switch state {
        case .recording:
            displayScreen = screenAtPointer() ?? NSScreen.main
            show()
        case .transcribing, .inserting, .success, .failure:
            show()
        default:
            panel.orderOut(nil)
            displayScreen = nil
        }
    }

    private func show() {
        guard let screen = displayScreen ?? screenAtPointer() ?? NSScreen.main else { return }
        panel.setFrameOrigin(HUDLayout.origin(visibleFrame: screen.visibleFrame))
        panel.orderFrontRegardless()
    }

    private func screenAtPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) }
    }
}

private struct DictationHUD: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            stateIndicator
                .frame(width: 18, height: 18)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .frame(width: HUDLayout.size.width, height: HUDLayout.size.height)
        .foregroundStyle(Brand.ink)
        .background(Brand.paper, in: Capsule())
        .overlay(Capsule().stroke(Brand.ink.opacity(0.2), lineWidth: 0.75))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch model.state {
        case .recording:
            Image(systemName: "waveform")
                .foregroundStyle(Brand.orange)
        case .transcribing, .inserting:
            ProgressView()
                .controlSize(.mini)
                .tint(Brand.orange)
        case .success:
            Image(systemName: "checkmark")
                .fontWeight(.bold)
                .foregroundStyle(Brand.success)
        case .failure:
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(Brand.lavender)
        default:
            EmptyView()
        }
    }

    private var label: String {
        switch model.state {
        case .recording: "Listening"
        case .transcribing: "Transcribing"
        case .inserting: "Inserting"
        case .success: "Inserted"
        case .failure(_, let transcript): transcript == nil ? "Try again" : "Copied"
        default: "Yoko Whisper"
        }
    }
}
