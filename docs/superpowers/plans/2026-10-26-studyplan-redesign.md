# StudyPlan Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure StudyPlan to 4 tabs + «Ещё», remove all demo data, fix grade maths, new neutral light/dark design, ru/en/kk, LMS import via Microsoft login in a WebView, group = members + invite + group tasks + materials (no chat, no roles), Postgres on Supabase.

**Architecture:** Offline-first stays (drift ↔ `POST /api/sync`, LWW). Three new synced tables (`lms_courses`, `lms_events`, `lms_materials`). LMS data is fetched by JavaScript running inside the logged-in LMS page (`flutter_inappwebview`), parsed by pure Dart functions, written to drift, synced like everything else. Theme via `ThemeData` + `ThemeExtension<AppPalette>`; strings via `gen-l10n`.

**Tech Stack:** Flutter (drift, flutter_bloc, dio, flutter_localizations, intl, flutter_inappwebview, html, share_plus), Node ≥20 ESM + Express 5 + Knex (SQLite tests / pg on Supabase).

**Spec:** `docs/superpowers/specs/2026-10-26-studyplan-redesign-design.md` — read it before any task; the "Анти-цели" section is binding.

## Global Constraints

- Work branch: `redesign`. Parallel tracks run in git worktrees branched from `redesign` and are merged back by the coordinator.
- `flutter analyze` must report no issues; `flutter test` and `npm test` (from `backend/`) must pass at the end of every task.
- Web build must compile: anything importing `flutter_inappwebview` or `dart:io` goes behind a conditional import with a `_stub` variant (pattern: `core/utils/file_download_helper.dart`).
- No emoji anywhere in UI. No shadows (`elevation: 0`, no `BoxShadow`). No gradients. Radius 8 for buttons/inputs/cards, 12 only for bottom sheets/dialogs. Spacing on a 4 px grid, screen padding 16. Icons: Material outlined set only.
- Widgets never use `AppColors.*` or `Colors.*` (except `Colors.transparent`); colours come from `context.palette` (Task B1).
- No user-visible string literals in widgets after a screen is redone: strings go to the section's ARB part (Task B2). Russian is the source language.
- Never show fabricated numbers: no grade, GPA, amount, badge or count that is not computed from the user's data.
- Thresholds and weights only in `mobile/lib/features/grades/domain/grading_rules.dart`.
- Synced-field checklist (CLAUDE.md): Knex migration + `SYNC_TABLES`/`SYNC_ORDER` + drift table + regenerated `.g.dart` + `sync_repository.dart` mapping.
- Commit messages: conventional style, end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.
- Do not touch `*.har`, `.claude/`, `~/` folder.

## Review Focus

1. LMS returns a course with no grades yet ("-", empty, 0,00 at semester start) → shown as «нет оценки», excluded from averages, never 0 and never 85. Test in C1 (`parseGradesOverview` on the real fixture where all grades are `0,00` and items are empty) and B4 (`weightedAverage` ignores nulls).
2. Re-import after the user edited credits / ticked an LMS deadline done / added a manual course → those survive; courses that disappeared from LMS become `isDeleted`. Test in E1 (`applyImport` re-run).
3. User with no group opens Group / Materials / group filter in Tasks → explanatory empty state with create/join actions, no crash on `group == null`. Widget tests in D3, D5.
4. Score exactly 50 → «D», passed, not «отработка»; admission 49.9 → at risk. Tests in B4.
5. Web build opens Grades → import button replaced by explanation, manual entry still works; no `flutter_inappwebview` import reachable on web. Test in E2 (`isLmsImportSupported` false on web stub) + `flutter build web` in Final.

---

## Wave 0 (coordinator, sequential, on `redesign`)

### Task B0: Dependencies and l10n scaffolding

**Files:** Modify `mobile/pubspec.yaml`, `.github/workflows/dart.yml`; Create `mobile/l10n.yaml`, `mobile/tool/merge_arb.dart`, `mobile/lib/l10n/parts/common_ru.arb`, `mobile/assets/fonts/Inter-{Regular,Medium,SemiBold}.ttf` (+ `OFL.txt`), `.gitignore` entries.

