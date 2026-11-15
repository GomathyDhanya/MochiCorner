import SwiftUI

struct ActivityCalendarView: View {
    @EnvironmentObject private var state: AppState
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var selectedDay = Date()
    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 760
            ScrollView {
                VStack(alignment: .leading, spacing: wide ? 18 : 14) {
                    gardenHeader(compact: !wide)
                    if wide {
                        HStack(alignment: .top, spacing: 18) {
                            calendarPanel(compact: false)
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 14) {
                                AnnualGardenView(pages: state.repository.pages, compact: true)
                                DayMemoryCard(day: selectedDay, compact: false)
                            }
                            .frame(width: min(330, geometry.size.width * 0.36))
                        }
                    } else {
                        AnnualGardenView(pages: state.repository.pages, compact: true)
                        calendarPanel(compact: true)
                        DayMemoryCard(day: selectedDay, compact: true)
                    }
                }
                .padding(wide ? 28 : 14)
                .frame(maxWidth: 1160, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color.cream.opacity(0.14))
        }
        .navigationTitle("")
    }

    private func gardenHeader(compact: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Memory garden")
                    .font(.system(size: compact ? 26 : 34, weight: .medium, design: .serif))
                if !compact {
                    Text("A quiet map of how your days unfolded.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
            SpriteCat(category: .study, frame: 0)
                .frame(width: compact ? 52 : 68, height: compact ? 46 : 60)
                .accessibilityHidden(true)
        }
    }

    private func calendarPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 14) {
            HStack(spacing: 8) {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(GardenIconButtonStyle()).accessibilityLabel("Previous month")
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: compact ? 19 : 24, weight: .medium, design: .serif))
                    .frame(maxWidth: .infinity)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(GardenIconButtonStyle()).accessibilityLabel("Next month")
                Button("Today") { showToday() }
                    .buttonStyle(.borderless).font(.caption.weight(.semibold))
            }
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 4 : 7), count: 7), spacing: compact ? 4 : 7) {
                ForEach(gridDays(), id: \.self) { day in
                    GardenDayCell(
                        day: day,
                        isCurrentMonth: calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                        compact: compact
                    ) { selectedDay = day }
                    .environmentObject(state)
                }
            }
        }
        .padding(compact ? 12 : 18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            }
        }
    }

    private func shiftMonth(_ amount: Int) {
        guard let month = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else { return }
        displayedMonth = month
        selectedDay = month
    }

    private func showToday() {
        displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
        selectedDay = .now
    }

    private func gridDays() -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay) else { return [] }
        var days: [Date] = []
        var day = firstWeek.start
        while day < lastWeek.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }
}

private struct GardenIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .background(.primary.opacity(configuration.isPressed ? 0.12 : 0.06), in: Circle())
    }
}

private struct GardenDayCell: View {
    @EnvironmentObject private var state: AppState
    let day: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let compact: Bool
    let select: () -> Void
    private var summary: GardenSummary { GardenSummary(day: day, sessions: state.repository.sessions) }

