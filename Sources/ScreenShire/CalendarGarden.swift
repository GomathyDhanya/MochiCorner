import SwiftUI

struct ActivityCalendarView: View {
    @EnvironmentObject private var state: AppState
    @State private var displayedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
    @State private var selectedDay = Date()
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Mochi’s memory garden", subtitle: "Every day becomes a small, readable memory. Icons and words carry meaning too—never color alone.")
                monthControls
                calendarGrid
                DayMemoryCard(day: selectedDay)
                    .environmentObject(state)
            }
            .padding(30)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle("")
    }

    private var monthControls: some View {
        HStack {
            Button { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)! } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year())).font(.title2.bold())
            Spacer()
            Button { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)! } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next month")
            Button("Today") { displayedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!; selectedDay = .now }
                .buttonStyle(.bordered)
        }
        .cozyCard(tint: .lilac.opacity(0.18))
    }

    private var calendarGrid: some View {
        let days = gridDays()
        return VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in Text(weekday.prefix(1)).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
                ForEach(days, id: \.self) { day in GardenDayCell(day: day, isCurrentMonth: calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month), isSelected: calendar.isDate(day, inSameDayAs: selectedDay)) { selectedDay = day }.environmentObject(state) }
            }
        }
        .cozyCard()
    }

    private func gridDays() -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: displayedMonth), let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start), let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end), let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay) else { return [] }
        var result: [Date] = []
        var day = firstWeek.start
        while day < lastWeek.end { result.append(day); day = calendar.date(byAdding: .day, value: 1, to: day)! }
        return result
    }
}

private struct GardenDayCell: View {
    @EnvironmentObject private var state: AppState
    let day: Date; let isCurrentMonth: Bool; let isSelected: Bool; let select: () -> Void
    private var summary: GardenSummary { GardenSummary(day: day, sessions: state.repository.sessions) }
    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(day.formatted(.dateTime.day())).font(.caption.bold()); Spacer(); if summary.minutes > 0 { Text(summary.gardenEmoji).font(.caption) } }
                if summary.minutes > 0 {
                    Text("\(summary.minutes)m").font(.caption2.monospacedDigit())
                    Text(summary.dominant.label).font(.caption2).lineLimit(1)
                } else { Text("—").font(.caption2).foregroundStyle(.tertiary) }
            }
            .foregroundStyle(isCurrentMonth ? Color.primary : Color.secondary.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading).padding(7)
            .background(isSelected ? Color.sage.opacity(0.35) : summary.tint.opacity(summary.minutes > 0 ? 0.16 : 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.sage : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)). \(summary.accessibilityDescription)")
    }
}

private struct DayMemoryCard: View {
    @EnvironmentObject private var state: AppState
    let day: Date
    private var summary: GardenSummary { GardenSummary(day: day, sessions: state.repository.sessions) }
    private var appMinutes: [(String, Int)] {
        let interval = Calendar.current.dateInterval(of: .day, for: day)!
        return Dictionary(grouping: state.repository.sessions, by: \.appName).map { name, sessions in
            let seconds = sessions.reduce(0.0) { partial, session in
                let end = session.endedAt ?? Date(); return partial + max(0, min(end, interval.end).timeIntervalSince(max(session.startedAt, interval.start)))
            }
            return (name, Int(seconds / 60))
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
    private var chapter: DailyChronicle? { state.repository.chronicles.first { Calendar.current.isDate($0.date, inSameDayAs: day) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { VStack(alignment: .leading, spacing: 3) { Text(day.formatted(date: .complete, time: .omitted)).font(.title3.bold()); Text(summary.minutes == 0 ? "A quiet page in Mochi’s garden." : summary.plainLanguage).foregroundStyle(.secondary) }; Spacer(); Text(summary.gardenEmoji).font(.system(size: 42)) }
            if summary.minutes > 0 {
                Divider()
                Text("Screen-time facts").font(.caption.bold()).foregroundStyle(.secondary)
                HStack(spacing: 8) { ForEach(summary.totals) { total in Label("\(total.minutes)m \(total.category.label)", systemImage: total.category.icon).font(.caption).padding(.horizontal, 8).padding(.vertical, 5).background(Color.sage.opacity(0.16), in: Capsule()) } }
                if !appMinutes.isEmpty { Text("Apps").font(.caption.bold()).foregroundStyle(.secondary); ForEach(appMinutes.prefix(5), id: \.0) { app in HStack { Text(app.0); Spacer(); Text("\(app.1)m").monospacedDigit().foregroundStyle(.secondary) } } }
            }
            if let chapter { Divider(); Label("Mochi wrote a chapter", systemImage: "book.closed.fill").font(.headline); Text(chapter.story).font(.callout) }
        }
        .cozyCard(tint: summary.tint.opacity(0.14))
    }
}

private struct GardenSummary {
    let day: Date; let totals: [ActivityTotal]
    init(day: Date, sessions: [UsageSession]) { self.day = day; totals = ActivityAnalyticsService.totals(sessions, for: day) }
    var minutes: Int { totals.reduce(0) { $0 + $1.minutes } }
    var dominant: ActivityCategory { totals.first?.category ?? .uncategorized }
    var tint: Color { switch dominant { case .work: .sage; case .code: .lilac; case .study: .peach; case .music: .lilac; case .entertainment: .peach; case .social: .sage; case .create: .peach; case .game: .lilac; case .uncategorized, .idle: .cream } }
    var gardenEmoji: String { switch dominant { case .work: "🪴"; case .code: "🪨"; case .study: "📚"; case .music: "🎵"; case .entertainment: "🍿"; case .social: "🌻"; case .create: "🎨"; case .game: "🍄"; case .uncategorized, .idle: "·" } }
    var plainLanguage: String { "\(minutes) minutes total, mostly \(dominant.label.lowercased())." }
    var accessibilityDescription: String { minutes == 0 ? "No tracked activity." : plainLanguage }
}
