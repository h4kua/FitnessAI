import AuthenticationFeature
import Core
import TestSupport
import XCTest

@MainActor
final class AuthenticationViewModelTests: XCTestCase {
    func testLoadHydratesCurrentStateAndTriggersCallback() async {
        let expectedUser = UserProfile(
            analyticsConsent: true,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 600),
            displayName: "Jordan"
        )
        let provider = MockAuthenticationProvider(
            currentAuthenticationState: .signedIn(expectedUser),
            signInBehavior: .succeed(expectedUser)
        )
        let viewModel = AuthenticationViewModel(authenticationProvider: provider)

        var callbackCount = 0
        viewModel.onStateChange = {
            callbackCount += 1
        }

        await viewModel.load()

        XCTAssertEqual(viewModel.authenticationState, .signedIn(expectedUser))
        XCTAssertEqual(callbackCount, 1)
    }

    func testSignInFailureTransitionsToFailedState() async {
        let provider = MockAuthenticationProvider(
            signInBehavior: .fail(MockServiceError.forcedFailure)
        )
        let viewModel = AuthenticationViewModel(authenticationProvider: provider)

        await viewModel.signIn()

        switch viewModel.loadState {
        case .failed(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("Expected sign-in failure to surface through loadState.")
        }
        XCTAssertEqual(viewModel.authenticationState, .signedOut)
    }

    func testConcurrentSignInRequestsAreCoalesced() async {
        let expectedUser = UserProfile(
            analyticsConsent: true,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 600),
            displayName: "Taylor"
        )
        let provider = MockAuthenticationProvider(
            signInBehavior: .succeed(expectedUser),
            signInDelayNanoseconds: 200_000_000
        )
        let viewModel = AuthenticationViewModel(authenticationProvider: provider)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.signIn() }
            group.addTask { await viewModel.signIn() }
            await group.waitForAll()
        }

        let signInCallCount = await provider.signInCallCount
        XCTAssertEqual(signInCallCount, 1)
        XCTAssertEqual(viewModel.authenticationState, .signedIn(expectedUser))
        XCTAssertEqual(viewModel.loadState, .loaded)
    }
}
