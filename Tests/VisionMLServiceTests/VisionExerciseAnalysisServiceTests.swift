import Core
import Infrastructure
import VisionMLService
import XCTest

final class VisionExerciseAnalysisServiceTests: XCTestCase {
    func testHighConfidenceSampleReturnsExcellentStatus() async throws {
        let service = VisionExerciseAnalysisService(logger: AppLogger(category: "Tests"))

        let analysis = try await service.analyze(
            sample: BodyPoseSample(
                jointConfidences: [
                    "leftShoulder": 0.92,
                    "rightShoulder": 0.88,
                    "leftHip": 0.84,
                    "rightHip": 0.82
                ]
            )
        )

        XCTAssertEqual(analysis.status, .excellent)
        XCTAssertEqual(analysis.classification, "Bodyweight Movement")
    }

    func testMidConfidenceSampleReturnsAcceptableStatus() async throws {
        let service = VisionExerciseAnalysisService(logger: AppLogger(category: "Tests"))

        let analysis = try await service.analyze(
            sample: BodyPoseSample(
                jointConfidences: [
                    "leftShoulder": 0.60,
                    "rightShoulder": 0.58,
                    "leftHip": 0.56,
                    "rightHip": 0.55
                ]
            )
        )

        XCTAssertEqual(analysis.status, .acceptable)
    }

    func testLowConfidenceSampleReturnsNeedsAttentionStatus() async throws {
        let service = VisionExerciseAnalysisService(logger: AppLogger(category: "Tests"))

        let analysis = try await service.analyze(
            sample: BodyPoseSample(
                jointConfidences: [
                    "leftShoulder": 0.22,
                    "rightShoulder": 0.18
                ]
            )
        )

        XCTAssertEqual(analysis.status, .needsAttention)
        XCTAssertNil(analysis.classification)
    }
}
