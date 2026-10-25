# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Правила работы

- Отвечать пользователю на русском языке.
- Редактировать файлы без остановок: не спрашивать подтверждения перед каждой правкой, а доводить задачу до конца и в конце кратко сообщать, что изменено.
- Перед необратимыми действиями (удаление файлов, `git push`, `git reset --hard`, изменения в базе данных) всё равно спрашивать подтверждение.

## Project

StudyPlan — offline-first student organizer (курсовая работа, Astana IT University). Two independent parts in one repo:

- `backend/` — Node.js ≥20 (ESM), Express 5, Knex (SQLite by default, PostgreSQL via `DB_CLIENT=pg`), Socket.IO, JWT auth.
- `mobile/` — Flutter app (package name `studyplan`) targeting Web, Windows, Android, iOS. Local DB is drift (SQLite), HTTP via Dio, state via `flutter_bloc` + drift streams.

Long-form Russian docs: `PROJECT_OVERVIEW.md`, `КУРСОВАЯ_РАБОТА_СВОДКА.md`, `РУКОВОДСТВО_ПО_ЗАЩИТЕ_И_УСТАНОВКЕ.md`, `CRITERIA_COMPLIANCE.md`.

## Commands

Backend (run from `backend/`; copy `.env.example` to `.env` for local config):

```
npm run setup              # migrate + seed demo data
npm run dev                # node --watch src/server.js, http://localhost:3000
npm start
npm run db:reset           # rollback all, migrate, seed
npm test                   # all tests, sequential (node:test + supertest)
node --test --test-concurrency=1 tests/sync.test.js                 # single file
node --test --test-concurrency=1 --test-name-pattern="LWW" tests/   # by test name
```

Mobile (run from `mobile/`; on this machine Flutter is at `C:\Users\aldia\flutter\bin`, the `.bat` launchers prepend it to PATH):

```
flutter pub get
flutter analyze            # CI runs this (.github/workflows/dart.yml)
flutter test               # CI runs this
flutter test test/widget_test.dart
flutter run -d chrome --web-port=5000
flutter run -d windows
dart run build_runner build --delete-conflicting-outputs   # regenerate app_database.g.dart after changing drift tables
```

If `mobile/build/web` exists, the backend serves it statically at `/`, so `flutter build web` + `npm start` gives a single-origin deployment.

Demo accounts from the seed: `headman@studyplan.dev` / `password123` (headman), `student@studyplan.dev` / `password123`; group invite code `IVT21A`.

## Architecture

### Offline-first sync (the core design)

The client owns a full local copy of the user's data; the server is the merge point. Both sides must stay in agreement on the table/column contract:

- Server contract: `backend/src/db/schema.js` — `SYNC_TABLES` (allowed columns, boolean coercion, per-table `validate`) and `SYNC_ORDER` (parents before children: subjects → lessons, tasks → subtasks, chat).
- Client tables: `mobile/lib/core/database/app_database.dart` (drift). Every synced table has a `syncStatus` column (`synced` / pending) used to find local changes.
- Protocol: single endpoint `POST /api/sync` (`backend/src/services/sync.service.js`, client in `mobile/lib/core/sync/sync_repository.dart`). Client pushes dirty rows plus `last_synced_at`; server applies them in one transaction with Last-Write-Wins on `updated_at` (epoch ms), then returns rows changed since `last_synced_at - PULL_OVERLAP_MS`. Deletes are soft (`is_deleted` tombstones). IDs are client-generated UUIDs.
- Server checks ownership and references with explicit queries inside the transaction rather than relying on FK errors (a failed statement aborts the whole transaction on PostgreSQL). Only a `headman` can publish group tasks (`is_group`), enforced server-side.
- Adding a synced field means touching: a Knex migration, `SYNC_TABLES` in `schema.js`, the drift table + regenerated `.g.dart`, and the push/pull mapping in `sync_repository.dart`.

### Backend layout

`src/server.js` (HTTP + Socket.IO bootstrap) → `src/app.js` (`createApp()`, used directly by tests) → `src/routes/index.js` (all routes, `requireAuth` middleware) → `controllers/` (thin HTTP layer) → `services/` (logic + Knex). Errors are thrown as `HttpError` (`utils/http-error.js`) and formatted by `middleware/error.js`. Realtime: `realtime/socket.js` (JWT-authenticated sockets, group rooms) and `realtime/notifier.js` (`emitToGroup` / `emitToUser`, called from services after sync/chat changes). Config is centralized in `src/config/env.js`; uploads go to `data/uploads`.

### Backend tests

Each test file must import `tests/setup.js` first (directly or via `tests/helpers.js`): it forces `NODE_ENV=test` and an in-memory SQLite DB, so `.env` is ignored. Use `resetDb()`, `registerUser()` and `authed(token)` from `helpers.js`. Tests run with `--test-concurrency=1` because they share one DB connection.

### Mobile layout

- `lib/main.dart` creates a single `AppDatabase` and `ApiClient` and passes them down through constructors (no DI container) — `SplashScreen` → `AuthScreen` or `MainShellScreen`.
- `lib/core/` — `database/` (drift tables + DAOs), `network/api_client.dart` (Dio, Bearer JWT, base URL changeable at runtime via `widgets/server_config_dialog.dart`), `sync/` (`SyncBloc` drives sync and the AppBar status indicator), `services/` (notifications, file storage, ICS export), `theme/` (dark "Midnight Slate" palette in `app_colors.dart`).
- `lib/features/<feature>/presentation/{screens,widgets}/` — one folder per screen area (timeline, schedule, tasks, chat, campus_map, profile, lms, grades, etc.). Screens read data reactively from DAO streams.
- Platform-specific code uses conditional imports, e.g. `core/utils/file_download_helper.dart` with `_web` / `_stub` variants — keep web builds compiling when touching file/IO code.
