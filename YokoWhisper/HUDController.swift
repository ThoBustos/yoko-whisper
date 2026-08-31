import AppKit
import SwiftUI

@MainActor
final class HUDController {
    private let panel: NSPanel

    init(model: AppModel) {
        panel = NSPanel(contentRect: .init(x: 0, y: 0, width: 620, height: 104),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: DictationHUD(model: model))
    }

    func update(for state: DictationState) {
        switch state {
        case .recording, .transcribing, .success, .failure: show()
        default: panel.orderOut(nil)
        }
    }

    private func show() {
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        panel.setFrameOrigin(.init(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.minY + 44))
        panel.orderFrontRegardless()
    }
}

private struct DictationHUD: View {
    let model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: model.state.label == "LISTENING" ? "mic.fill" : "waveform")
                .font(.title).frame(width: 104, height: 104).background(Brand.orange)
            VStack(alignment: .leading, spacing: 10) {
                Text(model.state.label).font(Brand.label)
                switch model.state {
                case .recording: ProgressView(value: Double(model.recorder.level)).tint(Brand.lavender)
                case .transcribing: ProgressView().controlSize(.small)
                case .success(let text): Text(text).font(Brand.label).lineLimit(2)
                case .failure(let message, _): Text(message).font(Brand.label).lineLimit(2)
                default: EmptyView()
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            Text(model.state.label == "LISTENING"
                 ? "\(model.preferences.shortcut.label.uppercased())  STOP\nESC  CANCEL"
                 : "COPIED TO CLIPBOARD")
                .font(Brand.label).padding(20)
        }
        .background(Brand.paper).foregroundStyle(Brand.ink)
        .overlay(Rectangle().stroke(Brand.ink, lineWidth: 1))
    }
}
