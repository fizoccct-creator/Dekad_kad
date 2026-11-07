# Dekad

A networking app for exchanging profiles at events, with AI help for bios,
badge text, follow-ups and note summaries.

Each user has two profiles, **professional** and **personal**, and shares
only the one that's active (by QR code now, NFC later).

```
backend/   FastAPI service that calls an LLM via Abacus RouteLLM
frontend/  Flutter app (Android / iOS)
render.yaml  Render deployment for the backend
```

## Backend

```bash
cd backend
python -m venv .venv
.venv/Scripts/activate        # Windows; use .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
cp .env.example .env          # then set ROUTELLM_API_KEY
uvicorn main:app --reload
```

API docs: http://localhost:8000/docs. Health check: `GET /health`.

| Endpoint | Purpose |
|---|---|
| `POST /api/bio-rewrite` | Rewrite a bio for professional or personal mode |
| `POST /api/badge-text` | Title, message and call to action for an event badge |
| `POST /api/follow-up` | Follow-up message, channel and when to send it |
| `POST /api/notes-summary` | Turn meeting notes into bullet points |

## Frontend

```bash
cd frontend
flutter pub get
flutter run                                         # backend at 10.0.2.2:8000 (Android emulator)
flutter run --dart-define=API_BASE_URL=https://<your-app>.onrender.com
flutter test
```

## Deploy

Render reads `render.yaml`. Set `ROUTELLM_API_KEY` in the Render dashboard.

## Status

UI follows the [Dekad_Kad Figma file](https://www.figma.com/design/CdFuuUGbUlhTwDgtSzVy9r/Dekad_Kad).
Design tokens live in `frontend/lib/theme/tokens.dart`.

- Working: profile switching, QR code of the active profile, QR scanning that
  saves a connection, contacts list with search and filters, contact notes,
  AI bio rewrite, AI notes summary, AI follow-up draft, AI event badge.
- Placeholder data: profile and contacts are sample data held in memory
  (`lib/data/`), so changes reset on restart.
- Not built yet: NFC exchange (screen is ready, the session isn't), onboarding
  and sign-up, local storage, backend auth.
