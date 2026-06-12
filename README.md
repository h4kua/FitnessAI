# FitnessAI — AI-Powered iOS Fitness Coach

[![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue?logo=apple)](https://developer.apple.com/ios/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-yellow?logo=firebase)](https://firebase.google.com)
[![Groq](https://img.shields.io/badge/AI%20Coach-Groq%20Llama--3-purple)](https://console.groq.com)
[![Vision](https://img.shields.io/badge/Apple-Vision%20Framework-lightgrey?logo=apple)](https://developer.apple.com/documentation/vision)

A fully offline-capable iOS fitness coaching app that combines Apple Vision on-device pose detection, a custom ST-GCN machine learning model for squat form recognition, real-time voice coaching, Groq AI chat, Firebase authentication, Apple HealthKit integration, and an exercise video tutorial library — all in a single dark-themed SwiftUI app.

---

## Feature Overview

| Feature | Description |
|---|---|
| **Real-time form analysis** | Vision framework detects 18 body joints at ~20 fps; rule-based + ML classifier flags Too Shallow, Torso Lean, and Knee Issue |
| **ST-GCN ML model** | Custom `MyActionClassifier.mlmodel` trained with Create ML on squat data; 60-frame sliding window; classes: `squat_correct`, `squat_too_shallow`, `squat_torse_lean` |
| **Rep counting** | Automatic rep counter for Squat (form-gated 3-phase), Push-Up, Pull-Up, Sit-Up, Jumping Jack, and Plank (hold seconds) |
| **Voice coaching** | `AVSpeechSynthesizer` speaks short labels aloud ("Too Shallow", "Torso Lean", "Knee Issue") in sync with the on-screen popup |
| **Form feedback popup** | Prominent popup with large label + coaching cue; spring-scale transition; color-coded by severity |
| **AI coaching chat** | Groq Llama-3 powered chat coach; context-aware (knows exercise, form, and user goal) |
| **Exercise tutorials** | Video library with 23 exercises across 4 categories (Jumping Jack, Push Up, Pull Up, Sit Up); front/side angle toggle; looping AVPlayer |
| **Training + Nutrition plan** | Combined tab with segmented control to switch between AI-matched workout recommendations and calorie/nutrition tracking |
| **Firebase authentication** | Email/password, Google Sign-In, phone OTP, guest mode — full registration, login, forgot-password, duplicate-account detection |
| **Firestore sync** | Workout sessions saved to Firestore per UID; secure server-side rules |
| **Apple HealthKit** | Reads active energy burned; daily calorie ring on dashboard; read-only (never writes health data) |
| **Daily goal tracking** | 🏆 banner and persistent badge when daily calorie goal is reached; resets at midnight |
| **90-day training programme** | Lose Fat / Build Muscle / Athletic / Maintain goals; rest-day detection; day-by-day progress |
| **Onboarding** | 4-step body profile setup (height, weight, age, gender → activity level → goal → timeline) |
| **Analytics / Privacy** | Shows only anonymised data the user generated; no third-party tracking |

---

## Screenshots

> _Run the app on a device and add your own screenshots here._

---

## Architecture

### Project Structure

```
FitnessCoach/
├── App/
│   ├── Sources/AppFeature/         AppRootView, AppShellViewModel, AppDependencies, MainTabView
│   ├── Resources/                  Assets.xcassets
│   ├── Supporting/                 Info.plist, FitnessCoach.entitlements
│   └── Configurations/
│       ├── Debug.xcconfig          🔒 gitignored — add GROK_ENV here
│       └── Release.xcconfig
│
├── Core/                           Pure Swift domain layer — no frameworks
│   ├── Domain/                     DetectedExercise, ExerciseAnalysis, ExerciseFormFeedback,
│   │                               BodyPoseSample, PosePoint, UserProfile, CalorieSummary,
│   │                               WorkoutPlan, WorkoutSessionSummary, …
│   └── Interfaces/                 ExerciseAnalysisProviding, AuthenticationProviding,
│                                   HealthDataProviding, WorkoutRecommendationProviding, …
│
├── DesignSystem/                   FitnessTheme, FitnessTypography, FitnessSpacing,
│                                   FitnessCard, GradientCard, MetricBadge, ScreenStateCard,
│                                   CircularProgressView, PrimaryActionButtonStyle
│
├── Features/
│   ├── AuthenticationFeature/      AuthenticationView, AuthenticationViewModel, OnboardingView
│   ├── DashboardFeature/           DashboardView, DashboardViewModel
│   ├── ExerciseCameraAnalysisFeature/  ← primary feature
│   │   ├── ExerciseCameraAnalysisView.swift   (hub + FullScreenCameraView + form popup)
│   │   ├── ExerciseCameraAnalysisViewModel.swift  (@MainActor, rep counter, voice)
│   │   ├── CameraCaptureController.swift      (AVCaptureSession, 20fps, .medium)
│   │   ├── CameraPreviewView.swift            (AVCaptureVideoPreviewLayer)
│   │   ├── SkeletonOverlayView.swift          (SwiftUI Canvas, EMA-smoothed joints)
│   │   └── SpeechCoach.swift                  (AVSpeechSynthesizer wrapper)
│   ├── AICoachChatFeature/         CoachChatView, CoachChatViewModel
│   ├── CalorieTrackingFeature/     CalorieTrackingView, CalorieTrackingViewModel
│   ├── WorkoutRecommendationsFeature/ WorkoutRecommendationsView, WorkoutRecommendationsViewModel
│   ├── ExerciseTutorialFeature/    ExerciseTutorialView (browse + player)
│   ├── AnalyticsFeature/           AnalyticsView, AnalyticsViewModel
│   └── SettingsFeature/            SettingsView, SettingsViewModel
│
├── Services/
│   ├── VisionMLService/            VisionExerciseAnalysisService, ActionClassifierService,
│   │                               MyActionClassifier.mlmodel, ExercisePoseClassifier,
│   │                               PoseFeatureExtractor, CoreMLFormClassifier, GroqCoachingService
│   ├── AuthenticationService/      FirebaseAuthenticationService, FirebaseWorkoutSessionStore
│   ├── HealthKitService/           LiveHealthKitService
│   └── WorkoutRecommendationService/ WorkoutRecommendationEngine, ApiNinjasExerciseCatalogService
│
├── Infrastructure/                 URLSessionHTTPClient, AppLogger, AppEnvironment,
│                                   UserDefaultsSettingsStore, KeychainSessionStore
│
├── DataVideo/                      MP4 exercise tutorials (front + side angle per exercise)
│   ├── JumpingJack/                3 exercises × 2 angles = 6 videos
│   ├── PushUp/                     6 exercises × 2 angles = 12 videos
│   ├── PullUp/                     8 exercises × 2 angles = 16 videos
│   └── SitUp/                      6 exercises × 2 angles = 12 videos
│
├── crew_backend/                   Optional Python CrewAI multi-agent backend
└── Tests/                          Unit tests per module
```

### Design Pattern

- **MVVM** — every screen has a `View` + `@MainActor ObservableObject ViewModel`
- **Single Xcode target** — all modules compiled together; `#if canImport()` guards for optional dependencies
- **`actor`-based ML services** — `VisionExerciseAnalysisService` and `ActionClassifierService` are Swift `actor` types; cross-actor calls use `await`
- **Dependency injection** — `AppDependencies` wires all services at app launch; ViewModels receive protocols, never concrete types

---

## Tab Navigation

| Tab | Label | Screen |
|-----|-------|--------|
| 0 | Home | Dashboard (calorie ring, daily goal, recent sessions) |
| 1 | Plan | MyPlanView — segmented: **Training** / **Nutrition** |
| 2 | Form | Exercise Camera Analysis (live pose + rep counter) |
| 3 | Coach | AI Coaching Chat (Groq Llama-3) |
| 4 | Profile | Settings (body profile, goal, calorie target) |
| 5 | Privacy | Analytics (anonymised usage data) |
| 6 | Tutorial | Exercise Video Library (23 exercises, front/side toggle) |

---

## Camera & ML Pipeline

```
AVCaptureSession (.medium preset, 20 fps cap)
  ↓ CVPixelBuffer
VNDetectHumanBodyPoseRequest  (on-device, offline)
  ↓ selectBestObservation()  — sticky centroid tracking (multi-person safe)
  ↓ EMA position smoother (α = 0.60)
BodyPoseSample [18 joints]
  ↓
┌─────────────────────────────────────────────────┐
│  ActionClassifierService                        │
│  60-frame sliding window → MyActionClassifier   │  ← ST-GCN ML model
│  classes: none | others | squat_correct         │
│           squat_too_shallow | squat_torse_lean  │
│  Confidence threshold: ≥ 0.55                   │
└─────────────────────────────────────────────────┘
  ↓ formFeedback (ML + rule-based hybrid)
ExerciseAnalysis { coachingCue, formFeedback, movementPhase, jointAngles }
  ↓
ExerciseCameraAnalysisViewModel (@MainActor)
  ├── RepTracker  (3-phase state machine for squat; 2-phase for others)
  ├── SpeechCoach (speaks "Too Shallow" / "Torso Lean" / "Knee Issue")
  └── Form popup  (large label + coaching cue, spring-scale transition)
  ↓
SkeletonOverlayView (SwiftUI Canvas)  +  FullScreenCameraView HUD
```

### ML Model — `MyActionClassifier.mlmodel`

| Property | Value |
|----------|-------|
| Architecture | ST-GCN (Spatial-Temporal Graph Convolutional Network) |
| Trained with | Create ML |
| Input | `poses` MLMultiArray `[60, 3, 18]` (60 frames × x/y/confidence × 18 joints) |
| Output | `label` (String) + `labelProbabilities` ([String: Double]) |
| Classes | `none` · `others` · `squat_correct` · `squat_too_shallow` · `squat_torse_lean` |
| Confidence threshold | ≥ 0.55 to override rule-based classifier |
| Model size | ~3.9 MB |

> ⚠️ The class name is `squat_torse_lean` (typo from training data — NOT "torso"). The code maps this correctly.

---

## Rep Counting

### Squat — 3-Phase Form-Gated Counter

```
.top        (knee ≥ 150°)  — reset accumulators: badFormEverSeen=false, reachedDepth=false
.descending (100°–150°)    — accumulate form errors; tooShallow fires at 120–150°
.bottom     (knee ≤ 100°)  — reachedDepth=true; still accumulate form errors
.top (from .bottom)        — count rep ONLY IF reachedDepth=true AND badFormEverSeen=false
```

A squat rep is counted only when the user reaches proper depth **AND** maintains correct form throughout. Any `tooShallow`, `torsoLean`, or `kneeIssue` at any point in the cycle disqualifies the rep.

### Other Exercises

| Exercise | Method | Bottom threshold | Top threshold |
|----------|--------|-----------------|---------------|
| Push-Up | avg elbow angle | 145° | 152° |
| Pull-Up | avg elbow angle | 125° | 155° |
| Sit-Up | avg hip angle | 115° | 150° |
| Jumping Jack | ankle spread (normalised) | 0.14 | 0.24 |
| Plank | stability score | hold time in seconds | — |

---

## Voice Coaching

- **Engine**: `AVSpeechSynthesizer` wrapped in `SpeechCoach`
- **Audio session**: `.playback` + `.duckOthers` — plays over music, ducks it slightly
- **What it says**: short labels that match the on-screen popup exactly:
  - Rep completed → speaks the count (e.g. "5")
  - Too Shallow detected → speaks **"Too Shallow"**
  - Torso Lean detected → speaks **"Torso Lean"**
  - Knee Issue detected → speaks **"Knee Issue"**
- **Debounce**: rep count has 1 s dedup; form cues have 4 s same-text dedup and wait 1.5 s after any rep announcement
- **Toggle**: speaker icon in the camera top bar

---

## Form Feedback Popup

Shown below the top bar whenever a form error is active. Hides automatically when form improves.

| Feedback | Colour | Label |
|----------|--------|-------|
| `tooShallow` | Orange | **Too Shallow** |
| `torsoLean` | Orange | **Torso Lean** |
| `kneeIssue` | Orange | **Knee Issue** |
| `bodyNotVisible` | Dark | Repositioning cue |
| `lowConfidence` | Dark | Lighting/position cue |
| `goodForm` | Hidden | — |

---

## Exercise Tutorial Library

A video browser backed by the `DataVideo/` bundle folder.

| Category | Exercises |
|----------|-----------|
| **Jumping Jack** | Criss-Cross Jacks, Jumping Jacks, Medicine Ball Press Jack |
| **Push Up** | Push-Up, Decline, Diamond, Incline, Weighted Diamond, Weighted |
| **Pull Up** | Pull-Up, Assisted, L-Sit, Ring, Dumbbell Weighted, Machine (Narrow + Regular), Plate Weighted |
| **Sit Up** | Sit-Up, Barbell, Dumbbell, Kettlebell, Plate, Smith Machine |

Each exercise has a **Front View** and **Side View** MP4. Videos loop automatically. The player uses `AVPlayer` via SwiftUI's `VideoPlayer`.

---

## Getting Started

### Requirements

- Xcode 14.3+ (tested on Xcode 14.3.1)
- macOS Ventura or later
- iOS 16.0+ device or simulator
- A [Firebase project](https://console.firebase.google.com) with **Authentication** and **Firestore Database** enabled
- A free [Groq API key](https://console.groq.com/keys) for AI coaching

### 1 — Clone

```bash
git clone https://github.com/h4kua/FitnessAI.git
cd FitnessAI
open FitnessCoach.xcodeproj
```

### 2 — Firebase credentials

Download your `GoogleService-Info.plist` from Firebase Console → Project Settings → Your iOS app, then place it at the project root:

```bash
cp GoogleService-Info.plist.template GoogleService-Info.plist
# Replace all placeholder values with your Firebase project values
```

### 3 — Groq API key

Create `App/Configurations/Debug.xcconfig` and add your key:

```
GROK_ENV = gsk_YourKeyHere
```

This file is gitignored. The key is read via `AppEnvironment.live()` → `Info.plist` substitution at build time.

### 4 — Firebase setup

In [Firebase Console](https://console.firebase.google.com):

**Authentication → Sign-in methods** — enable:
- Email/Password
- Google
- Phone

**Firestore Database** — set these security rules:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**For Phone OTP on simulator** — add test phone numbers under Authentication → Sign-in methods → Phone → Test phone numbers.

### 5 — Run

Select your target device in Xcode, then **⌘R**.

> **Note**: Camera features (pose detection, rep counting, voice coaching) require a **real device**. The simulator falls back to a sample-pose analyser.

---

## Environment Variables

| Variable | File | Purpose |
|----------|------|---------|
| `GROK_ENV` | `App/Configurations/Debug.xcconfig` | Groq API key for AI coaching chat and camera cues |
| `API_NINJAS_KEY` | Xcode scheme env vars | Optional — enables live exercise catalog from API Ninjas |

---

## Authentication Flows

| Method | Notes |
|--------|-------|
| Email / Password | Registration with duplicate-account detection; forgot-password email |
| Google Sign-In | `GIDSignIn` → Firebase credential exchange |
| Phone OTP | `PhoneAuthProvider` → 6-digit code screen; simulator test mode built-in |
| Guest / Skip | "Skip for now" continues as unauthenticated guest; all data stays local |

---

## AI Coaching — Groq

Chat coach is powered by `GroqCoachingService` calling `llama3-8b-8192` (or `llama3-70b-8192` for chat). The camera path uses a **fire-and-forget** `Task.detached(priority: .background)` so the AI call never blocks Vision processing. Form cues from the ML + rule-based engine fire immediately; Groq supplements with personalised cues when available.

---

## Optional Python Backend (CrewAI)

`crew_backend/` contains a multi-agent CrewAI pipeline for generating structured workout plans.

```bash
cd crew_backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # add GROQ_API_KEY
python main.py
```

---

## Build from Command Line

```bash
xcodebuild \
  -project FitnessCoach.xcodeproj \
  -scheme FitnessCoach \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug \
  build
```

---

## Key Technical Decisions

| Decision | Reason |
|----------|--------|
| Offline-first Vision pipeline | Groq removed from camera hot path — 8 s timeout would freeze frames |
| `selectedExercise` drives rep counting | Pose classifier lags human perception; user intent is ground truth |
| ST-GCN ML + rule-based hybrid | ML handles temporal patterns; rule-based `tooShallow` overrides ML `goodForm` when angle check is more reliable |
| `isVisionBusy` frame drop | Always processes the latest frame; never queues stale frames — prevents skeleton lag |
| EMA smoother (α = 0.60) | Reduces Vision joint noise without introducing visible lag |
| Sticky centroid tracking | Prevents skeleton jumping to a bystander in multi-person frames |
| 3-phase squat gate | `badFormEverSeen` + `reachedDepth` accumulators, never reset mid-rep — shallow squats cannot slip through even if they briefly touch depth |
| `AVSpeechSynthesizer.setActive(true)` on every speak | iOS silently deactivates the audio session after `stopSpeaking(at: .immediate)`; re-activating prevents silent failures on next call |
| Short voice labels ("Too Shallow") | Matches on-screen popup text exactly; faster to hear than full coaching sentences during exercise |

---

## Security Notes

- `*.xcodeproj/xcshareddata/xcschemes/` is in `.gitignore` — prevents Groq API key leaks from Xcode scheme environment variables
- `GoogleService-Info.plist` is gitignored; a `.template` file with placeholder values is committed instead
- `Debug.xcconfig` is gitignored

---

## License

MIT © 2026 Juan — see [LICENSE](LICENSE) for details.
