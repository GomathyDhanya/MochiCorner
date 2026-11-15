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
        repository.$pages.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
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
        updateDiary()
        evaluateGoals()
        goalTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateGoals(); self?.updateDiary() }
        }
    }
    private func updateDiary() {
        repository.carryOpenSteps(to: DaybookPage.key(.now))
        Task { await generateClosingChronicleIfNeeded(at: .now) }
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
        await generateChronicle(for: .now, automatically: false, replacingExisting: true)
    }

    func generateClosingChronicleIfNeeded(at now: Date) async {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let day = hour == 23 && minute >= 55
            ? calendar.startOfDay(for: now)
            : calendar.date(byAdding: .day, value: -1, to: now)!
        await generateChronicle(for: day, automatically: true)
    }

    private func generateChronicle(for day: Date, automatically: Bool, replacingExisting: Bool = false) async {
        guard !isGeneratingStory, replacingExisting || repository.chronicle(for: day) == nil else { return }
        guard !automatically || repository.hasDailyMemory(for: day) else { return }
        lastStoryError = nil
        storyStatus = nil
        isGeneratingStory = true
        defer { isGeneratingStory = false }
        let context = DailyStoryContextBuilder.make(sessions: repository.sessions, goals: repository.goals, chronicles: repository.chronicles, page: repository.pages[DaybookPage.key(day)], day: day)
        do {
            let chapter = try await GeminiStoryService().generate(context: context, enabled: aiEnabled, day: day)
            saveChronicle(chapter, replacingExisting: replacingExisting)
            if !automatically { storyStatus = replacingExisting ? "Mochi refreshed today’s chapter." : "Mochi added a new chapter to the bookshelf." }
        } catch StoryError.serviceBusy {
            saveChronicle(OfflineChronicle.make(context: context, day: day), replacingExisting: replacingExisting)
            if !automatically { storyStatus = "Gemini is busy right now, so Mochi made an offline chapter instead." }
        } catch StoryError.malformedResponse {
            saveChronicle(OfflineChronicle.make(context: context, day: day), replacingExisting: replacingExisting)
            if !automatically { storyStatus = "Gemini’s response needed tidying, so Mochi made an offline chapter instead." }
        } catch StoryError.disabled where automatically {
            repository.addChronicle(OfflineChronicle.make(context: context, day: day))
        } catch StoryError.missingKey where automatically {
            repository.addChronicle(OfflineChronicle.make(context: context, day: day))
        } catch { lastStoryError = error.localizedDescription }
    }
    private func saveChronicle(_ chapter: DailyChronicle, replacingExisting: Bool) {
        if replacingExisting { repository.replaceChronicle(chapter) }
        else { repository.addChronicle(chapter) }
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
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("MochiCorner", id: "workspace") {
            DashboardView()
                .environmentObject(state)
                .onAppear {
                    appDelegate.configure(state: state, openDashboard: { openWindow(id: "workspace") })
                    state.start()
                }
        }
            .defaultSize(width: 1040, height: 720)
            .commands { CommandGroup(after: .appInfo) { Button("Show Cat Widget") { appDelegate.showWidget() }.keyboardShortcut("w", modifiers: [.command, .shift]) } }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private weak var state: AppState?
    private var widget: FloatingWidgetController?
    private var statusItem: NSStatusItem?
    private var openDashboardAction: (() -> Void)?

    func configure(state: AppState, openDashboard: @escaping () -> Void) {
        openDashboardAction = openDashboard
        guard self.state == nil else { return }
        self.state = state
        widget = FloatingWidgetController(state: state)
        installMenuBarControls()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { state?.stop() }
    func showWidget() { state?.widgetVisible = true; widget?.show() }
    func openDashboard() {
        openDashboardAction?()
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    private func installMenuBarControls() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "MochiCorner")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "MochiCorner"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshMenu(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refreshMenu(menu) }

    private func refreshMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        addMenuItem("Open dashboard", action: #selector(openDashboardFromMenu), to: menu)
        addMenuItem(state?.trackingPaused == true ? "Start tracking" : "Stop tracking", action: #selector(toggleTracking), to: menu)
        addMenuItem(state?.widgetVisible == true ? "Hide Mochi" : "Show Mochi", action: #selector(toggleWidget), to: menu)
        menu.addItem(.separator())
        addMenuItem("Quit MochiCorner", action: #selector(quit), to: menu)
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func openDashboardFromMenu() { openDashboard() }
    @objc private func toggleTracking() { state?.trackingPaused.toggle() }
    @objc private func toggleWidget() { state?.widgetVisible.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
