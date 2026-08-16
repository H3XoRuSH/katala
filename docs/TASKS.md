# TASKS.md — Katala Implementation Task Decomposition

**Version:** 1.0.0
**Date:** 2026-08-10
**Status:** Implementation-Ready
**Derived from:** KATALA_SPEC_V3.md (WHAT), ARCHITECTURE.md (HOW), ARCHITECTURE_CONSISTENCY_REVIEW.md (audit)
**Target implementer:** AI coding agent (Claude Sonnet 4.6)

---

> **Purpose:** This document is the implementation roadmap. It converts the finalized architecture into a dependency-aware, incremental task plan. Work through tasks in order; each task is independently understandable and testable.

---

## AI Coding Agent Safety Rules

These rules are **non-negotiable**. Every task assumes compliance.

1. Follow ARCHITECTURE.md — do not redesign.
2. Follow KATALA_SPEC_V3.md — do not invent product behavior.
3. Do not replace native bridges with convenient packages (no `speech_to_text`).
4. Do not add network/cloud functionality.
5. Do not bypass application/use-case boundaries.
6. Do not put business logic in UI.
7. Do not duplicate business logic across platforms.
8. Do not add dependencies without justification.
9. Write tests with implementation.
10. Stop and report architectural conflicts — do not silently resolve disagreements between source documents.

---

## Definition of Done (Global)

Every task is complete only when ALL of the following are satisfied:

- [ ] Implementation matches the task scope
- [ ] Tests exist and pass (`flutter test` for Dart; platform tests where specified)
- [ ] `flutter analyze` produces zero errors
- [ ] Code follows ARCHITECTURE.md layer dependency rules (§4)
- [ ] No unexplained TODOs remain
- [ ] Acceptance criteria are demonstrably met
- [ ] No architecture violations (business logic in UI, data layer calling bridges, etc.)

---

## Table of Contents

