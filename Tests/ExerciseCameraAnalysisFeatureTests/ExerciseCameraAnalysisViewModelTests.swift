import Core
import ExerciseCameraAnalysisFeature
import TestSupport
import XCTest

@MainActor
final class ExerciseCameraAnalysisViewModelTests: XCTestCase {
    func testPreviewAnalysisSuccessPublishesAssessment() async {
        let expectedAnalysis = ExerciseAnalysis(
            classification: "Squat",
            coachingCue: "Keep your chest tall.",
            postureConfidence: 0.84,
            status: .excellent
        )
        let provider = MockExerciseAnalysisProvider(behavior: .succeed(expectedAnalysis))
        let viewModel = ExerciseCameraAnalysisViewModel(exerciseAnalysisProvider: provider)

        await viewModel.runPreviewAnalysis()

        XCTAssertEqual(viewModel.latestAnalysis, expectedAnalysis)
        XCTAssertEqual(viewModel.loadState, .loaded)
    }

    func testPreviewAnalysisFailureSurfacesToLoadState() async {
        let provider = MockExerciseAnalysisProvider(behavior: .fail(MockServiceError.forcedFailure))
        let viewModel = ExerciseCameraAnalysisViewModel(exerciseAnalysisProvider: provider)

        await viewModel.runPreviewAnalysis()

        switch viewModel.loadState {
        case .failed(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("Expected analysis failure to transition into a failed state.")
        }
        XCTAssertNil(viewModel.latestAnalysis)
    }

    func testConcurrentPreviewAnalysisRequestsAreCoalesced() async {
        let expectedAnalysis = ExerciseAnalysis(
            classification: "Lunge",
            coachingCue: "Stabilize your front knee.",
            postureConfidence: 0.71,
            status: .acceptable
        )
        let provider = MockExerciseAnalysisProvider(
            behavior: .succeed(expectedAnalysis),
            delayNanoseconds: 200_000_000
        )
        let viewModel = ExerciseCameraAnalysisViewModel(exerciseAnalysisProvider: provider)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.runPreviewAnalysis() }
            group.addTask { await viewModel.runPreviewAnalysis() }
            await group.waitForAll()
        }

        let analyzeCallCount = await provider.analyzeCallCount
        XCTAssertEqual(analyzeCallCount, 1)
        XCTAssertEqual(viewModel.latestAnalysis, expectedAnalysis)
        XCTAssertEqual(viewModel.loadState, .loaded)
    }
}
