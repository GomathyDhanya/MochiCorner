import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @State private var selected = 6
    @Environment(\.colorScheme) private var scheme
    private let destinations = [(6, "My daybook", "book.pages"), (0, "Today", "sun.max"), (5, "Memory garden", "leaf"), (1, "Gentle limits", "target"), (2, "App labels", "square.grid.2x2"), (3, "Daily chronicle", "book.closed"), (4, "Comfort settings", "slider.horizontal.3")]
    var body: some View {
        GeometryReader { geometry in
          let compact = geometry.size.width < 720
          HStack(spacing: 0) {
            if !compact {
                VStack(alignment: .leading, spacing: 16) {
                    Label("ScreenShire", systemImage: "leaf.fill")
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .lineLimit(1).minimumScaleFactor(0.82)
                        .padding(.horizontal, 4).padding(.top, 18)
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(destinations, id: \.0) { item in
                                Button { selected = item.0 } label: {
                                    Label(item.1, systemImage: item.2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .foregroundStyle(selected == item.0 ? .white : .white.opacity(0.84))
                                    .background(selected == item.0 ? Color.white.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 9))
                                    .accessibilityAddTraits(selected == item.0 ? .isSelected : [])
                            }
                        }
                    }
                }.padding(12).frame(width: 188).foregroundStyle(.white)
                    .background(Color(red: 0.13, green: 0.24, blue: 0.22))
            }
            VStack(spacing: 0) {
              if compact {
                HStack {
                    Label("ScreenShire", systemImage: "leaf.fill").font(.headline)
                    Spacer()
                    Picker("Section", selection: $selected) {
                        ForEach(destinations, id: \.0) { item in Text(item.1).tag(item.0) }
                    }.labelsHidden().fixedSize()
                }.padding(12)
                Divider()
              }
            ZStack(alignment: .topTrailing) {
                detailView.environmentObject(state).frame(maxWidth: .infinity, maxHeight: .infinity)
                if let goal = state.reachedGoal { GoalReachedBanner(status: goal) { state.dismissGoalAlert() }.padding(20) }
                if let message = state.toastMessage { Toast(message: message).padding(20).padding(.top, 88) }
            }
            }
          }.background(scheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(red: 0.97, green: 0.96, blue: 0.93))
        }.tint(scheme == .dark ? .sage : Color(red: 0.23, green: 0.39, blue: 0.30))
            .frame(minWidth: 340, minHeight: 310)
    }
    @ViewBuilder private var detailView: some View { switch selected { case 6: DaybookView(repository: state.repository); case 1: LimitsStudioView(); case 2: AppLibraryView(); case 3: ChronicleLibraryView(); case 4: ComfortStudioView(); case 5: ActivityCalendarView(); default: TodayView() } }
}

private struct Toast: View { let message: String; var body: some View { Label(message, systemImage: "checkmark.circle.fill").font(.callout.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 10).foregroundStyle(.white).background(Color.cocoa, in: Capsule()).shadow(radius: 8) } }

private struct GoalReachedBanner: View { let status: GoalStatus; let dismiss: () -> Void; var body: some View { HStack(spacing: 11) { Text("🐱").font(.title); VStack(alignment: .leading, spacing: 2) { Text("Mochi says: meow!").font(.headline); Text("Your \(status.goal.category.label) limit has been reached. A gentle pause might feel nice.").font(.caption).fixedSize(horizontal: false, vertical: true) }; Button("Okay", action: dismiss).buttonStyle(.bordered) }.padding(14).frame(maxWidth: 410).background(Color.peach, in: RoundedRectangle(cornerRadius: 18)).shadow(color: .black.opacity(0.12), radius: 14, y: 5) } }

