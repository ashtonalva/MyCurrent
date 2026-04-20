import Foundation

/// Loads `Secrets.plist` from the app bundle (gitignored — copy from `Secrets.example.plist`).
/// Never commit real keys. Optional env override for local runs: `HUMAN_DELTA_API_KEY`, `HUMAN_DELTA_BASE_URL`.
///
/// Official Human Delta API host: see [api.humandelta.ai](https://api.humandelta.ai/).
/// Developer keys / dashboard: [dev.humandelta.ai](https://dev.humandelta.ai/) (invite-based).
enum HumanDeltaSecrets {

    enum IntegrationMode: String {
        /// POST a natural-language query (Knowledge Base search). Default for Human Delta.
        case knowledgeSearch
        /// POST structured `RestPayload` JSON to your path (custom integrations).
        case customJSON
    }

    private static let plistDictionary: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    }()

    static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["HUMAN_DELTA_API_KEY"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let raw = plistDictionary?["HumanDeltaAPIKey"] as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static var baseURL: URL? {
        if let env = ProcessInfo.processInfo.environment["HUMAN_DELTA_BASE_URL"],
           let url = URL(string: env.trimmingCharacters(in: .whitespacesAndNewlines)),
           !env.isEmpty {
            return url
        }
        guard let raw = plistDictionary?["HumanDeltaBaseURL"] as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let url = URL(string: t) else { return nil }
        return url
    }

    /// Appended to `HumanDeltaBaseURL` (no leading slash required).
    static var restHintsPath: String {
        if let env = ProcessInfo.processInfo.environment["HUMAN_DELTA_REST_PATH"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let raw = (plistDictionary?["HumanDeltaRestHintsPath"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = raw, !raw.isEmpty {
            return raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let fallback = integrationMode == .knowledgeSearch ? "v1/search" : "v1/rest-hints"
        return fallback
    }

    /// Optional KB / index identifier when search requires it (see Human Delta developer console).
    static var knowledgeBaseId: String? {
        if let env = ProcessInfo.processInfo.environment["HUMAN_DELTA_KNOWLEDGE_BASE_ID"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let raw = plistDictionary?["HumanDeltaKnowledgeBaseId"] as? String else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static var integrationMode: IntegrationMode {
        let raw = ProcessInfo.processInfo.environment["HUMAN_DELTA_INTEGRATION_MODE"]
            ?? plistDictionary?["HumanDeltaIntegrationMode"] as? String
        switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "customjson", "custom_json", "endpoint", "direct":
            return .customJSON
        default:
            return .knowledgeSearch
        }
    }

    static var isConfiguredForRemote: Bool {
        apiKey != nil && baseURL != nil
    }
}
