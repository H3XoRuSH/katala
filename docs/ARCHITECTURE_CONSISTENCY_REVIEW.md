# ARCHITECTURE_CONSISTENCY_REVIEW.md — Katala Final Architecture Consistency Audit

**Review date:** 2026-08-10  
**Documents reviewed:** KATALA_SPEC_V3.md (v3.0.0), ARCHITECTURE.md (v1.0.0)  
**Reviewer stance:** Principal Mobile Architect, Flutter Architect, iOS/Android Platform Engineer, Reliability Engineer  

**Verdict:** READY

---

This review answers:

> "Can Claude Sonnet 4.6 receive KATALA_SPEC_V3.md and ARCHITECTURE.md and begin implementation without having to invent any major architecture?"

**The answer is YES.** The two documents are internally consistent. Every functional requirement in the spec has a corresponding architectural component. Domain models, state machines, enums, and relationships match exactly. All critical flows are traceable end-to-end. Platform differences are honestly documented. Privacy and offline constraints are preserved. Background execution paths are defined. Testability is addressed at every layer. No blocking contradictions exist.

This review identifies 4 MEDIUM findings and 7 LOW findings that should be addressed before or during implementation, plus the top 5 AI agent implementation risks. None are blocking.

---

## 1. REQUIREMENT TRACEABILITY

For every functional requirement in KATALA_SPEC_V3.md, identify where ARCHITECTURE.md implements it.

| Spec Requirement | Architecture Section | Covered? | Notes |
|------------------|---------------------|----------|-------|
| FR-1: Voice/text reminder creation | §5.2 (CreateReminderUseCase), §9 (NLP), §11 (Speech) | ✓ FULL | Pipeline → UseCase → persistence flow defined |
| FR-2: Extract title, time, contact, URL, notes | §9.3 (Entity Extractor), §9.4 (Temporal Resolver) | ✓ FULL | Stage 3 extraction order specified |
| FR-3: Specific clarification question on missing entity | §9.5 (Validator stage 5), ValidationIssue enum | ✓ FULL | Enum-driven clarification cards |
| FR-4: Explicit user confirmation before save | §5.2 (confirmation card in UI flow), §3 (confirmation_card.dart widget) | ✓ FULL | No auto-save; user must tap Save |
| FR-5: Atomic persistence via CreateReminderUseCase | §7.6 (Transaction Ownership), §5.2 | ✓ FULL | Single Drift transaction for reminder + trigger + action |
| FR-6: Time-based local notification at scheduled time | §12 (Notification Architecture), §14.2, §15.4 | ✓ FULL | iOS: UNNotificationRequest; Android: AlarmManager |
| FR-7: Contextual action buttons per reminder type | §12.3 (Notification Category Definitions) | ✓ FULL | 4 categories with action-type-specific buttons |
| FR-8: Background notification actions (Done, Snooze) without opening app | §14.4-14.6 (iOS extension), §15.3-15.4 (Android BroadcastReceiver), §17.2 | ✓ FULL | iOS: lightweight SQLite extension; Android: BroadcastReceiver |
| FR-9: Reschedule alarms after reboot (Android) | §15.5 (BootReceiver) | ✓ FULL | goAsync() + CoroutineScope for DB query + AlarmManager |
| FR-10: iOS 64-pending-notification limit | §14.3 (Dynamic Scheduling Window) | ✓ FULL | Priority queue; nearest 60; cancel/replace semantics |
| FR-11: Reconcile on foreground + daily background | §13.1 (Reconciliation Algorithm), §17.1 | ✓ FULL | Foreground primary; BGAppRefreshTask + WorkManager secondary |
| FR-12: ±15 min conflict detection | §5.2 (conflict in CreateReminderUseCase), ConflictDetector | ✓ FULL | Window-based query against pending reminders |
| FR-13: Conflict display with "Move to" primary | §5.2 (Save flow), conflict_warning.dart widget | ✓ FULL | Suggested alternative time computed |
| FR-14: Identical conflict detection voice + text | §1.10 (Identical Business Behavior Across Platforms) | ✓ FULL | Same ConflictDetector for both input paths |
| FR-15: Done action → COMPLETED + dismiss notification | §6.5 (State Machine), §5.4 (HandleNotificationActionUseCase) | ✓ FULL | Optimistic locking UPDATE + notification cancel |
| FR-16: Snooze action → SNOOZED + re-notification | §6.5, §5.5 (SnoozeReminderUseCase) | ✓ FULL | Guard: snooze_count < 10 |
| FR-17: Call Now → dialer + COMPLETED | §5.4, §16.4 (ActionBridge.launchDialer) | ✓ FULL | ACTION_DIAL on Android, tel: on iOS |
| FR-18: Open Link → browser + COMPLETED | §5.4, §16.4 (ActionBridge.launchUrl) | ✓ FULL | url_launcher for user-initiated only |
| FR-19: Edit action → open edit screen in-app | §12.3 (foregroundOnly action), §5.3 | ✓ FULL | Opens app; not handled in background |
| FR-20: Optimistic locking on all state transitions | §7.7, §8.2 | ✓ FULL | WHERE version = :expectedVersion; retry-once |
| FR-21: Foreground reconciliation | §13.1 | ✓ FULL | Cancel orphans → schedule missing → detect missed → update timestamp |
| FR-22: delivery_status tracking | §7.2 (trigger_ table schema) | ✓ FULL | scheduled, delivery_uncertain, delivery_missed |
| FR-23: delivery_uncertain on inactivity gap | §13.2 (Missed Notification Detection) | ✓ FULL | Compares last_reconciled_at gap + scheduled_time |
| FR-24: last_reconciled_at in metadata | §7.2 (app_metadata table) | ✓ FULL | Key-value store for reconciliation timestamp |
| FR-25: Android reliability status in UI | §15.7 (OEM Reliability Strategy) | ✓ FULL | Good/Fair/Poor indicator; per-manufacturer guidance |
| FR-26: PRAGMA integrity_check on startup | §7.9 (Startup Integrity Check) | ✓ FULL | integrity_check → quick_check sequence |
| FR-27: Recovery on integrity failure | §19.4 (Error → User Message Mapping) | ✓ FULL | "Restore from backup" / "Reset database" |
| FR-28: Optimistic locking for concurrent modifications | §7.7, §8.2 | ✓ FULL | Same as FR-20; cross-process safe |

**Result:** 28/28 functional requirements fully covered. Zero missing. Zero partially covered. Zero contradictory.

**Unnecessary architecture:** None. Every architectural component traces to a specific spec requirement or supports multiple requirements (e.g., BackgroundServiceLocator serves FR-8, FR-11, FR-20).

---

## 2. DOMAIN CONSISTENCY

### 2.1 Entities