struct TodayView: View {
    @EnvironmentObject private var state: AppState
    private var totals: [ActivityTotal] { ActivityAnalyticsService.totals(state.repository.sessions) }
    private var totalMinutes: Int { totals.reduce(0) { $0 + $1.minutes } }
    private var unclassified: [TrackedApp] { Dictionary(grouping: state.repository.sessions.filter { (state.repository.appMappings[$0.bundleIdentifier]?.category ?? $0.category) == .uncategorized }, by: \.bundleIdentifier).compactMap { id, sessions in sessions.last.map { TrackedApp(id: id, displayName: $0.appName, category: .uncategorized) } }.sorted { $0.displayName < $1.displayName } }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { TodayHero(); LazyVGrid(columns: [GridItem(.adaptive(minimum: 155))], spacing: 12) { MetricCard(eyebrow: "Foreground time", value: duration(totalMinutes), detail: "today so far", tint: .peach); MetricCard(eyebrow: "Mochi is seeing", value: state.currentCategory.label, detail: state.activeAppName, tint: .lilac); MetricCard(eyebrow: "Tracking", value: state.trackingPaused ? "Paused" : "On", detail: state.trackingExplanation, tint: .sage) }; if !state.goalStatuses.isEmpty { CheckpointsView() }; ActivityCard(totals: totals); if !unclassified.isEmpty { UnclassifiedCard(apps: unclassified) }; Button { state.resetDemo() } label: { Label("Load a cozy demo day", systemImage: "wand.and.stars") }.buttonStyle(.bordered).foregroundStyle(.secondary) }.padding(30).frame(maxWidth: 960, alignment: .leading) }.background(Color.cream.opacity(0.15)).navigationTitle("") }
    private func duration(_ minutes: Int) -> String { "\(minutes / 60)h \(minutes % 60)m" }
}

private struct TodayHero: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { heading; Spacer(); trackingButton }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 12) { heading; trackingButton }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        .foregroundStyle(.white)
        .background(Color(red: 0.13, green: 0.27, blue: 0.24), in: RoundedRectangle(cornerRadius: 20))
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Today").font(.system(size: 36, design: .serif))
            Label(state.trackingPaused ? "Tracking paused" : state.activeAppName,
                  systemImage: state.trackingPaused ? "pause.circle" : "circle.fill").font(.callout)
        }
    }
    private var trackingButton: some View {
        Button(state.trackingPaused ? "Resume tracking" : "Pause tracking") { state.trackingPaused.toggle() }
            .buttonStyle(.borderedProminent).tint(Color(red: 0.28, green: 0.42, blue: 0.34))
    }
}

private struct MetricCard: View { let eyebrow: String; let value: String; let detail: String; let tint: Color; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary); Text(value).font(.title3.bold()).lineLimit(1); Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(16).background(tint.opacity(0.21), in: RoundedRectangle(cornerRadius: 18)) } }

