# FitnessCoach CrewAI Backend

Multi-agent AI server for the FitnessCoach iOS app. Uses **CrewAI** with the
**Groq LLM** (llama-3.3-70b-versatile) to provide deeper workout analysis that
doesn't need to run in real-time.

## Agents

| Agent | Role |
|-------|------|
| Health Specialist | Validates safety of workout sessions and plans |
| Personal Coach | Generates personalized coaching feedback |
| Weekly Planner | Creates balanced 7-day workout programs |

## Setup

Requires Python 3.10–3.13 (CrewAI does not yet support Python 3.14).

```bash
# From the crew_backend/ directory:
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The `.env` in the project root must contain:

```
GROK_ENV=gsk_your_groq_api_key_here
```

## Run

```bash
cd crew_backend
source .venv/bin/activate
uvicorn main:app --reload --port 8000
```

## API Endpoints

### `GET /health`
Returns server status.

### `POST /session/review`
After a workout session, health + coaching agents collaborate on a review.

```json
{
  "exercise": "Squat",
  "duration_minutes": 20,
  "estimated_calories": 180.0,
  "rep_count": 24,
  "coaching_cue": "Push your knees out and keep your chest proud.",
  "confidence": 0.87
}
```

Response:
```json
{
  "review": "Great effort on the squats! For next time, try pausing 1 second at the bottom position to build more strength."
}
```

### `POST /workout/weekly-plan`
Generates a balanced 7-day plan using all three agents.

```json
{
  "target_calories_per_day": 600.0,
  "available_minutes_per_session": 30,
  "preferred_intensity": "moderate",
  "recent_session_titles": ["Bodyweight Squat", "Brisk Walk"]
}
```

## iOS App Integration

The iOS app can call this backend for non-real-time features:

- After a workout session → `POST /session/review`
- Weekly plan screen → `POST /workout/weekly-plan`

The backend URL defaults to `http://localhost:8000` when running locally.
Set `CREW_BACKEND_URL` in your Xcode scheme environment variables to point
at a remote server.

## Privacy

The backend **never** receives:
- Camera images or video
- HealthKit data (raw active energy history)
- Any personally identifiable information

It receives only: exercise name, duration, estimated calories, rep count,
and a confidence score.
