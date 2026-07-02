# Architecture

## Runtime Flow

```text
Flutter app
  ├─ Login + consent
  ├─ Employee QR scan + geolocation
  └─ Admin users, events, reports
        │
        ▼
Dart Shelf API
  ├─ AuthService: password verification, JWT
  ├─ AttendanceService: QR token hash, geofence, event write
  ├─ AdminService: user/event/report reads
  └─ LegacyMigrationService: old Users.logs and Devices import
        │
        ▼
MongoDB
  ├─ moper_users
  ├─ moper_attendance_events
  ├─ moper_device_sessions
  └─ moper_workplaces
```

## Key Decisions

- Flutter never stores Mongo credentials.
- QR payload is compared by server-side SHA-256 hash.
- Location is read only during a QR attendance action.
- `check_in` and `check_out` are stored as immutable events.
- Current work status is denormalized on `moper_users.currentStatus` for fast dashboards.
- API can run with in-memory repositories for demos and automated tests.

## API Surface

- `POST /auth/login`
- `GET /me`
- `GET /attendance/status`
- `POST /attendance/scan`
- `GET /admin/users`
- `GET /admin/users/:id/events`
- `GET /admin/reports/attendance`
- `POST /migration/legacy-mongo`

Admin endpoints require a JWT belonging to a user with `role=admin`.
