#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

// MARK: - Main hub view

public struct ExerciseCameraAnalysisView: View {
    @ObservedObject private var viewModel: ExerciseCameraAnalysisViewModel
#if canImport(AVFoundation)
    @StateObject private var cameraController = CameraCaptureController()
#endif
    @State private var isFullScreen = false

    public init(viewModel: ExerciseCameraAnalysisViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FitnessSpacing.large) {
                    pageHeader
                    exercisePicker
                    repCounterCard

                    if !viewModel.dailyReps.isEmpty {
                        dailySummaryCard
                    }

#if targetEnvironment(simulator)
                    simulatorCard
                    if case .loaded = viewModel.loadState,
                       let analysis = viewModel.latestAnalysis {
                        analysisResultCard(analysis: analysis)
                    }
#else
                    cameraLaunchCard
#endif
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xxLarge)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .overlay(alignment: .bottom) {
                if let msg = viewModel.sessionSavedMessage { savedToast(msg) }
            }
#if !targetEnvironment(simulator) && canImport(AVFoundation)
            .fullScreenCover(isPresented: $isFullScreen) {
                FullScreenCameraView(viewModel: viewModel, cameraController: cameraController)
            }
            .onChange(of: isFullScreen) { showing in
                if showing { Task { await launchCamera() } }
            }
#endif
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MetricBadge(systemImage: "camera.aperture", text: "On-device AI")
                Spacer()
                if viewModel.sessionElapsedSeconds > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.caption2)
                        Text(viewModel.sessionTimerDisplay).font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(FitnessTheme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(FitnessTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            Text("Exercise Form")
                .font(FitnessTypography.hero)
                .foregroundStyle(FitnessTheme.primaryText)
            Text("Real-time posture feedback & rep counting — works fully offline.")
                .font(FitnessTypography.body)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
        .padding(.top, FitnessSpacing.medium)
    }

    // MARK: - Exercise picker

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
        Button { viewModel.selectExercise(exercise) } label: {
            Text(exercise.rawValue)
                .font(FitnessTypography.caption)
                .foregroundStyle(viewModel.selectedExercise == exercise ? .black : FitnessTheme.primaryText)
                .padding(.horizontal, FitnessSpacing.medium)
                .padding(.vertical, FitnessSpacing.small)
                .background(viewModel.selectedExercise == exercise ? FitnessTheme.accent : FitnessTheme.surface)
                .clipShape(Capsule())
        }
    }

    // MARK: - Rep counter card

    private var repCounterCard: some View {
        FitnessCard {
            HStack(alignment: .center, spacing: FitnessSpacing.medium) {
                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text(viewModel.selectedExercise.rawValue)
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    Text(viewModel.selectedExercise == .plank ? "Today hold seconds" : "Today reps")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                    if let phase = viewModel.currentPhase { phaseBadge(phase) }
                }
                Spacer()
                Text("\(viewModel.repCount)")
                    .font(FitnessTypography.metric)
                    .foregroundStyle(FitnessTheme.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Button { viewModel.resetRepCount() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.body).foregroundStyle(FitnessTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Daily summary card

    private var dailySummaryCard: some View {
        FitnessCard(title: "Today") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: FitnessSpacing.small) {
                    ForEach(DetectedExercise.trackableExercises.filter {
                        (viewModel.dailyReps[$0] ?? 0) > 0
                    }, id: \.self) { exercise in
                        HStack {
                            Text(exercise.rawValue)
                                .font(FitnessTypography.caption)
                                .foregroundStyle(FitnessTheme.secondaryText)
                            Spacer()
                            Text(summaryValue(for: exercise, count: viewModel.dailyReps[exercise] ?? 0))
                                .font(FitnessTypography.caption.bold())
                                .foregroundStyle(FitnessTheme.primaryText)
                        }
                    }
                }
                Button {
                    Task { await viewModel.saveSession() }
                } label: {
                    HStack {
                        if viewModel.isSavingSession {
                            ProgressView().tint(.black).scaleEffect(0.8)
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

    // MARK: - Camera launch card (real device only)

#if !targetEnvironment(simulator)
    private var cameraLaunchCard: some View {
        GradientCard(gradient: LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.12),
                     Color(red: 0.08, green: 0.14, blue: 0.24)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )) {
            VStack(spacing: FitnessSpacing.large) {
                HStack(spacing: FitnessSpacing.medium) {
                    ZStack {
                        Circle()
                            .fill(FitnessTheme.accent.opacity(0.18))
                            .frame(width: 56, height: 56)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(FitnessTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Camera")
                            .font(FitnessTypography.sectionTitle)
                            .foregroundStyle(.white)
                        Text("On-device Vision — no internet needed")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }

                // Feature pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FitnessSpacing.small) {
                        featurePill(icon: "figure.mind.and.body", text: "Skeleton")
                        featurePill(icon: "repeat",               text: "Rep Count")
                        featurePill(icon: "checkmark.seal",       text: "Form Check")
                        featurePill(icon: "wifi.slash",           text: "Offline")
                    }
                }

                Button {
                    isFullScreen = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Start Camera")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(FitnessTypography.tiny)
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.10))
        .clipShape(Capsule())
    }
#endif

    // MARK: - Simulator card

#if targetEnvironment(simulator)
    private var simulatorCard: some View {
        FitnessCard(title: "Simulator Mode") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                Text("Live camera is unavailable in the Simulator. Tap below to analyze a sample \(viewModel.selectedExercise.rawValue) pose.")
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)
                Button("Analyze \(viewModel.selectedExercise.rawValue)") {
                    Task { await viewModel.runPreviewAnalysis() }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }
#endif

    // MARK: - Shared sub-views

    private func phaseBadge(_ phase: MovementPhase) -> some View {
        HStack(spacing: 4) {
            Image(systemName: phaseIcon(phase)).font(.caption2)
            Text(phaseLabel(phase)).font(FitnessTypography.caption)
        }
        .foregroundStyle(phaseColor(phase))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(phaseColor(phase).opacity(0.15))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: phase)
    }

    private func savedToast(_ message: String) -> some View {
        Text(message)
            .font(FitnessTypography.caption).foregroundStyle(.black)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.vertical, FitnessSpacing.small)
            .background(FitnessTheme.accent).clipShape(Capsule())
            .padding(.bottom, FitnessSpacing.xLarge)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: message)
    }

    private func analysisResultCard(analysis: ExerciseAnalysis) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    MetricBadge(systemImage: statusIcon(for: analysis.status),
                                text: statusTitle(for: analysis.status),
                                tint: statusTint(for: analysis.status))
                    Spacer()
                    Text("\(Int(analysis.postureConfidence * 100))% confidence")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
                if let fb = analysis.formFeedback { formFeedbackChip(fb) }
                Text(analysis.coachingCue)
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)
                if let phase = analysis.movementPhase, phase != .standing { phaseBadge(phase) }
            }
        }
    }

    // MARK: - Camera launch helper

