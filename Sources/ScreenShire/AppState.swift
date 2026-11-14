import AppKit
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let repository: ActivityRepository
    @Published var trackingPaused: Bool { didSet { UserDefaults.standard.set(trackingPaused, forKey: "trackingPaused"); trackingPaused ? monitor.stop() : monitor.start() } }
    @Published var widgetVisible: Bool { didSet { UserDefaults.standard.set(widgetVisible, forKey: "widgetVisible"); applyWidgetPreferences?() } }
    @Published var widgetScale: Double { didSet { UserDefaults.standard.set(widgetScale, forKey: "widgetScale"); applyWidgetPreferences?() } }
    @Published var reducedMotion: Bool { didSet { UserDefaults.standard.set(reducedMotion, forKey: "reducedMotion"); applyWidgetPreferences?() } }
    @Published var alwaysOnTop: Bool { didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop"); applyWidgetPreferences?() } }
    @Published var animationInterval: Double { didSet { UserDefaults.standard.set(animationInterval, forKey: "animationInterval") } }
    @Published var aiEnabled: Bool { didSet { UserDefaults.standard.set(aiEnabled, forKey: "aiEnabled") } }
    @Published private(set) var lastStoryError: String?
    @Published private(set) var goalStatuses: [GoalStatus] = []
    @Published private(set) var reachedGoal: GoalStatus?
    @Published private(set) var toastMessage: String?
    @Published private(set) var isGeneratingStory = false
    @Published private(set) var storyStatus: String?
    private var cancellables = Set<AnyCancellable>()
    private var alertedGoals = Set<String>()
    private let meowPlayer = MeowPlayer()
    var applyWidgetPreferences: (() -> Void)?
    private lazy var tracker = UsageSessionTracker(repository: repository)
    private lazy var monitor = AppActivityMonitor(tracker: tracker)
    init(repository: ActivityRepository = ActivityRepository()) {
        self.repository = repository
        let defaults = UserDefaults.standard
        trackingPaused = defaults.bool(forKey: "trackingPaused")
        widgetVisible = defaults.object(forKey: "widgetVisible") as? Bool ?? true
        widgetScale = defaults.object(forKey: "widgetScale") as? Double ?? 1
        reducedMotion = defaults.bool(forKey: "reducedMotion")
        alwaysOnTop = defaults.object(forKey: "alwaysOnTop") as? Bool ?? true
        animationInterval = defaults.object(forKey: "animationInterval") as? Double ?? 0.36
        aiEnabled = defaults.bool(forKey: "aiEnabled")
        // Observe published values, rather than objectWillChange, so views redraw
        // after repository mutations have completed.
        repository.$sessions.dropFirst().sink { [weak self] _ in self?.refreshFromData() }.store(in: &cancellables)
        repository.$goals.dropFirst().sink { [weak self] _ in self?.refreshFromData() }.store(in: &cancellables)
        repository.$appMappings.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        repository.$chronicles.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        tracker.$current.dropFirst().sink { [weak self] _ in self?.refreshFromData() }.store(in: &cancellables)
        tracker.$isIdle.dropFirst().sink { [weak self] _ in self?.refreshFromData() }.store(in: &cancellables)
        tracker.$lastTransition.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }
    var currentCategory: ActivityCategory { trackingPaused ? .idle : tracker.current.map { repository.appMappings[$0.bundleIdentifier]?.category ?? $0.category } ?? .uncategorized }
    var activeAppName: String { trackingPaused ? "Tracking paused" : (tracker.current?.appName ?? "Waiting for an active app") }
    var trackingExplanation: String { tracker.lastTransition }
    private var goalTimer: Timer?
    func start() {
        guard goalTimer == nil else { return }
        if !trackingPaused { monitor.start() }
        applyWidgetPreferences?()
        evaluateGoals()
        goalTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateGoals() }
        }
    }
    func stop() {
        goalTimer?.invalidate()
        goalTimer = nil
        monitor.stop()
    }
    func resetDemo() {
        let now = Date(); let cal = Calendar.current
        let examples: [(ActivityCategory, String, String, Int, Int)] = [(.code, "com.microsoft.VSCode", "Visual Studio Code", 205, 0), (.social, "com.apple.MobileSMS", "Messages", 75, 220), (.study, "com.apple.Preview", "Preview", 45, 310), (.create, "com.figma.Desktop", "Figma", 55, 380)]
        for (cat, id, name, minutes, offset) in examples { let end = cal.date(byAdding: .minute, value: -offset, to: now)!; let start = cal.date(byAdding: .minute, value: -minutes, to: end)!; repository.append(UsageSession(id: UUID(), bundleIdentifier: id, appName: name, category: cat, startedAt: start, endedAt: end)) }
    }
    func generateChronicle() async {
        guard !isGeneratingStory else { return }
        lastStoryError = nil
        storyStatus = nil
        isGeneratingStory = true
        defer { isGeneratingStory = false }
        let context = DailyStoryContextBuilder.make(sessions: repository.sessions, goals: repository.goals, chronicles: repository.chronicles)
        do {
            let chapter = try await GeminiStoryService().generate(context: context, enabled: aiEnabled)
            repository.addChronicle(chapter)
            storyStatus = "Mochi added a new chapter to the bookshelf."
        } catch StoryError.serviceBusy {
            repository.addChronicle(OfflineChronicle.make(context: context))
            storyStatus = "Gemini is busy right now, so Mochi made an offline chapter instead."
        } catch StoryError.malformedResponse {
            repository.addChronicle(OfflineChronicle.make(context: context))
            storyStatus = "Gemini’s response needed tidying, so Mochi made an offline chapter instead."
        } catch { lastStoryError = error.localizedDescription }
    }
    func dismissGoalAlert() { reachedGoal = nil }
    func assign(_ app: TrackedApp) {
        repository.map(app)
        tracker.reclassifyCurrent(bundleID: app.id, as: app.category)
        announce("\(app.displayName) is now \(app.category.label)")
    }
    func announce(_ message: String) {
        toastMessage = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard self?.toastMessage == message else { return }
            self?.toastMessage = nil
        }
    }
    private func evaluateGoals() {
        let statuses = GoalEvaluator.statuses(sessions: repository.sessions, goals: repository.goals)
        goalStatuses = statuses
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        for status in statuses where status.isReached {
            let key = "\(day)-\(status.id.uuidString)"
            if alertedGoals.insert(key).inserted { reachedGoal = status; meowPlayer.playGoalReached() }
        }
    }
    private func refreshFromData() { objectWillChange.send(); evaluateGoals() }
}

@main
struct ScreenShireApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup("ScreenShire") { DashboardView().environmentObject(state).onAppear { state.start(); appDelegate.state = state } }
            .defaultSize(width: 1040, height: 720)
            .commands { CommandGroup(after: .appInfo) { Button("Show Cat Widget") { appDelegate.showWidget() }.keyboardShortcut("w", modifiers: [.command, .shift]) } }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var state: AppState? { didSet { if let state { widget = FloatingWidgetController(state: state) } } }
    private var widget: FloatingWidgetController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationWillTerminate(_ notification: Notification) { state?.stop() }
    func showWidget() { state?.widgetVisible = true; widget?.show() }
}
