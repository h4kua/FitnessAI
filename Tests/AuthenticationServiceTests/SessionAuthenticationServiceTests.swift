import AuthenticationService
import Core
import Infrastructure
import TestSupport
import XCTest

final class SessionAuthenticationServiceTests: XCTestCase {
    func testBlankDisplayNameFallsBackToAthlete() async throws {
        let service = SessionAuthenticationService(logger: AppLogger(category: "Tests"))

        let state = try await service.signIn(displayName: "   ")

        switch state {
        case .signedIn(let user):
            XCTAssertEqual(user.displayName, "Athlete")
        case .signedOut:
            XCTFail("Expected a signed-in user.")
        }
    }

    func testSignOutResetsAuthenticationState() async throws {
        let service = SessionAuthenticationService(logger: AppLogger(category: "Tests"))
        _ = try await service.signIn(displayName: "Casey")

        await service.signOut()
        let state = await service.currentState()

        XCTAssertEqual(state, .signedOut)
    }

    func testRemoteAuthenticationStoresSessionAndReturnsSignedInUser() async throws {
        let userID = UUID()
        let responseBody = """
        {
          "access_token": "access-token",
          "refresh_token": "refresh-token",
          "expires_at": "2030-01-01T00:00:00Z",
          "user": {
            "id": "\(userID.uuidString)",
            "display_name": "Avery",
            "analytics_consent": true,
            "daily_calorie_goal": 640
          }
        }
        """.data(using: .utf8)!
        let client = MockHTTPClient(
            queuedResponses: [
                .success(
                    HTTPResponse(
                        body: responseBody,
                        headers: [:],
                        statusCode: 200
                    )
                )
            ]
        )
        let sessionStore = MockSessionStore()
        let service = RemoteAuthenticationService(
            client: client,
            configuration: APIConfiguration(
                analyticsBaseURL: nil,
                apiBaseURL: URL(string: "https://api.example.com")!,
                requestTimeout: 30,
                supportsGraphQL: false
            ),
            sessionStore: sessionStore,
            logger: AppLogger(category: "Tests")
        )

        let state = try await service.signIn(displayName: "Avery")

        switch state {
        case .signedIn(let user):
            XCTAssertEqual(user.id, userID)
            XCTAssertEqual(user.displayName, "Avery")
            XCTAssertEqual(user.dailyCalorieGoal.activeEnergyGoal, 640)
        case .signedOut:
            XCTFail("Expected remote authentication to sign the user in.")
        }

        let savedSessions = await sessionStore.savedSessions
        XCTAssertEqual(savedSessions.count, 1)
        XCTAssertEqual(savedSessions.first?.accessToken, "access-token")
    }
}
