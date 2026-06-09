# FitnessAI — Project Context

## Overview

iOS fitness coach app built with SwiftUI + MVVM. Uses Apple Vision for on-device body-pose detection, a custom Create ML action classifier for squat form recognition, and Firebase for auth/cloud storage. Fully offline for camera/ML features.

- **Bundle ID**: `com.JuanJavier.fitnesscoach`
- **Firebase project**: `fitness-737cb`
- **GitHub**: `https://github.com/h4kua/FitnessAI.git`
- **Min deployment**: iOS 16
- **Tested device**: iPhone X (MQA62CH/A, serial FK1VTLL8JCLG)

---

## Module Structure

```
fitness_project/
├── App/                        Main Xcode target entry point
│   ├── Sources/AppFeature/     AppDependencies, AppRootView, MainTabView
│   └── Configurations/         Debug.xcconfig (contains GROK_ENV API key — gitignored via xcscheme)
│
├── Core/                       Pure domain layer — no frameworks
│   ├── Domain/                 BodyPoseSample, DetectedExercise, ExerciseAnalysis, etc.
│   └── Interfaces/             Protocol definitions (ExerciseAnalysisProviding, etc.)
│
├── DesignSystem/               Reusable UI: FitnessTheme, FitnessCard, MetricBadge, etc.
│
├── Features/                   UI features (SwiftUI Views + ViewModels)
│   ├── AuthenticationFeature/  Sign-in, register, forgot password, phone OTP, guest
│   ├── DashboardFeature/       Home dashboard, calorie goal, daily completion banner
│   ├── ExerciseCameraAnalysisFeature/   ← PRIMARY FEATURE (see below)
│   ├── AICoachChatFeature/     Groq-powered AI coaching chat
│   ├── CalorieTrackingFeature/ Apple Health calorie data
│   ├── WorkoutRecommendationsFeature/
│   ├── AnalyticsFeature/
│   └── SettingsFeature/
│
├── Services/                   Concrete implementations
│   ├── AuthenticationService/  Firebase auth, phone OTP, session management
│   ├── HealthKitService/       LiveHealthKitService (UserDefaults flag for read-only HK)
│   ├── VisionMLService/        ← ML + CV pipeline (see below)
│   └── WorkoutRecommendationService/
│
├── Infrastructure/             Cross-cutting: networking, logging, persistence, security
│
└── Tests/                      Unit tests per module
```

---

## Camera / ML Pipeline (Critical)

### Architecture (from lesson PDF)
```
AVCaptureSession (AVFoundation)
  ↓
CVPixelBuffer → VNDetectHumanBodyPoseRequest (Vision — on-device, offline)
  ↓
VNHumanBodyPoseObservation
  ↓  ← joint name mapping: "left_upLeg_joint" → "left_hip" etc.
BodyPoseSample [jointPositions: [String: PosePoint], jointConfidences]
  ↓
┌──────────────────────────────────────────────────────────┐
│  Step 1: Exercise Classification                         │
│  • ActionClassifierService (60-frame sliding window)     │  ← ML model
│    MyActionClassifier.mlmodel (ST-GCN, Create ML)       │
│    classes: none|others|squat_correct|squat_too_shallow  │
│             |squat_torse_lean                            │
│  • Falls back to ExercisePoseClassifier (rule-based)     │
│    for push-up, jumping jack, pull-up, sit-up            │
└──────────────────────────────────────────────────────────┘
  ↓
┌──────────────────────────────────────────────────────────┐
│  Step 2: Form Feedback                                   │
│  • ML label → ExerciseFormFeedback (squat only)          │
│  • Rule-based ruleBasedFeedback() for everything else    │
│  • PoseFeatureExtractor → PoseFeatures (angles, lean)    │
│  • AngleSmoother × 4 (knee L/R, hip, torso)             │
└──────────────────────────────────────────────────────────┘
  ↓
ExerciseAnalysis {classification, coachingCue, poseJointPositions, formFeedback, movementPhase}
  ↓
ExerciseCameraAnalysisViewModel
  ↓
RepTracker (state machine: top→bottom→top = 1 rep)
  ↓
SkeletonOverlayView (SwiftUI Canvas) + SpeechCoach (AVSpeechSynthesizer)
```

### Key Files — VisionMLService

| File | Purpose |
|------|---------|
| `VisionExerciseAnalysisService.swift` | Main actor; runs Vision request, feeds ML window, calls classifiers |
| `ActionClassifierService.swift` | Actor; 60-frame sliding window → MyActionClassifier.mlmodel |
| `MyActionClassifier.mlmodel` | ST-GCN trained with Create ML (3.9 MB) |
| `ExercisePoseClassifier.swift` | Rule-based fallback classifier for non-squat exercises |
| `PoseFeatureExtractor.swift` | Extracts PoseFeatures (angles, torso lean) from BodyPoseSample |
| `CoreMLFormClassifier.swift` | Bridge between PoseFeatures and form feedback (rule-based backend A) |
| `GroqCoachingService.swift` | Groq API (fire-and-forget background task, never blocks camera) |

