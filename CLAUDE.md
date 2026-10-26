# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Правила работы

- Отвечать пользователю на русском языке.
- Редактировать файлы без остановок: не спрашивать подтверждения перед каждой правкой, а доводить задачу до конца и в конце кратко сообщать, что изменено.
- Перед необратимыми действиями (удаление файлов, `git push`, `git reset --hard`, изменения в базе данных) всё равно спрашивать подтверждение.

## Project

StudyPlan — offline-first student organizer (курсовая работа, Astana IT University). Two independent parts in one repo:

- `backend/` — Node.js ≥20 (ESM), Express 5, Knex, JWT auth. SQLite by default (dev/tests); production DB is PostgreSQL on Supabase via `DB_CLIENT=pg` + `DATABASE_URL` (Session pooler, port 5432) + `PG_SSL_CA` (Supabase root cert, `backend/certs/`, gitignored). See `backend/SUPABASE.md`. No chat, no Socket.IO, no LMS password proxy.
- `mobile/` — Flutter app (package name `studyplan`) targeting Web, Windows, Android, iOS. Local DB is drift (SQLite), HTTP via Dio, state via `flutter_bloc` + drift streams. UI in ru/en/kk, light/dark theme.

Group model: a group = members + invite code/link (`<server>/join/CODE`) + group tasks + shared materials. All members are equal (no headman/student roles in logic or UI; `users.role` column still exists but is unused).

Design docs: `docs/superpowers/specs/2026-10-26-studyplan-redesign-design.md` (redesign spec), `docs/i18n-glossary.md` (ru/en/kk terminology + Kazakh style rules), `docs/i18n-kk-review.md`. Long-form Russian docs: `PROJECT_OVERVIEW.md`, `КУРСОВАЯ_РАБОТА_СВОДКА.md`, `РУКОВОДСТВО_ПО_ЗАЩИТЕ_И_УСТАНОВКЕ.md`, `CRITERIA_COMPLIANCE.md` (pre-redesign, each has an «Обновление 26.10.2026» section at the end).

## Commands

Backend (run from `backend/`; copy `.env.example` to `.env` for local config):

```
npm run dev                # node --watch src/server.js, http://localhost:3000 (applies pending migrations on start)
npm start
npm run migrate            # knex migrate:latest
npm test                   # all tests, sequential (node:test + supertest)
node --test --test-concurrency=1 tests/sync.test.js                 # single file
node --test --test-concurrency=1 --test-name-pattern="LWW" tests/   # by test name
npm run setup / npm run seed / npm run db:reset   # local SQLite only (seed wipes tables)
```

**Never run `seed`, `setup` or `db:reset` against Supabase** (seed deletes all rows and inserts demo data; `db:reset` rolls back the schema). The server no longer seeds on startup; the seed exists for tests and manual local use. It creates `headman@studyplan.dev` / `student@studyplan.dev` (password `password123`, invite code `AITU26`) — local dev only; real users register themselves.

Mobile (run from `mobile/`; on this machine Flutter is at `C:\Users\aldia\flutter\bin`, the `.bat` launchers prepend it to PATH):

```
flutter pub get
flutter gen-l10n           # generate lib/l10n/generated (gitignored) — needed before analyze/test on a fresh checkout
flutter analyze            # CI runs gen-l10n, analyze, test (.github/workflows/dart.yml)
flutter test
flutter test test/main_shell_test.dart
flutter run -d chrome --web-port=5000
flutter run -d windows
dart run build_runner build --delete-conflicting-outputs   # regenerate app_database.g.dart / lms_dao.g.dart after changing drift tables
```

If `mobile/build/web` exists, the backend serves it statically at `/` (and `/join/:code` for invite links), so `flutter build web` + `npm start` gives a single-origin deployment.

On start the server prints a QR code for `http://<LAN IP>:<port>/open`: on Android that page (`src/utils/open-app.js`) opens the installed app via an intent URL `studyplan://connect?server=<origin>` (handled in `MainActivity.kt` → `core/services/connect_link.dart`; any page can fire that link, so `core/widgets/connect_link_prompt.dart` shows the host and saves `<origin>/api` as the API address only after the user confirms), falling back to the web version; other devices are redirected to `/`.

## Architecture

### Offline-first sync (the core design)

The client owns a full local copy of the user's data; the server is the merge point. Both sides must stay in agreement on the table/column contract:

- Server contract: `backend/src/db/schema.js` — `SYNC_TABLES` (allowed columns, boolean coercion, per-table `validate`) and `SYNC_ORDER` (parents before children): `subjects, lessons, tasks, subtasks, lms_courses, lms_events, lms_materials`.
- Client tables: `mobile/lib/core/database/app_database.dart` (drift, schemaVersion 2; LMS tables have `lms_dao.dart`). Every synced table has a `syncStatus` column (`synced` / pending) used to find local changes.
- Protocol: single endpoint `POST /api/sync` (`backend/src/services/sync.service.js`, client in `mobile/lib/core/sync/sync_repository.dart`). Client pushes dirty rows plus `last_synced_at`; server applies them in one transaction with Last-Write-Wins on `updated_at` (epoch ms), then returns rows changed since `last_synced_at - PULL_OVERLAP_MS`. Deletes are soft (`is_deleted` tombstones). IDs are client-generated UUIDs.
- Server checks ownership and references with explicit queries inside the transaction rather than relying on FK errors (a failed statement aborts the whole transaction on PostgreSQL). Any member may publish a group task (`is_group`) but only for their own `group_id`, enforced server-side.
- Adding a synced field means touching: a Knex migration, `SYNC_TABLES` in `schema.js`, the drift table + regenerated `.g.dart` (+ drift schema migration), and the push/pull mapping in `sync_repository.dart`.
- Supabase: migration `20261026000002_enable_rls.js` enables RLS without policies on every table (pg only) so Supabase's REST API exposes nothing; the backend connects as `postgres`.