#if !targetEnvironment(simulator) && canImport(AVFoundation)
    private func launchCamera() async {
        cameraController.onFrame = { [cameraController] pixelBuffer in
            let buf = SendablePixelBuffer(pixelBuffer)
            let isFront = cameraController.isFrontCamera
            Task { @MainActor in
                await viewModel.analyze(pixelBuffer: buf.value, isFrontCamera: isFront)
            }
        }
        viewModel.beginLiveAnalysis()
        let state = await cameraController.start()
        switch state {
        case .denied:  viewModel.handleCameraAccessDenied()
        case .failed(let msg): viewModel.handleCameraUnavailable(msg)
        default: break
        }
    }
#endif

    // MARK: - Helpers

    private func phaseIcon(_ phase: MovementPhase) -> String {
        switch phase {
        case .standing: return "figure.stand"
        case .descending: return "arrow.down"
        case .bottom: return "checkmark.circle.fill"
        case .rising: return "arrow.up"
        }
    }
    private func phaseLabel(_ phase: MovementPhase) -> String {
        switch phase {
        case .standing: return "Standing"
        case .descending: return "Descending ↓"
        case .bottom: return "Bottom ✓"
        case .rising: return "Rising ↑"
        }
    }
    private func phaseColor(_ phase: MovementPhase) -> Color {
        switch phase {
        case .standing: return FitnessTheme.secondaryText
        case .descending: return FitnessTheme.caution
        case .bottom: return FitnessTheme.success
        case .rising: return FitnessTheme.accent
        }
    }
    private func formFeedbackChip(_ feedback: ExerciseFormFeedback) -> some View {
        HStack(spacing: 6) {
            Image(systemName: feedbackIcon(feedback)).font(.caption)
            Text(feedbackLabel(feedback)).font(FitnessTypography.caption)
        }
        .foregroundStyle(feedbackColor(feedback))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(feedbackColor(feedback).opacity(0.15))
        .overlay(Capsule().stroke(feedbackColor(feedback).opacity(0.3), lineWidth: 1))
        .clipShape(Capsule())
    }
    private func feedbackIcon(_ f: ExerciseFormFeedback) -> String {
        switch f {
        case .goodForm: return "checkmark.seal.fill"
        case .tooShallow: return "arrow.down.to.line"
        case .torsoLean: return "figure.walk"
        case .kneeIssue: return "exclamationmark.triangle.fill"
        case .lowConfidence: return "eye.slash"
        case .bodyNotVisible: return "person.fill.xmark"
        }
    }
    private func feedbackLabel(_ f: ExerciseFormFeedback) -> String {
        switch f {
        case .goodForm: return "Good Form"
        case .tooShallow: return "Too Shallow"
        case .torsoLean: return "Chest Forward"
        case .kneeIssue: return "Knee Alignment"
        case .lowConfidence: return "Low Confidence"
        case .bodyNotVisible: return "Body Not Visible"
        }
    }
    private func feedbackColor(_ f: ExerciseFormFeedback) -> Color {
        switch f {
        case .goodForm: return FitnessTheme.success
        case .tooShallow, .torsoLean: return FitnessTheme.caution
        case .kneeIssue: return .orange
        case .lowConfidence, .bodyNotVisible: return FitnessTheme.secondaryText
        }
    }
    private func summaryValue(for exercise: DetectedExercise, count: Int) -> String {
        exercise == .plank ? "\(count) sec" : "\(count) reps"
    }
    private func statusIcon(for s: ExerciseFormStatus) -> String {
        switch s {
        case .acceptable: return "checkmark.circle"
        case .excellent: return "checkmark.seal.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .unavailable: return "questionmark.circle"
        }
    }
    private func statusTitle(for s: ExerciseFormStatus) -> String {
        switch s {
        case .acceptable: return "Good baseline"
        case .excellent: return "Strong form"
        case .needsAttention: return "Needs adjustment"
        case .unavailable: return "Unavailable"
        }
    }
    private func statusTint(for s: ExerciseFormStatus) -> Color {
        switch s {
        case .acceptable: return FitnessTheme.accent
        case .excellent: return FitnessTheme.success
        case .needsAttention: return FitnessTheme.caution
        case .unavailable: return FitnessTheme.secondaryText
        }
    }
}