private struct CheckpointsView: View { @EnvironmentObject private var state: AppState; var body: some View { VStack(alignment: .leading, spacing: 12) { Text("Gentle checkpoints").font(.title3.bold()); Text("Limits are soft guardrails. Mochi plays one gentle meow when one is reached.").font(.caption).foregroundStyle(.secondary); LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) { ForEach(state.goalStatuses) { status in GoalTile(status: status) } } }.cozyCard() } }
private struct GoalTile: View { let status: GoalStatus; var body: some View { VStack(alignment: .leading, spacing: 8) { Label(status.goal.category.label, systemImage: status.goal.category.icon).font(.caption.weight(.semibold)); Text(status.isReached ? "Time for a pause" : "\(status.remainingMinutes)m remaining").font(.headline); ProgressView(value: Double(status.usedMinutes), total: Double(status.goal.dailyLimitMinutes)).tint(status.isReached ? .peach : .sage); Text("\(status.usedMinutes) of \(status.goal.dailyLimitMinutes) min").font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color.lilac.opacity(0.18), in: RoundedRectangle(cornerRadius: 14)) } }
private struct ActivityCard: View { let totals: [ActivityTotal]; var body: some View { VStack(alignment: .leading, spacing: 13) { Text("Your day, at a glance").font(.title3.bold()); if totals.isEmpty { ContentUnavailableView("Nothing recorded yet", systemImage: "sparkles", description: Text("Open an app, then switch away once to see Mochi’s day begin.")) } else { ForEach(totals) { total in HStack(spacing: 10) { Image(systemName: total.category.icon).foregroundStyle(Color.cocoa).frame(width: 24); Text(total.category.label).frame(width: 108, alignment: .leading); ProgressView(value: Double(total.minutes), total: Double(max(1, totals.first?.minutes ?? 1))).tint(.sage); Text("\(total.minutes)m").monospacedDigit().foregroundStyle(.secondary).frame(width: 48, alignment: .trailing) } } } }.cozyCard() } }
private struct UnclassifiedCard: View { @EnvironmentObject private var state: AppState; let apps: [TrackedApp]; var body: some View { VStack(alignment: .leading, spacing: 12) { Label("A tiny bit of sorting", systemImage: "tray.full").font(.title3.bold()); Text("Mochi found these apps but doesn’t want to guess. Pick a label once and it will remember.").font(.caption).foregroundStyle(.secondary); ForEach(apps) { app in HStack { Text(app.displayName); Spacer(); CategoryPicker(selection: Binding(get: { state.repository.appMappings[app.id]?.category ?? .uncategorized }, set: { category in withAnimation { state.assign(TrackedApp(id: app.id, displayName: app.displayName, category: category)) } })) } } }.cozyCard(tint: .peach.opacity(0.12)) } }