### LMS import (Moodle at lms.astanait.edu.kz)

No credentials pass through our server. Flow: `features/lms/presentation/lms_import_screen.dart` opens a WebView (`flutter_inappwebview`; Android/iOS/Windows only — on web the button is replaced by an explanation) → user logs in via Microsoft → once on LMS with `M.cfg.sesskey`, the in-page script (`data/moodle_page_script.dart`) calls Moodle AJAX (`/lib/ajax/service.php`) same-origin, falling back to fetching HTML → `moodle_ajax_parser.dart` / `moodle_html_parser.dart` (pure functions, tested on fixtures in `test/lms/fixtures`) → `lms_models.dart` → `applyImport` in `data/lms_importer.dart` upserts into drift by LMS id (marks vanished rows deleted, keeps `manual` courses, credits and `is_done`) → normal sync. WebView uses conditional imports: `lms_webview.dart` exports `lms_webview_stub.dart` or `lms_webview_io.dart` (`dart.library.io`) so web never imports `flutter_inappwebview`.

### Backend layout

`src/server.js` (HTTP bootstrap, runs pending migrations) → `src/app.js` (`createApp()`, used directly by tests; serves web build + `/join/:code`) → `src/routes/index.js` (auth, groups `/groups/me|join|leave`, `/sync`, `/materials`, `/files/:name`; `requireAuth` middleware) → `controllers/` (thin HTTP layer) → `services/` (`auth`, `group`, `materials`, `sync`; logic + Knex). Errors are thrown as `HttpError` (`utils/http-error.js`) and formatted by `middleware/error.js`. Config is centralized in `src/config/env.js` (`buildPgConnection()` handles `DATABASE_URL`/SSL/CA; certificate verification is never disabled); uploads go to `data/uploads`. The `chat_messages` table still exists in the DB but is unused.

### Backend tests

Each test file must import `tests/setup.js` first (directly or via `tests/helpers.js`): it forces `NODE_ENV=test` and an in-memory SQLite DB, so `.env` is ignored. Use `resetDb()`, `registerUser()` and `authed(token)` from `helpers.js`. Tests run with `--test-concurrency=1` because they share one DB connection.

### Mobile layout

- `lib/main.dart` creates a single `AppSettings`, `AppDatabase` and `ApiClient` and passes them down through constructors (no DI container) — `SplashScreen` → `AuthScreen` or `MainShellScreen`. `AppSettings` (`core/settings/`) holds theme mode and locale (SharedPreferences).
- Navigation (`features/main_shell`): 4 tabs + More — Home, Schedule, Tasks, Grades, More (bottom bar on phones, side rail ≥ 840 px). More → Profile & settings, Group (members, invite, materials), Campus map. Inner screens use `Navigator.push`.
- `lib/core/` — `database/` (drift tables + DAOs), `network/api_client.dart` (Dio, Bearer JWT, base URL changeable at runtime via `widgets/server_config_dialog.dart`), `sync/` (`SyncBloc` drives sync and the status indicator), `services/` (notifications, file storage, ICS export), `utils/` (`date_util`, `due_format`, …).
- Theme: `core/theme/app_theme.dart` (light/dark `ThemeData`, Inter font) + `app_palette.dart` (`AppPalette` ThemeExtension with semantic colors). Widgets use `context.palette`, `context.text`, `context.l10n` from `theme_ext.dart` — no `AppColors`, avoid raw `Colors.*`. Style: neutral, no shadows/gradients/emoji, 1 px borders, rows with dividers instead of card stacks.
- Shared UI kit `core/widgets/ui/`: `ContentColumn` / `SliverContentColumn` / `ContentAppBar` (max-width content), `AppSheet` / `AppSheetLayout`, `SegmentedToggle`, `FilterChipsRow` / `AppFilterChip`, `EmptyState`, `ListRow` / `ListGroup`, `SectionHeader`, `StatusLabel`, `AppTextField`. Reuse these instead of ad-hoc widgets.
- Grades: all thresholds, weights, letter scale and credits default live only in `features/grades/domain/grading_rules.dart` (60/40 admission/final, pass 50); calculations in `grade_calculator.dart`. Don't hardcode grading numbers elsewhere.
- `lib/features/<feature>/` — `data/`, `domain/`, `presentation/{screens,widgets}/` per area: home, schedule, calendar, tasks, grades, group, materials, lms, profile, more, campus_map, auth, splash, main_shell. Screens read data reactively from DAO streams. No demo/fake data for real users: empty screens show `EmptyState`.
- l10n: ARB files `lib/l10n/app_{ru,en,kk}.arb` (`app_ru.arb` is the template, `l10n.yaml`), generated into `lib/l10n/generated/` (gitignored; produced by `flutter gen-l10n` or a build). Add every UI string to all three ARB files. Kazakh: follow the terminology and «Kazakh style rules» in `docs/i18n-glossary.md` (Сіз-form, infinitive buttons, etc.). LMS course names are not translated.
- Platform-specific code uses conditional imports (`core/utils/file_download_helper.dart` with `_web` / `_stub`, `features/lms/presentation/lms_webview.dart` with `_io` / `_stub`) — keep web builds compiling when touching file/IO/webview code.
