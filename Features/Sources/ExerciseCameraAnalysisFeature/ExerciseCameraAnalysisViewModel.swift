import Combine
#if canImport(CoreVideo)
import CoreVideo
#endif
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class ExerciseCameraAnalysisViewModel: ObservableObject {
    @Published public private(set) var latestAnalysis: ExerciseAnalysis?
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var cameraMessage = "Start the camera to analyze posture in real time."
    @Published public private(set) var repCount: Int = 0
    @Published public private(set) var currentExercise: DetectedExercise = .unknown
    @Published public var selectedExercise: DetectedExercise = .squat
    @Published public private(set) var dailyReps: [DetectedExercise: Int] = [:]
    @Published public private(set) var isSavingSession = false
    @Published public private(set) var sessionSavedMessage: String? = nil
    /// Elapsed seconds since the camera/session was started.
    @Published public private(set) var sessionElapsedSeconds: Int = 0

    // Derived shortcuts used by the view
    public var currentPhase: MovementPhase? { latestAnalysis?.movementPhase }
    public var currentFormFeedback: ExerciseFormFeedback? { latestAnalysis?.formFeedback }
    public var canSaveSession: Bool { !dailyReps.isEmpty && !isSavingSession }

    /// MM:SS display string — updates every second while a session is active.
    public var sessionTimerDisplay: String {
        let m = sessionElapsedSeconds / 60
        let s = sessionElapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private let exerciseAnalysisProvider: any ExerciseAnalysisProviding
    private let workoutSessionStore: (any WorkoutSessionStoring)?
    private var repTracker = RepTracker()
    private var sessionStartedAt: Date? = nil
    private var timerCancellable: AnyCancellable?

    public init(
        exerciseAnalysisProvider: any ExerciseAnalysisProviding,
        workoutSessionStore: (any WorkoutSessionStoring)? = nil
    ) {
        self.exerciseAnalysisProvider = exerciseAnalysisProvider
        self.workoutSessionStore = workoutSessionStore
        // Reset daily reps if the date has rolled over since last launch
        resetDailyRepsIfNeeded()
    }

    public func selectExercise(_ exercise: DetectedExercise) {
        selectedExercise = exercise
        repCount = 0
        repTracker = RepTracker()
    }

    public func resetRepCount() {
        repCount = 0
        repTracker = RepTracker()
    }

    public func runPreviewAnalysis() async {
        guard loadState != .loading else { return }
        loadState = .loading
        resetDailyRepsIfNeeded()
        markSessionStart()

        do {
            let sample = previewPoseSample(for: selectedExercise)
            let analysis = try await exerciseAnalysisProvider.analyze(sample: sample)
            applyAnalysis(analysis)
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Save session to Firestore

    public func saveSession() async {
        guard canSaveSession, let store = workoutSessionStore else { return }
        isSavingSession = true
        defer { isSavingSession = false }

        let totalReps = dailyReps.values.reduce(0, +)
        let primaryExercise = dailyReps.max(by: { $0.value < $1.value })?.key ?? selectedExercise
        let durationMinutes = sessionDurationMinutes()

        // Rough calorie estimate: ~0.32 kcal per rep × exercise MET factor
        let estimatedCalories = Double(totalReps) * 0.32 * Double(primaryExercise.metFactor)

        let summary = WorkoutSessionSummary(
            date: sessionStartedAt ?? Date(),
            title: "\(primaryExercise.rawValue) Session — \(totalReps) reps",
            estimatedCalories: estimatedCalories,
            durationMinutes: max(1, durationMinutes)
        )

        do {
            try await store.save(summary)
            sessionSavedMessage = "Workout saved! \(totalReps) reps in \(max(1, durationMinutes)) min."
            dailyReps = [:]
            repCount = 0
            repTracker = RepTracker()
            sessionStartedAt = nil
            stopSessionTimer()
            sessionElapsedSeconds = 0
        } catch {
            sessionSavedMessage = "Couldn't save: \(error.localizedDescription)"
        }

        // Auto-dismiss toast after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            sessionSavedMessage = nil
        }
    }

#if canImport(CoreVideo)
    public func beginLiveAnalysis() {
        if loadState == .idle {
            loadState = .loading
        }
        resetDailyRepsIfNeeded()
        markSessionStart()
        cameraMessage = "Point your full body toward the camera so posture feedback can update live."
    }

    public func handleCameraAccessDenied() {
        loadState = .failed("Camera access was denied. Enable Camera for FitnessCoach in Settings > Privacy & Security.")
    }

    public func handleCameraUnavailable(_ message: String) {
        loadState = .failed(message)
    }

    public func analyze(pixelBuffer: CVPixelBuffer, isFrontCamera: Bool = true) async {
        do {
            let analysis = try await exerciseAnalysisProvider.analyze(
                pixelBuffer: pixelBuffer,
                capturedAt: Date(),
                isFrontCamera: isFrontCamera
            )
            applyAnalysis(analysis)
            loadState = .loaded
            cameraMessage = analysis.coachingCue
        } catch let error as AppError {
            switch error {
            case .rateLimited:
                break   // silently drop throttled frames
            default:
                loadState = .failed(error.localizedDescription)
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
#endif

    // MARK: - Private

    private func applyAnalysis(_ analysis: ExerciseAnalysis) {
        let previousExercise = currentExercise
        currentExercise = analysis.detectedExercise

        if previousExercise != analysis.detectedExercise && analysis.detectedExercise != .unknown {
            repTracker = RepTracker()
        }

        let previousCount = repTracker.count
        repTracker.update(exercise: analysis.detectedExercise, angles: analysis.jointAngles)
        let newCount = repTracker.count

        if newCount > previousCount,
           analysis.detectedExercise == selectedExercise,
           analysis.detectedExercise != .unknown,
           analysis.detectedExercise != .standing {
            let added = newCount - previousCount
            dailyReps[selectedExercise] = (dailyReps[selectedExercise] ?? 0) + added
        }

        repCount = newCount
        latestAnalysis = analysis
    }

    private func markSessionStart() {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = Date()
        startSessionTimer()
    }

    private func startSessionTimer() {
        guard timerCancellable == nil else { return }
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.sessionStartedAt else { return }
                self.sessionElapsedSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    private func stopSessionTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func sessionDurationMinutes() -> Int {
        guard let start = sessionStartedAt else { return 1 }
        return max(1, Int(Date().timeIntervalSince(start) / 60))
    }

    // MARK: - Daily rep reset at midnight

    private static let dateKey = "camera.lastActiveDate"
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private func resetDailyRepsIfNeeded() {
        let todayStr = Self.dayFormatter.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: Self.dateKey) ?? ""
        if stored != todayStr {
            dailyReps = [:]
            repCount = 0
            repTracker = RepTracker()
            UserDefaults.standard.set(todayStr, forKey: Self.dateKey)
        }
    }

    // MARK: - Preview pose samples

    private func previewPoseSample(for exercise: DetectedExercise) -> BodyPoseSample {
        switch exercise {
        case .squat:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_shoulder":  PosePoint(x: 0.43, y: 0.70),
                    "right_shoulder": PosePoint(x: 0.57, y: 0.70),
                    "left_hip":       PosePoint(x: 0.44, y: 0.48),
                    "right_hip":      PosePoint(x: 0.56, y: 0.48),
                    "left_knee":      PosePoint(x: 0.38, y: 0.32),
                    "right_knee":     PosePoint(x: 0.62, y: 0.32),
                    "left_ankle":     PosePoint(x: 0.42, y: 0.12),
                    "right_ankle":    PosePoint(x: 0.58, y: 0.12)
                ]
            )
        case .pushUp:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_shoulder":  PosePoint(x: 0.44, y: 0.45),
                    "right_shoulder": PosePoint(x: 0.56, y: 0.45),
                    "left_hip":       PosePoint(x: 0.45, y: 0.42),
                    "right_hip":      PosePoint(x: 0.55, y: 0.42),
                    "left_elbow":     PosePoint(x: 0.34, y: 0.40),
                    "right_elbow":    PosePoint(x: 0.66, y: 0.40),
                    "left_wrist":     PosePoint(x: 0.38, y: 0.30),
                    "right_wrist":    PosePoint(x: 0.62, y: 0.30),
                    "left_knee":      PosePoint(x: 0.44, y: 0.28),
                    "right_knee":     PosePoint(x: 0.56, y: 0.28),
                    "left_ankle":     PosePoint(x: 0.43, y: 0.12),
                    "right_ankle":    PosePoint(x: 0.57, y: 0.12)
                ]
            )
        case .pullUp:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_wrist":     PosePoint(x: 0.35, y: 0.92),
                    "right_wrist":    PosePoint(x: 0.65, y: 0.92),
                    "left_elbow":     PosePoint(x: 0.28, y: 0.65),
                    "right_elbow":    PosePoint(x: 0.72, y: 0.65),
                    "left_shoulder":  PosePoint(x: 0.42, y: 0.62),
                    "right_shoulder": PosePoint(x: 0.58, y: 0.62),
                    "left_hip":       PosePoint(x: 0.44, y: 0.45),
                    "right_hip":      PosePoint(x: 0.56, y: 0.45),
                    "left_knee":      PosePoint(x: 0.43, y: 0.28),
                    "right_knee":     PosePoint(x: 0.57, y: 0.28),
                    "left_ankle":     PosePoint(x: 0.42, y: 0.12),
                    "right_ankle":    PosePoint(x: 0.58, y: 0.12)
                ]
            )
        case .jumpingJack:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_wrist":     PosePoint(x: 0.22, y: 0.82),
                    "right_wrist":    PosePoint(x: 0.78, y: 0.82),
                    "left_shoulder":  PosePoint(x: 0.42, y: 0.72),
                    "right_shoulder": PosePoint(x: 0.58, y: 0.72),
                    "left_hip":       PosePoint(x: 0.44, y: 0.50),
                    "right_hip":      PosePoint(x: 0.56, y: 0.50),
                    "left_knee":      PosePoint(x: 0.38, y: 0.30),
                    "right_knee":     PosePoint(x: 0.62, y: 0.30),
                    "left_ankle":     PosePoint(x: 0.26, y: 0.12),
                    "right_ankle":    PosePoint(x: 0.74, y: 0.12)
                ]
            )
        case .sitUp:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_shoulder":  PosePoint(x: 0.43, y: 0.30),
                    "right_shoulder": PosePoint(x: 0.57, y: 0.30),
                    "left_hip":       PosePoint(x: 0.44, y: 0.25),
                    "right_hip":      PosePoint(x: 0.56, y: 0.25),
                    "left_knee":      PosePoint(x: 0.42, y: 0.38),
                    "right_knee":     PosePoint(x: 0.58, y: 0.38),
                    "left_ankle":     PosePoint(x: 0.40, y: 0.20),
                    "right_ankle":    PosePoint(x: 0.60, y: 0.20)
                ]
            )
        case .standing, .unknown:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_shoulder":  PosePoint(x: 0.42, y: 0.72),
                    "right_shoulder": PosePoint(x: 0.58, y: 0.72),
                    "left_hip":       PosePoint(x: 0.44, y: 0.50),
                    "right_hip":      PosePoint(x: 0.56, y: 0.50),
                    "left_knee":      PosePoint(x: 0.43, y: 0.30),
                    "right_knee":     PosePoint(x: 0.57, y: 0.30),
                    "left_ankle":     PosePoint(x: 0.42, y: 0.12),
                    "right_ankle":    PosePoint(x: 0.58, y: 0.12)
                ]
            )
        }
    }

    private func standardConfidences() -> [String: Double] {
        [
            "left_shoulder": 0.91, "right_shoulder": 0.88,
            "left_elbow":    0.85, "right_elbow":    0.83,
            "left_wrist":    0.82, "right_wrist":    0.80,
            "left_hip":      0.83, "right_hip":      0.81,
            "left_knee":     0.79, "right_knee":     0.77,
            "left_ankle":    0.75, "right_ankle":    0.73
        ]
    }
}

