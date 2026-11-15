import SwiftUI

struct DaybookPage: Codable, Equatable {
    struct Step: Identifiable, Codable, Equatable {
        var id = UUID()
        var title: String
        var complete = false
    }

    var steps: [Step] = []
    var journal = ""
    var skippedSteps: Set<UUID>? = nil
    var tookBreak = false
    var board = Board()

    struct Board: Codable, Equatable {
        var mood = ""
        var tinyWin = ""
        var currently = ""
    }

    enum CodingKeys: String, CodingKey { case steps, journal, tookBreak, board, skippedSteps }

    init(steps: [Step] = [], journal: String = "", tookBreak: Bool = false, board: Board = Board()) {
        self.steps = steps
        self.journal = journal
        self.tookBreak = tookBreak
        self.board = board
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        steps = try values.decodeIfPresent([Step].self, forKey: .steps) ?? []
        journal = try values.decodeIfPresent(String.self, forKey: .journal) ?? ""
        tookBreak = try values.decodeIfPresent(Bool.self, forKey: .tookBreak) ?? false
        skippedSteps = try values.decodeIfPresent(Set<UUID>.self, forKey: .skippedSteps)
        board = try values.decodeIfPresent(Board.self, forKey: .board) ?? Board()
    }

    var petals: Int {
        steps.filter(\.complete).count + (tookBreak ? 1 : 0) +
            (journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) + boardPetals
    }

    var boardPetals: Int {
        [board.mood, board.tinyWin, board.currently]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    mutating func add(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        steps.append(Step(title: clean))
    }

    static func key(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year!, day.month!, day.day!)
    }
}

struct DaybookView: View {
    @ObservedObject var repository: ActivityRepository
    @EnvironmentObject private var state: AppState
    @State private var date = Date()
    @State private var reading = false

    var body: some View {
        GeometryReader { bounds in
            let roomy = bounds.size.width >= 670
            ScrollView {
                VStack(alignment: .leading, spacing: roomy ? 24 : 16) {
                    HStack {
                        Text("Daybook").font(.system(size: 27, weight: .medium, design: .serif))
                        Spacer()
                        Button { reading = true } label: { Image(systemName: "book.pages") }.accessibilityLabel("Read private journal")
                        DatePicker("Choose page", selection: $date, displayedComponents: .date)
                            .labelsHidden().fixedSize()
                        if !Calendar.current.isDateInToday(date) {
                            Button("Today") { date = .now }
                        }
                    }
                    GardenCover(date: date, petals: repository.pages[DaybookPage.key(date)]?.petals ?? 0)
                    AnnualGardenView(pages: repository.pages)
                    SlambookBoard(repository: repository, key: DaybookPage.key(date), roomy: roomy)
                        .id("board-\(DaybookPage.key(date))")
                    DailyPageEditor(
                        repository: repository,
                        key: DaybookPage.key(date),
                        roomy: roomy,
                        aiEnabled: state.aiEnabled,
                        enableAI: { state.aiEnabled = true }
                    )
                        .id(DaybookPage.key(date))
                }
                .padding(roomy ? 32 : 18)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $reading) { DiaryReader(repository: repository) }
        .navigationTitle("")
    }
}

struct TomorrowStepView: View {
    @ObservedObject var repository: ActivityRepository
    @State private var opening = false
    let chapter: DailyChronicle
    private var suggestion: String { chapter.suggestedStep?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    private var key: String {
        DaybookPage.key(Calendar.current.date(byAdding: .day, value: 1, to: chapter.date)!)
    }
    private var added: Bool { repository.pages[key]?.steps.contains { $0.title == suggestion } == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion)
            Button(added ? "In Small steps · \(key)" : "Add to Small steps · \(key)") {
                repository.addSuggestedStep(from: chapter)
            }
            .disabled(added)
            if added {
                Button("Open Small steps") { opening = true }
                    .sheet(isPresented: $opening) {
                        VStack {
                            HStack { Text(key).font(.headline); Spacer(); Button("Done") { opening = false } }
                            ScrollView { DailyPageEditor(repository: repository, key: key, roomy: false) }
                        }.padding().frame(minWidth: 320, idealWidth: 440, minHeight: 360)
                    }
            }
            if let error = repository.pageError { Text(error).font(.caption) }
        }
    }
}

