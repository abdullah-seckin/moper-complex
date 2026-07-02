# Legacy Migration

The migration moves the previous prototype data into the new clean model.

## Source Collections

- `Users`
  - `uname`, `upassword`, `fName`, `lName`, `isActive`, `state`
  - `logs[].date`
  - `logs[].logs[].time`, `Lat`, `Lng`, `state`
- `Devices`
  - `uID`, `platform`, `date`, `deviceData`

## Target Collections

- `moper_users`
- `moper_attendance_events`
- `moper_device_sessions`
- `moper_workplaces`

## Run

```bash
cd api
cp .env.example .env
# Fill MONGO_URI and set MOPER_USE_MEMORY=false
dart run bin/seed.dart
dart run bin/migrate_legacy.dart
```

## Idempotency

Attendance events use a `legacyKey` built from legacy user id, date, time, state and coordinates. Device sessions use legacy device id, username and date. Running migration multiple times updates users but does not duplicate events or device sessions.

## Passwords

Legacy `upassword` values are not kept as plain text. During migration they are converted to the new salted SHA-256 password hash format.