struct GoalsView: View { @EnvironmentObject private var state: AppState; @State private var category: ActivityCategory = .social; @State private var minutes = 45; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { PageHeader(title: "Gentle limits", subtitle: "Set a small boundary. Mochi will play one friendly meow when you reach it."); VStack(alignment: .leading, spacing: 12) { Text("Add a checkpoint").font(.headline); Picker("For", selection: $category) { CategoryOptions() }; Stepper("After \(minutes) minutes", value: $minutes, in: 5...720, step: 5); Button("Add this gentle limit") { state.repository.setGoals(state.repository.goals.filter { $0.category != category } + [UsageGoal(id: UUID(), category: category, dailyLimitMinutes: minutes, enabled: true)]); state.announce("\(category.label) limit set for \(minutes) minutes") }.buttonStyle(.borderedProminent).tint(.sage) }.cozyCard(); if state.goalStatuses.isEmpty { ContentUnavailableView("No limits yet", systemImage: "target", description: Text("Start with one category that deserves a little care.")) } else { Text("Today’s checkpoints").font(.title3.bold()); ForEach(state.goalStatuses) { GoalDetailRow(status: $0) } } }.padding(30).frame(maxWidth: 760, alignment: .leading) }.navigationTitle("") } }
private struct GoalDetailRow: View { @EnvironmentObject private var state: AppState; let status: GoalStatus; var body: some View { HStack(spacing: 15) { Image(systemName: status.goal.category.icon).font(.title3).frame(width: 30); VStack(alignment: .leading) { Text(status.goal.category.label).font(.headline); Text(status.isReached ? "Mochi has already meowed for this one today." : "\(status.remainingMinutes) minutes before the reminder.").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(status.usedMinutes)/\(status.goal.dailyLimitMinutes)m").monospacedDigit().foregroundStyle(status.isReached ? .orange : .secondary); Button("Remove", role: .destructive) { state.repository.setGoals(state.repository.goals.filter { $0.id != status.goal.id }) } }.cozyCard() } }

struct MappingsView: View { @EnvironmentObject private var state: AppState; @State private var appName = ""; @State private var bundleID = ""; @State private var category: ActivityCategory = .work; private var apps: [TrackedApp] { var combined = state.repository.sessions.reduce(into: [String: TrackedApp]()) { $0[$1.bundleIdentifier] = state.repository.appMappings[$1.bundleIdentifier] ?? TrackedApp(id: $1.bundleIdentifier, displayName: $1.appName, category: AppCategoryClassifier.defaults[$1.bundleIdentifier] ?? .uncategorized) }; for item in AppCategoryClassifier.defaults { combined[item.key] = state.repository.appMappings[item.key] ?? TrackedApp(id: item.key, displayName: friendlyName(item.key), category: item.value) }; return combined.values.sorted { $0.displayName < $1.displayName } }; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { PageHeader(title: "Teach Mochi your apps", subtitle: "Mochi starts cautiously: anything unfamiliar stays Uncategorized until you choose a label."); VStack(alignment: .leading, spacing: 10) { Text("Add an app yourself").font(.headline); TextField("App name, e.g. Safari", text: $appName); TextField("Bundle ID, e.g. com.apple.Safari", text: $bundleID); Picker("Category", selection: $category) { CategoryOptions() }; Button("Save app label") { guard !bundleID.trimmingCharacters(in: .whitespaces).isEmpty else { return }; state.assign(TrackedApp(id: bundleID.trimmingCharacters(in: .whitespaces), displayName: appName.isEmpty ? friendlyName(bundleID) : appName, category: category)); appName = ""; bundleID = "" }.buttonStyle(.borderedProminent).tint(.sage) }.cozyCard(); Text("Known apps").font(.title3.bold()); ForEach(apps) { AppMappingRow(app: $0) } }.padding(30).frame(maxWidth: 840, alignment: .leading) }.navigationTitle("") }; private func friendlyName(_ id: String) -> String { id.split(separator: ".").last.map(String.init)?.replacingOccurrences(of: "client", with: "") ?? id } }
private struct AppMappingRow: View { @EnvironmentObject private var state: AppState; let app: TrackedApp; var body: some View { HStack { Image(systemName: app.category.icon).foregroundStyle(.secondary).frame(width: 24); VStack(alignment: .leading) { Text(app.displayName).font(.headline); Text(app.id).font(.caption).foregroundStyle(.secondary) }; Spacer(); CategoryPicker(selection: Binding(get: { state.repository.appMappings[app.id]?.category ?? app.category }, set: { state.assign(TrackedApp(id: app.id, displayName: app.displayName, category: $0)) })) }.cozyCard() } }
private struct CategoryPicker: View { @Binding var selection: ActivityCategory; var body: some View { Picker("Category", selection: $selection) { ForEach(ActivityCategory.allCases.filter { $0 != .idle }) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 150) } }
private struct CategoryOptions: View { var body: some View { ForEach(ActivityCategory.allCases.filter { $0 != .idle && $0 != .uncategorized }) { Text($0.label).tag($0) } } }

struct ChroniclesView: View { @EnvironmentObject private var state: AppState; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) { PageHeader(title: "Mochi’s bookshelf", subtitle: "Each little book is a day. The facts below every chapter are calculated locally from your real screen time."); HStack { VStack(alignment: .leading, spacing: 5) { Text(state.aiEnabled ? "Ready for a chapter" : "Stories are sleeping").font(.headline); Text(state.aiEnabled ? "Gemini is optional; a local fallback appears when it is busy." : "Turn on Gemini in Comfort settings when you want to try it.").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { Task { await state.generateChronicle() } } label: { if state.isGeneratingStory { ProgressView().controlSize(.small) } else { Text("Make today’s chapter") } }.buttonStyle(.borderedProminent).tint(.lilac).disabled(!state.aiEnabled || state.isGeneratingStory) }.cozyCard(tint: .lilac.opacity(0.2)); if let status = state.storyStatus { Label(status, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }; if let error = state.lastStoryError { Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }; if state.repository.chronicles.isEmpty { ContentUnavailableView("No chapters yet", systemImage: "book.closed", description: Text("A chapter is a gentle reflection, not a productivity score.")) }; ForEach(state.repository.chronicles) { chapter in ChronicleBook(chapter: chapter) } }.padding(30).frame(maxWidth: 760, alignment: .leading) }.navigationTitle("") } }

private struct ChronicleBook: View { @EnvironmentObject private var state: AppState; let chapter: DailyChronicle; private var totals: [ActivityTotal] { ActivityAnalyticsService.totals(state.repository.sessions, for: chapter.date) }; var body: some View { VStack(alignment: .leading, spacing: 11) { HStack { Image(systemName: "book.closed.fill").foregroundStyle(Color.lilac); Text(chapter.title).font(.title3.bold()); Spacer(); Text(chapter.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }; Text(chapter.story).fixedSize(horizontal: false, vertical: true); if let suggestion = chapter.suggestedStep { TomorrowStepView(repository: state.repository, suggestion: suggestion) }; if !totals.isEmpty { Divider(); Text("Screen-time facts").font(.caption.weight(.bold)).foregroundStyle(.secondary); FlowTotals(totals: totals) } }.cozyCard(tint: .cream) } }
private struct FlowTotals: View { let totals: [ActivityTotal]; var body: some View { LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) { ForEach(totals.prefix(4)) { total in Label("\(total.minutes)m \(total.category.label)", systemImage: total.category.icon).font(.caption).padding(.horizontal, 8).padding(.vertical, 5).background(Color.sage.opacity(0.16), in: Capsule()) } } } }

struct SettingsView: View { @EnvironmentObject private var state: AppState; @State private var key = GeminiKeychain.load() ?? ""; @State private var confirmDeletion = false; @State private var saved = false; var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { PageHeader(title: "Comfort settings", subtitle: "Make ScreenShire feel like a friendly desk companion, not another demanding dashboard."); VStack(alignment: .leading, spacing: 12) { Text("Mochi’s corner").font(.headline); Toggle("Show Mochi’s widget", isOn: $state.widgetVisible); Toggle("Keep Mochi above other windows", isOn: $state.alwaysOnTop); Toggle("Use a still cat instead of animation", isOn: $state.reducedMotion); Slider(value: $state.widgetScale, in: 0.7...1.6) { Text("Widget size: \(state.widgetScale, format: .number.precision(.fractionLength(1)))×") }; Slider(value: $state.animationInterval, in: 0.3...0.6, step: 0.03) { Text("Animation pace: \(Int(state.animationInterval * 1000)) ms") } }.cozyCard(); VStack(alignment: .leading, spacing: 12) { Text("Optional Gemini stories").font(.headline); Toggle("Let Mochi write stories", isOn: $state.aiEnabled); SecureField("Gemini API key", text: $key); Button("Save key securely") { try? GeminiKeychain.save(key); saved = true }.buttonStyle(.bordered); if saved { Label("Saved in your macOS Keychain", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }; Text("Only category totals, goal status, and up to five fictional memory notes leave your Mac when you generate a chapter.").font(.caption).foregroundStyle(.secondary) }.cozyCard(tint: .lilac.opacity(0.15)); VStack(alignment: .leading, spacing: 8) { Text("Your data").font(.headline); Text("ScreenShire measures foreground app time. It does not read screen contents or claim to know whether you were focused.").font(.caption).foregroundStyle(.secondary); Button("Delete all local history", role: .destructive) { confirmDeletion = true }.confirmationDialog("Delete activity, chapters, and all daybook pages?", isPresented: $confirmDeletion) { Button("Delete history", role: .destructive) { state.repository.deleteAllHistory() } } }.cozyCard() }.padding(30).frame(maxWidth: 760, alignment: .leading) }.navigationTitle("") } }

struct PageHeader: View { let title: String; let subtitle: String; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 30, weight: .medium, design: .serif)).foregroundStyle(.primary); Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } } }
extension View {
    func cozyCard(tint: Color = Color(nsColor: .controlBackgroundColor)) -> some View {
        self.padding(18)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
            .shadow(color: .black.opacity(0.035), radius: 5, y: 2)
    }
}