// MARK: - Full-screen camera view

#if !targetEnvironment(simulator) && canImport(AVFoundation)
private struct FullScreenCameraView: View {
    @ObservedObject var viewModel: ExerciseCameraAnalysisViewModel
    @ObservedObject var cameraController: CameraCaptureController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ── 1. Black base (full bleed) ──
            Color.black.ignoresSafeArea()

            // ── 2. Camera feed (full bleed) ──
            CameraPreviewView(session: cameraController.session)
                .ignoresSafeArea()

            // ── 3. Skeleton overlay (full bleed) ──
            // Show skeleton whenever ANY joints were detected — this helps the user
            // frame themselves even when confidence is low.
            if let joints = viewModel.latestAnalysis?.poseJointPositions,
               !joints.isEmpty,
               !cameraController.isPaused {
                SkeletonOverlayView(joints: joints)
                    .ignoresSafeArea()
            }

            // ── 4. Pause dimmer ──
            if cameraController.isPaused {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Paused")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
            }

            // ── 5. HUD overlay ──
            // The ZStack itself respects safe areas (no .ignoresSafeArea here).
            // This ensures the top bar sits BELOW the iPhone X notch (44 pt safe area)
            // and interactive controls land in the easy-thumb zone at the bottom.
            VStack(spacing: 0) {
                topBar.padding(.top, 6)
                formCorrectionBanner
                    .padding(.top, 8)
                    .animation(.spring(response: 0.40, dampingFraction: 0.70),
                               value: viewModel.latestAnalysis?.formFeedback)
                Spacer()
                bottomPanel   // exercise picker + flip camera + controls all here
            }
        }
        .preferredColorScheme(.dark)
        // ← intentionally NO .ignoresSafeArea on the ZStack:
        //   background layers go full-bleed via their own .ignoresSafeArea(),
        //   while the HUD VStack stays within safe areas so buttons clear the notch.
        .onDisappear {
            cameraController.stop()
            viewModel.resetCameraSession()
        }
    }

    // MARK: - Form feedback popup
    // Large centered popup shown below the top bar on actionable form errors.
    // Label matches the voice output ("Too Shallow", "Torso Lean", "Knee Issue").

    @ViewBuilder
    private var formCorrectionBanner: some View {
        if !cameraController.isPaused,
           let feedback = viewModel.latestAnalysis?.formFeedback,
           let cue = viewModel.latestAnalysis?.coachingCue {
            switch feedback {
            case .tooShallow, .torsoLean, .kneeIssue:
                // Popup: big label + icon + coaching cue subtitle
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: formIcon(feedback))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text(formPopupLabel(feedback))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text(cue)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(formColor(feedback))
                )
                .padding(.horizontal, 20)
                .shadow(color: formColor(feedback).opacity(0.55), radius: 14, y: 4)
                .transition(.scale(scale: 0.88).combined(with: .opacity))

            case .bodyNotVisible, .lowConfidence:
                // Subtle dark pill — user just needs to reposition
                HStack(spacing: 10) {
                    Image(systemName: formIcon(feedback))
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.80))
                        .frame(width: 28)
                    Text(cue)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))

            case .goodForm:
                EmptyView()
            }
        }
    }

    /// The short label shown inside the popup — mirrors the voice output.
    private func formPopupLabel(_ f: ExerciseFormFeedback) -> String {
        switch f {
        case .tooShallow: return "Too Shallow"
        case .torsoLean:  return "Torso Lean"
        case .kneeIssue:  return "Knee Issue"
        default:          return formLabel(f)
        }
    }

    // MARK: - Top bar  (close + timer + voice toggle)
    // Exercise picker and camera-flip moved to the bottom panel so they are
    // reachable with the thumb on tall devices like iPhone X.

    private var topBar: some View {
        HStack(alignment: .center) {
            // ── Close — 44×44 pt tap target (HIG minimum) ──
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)

            Spacer()

            // ── Session timer (centre) ──
            if viewModel.sessionElapsedSeconds > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "timer").font(.caption2)
                    Text(viewModel.sessionTimerDisplay)
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
            }

            Spacer()

            // ── Voice guidance toggle ──
            Button {
                viewModel.toggleVoiceGuidance()
            } label: {
                Image(systemName: viewModel.voiceGuidanceEnabled
                      ? "speaker.wave.2.fill"
                      : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.voiceGuidanceEnabled
                                     ? FitnessTheme.accent : .white.opacity(0.45))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
        }
    }

    // MARK: - Bottom panel
    // All interactive controls live here so they're in easy thumb reach.
    //
    // Layout (top → bottom):
    //   ① Exercise chips  +  🔄 Flip camera
    //   ② Phase chip  /  Form chip  /  Rep counter (big)
    //   ③ Coaching cue text
    //   ④ [Pause]  [Stop]  [Save☁]

    private var bottomPanel: some View {
        VStack(spacing: 0) {

            // ─── ① Exercise picker row + flip camera ───────────────────────
            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DetectedExercise.trackableExercises, id: \.self) { ex in
                            Button { viewModel.selectExercise(ex) } label: {
                                Text(ex.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(viewModel.selectedExercise == ex ? .black : .white)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(
                                        viewModel.selectedExercise == ex
                                            ? FitnessTheme.accent
                                            : Color.white.opacity(0.18)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                // Flip camera — 48×48 pt for easy tap
                Button { cameraController.switchCamera() } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .disabled(cameraController.state != .configured)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // ─── ② Phase / form chips + big rep counter ────────────────────
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let phase = viewModel.currentPhase { phaseChip(phase) }
                    if let fb = viewModel.latestAnalysis?.formFeedback { formChip(fb) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(viewModel.repCount)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(FitnessTheme.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(viewModel.selectedExercise == .plank ? "today sec" : "today reps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // ─── ③ Coaching cue ─────────────────────────────────────────────
            if let cue = viewModel.latestAnalysis?.coachingCue, !cue.isEmpty {
                Text(cue)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            // ─── ④ Controls ─────────────────────────────────────────────────
            HStack(spacing: 12) {
                // Pause / Resume
                Button {
                    cameraController.isPaused ? cameraController.resume() : cameraController.pause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cameraController.isPaused ? "play.fill" : "pause.fill")
                        Text(cameraController.isPaused ? "Resume" : "Pause")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(FitnessTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Stop
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(FitnessTheme.caution)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(FitnessTheme.caution.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(FitnessTheme.caution.opacity(0.4), lineWidth: 1)
                    )
                }

                // Save — only visible when there are reps to save
                if viewModel.canSaveSession {
                    Button {
                        Task { await viewModel.saveSession() }
                    } label: {
                        Group {
                            if viewModel.isSavingSession {
                                ProgressView().tint(.black).scaleEffect(0.8)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(FitnessTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(viewModel.isSavingSession)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)   // comfortable clearance above home indicator
        }
        // Material background extends into home indicator area for visual continuity
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Chip helpers

    private func phaseChip(_ phase: MovementPhase) -> some View {
        HStack(spacing: 4) {
            Image(systemName: phaseIcon(phase)).font(.caption2)
            Text(phaseLabel(phase)).font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(phaseColor(phase).opacity(0.80))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.15), value: phase)
    }

    private func formChip(_ feedback: ExerciseFormFeedback) -> some View {
        HStack(spacing: 4) {
            Image(systemName: formIcon(feedback)).font(.caption2)
            Text(formLabel(feedback)).font(.caption.bold())
        }
        .foregroundStyle(formColor(feedback))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(formColor(feedback).opacity(0.20))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func phaseIcon(_ p: MovementPhase) -> String {
        switch p {
        case .standing:   return "figure.stand"
        case .descending: return "arrow.down"
        case .bottom:     return "checkmark.circle.fill"
        case .rising:     return "arrow.up"
        }
    }
    private func phaseLabel(_ p: MovementPhase) -> String {
        switch p {
        case .standing:   return "Standing"
        case .descending: return "Going down"
        case .bottom:     return "Bottom ✓"
        case .rising:     return "Coming up"
        }
    }
    private func phaseColor(_ p: MovementPhase) -> Color {
        switch p {
        case .standing:   return Color.gray
        case .descending: return FitnessTheme.caution
        case .bottom:     return FitnessTheme.success
        case .rising:     return FitnessTheme.accent
        }
    }
    private func formIcon(_ f: ExerciseFormFeedback) -> String {
        switch f {
        case .goodForm:       return "checkmark.seal.fill"
        case .tooShallow:     return "arrow.down.to.line"
        case .torsoLean:      return "figure.walk"
        case .kneeIssue:      return "exclamationmark.triangle.fill"
        case .lowConfidence:  return "eye.slash"
        case .bodyNotVisible: return "person.fill.xmark"
        }
    }
    private func formLabel(_ f: ExerciseFormFeedback) -> String {
        switch f {
        case .goodForm:       return "Good Form"
        case .tooShallow:     return "Go Deeper"
        case .torsoLean:      return "Chest Up"
        case .kneeIssue:      return "Knee Alignment"
        case .lowConfidence:  return "Low Confidence"
        case .bodyNotVisible: return "Not Visible"
        }
    }
    private func formColor(_ f: ExerciseFormFeedback) -> Color {
        switch f {
        case .goodForm:                       return FitnessTheme.success
        case .tooShallow, .torsoLean:         return FitnessTheme.caution
        case .kneeIssue:                      return Color.orange
        case .lowConfidence, .bodyNotVisible: return Color.gray
        }
    }
}
#endif