struct AnnualGardenView: View {
    let pages: [String: DaybookPage]
    var compact = false
    private var year: Int { Calendar.current.component(.year, from: .now) }
    private var thisYear: [(String, DaybookPage)] {
        pages.filter { $0.key.hasPrefix("\(year)-") }.sorted { $0.key < $1.key }
    }
    private var totalFlowers: Int { thisYear.reduce(0) { $0 + $1.1.petals } }
    private var flowers: Int { totalFlowers }
    private var activeDays: Int { thisYear.filter { $0.1.petals > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(compact ? "This year’s garden" : "Your growing garden")
                .font(.system(size: compact ? 20 : 24, weight: .medium, design: .serif))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    gardenCaption
                    Spacer(minLength: 8)
                    gardenStats
                }
                VStack(alignment: .leading, spacing: 3) {
                    gardenCaption
                    gardenStats
                }
            }
            GeometryReader { proxy in
                Canvas { context, size in
                    let ground = size.height * 0.78
                    context.fill(Path(CGRect(x: 0, y: ground, width: size.width, height: size.height - ground)), with: .color(Color.sage.opacity(0.25)))
                    for index in 0..<flowers {
                        let x = 22 + (CGFloat(index * 47 % max(1, Int(size.width - 44))))
                        let height = CGFloat(18 + (index * 13 % 40))
                        var stem = Path()
                        stem.move(to: CGPoint(x: x, y: ground + 4))
                        stem.addCurve(to: CGPoint(x: x + CGFloat(index % 3 - 1) * 5, y: ground - height), control1: CGPoint(x: x + 4, y: ground - height * 0.35), control2: CGPoint(x: x - 5, y: ground - height * 0.72))
                        context.stroke(stem, with: .color(Color(red: 0.25, green: 0.48, blue: 0.31)), lineWidth: 2)
                        let blossom = CGRect(x: x - 6, y: ground - height - 7, width: 13, height: 13)
                        let colors: [Color] = [Color.peach, Color.lilac, Color(red: 0.94, green: 0.52, blue: 0.60), Color(red: 0.96, green: 0.76, blue: 0.29)]
                        context.fill(Path(ellipseIn: blossom), with: .color(colors[index % colors.count]))
                        context.fill(Path(ellipseIn: blossom.insetBy(dx: 4, dy: 4)), with: .color(.white.opacity(0.78)))
                    }
                }
                .background(
                    LinearGradient(colors: [Color(red: 0.82, green: 0.92, blue: 0.88), Color.cream], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(alignment: .center) {
                    if flowers == 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.macro").font(.title2).foregroundStyle(Color.sage)
                            Text("Your first flower is waiting.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.frame(height: compact ? 96 : 128)
        }.cozyCard(tint: Color.sage.opacity(0.11))
    }

    private var gardenCaption: some View {
        Text("Flowers grow all year, then begin fresh on January 1.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var gardenStats: some View {
        Text("\(totalFlowers) flowers this year · \(activeDays) active days")
            .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
    }
}

private struct SlambookBoard: View {
    @ObservedObject var repository: ActivityRepository
    let key: String
    let roomy: Bool
    @State private var board: DaybookPage.Board
    @State private var clearing = false
    private var page: DaybookPage { repository.pages[key] ?? DaybookPage() }

    init(repository: ActivityRepository, key: String, roomy: Bool) {
        self.repository = repository
        self.key = key
        self.roomy = roomy
        _board = State(initialValue: repository.pages[key]?.board ?? DaybookPage.Board())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mood").font(.system(size: 25, weight: .medium, design: .serif))
                    Text("A few small things from today.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if page.boardPetals > 0 {
                    Button { clearing = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Clear mood")
                        .confirmationDialog("Clear today’s mood?", isPresented: $clearing) {
                            Button("Clear mood", role: .destructive) {
                                var next = page
                                next.board = .init()
                                if repository.savePage(next, for: key) {
                                    board = next.board
                                }
                            }
                        }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: roomy ? 210 : 145), spacing: 10)], spacing: 10) {
                BoardField(icon: "face.smiling", title: "Mood", placeholder: "Soft, brave, tired…", text: $board.mood, color: Color.peach)
                BoardField(icon: "sparkles", title: "Tiny win", placeholder: "What went right?", text: $board.tinyWin, color: Color.lilac)
                BoardField(icon: "headphones", title: "Now listening to", placeholder: "A song, podcast, or sound…", text: $board.currently, color: Color.sage)
            }
        }
        .onChange(of: page.board) { _, value in board = value }
        .onChange(of: board) { _, value in save() }
        .cozyCard(tint: Color.lilac.opacity(0.10))
    }

    private func save() {
        var next = page
        next.board = board
        _ = repository.savePage(next, for: key)
    }
}

private struct BoardField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) { Image(systemName: icon).foregroundStyle(color); Text(title).font(.caption.weight(.bold)) }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(8).background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(11)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DailyPageEditor: View {
    @ObservedObject var repository: ActivityRepository
    let key: String
    let roomy: Bool
    let aiEnabled: Bool
    let enableAI: () -> Void
    @State private var draft = ""
    @State private var brainDump = ""
    @State private var suggestions: [String] = []
    @State private var isShapingThought = false
    @State private var planningError: String?
    @State private var plannerOpen = false
    @State private var diaryOpen = false
    @State private var journalDraft: String
    @State private var noteSaved = false
    private var page: DaybookPage { repository.pages[key] ?? DaybookPage() }