- [Phase 0 — Project Foundation](#phase-0--project-foundation)
- [Phase 1 — Domain Foundation](#phase-1--domain-foundation)
- [Phase 2 — Persistence](#phase-2--persistence)
- [Phase 3 — Deterministic NLP](#phase-3--deterministic-nlp)
- [Phase 4 — Platform Bridge Interfaces](#phase-4--platform-bridge-interfaces)
- [Phase 5 — Application Layer](#phase-5--application-layer)
- [Phase 6 — iOS Native Implementation](#phase-6--ios-native-implementation)
- [Phase 7 — Android Native Implementation](#phase-7--android-native-implementation)
- [Phase 8 — UI Implementation](#phase-8--ui-implementation)
- [Phase 9 — First Vertical Slice (M3)](#phase-9--first-vertical-slice-m3)
- [Phase 10 — Notification System Hardening](#phase-10--notification-system-hardening)
- [Phase 11 — Integration, Testing & Polish](#phase-11--integration-testing--polish)
- [Phase 12 — Build, Release & Final Gate](#phase-12--build-release--final-gate)
- [Dependency Graph](#dependency-graph)
- [Milestones](#milestones)
- [MVP Final Gate Checklist](#mvp-final-gate-checklist)
- [MEDIUM Findings Resolution](#medium-findings-resolution)
- [LOW Findings Resolution](#low-findings-resolution)

---

## Phase 0 — Project Foundation

---

### TASK-001 — Flutter Project Creation & Directory Structure

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** None

**Purpose:** Create the Flutter project and establish the complete directory structure as defined by ARCHITECTURE.md §3.

**Scope:**
- `flutter create katala` with org `com.katala.app`
- Create the full directory tree from ARCHITECTURE.md §3:
  - `lib/main.dart`, `lib/app.dart`
  - `lib/ui/` (screens, widgets, theme)
  - `lib/application/use_cases/`
  - `lib/domain/` (entities, enums, nlp, validation)
  - `lib/data/` (repositories, dao, database)
  - `lib/platform/bridges/` (Dart interfaces)
  - `test/` mirroring lib structure
  - `ios/Bridges/`, `ios/KatalaNotificationExtension/`
  - `android/app/src/main/kotlin/com/katala/app/bridges/`, `receivers/`, `workers/`
- `assets/fonts/` directory for Inter font files
- `assets/sounds/` for notification chirp

**Files / directories:** All directories per ARCHITECTURE.md §3.

**Architecture:** ARCHITECTURE.md §3.

**Acceptance criteria:**
- `flutter analyze` succeeds on the empty scaffold
- All directories exist as specified
- `pubspec.yaml` includes the project name `katala`

**Tests:** Not applicable (scaffold only).

**Do not:**
- Add any source files beyond the empty scaffold
- Remove the default test directory
- Create any additional directories not in the architecture

---

### TASK-002 — Dependency Configuration

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Pin all dependencies as specified in ARCHITECTURE.md §22.1 and KATALA_SPEC_V3.md §40.2.

**Scope:**
- Configure `pubspec.yaml` with exact versions for:
  - `drift`, `drift_flutter`, `sqlite3_flutter_libs`
  - `flutter_riverpod`, `riverpod_annotation`
  - `path_provider`, `permission_handler`, `url_launcher`
  - `uuid`, `intl`, `timezone`
  - `flutter_local_notifications`, `shared_preferences`
- Dev dependencies: `build_runner`, `drift_dev`, `mocktail`, `flutter_test`
- Bundle Inter font (Regular 400, Medium 500, SemiBold 600, Bold 700) in `assets/fonts/`
- Configure font declarations in `pubspec.yaml`
- Run `flutter pub get` and commit `pubspec.lock`

**Files / directories:** `pubspec.yaml`, `pubspec.lock`, `assets/fonts/`

**Architecture:** ARCHITECTURE.md §22.1, §21.4; KATALA_SPEC_V3.md §40.2.

**Acceptance criteria:**
- `flutter pub get` succeeds with no version conflicts
- `pubspec.lock` is committed
- All required packages appear in `pubspec.yaml`
- No excluded packages (`speech_to_text`, `google_fonts`, `http`, `dio`, firebase_*) are present
- Inter font files exist in `assets/fonts/`

**Tests:** Not applicable.

**Do not:**
- Add any package not in the whitelist (KATALA_SPEC_V3.md §40.2)
- Use `google_fonts` package
- Use `speech_to_text` package
- Use caret constraints — pin exact versions

---

### TASK-003 — Analysis, Linting & Formatting Configuration

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Configure static analysis and code formatting to enforce code quality before any implementation begins.

**Scope:**
- Configure `analysis_options.yaml` with strict Flutter lint rules
- Enable: `unused_import`, `unused_local_variable`, `always_declare_return_types`, `avoid_dynamic_calls`, `no_logic_in_create_state`, `use_key_in_widget_constructors`
- Configure line length: 120 characters
- Configure `dart format` settings
- Add GitHub Actions CI configuration (`.github/workflows/ci.yml`):
  - Step 1: `flutter analyze`
  - Step 2: `flutter test`
  - Step 3: `flutter build ios --release --no-codesign` (verify build)
  - Step 4: `flutter build apk --release` (verify build)

**Files / directories:** `analysis_options.yaml`, `.github/workflows/ci.yml`

**Architecture:** ARCHITECTURE.md §23.7 (CI Pipeline).

**Acceptance criteria:**
- `flutter analyze` runs with zero errors on scaffold
- `dart format --set-exit-if-changed lib/` exits 0
- CI workflow file exists with all four steps

**Tests:** Verify CI passes on scaffold.

**Do not:**
- Add network traffic audit to CI yet (that comes in Phase 11)
- Skip lint configuration — it must exist before any business code

---

### TASK-004 — iOS Platform Configuration

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Configure the iOS project with App Group entitlements, Info.plist keys, and Notification Service Extension target.

**Scope:**
- Create App Group identifier: `group.com.katala.app`
- Add App Group entitlement to main app target
- Add App Group entitlement to Notification Service Extension target
- Create Notification Service Extension target: `KatalaNotificationExtension`
- Configure `Info.plist` for main app:
  - `NSMicrophoneUsageDescription`
  - `NSContactsUsageDescription`
  - `UIBackgroundModes`: `audio`, `fetch`
- Configure `Info.plist` for extension:
  - `NSExtension` dictionary with `NSExtensionPointIdentifier` = `com.apple.usernotifications.service`
  - `UNNotificationExtensionCategory`: `REMINDER_GENERAL`, `REMINDER_CALL`, `REMINDER_TEXT`, `REMINDER_URL`
- Set iOS deployment target to 16.0
- Set Swift version to 5.9
- Configure `NSFileProtectionCompleteUnlessOpen` for database directory

**Files / directories:** `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/KatalaNotificationExtension/Info.plist`, `ios/KatalaNotificationExtension/KatalaNotificationExtension.entitlements`, Xcode project settings

**Requirements:** KATALA_SPEC_V3.md §37.5.

**Architecture:** ARCHITECTURE.md §14.2, §14.4.

**Acceptance criteria:**
- Xcode project builds with both targets
- App Group capability is enabled on both targets
- All Info.plist keys are present with human-readable descriptions
- Notification extension target is recognized by Xcode

**Tests:** Manual verification: build and inspect entitlements with `codesign -d --entitlements`.

**Do not:**
- Implement any bridge code (Phase 6)
- Implement the extension database layer (Phase 6)
- Add CocoaPods (use Swift Package Manager)

---

### TASK-005 — Android Platform Configuration

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Configure the Android project with manifest permissions, receivers, and Kotlin source directories.

**Scope:**
- Set `minSdkVersion` = 26 (Android 8.0), `targetSdkVersion` = 34, `compileSdkVersion` = 34
- Set Kotlin version to 1.9+
- Add `AndroidManifest.xml` permissions:
  - `RECORD_AUDIO`, `POST_NOTIFICATIONS`, `READ_CONTACTS`
  - `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`
- Register receivers in manifest:
  - `BootReceiver` with `BOOT_COMPLETED` + `QUICKBOOT_POWERON` intent filter
  - `NotificationActionReceiver` (exported=false)
- Create Kotlin source directories:
  - `bridges/`
  - `receivers/`
  - `workers/`
- Configure ProGuard/R8 for release builds

**Files / directories:** `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, Kotlin source directories

**Requirements:** KATALA_SPEC_V3.md §37.6.

**Architecture:** ARCHITECTURE.md §15.

**Acceptance criteria:**
- `flutter build apk --debug` succeeds
- All permissions declared in manifest
- Both receivers registered in manifest
- Kotlin source directories exist

**Tests:** `flutter build apk --release` succeeds.

**Do not:**
- Implement any receiver or worker logic (Phase 7)
- Implement any bridge code (Phase 7)
- Add `FOREGROUND_SERVICE` permission requirement in MVP (deferred to Post-MVP per ADR-15)

---

### TASK-006 — Test Infrastructure Setup

**Phase:** 0 — Project Foundation
**Priority:** P0
**Depends on:** TASK-001, TASK-002

**Purpose:** Establish test infrastructure including Fake implementations and in-memory database configuration for all subsequent phases.

**Scope:**
- Create `test/test_helpers/` directory
- Implement `FakeClock` (accepts `DateTime` and `timezone` in constructor; `advance(Duration)` method)
- Create helper for in-memory Drift database: `test_database.dart`
- Create base test configuration with `ProviderScope.overrides`
- Set up test mocks via `mocktail` conventions
- Configure `flutter test` to run in CI-compatible mode (no device required)

**Files / directories:** `test/test_helpers/`

**Architecture:** ARCHITECTURE.md §23.2 (Mocking strategy).

**Acceptance criteria:**
- `FakeClock` compiles and is usable in a test
- In-memory Drift database helper compiles
- `flutter test` runs (even with zero tests) and succeeds

**Tests:** Self-validating: `flutter test` infrastructure works.

**Do not:**
- Create fake bridges yet (Phase 4)
- Create NLP test corpus yet (Phase 3)

---

## Phase 1 — Domain Foundation

---

### TASK-010 — Domain Enums

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-001, TASK-003

**Purpose:** Implement all domain enumerations as defined by the spec and architecture. These have zero dependencies and must exist before entities.

**Scope:**
- `ReminderStatus` (PENDING, COMPLETED, SNOOZED, DISMISSED)
- `IntentType` (GENERAL, CALL, TEXT, EMAIL, OPEN_URL)
- `TriggerType` (SCHEDULED_TIME, GEOFENCE)
- `ActionType` (CALL, TEXT, EMAIL, OPEN_URL, GENERAL)
- `DeliveryStatus` (scheduled, delivery_uncertain, delivery_missed)
- `ValidationIssue` (missingTitle, missingTime, ambiguousTime, timeInPast, unrecognizedIntent, incompleteAction, contactNotFound, invalidUrl)
- `SpeechAvailability` (available, unavailable, permissionDenied, notSupported)
- Each enum with `String` serialization values matching the database CHECK constraints

**Files / directories:** `lib/domain/enums/`

**Requirements:** KATALA_SPEC_V3.md §14, §15, §8.3, §34.1.

**Architecture:** ARCHITECTURE.md §6.2, §7.2.

**Acceptance criteria:**
- All 8 enums compile
- Serialization values match ARCHITECTURE.md database CHECK constraints exactly
- No Flutter or platform imports

**Tests:** Unit tests verifying each enum value's string serialization.

**Do not:**
- Add enums not listed above
- Add `toJson`/`fromJson` with any dependency on `json_serializable`

---

### TASK-011 — Clock Interface & SystemClock

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Implement the injectable Clock interface for deterministic temporal operations.

**Scope:**
- `Clock` abstract class with `DateTime now()` and `String localTimezone()`
- `SystemClock` implementation using `DateTime.now()` and `DateTime.now().timeZoneName`
- `FakeClock` implementation (started in TASK-006, refined here): constructor takes `DateTime` and optional `timezone`; `advance(Duration)` method

**Files / directories:** `lib/domain/nlp/clock.dart`

**Requirements:** KATALA_SPEC_V3.md §34.4.

**Architecture:** ARCHITECTURE.md §1.6, §9.2.

**Acceptance criteria:**
- `Clock` interface compiles
- `SystemClock` passes a basic smoke test (returns current time)
- `FakeClock` returns the injected time and timezone

**Tests:** Unit tests: `FakeClock` returns configured time; `advance()` shifts time correctly.

**Do not:**
- Use `Clock` as a singleton — it must always be injectable
- Add network time sync

---

### TASK-012 — Domain Entities & Value Objects

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-010

**Purpose:** Implement all domain entities and value objects as plain Dart classes.

**Scope:**
- `Reminder` entity: id (UUID v4 String), title, notes, intentType (IntentType), status (ReminderStatus), snoozeCount (int), snoozeDurationMinutes (int), parentReminderId (String?), depth (int), version (int), originalTranscript (String?), isDeleted (bool), deletedAt (DateTime?), createdAt (DateTime), updatedAt (DateTime), completedAt (DateTime?)
- `Trigger` value object: id, reminderId, triggerType, scheduledTimeUtc (DateTime), scheduledTimeTimezone (String), notificationScheduled (bool), notificationId (int?), firedAt (DateTime?), deliveryStatus (DeliveryStatus), recurrenceRule (String?)
- `Action` value object: id, reminderId, actionType, targetValue (String?), contactName (String?), contactPhone (String?), contactId (String?)
- `ParsedReminder` (NLP output): title (String?), contactName (String?), url (String?), phoneNumber (String?), notes (String?), scheduledTime (DateTime?), timezone (String?), intentType (IntentType), issues (List<ValidationIssue>), originalTranscript (String)
- `ValidatedReminder` (Application output): title (String), resolvedContact (ResolvedContact?), validatedUrl (String?), phoneNumber (String?), notes (String?), scheduledTime (DateTime), timezone (String), intentType (IntentType), originalTranscript (String)
- `ResolvedContact`: platformId (String), displayName (String), phoneNumber (String?), allPhoneNumbers (List<String>?)

**Files / directories:** `lib/domain/entities/`

**Requirements:** KATALA_SPEC_V3.md §14, §8.3, §34.3.

**Architecture:** ARCHITECTURE.md §6.2, §6.3, §6.4.

**Implementation notes:**
- Use `ResolvedContact` (not `ContactRef`) as the canonical name — this resolves ARCHITECTURE_CONSISTENCY_REVIEW.md finding L1.
- All entities use `DateTime` for timestamps; storage as ISO 8601 strings happens in the data layer.
- All IDs are `String` (UUID v4).
- `ParsedReminder` has nullable fields (NLP may not extract everything); `ValidatedReminder` has required fields (Application layer guarantees completeness).

**Acceptance criteria:**
- All 6 classes compile
- All fields match the spec
- No Flutter or platform imports
- `ParsedReminder` and `ValidatedReminder` are separate types (not interchangeable)

**Tests:** Equality and field access tests.

**Do not:**
- Add ORM annotations (Drift annotations go in data layer, not domain)
- Add `copyWith` methods yet (add when needed by application layer)
- Add JSON serialization in domain layer (that's a data layer concern)

---

### TASK-013 — Domain Errors

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Define the domain error hierarchy using sealed classes.

**Scope:**
- `AppError` sealed class with `userMessage` (String) and `technicalDetails` (String?)
- Domain errors:
  - `ValidationFailed` (issues: List<ValidationIssue>)
  - `ConflictDetected` (conflicts: List<Reminder>, suggestedAlternative: DateTime?)
  - `InvalidStateTransition` (from: ReminderStatus, to: ReminderStatus)
  - `TimeInPast` (scheduledTime: DateTime)
- Application errors (separate subclass):
  - `ContactDisambiguationRequired` (name: String, candidates: List<ResolvedContact>)
  - `SchedulingFailed` (reason: String)
  - `PersistenceFailed` (reason: String, retryable: bool)
  - `NotificationActionFailed` (reason: String)
- Platform bridge errors: `SpeechNotAvailable`, `PermissionDenied`, `NotificationLimitReached`, `CannotLaunchUrl`
- NLP errors: `UnrecognizedIntent`, `NoEntitiesExtracted`, `AmbiguousTimeResolution`
- `Result<T, E>` sealed class with `Success<T, E>` and `Failure<T, E>`

**Files / directories:** `lib/domain/errors.dart`, `lib/domain/result.dart`

**Requirements:** KATALA_SPEC_V3.md §35, Appendix B.

**Architecture:** ARCHITECTURE.md §19 (Error Architecture).

**Acceptance criteria:**
- All error classes compile
- `Result<T, E>` sealed class works with pattern matching
- Every error has a `userMessage` getter
- No Flutter dependencies

**Tests:** Verify error hierarchy pattern matching; verify `Result` success/failure unwrapping.

**Do not:**
- Add HTTP error types
- Map errors to UI strings in the domain layer (that's UI layer responsibility)

---

### TASK-014 — State Machine

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-010, TASK-012, TASK-013

**Purpose:** Implement the reminder state machine with all transitions and guards.

**Scope:**
- Function: `transition(Reminder current, ReminderStatus target, int newVersion) → Result<Reminder, InvalidStateTransition>`
- Valid transitions:
  - PENDING → COMPLETED [Done]
  - PENDING → SNOOZED [Snooze, guard: snooze_count < 10]
  - PENDING → DISMISSED [Dismiss]
  - SNOOZED → PENDING [Timer expires]
  - SNOOZED → SNOOZED [Snooze again, guard: snooze_count < 10]
  - SNOOZED → COMPLETED [Done]
  - SNOOZED → DISMISSED [Dismiss]
- Terminal states: COMPLETED, DISMISSED — no outgoing transitions
- On valid transition: increment version, update status, update timestamps (completedAt for COMPLETED, updatedAt for all)
- On snooze: increment snoozeCount
- Guard enforcement: return `InvalidStateTransition` for disallowed transitions

**Files / directories:** `lib/domain/state_machine.dart`

**Requirements:** KATALA_SPEC_V3.md §15.

**Architecture:** ARCHITECTURE.md §6.5.

**Implementation notes:**
- This is a pure function — no side effects, no database access, no notification scheduling
- The function returns a **new** `Reminder` with updated fields (immutable transition)
- The caller (use case) is responsible for persisting the returned Reminder

**Acceptance criteria:**
- All 8 transitions work correctly
- Guard `snooze_count < 10` blocks the 11th snooze attempt
- Terminal states reject all transition attempts
- Invalid transitions return `InvalidStateTransition`

**Tests:**
- `test/domain/state_machine_test.dart`
- For every transition: verify it works, verify guards, verify invalid transitions are blocked
- Test: two rapid transitions from same initial state (simulate optimistic lock scenario)

**Do not:**
- Add database persistence in the state machine
- Add notification side effects
- Add transitions not in the spec

---

### TASK-015 — Conflict Detection

**Phase:** 1 — Domain Foundation
**Priority:** P0
**Depends on:** TASK-012

**Purpose:** Implement the schedule conflict detector: given a candidate time and access to pending reminders, detect ±15 minute overlaps.

**Scope:**
- `ConflictDetector` class with method:
  - `detectConflicts(DateTime candidateTime, List<Reminder> pendingReminders) → List<Reminder>`
- A conflict exists when `candidateTime` is within ±15 minutes of any PENDING reminder's scheduled time
- `suggestAlternative(DateTime candidateTime, List<Reminder> conflicts) → DateTime?` — suggests the nearest non-conflicting time
- Pure function: same inputs → same outputs (no Clock dependency for detection itself)

**Files / directories:** `lib/domain/conflict_detector.dart`

**Requirements:** KATALA_SPEC_V3.md §18.

**Architecture:** ARCHITECTURE.md §5.2 (used in CreateReminderUseCase).

**Acceptance criteria:**
- Reminder at 2:00 PM conflicts with candidate at 1:50 PM or 2:10 PM
- Reminder at 2:00 PM does NOT conflict with candidate at 1:40 PM or 2:20 PM
- `suggestAlternative()` returns a time outside all conflict windows
- Empty pending list → no conflicts

**Tests:** `test/domain/conflict_detector_test.dart` — seed with known reminders, verify conflict detection and alternative suggestion.

**Do not:**
- Access the database directly (accepts `List<Reminder>` as parameter)
- Implement UI for conflict display (Phase 8)

---

## Phase 2 — Persistence

---

### TASK-020 — Drift Database Schema

**Phase:** 2 — Persistence
**Priority:** P0
**Depends on:** TASK-010, TASK-012

**Purpose:** Define the Drift database schema with all tables, columns, and CHECK constraints.

**Scope:**
- `reminder` table: id (TEXT PK), title (TEXT NOT NULL), notes (TEXT), intent_type (TEXT NOT NULL, CHECK), status (TEXT NOT NULL, CHECK, DEFAULT 'PENDING'), snooze_count (INTEGER DEFAULT 0), snooze_duration_minutes (INTEGER DEFAULT 10), parent_reminder_id (TEXT), depth (INTEGER DEFAULT 0), version (INTEGER DEFAULT 1), original_transcript (TEXT), is_deleted (INTEGER DEFAULT 0), deleted_at (TEXT), created_at (TEXT NOT NULL), updated_at (TEXT NOT NULL), completed_at (TEXT)
- `trigger_` table: id (TEXT PK), reminder_id (TEXT NOT NULL, FK), trigger_type (TEXT NOT NULL, CHECK), scheduled_time_utc (TEXT), scheduled_time_timezone (TEXT), notification_scheduled (INTEGER DEFAULT 0), notification_id (INTEGER), fired_at (TEXT), delivery_status (TEXT NOT NULL, DEFAULT 'scheduled', CHECK), recurrence_rule (TEXT)
- `action_` table: id (TEXT PK), reminder_id (TEXT NOT NULL, FK), action_type (TEXT NOT NULL, CHECK), target_value (TEXT), contact_name (TEXT), contact_phone (TEXT), contact_id (TEXT)
- `app_metadata` table: key (TEXT PK), value (TEXT NOT NULL)
- All CHECK constraints match domain enum values exactly
- Foreign keys from `trigger_.reminder_id` and `action_.reminder_id` to `reminder.id`
- Drift reactive queries: `watchPending()`, `watchOverdue()`, `watchByTimeRange()`

**Files / directories:** `lib/data/database/database.dart`, `lib/data/database/tables.dart`

**Requirements:** KATALA_SPEC_V3.md §16, §17.

**Architecture:** ARCHITECTURE.md §7.2.

**Implementation notes:**
- Store timestamps as ISO 8601 TEXT (Drift `DateTime` column type with custom converter)
- `app_metadata` is a key-value store (not a typed table) — stores `last_reconciled_at`, `schema_version`, and `user_preferences`
- The `app_metadata` table is NOT listed in SPEC §16 but IS required by ARCHITECTURE.md §7.2 — this is intentional (ARCHITECTURE_CONSISTENCY_REVIEW.md L6)

**Acceptance criteria:**
- `flutter pub run build_runner build` generates Drift code successfully
- All tables exist in generated code
- CHECK constraints are present in generated SQL

**Tests:** Not applicable (schema generation is verified by build_runner).

**Do not:**
- Add tables not in the spec or architecture
- Skip CHECK constraints
- Store `app_metadata` preferences in `shared_preferences` — they go in this table so the iOS extension can access them

---

### TASK-021 — Repository Interface & Drift Implementation

**Phase:** 2 — Persistence
**Priority:** P0
**Depends on:** TASK-020, TASK-012, TASK-013

**Purpose:** Implement the `ReminderRepository` interface and its Drift-backed implementation.

**Scope:**
- `ReminderRepository` abstract interface (in `lib/data/repositories/`):
  - `Future<Reminder> insert(Reminder reminder, Trigger trigger, Action? action)`
  - `Future<Reminder> update(Reminder reminder, {required int expectedVersion})` → throws on version mismatch
  - `Future<void> softDelete(String id)`
  - `Future<Reminder?> findById(String id)`
  - `Future<List<Reminder>> findPending()`
  - `Future<List<Reminder>> findOverdue(DateTime now)`
  - `Stream<List<Reminder>> watchPending()`
  - `Stream<List<Reminder>> watchOverdue()`
  - `Future<List<Reminder>> findByTimeRange(DateTime start, DateTime end)`
  - `Future<List<Reminder>> findPendingSortedByTime({int? limit})`
  - `Future<void> updateTrigger(Trigger trigger)`
  - `Future<Trigger?> findTriggerByReminderId(String reminderId)`
  - `Future<Action?> findActionByReminderId(String reminderId)`
  - `Future<void> updateMetadata(String key, String value)`
  - `Future<String?> getMetadata(String key)`
- `ReminderRepositoryImpl` using generated Drift DAOs
- Transaction support: `insert` wraps reminder + trigger + action in a single Drift transaction

**Files / directories:** `lib/data/repositories/reminder_repository.dart`

**Requirements:** KATALA_SPEC_V3.md §17, §27.

**Architecture:** ARCHITECTURE.md §7.5, §7.6.

**Acceptance criteria:**
- Interface compiles
- Implementation compiles against Drift
- `insert` is transactional (all three rows or none)
- `update` uses `WHERE version = :expectedVersion`
- `findPendingSortedByTime` supports an optional limit parameter

**Tests:** `test/data/repositories/reminder_repository_test.dart` — in-memory Drift database.

**Do not:**
- Call Platform Bridges from the repository
- Schedule notifications from the repository (ARCHITECTURE.md §4, ADR-11)
- Use `shared_preferences` for metadata (use `app_metadata` table)

---

### TASK-022 — Database Migrations

**Phase:** 2 — Persistence
**Priority:** P0
**Depends on:** TASK-020

**Purpose:** Implement the Drift migration framework and the initial schema migration.

**Scope:**
- Drift `MigrationStrategy` with `onCreate` and `onUpgrade` callbacks
- Initial migration (version 1): create all four tables
- Migration testing infrastructure: verify schema at each version
- `beforeOpen` callback: `PRAGMA journal_mode=WAL`, `PRAGMA busy_timeout=3000`, `PRAGMA foreign_keys=ON`

**Files / directories:** `lib/data/database/migrations.dart`

**Requirements:** KATALA_SPEC_V3.md §17.

**Architecture:** ARCHITECTURE.md §7.10, §7.3.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M4: When the Drift schema version is incremented, the iOS extension's raw SQLite queries in `ExtensionDatabase.swift` MUST be reviewed and updated in the same commit.

**Acceptance criteria:**
- In-memory database opens with all tables created
- Subsequent opens do not re-run migrations (version tracking works)
- WAL mode is enabled after migration
- `busy_timeout` is set to 3000ms

**Tests:** Integration test: open database, verify schema, close, re-open, verify data persists.

**Do not:**
- Write migrations as raw SQL strings outside the Drift migration framework
- Forget to set WAL mode (critical for iOS cross-process access)

---

### TASK-023 — Optimistic Locking

**Phase:** 2 — Persistence
**Priority:** P0
**Depends on:** TASK-021

**Purpose:** Implement optimistic locking for all state-transitioning UPDATE operations.

**Scope:**
- Every `UPDATE` on `reminder` includes `WHERE version = :expectedVersion`
- On 0 rows affected: throw `OptimisticLockFailed` error
- Repository-level retry-once logic: re-read the current entity, re-apply the transition, retry the UPDATE
- If retry fails: surface the error to the caller (application layer)
- Lock check applies to: `update`, `softDelete`, and any method that modifies `reminder` fields

**Files / directories:** `lib/data/repositories/reminder_repository.dart` (same file as TASK-021)

**Requirements:** KATALA_SPEC_V3.md §31.4.

**Architecture:** ARCHITECTURE.md §7.7, §8.2.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #5: The retry MUST re-read current state before retrying — do NOT retry the same UPDATE with the old version number.
- The implementation pseudocode in ARCHITECTURE.md §8.2 shows the correct pattern.

**Acceptance criteria:**
- Two concurrent updates from the same initial version: only one succeeds
- Version increments on every successful update
- `OptimisticLockFailed` is thrown when version mismatch occurs and retry also fails

**Tests:** Unit test: seed database, create two repository instances, update from both, verify exactly one succeeds.

**Do not:**
- Implement pessimistic locking
- Retry more than once (retry-once policy)
- Skip the re-read step before retry

---

### TASK-024 — Database Integrity Check

**Phase:** 2 — Persistence
**Priority:** P0
**Depends on:** TASK-021

**Purpose:** Implement the startup database integrity check as defined by the spec.

**Scope:**
- `DatabaseIntegrityChecker` class:
  - `Future<IntegrityResult> checkIntegrity(AppDatabase db)` — runs `PRAGMA integrity_check`
  - If integrity_check passes: run `PRAGMA quick_check` for fast secondary confirmation
  - `IntegrityResult` sealed: `IntegrityOk`, `IntegrityFailed(String details)`, `IntegrityRecoverable(String details)`
- Integration with app startup: must run before any queries
- On failure: throw `DatabaseCorruptionError` for the UI to show recovery screen

**Files / directories:** `lib/data/database/integrity_checker.dart`

**Requirements:** KATALA_SPEC_V3.md §17 (last paragraph), §36.1 step 1.

**Architecture:** ARCHITECTURE.md §7.9.

**Acceptance criteria:**
- `integrity_check` runs on startup
- Passes on a clean database
- Failures are surfaced as typed errors (not panics)
- Recovery screen triggers are handled by application layer

**Tests:** Unit test: run integrity check on in-memory clean database → passes. Test corruption detection with deliberately malformed database.

**Do not:**
- Attempt automatic repair (user must choose: restore or reset)
- Skip the integrity check on any startup path

---

## Phase 3 — Deterministic NLP

---

### TASK-030 — NLP Pipeline Orchestrator & Intermediate Types

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-011, TASK-012

**Purpose:** Implement the NLP pipeline orchestrator that chains the five stages together, plus the `ParsedReminder` intermediate type.

**Scope:**
- `NlpPipeline` class:
  - `ParsedReminder parse(String transcript, {required Clock clock})` — runs all 5 stages
  - Each stage is a pure function: `PreProcessor.normalize(String) → String`, `IntentDetector.detect(String) → IntentType`, etc.
- Pipeline order (critical — must not be reordered):
  1. Pre-Processor (normalize)
  2. Intent Detector (classify)
  3. Entity Extractor (extract title, contact, URL, phone, notes, time expression)
  4. Temporal Resolver (resolve time expression → DateTime)
  5. Validator (produce `List<ValidationIssue>`)
- `ParsedReminder` is the pipeline output; it has nullable fields for anything not extracted

**Files / directories:** `lib/domain/nlp/nlp_pipeline.dart`

**Requirements:** KATALA_SPEC_V3.md §8.3, §8.4.

**Architecture:** ARCHITECTURE.md §9.3.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #1: Stage order is CRITICAL. Entity extractor must run AFTER intent detection. Temporal resolver must run AFTER entity extraction. Validator must run LAST.
- The pipeline is a deterministic function: same transcript + same Clock = same `ParsedReminder`.

**Acceptance criteria:**
- `NlpPipeline.parse()` accepts a transcript string and Clock, returns `ParsedReminder`
- All 5 stages are called in the correct order
- NLP pipeline has zero platform imports

**Tests:** `test/domain/nlp/nlp_pipeline_test.dart` — full pipeline integration with FakeClock.

**Do not:**
- Reorder the stages
- Add ML/AI inference
- Add network calls
- Skip any stage for any input (even unrecognized transcripts go through all stages)

---

### TASK-031 — Pre-Processor (Stage 1)

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-030

**Purpose:** Implement text normalization: lowercase, strip filler words, apply STT common-error corrections.

**Scope:**
- Normalize: lowercase, collapse whitespace, trim
- Strip filler words: "um", "uh", "please", "can you", "i want to", "i need to"
- STT corrections table (initial set):
  - "remainder" → "reminder", "remain" → "remind"
  - "to morrow" → "tomorrow", "to day" → "today"
  - "too" → "two" (before time patterns), "for" → "four" (before time patterns)
  - Taglish: "pah remind" → "paremind", "na remind" → "magremind"
- `PreProcessor.normalize(String rawTranscript) → String`

**Files / directories:** `lib/domain/nlp/pre_processor.dart`

**Requirements:** KATALA_SPEC_V3.md §8.3 Stage 1.

**Architecture:** ARCHITECTURE.md §9.3.

**Acceptance criteria:**
- "Um, remind me to call Adam tomorrow" → "remind me to call adam tomorrow"
- "remainder to buy groceries" → "reminder to buy groceries"
- Whitespace is collapsed
- Case is lowercased

**Tests:** `test/domain/nlp/pre_processor_test.dart` — corpus-based: input → expected output.

**Do not:**
- Remove words that are part of reminder content (only known filler words)
- Over-correct (the STT corrections table is conservative)

---

### TASK-032 — Intent Detector (Stage 2)

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-031

**Purpose:** Classify the user's intent from normalized text. For MVP, only CREATE_REMINDER is supported.

**Scope:**
- `IntentDetector.detect(String normalized) → IntentType`
- English patterns: "remind me", "set a reminder", "add reminder", "reminder to", "don't forget", "i need to", "remember to"
- Taglish patterns: "pa-remind", "remind mo ko", "remind mo ako", "mag-remind", "ipaalala mo", "paremind", "paalala", "remind mo naman"
- Return `IntentType.GENERAL` for unrecognized patterns (not an error — validation handles it)
- For MVP: all detected intents map to CREATE_REMINDER (GENERAL intent = CREATE_REMINDER)

**Files / directories:** `lib/domain/nlp/intent_detector.dart`

**Requirements:** KATALA_SPEC_V3.md §9, Appendix A.1-A.2.

**Architecture:** ARCHITECTURE.md §9.3.

**Acceptance criteria:**
- "remind me to call adam" → CREATE_REMINDER (IntentType.GENERAL)
- "pa-remind mo ko tumawag kay mama" → CREATE_REMINDER
- "what's the weather" → CREATE_REMINDER (GENERAL — passes through, validation catches it)
- Detection is case-insensitive

**Tests:** `test/domain/nlp/intent_detector_test.dart` — corpus: every pattern from Appendix A.1 and A.2.

**Do not:**
- Add other intent types (EDIT, DELETE, QUERY, SNOOZE are Post-MVP)
- Return null or throw on unrecognized intent — always return a valid IntentType

---

### TASK-033 — Entity Extractor (Stage 3)

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-032

**Purpose:** Extract entities from normalized text: title, contact name, URL, phone number, notes, and raw time expression.

**Scope:**
- `EntityExtractor.extract(String normalized, IntentType intent) → ExtractedEntities`
- `ExtractedEntities`: title (String?), contactName (String?), url (String?), phoneNumber (String?), notes (String?), timeExpression (String?)
- Extraction order (CRITICAL):
  1. URL detection (regex: `https?://[^\s]+`) — extract and remove from text
  2. Phone number detection (regex: `\+?[\d\s\-\(\)]{7,}`) — extract and remove
  3. Contact name extraction: "call [Name]", "text [Name]", "tawagan si [Name]", "i-text si [Name]", "itext mo si [Name]"
  4. Time expression extraction: identify temporal phrases (delegated to Temporal Resolver in Stage 4)
  5. Title: remaining text after removing action prefix, contact, URL, phone, and time expression
  6. Notes: extracted from "note:", "notes:", "about:", or after title separator
- Action pattern removal: strip "call", "text", "message", "email", "tawagan", "i-text" etc. from title

**Files / directories:** `lib/domain/nlp/entity_extractor.dart`

**Requirements:** KATALA_SPEC_V3.md §10, Appendix A.3-A.4.

**Architecture:** ARCHITECTURE.md §9.3.

**Acceptance criteria:**
- "call adam tomorrow at 3pm" → title="adam", contactName="adam", timeExpression="tomorrow at 3pm"
- "check https://example.com at 5pm" → title="check", url="https://example.com", timeExpression="at 5pm"
- "call 09171234567 at noon" → title="call", phoneNumber="09171234567", timeExpression="at noon"
- "tawagan si mama bukas ng 9am" → title="mama", contactName="mama", timeExpression="bukas ng 9am"

**Tests:** `test/domain/nlp/entity_extractor_test.dart` — corpus: every combination from Appendix A.

**Do not:**
- Resolve contacts against the device address book (that's Application layer — Stage 3 outputs strings only)
- Reorder the extraction steps (URL first, then phone, then contact, etc.)
- Extract time as DateTime (that's Stage 4)

---

### TASK-034 — Temporal Resolver (Stage 4)

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-033, TASK-011

**Purpose:** Resolve extracted time expressions to concrete `DateTime` values using an injectable `Clock`.

**Scope:**
- `TemporalResolver.resolve(String timeExpression, {required Clock clock}) → TemporalResult`
- `TemporalResult`: resolvedTime (DateTime?), timezone (String), ambiguity (TemporalAmbiguity?)
- `TemporalAmbiguity` enum: `none`, `bareNumber` (e.g., "at 3"), `relativeWithoutAnchor` (e.g., "later")
- Expression types to resolve:
  - Absolute: "today", "tomorrow", "tonight", "this morning/afternoon/evening"
  - Day-of-week: "next Monday", "this Friday", "sa Lunes" (Filipino)
  - Clock time: "at 3 PM", "at 14:00", "noon", "midnight", "3:30 PM"
  - Relative: "in 30 minutes", "in 2 hours", "in 3 days"
  - Combined: "tomorrow at 5 PM", "next Monday at 10 AM"
  - Filipino: "bukas" (tomorrow), "mamaya" (later), "ngayon" (today), "bukas ng umaga" (tomorrow morning), "mamayang 5pm" (later at 5pm), "sa Lunes" (on Monday)
- Bare numbers 1-12: set `ambiguity = bareNumber` (do NOT auto-resolve — Validator catches this)
- "later" / "mamaya" without time: default to 2 hours from now
- "tonight": 8:00 PM; "this morning": 9:00 AM; "this afternoon": 2:00 PM; "this evening": 7:00 PM
- Time caps: "later" resolves no later than 10:00 PM; if current time > 10 PM, resolves to 8:00 AM tomorrow

**Files / directories:** `lib/domain/nlp/temporal_resolver.dart`

**Requirements:** KATALA_SPEC_V3.md §11, Appendix A.5-A.6.

**Architecture:** ARCHITECTURE.md §9.3 (Stage 4), §9.4.

**Implementation notes:**
- Clock injection is critical for testability — every resolution must use the injected Clock, never `DateTime.now()` directly
- Timezone-aware: resolved time includes the IANA timezone from the injected Clock
- Week starts on Monday for "next week" calculations

**Acceptance criteria:**
- With FakeClock at Monday 10 AM: "tomorrow at 3 PM" → Tuesday 3:00 PM
- "in 30 minutes" → 30 minutes from FakeClock's now
- "at 3" (bare number) → ambiguity flag set (no resolution)
- "bukas ng 9 am" (with Filipino timezone context) → tomorrow 9:00 AM
- "mamaya" → 2 hours from now (capped at 10 PM)

**Tests:** `test/domain/nlp/temporal_resolver_test.dart` — every expression type from Appendix A.5-A.6 with FakeClock.

**Do not:**
- Use `DateTime.now()` directly
- Auto-resolve bare numbers (1-12) to AM or PM
- Support "every Monday", "daily" (recurrence is Post-MVP)

---

### TASK-035 — Validator (Stage 5)

**Phase:** 3 — Deterministic NLP
**Priority:** P0
**Depends on:** TASK-034, TASK-012

**Purpose:** Validate the extracted entities and produce a list of `ValidationIssue` values that drive the UI clarification flow.

**Scope:**
- `Validator.validate(ParsedReminder parsed) → List<ValidationIssue>`
- Issues to detect:
  - `missingTitle` — title is null, empty, or whitespace-only
  - `missingTime` — no time expression extracted
  - `ambiguousTime` — bare number 1-12 (AM/PM ambiguity)
  - `timeInPast` — resolved time is in the past (using the same Clock)
  - `unrecognizedIntent` — IntentDetector returned GENERAL but no CREATE_REMINDER pattern matched
  - `incompleteAction` — action keyword detected (call/text/email) but no contact name or phone extracted
  - `contactNotFound` — contact name found but will need resolution (reserved for Application layer)
  - `invalidUrl` — URL extracted but fails validation (scheme not http/https, length > 2048)
- Multiple issues can be returned simultaneously (e.g., missingTitle AND missingTime)

**Files / directories:** `lib/domain/nlp/validator.dart`

**Requirements:** KATALA_SPEC_V3.md §12.

**Architecture:** ARCHITECTURE.md §9.3 (Stage 5).

**Acceptance criteria:**
- No title → `[missingTitle]`
- No time expression → `[missingTime]`
- Bare "at 3" → `[ambiguousTime]`
- Past time → `[timeInPast]`
- Valid complete transcript → `[]` (empty list)
- Both missing title AND missing time → both issues present

**Tests:** `test/domain/nlp/validator_test.dart` — for every `ValidationIssue` enum value, produce an input that triggers it.

**Do not:**
- Validate contact resolution (that's Application layer)
- Return issues for things that aren't problems (e.g., missing notes is NOT an issue)

---

### TASK-036 — NLP Test Corpus

**Phase:** 3 — Deterministic NLP
**Priority:** P1
**Depends on:** TASK-030 through TASK-035

**Purpose:** Build the comprehensive NLP test corpus. Every pattern from KATALA_SPEC_V3.md Appendix A must have corresponding test cases.

**Scope:**
- Create test corpus files (JSON or Dart list of test cases):
  - `test/domain/nlp/corpus/english_create_reminder.json`
  - `test/domain/nlp/corpus/taglish_create_reminder.json`
  - `test/domain/nlp/corpus/edge_cases.json`
- Each test case: `{ input, expectedIntent, expectedTitle, expectedContactName, expectedTimeExpression, expectedResolvedTime (with FakeClock), expectedIssues }`
- Minimum corpus size: 50 English + 25 Taglish + 25 edge cases
- Edge cases: empty string, only filler words, URLs without reminders, phone numbers without context, ambiguous times, past times, extremely long input

**Files / directories:** `test/domain/nlp/corpus/`

**Requirements:** KATALA_SPEC_V3.md §9-§13, Appendix A.

**Acceptance criteria:**
- Full NLP pipeline test runs against entire corpus
- 100% of corpus tests pass
- Corpus covers every pattern from Appendix A
- Edge case corpus includes at least 25 cases

**Tests:** Parameterized test: for each corpus entry, run `NlpPipeline.parse()` and assert expected output.

**Do not:**
- Skip Taglish corpus (it's MVP)
- Create corpus entries that require real speech (corpus is transcript → parsed, no STT)

---

## Phase 4 — Platform Bridge Interfaces

---

### TASK-040 — SpeechBridge Interface & FakeSpeechBridge

**Phase:** 4 — Platform Bridge Interfaces
**Priority:** P0
**Depends on:** TASK-010, TASK-013

**Purpose:** Define the `SpeechBridge` abstract interface and a `FakeSpeechBridge` for testing.

**Scope:**
- `SpeechBridge` abstract class:
  - `Future<SpeechAvailability> get availability`
  - `Future<bool> get isOnDeviceAvailable`
  - `Stream<String> startListening()`
  - `Future<String> stopListening()`
  - `Future<void> cancel()`
  - `Future<void> dispose()`
- `FakeSpeechBridge`: accepts pre-configured transcripts in constructor; `startListening()` returns them as a stream with configurable delay
- Error types: `SpeechPermissionDenied`, `SpeechUnavailable`, `SpeechRecognitionFailed`, `SpeechTimeout`, `SpeechNoSpeech`

**Files / directories:** `lib/platform/bridges/speech_bridge.dart`, `test/test_helpers/fake_speech_bridge.dart`

**Requirements:** KATALA_SPEC_V3.md §34.1.

**Architecture:** ARCHITECTURE.md §11.2, §16.1.

**Acceptance criteria:**
- Interface compiles with all methods
- `FakeSpeechBridge` can be configured to return any transcript
- `FakeSpeechBridge` can simulate errors (throw `SpeechTimeout`, etc.)

**Tests:** Unit test: FakeSpeechBridge returns configured transcript; simulates timeout.

**Do not:**
- Implement any native code (Phase 6, 7)
- Add platform-specific imports to the interface

---

### TASK-041 — NotificationBridge Interface & FakeNotificationBridge

**Phase:** 4 — Platform Bridge Interfaces
**Priority:** P0
**Depends on:** TASK-012, TASK-013

**Purpose:** Define the `NotificationBridge` abstract interface and a `FakeNotificationBridge` for testing.

**Scope:**
- `NotificationBridge` abstract class:
  - `Future<void> configureCategories()`
  - `Future<int> schedule(ValidatedReminder reminder)` — returns platform notification ID
  - `Future<void> cancel(int notificationId)`
  - `Future<void> cancelForReminder(String reminderId)`
  - `Future<Set<int>> getScheduledIds()`
  - `Future<ReconciliationResult> reconcile(List<Reminder> pendingReminders, {required int maxScheduled})`
  - `Future<int> cleanupOrphans(Set<String> activeReminderIds)`
  - `Future<void> dismiss(int notificationId)`
- `ReconciliationResult`: scheduled (int), cancelled (int), failed (int), deliveryUncertainReminderIds (List<String>), errors (List<String>)
- `FakeNotificationBridge`: in-memory tracking of scheduled notification IDs
- Error: `NotificationSchedulingFailed`

**Files / directories:** `lib/platform/bridges/notification_bridge.dart`, `test/test_helpers/fake_notification_bridge.dart`

**Requirements:** KATALA_SPEC_V3.md §34.2.

**Architecture:** ARCHITECTURE.md §12, §16.2.

**Acceptance criteria:**
- Interface compiles
- `FakeNotificationBridge` tracks scheduled IDs
- `FakeNotificationBridge.reconcile()` runs the reconciliation algorithm against in-memory state

**Tests:** Unit test: schedule, verify ID returned; cancel, verify ID removed; reconcile with mismatched state.

**Do not:**
- Implement the real `reconcile()` algorithm in the fake — fake just tracks state

---

### TASK-042 — ContactBridge Interface & FakeContactBridge

**Phase:** 4 — Platform Bridge Interfaces
**Priority:** P0
**Depends on:** TASK-012 (ResolvedContact)

**Purpose:** Define the `ContactBridge` abstract interface and a `FakeContactBridge` for testing.

**Scope:**
- `ContactBridge` abstract class:
  - `Future<List<ResolvedContact>> resolve(String name)`
  - `Future<ResolvedContact?> getById(String contactId)`
- `FakeContactBridge`: accepts `Map<String, List<ResolvedContact>>` in constructor; `resolve(name)` returns matches
- Search strategy (documented in interface): 1. Exact display-name match (case-insensitive). 2. First-name or last-name startsWith. 3. Contains match. Max 20 results.

**Files / directories:** `lib/platform/bridges/contact_bridge.dart`, `test/test_helpers/fake_contact_bridge.dart`

**Requirements:** KATALA_SPEC_V3.md §34.3.

**Architecture:** ARCHITECTURE.md §16.3.

**Acceptance criteria:**
- Interface compiles
- `FakeContactBridge` returns pre-configured contacts for known names
- Unknown names return empty list

**Tests:** Unit test: resolve known name → returns contacts; resolve unknown name → empty list.

**Do not:**
- Implement actual CNContactStore/ContactsContract access (Phase 6, 7)

---

### TASK-043 — ActionBridge Interface

**Phase:** 4 — Platform Bridge Interfaces
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Define the `ActionBridge` abstract interface for launching system actions (dialer, SMS, browser).

**Scope:**
- `ActionBridge` abstract class:
  - `Future<bool> launchDialer(String phoneNumber)`
  - `Future<bool> launchSms(String phoneNumber, {String? body})`
  - `Future<bool> launchUrl(String url)`
- No `FakeActionBridge` needed — tests mock this interface
- Error types: `InvalidPhone`, `InvalidUrl`, `CannotLaunch`

**Files / directories:** `lib/platform/bridges/action_bridge.dart`

**Requirements:** KATALA_SPEC_V3.md §34 (platform bridges).

**Architecture:** ARCHITECTURE.md §16.4.

**Acceptance criteria:**
- Interface compiles
- All three methods are declared

**Tests:** Not applicable (interface only).

**Do not:**
- Add methods beyond the three listed
- Auto-initiate any action (always requires explicit user intent)

---

### TASK-044 — Permission Abstraction

**Phase:** 4 — Platform Bridge Interfaces
**Priority:** P1
**Depends on:** TASK-001

**Purpose:** Create a thin permission-checking abstraction for use by the UI and Application layers.

**Scope:**
- `PermissionBridge` abstract class / or use `permission_handler` directly per ARCHITECTURE.md §20.2
- Riverpod providers for reactive permission state:
  - `microphonePermissionProvider`
  - `notificationPermissionProvider`
  - `contactsPermissionProvider`
  - `exactAlarmPermissionProvider` (Android only)
- Permission status checking functions
- Denial handling with "Open Settings" deep link capability

**Files / directories:** `lib/platform/permissions.dart`

**Requirements:** KATALA_SPEC_V3.md §30.4.

**Architecture:** ARCHITECTURE.md §20.

**Implementation notes:**
- `permission_handler` package is used directly (ARCHITECTURE.md §22.1 says it's "thin enough")
- Android exact alarm permission: check `AlarmManager.canScheduleExactAlarms()` via a native call if needed

**Acceptance criteria:**
- All four permission providers compile
- Permission status can be checked reactively via Riverpod

**Tests:** Widget test: override permission providers with fake statuses, verify UI responds.

**Do not:**
- Request permissions at app startup (permissions are requested contextually per §20.1)
- Request Contacts permission before user creates a CALL/TEXT reminder

---

## Phase 5 — Application Layer

---

### TASK-050 — CreateReminderUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-021, TASK-030, TASK-040, TASK-041, TASK-042, TASK-015

**Purpose:** Implement the primary use case: convert a transcript into a persisted, scheduled reminder.

**Scope:**
- `CreateReminderUseCase`:
  1. Accept `String transcript` + resolved permissions
  2. Call `NlpPipeline.parse(transcript)` → `ParsedReminder`
  3. If `ParsedReminder.issues` is non-empty: return `Failure(ValidationFailed(issues))` — UI shows clarification card
  4. If `ParsedReminder` has a contact name: call `ContactBridge.resolve(name)` → may return multiple matches, single match, or none
  5. If multiple matches: return `Failure(ContactDisambiguationRequired)`
  6. Build `ValidatedReminder` from ParsedReminder + resolved contact
  7. Call `ConflictDetector.detectConflicts()` — if conflict: return `Failure(ConflictDetected)` — UI shows conflict card
  8. In a single operation: persist `Reminder` + `Trigger` + `Action` atomically in DB
  9. Schedule notification via `NotificationBridge.schedule()`
  10. If scheduling fails: reminder is already persisted (DB is authoritative); return success with warning that reconciliation will retry
- Return type: `Result<Reminder, AppError>`

**Files / directories:** `lib/application/use_cases/create_reminder_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §6.1, §6.2, §27.2.

**Architecture:** ARCHITECTURE.md §5.2.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M1: Contact resolution happens at save time (not at preview time). If the UI wants a preview of contact matches, `ResolveContactsUseCase` may be called separately and `CreateReminderUseCase` re-resolves at save. This prevents TOCTOU issues.
- Notification scheduling is AFTER persistence per ADR-11.

**Acceptance criteria:**
- Full flow: transcript → NLP → contact resolution → conflict check → persist → schedule → returns Reminder
- Missing time → returns `ValidationFailed` with `missingTime` issue
- Conflict detected → returns `ConflictDetected`
- Scheduling failure → reminder is persisted; returns success with warning
- Contact not found → reminder stored with name string only

**Tests:** `test/application/use_cases/create_reminder_use_case_test.dart` — FakeClock, FakeSpeechBridge, FakeNotificationBridge, FakeContactBridge, in-memory DB.

**Do not:**
- Auto-save (ADR-6 — user must explicitly confirm)
- Call `ContactBridge` from within NLP
- Skip conflict detection

---

### TASK-051 — CompleteReminderUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-014, TASK-021, TASK-041

**Purpose:** Implement the Complete use case: transition a reminder to COMPLETED and dismiss its notification.

**Scope:**
- `CompleteReminderUseCase`:
  1. Look up reminder by ID
  2. Call state machine: `transition(reminder, ReminderStatus.COMPLETED, reminder.version + 1)`
  3. If transition fails: return `Failure(InvalidStateTransition)`
  4. Persist updated reminder via `ReminderRepository.update()` with optimistic locking
  5. Cancel notification via `NotificationBridge.cancelForReminder(reminderId)`
  6. If cancel fails: log, continue (notification may already be dismissed)
  7. Return `Result<Reminder, AppError>`

**Files / directories:** `lib/application/use_cases/complete_reminder_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §6.5, §22.

**Architecture:** ARCHITECTURE.md §5.4.

**Acceptance criteria:**
- PENDING → COMPLETED transition succeeds
- Notification is cancelled after persistence
- SNOOZED → COMPLETED transition succeeds
- Already COMPLETED → returns `InvalidStateTransition`

**Tests:** Unit test with fake bridge + in-memory DB.

**Do not:**
- Delete the reminder (COMPLETED is a terminal state, not deletion)
- Call notification cancel before persistence (if persistence fails, notification should remain)

---

### TASK-052 — SnoozeReminderUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-014, TASK-021, TASK-041

**Purpose:** Implement the Snooze use case: transition to SNOOZED with guard check and schedule re-notification.

**Scope:**
- `SnoozeReminderUseCase`:
  1. Look up reminder by ID
  2. Check guard: `reminder.snoozeCount < 10` — if exceeded, return `Failure(InvalidStateTransition)`
  3. Call state machine: `transition(reminder, ReminderStatus.SNOOZED, reminder.version + 1)`
  4. Persist with optimistic locking
  5. Calculate new trigger time: `now + reminder.snoozeDurationMinutes`
  6. Schedule new notification via `NotificationBridge.schedule()`
  7. Return `Result<Reminder, AppError>`

**Files / directories:** `lib/application/use_cases/snooze_reminder_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §6.5, §15.

**Architecture:** ARCHITECTURE.md §5.5.

**Acceptance criteria:**
- PENDING → SNOOZED with snoozeCount incremented
- New notification scheduled at snooze duration from now
- 11th snooze attempt: returns failure (guard)
- SNOOZED → SNOOZED (re-snooze) works

**Tests:** Unit test with FakeClock.

**Do not:**
- Allow unlimited snoozes (guard at 10 per spec)
- Forget to increment `snoozeCount`

---

### TASK-053 — DeleteReminderUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-021, TASK-041

**Purpose:** Implement soft-delete with undo support.

**Scope:**
- `DeleteReminderUseCase`:
  1. Look up reminder by ID
  2. Call `ReminderRepository.softDelete(id)` — sets `is_deleted = 1`, `deleted_at = now`
  3. Cancel notification via `NotificationBridge.cancelForReminder(reminderId)`
  4. Return success with deleted reminder (for undo)
- `UndoDeleteReminderUseCase`:
  1. Restore `is_deleted = 0`, `deleted_at = null`
  2. Re-schedule notification if reminder is still PENDING and trigger time is in future

**Files / directories:** `lib/application/use_cases/delete_reminder_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §28.6 (Undo snackbar).

**Architecture:** ARCHITECTURE.md §5.7.

**Acceptance criteria:**
- Soft delete sets `is_deleted = 1` (row not removed)
- Notification is cancelled
- Undo restores the reminder
- Undo re-schedules notification if applicable

**Tests:** Unit test with in-memory DB.

**Do not:**
- Hard-delete rows (soft delete only — retention per spec)
- Skip notification cancellation on delete

---

### TASK-054 — EditReminderUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-021, TASK-041

**Purpose:** Implement reminder editing with notification re-scheduling.

**Scope:**
- `EditReminderUseCase`:
  1. Look up existing reminder
  2. Accept updated fields (title, notes, scheduledTime, intentType, action details)
  3. If scheduled time changed: cancel old notification, persist updated reminder, schedule new notification
  4. If scheduled time unchanged: persist updated reminder only
  5. All updates use optimistic locking
  6. Return `Result<Reminder, AppError>`

**Files / directories:** `lib/application/use_cases/edit_reminder_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.6 (Reminder detail with edit).

**Architecture:** ARCHITECTURE.md §5.6.

**Acceptance criteria:**
- Title change persists without notification side effects
- Time change cancels old notification and schedules new one
- Optimistic lock conflict returns error

**Tests:** Unit test with in-memory DB.

**Do not:**
- Allow editing COMPLETED or DISMISSED reminders
- Allow editing a deleted reminder

---

### TASK-055 — HandleNotificationActionUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-051, TASK-052, TASK-043

**Purpose:** Route notification action payloads to the appropriate use case. This is the entry point for background notification actions.

**Scope:**
- `HandleNotificationActionUseCase`:
  1. Accept `String reminderId, String actionIdentifier`
  2. Map action identifier to operation:
     - `"DONE"` → `CompleteReminderUseCase`
     - `"SNOOZE"` → `SnoozeReminderUseCase`
     - `"CALL"` → `ActionBridge.launchDialer()` + mark COMPLETED
     - `"OPEN_URL"` → `ActionBridge.launchUrl()` + mark COMPLETED
     - `"EDIT"` → return signal to open app (foreground only)
  3. Execute the delegated use case
  4. Return result

**Files / directories:** `lib/application/use_cases/handle_notification_action_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §22, §25.3.

**Architecture:** ARCHITECTURE.md §5.4.

**Acceptance criteria:**
- DONE action → reminder is COMPLETED
- CALL action → dialer launched + reminder COMPLETED
- OPEN_URL action → browser launched + reminder COMPLETED
- SNOOZE action → reminder SNOOZED + re-notification scheduled
- EDIT action → returns "open app" signal

**Tests:** Unit test with fake bridges.

**Do not:**
- Handle EDIT in background (must open app)
- Auto-launch dialer/SMS without user tapping the notification action

---

### TASK-056 — ReconcileNotificationsUseCase

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-021, TASK-041

**Purpose:** Implement the notification reconciliation algorithm that runs on every foreground entry and daily background wake.

**Scope:**
- `ReconcileNotificationsUseCase`:
  1. Query all PENDING reminders from repository (sorted by trigger time)
  2. Call `NotificationBridge.reconcile(pendingReminders, maxScheduled: 60 for iOS, unlimited for Android)`
  3. Reconciliation algorithm (in NotificationBridge):
     a. Cancel OS notifications for reminders NOT in pending list (orphans)
     b. Schedule OS notifications for PENDING reminders that are missing them
     c. Detect missed deliveries: compare `last_reconciled_at` gap to each reminder's trigger time; if trigger time falls in the gap, set `delivery_status = delivery_uncertain`
     d. Return `ReconciliationResult`
  4. Update `last_reconciled_at` in `app_metadata` after reconciliation completes
  5. Return result

**Files / directories:** `lib/application/use_cases/reconcile_notifications_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §20, §21, §36.1.

**Architecture:** ARCHITECTURE.md §13.

**Acceptance criteria:**
- Orphan notifications (scheduled but DB says COMPLETED) are cancelled
- Missing notifications are scheduled
- Missed deliveries are detected and marked
- `last_reconciled_at` is updated
- Reconciliation is idempotent (running twice = same state)
- iOS: respects 60-notification limit (priority queue)

**Tests:** Integration test: seed DB + OS mismatch, run reconciliation, verify convergence.

**Do not:**
- Skip reconciliation on any foreground entry
- Delete reminders during reconciliation (reconciliation only manages notifications)

---

### TASK-057 — ResolveContactsUseCase

**Phase:** 5 — Application Layer
**Priority:** P1
**Depends on:** TASK-042

**Purpose:** Wrap contact resolution with disambiguation logic. Used both by CreateReminderUseCase and for UI preview.

**Scope:**
- `ResolveContactsUseCase`:
  1. Accept `String name`
  2. Call `ContactBridge.resolve(name)`
  3. If 0 results: return empty — caller handles "contact not found"
  4. If 1 result: return the single match
  5. If >1 result: return all candidates for disambiguation UI
  6. Permission denied: return empty list (no error thrown)

**Files / directories:** `lib/application/use_cases/resolve_contacts_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §6.2 step 5, §10.4.

**Architecture:** ARCHITECTURE.md §5.1.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M1: This use case may be called for UI preview purposes. `CreateReminderUseCase` re-resolves at save time.

**Acceptance criteria:**
- Single match returned directly
- Multiple matches returned for disambiguation
- No matches → empty list
- Permission denied → empty list (no error)

**Tests:** Unit test with FakeContactBridge.

**Do not:**
- Throw on permission denied (return empty — caller handles)
- Auto-pick the first match when multiple exist

---

### TASK-058 — BackgroundServiceLocator

**Phase:** 5 — Application Layer
**Priority:** P0
**Depends on:** TASK-021, TASK-041, TASK-043

**Purpose:** Implement the static service locator for background execution contexts (notification action callbacks, BOOT_COMPLETED receiver, WorkManager).

**Scope:**
- `BackgroundServiceLocator` class:
  - Static lazy initialization: `initialize({databasePath, notificationBridge, actionBridge})`
  - Provides: `ReminderRepository`, `NotificationBridge`, `ActionBridge`, `Clock`
  - `dispose()` method to close database
  - `_ensureInitialized()` guard on all accessors
- Does NOT use Riverpod, WidgetsBinding, or any Flutter UI dependency
- Thread-safe: single initialization (guarded by `_initialized` flag)

**Files / directories:** `lib/application/background_service_locator.dart`

**Requirements:** KATALA_SPEC_V3.md §33.4, §26.

**Architecture:** ARCHITECTURE.md §17.2, §17.3.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M2: Background initialization must complete within 2 seconds on iOS. The first-ever background initialization may be slower (Drift schema creation). Test this explicitly.
- Database path must point to the shared App Group container on iOS, or the app's internal storage on Android.

**Acceptance criteria:**
- `BackgroundServiceLocator.initialize()` opens database and creates repository
- Accessors throw if accessed before initialization
- `dispose()` closes the database
- No Flutter imports in the file

**Tests:** `test/integration/background_service_locator_test.dart` — initialize with in-memory DB, verify accessors work, verify dispose.

**Do not:**
- Use Riverpod in this file
- Reference any widget or UI class
- Skip the initialization guard

---

### TASK-059 — Application Layer Riverpod Providers

**Phase:** 5 — Application Layer
**Priority:** P1
**Depends on:** TASK-050 through TASK-057

**Purpose:** Wire up Riverpod providers for all use cases (foreground DI).

**Scope:**
- Providers for each use case:
  - `createReminderUseCaseProvider`
  - `completeReminderUseCaseProvider`
  - `snoozeReminderUseCaseProvider`
  - `deleteReminderUseCaseProvider`
  - `editReminderUseCaseProvider`
  - `handleNotificationActionUseCaseProvider`
  - `reconcileNotificationsUseCaseProvider`
  - `resolveContactsUseCaseProvider`
- Each provider injects: `ReminderRepository`, relevant bridges, `ConflictDetector`
- `databaseProvider` — singleton Drift database
- `reminderRepositoryProvider` — depends on `databaseProvider`
- Reactive stream providers: `pendingRemindersProvider`, `overdueRemindersProvider`

**Files / directories:** `lib/application/providers.dart`

**Requirements:** KATALA_SPEC_V3.md §33.1.

**Architecture:** ARCHITECTURE.md §18.1.

**Acceptance criteria:**
- All providers compile
- `ProviderScope` can be created with real or overridden providers
- Stream providers react to database changes

**Tests:** Widget test: `ProviderScope.overrides` with fake services, verify providers resolve.

**Do not:**
- Create providers in UI layer (they live in application layer or alongside the provider file)
- Hard-code real implementations in providers (they must be overridable)

---

## Phase 6 — iOS Native Implementation

---

### TASK-060 — iOS SpeechBridgeImpl (SFSpeechRecognizer)

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-040, TASK-004

**Purpose:** Implement the native iOS speech bridge using `SFSpeechRecognizer` with on-device-only enforcement.

**Scope:**
- `SpeechBridgeImpl.swift`:
  - Use `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
  - `startListening()`: configure audio session, begin recognition, stream partial results to Dart via `FlutterEventChannel`
  - `stopListening()`: end audio, return final transcript
  - `cancelListening()`: cancel recognition, close stream without result
  - `getAvailability()`: check `SFSpeechRecognizer.isOnDevice` and authorization status
  - Enforce 30-second max session timeout
  - Silence detection: timer resets on each partial result; no result for N seconds → stop and return
- Method channel: `com.katala.app/speech`
- Handle audio interruptions (phone call, Siri) gracefully

**Files / directories:** `ios/Bridges/SpeechBridgeImpl.swift`

**Requirements:** KATALA_SPEC_V3.md §34.1, CC-6.

**Architecture:** ARCHITECTURE.md §11.2, §14.1, §16.1.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L5: Silence detection uses a timer that resets on each partial result. If no result for N seconds, stop and return final transcript.
- `Info.plist` must have `NSSpeechRecognitionUsageDescription` (already configured in TASK-004).

**Acceptance criteria:**
- Voice → text transcription works on iOS device
- `requiresOnDeviceRecognition = true` is set (verify by checking that cloud-only language throws `SpeechUnavailable`)
- Partial results stream to Dart
- Silence timeout stops recognition
- 30-second max session is enforced

**Tests:** Manual device test: speak known phrase, verify transcription. Test with airplane mode.

**Do not:**
- Set `requiresOnDeviceRecognition = false`
- Store audio to disk
- Use cloud STT fallback

---

### TASK-061 — iOS NotificationBridgeImpl (UNUserNotificationCenter)

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-041, TASK-004

**Purpose:** Implement the native iOS notification bridge.

**Scope:**
- `NotificationBridgeImpl.swift`:
  - `configureCategories()`: register 4 notification categories with action buttons:
    - `REMINDER_GENERAL`: Done, Snooze, Edit (foreground)
    - `REMINDER_CALL`: Call Now, Done, Snooze
    - `REMINDER_TEXT`: Text Now, Done, Snooze
    - `REMINDER_URL`: Open Link, Done, Snooze
  - `schedule()`: create `UNNotificationRequest` with content, trigger, and category
  - `cancel()`: remove pending notification by ID
  - `getScheduledIds()`: query `UNUserNotificationCenter.getPendingNotificationRequests()`
  - `reconcile()`: implement reconciliation algorithm per ARCHITECTURE.md §13.1
  - iOS 64-notification limit: priority queue — nearest 60 scheduled; cancel those not in top 60; schedule missing ones in top 60
  - `dismiss()`: remove delivered notification
- Method channel: `com.katala.app/notifications`

**Files / directories:** `ios/Bridges/NotificationBridgeImpl.swift`

**Requirements:** KATALA_SPEC_V3.md §19, §23, §34.2.

**Architecture:** ARCHITECTURE.md §12, §14.2, §14.3, §16.2.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M3: Categories MUST be registered identically to what `flutter_local_notifications` expects. The native bridge registers categories; `flutter_local_notifications` references them without re-creating. Verify with integration test.
- The 64-notification limit strategy (ARCHITECTURE_CONSISTENCY_REVIEW.md AI Risk #4): priority queue with explicit replacement — do NOT implement "schedule if count < 64 else skip."

**Acceptance criteria:**
- Notifications fire at scheduled time on iOS device
- Actions appear on notification banner
- More than 60 pending reminders → farthest beyond 60 are not scheduled but remain in DB
- Reconciliation cancels orphans and schedules missing

**Tests:** Manual device test: schedule notification, verify delivery and actions.

**Do not:**
- Forget the 64-notification iOS limit
- Implement "append" scheduling (must be priority-queue with replacement)

---

### TASK-062 — iOS ContactBridgeImpl (CNContactStore)

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-042, TASK-004

**Purpose:** Implement native iOS contact resolution via `CNContactStore`.

**Scope:**
- `ContactBridgeImpl.swift`:
  - `resolve(name)`: search `CNContactStore` for matching contacts
  - Search strategy: 1. Exact display-name match (case/diacritic-insensitive). 2. Given-name or family-name prefix. 3. Contains match. Max 20 results.
  - Return `List<Map<String, String?>>` per bridge contract
  - Permission denied → return empty list (no error)
- Method channel: `com.katala.app/contacts`

**Files / directories:** `ios/Bridges/ContactBridgeImpl.swift`

**Requirements:** KATALA_SPEC_V3.md §34.3.

**Architecture:** ARCHITECTURE.md §16.3.

**Acceptance criteria:**
- Contact resolution returns matches from device contacts
- Permission denied returns empty list
- Search strategy matches documented behavior

**Tests:** Manual device test: create reminder "call [real contact name]", verify resolution.

**Do not:**
- Cache contact data (privacy: always query fresh)
- Return more than 20 results

---

### TASK-063 — iOS ActionBridgeImpl

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-043, TASK-004

**Purpose:** Implement native iOS action launching.

**Scope:**
- `ActionBridgeImpl.swift`:
  - `launchDialer(phoneNumber)`: open `tel:` URL via `UIApplication.shared.open()`
  - `launchSms(phoneNumber)`: open `sms:` URL
  - `launchUrl(url)`: validate scheme (http/https only), open via `UIApplication.shared.open()`
- Method channel: `com.katala.app/actions`

**Files / directories:** `ios/Bridges/ActionBridgeImpl.swift`

**Requirements:** KATALA_SPEC_V3.md §31.1, §31.2.

**Architecture:** ARCHITECTURE.md §16.4.

**Acceptance criteria:**
- `launchDialer` opens phone dialer with number pre-filled
- `launchUrl` validates and opens URL in browser
- `javascript:`, `file:`, `data:` schemes are rejected

**Tests:** Manual device test.

**Do not:**
- Auto-initiate calls (use `tel:` URL — shows confirmation)
- Auto-send SMS (open compose screen only)
- Allow non-http/https URL schemes

---

### TASK-064 — iOS Notification Service Extension

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-004, TASK-020

**Purpose:** Implement the Notification Service Extension for handling notification actions while the main app is killed.

**Scope:**
- `NotificationService.swift`:
  - `didReceive(_ response: UNNotificationResponse, completionHandler:)` — handles notification action tap
  - Extract `reminderId` and `action` from notification payload
  - Open shared SQLite database at App Group container path
  - Execute state transition with optimistic locking (raw SQL UPDATE)
  - Dismiss notification after action
  - Handle errors: if DB unavailable, return gracefully (action opens app)
- `ExtensionDatabase.swift` — lightweight SQLite layer:
  - `openDatabase(path)` — opens shared SQLite in WAL mode
  - `updateReminderStatus(id, status, expectedVersion)` → returns success/failure
  - `getSchemaVersion()` — reads `schema_version` from `app_metadata`
  - Schema version guard: if extension's expected version < DB version, refuse to run (return error → iOS opens app)

**Files / directories:** `ios/KatalaNotificationExtension/`

**Requirements:** KATALA_SPEC_V3.md §23.

**Architecture:** ARCHITECTURE.md §14.4-§14.6.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M4: The extension uses raw SQLite (not Drift). When the main app's Drift schema version is incremented, the extension's SQL queries MUST be updated in the same commit. Add a CI check: compare extension's expected schema version to main app's Drift schema version.
- Database file protection: `NSFileProtectionCompleteUnlessOpen` allows lock-screen access (ADR-14).
- WAL mode is mandatory for cross-process access (ADR-8).

**Acceptance criteria:**
- Notification action tapped while app is killed → reminder status is updated in DB
- Schema version mismatch → extension refuses to run (opens app instead)
- Extension completes within 1 second

**Tests:** Manual device test: kill app, deliver notification, tap Done, open app, verify COMPLETED. Test concurrent access: main app + extension modifying same reminder.

**Do not:**
- Use Drift in the extension (too heavy — raw SQLite only per ADR-2)
- Skip the schema version guard
- Forget WAL mode

---

### TASK-065 — iOS BGAppRefreshTask

**Phase:** 6 — iOS Native Implementation
**Priority:** P1
**Depends on:** TASK-061

**Purpose:** Implement iOS background app refresh for periodic reconciliation.

**Scope:**
- Register `BGAppRefreshTask` with identifier `com.katala.app.reconcile`
- Task handler: run `ReconcileNotificationsUseCase` in a background Dart isolate
- Schedule next refresh after each run
- Best-effort only — OS may delay or skip
- Handle expiration: save partial progress, schedule next refresh

**Files / directories:** `ios/Runner/AppDelegate.swift`

**Requirements:** KATALA_SPEC_V3.md §36.7.

**Architecture:** ARCHITECTURE.md §17.1 (BGAppRefreshTask row).

**Acceptance criteria:**
- Background refresh task is registered
- Reconciliation runs (at least sometimes — best-effort)
- Task expiration does not crash

**Tests:** Manual: use `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.katala.app.reconcile"]` in debugger.

**Do not:**
- Rely on this as the primary reconciliation path (foreground is primary)
- Crash on expiration

---

### TASK-066 — iOS AppDelegate & FlutterMethodChannel Registration

**Phase:** 6 — iOS Native Implementation
**Priority:** P0
**Depends on:** TASK-060, TASK-061, TASK-062, TASK-063, TASK-064, TASK-065

**Purpose:** Wire up all iOS method channels in `AppDelegate` and initialize notification categories on startup.

**Scope:**
- `AppDelegate.swift`:
  - Register method channels: `com.katala.app/speech`, `/notifications`, `/contacts`, `/actions`
  - Set channel handlers to the corresponding bridge implementations
  - On launch: call `NotificationBridge.configureCategories()`
  - Register `BGAppRefreshTask` scheduler
  - Configure audio session for speech recognition
- Flutter plugin registration is auto-handled by Flutter engine

**Files / directories:** `ios/Runner/AppDelegate.swift`

**Requirements:** KATALA_SPEC_V3.md §37.5.

**Architecture:** ARCHITECTURE.md §16.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L4: Method channels are auto-registered on iOS by `FlutterAppDelegate`. The native implementations should use `FlutterMethodChannel` with the channel name. Registration happens in `AppDelegate`.

**Acceptance criteria:**
- All four method channels are functional
- Categories are configured before any notification is scheduled
- App builds and runs on iOS simulator

**Tests:** Manual: verify each bridge method is callable from Dart.

**Do not:**
- Register channels manually — use Flutter's auto-registration
- Delay category configuration (must happen before reconciliation)

---

## Phase 7 — Android Native Implementation

---

### TASK-070 — Android SpeechBridgeImpl (SpeechRecognizer)

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-040, TASK-005

**Purpose:** Implement the native Android speech bridge with on-device preference.

**Scope:**
- `SpeechBridgeImpl.kt`:
  - Android 13+ (API 33+): use `SpeechRecognizer.createOnDeviceSpeechRecognizer(context)` — enforces on-device
  - Android 10-12 (API 29-32): use `SpeechRecognizer.createSpeechRecognizer(context)` with `EXTRA_PREFER_OFFLINE = true`
  - `startListening()`: create recognition intent, start listening, stream partial results to Dart
  - `stopListening()`: stop recognition, return final transcript
  - `cancelListening()`: destroy recognizer, close stream
  - `getAvailability()`: check `SpeechRecognizer.isRecognitionAvailable()` and `isOnDeviceRecognitionAvailable()` (API 31+)
  - Silence detection: rely on `SpeechRecognizer`'s built-in end-of-speech detection; timer-based fallback
- Method channel: `com.katala.app/speech`

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/bridges/SpeechBridgeImpl.kt`

**Requirements:** KATALA_SPEC_V3.md §34.1, CC-6, §30.2.

**Architecture:** ARCHITECTURE.md §11.2, §15.1, §16.1.

**Implementation notes:**
- Reference KATALA_SPEC_V3.md §30.2: On Android < 13, `EXTRA_PREFER_OFFLINE` is a preference, not a guarantee. Document this honestly in the UI.
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L5: Rely on built-in end-of-speech detection where available; implement timer-based fallback.

**Acceptance criteria:**
- Voice → text works on Android device
- On Android 13+: `createOnDeviceSpeechRecognizer` is used
- On Android 10-12: `EXTRA_PREFER_OFFLINE` is set
- Partial results stream to Dart

**Tests:** Manual device test: speak known phrase, verify transcription.

**Do not:**
- Use `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` with default settings (must set `EXTRA_PREFER_OFFLINE`)
- Store audio to disk
- Use cloud STT

---

### TASK-071 — Android NotificationBridgeImpl (AlarmManager)

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-041, TASK-005

**Purpose:** Implement the native Android notification bridge using AlarmManager.

**Scope:**
- `NotificationBridgeImpl.kt`:
  - `configureCategories()`: create `NotificationChannel` instances for each category, register action intents
  - `schedule()`: create `PendingIntent` for alarm + notification display; schedule with `AlarmManager.setExactAndAllowWhileIdle()` AND `setAlarmClock()` (dual scheduling per OEM reliability strategy)
  - `cancel()`: cancel `PendingIntent` by matching `requestCode`
  - `getScheduledIds()`: best-effort only — `PendingIntent` cannot be reliably enumerated; track scheduled IDs in memory (rebuilt on app start via reconciliation)
  - `reconcile()`: compare DB state against tracked scheduled IDs
  - `dismiss()`: cancel notification via `NotificationManager.cancel()`
- Method channel: `com.katala.app/notifications`
- Check `AlarmManager.canScheduleExactAlarms()` before scheduling

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/bridges/NotificationBridgeImpl.kt`

**Requirements:** KATALA_SPEC_V3.md §19, §24, §34.2.

**Architecture:** ARCHITECTURE.md §12, §15.4, §16.2.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M3: The native bridge creates `NotificationChannel` instances. `flutter_local_notifications`'s `AndroidInitializationSettings` does NOT create channels independently — it references the already-registered native channels.
- Dual scheduling (`setExactAndAllowWhileIdle` + `setAlarmClock`) is critical for OEM reliability (ARCHITECTURE.md §15.7).

**Acceptance criteria:**
- Notifications fire at scheduled time on Android device
- Notifications fire after Doze entry
- Actions appear on notification
- Exact alarm permission check works

**Tests:** Manual device test: schedule notification, verify delivery. Test on Xiaomi/OPPO/Samsung device if available.

**Do not:**
- Rely solely on `setExact` (use `setAlarmClock` too)
- Skip exact alarm permission check
- Implement `getScheduledIds()` by querying AlarmManager (not reliable on Android)

---

### TASK-072 — Android ContactBridgeImpl (ContactsContract)

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-042, TASK-005

**Purpose:** Implement native Android contact resolution.

**Scope:**
- `ContactBridgeImpl.kt`:
  - `resolve(name)`: query `ContactsContract.Contacts.CONTENT_URI` with name filter
  - Get phone numbers from `ContactsContract.CommonDataKinds.Phone`
  - Search strategy: same as iOS (exact → prefix → contains; max 20 results)
  - Permission denied → return empty list
- Method channel: `com.katala.app/contacts`

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/bridges/ContactBridgeImpl.kt`

**Requirements:** KATALA_SPEC_V3.md §34.3.

**Architecture:** ARCHITECTURE.md §16.3.

**Acceptance criteria:**
- Contact resolution returns matches from device contacts
- Permission denied returns empty list

**Tests:** Manual device test.

**Do not:**
- Cache contact data
- Return more than 20 results

---

### TASK-073 — Android ActionBridgeImpl

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-043, TASK-005

**Purpose:** Implement native Android action launching.

**Scope:**
- `ActionBridgeImpl.kt`:
  - `launchDialer(phoneNumber)`: use `Intent.ACTION_DIAL` (NOT `ACTION_CALL`)
  - `launchSms(phoneNumber)`: use `Intent.ACTION_SENDTO` with `sms:` URI
  - `launchUrl(url)`: validate scheme, open via `Intent.ACTION_VIEW`
- Method channel: `com.katala.app/actions`

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/bridges/ActionBridgeImpl.kt`

**Requirements:** KATALA_SPEC_V3.md §31.1, §31.2.

**Architecture:** ARCHITECTURE.md §16.4.

**Acceptance criteria:**
- `ACTION_DIAL` (not `ACTION_CALL`) is used
- URL scheme validation rejects non-http/https

**Tests:** Manual device test.

**Do not:**
- Use `ACTION_CALL` (must be `ACTION_DIAL`)
- Auto-send SMS

---

### TASK-074 — Android BootReceiver

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-005, TASK-071

**Purpose:** Implement the BOOT_COMPLETED receiver to re-schedule all alarms after device reboot.

**Scope:**
- `BootReceiver.kt`:
  - `onReceive()`: check `Intent.ACTION_BOOT_COMPLETED` or `QUICKBOOT_POWERON`
  - Use `goAsync()` for extended execution (within 10-second budget)
  - Open shared SQLite database
  - Query all PENDING/SNOOZED reminders (limit to nearest 60 to stay within budget)
  - Re-schedule each via `AlarmManager`
  - Update `last_reconciled_at` in `app_metadata`
  - Close database
  - Call `pendingResult.finish()`

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/receivers/BootReceiver.kt`

**Requirements:** KATALA_SPEC_V3.md §36.6.

**Architecture:** ARCHITECTURE.md §15.5.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L2: Query MUST be limited to nearest 60 PENDING reminders to stay within the ~10-second `goAsync()` budget. The full reconciliation will handle the rest on next foreground.

**Acceptance criteria:**
- After reboot, alarms are re-scheduled
- Does not exceed 10-second budget
- Queries limited to 60 nearest reminders

**Tests:** Manual device test: create reminders, reboot device, verify alarms fire.

**Do not:**
- Query all reminders without limit (can exceed 10-second budget)
- Forget `goAsync()` — required for broadcast receiver async work

---

### TASK-075 — Android ReconciliationWorker (WorkManager)

**Phase:** 7 — Android Native Implementation
**Priority:** P1
**Depends on:** TASK-071

**Purpose:** Implement the periodic WorkManager task for daily background reconciliation.

**Scope:**
- `ReconciliationWorker.kt`:
  - Extend `CoroutineWorker`
  - `doWork()`: open shared database, query pending reminders (limit 60), run reconciliation, update `last_reconciled_at`, close database
  - Return `Result.success()` or `Result.retry()` on failure
- Schedule: `PeriodicWorkRequestBuilder<ReconciliationWorker>(24, TimeUnit.HOURS)`
- Constraints: `NetworkType.NOT_REQUIRED` (works offline), requires battery not low

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/workers/ReconciliationWorker.kt`

**Requirements:** KATALA_SPEC_V3.md §36.7.

**Architecture:** ARCHITECTURE.md §15.6.

**Acceptance criteria:**
- Worker is scheduled on app startup
- Reconciliation runs at least once per 24 hours (best-effort, subject to Doze/OEM)
- Failures retry

**Tests:** Manual: use `adb shell am broadcast` to trigger; or use WorkManager testing APIs.

**Do not:**
- Assume this is reliable on all devices (OEMs may restrict WorkManager)
- Skip error handling (always return `Result.retry()` on transient failure)

---

### TASK-076 — Android NotificationActionReceiver

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-005

**Purpose:** Implement the BroadcastReceiver for handling notification actions (Done, Snooze, Call, Open Link) when the app is in the background.

**Scope:**
- `NotificationActionReceiver.kt`:
  - `onReceive()`: extract action identifier and reminder ID from intent extras
  - Route to appropriate handling:
    - DONE → launch Dart callback or use native Kotlin SQLite for state transition
    - SNOOZE → same
    - CALL → `ActionBridge.launchDialer()`
    - OPEN_URL → `ActionBridge.launchUrl()`
  - Decision point: if the Flutter engine is alive, delegate to Dart `BackgroundServiceLocator`. If killed, use native SQLite (similar to iOS extension approach).
- Register with `exported=false` in manifest

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/receivers/NotificationActionReceiver.kt`

**Requirements:** KATALA_SPEC_V3.md §24.4.

**Architecture:** ARCHITECTURE.md §15.3.

**Acceptance criteria:**
- Done notification action works while app is backgrounded
- After action: reminder status is updated in DB
- Notification is dismissed after action

**Tests:** Manual device test.

**Do not:**
- Always spin up Flutter engine (check if already alive first)
- Block the receiver thread

---

### TASK-077 — Android MainActivity & MethodChannel Registration

**Phase:** 7 — Android Native Implementation
**Priority:** P0
**Depends on:** TASK-070 through TASK-076

**Purpose:** Wire up all Android method channels and initialize background workers on startup.

**Scope:**
- `MainActivity.kt`:
  - Configure method channels: `com.katala.app/speech`, `/notifications`, `/contacts`, `/actions`
  - Set channel handlers to the corresponding bridge implementations
  - On create: call `NotificationBridge.configureCategories()`
  - Schedule `ReconciliationWorker` with `PeriodicWorkRequest`
  - Initialize `BackgroundServiceLocator` with database path and bridges
- `Application.kt` (or `MainActivity`): check exact alarm permission on first launch

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/MainActivity.kt`

**Requirements:** KATALA_SPEC_V3.md §37.6.

**Architecture:** ARCHITECTURE.md §16.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L4: Method channels are auto-registered by `FlutterEngine`. Configure in `configureFlutterEngine()` override.

**Acceptance criteria:**
- All four method channels are functional
- Categories configured before any notification
- Worker scheduled on startup
- App builds and runs on Android emulator

**Tests:** Manual: verify each bridge method is callable from Dart.

**Do not:**
- Register channels in `onCreate` before Flutter engine is ready
- Skip category configuration

---

### TASK-078 — Android OEM Reliability Integration

**Phase:** 7 — Android Native Implementation
**Priority:** P1
**Depends on:** TASK-071, TASK-074, TASK-075

**Purpose:** Implement the OEM reliability status detection and per-manufacturer guidance.

**Scope:**
- Detect reliability level:
  - **Good:** exact alarm granted, battery optimization disabled, auto-start enabled
  - **Fair:** exact alarm granted, battery optimization may be active
  - **Poor:** exact alarm denied or device known to aggressively kill background processes
- Per-manufacturer guidance strings (Xiaomi, OPPO, realme, Samsung, Huawei):
  - Instructions for disabling battery optimization
  - Instructions for enabling auto-start
- `ReliabilityStatus` provider accessible from Settings UI
- Detect `Build.MANUFACTURER` and show appropriate guidance

**Files / directories:** `android/app/src/main/kotlin/com/katala/app/bridges/ReliabilityChecker.kt`

**Requirements:** KATALA_SPEC_V3.md §24.7.

**Architecture:** ARCHITECTURE.md §15.7.

**Acceptance criteria:**
- Reliability status is Good/Fair/Poor based on actual device state
- Manufacturer-specific guidance is shown for known OEMs
- Generic guidance for unknown manufacturers

**Tests:** Manual: test on different manufacturer devices (or emulators with spoofed Build.MANUFACTURER).

**Do not:**
- Exaggerate reliability (be honest per §1.11)
- Attempt to auto-modify battery optimization settings (user must do it)

---

## Phase 8 — UI Implementation

---

### TASK-080 — Theme, Typography & Color System

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-001

**Purpose:** Implement the design system: color tokens, typography, dark/light theme, and Inter font configuration.

**Scope:**
- `colors.dart`: all color tokens from KATALA_SPEC_V3.md §28.2 (dark + light)
- `typography.dart`: Inter font styles per §28.3 (Headline 28sp Bold, Title 20sp SemiBold, Body 16sp Regular, Caption 14sp Regular, Small 12sp Medium)
- `ThemeData` for dark theme (default) and light theme
- `MaterialApp` configuration in `app.dart`:
  - `themeMode`: default to dark
  - `theme`: light `ThemeData`
  - `darkTheme`: dark `ThemeData`
- Font family: "Inter" with fallback to system default

**Files / directories:** `lib/ui/theme/colors.dart`, `lib/ui/theme/typography.dart`, `lib/app.dart`

**Requirements:** KATALA_SPEC_V3.md §28.1-§28.3.

**Architecture:** ARCHITECTURE.md §3 (directory structure).

**Acceptance criteria:**
- App renders with dark theme by default
- All color tokens are accessible
- Inter font is used (verify on device/simulator)
- Light theme is available via Settings toggle

**Tests:** Widget test: verify theme is applied; verify color contrast meets 4.5:1 minimum.

**Do not:**
- Use `google_fonts` package (fonts are bundled)
- Add colors not in the spec's color system
- Hard-code colors in widgets (use theme tokens)

---

### TASK-081 — App Shell & Navigation

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-080, TASK-059

**Purpose:** Implement the app shell with navigation and the main scaffold.

**Scope:**
- `main.dart`: `ProviderScope` wrapping `MaterialApp`
- `app.dart`: `MaterialApp` with theme, routes
- Navigation: push-based (no bottom nav bar — single-screen app with overlays)
- Routes:
  - `/` → HomeScreen
  - `/reminder/:id` → ReminderDetailScreen
  - `/settings` → SettingsScreen
  - `/onboarding` → OnboardingScreen (first launch only)
- Overlays: VoiceInputOverlay, ConfirmationCard, ClarificationCard (shown as bottom sheets or dialogs)
- Startup sequence in `main.dart`:
  1. Initialize database
  2. Run integrity check
  3. Run reconciliation
  4. Configure notification categories
  5. Render UI

**Files / directories:** `lib/main.dart`, `lib/app.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4, §36.1.

**Architecture:** ARCHITECTURE.md §3, §17.3 (foreground initialization).

**Acceptance criteria:**
- App launches without errors
- Dark theme is applied
- Startup sequence runs in correct order
- Navigation between screens works

**Tests:** Widget test: app launches, ProviderScope is accessible.

**Do not:**
- Add a bottom navigation bar (single-screen app)
- Skip the startup integrity check + reconciliation sequence
- Use named routes with `onGenerateRoute` (simple push navigation is fine)

---

### TASK-082 — Home Screen (Timeline)

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-081, TASK-059

**Purpose:** Implement the primary home screen with grouped timeline, FAB, and empty states.

**Scope:**
- `HomeScreen`:
  - Observe `pendingRemindersProvider` via Riverpod
  - Group reminders: Overdue, Today, Tomorrow, This Week, Later
  - Each group: expandable section header with count badge
  - Reminder tiles: title, time, intent icon (📞, 🔗, etc.), delivery status indicator
  - Overdue group: expanded by default, red accent
  - Reliability banner: shown when `delivery_uncertain` reminders exist (§28.4.2)
  - FAB: large mic button (primary accent color)
  - Empty state: bird illustration + "No reminders yet. Tap the mic to create one."
  - All-caught-up state: bird illustration + "All caught up! 🎉"
  - Pull-to-refresh: triggers reconciliation
  - Swipe right → complete; swipe left → delete; long-press alternatives

**Files / directories:** `lib/ui/screens/home_screen.dart`, `lib/ui/widgets/timeline_group.dart`, `lib/ui/widgets/reminder_tile.dart`, `lib/ui/widgets/reliability_banner.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.2, §28.5, §28.7.

**Acceptance criteria:**
- Timeline shows overdue reminders first (expanded, red)
- Groups are correctly categorized by time
- Empty state renders when no reminders exist
- Pull-to-refresh triggers reconciliation
- Swipe gestures work
- Accessibility labels on all interactive elements

**Tests:** Widget test: render with mock providers, verify grouping; swipe gesture test.

**Do not:**
- Cache reminder state in UI (always observe via Riverpod stream)
- Show completed reminders on the timeline (hidden by default per PD-6)
- Use color alone to indicate status (add icons + text)

---

### TASK-083 — Mic Button & Voice Input Overlay

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-082, TASK-040

**Purpose:** Implement the one-tap microphone button and the listening-state overlay.

**Scope:**
- `MicButton`: FAB with microphone icon
  - Check microphone permission + STT availability before starting
  - If unavailable: button disabled with explanation
  - On tap: audio session starts, overlay appears
- `VoiceInputOverlay`:
  - Pulsing mic icon with waveform animation
  - Live transcript streaming from `SpeechBridge.startListening()`
  - Tap to stop: ends listening, sends transcript to NLP pipeline
  - Haptic feedback on start/stop
  - Auto-stop after 30 seconds (max session)
  - Error states: "Voice input unavailable", "I didn't catch that", etc.

**Files / directories:** `lib/ui/widgets/mic_button.dart`, `lib/ui/widgets/voice_input_overlay.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.3.

**Acceptance criteria:**
- Mic button is prominent and accessible
- Tapping starts listening with animation
- Transcript appears in real-time
- Tapping again stops and processes
- Disabled state when STT unavailable

**Tests:** Widget test: render with `FakeSpeechBridge`, verify transcript appears; error state test.

**Do not:**
- Auto-save after voice input (always show confirmation card)
- Block the UI thread during STT
- Record audio to disk

---

### TASK-084 — Confirmation Card

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-050

**Purpose:** Implement the reminder preview/confirmation card shown after successful NLP parsing.

**Scope:**
- `ConfirmationCard` widget (bottom sheet or dialog):
  - Shows parsed: title, time (formatted), contact name + phone (if any), URL (if any), notes
  - [Save] button: calls `CreateReminderUseCase` to persist
  - [Edit] button: opens manual edit form with pre-filled fields
  - Haptic feedback + chirp sound on successful save
  - Success state: brief checkmark animation, then dismiss
  - Error state: "Couldn't save. Try again." with retry
  - Conflict warning: integrated into confirmation card (see TASK-085)

**Files / directories:** `lib/ui/widgets/confirmation_card.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.4.

**Acceptance criteria:**
- Parsed fields are displayed clearly
- Save calls CreateReminderUseCase
- Edit opens editable form
- Save success → dismisses card
- Save failure → shows error with retry

**Tests:** Widget test: render with mock ParsedReminder, tap Save, verify use case called.

**Do not:**
- Auto-save (user must tap Save per ADR-6)
- Skip contact disambiguation display (show multiple matches if applicable)

---

### TASK-085 — Clarification Card

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-050

**Purpose:** Implement the clarification card for when NLP validation fails — missing time, ambiguous time, missing title, etc.

**Scope:**
- `ClarificationCard` widget:
  - Shows original transcript
  - Shows specific question based on `ValidationIssue`:
    - `missingTime` → "When should I remind you?" with time picker + quick chips ("Later today", "Tomorrow 9 AM", "Tomorrow 5 PM")
    - `ambiguousTime` → "Did you mean AM or PM?" with AM/PM toggle
    - `missingTitle` → "What should I remind you about?" with text field
    - `timeInPast` → "That time has passed. Pick a future time." with time picker
  - Save is disabled until all required fields are filled
  - Manual input for all fields always available

**Files / directories:** `lib/ui/widgets/clarification_card.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.5, §12.

**Acceptance criteria:**
- Each `ValidationIssue` enum value produces a specific, helpful clarification
- Save is disabled until required fields are complete
- Quick-pick chips provide fast resolution
- Time picker is available as fallback

**Tests:** Widget test: render with each `ValidationIssue`, verify correct question and input.

**Do not:**
- Show a generic "I didn't understand" message — always be specific
- Auto-resolve ambiguous times

---

### TASK-086 — Conflict Warning Display

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-015, TASK-084

**Purpose:** Implement the conflict warning UI shown when a new reminder conflicts with existing ones.

**Scope:**
- `ConflictWarning` widget (integrated into confirmation card flow):
  - Shows: "This overlaps with [existing reminder title] at [time]"
  - Primary action: "Move to [suggested alternative time]"
  - Secondary action: "Save Anyway"
  - Tertiary action: "Cancel" (go back to editing)
  - Displays conflicting reminders for context

**Files / directories:** `lib/ui/widgets/conflict_warning.dart`

**Requirements:** KATALA_SPEC_V3.md §18, §28.4.4.

**Architecture:** ARCHITECTURE.md §5.2.

**Acceptance criteria:**
- Conflict detected → warning shown with suggested alternative
- "Move to" updates the scheduled time
- "Save Anyway" persists despite conflict
- "Cancel" returns to editing

**Tests:** Widget test: mock ConflictDetectedError, verify three options displayed.

**Do not:**
- Block saving entirely (user can always choose "Save Anyway")
- Forget to show the conflicting reminder's title and time

---

### TASK-087 — Reminder Detail Screen

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-081

**Purpose:** Implement the reminder detail view with full information, action buttons, and edit capability.

**Scope:**
- `ReminderDetailScreen`:
  - Title, time, notes, intent type with icon
  - Contact info (if any) with action button (Call/Text)
  - URL (if any) with "Open" button
  - Status badge (PENDING/COMPLETED/SNOOZED/DISMISSED)
  - Action buttons: [Complete] [Snooze] [Edit] [Delete]
  - Edit mode: allows modifying title, time, notes, action details
  - Delivery status indicator
  - Created/updated/completed timestamps
  - Original transcript (if voice-created)

**Files / directories:** `lib/ui/screens/reminder_detail_screen.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.6.

**Acceptance criteria:**
- All reminder fields are displayed
- Action buttons work (Complete → COMPLETED, etc.)
- Edit mode saves changes
- Delete with undo snackbar
- Back navigation works

**Tests:** Widget test: render with mock Reminder, verify all fields, tap Complete.

**Do not:**
- Allow editing COMPLETED or DISMISSED reminders
- Show edit/complete buttons for terminal-state reminders

---

### TASK-088 — Text Input Fallback

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-083

**Purpose:** Implement the manual text input as an always-available alternative to voice.

**Scope:**
- `TextInputField` widget:
  - Accessible via swipe on mic button or keyboard icon
  - Text field with auto-focus
  - Real-time NLP parsing (debounced 300ms) as user types
  - Shows parsed preview below input (title, time, contact, etc.)
  - On submit: runs same NLP → confirmation flow as voice
  - Character limit: 500 characters

**Files / directories:** `lib/ui/widgets/text_input_field.dart`

**Requirements:** KATALA_SPEC_V3.md §6.3.

**Acceptance criteria:**
- Text input is always available
- Live preview updates as user types
- Submit triggers same NLP pipeline as voice
- Voice-unavailable state highlights text input as primary path

**Tests:** Widget test: type text, verify NLP pipeline called (with debounce).

**Do not:**
- Use a different NLP path for text vs. voice (same pipeline)
- Skip the confirmation card for text input

---

### TASK-089 — Settings Screen

**Phase:** 8 — UI Implementation
**Priority:** P1
**Depends on:** TASK-081

**Purpose:** Implement the Settings screen with user preferences and platform-specific reliability info.

**Scope:**
- `SettingsScreen`:
  - Default snooze duration picker (5/10/15/30 minutes)
  - Theme toggle: Dark / Light / System
  - Language: English (only option in MVP)
  - Android: Notification reliability section:
    - Status indicator (Good/Fair/Poor)
    - Pending/scheduled/uncertain/missed counts
    - Battery optimization status + shortcut
    - Exact alarm permission status
    - Manufacturer-specific guidance
  - Database backup toggle (opt-in with privacy notice)
  - Privacy policy link
  - About section
  - Diagnostics (long-press version number): DB size, reminder counts, last reconciliation, STT availability, permission statuses, sanitized logs

**Files / directories:** `lib/ui/screens/settings_screen.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.7, §25.4, §25.5.

**Architecture:** ARCHITECTURE.md §25.4-§25.5.

**Acceptance criteria:**
- Settings screen is accessible from home screen
- Theme toggle works immediately
- Snooze duration is persisted
- Android reliability section shows accurate data

**Tests:** Widget test: render settings, tap theme toggle, verify theme changes.

**Do not:**
- Add settings not in the spec
- Transmit diagnostic data (everything is local-only)

---

### TASK-090 — Onboarding Flow

**Phase:** 8 — UI Implementation
**Priority:** P0
**Depends on:** TASK-081

**Purpose:** Implement the 3-screen onboarding carousel for first-launch permission education.

**Scope:**
- `OnboardingScreen`:
  - **Screen 1: Welcome** — Katala logo, tagline, [Get Started]
  - **Screen 2: How It Works** — animated mic icon, example, [Next]
  - **Screen 3: Permissions** — Microphone + Notifications with [Grant] buttons, [Done]
- Request Microphone and Notification permissions on Screen 3
- Contacts permission is NOT requested here (requested contextually on first CALL/TEXT reminder)
- Onboarding shown only on first launch (track via `shared_preferences`)
- Skip available on all screens

**Files / directories:** `lib/ui/screens/onboarding_screen.dart`

**Requirements:** KATALA_SPEC_V3.md §28.4.1, §30.4.

**Architecture:** ARCHITECTURE.md §20.1.

**Acceptance criteria:**
- Onboarding shown only on first launch
- All three screens are present
- Permission requests trigger native dialogs
- "Done" navigates to home screen
- Skippable from any screen

**Tests:** Widget test: verify onboarding renders, verify completion flag is saved.

**Do not:**
- Request Contacts permission during onboarding
- Request Location permission at all (Post-MVP)
- Make onboarding unskippable

---

### TASK-091 — Swipe Gestures & Undo Snackbar

**Phase:** 8 — UI Implementation
**Priority:** P1
**Depends on:** TASK-082

**Purpose:** Implement swipe-to-complete, swipe-to-delete, and the 5-second undo snackbar.

**Scope:**
- Swipe right on reminder tile → green stripe → mark COMPLETED
- Swipe left on reminder tile → red stripe → soft-delete
- After complete/delete: undo snackbar with 5-second countdown bar
- Undo reverses the state transition
- Long-press alternative for accessibility (opens context menu with Complete/Delete options)

**Files / directories:** `lib/ui/widgets/reminder_tile.dart` (gesture handlers)

**Requirements:** KATALA_SPEC_V3.md §28.5, §28.6.

**Acceptance criteria:**
- Swipe right completes the reminder
- Swipe left deletes the reminder
- Undo snackbar appears for 5 seconds
- Undo reverses the action
- Long-press shows alternative for screen reader users

**Tests:** Widget test: simulate swipe, verify use case called, verify undo works.

**Do not:**
- Hard-delete after snackbar expires (soft delete is permanent after undo window)
- Forget accessibility alternatives

---

### TASK-092 — Empty & Error States

**Phase:** 8 — UI Implementation
**Priority:** P1
**Depends on:** TASK-082

**Purpose:** Implement all empty states, error states, and the database corruption recovery screen.

**Scope:**
- Empty timeline: bird illustration + "No reminders yet"
- All-caught-up: bird illustration + "All caught up! 🎉"
- Voice unavailable: mic disabled + explanation + text input highlighted
- Database corruption: recovery screen with [Restore from Backup] [Reset Database]
- Permission denied states for mic, notifications, contacts
- STT unavailable: explanation + text fallback

**Files / directories:** `lib/ui/widgets/` (various error/empty state widgets)

**Requirements:** KATALA_SPEC_V3.md §28.7, §35.2.

**Acceptance criteria:**
- Every error state from §35.2 has a corresponding UI
- Empty states are not error-looking (friendly, on-brand)
- Recovery screen for database corruption is clear and actionable

**Tests:** Widget test: trigger each error state, verify correct message and action buttons.

**Do not:**
- Show raw error messages to users (always use user-friendly text)
- Log personal data in error states

---

### TASK-093 — Accessibility Implementation

**Phase:** 8 — UI Implementation
**Priority:** P1
**Depends on:** TASK-082 through TASK-092

**Purpose:** Ensure WCAG 2.1 AA equivalent accessibility across all screens.

**Scope:**
- All tappable targets ≥ 48×48 dp
- Minimum contrast ratio: 4.5:1 for normal text, 3:1 for large text
- All interactive elements have `Semantics` labels
- Screen reader: all screens navigable via TalkBack/VoiceOver
- Long-press alternatives for all swipe gestures
- Haptic feedback for key actions (save, complete, error)
- Do not rely solely on color to convey state (icons + text alongside color)
- Live transcript during voice input (captions)

**Files / directories:** All UI files (accessibility audit pass)

**Requirements:** KATALA_SPEC_V3.md §29.

**Acceptance criteria:**
- TalkBack/VoiceOver can navigate all screens
- Contrast ratios pass WCAG AA minimums
- All interactive elements have labels
- Color is never the sole indicator of state
- Haptic feedback on save, complete, and error

**Tests:** Manual accessibility audit with screen reader. Widget test: verify semantics labels.

**Do not:**
- Skip any screen in the accessibility audit
- Use color-only state indicators

---

## Phase 9 — First Vertical Slice (M3)

---

### TASK-100 — End-to-End Voice-to-Persist Integration

**Phase:** 9 — First Vertical Slice
**Priority:** P0
**Depends on:** TASK-050 (CreateReminderUseCase), TASK-060 (iOS SpeechBridge), TASK-070 (Android SpeechBridge), TASK-082 through TASK-084 (UI)

**Purpose:** Wire together the complete vertical slice: Voice → STT → NLP → Confirmation → Persist → Notification → Display on Timeline. This is milestone M3.

**Scope:**
- Integration test: on real device or simulator
  1. Tap mic → audio session starts
  2. Speak a known phrase (or use FakeSpeechBridge in test)
  3. Live transcript streams to overlay
  4. Stop → NLP parses transcript
  5. Confirmation card appears with parsed fields
  6. Tap Save → reminder persists, notification is scheduled
  7. Timeline shows the new reminder
- Verify: reminder is in database, notification is scheduled (check OS notification center)
- Verify: < 5 seconds from mic tap to persisted (mid-range device)

**Files / directories:** Integration test file.

**Requirements:** KATALA_SPEC_V3.md §6.1, G1.

**Architecture:** ARCHITECTURE.md §5.2, §30.1 (architecture validation).

**Acceptance criteria:**
- Full flow works end-to-end on at least one platform
- Reminder appears in database after save
- Notification is scheduled
- Timeline reflects the new reminder
- Voice-to-persisted completes in < 5 seconds on mid-range device

**Tests:** Integration test: `test/integration/create_reminder_flow_test.dart`

**Do not:**
- Skip this milestone — it's the first proof that the architecture works
- Test only on simulator (test on at least one real device)

---

### TASK-101 — Device Validation — iOS

**Phase:** 9 — First Vertical Slice
**Priority:** P0
**Depends on:** TASK-100, TASK-064

**Purpose:** Validate the complete flow on a real iOS device, including notification actions while app is killed.

**Scope:**
- Test matrix:
  1. Create voice reminder → verify notification fires
  2. Kill app → notification fires → tap Done → open app → verify COMPLETED
  3. Kill app → notification fires → tap Snooze → verify re-notification
  4. Kill app → notification fires → tap Call Now → verify dialer opens + COMPLETED
  5. Rapid alternation: main app + extension modifying same reminder → verify optimistic lock
  6. Airplane mode: create reminder → notification fires → tap Done → works fully offline
  7. Multiple reminders (70+) → verify only nearest 60 scheduled

**Requirements:** KATALA_SPEC_V3.md §38.1 (iOS tests).

**Architecture:** ARCHITECTURE.md §30 (validation questions).

**Acceptance criteria:**
- All 7 device tests pass on iOS 16+ device
- Extension handles actions in < 1 second
- Cross-process DB access works
- WAL mode prevents corruption

**Tests:** Manual device validation.

**Do not:**
- Skip the killed-app notification action test (this is the riskiest path)
- Test only on simulator (extension behavior differs)

---

### TASK-102 — Device Validation — Android

**Phase:** 9 — First Vertical Slice
**Priority:** P0
**Depends on:** TASK-100, TASK-074, TASK-076

**Purpose:** Validate the complete flow on a real Android device, including reboot and OEM behavior.

**Scope:**
- Test matrix:
  1. Create voice reminder → verify notification fires
  2. Kill app (force-stop) → open app → verify reconciliation detects missed notification
  3. Reboot device → verify alarms re-scheduled via BootReceiver
  4. Notification action while app backgrounded → verify state transition
  5. Doze mode: wait for Doze → verify alarm still fires (setExactAndAllowWhileIdle + setAlarmClock)
  6. Airplane mode: full flow works offline
  7. Test on at least one OEM device (Xiaomi/OPPO/Samsung) if available

**Requirements:** KATALA_SPEC_V3.md §38.1 (Android tests).

**Architecture:** ARCHITECTURE.md §15.7, §30.

**Acceptance criteria:**
- All 7 device tests pass on Android 10+ device
- BootReceiver re-schedules alarms within 10 seconds
- Force-stop recovery works on next foreground
- Doze does not prevent notification delivery

**Tests:** Manual device validation.

**Do not:**
- Skip OEM device testing if available (this is the Philippine-market target)
- Assume all Android devices behave like stock Android

---

## Phase 10 — Notification System Hardening

---

### TASK-110 — Notification Category Coordination & Integration Test

**Phase:** 10 — Notification System Hardening
**Priority:** P0
**Depends on:** TASK-061, TASK-071, TASK-041

**Purpose:** Verify that native notification categories registered by the custom bridge are correctly recognized by `flutter_local_notifications` action handlers. This resolves ARCHITECTURE_CONSISTENCY_REVIEW.md M3.

**Scope:**
- Integration test:
  1. Register categories via `NotificationBridge.configureCategories()` (native)
  2. Initialize `flutter_local_notifications` with the SAME category identifiers
  3. Schedule a notification with each category
  4. Tap each action on the notification
  5. Verify the correct `onDidReceiveNotificationResponse` callback fires with the correct `actionId`
  6. Verify categories are identical between native and Dart sides (no identifier mismatches)
- Document the exact category identifier strings used on both sides
- On Android: verify `NotificationChannel` IDs match category identifiers
- On iOS: verify `UNNotificationCategory` identifiers match

**Files / directories:** Integration test, `lib/platform/bridges/notification_bridge.dart` (documentation)

**Architecture:** ARCHITECTURE.md §12.3, §16.5.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md M3: On iOS, `DarwinInitializationSettings` must pass the same category identifiers. On Android, `AndroidInitializationSettings` does NOT create channels — they are created by the native bridge. The Dart side references them only.

**Acceptance criteria:**
- All 4 notification categories work with action buttons
- `onDidReceiveNotificationResponse` fires for each action type
- No identifier mismatches between native and Dart
- Integration test passes on both platforms

**Tests:** Integration test: `test/integration/notification_category_test.dart`

**Do not:**
- Create categories independently in native and Dart (one source of truth: native bridge)
- Use different identifier strings

---

### TASK-111 — Notification ID Mapping & Lifecycle

**Phase:** 10 — Notification System Hardening
**Priority:** P0
**Depends on:** TASK-061, TASK-071

**Purpose:** Ensure robust notification ID mapping between DB and OS, handling all lifecycle scenarios.

**Scope:**
- Notification ID stored in `trigger_.notification_id` after scheduling
- ID is platform-generated integer
- On cancellation: ID is nulled in DB
- On re-scheduling (e.g., after snooze): old ID cancelled, new ID generated and stored
- Lifecycle scenarios to handle:
  - App force-stopped → all IDs unknown → reconciliation re-derives from DB
  - Notification dismissed by user (not via Katala action) → ID still in DB → reconciliation cancels orphan
  - Multiple notifications for same reminder (should never happen) → reconciliation deduplicates
- `NotificationBridge.getScheduledIds()`: best-effort on Android (in-memory tracking + reconciliation fallback)

**Files / directories:** `lib/platform/bridges/notification_bridge.dart` (Dart side), native implementations

**Requirements:** KATALA_SPEC_V3.md §19, §20.

**Architecture:** ARCHITECTURE.md §12.4.

**Acceptance criteria:**
- Every scheduled notification has a DB-tracked ID
- Cancellation updates DB
- Re-scheduling properly cleans up old ID
- Reconciliation deduplicates
- No notification ID leaks (orphans cleaned on reconciliation)

**Tests:** Integration test: schedule → verify ID stored → cancel → verify ID cleared → re-schedule → verify new ID.

**Do not:**
- Rely on OS to track notification IDs (DB is authoritative)
- Allow duplicate notification IDs for same reminder

---

### TASK-112 — Stale Notification Cleanup & Duplicate Prevention

**Phase:** 10 — Notification System Hardening
**Priority:** P1
**Depends on:** TASK-056, TASK-111

**Purpose:** Implement proactive stale notification cleanup and prevent duplicate notifications.

**Scope:**
- Stale notification detection: any OS notification whose DB reminder is COMPLETED, DISMISSED, or soft-deleted
- Cleanup on reconciliation: cancel all detected stale notifications
- Duplicate prevention:
  - Before scheduling: check if `trigger_.notification_scheduled == true` and a valid `notification_id` exists
  - If a notification is already scheduled for this reminder: cancel it first, then schedule new (idempotent scheduling)
  - Race condition guard: scheduling uses a check-then-act pattern with DB transaction

**Files / directories:** `lib/application/use_cases/reconcile_notifications_use_case.dart` (enhanced)

**Requirements:** KATALA_SPEC_V3.md §20.2, §27.7.

**Architecture:** ARCHITECTURE.md §13.1.

**Acceptance criteria:**
- Reconciliation cancels notifications for COMPLETED/DISMISSED reminders
- Scheduling a notification for an already-scheduled reminder cancels the old one first
- No duplicate notifications fire for the same reminder
- Race condition between scheduling and reconciliation does not produce duplicates

**Tests:** Integration test: seed stale notifications in fake bridge, run reconciliation, verify cancelled.

**Do not:**
- Skip the cancel-before-schedule step (must be idempotent)

---

### TASK-113 — Missed Notification Detection & delivery_uncertain Logic

**Phase:** 10 — Notification System Hardening
**Priority:** P0
**Depends on:** TASK-056

**Purpose:** Implement robust missed-notification detection during reconciliation.

**Scope:**
- On every reconciliation:
  1. Read `last_reconciled_at` from `app_metadata`
  2. For each PENDING reminder whose `scheduled_time_utc` falls between `last_reconciled_at` and `now`:
     - If `delivery_status == scheduled`: set to `delivery_uncertain`
  3. Update `last_reconciled_at` AFTER the reconciliation pass
- `delivery_missed` status: set when the user explicitly confirms they didn't see a notification (via the reliability banner)
- Gap calculation: if `last_reconciled_at` is null (first reconciliation), skip missed detection for the first pass

**Files / directories:** `lib/application/use_cases/reconcile_notifications_use_case.dart`

**Requirements:** KATALA_SPEC_V3.md §21, §36.1.

**Architecture:** ARCHITECTURE.md §13.2.

**Acceptance criteria:**
- Missed deliveries correctly detected based on time gap
- `delivery_uncertain` is set for reminders in the gap
- `last_reconciled_at` is updated after each reconciliation
- First reconciliation (null `last_reconciled_at`) skips missed detection

**Tests:** Unit test: seed DB with reminders in the past, mock `last_reconciled_at` to old date, run reconciliation, verify `delivery_uncertain` set.

**Do not:**
- Mark all past reminders as missed (only those in the gap since last reconciliation)
- Forget to update `last_reconciled_at` after reconciliation

---

## Phase 11 — Integration, Testing & Polish

---

### TASK-120 — NLP Pipeline Integration Tests

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-036, TASK-050

**Purpose:** Run the full NLP corpus through the end-to-end pipeline (not just individual stages).

**Scope:**
- Integration test: for every corpus entry, run `NlpPipeline.parse()` with FakeClock
- Assert: intent matches expected, title matches expected, time matches expected, issues match expected
- Regression testing: corpus must stay at 100% pass rate
- Add CI step: `flutter test test/domain/nlp/corpus/`

**Files / directories:** `test/domain/nlp/corpus_runner_test.dart`

**Requirements:** KATALA_SPEC_V3.md §38.2.

**Architecture:** ARCHITECTURE.md §10 (NLP Test Architecture).

**Acceptance criteria:**
- 100% corpus pass rate
- Test runs in CI
- Adding a new corpus entry that breaks existing cases is caught

**Tests:** This is a test task — it validates existing tests all pass together.

**Do not:**
- Skip Taglish corpus entries (they're MVP)

---

### TASK-121 — Use Case Integration Tests

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-050 through TASK-057

**Purpose:** Write integration tests for all use cases with real in-memory Drift and fake bridges.

**Scope:**
- Tests:
  - `create_reminder_flow_test.dart`: transcript → NLP → confirmation → persist → verify DB + fake notification
  - `notification_action_flow_test.dart`: seed DB → simulate notification action → verify state transition
  - `reconciliation_flow_test.dart`: seed DB + fake bridge mismatch → reconcile → verify convergence
  - `background_service_locator_test.dart`: initialize locator → execute use case → dispose
  - `concurrent_modification_test.dart`: two simultaneous updates → verify optimistic lock

**Files / directories:** `test/integration/`

**Requirements:** KATALA_SPEC_V3.md §38.3.

**Architecture:** ARCHITECTURE.md §23.4.

**Acceptance criteria:**
- All integration tests pass
- Tests run in CI without physical device

**Tests:** This task creates the tests.

**Do not:**
- Use real bridges in integration tests (use fakes)
- Skip any use case

---

### TASK-122 — Widget Tests

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-082 through TASK-092

**Purpose:** Write widget tests for all key UI components.

**Scope:**
- Tests:
  - `confirmation_card_test.dart`: render with ParsedReminder, tap Save, verify use case called
  - `clarification_card_test.dart`: render with each ValidationIssue, verify correct input
  - `timeline_group_test.dart`: render with mock reminders, verify grouping
  - `conflict_warning_test.dart`: render with mock conflict, verify three options
  - `voice_input_overlay_test.dart`: render with FakeSpeechBridge, verify transcript streaming
  - `home_screen_test.dart`: render with mock providers, verify empty/grouped states

**Files / directories:** `test/ui/widgets/`

**Requirements:** KATALA_SPEC_V3.md §38.2 (widget tests).

**Architecture:** ARCHITECTURE.md §23.3.

**Acceptance criteria:**
- All widget tests pass
- Tests use `ProviderScope.overrides` with fake services
- Each key widget has at least one test

**Tests:** This task creates the tests.

**Do not:**
- Test NLP logic in widget tests (that's unit test territory)
- Use real database in widget tests

---

### TASK-123 — State Machine & Conflict Detection Unit Tests

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-014, TASK-015

**Purpose:** Ensure comprehensive unit test coverage for state machine transitions and conflict detection.

**Scope:**
- `state_machine_test.dart`: verify every transition in §15.2, verify all guards, verify terminal state behavior, verify version increment
- `conflict_detector_test.dart`: verify ±15 min detection, verify alternative time suggestion, verify edge cases (DST transitions, midnight boundary, empty list, single reminder at same time)

**Files / directories:** `test/domain/state_machine_test.dart`, `test/domain/conflict_detector_test.dart`

**Requirements:** KATALA_SPEC_V3.md §15, §18.

**Architecture:** ARCHITECTURE.md §23.2.

**Acceptance criteria:**
- Every state machine transition has a test
- Every guard has a test
- Conflict detector edge cases all pass
- 100% coverage on state machine and conflict detector

**Tests:** This task creates/expands the tests.

**Do not:**
- Skip SNOOZED → SNOOZED (re-snooze) test
- Skip the `snooze_count < 10` guard test

---

### TASK-124 — Performance Profiling

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-100

**Purpose:** Profile the voice-to-persist flow to ensure it meets the < 5 second target.

**Scope:**
- Measure each stage of the flow:
  1. STT: time from mic tap to final transcript
  2. NLP: pipeline parse time
  3. Contact resolution time
  4. Database transaction time
  5. Notification scheduling time
  6. Total: mic tap to persisted
- Target: total < 5 seconds on mid-range devices (iPhone SE 2020, Samsung A54 equivalent)
- If any stage exceeds budget: log as performance issue
- Database query optimization: ensure indices on `scheduled_time_utc`, `status`, `reminder_id`
- Drift reactive stream performance: verify timeline updates in < 100ms

**Files / directories:** Performance profiling script/notes in `test/performance/`

**Requirements:** KATALA_SPEC_V3.md G1.

**Architecture:** ARCHITECTURE.md §25 (observability).

**Acceptance criteria:**
- Voice-to-persisted < 5 seconds on mid-range device
- NLP pipeline < 100ms
- Database insert < 50ms
- Timeline update < 100ms

**Tests:** Manual profiling with device-side timing.

**Do not:**
- Add performance-measurement dependencies
- Ship debug timing logs in release builds

---

### TASK-125 — Network Traffic Audit Setup

**Phase:** 11 — Integration, Testing & Polish
**Priority:** P1
**Depends on:** TASK-100

**Purpose:** Set up the CI network traffic audit to verify zero network requests from Katala code.

**Scope:**
- CI step (manual or semi-automated):
  1. Build release IPA/APK
  2. Install on device/simulator with network proxy (mitmproxy)
  3. Run all MVP use cases (create reminder, complete, snooze, delete, open URL, call)
  4. Assert: zero HTTP/HTTPS requests from Katala process
  5. Allowlist: `tel:` and `https://` user-initiated actions are excluded (user tapped "Call" or "Open Link")
  6. Fail build if any unexpected requests detected
- Document the audit procedure for manual verification

**Files / directories:** `test/network_audit/` (mitmproxy script + instructions)

**Requirements:** KATALA_SPEC_V3.md §30.3, §38.5, AC-21.

**Architecture:** ARCHITECTURE.md §21.7.

**Implementation notes:**
- Reference ARCHITECTURE_CONSISTENCY_REVIEW.md L7: `mitmproxy --scripts` with an assertion script. Alternative: check no sockets opened using `lsof` equivalent.

**Acceptance criteria:**
- Network audit script exists
- Audit passes on release build
- No unexpected network connections detected
- Procedure is documented for manual runs

**Tests:** Manual: run the audit.

**Do not:**
- Block CI on network audit if mitmproxy is not available in CI (make it a manual gate)
- Skip this entirely — it's the verification of the "zero network" privacy guarantee

---

## Phase 12 — Build, Release & Final Gate

---

### TASK-130 — iOS Signing, Entitlements & Release Configuration

**Phase:** 12 — Build, Release & Final Gate
**Priority:** P1
**Depends on:** TASK-004, TASK-066

**Purpose:** Finalize iOS release configuration: signing, entitlements, and App Store compliance.

**Scope:**
- Verify both targets (main app + extension) have correct App Group entitlements
- Configure release code signing with Apple Developer account
- Verify `Info.plist` privacy descriptions are accurate and complete
- Confirm `NSFileProtectionCompleteUnlessOpen` for database directory
- Verify notification sound files (.caf) are in the bundle
- Verify Inter font files are bundled
- Test archive and export IPA
- Privacy nutrition labels for App Store
- No required `Info.plist` keys are missing

**Files / directories:** `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, Xcode project settings

**Requirements:** KATALA_SPEC_V3.md §37.5.

**Architecture:** ARCHITECTURE.md §24.2.

**Acceptance criteria:**
- Release IPA builds and archives successfully
- Both targets have correct entitlements
- All privacy descriptions are present
- App Store compliance check passes

**Tests:** Manual: archive → validate → export.

**Do not:**
- Ship debug builds as release
- Forget the extension target's entitlements

---

### TASK-131 — Android Signing, Manifest & Release Configuration

**Phase:** 12 — Build, Release & Final Gate
**Priority:** P1
**Depends on:** TASK-005, TASK-077

**Purpose:** Finalize Android release configuration: signing, manifest, and Play Store compliance.

**Scope:**
- Create/configure release keystore
- Configure `build.gradle` for release signing
- Verify all manifest permissions are declared
- Verify receivers are registered correctly
- Enable ProGuard/R8 for release builds
- Verify notification sound files (.ogg) are in assets
- Verify Inter font files are bundled
- Test release APK/AAB build
- Play Store data safety form preparation

**Files / directories:** `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, keystore

**Requirements:** KATALA_SPEC_V3.md §37.6.

**Architecture:** ARCHITECTURE.md §24.3.

**Acceptance criteria:**
- Release APK/AAB builds and signs successfully
- All permissions declared
- ProGuard/R8 enabled without obfuscation issues
- Play Store compliance check passes

**Tests:** Manual: `flutter build apk --release` → install → smoke test.

**Do not:**
- Commit keystore or passwords to repository
- Disable ProGuard for release

---

### TASK-132 — Final Privacy Verification

**Phase:** 12 — Build, Release & Final Gate
**Priority:** P0
**Depends on:** TASK-125, TASK-130, TASK-131

**Purpose:** Run the complete privacy checklist against the release builds.

**Scope:**
- Verify:
  - Zero network requests from Katala code (network audit)
  - No analytics SDKs in dependency tree
  - No crash reporting SDKs
  - No advertising SDKs
  - No user accounts or authentication
  - On-device STT enforcement on both platforms
  - Audio is never stored to disk
  - Font is bundled, not downloaded
  - Database excluded from backups by default
  - No logging of personal data in release builds
  - All permissions have usage descriptions
  - Contacts permission requested only contextually

**Files / directories:** All (audit pass)

**Requirements:** KATALA_SPEC_V3.md §30, AC-21 through AC-24.

**Architecture:** ARCHITECTURE.md §21.

**Acceptance criteria:**
- All 12 privacy checks pass
- Network audit shows zero requests
- Dependency audit shows only whitelisted packages

**Tests:** Manual audit + network traffic audit.

**Do not:**
- Skip any check
- Assume compliance without verification

---

### TASK-133 — MVP Final Gate Checklist

**Phase:** 12 — Build, Release & Final Gate
**Priority:** P0
**Depends on:** All previous tasks

**Purpose:** Run the complete MVP acceptance checklist as defined by KATALA_SPEC_V3.md §39.

**Scope:**

**Functional:**
- [ ] AC-1: Voice-to-persist < 5 seconds
- [ ] AC-2: Live transcript during speech
- [ ] AC-3: Explicit Save required
- [ ] AC-4: STT unavailable → text input primary
- [ ] AC-5-9: NLP acceptance criteria (all 5)
- [ ] AC-10-14: Notification acceptance criteria (all 5)
- [ ] AC-15-17: Reconciliation acceptance criteria (all 3)
- [ ] AC-18-20: Database acceptance criteria (all 3)
- [ ] AC-21-24: Privacy acceptance criteria (all 4)
- [ ] AC-25-27: Conflict detection acceptance criteria (all 3)
- [ ] AC-28-31: Reliability acceptance criteria (all 4)

**Architecture:**
- [ ] Layer dependency rules not violated (§4)
- [ ] Domain has zero platform imports
- [ ] Data layer does NOT call Platform Bridges
- [ ] NLP is deterministic (corpus 100% pass)
- [ ] Business logic identical on iOS and Android

**Offline:**
- [ ] All MVP features work in airplane mode
- [ ] STT works without internet

**Platform:**
- [ ] iOS: notification actions work while app killed
- [ ] iOS: App Group shared container works
- [ ] iOS: 64-notification limit handled correctly
- [ ] Android: BOOT_COMPLETED reschedules alarms
- [ ] Android: Force-stop recovery works
- [ ] Android: OEM reliability guidance present

**Testing:**
- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] All integration tests pass
- [ ] NLP corpus 100% pass
- [ ] Network traffic audit passes
- [ ] Device tests pass on iOS and Android

**Build:**
- [ ] Release IPA builds
- [ ] Release APK/AAB builds
- [ ] CI passes (analyze, test, build)

**Privacy:**
- [ ] Zero network requests
- [ ] On-device STT enforced
- [ ] No analytics/crash reporting
- [ ] Database excluded from backups by default
- [ ] All permissions have usage descriptions

**Files / directories:** This is a checklist, not code.

**Acceptance criteria:**
- Every checkbox is ticked
- Any unticked item has a documented reason and plan

**Do not:**
- Ship with unticked checklist items
- Mark items as complete without verification

---

## Dependency Graph

```
Phase 0 (Project Foundation)
TASK-001 (Project scaffold)
  ├── TASK-002 (Dependencies)
  ├── TASK-003 (Linting/CI)
  ├── TASK-004 (iOS config)
  ├── TASK-005 (Android config)
  └── TASK-006 (Test infra)
        │
Phase 1 (Domain Foundation)
TASK-010 (Enums)
  ├── TASK-011 (Clock)
  ├── TASK-012 (Entities) ← TASK-010
  └── TASK-013 (Errors)
        ├── TASK-014 (State Machine) ← TASK-010, TASK-012, TASK-013
        └── TASK-015 (Conflict Detection) ← TASK-012
              │
Phase 2 (Persistence)
TASK-020 (Drift Schema) ← TASK-010, TASK-012
  ├── TASK-021 (Repository) ← TASK-020, TASK-012, TASK-013
  ├── TASK-022 (Migrations) ← TASK-020
  ├── TASK-023 (Optimistic Locking) ← TASK-021
  └── TASK-024 (Integrity Check) ← TASK-021
        │
Phase 3 (NLP) — can run in parallel with Phase 2
TASK-030 (Pipeline Orchestrator) ← TASK-011, TASK-012
  ├── TASK-031 (Pre-Processor) ← TASK-030
  ├── TASK-032 (Intent Detector) ← TASK-031
  ├── TASK-033 (Entity Extractor) ← TASK-032
  ├── TASK-034 (Temporal Resolver) ← TASK-033, TASK-011
  ├── TASK-035 (Validator) ← TASK-034, TASK-012
  └── TASK-036 (Corpus) ← TASK-030 through TASK-035
        │
Phase 4 (Bridge Interfaces) — can run in parallel with Phases 2, 3
TASK-040 (SpeechBridge) ← TASK-010, TASK-013
TASK-041 (NotificationBridge) ← TASK-012, TASK-013
TASK-042 (ContactBridge) ← TASK-012
TASK-043 (ActionBridge)
TASK-044 (Permission Abstraction)
        │
Phase 5 (Application Layer)
TASK-050 (CreateReminder) ← TASK-021, TASK-030, TASK-040, TASK-041, TASK-042, TASK-015 (HEAVY)
  ├── TASK-051 (Complete) ← TASK-014, TASK-021, TASK-041
  ├── TASK-052 (Snooze) ← TASK-014, TASK-021, TASK-041
  ├── TASK-053 (Delete) ← TASK-021, TASK-041
  ├── TASK-054 (Edit) ← TASK-021, TASK-041
  ├── TASK-055 (HandleAction) ← TASK-051, TASK-052, TASK-043
  ├── TASK-056 (Reconcile) ← TASK-021, TASK-041
  ├── TASK-057 (ResolveContacts) ← TASK-042
  ├── TASK-058 (BackgroundLocator) ← TASK-021, TASK-041, TASK-043
  └── TASK-059 (Providers) ← TASK-050 through TASK-057
        │
        ├──→ Phase 6 (iOS Native) ──── can run in PARALLEL with Phase 7
        │    TASK-060 (iOS Speech) ← TASK-040, TASK-004
        │    TASK-061 (iOS Notif) ← TASK-041, TASK-004
        │    TASK-062 (iOS Contact) ← TASK-042, TASK-004
        │    TASK-063 (iOS Action) ← TASK-043, TASK-004
        │    TASK-064 (iOS Extension) ← TASK-004, TASK-020
        │    TASK-065 (iOS BGRefresh) ← TASK-061
        │    TASK-066 (iOS AppDelegate) ← TASK-060 through TASK-065
        │
        └──→ Phase 7 (Android Native) ──── can run in PARALLEL with Phase 6
             TASK-070 (Android Speech) ← TASK-040, TASK-005
             TASK-071 (Android Notif) ← TASK-041, TASK-005
             TASK-072 (Android Contact) ← TASK-042, TASK-005
             TASK-073 (Android Action) ← TASK-043, TASK-005
             TASK-074 (BootReceiver) ← TASK-005, TASK-071
             TASK-075 (WorkManager) ← TASK-071
             TASK-076 (ActionReceiver) ← TASK-005
             TASK-077 (MainActivity) ← TASK-070 through TASK-076
             TASK-078 (OEM Reliability) ← TASK-071, TASK-074, TASK-075
             │
             └──→ Phase 8 (UI) ──── can start after Phase 5
                  TASK-080 (Theme) ← TASK-001
                  TASK-081 (App Shell) ← TASK-080, TASK-059
                    ├── TASK-082 (Home Screen) ← TASK-081, TASK-059
                    ├── TASK-083 (Mic/Voice) ← TASK-082, TASK-040
                    ├── TASK-084 (Confirmation) ← TASK-050
                    ├── TASK-085 (Clarification) ← TASK-050
                    ├── TASK-086 (Conflict) ← TASK-015, TASK-084
                    ├── TASK-087 (Detail) ← TASK-081
                    ├── TASK-088 (Text Input) ← TASK-083
                    ├── TASK-089 (Settings) ← TASK-081
                    ├── TASK-090 (Onboarding) ← TASK-081
                    ├── TASK-091 (Swipes/Undo) ← TASK-082
                    ├── TASK-092 (Empty/Error) ← TASK-082
                    └── TASK-093 (Accessibility) ← TASK-082 through TASK-092
                          │
                          └──→ Phase 9 (First Vertical Slice)
                               TASK-100 (E2E Integration) ← TASK-050, TASK-060/070, TASK-082 through TASK-084
                                 ├── TASK-101 (iOS Device Validation) ← TASK-100, TASK-064
                                 └── TASK-102 (Android Device Validation) ← TASK-100, TASK-074, TASK-076
                                       │
                                       └──→ Phase 10 (Notification Hardening)
                                            TASK-110 (Category Coordination) ← TASK-061, TASK-071, TASK-041
                                            TASK-111 (ID Mapping) ← TASK-061, TASK-071
                                            TASK-112 (Stale Cleanup) ← TASK-056, TASK-111
                                            TASK-113 (Missed Detection) ← TASK-056
                                                  │
                                                  └──→ Phase 11 (Integration & Testing)
                                                       TASK-120 (NLP Pass) ← TASK-036, TASK-050
                                                       TASK-121 (Use Case Tests) ← TASK-050 through TASK-057
                                                       TASK-122 (Widget Tests) ← TASK-082 through TASK-092
                                                       TASK-123 (State Machine Tests) ← TASK-014, TASK-015
                                                       TASK-124 (Performance) ← TASK-100
                                                       TASK-125 (Network Audit) ← TASK-100
                                                             │
                                                             └──→ Phase 12 (Build & Release)
                                                                  TASK-130 (iOS Release) ← TASK-004, TASK-066
                                                                  TASK-131 (Android Release) ← TASK-005, TASK-077
                                                                  TASK-132 (Privacy Verification) ← TASK-125, TASK-130, TASK-131
                                                                  TASK-133 (MVP Gate) ← ALL
```

**Parallelizable groups:**
- Phase 2 (Persistence) and Phase 3 (NLP) can run in parallel
- Phase 4 (Bridge Interfaces) can run in parallel with Phases 2, 3
- Phase 6 (iOS) and Phase 7 (Android) can run in parallel
- Phase 8 (UI) can start once Phase 5 completes, overlapping with Phases 6, 7
- Tasks within Phase 5: TASK-051 through TASK-057 can run in parallel after TASK-050
- Tasks within Phase 8: TASK-082 through TASK-092 can largely run in parallel after TASK-081

---

## Milestones

### M0 — Project Boots
**Tasks:** TASK-001 through TASK-006
**Definition of done:**
- `flutter create` succeeds
- `flutter analyze` passes with zero errors
- `flutter test` passes (even with zero tests)
- `flutter build apk --debug` succeeds
- Xcode project opens without errors
- All directories match ARCHITECTURE.md §3

---

### M1 — Domain + Persistence Complete
**Tasks:** TASK-010 through TASK-024
**Definition of done:**
- All domain entities, enums, and value objects compile
- State machine passes all transition tests
- Conflict detector passes all tests
- Drift schema generates cleanly
- Repository CRUD operations pass tests
- In-memory database tests pass
- Migrations work from version 1
- Integrity check runs on startup
- `Result<T, E>` type is used across the domain layer

---

### M2 — NLP Accepts Deterministic Corpus
**Tasks:** TASK-030 through TASK-036, TASK-120
**Definition of done:**
- All 5 NLP stages implemented
- Pipeline produces `ParsedReminder` for any input
- Full test corpus (50 English + 25 Taglish + 25 edge cases) passes 100%
- NLP is deterministic (same input + same Clock = same output)
- NLP has zero platform imports
- Contact names are output as strings (not resolved)

---

### M3 — First End-to-End Reminder Works on Device
**Tasks:** TASK-040 through TASK-059, TASK-060 through TASK-078 (at least one platform), TASK-080 through TASK-091, TASK-100 through TASK-102
**Definition of done:**
- Voice → STT → NLP → Confirmation → Save → DB → Notification → Timeline
- Full flow works on at least one real device (iOS or Android)
- Voice-to-persisted < 5 seconds
- Notification fires at scheduled time
- Notification action (Done/Snooze) works while app is backgrounded
- Timeline reflects saved reminders

---

### M4 — Notification Actions Work (Both Platforms)
**Tasks:** TASK-110 through TASK-113, TASK-064, TASK-076 (completion)
**Definition of done:**
- iOS: notification action while app killed → state transition persists
- Android: notification action while app backgrounded → state transition persists
- All 4 notification categories work with correct action buttons
- Reconciliation runs on every foreground entry
- Missed notifications are detected and marked
- Stale notifications are cleaned up
- Duplicate notifications are prevented

---

### M5 — iOS Reliability Complete
**Tasks:** All Phase 6 tasks complete + TASK-101
**Definition of done:**
- All 7 iOS device tests from TASK-101 pass
- Extension handles actions in < 1 second
- Cross-process DB access works without corruption
- 64-notification limit handled (priority queue)
- BGAppRefreshTask registered (best-effort)

---

### M6 — Android Reliability Complete
**Tasks:** All Phase 7 tasks complete + TASK-102
**Definition of done:**
- All 7 Android device tests from TASK-102 pass
- BootReceiver re-schedules alarms within 10 seconds
- Force-stop recovery detected on next foreground
- OEM reliability status shows accurate data
- Manufacturer-specific guidance is present for top OEMs

---

### M7 — MVP Complete
**Tasks:** All tasks through TASK-133
**Definition of done:**
- Every checkbox in TASK-133 (MVP Final Gate) is ticked
- Release builds for iOS and Android are ready
- Network audit passes (zero requests)
- All tests pass (unit, widget, integration, NLP corpus)
- Privacy verification passes all 12 checks
- Device tests pass on both platforms

---

## MVP Final Gate Checklist

This mirrors TASK-133. It is repeated here as the canonical completion checklist.

### Functional Requirements (from KATALA_SPEC_V3.md §39)
- [ ] AC-1: Voice-to-reminder < 5 seconds
- [ ] AC-2: Live transcript during speech
- [ ] AC-3: Explicit Save required (no auto-save)
- [ ] AC-4: STT unavailable → text input primary
- [ ] AC-5-AC-9: All NLP acceptance criteria
- [ ] AC-10-AC-14: All notification acceptance criteria
- [ ] AC-15-AC-17: All reconciliation acceptance criteria
- [ ] AC-18-AC-20: All database acceptance criteria
- [ ] AC-21-AC-24: All privacy acceptance criteria
- [ ] AC-25-AC-27: All conflict detection acceptance criteria
- [ ] AC-28-AC-31: All reliability acceptance criteria

### Architecture Requirements
- [ ] Layer dependency rules enforced (§4)
- [ ] Domain has zero platform imports
- [ ] Data layer does NOT call Platform Bridges
- [ ] Business logic identical on iOS and Android
- [ ] Background service locator used in background contexts (not Riverpod)

### Privacy Requirements
- [ ] Zero network requests from Katala code
- [ ] On-device STT enforced on both platforms
- [ ] Audio never stored to disk
- [ ] No analytics, crash reporting, or advertising SDKs
- [ ] No user accounts or authentication
- [ ] Font bundled, not downloaded
- [ ] Database excluded from backups by default
- [ ] All permissions have usage descriptions
- [ ] Release builds strip debug logging of personal data

### Platform Requirements
#### iOS
- [ ] Notification actions work while app killed (extension)
- [ ] App Group shared container works
- [ ] 64-notification limit handled (priority queue)
- [ ] `requiresOnDeviceRecognition = true` enforced
- [ ] BGAppRefreshTask registered
- [ ] WAL mode enabled
- [ ] `NSFileProtectionCompleteUnlessOpen` configured

#### Android
- [ ] BOOT_COMPLETED reschedules alarms
- [ ] Force-stop recovery works on next foreground
- [ ] `EXTRA_PREFER_OFFLINE` set on Android 10-12
- [ ] `createOnDeviceSpeechRecognizer` used on Android 13+
- [ ] `setExactAndAllowWhileIdle` + `setAlarmClock` used
- [ ] OEM reliability status visible in Settings
- [ ] Manufacturer-specific guidance present
- [ ] `goAsync()` used in BootReceiver

### Testing Requirements
- [ ] All unit tests pass (flutter test)
- [ ] All widget tests pass
- [ ] All integration tests pass
- [ ] NLP corpus 100% pass (50 English + 25 Taglish + 25 edge cases)
- [ ] State machine: all transitions tested
- [ ] Conflict detector: all edge cases tested
- [ ] Optimistic locking tested
- [ ] Network traffic audit passes
- [ ] iOS device tests pass (7 tests)
- [ ] Android device tests pass (7 tests)

### Build Requirements
- [ ] Release IPA builds and archives
- [ ] Release APK/AAB builds and signs
- [ ] CI passes: analyze → test → build
- [ ] `flutter analyze` zero errors
- [ ] `dart format` compliant
- [ ] `pubspec.lock` committed

---

## MEDIUM Findings Resolution

From ARCHITECTURE_CONSISTENCY_REVIEW.md:

| Finding | Resolution | Reference |
|---------|-----------|-----------|
| **M1:** Contact preview vs. save-time resolution inconsistency | **IMPLEMENTATION NOTE** in TASK-050 (CreateReminderUseCase): Resolve at save time. UI preview uses ResolveContactsUseCase separately. CreateReminderUseCase re-resolves at save for consistency. | TASK-050 |
| **M2:** Background callback initialization timing not quantified | **IMPLEMENTATION NOTE** in TASK-058 (BackgroundServiceLocator): Target < 2 seconds for DB open + use case execution. First-run may be slower (Drift schema creation). If background callback killed mid-operation, next foreground reconciliation handles it. | TASK-058 |
| **M3:** Category dual-registration coordination fragile | **IMPLEMENT AS TASK** → TASK-110: explicit integration test for category coordination between native bridge and flutter_local_notifications. | TASK-110 |
| **M4:** iOS extension schema migration synchronization not enforced | **IMPLEMENTATION NOTE** in TASK-022 (Migrations) + TASK-064 (Extension): When Drift schema version increments, extension SQL queries MUST be reviewed and updated in the same commit. CI check: compare extension's expected schema version to main app's. Extension refuses to run if schema version > supported. | TASK-022, TASK-064 |

---

## LOW Findings Resolution

From ARCHITECTURE_CONSISTENCY_REVIEW.md:

| Finding | Resolution | Reference |
|---------|-----------|-----------|
| **L1:** `ValidatedReminder` vs `ContactRef` vs `ResolvedContact` naming | **CODE STANDARD:** Use `ResolvedContact` universally (matches SPEC §34.3). Architecture's `ContactRef` is the same type — use `ResolvedContact`. | TASK-012 |
| **L2:** Android BOOT_COMPLETED query limit | **IMPLEMENTATION NOTE** in TASK-074: Query limited to nearest 60 PENDING reminders per the 10-second `goAsync()` budget. | TASK-074 |
| **L3:** `flutter_local_notifications` role partially superseded | **IMPLEMENTATION NOTE** in TASK-041 + TASK-110: Clarify division: native bridge handles scheduling + categories; flutter_local_notifications handles display + action callbacks. | TASK-041, TASK-110 |
| **L4:** PlatformChannel registration sequence not specified | **IMPLEMENTATION NOTE** in TASK-066 + TASK-077: Channels auto-registered by Flutter engine. Native implementations use `FlutterMethodChannel` (iOS) / `MethodChannel` (Android). | TASK-066, TASK-077 |
| **L5:** Silence detection implementation not specified | **IMPLEMENTATION NOTE** in TASK-060 + TASK-070: iOS: timer resets on partial results. Android: rely on built-in end-of-speech; timer fallback. | TASK-060, TASK-070 |
| **L6:** `app_metadata` table not in SPEC data model | **IMPLEMENTATION NOTE** in TASK-020: `app_metadata` is required by architecture for `last_reconciled_at` and `schema_version`. Store in database (not shared_preferences) so iOS extension can access. | TASK-020 |
| **L7:** CI network traffic audit tooling not specified | **IMPLEMENTATION NOTE** in TASK-125: `mitmproxy --scripts` or simpler `lsof` check. Manual gate if CI proxy not available. | TASK-125 |

---

## AI Coding-Agent Risk Mitigations

From ARCHITECTURE_CONSISTENCY_REVIEW.md "AI Agent Risk (Top 5)":

| Risk | Mitigation |
|------|-----------|
| **1. NLP extraction order violation** | TASK-030 documents stage order as CRITICAL. TASK-035 tests verify correct ordering. |
| **2. iOS extension uses wrong database path** | TASK-064 specifies App Group shared container path. TASK-004 pre-configures App Group entitlements. |
| **3. Category dual-registration conflict** | TASK-110 is a dedicated integration test for category coordination. TASK-041 documents division of labor. |
| **4. iOS 64-limit append instead of replace** | TASK-061 explicitly requires priority-queue algorithm with replacement semantics. |
| **5. Optimistic locking retry without re-read** | TASK-023 requires re-read before retry. ARCHITECTURE.md §8.2 pseudocode shows correct pattern. |

---

*End of TASKS.md*
