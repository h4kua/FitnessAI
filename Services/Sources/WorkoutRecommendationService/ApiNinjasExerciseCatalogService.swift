#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
import Foundation

public struct ApiNinjasExerciseCatalogService: ExerciseCatalogProviding {
    private static let baseURL = "https://api.api-ninjas.com/v1/exercises"

    private let apiKey: String
    private let httpClient: any HTTPClient
    private let requestTimeout: TimeInterval

    public init(apiKey: String, httpClient: any HTTPClient, requestTimeout: TimeInterval = 30) {
        self.apiKey = apiKey
        self.httpClient = httpClient
        self.requestTimeout = requestTimeout
    }

    public func exercises(matching query: ExerciseSearchQuery) async throws -> [ExerciseTemplate] {
        var components = URLComponents(string: Self.baseURL)!
        var queryItems: [URLQueryItem] = []

        if let type = query.type {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if let muscle = query.muscle {
            queryItems.append(URLQueryItem(name: "muscle", value: muscle))
        }
        if let difficulty = query.difficulty {
            queryItems.append(URLQueryItem(name: "difficulty", value: apiNinjasDifficulty(difficulty)))
        }
        if query.offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: "\(query.offset)"))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw NetworkError.invalidRequest("Could not construct exercise catalog URL")
        }

        let request = APIRequest(
            url: url,
            method: .get,
            headers: ["X-Api-Key": apiKey],
            timeoutInterval: requestTimeout
        )
        let response = try await httpClient.send(request)

        guard response.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: response.statusCode, message: nil)
        }

        let raw = try JSONDecoder().decode([ApiNinjasExercise].self, from: response.body)
        return raw.map(\.asExerciseTemplate)
    }

    private func apiNinjasDifficulty(_ intensity: WorkoutIntensity) -> String {
        switch intensity {
        case .low: return "beginner"
        case .moderate: return "intermediate"
        case .high: return "expert"
        }
    }
}

// MARK: - API Ninjas response shape

private struct ApiNinjasExercise: Decodable {
    let name: String
    let type: String
    let muscle: String
    let equipment: String
    let difficulty: String
    let instructions: String

    var asExerciseTemplate: ExerciseTemplate {
        ExerciseTemplate(
            id: "ninjas-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: name,
            type: ExerciseType(rawValue: type.lowercased().replacingOccurrences(of: " ", with: "_")) ?? .strength,
            difficulty: mappedDifficulty,
            primaryMuscle: muscle.isEmpty ? nil : muscle,
            equipment: equipment.isEmpty ? [] : [equipment],
            instructions: instructions,
            safetyInfo: nil,
            sourceProvider: "API Ninjas"
        )
    }

    private var mappedDifficulty: WorkoutIntensity {
        switch difficulty.lowercased() {
        case "beginner": return .low
        case "intermediate": return .moderate
        default: return .high
        }
    }
}
