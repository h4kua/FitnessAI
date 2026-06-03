#if canImport(CoreVideo)
import CoreVideo
#endif

public protocol ExerciseAnalysisProviding: Sendable {
    func analyze(sample: BodyPoseSample) async throws -> ExerciseAnalysis

#if canImport(CoreVideo)
    func analyze(
        pixelBuffer: CVPixelBuffer,
        capturedAt: Date,
        isFrontCamera: Bool
    ) async throws -> ExerciseAnalysis
#endif
}

#if canImport(CoreVideo)
public extension ExerciseAnalysisProviding {
    /// Convenience overload with sensible defaults.
    func analyze(
        pixelBuffer: CVPixelBuffer,
        capturedAt: Date = Date(),
        isFrontCamera: Bool = true
    ) async throws -> ExerciseAnalysis {
        throw AppError.unavailable("Live camera analysis is unavailable in the current configuration.")
    }
}
#endif
