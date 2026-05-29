#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct ExerciseCameraAnalysisView: View {
    @ObservedObject private var viewModel: ExerciseCameraAnalysisViewModel
#if canImport(AVFoundation)
    @StateObject private var cameraController = CameraCaptureController()
#endif

    public init(viewModel: ExerciseCameraAnalysisViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FitnessSpacing.xLarge) {
                    header
                    exercisePicker
                    repCounterCard

                    if !viewModel.dailyReps.isEmpty {
                        dailySummaryCard
                    }

                    cameraSetupCard

#if targetEnvironment(simulator)
                    simulatorCard
#else
                    liveCameraCard
#endif

                    switch viewModel.loadState {
                    case .idle:
                        ScreenStateCard(
                            title: "Ready to analyze",
                            message: "Select an exercise above, then tap the button to start.",
                            imageSystemName: "figure.strengthtraining.functional",
                            actionTitle: actionTitle,
                            onAction: runAnalysis
                        )
                    case .loading:
                        ScreenStateCard(
                            title: "Analyzing movement",
                            message: "Reviewing posture and preparing a coaching cue.",
                            imageSystemName: "waveform.path.ecg"
                        )
                    case .failed(let message):
                        ScreenStateCard(
                            title: "Analysis interrupted",
                            message: message,
                            imageSystemName: "camera.metering.unknown",
                            actionTitle: "Try Again",
                            onAction: runAnalysis
                        )
                    case .loaded:
                        if let analysis = viewModel.latestAnalysis {
                            analysisResultCard(analysis: analysis)
                        }
                    }
                }
                .padding(FitnessSpacing.large)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Form Feedback")
            .overlay(alignment: .bottom) {
                if let msg = viewModel.sessionSavedMessage {
                    savedToast(msg)
                }
            }
#if canImport(AVFoundation)
            .onDisappear {
                cameraController.stop()
            }
#endif
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.small) {
            MetricBadge(systemImage: "camera.aperture", text: "Live form coaching")
            Text("Exercise Form")
                .font(FitnessTypography.hero)
                .foregroundStyle(FitnessTheme.primaryText)
            Text("Real-time posture feedback and rep counting.")
                .font(FitnessTypography.body)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
    }

    // MARK: - Exercise Picker

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FitnessSpacing.small) {
                ForEach(DetectedExercise.trackableExercises, id: \.self) { exercise in
                    exerciseChip(exercise)
                }
            }
            .padding(.horizontal, FitnessSpacing.large)
        }
        .padding(.horizontal, -FitnessSpacing.large)
    }

    private func exerciseChip(_ exercise: DetectedExercise) -> some View {
        Button {
            viewModel.selectExercise(exercise)
        } label: {
            Text(exercise.rawValue)
                .font(FitnessTypography.caption)
                .foregroundStyle(
                    viewModel.selectedExercise == exercise ? .black : FitnessTheme.primaryText
                )
                .padding(.horizontal, FitnessSpacing.medium)
                .padding(.vertical, FitnessSpacing.small)
                .background(
                    viewModel.selectedExercise == exercise
                        ? FitnessTheme.accent
                        : FitnessTheme.surface
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Rep Counter Card

    private var repCounterCard: some View {
        FitnessCard {
            HStack(alignment: .center, spacing: FitnessSpacing.medium) {
                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text(viewModel.selectedExercise.rawValue)
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(FitnessTheme.primaryText)

                    // Timer + session reps label row
                    HStack(spacing: FitnessSpacing.small) {
                        Text("Session reps")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                        if viewModel.sessionElapsedSeconds > 0 {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                Text(viewModel.sessionTimerDisplay)
                                    .font(.caption2.monospacedDigit())
                            }
                            .foregroundStyle(FitnessTheme.accent)
                        }
                    }

                    // Movement phase badge
                    if let phase = viewModel.currentPhase {
                        phaseBadge(phase)
                    }
                }

                Spacer()

                Text("\(viewModel.repCount)")
                    .font(FitnessTypography.metric)
                    .foregroundStyle(FitnessTheme.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Button {
                    viewModel.resetRepCount()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Daily Summary Card

    private var dailySummaryCard: some View {
        FitnessCard(title: "Today") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: FitnessSpacing.small
                ) {
                    ForEach(DetectedExercise.trackableExercises.filter {
                        (viewModel.dailyReps[$0] ?? 0) > 0
                    }, id: \.self) { exercise in
                        HStack {
                            Text(exercise.rawValue)
                                .font(FitnessTypography.caption)
                                .foregroundStyle(FitnessTheme.secondaryText)
                            Spacer()
                            Text("\(viewModel.dailyReps[exercise] ?? 0) reps")
                                .font(FitnessTypography.caption)
                                .foregroundStyle(FitnessTheme.primaryText)
                        }
                    }
                }

                // ── Saran 3: Save to Firestore button ──
                Button {
                    Task { await viewModel.saveSession() }
                } label: {
                    HStack {
                        if viewModel.isSavingSession {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(viewModel.isSavingSession ? "Saving…" : "Save Workout")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!viewModel.canSaveSession)
            }
        }
    }

    // MARK: - Camera Setup Card

    private var cameraSetupCard: some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                MetricBadge(systemImage: "viewfinder.circle", text: "Setup tips")
                Text("Place your full body in frame, keep the device stable at chest height.")
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FitnessSpacing.small) {
                        MetricBadge(systemImage: "camera.fill",          text: "Full body")
                        MetricBadge(systemImage: "figure.mind.and.body", text: "On-device")
                        MetricBadge(systemImage: "brain",                text: "Groq AI",
                                    tint: FitnessTheme.caution)
                    }
                }
            }
        }
    }

    // MARK: - Simulator Card