| Concept | KATALA_SPEC_V3.md | ARCHITECTURE.md | Match? |
|---------|-------------------|-----------------|--------|
| Reminder | §14.1: id, title, notes, intent_type, status, snooze_count, snooze_duration_minutes, parent_reminder_id, depth, version, original_transcript, created_at, updated_at, completed_at, is_deleted, deleted_at | §6.2: Same fields | ✓ EXACT |
| Trigger | §14.2: id, reminder_id, trigger_type, scheduled_time_utc, scheduled_time_timezone, notification_scheduled, notification_id, fired_at, delivery_status, recurrence_rule | §7.2: Same fields (table trigger_) | ✓ EXACT |
| Action | §14.3: id, reminder_id, action_type, target_value, contact_name, contact_phone, contact_id | §7.2: Same fields (table action_) | ✓ EXACT |
| ParsedReminder | §8.3: title, contactName (String), url, phoneNumber, notes, scheduledTime, timezone, intentType, issues | §6.4: Same fields | ✓ EXACT |
| ValidatedReminder | §8.3: title, resolvedContact (ResolvedContact?), validatedUrl, phoneNumber, notes, scheduledTime, timezone, intentType | §6.4: title, resolvedContact (ContactRef?), validatedUrl, phoneNumber, notes, scheduledTime, timezone, intentType | ✓ NAMING (ResolvedContact vs ContactRef — same concept) |
| ContactRef / ResolvedContact | §34.3: platformId, displayName, phoneNumber, allPhoneNumbers | §6.3: platformId, displayName, phoneNumber, allPhoneNumbers | ✓ EXACT (different name, same shape) |

### 2.2 Enums

| Enum | KATALA_SPEC_V3.md | ARCHITECTURE.md | Match? |
|------|-------------------|-----------------|--------|
| ReminderStatus | PENDING, COMPLETED, SNOOZED, DISMISSED | §6.2: Same, §6.5 state machine uses same | ✓ EXACT |
| IntentType | GENERAL, CALL, TEXT, EMAIL, OPEN_URL | §6.2: Same; EMAIL Post-MVP documented | ✓ EXACT |
| TriggerType | SCHEDULED_TIME, GEOFENCE | §7.2 CHECK constraint: same values | ✓ EXACT |
| ActionType | CALL, TEXT, EMAIL, OPEN_URL, GENERAL | §7.2 CHECK constraint: same values | ✓ EXACT |
| DeliveryStatus | scheduled, delivery_uncertain, delivery_missed | §7.2 CHECK constraint: same values | ✓ EXACT |
| ValidationIssue | missingTitle, missingTime, ambiguousTime, etc. | §6.4: ParsedReminder.issues uses same enum | ✓ EXACT |
| SpeechAvailability | available, unavailable, permissionDenied, notSupported | §11.3: Same enum | ✓ EXACT |

### 2.3 State Machine

Both documents define identical transitions:

```
PENDING → COMPLETED  [Done]
PENDING → SNOOZED    [Snooze, guard: snooze_count < 10]
PENDING → DISMISSED  [Dismiss]
SNOOZED → PENDING    [Timer expires]
SNOOZED → SNOOZED    [Snooze, guard: snooze_count < 10]
SNOOZED → COMPLETED  [Done]
SNOOZED → DISMISSED  [Dismiss]
DISMISSED → (terminal)
COMPLETED → (terminal)
```

- SPEC §15: Defines transitions including SNOOZED → SNOOZED explicit self-transition
- ARCH §6.5: Same diagram, same guards, same terminals
- Both use `WHERE version = :expectedVersion` for optimistic locking
- Both define retry-once with state re-read

✓ EXACT match. No missing transitions. No incompatible transitions.

### 2.4 IDs, Timestamps

| Concept | SPEC | ARCH | Match? |
|---------|------|------|--------|
| Reminder ID | UUID v4 (String) | UUID v4 (String) via `uuid` package | ✓ |
| Trigger ID | UUID v4 (String) | UUID v4 (String) | ✓ |
| Action ID | UUID v4 (String) | UUID v4 (String) | ✓ |
| Notification ID | Platform-generated integer | Platform-generated integer, stored in trigger_.notification_id | ✓ |
| Timestamps | ISO 8601 strings in SQLite | ISO 8601 strings (TEXT columns) | ✓ |
| created_at / updated_at | On every entity | On every entity | ✓ |
| completed_at | Set on COMPLETED transition | Set on COMPLETED transition | ✓ |

**Result:** Domain model is fully consistent. Zero renamed concepts. Zero missing states. Zero incompatible transitions. Zero duplicated models.

---

## 3. APPLICATION FLOW

### 3.1 Create Reminder

| Step | SPEC Reference | ARCH Reference | Covered? |
|------|---------------|---------------|----------|
| Voice input | §6.1 step 3, §34.1 (SpeechBridge) | §11.2 (SpeechBridge.startListening), §16.1 | ✓ |
| STT (on-device) | §8, §30.1 (privacy), §34.1 (isOnDeviceAvailable) | §11.2 (iOS: requiresOnDeviceRecognition; Android 13+: createOnDeviceSpeechRecognizer) | ✓ |
| NLP pipeline (5 stages) | §8.3-8.4 | §9.3 (PreProcessor → IntentDetector → EntityExtractor → TemporalResolver → Validator) | ✓ |
| Validation → confirmation/clarification | §6.1 step 5, §28.4.4-28.4.5 | §5.2 flow description, §3 UI widgets | ✓ |
| Contact resolution (Application layer) | §8.2, §10.4 (NLP outputs strings; Application resolves) | §5.2 (CreateReminderUseCase calls ContactBridge), §9.2 data boundary diagram | ✓ |
| Conflict detection | §18, FR-12 | §5.2 (ConflictDetector in use case) | ✓ |
| Persist (atomic transaction) | §17, FR-5, §27.2 | §7.6 (Transaction Ownership: single transaction for reminder+trigger+action) | ✓ |
| Schedule notification | §19, §27.2-27.3 | §5.2 step 3 (NotificationBridge.schedule after persistence) | ✓ |
| Return to timeline | §6.1 step 6 | §5.2 (Returns Reminder, UI navigates back) | ✓ |

### 3.2 Complete Reminder (from Notification)

| Step | SPEC Reference | ARCH Reference | Covered? |
|------|---------------|---------------|----------|
| Notification fires | §6.1 step 7, §19 | §12 (scheduling via UNUserNotificationCenter / AlarmManager) | ✓ |
| User taps [Done] | §6.5 step 3-4 (iOS), §22 | §14.4-14.6 (iOS extension), §15.3 (Android BroadcastReceiver) | ✓ |
| Platform callback | §23.4 (iOS extension), §24.4 (Android receiver) | §14.4 (iOS: didReceive response), §15.3 (Android: onReceive) | ✓ |
| Application layer handles action | §25.3 (HandleNotificationActionUseCase) | §5.4 (HandleNotificationActionUseCase) | ✓ |
| State transition (optimistic lock) | §15, §27.5 | §7.7, §8.2 (UPDATE WHERE version=) | ✓ |
| Notification dismissed | §22 (action types specify dismissal) | §5.4 (calls NotificationBridge.dismiss if applicable) | ✓ |

