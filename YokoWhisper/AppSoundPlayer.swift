import AppKit
import Foundation

enum AppSound: String, CaseIterable {
    case recordingBegan = "recording-start"
    case recordingReleased = "recording-release"
}

@MainActor
protocol AppSoundPlaying {
    func play(_ sound: AppSound)
}

@MainActor
final class AppSoundPlayer: AppSoundPlaying {
    private let sounds: [AppSound: NSSound]
    private var currentSound: NSSound?

    init(bundle: Bundle = .main) {
        sounds = Dictionary(uniqueKeysWithValues: AppSound.allCases.compactMap { sound in
            guard let url = bundle.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let player = NSSound(contentsOf: url, byReference: true)
            else { return nil }
            return (sound, player)
        })
    }

    func play(_ sound: AppSound) {
        guard let player = sounds[sound] else { return }
        currentSound?.stop()
        player.currentTime = 0
        player.play()
        currentSound = player
    }
}
