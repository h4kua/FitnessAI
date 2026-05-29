import Combine
import Foundation
#if canImport(Core)
import Core
#endif
#if canImport(VisionMLService)
import VisionMLService
#endif

// MARK: - Chat message model

public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: String
    public let timestamp: Date

    public enum Role: Sendable { case user, assistant }

    public init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - View model

@MainActor
public final class CoachChatViewModel: ObservableObject {
    @Published public private(set) var messages: [ChatMessage] = []
    @Published public private(set) var isThinking = false
    @Published public var inputText = ""

    private let groqService: GroqCoachingService?
    private let userProfile: UserProfile
    private let calorieGoal: Double

    public init(
        groqService: GroqCoachingService?,
        userProfile: UserProfile,
        calorieGoal: Double
    ) {
        self.groqService = groqService
        self.userProfile = userProfile
        self.calorieGoal = calorieGoal

        // Greet the user immediately
        messages.append(ChatMessage(
            role: .assistant,
            content: "Hi \(userProfile.displayName)! 👋 I'm your AI fitness coach. Ask me about workout plans, exercise technique, nutrition, recovery — anything to help you reach your goals."
        ))
    }

    public func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        isThinking = true
        defer { isThinking = false }

        guard let groq = groqService else {
            messages.append(ChatMessage(
                role: .assistant,
                content: "The Groq API key isn't set up yet. Add **GROQ_API_KEY** to your Xcode scheme's environment variables to enable AI coaching."
            ))
            return
        }

        // Build conversation history including the message just appended
        let history: [(role: String, content: String)] = messages.map { msg in
            switch msg.role {
            case .user:      return (role: "user",      content: msg.content)
            case .assistant: return (role: "assistant", content: msg.content)
            }
        }

        let context = """
        User name: \(userProfile.displayName)
        Daily active-calorie goal: \(Int(calorieGoal)) kcal
        """

        let reply = await groq.chat(history: history, userContext: context)

        messages.append(ChatMessage(
            role: .assistant,
            content: reply ?? "I couldn't reach the server right now. Check your connection and try again."
        ))
    }

    public func clearHistory() {
        // Keep the welcome message, drop the rest
        messages = Array(messages.prefix(1))
        inputText = ""
    }
}
