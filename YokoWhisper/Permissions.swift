import AVFoundation
import ApplicationServices
import AppKit
import Observation

enum PermissionState: String, Sendable { case unknown, denied, granted }

@MainActor
@Observable
final class PermissionService {
    private(set) var microphone: PermissionState = .unknown
    private(set) var accessibility: PermissionState = .denied

    init() { refresh() }

    func refresh() {
        microphone = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
        accessibility = AXIsProcessTrusted() ? .granted : .denied
    }

    func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
        return granted
    }

    func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refresh()
    }

    func openPrivacyPane(_ pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)")!
        NSWorkspace.shared.open(url)
    }
}