    var body: some View {
        Button(action: select) {
            VStack(spacing: compact ? 1 : 4) {
                HStack {
                    Text(day.formatted(.dateTime.day()))
                        .font(compact ? .caption.weight(.semibold) : .callout.weight(.semibold))
                    Spacer(minLength: 2)
                    if summary.minutes > 0 {
                        Image(systemName: summary.dominant.icon)
                            .font(.system(size: compact ? 7 : 10, weight: .bold))
                    }
                }
                Spacer(minLength: 0)
                if summary.minutes > 0 {
                    HStack(spacing: 3) {
                        Capsule().fill(summary.tint).frame(maxWidth: .infinity, minHeight: 3, maxHeight: 3)
                        if !compact { Text("\(summary.minutes)m").font(.caption2.monospacedDigit()) }
                    }
                }
            }
            .foregroundStyle(isSelected ? .white : (isCurrentMonth ? Color.primary : Color.secondary.opacity(0.42)))
            .padding(compact ? 5 : 8)
            .frame(maxWidth: .infinity, minHeight: compact ? 48 : 70, alignment: .topLeading)
            .background(cellBackground, in: RoundedRectangle(cornerRadius: compact ? 8 : 11, style: .continuous))
            .overlay {
                if Calendar.current.isDateInToday(day) {
                    RoundedRectangle(cornerRadius: compact ? 8 : 11).stroke(Color.sage, lineWidth: isSelected ? 0 : 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)). \(summary.accessibilityDescription)")
    }

    private var cellBackground: Color {
        if isSelected { return Color(red: 0.14, green: 0.31, blue: 0.27) }
        return summary.minutes > 0 ? summary.tint.opacity(0.17) : .primary.opacity(0.025)
    }
}

private struct DayMemoryCard: View {
    @EnvironmentObject private var state: AppState
    let day: Date
    let compact: Bool
    private var summary: GardenSummary { GardenSummary(day: day, sessions: state.repository.sessions) }
    private var appMinutes: [(String, Int)] {
        let interval = Calendar.current.dateInterval(of: .day, for: day)!
        return Dictionary(grouping: state.repository.sessions, by: \.appName).map { name, sessions in
            let seconds = sessions.reduce(0.0) { partial, session in
                let end = session.endedAt ?? Date()
                return partial + max(0, min(end, interval.end).timeIntervalSince(max(session.startedAt, interval.start)))
            }
            return (name, Int(seconds / 60))
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
    @State private var showingSummary = false
    private var chapter: DailyChronicle? {
        state.repository.chronicles.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.formatted(.dateTime.weekday(.wide))).font(.caption.weight(.bold)).textCase(.uppercase).tracking(1.2)
                    Text(day.formatted(.dateTime.month(.wide).day()))
                        .font(.system(size: compact ? 23 : 29, weight: .medium, design: .serif))
                }
                Spacer()
                Button { showingSummary = true } label: { Image(systemName: "book.pages") }.accessibilityLabel("Read full day summary")
                Text(summary.minutes == 0 ? "Quiet day" : "\(summary.minutes)m")
                    .font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.white.opacity(0.55), in: Capsule())
            }

            if summary.minutes == 0 {
                Label("Time away from the screen belongs here too.", systemImage: "moon.stars")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                categorySummary
                if !compact && !appMinutes.isEmpty {
                    Divider()
                    Text("Most visited").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(appMinutes.prefix(4), id: \.0) { app in
                        HStack { Text(app.0).lineLimit(1); Spacer(); Text("\(app.1)m").monospacedDigit().foregroundStyle(.secondary) }
                            .font(.callout)
                    }
                }
            }

            if !compact, let chapter {
                Divider()
                Label("Mochi’s note", systemImage: "book.closed.fill").font(.caption.weight(.bold))
                Text(chapter.story).font(.caption).lineLimit(4)
            }
        }
        .sheet(isPresented: $showingSummary) {
            let page = state.repository.pages[DaybookPage.key(day)] ?? DaybookPage()
            VStack(alignment: .leading) {
                HStack { Text(day.formatted(date: .complete, time: .omitted)).font(.headline); Spacer(); Button("Done") { showingSummary = false } }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(summary.minutes) screen minutes · \(page.petals) petals")
                        ForEach(summary.totals) { Text("\($0.category.label) · \($0.minutes)m") }
                        ForEach(page.steps) { Label($0.title, systemImage: $0.complete ? "checkmark.circle.fill" : "circle") }
                        if page.tookBreak { Label("Screen-free break", systemImage: "leaf") }
                        ForEach(Array([page.board.mood, page.board.tinyWin, page.board.currently].enumerated()), id: \.offset) { _, value in if !value.isEmpty { Text(value).italic() } }
                        if !page.journal.isEmpty { Divider(); Text("Private journal").bold(); Text(page.journal) }
                        if let chapter { Divider(); Text(chapter.title).bold(); Text(chapter.story) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding().frame(minWidth: 320, minHeight: 350)
        }
        .padding(compact ? 14 : 20)
        .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.20))
        .background(
            LinearGradient(colors: [summary.tint.opacity(0.46), Color.cream.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.07)))
    }

    private var categorySummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 82 : 110), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(summary.totals.prefix(compact ? 3 : 5)) { total in
                Label("\(total.minutes)m \(total.category.label)", systemImage: total.category.icon)
                    .font(.caption2.weight(.medium)).lineLimit(1)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(.white.opacity(0.55), in: Capsule())
            }
        }
    }
}

private struct GardenSummary {
    let day: Date
    let totals: [ActivityTotal]
    init(day: Date, sessions: [UsageSession]) {
        self.day = day
        totals = ActivityAnalyticsService.totals(sessions, for: day).filter { $0.minutes > 0 }
    }
    var minutes: Int { totals.reduce(0) { $0 + $1.minutes } }
    var dominant: ActivityCategory { totals.first?.category ?? .uncategorized }
    var tint: Color {
        switch dominant {
        case .work, .social: .sage
        case .code, .music, .game: .lilac
        case .study, .entertainment, .create: .peach
        case .uncategorized, .idle: .cream
        }
    }
    var accessibilityDescription: String {
        minutes == 0 ? "No tracked activity." : "\(minutes) minutes total, mostly \(dominant.label.lowercased())."
    }
}
