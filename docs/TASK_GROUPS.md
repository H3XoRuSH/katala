# TASK_GROUPS.md — Katala Implementation Task Groups

**Version:** 1.0.0
**Date:** 2026-08-10
**Status:** Implementation-Ready
**Ordering:** Android-first (implementer has Android devices only)
**Derived from:** TASKS.md (task list), KATALA_SPEC_V3.md (spec), ARCHITECTURE.md (architecture), ARCHITECTURE_CONSISTENCY_REVIEW.md (audit)

---

> **Purpose:** This document organizes the 82 tasks from TASKS.md into 19 dependency-aware implementation groups. Each group is a coherent, independently implementable milestone that leaves the repository in a known, testable state. An AI coding agent implements one group at a time; each group ends with a quality gate before the next begins.

---

## Group Types Used

| Type | Meaning |
|------|---------|
| FOUNDATION | Project scaffold, build config, CI, directories |
| DOMAIN | Domain entities, enums, state machine, conflict detection |
| DATA | Drift schema, repository, migrations, integrity |
| NLP | Deterministic NLP pipeline stages and corpus |
| PLATFORM | Bridge interfaces, native implementations, background wiring |
| APPLICATION | Use cases, service locator, Riverpod providers |
| UI | Screens, widgets, theme, accessibility |
| NOTIFICATIONS | Notification scheduling, reconciliation, hardening |
| INTEGRATION | End-to-end wire-up and device validation |
| TESTING | Test suite completion, corpus validation, performance |
| RELIABILITY | OEM handling, missed detection, recovery |
| RELEASE | Signing, build config, privacy audit, MVP gate |

---

## MILESTONE 0 — Project Foundation

---

### GROUP-1 — Project Scaffold, Dependencies & Configuration

**Objective:** A buildable, analyzable Flutter project with all dependencies pinned, CI configured, platform targets configured, and test infrastructure in place.

**Type:** FOUNDATION

**Depends on:** None (project start)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-001 | Flutter Project Creation & Directory Structure |
| TASK-002 | Dependency Configuration |
| TASK-003 | Analysis, Linting & Formatting Configuration |
| TASK-004 | iOS Platform Configuration |
| TASK-005 | Android Platform Configuration |
| TASK-006 | Test Infrastructure Setup |

**Implementation boundary:**
- Create the Flutter scaffold and all directories per ARCHITECTURE.md §3
- Pin all dependencies; commit `pubspec.lock`
- Configure `analysis_options.yaml` with strict Flutter lint rules
- Create GitHub Actions CI with analyze, test, and build steps
- Configure iOS project: App Group entitlements, Info.plist keys, Notification Service Extension target
- Configure Android project: manifest permissions, receivers, Kotlin source directories
- Create `FakeClock`, in-memory Drift helper, and mocktail conventions
- Do NOT implement any bridge code, receivers, or extension logic
- Do NOT add any source files beyond the empty scaffold

