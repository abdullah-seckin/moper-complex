# Hi Developer

This catalog is the developer entry point for Moper Complex. It explains how the project is structured, how the app and API communicate, how to run the demo modes, and where to change specific parts of the system.

## Project Purpose

Moper Complex is an employee attendance platform for small businesses. It verifies working-hour actions with two signals:

1. A QR code that belongs to the workplace.
2. A location check that confirms the employee is inside the workplace geofence.

The project combines the former employee-facing and HR/Admin-facing flows into one Flutter application, backed by a Dart Shelf API and a clean MongoDB data model.

## Start Here

| Need | Go To |
|---|---|
| Run the mobile app without backend setup | [Embedded Flutter demo](#embedded-flutter-demo) |
| Run the API without MongoDB | [API in-memory demo](#api-in-memory-demo) |
| Connect to MongoDB | [MongoDB mode](#mongodb-mode) |
| Understand request and response contracts | [API catalog](#api-catalog) |
| Understand collections and domain objects | [Data catalog](#data-catalog) |
| Work on Flutter screens | [Mobile app catalog](#mobile-app-catalog) |
| Work on backend logic | [Backend catalog](#backend-catalog) |
| Import legacy data | [Migration workflow](#migration-workflow) |

## Repository Map

```text
moper-complex
|-- app
|   |-- lib/core                 # Config, theme, API client, session, shared models
|   |-- lib/features/auth        # Login and role routing
|   |-- lib/features/attendance  # Employee home and QR scan flow
|   |-- lib/features/admin       # HR/Admin user list, detail, maps, reports
|   `-- lib/features/legal       # KVKK and consent screens
|-- api
|   |-- bin                      # server, seed, legacy migration entry points
|   |-- lib/config               # Environment and runtime configuration
|   |-- lib/core                 # HTTP envelope, security helpers, geo math
|   |-- lib/domain               # Domain models and enums
|   |-- lib/repositories         # MongoDB and in-memory repository implementations
|   |-- lib/server               # Service composition and Shelf router
|   |-- lib/services             # Auth, attendance, admin, migration, demo seed
|   `-- test                     # API integration tests
`-- docs
    |-- architecture.md
    |-- migration.md
    |-- hi-developer.md
    `-- screenshots
```

## Runtime Modes

### Embedded Flutter Demo

The Flutter app contains an offline demo store. If `POST /auth/login` cannot reach the API because the backend is not running, the app falls back to local demo users.

Use this mode for portfolio reviews and UI demonstrations:

```bash
cd app
flutter pub get
flutter run
```

Demo accounts:

| Role | Username | Password |
|---|---|---|
| HR/Admin | `admin` | `moper123` |
| Employee | `personel` | `moper123` |
| Employee | `selin` | `moper123` |

### API In-Memory Demo

Use this mode when you want to test API behavior without MongoDB.

```bash
cd api
dart pub get
MOPER_USE_MEMORY=true dart run bin/server.dart
```

The API seeds the same demo users and the default workplace on startup.

### MongoDB Mode

Use this mode for persistent data and migration work.

```bash
cd api
cp .env.example .env
# Fill MONGO_URI and secrets in .env
dart pub get
dart run bin/server.dart
```

Run the Flutter app against the API:

```bash
cd app
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

For Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Environment Catalog

The API reads `.env` first and then overlays process environment variables.

| Variable | Default | Purpose |
|---|---:|---|
| `PORT` | `8080` | HTTP port for the Shelf API |
| `MOPER_ENV_FILE` | `.env` | Optional custom env file path |
| `MONGO_URI` | empty | MongoDB connection string; empty means in-memory if memory mode is enabled or no DB is configured |
| `MOPER_USE_MEMORY` | `false` | Forces in-memory repositories when set to `true` |
| `JWT_SECRET` | `dev-only-change-me` | Secret used to sign API JWTs |
| `MIGRATION_KEY` | `local-migration-key` | Header key for protected migration endpoint |
| `DEFAULT_QR_TOKEN` | `MOPER_DEMO_QR` | QR payload expected for the default workplace |
| `DEFAULT_WORKPLACE_NAME` | `Moper HQ` | Seeded workplace name |
| `DEFAULT_WORKPLACE_LAT` | `40.9862` | Seeded workplace latitude |
| `DEFAULT_WORKPLACE_LNG` | `29.1244` | Seeded workplace longitude |
| `DEFAULT_WORKPLACE_RADIUS_METERS` | `250` | Geofence radius for attendance scans |

The Flutter app reads only one compile-time value:

| Dart Define | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `localhost:8080`, Android uses `10.0.2.2:8080` | API base URL used by the mobile client |

## API Catalog

All successful API responses use this envelope:

```json
{
  "data": {}
}
```

All errors use this envelope:

```json
{
  "error": {
    "message": "Human readable error",
    "details": {}
  }
}
```

Authenticated routes require:

```text
Authorization: Bearer <jwt>
```

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/health` | No | Health check |
| `POST` | `/auth/login` | No | Login and create a device session |
| `GET` | `/me` | User | Return the current user |
| `GET` | `/attendance/status` | User | Return current work status |
| `POST` | `/attendance/scan` | User | Validate QR and geofence, then write check-in/out event |
| `GET` | `/admin/users` | Admin | List all users |
| `GET` | `/admin/users/:id/events` | Admin | List events for one user with optional date range |
| `GET` | `/admin/reports/attendance` | Admin | Return report rows for Excel export |
| `POST` | `/migration/legacy-mongo` | Admin or migration key | Import legacy snapshot payload |

### Login

```http
POST /auth/login
Content-Type: application/json
```

```json
{
  "username": "admin",
  "password": "moper123",
  "platform": "ios",
  "deviceInfo": {
    "name": "iPhone Simulator"
  }
}
```

Returns:

```json
{
  "data": {
    "token": "<jwt>",
    "user": {
      "id": "user-id",
      "username": "admin",
      "firstName": "IK",
      "lastName": "Yoneticisi",
      "fullName": "IK Yoneticisi",
      "role": "admin",
      "active": true,
      "currentStatus": "off"
    }
  }
}
```

### Attendance Scan

```http
POST /attendance/scan
Authorization: Bearer <jwt>
Content-Type: application/json
```

```json
{
  "qrPayload": "MOPER_DEMO_QR",
  "location": {
    "latitude": 40.9862,
    "longitude": 29.1244,
    "accuracy": 12.5
  }
}
```

The backend:

1. Hashes the QR payload.
2. Finds an active workplace with the same QR hash.
3. Calculates the distance from submitted coordinates to the workplace.
4. Rejects the request if the employee is outside `radiusMeters`.
5. Creates the next event based on `currentStatus`.
6. Updates `moper_users.currentStatus`.

Possible validation failures:

| Status | Message |
|---:|---|
| `400` | `Invalid QR code.` |
| `401` | `Bearer token required.` |
| `422` | `Location is outside the workplace boundary.` |

### Date Range Queries

Admin event and report endpoints accept:

```text
?startDate=2026-07-01&endDate=2026-07-31
```

`endDate` is expanded to the end of the given day on the API side.

## Data Catalog

| Collection | Owned By | Purpose |
|---|---|---|
| `moper_users` | `UserRepository` | User identity, role, password hash, active flag, current work status |
| `moper_attendance_events` | `AttendanceRepository` | Immutable check-in/check-out events |
| `moper_device_sessions` | `DeviceSessionRepository` | Login device metadata and session history |
| `moper_workplaces` | `WorkplaceRepository` | Workplace geofence and QR token hash |

### Core Domain Values

| Domain | Values | Notes |
|---|---|---|
| `UserRole` | `employee`, `admin` | Admin routes require `admin` |
| `WorkStatus` | `off`, `working` | Stored on the user for fast dashboard reads |
| `AttendanceEventType` | `check_in`, `check_out` | Events are append-only |
| `AttendanceEvent.source` | `qr`, `demo` | Real API events use `qr`; embedded demo events use `demo` |

### User Shape

```json
{
  "id": "user-id",
  "username": "personel",
  "firstName": "Demo",
  "lastName": "Personel",
  "passwordHash": "<salted-hash>",
  "role": "employee",
  "active": true,
  "currentStatus": "off",
  "legacyId": "optional-legacy-id"
}
```

### Attendance Event Shape

```json
{
  "id": "event-id",
  "userId": "user-id",
  "workplaceId": "default-workplace",
  "type": "check_in",
  "serverTime": "2026-07-02T09:00:00.000Z",
  "location": {
    "latitude": 40.9862,
    "longitude": 29.1244,
    "accuracy": 12.5
  },
  "source": "qr",
  "legacyKey": "optional-idempotency-key"
}
```

## Mobile App Catalog

| Area | Files | Responsibility |
|---|---|---|
| App entry | `app/lib/main.dart` | Bootstraps config, session store, API client, and initial screen |
| Config | `app/lib/core/app_config.dart` | Resolves `API_BASE_URL` and Android emulator default |
| API client | `app/lib/core/api_client.dart` | HTTP calls, response parsing, embedded demo fallback |
| Models | `app/lib/core/models.dart` | User, event, report row models |
| Session | `app/lib/core/session_store.dart` | Local token and user session persistence |
| Theme | `app/lib/core/app_theme.dart` | Material 3 visual system |
| Auth | `app/lib/features/auth/login_page.dart` | Login, password visibility, consent checks |
| Legal | `app/lib/features/legal/legal_text_page.dart` | KVKK and explicit consent text |
| Employee | `app/lib/features/attendance/employee_home_page.dart` | Current status and QR entry point |
| QR scan | `app/lib/features/attendance/qr_scan_page.dart` | QR scanner, location permission, attendance request |
| Admin list | `app/lib/features/admin/admin_home_page.dart` | Staff list, status display, report export |
| Admin detail | `app/lib/features/admin/user_events_page.dart` | Date filters, event list, map preview/open action |

## Backend Catalog

| Area | Files | Responsibility |
|---|---|---|
| Runtime config | `api/lib/config/app_config.dart` | Reads env and default workplace settings |
| HTTP helpers | `api/lib/core/http.dart` | JSON envelope, CORS, error handling, payload parsing |
| Security | `api/lib/core/security.dart` | Password hashing, QR token hashing, JWT service |
| Geo | `api/lib/core/geo.dart` | Distance calculation for geofence checks |
| Models | `api/lib/domain/models.dart` | Domain entities and enum values |
| Repositories | `api/lib/repositories/*.dart` | MongoDB and in-memory persistence adapters |
| Service composition | `api/lib/server/app_services.dart` | Wires repositories into services |
| Router | `api/lib/server/router.dart` | Shelf routes, auth guard, admin guard |
| Auth service | `api/lib/services/auth_service.dart` | Login, active-user checks, device sessions, JWT |
| Attendance service | `api/lib/services/attendance_service.dart` | QR validation, geofence validation, event creation |
| Admin service | `api/lib/services/admin_service.dart` | User lists, event history, report rows |
| Migration service | `api/lib/services/migration_service.dart` | Legacy Users and Devices import |
| Demo seed | `api/lib/services/demo_seed.dart` | Default workplace and three demo users |

## Development Workflows

### Add a New API Endpoint

1. Add or extend a method in the relevant service under `api/lib/services`.
2. Add repository methods only if persistence access is missing.
3. Add the route in `api/lib/server/router.dart`.
4. Keep responses inside the `data` envelope by returning through `jsonResponse`.
5. Add or update tests in `api/test/server_test.dart`.
6. Update this catalog if the endpoint is public or important for the app.

### Add a New Flutter Screen

1. Place the screen in the matching `app/lib/features/<feature>` folder.
2. Keep network calls inside `app/lib/core/api_client.dart`.
3. Reuse shared models from `app/lib/core/models.dart`.
4. Keep role routing explicit after login.
5. Add empty, loading, success, and error states where the user can wait on data.
6. Update screenshots if the portfolio flow changes.

### Change Attendance Rules

1. Start in `api/lib/services/attendance_service.dart`.
2. Keep QR token comparison server-side.
3. Keep geofence validation server-side.
4. Store a new immutable event instead of editing old events.
5. Update `currentStatus` only after the event write succeeds.
6. Add tests for invalid QR, out-of-range location, check-in, and check-out.

## Migration Workflow

The legacy importer moves data from older prototype collections into the new collections.

Source collections:

| Legacy Collection | Important Fields |
|---|---|
| `Users` | `uname`, `upassword`, `fName`, `lName`, `isActive`, `state`, `logs` |
| `Devices` | `uID`, `platform`, `date`, `deviceData` |

Target collections:

| Target Collection | Notes |
|---|---|
| `moper_users` | Legacy passwords are converted to salted SHA-256 hashes |
| `moper_attendance_events` | Legacy logs become immutable events |
| `moper_device_sessions` | Legacy device rows become session rows |
| `moper_workplaces` | Seeded before migration |

Run:

```bash
cd api
cp .env.example .env
# Set MONGO_URI and make sure MOPER_USE_MEMORY=false
dart run bin/seed.dart
dart run bin/migrate_legacy.dart
```

Idempotency:

- Attendance events use `legacyKey`.
- Device sessions use `legacyKey`.
- Re-running migration updates users but does not duplicate events or sessions.

## Testing and Quality Gates

Run backend checks:

```bash
cd api
dart analyze
dart test
```

Run Flutter checks:

```bash
cd app
flutter analyze
flutter test
```

Recommended acceptance scenarios:

1. Employee logs in with `personel / moper123`.
2. Employee scans `MOPER_DEMO_QR` near the default workplace coordinates.
3. API records `check_in`.
4. Employee scans again and API records `check_out`.
5. Admin logs in with `admin / moper123`.
6. Admin opens the employee detail page and sees events.
7. Admin filters by date and exports an Excel report.

## Security Notes

- MongoDB credentials must stay in `.env`, never in Flutter code.
- Flutter must never hash or compare production QR secrets by itself.
- QR payloads are compared as hashes on the backend.
- Location is requested only during the attendance action.
- Admin endpoints are protected with both JWT and role checks.
- Migration endpoint is protected by `x-migration-key` or an admin JWT.
- Demo credentials are intentionally low security and must not be reused in production.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Login works only with demo accounts | API is not running, so Flutter used embedded demo fallback | Start the API or pass the correct `API_BASE_URL` |
| iOS simulator cannot reach API | API is not listening on `localhost:8080` | Start `dart run bin/server.dart` in `api` |
| Android emulator cannot reach API | Android emulator cannot use host `localhost` | Use `http://10.0.2.2:8080` |
| `Invalid QR code.` | QR payload does not match `DEFAULT_QR_TOKEN` hash | Scan or submit the configured QR token |
| `Location is outside the workplace boundary.` | Coordinates are outside `DEFAULT_WORKPLACE_RADIUS_METERS` | Adjust demo coordinates or workplace radius |
| Admin route returns `403` | Logged-in user role is `employee` | Use the `admin` account |
| Seed fails with `MONGO_URI is required` | Mongo mode command was run without Mongo URI | Fill `.env` before running seed or migration |

## Definition of Done

Before a feature is considered ready:

1. The app flow works in embedded demo mode when possible.
2. API behavior works in in-memory mode.
3. MongoDB mode has no hardcoded secrets.
4. Admin-only behavior is role guarded.
5. Date filters behave correctly for start and end dates.
6. Errors are user-readable in the Flutter UI.
7. Public behavior is reflected in README or docs.

## Related Docs

- [Architecture](architecture.md)
- [Migration](migration.md)
