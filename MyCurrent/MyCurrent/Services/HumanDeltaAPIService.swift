import Foundation

/// Human Delta public API lives at [api.humandelta.ai](https://api.humandelta.ai/) (Knowledge Base REST).
/// Keys come from [dev.humandelta.ai](https://dev.humandelta.ai/).
///
/// **Modes** (`HumanDeltaIntegrationMode` in Secrets):
/// - `knowledgeSearch` — POST `{ "query": "..." [, "knowledge_base_id": "..." ] }`, Bearer token (default path `v1/search`).
/// - `customJSON` — POST structured `RestPayload` to your chosen path.
enum HumanDeltaAPIService {

    enum ServiceError: Error {
        case notConfigured
        case badStatus(Int)
        case emptyBody
    }

    struct RestPayload: Encodable {
        let schemaVersion: Int
        let userDeltaBias: Int
        let predictedHealthScore: Int
        let personalizedHealthScore: Int
        let sleepBedtime: String
        let sleepWakeTime: String
        let sleepHoursEstimate: Double
        let scheduleBlocks: [Block]

        struct Block: Encodable {
            let day: String
            let start: String
            let end: String
            let label: String
        }

        static func build(
            schedule: [ScheduleBlock],
            sleep: SleepLog,
            caffeine: [CaffeineEntry],
            profile: HealthProfile,
            feedbackHistory: [UserScoreFeedback],
            mlPredictedScore: Int?
        ) -> RestPayload {
            let state = DashboardCalculator.buildState(
                sleep: sleep,
                caffeine: caffeine,
                schedule: schedule,
                profile: profile,
                feedbackHistory: feedbackHistory,
                mlPredictedScore: mlPredictedScore
            )
            return RestPayload(
                schemaVersion: 1,
                userDeltaBias: state.userDeltaBias,
                predictedHealthScore: state.predictedHealthScore,
                personalizedHealthScore: state.personalizedHealthScore,
                sleepBedtime: sleep.bedtime,
                sleepWakeTime: sleep.wakeTime,
                sleepHoursEstimate: HumanDeltaScheduleAdvisor.estimatedSleepHours(sleep: sleep),
                scheduleBlocks: schedule.map {
                    Block(day: $0.day, start: $0.start, end: $0.end, label: $0.label)
                }
            )
        }
    }

    private struct KnowledgeSearchRequest: Encodable {
        let query: String
        let knowledgeBaseId: String?

        enum CodingKeys: String, CodingKey {
            case query
            case knowledgeBaseId = "knowledge_base_id"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(query, forKey: .query)
            try c.encodeIfPresent(knowledgeBaseId, forKey: .knowledgeBaseId)
        }
    }

    private struct FlexibleResponse: Decodable {
        let recommendations: [String]?
        let hints: [String]?
        let data: [String]?
        let answer: String?
        let response: String?
        let message: String?
        let text: String?
    }

    static func fetchRestHints(payload: RestPayload) async throws -> [String] {
        switch HumanDeltaSecrets.integrationMode {
        case .knowledgeSearch:
            return try await fetchKnowledgeSearch(payload: payload)
        case .customJSON:
            return try await fetchCustomJSON(payload: payload)
        }
    }

    private static func fetchKnowledgeSearch(payload: RestPayload) async throws -> [String] {
        guard HumanDeltaSecrets.isConfiguredForRemote,
              let key = HumanDeltaSecrets.apiKey,
              let base = HumanDeltaSecrets.baseURL else {
            throw ServiceError.notConfigured
        }
        let path = HumanDeltaSecrets.restHintsPath
        let url = base.appendingPathComponent(path)

        let prompt = knowledgeSearchPrompt(from: payload)
        let body = KnowledgeSearchRequest(query: prompt, knowledgeBaseId: HumanDeltaSecrets.knowledgeBaseId)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.badStatus(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw ServiceError.badStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw ServiceError.emptyBody
        }

        return decodeHintLines(from: data)
    }

    private static func fetchCustomJSON(payload: RestPayload) async throws -> [String] {
        guard HumanDeltaSecrets.isConfiguredForRemote,
              let key = HumanDeltaSecrets.apiKey,
              let base = HumanDeltaSecrets.baseURL else {
            throw ServiceError.notConfigured
        }
        let path = HumanDeltaSecrets.restHintsPath
        let url = base.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.badStatus(-1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw ServiceError.badStatus(http.statusCode)
        }
        guard !data.isEmpty else {
            throw ServiceError.emptyBody
        }

        let lines = decodeHintLines(from: data)
        return lines
    }

    private static func knowledgeSearchPrompt(from payload: RestPayload) -> String {
        let blocksDescription = payload.scheduleBlocks.map {
            "\($0.day) \($0.start)-\($0.end): \($0.label)"
        }.joined(separator: "; ")

        return """
You help a student manage energy and rest. Reply with 3–6 short plain-text lines only (no markdown). One practical idea per line.

Human Delta bias (recent self-report minus predicted, range about −15…+15): \(payload.userDeltaBias).
Predicted score \(payload.predictedHealthScore); personalized \(payload.personalizedHealthScore).
Estimated sleep \(String(format: "%.1f", payload.sleepHoursEstimate)) h; bedtime \(payload.sleepBedtime); wake \(payload.sleepWakeTime).
Schedule blocks: \(blocksDescription.isEmpty ? "(none)" : blocksDescription).

Suggest rest windows, screen breaks, and protecting sleep given this Human Delta and schedule.
"""
    }

    private static func decodeHintLines(from data: Data) -> [String] {
        if let strings = try? JSONDecoder().decode([String].self, from: data), !strings.isEmpty {
            return strings
        }
        guard let decoded = try? JSONDecoder().decode(FlexibleResponse.self, from: data) else {
            return []
        }
        if let r = decoded.recommendations, !r.isEmpty { return r }
        if let h = decoded.hints, !h.isEmpty { return h }
        if let d = decoded.data, !d.isEmpty { return d }
        if let a = decoded.answer { let l = splitAnswerLines(a); if !l.isEmpty { return l } }
        if let r = decoded.response { let l = splitAnswerLines(r); if !l.isEmpty { return l } }
        if let m = decoded.message { let l = splitAnswerLines(m); if !l.isEmpty { return l } }
        if let t = decoded.text { let l = splitAnswerLines(t); if !l.isEmpty { return l } }
        return []
    }

    private static func splitAnswerLines(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { stripLeadingBullet($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private static func stripLeadingBullet(_ line: String) -> String {
        var t = line
        for p in ["- ", "• ", "* ", "· ", "— "] where t.hasPrefix(p) {
            t = String(t.dropFirst(p.count))
            break
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}
