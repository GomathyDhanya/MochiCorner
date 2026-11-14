import SwiftUI

private struct StudioShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.system(size: geometry.size.width < 600 ? 28 : 36, weight: .medium, design: .serif))
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                    content()
                }
                .padding(geometry.size.width < 600 ? 16 : 28)
                .frame(maxWidth: 1050)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle("")
    }
}

private struct StudioSurface<Content: View>: View {
    var tint = Color(nsColor: .controlBackgroundColor)
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.075)))
            .shadow(color: .black.opacity(0.035), radius: 7, y: 3)
    }
}

private struct PageHero<Content: View>: View {
    let icon: String
    let eyebrow: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon).font(.system(size: 26, weight: .medium))
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1.6).foregroundStyle(.white.opacity(0.68))
                content()
            }
            Spacer(minLength: 0)
        }
        .padding(22).foregroundStyle(.white)
        .background(
            LinearGradient(colors: [Color(red: 0.10, green: 0.25, blue: 0.22), Color(red: 0.28, green: 0.43, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

struct LimitsStudioView: View {
    @EnvironmentObject private var state: AppState
    @State private var category: ActivityCategory = .social
    @State private var minutes = 45

    var body: some View {
        StudioShell(title: "Gentle limits", subtitle: "Choose a stopping point before an app category takes over the day.") {
            PageHero(icon: "hourglass", eyebrow: "Today’s boundaries") {
                Text(state.goalStatuses.isEmpty ? "Make room for what matters." : "\(state.goalStatuses.filter(\.isReached).count) of \(state.goalStatuses.count) limits reached")
                    .font(.title3.weight(.medium))
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) { limitComposer.frame(width: 310); limitList }
                VStack(spacing: 16) { limitComposer; limitList }
            }
        }
    }

    private var limitComposer: some View {
        StudioSurface(tint: Color.sage.opacity(0.14)) {
            VStack(alignment: .leading, spacing: 16) {
                Text("New limit").font(.system(size: 23, design: .serif))
                LabeledContent("Category") {
                    Picker("Category", selection: $category) { ProductiveCategoryOptions() }.labelsHidden().frame(width: 140)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Daily allowance"); Spacer(); Text("\(minutes) min").font(.headline.monospacedDigit()) }
                    Slider(value: Binding(get: { Double(minutes) }, set: { minutes = Int($0) }), in: 10...180, step: 5)
                    HStack {
                        ForEach([30, 45, 60, 90], id: \.self) { amount in
                            Button("\(amount)m") { minutes = amount }
                                .buttonStyle(.bordered).controlSize(.small).tint(minutes == amount ? .sage : .secondary)
                        }
                    }
                }
                Button { addLimit() } label: { Label("Set gentle limit", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.36, blue: 0.29)).frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private var limitList: some View {
        if state.goalStatuses.isEmpty {
            StudioSurface {
                VStack(spacing: 12) {
                    Image(systemName: "leaf").font(.system(size: 34)).foregroundStyle(Color.sage)
                    Text("No limits yet").font(.title3.weight(.medium))
                    Text("Start with the category that most often steals your time.").foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, minHeight: 190)
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                ForEach(state.goalStatuses) { status in LimitCard(status: status) }
            }.frame(maxWidth: .infinity)
        }
    }

    private func addLimit() {
        let goal = UsageGoal(id: UUID(), category: category, dailyLimitMinutes: minutes, enabled: true)
        state.repository.setGoals(state.repository.goals.filter { $0.category != category } + [goal])
        state.announce("\(category.label) limit set for \(minutes) minutes")
    }
}

private struct LimitCard: View {
    @EnvironmentObject private var state: AppState
    let status: GoalStatus

    var body: some View {
        StudioSurface(tint: status.isReached ? Color.peach.opacity(0.17) : Color(nsColor: .controlBackgroundColor)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: status.goal.category.icon).font(.title3).foregroundStyle(Color.sage)
                    Text(status.goal.category.label).font(.headline)
                    Spacer()
                    Menu { Button("Remove limit", role: .destructive) { remove() } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton)
                }
                Text(status.isReached ? "Time for a pause" : "\(status.remainingMinutes) minutes left")
                    .font(.system(size: 21, weight: .medium, design: .serif))
                ProgressView(value: Double(status.usedMinutes), total: Double(max(1, status.goal.dailyLimitMinutes))).tint(status.isReached ? .peach : .sage)
                Text("\(status.usedMinutes) of \(status.goal.dailyLimitMinutes) minutes").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func remove() { state.repository.setGoals(state.repository.goals.filter { $0.id != status.goal.id }) }
}

struct AppLibraryView: View {
    @EnvironmentObject private var state: AppState
    @State private var query = ""
    @State private var showingAdd = false
    @State private var appName = ""
    @State private var bundleID = ""
    @State private var category: ActivityCategory = .work

    private var apps: [TrackedApp] {
        var combined = state.repository.sessions.reduce(into: [String: TrackedApp]()) {
            $0[$1.bundleIdentifier] = state.repository.appMappings[$1.bundleIdentifier] ?? TrackedApp(id: $1.bundleIdentifier, displayName: $1.appName, category: AppCategoryClassifier.defaults[$1.bundleIdentifier] ?? .uncategorized)
        }
        for item in AppCategoryClassifier.defaults {
            combined[item.key] = state.repository.appMappings[item.key] ?? TrackedApp(id: item.key, displayName: friendlyName(item.key), category: item.value)
        }
        let all = combined.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return query.isEmpty ? all : all.filter { $0.displayName.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        StudioShell(title: "App labels", subtitle: "Teach Mochi what each app means in your day.") {
            HStack(spacing: 12) {
                Label { TextField("Search apps", text: $query).textFieldStyle(.plain) } icon: { Image(systemName: "magnifyingglass").foregroundStyle(.secondary) }
                    .padding(11).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                Button { showingAdd.toggle() } label: { Label("Add app", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.36, blue: 0.29))
            }
            if showingAdd { addAppSurface }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                ForEach(apps) { app in AppLabelCard(app: app) }
            }
        }
    }

    private var addAppSurface: some View {
        StudioSurface(tint: Color.sage.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Add an application").font(.title3.weight(.medium)); Spacer(); Button { showingAdd = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                ViewThatFits(in: .horizontal) {
                    HStack { fields; saveButton }
                    VStack { fields; saveButton }
                }
            }
        }
    }

    private var fields: some View {
        Group {
            TextField("App name", text: $appName).textFieldStyle(.roundedBorder)
            TextField("Bundle ID", text: $bundleID).textFieldStyle(.roundedBorder)
            Picker("Category", selection: $category) { ProductiveCategoryOptions() }.frame(width: 150)
        }
    }

    private var saveButton: some View {
        Button("Save") { saveApp() }.buttonStyle(.borderedProminent).tint(.sage)
            .disabled(bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func saveApp() {
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        state.assign(TrackedApp(id: id, displayName: appName.isEmpty ? friendlyName(id) : appName, category: category))
        appName = ""; bundleID = ""; showingAdd = false
    }

    private func friendlyName(_ id: String) -> String {
        id.split(separator: ".").last.map(String.init)?.replacingOccurrences(of: "client", with: "") ?? id
    }
}

private struct AppLabelCard: View {
    @EnvironmentObject private var state: AppState
    let app: TrackedApp
    var body: some View {
        StudioSurface {
            HStack(spacing: 13) {
                Image(systemName: app.category.icon).font(.title3).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(Color(red: 0.20, green: 0.38, blue: 0.31), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName.capitalized).font(.headline).lineLimit(1)
                    Text(app.id).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Menu {
                    ForEach(ActivityCategory.allCases.filter { $0 != .idle }) { category in
                        Button { state.assign(TrackedApp(id: app.id, displayName: app.displayName, category: category)) } label: {
                            Label(category.label, systemImage: category.icon)
                        }
                    }
                } label: {
                    Text((state.repository.appMappings[app.id]?.category ?? app.category).label)
                        .font(.caption.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 6)
                        .background(.primary.opacity(0.055), in: Capsule())
                }.menuStyle(.borderlessButton).fixedSize()
            }
        }
    }
}

struct ChronicleLibraryView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        StudioShell(title: "Daily chronicle", subtitle: "A warm, factual reflection on the shape of your day.") {
            PageHero(icon: "sparkles", eyebrow: "Gemini reflection") {
                ViewThatFits(in: .horizontal) {
                    HStack { chronicleMessage; Spacer(); generateButton }
                    VStack(alignment: .leading, spacing: 12) { chronicleMessage; generateButton }
                }
            }
            if let status = state.storyStatus { Label(status, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green) }
            if let error = state.lastStoryError { Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange) }
            if state.repository.chronicles.isEmpty {
                StudioSurface {
                    VStack(spacing: 12) {
                        SpriteCat(category: .study, frame: 0).frame(width: 100, height: 84)
                        Text("The bookshelf is waiting").font(.system(size: 24, design: .serif))
                        Text("Generate a chapter after your day has taken shape.").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 230)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                    ForEach(state.repository.chronicles) { chapter in ChronicleCard(chapter: chapter) }
                }
            }
        }
    }

    private var chronicleMessage: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.aiEnabled ? "Turn today into a chapter" : "Gemini is resting").font(.title3.weight(.medium))
            Text(state.aiEnabled ? "Only aggregate activity totals are included." : "Enable reflections in Comfort Settings.")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var generateButton: some View {
        Button { Task { await state.generateChronicle() } } label: {
            if state.isGeneratingStory { ProgressView().controlSize(.small) } else { Label("Write today’s chapter", systemImage: "wand.and.stars") }
        }.buttonStyle(.borderedProminent).tint(.white.opacity(0.18)).disabled(!state.aiEnabled || state.isGeneratingStory)
    }
}

private struct ChronicleCard: View {
    @EnvironmentObject private var state: AppState
    let chapter: DailyChronicle
    private var totals: [ActivityTotal] { ActivityAnalyticsService.totals(state.repository.sessions, for: chapter.date).filter { $0.minutes > 0 } }

    var body: some View {
        StudioSurface(tint: Color.cream.opacity(0.72)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(chapter.date.formatted(.dateTime.month(.abbreviated).day())).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Spacer(); Image(systemName: "bookmark.fill").foregroundStyle(Color.sage)
                }
                Text(chapter.title).font(.system(size: 23, weight: .medium, design: .serif))
                Text(chapter.story).font(.callout).fixedSize(horizontal: false, vertical: true)
                if let suggestion = chapter.suggestedStep {
                    Divider(); Text("A small experiment").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    TomorrowStepView(repository: state.repository, suggestion: suggestion)
                }
                if !totals.isEmpty {
                    HStack { ForEach(totals.prefix(3)) { total in Label("\(total.minutes)m", systemImage: total.category.icon).font(.caption2).padding(5).background(.white.opacity(0.6), in: Capsule()) } }
                }
            }
        }
    }
}

