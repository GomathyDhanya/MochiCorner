import XCTest
import SwiftUI
@testable import ScreenShire

final class ScreenShireTests: XCTestCase {
    @MainActor func testClosingDashboardKeepsBackgroundServiceRunning() {
        XCTAssertFalse(AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    func testGeminiStepValidation() {
        let service = GeminiStoryService()
        let good = #"{"title":"Garden","story":"Mochi paused.","memorySummary":"A break","suggestedStep":"Sketch on paper"}"#
        XCTAssertEqual(service.decodeChapter(good)?.suggestedStep, "Sketch on paper")
        XCTAssertNil(service.decodeChapter(good.replacingOccurrences(of: "Sketch on paper", with: " ")))
    }

    func testGeminiPlanningValidation() {
        let service = GeminiPlanningService()
        XCTAssertEqual(service.decodeSteps(#"{"steps":["Open the document","Write one heading"]}"#), ["Open the document", "Write one heading"])
        XCTAssertNil(service.decodeSteps(#"{"steps":[]}"#))
        XCTAssertNil(service.decodeSteps(#"{"steps":["One","Two","Three","Four"]}"#))
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
            currently: "Listening to rain"
        )
        XCTAssertTrue(store.savePage(page, for: DaybookPage.key(.now)))
        for width: CGFloat in [340, 780] {
            let view = DaybookView(repository: store)
                .environmentObject(AppState(repository: store))
                .frame(width: width, height: 600)
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
    @MainActor func testCarryAcrossMissedDaysAndCompletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ActivityRepository(directory: directory)
        var page = DaybookPage()
        page.add("Read")
        XCTAssertTrue(repo.savePage(page, for: "2026-11-11"))
        repo.carryOpenSteps(to: "2026-11-14")
        repo.carryOpenSteps(to: "2026-11-14")
        var carried = try XCTUnwrap(repo.pages["2026-11-14"])
        XCTAssertEqual(carried.steps, page.steps)
        carried.steps[0].complete = true
        XCTAssertTrue(repo.savePage(carried, for: "2026-11-14"))
        repo.carryOpenSteps(to: "2026-11-15")
        XCTAssertNil(repo.pages["2026-11-15"])
    }

    @MainActor func testChapterSchedulesOnceOnFollowingLocalDay() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = ActivityRepository(directory: dir)
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 22)))
        let chapter = DailyChronicle(id: UUID(), date: date, title: "Winter", story: "Snow", memorySummary: "Walk", suggestedStep: " Walk outside ")
        store.addChronicle(chapter)
        store.addSuggestedStep(from: chapter)
        XCTAssertEqual(ActivityRepository(directory: dir).pages["2026-01-01"]?.steps.map(\.title), ["Walk outside"])
    }

    @MainActor func testReplacingChronicleKeepsOneChapterForTheDay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityRepository(directory: directory)
        let day = Date()
        repository.addChronicle(.init(id: UUID(), date: day, title: "First", story: "First story", memorySummary: "First memory"))
        repository.replaceChronicle(.init(id: UUID(), date: day, title: "Fresh", story: "Fresh story", memorySummary: "Fresh memory"))
        XCTAssertEqual(repository.chronicles.count, 1)
        XCTAssertEqual(repository.chronicle(for: day)?.title, "Fresh")
    }

    @MainActor func testAutomaticChronicleClosesYesterdayOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ActivityRepository(directory: directory)
        let calendar = Calendar.current
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: .now))
        XCTAssertTrue(repository.savePage(.init(board: .init(mood: "Hopeful")), for: DaybookPage.key(yesterday)))
        let state = AppState(repository: repository)
        state.aiEnabled = false
        await state.generateClosingChronicleIfNeeded(at: .now)
        let chapter = try XCTUnwrap(repository.chronicle(for: yesterday))
        XCTAssertEqual(chapter.date.timeIntervalSince1970, yesterday.timeIntervalSince1970, accuracy: 1)
        await state.generateClosingChronicleIfNeeded(at: .now)
        XCTAssertEqual(repository.chronicles.count, 1)
    }

    @MainActor func testDiaryReaderShowsSavedEntryAtCompactSize() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = ActivityRepository(directory: dir)
        XCTAssertTrue(repo.savePage(.init(journal: "The first snow fell during our walk."), for: "2026-11-14"))
        let host = NSHostingView(rootView: DiaryReader(repository: repo).frame(width: 420, height: 400))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 400)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        XCTAssertEqual(bitmap.size, host.bounds.size)
        if let folder = ProcessInfo.processInfo.environment["SCREENSHIRE_PREVIEWS"] {
            try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: folder).appendingPathComponent("diary.png"))
        }
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