### Key Files — ExerciseCameraAnalysisFeature

| File | Purpose |
|------|---------|
| `ExerciseCameraAnalysisView.swift` | Main hub + FullScreenCameraView (full-screen camera modal) |
| `ExerciseCameraAnalysisViewModel.swift` | @MainActor; rep counting, daily reps, voice trigger |
| `CameraCaptureController.swift` | AVCaptureSession wrapper; start/stop/pause/resume/switchCamera |
| `CameraPreviewView.swift` | UIViewRepresentable wrapping AVCaptureVideoPreviewLayer |
| `SkeletonOverlayView.swift` | SwiftUI Canvas drawing bones + joint dots (always shown, even low confidence) |
| `SpeechCoach.swift` | AVSpeechSynthesizer wrapper for TTS voice coaching |

---

## Camera View Layout (iPhone X — full screen)

```
┌────────────────────────────────────┐  ← below notch (44 pt safe area)
│  [✕]      ⏱ 02:34      [🔊/🔇]  │  ← top bar (no .ignoresSafeArea)
│                                    │
│         CAMERA LIVE                │  ← AVCaptureVideoPreviewLayer (full bleed)
│       + SKELETON OVERLAY           │  ← SkeletonOverlayView on Canvas
│                                    │
├────────────────────────────────────┤
│ [Squat][PushUp][PullUp]..   [🔄] │  ← exercise chips + flip camera
│ [Going down]  [Too Shallow]    42 │  ← phase chip + form chip + rep count
│ "Lower your hips more..."         │  ← coaching cue
│ [⏸ Pause]  [⏹ Stop]   [☁️]    │  ← controls (50 pt tall)
└────────────────────────────────────┘  ← material extends behind home indicator
```

**Important**: ZStack has NO `.ignoresSafeArea` — background layers individually ignore safe areas so they go full-bleed, but HUD VStack naturally stays below notch.

---

## Vision Orientation (Critical Bug — Fixed)

iPhone camera delivers pixel buffers in LANDSCAPE natively. We dynamically detect orientation:

```swift
let isLandscape = CVPixelBufferGetWidth(buf) > CVPixelBufferGetHeight(buf)
if isLandscape {
    orientation = isFrontCamera ? .leftMirrored : .right
} else {
    // AVCaptureVideoDataOutput already rotated to portrait
    orientation = isFrontCamera ? .upMirrored : .up
}
```

---

## Vision Joint Name Mapping (Critical Bug — Fixed)

Apple Vision uses verbose internal names. All downstream code uses short names. `visionJointMap` bridges them:

```
"left_upLeg_joint"     → "left_hip"
"left_leg_joint"       → "left_knee"
"left_foot_joint"      → "left_ankle"
"left_shoulder_1_joint"→ "left_shoulder"
"left_forearm_joint"   → "left_elbow"
"left_hand_1_joint"    → "left_wrist"
... (18 joints total)
```

---

## ML Model — MyActionClassifier.mlmodel

- **Architecture**: ST-GCN (Spatial-Temporal Graph Convolutional Network)
- **Trained**: Create ML, 2026-06-09
- **Input**: `poses` — MLMultiArray `[60, 3, 18]` (60 frames × x/y/conf × 18 joints)
- **Output**: `label` (String) + `labelProbabilities` ([String: Double])
- **Classes**: `none` | `others` | `squat_correct` | `squat_too_shallow` | `squat_torse_lean`
  - ⚠️ Note: class name is `squat_torse_lean` (typo from training data, NOT "torso")
- **Window**: 60 frames = 30 FPS × 2 seconds
- **Confidence threshold**: ≥ 0.55 to override rule-based classifier
- **Keypoint order** (dim 2): nose, neck, right shoulder, right elbow, right wrist, left shoulder, left elbow, left wrist, right hip, right knee, right ankle, left hip, left knee, left ankle, right eye, left eye, right ear, left ear

---

## Authentication

- **Firebase Auth**: email/password, Google Sign-In, phone OTP
- **Guest mode**: "Continue without account" button bypasses auth
- **Phone OTP**: `PhoneAuthProvider.provider().verifyPhoneNumber`, simulator uses `"simulator-verification-id"` / any OTP except `"000000"` passes
- **Wrong password**: maps `.invalidCredential` → `.wrongPassword`
- **Duplicate email**: shows "Sign In Instead" + "Reset Password" smart actions
- **Error handling**: `ShakeEffect: GeometryEffect` shake animation on error