**Expected files / areas:**
- `lib/main.dart`, `lib/app.dart`, full directory tree under `lib/`
- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`
- `.github/workflows/ci.yml`
- `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`
- `ios/KatalaNotificationExtension/` (target only, no code)
- `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle`
- `test/test_helpers/`

**Acceptance criteria:**
- `flutter create` succeeds
- `flutter analyze` passes with zero errors on the scaffold
- `flutter pub get` succeeds with no version conflicts
- `dart format --set-exit-if-changed lib/` exits 0
- `flutter build apk --debug` succeeds
- Xcode project builds with both targets
- All required directories match ARCHITECTURE.md §3
- All Info.plist keys present with human-readable descriptions
- All Android permissions declared; receivers registered in manifest
- `FakeClock` compiles; in-memory Drift helper compiles
- `flutter test` runs (even with zero tests) and succeeds
- CI workflow file exists

**Tests required:**
- CI self-verification: `flutter analyze`, `flutter test`, `flutter build apk --debug` all pass on scaffold

**Manual/device validation:** None required (scaffold only)

**Definition of done:**
- [ ] `flutter create` succeeds
- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes (even with zero tests)
- [ ] `flutter build apk --debug` succeeds
- [ ] Xcode project opens without errors
- [ ] All directories exist per ARCHITECTURE.md §3
- [ ] `pubspec.lock` is committed
- [ ] No excluded packages present in `pubspec.yaml`
- [ ] CI workflow file committed

**Risks:**
- iOS App Group entitlement misconfiguration (early catch — no code depends on it yet)
- Android SDK version mismatch with installed SDK on CI

---

## MILESTONE 1 — Domain Layer

---

### GROUP-2 — Domain Foundation & Business Logic

**Objective:** All domain types, error hierarchy, state machine, and conflict detection exist as pure Dart with zero platform dependencies. The domain layer is fully unit-testable in isolation.

**Type:** DOMAIN

**Depends on:** GROUP-1 (project must exist and analyze)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-010 | Domain Enums |
| TASK-011 | Clock Interface & SystemClock |
| TASK-012 | Domain Entities & Value Objects |
| TASK-013 | Domain Errors |
| TASK-014 | State Machine |
| TASK-015 | Conflict Detection |

**Implementation boundary:**
- Implement all 8 domain enums with String serialization matching database CHECK constraints
- Implement `Clock` abstract class, `SystemClock`, and refine `FakeClock`
- Implement all 6 domain entities/value objects as plain Dart classes
- Implement `AppError` sealed hierarchy and `Result<T, E>` sealed class
- Implement `transition()` pure function with all 8 valid transitions and guard enforcement
- Implement `ConflictDetector.detectConflicts()` and `suggestAlternative()` as pure functions
- Do NOT add ORM annotations, JSON serialization, or Flutter imports to domain
- Do NOT access database or platform bridges from domain

**Expected files / areas:**
- `lib/domain/enums/` (8 enum files)
- `lib/domain/nlp/clock.dart`
- `lib/domain/entities/` (6 entity files)
- `lib/domain/errors.dart`, `lib/domain/result.dart`
- `lib/domain/state_machine.dart`
- `lib/domain/conflict_detector.dart`
- `test/domain/state_machine_test.dart`
- `test/domain/conflict_detector_test.dart`

**Acceptance criteria:**
- All 8 enums compile; serialization values match ARCHITECTURE.md database CHECK constraints
- `Clock` interface compiles; `SystemClock` returns current time; `FakeClock` returns injected time
- All 6 entity classes compile; `ParsedReminder` and `ValidatedReminder` are separate types
- `Result<T, E>` works with pattern matching; every error has `userMessage`
- All 8 state machine transitions work correctly; guard `snooze_count < 10` blocks 11th snooze
- Terminal states (COMPLETED, DISMISSED) reject all transition attempts
- Conflict detection: ±15 min windows; `suggestAlternative()` returns time outside all conflicts
- Zero Flutter or platform imports in domain layer

**Tests required:**
- `test/domain/` — unit tests for every enum serialization value
- `test/domain/state_machine_test.dart` — every transition, every guard, terminal states, version increment, rapid concurrent transitions
- `test/domain/conflict_detector_test.dart` — ±15 min detection, alternative suggestion, edge cases (DST, midnight, empty list)

**Manual/device validation:** None (pure Dart)

**Definition of done:**
- [ ] All domain classes compile with zero errors
- [ ] All unit tests pass (`flutter test test/domain/`)
- [ ] Zero platform imports in `lib/domain/`
- [ ] State machine: all 8 transitions + guards tested
- [ ] Conflict detector: all edge cases tested
- [ ] `Result<T, E>` pattern matching works
- [ ] `flutter analyze` passes on domain code

**Risks:**
- `ResolvedContact` vs `ContactRef` naming inconsistency (resolved: use `ResolvedContact` per finding L1)
- State machine transition table completeness — verify spec §15 against implementation

---

## MILESTONE 2 — Data Layer

---

### GROUP-3 — Database Schema, Repository & Reliability

**Objective:** A working Drift/SQLite database with complete schema, repository abstraction, migration framework, optimistic locking, and startup integrity check.

**Type:** DATA

**Depends on:** GROUP-2 (domain enums, entities, and errors must exist for schema and repository)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-020 | Drift Database Schema |
| TASK-021 | Repository Interface & Drift Implementation |
| TASK-022 | Database Migrations |
| TASK-023 | Optimistic Locking |
| TASK-024 | Database Integrity Check |

**Implementation boundary:**
- Define all 4 Drift tables with CHECK constraints matching domain enum values
- Implement `ReminderRepository` abstract interface and Drift-backed implementation
- Transactional `insert()`: reminder + trigger + action in single transaction
- `update()` with `WHERE version = :expectedVersion`; retry-once with re-read
- Drift migration framework: version 1 creates all tables; WAL mode + busy_timeout
- `DatabaseIntegrityChecker`: runs `PRAGMA integrity_check` on startup
- Use `app_metadata` table for `last_reconciled_at`, `schema_version`, preferences
- Do NOT call Platform Bridges from the repository
- Do NOT schedule notifications from the data layer

**Expected files / areas:**
- `lib/data/database/database.dart`, `lib/data/database/tables.dart`
- `lib/data/database/migrations.dart`
- `lib/data/database/integrity_checker.dart`
- `lib/data/repositories/reminder_repository.dart`
- `test/data/repositories/reminder_repository_test.dart`

**Acceptance criteria:**
- `flutter pub run build_runner build` generates Drift code successfully
- All CHECK constraints present in generated SQL
- Repository interface and implementation compile
- `insert()` is transactional (all three rows or none)
- `update()` uses optimistic locking; concurrent updates from same version: only one succeeds
- Version increments on every successful update
- `OptimisticLockFailed` thrown when retry also fails
- In-memory database opens with all tables; WAL mode enabled; `busy_timeout = 3000ms`
- `integrity_check` runs on startup; passes on clean database
- `app_metadata` table stores key-value data (not `shared_preferences`)
- Schema version guard: extension schema version must be reviewed when Drift schema changes

**Tests required:**
- `test/data/repositories/reminder_repository_test.dart` — CRUD, transactions, in-memory DB
- Integration test: open → verify schema → close → re-open → verify data persists
- Concurrent update test: two repository instances, verify optimistic lock

**Manual/device validation:** None (in-memory database tests)

**Definition of done:**
- [ ] Drift code generation succeeds
- [ ] All repository methods tested with in-memory database
- [ ] Optimistic locking tested with concurrent update scenario
- [ ] Migration from version 1 works; WAL mode enabled
- [ ] Integrity check passes on clean database
- [ ] `flutter analyze` passes on data layer code
- [ ] No platform bridge imports in `lib/data/`

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #5: retry MUST re-read current state before retrying — do NOT retry with old version number
- ARCHITECTURE_CONSISTENCY_REVIEW.md M4: when Drift schema version increments, iOS extension SQL queries MUST be reviewed in same commit

---

## MILESTONE 3 — NLP Engine

---

### GROUP-4 — NLP Pipeline (All 5 Stages + Corpus)

**Objective:** A complete, deterministic 5-stage NLP pipeline that produces `ParsedReminder` from any transcript string. Fully tested with a 100+ entry corpus including English, Taglish, and edge cases.

**Type:** NLP

**Depends on:** GROUP-2 (Clock interface, domain entities, enums for `IntentType`, `ValidationIssue`)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-030 | NLP Pipeline Orchestrator & Intermediate Types |
| TASK-031 | Pre-Processor (Stage 1) |
| TASK-032 | Intent Detector (Stage 2) |
| TASK-033 | Entity Extractor (Stage 3) |
| TASK-034 | Temporal Resolver (Stage 4) |
| TASK-035 | Validator (Stage 5) |
| TASK-036 | NLP Test Corpus |

**Implementation boundary:**
- Implement `NlpPipeline.parse()` orchestrating 5 stages in fixed order
- Stage 1 (Pre-Processor): normalize, strip fillers, STT corrections, Taglish corrections
- Stage 2 (Intent Detector): English + Taglish patterns → `IntentType.GENERAL`
- Stage 3 (Entity Extractor): URL → phone → contact → time expression → title → notes (CRITICAL order)
- Stage 4 (Temporal Resolver): absolute, relative, day-of-week, combined, Filipino expressions; bare number ambiguity
- Stage 5 (Validator): produce `List<ValidationIssue>` for missing fields, ambiguous times, past times
- Each stage is a pure function; pipeline is deterministic (same input + same Clock = same output)
- Build corpus: 50 English + 25 Taglish + 25 edge cases
- Do NOT reorder stages
- Do NOT add ML/AI inference or network calls
- Do NOT resolve contacts against device (Stage 3 outputs strings only)

**Expected files / areas:**
- `lib/domain/nlp/nlp_pipeline.dart`
- `lib/domain/nlp/pre_processor.dart`
- `lib/domain/nlp/intent_detector.dart`
- `lib/domain/nlp/entity_extractor.dart`
- `lib/domain/nlp/temporal_resolver.dart`
- `lib/domain/nlp/validator.dart`
- `test/domain/nlp/nlp_pipeline_test.dart`
- `test/domain/nlp/pre_processor_test.dart`
- `test/domain/nlp/intent_detector_test.dart`
- `test/domain/nlp/entity_extractor_test.dart`
- `test/domain/nlp/temporal_resolver_test.dart`
- `test/domain/nlp/validator_test.dart`
- `test/domain/nlp/corpus/` (3 JSON/Dart files)

**Acceptance criteria:**
- `NlpPipeline.parse()` accepts transcript + Clock, returns `ParsedReminder`
- All 5 stages called in correct order (Stage 1 → 2 → 3 → 4 → 5)
- Pre-processor: "Um, remind me to call Adam tomorrow" → "remind me to call adam tomorrow"
- Intent detector: "pa-remind mo ko tumawag kay mama" → CREATE_REMINDER
- Entity extractor: "call adam tomorrow at 3pm" → title="adam", contactName="adam"
- Temporal resolver: with FakeClock Monday 10 AM, "tomorrow at 3 PM" → Tuesday 3:00 PM
- Validator: missing title → `[missingTitle]`; bare "at 3" → `[ambiguousTime]`
- 100% corpus pass rate (50 English + 25 Taglish + 25 edge cases)
- NLP pipeline has zero platform imports
- NLP is deterministic: same transcript + same FakeClock = identical `ParsedReminder`

**Tests required:**
- Individual stage unit tests: each stage with corpus-based input → expected output
- Full pipeline integration: `test/domain/nlp/nlp_pipeline_test.dart` with FakeClock
- Corpus runner: parameterized test across all 100+ entries
- Edge cases: empty string, only fillers, URLs without reminders, ambiguous times, past times, extremely long input

**Manual/device validation:** None (pure Dart)

**Definition of done:**
- [ ] All 5 NLP stages implemented
- [ ] Pipeline produces `ParsedReminder` for any input
- [ ] Corpus passes 100% (50 English + 25 Taglish + 25 edge cases)
- [ ] NLP is deterministic
- [ ] NLP has zero platform imports
- [ ] Stage order is preserved (AI Risk #1 mitigated)
- [ ] `flutter test test/domain/nlp/` passes all tests

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #1: Stage order is CRITICAL — entity extractor AFTER intent detector, temporal resolver AFTER entity extraction, validator LAST
- Taglish patterns coverage: Appendix A.2 must have complete coverage
- Bare number (1-12) must set ambiguity flag, NOT auto-resolve to AM/PM
- "mamaya" / "later" time cap at 10 PM with next-day overflow

---

## MILESTONE 4 — Platform Contracts

---

### GROUP-5 — Platform Bridge Interfaces & Permission Abstraction

**Objective:** All Dart-side platform bridge contracts defined with fake implementations for testing. The application layer can be built and tested against these interfaces without any native code.

**Type:** PLATFORM

**Depends on:** GROUP-2 (domain enums, entities, errors for bridge signatures)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-040 | SpeechBridge Interface & FakeSpeechBridge |
| TASK-041 | NotificationBridge Interface & FakeNotificationBridge |
| TASK-042 | ContactBridge Interface & FakeContactBridge |
| TASK-043 | ActionBridge Interface |
| TASK-044 | Permission Abstraction |

**Implementation boundary:**
- `SpeechBridge`: startListening/stopListening/cancel/dispose with Stream<String> partial results
- `NotificationBridge`: schedule/cancel/reconcile/configureCategories with ReconciliationResult
- `ContactBridge`: resolve(name) → List<ResolvedContact>; search strategy documented
- `ActionBridge`: launchDialer/launchSms/launchUrl (no fake needed)
- `FakeSpeechBridge`: configurable transcripts and simulated errors
- `FakeNotificationBridge`: in-memory tracking of scheduled IDs with reconciliation
- `FakeContactBridge`: Map-based contact resolution
- Riverpod providers for reactive permission state (mic, notifications, contacts, exact alarm)
- Do NOT implement any native code
- Do NOT add platform-specific imports to interfaces

**Expected files / areas:**
- `lib/platform/bridges/speech_bridge.dart`
- `lib/platform/bridges/notification_bridge.dart`
- `lib/platform/bridges/contact_bridge.dart`
- `lib/platform/bridges/action_bridge.dart`
- `lib/platform/permissions.dart`
- `test/test_helpers/fake_speech_bridge.dart`
- `test/test_helpers/fake_notification_bridge.dart`
- `test/test_helpers/fake_contact_bridge.dart`

**Acceptance criteria:**
- All 4 bridge interfaces compile
- `FakeSpeechBridge` returns configured transcripts and can simulate errors
- `FakeNotificationBridge` tracks scheduled IDs and runs reconciliation
- `FakeContactBridge` returns pre-configured contacts
- Permission providers compile and can be checked reactively
- `flutter_local_notifications` role clarified: display + action callbacks; native bridge handles scheduling + categories (per finding L3)

**Tests required:**
- Unit tests for each fake bridge: schedule/cancel/reconcile cycle
- Widget test: override permission providers with fake statuses

**Manual/device validation:** None (interfaces only)

**Definition of done:**
- [ ] All bridge interfaces compile
- [ ] All fake bridges usable in tests
- [ ] Permission providers provide reactive state
- [ ] `flutter analyze` passes

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md M3: Category registration division between native bridge and flutter_local_notifications must be clear
- `FakeNotificationBridge.reconcile()` must exercise the same algorithm interface as the real implementation
- Permission bridge uses `permission_handler` package directly per ARCHITECTURE.md §20.2

---

## MILESTONE 5 — Application Layer

---

### GROUP-6 — Core Use Cases (Create, Complete, Snooze, Delete, Edit)

**Objective:** All primary reminder lifecycle use cases implemented and testable with fake bridges and in-memory database.

**Type:** APPLICATION

**Depends on:** GROUP-2 (state machine, conflict detector), GROUP-3 (repository), GROUP-4 (NLP pipeline), GROUP-5 (bridge interfaces)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-050 | CreateReminderUseCase |
| TASK-051 | CompleteReminderUseCase |
| TASK-052 | SnoozeReminderUseCase |
| TASK-053 | DeleteReminderUseCase |
| TASK-054 | EditReminderUseCase |

**Implementation boundary:**
- `CreateReminderUseCase`: transcript → NLP → contact resolution → conflict check → persist → schedule notification (10-step flow)
- `CompleteReminderUseCase`: state machine transition → optimistic-lock persist → cancel notification
- `SnoozeReminderUseCase`: guard check → transition → re-schedule notification at snooze duration
- `DeleteReminderUseCase`: soft-delete + `UndoDeleteReminderUseCase` with notification re-schedule
- `EditReminderUseCase`: update fields; cancel + re-schedule if time changed
- All use cases return `Result<T, AppError>`
- Contact resolution at save time (not preview time) per finding M1
- Notification scheduling AFTER persistence per ADR-11
- Do NOT auto-save (ADR-6 — user must explicitly confirm)
- Do NOT call ContactBridge from within NLP

**Expected files / areas:**
- `lib/application/use_cases/create_reminder_use_case.dart`
- `lib/application/use_cases/complete_reminder_use_case.dart`
- `lib/application/use_cases/snooze_reminder_use_case.dart`
- `lib/application/use_cases/delete_reminder_use_case.dart`
- `lib/application/use_cases/edit_reminder_use_case.dart`
- `test/application/use_cases/create_reminder_use_case_test.dart`

**Acceptance criteria:**
- Full Create flow: transcript → NLP → contact resolution → conflict check → persist → schedule → returns Reminder
- Missing time → returns `ValidationFailed` with `missingTime` issue
- Conflict detected → returns `ConflictDetected` with suggested alternative
- Scheduling failure → reminder persisted; returns success with warning
- PENDING → COMPLETED transition succeeds; notification cancelled
- SNOOZED → COMPLETED transition succeeds
- Already COMPLETED → returns `InvalidStateTransition`
- Snooze: PENDING → SNOOZED with snoozeCount incremented; new notification scheduled
- 11th snooze attempt → returns failure (guard enforced)
- Soft delete sets `is_deleted = 1`; undo restores reminder + re-schedules
- Time change on edit: old notification cancelled, new scheduled

**Tests required:**
- `test/application/use_cases/create_reminder_use_case_test.dart` — FakeClock, FakeSpeechBridge, FakeNotificationBridge, FakeContactBridge, in-memory DB
- Unit tests for each use case with fake bridges
- Test: scheduling failure → reminder still persisted
- Test: conflict detected → user can save anyway (Save Anyway path)

**Manual/device validation:** None (all fakes)

**Definition of done:**
- [ ] All 5 use cases implemented
- [ ] All use case tests pass with fake bridges and in-memory DB
- [ ] Contact resolution at save time (M1 resolved)
- [ ] Notification scheduling AFTER persistence (ADR-11)
- [ ] No auto-save (ADR-6)
- [ ] `flutter analyze` passes

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md M1: Contact re-resolution at save time prevents TOCTOU
- Create flow has 10 steps; ordering is critical (NLP → contact → conflict → persist → notify)

---

### GROUP-7 — Application Infrastructure (Notification Actions, Reconciliation, DI)

**Objective:** Complete the application layer with notification action handling, reconciliation, background service locator, and Riverpod DI wiring.

**Type:** APPLICATION, PLATFORM

**Depends on:** GROUP-6 (uses Complete, Snooze, ActionBridge)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-055 | HandleNotificationActionUseCase |
| TASK-056 | ReconcileNotificationsUseCase |
| TASK-057 | ResolveContactsUseCase |
| TASK-058 | BackgroundServiceLocator |
| TASK-059 | Application Layer Riverpod Providers |

**Implementation boundary:**
- `HandleNotificationActionUseCase`: route DONE/SNOOZE/CALL/OPEN_URL/EDIT to correct use case
- `ReconcileNotificationsUseCase`: query PENDING → cancel orphans → schedule missing → detect missed → update `last_reconciled_at`
- `ResolveContactsUseCase`: 0/1/many results → disambiguation; permission denied → empty list
- `BackgroundServiceLocator`: static lazy initialization; no Riverpod, no Flutter UI imports; thread-safe
- Riverpod providers for all use cases, database, repository, and reactive stream providers
- Do NOT use Riverpod in BackgroundServiceLocator
- Do NOT reference any widget or UI class in BackgroundServiceLocator

**Expected files / areas:**
- `lib/application/use_cases/handle_notification_action_use_case.dart`
- `lib/application/use_cases/reconcile_notifications_use_case.dart`
- `lib/application/use_cases/resolve_contacts_use_case.dart`
- `lib/application/background_service_locator.dart`
- `lib/application/providers.dart`
- `test/integration/background_service_locator_test.dart`

**Acceptance criteria:**
- DONE action → reminder COMPLETED; CALL → dialer + COMPLETED; OPEN_URL → browser + COMPLETED
- SNOOZE action → reminder SNOOZED + re-notification; EDIT → returns "open app" signal
- Reconciliation: orphans cancelled; missing scheduled; missed deliveries detected and marked
- `last_reconciled_at` updated after reconciliation; reconciliation is idempotent
- iOS: respects 60-notification limit (priority queue)
- `BackgroundServiceLocator.initialize()` opens database; accessors throw if accessed before init
- No Flutter imports in `background_service_locator.dart`
- All providers compile; `ProviderScope.overrides` works with fake services
- Reactive stream providers react to database changes

**Tests required:**
- Unit tests for HandleNotificationActionUseCase with fake bridges
- Integration test for reconciliation: seed DB + fake bridge mismatch → verify convergence
- Integration test for BackgroundServiceLocator: init → use case → dispose
- Widget test: `ProviderScope.overrides` with fake services, verify providers resolve

**Manual/device validation:** None (all fakes)

**Definition of done:**
- [ ] All use cases implemented and tested
- [ ] BackgroundServiceLocator works with in-memory DB
- [ ] Reconciliation algorithm tested end-to-end
- [ ] All Riverpod providers resolve with overrides
- [ ] `flutter analyze` passes

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md M2: Background initialization must complete within 2 seconds on iOS; first-run may be slower
- Reconciliation idempotency: running twice must produce same state
- iOS 64-notification limit must be handled in reconciliation (not just in bridge)

---

## MILESTONE 6 — Android Native Implementation

---

### GROUP-8 — Android Native Bridges

**Objective:** Working native Android implementations for speech recognition, notifications (AlarmManager), contact resolution, and action launching. All bridge contracts from GROUP-5 are fulfilled.

**Type:** PLATFORM

**Depends on:** GROUP-1 (Android config from TASK-005), GROUP-5 (bridge interfaces)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-070 | Android SpeechBridgeImpl (SpeechRecognizer) |
| TASK-071 | Android NotificationBridgeImpl (AlarmManager) |
| TASK-072 | Android ContactBridgeImpl (ContactsContract) |
| TASK-073 | Android ActionBridgeImpl |

**Implementation boundary:**
- Speech: Android 13+ → `createOnDeviceSpeechRecognizer`; Android 10-12 → `EXTRA_PREFER_OFFLINE`
- Notifications: `setExactAndAllowWhileIdle()` + `setAlarmClock()` dual scheduling; NotificationChannel per category
- Contacts: `ContactsContract` with name filter (exact → prefix → contains; max 20)
- Actions: `ACTION_DIAL` (not `ACTION_CALL`); `ACTION_SENDTO` for SMS; `ACTION_VIEW` for URLs
- Method channels: `com.katala.app/speech`, `/notifications`, `/contacts`, `/actions`
- Do NOT use `ACTION_CALL` (must be `ACTION_DIAL`)
- Do NOT rely solely on `setExact` (use `setAlarmClock` too)
- Do NOT implement `getScheduledIds()` by querying AlarmManager (not reliable on Android)

**Expected files / areas:**
- `android/app/src/main/kotlin/com/katala/app/bridges/SpeechBridgeImpl.kt`
- `android/app/src/main/kotlin/com/katala/app/bridges/NotificationBridgeImpl.kt`
- `android/app/src/main/kotlin/com/katala/app/bridges/ContactBridgeImpl.kt`
- `android/app/src/main/kotlin/com/katala/app/bridges/ActionBridgeImpl.kt`

**Acceptance criteria:**
- Voice → text works on Android device
- Android 13+: `createOnDeviceSpeechRecognizer` used
- Android 10-12: `EXTRA_PREFER_OFFLINE` set
- Notifications fire at scheduled time; fire after Doze entry
- Actions appear on notification
- Exact alarm permission check works
- Contact resolution returns matches; permission denied → empty list
- `ACTION_DIAL` used (not `ACTION_CALL`); URL scheme validation rejects non-http/https

**Tests required:**
- Manual device test: speak known phrase, verify transcription
- Manual: schedule notification, verify delivery (test on Xiaomi/OPPO/Samsung if available)
- Manual: contact resolution with real contacts
- Manual: dialer, SMS, browser launching

**Manual/device validation:** Required — real Android device(s); test on at least one OEM device if available

**Definition of done:**
- [ ] All 4 native bridge implementations compile
- [ ] Speech transcription works on device
- [ ] Notifications fire with actions
- [ ] Dual scheduling (`setExactAndAllowWhileIdle` + `setAlarmClock`) implemented
- [ ] Method channels respond from Dart
- [ ] `EXTRA_PREFER_OFFLINE` documented as best-effort for Android < 13

**Risks:**
- Android < 13: `EXTRA_PREFER_OFFLINE` is a preference, not a guarantee (honestly documented per §1.11)
- OEM behavior varies widely; dual scheduling helps but is not a guarantee
- `getScheduledIds()` cannot be reliably implemented on Android — reconciled from DB state only

---

### GROUP-9 — Android Background, Receivers & Wiring

**Objective:** BootReceiver for alarm re-scheduling, WorkManager for daily reconciliation, NotificationActionReceiver for background actions, MainActivity wiring, and OEM reliability status.

**Type:** PLATFORM, NOTIFICATIONS, RELIABILITY

**Depends on:** GROUP-8 (needs NotificationBridgeImpl for alarm scheduling)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-074 | Android BootReceiver |
| TASK-075 | Android ReconciliationWorker (WorkManager) |
| TASK-076 | Android NotificationActionReceiver |
| TASK-077 | Android MainActivity & MethodChannel Registration |
| TASK-078 | Android OEM Reliability Integration |

**Implementation boundary:**
- BootReceiver: query nearest 60 PENDING reminders; re-schedule via AlarmManager; `goAsync()` within 10-second budget
- ReconciliationWorker: `PeriodicWorkRequestBuilder` (24 hours); `NetworkType.NOT_REQUIRED`; `Result.retry()` on failure
- NotificationActionReceiver: route DONE/SNOOZE/CALL/OPEN_URL; check if Flutter engine alive vs. native SQLite
- MainActivity: configure method channels; schedule ReconciliationWorker; initialize BackgroundServiceLocator
- OEM: detect reliability level (Good/Fair/Poor); per-manufacturer guidance strings
- Do NOT query all reminders in BootReceiver (limit 60 per finding L2)
- Do NOT always spin up Flutter engine from NotificationActionReceiver
- Do NOT auto-modify battery optimization settings

**Expected files / areas:**
- `android/app/src/main/kotlin/com/katala/app/receivers/BootReceiver.kt`
- `android/app/src/main/kotlin/com/katala/app/workers/ReconciliationWorker.kt`
- `android/app/src/main/kotlin/com/katala/app/receivers/NotificationActionReceiver.kt`
- `android/app/src/main/kotlin/com/katala/app/MainActivity.kt`
- `android/app/src/main/kotlin/com/katala/app/bridges/ReliabilityChecker.kt`

**Acceptance criteria:**
- After reboot, alarms re-scheduled within 10 seconds
- BootReceiver query limited to 60 nearest reminders
- Worker scheduled on startup; reconciliation runs at least once per 24 hours (best-effort)
- Notification action (Done) while app backgrounded → state updated in DB
- All 4 method channels functional from Dart
- Categories configured before any notification
- Reliability status Good/Fair/Poor based on actual device state
- Manufacturer-specific guidance shown for known OEMs; generic for unknown

**Tests required:**
- Manual: create reminders → reboot device → verify alarms fire
- Manual: `adb shell am broadcast` to trigger worker
- Manual: notification action while app backgrounded
- Manual: verify reliability status on device (or emulator with spoofed Build.MANUFACTURER)

**Manual/device validation:** Required — real Android device(s); OEM device testing strongly recommended

**Definition of done:**
- [ ] BootReceiver re-schedules alarms after reboot
- [ ] ReconciliationWorker registered and runs
- [ ] NotificationActionReceiver handles background actions
- [ ] App builds and runs on Android device
- [ ] Method channels respond to Dart calls
- [ ] OEM reliability guidance present

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md L2: BootReceiver must limit query to 60 nearest reminders for 10-second `goAsync()` budget
- OEMs may restrict WorkManager (Xiaomi, OPPO, Huawei) — be honest about reliability
- NotificationActionReceiver: Flutter engine alive check must be fast

---

## MILESTONE 7 — iOS Native Implementation

---

### GROUP-10 — iOS Native Bridges

**Objective:** Working native iOS implementations for speech recognition, notifications, contact resolution, and action launching. All bridge contracts from GROUP-5 are fulfilled.

**Type:** PLATFORM

**Depends on:** GROUP-1 (iOS config from TASK-004), GROUP-5 (bridge interfaces)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-060 | iOS SpeechBridgeImpl (SFSpeechRecognizer) |
| TASK-061 | iOS NotificationBridgeImpl (UNUserNotificationCenter) |
| TASK-062 | iOS ContactBridgeImpl (CNContactStore) |
| TASK-063 | iOS ActionBridgeImpl |

**Implementation boundary:**
- Speech: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`; 30-second max session; silence detection via timer
- Notifications: 4 categories (GENERAL, CALL, TEXT, URL) with action buttons; 64-notification limit with priority queue
- Contacts: CNContactStore search (exact → prefix → contains; max 20)
- Actions: `tel:`, `sms:`, `http:`/`https:` URL validation and launching
- Method channels: `com.katala.app/speech`, `/notifications`, `/contacts`, `/actions`
- Do NOT set `requiresOnDeviceRecognition = false`
- Do NOT store audio to disk
- Do NOT use cloud STT fallback