**Produces:**
- Deps added: `flutter_localizations` (sdk), `flutter_inappwebview` (latest stable), `html` (latest stable). Removed: `socket_io_client`. `flutter: generate: true`. Font family `Inter` declared.
- `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_ru.arb`, `output-localization-file: app_localizations.dart`, `output-class: AppLocalizations`, `output-dir: lib/l10n/generated`, `synthetic-package: false`, `nullable-getter: false`.
- `dart run tool/merge_arb.dart` merges every `lib/l10n/parts/*_<locale>.arb` into `lib/l10n/app_<locale>.arb` for `ru`, `en`, `kk`; fails on duplicate keys; locales with missing keys get the Russian value copied and the key listed on stdout as `MISSING <locale> <key>`.
- During waves 1–2 `lib/l10n/app_*.arb` and `lib/l10n/generated/` are gitignored; CI runs `dart run tool/merge_arb.dart && flutter gen-l10n` before analyze/test.
- Key naming: `<section>_<camelCase>`; sections: `common`, `nav`, `home`, `schedule`, `tasks`, `grades`, `group`, `profile`, `auth`, `lms`, `map`.

- [ ] Add deps, font files (download Inter from the official `rsms/inter` GitHub release), l10n.yaml, merge script, a `common_ru.arb` with `common_appName`, `common_save`, `common_cancel`, `common_delete`, `common_retry`, `common_loading`.
- [ ] Run `flutter pub get && dart run tool/merge_arb.dart && flutter gen-l10n && flutter analyze && flutter test` → all pass.
- [ ] Commit `chore(mobile): add l10n scaffolding, Inter font, webview and html deps`.

---

## Wave 1 (three parallel tracks)

### Track A — Backend (one agent, worktree `wt-backend`, tasks in order)

#### Task A1: Remove LMS password login and auto-seed
**Files:** Delete `backend/src/services/lmsService.js`, `backend/src/controllers/lms.controller.js`, `backend/tests/lms.test.js`; Modify `backend/src/routes/index.js` (drop `/lms/login`), `backend/src/server.js` (no seed on empty `users`).
- [ ] Test `server does not seed on startup` is impractical; instead add to `tests/seed.test.js` nothing — just delete the code path and verify `npm test` passes and `grep -r "lms/login\|lmsService" backend/src` is empty.
- [ ] Commit `refactor(backend): remove LMS password proxy and startup auto-seed`.

#### Task A2: Remove chat and realtime
**Files:** Delete `services/chat.service.js`, `controllers/chat.controller.js` (if present), `realtime/`, chat tests; Modify `routes/index.js` (drop `/chat/*`, keep `GET /files/:name` only if materials use it), `server.js` (plain HTTP server, no Socket.IO), `services/sync.service.js` (no chat push/pull, no `emitToGroup`), `db/schema.js` (drop `MESSAGE_TYPES`, `HEADMAN_ONLY_MESSAGE_TYPES`), `package.json` (drop `socket.io`). Keep the `chat_messages` migration (no destructive migration).
- [ ] Update `tests/sync.test.js`: the sync response no longer contains `chat_messages`; a push containing `chat_messages` is ignored (200, nothing stored).
- [ ] `npm test` passes. Commit `refactor(backend): remove group chat and Socket.IO`.

#### Task A3: Equal group members
**Files:** Modify `services/sync.service.js:40` (publish `is_group` iff `user.group_id` and `data.group_id === user.group_id`), `services/group.service.js` (creator no longer becomes `headman`; any member may `updateGroup` title/`semester_start`; `getMyGroup` returns `members: [{id, name}]` ordered by name), `services/materials.service.js` (any member uploads; only uploader deletes).
**Produces:** `GET /api/groups/me` → `{ group: {id, title, invite_code, semester_start}, members: [{id, name}] }` (keep existing shape, add/confirm `members`).
- [ ] Tests: `student member can publish group task`, `non-member cannot publish group task for another group`, `any member can update semester_start`, `GET /groups/me lists members by name`, `only uploader can delete material` (another member gets 403).
- [ ] Run → fail; implement; run → pass. Commit `feat(backend): make all group members equal`.

