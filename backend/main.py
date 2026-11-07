"""Dekad backend: LLM-powered helpers for professional networking."""

import json
import logging
import os
from contextlib import asynccontextmanager
from typing import Any, Literal

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ValidationError

load_dotenv()

logger = logging.getLogger("dekad")

ROUTELLM_API_KEY = os.getenv("ROUTELLM_API_KEY", "")
ROUTELLM_BASE_URL = os.getenv("ROUTELLM_BASE_URL", "https://routellm.abacus.ai/v1").rstrip("/")
MODEL_NAME = os.getenv("MODEL_NAME", "gpt-4.1-mini")
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()]

SYSTEM_PROMPT = (
    "You are a Networking Guide helping professionals enhance their networking "
    "effectiveness. Give concise, actionable suggestions that improve how people "
    "connect and communicate professionally. Be direct and stay focused on the "
    "specific task requested. Always reply with a single JSON object that matches "
    "the schema you are given, and nothing else."
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http = httpx.AsyncClient(timeout=httpx.Timeout(30.0))
    yield
    await app.state.http.aclose()


app = FastAPI(title="Dekad API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------- Models ----------

class BioRewriteRequest(BaseModel):
    raw_bio: str = Field(min_length=1, max_length=4000)
    mode: Literal["professional", "personal"]
    max_length: int = Field(default=200, ge=20, le=1000)


class BioRewriteResponse(BaseModel):
    rewritten_bio: str


class BadgeTextRequest(BaseModel):
    badge_id: str
    event_context: str = Field(min_length=1, max_length=2000)
    user_role: str = Field(min_length=1, max_length=200)


class BadgeTextResponse(BaseModel):
    badge_id: str
    title: str
    message: str
    cta: str
    tone: str


class FollowUpRequest(BaseModel):
    contact_id: str
    previous_conversation: str = Field(min_length=1, max_length=8000)
    last_meeting_date: str


class FollowUpResponse(BaseModel):
    contact_id: str
    suggested_message: str
    send_channel: Literal["email", "linkedin", "sms", "whatsapp", "call"]
    delay_days: int = Field(ge=0, le=60)


class NotesSummaryRequest(BaseModel):
    notes: str = Field(min_length=1, max_length=8000)


class NotesSummaryResponse(BaseModel):
    summary_bullets: list[str]


# ---------- LLM helper ----------

async def ask_llm_json(prompt: str) -> dict[str, Any]:
    """Send a prompt to RouteLLM and return the reply parsed as a JSON object."""
    if not ROUTELLM_API_KEY:
        raise HTTPException(status_code=503, detail="ROUTELLM_API_KEY is not configured")

    try:
        response = await app.state.http.post(
            f"{ROUTELLM_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {ROUTELLM_API_KEY}"},
            json={
                "model": MODEL_NAME,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt},
                ],
            },
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
    except httpx.HTTPError as exc:
        logger.exception("LLM request failed")
        raise HTTPException(status_code=502, detail="LLM request failed") from exc
    except (KeyError, IndexError, ValueError) as exc:
        raise HTTPException(status_code=502, detail="Unexpected LLM response shape") from exc

    return parse_json_object(content)


def parse_json_object(text: str) -> dict[str, Any]:
    """Parse a JSON object, tolerating code fences or stray text around it."""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end < start:
        raise HTTPException(status_code=502, detail="LLM did not return JSON")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail="LLM returned invalid JSON") from exc


def build(model: type[BaseModel], data: dict[str, Any]) -> BaseModel:
    try:
        return model(**data)
    except ValidationError as exc:
        raise HTTPException(status_code=502, detail="LLM output did not match schema") from exc


# ---------- Routes ----------

@app.get("/health")
async def health():
    return {"status": "ok", "llm_configured": bool(ROUTELLM_API_KEY)}


@app.post("/api/bio-rewrite", response_model=BioRewriteResponse)
async def bio_rewrite(req: BioRewriteRequest):
    data = await ask_llm_json(
        f"Rewrite this bio for a {req.mode} profile in at most {req.max_length} characters.\n"
        'Schema: {"rewritten_bio": string}\n\n'
        f"Bio:\n{req.raw_bio}"
    )
    result = build(BioRewriteResponse, data)
    result.rewritten_bio = result.rewritten_bio.strip()[: req.max_length]
    return result


@app.post("/api/badge-text", response_model=BadgeTextResponse)
async def badge_text(req: BadgeTextRequest):
    data = await ask_llm_json(
        "Write short text for an event badge.\n"
        f"Event context: {req.event_context}\n"
        f"Wearer's role: {req.user_role}\n"
        'Schema: {"title": string (max 40 chars), "message": string (max 120 chars), '
        '"cta": string (max 25 chars), "tone": string (one word)}'
    )
    return build(BadgeTextResponse, {**data, "badge_id": req.badge_id})


@app.post("/api/follow-up", response_model=FollowUpResponse)
async def follow_up(req: FollowUpRequest):
    data = await ask_llm_json(
        "Suggest a follow-up message for a professional contact.\n"
        f"Last meeting date: {req.last_meeting_date}\n"
        f"Previous conversation:\n{req.previous_conversation}\n\n"
        'Schema: {"suggested_message": string, '
        '"send_channel": one of "email"|"linkedin"|"sms"|"whatsapp"|"call", '
        '"delay_days": integer 0-60 (days from today to wait before sending)}'
    )
    return build(FollowUpResponse, {**data, "contact_id": req.contact_id})


@app.post("/api/notes-summary", response_model=NotesSummaryResponse)
async def notes_summary(req: NotesSummaryRequest):
    data = await ask_llm_json(
        "Summarize these networking notes into 3-6 short bullet points "
        "(key points, action items, next steps).\n"
        'Schema: {"summary_bullets": [string]}\n\n'
        f"Notes:\n{req.notes}"
    )
    return build(NotesSummaryResponse, data)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