---

## HealthKit

- **Read-only** — app never writes health data
- **Auth bug fixed**: `healthStore.authorizationStatus(for:)` always returns `.sharingDenied` for read-only types (Apple privacy design). Use `UserDefaults("healthkit.hasAuthorized")` flag instead — set to `true` after first `requestAuthorization` call completes.

---

## Groq API

- **Key**: stored in `App/Configurations/Debug.xcconfig` — never committed (xcscheme removed, xcschemes in `.gitignore`)
- **Usage**: AI Coach Chat tab only — NOT in camera hot path
- **Camera integration**: fire-and-forget `Task.detached(priority: .background)` — result discarded; `defaultCue()` used immediately
- **Reason**: 8-second timeout would freeze camera frames when offline

---

## Voice Coaching (TTS)

- **Class**: `SpeechCoach` wrapping `AVSpeechSynthesizer`
- **Audio session**: `.playback` + `.duckOthers` (mixes with music, ducks slightly)
- **Rep announcement**: speaks count on every rep increment (1 s cooldown, interrupts current speech)
- **Form cues**: speaks only `tooShallow` / `torsoLean` / `kneeIssue` (4 s cooldown, skips if speech active within 1.5 s)
- **Toggle**: `voiceGuidanceEnabled: Bool` — speaker icon in camera top bar
- **Stop**: auto-stopped in `resetCameraSession()`

---

## Rep Counting

State machine in `RepTracker` (inside ViewModel):

| Exercise | Primary angle | Bottom threshold | Top threshold |
|----------|--------------|-----------------|---------------|
| Squat | avg knee | 110° | 150° |
| Push-up | avg elbow | 90° | 150° |
| Pull-up | avg elbow | 110° | 155° |
| Sit-up | avg hip | 80° | 140° |
| Jumping jack | ankle spread | 0.20 (normalized) | 0.08 |

`selectedExercise` (user's choice) always drives rep counting — NOT `detectedExercise` from classifier.

Daily reps persist to `UserDefaults` and reset at midnight (checked via `"camera.lastActiveDate"` key).

---

## Daily Goal Completion

- `DashboardViewModel.markGoalCompletedIfNeeded(ratio:)` — persists `"goal.completedDate"` as `"yyyy-MM-dd"` when ratio ≥ 1.0
- `restoreGoalCompletion()` — on init + `load()`, compares stored date to today
- UI: gold `🏆` banner at top of dashboard; "Goal Complete ✓" green pill on calorie card

---

## Key Design Decisions

1. **Offline first**: Vision body-pose is fully on-device; Groq removed from camera path
2. **selectedExercise drives everything**: user picks exercise; classifier only provides form feedback
3. **Skeleton always shown**: `rawPositions` forwarded in all confidence paths (including very low) so user can reposition
4. **Actor isolation**: `VisionExerciseAnalysisService` and `ActionClassifierService` are both `actor`; cross-actor calls use `await`
5. **ML + rules hybrid**: ML model for squat form pattern recognition; rule-based for angles/verification and all other exercises
6. **Confidence bands**: 0.50 (full) / 0.25 (partial) — lowered from original 0.65/0.40 for iPhone X indoor lighting

---

## Security Notes

- ⚠️ `*.xcodeproj/xcshareddata/xcschemes/` added to `.gitignore` — prevents API key leaks from Xcode scheme environment variables
- Groq API key is in `Debug.xcconfig` only (not in any committed file)
- GitHub push protection was triggered once (xcscheme with key was in a commit); fixed with `git rm --cached` + force push

---

## Commit History

```
0927b2d  Add real-time voice coaching (TTS)
d305919  Integrate MyActionClassifier.mlmodel (ST-GCN)
e7a7e0a  Fix body detection + iPhone X notch/thumb-reach issues
3f3fec9  Redesign camera: full-screen immersive mode
30a2e83  Make live camera fully offline; fix rep counting
13e1cce  Add skeleton overlay, pause/stop, fix HealthKit + Vision joints
3e4d832  Fix HealthKit auth, Vision joint names, front/back camera
95277db  Add Skip / Continue as Guest button
7963d4c  Initial commit
```

---

## Local Setup

```bash
cd /Users/JujuOnTheBeat/Documents/fitness_project
open FitnessCoach.xcodeproj
# Scheme: FitnessCoach
# Signing: Juan Javier (personal team)
# Run on: iPhone (real device) — camera features require hardware
```

Build command:
```bash
xcodebuild -scheme FitnessCoach -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build
```
