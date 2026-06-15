import Foundation
import Observation

/// Hardness tier derived from the impact magnitude (in g) of a slap.
enum SlapHardness: Int, CaseIterable, Comparable {
    case soft
    case solid
    case hard
    case brutal
    case devastating

    init(impact: Double) {
        switch impact {
        case ..<1.0:
            self = .soft
        case 1.0..<2.0:
            self = .solid
        case 2.0..<3.5:
            self = .hard
        case 3.5..<5.0:
            self = .brutal
        default:
            self = .devastating
        }
    }

    var label: String {
        switch self {
        case .soft:
            "Soft"
        case .solid:
            "Solid"
        case .hard:
            "Hard"
        case .brutal:
            "Brutal"
        case .devastating:
            "Devastating"
        }
    }

    var symbol: String {
        switch self {
        case .soft:
            "leaf.fill"
        case .solid:
            "hand.raised.fill"
        case .hard:
            "flame.fill"
        case .brutal:
            "bolt.fill"
        case .devastating:
            "burst.fill"
        }
    }

    static func < (lhs: SlapHardness, rhs: SlapHardness) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single recorded slap with the moment it landed and how hard it hit.
struct SlapRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let impact: Double

    init(id: UUID = UUID(), date: Date = Date(), impact: Double) {
        self.id = id
        self.date = date
        self.impact = impact
    }

    var hardness: SlapHardness {
        SlapHardness(impact: impact)
    }
}

/// Persistent lifetime history of every detected slap, with aggregate stats.
@MainActor
@Observable
final class SlapStatsStore {
    /// Newest first.
    private(set) var events: [SlapRecord] = []

    @ObservationIgnored private let storeURL: URL?
    @ObservationIgnored private let maximumStoredEvents = 2000

    init(storeURL: URL? = SlapStatsStore.defaultStoreURL()) {
        self.storeURL = storeURL
        events = Self.load(from: storeURL)
    }

    // MARK: - Recording

    func record(impact: Double) {
        let event = SlapRecord(impact: impact)
        events.insert(event, at: 0)

        if events.count > maximumStoredEvents {
            events.removeLast(events.count - maximumStoredEvents)
        }

        persist()
    }

    func clear() {
        guard !events.isEmpty else {
            return
        }

        events.removeAll()
        persist()
    }

    // MARK: - Aggregates

    var totalSlaps: Int {
        events.count
    }

    var maxImpact: Double {
        events.map(\.impact).max() ?? 0
    }

    var averageImpact: Double {
        guard !events.isEmpty else {
            return 0
        }

        return events.reduce(0) { $0 + $1.impact } / Double(events.count)
    }

    var hardestEvent: SlapRecord? {
        events.max { $0.impact < $1.impact }
    }

    var hardestHardness: SlapHardness {
        SlapHardness(impact: maxImpact)
    }

    var lastEvent: SlapRecord? {
        events.first
    }

    var slapsToday: Int {
        let calendar = Calendar.current
        return events.filter { calendar.isDateInToday($0.date) }.count
    }

    /// Count of slaps grouped by hardness tier, ordered from soft to devastating.
    var hardnessBreakdown: [(hardness: SlapHardness, count: Int)] {
        SlapHardness.allCases.map { hardness in
            (hardness, events.filter { $0.hardness == hardness }.count)
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let storeURL else {
            return
        }

        let snapshot = events
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(snapshot)
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Stats are non-critical; a failed write must never break detection.
        }
    }

    private static func load(from url: URL?) -> [SlapRecord] {
        guard let url, let data = try? Data(contentsOf: url) else {
            return []
        }

        let decoded = (try? JSONDecoder().decode([SlapRecord].self, from: data)) ?? []
        return decoded.sorted { $0.date > $1.date }
    }

    private static func defaultStoreURL() -> URL? {
        guard let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        return supportDirectory
            .appendingPathComponent("SlamX", isDirectory: true)
            .appendingPathComponent("slap-events.json", isDirectory: false)
    }
}