    init(repository: ActivityRepository, key: String, roomy: Bool, aiEnabled: Bool = false, enableAI: @escaping () -> Void = {}) {
        self.repository = repository
        self.key = key
        self.roomy = roomy
        self.aiEnabled = aiEnabled
        self.enableAI = enableAI
        _journalDraft = State(initialValue: repository.pages[key]?.journal ?? "")
        _noteSaved = State(initialValue: true)
    }

    var body: some View {
        let layout = roomy ? AnyLayout(HStackLayout(alignment: .top, spacing: 18)) : AnyLayout(VStackLayout(spacing: 16))
        VStack(alignment: .leading, spacing: 14) {
          layout {
            VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Small steps").font(.system(size: 23, design: .serif))
                    Spacer()
                    Text("\(page.steps.filter(\.complete).count) / \(page.steps.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Divider()
                ForEach(page.steps) { step in
                    HStack {
                        Toggle(step.title, isOn: Binding(get: { step.complete }, set: { done in
                            update { page in
                                if let i = page.steps.firstIndex(where: { $0.id == step.id }) {
                                    page.steps[i].complete = done
                                }
                            }
                        })).toggleStyle(.checkbox)
                        Spacer()
                        Button { update { page in page.skippedSteps = (page.skippedSteps ?? []).union([step.id]); page.steps.removeAll { $0.id == step.id } } } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.borderless).accessibilityLabel("Remove \(step.title)")
                    }
                }
                HStack {
                    TextField("Add a small step…", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button(action: add) { Image(systemName: "plus.circle.fill").font(.title2) }
                        .buttonStyle(.plain).accessibilityLabel("Add step").disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 8)
                DisclosureGroup("Turn a thought into gentle steps", isExpanded: $plannerOpen) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("What feels tangled or hard to begin?", text: $brainDump, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            if !aiEnabled {
                                PlannerActionButton(title: "Enable Gemini", icon: "wand.and.stars", primary: false, action: enableAI)
                            }
                            PlannerActionButton(title: "Shape it", icon: "sparkles", primary: true, isLoading: isShapingThought, action: shapeThought)
                                .disabled(isShapingThought || brainDump.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if let planningError {
                            Text(planningError).font(.caption).foregroundStyle(.red)
                        }
                        ForEach(suggestions, id: \.self) { suggestion in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "sparkle").foregroundStyle(Color.lilac)
                                Text(suggestion).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Button("Add") { addSuggestion(suggestion) }
                                    .buttonStyle(.borderless)
                                    .disabled(page.steps.contains { $0.title.caseInsensitiveCompare(suggestion) == .orderedSame })
                            }
                        }
                        if !suggestions.isEmpty {
                            HStack {
                                Spacer()
                                Button("Done with suggestions", action: resetPlanner)
                                    .buttonStyle(.borderless)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.cocoa)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }.cozyCard()
            Toggle("I took a screen-free break", isOn: Binding(get: { page.tookBreak }, set: { value in
                update { $0.tookBreak = value }
            })).toggleStyle(.switch).frame(maxWidth: .infinity, alignment: .leading).cozyCard(tint: Color.sage.opacity(0.16))
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("Private journal").font(.system(size: 23, design: .serif)); Spacer(); Button("Read diary") { diaryOpen = true } }.sheet(isPresented: $diaryOpen) { DiaryReader(repository: repository) }
                Divider()
                TextEditor(text: $journalDraft)
                    .font(.system(size: 17, design: .serif)).lineSpacing(6)
                    .foregroundStyle(.black.opacity(0.84)).frame(minHeight: 168)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .padding(.leading, 20).background(NotebookPaper())
                    .onChange(of: page.journal) { _, value in if noteSaved { journalDraft = value } }
                    .onChange(of: journalDraft) { _, value in
                        noteSaved = value == page.journal
                    }
                HStack {
                    Label(noteSaved ? "Saved on this Mac" : "Unsaved note", systemImage: noteSaved ? "checkmark.circle" : "pencil")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Save note", action: saveJournal)
                        .buttonStyle(.borderedProminent).tint(.sage)
                        .disabled(noteSaved)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).cozyCard()
          }
            if let error = repository.pageError { Text(error).foregroundStyle(.red) }
        }
    }