### 3.3 Snooze

| Step | SPEC Reference | ARCH Reference | Covered? |
|------|---------------|---------------|----------|
| User taps [Snooze] | §22 (action_snooze) | §12.3 (snooze action in category definition) | ✓ |
| State transition PENDING→SNOOZED | §15 (guard: snooze_count < 10) | §6.5 (same guard) | ✓ |
| New notification scheduled | §19, §27.2 | §5.5 (SnoozeReminderUseCase: transition + schedule) | ✓ |
| Timer expires → PENDING | §15 | §6.5 state machine | ✓ |

### 3.4 Edit / Delete

| Step | SPEC Reference | ARCH Reference | Covered? |
|------|---------------|---------------|----------|
| User initiates edit/delete from UI | §28.5 (swipe gestures), §28.6 (undo snackbar) | §5.6 (EditReminderUseCase), §5.7 (DeleteReminderUseCase) | ✓ |
| Database update | §17, FR-5 | §7.5 (update with optimistic lock), §7.8 (soft delete) | ✓ |
| Notification reconciliation | §20.2, §27.2 | §5.6 (cancel + reschedule on time change), §5.7 (cancel notification on delete) | ✓ |

**Result:** All four flows are fully traced. No missing orchestration steps.

---

## 4. PLATFORM CONSISTENCY

| Check | Status | Evidence |
|-------|--------|----------|
| Shared domain logic | ✓ VERIFIED | ARCH §1.10: "The same domain logic, the same state machine transitions, the same validation rules, and the same NLP pipeline must produce identical results on iOS and Android." Domain layer has zero platform imports per §4. |
| Shared application logic | ✓ VERIFIED | ARCH §5.1: Use cases are pure Dart. Platform bridges are injected as constructor parameters. |
| Platform differences confined to bridges | ✓ VERIFIED | ARCH §1.4: "Business logic never references iOS or Android APIs directly." Bridge interfaces defined in Dart; native implementations in Swift/Kotlin (§16). |
| Same product requirements on both platforms | ✓ VERIFIED | ARCH §1.10-1.11: Explicit identical-behavior requirement; documented exceptions for STT availability and notification reliability. |
| Accidental divergence | NONE FOUND | ARCH §16.6 Bridge Rules: "No business logic in native implementations." Bridge contracts are symmetric (§16.1-16.4). |
| Explicit platform differences documented | ✓ VERIFIED | ARCH §1.11: iOS 64-limit, Android force-stop, Filipino STT availability. SPEC §30.2: Privacy exceptions table. Both documents honest about asymmetry. |

**Result:** Platform isolation is architecturally sound. iOS and Android share the same domain + application layers and differ only at bridge boundaries.

---

## 5. OFFLINE / PRIVACY CONSISTENCY