#### Task A4: LMS sync tables
**Files:** Create migration `backend/src/db/migrations/20261026000001_create_lms_tables.js`; Modify `db/schema.js`, `services/sync.service.js` (ownership like `subjects`; `lms_courses.subject_id` must reference the user's own subject if not null), `tests/sync.test.js`.
**Produces (exact column names, all tables also get `user_id`, `server_updated_at` like existing ones):**
- `lms_courses`: id, source (`lms`|`manual`), lms_course_id (int, null), subject_id (uuid, null), classification (`inprogress`|`past`|`future`|null), title (≤255, required), teacher_name (≤160), credits (int 1..30, default 5), register_midterm, register_endterm, final_exam, total (real 0..100 or null), grade_items_json (text ≤100k or null), imported_at (epoch ms or null), is_deleted, updated_at.
- `lms_events`: id, lms_event_id (int, null), lms_course_id (int, null), title (≤255, required), course_title (≤255), event_type (`deadline`|`class`|`other`), module_name (≤64), starts_at (epoch ms, required), duration_min (int ≥0 or null), location (≤128), url (≤1024), is_done (bool), imported_at, is_deleted, updated_at.
- `lms_materials`: id, lms_module_id (int, null), lms_course_id (int, null), course_title (≤255), section_title (≤255), title (≤255, required), material_type (`file`|`folder`|`url`|`page`|`other`), url (≤1024), imported_at, is_deleted, updated_at.
- `SYNC_ORDER = ['subjects', 'lessons', 'tasks', 'subtasks', 'lms_courses', 'lms_events', 'lms_materials']`.
- [ ] Tests: push+pull round-trip per table; validation rejects `total: 101`, `event_type: 'x'`, foreign `subject_id`; LWW on `lms_courses.credits`.
- [ ] Run → fail; implement; run → pass. Commit `feat(backend): add LMS sync tables`.

#### Task A5: Postgres/Supabase config, RLS, SPA join route
**Files:** Modify `src/config/env.js`, `knexfile.js`, `.env.example`, `src/app.js`; Create migration `20261026000002_enable_rls.js` (pg only: `ALTER TABLE … ENABLE ROW LEVEL SECURITY` for every table in `public` incl. `knex_migrations*`; no-op on sqlite), `tests/env.test.js`.
**Produces:** `buildPgConnection(env) → { connectionString | host…, ssl }`: when `DATABASE_URL` is set, `ssl = { ca: fs.readFileSync(PG_SSL_CA) }` if `PG_SSL_CA` set, else `{ rejectUnauthorized: true }`; `PG_SSL=false` disables explicitly; `rejectUnauthorized: false` is never produced. App serves `index.html` for `GET /join/:code` when the web build exists.
- [ ] Tests in `env.test.js`: URL + CA path → `ssl.ca` set; URL without CA → `rejectUnauthorized: true`; `PG_SSL=false` → `ssl: false`.
- [ ] Run → fail; implement; run → pass. Commit `feat(backend): Supabase-ready pg config, RLS migration, join route`.

### Track B — Mobile foundation (one agent, on `redesign` directly, tasks in order)

#### Task B1: Theme, palette, settings, shared UI widgets
**Files:** Create `lib/core/theme/app_palette.dart`, `lib/core/theme/theme_ext.dart`, `lib/core/settings/app_settings.dart`, `lib/core/widgets/ui/{empty_state,list_row,section_header,status_label,app_text_field}.dart`; Rewrite `lib/core/theme/app_theme.dart`; Modify `lib/main.dart`; Test `test/core/app_settings_test.dart`, `test/core/ui_widgets_test.dart`.
**Produces:**
- `class AppPalette extends ThemeExtension<AppPalette>` with `Color background, surface, surfaceMuted, border, textPrimary, textSecondary, textTertiary, primary, onPrimary, accent, success, successMuted, warning, warningMuted, danger, dangerMuted`; `static const light`, `static const dark`. Neutral zinc-like greys; `primary` ≈ #18181B in light / #FAFAFA in dark; one blue `accent` for links/selection; status colours muted.
- `AppTheme.light()` / `AppTheme.dark()` → `ThemeData` (M3, `fontFamily: 'Inter'`, elevation 0 everywhere, radii per Global Constraints, `NavigationBar`/`NavigationRail` themed, `textTheme` sizes 28/22/17/15/13/12, numbers use `FontFeature.tabularFigures()` via `AppPalette`-independent `TextStyle` helpers).
- `extension ThemeX on BuildContext { AppPalette get palette; TextTheme get text; AppLocalizations get l10n; }`.
- `class AppSettings extends ChangeNotifier { ThemeMode get themeMode; Locale? get locale; Future<void> load(); Future<void> setThemeMode(ThemeMode); Future<void> setLocale(Locale?); }` — SharedPreferences keys `settings.theme_mode` (`system|light|dark`), `settings.locale` (`ru|en|kk|` empty = system). `resolveLocale(List<Locale> device) → Locale` picks kk/en/ru by language code, else `ru`.
- `EmptyState({required String title, required String message, String? actionLabel, VoidCallback? onAction})`, `ListRow({required String title, String? subtitle, Widget? leading, Widget? trailing, VoidCallback? onTap})`, `SectionHeader(String title, {Widget? trailing})`, `StatusLabel({required String text, required StatusTone tone})` with `enum StatusTone { neutral, success, warning, danger }` (text + muted background, radius 4).
- `main.dart`: `MaterialApp` gets `theme`, `darkTheme`, `themeMode`, `locale`, `localizationsDelegates`, `supportedLocales: [ru, en, kk]`, listens to `AppSettings` (passed down via constructor like `db`/`apiClient`).
- [ ] Tests: settings persist and reload; `resolveLocale([Locale('kk','KZ')]) == Locale('kk')`, `resolveLocale([Locale('de')]) == Locale('ru')`; `EmptyState` renders title/message and calls `onAction`.
- [ ] Run → fail; implement; run → pass; `flutter analyze` clean. Commit `feat(mobile): light/dark theme, palette, settings, base UI widgets`.

#### Task B2: Navigation shell
**Files:** Rewrite `lib/features/main_shell/presentation/screens/main_shell_screen.dart`; Create `lib/features/more/presentation/screens/more_screen.dart`, `lib/l10n/parts/nav_ru.arb`; Delete `lib/core/widgets/app_navigation_drawer.dart`, `lib/core/widgets/custom_sliver_app_bar.dart`, `features/portal`, `features/timeline`, `features/simulator`, `features/retakes`, `features/scholarship`, `features/reminders`, `features/admin`, `features/chat`, `features/lms/presentation/widgets/lms_modal.dart`, `core/database/chat_dao.dart` usage; Test `test/main_shell_test.dart`.
**Produces:**
- `enum AppTab { home, schedule, tasks, grades, more }`. `MainShellScreen({required AppDatabase db, required ApiClient apiClient, required AppSettings settings})`. Width < 840 → `NavigationBar`; ≥ 840 → `NavigationRail` (extended labels ≥ 1200). Tabs kept alive (`IndexedStack`). Android back on non-home tab → home tab; on home → system.
- Each tab body is a screen with its own `AppBar`; until Wave 2 the tab bodies are the existing `TimelineScreen`-free placeholders: Home → `EmptyState`, Schedule → existing `ScheduleCalendarScreen`, Tasks → existing `DeadlinesScreen`, Grades → existing `GradesScreen`, More → `MoreScreen`.
- `MoreScreen` rows: Группа → `GroupScreen` (placeholder `EmptyState` until D5), Карта AITU → existing `CampusMapScreen`, Профиль и настройки → existing `ProfileScreen`. Sync status indicator lives in `MoreScreen` header row (uses existing `SyncBloc`).
- Removed features' references to `AituDataService` disappear with them; `AituDataService` itself is deleted in B3.
- [ ] Test: phone width shows 5 destinations with `nav_*` labels; 1000 px width shows `NavigationRail`; tapping Grades switches body.
- [ ] Run → fail; implement; run → pass. Commit `feat(mobile): 4 tabs + More navigation, remove obsolete sections`.

#### Task B3: Grading domain
**Files:** Create `lib/features/grades/domain/grading_rules.dart`, `lib/features/grades/domain/grade_calculator.dart`; Delete `lib/features/grades/data/services/aitu_data_service.dart`, `lib/features/grades/data/models/grade_models.dart` (fix imports: Grades screen temporarily shows `EmptyState` until D4); Test `test/grades/grade_calculator_test.dart`.
**Produces:**
- `grading_rules.dart`: `kAdmissionWeight = 0.6`, `kFinalWeight = 0.4`, `kPassThreshold = 50.0`, `kIncreasedScholarship = 90.0`, `kRegularScholarship = 75.0`, `kDefaultCredits = 5`, `kLetterScale` = list of `(min, letter, points)` exactly per spec (95 A 4.00 … 50 D 1.00, else F 0).
- `class CourseScores { final double? midterm, endterm, finalExam, lmsTotal; final int credits; }`
- `double? admissionRating(CourseScores)` — mean of present midterm/endterm; null if both null.
- `double? courseTotal(CourseScores)` — if midterm, endterm and final all present → `0.6*admission + 0.4*final`; else `lmsTotal`; rounded to 1 decimal.
- `LetterGrade letterFor(double total)` → `class LetterGrade { String letter; double points; }`.
- `enum CourseStatus { noGrades, inProgress, passed, atRisk, failed }`; `CourseStatus statusFor(CourseScores)`: noGrades when nothing present; atRisk when admission < 50 or `requiredFinal(…, 50) > 100`; failed when final present and (final < 50 or total < 50); passed when total ≥ 50 with final present (or only lmsTotal ≥ 50); else inProgress.
- `double? requiredFinal(CourseScores, double targetTotal)` → `(target - 0.6*admission) / 0.4`, null if admission null.
- `double? weightedAverage(Iterable<CourseScores>)` and `double? gpa(Iterable<CourseScores>)` — credit-weighted over courses with non-null total; null if none.
- `enum ScholarshipStatus { increased, regular, none, unknown }`; `ScholarshipStatus scholarshipFor(Iterable<CourseScores>)` — unknown if no totals; increased if all non-null totals ≥ 90; regular if all ≥ 75; else none.
- [ ] Tests: `courseTotal(mid 80, end 90, final 70) == 79.0`; `letterFor(50).letter == 'D'`; `letterFor(49.9).letter == 'F'`; `letterFor(94.9).letter == 'A-'`; `statusFor(mid 40, end 59.8)` → atRisk; `statusFor(lmsTotal 50)` → passed; `requiredFinal(mid 80,end 90, 90) == 97.5`; `weightedAverage([(90,5),(60,10)]) == 70.0`; nulls ignored; `gpa([(95,5),(85,5)]) == 3.665` (±0.001); scholarship increased/regular/none/unknown cases.
- [ ] Run → fail; implement; run → pass. Commit `feat(mobile): grading rules and calculator`.

#### Task B4: Drift schema v2 + sync mapping
**Files:** Modify `lib/core/database/app_database.dart` (+ regenerate `.g.dart`), `lib/core/sync/sync_repository.dart`; Create `lib/core/database/lms_dao.dart`; Delete `ChatMessages` table + `chat_dao.dart`; Test `test/core/lms_dao_test.dart`, `test/core/migration_test.dart`.
**Produces:**
- Drift tables `LmsCourses`, `LmsEvents`, `LmsMaterials` — Dart camelCase of Task A4 columns + `userId` + `syncStatus` (default `'synced'`). `schemaVersion = 2`; `onUpgrade(1→2)`: create the three tables, drop `chat_messages`.
- `LmsDao` (registered on `AppDatabase`): `Stream<List<LmsCourse>> watchCourses(String userId)` (not deleted, ordered by title); `Stream<List<LmsEvent>> watchEvents(String userId, {String? type, int? fromMs, int? toMs})`; `Stream<List<LmsMaterial>> watchMaterials(String userId)`; `Future<void> upsertManualCourse(LmsCoursesCompanion)`; `Future<void> updateCredits(String id, int credits)`; `Future<void> setEventDone(String id, bool done)`; `Future<void> softDeleteCourse(String id)`. Every write sets `updatedAt = now` and `syncStatus = 'pending_update'` (or `pending_create`) like `TaskDao`.
- `sync_repository.dart`: push and pull for the three tables with exact snake_case names from A4; chat push/pull removed.
- [ ] Tests (in-memory `NativeDatabase.memory()`): manual course insert → appears in `watchCourses` and is pending; `updateCredits` marks pending; migration test opens a v1 schema file/DB and upgrades to v2 without error.
- [ ] `dart run build_runner build --delete-conflicting-outputs`; run → pass. Commit `feat(mobile): LMS tables, DAO and sync mapping`.

#### Task B5: Remove remaining demo data outside redesigned screens
**Files:** `features/auth/...auth_screen.dart` (remove quick-login buttons, prefilled `AITU26`, `IVT21A` hint), `features/files/data/services/files_repository.dart` (remove `_seedFiles`), `features/profile/...` (remove `BDA-2601`/`ИВТ-21`/`IVT21A`/«семестр 3» fallbacks), `core/utils/date_util.dart` (`academicWeekNumber(DateTime date, {DateTime? semesterStart})`: default start = 1 Sep of the academic year containing `date`, i.e. previous year for Jan–Aug), `core/services/ics_export_service.dart` (lessons from drift).
- [ ] Test `date_util_test.dart`: `academicWeekNumber(DateTime(2027,2,3))` uses 2026-09-01 start and is positive; with explicit `semesterStart` it counts from it.
- [ ] `grep -rn "AITU26\|IVT21A\|BDA-2601\|password123\|43 574\|50 110\|45\.7" mobile/lib` → empty. Commit `fix(mobile): remove demo data and fix academic week numbering`.

### Track C — LMS parsing (one agent, worktree `wt-lms`, new files only)

#### Task C1: Models, HTML parsers, fixtures
**Files:** Create `mobile/lib/features/lms/data/lms_models.dart`, `mobile/lib/features/lms/data/moodle_html_parser.dart`, `mobile/test/lms/fixtures/*.html`, `mobile/test/lms/moodle_html_parser_test.dart`; scratch extraction script lives outside the repo.
**Produces:**
- `class LmsCourseData { int lmsCourseId; String title; String? teacherName; String? classification; double? total; double? midterm; double? endterm; double? finalExam; String? gradeItemsJson; }`
- `class LmsEventData { int? lmsEventId; int? lmsCourseId; String title; String? courseTitle; LmsEventType type; String? moduleName; DateTime startsAt; int? durationMin; String? location; String? url; }`, `enum LmsEventType { deadline, classSession, other }` (stored as `deadline` / `class` / `other`).
- `class LmsMaterialData { int? lmsModuleId; int? lmsCourseId; String? courseTitle; String? sectionTitle; String title; String materialType; String? url; }`
- `class LmsProfileData { String fullName; String? email; int? lmsUserId; }`
- `class LmsImportResult { List<LmsCourseData> courses; List<LmsEventData> events; List<LmsMaterialData> materials; LmsProfileData? profile; Map<String,String> errors; }` (`errors` keys: `courses`, `grades`, `deadlines`, `classes`, `materials`, `profile`).
- `double? parseMoodleScore(String raw)` — `"0,00"` → 0.0 only when the course has graded items; `"-"`, `""`, `"–"` → null; `"85,50"` → 85.5; `"85.5 %"` → 85.5.
- `List<LmsCourseData> parseGradesOverview(String html)` (course link `course/user.php?mode=grade&id=N`, title/teacher split on `" | "`, empty rows skipped); `LmsCourseData applyCourseGradeReport(LmsCourseData base, String html)` (fills midterm/endterm/final from item names matching, case-insensitive, `register midterm|midterm|рубежный контроль 1|1-ші аралық` / `register endterm|endterm|рубежный контроль 2` / `final|финал|экзамен|емтихан`, plus `gradeItemsJson` = list of `{name, grade, range}`); `LmsProfileData parseProfile(String html)`; `List<LmsEventData> parseCalendarDay(String html, DateTime day)`; `List<LmsMaterialData> parseCourseContents(String html, int courseId, String courseTitle)`.
- Fixtures extracted from the three HAR files in the repo root with a throwaway Node script kept in the scratchpad: student name, email, user id (`21011`), and teacher names replaced by `Student Test`, `student@example.com`, `1`, `Teacher A/B/C…`. Only the main HTML documents are saved.
- [ ] Tests: overview fixture → 6 courses, first title `Physical Education (Athletics)`, teacher `Teacher A`, ids parsed, all `total == null` (Review Focus 1: `0,00` in an overview without graded items is treated as "нет оценки" — the parser marks totals null when every course is `0,00` and no report says otherwise; document this rule in the parser); profile fixture → `fullName == 'Student Test'`; `parseMoodleScore` table of cases; hand-written small HTML snippet for `applyCourseGradeReport` (Moodle user report table with Register Midterm 80, Register Endterm 90, Final exam `-`).
- [ ] Run → fail; implement with `package:html`; run → pass. Commit `feat(lms): models and Moodle HTML parsers`.

#### Task C2: AJAX JSON parsers and the in-page JS
**Files:** Create `mobile/lib/features/lms/data/moodle_ajax_parser.dart`, `mobile/lib/features/lms/data/moodle_page_script.dart`, `mobile/test/lms/moodle_ajax_parser_test.dart`.
**Produces:**
- Parsers over Moodle external-function JSON (check field names against Moodle docs via Context7 / moodledev.io): `parseEnrolledCourses(json)` (`courses[].id, fullname, …`; classification passed in), `parseActionEvents(json)` (`events[].id, name, timesort, course.id, course.fullname, modulename, url` → deadline), `parseCalendarView(json)` (`events[]` or `weeks[].days[].events[]` with `timestart`, `timeduration`, `modulename == 'attendance'` → `classSession`, `location`), `parseCourseContents(json, courseId, courseTitle)` (`[].name` section, `modules[].id, name, modname, url` → material type: resource→file, folder, url, page, else other), `applyGradeItems(LmsCourseData, json)` (`usergrades[0].gradeitems[].itemname, graderaw, gradeformatted, grademax`, same name matching as C1).
- `const String kMoodleImportScript` — a JS async function `studyplanImport(sinceSec, untilSec)` that reads `M.cfg.sesskey`, `M.cfg.wwwroot`, calls `POST /lib/ajax/service.php?sesskey=…` with batched `[{index, methodname, args}]`, and for each data kind falls back to `fetch` of the HTML page; returns `JSON.stringify({ajax: {...raw per kind or {error}}, html: {...raw per kind}})`. Kinds: courses (classifications `inprogress`, `past`), deadlines, calendar months covering `sinceSec..untilSec`, contents per course, grade items per course, overview HTML, per-course grade report HTML, profile HTML.
- `LmsImportResult buildImportResult(Map<String, dynamic> scriptOutput)` — prefers AJAX data per kind, falls back to HTML parsers from C1, collects per-kind errors without throwing.
- [ ] Tests: hand-written JSON samples per function (shapes from docs); `buildImportResult` with ajax error for grades + html overview present → courses from HTML, `errors` empty for courses; with both failing → `errors['grades']` set and other kinds still filled.
- [ ] Run → fail; implement; run → pass. Commit `feat(lms): Moodle AJAX parsers, in-page import script, result builder`.

---

## Wave 2 (parallel, after Wave 1 is merged into `redesign`)

Every D task: owns only its feature folder(s) and `lib/l10n/parts/<section>_ru.arb`; uses `context.palette`, `context.text`, `context.l10n`, `EmptyState`, `ListRow`, `SectionHeader`, `StatusLabel` from B1; adds widget tests for (a) empty state and (b) one populated state with in-memory drift; must leave `flutter analyze` clean. Run in its own worktree; before committing run `dart run tool/merge_arb.dart && flutter gen-l10n && flutter analyze && flutter test`.

#### Task D1: Home (`features/home/`, section `home`)
Today view from drift only: next lesson today (manual `lessons` for today's weekday/parity or `specificDate`, plus `lms_events` type `class` today), deadlines in the next 7 days (own + group tasks not completed + `lms_events` deadline not done), last updated grades (top 3 `lms_courses` by `updatedAt` with total). When the user has no lessons, no tasks and no courses: first-steps checklist (Добавить расписание → Schedule tab; Импортировать из LMS → Grades tab; Группа → Group screen), each item hidden once satisfied. Expose `HomeScreen({db, userId, onOpenTab(AppTab)})`; wire into shell.
Tests: empty DB → checklist with 3 items; one lesson today → shows it with time.

#### Task D2: Schedule + academic calendar (`features/schedule/`, `features/calendar/`, section `schedule`)
Week strip + day list merging `lessons` and `lms_events(type class)` (label «LMS» via `StatusLabel(neutral)`); add/edit lesson sheet (existing logic, new UI); segmented control «Пары / Календарь» to the academic calendar (keep the 12 reference events, strings to ARB, category colours from palette). Week parity from `academicWeekNumber` (B5).
Tests: empty → `EmptyState` with «Добавить пару»; one LMS class on selected day → shown with «LMS».

#### Task D3: Tasks (`features/tasks/`, section `tasks`)
List grouped by due date (Просрочено / Сегодня / Неделя / Позже / Без срока); filter chips «Все / Мои / Группа / LMS / Выполненные»; LMS deadlines read-only except done toggle (`LmsDao.setEventDone`); group tasks show author (`subjectTitle` stays; author from `userId` lookup in group members if available, else hidden). Task detail sheet redesigned (subtasks, attachments as today). «Опубликовать для группы» switch visible only when the user has a group (from SharedPreferences `group_data`).
Tests: empty → `EmptyState`; filter «Группа» with no group → empty state with join hint (Review Focus 3); LMS deadline done toggle persists.

#### Task D4: Grades (`features/grades/presentation/`, section `grades`)
Summary header: weighted average, GPA (current semester = `classification inprogress` or manual), scholarship status (`StatusLabel`), «Последний импорт: …» (max `importedAt`); list of current courses (title, letter, total, status label), «Прошлые семестры» collapsed section with overall GPA; course detail: components, admission rating, required final for 50 and 90 («нужно N на финале»; «недостижимо» if > 100), editable credits, manual component entry for `manual` courses, «Что будет, если…» slider/field for the missing final (not persisted), delete manual course. «Добавить предмет вручную». Import entry button calls `onImportLms` callback (wired in E2); on web shows the explanation text instead.
Tests: empty → `EmptyState` with import + manual actions; course with mid 80/end 90/no final → detail shows «97.5» for 90 target; course with all `total == null` → «нет оценки», excluded from average.

#### Task D5: Group + materials (`features/group/`, `features/files/` → materials, section `group`)
`GroupScreen`: no group → `EmptyState` with «Создать группу» / «Вступить по коду»; with group → title, code row (Копировать, Пригласить via `share_plus` text `group_inviteMessage(title, code, link)` where link = `<apiBase without /api>/join/<code>`), members list, «Материалы группы», «Покинуть группу» (confirm). Materials screen: tabs «Группа» (REST `/api/materials`, upload via `file_picker`, delete own) and «LMS» (`LmsDao.watchMaterials`, opens URL with `url_launcher` external browser); cached last group list in SharedPreferences for offline view. Web: on launch, if `Uri.base.path` matches `/join/<code>`, store code and prefill join field after auth.
Tests: no group → empty state with two actions (Review Focus 3); materials LMS tab lists one material from drift.

#### Task D6: Profile & settings, auth, splash, server dialog, map (`features/profile/`, `features/auth/`, `features/splash/`, `core/widgets/server_config_dialog.dart`, `features/campus_map/`, sections `profile`, `auth`, `map`)
Profile & settings: name/email (editable as today), LMS profile (from SharedPreferences `lms.profile` if present), Тема (Системная/Светлая/Тёмная → `AppSettings.setThemeMode`), Язык (Системный/Русский/English/Қазақша → `setLocale`), Напоминания (deadline reminder toggle wired to `NotificationService.scheduleDeadlineReminders`), Экспорт .ics, Сервер (dialog), Выйти. Auth/registration redesigned (no demo); splash minimal (wordmark only). Map screen: restyle only.
Tests: switching theme to dark updates `AppSettings.themeMode`; language list shows 4 options.

#### Task E1: LMS import application to drift (`features/lms/data/lms_importer.dart`; may start in Wave 1 after B4 lands)
`Future<LmsImportSummary> applyImport(AppDatabase db, String userId, LmsImportResult r, {required DateTime now})`: upsert `lms_courses` by `lmsCourseId` (source `lms`; keep `credits`; overwrite scores, title, teacher, classification, `gradeItemsJson`, `importedAt`); courses with source `lms` absent from `r.courses` → `isDeleted` (only if `errors['courses']` is absent); manual courses untouched; create `subjects` for course titles missing in the user's subjects and set `subjectId`; upsert `lms_events` by `lmsEventId` (keep `isDone`), delete-mark missing future ones of the imported kinds; upsert `lms_materials` by `lmsModuleId`; store profile JSON in SharedPreferences `lms.profile`; all writes pending for sync. `LmsImportSummary { int courses, events, classes, materials; Map<String,String> errors; }`.
Tests (in-memory drift, Review Focus 2): first import creates rows + subjects; edit credits + mark event done + add manual course, re-import with one course removed → credits/isDone kept, manual intact, removed course `isDeleted`; `errors['courses']` set → no deletions.

#### Task E2: LMS import screen (`features/lms/presentation/lms_import_screen.dart` + `lms_webview_io.dart` / `lms_webview_stub.dart`, section `lms`)
`bool get isLmsImportSupported` (false in stub/web, true on Android/iOS/Windows). Screen: explainer (пароль вводится только на странице Microsoft), then `InAppWebView` on `https://lms.astanait.edu.kz/auth/oidc/?source=loginpage`; on each load stop, evaluate `typeof M !== 'undefined' && M.cfg && M.cfg.sesskey` on `lms.astanait.edu.kz` non-login pages → run `kMoodleImportScript` via `callAsyncJavaScript` (since = start of current academic year, until = +6 months) → `buildImportResult` → `applyImport` → summary screen («Импортировано: N курсов, …»; per-kind errors listed with «Повторить»). Never read cookies; never persist anything from the WebView besides the parsed result. Wire `onImportLms` in Grades (D4) and Profile (D6) to push this screen; trigger sync after success.
Tests: stub reports unsupported; summary widget renders counts and an error line.

---

## Wave 3 (sequential)

#### Task F1: English and Kazakh translations
Fill `lib/l10n/parts/*_en.arb` and `*_kk.arb` for every key (merge script must print no `MISSING`). Kazakh: academic terminology as used by Kazakh universities; verify uncertain terms via web search; list every uncertain string with the chosen variant and alternatives in `docs/i18n-kk-review.md`.

#### Task F2: Independent Kazakh review
A different agent reviews `*_kk.arb` against `*_ru.arb` (grammar, case endings, consistency, natural phrasing, length on phone width) and edits in place; appends findings to `docs/i18n-kk-review.md`.

#### Task F3: Finalize l10n
Run merge, commit `lib/l10n/app_{ru,en,kk}.arb`, delete `lib/l10n/parts/` and `tool/merge_arb.dart`, un-ignore the ARB files (keep `generated/` ignored), CI keeps `flutter gen-l10n` before analyze. Test: pump app with `Locale('kk')` and `Locale('en')` → nav labels non-empty and different from Russian.

#### Task G1: Connect Supabase (needs user: DB password + CA cert)
Put `DATABASE_URL` (Session pooler, port 5432) and `PG_SSL_CA=certs/supabase-ca.crt` into `backend/.env` (gitignored; `backend/certs/` gitignored); run `npm run migrate` with `DB_CLIENT=pg`; verify tables and RLS via Supabase MCP `list_tables` and `get_advisors` (security); start backend and register a user from the app.

#### Task Z: Final verification
`flutter analyze`, `flutter test`, `flutter build web`, `npm test`; manual run on Windows/web via Playwright: fresh user → empty states everywhere; light/dark switch; language switch; manual grade entry + what-if. Whole-branch review by a fresh reviewer.