**Expected files / areas:**
- `ios/Bridges/SpeechBridgeImpl.swift`
- `ios/Bridges/NotificationBridgeImpl.swift`
- `ios/Bridges/ContactBridgeImpl.swift`
- `ios/Bridges/ActionBridgeImpl.swift`

**Acceptance criteria:**
- Voice → text transcription works on iOS device
- `requiresOnDeviceRecognition = true` is set; cloud-only language throws `SpeechUnavailable`
- Partial results stream to Dart; silence timeout stops recognition
- 30-second max session enforced
- Notifications fire at scheduled time; actions appear on notification banner
- More than 60 pending reminders → farthest beyond 60 not scheduled
- Contact resolution returns matches; permission denied → empty list
- `tel:` opens dialer with confirmation; URL scheme validation rejects `javascript:`/`file:`/`data:`

**Tests required:**
- Manual device test: speak known phrase, verify transcription; test with airplane mode
- Manual: schedule notification, verify delivery and actions
- Manual: contact resolution with real contacts
- Manual: dialer, SMS, browser launching

**Manual/device validation:** Required — real iOS device for speech and notifications

**Definition of done:**
- [ ] All 4 native bridge implementations compile
- [ ] Speech transcription works on device
- [ ] Notifications fire with actions
- [ ] Method channels respond from Dart
- [ ] 64-notification limit enforced (AI Risk #4 mitigated)

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #4: iOS 64-limit must use priority-queue with replacement, NOT "schedule if count < 64 else skip"
- Silence detection timing (finding L5): timer resets on each partial result
- Audio interruption handling (phone call, Siri) must be graceful

---

### GROUP-11 — iOS Background, Extension & Wiring

**Objective:** iOS notification extension for killed-app actions, background refresh task, and AppDelegate method channel wiring.

**Type:** PLATFORM, NOTIFICATIONS

**Depends on:** GROUP-10 (needs bridge implementations), GROUP-1 (TASK-004 for extension target)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-064 | iOS Notification Service Extension |
| TASK-065 | iOS BGAppRefreshTask |
| TASK-066 | iOS AppDelegate & FlutterMethodChannel Registration |

**Implementation boundary:**
- Extension: handle notification actions when main app killed; raw SQLite (not Drift); schema version guard
- Extension: `ExtensionDatabase.swift` — open shared SQLite in WAL mode; optimistic locking UPDATE
- Extension: complete within 1 second; refuse to run if schema version mismatched
- BGAppRefreshTask: register `com.katala.app.reconcile`; best-effort reconciliation
- AppDelegate: register all 4 method channels; configure notification categories on launch
- Do NOT use Drift in the extension (too heavy — raw SQLite only per ADR-2)
- Do NOT skip the schema version guard

**Expected files / areas:**
- `ios/KatalaNotificationExtension/NotificationService.swift`
- `ios/KatalaNotificationExtension/ExtensionDatabase.swift`
- `ios/Runner/AppDelegate.swift`

**Acceptance criteria:**
- Notification action while app killed → reminder status updated in DB
- Schema version mismatch → extension refuses to run (opens app)
- Extension completes within 1 second
- Cross-process DB access works (WAL mode)
- BGAppRefreshTask registered; reconciliation runs (best-effort)
- All 4 method channels functional from Dart
- Categories configured before any notification is scheduled

**Tests required:**
- Manual device test: kill app → deliver notification → tap Done → open app → verify COMPLETED
- Manual: concurrent access (main app + extension modifying same reminder)
- Manual: `_simulateLaunchForTaskWithIdentifier:` debugger command for BGAppRefreshTask

**Manual/device validation:** Required — real iOS device; extension behavior differs on simulator

**Definition of done:**
- [ ] Extension handles actions in < 1 second
- [ ] Schema version guard works
- [ ] Cross-process DB access works without corruption
- [ ] App builds and runs on iOS device
- [ ] Method channels respond to Dart calls

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md M4: extension schema version must stay in sync with Drift schema; CI check needed
- ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #2: extension MUST use App Group shared container path, NOT app sandbox
- WAL mode is mandatory for cross-process access (ADR-8)
- `NSFileProtectionCompleteUnlessOpen` required for lock-screen access (ADR-14)

---

## MILESTONE 8 — User Interface

---

### GROUP-12 — UI Foundation, Home Screen & Input Methods

**Objective:** Themed app shell with navigation, home screen with timeline, voice input overlay, text input fallback, and onboarding flow.

**Type:** UI

**Depends on:** GROUP-1 (project scaffold), GROUP-7 (Riverpod providers), GROUP-5 (SpeechBridge interface)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-080 | Theme, Typography & Color System |
| TASK-081 | App Shell & Navigation |
| TASK-082 | Home Screen (Timeline) |
| TASK-083 | Mic Button & Voice Input Overlay |
| TASK-088 | Text Input Fallback |
| TASK-090 | Onboarding Flow |

**Implementation boundary:**
- Design system: color tokens (dark + light), Inter typography, `ThemeData`
- App shell: `ProviderScope` → `MaterialApp`; push-based navigation; startup sequence (DB init → integrity → reconciliation → categories → render)
- Home screen: grouped timeline (Overdue/Today/Tomorrow/This Week/Later); reminder tiles; FAB; empty states; pull-to-refresh
- Voice input: mic button with permission check; pulsing overlay with live transcript; 30-second auto-stop
- Text input: always-available; real-time NLP parsing (300ms debounce); same pipeline as voice
- Onboarding: 3 screens (Welcome, How It Works, Permissions); first-launch only; skippable
- Do NOT add bottom navigation bar (single-screen app)
- Do NOT use `google_fonts` (fonts bundled)
- Do NOT request Contacts permission during onboarding
- Do NOT auto-save after voice input

**Expected files / areas:**
- `lib/ui/theme/colors.dart`, `lib/ui/theme/typography.dart`
- `lib/app.dart`, `lib/main.dart`
- `lib/ui/screens/home_screen.dart`
- `lib/ui/widgets/timeline_group.dart`, `lib/ui/widgets/reminder_tile.dart`
- `lib/ui/widgets/mic_button.dart`, `lib/ui/widgets/voice_input_overlay.dart`
- `lib/ui/widgets/text_input_field.dart`
- `lib/ui/screens/onboarding_screen.dart`

**Acceptance criteria:**
- App renders with dark theme by default; light theme available via toggle
- Inter font used; all color tokens accessible
- Startup sequence runs in correct order (DB → integrity → reconcile → categories → UI)
- Timeline shows overdue reminders first (expanded, red accent)
- Groups correctly categorized by time; empty state renders
- Mic button is prominent; tapping starts listening with animation
- Live transcript appears in real-time; tapping again stops and processes
- Text input always available; live preview updates as user types
- Onboarding shown only on first launch; skippable from any screen
- Microphone and Notification permissions requested on onboarding Screen 3

**Tests required:**
- Widget test: theme applied; color contrast meets 4.5:1 minimum
- Widget test: app launches; ProviderScope accessible
- Widget test: timeline renders with mock providers; grouping verified; swipe gestures
- Widget test: `FakeSpeechBridge` → transcript appears; error states
- Widget test: text input → NLP pipeline called with debounce
- Widget test: onboarding renders; completion flag saved

**Manual/device validation:** Visual verification of theme, font loading, and timeline on device/simulator

**Definition of done:**
- [ ] Dark theme renders correctly
- [ ] Home screen shows timeline with groups
- [ ] Mic button starts voice input overlay
- [ ] Text input runs NLP pipeline
- [ ] Onboarding completes and navigates to home
- [ ] All widget tests pass
- [ ] `flutter analyze` passes

**Risks:**
- Inter font bundling: verify font files load correctly on both platforms
- Voice input overlay animation must not block UI thread
- Live NLP parsing at 300ms debounce must not cause jank

---

### GROUP-13 — Reminder Interaction UI (Confirmation, Clarification, Conflict, Detail)

**Objective:** Complete the reminder creation and viewing UI: confirmation card, clarification card, conflict warning, and reminder detail screen.

**Type:** UI

**Depends on:** GROUP-6 (CreateReminderUseCase), GROUP-12 (Home screen for navigation context)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-084 | Confirmation Card |
| TASK-085 | Clarification Card |
| TASK-086 | Conflict Warning Display |
| TASK-087 | Reminder Detail Screen |

**Implementation boundary:**
- Confirmation card: parsed fields display; Save/Edit buttons; success animation; error with retry
- Clarification card: specific question per `ValidationIssue`; quick-pick chips; time picker fallback; Save disabled until complete
- Conflict warning: "Move to [alternative]" primary; "Save Anyway" secondary; "Cancel" tertiary
- Detail screen: full reminder info; action buttons (Complete/Snooze/Edit/Delete); edit mode; delivery status
- Do NOT auto-save (user must tap Save per ADR-6)
- Do NOT allow editing COMPLETED or DISMISSED reminders
- Do NOT skip contact disambiguation display

**Expected files / areas:**
- `lib/ui/widgets/confirmation_card.dart`
- `lib/ui/widgets/clarification_card.dart`
- `lib/ui/widgets/conflict_warning.dart`
- `lib/ui/screens/reminder_detail_screen.dart`

**Acceptance criteria:**
- Parsed fields displayed clearly on confirmation card
- Save calls CreateReminderUseCase; success dismisses card; failure shows retry
- Each `ValidationIssue` produces a specific, helpful clarification
- Save disabled until required fields complete
- Conflict detected → warning shown with suggested alternative
- "Move to" updates time; "Save Anyway" persists despite conflict
- Detail screen shows all fields; action buttons work; edit mode saves changes
- Delete with undo snackbar

**Tests required:**
- Widget test: render ConfirmationCard with mock ParsedReminder; tap Save; verify use case called
- Widget test: render ClarificationCard with each ValidationIssue; verify correct question and input
- Widget test: mock ConflictDetectedError; verify three options displayed
- Widget test: render ReminderDetailScreen with mock Reminder; verify all fields; tap Complete

**Manual/device validation:** Visual verification of card layouts and transitions

**Definition of done:**
- [ ] Confirmation card displays parsed reminder correctly
- [ ] Clarification card addresses each ValidationIssue specifically
- [ ] Conflict warning offers three resolution paths
- [ ] Detail screen shows complete reminder information
- [ ] All widget tests pass
- [ ] `flutter analyze` passes

**Risks:**
- Contact disambiguation UI: must handle single match, multiple matches, and no match gracefully
- Conflict "Save Anyway" path must bypass conflict check on persistence

---

### GROUP-14 — UI Polish, Settings & Accessibility

**Objective:** Settings screen, swipe gestures, undo snackbar, all empty/error states, and WCAG 2.1 AA equivalent accessibility.

**Type:** UI

**Depends on:** GROUP-12 (Home screen), GROUP-13 (Detail screen for gesture context)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-089 | Settings Screen |
| TASK-091 | Swipe Gestures & Undo Snackbar |
| TASK-092 | Empty & Error States |
| TASK-093 | Accessibility Implementation |

**Implementation boundary:**
- Settings: snooze duration, theme toggle, Android reliability section, privacy policy, diagnostics
- Swipe gestures: right → complete (green); left → delete (red); 5-second undo snackbar; long-press alternatives
- Empty/error states: empty timeline, all-caught-up, voice unavailable, DB corruption recovery, permission denied
- Accessibility: 48×48 dp targets; 4.5:1 contrast; Semantics labels; TalkBack/VoiceOver navigation; haptic feedback
- Do NOT add settings not in the spec
- Do NOT transmit diagnostic data
- Do NOT hard-delete after snackbar expires (soft delete is permanent after undo window)
- Do NOT use color-only state indicators

**Expected files / areas:**
- `lib/ui/screens/settings_screen.dart`
- `lib/ui/widgets/reminder_tile.dart` (gesture handlers)
- `lib/ui/widgets/` (error/empty state widgets: reliability_banner, empty_state, error_state, recovery_screen)
- All UI files (accessibility audit pass)

**Acceptance criteria:**
- Settings screen accessible from home; theme toggle works immediately
- Snooze duration persisted; Android reliability section shows accurate data
- Swipe right completes; swipe left deletes; undo snackbar appears for 5 seconds
- Undo reverses the action; long-press shows alternatives for screen reader users
- Every error state from spec §35.2 has corresponding UI
- Empty states are friendly, on-brand; DB corruption recovery screen is clear and actionable
- All tappable targets ≥ 48×48 dp; minimum contrast 4.5:1
- All interactive elements have Semantics labels
- TalkBack/VoiceOver can navigate all screens
- Haptic feedback on save, complete, and error

**Tests required:**
- Widget test: settings screen — tap theme toggle, verify theme changes
- Widget test: simulate swipe, verify use case called, verify undo works
- Widget test: trigger each error state, verify correct message and action buttons
- Manual accessibility audit with screen reader
- Widget test: verify Semantics labels on all interactive elements

**Manual/device validation:** Accessibility audit with TalkBack (Android) and VoiceOver (iOS)

**Definition of done:**
- [ ] Settings screen complete with all specified options
- [ ] Swipe gestures work with undo
- [ ] All empty/error states implemented
- [ ] Accessibility audit passes
- [ ] All widget tests pass
- [ ] `flutter analyze` passes

**Risks:**
- Swipe gesture conflicts with system back gesture on Android — test thoroughly
- Accessibility labels must be in English (MVP language)
- DB corruption recovery screen must handle both "Restore from Backup" and "Reset Database" paths

---

## MILESTONE 9 — First Vertical Slice

---

### GROUP-15 — End-to-End Integration & Device Validation

**Objective:** Wire the complete vertical slice: Voice → STT → NLP → Confirmation → Save → DB → Notification → Timeline. Validate on real iOS and Android devices.

**Type:** INTEGRATION, TESTING

**Depends on:** GROUP-6 (CreateReminderUseCase), GROUP-8 (Android bridges) or GROUP-10 (iOS bridges), GROUP-9 (Android receivers), GROUP-11 (iOS extension), GROUP-12 (Home + Voice UI), GROUP-13 (Confirmation/Detail UI)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-100 | End-to-End Voice-to-Persist Integration |
| TASK-101 | Device Validation — iOS |
| TASK-102 | Device Validation — Android |

**Implementation boundary:**
- Integration test: mic → STT → live transcript → NLP → confirmation → save → persist → notification → timeline
- Verify: < 5 seconds from mic tap to persisted (mid-range device)
- iOS device tests (7): voice reminder → notification fires; killed app → notification action; snooze → re-notification; call now → dialer + COMPLETED; rapid alternation → optimistic lock; airplane mode; 70+ reminders → 60-limit
- Android device tests (7): voice reminder; force-stop recovery; reboot → alarm re-schedule; background action; Doze mode; airplane mode; OEM device (if available)
- Do NOT skip the killed-app notification action test (riskiest path)
- Do NOT test only on simulator (extension/receiver behavior differs)

**Expected files / areas:**
- `test/integration/create_reminder_flow_test.dart`
- Device test logs/notes (manual)

**Acceptance criteria:**
- Full flow works end-to-end on at least one platform
- Voice-to-persisted < 5 seconds on mid-range device
- Reminder in database after save; notification scheduled; timeline reflects new reminder
- iOS: all 7 device tests pass on iOS 16+ device
- iOS: extension handles actions in < 1 second; cross-process DB access works
- Android: all 7 device tests pass on Android 10+ device
- Android: BootReceiver re-schedules alarms within 10 seconds; force-stop recovery works
- Android: Doze does not prevent notification delivery

**Tests required:**
- Integration test: `test/integration/create_reminder_flow_test.dart` (FakeSpeechBridge acceptable for CI)
- Manual device tests: all 14 tests across iOS and Android

**Manual/device validation:** REQUIRED — real iOS device and real Android device(s). This is the first proof the architecture works.

**Definition of done:**
- [ ] Voice-to-persist flow works on at least one platform
- [ ] < 5 seconds performance target met
- [ ] iOS device tests pass (7/7)
- [ ] Android device tests pass (7/7)
- [ ] Integration test passes in CI
- [ ] No architecture violations detected

**Risks:**
- Performance target (< 5 seconds) may be challenging on older devices — profile individual stages
- OEM Android devices may behave differently from stock — document variances
- iOS extension concurrency with main app must be tested under load

---

## MILESTONE 10 — Notification Hardening

---

### GROUP-16 — Notification System Reliability

**Objective:** Harden the notification system: verify category coordination between native and Dart, ensure robust ID mapping, implement stale cleanup and duplicate prevention, and validate missed notification detection.

**Type:** NOTIFICATIONS, RELIABILITY

**Depends on:** GROUP-8 (Android notifications), GROUP-10 (iOS notifications), GROUP-7 (ReconcileNotificationsUseCase)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-110 | Notification Category Coordination & Integration Test |
| TASK-111 | Notification ID Mapping & Lifecycle |
| TASK-112 | Stale Notification Cleanup & Duplicate Prevention |
| TASK-113 | Missed Notification Detection & delivery_uncertain Logic |

**Implementation boundary:**
- Category coordination: verify native categories match `flutter_local_notifications` identifiers exactly
- ID mapping: `trigger_.notification_id` stored; cancelled on cancel; re-generated on re-schedule
- Stale cleanup: reconciliation cancels notifications for COMPLETED/DISMISSED/deleted reminders
- Duplicate prevention: cancel-before-schedule; check-then-act with DB transaction
- Missed detection: gap between `last_reconciled_at` and `now`; set `delivery_uncertain` for reminders in gap
- Do NOT create categories independently in native and Dart (one source of truth: native bridge)
- Do NOT use different identifier strings between platforms
- Do NOT mark all past reminders as missed (only those in gap since last reconciliation)

**Expected files / areas:**
- `lib/platform/bridges/notification_bridge.dart` (documentation updates)
- `lib/application/use_cases/reconcile_notifications_use_case.dart` (enhanced)
- `test/integration/notification_category_test.dart`
- Native bridge files (minor updates for ID tracking)

**Acceptance criteria:**
- All 4 notification categories work with action buttons
- `onDidReceiveNotificationResponse` fires for each action type
- No identifier mismatches between native and Dart
- Every scheduled notification has DB-tracked ID
- Cancellation updates DB; re-scheduling cleans up old ID
- Reconciliation cancels notifications for COMPLETED/DISMISSED reminders
- Scheduling a notification for an already-scheduled reminder cancels old first
- No duplicate notifications fire for same reminder
- Missed deliveries correctly detected based on time gap
- `delivery_uncertain` set for reminders in the gap
- `last_reconciled_at` updated after each reconciliation
- First reconciliation (null `last_reconciled_at`) skips missed detection

**Tests required:**
- Integration test: register categories → schedule notification → tap action → verify callback
- Integration test: schedule → verify ID stored → cancel → verify ID cleared → re-schedule → verify new ID
- Integration test: seed stale notifications → run reconciliation → verify cancelled
- Unit test: seed DB with past reminders, mock `last_reconciled_at` to old date, run reconciliation, verify `delivery_uncertain`

**Manual/device validation:** Notification action tap test on both platforms

**Definition of done:**
- [ ] Category coordination test passes on both platforms
- [ ] Notification ID lifecycle is robust
- [ ] Stale notifications cleaned on reconciliation
- [ ] Duplicate notifications prevented
- [ ] Missed detection logic verified
- [ ] `flutter analyze` passes

**Risks:**
- ARCHITECTURE_CONSISTENCY_REVIEW.md M3: category identifiers must be EXACTLY identical between native bridge and flutter_local_notifications
- Race condition between scheduling and reconciliation must be handled (check-then-act with transaction)
- `last_reconciled_at` must be updated AFTER reconciliation pass, not before

---

## MILESTONE 11 — Testing & Audit

---

### GROUP-17 — Test Suite Completion

**Objective:** Comprehensive test coverage: NLP corpus run, use case integration tests, widget tests, state machine and conflict detector unit tests.

**Type:** TESTING

**Depends on:** GROUP-4 (NLP corpus), GROUP-6/7 (use cases), GROUP-12/13/14 (UI), GROUP-2 (state machine, conflict detector)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-120 | NLP Pipeline Integration Tests |
| TASK-121 | Use Case Integration Tests |
| TASK-122 | Widget Tests |
| TASK-123 | State Machine & Conflict Detection Unit Tests |

**Implementation boundary:**
- NLP corpus runner: parameterized test across all 100+ entries; 100% pass rate
- Use case integration: create flow, notification action flow, reconciliation flow, background locator, concurrent modification
- Widget tests: confirmation card, clarification card, timeline group, conflict warning, voice overlay, home screen
- State machine: every transition, guard, terminal state, version increment
- Conflict detector: ±15 min, alternative suggestion, DST, midnight boundary, empty list
- All tests use fakes (FakeClock, fake bridges, in-memory DB)
- Add CI step: `flutter test test/domain/nlp/corpus/`
- Do NOT use real bridges in integration tests
- Do NOT skip Taglish corpus entries

**Expected files / areas:**
- `test/domain/nlp/corpus_runner_test.dart`
- `test/integration/create_reminder_flow_test.dart`
- `test/integration/notification_action_flow_test.dart`
- `test/integration/reconciliation_flow_test.dart`
- `test/integration/background_service_locator_test.dart`
- `test/integration/concurrent_modification_test.dart`
- `test/ui/widgets/confirmation_card_test.dart`
- `test/ui/widgets/clarification_card_test.dart`
- `test/ui/widgets/timeline_group_test.dart`
- `test/ui/widgets/conflict_warning_test.dart`
- `test/ui/widgets/voice_input_overlay_test.dart`
- `test/ui/widgets/home_screen_test.dart`
- `test/domain/state_machine_test.dart` (expanded)
- `test/domain/conflict_detector_test.dart` (expanded)

**Acceptance criteria:**
- 100% NLP corpus pass rate; test runs in CI
- All integration tests pass with fake bridges and in-memory DB
- All widget tests pass with `ProviderScope.overrides`
- Every state machine transition has a test; every guard has a test
- Conflict detector edge cases all pass; 100% coverage on state machine and conflict detector
- All tests run in CI without physical device

**Tests required:** This group creates/expands the tests themselves. Self-validating: `flutter test` must pass all.

**Manual/device validation:** None (all automated)

**Definition of done:**
- [ ] `flutter test` passes all tests (unit, widget, integration, NLP corpus)
- [ ] NLP corpus 100% pass (50 English + 25 Taglish + 25 edge cases)
- [ ] State machine: 100% coverage on transitions and guards
- [ ] Conflict detector: all edge cases pass
- [ ] CI step runs all tests

**Risks:**
- Adding new corpus entries that break existing cases must be caught by CI
- Integration tests must be fast enough for CI (in-memory DB is key)
- Widget tests must not depend on real device features

---

### GROUP-18 — Performance Profiling & Network Audit

**Objective:** Profile the voice-to-persist flow to meet < 5 second target, and set up network traffic audit to verify zero network requests.

**Type:** TESTING, RELIABILITY

**Depends on:** GROUP-15 (end-to-end flow working)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-124 | Performance Profiling |
| TASK-125 | Network Traffic Audit Setup |

**Implementation boundary:**
- Performance: measure STT, NLP, contact resolution, DB transaction, notification scheduling individually
- Target: total < 5 seconds on mid-range device; NLP < 100ms; DB insert < 50ms; timeline update < 100ms
- Database indices: ensure on `scheduled_time_utc`, `status`, `reminder_id`
- Network audit: mitmproxy script; assert zero HTTP/HTTPS from Katala process
- Allowlist: `tel:` and user-initiated `https://` actions excluded
- Do NOT add performance-measurement dependencies
- Do NOT ship debug timing logs in release builds
- Do NOT block CI on network audit if mitmproxy unavailable (make it manual gate)

**Expected files / areas:**
- `test/performance/` (profiling notes/scripts)
- `test/network_audit/` (mitmproxy script + instructions)

**Acceptance criteria:**
- Voice-to-persisted < 5 seconds on mid-range device
- NLP pipeline < 100ms; database insert < 50ms; timeline update < 100ms
- Database indices in place on key columns
- Network audit script exists; audit passes on release build
- Zero unexpected network connections detected
- Procedure documented for manual runs

**Tests required:**
- Manual profiling with device-side timing
- Manual network audit run

**Manual/device validation:** Required — real device profiling; mitmproxy network capture

**Definition of done:**
- [ ] Performance targets met or documented as requiring optimization
- [ ] Database indices verified
- [ ] Network audit script created and documented
- [ ] Network audit passes (zero unexpected requests)

**Risks:**
- Performance targets may be challenging on older devices; if not met, document as known limitation
- Drift reactive stream performance (timeline update < 100ms) depends on query optimization
- Network audit requires mitmproxy setup on CI or manual run

---

## MILESTONE 12 — Release

---

### GROUP-19 — Build, Release & Final Gate

**Objective:** Finalize iOS and Android release configuration, run complete privacy verification, and execute the MVP final gate checklist.

**Type:** RELEASE

**Depends on:** ALL previous groups (complete implementation)

**Tasks:**

| Task ID | Title |
|---------|-------|
| TASK-130 | iOS Signing, Entitlements & Release Configuration |
| TASK-131 | Android Signing, Manifest & Release Configuration |
| TASK-132 | Final Privacy Verification |
| TASK-133 | MVP Final Gate Checklist |

**Implementation boundary:**
- iOS: verify both targets have App Group entitlements; configure release signing; archive IPA; privacy nutrition labels
- Android: create release keystore; configure ProGuard/R8; build release APK/AAB; Play Store data safety form
- Privacy: 12 checks (zero network, on-device STT, no analytics, no crash reporting, no ads, no accounts, audio not stored, font bundled, DB excluded from backups, no personal data logging, usage descriptions, contextual contacts)
- MVP gate: all 40+ functional, architecture, privacy, platform, testing, and build checkboxes from TASK-133
- Do NOT commit keystore or passwords
- Do NOT ship debug builds as release
- Do NOT skip any privacy check
- Do NOT mark items complete without verification

**Expected files / areas:**
- `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, Xcode project settings
- `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, keystore
- This is primarily a verification/checklist pass, not new code

**Acceptance criteria:**
- Release IPA builds and archives; both targets have correct entitlements
- Privacy descriptions present; App Store compliance passes
- Release APK/AAB builds and signs; ProGuard/R8 enabled
- Play Store compliance passes
- All 12 privacy checks pass
- Network audit shows zero requests
- Dependency audit shows only whitelisted packages
- Every MVP final gate checkbox ticked
- Any unticked item has documented reason and plan

**Tests required:**
- Manual: archive → validate → export IPA
- Manual: `flutter build apk --release` → install → smoke test
- Manual: network traffic audit pass
- Manual: full MVP gate checklist walkthrough

**Manual/device validation:** Required — release builds must be smoke-tested on real devices

**Definition of done:**
- [ ] Release IPA builds and archives successfully
- [ ] Release APK/AAB builds and signs successfully
- [ ] Privacy verification: all 12 checks pass
- [ ] MVP final gate: every checkbox ticked
- [ ] CI passes (analyze, test, build)
- [ ] `flutter analyze` zero errors
- [ ] `dart format` compliant
- [ ] `pubspec.lock` committed

**Risks:**
- Apple Developer account and signing certificates must be available for iOS release
- Android keystore management: lost keystore = cannot update app on Play Store
- Privacy nutrition labels must be accurate (legal risk if incorrect)
- OEM device testing for Android may reveal issues at final gate

---

## Recommended Implementation Order

```
GROUP-1   (Project Foundation)
   ↓
GROUP-2   (Domain Layer)
   ↓
   ├──→ GROUP-3   (Database & Persistence)  ──┐
   ├──→ GROUP-4   (NLP Pipeline)             ──┤  ← can run in PARALLEL
   └──→ GROUP-5   (Bridge Interfaces)        ──┘
                      ↓
                GROUP-6   (Core Use Cases)
                      ↓
                GROUP-7   (App Infrastructure)
                      ↓
         ┌────────────┼────────────┐
         ↓            ↓            ↓
    GROUP-8       GROUP-10     GROUP-12
    (Android      (iOS         (UI Foundation)
    Bridges)      Bridges)          ↓
         ↓            ↓        GROUP-13
    GROUP-9       GROUP-11     (Reminder UI)
    (Android      (iOS              ↓
    Bg)           Bg/Ext)      GROUP-14
         │            │        (UI Polish)
         └────────────┼────────────┘
                      ↓
                GROUP-15  (First Vertical Slice)
                      ↓
                GROUP-16  (Notification Hardening)
                      ↓
                GROUP-17  (Test Suite)
                      ↓
                GROUP-18  (Performance & Audit)
                      ↓
                GROUP-19  (Build, Release & Gate)
```

**Key dependency notes:**

- **GROUP-2 → GROUP-3/4/5:** Domain is the foundation for everything. GROUP-3 (Database), GROUP-4 (NLP), and GROUP-5 (Bridge Interfaces) can all start after Domain and run in parallel — they have no dependencies on each other.
- **GROUP-5 → GROUP-6:** Application layer needs all bridge interfaces defined before use cases can reference them.
- **GROUP-6 → GROUP-7:** Infrastructure use cases (HandleAction, Reconcile, BackgroundLocator) depend on core use cases (Complete, Snooze).
- **GROUP-7 → GROUP-8/10/12:** After the application layer is complete, Android native, iOS native, and UI can proceed in parallel.
- **GROUP-10 → GROUP-11:** iOS background/extension needs iOS bridges built first.
- **GROUP-8 → GROUP-9:** Android background needs Android bridges (especially NotificationBridge) built first.
- **GROUP-12 → GROUP-13 → GROUP-14:** UI builds incrementally: foundation → interaction → polish.
- **GROUP-8/9 + GROUP-10/11 + GROUP-12/13/14 → GROUP-15:** The first vertical slice requires at least one platform's native layer AND the core UI to be complete.
- **GROUP-16:** Notification hardening can start after both platforms' notification implementations are done.
- **GROUP-17/18:** Testing and performance work requires the vertical slice to be functional.
- **GROUP-19:** Release is the final gate — depends on everything.

---

## Parallel Execution Opportunities

| Parallel Set | Groups | Rationale |
|-------------|--------|-----------|
| **After Domain** | GROUP-3, GROUP-4, GROUP-5 | Database, NLP, and Bridge Interfaces share no dependencies; different areas |
| **After App Layer** | GROUP-8+9 (Android), GROUP-10+11 (iOS), GROUP-12+13+14 (UI) | Three independent streams: Android native, iOS native, Flutter UI |
| **Within UI** | GROUP-13 tasks (084-087) | Confirmation, Clarification, Conflict, Detail can be built in parallel after GROUP-12 |
| **Within Testing** | GROUP-17 tasks (120-123) | NLP pass, use case tests, widget tests, state machine tests are independent |
| **After Vertical Slice** | GROUP-16, GROUP-17, GROUP-18 | Notification hardening, test suite, and performance can partially overlap |

---

## Critical Path

```
GROUP-1
   ↓
GROUP-2
   ↓
GROUP-5   (Bridge Interfaces — on critical path to App Layer)
   ↓
GROUP-6   (Core Use Cases)
   ↓
GROUP-7   (App Infrastructure)
   ↓
GROUP-12  (UI Foundation — needed for vertical slice)
   ↓
GROUP-13  (Reminder UI)
   ↓
GROUP-15  (First Vertical Slice — MVP proof)
   ↓
GROUP-19  (Release Gate)
```

**Total critical path groups:** 10

Groups that are OFF the critical path (can slip without delaying MVP):
- GROUP-3 (Database) — can be built in parallel with NLP; needed by GROUP-6
- GROUP-4 (NLP) — on critical path through GROUP-6 dependency, but early enough to not delay
- GROUP-8/9 (Android) — parallel with iOS; at least one platform needed for GROUP-15
- GROUP-10/11 (iOS) — parallel with Android
- GROUP-14 (UI Polish) — can slip past vertical slice
- GROUP-16 (Notification Hardening) — can slip past vertical slice
- GROUP-17 (Test Suite) — can slip past vertical slice
- GROUP-18 (Performance & Audit) — can slip past vertical slice

---

## MVP Boundary

**MVP groups:** GROUP-1 through GROUP-19 (all groups — Katala MVP is the complete set)

All 82 tasks from TASKS.md are MVP scope. KATALA_SPEC_V3.md §4 defines MVP scope as: voice/text reminder creation, deterministic NLP, time-based local notifications with action buttons, conflict detection, reconciliation, English + Taglish support, iOS 16+ and Android 10+. There are no Post-MVP tasks in TASKS.md — deferred features (recurrence, geofence, location-based reminders, edit/delete/query NLP intents, subtasks, cloud sync, export/import) are explicitly excluded from the task list.

---

## Earliest Practical Vertical Slice

The TASKS.md dependency graph places the formal vertical slice at GROUP-15 (TASK-100), which requires nearly all preceding groups. However, an earlier **soft vertical slice** is achievable after GROUP-13 without any native code:

**Soft Slice (after GROUP-13):**
```
Text Input → NLP (GROUP-4) → Confirmation Card (GROUP-13) → Save → DB (GROUP-3) → Timeline (GROUP-12)
```
This validates the core NLP → persist → display loop entirely with fake bridges and in-memory DB. It proves the architecture works from text input through persistence to UI display. What it lacks: voice input, real notifications, platform bridges, background actions.

**Hard Slice (GROUP-15):** Adds real voice input (via native STT bridge) and real notification scheduling. This is the first true end-to-end validation.

The soft slice is a recommended checkpoint: after GROUP-13, run the text-to-timeline flow manually before investing in native bridge implementation.

---

## Task Coverage Audit

| Task ID | Task Title | Group | Milestone |
|---------|-----------|-------|-----------|
| TASK-001 | Flutter Project Creation & Directory Structure | GROUP-1 | M0 — Foundation |
| TASK-002 | Dependency Configuration | GROUP-1 | M0 — Foundation |
| TASK-003 | Analysis, Linting & Formatting Configuration | GROUP-1 | M0 — Foundation |
| TASK-004 | iOS Platform Configuration | GROUP-1 | M0 — Foundation |
| TASK-005 | Android Platform Configuration | GROUP-1 | M0 — Foundation |
| TASK-006 | Test Infrastructure Setup | GROUP-1 | M0 — Foundation |
| TASK-010 | Domain Enums | GROUP-2 | M1 — Domain |
| TASK-011 | Clock Interface & SystemClock | GROUP-2 | M1 — Domain |
| TASK-012 | Domain Entities & Value Objects | GROUP-2 | M1 — Domain |
| TASK-013 | Domain Errors | GROUP-2 | M1 — Domain |
| TASK-014 | State Machine | GROUP-2 | M1 — Domain |
| TASK-015 | Conflict Detection | GROUP-2 | M1 — Domain |
| TASK-020 | Drift Database Schema | GROUP-3 | M2 — Data |
| TASK-021 | Repository Interface & Drift Implementation | GROUP-3 | M2 — Data |
| TASK-022 | Database Migrations | GROUP-3 | M2 — Data |
| TASK-023 | Optimistic Locking | GROUP-3 | M2 — Data |
| TASK-024 | Database Integrity Check | GROUP-3 | M2 — Data |
| TASK-030 | NLP Pipeline Orchestrator & Intermediate Types | GROUP-4 | M3 — NLP |
| TASK-031 | Pre-Processor (Stage 1) | GROUP-4 | M3 — NLP |
| TASK-032 | Intent Detector (Stage 2) | GROUP-4 | M3 — NLP |
| TASK-033 | Entity Extractor (Stage 3) | GROUP-4 | M3 — NLP |
| TASK-034 | Temporal Resolver (Stage 4) | GROUP-4 | M3 — NLP |
| TASK-035 | Validator (Stage 5) | GROUP-4 | M3 — NLP |
| TASK-036 | NLP Test Corpus | GROUP-4 | M3 — NLP |
| TASK-040 | SpeechBridge Interface & FakeSpeechBridge | GROUP-5 | M4 — Platform Contracts |
| TASK-041 | NotificationBridge Interface & FakeNotificationBridge | GROUP-5 | M4 — Platform Contracts |
| TASK-042 | ContactBridge Interface & FakeContactBridge | GROUP-5 | M4 — Platform Contracts |
| TASK-043 | ActionBridge Interface | GROUP-5 | M4 — Platform Contracts |
| TASK-044 | Permission Abstraction | GROUP-5 | M4 — Platform Contracts |
| TASK-050 | CreateReminderUseCase | GROUP-6 | M5 — Application |
| TASK-051 | CompleteReminderUseCase | GROUP-6 | M5 — Application |
| TASK-052 | SnoozeReminderUseCase | GROUP-6 | M5 — Application |
| TASK-053 | DeleteReminderUseCase | GROUP-6 | M5 — Application |
| TASK-054 | EditReminderUseCase | GROUP-6 | M5 — Application |
| TASK-055 | HandleNotificationActionUseCase | GROUP-7 | M5 — Application |
| TASK-056 | ReconcileNotificationsUseCase | GROUP-7 | M5 — Application |
| TASK-057 | ResolveContactsUseCase | GROUP-7 | M5 — Application |
| TASK-058 | BackgroundServiceLocator | GROUP-7 | M5 — Application |
| TASK-059 | Application Layer Riverpod Providers | GROUP-7 | M5 — Application |
| TASK-060 | iOS SpeechBridgeImpl (SFSpeechRecognizer) | GROUP-10 | M7 — iOS |
| TASK-061 | iOS NotificationBridgeImpl (UNUserNotificationCenter) | GROUP-10 | M7 — iOS |
| TASK-062 | iOS ContactBridgeImpl (CNContactStore) | GROUP-10 | M7 — iOS |
| TASK-063 | iOS ActionBridgeImpl | GROUP-10 | M7 — iOS |
| TASK-064 | iOS Notification Service Extension | GROUP-11 | M7 — iOS |
| TASK-065 | iOS BGAppRefreshTask | GROUP-11 | M7 — iOS |
| TASK-066 | iOS AppDelegate & FlutterMethodChannel Registration | GROUP-11 | M7 — iOS |
| TASK-070 | Android SpeechBridgeImpl (SpeechRecognizer) | GROUP-8 | M6 — Android |
| TASK-071 | Android NotificationBridgeImpl (AlarmManager) | GROUP-8 | M6 — Android |
| TASK-072 | Android ContactBridgeImpl (ContactsContract) | GROUP-8 | M6 — Android |
| TASK-073 | Android ActionBridgeImpl | GROUP-8 | M6 — Android |
| TASK-074 | Android BootReceiver | GROUP-9 | M6 — Android |
| TASK-075 | Android ReconciliationWorker (WorkManager) | GROUP-9 | M6 — Android |
| TASK-076 | Android NotificationActionReceiver | GROUP-9 | M6 — Android |
| TASK-077 | Android MainActivity & MethodChannel Registration | GROUP-9 | M6 — Android |
| TASK-078 | Android OEM Reliability Integration | GROUP-9 | M6 — Android |
| TASK-080 | Theme, Typography & Color System | GROUP-12 | M8 — UI |
| TASK-081 | App Shell & Navigation | GROUP-12 | M8 — UI |
| TASK-082 | Home Screen (Timeline) | GROUP-12 | M8 — UI |
| TASK-083 | Mic Button & Voice Input Overlay | GROUP-12 | M8 — UI |
| TASK-088 | Text Input Fallback | GROUP-12 | M8 — UI |
| TASK-090 | Onboarding Flow | GROUP-12 | M8 — UI |
| TASK-084 | Confirmation Card | GROUP-13 | M8 — UI |
| TASK-085 | Clarification Card | GROUP-13 | M8 — UI |
| TASK-086 | Conflict Warning Display | GROUP-13 | M8 — UI |
| TASK-087 | Reminder Detail Screen | GROUP-13 | M8 — UI |
| TASK-089 | Settings Screen | GROUP-14 | M8 — UI |
| TASK-091 | Swipe Gestures & Undo Snackbar | GROUP-14 | M8 — UI |
| TASK-092 | Empty & Error States | GROUP-14 | M8 — UI |
| TASK-093 | Accessibility Implementation | GROUP-14 | M8 — UI |
| TASK-100 | End-to-End Voice-to-Persist Integration | GROUP-15 | M9 — First Vertical Slice |
| TASK-101 | Device Validation — iOS | GROUP-15 | M9 — First Vertical Slice |
| TASK-102 | Device Validation — Android | GROUP-15 | M9 — First Vertical Slice |
| TASK-110 | Notification Category Coordination & Integration Test | GROUP-16 | M10 — Notification Hardening |
| TASK-111 | Notification ID Mapping & Lifecycle | GROUP-16 | M10 — Notification Hardening |
| TASK-112 | Stale Notification Cleanup & Duplicate Prevention | GROUP-16 | M10 — Notification Hardening |
| TASK-113 | Missed Notification Detection & delivery_uncertain Logic | GROUP-16 | M10 — Notification Hardening |
| TASK-120 | NLP Pipeline Integration Tests | GROUP-17 | M11 — Testing |
| TASK-121 | Use Case Integration Tests | GROUP-17 | M11 — Testing |
| TASK-122 | Widget Tests | GROUP-17 | M11 — Testing |
| TASK-123 | State Machine & Conflict Detection Unit Tests | GROUP-17 | M11 — Testing |
| TASK-124 | Performance Profiling | GROUP-18 | M11 — Testing |
| TASK-125 | Network Traffic Audit Setup | GROUP-18 | M11 — Testing |
| TASK-130 | iOS Signing, Entitlements & Release Configuration | GROUP-19 | M12 — Release |
| TASK-131 | Android Signing, Manifest & Release Configuration | GROUP-19 | M12 — Release |
| TASK-132 | Final Privacy Verification | GROUP-19 | M12 — Release |
| TASK-133 | MVP Final Gate Checklist | GROUP-19 | M12 — Release |

**Verification:** All 82 tasks from TASKS.md appear exactly once. Total: 82 tasks in 19 groups across 12 milestones. ✓

---

## Group Completion Checklist (Reusable)

Every group must pass this gate before the next group begins:

- [ ] All tasks in group completed per their individual acceptance criteria
- [ ] Acceptance criteria for the group satisfied
- [ ] `flutter test` passes (all tests — unit, widget, integration as applicable)
- [ ] `flutter analyze` produces zero errors
- [ ] `dart format --set-exit-if-changed lib/ test/` exits 0
- [ ] Code follows ARCHITECTURE.md layer dependency rules (§4)
- [ ] No architecture violations (business logic in UI, data layer calling bridges, etc.)
- [ ] No unrelated files changed (only files within the group's implementation boundary)
- [ ] No future group tasks implemented (scope discipline)
- [ ] No unexplained TODOs remain
- [ ] Manual/device tests completed where required by the group
- [ ] Git working tree reviewed — only intended changes
- [ ] Ready for next group

---

*End of TASK_GROUPS.md*
