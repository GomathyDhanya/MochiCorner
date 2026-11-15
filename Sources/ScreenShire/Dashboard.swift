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
                    HStack(spacing: 8) {
                        ScreenShireLogoMark(size: 34)
                        Text("MochiCorner")
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                    HStack(spacing: 7) { ScreenShireLogoMark(size: 28); Text("MochiCorner") }.font(.headline)
                    Spacer()
                    Menu {
                        ForEach(destinations, id: \.0) { item in
                            Button { selected = item.0 } label: { Label(item.1, systemImage: item.2) }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 32)
                            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("Open navigation")
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

private struct CategoryPicker: View { @Binding var selection: ActivityCategory; var body: some View { Picker("Category", selection: $selection) { ForEach(ActivityCategory.allCases.filter { $0 != .idle }) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 150) } }

extension View {
    func cozyCard(tint: Color = Color(nsColor: .controlBackgroundColor)) -> some View {
        self.padding(18)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.09)))
            .shadow(color: .black.opacity(0.035), radius: 5, y: 2)
    }
}
