import AVFoundation
import Foundation

enum SlapSound: String, CaseIterable, Identifiable {
    case slap
    case fart
    case sexy
    case yowch
    case whip

    var id: Self { self }

    var title: String {
        switch self {
        case .slap:
            "Impact"
        case .fart:
            "Air Pop"
        case .sexy:
            "Spotlight"
        case .yowch:
            "Alert"
        case .whip:
            "Snap"
        }
    }

    var isBonus: Bool {
        self == .sexy
    }

    var resourceName: String {
        switch self {
        case .slap:
            "ImpactSoundEffect"
        case .fart:
            "AirPopSoundEffect"
        case .sexy:
            "SpotlightSoundEffect"
        case .yowch:
            "AlertSoundEffect"
        case .whip:
            "SnapSoundEffect"
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
        case .whip:
            "lasso"
        }
    }

    static func availableSounds(includeBonus: Bool) -> [SlapSound] {
        allCases.filter { includeBonus || !$0.isBonus }
    }
}

struct CustomSlapSound: Identifiable, Hashable {
    let id: String
    let title: String
}

enum SoundPlayerError: LocalizedError {
    case customDirectoryUnavailable
    case unsupportedAudioFile

    var errorDescription: String? {
        switch self {
        case .customDirectoryUnavailable:
            "Custom sound storage is not available."
        case .unsupportedAudioFile:
            "Choose an MP3 audio file."
        }
    }
}

final class SoundPlayer {
    private static let supportedAudioExtensions = Set(["mp3"])

    private var bundledPlayers: [SlapSound: AVAudioPlayer] = [:]
    private var customPlayers: [URL: AVAudioPlayer] = [:]

    init() {
        for sound in SlapSound.allCases {
            guard let url = Self.resourceURL(for: sound) else {
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                bundledPlayers[sound] = player
            } catch {
                bundledPlayers[sound] = nil
            }
        }
    }

    func isReady(for sound: SlapSound, customSoundID: String?) -> Bool {
        if let customSoundID, !customSoundID.isEmpty {
            guard let customURL = customURL(id: customSoundID) else {
                return false
            }

            return FileManager.default.fileExists(atPath: customURL.path)
        }

        return bundledPlayers[sound] != nil
    }

    func play(_ sound: SlapSound, customSoundID: String? = nil) {
        if let customSoundID,
           !customSoundID.isEmpty,
           let customURL = customURL(id: customSoundID),
           playCustomSound(at: customURL) {
            return
        }

        guard let player = bundledPlayers[sound] else {
            return
        }

        player.currentTime = 0
        player.play()
    }

    func customSounds() -> [CustomSlapSound] {
        guard let directory = customDirectory() else {
            return []
        }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { Self.supportedAudioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { CustomSlapSound(id: $0.lastPathComponent, title: $0.deletingPathExtension().lastPathComponent) }
    }

    func importCustomSound(from sourceURL: URL) throws -> CustomSlapSound {
        guard Self.supportedAudioExtensions.contains(sourceURL.pathExtension.lowercased()) else {
            throw SoundPlayerError.unsupportedAudioFile
        }

        guard let directory = customDirectory() else {
            throw SoundPlayerError.customDirectoryUnavailable
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationURL = uniqueDestinationURL(for: sourceURL, in: directory)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        customPlayers[destinationURL] = nil
        return CustomSlapSound(
            id: destinationURL.lastPathComponent,
            title: destinationURL.deletingPathExtension().lastPathComponent
        )
    }

    func customSoundExists(id: String) -> Bool {
        guard let url = customURL(id: id) else {
            return false
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    func removeCustomSound(id: String) throws {
        guard let url = customURL(id: id), FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        customPlayers[url] = nil
        try FileManager.default.removeItem(at: url)
    }

    private static func resourceURL(for sound: SlapSound) -> URL? {
        #if SWIFT_PACKAGE
        if let packageURL = Bundle.module.url(forResource: sound.resourceName, withExtension: "mp3") {
            return packageURL
        }
        #endif

        return Bundle.main.url(forResource: sound.resourceName, withExtension: "mp3")
    }

    private func playCustomSound(at url: URL) -> Bool {
        do {
            let player: AVAudioPlayer
            if let cachedPlayer = customPlayers[url] {
                player = cachedPlayer
            } else {
                let newPlayer = try AVAudioPlayer(contentsOf: url)
                newPlayer.prepareToPlay()
                customPlayers[url] = newPlayer
                player = newPlayer
            }

            player.currentTime = 0
            player.play()
            return true
        } catch {
            customPlayers[url] = nil
            return false
        }
    }

    private func customURL(id: String) -> URL? {
        customDirectory()?.appendingPathComponent(id)
    }

    private func customDirectory() -> URL? {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return applicationSupportURL
            .appendingPathComponent("SlamDih", isDirectory: true)
            .appendingPathComponent("CustomSounds", isDirectory: true)
    }

    private func uniqueDestinationURL(for sourceURL: URL, in directory: URL) -> URL {
        let sanitizedName = sanitizedFileName(from: sourceURL)
        let baseName = (sanitizedName as NSString).deletingPathExtension
        let fileExtension = (sanitizedName as NSString).pathExtension
        var destinationURL = directory.appendingPathComponent(sanitizedName)
        var suffix = 2

        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = directory.appendingPathComponent("\(baseName)-\(suffix).\(fileExtension)")
            suffix += 1
        }

        return destinationURL
    }

    private func sanitizedFileName(from url: URL) -> String {
        let fallbackName = "CustomSound.\(url.pathExtension.lowercased())"
        let candidate = url.lastPathComponent.isEmpty ? fallbackName : url.lastPathComponent
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-"))
        let sanitized = String(candidate.unicodeScalars.map { scalar in
            allowedCharacters.contains(scalar) ? Character(scalar) : "-"
        })

        return sanitized.isEmpty ? fallbackName : sanitized
    }
}
