import Foundation
import SwiftUI

enum GamePhase: Equatable {
    case menu
    case attract
    case playing
    case paused
    case gameOver
    case enteringScore
}

enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case novice = "Novice"
    case arcade = "Arcade"
    case insane = "Insane"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .novice: return "NOVICE"
        case .arcade: return "ARCADE"
        case .insane: return "INSANE"
        }
    }

    var startingBalls: Int {
        switch self {
        case .novice: return 125
        case .arcade: return 100
        case .insane: return 75
        }
    }

    /// Center distance of the two nails over the start hole. Wider is an easier shot.
    /// Each value stays far enough apart for a ball to fall through.
    var chuckerGap: Double {
        switch self {
        case .novice: return 31
        case .arcade: return 26
        case .insane: return 22
        }
    }

    var feverChance: Double {
        switch self {
        case .novice: return 0.09
        case .arcade: return 0.055
        case .insane: return 0.035
        }
    }

    var feverRounds: Int {
        switch self {
        case .novice: return 16
        case .arcade: return 12
        case .insane: return 8
        }
    }

    var fireInterval: Double {
        switch self {
        case .novice: return 0.16
        case .arcade: return 0.18
        case .insane: return 0.22
        }
    }
}

enum PocketKind {
    case chucker
    case tulip
    case attacker
    case out
}

struct Pocket {
    var pos: Vec
    var radius: Double
    var kind: PocketKind
    var payout: Int
    var open: Bool
    var flash: Double
    var label: String
}

enum ReelSymbol: Int, CaseIterable {
    case blank = 0
    case cherry
    case bell
    case bar
    case seven
    case star

    var glyph: String {
        switch self {
        case .blank: return "—"
        case .cherry: return "桜"
        case .bell: return "ベル"
        case .bar: return "BAR"
        case .seven: return "7"
        case .star: return "★"
        }
    }

    var shortGlyph: String {
        switch self {
        case .blank: return "—"
        case .cherry: return "桜"
        case .bell: return "ベル"
        case .bar: return "BAR"
        case .seven: return "7"
        case .star: return "★"
        }
    }
}

struct Reel {
    var offset: Double = 0
    var speed: Double = 0
    var spinning: Bool = false
    var stopIndex: Int = 0
    var display: ReelSymbol = .seven
}

struct Windmill {
    var pos: Vec
    var angle: Double
    var speed: Double
    var armLength: Double
    var thickness: Double
}

struct Particle {
    var pos: Vec
    var vel: Vec
    var life: Double
    var maxLife: Double
    var colorIndex: Int
    var size: Double
    var petal: Bool
}

struct FloatingScore {
    var pos: Vec
    var text: String
    var life: Double
    var colorIndex: Int
}

struct RailStreak {
    var t: Double
    var power: Double
}

struct HighScoreEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var initials: String
    var score: Int
    var table: String
    var difficulty: String
    var date: Date

    init(
        id: UUID = UUID(),
        initials: String,
        score: Int,
        table: String,
        difficulty: String,
        date: Date = Date()
    ) {
        self.id = id
        self.initials = String(initials.uppercased().prefix(3)).padding(toLength: 3, withPad: "A", startingAt: 0)
        self.score = score
        self.table = table
        self.difficulty = difficulty
        self.date = date
    }
}

@MainActor
final class HighScoreStore: ObservableObject {
    static let shared = HighScoreStore()
    static let maxEntries = 10
    private static let key = "pachinko.highScores.v1"

    @Published private(set) var entries: [HighScoreEntry] = []

    private init() { load() }

    var topScore: Int { entries.first?.score ?? 0 }

    func qualifies(_ score: Int) -> Bool {
        guard score > 0 else { return false }
        if entries.count < Self.maxEntries { return true }
        return score > (entries.last?.score ?? 0)
    }

    func rank(for score: Int) -> Int? {
        guard qualifies(score) else { return nil }
        if let idx = entries.firstIndex(where: { score > $0.score }) {
            return idx + 1
        }
        return entries.count + 1
    }

    @discardableResult
    func submit(initials: String, score: Int, table: CabinetTheme, difficulty: Difficulty) -> Bool {
        guard qualifies(score) else { return false }
        let entry = HighScoreEntry(
            initials: initials,
            score: score,
            table: table.shortName,
            difficulty: difficulty.shortName
        )
        entries.append(entry)
        entries.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.date < b.date
        }
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        save()
        return true
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return }
        let decoded = (try? JSONDecoder().decode([HighScoreEntry].self, from: data)) ?? []
        entries = decoded.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.date < b.date
        }
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