#if targetEnvironment(simulator)
    private var simulatorCard: some View {
        FitnessCard(title: "Simulator Mode") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                Text("Live camera is unavailable in the Simulator. Tap below to analyze a sample \(viewModel.selectedExercise.rawValue) pose.")
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)
                Button(actionTitle, action: runAnalysis)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
#endif

    // MARK: - Live Camera Card

#if !targetEnvironment(simulator)
    private var liveCameraCard: some View {
        FitnessCard(title: "Live Camera") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
#if canImport(AVFoundation)
                ZStack(alignment: .bottom) {
                    CameraPreviewView(session: cameraController.session)
                        .frame(height: 340)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    // Phase + rep + timer overlay
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if viewModel.currentExercise != .unknown {
                                Text(viewModel.currentExercise.rawValue)
                                    .font(FitnessTypography.sectionTitle)
                                    .foregroundStyle(.white)
                            }
                            if let phase = viewModel.currentPhase {
                                phaseOverlayBadge(phase)
                            }
                            // Session timer
                            if viewModel.sessionElapsedSeconds > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.caption2)
                                    Text(viewModel.sessionTimerDisplay)
                                        .font(.caption2.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(viewModel.repCount)")
                                .font(FitnessTypography.sectionTitle)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("reps")
                                .font(FitnessTypography.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(FitnessSpacing.medium)
                    .background(.black.opacity(0.6))
                    .clipShape(BottomRoundedShape(radius: 24))
                }

                Text(viewModel.cameraMessage)
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)

                Button("Start Live Camera", action: runAnalysis)
                    .buttonStyle(PrimaryActionButtonStyle())
#endif
            }
        }
    }
