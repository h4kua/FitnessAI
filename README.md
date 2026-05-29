# FitnessAI — AI-Powered iOS Fitness Coach

[![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue?logo=apple)](https://developer.apple.com/ios/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-yellow?logo=firebase)](https://firebase.google.com)
[![Groq](https://img.shields.io/badge/AI%20Coaching-Groq%20LLM-purple)](https://console.groq.com)

A real-time iOS fitness coaching app that combines Apple Vision on-device pose detection, Groq AI coaching cues, Firebase authentication, and Apple Health integration to deliver personalised workout guidance.

---

## Features

| Feature | Details |
|---|---|
| **Real-time form feedback** | Vision framework detects body pose at 5 fps; rule-based classifier flags depth, torso lean, and knee asymmetry |
| **Rep counting** | Automatic squat / push-up / pull-up / sit-up / jumping-jack rep counter with per-exercise daily totals |
| **Session timer** | Live MM:SS timer on the camera overlay, auto-reset every midnight |
| **AI coaching cues** | Groq LLM generates personalised cues when form is acceptable; rule-based cues fire immediately for critical issues |
| **Firebase Auth** | Email/password, Google Sign-In, and phone-number OTP — full registration, login, forgot-password, and duplicate-account detection |
| **Firestore sync** | User profile and workout sessions saved to Firestore; secure rules enforced per UID |
| **Apple Health** | Reads active energy burned; calorie ring on the dashboard auto-resets each day |
| **Daily goal tracking** | "🏆 Daily Goal Achieved!" banner and persistent completion badge; resets at midnight |
| **Workout recommendations** | On-device recommendation engine surfaces a daily workout based on remaining calorie budget and user goal |
| **Multi-goal programmes** | Lose fat / build muscle / athletic / maintain — 90-day progressive plan with rest-day detection |
| **Settings & onboarding** | Body profile, activity level, goal picker, calorie goal adjustment |

---

## Screenshots

> _Add your own screenshots here after first run._

---

## Architecture

```
FitnessCoach/
├── App/                        # App entry point, dependency wiring
│   └── Configurations/
│       ├── Debug.xcconfig      # 🔒 gitignored — copy from .template
│       └── Release.xcconfig
├── Core/                       # Domain models + protocol interfaces
│   ├── Domain/                 # ExerciseAnalysis, UserProfile, CalorieSummary …
│   └── Interfaces/             # AuthenticationProviding, HealthDataProviding …
├── Features/                   # SwiftUI MVVM feature modules
│   ├── AuthenticationFeature/  # Sign-in, register, forgot password, phone OTP
│   ├── DashboardFeature/       # Hero banner, calorie ring, goal completion
│   ├── ExerciseCameraAnalysis/ # Live camera, rep counter, form feedback
│   ├── AICoachChatFeature/     # Groq chat interface
│   └── SettingsFeature/        # Body profile, goal, calorie target
├── Services/                   # Concrete service implementations
│   ├── AuthenticationService/  # Firebase + Session + Remote auth
│   ├── VisionMLService/        # Pose detection, feature extraction, rule engine
│   └── WorkoutRecommendation/  # On-device recommendation engine
├── Infrastructure/             # Networking, persistence, logging, config
├── DesignSystem/               # FitnessTheme, typography, reusable components
├── crew_backend/               # Optional Python CrewAI backend (Groq multi-agent)
└── Tests/
```

**Pattern:** single Xcode target, `#if canImport()` for optional platform modules, `actor`-based services, `@MainActor` ViewModels, async/await throughout.

---

## Getting Started

### Prerequisites

- Xcode 14.3+ (tested on Xcode 14.3.1, macOS Ventura)
- iOS 16.0+ device or simulator
- A free [Firebase project](https://console.firebase.google.com) with Auth + Firestore enabled
- A free [Groq API key](https://console.groq.com/keys)

### 1 — Clone

```bash
git clone https://github.com/h4kua/FitnessAI.git
cd FitnessAI
```

### 2 — Add Firebase credentials

```bash
cp GoogleService-Info.plist.template GoogleService-Info.plist
# Open GoogleService-Info.plist and replace placeholders with your Firebase project values
# (Firebase Console → Project Settings → iOS app → download GoogleService-Info.plist)
```

### 3 — Add your Groq API key

```bash
cp App/Configurations/Debug.xcconfig.template App/Configurations/Debug.xcconfig
# Open Debug.xcconfig and set:
#   GROK_ENV = gsk_YourActualKeyHere
```

### 4 — Firebase setup

In [Firebase Console](https://console.firebase.google.com):

1. **Authentication → Sign-in methods** — enable Email/Password, Google, and Phone.
2. **Firestore Database** — create a database, then set these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

3. **For phone OTP on a real device** — upload an APNs Auth Key under Project Settings → Cloud Messaging. For the Simulator, add test phone numbers under Authentication → Sign-in methods → Phone → Test phone numbers.

### 5 — Open & run

```bash
open FitnessCoach.xcodeproj
```

Select a simulator or connected device, then **⌘R**.

---

## Authentication flows

| Method | Notes |
|---|---|
| Email + Password | Full registration with password-strength rules; forgot-password email; duplicate-account inline actions |
| Google Sign-In | `GIDSignIn` → Firebase credential |
| Phone OTP | `PhoneAuthProvider` → 6-digit code screen; Simulator test mode built-in |

---

## AI Coaching — Groq

Coaching cues are generated by `llama3-8b-8192` via the Groq REST API.  
The key is read from `GROK_ENV` in `Info.plist` → `AppEnvironment.live()`.  
The `VisionExerciseAnalysisService` only calls Groq when:
- pose confidence ≥ 55 %
- no critical form issue is already flagged (rule-based cues take priority)

---

## Optional Python Backend (CrewAI)

`crew_backend/` contains a multi-agent CrewAI pipeline that can generate structured workout plans and safety checks.

```bash
cd crew_backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # add your GROQ_API_KEY
python main.py
```

---

## Environment Variables

| Variable | Where | Description |
|---|---|---|
| `GROK_ENV` | `Debug.xcconfig` | Groq API key for AI coaching cues |
| `GROQ_API_KEY` | `crew_backend/.env` | Groq key for the Python backend |

---

## Contributing

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes
4. Open a pull request

---

## License

MIT © 2024 Juan Javier — see [LICENSE](LICENSE) for details.
