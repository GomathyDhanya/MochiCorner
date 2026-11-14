import AppKit
import Foundation

struct AppCategoryClassifier {
    let customMappings: [String: TrackedApp]
    static let defaults: [String: ActivityCategory] = [
        "com.apple.dt.Xcode": .code, "com.microsoft.VSCode": .code, "com.todesktop.230313mzl4w4u92": .code,
        "com.apple.Terminal": .code, "com.googlecode.iterm2": .code, "com.apple.MobileSMS": .social,
        "com.hnc.Discord": .social, "us.zoom.xos": .social, "com.apple.Music": .music,
        "com.spotify.client": .music, "com.apple.TV": .entertainment, "org.videolan.vlc": .entertainment,
        "com.figma.Desktop": .create, "com.adobe.Photoshop": .create, "com.blenderfoundation.blender": .create,
        "com.apple.Preview": .study, "com.microsoft.Word": .work, "com.microsoft.Excel": .work
    ]
    func category(for bundleID: String) -> ActivityCategory { customMappings[bundleID]?.category ?? Self.defaults[bundleID] ?? .uncategorized }
}

@MainActor
final class UsageSessionTracker: ObservableObject {
    @Published private(set) var current: UsageSession?
    @Published private(set) var isIdle = false
    @Published private(set) var lastTransition = "Waiting for the first foreground app."
    private let repository: ActivityRepository
    private let idleThreshold: TimeInterval
    init(repository: ActivityRepository, idleThreshold: TimeInterval = 300) { self.repository = repository; self.idleThreshold = idleThreshold }
    func activate(bundleID: String, name: String, at date: Date = Date()) {
        if current?.bundleIdentifier == bundleID, !isIdle { return }
        finish(at: date)
        let category = AppCategoryClassifier(customMappings: repository.appMappings).category(for: bundleID)
        let session = UsageSession(id: UUID(), bundleIdentifier: bundleID, appName: name, category: category, startedAt: date, endedAt: date)
        current = session; isIdle = false; lastTransition = "Tracking \(name) as \(category.label)."; repository.append(session)
    }
    func becomeIdle(at date: Date = Date(), idleSince: Date? = nil) { guard !isIdle else { return }; finish(at: idleSince ?? date); isIdle = true; lastTransition = "Paused for inactivity after \(Int(idleThreshold / 60)) minutes." }
    func resume(at date: Date = Date()) { guard isIdle else { return }; isIdle = false; if let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier { activate(bundleID: id, name: app.localizedName ?? id, at: date) } }
    func finish(at date: Date = Date()) { guard var session = current else { return }; session.endedAt = max(date, session.startedAt); repository.replace(session); current = nil }
    func checkIdle() {
        // kCGAnyInputEventType is UInt32.max. `.null` only represents a null event.
        let anyInputEvent = CGEventType(rawValue: UInt32.max)!
        let seconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEvent)
        if seconds >= idleThreshold { becomeIdle(idleSince: Date().addingTimeInterval(-seconds)) }
        else if isIdle { resume() }
        else { checkpoint() }
    }
    func reconcileFrontmostApplication() {
        guard !isIdle, let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier else { return }
        if current?.bundleIdentifier != id { activate(bundleID: id, name: app.localizedName ?? id) }
    }
    func reclassifyCurrent(bundleID: String, as category: ActivityCategory) {
        guard var session = current, session.bundleIdentifier == bundleID else { return }
        session.category = category
        current = session
        repository.replace(session)
        lastTransition = "Tracking \(session.appName) as \(category.label)."
    }
    private func checkpoint(at date: Date = Date()) {
        guard var session = current else { return }
        session.endedAt = max(date, session.startedAt)
        current = session
        repository.replace(session)
    }
}

@MainActor
final class AppActivityMonitor {
    private var activation: NSObjectProtocol?
    private var timer: Timer?
    private let tracker: UsageSessionTracker
    init(tracker: UsageSessionTracker) { self.tracker = tracker }
    func start() {
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, let id = app.bundleIdentifier else { return }
            Task { @MainActor in self?.tracker.activate(bundleID: id, name: app.localizedName ?? id) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.tracker.checkIdle(); self?.tracker.reconcileFrontmostApplication() } }
        if let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier { tracker.activate(bundleID: id, name: app.localizedName ?? id) }
    }
    func stop() { if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }; timer?.invalidate(); tracker.finish() }
}

struct ActivityAnalyticsService {
    static func totals(_ sessions: [UsageSession], for day: Date = Date(), calendar: Calendar = .current) -> [ActivityTotal] {
        let interval = calendar.dateInterval(of: .day, for: day)!
        let ordered = sessions.sorted { $0.startedAt < $1.startedAt }
        let measured = ordered.enumerated().compactMap { index, session -> (ActivityCategory, TimeInterval)? in
            // A new foreground session is authoritative: an earlier one cannot
            // continue beyond it. This also repairs old overlapping records.
            let nextStart = ordered.indices.contains(index + 1) ? ordered[index + 1].startedAt : Date.distantFuture
            let end = min(session.endedAt ?? Date(), nextStart, interval.end)
            let start = max(session.startedAt, interval.start)
            let overlap = max(0, end.timeIntervalSince(start))
            return overlap > 0 ? (session.category, overlap) : nil
        }
        let byCategory = Dictionary(grouping: measured, by: { $0.0 })
        return byCategory.map { ActivityTotal(category: $0.key, minutes: Int($0.value.reduce(0) { $0 + $1.1 } / 60)) }.sorted { $0.minutes > $1.minutes }
    }
}