#endif

    // MARK: - Analysis Result Card

    private func analysisResultCard(analysis: ExerciseAnalysis) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                // Status + confidence
                HStack {
                    MetricBadge(
                        systemImage: statusIcon(for: analysis.status),
                        text: statusTitle(for: analysis.status),
                        tint: statusTint(for: analysis.status)
                    )
                    Spacer()
                    Text("\(Int(analysis.postureConfidence * 100))% confidence")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }

                // ── Saran 2: Form feedback chip ──
                if let feedback = analysis.formFeedback {
                    formFeedbackChip(feedback)
                }

                // Coaching cue
                Text(analysis.coachingCue)
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)

                if let classification = analysis.classification {
                    Text("Detected: \(classification)")
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }

                // ── Saran 1: Phase row in result ──
                if let phase = analysis.movementPhase, phase != .standing {
                    phaseBadge(phase)
                }

                // Joint angles grid
                if !analysis.jointAngles.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: FitnessSpacing.small
                    ) {
                        ForEach(analysis.jointAngles.sorted { $0.key < $1.key }, id: \.key) { key, value in
                            MetricBadge(
                                systemImage: "angle",
                                text: "\(key.replacingOccurrences(of: "_", with: " ")): \(Int(value))°"
                            )
                        }
                    }
                }

                Button("Run Another Check", action: runAnalysis)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    // MARK: - Saran 1: Phase badge views

    /// Compact inline badge shown in the rep counter card and result card.
    @ViewBuilder
    private func phaseBadge(_ phase: MovementPhase) -> some View {
        HStack(spacing: 4) {
            Image(systemName: phaseIcon(phase))
                .font(.caption2)
            Text(phaseLabel(phase))
                .font(FitnessTypography.caption)
        }
        .foregroundStyle(phaseColor(phase))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(phaseColor(phase).opacity(0.15))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    /// Smaller badge for the live camera dark overlay.
    @ViewBuilder
    private func phaseOverlayBadge(_ phase: MovementPhase) -> some View {
        HStack(spacing: 4) {
            Image(systemName: phaseIcon(phase))
                .font(.caption2)
            Text(phaseLabel(phase))
                .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(phaseColor(phase).opacity(0.75))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.15), value: phase)
    }

    private func phaseIcon(_ phase: MovementPhase) -> String {
        switch phase {
        case .standing:   return "figure.stand"
        case .descending: return "arrow.down"
        case .bottom:     return "checkmark.circle.fill"
        case .rising:     return "arrow.up"
        }
    }

    private func phaseLabel(_ phase: MovementPhase) -> String {
        switch phase {
        case .standing:   return "Standing"
        case .descending: return "Descending ↓"
        case .bottom:     return "Bottom ✓"
        case .rising:     return "Rising ↑"
        }
    }

    private func phaseColor(_ phase: MovementPhase) -> Color {
        switch phase {
        case .standing:   return FitnessTheme.secondaryText
        case .descending: return FitnessTheme.caution
        case .bottom:     return FitnessTheme.success
        case .rising:     return FitnessTheme.accent
        }
    }

    // MARK: - Saran 2: Form feedback chip

    @ViewBuilder
    private func formFeedbackChip(_ feedback: ExerciseFormFeedback) -> some View {
        HStack(spacing: 6) {
            Image(systemName: feedbackIcon(feedback))
                .font(.caption)
            Text(feedbackLabel(feedback))
                .font(FitnessTypography.caption)
        }
        .foregroundStyle(feedbackColor(feedback))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(feedbackColor(feedback).opacity(0.15))
        .overlay(
            Capsule().stroke(feedbackColor(feedback).opacity(0.3), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private func feedbackIcon(_ feedback: ExerciseFormFeedback) -> String {
        switch feedback {
        case .goodForm:        return "checkmark.seal.fill"
        case .tooShallow:      return "arrow.down.to.line"
        case .torsoLean:       return "figure.walk"
        case .kneeIssue:       return "exclamationmark.triangle.fill"
        case .lowConfidence:   return "eye.slash"
        case .bodyNotVisible:  return "person.fill.xmark"
        }
    }

    private func feedbackLabel(_ feedback: ExerciseFormFeedback) -> String {
        switch feedback {
        case .goodForm:        return "Good Form"
        case .tooShallow:      return "Too Shallow"
        case .torsoLean:       return "Chest Forward"
        case .kneeIssue:       return "Knee Alignment"
        case .lowConfidence:   return "Low Confidence"
        case .bodyNotVisible:  return "Body Not Visible"
        }
    }

    private func feedbackColor(_ feedback: ExerciseFormFeedback) -> Color {
        switch feedback {
        case .goodForm:                          return FitnessTheme.success
        case .tooShallow, .torsoLean:            return FitnessTheme.caution
        case .kneeIssue:                         return Color.orange
        case .lowConfidence, .bodyNotVisible:    return FitnessTheme.secondaryText
        }
    }

    // MARK: - Toast

    private func savedToast(_ message: String) -> some View {
        Text(message)
            .font(FitnessTypography.caption)
            .foregroundStyle(.black)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.vertical, FitnessSpacing.small)
            .background(FitnessTheme.accent)
            .clipShape(Capsule())
            .padding(.bottom, FitnessSpacing.xLarge)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: message)
    }

    // MARK: - Actions

    private func runAnalysis() {
#if targetEnvironment(simulator)
        Task { await viewModel.runPreviewAnalysis() }
#else
        Task { await startCameraIfNeeded() }
#endif
    }

    private var actionTitle: String {
#if targetEnvironment(simulator)
        "Analyze \(viewModel.selectedExercise.rawValue)"
#else
        "Start Live Camera"
#endif
    }

#if canImport(AVFoundation)
    private func startCameraIfNeeded() async {
        cameraController.onFrame = { pixelBuffer in
            let wrappedBuffer = SendablePixelBuffer(pixelBuffer)
            Task { @MainActor in
                await viewModel.analyze(pixelBuffer: wrappedBuffer.value)
            }
        }

        viewModel.beginLiveAnalysis()
        let state = await cameraController.start()

        switch state {
        case .configured:
            break
        case .denied:
            viewModel.handleCameraAccessDenied()
        case .failed(let message):
            viewModel.handleCameraUnavailable(message)
        case .idle, .requestingPermission:
            break
        }
    }
#endif

    // MARK: - Status helpers

    private func statusIcon(for status: ExerciseFormStatus) -> String {
        switch status {
        case .acceptable:     return "checkmark.circle"
        case .excellent:      return "checkmark.seal.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .unavailable:    return "questionmark.circle"
        }
    }

    private func statusTitle(for status: ExerciseFormStatus) -> String {
        switch status {
        case .acceptable:     return "Good baseline"
        case .excellent:      return "Strong form"
        case .needsAttention: return "Needs adjustment"
        case .unavailable:    return "Unavailable"
        }
    }

    private func statusTint(for status: ExerciseFormStatus) -> Color {
        switch status {
        case .acceptable:     return FitnessTheme.accent
        case .excellent:      return FitnessTheme.success
        case .needsAttention: return FitnessTheme.caution
        case .unavailable:    return FitnessTheme.secondaryText
        }
    }
}

// MARK: - Helpers

private struct BottomRoundedShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            p.closeSubpath()
        }
    }
}
