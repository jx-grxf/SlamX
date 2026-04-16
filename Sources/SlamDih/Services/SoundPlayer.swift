import AVFoundation
import Foundation

enum SlapSound: String, CaseIterable, Identifiable {
    case slap
    case fart

    var id: Self { self }

    var title: String {
        switch self {
        case .slap:
            "Slap"
        case .fart:
            "Fart"
        }
    }

    var resourceName: String {
        switch self {
        case .slap:
            "SlapSoundEffect"
        case .fart:
            "FartSoundEffect"
        }
    }

    var symbol: String {
        switch self {
        case .slap:
            "hand.raised.fill"
        case .fart:
            "wind"
        }
    }
}

final class SoundPlayer {
    private var players: [SlapSound: AVAudioPlayer] = [:]

    init() {
        for sound in SlapSound.allCases {
            guard let url = Bundle.module.url(forResource: sound.resourceName, withExtension: "mp3") else {
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[sound] = player
            } catch {
                players[sound] = nil
            }
        }
    }

    func isReady(for sound: SlapSound) -> Bool {
        players[sound] != nil
    }

    func play(_ sound: SlapSound) {
        guard let player = players[sound] else {
            return
        }

        player.currentTime = 0
        player.play()
    }
}
