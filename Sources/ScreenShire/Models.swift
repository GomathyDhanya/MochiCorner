import Foundation

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case work, code, study, music, entertainment, social, create, game, uncategorized, idle
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self { case .work: "briefcase"; case .code: "chevron.left.forwardslash.chevron.right"; case .study: "book"; case .music: "music.note"; case .entertainment: "film"; case .social: "bubble.left.and.bubble.right"; case .create: "paintpalette"; case .game: "gamecontroller"; case .uncategorized: "questionmark.circle"; case .idle: "moon" }
    }
}

struct TrackedApp: Codable, Identifiable, Hashable {
    let id: String
    var displayName: String
    var category: ActivityCategory
}

struct UsageSession: Codable, Identifiable, Hashable {
    let id: UUID
    let bundleIdentifier: String
    let appName: String
    var category: ActivityCategory
    let startedAt: Date
    var endedAt: Date?
    var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
}

struct UsageGoal: Codable, Identifiable, Hashable {
    let id: UUID
    var category: ActivityCategory
    var dailyLimitMinutes: Int
    var enabled: Bool
}

struct DailyChronicle: Codable, Identifiable {
    let id: UUID
    let date: Date
    var title: String
    var story: String
    var memorySummary: String
}

struct ActivityTotal: Identifiable { let category: ActivityCategory; let minutes: Int; var id: String { category.rawValue } }
