import XCTest
@testable import ScreenShire

final class ScreenShireTests: XCTestCase {
    func testBuiltInClassifierRecognizesCode() {
        XCTAssertEqual(AppCategoryClassifier(customMappings: [:]).category(for: "com.apple.dt.Xcode"), .code)
    }
    func testCustomMappingWins() {
        let mapping = TrackedApp(id: "com.apple.Safari", displayName: "Safari", category: .study)
        XCTAssertEqual(AppCategoryClassifier(customMappings: [mapping.id: mapping]).category(for: mapping.id), .study)
    }
    func testDailyTotalsExcludeTimeOutsideDay() {
        let calendar = Calendar(identifier: .gregorian)
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 12))!
        let session = UsageSession(id: UUID(), bundleIdentifier: "test", appName: "Test", category: .code, startedAt: noon, endedAt: noon.addingTimeInterval(90 * 60))
        XCTAssertEqual(ActivityAnalyticsService.totals([session], for: noon, calendar: calendar).first?.minutes, 90)
    }
    func testEverySuppliedCatFrameLoads() {
        let scenes = ActivityCategory.allCases.filter { $0 != .idle && $0 != .uncategorized }
        for scene in scenes {
            for frame in 0...2 { XCTAssertNotNil(CatSpriteLibrary.image(for: scene, frame: frame), "Missing \(scene.rawValue) frame \(frame)") }
        }
        XCTAssertNotNil(CatSpriteLibrary.image(for: .idle, frame: 0))
        XCTAssertNotNil(CatSpriteLibrary.image(for: .uncategorized, frame: 0))
        for frame in 0...2 { XCTAssertNotNil(CatSpriteLibrary.bellyRub(frame: frame), "Missing belly-rub frame \(frame)") }
    }
    func testGoalStatusMarksLimitReached() {
        let now = Date()
        let session = UsageSession(id: UUID(), bundleIdentifier: "test", appName: "Test", category: .social, startedAt: now.addingTimeInterval(-50 * 60), endedAt: now)
        let goal = UsageGoal(id: UUID(), category: .social, dailyLimitMinutes: 45, enabled: true)
        XCTAssertTrue(GoalEvaluator.statuses(sessions: [session], goals: [goal], date: now).first?.isReached == true)
    }
    func testOverlappingSessionsAreNotDoubleCounted() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 9))!
        let first = UsageSession(id: UUID(), bundleIdentifier: "a", appName: "A", category: .work, startedAt: start, endedAt: start.addingTimeInterval(120 * 60))
        let second = UsageSession(id: UUID(), bundleIdentifier: "b", appName: "B", category: .code, startedAt: start.addingTimeInterval(60 * 60), endedAt: start.addingTimeInterval(150 * 60))
        let total = ActivityAnalyticsService.totals([first, second], for: start, calendar: calendar).reduce(0) { $0 + $1.minutes }
        XCTAssertEqual(total, 150)
    }
}
