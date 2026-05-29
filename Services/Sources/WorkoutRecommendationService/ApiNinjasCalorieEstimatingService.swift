#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
import Foundation

public struct ApiNinjasCalorieEstimatingService: CalorieEstimating {
    private static let baseURL = "https://api.api-ninjas.com/v1/caloriesburned"

    private let apiKey: String
    private let httpClient: any HTTPClient
    private let requestTimeout: TimeInterval

    public init(apiKey: String, httpClient: any HTTPClient, requestTimeout: TimeInterval = 30) {
        self.apiKey = apiKey
        self.httpClient = httpClient
        self.requestTimeout = requestTimeout
    }

    public func estimate(activityName: String, durationMinutes: Int, weightPounds: Double?) async throws -> CalorieEstimate {
        var components = URLComponents(string: Self.baseURL)!
        var queryItems = [
            URLQueryItem(name: "activity", value: activityName),
            URLQueryItem(name: "duration", value: "\(durationMinutes)")
        ]
        if let weight = weightPounds {
            queryItems.append(URLQueryItem(name: "weight", value: "\(Int(weight))"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NetworkError.invalidRequest("Could not construct calorie estimate URL")
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

        let raw = try JSONDecoder().decode([ApiNinjasCalorieResult].self, from: response.body)
        guard let first = raw.first else {
            return CalorieEstimate(
                activityName: activityName,
                estimatedCalories: Double(durationMinutes) * 5,
                durationMinutes: durationMinutes
            )
        }

        return CalorieEstimate(
            activityName: first.name,
            estimatedCalories: first.totalCalories,
            durationMinutes: durationMinutes
        )
    }
}

private struct ApiNinjasCalorieResult: Decodable {
    let name: String
    let calories_per_hour: Double
    let duration_minutes: Double
    let total_calories: Double

    var totalCalories: Double { total_calories }
}
