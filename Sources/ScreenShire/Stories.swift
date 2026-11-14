import Foundation
import Security

struct StoryGoalStatus: Codable { let category: String; let limitMinutes: Int; let actualMinutes: Int; let overByMinutes: Int }
struct DailyStoryContext: Codable { let date: String; let categories: [ActivityTotalDTO]; let goals: [StoryGoalStatus]; let previousStoryMemory: [String] }
struct ActivityTotalDTO: Codable { let name: String; let minutes: Int }

enum DailyStoryContextBuilder {
    static func make(sessions: [UsageSession], goals: [UsageGoal], chronicles: [DailyChronicle]) -> DailyStoryContext {
        let totals = ActivityAnalyticsService.totals(sessions)
        let minutes = Dictionary(uniqueKeysWithValues: totals.map { ($0.category, $0.minutes) })
        let statuses = goals.filter(\.enabled).map { StoryGoalStatus(category: $0.category.rawValue, limitMinutes: $0.dailyLimitMinutes, actualMinutes: minutes[$0.category, default: 0], overByMinutes: max(0, minutes[$0.category, default: 0] - $0.dailyLimitMinutes)) }
        let date = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return DailyStoryContext(date: String(date), categories: totals.map { ActivityTotalDTO(name: $0.category.rawValue, minutes: $0.minutes) }, goals: statuses, previousStoryMemory: chronicles.prefix(5).map(\.memorySummary))
    }
}

enum GeminiKeychain {
    private static let service = "com.screenshire.gemini"
    static func load() -> String? { let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true]; var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }; return String(data: data, encoding: .utf8) }
    static func save(_ key: String) throws { let data = Data(key.utf8); let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]; SecItemDelete(base as CFDictionary); var q = base; q[kSecValueData as String] = data; guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw NSError(domain: "ScreenShire", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not save the Gemini key in Keychain."]) } }
}

enum StoryError: LocalizedError { case disabled, missingKey, malformedResponse, serviceBusy; var errorDescription: String? { switch self { case .disabled: "Enable AI stories in Settings first."; case .missingKey: "Add a Gemini API key in Settings first."; case .malformedResponse: "Gemini’s reply was not in the expected format."; case .serviceBusy: "Gemini is receiving high demand." } } }

enum OfflineChronicle {
    static func make(context: DailyStoryContext) -> DailyChronicle {
        let lead = context.categories.max(by: { $0.minutes < $1.minutes })?.name ?? "quiet"
        let overGoal = context.goals.contains { $0.overByMinutes > 0 }
        let minutes = context.categories.first(where: { $0.name == lead })?.minutes ?? 0
        let reflection = overGoal ? "Mochi noticed the day had become a little fuller than planned, so they tucked a gentle reminder beside tomorrow’s teacup." : "With a contented stretch, Mochi put the day’s tools away and saved a little warmth for tomorrow."
        return DailyChronicle(id: UUID(), date: .now, title: "Mochi’s Little \(lead.capitalized) Day", story: "Mochi spent \(minutes) minutes in the \(lead) corner of ScreenShire, following a small thread of curiosity from one task to the next. \(reflection)", memorySummary: "Mochi had a \(lead) day and ended it with a gentle plan for tomorrow.")
    }
}

struct GeminiStoryService {
    func generate(context: DailyStoryContext, enabled: Bool) async throws -> DailyChronicle {
        guard enabled else { throw StoryError.disabled }; guard let key = GeminiKeychain.load(), !key.isEmpty else { throw StoryError.missingKey }
        let facts = String(data: try JSONEncoder().encode(context), encoding: .utf8)!
        let prompt = """
        Write a warm, concise fictional cat chronicle about Mochi's day.
        Use only the supplied aggregate facts for activity details. You may mention exact numeric minutes only when they appear in Facts; never invent or estimate a statistic. Be gentle about exceeded goals.
        Return ONLY a valid JSON object, with exactly these non-empty string properties:
        {"title":"short chapter title","story":"2–4 sentence story","memorySummary":"one short continuity note"}
        Do not use Markdown, code fences, or extra keys.
        Facts: \(facts)
        """
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["responseMimeType": "application/json"]]
        // Use a specific available lightweight model instead of the overloaded
        // rolling `gemini-flash-latest` alias.
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!); request.httpMethod = "POST"; request.timeoutInterval = 20; request.setValue(key, forHTTPHeaderField: "x-goog-api-key"); request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await requestWithRetry(request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw StoryError.serviceBusy }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let candidates = json["candidates"] as? [[String: Any]], let content = candidates.first?["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]], let output = parts.first?["text"] as? String, let chapter = decodeChapter(output) else { throw StoryError.malformedResponse }
        return DailyChronicle(id: UUID(), date: Date(), title: chapter.title, story: chapter.story, memorySummary: chapter.memorySummary)
    }
    private func requestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        for attempt in 0..<3 {
            do {
                let result = try await URLSession.shared.data(for: request)
                if let response = result.1 as? HTTPURLResponse, response.statusCode != 429 && response.statusCode != 503 { return result }
            } catch {
                if attempt == 2 { throw StoryError.serviceBusy }
            }
            if attempt < 2 { try await Task.sleep(for: .seconds(Double(1 << attempt))) }
        }
        throw StoryError.serviceBusy
    }
    private func decodeChapter(_ output: String) -> GeneratedChapter? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let unfenced = trimmed.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonText: String
        if let first = unfenced.firstIndex(of: "{"), let last = unfenced.lastIndex(of: "}") { jsonText = String(unfenced[first...last]) } else { jsonText = unfenced }
        return try? JSONDecoder().decode(GeneratedChapter.self, from: Data(jsonText.utf8))
    }
    private struct GeneratedChapter: Decodable {
        let title: String; let story: String; let memorySummary: String
        enum CodingKeys: String, CodingKey { case title, story, memorySummary, memory_summary }
        init(from decoder: Decoder) throws { let values = try decoder.container(keyedBy: CodingKeys.self); title = try values.decode(String.self, forKey: .title); story = try values.decode(String.self, forKey: .story); memorySummary = try values.decodeIfPresent(String.self, forKey: .memorySummary) ?? values.decode(String.self, forKey: .memory_summary) }
    }
}
