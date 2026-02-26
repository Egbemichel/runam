# RunAm

> A community-driven errand delivery platform connecting people who need tasks done ("Buyers") with nearby students who earn by running those errands ("Runners").

RunAm combines a **Flutter** mobile frontend with a **Django + GraphQL** backend, real-time WebSocket support via Django Channels, background task processing with Celery, and a trust-score system to keep the community safe and reliable.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Environment Variables](#environment-variables)
- [Running the Project](#running-the-project)
- [API](#api)
- [Key Concepts](#key-concepts)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

RunAm is a two-sided marketplace:

| Role | Description |
|------|-------------|
| **Buyer** | Posts an errand (pick-up/drop-off, list of tasks, budget, payment method) and waits for a Runner to accept. |
| **Runner** | A nearby user (typically a student) who receives errand offers, accepts them, and completes the delivery in exchange for payment. |

The platform handles the full lifecycle of an errand — from creation and runner matching through real-time tracking, acceptance, completion, and ratings — while maintaining a **trust score** for every participant.

---

## Architecture

```
runam/
└── src/
    ├── backend/     # Django (Python) — GraphQL API, business logic, async workers
    └── frontend/    # Flutter (Dart) — Cross-platform mobile app
```

The two services communicate exclusively over **GraphQL** (HTTP) and **WebSockets** (Django Channels + Redis).

```
┌─────────────────────┐        GraphQL / WS        ┌───────────────────────────┐
│  Flutter App        │ ◄────────────────────────► │  Django (ASGI)            │
│  (iOS / Android)    │                             │  ├── Graphene GraphQL     │
└─────────────────────┘                             │  ├── graphql-jwt (auth)   │
                                                    │  ├── Django Channels (WS) │
                                                    │  └── Celery tasks         │
                                                    └───────────┬───────────────┘
                                                                │
                                              ┌─────────────────▼──────────────┐
                                              │  Redis  (channel layer +        │
                                              │          Celery broker)         │
                                              └────────────────────────────────┘
```

---

## Features

- **Dual-role system** — users switch between Buyer and Runner mode in the app.
- **Errand lifecycle management** — create, match, accept, track, complete, and cancel errands.
- **Automatic runner matching** — Celery task ranks nearby runners by proximity (Haversine) and trust score, then dispatches sequential offers with a configurable TTL.
- **Real-time offers** — Django Channels pushes errand offers to Runners over WebSockets; the Flutter app reacts instantly via `GetX` streams.
- **Trust score system** — every completed/cancelled errand adjusts participant scores; ratings (1–5 stars with comment) are stored per errand.
- **Google Sign-In** — social authentication via `django-allauth` (backend) and `google_sign_in` (frontend).
- **JWT authentication** — stateless auth with short-lived tokens and 7-day refresh tokens (`django-graphql-jwt`).
- **Image uploads** — errand photos stored locally (dev) or in S3-compatible storage via Supabase (prod).
- **Mapbox maps** — interactive map with real-time location updates and route display.
- **Payment methods** — Cash or Online (framework ready).
- **Webhook support** — configurable outbound webhooks for external integrations.

---

## Tech Stack

### Backend

| Technology | Purpose |
|------------|---------|
| Python 3 / Django 6 | Web framework |
| Graphene-Django | GraphQL API |
| django-graphql-jwt | JWT authentication |
| django-allauth | Social authentication (Google) |
| Django Channels | WebSocket / async support |
| Celery | Background task queue (runner matching, offer expiry) |
| Redis | Channel layer + Celery broker |
| SQLite (dev) / PostgreSQL (prod) | Database |
| django-storages / Supabase S3 | File storage |
| django-cors-headers | CORS handling |

### Frontend

| Technology | Purpose |
|------------|---------|
| Flutter | 3.10+ | Cross-platform UI framework |
| GetX | State management & dependency injection |
| Go Router | Declarative navigation |
| graphql_flutter | GraphQL client |
| web_socket_channel | WebSocket client |
| google_sign_in | Google OAuth |
| Mapbox Maps Flutter | Interactive maps |
| Geolocator | Device location |
| Google Fonts | Typography (Shantell Sans) |
| flutter_dotenv | Environment config |
| Lottie | Animations |

---

## Repository Structure

```
src/
├── backend/
│   ├── core/                  # Django project settings, URLs, schema root, ASGI/WSGI
│   ├── apps/
│   │   ├── users/             # UserProfile, avatar, trust score, roles
│   │   ├── errands/           # Errand, ErrandOffer, ErrandTask — core domain
│   │   ├── locations/         # UserLocation (live runner/buyer position)
│   │   ├── roles/             # Role model (BUYER / RUNNER)
│   │   └── trust/             # TrustScoreEvent, Rating
│   ├── errand_location/       # ErrandLocation (pickup / dropoff coordinates)
│   ├── runners/               # Runner matching service (Haversine distance sort)
│   ├── manage.py
│   ├── requirements.txt
│   └── schema.graphql         # Auto-generated schema snapshot
│
└── frontend/
    ├── lib/
    │   ├── app/               # App entry, router (GoRouter), theme
    │   ├── components/        # Reusable widgets (ErrandCard, etc.)
    │   ├── controllers/       # GetX controllers (AuthController, RunnerOfferController)
    │   ├── features/
    │   │   └── errand/        # Errand creation, searching, in-progress screens
    │   ├── graphql/           # GraphQL query/mutation definitions
    │   ├── models/            # Dart data models (AppUser, Errand, UserLocation, Place)
    │   ├── screens/
    │   │   ├── home/          # Main home screen
    │   │   ├── onboarding/    # First-run onboarding
    │   │   ├── profile/       # User profile screen
    │   │   ├── runner/        # Runner offer acceptance dashboard
    │   │   └── splash/        # Splash / loading screen
    │   ├── services/          # API & auth services
    │   └── main.dart          # App entry point
    ├── assets/images/         # App images and icons
    ├── pubspec.yaml
    └── .env                   # Environment variables (not committed)
```

---

## Getting Started

### Prerequisites

| Tool | Minimum Version |
|------|----------------|
| Python | 3.11+ |
| pip | latest |
| Redis | 6+ |
| Flutter | 3.10+ (Dart SDK `^3.7.2` minimum) |
| Dart | 3.7.2+ |
| Android Studio / Xcode | Latest stable |

### Backend Setup

```bash
cd src/backend

# Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables (see section below)
cp .env.example .env             # or create .env manually

# Apply database migrations
python manage.py migrate

# (Optional) Create a superuser for the Django admin
python manage.py createsuperuser

# Start the development server
python manage.py runserver
```

> **Redis** must be running locally on port 6379 for Django Channels and Celery.
> Start it with `redis-server` or `docker run -p 6379:6379 redis`.

To process background tasks (runner matching, offer expiry), start Celery in a separate terminal:

```bash
cd src/backend
celery -A core worker -l info
```

### Frontend Setup

```bash
cd src/frontend

# Install Flutter packages
flutter pub get

# Create the .env file (see section below)
touch .env

# Run on a connected device / emulator
flutter run
```

---

## Environment Variables

### Backend (`src/backend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `DJANGO_SECRET_KEY` | Yes | Django secret key |
| `GOOGLE_CLIENT_ID` | Yes | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Yes | Google OAuth client secret |
| `CELERY_BROKER_URL` | No | Redis URL (default: `redis://localhost:6379/0`) |
| `CELERY_RESULT_BACKEND` | No | Redis URL for Celery results |
| `ERRAND_TTL_MINUTES` | No | Minutes before an unmatched errand expires (default: `30`) |
| `STORAGE_MODE` | No | `dev` (local files) or `prod` (Supabase S3) |
| `SUPABASE_S3_ACCESS_KEY_ID` | Prod only | Supabase S3 access key |
| `SUPABASE_S3_SECRET_ACCESS_KEY` | Prod only | Supabase S3 secret key |
| `SUPABASE_S3_BUCKET_NAME` | Prod only | S3 bucket name |
| `SUPABASE_S3_REGION_NAME` | Prod only | S3 region |
| `SUPABASE_S3_ENDPOINT_URL` | Prod only | Supabase S3 endpoint URL |
| `WEBHOOK_URLS` | No | Comma-separated list of outbound webhook endpoints |
| `DJANGO_LOG_LEVEL` | No | Log level (default: `INFO`) |

### Frontend (`src/frontend/.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `MAPBOX_PUBLIC_TOKEN` | Yes | Mapbox public access token |

---

## Running the Project

### Development (all services)

```bash
# Terminal 1 — Redis
redis-server

# Terminal 2 — Django backend
cd src/backend && source .venv/bin/activate
python manage.py runserver

# Terminal 3 — Celery worker
cd src/backend && source .venv/bin/activate
celery -A core worker -l info

# Terminal 4 — Flutter app
cd src/frontend
flutter run
```

### Running Tests

**Backend:**
```bash
cd src/backend
python manage.py test
# or with pytest
pytest
```

**Frontend:**
```bash
cd src/frontend
flutter test
```

### Building for Production

**Android APK:**
```bash
cd src/frontend
flutter build apk --release
```

**iOS:**
```bash
cd src/frontend
flutter build ios --release
```

---

## API

The backend exposes a single **GraphQL endpoint**:

```
POST /graphql/
```

An interactive **GraphiQL** explorer is available at `http://localhost:8000/graphql/` in development.

### Authentication

All protected mutations and queries require a JWT token in the `Authorization` header:

```
Authorization: JWT <token>
```

Obtain a token with the `tokenAuth` mutation:

```graphql
mutation {
  tokenAuth(username: "user@example.com", password: "secret") {
    token
    refreshExpiresIn
  }
}
```

### Key Operations

| Operation | Type | Description |
|-----------|------|-------------|
| `me` | Query | Get the current authenticated user |
| `errands` | Query | List errands (filter by status or requesterId) |
| `errand(id)` | Query | Get a single errand |
| `createErrand` | Mutation | Post a new errand |
| `updateErrand` | Mutation | Update errand fields or status |
| `deleteErrand` | Mutation | Remove an errand |
| `updateUserLocation` | Mutation | Update the caller's live location |
| `tokenAuth` | Mutation | Obtain JWT token |
| `refreshToken` | Mutation | Refresh an expiring JWT |
| `uploadImage` | Mutation | Upload an errand image (multipart) |

---

## Key Concepts

### Errand Lifecycle

```
PENDING → IN_PROGRESS → COMPLETED
                      ↘ CANCELLED
         ↓ (no runner found / TTL elapsed)
        EXPIRED
```

1. **Buyer** creates an errand — status becomes `PENDING`.
2. A **Celery task** (`start_errand_matching`) fires immediately, finds nearby Runners sorted by distance and trust score, and creates `ErrandOffer` records with a per-offer TTL.
3. Each **Runner** receives a real-time offer over WebSockets and has a limited window to accept.
4. On acceptance, the errand transitions to `IN_PROGRESS` and the Buyer is notified.
5. After completion, both parties leave a **rating**; trust scores are adjusted accordingly.
6. If no Runner accepts within the errand TTL, the errand is marked `EXPIRED`.

### Trust Score

Every user starts with a trust score of **60**. `TrustScoreEvent` records track each positive or negative delta (e.g., completing an errand, receiving a high rating, cancelling last-minute). The score influences how high a Runner appears in the matching queue.

### Runner Matching

`runners/services.py::get_nearby_runners` fetches all active Runners who have a saved location and sorts them using the **Haversine formula** by distance to the errand pick-up point, breaking ties by trust score (descending).

---

## Contributing

Contributions are welcome! To get started:

1. Fork the repository and create a feature branch.
2. Follow the existing code style (PEP 8 for Python, `flutter_lints` for Dart).
3. Add or update tests for your changes.
4. Open a pull request with a clear description.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](src/frontend/LICENSE) file for details.