    private func add() {
        if update({ $0.add(draft) }) {
            draft = ""
        }
    }

    private func saveJournal() {
        if update({ $0.journal = journalDraft }) { noteSaved = true }
    }

    private func shapeThought() {
        let thought = brainDump
        planningError = nil
        isShapingThought = true
        Task {
            defer { isShapingThought = false }
            do {
                suggestions = try await GeminiPlanningService().generateSteps(from: thought, enabled: aiEnabled)
            } catch {
                planningError = error.localizedDescription
            }
        }
    }

    private func addSuggestion(_ suggestion: String) {
        guard update({ $0.add(suggestion) }) else { return }
        suggestions.removeAll { $0 == suggestion }
    }

    private func resetPlanner() {
        brainDump = ""
        suggestions = []
        planningError = nil
        plannerOpen = false
    }

    @discardableResult private func update(_ edit: (inout DaybookPage) -> Void) -> Bool {
        var next = page
        edit(&next)
        return repository.savePage(next, for: key)
    }
}

private struct PlannerActionButton: View {
    let title: String
    let icon: String
    let primary: Bool
    var isLoading = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(primary ? .white : Color.cocoa)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule().fill(primary
                    ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.49, green: 0.35, blue: 0.61), Color.lilac], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.lilac.opacity(0.24)))
            }
            .overlay {
                Capsule().stroke(primary ? .clear : Color.lilac.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: primary ? Color.lilac.opacity(0.22) : .clear, radius: 7, y: 3)
            .opacity(isEnabled ? 1 : 0.48)
        }
        .buttonStyle(.plain)
    }
}

struct DiaryReader: View {
    @ObservedObject var repository: ActivityRepository
    @State private var index = 0
    @State private var deleting: String?
    @Environment(\.dismiss) private var dismiss
    private func heading(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = Calendar(identifier: .gregorian).date(from: .init(year: parts[0], month: parts[1], day: parts[2])) else { return key }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }
    private var entries: [String] { repository.pages.keys.filter { !(repository.pages[$0]?.journal ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.sorted(by: >) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Label("Private journal", systemImage: "book").font(.headline); Spacer(); Button("Close") { dismiss() } }
            Divider()
            if entries.isEmpty { Text("Your first saved note will appear here.") }
            else {
                let position = min(index, entries.count - 1)
                let day = entries[position]
                HStack {
                    Text(heading(day)).font(.system(.title, design: .serif))
                    Spacer()
                    Button { deleting = day } label: { Image(systemName: "trash") }.accessibilityLabel("Delete this note")
                }
                ScrollView { Text(repository.pages[day]?.journal ?? "").font(.system(size: 18, design: .serif)).lineSpacing(8).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                Divider()
                HStack {
                    Button("Newer") { index = position - 1 }.disabled(position == 0)
                    Spacer(); Text("Page \(position + 1) of \(entries.count)").italic(); Spacer()
                    Button("Older") { index = position + 1 }.disabled(position + 1 == entries.count)
                }
            }
        }.padding(28).padding(.leading, 16).frame(minWidth: 320, idealWidth: 520, minHeight: 380)
        .background(NotebookPaper()).foregroundStyle(Color.black.opacity(0.82))
        .padding(6).background(Color(red: 0.16, green: 0.29, blue: 0.24))
        .confirmationDialog("Delete this diary entry?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { key in
            Button("Delete note", role: .destructive) { repository.deleteNote(on: key) }
        } message: { _ in Text("Your steps and slambook stay on the page.") }
    }
}

private struct NotebookPaper: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 1, green: 0.979, blue: 0.916)))
            var rules = Path()
            for y in stride(from: CGFloat(24), to: size.height, by: 25) {
                rules.move(to: CGPoint(x: 12, y: y))
                rules.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(rules, with: .color(.blue.opacity(0.13)), lineWidth: 0.7)
            context.fill(Path(CGRect(x: 0, y: 0, width: 8, height: size.height)), with: .color(Color.sage))
            context.fill(Path(CGRect(x: 25, y: 0, width: 1, height: size.height)), with: .color(.red.opacity(0.25)))
        }.clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
    }
}
