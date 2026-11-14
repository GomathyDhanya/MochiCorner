import SwiftUI

struct DaybookPage: Codable, Equatable {
    struct Step: Identifiable, Codable, Equatable {
        var id = UUID()
        var title: String
        var complete = false
    }

    var steps: [Step] = []
    var journal = ""
    var tookBreak = false
    var board = Board()

    struct Board: Codable, Equatable {
        var mood = ""
        var tinyWin = ""
        var currently = ""
        var keepsake = ""
    }

    enum CodingKeys: String, CodingKey { case steps, journal, tookBreak, board }

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
        board = try values.decodeIfPresent(Board.self, forKey: .board) ?? Board()
    }

    var petals: Int {
        steps.filter(\.complete).count + (tookBreak ? 1 : 0) +
            (journal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) + boardPetals
    }

    var boardPetals: Int {
        [board.mood, board.tinyWin, board.currently, board.keepsake]
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
    @State private var date = Date()

    var body: some View {
        GeometryReader { bounds in
            let roomy = bounds.size.width >= 670
            ScrollView {
                VStack(alignment: .leading, spacing: roomy ? 24 : 16) {
                    HStack {
                        Text("Daybook").font(.system(size: 27, weight: .medium, design: .serif))
                        Spacer()
                        DatePicker("Choose page", selection: $date, displayedComponents: .date)
                            .labelsHidden().fixedSize()
                        if !Calendar.current.isDateInToday(date) {
                            Button("Today") { date = .now }
                        }
                    }
                    GardenCover(date: date, petals: repository.pages[DaybookPage.key(date)]?.petals ?? 0)
                    GardenGrowthView(pages: repository.pages)
                    SlambookBoard(repository: repository, key: DaybookPage.key(date), roomy: roomy)
                        .id("board-\(DaybookPage.key(date))")
                    DailyPageEditor(repository: repository, key: DaybookPage.key(date), roomy: roomy)
                        .id(DaybookPage.key(date))
                }
                .padding(roomy ? 32 : 18)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
    }
}

struct TomorrowStepView: View {
    @ObservedObject var repository: ActivityRepository
    let suggestion: String
    private var key: String {
        DaybookPage.key(Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
    }
    private var added: Bool { repository.pages[key]?.steps.contains { $0.title == suggestion } == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion)
            Button(added ? "In tomorrow’s daybook" : "Add to tomorrow’s daybook") {
                var page = repository.pages[key] ?? DaybookPage()
                page.add(suggestion)
                _ = repository.savePage(page, for: key)
            }.disabled(added)
            if let error = repository.pageError { Text(error).font(.caption) }
        }
    }
}

private struct GardenGrowthView: View {
    let pages: [String: DaybookPage]
    private var recent: [(String, DaybookPage)] { pages.sorted { $0.key < $1.key }.suffix(21) }
    private var flowers: Int { min(30, recent.reduce(0) { $0 + $1.1.petals }) }
    private var activeDays: Int { recent.filter { $0.1.petals > 0 }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your growing garden").font(.system(size: 24, weight: .medium, design: .serif))
            HStack(alignment: .firstTextBaseline) {
                Text("Each saved memory, break, and completed step grows a flower.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("\(flowers) flowers · \(activeDays) active days")
                    .font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
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
            }.frame(height: 128)
        }.cozyCard(tint: Color.sage.opacity(0.11))
    }
}

private struct SlambookBoard: View {
    @ObservedObject var repository: ActivityRepository
    let key: String
    let roomy: Bool
    @State private var board: DaybookPage.Board
    @State private var saved = true
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
                    Text("Today’s little board").font(.system(size: 25, weight: .medium, design: .serif))
                    Text("A few details worth keeping.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(saved ? "Saved" : "Save board", action: save)
                    .buttonStyle(.borderedProminent).tint(.sage).disabled(saved)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: roomy ? 210 : 145), spacing: 10)], spacing: 10) {
                BoardField(icon: "face.smiling", title: "Mood", placeholder: "Soft, brave, tired…", text: $board.mood, color: Color.peach)
                BoardField(icon: "sparkles", title: "Tiny win", placeholder: "What went right?", text: $board.tinyWin, color: Color.lilac)
                BoardField(icon: "headphones", title: "Currently", placeholder: "Reading, listening, making…", text: $board.currently, color: Color.sage)
                BoardField(icon: "quote.opening", title: "Keepsake", placeholder: "A line to remember", text: $board.keepsake, color: Color(red: 0.94, green: 0.76, blue: 0.29))
            }
        }
        .onChange(of: board) { _, value in saved = value == page.board }
        .cozyCard(tint: Color.lilac.opacity(0.10))
    }

    private func save() {
        var next = page
        next.board = board
        if repository.savePage(next, for: key) { saved = true }
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
    @State private var draft = ""
    @State private var journalDraft: String
    @State private var noteSaved = false
    private var page: DaybookPage { repository.pages[key] ?? DaybookPage() }

    init(repository: ActivityRepository, key: String, roomy: Bool) {
        self.repository = repository
        self.key = key
        self.roomy = roomy
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
                        Button { update { $0.steps.removeAll { $0.id == step.id } } } label: {
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
            }.cozyCard()
            Toggle("I took a screen-free break", isOn: Binding(get: { page.tookBreak }, set: { value in
                update { $0.tookBreak = value }
            })).toggleStyle(.switch).frame(maxWidth: .infinity, alignment: .leading).cozyCard(tint: Color.sage.opacity(0.16))
            }.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                Text("Private journal").font(.system(size: 23, design: .serif))
                Divider()
                TextEditor(text: $journalDraft)
                    .font(.body)
                    .frame(minHeight: 138)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
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

    @discardableResult private func update(_ edit: (inout DaybookPage) -> Void) -> Bool {
        var next = page
        edit(&next)
        return repository.savePage(next, for: key)
    }
}
