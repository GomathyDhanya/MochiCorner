import XCTest
import SwiftUI
@testable import ScreenShire

final class ScreenShireTests: XCTestCase {
    func testGeminiStepValidation() {
        let service = GeminiStoryService()
        let good = #"{"title":"Garden","story":"Mochi paused.","memorySummary":"A break","suggestedStep":"Sketch on paper"}"#
        XCTAssertEqual(service.decodeChapter(good)?.suggestedStep, "Sketch on paper")
        XCTAssertNil(service.decodeChapter(good.replacingOccurrences(of: "Sketch on paper", with: " ")))
    }

    @MainActor func testUnreadableDaybookIsPreserved() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("daybook.json")
        let original = Data("partial page".utf8)
        try original.write(to: file)
        let store = ActivityRepository(directory: dir)
        XCTAssertFalse(store.savePage(DaybookPage(), for: "2026-11-14"))
        XCTAssertNotNil(store.pageError)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    @MainActor func testDaybookRendersAtCompactAndWideSizes() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ActivityRepository(directory: dir)
        var page = DaybookPage()
        page.add("Walk outside before the next meeting")
        page.board = DaybookPage.Board(
            mood: "Calm",
            tinyWin: "Made room for a walk",
            currently: "Listening to rain",
            keepsake: "Small is still progress"
        )
        XCTAssertTrue(store.savePage(page, for: DaybookPage.key(.now)))
        for width: CGFloat in [340, 780] {
            let view = DaybookView(repository: store).frame(width: width, height: 600)
            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 600)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertEqual(bitmap.size.width, width)
            XCTAssertEqual(bitmap.size.height, 600)
            if let folder = ProcessInfo.processInfo.environment["SCREENSHIRE_PREVIEWS"] {
                let url = URL(fileURLWithPath: folder).appendingPathComponent("daybook-\(Int(width)).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }
    @MainActor func testDashboardWindowLayouts() throws {
        for width: CGFloat in [340, 1040] {
            let dashboard = DashboardView().environmentObject(AppState())
                .environment(\.colorScheme, .light).frame(width: width, height: 720)
            let host = NSHostingView(rootView: dashboard)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 720)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertEqual(bitmap.size.width, width)
            if let folder = ProcessInfo.processInfo.environment["SCREENSHIRE_PREVIEWS"] {
                let url = URL(fileURLWithPath: folder).appendingPathComponent("window-\(Int(width)).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }
    @MainActor func testMemoryGardenFitsWithoutScrolling() throws {
        let state = AppState()
        for width: CGFloat in [340, 852] {
            let garden = ActivityCalendarView().environmentObject(state)
                .environment(\.colorScheme, .light).frame(width: width, height: 720)
            let host = NSHostingView(rootView: garden)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 720)
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertEqual(bitmap.size, NSSize(width: width, height: 720))
            if let folder = ProcessInfo.processInfo.environment["SCREENSHIRE_PREVIEWS"] {
                let url = URL(fileURLWithPath: folder).appendingPathComponent("garden-\(Int(width)).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }
    @MainActor func testDaybookRoundTripAndDeletion() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ActivityRepository(directory: dir)
        var page = DaybookPage()
        page.add("   ")
        page.add("  Walk outside ")
        XCTAssertEqual(page.steps.map(\.title), ["Walk outside"])
        page.steps[0].complete = true
        page.tookBreak = true
        page.journal = "The walk helped."
        XCTAssertEqual(page.petals, 3)
        XCTAssertTrue(store.savePage(page, for: "2026-11-14"))
        let reopened = ActivityRepository(directory: dir)
        XCTAssertEqual(reopened.pages["2026-11-14"], page)
        reopened.deleteAllHistory()
        XCTAssertTrue(ActivityRepository(directory: dir).pages.isEmpty)
    }
    func testDaybookBoardMigratesAndRewardsPetals() throws {
        let oldPage = #"{"steps":[],"journal":"Saved","tookBreak":true}"#
        var page = try JSONDecoder().decode(DaybookPage.self, from: Data(oldPage.utf8))
        XCTAssertEqual(page.board, DaybookPage.Board())
        XCTAssertEqual(page.petals, 2)

        page.board.mood = "Hopeful"
        page.board.tinyWin = "Closed one loose loop"
        XCTAssertEqual(page.boardPetals, 2)
        XCTAssertEqual(page.petals, 4)
    }
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
