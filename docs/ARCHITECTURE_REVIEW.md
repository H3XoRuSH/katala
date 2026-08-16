# ARCHITECTURE_REVIEW.md — Katala Architecture Readiness Audit

**Review date:** 2026-08-10
**Documents reviewed:** KATALA_SPEC_V2.md (v2.0.0)
**Reviewer stance:** Principal Mobile Architect, Flutter Architect, iOS/Android Platform Engineer, Reliability Engineer

**Verdict:** NEEDS MAJOR REVISION

---

This review answers:

> "Can a competent engineering team or AI coding agent take this specification and build the defined MVP reliably on real iOS and Android devices without making major architectural decisions on its own?"

**The answer is NO — not yet.** The specification has improved substantially since V1, but several architectural gaps remain that would force an implementer to invent critical infrastructure without guidance. Three of these are severe enough to block implementation.

---

# CRITICAL ARCHITECTURAL GAPS (Top First)

## [CRITICAL] C1: iOS Notification Extension Database Access Is Architecturally Undefined

**Category:** iOS / Database / Notifications

**Location:** §19.5 (iOS: "Background action handling"), §28.4 (iOS: "Shared App Group container for notification extension access"), §19.3 (Notification Actions table)

**Problem:** The spec states that notification actions (Done, Snooze) "MUST work without opening the app" (FR-8). On iOS, this requires a `UNNotificationServiceExtension` or `UNNotificationContentExtension` that runs in a separate process. That extension must access the same SQLite database to update reminder state. The spec mentions "Shared App Group container for SQLite access" in one line (§28.4) but never defines:

1. **How Drift operates across an App Group container.** Drift assumes a single-process model. Two processes (main app + notification extension) accessing the same SQLite file concurrently requires WAL mode + careful locking. Drift does not natively handle cross-process access.
2. **How the notification extension discovers and initializes the database.** Extensions have a different lifecycle — they are launched on-demand, run briefly, and are killed. There is no "app startup" sequence for them.
3. **How Riverpod/DI works in the extension.** The extension is a separate binary. The spec's Riverpod-based dependency injection does not automatically carry over.
4. **How the extension performs the same optimistic-locking state transitions** without access to the full application layer.
5. **What happens when the extension is updating the database while the main app is also running.** Both processes can write concurrently. The spec's optimistic locking (§15.4) handles logical races but does not address SQLite-level `SQLITE_BUSY` errors from cross-process contention.

**Why it matters:** Without this defined, the implementer must either:
- (a) Build a completely separate data access layer for the extension, duplicating domain logic and creating maintenance risk.
- (b) Skip background notification actions on iOS entirely (violating FR-8).
- (c) Use `UNNotificationAction` with `UNNotificationActionOption.foreground` which opens the app (violating the "without opening the app" requirement).

**Failure scenario:**
1. User receives a notification while app is killed.
2. User taps "✓ Done" on the notification.
3. iOS launches the notification extension.
4. Extension tries to open the SQLite database but the file is in the main app's sandbox, not the shared container.
5. Extension crashes silently. Notification is dismissed but reminder remains PENDING.
6. User opens Katala later, sees the reminder still pending, and loses trust.

**Recommendation:** Add a dedicated section defining the iOS notification extension architecture:
- Specify WAL mode for SQLite.
- Define a lightweight data access path for the extension (raw SQLite via `sqflite` or a minimal Drift setup using the shared container path).
- Define a `NotificationActionHandler` interface that both the main app and extension can use, with its own minimal dependency tree that excludes Riverpod, UI, and heavy services.
- Document that the extension must duplicate a subset of domain logic (state machine transitions) and that this is an accepted maintenance trade-off.
- Add an integration test that verifies cross-process database access.

**Implementation impact:** HIGH — requires significant iOS-specific infrastructure before notification actions work.

---

## [CRITICAL] C2: Android Notification Reliability Is Undefined for Force-Stop and OEM Kill

**Category:** Android / Notifications / Lifecycle

**Location:** §19.5 (Android), §31.5 (Device Reboot), §19.6 (Notification Behavior Matrix)

**Problem:** The spec correctly identifies that Android alarms are impermanent and that BOOT_COMPLETED is not guaranteed. However, the spec then defines a recovery strategy that has a critical architectural gap:

1. **BOOT_COMPLETED receiver** (§31.5): "On receive: query all PENDING reminders, reschedule all alarms." But on Android 8+, the app cannot start a background service from a BOOT_COMPLETED receiver without becoming a foreground service within ~5 seconds. Rescheduling potentially hundreds of alarms via AlarmManager within 5 seconds is feasible, but Drift database initialization (reading the schema, running migrations, opening the file) takes time. The receiver may be killed before it finishes.

2. **WorkManager periodic task** (§19.5): "Schedule a periodic DailyReconciliationWorker." But WorkManager itself is subject to Doze, battery optimization, and OEM restrictions. On devices from Xiaomi, OPPO, Huawei, and other manufacturers common in the Philippines, WorkManager periodic tasks may be:
   - Delayed by hours or days
   - Run only when the device is charging
   - Not run at all until the user opens the app

