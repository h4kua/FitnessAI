"""
FitnessCoach CrewAI Backend
----------------------------
Runs a FastAPI server with three CrewAI agents (health, coaching, planner)
powered by the Groq LLM. The iOS app calls this server for deeper AI analysis
that doesn't need to run in real-time (session reviews, weekly plans).

Start:
    cd crew_backend
    pip install -r requirements.txt
    uvicorn main:app --reload --port 8000
"""

import os
from pathlib import Path
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from crewai import Agent, Task, Crew, LLM, Process

# Load .env from the project root (parent of crew_backend/)
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

GROQ_API_KEY = os.getenv("GROK_ENV")
if not GROQ_API_KEY:
    raise RuntimeError(
        "GROK_ENV is not set. Add it to .env in the project root:\n"
        "  GROK_ENV=gsk_your_key_here"
    )

# Groq via LiteLLM (CrewAI uses LiteLLM under the hood)
llm = LLM(
    model="groq/llama-3.3-70b-versatile",
    api_key=GROQ_API_KEY,
    temperature=0.6,
    max_tokens=512,
)

# ── Agents ────────────────────────────────────────────────────────────────────

from agents.health_agent   import build as build_health
from agents.coaching_agent import build as build_coaching
from agents.planner_agent  import build as build_planner

health_agent   = build_health(llm)
coaching_agent = build_coaching(llm)
planner_agent  = build_planner(llm)

# ── FastAPI ───────────────────────────────────────────────────────────────────

app = FastAPI(
    title="FitnessCoach CrewAI Backend",
    description="Multi-agent AI backend for the FitnessCoach iOS app.",
    version="1.0.0",
)


@app.get("/health")
def health_check():
    return {"status": "ok", "llm": "groq/llama-3.3-70b-versatile"}


# ── Request / Response schemas ────────────────────────────────────────────────

class SessionReviewRequest(BaseModel):
    exercise: str                    # e.g. "Squat"
    duration_minutes: int
    estimated_calories: float
    rep_count: int
    coaching_cue: str                # The last cue shown in the app
    confidence: float                # 0.0–1.0 pose confidence


class WeeklyPlanRequest(BaseModel):
    target_calories_per_day: float
    available_minutes_per_session: int
    preferred_intensity: str         # "low", "moderate", "high"
    recent_session_titles: list[str] # Last 7 sessions for novelty


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.post("/session/review")
def review_session(req: SessionReviewRequest):
    """
    After the user completes a workout session, the health agent and coaching
    agent collaborate to produce a brief session review and tip.
    """
    session_summary = (
        f"Exercise: {req.exercise}\n"
        f"Duration: {req.duration_minutes} minutes\n"
        f"Estimated calories burned: {int(req.estimated_calories)} kcal\n"
        f"Reps completed: {req.rep_count}\n"
        f"Last coaching cue shown: \"{req.coaching_cue}\"\n"
        f"Pose detection confidence: {int(req.confidence * 100)}%"
    )

    safety_review = Task(
        description=(
            f"Review this workout session for safety, realism, and quality:\n\n"
            f"{session_summary}\n\n"
            "Flag any concerns (e.g. too many reps at low confidence, unrealistic calorie burn). "
            "Keep your review to 3 bullet points."
        ),
        agent=health_agent,
        expected_output="3 brief bullet points: safety observations about the session.",
    )

    coaching_summary = Task(
        description=(
            f"Based on this session:\n\n{session_summary}\n\n"
            "Write one encouraging summary sentence (max 20 words) and one specific improvement tip "
            "for next time. Do not mention AI or sensors."
        ),
        agent=coaching_agent,
        expected_output="Two sentences: a celebration and a next-session tip.",
        context=[safety_review],
    )

    crew = Crew(
        agents=[health_agent, coaching_agent],
        tasks=[safety_review, coaching_summary],
        process=Process.sequential,
        verbose=False,
    )

    try:
        result = crew.kickoff()
        return {"review": str(result)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/workout/weekly-plan")
def generate_weekly_plan(req: WeeklyPlanRequest):
    """
    Generate a balanced 7-day workout plan using all three agents:
    planner drafts, health agent validates safety, coaching agent polishes.
    """
    context = (
        f"Daily calorie target: {int(req.target_calories_per_day)} kcal active energy\n"
        f"Session length: {req.available_minutes_per_session} minutes\n"
        f"Preferred intensity: {req.preferred_intensity}\n"
        f"Recent sessions (avoid repeating): {', '.join(req.recent_session_titles) or 'none'}"
    )

    draft_plan = Task(
        description=(
            f"Create a 7-day workout plan for this user:\n\n{context}\n\n"
            "Include rest days. For each active day, name the workout (e.g. 'Bodyweight Strength Circuit'), "
            "state duration, intensity, and 2-3 exercises. Format as a numbered list."
        ),
        agent=planner_agent,
        expected_output="A 7-day numbered workout plan with workout names, durations, and exercises.",
    )

    safety_check = Task(
        description=(
            "Review the 7-day plan for safety. Check for:\n"
            "- Back-to-back high-intensity days (flag and fix)\n"
            "- Missing rest days\n"
            "- Any exercises inappropriate for general fitness\n"
            "Return the corrected plan if changes were needed, or confirm it is safe."
        ),
        agent=health_agent,
        expected_output="Corrected 7-day plan with a one-line safety confirmation.",
        context=[draft_plan],
    )

    polish_plan = Task(
        description=(
            "Take the validated 7-day plan and rewrite each day's description in an encouraging, "
            "user-friendly tone. Add a one-sentence motivation note for each active day. "
            "Keep the format clean and easy to read on a phone screen."
        ),
        agent=coaching_agent,
        expected_output="A polished 7-day plan with motivational notes, ready to display in the app.",
        context=[safety_check],
    )

    crew = Crew(
        agents=[planner_agent, health_agent, coaching_agent],
        tasks=[draft_plan, safety_check, polish_plan],
        process=Process.sequential,
        verbose=False,
    )

    try:
        result = crew.kickoff()
        return {"plan": str(result)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
