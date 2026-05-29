#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
import Foundation

/// Sends joint angles (NOT images or health data) to the Groq API to generate
/// a single coaching cue. Rate-limited to once per 3 seconds.
public actor GroqCoachingService {
    private static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private static let model = "llama-3.3-70b-versatile"
    private static let cooldown: TimeInterval = 3.0

    private let apiKey: String
    private let httpClient: any HTTPClient
    private let logger: AppLogger
    private var lastCallAt: Date?

    public init(apiKey: String, httpClient: any HTTPClient, logger: AppLogger) {
        self.apiKey = apiKey
        self.httpClient = httpClient
        self.logger = logger
    }

    /// Generate a coaching cue. Returns nil if rate-limited or API unavailable.
    public func coachingCue(
        for exercise: DetectedExercise,
        angles: [String: Double],
        confidence: Double
    ) async -> String? {
        guard isReadyForNextCall() else { return nil }
        lastCallAt = Date()

        let anglesText = angles
            .sorted { $0.key < $1.key }
            .map { "\($0.key.replacingOccurrences(of: "_", with: " ")): \(Int($0.value))°" }
            .joined(separator: ", ")

        let userMessage = """
        Exercise detected: \(exercise.rawValue) (confidence \(Int(confidence * 100))%)
        Key joint angles: \(anglesText.isEmpty ? "not available" : anglesText)
        Focus: \(exercise.coachingPromptHint)
        """

        let body = GroqRequest(
            model: Self.model,
            messages: [
                .system("You are a professional fitness coach. Given the detected exercise and joint angles from a body pose sensor, give ONE concise coaching cue in 12 words or fewer. Be specific, encouraging, and actionable. Never mention AI or sensors."),
                .user(userMessage)
            ],
            maxTokens: 60,
            temperature: 0.6
        )

        do {
            let data = try JSONEncoder().encode(body)
            let request = APIRequest(
                url: Self.endpoint,
                method: .post,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ],
                body: data,
                timeoutInterval: 8
            )
            let response = try await httpClient.send(request)
            guard response.statusCode == 200 else {
                logger.warning("Groq API returned \(response.statusCode)")
                return nil
            }
            let parsed = try JSONDecoder().decode(GroqResponse.self, from: response.body)
            let cue = parsed.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Groq coaching cue for \(exercise.rawValue): \(cue ?? "nil")")
            return cue
        } catch {
            logger.warning("Groq API error: \(error.localizedDescription)")
            return nil
        }
    }

    private func isReadyForNextCall() -> Bool {
        guard let last = lastCallAt else { return true }
        return Date().timeIntervalSince(last) >= Self.cooldown
    }

    /// Multi-turn AI coach chat. `history` is ordered oldest-first (role = "user" | "assistant").
    /// `userContext` is injected into the system prompt (name, goals, etc.).
    /// Returns the assistant reply, or nil on network/API failure.
    public func chat(
        history: [(role: String, content: String)],
        userContext: String
    ) async -> String? {
        let systemPrompt = """
        You are an expert personal fitness coach. \
        You help users with personalised workout plans, exercise technique, \
        nutrition guidance, recovery strategies, and motivation. \
        Be concise, specific, encouraging, and evidence-based. \
        Never make medical diagnoses or replace professional medical advice. \
        Respond in the same language the user writes in. \
        User context: \(userContext)
        """

        var groqMessages: [GroqMessage] = [.system(systemPrompt)]
        for entry in history {
            groqMessages.append(GroqMessage(role: entry.role, content: entry.content))
        }

        let body = GroqRequest(
            model: Self.model,
            messages: groqMessages,
            maxTokens: 500,
            temperature: 0.7
        )

        do {
            let data = try JSONEncoder().encode(body)
            let request = APIRequest(
                url: Self.endpoint,
                method: .post,
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ],
                body: data,
                timeoutInterval: 30
            )
            let response = try await httpClient.send(request)
            guard response.statusCode == 200 else {
                logger.warning("Groq chat API returned \(response.statusCode)")
                return nil
            }
            let parsed = try JSONDecoder().decode(GroqResponse.self, from: response.body)
            let reply = parsed.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Groq coach chat reply: \(reply?.count ?? 0) chars")
            return reply
        } catch {
            logger.warning("Groq chat error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Request / Response models

private struct GroqRequest: Encodable {
    let model: String
    let messages: [GroqMessage]
    let max_tokens: Int
    let temperature: Double

    init(model: String, messages: [GroqMessage], maxTokens: Int, temperature: Double) {
        self.model = model
        self.messages = messages
        self.max_tokens = maxTokens
        self.temperature = temperature
    }
}

private struct GroqMessage: Encodable {
    let role: String
    let content: String

    static func system(_ content: String) -> GroqMessage { .init(role: "system", content: content) }
    static func user(_ content: String) -> GroqMessage { .init(role: "user", content: content) }
}

private struct GroqResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
