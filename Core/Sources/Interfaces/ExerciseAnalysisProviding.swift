#if canImport(CoreVideo)
import CoreVideo
#endif

public protocol ExerciseAnalysisProviding: Sendable {
    func analyze(sample: BodyPoseSample) async throws -> ExerciseAnalysis

#if canImport(CoreVideo)
    func analyze(
        pixelBuffer: CVPixelBuffer,
        capturedAt: Date
    ) async throws -> ExerciseAnalysis
#endif
}

#if canImport(CoreVideo)
public extension ExerciseAnalysisProviding {
    func analyze(
        pixelBuffer: CVPixelBuffer,
        capturedAt: Date = Date()
    ) async throws -> ExerciseAnalysis {
        throw AppError.unavailable("Live camera analysis is unavailable in the current configuration.")
    }
}
#endif
