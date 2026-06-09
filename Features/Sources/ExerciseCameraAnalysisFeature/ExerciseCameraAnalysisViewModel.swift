import Combine
#if canImport(CoreVideo)
import CoreVideo
#endif
#if canImport(Core)
import Core
#endif
#if canImport(AVFoundation)
import AVFoundation
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
    /// Whether real-time voice coaching is enabled. User can toggle in-session.
    @Published public var voiceGuidanceEnabled: Bool = true
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

    // MARK: - Voice coaching
#if canImport(AVFoundation)
    private let speechCoach = SpeechCoach()
#endif
    /// Last text spoken aloud — used to avoid repeating the same message.
    private var lastSpokenText: String = ""
    /// Timestamp of the last speech event — used for cooldown enforcement.
    private var lastSpeechDate: Date = .distantPast
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
        repCount = dailyReps[selectedExercise] ?? 0
    }

    public func selectExercise(_ exercise: DetectedExercise) {
        selectedExercise = exercise
        repCount = dailyReps[exercise] ?? 0
        repTracker = RepTracker()
    }

    public func resetRepCount() {
        dailyReps[selectedExercise] = nil
        persistDailyReps()
        repCount = 0
        repTracker = RepTracker()
    }

    /// Toggle voice coaching on / off. Immediately stops any ongoing speech when disabling.
    public func toggleVoiceGuidance() {
        voiceGuidanceEnabled.toggle()
#if canImport(AVFoundation)
        if !voiceGuidanceEnabled { speechCoach.stop() }
#endif
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

        let estimatedCalories: Double
        if primaryExercise == .plank {
            estimatedCalories = Double(totalReps) / 60.0 * Double(primaryExercise.metFactor) * 1.2
        } else {
            // Rough calorie estimate: ~0.32 kcal per rep × exercise MET factor
            estimatedCalories = Double(totalReps) * 0.32 * Double(primaryExercise.metFactor)
        }
        let unit = primaryExercise == .plank ? "sec" : "reps"

        let summary = WorkoutSessionSummary(
            date: sessionStartedAt ?? Date(),
            title: "\(primaryExercise.rawValue) Session — \(totalReps) \(unit)",
            estimatedCalories: estimatedCalories,
            durationMinutes: max(1, durationMinutes)
        )

        do {
            try await store.save(summary)
            sessionSavedMessage = "Workout saved! \(totalReps) \(unit) in \(max(1, durationMinutes)) min."
            repTracker = RepTracker()
            repCount = dailyReps[selectedExercise] ?? 0
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

    /// Called when the user taps Stop — resets to idle so they can start a fresh session.
    public func resetCameraSession() {
        loadState = .idle
        latestAnalysis = nil
        stopSessionTimer()
        sessionElapsedSeconds = 0
        sessionStartedAt = nil
        cameraMessage = "Start the camera to analyze posture in real time."
#if canImport(AVFoundation)
        speechCoach.stop()
#endif
        lastSpokenText = ""
        lastSpeechDate = .distantPast
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
        currentExercise = analysis.detectedExercise

        // Always count reps against the exercise the user explicitly selected.
        // The pose classifier is used for FORM feedback only — it requires deep
        // angles to be confident, so it lags behind human perception.
        // Using selectedExercise means: if you pick Squat and bend your knees,
        // reps are counted immediately without waiting for the classifier to agree.

        // Augment joint angles with derived metrics needed by RepTracker
        var augmentedAngles = analysis.jointAngles
        if selectedExercise == .jumpingJack,
           let leftAnkle = analysis.poseJointPositions["left_ankle"],
           let rightAnkle = analysis.poseJointPositions["right_ankle"] {
            augmentedAngles["ankle_spread"] = abs(leftAnkle.x - rightAnkle.x)
        }
        if selectedExercise == .plank {
            augmentedAngles["plank_stability"] = plankStabilityScore(from: analysis.poseJointPositions)
        }
        if selectedExercise == .pushUp {
            augmentedAngles["pushup_shoulder_y"] = pushUpShoulderY(from: analysis.poseJointPositions) ?? -1
        }

        let previousCount = repTracker.count
        repTracker.update(exercise: selectedExercise, angles: augmentedAngles, capturedAt: Date())
        let newCount = repTracker.count

        if newCount > previousCount {
            let added = newCount - previousCount
            dailyReps[selectedExercise] = (dailyReps[selectedExercise] ?? 0) + added
            persistDailyReps()

            // ── Voice: announce rep completion ────────────────────────────────
            // Interrupt whatever else might be playing; rep count > form cue.
            let total = dailyReps[selectedExercise] ?? 0
            speakVoice("\(total)", highPriority: true)
        }

        repCount = dailyReps[selectedExercise] ?? 0
        latestAnalysis = analysis

        // ── Voice: speak actionable form cue when it changes ─────────────────
        // Only for genuine errors (tooShallow / torsoLean / kneeIssue).
        // Generic "good form" or "standing" cues are shown on screen only.
        if let feedback = analysis.formFeedback,
           !analysis.coachingCue.isEmpty,
           feedback == .tooShallow || feedback == .torsoLean || feedback == .kneeIssue {
            speakVoice(analysis.coachingCue, highPriority: false)
        }
    }

    // MARK: - Voice helpers

    /// Speak `text` subject to debounce rules.
    /// - `highPriority`: rep counts — always speak, interrupt current speech.
    /// - normal: form cues — only speak after 4 s cooldown if text changed.
    private func speakVoice(_ text: String, highPriority: Bool) {
        guard voiceGuidanceEnabled else { return }
#if canImport(AVFoundation)
        let now = Date()
        let cooldown: TimeInterval = highPriority ? 1.0 : 4.0

        if !highPriority {
            // Skip if same message was spoken recently
            if text == lastSpokenText, now.timeIntervalSince(lastSpeechDate) < cooldown { return }
            // Skip if a rep was just announced (give it 1.5 s of air time)
            if now.timeIntervalSince(lastSpeechDate) < 1.5, speechCoach.isSpeaking { return }
        }

        lastSpokenText = text
        lastSpeechDate = now
        speechCoach.speak(text)
#endif
    }

    private func pushUpShoulderY(from joints: [String: PosePoint]) -> Double? {
        guard let leftShoulder = joints["left_shoulder"],
              let rightShoulder = joints["right_shoulder"] else { return nil }
        return (leftShoulder.y + rightShoulder.y) / 2
    }

    private func plankStabilityScore(from joints: [String: PosePoint]) -> Double {
        guard let leftShoulder = joints["left_shoulder"],
              let rightShoulder = joints["right_shoulder"],
              let leftHip = joints["left_hip"],
              let rightHip = joints["right_hip"],
              let leftAnkle = joints["left_ankle"],
              let rightAnkle = joints["right_ankle"]
        else { return 0 }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let hipY = (leftHip.y + rightHip.y) / 2
        let ankleY = (leftAnkle.y + rightAnkle.y) / 2

        let bodyLow = (shoulderY + hipY) / 2 < 0.62
        let shoulderHipScore = 1.0 - min(abs(shoulderY - hipY) / 0.16, 1.0)
        let hipAnkleScore = 1.0 - min(abs(hipY - ankleY) / 0.24, 1.0)
        let score = shoulderHipScore * 0.65 + hipAnkleScore * 0.35
        return bodyLow ? score : 0
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
    private static let repsKeyPrefix = "camera.dailyReps"
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
            persistDailyReps()
        } else {
            loadDailyReps(for: todayStr)
        }
    }

    private func dailyRepsKey() -> String {
        dailyRepsKey(for: ExerciseCameraAnalysisViewModel.dayFormatter.string(from: Date()))
    }

    private func dailyRepsKey(for day: String) -> String {
        "\(Self.repsKeyPrefix).\(day)"
    }

    private func loadDailyReps(for day: String) {
        guard let stored = UserDefaults.standard.dictionary(forKey: dailyRepsKey(for: day)) as? [String: Int] else {
            dailyReps = [:]
            return
        }
        dailyReps = stored.reduce(into: [:]) { result, item in
            guard let exercise = DetectedExercise(rawValue: item.key), item.value > 0 else { return }
            result[exercise] = item.value
        }
    }

    private func persistDailyReps() {
        let encoded = dailyReps.reduce(into: [String: Int]()) { result, item in
            if item.value > 0 {
                result[item.key.rawValue] = item.value
            }
        }
        UserDefaults.standard.set(encoded, forKey: dailyRepsKey())
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
        case .plank:
            return BodyPoseSample(
                jointConfidences: standardConfidences(),
                jointPositions: [
                    "left_shoulder":  PosePoint(x: 0.32, y: 0.38),
                    "right_shoulder": PosePoint(x: 0.42, y: 0.38),
                    "left_elbow":     PosePoint(x: 0.28, y: 0.28),
                    "right_elbow":    PosePoint(x: 0.38, y: 0.28),
                    "left_wrist":     PosePoint(x: 0.25, y: 0.22),
                    "right_wrist":    PosePoint(x: 0.35, y: 0.22),
                    "left_hip":       PosePoint(x: 0.58, y: 0.36),
                    "right_hip":      PosePoint(x: 0.68, y: 0.36),
                    "left_knee":      PosePoint(x: 0.75, y: 0.34),
                    "right_knee":     PosePoint(x: 0.85, y: 0.34),
                    "left_ankle":     PosePoint(x: 0.88, y: 0.32),
                    "right_ankle":    PosePoint(x: 0.96, y: 0.32)
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
    private var plankHoldStartedAt: Date?
    private var plankAccumulatedSeconds: Int = 0
    private var pushUpHighestShoulderY: Double?
    private var pushUpLowestShoulderY: Double?

    mutating func update(exercise: DetectedExercise, angles: [String: Double], capturedAt: Date = Date()) {
        switch exercise {
        // Squat: count quicker by accepting a solid partial depth, then full return to standing.
        case .squat:
            countReps(primaryAngle: averageKnee(angles), bottomThreshold: 130, topThreshold: 150)
        // Push-up: iPhone X/Vision often reports a bottom push-up around 100–120°.
        case .pushUp:
            countPushUp(elbowAngle: averageElbow(angles), shoulderY: validMetric(angles["pushup_shoulder_y"]))
        // Pull-up: bottom = 110° (arms bent, chin over bar), top = 155° (arms extended)
        case .pullUp:
            countReps(primaryAngle: averageElbow(angles), bottomThreshold: 125, topThreshold: 155)
        // Sit-up: count a clean crunch without requiring a fully compressed hip angle.
        case .sitUp:
            countReps(primaryAngle: averageHip(angles), bottomThreshold: 115, topThreshold: 150)
        // Jumping jack: count each open position after feet return close together.
        case .jumpingJack:
            countJumpingJack(spread: averageAnkleSpread(angles))
        // Plank is a hold, so count stable seconds instead of reps.
        case .plank:
            countPlankHold(stability: angles["plank_stability"], capturedAt: capturedAt)
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

    private mutating func countJumpingJack(spread: Double?) {
        guard let spread else { return }
        switch phase {
        case .top where spread < 0.14:
            phase = .bottom
        case .bottom where spread > 0.24:
            phase = .top
            count += 1
        default:
            break
        }
    }

    private mutating func countPushUp(elbowAngle: Double?, shoulderY: Double?) {
        let countBeforeAngle = count
        countReps(primaryAngle: elbowAngle, bottomThreshold: 145, topThreshold: 152)
        if count > countBeforeAngle { return }

        guard let shoulderY else { return }

        pushUpHighestShoulderY = max(pushUpHighestShoulderY ?? shoulderY, shoulderY)
        pushUpLowestShoulderY = min(pushUpLowestShoulderY ?? shoulderY, shoulderY)

        guard let highest = pushUpHighestShoulderY,
              let lowest = pushUpLowestShoulderY else { return }

        let range = highest - lowest
        guard range >= 0.025 else { return }

        let bottomLine = lowest + range * 0.35
        let topLine = lowest + range * 0.70

        switch phase {
        case .top where shoulderY <= bottomLine:
            phase = .bottom
        case .bottom where shoulderY >= topLine:
            phase = .top
            count += 1
        default:
            break
        }
    }

    private mutating func countPlankHold(stability: Double?, capturedAt: Date) {
        guard let stability, stability >= 0.55 else {
            if let started = plankHoldStartedAt {
                plankAccumulatedSeconds += max(0, Int(capturedAt.timeIntervalSince(started)))
            }
            plankHoldStartedAt = nil
            count = plankAccumulatedSeconds
            return
        }

        if plankHoldStartedAt == nil {
            plankHoldStartedAt = capturedAt
        }
        let currentHold = plankHoldStartedAt.map { max(0, Int(capturedAt.timeIntervalSince($0))) } ?? 0
        count = plankAccumulatedSeconds + currentHold
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

    // Jumping jack uses ankle horizontal spread (normalised 0–1) instead of an angle.
    // The "angle" dictionary doesn't contain this directly — we derive it from
    // a synthetic key injected by the ViewModel's applyAnalysis step.
    private func averageAnkleSpread(_ angles: [String: Double]) -> Double? {
        angles["ankle_spread"]
    }

    private func validMetric(_ value: Double?) -> Double? {
        guard let value, value >= 0 else { return nil }
        return value
    }
}