3. **Force-stop handling** (§19.6, §38 change #26): The spec acknowledges that "Notification actions on Android may not survive force-stop" but doesn't define the architectural boundary. After force-stop on most Android devices, ALL alarms are cancelled AND the BOOT_COMPLETED receiver is disabled until the user manually re-opens the app. The spec's reconciliation is described as "on next app open" but there is no defined mechanism to detect how many reminders were missed during the gap.

4. **No persistent "missed notification" detection.** There is no flag or counter that tracks whether a notification actually fired. The `Trigger.notification_scheduled` field (§14.2) tracks scheduling state, not delivery confirmation. The app cannot distinguish between "notification fired but user ignored it" and "notification was never scheduled because alarms were cleared."

**Why it matters:** On Android devices common in the Philippine market (where price-sensitive users favor Xiaomi, OPPO, realme, and Samsung's lower-end models), the aggressive battery optimization means Katala's notification reliability could be as low as "fires only if the user opened the app in the last few hours." For a reminder app, this is an existential reliability problem.

**Failure scenario:**
1. User creates reminder for "Call dentist tomorrow at 10 AM."
2. User force-stops Katala (or device automatically kills it for battery).
3. 10 AM arrives. No notification fires.
4. User misses the dentist appointment.
5. User opens Katala at 6 PM. Reconciliation runs. Reminder shows as overdue. Too late.

**Recommendation:**
- Add a `last_reconciled_at` timestamp to the app's internal state, persisted to UserPreference or a dedicated metadata table.
- On app foreground, compare `last_reconciled_at` to `now`. If the gap exceeds a threshold (e.g., 6 hours), show a banner: "Katala was inactive for [duration]. [X] reminders may have been missed." List the overdue reminders that were scheduled during the gap.
- Define a foreground service option (gated behind a user-facing setting, off by default) that keeps a persistent notification: "Katala is keeping your reminders active." This is the only reliable way to prevent Android from killing the app on aggressive-OEM devices. Document this as an optional power-user feature with a battery impact disclaimer.
- Add a `missed_delivery_estimated` boolean to Trigger, set during reconciliation when a reminder's scheduled_time is in the past but fired_at is null and the app was known to be inactive. This enables the UI to distinguish "probably missed" from "user ignored."
- Define the BOOT_COMPLETED receiver implementation with explicit timing: the receiver must complete (query + reschedule) within 5 seconds, or use `goAsync()` / a WorkManager OneTimeWorkRequest enqueued from the receiver for longer operations.

**Implementation impact:** HIGH — adds Android-specific infrastructure and a new reliability contract.

---

## [CRITICAL] C3: `flutter_local_notifications` vs. Spec-Defined Notification Behavior Has Unexplored Gaps

**Category:** Flutter / Notifications / Dependencies

**Location:** §34.2 (Dependency Whitelist), §19.5 (Platform-Specific Implementation), §19.3 (Notification Actions)

**Problem:** The spec mandates `flutter_local_notifications` (§34.2) for notifications but also specifies behaviors that this package may not support directly, or may support differently on each platform:

1. **Background action handling without opening the app** (§19.3, action_done, action_snooze): `flutter_local_notifications` uses platform channels to relay notification action taps back to Dart. On iOS, this requires the `didReceiveNotificationResponse` callback — but this fires in the MAIN APP process, NOT in a notification extension. If the app is terminated, iOS launches the app in the background to handle the action. The package does provide a `onDidReceiveNotificationResponse` callback that works in this scenario, BUT the Dart code must initialize Riverpod, Drift, and the full application layer within the brief background execution window (~5 seconds on iOS 16+, even less on older versions). This may not be enough time for Drift migration checks + schema validation. On Android, background actions work via `BroadcastReceiver` with `goAsync()`, but `flutter_local_notifications` abstracts this behind its own plugin — the spec needs to verify that the plugin passes `EXTRA_PREFER_OFFLINE` or equivalent for the receiver to function.

2. **iOS notification categories** (§19.1): `flutter_local_notifications` supports category registration, but the categories must be configured BEFORE any notifications are scheduled. The spec says "Configure notification categories at app init" (§29.2: `configureCategories()`), which is correct. However, if categories change between app versions, already-scheduled notifications reference old category definitions. This matters for migration.

3. **Custom notification sounds** (§23.7): On iOS, custom sounds must be in the app bundle (.caf format) or in the shared group container. `flutter_local_notifications` can reference bundled sounds. On Android, custom sounds are in `res/raw/`. The spec says ".caf (iOS) / .ogg (Android)" but `flutter_local_notifications` documentation primarily shows `.aiff`, `.wav`, or `.caf` for iOS and `.mp3`/`.ogg`/`.wav` for Android. This is minor but an AI agent may waste time on audio format debugging.

4. **The `speech_to_text` package alternative** (§34.2): The spec says "`speech_to_text` or custom native bridge — STT." The `speech_to_text` package (v6.x) does NOT expose `requiresOnDeviceRecognition` (iOS) or `EXTRA_PREFER_OFFLINE` (Android) directly. It uses the platform's default speech recognition behavior, which on iOS defaults to on-device when available but does not enforce it. On Android, it does not set `EXTRA_PREFER_OFFLINE`. **This means the spec's mandated `speech_to_text` package cannot enforce the spec's privacy requirement CC-6 ("No cloud STT").** An implementer following the spec literally would install `speech_to_text`, discover it doesn't support on-device-only enforcement, and then need to build a custom bridge — wasting the time spent on the package integration.

**Why it matters:** The dependency whitelist creates an implicit architecture contract. If the whitelisted packages cannot fulfill the spec requirements, the implementer faces a choice between deviating from the spec or building custom native code that the spec didn't anticipate.

**Failure scenario:**
1. Implementer integrates `speech_to_text` package as specified.
2. On iOS, `SFSpeechRecognizer` default behavior may send audio to Apple servers when on-device is not available.
3. Implementer misses this because the spec mandates on-device, but the package doesn't enforce it.
4. Privacy audit (AC-23) passes (no HTTP requests from Katala code), but audio is still sent to Apple via the OS speech service.
5. Privacy claim is technically violated.

**Recommendation:**
- Remove `speech_to_text` from the dependency whitelist. Replace with: "Custom native bridge for STT (mandatory). The `speech_to_text` package does not expose on-device-only enforcement and MUST NOT be used."
- Add an architectural decision record: ADR-10: "Custom STT native bridge required because no Flutter package exposes `requiresOnDeviceRecognition` (iOS) and `EXTRA_PREFER_OFFLINE` (Android) simultaneously."
- Verify `flutter_local_notifications` background action handling on both platforms with a dedicated spike/integration test that measures initialization time for Dart in the background callback.
- Document that the background Dart isolate for notification handling must initialize a minimal subset of the app (no UI, no Riverpod providers that depend on WidgetsBinding, no MaterialApp) within 3 seconds to stay under the iOS background execution limit.

**Implementation impact:** HIGH — STT requires custom native bridge from day one instead of using a package.

---

# 1. ARCHITECTURE CONSISTENCY

## [MEDIUM] A1: Application Layer Boundaries Are Undefined

**Category:** Architecture

**Location:** §28.1 (Flutter Architecture), §8.4 (Design Principle: Modularity)

**Problem:** The spec defines four layers (UI, Application, Domain, Data) plus Platform Bridges. The Domain layer has clear responsibilities: NLP pipeline, State Machine, Entity Extraction, Temporal Resolution, Contact Resolution, Confidence Scoring. The Data layer has clear responsibilities: Drift DAOs, Repository pattern.

The Application layer is listed as "ReminderService, NotificationService, SettingsService, ConflictDetector" but:
- **What is the exact responsibility of `ReminderService` vs. the repository?** If the repository handles persistence and the service handles orchestration, where does notification scheduling live? The spec says `ReminderService` is in the Application layer but notification scheduling is described in §19 and §29.2 as part of `NotificationBridge` (Platform). Who calls `NotificationBridge.schedule()` — the Application service or the Data repository?
- **Where does the create-reminder use case live?** It spans: UI (mic button) → Platform Bridge (STT) → Domain (NLP pipeline → ReminderDraft) → UI (confirmation card) → Data (persist) → Platform (schedule notification). There is no defined `CreateReminderUseCase` or equivalent orchestration class.
- **`ConflictDetector` is listed in Application layer** (§28.1) but its algorithm is purely domain logic (§18). It operates on database queries, which puts it in Data layer territory. This is a layer violation unless clarified.

**Why it matters:** Without clear Application layer boundaries, an implementer will place notification scheduling in the UI (coupled to button callbacks), in the repository (data layer doing platform work), or in a use case that doesn't exist yet. Different parts of the app will handle it differently, creating inconsistent error handling and duplicate scheduling logic.

**Recommendation:**
- Define a `CreateReminderUseCase` that orchestrates: NLP pipeline → ReminderDraft → (user confirmation) → persist → schedule notification → return result. Make this the single path for reminder creation from any input source (voice, text, manual).
- Define explicitly that `ReminderRepository.update()` is responsible ONLY for persistence (write to SQLite). The caller (Application layer or Use Case) is responsible for then calling `NotificationBridge.schedule()` or `cancel()` based on the mutation type.
- Move `ConflictDetector` to the Domain layer. The Application layer calls it and passes the result to the UI for display.

**Implementation impact:** LOW — clarification only, no structural change needed.

---

## [MEDIUM] A2: ReminderDraft Builder Couples Domain Output to Database Schema

**Category:** Architecture / Domain

**Location:** §8.1 (Pipeline Overview), §16.1 (ReminderDraft), Appendix B

**Problem:** The NLP pipeline outputs a `ReminderDraft` which maps 1:1 to the database schema fields (Appendix B). The `ReminderDraft` contains `validationErrors` and `conflicts` — concepts that are use-case concerns (the Application layer decides how to handle validation failures), not pipeline output. The pipeline should output parsed entities + confidence. The application layer should validate and detect conflicts.

Specifically:
- `ReminderDraft.validationErrors: List<ValError>` — validation is a separate stage (Semantic Validator, Stage 7) that should produce a `ValidationResult`. Whether a validation error blocks saving or triggers a clarification question is an Application layer decision.
- `ReminderDraft.conflicts: List<Conflict>` — conflict detection requires database queries (§18.2). The NLP pipeline is supposed to be pure and database-independent (§8.1: "All NLP functions MUST be pure"). Putting conflicts in the draft violates this.

**Why it matters:** The NLP pipeline cannot be unit tested independently if it requires a database for conflict detection. The purity constraint breaks.

**Recommendation:**
- Split `ReminderDraft` into two concepts:
  1. `ParsedReminder` (NLP output): title, notes, intentType, actionType, triggerTime, triggerTimezone, contactRef, phoneNumber, url, confidence, originalTranscript, normalizedTranscript, warnings (NLP-level concerns only: e.g., "no time specified").
  2. `ValidatedReminderDraft` (Application layer output): `ParsedReminder` + `validationErrors` (domain validator) + `conflicts` (domain conflict detector with injected DB). This is what the UI receives.
- Remove `validationErrors` and `conflicts` from the NLP output. Move them to the Application layer orchestration.

**Implementation impact:** LOW — renaming and re-scoping two data structures.

---

## [HIGH] A3: Contact Resolution Violates NLP Purity

**Category:** Architecture / NLP

**Location:** §8.1 ("All NLP functions MUST be pure"), §10.3 (Contact Resolution algorithm), §29.3 (ContactBridge)

**Problem:** The spec states "All NLP functions MUST be pure: same input always produces same output" (§8.1). But Contact Resolution (§10.3) requires querying the device contacts database — an inherently impure operation. The contacts DB state changes independently of the NLP input: contacts are added, deleted, or modified by the user outside of Katala.

The spec handles this by passing `contactsDB` as a parameter: `resolveContact(name, contactsDB)`. This makes the function "deterministic for a given contact DB state" but not pure — the same input at different times can produce different output as the contacts change. This is acceptable if classified correctly, but the spec's "MUST be pure" language creates a contradiction that will confuse implementers.

**Why it matters:** An implementer reading "MUST be pure" may try to make contact resolution pure by pre-loading contacts and passing them as an immutable snapshot. This would mean contacts added after app launch are invisible to NLP until the next cold start — a subtle bug.

**Recommendation:**
- Reclassify NLP functions into two categories:
  - **Pure functions** (no side effects, deterministic): Pre-Processor, Intent Detector, Entity Extractor, Temporal Resolver, Confidence Scorer.
  - **Impure but deterministic-with-respect-to-injected-state** (reads external state but same input + same DB state = same output): Contact Resolver, Semantic Validator (which calls Contact Resolver).
- Clarify that Contact Resolver receives a live (not cached) contacts database reference and queries it on each invocation.
- Add unit test guidance: test pure functions with fixed inputs, test contact resolution with a FakeContactBridge that returns pre-configured results.

**Implementation impact:** NONE — clarification only.

---

## [MEDIUM] A4: UserPreference as Stringly-Typed Key-Value Store Is a Data Integrity Risk

**Category:** Architecture / Data

**Location:** §14.2 (UserPreference), §7.5 (Data Integrity), §17 (Persistence)

**Problem:** `UserPreference` stores all preferences as JSON-encoded strings keyed by name (§14.2). This means:
- Type validation occurs at runtime, not compile time.
- A migration that changes a preference's format requires manual handling of every stored value.
- A bug that writes "ture" instead of "true" for `haptics_enabled` would silently break the preference until detected.
- No foreign keys, no constraints beyond the key-value store model.

While the spec acknowledges this is "acceptable for MVP" (the previous review said this), there are 15+ preferences with different types (int, bool, String). An enum mismatch between the key name and expected type would compile fine but fail at runtime.

**Why it matters:** This is a minor reliability risk in MVP but becomes a maintenance burden. An implementer reading the spec literally would create a generic `getPreference<T>(key)` method that does runtime type casting, which is error-prone.

**Recommendation:**
- Define a typed `UserPreferences` class with explicit fields, serialization/deserialization at the persistence boundary, and compile-time type safety.
- OR explicitly document that the key-value approach is temporary for MVP and that each preference key MUST have a corresponding typed accessor method with unit tests verifying type correctness.
- Add `value_type` column to UserPreference (string, int, bool, json) to enable runtime validation.

**Implementation impact:** LOW — can be deferred to implementation but should be noted.

---

# 2. DATA FLOW AUDIT

## Data Flow Diagram

```
[User Voice]
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 1: SpeechBridge (Platform)                     │
│   Input:  Microphone audio stream                    │
│   Output: RawTranscript (String)                     │
│   Failure: No STT → disable voice; text fallback     │
│   Async: Yes (streaming)                             │
│   Owner: Platform Bridge (iOS/Android native)        │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 2: PreProcessor (Domain, Pure)                 │
│   Input:  RawTranscript                              │
│   Output: NormalizedTranscript                       │
│   Failure: N/A (always succeeds)                     │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 3: IntentDetector (Domain, Pure)               │
│   Input:  NormalizedTranscript                       │
│   Output: DetectedIntent                             │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 4: EntityExtractor (Domain, Pure)              │
│   Input:  NormalizedTranscript                       │
│   Output: ExtractedEntities                          │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ├─────────────────────────────────────┐
    ▼                                     ▼
┌──────────────────────┐    ┌──────────────────────────┐
│ STAGE 5: Temporal    │    │ STAGE 6: ContactResolver  │
│ Resolver (Domain)    │    │ (Domain, Impure)          │
│ Input: Entities+Clock│    │ Input: Entities+ContactsDB│
│ Output: ResolvedTime │    │ Output: ContactRef        │
│ Owner: Domain NLP    │    │ Owner: Domain NLP         │
└──────────────────────┘    └──────────────────────────┘
    │                                     │
    └───────────────┬─────────────────────┘
                    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 7: SemanticValidator (Domain)                  │
│   Input:  Intent + Entities + Time + ContactRef      │
│   Output: ValidationResult (errors/warnings)         │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 8: ConfidenceScorer (Domain, Pure)             │
│   Input:  All pipeline results                       │
│   Output: ConfidenceScore + Level                    │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ STAGE 9: ReminderDraftBuilder (Domain)               │
│   Input:  All pipeline results                       │
│   Output: ReminderDraft                              │
│   Owner: Domain NLP                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ APPLICATION LAYER: CreateReminderUseCase              │
│   1. Receive ReminderDraft                           │
│   2. Detect conflicts (ConflictDetector + DB)        │
│   3. Present to UI for confirmation                  │
│   4. On [Save]:                                      │
│      a. Map ReminderDraft → Reminder+Trigger+Action  │
│      b. Persist via ReminderRepository (transaction) │
│      c. Schedule via NotificationBridge.schedule()   │
│      d. Return success/failure to UI                 │
│   Owner: Application Layer                           │
│   ⚠ GAP: No defined UseCase class. Ad hoc.          │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ DATA LAYER: ReminderRepository                       │
│   Input:  Reminder + Trigger + Action                │
│   Output: Persisted entities (with IDs)              │
│   Transaction: BEGIN → INSERT Reminder → INSERT      │
│                Trigger → INSERT Action → COMMIT      │
│   On failure: ROLLBACK, throw RepositoryException    │
│   Owner: Data Layer                                  │
│   ⚠ GAP: Repository DOES NOT schedule notifications.│
│          Caller must do it separately. What if       │
│          DB succeeds but scheduling fails?           │
└─────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ PLATFORM: NotificationBridge.schedule()              │
│   Input:  Reminder (with ID, Trigger)                │
│   Output: notification_id (int), updates             │
│           trigger.notification_scheduled = true       │
│   Failure: Sets notification_scheduled = false.      │
│            No user-visible error. Retry on next       │
│            reconciliation.                            │
│   ⚠ GAP: See finding C3 below.                      │
└─────────────────────────────────────────────────────┘

[User taps notification action]
    │
    ▼
┌─────────────────────────────────────────────────────┐
│ NOTIFICATION ACTION HANDLER                          │
│   Input:  notification_id, action_id                 │
│   1. Look up Reminder by notification_id             │
│   2. Execute state transition (optimistic locking)   │
│   3. Cancel/update notification as needed            │
│   4. Update Trigger.notification_scheduled           │
│   Owner: Platform Bridge                             │
│   ⚠ GAP: On iOS, this runs in a separate process    │
│          (notification extension). See finding C1.   │
│   ⚠ GAP: On Android, this runs in BroadcastReceiver.│
│          The receiver must complete within 10s.      │
│          Drift init + migration + query + update     │
│          may exceed this. See finding C2.            │
└─────────────────────────────────────────────────────┘
```

## Data Flow Gaps Identified

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| DF-1 | No atomicity between DB persistence and notification scheduling. If DB write succeeds but scheduling fails, `notification_scheduled = false` but there is no immediate retry. The user sees "Saved" but no notification fires until reconciliation. | HIGH | Persistence → Scheduling |
| DF-2 | Notification action handler must re-implement subset of domain logic (state machine) in the platform layer for background execution. The spec doesn't define this subset or its ownership. | CRITICAL | Notification action → State change |
| DF-3 | The NLP pipeline → ReminderDraft → Confirmation flow has no defined timeout for user confirmation. If user leaves the confirmation card open for hours and then taps [Save], the parsed time may now be in the past. | MEDIUM | Confirmation → Save |
| DF-4 | Contact snapshot at creation time vs. live resolution. The spec says "Contact data is a snapshot taken at reminder creation time" (§26.3). But if the NLP resolves a contact and the user edits the reminder 10 minutes later (changing the contact name), should the system re-resolve? Not specified. | LOW | Contact resolution → Persistence |

---

# 3. FLUTTER ARCHITECTURE AUDIT

## [MEDIUM] F1: Riverpod Scoping for Notification Callbacks Is Undefined

**Category:** Flutter / State Management

**Location:** §28.2 (State Management: Riverpod), §19.3 (Notification Actions), §31.2 (App Foreground)

**Problem:** Riverpod uses `ProviderScope` as the root of the provider tree, typically created by `ProviderScope(child: MyApp())` at the widget tree root. Notification action callbacks (both `flutter_local_notifications` Dart callbacks and native handlers that invoke Dart) execute outside the widget tree. There is no `ProviderScope` ancestor in a background callback context.

The spec says "All services are provided via Riverpod providers" (§28.2) and "UI observes state via `ref.watch()`" but never addresses how Riverpod providers are accessed from:
1. Notification action handlers (Dart callback invoked by platform when app is launched in background)
2. `BGAppRefreshTask` handler (iOS)
3. `WorkManager` periodic task (Android)
4. `BOOT_COMPLETED` receiver → Dart callback (Android)

**Why it matters:** An implementer following the Riverpod pattern will `ref.read(reminderRepositoryProvider)` in UI code. In a background callback, there is no `ref` because there is no `ProviderScope`. The implementer must either:
- Create a separate `ProviderScope` for background execution (which duplicates provider initialization)
- Use a service locator pattern alongside Riverpod (violating the "all services via Riverpod" rule)
- Access the database directly (violating the repository pattern)

**Failure scenario:**
1. App is killed. Notification fires.
2. User taps "✓ Done." iOS/Android launches the app in background.
3. `flutter_local_notifications` calls `onDidReceiveNotificationResponse`.
4. Callback tries to `ref.read(reminderRepositoryProvider)`.
5. Crash: `ProviderScope` not found in widget tree.
6. State transition fails silently. Reminder stays PENDING.

**Recommendation:**
- Define a `BackgroundServiceLocator` — a minimal, non-Riverpod service locator used ONLY for background callbacks. It initializes the database (Drift), provides repository instances, and exposes the state machine. It does NOT initialize Riverpod, UI services, or anything widget-dependent.
- OR: Define a `backgroundProviderScope` that is created once at app startup and stored in a static/global variable, reused by background callbacks. This is a pragmatic approach but violates clean Riverpod patterns.
- Explicitly document this as an architectural trade-off and choose one approach.

**Implementation impact:** MEDIUM — requires additional infrastructure for background execution.

---

## [MEDIUM] F2: Platform Channel Initialization Order vs. Drift Startup

**Category:** Flutter / Lifecycle

**Location:** §31.1 (App Startup Sequence), §28.4 (Platform-Specific Implementation)

**Problem:** The startup sequence (§31.1) says: 1. Check database integrity, 2. Run migrations, 3. Initialize platform bridges, 4. Configure notification categories, 5. Reconcile notifications, 6. Clean up soft-deletes, 7. Render UI.

On Flutter, platform channels (MethodChannels used by flutter_local_notifications, speech_to_text, permission_handler, url_launcher) are initialized when the Flutter engine starts, BEFORE `main()` runs in Dart. However, the plugins' Dart-side code needs to register handlers, which typically happens during `WidgetsFlutterBinding.ensureInitialized()` or plugin registration.

The startup sequence implies Drift is initialized before platform bridges. But if `flutter_local_notifications` needs to configure notification categories (§29.2: `configureCategories()`), and this requires the plugin to be initialized first (via `FlutterLocalNotificationsPlugin().initialize()`), then step 3 (initialize platform bridges) should come before step 1 (database check) or at least before step 2 (migrations). The order matters because:
- `configureCategories()` must happen before any notification is scheduled.
- If reconciliation (step 5) schedules notifications, categories must already exist.
- The current order is correct for this (3→4→5), but step 1-2 blocking step 3 means a database corruption prevents notification categories from being configured, which means even new notifications from the OS won't show correctly.

**Why it matters:** Minor — the current order mostly works. But the spec doesn't define whether the app should proceed to configure notifications if the database integrity check fails. The current language ("If check fails: show error screen") implies the app should NOT continue to configure notifications, which means a corrupt database also disables notifications for already-scheduled reminders. This may be the correct choice (don't fire notifications for reminders you can't read), but it should be explicit.

**Recommendation:**
- Document that notification categories should be configured EVEN if the database check fails, because existing OS-scheduled notifications need correct category definitions to display action buttons. OR document the opposite choice explicitly.
- Verify that `flutter_local_notifications` initialization does not depend on Drift or any database state.

**Implementation impact:** LOW — clarification only.

---

## [LOW] F3: No Widget Test Strategy

**Category:** Flutter / Testing

**Location:** §32 (Testing Strategy), §32.1 (Test Pyramid)

**Problem:** The test pyramid includes "UI: Widget tests (Flutter)" but never specifies which widgets should have widget tests or what mocking strategy to use. Widget tests with Riverpod require `ProviderScope` overrides. With `flutter_local_notifications`, `speech_to_text` (or custom bridge), and `permission_handler`, many widgets depend on platform plugins that are unavailable in tests.

**Why it matters:** Without guidance, widget tests will either be skipped (reducing coverage) or over-mocked (producing tests that pass but don't catch real bugs).

**Recommendation:**
- Add a widget test section: "Key widgets to test: ConfirmationCard, ClarificationCard, TimelineGroup, VoiceInputOverlay. Use `ProviderScope.overrides` to inject fake services. Mock platform bridges with `FakeSpeechBridge`, `FakeNotificationBridge`. Widget tests should verify UI state, not NLP correctness."
- Specify that widget tests should NOT cover NLP pipeline logic (already covered by unit tests). Widget tests verify the UI renders correctly given pre-built ReminderDraft/Reminder objects.

**Implementation impact:** LOW.

---

# 4. NATIVE BRIDGE CONTRACT AUDIT

## [HIGH] B1: SpeechBridge `startListening()` Contract Is Underspecified

**Category:** Platform Bridge

**Location:** §29.1 (SpeechBridge)

**Problem:**

```dart
Stream<String> startListening({Duration? silenceTimeout});
```

The contract is missing:
- **Cancellation:** How does the caller cancel an in-progress listening session? `stopListening()` is defined but its semantics are unclear — does it cancel and return the partial transcript, or discard?
- **Timeout:** The spec says "Maximum session: 30 seconds" (§8.2). Who enforces this — the bridge internally or the caller? If the bridge auto-stops at 30s, does the Stream emit a done event or an error?
- **Error propagation:** What errors can the Stream emit? `SpeechException`? `PermissionException`? How does the caller distinguish "no speech detected" from "STT engine crashed"?
- **Idempotency:** What happens if `startListening()` is called while already listening? Reject? Restart? The spec says the mic button is a toggle — `stopListening()` is called first — but programmatic misuse is possible.
- **Lifecycle interruption:** What happens if a phone call arrives mid-listening? The OS interrupts the audio session. Does the bridge emit an error? Resume automatically?
- **`silenceTimeout`:** The spec says default 2 seconds, configurable. But whose clock? The bridge's internal timer or an external timer that triggers `stopListening()`? If internal, does the Stream emit what was captured before timeout?

**Recommendation:**
- Define explicit error types: `SpeechNotAvailableException`, `PermissionDeniedException`, `NoSpeechDetectedException`, `SpeechTimeoutException`, `AudioInterruptedError`.
- Define `startListening` return type more explicitly: `Stream<SpeechResult>` where `SpeechResult` has `text`, `isFinal`, `confidence`.
- Define `stopListening()` semantics: "Stops the microphone. The Stream emits a final `SpeechResult(isFinal: true)` with whatever was captured, then closes. If no speech was detected, emits an error on the Stream."
- Add: `Future<void> cancelListening()` — stops and discards without emitting final result.
- Document that the bridge internally enforces the 30s max session and 2s silence timeout (configurable).

**Implementation impact:** MEDIUM — requires defining error types and more specific contract.

---

## [HIGH] B2: NotificationBridge `reconcile()` Contract Is Underspecified

**Category:** Platform Bridge

**Location:** §29.2 (NotificationBridge)

**Problem:**

```dart
Future<void> reconcile(List<Reminder> pendingReminders);
```

This is the most architecturally significant bridge method — it is the linchpin of notification reliability. But:

- **What does reconciliation actually do?** The spec says (§19.5 iOS): "ensures nearest 60 reminders have notifications." But the method signature takes a list of ALL pending reminders. Who decides which 60 — the bridge or the caller? If the bridge, the caller passes all pending reminders and the bridge sorts/limits internally. If the caller, the bridge must accept exactly which reminders to schedule.
- **What is the return value?** `Future<void>` — but the caller needs to know which reminders were actually scheduled (to update `notification_scheduled` flags) and which failed.
- **Cancellation of stale notifications:** Does `reconcile()` also cancel notifications for reminders that are no longer pending (e.g., completed, deleted)? The spec says "Reconcile notification queue" but doesn't define cleanup of orphaned notifications.
- **Platform difference:** On iOS, reconciliation needs to cancel existing notifications and re-schedule. On Android, it needs to cancel existing alarms and re-schedule. The bridge interface abstracts this, but the behavior difference (64 limit on iOS, unlimited on Android) affects the algorithm.
- **Concurrency:** What if reconciliation is running when a new reminder is being created? Should reconciliation be serialized with scheduling operations?

**Recommendation:**
- Change the signature:
  ```dart
  Future<ReconciliationResult> reconcile({
    required List<Reminder> toSchedule,    // reminders that SHOULD have notifications
    required List<int> knownNotificationIds, // all notification IDs currently tracked
  });
  
  class ReconciliationResult {
    final List<int> scheduledIds;     // successfully scheduled
    final List<int> failedIds;        // failed to schedule
    final List<int> cancelledIds;     // orphaned notifications that were cancelled
    final List<String> errors;
  }
  ```
- Define reconciliation algorithm ownership: "The Application layer determines which reminders to schedule (nearest N for iOS, all PENDING for Android). The bridge implements the platform-specific scheduling/cancellation logic. Results are returned to the Application layer which updates `trigger.notification_scheduled` flags."
- Define that reconciliation internally uses a serial queue (per platform bridge instance) to prevent concurrent scheduling.

**Implementation impact:** MEDIUM — more explicit contract but improves correctness.

---

## [MEDIUM] B3: ContactBridge `searchByName` Is Too Narrow

**Category:** Platform Bridge

**Location:** §29.3 (ContactBridge)

**Problem:**

```dart
Future<List<ContactEntry>> searchByName(String query);
```

The NLP's Contact Resolver (§10.3) needs three different search operations:
1. Exact display-name match (case-insensitive)
2. First-name or last-name startsWith
3. Contains match (name appears anywhere in display name)

A single `searchByName(String query)` method conflates these three search types. The bridge implementer doesn't know which search strategy to use. On iOS, `CNContactStore` has `unifiedContacts(matching: predicate)` where the predicate can be configured differently. On Android, `ContactsContract` has different URI queries for exact vs. partial matching.

**Why it matters:** If the bridge implements exact match only (the simplest interpretation of "searchByName"), partial and contains matching won't work. If it implements contains matching only, it may return too many results (making the three-tier resolution meaningless). The spec's resolution algorithm assumes three distinct queries with different performance/correctness characteristics.

**Recommendation:**
- Split into three methods OR add a `searchType` parameter:
  ```dart
  enum ContactSearchType { exact, startsWith, contains }
  Future<List<ContactEntry>> searchByName(String query, {required ContactSearchType type});
  ```
- OR keep one method and specify: "The bridge MUST return results sorted by relevance. The Application layer performs the three-tier filtering (exact → startsWith → contains) on the results. The bridge should return up to 20 matching contacts."

**Implementation impact:** LOW — minor API change.

---

## [LOW] B4: ActionBridge Includes Post-MVP Method

**Category:** Platform Bridge

**Location:** §29.4 (ActionBridge)

**Problem:** `openMaps(double lat, double lng, String? label)` is in the ActionBridge interface but maps/geofencing is Post-MVP (§22). Including it in the MVP bridge interface creates a dead method that must be implemented but won't be called.

**Recommendation:** Remove `openMaps` from the MVP ActionBridge. Add it in Post-MVP with a migration strategy.

**Implementation impact:** NONE — cleanup only.

---

# 5. iOS REALITY CHECK

## Classification of iOS Capabilities

| Capability | Classification | Evidence |
|-----------|---------------|----------|
| `SFSpeechRecognizer` on-device English | **GUARANTEED BY API** | iOS 13+ with `requiresOnDeviceRecognition = true` |
| `SFSpeechRecognizer` on-device Filipino | **NOT AVAILABLE** | Spec confirms (§13.2): `supportsOnDeviceRecognition` returns `false` |
| Microphone permission request | **GUARANTEED BY API** | Standard `AVAudioSession` |
| Speech recognition permission request | **GUARANTEED BY API** | `SFSpeechRecognizer.requestAuthorization` |
| `UNUserNotificationCenter` scheduling | **GUARANTEED BY API** | Standard iOS notification API |
| 64 pending notification limit | **GUARANTEED BY API** (as a limit) | iOS hard limit; must work around it |
| `BGAppRefreshTask` daily execution | **BEST EFFORT** | Does NOT run if app force-quit; system decides timing; may not run at all under Low Power Mode |
| Notification action background handling | **GUARANTEED BY API** (launches app) | Extension runs in separate process; requires App Group |
| Time-Sensitive notifications (iOS 15+) | **GUARANTEED BY API** (entitlement required) | Must be enabled in Capabilities; breaks through Focus |
| Critical Alerts (bypass mute) | **NOT AVAILABLE** | Spec correctly does not use Critical Alerts |
| iOS 16+ `NSFileProtectionComplete` | **GUARANTEED BY API** | Default for app sandbox |
| Notification persistence across reboot | **GUARANTEED BY API** | iOS preserves all scheduled notifications |
| Force-quit disables all background execution | **GUARANTEED BY API** (as a limitation) | iOS policy: force-quit = user intent to stop app |
| App Group container for SQLite | **GUARANTEED BY API** | Requires capability + provisioning profile |

## [HIGH] I1: BGAppRefreshTask Is Not Reliable Enough for the Designated Role

**Category:** iOS / Lifecycle

**Location:** §19.5 (iOS: BGAppRefreshTask), §31.5 (Device Reboot)

**Problem:** The spec relies on `BGAppRefreshTask` as the primary background reconciliation mechanism for iOS. The spec even notes its limitation: "BGAppRefreshTask does NOT run if the app has been force-quit by the user." But this is presented as a footnote, not as a fundamental reliability constraint.

The real reliability characteristics of `BGAppRefreshTask` on iOS 16+:
- The system decides when to run it based on device usage patterns. If the user rarely uses Katala, the task may run less frequently.
- Under Low Power Mode, background tasks are deprioritized or skipped.
- The task has ~30 seconds to complete. Drift init + migration check + querying 60 reminders + cancelling old notifications + scheduling new ones via `UNUserNotificationCenter` must fit within this window.
- If the task crashes or exceeds the time limit, the system may exponentially back off future executions.
- The task does NOT run if the app was force-quit (which many users do regularly).

**The net effect:** On iOS, if a user creates 70 reminders and then force-quits the app, only the nearest 60 fire. The remaining 10 will never fire until the user manually opens Katala. This is a correct statement of iOS behavior, but the spec should not call the system "reconciled" in this scenario — it should call it "degraded."

**Why it matters:** The spec's language around iOS notification reliability is more optimistic than the platform warrants. An implementer who reads "BGAppRefreshTask daily" may assume daily execution is guaranteed, leading to a reliability model that silently fails.

**Failure scenario:**
1. User creates 65 reminders over a month (all PENDING).
2. iOS schedules the nearest 60. 5 reminders (farthest in the future) have no notification.
3. User force-quits Katala after each use (common behavior).
4. Days pass. The nearest 60 reminders fire correctly.
5. BGAppRefreshTask never runs (force-quit disabled it).
6. The 5 unscheduled reminders come due. No notifications fire.
7. Weeks later, user opens Katala. Reconciliation runs. 5 reminders are overdue. User is confused and angry.

**Recommendation:**
- Rename the iOS reconciliation strategy: "Best-Effort Dynamic Window" instead of "Dynamic Scheduling Window." The distinction matters for reliability expectations.
- Add an in-app visual indicator when the notification queue is not fully scheduled: "5 of your 65 reminders are queued and will fire when space is available." Or: "iOS limits Katala to 64 active notifications. Open the app periodically to ensure all reminders fire."
- Add a badge count that reflects the number of overdue reminders (increments when reconciliation detects missed delivery).
- Consider implementing `BGProcessingTask` (less frequent but longer runtime) as a secondary reconciliation path alongside `BGAppRefreshTask`.

**Implementation impact:** MEDIUM — mostly documentation and UI changes.

---

## [MEDIUM] I2: `NSFileProtectionComplete` Conflicts with Background DB Access

**Category:** iOS / Security / Database

**Location:** §26.1 (Local Storage), §19.5 (iOS notification extension), §28.4 (iOS: Shared App Group container)

**Problem:** `NSFileProtectionComplete` means the database file is encrypted when the device is locked. This is correct for privacy. But:
- Notification extensions run when the device may be locked (notification arrives on lock screen).
- If the device is locked and the notification extension tries to access the database, it will fail with a file protection error.
- The spec says notification actions (Done, Snooze) MUST work from the lock screen (§19.6: "Device locked → Lock screen notification").

**Why it matters:** On iOS, a notification action tap on the lock screen that requires database access will fail silently unless the app handles `NSFileProtectionComplete` correctly. The app has two choices:
1. Use `NSFileProtectionCompleteUnlessOpen` — slightly less secure but allows access after first unlock until reboot.
2. Use `NSFileProtectionComplete` and accept that lock-screen notification actions will fail (show error to user).

Neither choice is specified.

**Recommendation:**
- Adopt `NSFileProtectionCompleteUnlessOpen` (or `NSFileProtectionComplete` with `NSFileProtectionCompleteUnlessOpen` for the shared container). Document the choice: "Database is protected when device is locked before first unlock. After first unlock, the database is accessible to the notification extension. This is the standard iOS pattern for apps with notification actions."
- Add an acceptance criterion: "Notification actions (Done, Snooze) work when the device is locked, provided the device has been unlocked at least once since boot." (This is the OS guarantee for `CompleteUnlessOpen`.)
- Test explicitly: lock device → receive notification → tap Done on lock screen → unlock → verify reminder is COMPLETED.

**Implementation impact:** MEDIUM — requires testing and correct file protection class.

---

## [LOW] I3: Inter Font Bundling Size Not Assessed

**Category:** iOS / Build

**Location:** §23.5 (Typography), §27.2 (Offline Behavior)

**Problem:** The spec says "Bundle font in app; no runtime download" for Inter (Google Fonts). Inter is ~3.5 MB for all weights. The spec uses: Bold 700, SemiBold 600, Regular 400, Medium 500 = 4 weights. Bundling only these 4 weights as .ttf files is ~1.5 MB. This is acceptable, but the spec doesn't mention font subsetting or file format optimization.

**Recommendation:** Specify: "Bundle Inter Regular, Medium, SemiBold, and Bold only. Use .ttf format. Consider font subsetting if app size is a concern."

**Implementation impact:** NONE — clarification only.

---

# 6. ANDROID REALITY CHECK

## Classification of Android Capabilities

| Capability | Classification | Evidence |
|-----------|---------------|----------|
| `SpeechRecognizer` with English offline model | **BEST EFFORT** | Depends on device having English offline model downloaded |
| `EXTRA_PREFER_OFFLINE` | **BEST EFFORT** | "Preference," not guarantee; spec acknowledges (§25.3) |
| `SCHEDULE_EXACT_ALARM` permission | **GUARANTEED BY API** | Android 12+; can be revoked by user |
| `canScheduleExactAlarms()` check | **GUARANTEED BY API** | Runtime check |
| `AlarmManager.setExactAndAllowWhileIdle()` | **BEST EFFORT** | Subject to Doze, battery optimization, OEM restrictions |
| `BOOT_COMPLETED` receiver | **OS/DEVICE DEPENDENT** | Not guaranteed on Xiaomi, OPPO, Huawei, some Samsung |
| `WorkManager` periodic task | **OS/DEVICE DEPENDENT** | Subject to Doze, battery optimization, OEM restrictions |
| Notification actions via BroadcastReceiver | **GUARANTEED BY API** | Must complete within ~10 seconds |
| Force-stop clears all alarms | **GUARANTEED BY API** (as limitation) | Android behavior; BOOT_COMPLETED also disabled |
| `ACTION_DIAL` (never `ACTION_CALL`) | **GUARANTEED BY API** | Correctly specified |
| Contacts permission | **GUARANTEED BY API** | Runtime permission |
| Offline Filipino speech model | **OS/DEVICE DEPENDENT** | Varies by manufacturer; often absent on budget devices |

## [HIGH] AN1: `EXTRA_PREFER_OFFLINE` Is Not a Privacy Guarantee

**Category:** Android / Privacy / STT

**Location:** §8.2 (Android STT), §25.3 (Documented Exceptions), §34.1 (CC-6: No cloud STT)

**Problem:** The spec says "Android: `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE = true`" and then honestly documents "Android STT (pre-13 or non-Pixel devices): Audio may be sent to Google for server-side processing" (§25.3). This is honest, but it contradicts CC-6 ("No cloud STT. Always enforce on-device recognition. If unavailable, disable voice — do NOT silently fall back.").

On Android < 13, there is NO API to check whether an offline model is available. `EXTRA_PREFER_OFFLINE` is literally just a preference — the system may still use cloud STT. The only way to truly enforce on-device-only on Android < 13 is to check for network connectivity and refuse to start STT if connected (which the spec does not require and would be a poor UX).

On Android 13+, `SpeechRecognizer` has `checkRecognitionSupport()` or similar, but the API surface varies. The spec says "For Android 13+: check recognition support via platform API" but doesn't name the specific API.

**Why it matters:** On Android devices running < 13 (which is the majority of active Android devices in the Philippines), Katala CANNOT technically guarantee on-device-only speech recognition. The privacy guarantee is unenforceable. The spec's own CC-6 says "If unavailable, disable voice," but the app can't detect "unavailable" on Android < 13.

**Recommendation:**
- Define the Android STT privacy policy more precisely based on OS version:
  - **Android 13+:** Use `SpeechRecognizer` API to check for on-device model availability. If unavailable, disable voice input (consistent with CC-6).
  - **Android 10-12:** Use `EXTRA_PREFER_OFFLINE`. Document that on-device guarantee cannot be technically enforced. Show a one-time notice during onboarding: "On this Android version, Katala requests on-device speech recognition but cannot guarantee it. Your voice input may be processed by Google's speech service. [Learn More]"
- Add this to the onboarding flow and the Privacy Information screen (§25.5).
- This is a product decision that affects the privacy guarantee. Add as PD-9.

**Implementation impact:** MEDIUM — requires version-specific behavior and additional disclosure UX.

---

## [HIGH] AN2: OEM Background Restrictions in the Philippine Market

**Category:** Android / Notifications / Lifecycle

**Location:** §19.5 (Android), §19.6 (Notification Behavior Matrix), §38 change #26

**Problem:** The spec acknowledges "Notification actions on Android may not survive force-stop" and adds "Guide users to disable battery optimization" (§19.5). This is insufficient.

In the Philippines, the top Android manufacturers by market share are Samsung, realme, OPPO, Xiaomi, and vivo (not Pixel). These manufacturers implement aggressive background kill policies that go FAR beyond standard Android Doze:

- **Xiaomi (MIUI/HyperOS):** Auto-start must be manually enabled per app, hidden in Security → Permissions → Autostart. Background services are killed within minutes unless the app is locked in the recents menu. `BOOT_COMPLETED` is blocked by default for non-system apps.
- **OPPO/realme (ColorOS):** "Background freezing" kills apps aggressively. Power Saver blocks alarms and receivers. Auto-launch must be manually enabled.
- **Samsung (One UI):** "Sleep" and "Deep sleep" lists automatically place rarely-used apps into restricted buckets. Alarms are delayed or cancelled.
- **vivo (Funtouch OS):** Similar auto-start restrictions. Background services killed aggressively.

The spec's guidance ("Guide users to disable battery optimization") is a single sentence that does not account for the multi-step, manufacturer-specific process users must follow. On Xiaomi alone, users must: (1) enable Autostart, (2) disable battery optimization, (3) lock the app in recents, (4) disable "MIUI optimization" (hidden in Developer Options). This is not reasonable to explain to a non-technical user.

**Why it matters:** On the majority of devices in Katala's target market, notifications will be unreliable regardless of the app's implementation. A reminder app that silently misses reminders on most devices in its primary market has a fundamental product-market fit problem that architecture cannot solve — but the architecture MUST account for it honestly.

**Failure scenario:**
1. User installs Katala on a Xiaomi Redmi Note (Philippines bestseller).
2. User creates a reminder for tomorrow.
3. User closes Katala (swipes away from recents).
4. Xiaomi kills Katala's background processes within minutes.
5. Next day: no notification. AlarmManager alarm was cleared when the app was killed.
6. User misses the reminder.
7. User uninstalls Katala. Leaves 1-star review: "Doesn't remind me of anything."

**Recommendation:**
- Add a "Device Compatibility" section to onboarding that detects the manufacturer and provides specific, illustrated instructions for enabling background execution (with screenshots for Samsung, Xiaomi, OPPO, realme).
- Implement a self-test: on first reminder creation, schedule a test notification 2 minutes later. If the app is in the background and the notification doesn't fire (detected via app foreground reconciliation), show: "Katala may not be able to deliver notifications reliably on this device. [See how to fix this]"
- Add a persistent notification option ("Katala is running" — Android foreground service) that guarantees the app won't be killed. Make this optional but recommended for users on affected devices. Document the battery impact.
- Set `AlarmManager` alarms using both `setExactAndAllowWhileIdle()` AND `setAlarmClock()` (the latter has higher priority and may survive some OEM restrictions).
- Consider using `WorkManager` with `ExistingPeriodicWorkPolicy.KEEP` to maintain a periodic heartbeat.

**Implementation impact:** HIGH — requires manufacturer-specific documentation, self-test infrastructure, and a foreground service option.

---

## [MEDIUM] AN3: `notification_scheduled` Flag Cannot Be Verified on Android

**Category:** Android / Notifications / Database

**Location:** §14.2 (Trigger), §19.5 (Android), §29.2 (NotificationBridge.getScheduledNotificationIds)

**Problem:** The Trigger entity has a `notification_scheduled` boolean (§14.2) that is "Set to true after successful scheduling. Set to false if scheduling fails." On Android, `AlarmManager.setExactAndAllowWhileIdle()` returning successfully does NOT mean the alarm will actually fire. The alarm can be:
- Cleared by the system during Doze
- Removed by battery optimization
- Cancelled by the manufacturer's background killer
- Lost on force-stop

There is no Android API to verify that a scheduled alarm still exists. `NotificationBridge.getScheduledNotificationIds()` (§29.2) is documented as "Best-effort" but on Android, there is no API to enumerate pending alarms. The method would need to maintain a separate in-memory/app-stored list, which is precisely what the database already has. The best-effort result is essentially "whatever the database says" — making the method circular.

**Why it matters:** The `notification_scheduled` flag creates a false sense of reliability. The flag says `true` after scheduling succeeds, but the alarm could have been cleared milliseconds later by the OS without any callback to the app. The flag will remain `true` even though the notification is guaranteed not to fire.

**Recommendation:**
- Rename `notification_scheduled` to `notification_scheduling_attempted` and document: "Set to true after the scheduling API call returns success. This does NOT guarantee the notification will fire. The alarm may be cleared by the OS at any time without notice."
- Do not rely on `notification_scheduled` for reconciliation decisions. Instead, on reconciliation, re-schedule ALL pending reminders regardless of the flag value. The cost of duplicate scheduling (the same alarm overwritten) is near zero; the cost of missing a notification is high.
- Remove `getScheduledNotificationIds()` from the Android bridge implementation (it cannot be implemented truthfully) and return an empty list, making reconciliation always do a full re-schedule.

**Implementation impact:** LOW — naming change and reconciliation logic adjustment.

---

# 7. SPEECH RECOGNITION ARCHITECTURE

## [MEDIUM] S1: The English/Taglish/Filipino STT Strategy Is Product-Defined but Architecturally Fragile

**Category:** Speech Recognition / NLP

**Location:** §13 (Language Support & Limitations), §8.2 (Speech-to-Text), §13.1 (Capability Matrix)

**Problem:** The spec has resolved the V1 issue by honestly documenting Filipino STT limitations. The current strategy is:

- English voice input: Works on both platforms with on-device STT.
- Taglish voice input: Works because English intent/action keywords are captured by the English STT model; Filipino temporal words are parsed by Katala NLP regardless of STT language.
- Filipino voice input: Does not work via voice on iOS (no on-device model). Works unreliably on Android.

This is architecturally coherent but creates an implicit dependence on the STT engine's behavior with code-switched input. Taglish speakers mix English and Filipino in unpredictable ways. The STT engine processes the audio and outputs its best transcription. Key questions the architecture doesn't answer:

1. **What happens when the English STT model mishears a Filipino word?** "Bukas" could become "book us" — which the NLP would not recognize as a temporal expression. The intent/action keywords are in English and likely preserved, but temporal entities may be lost.
2. **What happens when the user's accent affects English word recognition?** Philippine English has distinct pronunciation features. If "remind me" is transcribed as "remand me," the STT error correction table (§8.3) catches "rewind me" → "remind me" but not "remand me" → "remind me."
3. **What is the actual recognition accuracy for Taglish on mid-range devices?** The spec sets AC-5: "All test corpus commands (Taglish) parse with ≥ MEDIUM confidence." This tests the NLP parser, not the STT → NLP pipeline end-to-end. A REAL voice-to-parsed-reminder test with Taglish on actual devices is not in the acceptance criteria.

**Why it matters:** The STT error correction table has 10 entries, all based on English phonetic errors. Taglish-specific STT errors (Filipino word misrecognized as English word) are not addressed. An implementer following the spec would add English-centric corrections and miss the Taglish-specific errors that surface during real-world use.

**Recommendation:**
- Add: "The STT error correction dictionary (§8.3) MUST be tested with audio recordings of Filipino-accented English and Taglish speakers on both iOS and Android. Add Taglish-specific corrections based on empirical testing. The initial table in §8.3 is a placeholder; it must be expanded during Phase 4 (Platform Bridges) with real-device testing."
- Add an acceptance criterion: "AC-5b: Recorded Taglish audio commands from 5 different Filipino speakers produce correct parse results (≥ MEDIUM confidence) on at least 4 out of 5 speakers on both platforms."
- Add developer guidance: "The STT error correction is a data-driven component. Build a test harness that accepts an audio file → STT → NLP → assert output, to make the correction dictionary iterable."
- Document that STT accuracy for Taglish is a product risk that cannot be fully resolved in specification — it requires empirical validation with the target user population.

**Implementation impact:** LOW — specification and testing guidance only.

---

## [LOW] S2: No Speech Recognition Availability Cache or Status Indicator

**Category:** Speech Recognition / UX

**Location:** §8.2 (Error handling table), §31.1 (App Startup Sequence)

**Problem:** The spec defines error behavior when STT is unavailable, but the check (`isOnDeviceAvailable`) is described as called before each listening session. On iOS, `SFSpeechRecognizer.supportsOnDeviceRecognition` is a synchronous property check. On Android 13+, the equivalent check may be asynchronous. The spec doesn't define whether the availability check is cached, how often it's refreshed, or whether the UI shows STT availability status before the user taps the mic.

If the check is slow (e.g., on Android checking for downloaded models), the mic button would appear enabled but then fail after a tap + delay — a frustrating UX.

**Recommendation:**
- Cache STT availability status at app startup (step 3c in §31.1). Refresh on app foreground.
- Show mic button state based on cached status: enabled (blue), disabled (gray with explanation).
- If the cached status is stale (check failed last time), re-check on tap but show a spinner while checking.
- Add a `SpeechAvailability` provider that exposes `isAvailable`, `isOnDeviceAvailable`, `unavailableReason` reactively.

**Implementation impact:** LOW.

---

# 8. NLP ARCHITECTURE

## [LOW] N1: Entity Extraction Order Dependencies Not Specified

**Category:** NLP

**Location:** §10 (Entity Extraction), §10.5 (Title Generation)

**Problem:** The Entity Extractor (§10.1) extracts TEMPORAL, CONTACT, PHONE_NUMBER, URL, ACTION, and NOTES entities. But the extraction order matters:

- URL extraction must happen BEFORE contact extraction, because "call https://..." should not extract "https" as a contact name.
- ACTION extraction must happen BEFORE contact extraction, because the action verb determines the span of the contact name.
- TEMPORAL extraction should happen early, because temporal phrases ("tomorrow") should be removed before NOTES extraction.

The spec lists entity types but doesn't define extraction order. The contact extraction pattern (§10.2) correctly uses action verbs as anchors, which implies ACTION extraction happens first — but this is implicit.

**Why it matters:** An implementer who extracts entities in a different order (e.g., CONTACT before ACTION) will get different results for the same input. This violates CC-14 (NLP functions must produce deterministic output) because the implementation detail of extraction order affects correctness.

**Recommendation:**
- Define explicit extraction order: 1. URL, 2. TEMPORAL, 3. ACTION, 4. CONTACT, 5. PHONE_NUMBER, 6. NOTES (everything remaining after above).
- Justify: "URLs and temporal expressions are structurally identifiable independent of language. Action verbs anchor contact name extraction. Notes are the unresolvable remainder."
- Add a pipeline stage diagram showing the order.

**Implementation impact:** NONE — clarification only.

---

## [MEDIUM] N2: Confidence Scoring Formula Is Undefined

**Category:** NLP

**Location:** §12 (Confidence Scoring & UX Decisions), §8.1 (Pipeline)

**Problem:** The spec defines confidence thresholds (HIGH ≥ 0.85, MEDIUM 0.50-0.84, LOW < 0.50) but never specifies how the confidence score is calculated. The Confidence Scorer (§8.1, Stage 8) receives "all results" and outputs a score, but the formula is unspecified. This is the single most important number in the UX flow — it determines whether the user sees a confirmation card or a clarification card.

Without a formula:
- Different implementers will produce different scores for the same input.
- The acceptance criterion AC-4 ("All test corpus commands (English) parse with ≥ HIGH confidence") cannot be verified because the scoring is undefined.
- An AI agent might use a simple weighted average (70% intent confidence + 30% temporal confidence), a minimum-of-all-components approach, or a complex heuristic.

**Why it matters:** Confidence scoring directly controls UX behavior. If the formula is too generous, low-quality parses are shown as confirmation cards (increasing user error). If too strict, good parses are shown as clarification cards (increasing user friction).

**Recommendation:**
- Define the confidence formula explicitly. A reasonable baseline:
  ```
  confidence = (
    (intentFound    ? 0.30 : 0.0) +
    (temporalFound  ? 0.35 : 0.0) +
    (titleFound     ? 0.15 : 0.0) +
    (contactResolved? 0.10 : (contactAttempted ? 0.05 : 0.0)) +
    (actionFound    ? 0.05 : 0.0) +
    (noWarnings     ? 0.05 : 0.0)
  )
  ```
- OR specify: "Confidence scoring is intentionally deferred to implementation tuning. The test corpus (§32.3-32.4) must produce confidence ≥ 0.85 for English and ≥ 0.50 for Taglish. The scoring function must be documented in code with justification."

**Implementation impact:** LOW — formula definition or deliberate deferral.

---

## [LOW] N3: STT Error Correction Table Has No Taglish Entries

**Category:** NLP / Language

**Location:** §8.3 (STT error correction table), §13 (Language Support)

**Problem:** The 10-entry STT error correction table is entirely English-centric. Common Taglish STT errors are not addressed:
- "pa-remind" → "paramind" or "power mind"
- "tawagan" → "the wagon" or "talk again"
- "mamaya" → "mama ya" or "my my"
- "bukas" → "book us"

**Recommendation:** Explicitly state that the correction table is English-only for MVP and that Taglish-specific corrections must be added during empirical testing in Phase 4. Add a note: "The STT correction table in §8.3 is a minimum viable set. It MUST be expanded based on real-device testing with Filipino-accented English and Taglish speakers."

**Implementation impact:** NONE — documentation.

---

# 9. DATABASE ARCHITECTURE

## [MEDIUM] D1: Drift Cross-Process Access Strategy Is Missing

**Category:** Database / iOS

**Location:** §17 (Persistence), §19.5 (iOS: Notification Extension), §28.4 (iOS: Shared App Group)

**Problem:** Covered in detail in finding C1. Additional database-specific concerns:

- Drift uses `sqlite3` directly via `dart:ffi`. The notification extension on iOS is a separate binary that must also use `sqlite3` via FFI. Drift's generated code compiles for the main app target. Sharing this code with the extension requires either:
  - A shared framework target containing the database layer (recommended but complex for Flutter)
  - Duplicating the Drift-generated code in the extension target (maintenance burden)
  - Using raw `sqflite` in the extension instead of Drift (loses type safety)

- WAL mode is required for concurrent read/write access between the main app and extension. Drift defaults to WAL mode on iOS, but this must be explicitly verified and tested.

- The App Group container path is different from the app's default documents directory. Drift's `QueryExecutor` must be configured with the shared container path.

**Recommendation:**
- Add a dedicated section: "§17.5: iOS Notification Extension Database Access"
- Specify: "The notification extension uses the same Drift database schema via the shared App Group container. The extension initializes Drift with the shared container path. WAL mode is mandatory. The extension creates its own Drift database connection (separate from the main app's connection) to avoid cross-process connection sharing."
- Specify: "The extension bundles a minimal subset of the data layer: ReminderDao (query + update status only), TriggerDao (query + update), and the optimistic locking update logic. It does NOT bundle migrations, schema creation, or the full Drift database class."
- Add an integration test: "Create a reminder in the main app. Kill the app. In the notification extension test harness, query the reminder by ID, update its status to COMPLETED. Open the main app. Verify the reminder is COMPLETED."

**Implementation impact:** HIGH — requires non-trivial iOS + Flutter build configuration.

---

## [MEDIUM] D2: Reminder `version` Field for Optimistic Locking Has No Defined Initial Value Behavior

**Category:** Database / Concurrency

**Location:** §14.2 (Reminder), §15.4 (Concurrency: Optimistic Locking)

**Problem:** The `version` field defaults to 0. The optimistic locking update uses `WHERE id = ? AND version = ?`. On creation, `version = 0`. On first state transition:
```sql
UPDATE reminders SET status = ?, version = version + 1, updated_at = ?
WHERE id = ? AND version = ?
```
If two processes attempt the first transition simultaneously (e.g., notification action + in-app action, both reading `version = 0`), one succeeds (version becomes 1), and the other's `WHERE version = 0` finds no match. The spec says: "Retry once by re-reading the current state and re-evaluating the transition."

But what does "re-evaluating the transition" mean if the transition is "PENDING → COMPLETED"? After the first process completes it, the reminder is COMPLETED. The re-read shows status = COMPLETED. The guard says "Always allowed." The retry would set COMPLETED again — which is harmless but wastes a write. However, for "SNOOZED → PENDING" the guard is "Automatic" (timer fires). If two snooze timers fire simultaneously (unlikely but theoretically possible if app was suspended), both read `version = 0`, one succeeds, the other retries, reads `status = PENDING`, guard says "Automatic" but `status` is already PENDING — what should happen? The spec defines `SNOOZED → PENDING` but not `PENDING → PENDING` (a no-op transition not in the state machine).

**Why it matters:** Edge case — unlikely but the retry logic needs to handle the case where the transition is no longer applicable after re-read. The spec currently says "If the guard no longer allows the transition, abort silently." This is correct, but the guard definitions need to be checked against all possible re-read states.

**Recommendation:**
- Add a state machine rule: "After retry, if the current state does not allow the attempted transition, treat as success (the desired outcome was achieved by the other process) and return without error."
- Verify each transition: if the "other process" completes it first, is the retry result correct?
  - PENDING → COMPLETED: retry reads COMPLETED, guard "Always allowed" → re-sets COMPLETED. Harmless.
  - PENDING → SNOOZED: retry reads SNOOZED, guard "snooze_count < 10" on current state? Already SNOOZED, so trying PENDING→SNOOZED again reads status=SNOOZED, not PENDING. The transition requires FROM=PENDING. Abort silently. Correct.
  - SNOOZED → PENDING (auto): retry reads PENDING, FROM is SNOOZED but current is PENDING. Abort silently. Correct.
  - PENDING → DISMISSED: retry reads DISMISSED. Abort silently. Correct.
- The logic is correct as long as "abort silently" is implemented properly.

**Implementation impact:** NONE — validation confirms current design is correct.

---

## [LOW] D3: No Index on `trigger.scheduled_time`

**Category:** Database / Performance

**Location:** §14.2 (Trigger), §18.2 (Conflict Detection), §19.5 (Reconciliation queries)

**Problem:** Conflict detection queries `WHERE t.scheduled_time BETWEEN ? AND ?`. Reconciliation queries all PENDING reminders ordered by `scheduled_time`. Neither section specifies an index on `scheduled_time`. For MVP-scale data (hundreds of reminders), this is fine. But the spec should note it.

**Recommendation:** Add: "Index `triggers.scheduled_time` for conflict detection and reconciliation queries."

**Implementation impact:** NONE — one-line addition to schema.

---

# 10. NOTIFICATION ARCHITECTURE

## [HIGH] NO1: Reconciliation Does Not Detect Missing Notifications — Only Reschedules

**Category:** Notifications / Reliability

**Location:** §19.5 (iOS/Android reconciliation), §31.2 (App Foreground), §31.5 (Device Reboot)

**Problem:** The reconciliation strategy is: "For all PENDING reminders with future times, ensure a notification is scheduled." This prevents FUTURE missed notifications but does nothing to detect PAST missed notifications. There is no mechanism that answers: "This reminder was scheduled for 2 PM. It's now 3 PM. Did the notification fire?"

The spec acknowledges this indirectly: "Reminder stays PENDING; shows as overdue in app" (§19.6: "Notification expires unacted"). But this treats "notification expired unacted" and "notification never fired" identically. The user experience is the same (overdue reminder), but the system's trustworthiness is different. If notifications are silently not firing on a user's device, the app should know and inform the user.

**Why it matters:** Without missed-notification detection, Katala cannot distinguish between "user chose to ignore the notification" and "notification was never delivered due to platform issues." This prevents the app from providing reliability feedback and degrades trust over time.

**Failure scenario:**
1. User creates 5 reminders for today.
2. User's Xiaomi device kills Katala overnight.
3. None of the 5 notifications fire.
4. User opens Katala at 6 PM. All 5 reminders show as "Overdue."
5. User thinks: "Did I just miss them, or did Katala fail?" — No way to know.
6. This ambiguity erodes trust. The user can't tell if the app is reliable.

**Recommendation:**
- Add a `delivery_tracking` mechanism (lightweight):
  - When a notification is scheduled, set `trigger.notification_scheduled = true` and store `trigger.last_scheduled_at = now`.
  - When reconciliation runs, for each PENDING reminder where `scheduled_time < now` AND `fired_at IS NULL` AND `notification_scheduled == true` AND `last_scheduled_at < scheduled_time`: set `trigger.delivery_uncertain = true`. This means "the notification was scheduled but we don't know if it fired."
  - When reconciliation runs, for each PENDING reminder where `scheduled_time < now` AND `fired_at IS NULL` AND `notification_scheduled == false`: set `trigger.delivery_missed = true`. This means "we never even scheduled this notification."
  - Display in UI: "⚠️ 3 reminders may not have fired. [Review]" when `delivery_uncertain` or `delivery_missed` count > 0.
- This is optional for MVP but should be noted as a Post-MVP reliability enhancement.

**Implementation impact:** LOW — additional columns and logic, but significantly improves reliability transparency.

---

## [MEDIUM] NO2: Snooze Count Max of 10 Has No Recovery

**Category:** Notifications / State Machine

**Location:** §15.2 (Defined Transitions), §7.4 (FR-15)

**Problem:** FR-15 says "User MUST be able to Snooze a reminder up to 10 times." After the 10th snooze, the Snooze action is no longer available. What happens? The user sees a notification with [✓ Done] but no [⏰ Snooze] — or has [Snooze] greyed out — with no explanation of why. The spec doesn't define the UX for the "snooze exhausted" state.

**Why it matters:** Users who reach the snooze limit (likely power-users of a specific reminder) will be confused when the Snooze button disappears. The spec needs to define what replaces it.

**Recommendation:**
- Define "snooze exhausted" UX:
  - After snooze_count = 10, the notification still shows [⏰ Snooze] but tapping it shows an alert: "You've snoozed this reminder 10 times. [Mark as Done] [Edit Reminder Time]"
  - OR: After snooze_count = 10, the Snooze button is replaced with [✏️ Reschedule] which opens the edit form.
  - In-app: the Snooze button is disabled/greyed with explanation "Snoozed 10/10 times."
- This is a product decision (PD-9 candidate).

**Implementation impact:** LOW — UX definition, minimal code.

---

## [LOW] NO3: Notification ID Hashing with Collision Detection Is Vague

**Category:** Notifications / Implementation

**Location:** §19.4 (Notification ID Strategy)

**Problem:** "Use a hash of the Reminder UUID truncated to fit in a 32-bit signed integer, with collision detection on scheduling." This is underspecified:
- Which hash function? Dart's `hashCode`? `crc32`? The first 32 bits of the UUID?
- What is the collision detection strategy? If a collision is detected, what ID is used instead?
- How is the collision stored? A separate table? In-memory during the scheduling call?

**Recommendation:**
- Use a simpler strategy: "Notification IDs are auto-incrementing integers managed by the NotificationBridge. The bridge maintains an internal mapping from notification_id → reminder_id. This avoids hashing collisions entirely."
- OR: "Use the last 31 bits of the UUID's hash (Dart's `hashCode` masked with 0x7FFFFFFF). On collision (detected when attempting to schedule with an ID already in the bridge's active notification map), increment by 1 modulo 2^31 until an unused ID is found. Store the assigned notification_id in `trigger.notification_id`. Collision resolution happens during `schedule()`, not during reconciliation."

**Implementation impact:** LOW — implementation detail.

---

# 11. LIFECYCLE AUDIT

## [MEDIUM] L1: No Defined Behavior for "App Killed During Voice Recording"

**Category:** Lifecycle / STT

**Location:** §8.2 (Speech-to-Text), §31.3 (App Background), §31.4 (App Termination)

**Problem:** What happens if the user is recording a voice command and:
- Receives a phone call? (Audio session interrupted)
- Switches to another app? (App backgrounded)
- App is killed by the OS? (Low memory)

The spec says "Auto-stop on 2 seconds of silence" but doesn't address forced interruption. On iOS, the audio session is deactivated when a call arrives. On Android, the mic may be released when backgrounded. The STT session may produce a partial result, an error, or nothing.

**Why it matters:** The spec defines error handling for "No speech detected" and "STT engine unavailable" but not for "Recording interrupted." The implementer must decide whether to process the partial transcript (potentially incorrect) or discard it (losing user input).

**Recommendation:**
- Add to §8.2 error handling table:
  - "Recording interrupted (call, app switch, OS kill)" → If partial transcript available, process it and show confirmation card. Mark confidence as MEDIUM (penalize for potential incompleteness). If no partial transcript, show "Recording was interrupted. Try again?"
- On iOS: use `AVAudioSession.interruptionNotification` to detect audio interruptions and gracefully stop the STT session.
- On Android: use `AudioManager.OnAudioFocusChangeListener` for the same purpose.

**Implementation impact:** MEDIUM — requires platform-specific audio interruption handling.

---

## [LOW] L2: System Clock Change Handling Is Undefined

**Category:** Lifecycle / Data Integrity

**Location:** §11.9 (Timezone and DST), §31.6 (Timezone Change)

**Problem:** The spec covers timezone changes (§31.6) and DST transitions (§31.7). It does not cover manual system clock changes (user changes device time). If a user manually sets the clock forward by 2 hours:
- Already-scheduled notifications may fire at the wrong wall-clock time (because `AlarmManager` uses elapsed real-time on Android, but iOS uses wall-clock time).
- `DateTime.now()` will return the (incorrect) device time, potentially creating reminders with wrong UTC timestamps if the implementation uses `DateTime.now().toUtc()`.
- Reconciliation may incorrectly compute overdue reminders.

**Recommendation:**
- Document that Katala relies on the device clock being reasonably accurate. Add a startup check: compare `DateTime.now()` against a monotonic clock source (if available) to detect large jumps. If detected, show a warning: "Your device's clock may have changed. Some reminder times may be incorrect. [Review reminders]"
- On Android, use `SystemClock.elapsedRealtime()` for alarm scheduling (already the default with `setExactAndAllowWhileIdle`). On iOS, there is no monotonic-time-based scheduling — notifications use wall-clock time.
- Add a note to §31: "Katala assumes the device clock is set to automatic (network-provided) time. Manual clock changes can cause incorrect notification delivery and reminder times."

**Implementation impact:** LOW — documentation and optional startup check.

---

# 12. CONCURRENCY / IDEMPOTENCY AUDIT

## [MEDIUM] CO1: Optimistic Locking Works for State Transitions but Not for Create/Delete

**Category:** Concurrency

**Location:** §15.4 (Concurrency: Optimistic Locking), §17.3 (Migrations), §7.5 (Data Integrity)

**Problem:** The optimistic locking model (§15.4) covers state transitions on EXISTING reminders using the `version` column. It does not cover:
1. **Duplicate creation:** User taps [Save] twice on the confirmation card. Two `INSERT` operations run. Without a unique constraint, two reminders are created. The spec has no idempotency key for creation.
2. **Simultaneous create and delete:** Extremely unlikely but: reminder is being created (transaction not yet committed) while a periodic cleanup hard-deletes it (the reminder doesn't exist yet, so no conflict).
3. **Simultaneous soft-delete and state transition:** User deletes a reminder while a notification action marks it COMPLETED. Both read `version = N`, one succeeds (version becomes N+1), the other retries, reads `is_deleted = true`, and should abort. The spec's delete transition (§15.3) says "Sets is_deleted=true" but doesn't specify a version check. If delete doesn't use optimistic locking, a notification action could succeed AFTER the delete (resurrecting a deleted reminder).

**Why it matters:** The most likely scenario is double-tap on [Save]. Without an idempotency key or UI-level debouncing (disable button after first tap), two reminders are created.

**Recommendation:**
- Add UI-level debouncing: [Save] button is disabled immediately on first tap, re-enabled only on error. This is a UI concern but should be specified.
- Add optimistic locking to delete: `UPDATE reminders SET is_deleted = true, version = version + 1 WHERE id = ? AND version = ?`.
- For creation idempotency: optional for MVP. Add a `client_generated_id` (already UUID) and a unique constraint, OR accept the (low) risk of double-tap creating duplicates and rely on UI debouncing.

**Implementation impact:** LOW — UI debouncing is standard, delete version check is one SQL change.

---

## [LOW] CO2: Notification Action Handlers and Main App Can Write Concurrently

**Category:** Concurrency / iOS

**Location:** §15.4, §19.5 (iOS: Background action handling), §28.4 (iOS: Shared App Group)

**Problem:** On iOS, the notification extension runs in a SEPARATE PROCESS. It opens its own SQLite connection to the shared App Group database. The main app may also be running (foreground or background) with its own SQLite connection. Both can write concurrently. SQLite WAL mode handles this correctly at the file level (writers do not block readers, multiple writers are serialized by SQLite's internal locking). However:

- If the main app is in the middle of a transaction (e.g., editing a reminder) and the extension attempts a state transition on the SAME reminder, the optimistic locking WHERE clause handles this at the application level.
- But if the main app's transaction spans multiple reminders and the extension writes to one of them, the main app's transaction may see inconsistent data (depending on isolation level).

**Recommendation:**
- Document: "All database transactions should be short-lived (single-reminder operations). Multi-entity writes (Reminder + Trigger + Action) are wrapped in a single transaction but limited to one reminder at a time. Cross-reminder transactions are prohibited."
- WAL mode default isolation is "read committed" — readers see the latest committed state. This is acceptable.

**Implementation impact:** NONE — documentation of existing constraint.

---

# 13. PERMISSION ARCHITECTURE

## [LOW] PE1: Notification Permission Denial Has No In-App Fallback Guidance

**Category:** Permissions / UX

**Location:** §7.2 (FR-9: notification requirements), §19.5, §30.1 (Error Handling)

**Problem:** The error handling table says: "Notification permission denied → 'Notifications off — you might miss reminders' + Settings button." This is correct for initial creation, but what about reminders that were ALREADY scheduled before the user revoked notification permission? On iOS, scheduled notifications remain until the 64-limit cycles them out. On Android, revoking notification permission does not cancel alarms (alarms are separate from notification display permission), but notifications won't be displayed.

The app should detect permission revocation and inform the user that existing reminders will not display notifications.

**Recommendation:**
- Add to §31 (Lifecycle): "On app foreground, check notification permission status. If permission was previously granted but is now denied, show a banner: 'Notifications are disabled. Your [N] existing reminders will not alert you. [Enable Notifications]'"

**Implementation impact:** LOW — one additional foreground check.

---

# 14. PRIVACY AND SECURITY ARCHITECTURE

## [MEDIUM] PS1: Zero Network Verification Is Specified but Not Automatable

**Category:** Security / Build

**Location:** §34.1 (CC-1: No network requests), §33.4 (AC-23: Network traffic audit)

**Problem:** AC-23 requires: "Release build makes zero network requests (verified by network traffic audit)." This is a manual test described as an audit. But the spec doesn't define:
1. **How to automate this check in CI.** If a developer accidentally adds a dependency that makes network requests (e.g., a Firebase dependency that auto-initializes), the manual audit would catch it only during Phase 8 testing — weeks after the dependency was added.
2. **What constitutes "Katala code."** If the `url_launcher` plugin opens a browser (user-initiated action), does that count? No — it's user-initiated. But if `google_fonts` checks for font updates on startup, does that count? Yes — it's automatic. The boundary needs definition.

**Why it matters:** CC-1 is the single most important architectural constraint. A single accidentally-added dependency could violate it. Manual verification at the end of the project creates a risk that the violation is discovered late and requires significant rework.

**Recommendation:**
- Add a CI step: "Build the release IPA/APK. Run on a device with a network proxy (mitmproxy/Charles). Assert that the only network requests are OS-level (certificate validation, push notification registration, map tiles if Post-MVP). Fail the build if any unexpected request is detected."
- Define "Katala code" explicitly: "Any Dart code, native Swift/Kotlin code, or third-party dependency included in the app binary. Excludes: OS-level services (push notification registration, map tile loading in Post-MVP), user-initiated actions (dialer, browser, messages intents)."
- Add to dependency review: "Before adding any pub.dev package, verify it makes no network requests by reading its source code and/or testing in isolation."

**Implementation impact:** MEDIUM — requires CI infrastructure but significantly reduces risk.

---

## [LOW] PS2: Debug Logging of NLP Pipeline Could Leak Transcripts

**Category:** Security / Privacy

**Location:** §25.6 (Logging Policy), §8.1 (Pipeline), §34.3 (CC-14)

**Problem:** The logging policy says debug builds can have "Verbose NLP pipeline logging." This could inadvertently include raw transcripts (which contain personal information). An implementer might log the full `RawTranscript` and `NormalizedTranscript` objects at each pipeline stage for debugging, violating the spirit of the privacy policy even if not technically a release-build issue.

**Why it matters:** Debug builds are used by developers but may also be shared with testers or run on personal devices. A developer's device could be backed up to iCloud, including debug logs with transcript data.

**Recommendation:**
- Refine: "Debug logging: NLP pipeline stage names, timing, confidence scores, and entity counts. NOT raw transcript text, contact names, or resolved times. Use tokenized/sanitized representations for debugging (e.g., 'TRANSCRIPT_LENGTH=47', 'CONTACT_FOUND=1', 'INTENT=CREATE_REMINDER')."
- Add a release-build assertion: `assert(!kReleaseMode || !log.contains(transcript))` in the logging wrapper.

**Implementation impact:** NONE — policy clarification.

---

# 15. DEPENDENCY AUDIT

## [HIGH] DE1: `speech_to_text` Package Is Incompatible with On-Device-Only Requirement

**Category:** Dependencies

**Location:** §34.2 (Dependency Whitelist), §8.2 (Speech-to-Text), §34.1 (CC-6)

**Problem:** Covered in finding C3. Summary:

The `speech_to_text` package (pub.dev, v6.x):
- On iOS: wraps `SFSpeechRecognizer` but does NOT expose `requiresOnDeviceRecognition`. The default behavior depends on the OS. Apple may use server-side recognition when on-device is not available, and the package provides no way to prevent this.
- On Android: wraps `SpeechRecognizer` but does NOT set `EXTRA_PREFER_OFFLINE`. Audio may be sent to Google servers.
- Does NOT expose `supportsOnDeviceRecognition` (iOS) or Android 13+ model availability checks.

**Using this package would violate CC-6.**

The spec acknowledges this implicitly by saying "`speech_to_text` or custom native bridge," but listing it as an allowed package creates a false equivalence. An AI agent or junior developer reading the dependency whitelist would reasonably choose the package (easier) over the custom bridge (harder) and unknowingly violate the privacy requirement.

**Recommendation:**
- Remove `speech_to_text` from the whitelist. Replace with: "Custom native bridge for STT (mandatory). See §29.1 for the SpeechBridge contract. No Flutter package currently enforces on-device-only recognition on both platforms."
- Add ADR-10 documenting the decision.
- If there is a desire to evaluate `speech_to_text` as a fallback option, add: "The `speech_to_text` package may be used ONLY if its source code is verified to expose on-device-only enforcement. As of v6.x, it does not. Re-evaluate in Post-MVP."

**Implementation impact:** HIGH — custom native bridge is mandatory from day one.

---

## [MEDIUM] DE2: `google_fonts` May Make Network Requests

**Category:** Dependencies / Privacy

**Location:** §34.2 (Dependency Whitelist), §27.2 (Offline Behavior)

**Problem:** The spec says "Bundle Inter font in app; no runtime download" (§27.2). The `google_fonts` package, by default, fetches fonts from Google's servers at runtime. The spec acknowledges this by saying "Bundle font in app" but still lists `google_fonts` as an allowed dependency. The `google_fonts` package CAN be used with bundled fonts (by specifying the font files in `pubspec.yaml` and using `GoogleFonts.config.allowRuntimeFetching = false`), but this is NOT the default behavior.

An AI agent that adds `google_fonts` without the bundling configuration will introduce network requests — violating CC-1.

**Recommendation:**
- Replace `google_fonts` with: "Bundle Inter font files (.ttf) directly in `assets/fonts/`. Use `google_fonts` ONLY with `GoogleFonts.config.allowRuntimeFetching = false` and bundled font files. Verify no network requests with network traffic audit."
- OR remove `google_fonts` entirely and specify: "Add Inter .ttf files to pubspec.yaml fonts section. Use standard Flutter font declarations (no google_fonts package)."

**Implementation impact:** LOW — configuration change, same visual result.

---

## [LOW] DE3: `flutter_local_notifications` Configuration for Background Actions

**Category:** Dependencies

**Location:** §34.2, §19.3 (Notification Actions)

**Problem:** The spec uses `flutter_local_notifications` for notifications but defines notification action callbacks that perform database operations. `flutter_local_notifications` provides `onDidReceiveNotificationResponse` for handling notification taps. For actions where the app should NOT open (Done, Snooze), the handler must complete without launching the UI.

On iOS, the callback fires in the main app process (launched in background). On Android, it fires in the BroadcastReceiver context (short-lived). The spec doesn't specify HOW `flutter_local_notifications` should be initialized for background-only handling vs. foreground handling.

**Recommendation:**
- Add implementation note: "The `FlutterLocalNotificationsPlugin.initialize()` call MUST include both `onDidReceiveNotificationResponse` (for when app is launched) and a separate background handler registration. On iOS, use `DarwinNotificationCenter` or `UNUserNotificationCenter` delegate methods directly. On Android, configure the `AndroidFlutterLocalNotificationsPlugin` to use a `BroadcastReceiver` subclass for background actions."
- Verify that `flutter_local_notifications` version supports the required background action behavior before starting Phase 4.

**Implementation impact:** LOW — configuration guidance.

---

# 16. TESTABILITY AUDIT

## [MEDIUM] T1: NLP Pipeline Test Strategy Relies on Unspecified Fake Implementations

**Category:** Testing

**Location:** §32.2 (Unit Tests), §32.5 (NLP Testability), §32.6 (Platform Bridge Testing)

**Problem:** The test strategy is well-defined for pure NLP functions. But tests for the Contact Resolver require a `FakeContactBridge`. Tests for the Semantic Validator that involves contact resolution require the same. Tests for Conflict Detector require a database with pre-seeded reminders.

The spec doesn't define:
1. **What `FakeContactBridge` returns.** A pre-configured list of contacts? A mapping from query string → results? Something else?
2. **How to seed the test database for conflict detection.** Drift's testing utilities? Raw SQL inserts?
3. **Whether integration tests should use an in-memory SQLite database.** Drift supports in-memory databases for testing. This should be specified.
4. **How to test the Temporal Resolver with DST boundaries.** The `FakeClock` approach works, but the tests should explicitly cover spring-forward and fall-back edge cases.

**Why it matters:** Without these definitions, different implementers will create different test infrastructure, and some tests may pass due to fake implementations that don't accurately simulate real behavior.

**Recommendation:**
- Define `FakeContactBridge` behavior: "Accepts a `Map<String, List<ContactEntry>>` in its constructor mapping query strings to expected results. Returns empty list for unconfigured queries."
- Specify: "All data layer tests use Drift's in-memory database (`NativeDatabase.memory()`). The database is created and migrated fresh for each test."
- Add to §32.2: "Temporal Resolver DST tests: inject a `FakeClock` set to 2026-03-08 01:30 AM EST (one hour before spring-forward). Resolve 'in 2 hours'. Expect 2026-03-08 03:30 AM EDT (not 03:30 AM EST, which doesn't exist)."
- Add: "Conflict Detector tests: pre-seed database with known reminders. Verify conflict detection with times at -16, -15, -14, 0, +14, +15, +16 minutes from existing reminder."

**Implementation impact:** LOW — test specification additions.

---

## [LOW] T2: No Performance Test Specification

**Category:** Testing / Performance

**Location:** §33.1 (AC-1, AC-3), §1.2 (Core Identity: Fast)

**Problem:** AC-1: "Tapping the mic starts listening within 500ms." AC-3: "After silence timeout, NLP processes and shows confirmation within 500ms." These are performance acceptance criteria with no defined test methodology:
- On which device? "Mid-range devices" is mentioned in G1 but not in acceptance criteria.
- How is the timing measured? Instrumented code? Manual stopwatch?
- What is the acceptable range? Is 550ms a failure?

**Recommendation:**
- Define: "Performance tests run on: iPhone SE (3rd gen, 2022) for iOS; Samsung Galaxy A34 or equivalent for Android."
- Timing: instrumented using `Stopwatch` in Dart. Log timing to debug console. Automated assertion in integration tests: `stopwatch.elapsedMilliseconds < 500`.
- Define tolerance: "AC-1: Mic starts within 500ms (median of 10 runs, p95 < 750ms). AC-3: NLP + confirmation within 500ms (median of 10 runs, p95 < 1000ms)."

**Implementation impact:** NONE — specification only.

---

# 17. BUILD AND RELEASE AUDIT

## [HIGH] BR1: iOS Notification Extension Target Not Defined in Build Configuration

**Category:** Build / iOS

**Location:** §19.5 (iOS), §28.4 (iOS: Shared App Group container)

**Problem:** To support notification actions that work without opening the app, iOS requires:
1. A `Notification Service Extension` target (for modifying notification content before display) OR a `Notification Content Extension` target (for custom UI).
2. For background state changes (Done, Snooze), the spec needs the main app to handle the action in the background. This requires:
   - `UNUserNotificationCenter` delegate configured in the main app
   - `flutter_local_notifications` background callback to invoke Dart code
   - The app must be launched in the background to handle the action.
3. An App Group capability configured in the Xcode project for BOTH the main app target and the extension target.
4. Provisioning profile that includes the App Group.

The spec mentions these requirements in passing (§19.5, §28.4) but doesn't include them in:
- The implementation roadmap (§36) — Phase 4 says "iOS SpeechBridge...iOS NotificationBridge...Notification action handlers" but doesn't call out the extension target as a separate build artifact.
- The implementation constraints (§34) — no mention of App Group entitlement configuration.
- The acceptance criteria (§33) — no AC for extension target working correctly.

**Why it matters:** An implementer who follows the roadmap literally would build the NotificationBridge and then discover in testing that background notification actions don't work, because the extension target was never created. Adding it retroactively requires significant Xcode project changes.

**Recommendation:**
- Add to Phase 4 (Week 5-6): "Create iOS Notification Service Extension target. Configure App Group capability. Configure shared container path. Implement notification action handler in extension."
- Add to §34.1: "CC-19: The iOS app MUST include a Notification Service Extension target configured with App Group capability for shared database access."
- Add AC: "AC-17b: On iOS, tapping Done on a notification while the app is killed marks the reminder COMPLETED and the change is visible when the app is next opened."
- Add build configuration: "Xcode project must include: main app target, Notification Service Extension target. Both targets must share an App Group with identifier `group.com.katala.reminders`."

**Implementation impact:** HIGH — adds significant iOS build complexity.

---

## [MEDIUM] BR2: Flutter and Dart Version Not Pinned

**Category:** Build

**Location:** §28.4 (iOS/Android deployment targets), §34 (Implementation Constraints)

**Problem:** The spec defines minimum OS versions (iOS 16+, Android 10 / API 29) but does not pin:
- Flutter SDK version (e.g., 3.24.x, 3.27.x?)
- Dart SDK version
- Xcode version
- Kotlin version (spec says 1.9+ but not a specific version)
- Swift version (spec says 5.9+ but not a specific version)
- Gradle version / Android Gradle Plugin version
- `pubspec.yaml` dependency version constraints (e.g., `drift: ^2.x` or `drift: >=2.15.0 <3.0.0`?)

**Why it matters:** Different versions of Flutter have different channel requirements, Swift interoperability, Android API support, and Xcode compatibility. An AI agent that generates a `pubspec.yaml` with `drift: any` could pull in a breaking major version change. An agent that uses Flutter 3.27 may have Dart 3.6 features not available in 3.24.

**Recommendation:**
- Pin: Flutter ≥ 3.24.0, Dart ≥ 3.5.0. Specify: "The Flutter version must be the latest stable at the time of implementation start. All dependencies must use caret constraints (^) with minimum versions verified to be compatible."
- Add a `pubspec.lock` verification step in CI: "`flutter pub get` must succeed with the locked versions. Dependency resolution must produce zero conflicts."
- Specify: "All platform build tools (Xcode, Kotlin, Gradle) should use the versions recommended by Flutter's current stable release documentation."

**Implementation impact:** MEDIUM — version pinning affects CI and developer setup.

---

## [LOW] BR3: Code Signing and Distribution Not Addressed

**Category:** Build

**Location:** §36 (Implementation Roadmap), §37 (Open Product Decisions)

**Problem:** The spec has zero mention of:
- iOS code signing (development team, provisioning profiles)
- Android signing keys (debug vs. release keystore)
- App Store Connect configuration
- Google Play Console configuration
- TestFlight / Internal Testing distribution
- App Store review guidelines compliance (especially for microphone access justification)

While these are not architectural concerns per se, they are build/release requirements that an implementer must address. The spec's "Implementation-Ready" claim should at minimum note these as requirements.

**Recommendation:**
- Add to §34: "CC-20: iOS code signing requires an Apple Developer account with provisioning profiles configured for the main app target and notification extension target, both with App Group capability."
- Add to §36 Phase 1: "Create Apple Developer provisioning profiles. Create Android release keystore. Configure Fastlane or manual build scripts. Submit empty app to TestFlight and Google Play Internal Testing to verify pipeline."

**Implementation impact:** NONE — documentation.

---

# 18. AI CODING-AGENT READINESS

## Summary: Top AI Agent Failure Modes

| # | Failure Mode | Severity | Mitigation in Spec? |
|---|-------------|----------|---------------------|
| 1 | Using `speech_to_text` package → cloud STT on iOS | **CRITICAL** | ❌ Package still listed as allowed (C3, DE1) |
| 2 | Skipping iOS notification extension target | **CRITICAL** | ❌ Not in roadmap, not a constraint (C1, BR1) |
| 3 | Not configuring App Group for shared DB | **CRITICAL** | ❌ Mentioned in one line, not actionable (C1) |
| 4 | Putting notification scheduling in UI button callbacks | **HIGH** | ⚠️ Layer rules exist but UseCase undefined (A1) |
| 5 | Using `google_fonts` with runtime fetching | **HIGH** | ⚠️ Spec says bundle but package still listed (DE2) |
| 6 | Building NLP as single God function | **HIGH** | ✅ Stage interfaces defined (§8.4) |
| 7 | Adding cloud STT "as fallback" for Filipino | **HIGH** | ✅ CC-6 explicitly prohibits |
| 8 | Creating different behavior on iOS vs Android | **MEDIUM** | ✅ CC-18 mandates identical business logic |
| 9 | Over-engineering NLP with custom DSL/rule engine | **MEDIUM** | ⚠️ Spec says "simple regex" but not explicitly forbidding framework |
| 10 | Not implementing optimistic locking | **MEDIUM** | ✅ §15.4 explicitly defined |
| 11 | Hard-coding `DateTime.now()` in NLP | **MEDIUM** | ✅ §11.1, §32.5 mandate injectable Clock |
| 12 | Putting API keys or secrets in code | **LOW** | ✅ No cloud services, no keys needed |
| 13 | Skipping DB integrity check on startup | **LOW** | ✅ §17.2, §31.1 explicitly required |
| 14 | Bundling entire Inter font family (all weights) | **LOW** | Not addressed (I3) |
| 15 | Creating notification categories after scheduling | **LOW** | ✅ §31.1 step 4: configure before reconcile |

## [HIGH] AI1: Agent Will Treat the Spec's STT Package Suggestion as Endorsement

**Category:** AI-Agent

**Location:** §34.2

**Problem:** The dependency whitelist includes `speech_to_text` as a first-class option: "`speech_to_text` or custom native bridge — STT." An AI agent will interpret "or" as "either is acceptable" and choose the package (path of least resistance). The agent will not realize that the package violates CC-6 until it's too late, because the constraint is documented in §34.1 (5 sections away) and not linked from the dependency list.

**Recommendation:** Remove `speech_to_text` from the whitelist. See DE1.

---

## [MEDIUM] AI2: Agent Will Implement Notification Scheduling Inside the Repository

**Category:** AI-Agent

**Location:** §17 (Persistence), §19 (Notification Architecture), §28.1 (Layer Architecture)

**Problem:** An AI agent reading "Repository pattern" (§28.1 Data Layer) and "When a reminder's trigger time changes, cancel the existing notification and schedule a new one" (from V1 review fix) will naturally place notification scheduling inside the repository's `save()` or `update()` method. This is the path of least resistance but violates the layer rules (Data layer doing Platform work).

The spec's layer diagram (§28.1) shows Data Layer below Platform Bridges — implying Data depends on Platform, which violates dependency inversion. The correct dependency is: Application → Data (for persistence) + Application → Platform Bridges (for scheduling). The spec doesn't call this out explicitly.

**Recommendation:**
- Add explicit rule to §28.3: "Data layer does NOT call Platform Bridges. Data layer persists and queries. Application layer orchestrates: first persist, then schedule/cancel notifications via Platform Bridges."
- Add an architectural decision: "ADR-11: Notification scheduling is an Application-layer concern, not a Data-layer concern. The repository returns the persisted entity; the caller schedules the notification."

**Implementation impact:** NONE — documentation prevents implementation error.

---

## [MEDIUM] AI3: Agent Will Not Handle the iOS 64-Notification Limit Correctly

**Category:** AI-Agent / iOS

**Location:** §19.5 (iOS strategy), §29.2 (NotificationBridge)

**Problem:** The spec says "Schedule nearest 60 PENDING reminders. Keep 4 slots as buffer." An AI agent might implement this as:
1. On save: if pending count < 64, schedule.
2. On save: if pending count >= 64, don't schedule (reminder exists but has no notification).

This is incorrect. The correct implementation is:
1. Always schedule the new reminder's notification (it's one of the "nearest" by definition if it was just created).
2. If this pushes the total to 65, find the farthest-in-future PENDING notification and cancel it.
3. Maintain exactly the nearest N (≤ 64) reminders with notifications.

The spec's current language ("Schedule nearest 60 PENDING reminders") doesn't make the replacement semantics clear. An agent might append rather than replace.

**Recommendation:**
- Clarify: "The dynamic scheduling window operates as a priority queue. On every scheduling event (create, edit, delete, complete, reconciliation): (1) Determine the set of PENDING/SNOOZED reminders with future trigger times. (2) Sort by scheduled_time ascending. (3) Take the first 60. (4) Cancel any currently-scheduled notification whose reminder_id is NOT in the top 60. (5) Schedule notifications for any reminder in the top 60 that doesn't already have one. (6) Update trigger.notification_scheduled flags."

**Implementation impact:** NONE — clarification.

---

# 19. COMPLEXITY AUDIT

| Item | Verdict | Rationale |
|------|---------|-----------|
| 8-stage NLP pipeline | **KEEP** | Each stage is independently testable. Required for deterministic, offline parsing. |
| ReminderDraft intermediate model | **KEEP** | Essential for decoupling NLP output from persistence. |
| Separate Trigger and Action entities | **KEEP** | Clean normalization. Enables future trigger types (geofence) without schema change. |
| UserPreference key-value store | **KEEP** (for MVP) | Acceptable for < 20 preferences. Revisit in Post-MVP. |
| Optimistic locking with version column | **KEEP** | Necessary for concurrent notification + in-app actions. Simple integer, widely understood. |
| Follow-up engine (Post-MVP) | **DEFER** | Correctly scoped. Schema prep (depth, recurrence_rule) is reasonable. |
| Geofencing (Post-MVP) | **DEFER** | Correctly scoped. |
| Riverpod for DI + state management | **KEEP** | Standard Flutter choice. Compile-safe. |
| STT error correction as data structure | **KEEP** | Good design: data-driven corrections are easier to extend than hardcoded conditionals. |
| Separate `FakeClock` for NLP testing | **KEEP** | Essential for deterministic temporal tests. |
| Bundle Inter font instead of runtime download | **KEEP** | Privacy requirement. |
| Notification categories per intent type | **SIMPLIFY** (consider) | Four categories with 3-4 actions each. Could be simplified to one category with dynamic actions (if platform allows). Otherwise, KEEP. |
| BGAppRefreshTask + WorkManager dual reconciliation | **KEEP** | Necessary for platform reliability. Not overengineering. |
| "Snoozed" notification content change | **DEFER** | The spec doesn't mention whether a snoozed notification should show "Snoozed" or the new fire time. This is a minor UX detail, not architectural. |

---

# 20. ARCHITECTURAL DECISION RECORDS — NEW REQUIRED

## BLOCKING Decisions

| ID | Decision | Why It Matters | Options | Recommended |
|----|----------|---------------|---------|-------------|
| **ADR-10** | Custom STT native bridge vs. `speech_to_text` package | CC-6 (No cloud STT) is unenforceable with the package | (a) Custom bridge (mandatory enforced on-device), (b) Use package with caveat (downgrades privacy claim) | **(a) Custom bridge.** See C3, DE1. |
| **ADR-11** | Notification scheduling ownership | Prevents data layer from calling platform bridges | (a) Application layer orchestrates (call repository THEN call bridge), (b) Repository calls bridge internally (simpler but layer violation) | **(a) Application layer orchestration.** See A1, AI2. |
| **ADR-12** | iOS notification extension architecture | Required for background notification actions | (a) Notification Service Extension with App Group + Drift subset, (b) Foreground-only notification actions (violates FR-8), (c) UNNotificationAction with foreground option (opens app) | **(a) Service Extension + App Group.** See C1, BR1. |
| **ADR-13** | Background execution Riverpod scoping | Notification callbacks run outside widget tree | (a) Static service locator for background callbacks, (b) Separate `ProviderScope` per background isolate, (c) Initialize full Riverpod graph in background | **(a) Static service locator.** See F1. |

## IMPORTANT Decisions

| ID | Decision | Why It Matters | Recommended |
|----|----------|---------------|-------------|
| **ADR-14** | Database file protection class (iOS) | Lock-screen notification actions require DB access | `NSFileProtectionCompleteUnlessOpen` |
| **ADR-15** | Android OEM background reliability strategy | Most Philippine-market devices kill background apps aggressively | Optional foreground service + per-manufacturer setup guides |
| **ADR-16** | Confidence scoring formula | Controls UX behavior for every voice input | Defer to implementation with test corpus validation |
| **ADR-17** | `UserPreference` type safety approach | Risk of runtime type errors for preferences | Typed accessor methods with unit tests for MVP |

---

# FINAL OUTPUT

## 1. Architecture Readiness Verdict

### NEEDS MAJOR REVISION

KATALA_SPEC_V2.md is a substantial improvement over V1. The specification demonstrates mature architectural thinking — the layer separation, NLP pipeline modularity, state machine, optimistic locking, platform bridge abstraction, and honest documentation of platform limitations are well-conceived. Many V1 issues identified in SPEC_REVIEW.md have been addressed (auto-save removal, AM/PM toggle, backup exclusion, background reconciliation, Filipino STT honesty, Riverpod mandate).

**However**, three architectural gaps prevent implementation from proceeding reliably:

1. **iOS notification extension architecture is undefined.** The spec requires background notification actions but doesn't define the cross-process database access, extension target, or App Group configuration. Without this, FR-8 ("Notification actions MUST work without opening the app") cannot be implemented on iOS.

2. **The mandated STT dependency (`speech_to_text`) cannot enforce the spec's on-device-only privacy requirement.** The whitelist includes a package that is architecturally incompatible with CC-6. The implementer must discover this incompatibility and build a custom bridge — but the spec doesn't call this out, creating a trap.

3. **Android notification reliability on Philippine-market devices is not architecturally addressed.** The spec acknowledges the problem in one sentence but provides no detection, mitigation, or user communication strategy for the case where most target devices silently kill background processes.

These three issues interact: they all affect the core value proposition (voice → notification → action). Resolving them requires specification changes, not just implementation decisions.

## 2. Critical Findings

| ID | Finding |
|----|---------|
| **C1** | iOS notification extension database access is architecturally undefined — no cross-process Drift strategy, no extension target in build plan, no shared container configuration |
| **C2** | Android notification reliability is undefined for force-stop and OEM kill — no missed-notification detection, no recovery transparency |
| **C3** | `flutter_local_notifications` + `speech_to_text` package assumptions have unexplored gaps — STT package cannot enforce on-device-only, and the notification package's background behavior assumptions are unverified |

## 3. High-Priority Findings

| ID | Finding |
|----|---------|
| **A3** | Contact resolution violates NLP purity claim — needs reclassification |
| **B1** | SpeechBridge contract is underspecified — missing error types, cancellation, lifecycle interruption |
| **B2** | NotificationBridge `reconcile()` contract is underspecified — missing return value, orphan cleanup |
| **DE1** | `speech_to_text` package incompatible with CC-6 (on-device-only requirement) |
| **BR1** | iOS notification extension target not defined in build configuration |
| **AI1** | Agent will treat `speech_to_text` as equivalent to custom bridge |
| **I1** | BGAppRefreshTask not reliable enough for designated reconciliation role |
| **AN1** | `EXTRA_PREFER_OFFLINE` is not a privacy guarantee on Android < 13 |
| **AN2** | OEM background restrictions in Philippine market not addressed |
| **NO1** | Reconciliation does not detect past missed notifications |
| **F1** | Riverpod scoping for background notification callbacks is undefined |
| **C3** (duplicate) | `speech_to_text` package incompatibility |

## 4. Blocking Decisions

1. **ADR-10:** Custom STT bridge vs. `speech_to_text` package — MUST resolve before Phase 4 (Platform Bridges)
2. **ADR-11:** Notification scheduling ownership (Application vs. Data layer)
3. **ADR-12:** iOS notification extension architecture (App Group, shared database, extension target)
4. **ADR-13:** Background execution dependency injection (Riverpod vs. service locator)
5. **ADR-14:** iOS database file protection class
6. **ADR-15:** Android OEM background reliability strategy

## 5. Recommended Architecture Changes

1. **Remove `speech_to_text` from dependency whitelist.** Mandate custom native STT bridge (CRITICAL).
2. **Add iOS notification extension target specification** — define cross-process database access, App Group, extension lifecycle, and build configuration (CRITICAL).
3. **Define missed-notification detection** — add `delivery_uncertain`/`delivery_missed` tracking to Trigger entity (HIGH).
4. **Define Application layer use cases** — `CreateReminderUseCase`, `HandleNotificationActionUseCase` — to clarify orchestration boundaries (HIGH).
5. **Define background execution service locator** — separate from Riverpod for notification callbacks (HIGH).
6. **Add Android OEM reliability strategy** — foreground service option, per-manufacturer guides, self-test (HIGH).
7. **Expand SpeechBridge contract** — add error types, cancellation, lifecycle interruption handling (MEDIUM).
8. **Expand NotificationBridge contract** — add `ReconciliationResult` return type, orphan cleanup (MEDIUM).
9. **Split ReminderDraft** into `ParsedReminder` (NLP output) and `ValidatedReminderDraft` (Application output) (MEDIUM).
10. **Add confidence scoring formula or deliberate deferral** — currently undefined (MEDIUM).
11. **Pin Flutter/Dart versions** (MEDIUM).
12. **Add CI network traffic verification** to automate CC-1 compliance (MEDIUM).

## 6. AI Coding-Agent Risk Summary

The biggest AI agent implementation risks (in order of likelihood × impact):

1. **Agent uses `speech_to_text` package → silently violates on-device privacy requirement.** The package is listed in the whitelist. An agent will choose it. Fix: remove from whitelist.
2. **Agent skips iOS notification extension target → background notification actions don't work.** The spec mentions App Group in one line. An agent will miss it. Fix: add explicit build requirements.
3. **Agent puts notification scheduling in UI callbacks → inconsistent error handling, duplicate scheduling.** The layer rules exist but no UseCase is defined. Fix: define `CreateReminderUseCase`.
4. **Agent doesn't handle Android OEM background killing → app gets 1-star reviews in Philippines.** The problem is acknowledged but no mitigation is defined. Fix: add detection + user guidance.
5. **Agent uses `google_fonts` with runtime fetching → introduces network requests.** The package is whitelisted and its default behavior fetches from Google. Fix: mandate bundling with explicit configuration.
6. **Agent builds NLP pipeline as single function → untestable.** Mitigated: stage interfaces are defined (§8.4). Risk: MEDIUM.
7. **Agent implements different notification behavior on iOS vs. Android.** Mitigated: CC-18 mandates identical business logic. Risk: LOW.

## 7. Minimum Required Changes Before ARCHITECTURE.md

To move this specification from NEEDS MAJOR REVISION to READY WITH MINOR CHANGES:

1. **Remove `speech_to_text` from the dependency whitelist** and add ADR-10 mandating custom native STT bridge (addresses C3, DE1, AI1).
2. **Add a dedicated section defining the iOS notification extension architecture** (§19.5.1 or new §17.5): App Group configuration, shared database path, extension target, initialization sequence, minimal data layer subset (addresses C1, BR1, D1).
3. **Add missed-notification detection fields** to the Trigger entity and define the reconciliation transparency mechanism (addresses C2, NO1, AN2).
4. **Define `CreateReminderUseCase`** as the single orchestration point for reminder creation, clarifying that the Application layer (not Data layer) calls NotificationBridge (addresses A1, AI2).
5. **Add the Android OEM reliability section** — foreground service option, self-test, per-manufacturer guidance during onboarding (addresses AN2).
6. **Define background execution service locator** — the non-Riverpod initialization path for notification callbacks (addresses F1).

**With these six changes**, the specification would be architecturally sound enough for a competent team or AI agent to begin implementation without inventing critical infrastructure.

---

*End of ARCHITECTURE_REVIEW.md*