// MARK: - Rep counter state machine

private struct RepTracker {
    private enum Phase { case top, bottom }

    var count: Int = 0
    private var phase: Phase = .top

    mutating func update(exercise: DetectedExercise, angles: [String: Double]) {
        switch exercise {
        case .squat:
            countReps(primaryAngle: averageKnee(angles), bottomThreshold: 100, topThreshold: 155)
        case .pushUp:
            countReps(primaryAngle: averageElbow(angles), bottomThreshold: 90, topThreshold: 155)
        case .pullUp:
            countReps(primaryAngle: averageElbow(angles), bottomThreshold: 100, topThreshold: 150)
        case .sitUp:
            countReps(primaryAngle: averageHip(angles), bottomThreshold: 90, topThreshold: 150)
        default:
            break
        }
    }

    private mutating func countReps(
        primaryAngle: Double?,
        bottomThreshold: Double,
        topThreshold: Double
    ) {
        guard let angle = primaryAngle else { return }
        switch phase {
        case .top where angle < bottomThreshold:
            phase = .bottom
        case .bottom where angle > topThreshold:
            phase = .top
            count += 1
        default:
            break
        }
    }

    private func averageKnee(_ angles: [String: Double]) -> Double? {
        let values = [angles["left_knee"], angles["right_knee"]].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageElbow(_ angles: [String: Double]) -> Double? {
        let values = [angles["left_elbow"], angles["right_elbow"]].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageHip(_ angles: [String: Double]) -> Double? {
        let values = [angles["left_hip"], angles["right_hip"]].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
