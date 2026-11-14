import AVFoundation
import Foundation

struct GoalStatus: Identifiable, Equatable {
    let goal: UsageGoal
    let usedMinutes: Int
    var id: UUID { goal.id }
    var remainingMinutes: Int { max(0, goal.dailyLimitMinutes - usedMinutes) }
    var isReached: Bool { usedMinutes >= goal.dailyLimitMinutes }
}

enum GoalEvaluator {
    static func statuses(sessions: [UsageSession], goals: [UsageGoal], date: Date = .now) -> [GoalStatus] {
        let minutes = Dictionary(uniqueKeysWithValues: ActivityAnalyticsService.totals(sessions, for: date).map { ($0.category, $0.minutes) })
        return goals.filter(\.enabled).map { GoalStatus(goal: $0, usedMinutes: minutes[$0.category, default: 0]) }
    }
}

@MainActor
final class MeowPlayer {
    private var player: AVAudioPlayer?
    func playGoalReached() {
        // SwiftPM processes resources into the root of the resource bundle.
        guard let url = Bundle.module.url(forResource: "cat-meow", withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.85
        player?.prepareToPlay()
        player?.play()
    }
}