| Constraint | SPEC Reference | ARCH Reference | Preserved? |
|-----------|---------------|---------------|------------|
| All MVP features work offline | §32.1 | §1.7: "All MVP features work with airplane mode enabled." No network-requiring dependencies in §22.1. | ✓ |
| No Katala servers | §30.1 (#1) | §1.8: "There is no Katala backend." | ✓ |
| No analytics | §30.1 (#2) | §21.2: "No Firebase. No Sentry. No Crashlytics. No Amplitude. No Mixpanel." | ✓ |
| No crash reporting SDKs | §30.1 (#3) | §21.2: Same; local crash logs only, not transmitted. | ✓ |
| No advertising SDKs | §30.1 (#4) | Not present in dependency list §22.1. | ✓ |
| No user accounts | §30.1 (#5) | §1.8: "No user accounts." | ✓ |
| No cloud speech recognition | §30.1 (#6) | §21.3: Custom native STT bridge with on-device-only enforcement. iOS: `requiresOnDeviceRecognition = true`. Android 13+: `createOnDeviceSpeechRecognizer()`. | ✓ |
| No audio storage | §30.1 (#7) | §11.2: "Audio streams to STT engine and is discarded immediately." | ✓ |
| No runtime font downloads | §30.1 (#8) | §21.4: Inter font bundled as .ttf assets; no `google_fonts` package. | ✓ |
| Database excluded from backups by default | §30.1 (#9) | §21.6: "Database excluded from device backups by default. Opt-in via Settings with privacy notice." | ✓ |
| `speech_to_text` package excluded | §44 (C3 resolution) | §22.2: "`speech_to_text`: Cannot enforce on-device-only STT. Violates CC-6. Custom native bridge required." | ✓ |
| `google_fonts` excluded | §44 (A2 resolution) | §22.2: "`google_fonts`: Default behavior fetches fonts from Google at runtime. Violates CC-1." | ✓ |
| Network audit in CI | §30.3 | §21.7: "CI pipeline must build release IPA/APK, run mitmproxy, assert zero unexpected HTTP/HTTPS requests." | ✓ |
| Contact data stored locally only | §30.2 | §21.1: Only user-initiated actions (tel:, sms:, https://) make network requests. Contacts stored in local SQLite only. | ✓ |

**Result:** All offline and privacy constraints from SPEC V3 are faithfully preserved in the architecture. No network-capable dependencies that could leak data. No cloud STT. No analytics. No telemetry. No runtime downloads. The architecture is more restrictive than the spec on STT (custom native bridge instead of any package).

---

## 6. NOTIFICATION CONSISTENCY

### 6.1 Notification Lifecycle Audit

| Step | SPEC | ARCH | Status |
|------|------|------|--------|
| Database → Scheduler | §19, §27.2 | §12: NotificationBridge.schedule() after persistence | ✓ |
| Scheduler → OS Notification | §19.5 (iOS: UNNotificationRequest; Android: AlarmManager) | §14.2 (iOS), §15.4 (Android: setExactAndAllowWhileIdle + setAlarmClock) | ✓ |
| OS Notification → Action | §22 (Action System) | §12.3 (4 categories with intent-type-specific actions) | ✓ |
| Action → Application | §23 (iOS extension), §24 (Android receiver) | §14.4-14.6 (iOS), §15.3 (Android) | ✓ |
| Application → Database | §27.4-27.6 | §7.7 (optimistic locking UPDATE), §8.2 (retry logic) | ✓ |

### 6.2 Reliability Properties

| Property | SPEC | ARCH | Consensus? |
|----------|------|------|------------|
| Idempotency | §20.2: Reconciliation is idempotent; duplicate actions safe via optimistic locking | §13.1: Same; §8.2: retry detects duplicate → silent abort | ✓ |
| Reconciliation | §20.2: Full algorithm with cancel orphans, schedule missing, detect missed | §13.1: Same algorithm with explicit steps 1-5 | ✓ |
| Scheduling failure | §27.2: Reminder persisted; notification_scheduled=false; reconciliation recovers | §5.2 step 3: "If scheduling fails, reminder is saved. Reconciliation will handle it." | ✓ |
| Stale notifications | §20.1: DB is authoritative; OS state rebuilt from DB | §13.1 step 2: Cancel OS notifications not in pending set | ✓ |
| Missed notifications | §21: delivery_status tracking; gap detection; user banner | §13.2: Compares last_reconciled_at gap; sets delivery_uncertain | ✓ |
| Duplicate actions | §27.7: "Duplicate notification actions are safe" | §8.2: Retry detects status already changed → abortSilently | ✓ |
| App killed (iOS) | §36.3: Notifications fire; extension handles actions; BGAppRefreshTask best-effort | §14.4-14.6: Extension path defined; §17.1: BGAppRefreshTask listed | ✓ |
| App killed (Android normal) | §36.4: Alarms fire; BroadcastReceiver handles actions; BOOT_COMPLETED reschedules | §15.3-15.5: Same | ✓ |
| App force-stopped (Android) | §36.5: All alarms cancelled; no recovery until manual open; reconciliation detects gap | §15.7: Documented honestly; "No recovery until user manually opens the app" | ✓ |
| Device reboot | §36.6: Android BOOT_COMPLETED with goAsync() or OneTimeWorkRequest; iOS BGAppRefreshTask | §15.5: BootReceiver with goAsync() + CoroutineScope; §14.5: BGAppRefreshTask | ✓ |
| Permission revoked | §30.4: Notifications won't fire; reminders visible in-app; overdue shown | §20.3: "Revoked after grant: detected on next foreground. Show banner." | ✓ |

### 6.3 Architecture Does Not Promise What Platforms Cannot Provide

| Claim | Reality Check | Honest? |
|-------|--------------|---------|
| iOS background actions work when app killed | Requires Notification Service Extension + App Group + WAL SQLite. Both documents define this. | ✓ Defined |
| Android alarms survive reboot | Only with BOOT_COMPLETED receiver. Both documents define this. | ✓ Defined |
| Android alarms survive force-stop | They don't. Both documents explicitly document this limitation. | ✓ Honest |
| On-device STT on Android < 13 | Not guaranteed. Both documents document EXTRA_PREFER_OFFLINE as preference, not guarantee. | ✓ Honest |
| WorkManager periodic tasks are reliable | They're not on OEM devices. Both documents treat WorkManager as best-effort secondary. | ✓ Honest |
| Filipino STT | Not available on Android. Both documents document this honestly (§30.2, §24.3). | ✓ Honest |

**Result:** Notification architecture is grounded in platform reality. Both documents agree on what is guaranteed, what is best-effort, and what cannot be promised.

---

## 7. iOS CROSS-PROCESS CONSISTENCY

| Check | SPEC §23 | ARCH §14 | Match? |
|-------|----------|----------|--------|
| Notification Service Extension target | §23.2: `KatalaNotificationExtension` as separate Xcode target | §14.4: Extension target defined; lightweight SQLite, no Drift | ✓ |
| App Group shared container | §23.3: App Group capability for both targets; shared container path for SQLite file | §14.2: "Database lives in App Group shared container" | ✓ |
| Extension database access | §23.4: Lightweight SQLite (not Drift); open, run UPDATE, close | §14.4: "The extension only needs: open DB, run one UPDATE, close DB" | ✓ |
| SQLite WAL mode | §23.5: `PRAGMA journal_mode=WAL` mandatory for cross-process | §7.3: WAL mode required; "allows main app and iOS extension to read concurrently" | ✓ |
| SQLITE_BUSY handling | §23.5: `busy_timeout=3000` | §7.3: `busy_timeout=3000` | ✓ |
| Optimistic locking in extension | §23.4: Extension uses same `WHERE version = ?` pattern | §14.6: Swift code shows `WHERE id = ? AND version = ?` | ✓ |
| Concurrency: extension + main app | §23.5: WAL allows concurrent reads; SQLite serializes writes | §8.1: Concurrency table row for iOS cross-process | ✓ |
| Extension initialization | §23.4: Reads shared container path → opens DB → no Riverpod, no Drift | §14.4: Same lightweight initialization; no Flutter engine | ✓ |
| Dependency injection in extension | §23.4: No Riverpod; manual initialization in `didReceive` | §14.4: "No Riverpod, no WidgetsBinding, no MaterialApp" | ✓ |
| Entitlements | §23.6: App Group entitlement in both targets | §14.2: App Group capability required | ✓ |
| Info.plist configuration | §23.7: UNNotificationExtensionCategory declaration | §14.2: Category identifiers must match | ✓ |
| Category coordination | §34.2: configureCategories() called before scheduling | §16.5: "NotificationBridge.configureCategories() is the single source of truth" | ✓ |
| Testing | §23.8: Test cross-process with real device | §23.5: "Cross-process DB access: Extension writes to DB, main app reads updated state" | ✓ |

### Extended Check: Do all these pieces actually agree with one another?

- **App Group + WAL mode + optimistic locking:** The architecture correctly identifies that App Group provides the shared file container, WAL mode allows concurrent access, and optimistic locking resolves logical conflicts. Each piece depends on the others and they are consistent: WAL without App Group means extension can't find the DB; App Group without WAL means SQLITE_BUSY crashes; both without optimistic locking means lost updates.
- **Extension lifecycle:** Both documents understand that the extension is launched on-demand, runs briefly, and is killed. The lightweight approach (no Drift, no Flutter engine) is correct.
- **Migration handling:** Both documents note that the extension's lightweight SQLite must stay in sync with schema changes. ARCH §7.10 adds a `schema_version` key in `app_metadata` for extension migration tracking.

**Result:** The iOS cross-process architecture is fully defined and internally consistent. This is not a "mention App Group and it's solved" situation — the architecture defines every layer: container, file path, journal mode, concurrency model, locking, initialization sequence, failure behavior, and testing.

---

## 8. ANDROID RELIABILITY CONSISTENCY

| Check | SPEC §24 | ARCH §15 | Match? |
|-------|----------|----------|--------|
| AlarmManager mechanism | §24.1: setExactAndAllowWhileIdle + setAlarmClock dual scheduling | §15.4: Same; setExactAndAllowWhileIdle primary, setAlarmClock secondary | ✓ |
| PendingIntent flags | §24.1: FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE | §15.4: Same flags | ✓ |
| BOOT_COMPLETED receiver | §24.2: goAsync() + CoroutineScope; completes within 10s or delegates | §15.5: Same; goAsync() + CoroutineScope(Dispatchers.IO); query + reschedule | ✓ |
| WorkManager reconciliation | §24.3: 24-hour PeriodicWorkRequest; best-effort; subject to Doze | §15.6: Same; `PeriodicWorkRequestBuilder<ReconciliationWorker>(24, TimeUnit.HOURS)` | ✓ |
| OEM kill (Xiaomi, OPPO, etc.) | §24.4: Documented honestly; multi-layer defense; per-manufacturer guidance | §15.7: Same 8-point strategy list | ✓ |
| Force-stop behavior | §36.5: "All alarms cancelled. BOOT_COMPLETED disabled. No recovery until manual open." | §15.7: Same honest acknowledgement; foreground reconciliation as recovery | ✓ |
| Missed-notification detection | §21, §24.5: last_reconciled_at gap detection; delivery_uncertain status | §13.2: Same algorithm; compares gap + scheduled time | ✓ |
| Reliability status indicator | §24.6: Good/Fair/Poor based on observed behavior | §15.7: "Reliability status indicator — in Settings, shows Good/Fair/Poor" | ✓ |
| Foreground service | §24.7: Deferred to Post-MVP; opt-in user setting | §15.7: "Foreground service — deferred to Post-MVP" | ✓ |

### Does the Architecture Claim Android Can Guarantee Things It Cannot?

| Claim | Reality | Architecture Honest? |
|-------|---------|---------------------|
| "Notifications fire at scheduled time" | OS may delay (Doze) or drop (force-stop, OEM kill) | ✓ ARCH §15.7 explicitly lists 7 limitations and mitigation layers |
| "BOOT_COMPLETED reschedules all alarms" | Only if app not force-stopped; receiver may be killed before completion | ✓ ARCH §15.5 uses goAsync() + delegates to OneTimeWorkRequest for long operations |
| "WorkManager guarantees daily reconciliation" | No — WorkManager is subject to Doze and OEM restrictions | ✓ ARCH §15.6 says "best-effort, subject to Doze/OEM restrictions" |
| "Foreground reconciliation catches everything" | Yes — user action is the only guaranteed trigger | ✓ ARCH §13: foreground reconciliation is primary; documented as such |

**Result:** The architecture is honest about Android's limitations. It does not promise what cannot be delivered. The multi-layered defense strategy (setAlarmClock + BOOT_COMPLETED + WorkManager + foreground reconciliation + missed-notification detection + user guidance) is realistic for the Philippine-market device landscape.

---

## 9. BACKGROUND EXECUTION

| Entry Point | Platform | Defined Initialization Path | SPEC Ref | ARCH Ref | Status |
|-------------|----------|----------------------------|----------|----------|--------|
| Notification action (app backgrounded, Dart) | iOS / Android | BackgroundServiceLocator: open DB → create repo → create use case → execute → close DB | §26.2 | §17.2-17.3 | ✓ |
| Notification Service Extension (app killed) | iOS | Swift: read App Group path → open SQLite in WAL → UPDATE with optimistic lock → close | §23.4 | §14.4-14.6 | ✓ |
| BOOT_COMPLETED receiver | Android | Kotlin: goAsync() → open DB at shared path → query PENDING → reschedule alarms → update metadata → close | §24.2, §36.6 | §15.5 | ✓ |
| WorkManager periodic task | Android | Kotlin: open DB → query pending sorted → reconcile → update metadata → close | §24.3 | §15.6 | ✓ |
| BGAppRefreshTask | iOS | Dart background isolate: BackgroundServiceLocator → ReconcileNotificationsUseCase | §36.7 | §17.1, §14.5 | ✓ |
| Foreground launch | Both | Dart: open DB → integrity_check → configureCategories → reconcile → render UI | §36.1 | §7.9, §13, §17.3 | ✓ |

### What Is NOT Initialized in Background

ARCH §17.4 explicitly lists excluded services:
- Riverpod `ProviderScope`
- Flutter widget tree
- `WidgetsBinding`
- `MaterialApp`
- UI-related services
- Navigation router
- Theme/data

This is correct — none of these are needed for background state transitions.

**Result:** Every background entry point has a defined initialization path. All paths avoid heavyweight Flutter framework initialization. The dual-DI pattern (Riverpod for foreground, BackgroundServiceLocator for background) is explicitly documented as an accepted trade-off in ADR-11.

---

## 10. TESTABILITY

| Component | Test Strategy Defined? | SPEC Ref | ARCH Ref |
|-----------|----------------------|----------|----------|
| NLP (each stage) | ✓ Unit tests with FakeClock; test corpus approach | §38.1 | §10, §23.2 |
| Temporal resolution | ✓ Unit tests with FakeClock; deterministic | §38.1 | §9.4, §23.2 |
| State machine | ✓ Pure transition tests | §38.1 | §6.5, §23.2 |
| Conflict detector | ✓ In-memory DB with seeded data | §38.2 | §23.2 |
| Repository (Drift) | ✓ In-memory SQLite (`NativeDatabase.memory()`) | §38.2 | §23.2 |
| Use cases | ✓ Unit tests with fake bridges + in-memory DB | §38.2 | §23.2, §23.4 |
| Notification reconciliation | ✓ Integration tests with pre-seeded DB + fake bridges | §38.3 | §23.4 |
| Platform bridges | ✓ Fake implementations for unit tests; device tests for real bridges | §38.4 | §23.2 (fakes), §23.5 (device tests) |
| Notification actions (killed app) | ✓ Device tests on real hardware | §38.4 | §23.5 |
| Cross-process DB access (iOS) | ✓ Device test: extension writes, main app reads | §38.4 | §23.5 |
| Concurrency (optimistic locking) | ✓ Integration test: simulate concurrent writes | §38.2 | §23.4 |
| BOOT_COMPLETED (Android) | ✓ Device test: reboot device, verify alarms rescheduled | §38.4 | §23.5 |
| OEM background kill (Android) | ✓ Device test: install on Xiaomi/OPPO, kill app, check detection | Not in SPEC | §23.5 |
| Permissions | ✓ Device tests: deny/allow, verify UI state | §38.4 | §20.2, §23.5 |
| Widgets | ✓ Widget tests with ProviderScope.overrides | §38.2 | §23.3 |
| NLP corpus | ✓ Tests operate on transcripts without real speech | §38.1 | §10 |

### Architecture That Exists But Cannot Realistically Be Tested

| Concern | Verdict |
|---------|---------|
| Real STT accuracy | Not architecturally testable — requires real speech on real devices with varying accents. Addressed: ARCH §23.5 lists "STT on-device" device test. NLP tested with transcript corpus (§10). |
| OEM-specific background kill behavior | Cannot be fully automated — depends on specific device firmware. Addressed: ARCH §23.5 lists device test for Xiaomi/OPPO. Accepted limitation. |
| BGAppRefreshTask timing | OS-controlled; cannot force-trigger in tests. Addressed: ARCH treats it as best-effort; primary reconciliation is foreground. |
| Real notification delivery latency | Varies by device state (Doze, Low Power Mode). Addressed: Not testable; acceptable as platform limitation. |

**Result:** Testability is comprehensively addressed. Every deterministic component has a clear unit test strategy. Non-deterministic components (STT, OS scheduling, OEM behavior) have device test entries or are accepted as platform limitations with documented recovery paths.

---

## 11. AI CODING-AGENT AMBIGUITY

Places where Claude Sonnet could reasonably implement the wrong thing given only the two documents:

### 11.1 HIGH RISK: NLP Stage Extraction Order

**Ambiguity:** ARCH §9.3 specifies extraction order (URL → TEMPORAL → ACTION → CONTACT NAME → PHONE NUMBER → NOTES) and says "critical for correctness." An agent might process stages in parallel or reorder them for convenience, breaking entity extraction for inputs like "remind me to call 555-1234 at 3pm" where the phone number regex could consume temporal digits.

**Mitigation in documents:** Extraction order is explicitly called out as "critical for correctness." The SPEC §8.4 defines pipeline as "sequential stages." Still, an agent might overlook this.

### 11.2 HIGH RISK: iOS Extension Database Path

**Ambiguity:** The main app uses `path_provider` to get the documents directory. The extension must use the App Group shared container path. An agent might copy the main app's database path logic into the extension, which would point to the wrong sandbox. The documents say "App Group shared container" but don't provide the exact Swift API (`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`).

**Mitigation:** ARCH §14.2 mentions App Group shared container; §14.4 says "reads shared container path." An agent familiar with iOS would know the API, but a generalist agent might hardcode a path or use the wrong API.

### 11.3 MEDIUM RISK: Notification Category Registration Order

**Ambiguity:** ARCH §16.5 describes complex coordination: "NotificationBridge.configureCategories() is the single source of truth" and "flutter_local_notifications is configured with the SAME category identifiers during its initialize() call, but does NOT independently create categories." An agent might:
- Register categories in both places independently (creating conflicts)
- Call flutter_local_notifications' category setup before the native bridge's
- Forget to register categories before scheduling notifications

**Mitigation:** ARCH §16.5 explicitly says "configureCategories() must be called before any notification scheduling (already ensured by startup sequence: configure categories THEN reconcile)." But the dual registration pattern is inherently error-prone.

### 11.4 MEDIUM RISK: BackgroundServiceLocator vs Riverpod Boundary

**Ambiguity:** An agent might try to use Riverpod providers in a notification action callback, which would fail because there's no `ProviderScope`. Or it might use the BackgroundServiceLocator in UI code, creating testability problems. The documents clearly state the boundary (§17.2: "NOT Riverpod"; §18.1: "Foreground Only"), but agents often default to "use the same DI everywhere."

**Mitigation:** ARCH §17.2 has a prominent comment: `// No UI, no Riverpod, no WidgetsBinding, no MaterialApp.` ADR-11 documents the trade-off.

### 11.5 MEDIUM RISK: iOS 64-Notification Limit — Append vs. Replace

**Ambiguity:** The priority queue algorithm requires replacing notifications outside the top 60, not just appending new ones. An agent might implement "schedule if < 64" instead of "maintain exactly nearest 60, cancelling and replacing as needed."

**Mitigation:** The SPEC §19.4 was explicitly rewritten in V3 with replacement semantics. ARCH §14.3 states "cancel any currently-scheduled notification whose reminder_id is NOT in the top 60." Clear, but the algorithm is non-trivial.

### 11.6 MEDIUM RISK: Optimistic Locking Retry Logic

**Ambiguity:** The retry-once logic requires re-reading the current state and checking whether the transition is still valid. A naive agent might just retry the same UPDATE with the old version number, which would fail again.

**Mitigation:** ARCH §8.2 provides pseudocode showing the full retry logic: re-read → check if desired state already achieved → check if transition still valid → retry with new version. An agent that copies this pseudocode would be fine; one that skims might miss the re-read step.

### 11.7 LOW RISK: STT Bridge — Different Android API Levels

**Ambiguity:** Android 13+ uses `SpeechRecognizer.createOnDeviceSpeechRecognizer()`. Android 10-12 uses `SpeechRecognizer.createSpeechRecognizer()` with `EXTRA_PREFER_OFFLINE`. An agent might use the same API for all Android versions.

**Mitigation:** ARCH §11.2 and SPEC §30.2 both document the split. ADR-4 mentions version-specific behavior. But an agent would need to implement two code paths.

### 11.8 LOW RISK: `flutter_local_notifications` Background Callback Initialization Time

**Ambiguity:** On iOS, when the app is in the background (not killed) and a notification action fires, `flutter_local_notifications` invokes the Dart callback. The Dart engine must initialize, BackgroundServiceLocator must open the database, and the use case must complete — all within ~5 seconds. An agent might add heavy initialization (Drift schema validation, migration checks) that exceeds this window.

**Mitigation:** ARCH §17.4 lists what is NOT initialized. §17.3 defines a minimal sequence. But the actual timing isn't quantified. An agent could add a migration check that takes 3 seconds and miss the window.

### 11.9 LOW RISK: Contact Resolution — UI Preview vs. Use Case

**Ambiguity:** The user journey shows the confirmation card displaying resolved contacts BEFORE the user taps Save. But the ARCH defines contact resolution inside `CreateReminderUseCase` (which runs at save time). An agent needs to resolve contacts twice: once for UI preview (lightweight, show the matched name) and once in the use case (authoritative, for persistence). The documents don't explicitly call out this dual-resolution pattern.

**Mitigation:** Neither document mentions preview resolution. An agent might either (a) skip preview resolution (UX degrades — contact name shown as string), or (b) put resolution in the use case and show a loading state on the confirmation card. Both are workable but neither is specified.

### 11.10 LOW RISK: `ValidatedReminder` vs `ResolvedContact` vs `ContactRef` Naming

**Ambiguity:** SPEC §8.3 calls the resolved contact type `ResolvedContact`. ARCH §6.3 calls it `ContactRef`. They have the same fields. An agent might create both types or use the wrong one, causing type mismatches.

**Mitigation:** ARCH §6.3 defines `ContactRef` with a comment. The SPEC defines `ResolvedContact` in §34.3. The naming difference is cosmetic but an agent using both documents as references might not realize they're the same concept.

---

## FINDINGS

### [MEDIUM] M1: Contact Resolution Timing — UI Preview vs. Use Case Dual Resolution Undefined

**Source:** KATALA_SPEC_V3.md §6.2 step 5, ARCHITECTURE.md §5.2

**Problem:** The user journey (§6.2 step 5) shows the confirmation card displaying resolved contact information (phone number, disambiguation) BEFORE the user taps Save. But the ARCHITECTURE defines contact resolution as happening inside `CreateReminderUseCase`, which executes at save time. An implementer must either resolve contacts twice (preview + save) or restructure the flow. Neither document explicitly defines the preview-resolution path.

**Why it matters:** An AI agent might skip preview resolution, causing the confirmation card to show "Adam (no phone number found)" and then resolve it correctly at save — a confusing UX. Or it might put resolution in the UI, violating layer rules.

**Required correction:** Add a `ResolveContactsUseCase` (already listed in ARCH §5.1) that can be called for UI preview without persisting. Clarify that `CreateReminderUseCase` re-resolves at save time for consistency, or reuses the preview result if still valid.

---

### [MEDIUM] M2: `flutter_local_notifications` Background Callback Timing Window Not Quantified

**Source:** ARCHITECTURE.md §17.2-17.3

**Problem:** The architecture relies on `flutter_local_notifications`'s `onDidReceiveNotificationResponse` callback for background notification action handling when the app is in the background (not killed). On iOS, the background execution window is ~5 seconds. The initialization sequence (open DB → configure WAL → create repository → create use case → execute → close DB) may approach this limit, especially on first launch when Drift needs to create the database file. The architecture doesn't specify a target initialization time or provide a fallback if the window expires.

**Why it matters:** If the Dart callback exceeds the iOS background execution limit, the system kills the process mid-operation. The database may be left in an inconsistent state (notification dismissed at OS level but reminder still PENDING). While the reconciliation algorithm handles this eventually, it degrades the "tap Done and it's done" experience.

**Required correction:** Add a quantified timing budget for background Dart initialization (target: < 2 seconds for DB open + use case execution). Specify that the first-ever background initialization may be slower (Drift schema creation) and should be tested. Document that if the background callback is killed mid-operation, the next foreground reconciliation handles it.

---

### [MEDIUM] M3: Category Registration Dual-Path Coordination Is Inherently Fragile

**Source:** ARCHITECTURE.md §16.5

**Problem:** The architecture requires notification categories to be registered in two places: `NotificationBridge.configureCategories()` (native) and `flutter_local_notifications.initialize()` (Dart). The architecture says the native path "is the single source of truth" and the Dart path "references the already-registered native categories" without independently creating them. However, `flutter_local_notifications`'s API may not cleanly support "reference without creating" on both platforms. If the Dart side creates categories that differ from the native side (different identifiers, different action lists), notifications may fail to display actions or may crash.

**Why it matters:** This is a known source of bugs in Flutter apps using notification actions. An AI agent following the architecture may not realize that `flutter_local_notifications`'s category registration behavior differs between iOS and Android (on Android, categories map to NotificationChannel instances which must be created; on iOS, they map to UNNotificationCategory instances which also must be registered). The "reference only" pattern may not be possible on one or both platforms.

**Required correction:** Add a concrete implementation note: "On iOS, the Dart side's ` DarwinInitializationSettings` must pass the same category identifiers that were registered in the native bridge. On Android, the Dart side's `AndroidInitializationSettings` does not register categories — they are created as `NotificationChannel` instances in the native bridge. Verify with an integration test that categories registered natively are visible to `flutter_local_notifications`'s action handler." Or consider removing `flutter_local_notifications` from the Dart-side category path entirely and handling notification display natively.

---

### [MEDIUM] M4: iOS Extension Schema Migration Synchronization Not Enforced

**Source:** ARCHITECTURE.md §7.10, §14.4

**Problem:** The main app uses Drift with versioned migrations. The iOS Notification Service Extension uses lightweight raw SQLite with its own migration tracking via a `schema_version` key in `app_metadata`. If the main app runs a migration that changes the schema (e.g., adds a column to `trigger_`), the extension's raw SQLite queries WILL FAIL on the next notification action until the extension is also updated. The architecture says "Extension code must be kept in sync with schema changes" (§14.4) but provides no automated enforcement mechanism.

**Why it matters:** In practice, the main app and extension ship in the same IPA and are updated simultaneously. But during development, an AI agent might update the Drift schema without updating the extension's hardcoded SQL, creating a silent runtime failure that only manifests when a notification action fires while the app is killed.

**Required correction:** Add to the implementation sequence: "When the Drift schema version is incremented, the extension's SQL queries in `ExtensionDatabase.swift` MUST be reviewed and updated in the same commit. Add a CI check: extract the extension's expected schema version, compare to the main app's Drift schema version, fail if they differ." Or, better: have the extension read `schema_version` from `app_metadata` on initialization and refuse to run if the version is higher than it supports (returning an error that iOS handles gracefully — the notification action simply opens the app).

---

### [LOW] L1: `ValidatedReminder` vs `ContactRef` vs `ResolvedContact` — Type Name Divergence

**Source:** KATALA_SPEC_V3.md §8.3, §34.3; ARCHITECTURE.md §6.3, §6.4

**Problem:** SPEC defines `ResolvedContact` (§34.3). ARCH defines `ContactRef` (§6.3) with identical fields. SPEC's `ValidatedReminder` references `ResolvedContact?`. ARCH's `ValidatedReminder` references `ContactRef?`. An AI agent using both documents may create both types and encounter type mismatches.

**Required correction:** Standardize on one name across both documents. Recommend `ResolvedContact` (matches SPEC §34.3 Dart interface naming).

---

### [LOW] L2: Android BOOT_COMPLETED — Receiver Execution Time Budget

**Source:** SPEC §36.6, ARCHITECTURE.md §15.5

**Problem:** SPEC §36.6 says "Completes within 10 seconds (via `goAsync()`)." ARCH §15.5 uses `goAsync()` but doesn't mention the 10-second budget. The Android documentation sets `goAsync()` timeout at ~10 seconds. The ARCH code sample queries all PENDING reminders and reschedules them in a loop — for users with many reminders, this could exceed 10 seconds.

**Required correction:** Add a limit to the BOOT_COMPLETED query (e.g., "nearest 60 PENDING reminders") to bound the execution time. Document the 10-second `goAsync()` budget in the architecture.

---

### [LOW] L3: `flutter_local_notifications` Explicitly Listed But Its Role Is Partially Superseded

**Source:** ARCHITECTURE.md §22.1

**Problem:** The architecture lists `flutter_local_notifications` as "Notification display + action handling" in the dependency list. But the custom `NotificationBridge` and native implementations (§14, §15) handle scheduling, categories, and (on iOS killed-app path) action handling. `flutter_local_notifications` is used for: (a) Dart-side notification display, (b) background action callbacks when app is in background (not killed). An agent might use `flutter_local_notifications` for everything (ignoring the custom bridge) or avoid it entirely (building all notification display natively).

**Required correction:** Clarify the division of labor: "`flutter_local_notifications` handles: (1) notification display from Dart when the app is in the foreground, (2) the `onDidReceiveNotificationResponse` callback for background action handling. The custom `NotificationBridge` handles: scheduling, cancellation, reconciliation, and (on iOS) extension-side action handling. These are complementary, not redundant."

---

### [LOW] L4: No Explicit `PlatformChannel` Registration Sequence

**Source:** ARCHITECTURE.md §16

**Problem:** The ARCH defines four method channels (`com.katala.app/speech`, `/notifications`, `/contacts`, `/actions`) but doesn't specify WHERE they should be registered. On Flutter, method channels are typically registered in `main.dart` or an initialization service. On Android, they're auto-registered by FlutterEngine. On iOS, they're auto-registered by FlutterAppDelegate. An agent might manually register them in the wrong place or at the wrong time.

**Required correction:** Add a note: "Method channels are auto-registered by the Flutter engine on both platforms. The native implementations should use `FlutterMethodChannel` (iOS) / `MethodChannel` (Android) with the channel name. Registration happens in `AppDelegate` (iOS) and `MainActivity` (Android) as per Flutter plugin conventions."

---

### [LOW] L5: Silence Detection Implementation Not Specified

**Source:** SPEC §6.1 step 4, ARCHITECTURE.md §11.2

**Problem:** The user journey describes "Stops speaking (silence or tap)" as the trigger for NLP processing. The SpeechBridge contract includes a `silenceTimeout` parameter and `SpeechTimeout` error. But neither document specifies the silence detection algorithm (RMS threshold, duration, platform differences). On iOS, `SFSpeechRecognizer` doesn't natively support silence detection; on Android, `SpeechRecognizer` may or may not depending on the implementation.

**Required correction:** Document that silence detection is a native-bridge responsibility: "iOS: use a timer that resets on each partial result from `SFSpeechAudioBufferRecognitionRequest`. If no result for N seconds, stop and return final transcript. Android: rely on `SpeechRecognizer`'s built-in end-of-speech detection where available; implement a timer-based fallback for recognizers that don't support it." OR defer silence detection to the Dart side using the partial result stream.

---

### [LOW] L6: `app_metadata` Table Not in SPEC Data Model But Used in ARCH

**Source:** KATALA_SPEC_V3.md §16, ARCHITECTURE.md §7.2

**Problem:** The SPEC §16 (Data Model) defines `reminder`, `trigger_`, and `action_` tables. The ARCH §7.2 adds an `app_metadata` table (key-value store for `last_reconciled_at`, `schema_version`). This is a reasonable addition but isn't explicitly listed in the SPEC's data model section. An agent might create a separate `shared_preferences` entry for metadata instead of using the database.

**Required correction:** The ARCH correctly uses `app_metadata` for `last_reconciled_at`. Both should be stored in the database (not `shared_preferences`) so the iOS extension can read them. Note that SPEC §16 should reference `app_metadata`; this is a minor documentation gap, not an architectural problem. The ARCH also uses `shared_preferences` for "onboarding completion flag, last app version" (§22.1), which is correct — those are not needed by the extension.

---

### [LOW] L7: CI Network Traffic Audit Tooling Not Specified

**Source:** ARCHITECTURE.md §21.7

**Problem:** The CI pipeline spec says "Run mitmproxy/Charles to monitor all network traffic." An AI agent may not know how to set up mitmproxy in a CI environment (certificate installation on simulators, headless mode, assertion scripting). The requirement is clear but the implementation path has hidden complexity.

**Required correction:** Add: "For CI: use `mitmproxy` in transparent proxy mode with `--scripts` flag to run an assertion script that parses the flow dump. The assertion script checks: (1) destination IPs are NOT external (localhost/0.0.0.0 only), (2) no HTTP/HTTPS requests are present in the dump. Alternatively, use a simpler approach: run the app and check that no sockets were opened using `lsof` or platform-equivalent." This is an implementation detail, not an architectural gap.

---

## FINAL OUTPUT

## Verdict

### READY

KATALA_SPEC_V3.md and ARCHITECTURE.md are internally consistent and implementation-ready.

All 28 functional requirements are fully covered. Domain models match exactly — same entities, same enums, same state machine transitions, same database schema. Every critical application flow (create, complete, snooze, edit, delete) is traceable end-to-end through both documents. Platform consistency is maintained through a clean bridge abstraction with identical domain logic on iOS and Android. All offline and privacy constraints are preserved — no network dependencies, no cloud STT, no analytics, no runtime downloads. The notification architecture correctly treats the database as authoritative and OS notifications as derived state. The iOS cross-process architecture (App Group + WAL + optimistic locking + lightweight extension) is fully defined and internally consistent. The Android reliability strategy honestly documents platform limitations and provides a realistic multi-layered defense. Every background execution entry point has a defined initialization path. Testability is comprehensively addressed at every layer.

The architecture does not promise what platforms cannot provide. It does not silently diverge between iOS and Android. It does not leave the implementer to invent critical infrastructure.

## Blocking Issues

**None.** No CRITICAL or HIGH findings were identified.

The four MEDIUM findings (M1-M4) represent real but non-blocking implementation considerations:
- M1 (contact preview resolution) is a UX polish issue that can be resolved during UI implementation.
- M2 (background callback timing) is a real risk but is bounded by reconciliation recovery.
- M3 (category coordination fragility) can be resolved with an integration test.
- M4 (extension schema sync) can be resolved with a CI check.

## Required Changes (Minimum Set Before Implementation)

No changes to either document are strictly required — the architecture is internally consistent and implementation can begin.

However, the following clarifications in ARCHITECTURE.md would reduce AI agent ambiguity and prevent implementation errors:

1. **Clarify contact resolution timing** (§5.2): Add a note that `ResolveContactsUseCase` may be called for UI preview purposes, and `CreateReminderUseCase` re-resolves at save time for consistency. (Addresses M1)

2. **Quantify background callback timing** (§17.3): Add a target budget ("Background initialization must complete within 2 seconds on iOS" with note about first-run Drift schema creation). (Addresses M2)

3. **Add concrete category coordination example** (§16.5): Show the exact `DarwinInitializationSettings` and `AndroidInitializationSettings` configuration that "references without creating" categories. (Addresses M3)

4. **Standardize `ContactRef` → `ResolvedContact`** (§6.3, §6.4): Use the same type name as the SPEC to prevent type confusion. (Addresses L1)

5. **Add BOOT_COMPLETED query limit** (§15.5): Limit to nearest 60 PENDING reminders to stay within the 10-second `goAsync()` budget. (Addresses L2)

6. **Clarify `flutter_local_notifications` division of labor** (§22.1): Explicitly list what `flutter_local_notifications` handles vs. what the custom `NotificationBridge` handles. (Addresses L3)

## AI Agent Risk (Top 5)

1. **NLP extraction order violation** — Agent processes stages in parallel or reorders them, breaking entity extraction for inputs where patterns overlap. The order is specified as "critical" in ARCH §9.3 but agents often ignore ordering constraints in pipeline definitions.

2. **iOS extension uses wrong database path** — Agent copies the main app's `path_provider` logic into the extension, which resolves to the extension's sandbox instead of the App Group shared container. The documents say "App Group shared container" but don't provide the exact Swift API call.

3. **Notification category dual-registration conflict** — Agent registers categories independently in both the native bridge and `flutter_local_notifications`, creating mismatched identifiers. The "single source of truth" rule in §16.5 requires careful implementation across two registration points.

4. **iOS 64-notification limit — append instead of replace** — Agent implements "schedule if count < 64" instead of the priority-queue replacement algorithm. Despite explicit clarification in SPEC V3, the easier "append" path is tempting.

5. **Optimistic locking retry without state re-read** — Agent retries the same UPDATE with the old version number instead of re-reading the current state. The pseudocode in ARCH §8.2 shows the correct pattern, but an agent skimming might implement a simple retry loop that always fails on the second attempt.

---

*End of ARCHITECTURE_CONSISTENCY_REVIEW.md*
