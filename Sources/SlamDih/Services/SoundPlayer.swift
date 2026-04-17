import AVFoundation
import Foundation

enum SlapSound: String, CaseIterable, Identifiable {
    case slap
    case fart
    case sexy
    case yowch

    var id: Self { self }

    var title: String {
        switch self {
        case .slap:
            "Slap"
        case .fart:
            "Fart"
        case .sexy:
            "Sexy"
        case .yowch:
            "Yowch"
        }
    }

    var resourceName: String {
        switch self {
        case .slap:
            "SlapSoundEffect"
        case .fart:
            "FartSoundEffect"
        case .sexy:
            "SexySoundEffect"
        case .yowch:
            "YowchSoundEffect"
        }
    }

    var symbol: String {
        switch self {
        case .slap:
            "hand.raised.fill"
        case .fart:
            "wind"
        case .sexy:
            "sparkles"
        case .yowch:
            "exclamationmark.bubble.fill"
        }
    }
}

final class SoundPlayer {
    private var players: [SlapSound: AVAudioPlayer] = [:]

    init() {
        for sound in SlapSound.allCases {
            guard let url = Self.resourceURL(for: sound) else {
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

    private static func resourceURL(for sound: SlapSound) -> URL? {
        #if SWIFT_PACKAGE
        if let packageURL = Bundle.module.url(forResource: sound.resourceName, withExtension: "mp3") {
            return packageURL
        }
        #endif

        return Bundle.main.url(forResource: sound.resourceName, withExtension: "mp3")
    }
}
