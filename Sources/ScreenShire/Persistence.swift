import Foundation

@MainActor
final class ActivityRepository: ObservableObject {
    @Published private(set) var sessions: [UsageSession] = []
    @Published private(set) var appMappings: [String: TrackedApp] = [:]
    @Published private(set) var goals: [UsageGoal] = []
    @Published private(set) var chronicles: [DailyChronicle] = []
    private let directory: URL
    @Published private(set) var pages: [String: DaybookPage] = [:]
    @Published private(set) var pageError: String?
    private var pagesReadable = true
    private var pagesURL: URL { directory.appendingPathComponent("daybook.json") }

    func savePage(_ page: DaybookPage, for key: String) -> Bool {
        guard pagesReadable else { return false }
        var next = pages
        next[key] = page
        do {
            try JSONEncoder().encode(next).write(to: pagesURL, options: .atomic)
            pages = next
            pageError = nil
            return true
        } catch {
            pageError = "Couldn’t save this page. Check available disk space and try again."
            return false
        }
    }
    private var sessionsURL: URL { directory.appendingPathComponent("sessions.json") }
    private var stateURL: URL { directory.appendingPathComponent("state.json") }
    private struct State: Codable { var apps: [TrackedApp]; var goals: [UsageGoal]; var chronicles: [DailyChronicle] }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ScreenShire")
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        if directory == nil {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.directory.path)
        }
        load()
    }
    func append(_ session: UsageSession) { sessions.append(session); saveSessions() }
    func replace(_ session: UsageSession) { guard let i = sessions.firstIndex(where: { $0.id == session.id }) else { return }; sessions[i] = session; saveSessions() }
    func map(_ app: TrackedApp) {
        appMappings[app.id] = app
        // A deliberate app-label correction also corrects historical totals.
        sessions = sessions.map { session in
            guard session.bundleIdentifier == app.id else { return session }
            var corrected = session; corrected.category = app.category; return corrected
        }
        saveSessions(); saveState()
    }
    func setGoals(_ values: [UsageGoal]) {
        goals = values; saveState()
    }
    func addChronicle(_ value: DailyChronicle) {
        chronicles.insert(value, at: 0)
        saveState()
        addSuggestedStep(from: value)
    }

    func replaceChronicle(_ value: DailyChronicle) {
        chronicles.removeAll { Calendar.current.isDate($0.date, inSameDayAs: value.date) }
        chronicles.insert(value, at: 0)
        saveState()
    }

    func addSuggestedStep(from chapter: DailyChronicle) {
        guard let title = chapter.suggestedStep?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
              let date = Calendar.current.date(byAdding: .day, value: 1, to: chapter.date) else { return }
        let key = DaybookPage.key(date)
        var page = pages[key] ?? DaybookPage()
        guard !page.steps.contains(where: { $0.id == chapter.id || $0.title == title }) else { return }
        page.skippedSteps?.remove(chapter.id)
        page.steps.append(.init(id: chapter.id, title: title))
        _ = savePage(page, for: key)
    }

    func deleteChronicle(_ chapter: DailyChronicle) {
        chronicles.removeAll { $0.id == chapter.id }
        saveState()
    }

    func chronicle(for day: Date) -> DailyChronicle? {
        chronicles.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func hasDailyMemory(for day: Date) -> Bool {
        let page = pages[DaybookPage.key(day)]
        let hasPageMemory = page.map {
            !$0.journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !$0.steps.isEmpty || $0.tookBreak || $0.boardPetals > 0
        } ?? false
        guard !hasPageMemory else { return true }
        guard let interval = Calendar.current.dateInterval(of: .day, for: day) else { return false }
        return sessions.contains { session in
            let end = session.endedAt ?? Date()
            return session.startedAt < interval.end && end > interval.start
        }
    }

    @discardableResult func deleteNote(on key: String) -> Bool {
        guard var page = pages[key] else { return true }
        page.journal = ""
        return savePage(page, for: key)
    }
    func deleteAllHistory() {
        do {
            if FileManager.default.fileExists(atPath: pagesURL.path) { try FileManager.default.removeItem(at: pagesURL) }
            pages = [:]
            pagesReadable = true
            pageError = nil
        } catch { pageError = "Couldn’t delete the daybook." }
        sessions = []; chronicles = []; saveSessions(); saveState()
    }
    private func load() {
        if FileManager.default.fileExists(atPath: pagesURL.path) {
            do { pages = try JSONDecoder().decode([String: DaybookPage].self, from: Data(contentsOf: pagesURL)) }
            catch { pagesReadable = false; pageError = "The saved daybook could not be read. Its file has been preserved." }
        }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        sessions = (try? d.decode([UsageSession].self, from: Data(contentsOf: sessionsURL))) ?? []
        // Old builds stored an open session with no heartbeat. Never let a
        // prior app run turn into hours of phantom usage after a relaunch.
        let repaired = sessions.map { session -> UsageSession in
            guard session.endedAt == nil else { return session }
            var closed = session; closed.endedAt = closed.startedAt; return closed
        }
        if repaired != sessions { sessions = repaired; saveSessions() }
        if let state = try? d.decode(State.self, from: Data(contentsOf: stateURL)) { appMappings = Dictionary(uniqueKeysWithValues: state.apps.map { ($0.id, $0) }); goals = state.goals; chronicles = state.chronicles }
    }
    private func saveSessions() {
        write(sessions, to: sessionsURL)
    }
    private func saveState() {
        write(State(apps: Array(appMappings.values), goals: goals, chronicles: chronicles), to: stateURL)
    }
    private func write<T: Encodable>(_ value: T, to url: URL) { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; guard let d = try? e.encode(value) else { return }; try? d.write(to: url, options: .atomic) }
    func carryOpenSteps(to today: String) {
        var target = pages[today] ?? DaybookPage()
        var seen = Set(target.steps.map(\.id)).union(target.skippedSteps ?? [])
        for key in pages.keys.filter({ $0 < today }).sorted(by: >) {
            seen.formUnion(pages[key]?.skippedSteps ?? [])
            for step in pages[key]!.steps where seen.insert(step.id).inserted && !step.complete { target.steps.append(step) }
        }
        if !target.steps.isEmpty && target != pages[today] { _ = savePage(target, for: today) }
    }
}