struct ComfortStudioView: View {
    @EnvironmentObject private var state: AppState
    @State private var key = GeminiKeychain.load() ?? ""
    @State private var saved = false
    @State private var confirmDeletion = false

    var body: some View {
        StudioShell(title: "Comfort settings", subtitle: "Tune Mochi, reflections, and privacy to fit your space.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], alignment: .leading, spacing: 16) {
                widgetSettings
                geminiSettings
                privacySettings
            }
        }
    }

    private var widgetSettings: some View {
        StudioSurface {
            VStack(alignment: .leading, spacing: 15) {
                SettingsHeading(icon: "cat", title: "Mochi’s corner", detail: "Appearance and movement")
                Divider()
                Toggle("Show desktop companion", isOn: $state.widgetVisible)
                Toggle("Keep above other windows", isOn: $state.alwaysOnTop)
                Toggle("Reduce animation", isOn: $state.reducedMotion)
                settingSlider("Widget size", value: $state.widgetScale, range: 0.7...1.6, valueText: String(format: "%.1f×", state.widgetScale))
                settingSlider("Animation pace", value: $state.animationInterval, range: 0.3...0.6, valueText: "\(Int(state.animationInterval * 1000)) ms")
            }
        }
    }

    private var geminiSettings: some View {
        StudioSurface(tint: Color.lilac.opacity(0.15)) {
            VStack(alignment: .leading, spacing: 15) {
                SettingsHeading(icon: "sparkles", title: "Gemini reflections", detail: "Optional daily chapters")
                Divider(); Toggle("Enable daily reflections", isOn: $state.aiEnabled)
                SecureField("Gemini API key", text: $key).textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save to Keychain") { saveKey() }.buttonStyle(.borderedProminent).tint(.lilac).disabled(key.isEmpty)
                    if saved { Label("Saved", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
                }
                Text("ScreenShire sends category totals, goal status, and short fictional memory notes when you request a chapter.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var privacySettings: some View {
        StudioSurface(tint: Color.sage.opacity(0.12)) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsHeading(icon: "lock.shield", title: "Your data", detail: "Stored locally on this Mac")
                Divider()
                Label("Foreground app names and time", systemImage: "checkmark.circle")
                Label("No screen contents or keystrokes", systemImage: "eye.slash")
                Button("Delete all local history", role: .destructive) { confirmDeletion = true }
                    .confirmationDialog("Delete activity, chapters, and all daybook pages?", isPresented: $confirmDeletion) {
                        Button("Delete history", role: .destructive) { state.repository.deleteAllHistory() }
                    }
            }
        }
    }

    private func settingSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(spacing: 6) { HStack { Text(title); Spacer(); Text(valueText).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }; Slider(value: value, in: range) }
    }

    private func saveKey() { do { try GeminiKeychain.save(key); saved = true } catch { saved = false } }
}

private struct SettingsHeading: View {
    let icon: String; let title: String; let detail: String
    var body: some View { HStack(spacing: 12) { Image(systemName: icon).font(.title3).frame(width: 38, height: 38).background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) } } }
}

private struct ProductiveCategoryOptions: View {
    var body: some View { ForEach(ActivityCategory.allCases.filter { $0 != .idle && $0 != .uncategorized }) { Text($0.label).tag($0) } }
}

private struct AllCategoryOptions: View {
    var body: some View { ForEach(ActivityCategory.allCases.filter { $0 != .idle }) { Text($0.label).tag($0) } }
}
