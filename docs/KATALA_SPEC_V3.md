# KATALA — Product & Technical Specification V3

**Version:** 3.0.0
**Date:** 2026-08-10
**Status:** Implementation-Ready
**Replaces:** KATALA_SPEC_V2.md
**Sources reconciled:** KATALA_SPEC_V2.md, ARCHITECTURE_REVIEW.md, SPEC_REVIEW.md, PLAN.md

---

> **Purpose:** This specification answers: "Could a capable coding agent implement the MVP from KATALA_SPEC_V3.md without having to invent architecture for iOS notification actions, Android notification reliability, speech recognition, background initialization, notification reconciliation, or database synchronization?" The answer must be **yes**.

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Goals](#2-goals)
3. [Non-Goals](#3-non-goals)
4. [MVP Scope](#4-mvp-scope)
5. [Post-MVP Scope](#5-post-mvp-scope)
6. [User Journeys](#6-user-journeys)
7. [Functional Requirements](#7-functional-requirements)
8. [NLP Architecture](#8-nlp-architecture)
9. [Intent Detection](#9-intent-detection)
10. [Entity Extraction](#10-entity-extraction)
11. [Temporal Resolution](#11-temporal-resolution)
12. [Validation, Ambiguity & Clarification](#12-validation-ambiguity--clarification)
13. [Language Support & Limitations](#13-language-support--limitations)
14. [Reminder Domain Model](#14-reminder-domain-model)
15. [State Machine](#15-state-machine)
16. [Data Model](#16-data-model)
17. [Persistence (Drift/SQLite)](#17-persistence-driftsqlite)
18. [Conflict Detection](#18-conflict-detection)
19. [Notification Architecture](#19-notification-architecture)
20. [Notification Source of Truth & Reconciliation](#20-notification-source-of-truth--reconciliation)
21. [Missed Notification Tracking](#21-missed-notification-tracking)
22. [Action System](#22-action-system)
23. [iOS Notification Extension Architecture](#23-ios-notification-extension-architecture)
24. [Android OEM Reliability Strategy](#24-android-oem-reliability-strategy)
25. [Application Layer — Use Cases](#25-application-layer--use-cases)
26. [Background Initialization](#26-background-initialization)
27. [Failure Atomicity & Reconciliation](#27-failure-atomicity--reconciliation)
28. [UX Specification](#28-ux-specification)
29. [Accessibility](#29-accessibility)
30. [Privacy](#30-privacy)
31. [Security](#31-security)
32. [Offline Behavior](#32-offline-behavior)
33. [Platform Architecture](#33-platform-architecture)
34. [Platform Bridge Contracts](#34-platform-bridge-contracts)
35. [Error Handling & Failure Modes](#35-error-handling--failure-modes)
36. [Lifecycle, Reboot & Background Behavior](#36-lifecycle-reboot--background-behavior)
37. [Build Configuration](#37-build-configuration)
38. [Testing Strategy](#38-testing-strategy)
39. [Acceptance Criteria](#39-acceptance-criteria)
40. [Implementation Constraints](#40-implementation-constraints)
41. [Architectural Decisions](#41-architectural-decisions)
42. [Implementation Roadmap](#42-implementation-roadmap)
43. [Open Product Decisions](#43-open-product-decisions)
44. [Architecture Review Resolution Matrix](#44-architecture-review-resolution-matrix)
45. [Changes From V2](#45-changes-from-v2)

---

## 1. Product Vision

### 1.1 What Is Katala?

Katala is an **offline-first, voice-driven, context-aware smart reminder application** for iOS and Android. Named after the Philippine Red-vented Cockatoo (*Cacatua haematuropygia*), known for its intelligence and distinctive voice.

Katala converts natural speech into actionable, context-rich reminders entirely on-device. It requires zero cloud APIs, zero user accounts, incurs zero server costs, and processes all personal data locally.

### 1.2 Core Identity

| Pillar | Meaning |
|--------|---------|
| **Offline-first** | All core functionality works without internet. No cloud APIs, no user accounts, no server costs. |
| **Voice-driven** | Primary input is spoken natural language. Text input is the always-available fallback. |
| **Context-aware** | Reminders carry actionable payloads — phone calls, URLs, directions — not just text. |
| **Privacy-guaranteed** | All personal data processing occurs on-device. No reminder content, contact data, or location data is sent to any server operated by Katala. OS speech recognition may use platform-provided services; Katala configures on-device-only where the platform supports it. See §30 for full privacy specification. |
| **Fast** | Voice-to-persisted-reminder in under 5 seconds for simple commands on mid-range devices. |
| **Honest** | Never promises behavior that iOS or Android cannot guarantee. Documents platform limitations explicitly. |

### 1.3 What Katala Is NOT

- **Not a calendar app** — no events, invitations, or multi-party scheduling.
- **Not a voice assistant** — no Q&A, smart home control, or purchases.
- **Not a task manager** — no projects, subtasks, priorities, tags, or Kanban.
- **Not a communication app** — facilitates initiating calls/texts but does not handle them.
- **Not a note-taking app** — voice input creates reminders, not freeform notes.

### 1.4 Target Users

**Primary: The Busy Professional (Philippines, age 25–55)**
- Smartphone as primary productivity tool
- Frequently needs reminders for calls, meetings, tasks
- May be driving or commuting — needs hands-free interaction
- Values speed: wants to capture a reminder in under 5 seconds
- May speak English, Filipino, or Taglish (mixed)
- May have limited or intermittent internet connectivity

**Secondary: The Privacy-Conscious User**
- Avoids cloud-based assistants (Siri, Google Assistant)
- Chooses Katala for provable on-device architecture
- Willing to accept reduced functionality for guaranteed privacy

---

## 2. Goals

| ID | Goal | Measurable Criterion |
|----|------|---------------------|
| G1 | Voice-to-reminder in under 5 seconds | From mic tap to persisted reminder < 5s on mid-range devices |
| G2 | 100% offline core functionality | All MVP features work with airplane mode enabled |
| G3 | Zero data transmission to Katala-operated servers | No Katala backend exists; no network requests initiated by Katala code during normal operation |
| G4 | Actionable notifications with 1-tap actions | Notification banners include contextual action buttons |
| G5 | Schedule conflict awareness | New reminders within ±15 min of existing ones trigger a conflict warning |
| G6 | Natural language understanding for English + Taglish | Parser handles relative times, contacts, actions for en + common tl-en patterns |
| G7 | Cross-platform single codebase | One Flutter codebase serving iOS and Android |
| G8 | Accessible | Meets WCAG 2.1 AA equivalent for mobile |
| G9 | Honest about platform limitations | Users are never surprised by silently missing features |

---

## 3. Non-Goals

| ID | Non-Goal | Rationale |
|----|----------|-----------|
| NG1 | Cloud sync between devices | Contradicts offline-first privacy model |
| NG2 | User accounts or authentication | No server, no accounts |
| NG3 | Calendar integration | Adds complexity without core value |
| NG4 | Multi-party reminders / sharing | Requires server infrastructure |
| NG5 | Voice wake word ("Hey Katala") | Always-on mic; battery and privacy concerns |
| NG6 | Smart home control | Not a voice assistant |
| NG7 | Web or desktop version | Mobile-only |
| NG8 | AI/LLM-powered conversation | Must work offline with deterministic rule-based parsing |
| NG9 | Recurring reminders (MVP) | Voice creation too complex for rule-based NLP; UI-only in Post-MVP |
| NG10 | Custom notification sounds per reminder | OS limitations; use category-level sounds |
| NG11 | Server-side speech recognition | On-device STT required; no cloud fallback |
| NG12 | Location-based reminders (MVP) | Deferred to Post-MVP to reduce MVP complexity |

---

## 4. MVP Scope

### 4.1 Core MVP Features

| Feature | Classification | Rationale |
|---------|---------------|-----------|
| Voice input → text via on-device STT (custom native bridge) | **MVP** | Central value proposition |
| Text input fallback | **MVP** | Required for accessibility and degradation |
| NLP: CREATE_REMINDER with time, contact, URL, notes | **MVP** | Minimum viable voice reminder |
| NLP: CALL action + contact resolution | **MVP** | Key differentiator |
| NLP: URL detection + OPEN_URL action | **MVP** | Simple regex, high value |
| NLP: TEXT action + contact resolution | **MVP** | Natural extension of CALL |
| Notification scheduling with Done, Snooze, Call, Open Link actions | **MVP** | Core notification interaction |
| Notification actions without opening app (iOS: Notification Service Extension; Android: BroadcastReceiver) | **MVP** | Critical UX |
| Home screen timeline (overdue, today, tomorrow, later) | **MVP** | Primary UI |
| Reminder detail view with action buttons | **MVP** | Required for non-notification interaction |
| Manual reminder creation/edit form | **MVP** | Text fallback and editing |
| Settings screen (defaults, appearance, language) | **MVP** | Configurable user preferences |
| Onboarding (permissions education, mic + notifications) | **MVP** | Critical for permission acceptance |
| Conflict detection | **MVP** | Relatively simple; high value |
| Dark mode (default) + light mode | **MVP** | Design principle |
| Accessibility (WCAG 2.1 AA equivalent) | **MVP** | Required for inclusive product |
| English (en-US) full NLP + STT support | **MVP** | Primary supported language |
| Taglish temporal + action keyword support | **MVP** | Primary market need |
| Filipino temporal keyword support | **MVP** | Parse Filipino time expressions |
| Notification reconciliation on foreground + daily background wake | **MVP** | Catches missed notifications |
| Missed-notification visibility | **MVP** | Honest reliability communication |
| Database integrity check on startup | **MVP** | Prevent silent data corruption |
| Undo snackbar for complete/delete | **MVP** | Forgiving UX |

### 4.2 What MVP Does NOT Include

- Geofencing / location-based reminders (Post-MVP)
- Follow-up engine / conditional chaining (Post-MVP)
- Voice EDIT, DELETE, QUERY, or SNOOZE intents (UI-only for MVP)
- Recurring reminders (Post-MVP)
- Data export (Post-MVP)
- Database encryption at rest (Post-MVP)
- Tablet/iPad layouts (phone-only)
- Filipino full NLP intent patterns (temporal keywords only in MVP)
- Cloud STT fallback (never)
- Foreground service on Android (deferred; optional user-facing setting in Post-MVP)

---

## 5. Post-MVP Scope

| Feature | Priority | Notes |
|---------|----------|-------|
| Geofencing + saved locations | P1 | Deferred to limit MVP surface |
| Follow-up engine (conditional chaining) | P1 | Key differentiator |
| Voice EDIT, DELETE, QUERY, SNOOZE intents | P2 | Complex; needs robust reminder disambiguation |
| Recurring reminders (UI creation) | P2 | Common user expectation |
| Filipino full NLP intent patterns | P2 | Requires expanded regex coverage |
| Database encryption (SQLCipher) | P2 | Privacy enhancement |
| Data export (JSON) | P3 | User data portability |
| Tablet/iPad layouts | P3 | Larger screen adaptation |
| App-level biometric lock | P3 | Additional privacy layer |
| Notification quiet hours | P3 | "Later" capping, quiet sounds |
| Android foreground service (opt-in) | P3 | Reliability for aggressive-OEM devices |

---

## 6. User Journeys

### 6.1 Journey: Creating a Simple Reminder by Voice

**Trigger:** User opens app and speaks "Remind me to buy groceries tomorrow at 5 PM"

| Step | User Action | System Response | UI State | Failure | Recovery |
|------|------------|-----------------|----------|---------|----------|
| 1 | Opens app | Home screen with prominent mic button. Startup runs DB integrity check + notification reconciliation. | Timeline view | App crashes | Re-open app |
| 2 | Taps mic button | Audio session activates. Listening animation begins. Haptic feedback. | Pulsing mic icon, waveform | Mic permission denied | Show "Microphone access needed" with Settings button |
| 3 | Speaks command | Native STT converts to text. Live transcript appears. | Transcript streaming | STT unavailable (no on-device model) | Fall back to text input with explanation: "Voice unavailable — on-device speech model not found. Type your reminder below." |
| 4 | Stops speaking (silence or tap) | NLP pipeline processes: intent=CREATE_REMINDER, title="buy groceries", time="tomorrow 5:00 PM". All required entities present → VALID. | Brief processing indicator (<500ms) | Parse fails or missing required entities | Show transcript with clarification card |
| 5 | Reviews confirmation card | Shows: "Buy groceries — Tomorrow at 5:00 PM" with parsed fields | Confirmation card with [Save] [Edit] | N/A | N/A |
| 6 | Taps [Save] | `CreateReminderUseCase` executes: (1) persist reminder + trigger + action atomically in DB, (2) schedule OS notification, (3) persist scheduling state. Haptic + chirp sound. Returns to timeline. | Success → timeline shows new reminder | DB write fails | Retry once; on failure, show error with retry. If scheduling fails, reminder is persisted (DB is source of truth); reconciliation will schedule on next foreground. |
| 7 | Next day at 5:00 PM | Notification fires with [✓ Done] [⏰ Snooze] | System notification | Notification permission denied | Reminder shows as overdue when app next opened |

### 6.2 Journey: Creating a Call Reminder

**Trigger:** "Remind me to call Adam at 2 PM"

Steps 1-4 as in 6.1. NLP extracts: intent=CREATE_REMINDER, action=CALL, contact_name="Adam", time="2:00 PM today".

| Step | What Happens |
|------|-------------|
| 5 | `CreateReminderUseCase` resolves "Adam" against device contacts via `ContactBridge`. One match → attaches phone number. Multiple matches → disambiguation sheet. No match → stores name only, shows "(no phone number found)". Contacts permission denied → stores name only. |
| 6 | User taps [Save]. Reminder persisted with intent_type=CALL. |
| 7 | At 2:00 PM, notification: "Call Adam" with [📞 Call Now] [⏰ Snooze] [✓ Done]. |
| 8 | User taps [📞 Call Now]. Dialer opens with Adam's number pre-filled. Reminder marked COMPLETED. |

### 6.3 Journey: Creating by Text Input

| Step | What Happens |
|------|-------------|
| 1 | User taps "+" or swipes mic → keyboard icon. Text field appears with cursor focused. |
| 2 | Types: "Call dentist Monday 9am". Real-time NLP parses as user types (debounced 300ms). Shows parsed preview below input. |
| 3 | User optionally edits fields using form controls (date picker, time picker, contact picker). |
| 4 | Taps [Save]. `CreateReminderUseCase` persists and schedules. |

### 6.4 Journey: URL Reminder

**Trigger:** "Remind me to check this link at 8 PM — https://example.com/report"

Extracts: title="check this link", action=OPEN_URL, target="https://example.com/report", time="8:00 PM today". Notification at 8 PM with [🔗 Open Link] [✓ Done]. User taps [🔗 Open Link] → opens in default browser, reminder marked COMPLETED.

### 6.5 Journey: Notification Action While App Is Killed (iOS)

**Trigger:** Notification fires for "Call Adam at 2 PM" while Katala is not running.

| Step | What Happens |
|------|-------------|
| 1 | iOS delivers notification. |
| 2 | User long-presses/force-touches notification → sees [📞 Call Now] [⏰ Snooze] [✓ Done]. |
| 3 | User taps [✓ Done]. |
| 4 | iOS launches Notification Service Extension. Extension initializes: reads App Group shared container path → opens SQLite in WAL mode → loads minimal state machine → updates reminder to COMPLETED with optimistic locking → dismisses notification. |
| 5 | Extension terminates. Later, when main app opens, it reads the updated state from the shared database — reminder already COMPLETED. |

See §23 for full iOS notification extension architecture.

### 6.6 Journey: Android Reliability — Missed Notification Detection

**Trigger:** User creates reminder "Call dentist tomorrow at 10 AM." Device is a Xiaomi phone with aggressive battery optimization. Katala's process was killed overnight.

| Step | What Happens |
|------|-------------|
| 1 | 10 AM arrives. No notification fires (alarms were cleared by force-stop). |
| 2 | User opens Katala at 6 PM. `ReconcileNotificationsUseCase` runs on foreground. |
| 3 | Reconciliation detects: reminder.scheduled_time (10 AM today) < now, trigger.fired_at is null, trigger.notification_status = scheduled, but `last_reconciled_at` was > 12 hours ago. |
| 4 | Sets trigger.delivery_status = `delivery_uncertain`. |
| 5 | UI shows banner: "Katala was inactive for 20 hours. 1 reminder may have been missed." |
| 6 | Reminder appears in Overdue section with ⚠️ indicator. |

---

## 7. Functional Requirements

### 7.1 Reminder Creation

| ID | Requirement |
|----|------------|
| FR-1 | User MUST be able to create a reminder by voice (primary) or text input (fallback) |
| FR-2 | Voice creation MUST extract: title, time/date, contact (if CALL/TEXT), URL (if present), notes |
| FR-3 | When a required entity is missing, system MUST show a specific clarification question (not a generic error) |
| FR-4 | User MUST explicitly confirm every reminder before it is saved (no auto-save) |
| FR-5 | Created reminders MUST be persisted to local SQLite database atomically with their Trigger and Action via `CreateReminderUseCase` |

### 7.2 Notification Delivery

| ID | Requirement |
|----|------------|
| FR-6 | Time-based reminders MUST fire a local notification at the scheduled time |
| FR-7 | Notifications MUST include contextual action buttons based on reminder type |
| FR-8 | Notification actions (Done, Snooze) MUST work without opening the app |
| FR-9 | On Android, the app MUST reschedule all pending alarms after device reboot (when BOOT_COMPLETED is received) |
| FR-10 | On iOS, the app MUST manage the 64-pending-notification limit via dynamic scheduling (maintain nearest 60; 4 buffer slots) |
| FR-11 | The app MUST reconcile the notification queue on every foreground entry and via a daily background wake |

### 7.3 Conflict Detection

| ID | Requirement |
|----|------------|
| FR-12 | When a new reminder's time is within ±15 minutes of an existing PENDING/SNOOZED reminder, system MUST show a conflict warning |
| FR-13 | Conflict warning MUST display conflicting reminders; "Move to [suggested alternative time]" is primary option; "Save Anyway" is secondary |
| FR-14 | Conflict detection MUST work identically for voice-created and text-created reminders |

### 7.4 Notification Actions

| ID | Requirement |
|----|------------|
| FR-15 | [✓ Done] action MUST mark the reminder COMPLETED and dismiss the notification |
| FR-16 | [⏰ Snooze] action MUST mark the reminder SNOOZED and schedule a re-notification after the snooze duration |
| FR-17 | [📞 Call Now] action MUST open the phone dialer with the resolved phone number and mark the reminder COMPLETED |
| FR-18 | [🔗 Open Link] action MUST open the URL in the default browser and mark the reminder COMPLETED |
| FR-19 | [✏️ Edit] action MUST open the reminder edit screen in-app |
| FR-20 | All notification actions MUST update the database atomically with optimistic locking |

### 7.5 Reconciliation & Reliability

| ID | Requirement |
|----|------------|
| FR-21 | On every foreground entry, the app MUST reconcile: cancel notifications for deleted/completed reminders, schedule notifications for PENDING reminders missing from the OS queue |
| FR-22 | The app MUST track `delivery_status` for each Trigger: `scheduled`, `delivery_uncertain`, `delivery_missed` (see §21) |
| FR-23 | When reconciliation detects that the app was potentially inactive during a reminder's fire time, MUST set delivery_status to `delivery_uncertain` and inform the user |
| FR-24 | The app MUST store `last_reconciled_at` in a metadata table to compute inactivity gaps |
| FR-25 | On Android, the app MUST detect when alarms may have been cleared (force-stop, OEM kill) and present a reliability status in the UI |

### 7.6 Database Integrity

| ID | Requirement |
|----|------------|
| FR-26 | On startup, the app MUST run `PRAGMA integrity_check` on the SQLite database |
| FR-27 | If integrity check fails, the app MUST show a recovery option (restore from backup or reset) |
| FR-28 | All state transitions on reminders MUST use optimistic locking (version column) to prevent concurrent modification conflicts |

---

## 8. NLP Architecture

### 8.1 Design Principles

- **Deterministic:** Rule-based regex + temporal resolution. No ML inference, no ONNX, no TensorFlow Lite.
- **Pure:** NLP stages are pure functions — same input always produces same output. No side effects. No platform dependencies. No contact database access.
- **Testable:** Each stage is independently testable with known inputs and expected outputs. Clock is injectable.
- **Pipeline:** Sequential stages operating on typed intermediate representations.

### 8.2 Data Boundaries — NLP Purity

A critical architectural distinction: NLP parsing is pure. Contact resolution is platform-dependent. The NLP pipeline outputs a `ParsedReminder` that contains **contact names as strings**, not resolved contacts. The Application layer resolves those names via `ContactBridge` to produce a `ValidatedReminder`.

```
User Transcript
       │
       ▼  (Pure NLP — no platform dependencies)
┌──────────────────────────────┐
│ Stage 1: Pre-Processor       │ → NormalizedTranscript
│ Stage 2: Intent Detector     │ → IntentClassification
│ Stage 3: Entity Extractor    │ → ExtractedEntities (contact_name: string, not Contact object)
│ Stage 4: Temporal Resolver   │ → ResolvedDateTime
│ Stage 5: Validator           │ → ValidationResult
└──────────────────────────────┘
       │
       ▼  ParsedReminder (contact names as strings; no phone numbers)
       │
       ▼  (Application layer — platform-dependent)
┌──────────────────────────────┐
│ ContactBridge.resolve(name)  │ → ResolvedContact (phone number, etc.)
│ URL validation               │ → Validated URL
└──────────────────────────────┘
       │
       ▼  ValidatedReminder (ready for persistence)
```

### 8.3 Stage Interfaces

Each stage is a class or top-level function with:
- Explicit typed input
- Explicit typed output
- Injectable `Clock` for temporal stages
- No side effects

```dart
// Stage input/output types
class RawTranscript { final String text; }
class NormalizedTranscript { final String text; }
class IntentClassification { final IntentType intent; final double confidenceInternal; } // internal, not UX
class ExtractedEntities {
  final String? title;
  final String? contactName;     // String, NOT Contact object — NLP boundary
  final String? url;
  final String? phoneNumber;     // Raw phone number string from transcript
  final String? notes;
  final List<TemporalExpression> temporalExpressions;
}
class ParsedReminder {
  final String title;
  final String? contactName;     // Still a string — will be resolved by Application layer
  final String? url;
  final String? phoneNumber;
  final String? notes;
  final DateTime? scheduledTime;
  final String? timezone;
  final IntentType intentType;
  final List<ValidationIssue> issues; // Missing entities, ambiguities
}
class ValidatedReminder {
  final String title;
  final ResolvedContact? resolvedContact; // Platform-resolved
  final Uri? validatedUrl;
  final String? phoneNumber;
  final String? notes;
  final DateTime scheduledTime;
  final String timezone;
  final IntentType intentType;
}
```

### 8.4 Pipeline Order

1. **Pre-Processor** — Lowercase, collapse whitespace, normalize quotes, strip "um"/"uh" only adjacent to silence markers. Do NOT strip content words.
2. **Intent Detector** — Regex patterns classify intent (CREATE_REMINDER is the only MVP intent; others deferred).
3. **Entity Extractor** — Extract title, contact name (as string), URL, phone number, notes, temporal expressions.
4. **Temporal Resolver** — Resolve temporal expressions to absolute UTC datetimes using injectable Clock.
5. **Validator** — Check required entities present. Produce `ValidationResult` with list of issues.

---

## 9. Intent Detection

### 9.1 MVP Intents

Only one intent is supported for voice creation in MVP:

| Intent | Description |
|--------|-------------|
| `CREATE_REMINDER` | Create a new reminder |

Voice EDIT, DELETE, QUERY, and SNOOZE intents are Post-MVP.

### 9.2 English Intent Patterns

```
"remind me"
"set a reminder"
"add reminder"
"reminder to"
"don't forget"
"i need to"
"remember to"
```

### 9.3 Taglish Intent Patterns

```
"pa-remind"
"remind mo ko"
"remind mo ako"
"mag-remind"
"ipaalala mo"
"paremind"
"paalala"
"remind mo naman"
```

### 9.4 Action Detection (within CREATE_REMINDER)

| Pattern | Action Type |
|---------|-------------|
| `call`, `tawagan`, `tumawag`, `phone` | CALL |
| `text`, `message`, `sms`, `i-text`, `itext` | TEXT |
| `email`, `i-email` | EMAIL (Post-MVP) |
| `http://`, `https://` (URL regex) | OPEN_URL |
| `open`, `check`, `look at` + URL | OPEN_URL |

---

## 10. Entity Extraction

### 10.1 Contact Name Extraction

Extract contact names as **strings** from the transcript. Do not query the contacts database from NLP.

English patterns:
```
"call [Name]"
"text [Name]"
"message [Name]"
```

Taglish patterns:
```
"tawagan si [Name]"
"i-text si [Name]"
"tumawag kay [Name]"
```

The extracted name string is stored in `ParsedReminder.contactName`. The Application layer resolves it via `ContactBridge`.

### 10.2 URL Detection

Regex: `https?://[^\s]+`

Must be validated in the Application layer (whitelist http:// and https:// only) before storage AND before opening.

### 10.3 Phone Number Detection

Regex: `\+?[0-9]{7,15}` patterns in the transcript.

### 10.4 Contact Resolution (Application Layer — NOT NLP)

`ContactBridge.resolve(name: String)` performs:

1. **Exact match** — first name, last name, or full name exactly equals the query (case-insensitive)
2. **Partial match** — query is a substring of the contact's display name
3. **Contains match** — contact's display name contains the query words in any order

No fuzzy matching (no Jaro-Winkler, no Levenshtein). Simpler is faster and covers common cases.

Multiple matches → UI disambiguation. No match → store name only; user can manually pick later. Contacts permission denied → store name only.

---

## 11. Temporal Resolution

### 11.1 Clock Injection

All temporal resolution functions accept an injectable `Clock` interface:

```dart
abstract class Clock {
  DateTime now();
  String localTimezone();
}
```

Production: `SystemClock` (delegates to `DateTime.now()`).
Test: `FakeClock` (returns fixed datetime).

### 11.2 Temporal Expression Types

| Type | Example | Resolution |
|------|---------|-----------|
| Absolute datetime | "January 15 at 3 PM" | Exact |
| Relative minutes | "in 15 minutes" | now + 15 min |
| Relative hours | "in 2 hours" | now + 2 hrs |
| Named time | "noon", "midnight" | 12:00 PM, 12:00 AM |
| Day + time | "tomorrow at 5 PM" | Next day, 5:00 PM |
| Day without time | "on Friday" | Show time clarification (no default) |
| Next weekday | "next Monday" | Upcoming Monday |
| Bare time | "at 3 PM" | Today at 3 PM (or tomorrow if past) |
| "Later" | "later" | now + 2 hours, capped: if result > 10 PM or < 7 AM → move to 8 AM next day |
| Filipino relative | "mamaya" (later), "bukas" (tomorrow), "ngayon" (today), "sa susunod na linggo" (next week) | Same as English equivalents |

### 11.3 AM/PM Handling

Bare numbers 1–12 without AM/PM: **always show AM/PM toggle** on the confirmation card. Never auto-resolve. One tap is cheap; getting it wrong causes missed reminders.

### 11.4 Missing Time Clarification

When no time is specified (e.g., "Remind me to call Adam"):
- Confirmation card shows the parsed fields
- Time field shows "Tap to set a time" with quick-pick chips: [9:00 AM] [12:00 PM] [5:00 PM] [Pick a time]
- Save button is disabled until user sets a time
- No default time — the user must explicitly choose

### 11.5 Timezone Handling

- All times stored as UTC with timezone identifier (`scheduled_time_utc` + `timezone`)
- Resolved using the device's local timezone at creation time
- Notification scheduling uses the stored timezone for correct local fire time

---

## 12. Validation, Ambiguity & Clarification

### 12.1 Design Decision: No Confidence Scores

KATALA_SPEC_V2.md used a 0.0–1.0 confidence field but never defined how it was calculated. V3 removes confidence as a formal numerical contract.

**Instead**, the Validator stage produces explicit `ValidationIssue` entries:

```dart
enum ValidationIssue {
  missingTitle,
  missingTime,
  ambiguousTime,      // AM/PM ambiguity
  ambiguousContact,   // Multiple contact matches
  unresolvedContact,  // Contact name provided but no match found
  invalidUrl,
  timeInPast,
}
```

The UI layer maps `ValidationIssue` entries to specific clarification cards — not a generic confidence-based flow.

### 12.2 Validation Rules

| Condition | Issues | UX Behavior |
|-----------|--------|-------------|
| Title extracted, time extracted, no ambiguities | None | Show confirmation card with [Save] [Edit] |
| Title extracted, time missing | `missingTime` | Show clarification card with time picker + quick-pick chips |
| Time has bare number 1–12 without AM/PM | `ambiguousTime` | Show AM/PM toggle on confirmation card |
| Contact name provided but no match | `unresolvedContact` | Show "(no phone number found)" next to contact name; allow manual pick |
| Contact name has multiple matches | `ambiguousContact` | Show disambiguation sheet with matching contacts |
| URL present but invalid (not http/https) | `invalidUrl` | Strip URL; show warning in confirmation |
| Time is in the past | `timeInPast` | Show warning; allow save anyway or pick new time |

### 12.3 Clarification UX

The clarification card shows:
1. Original transcript (so user sees what was parsed)
2. Specific question (e.g., "What time?")
3. Quick-pick chips
4. Manual input option
5. Save button (disabled until required fields are filled)

---

## 13. Language Support & Limitations

### 13.1 Supported Languages — MVP

| Language/Pattern | NLP Support | STT Support (iOS) | STT Support (Android) |
|-----------------|-------------|-------------------|----------------------|
| English (en-US) | Full intent + entity + temporal | SFSpeechRecognizer (on-device available) | SpeechRecognizer (on-device available) |
| Taglish (en-tl mixed) | Intent patterns + temporal keywords + contact extraction | Works when primary speech is English | Works when primary speech is English |
| Filipino time keywords | Temporal keywords only ("mamaya", "bukas", "ngayon") | Not supported on-device for pure Filipino on iOS | Partially supported on Android |

### 13.2 Honest Platform Limitation

Filipino on-device STT:
- **iOS:** SFSpeechRecognizer does not support Filipino for on-device recognition. Voice input for pure Filipino speech is **disabled** on iOS. Text input is available. This is documented in onboarding and Settings.
- **Android:** SpeechRecognizer supports Filipino but on-device model availability varies by device manufacturer and Google app version. If on-device is unavailable, voice input for Filipino is disabled — no cloud fallback.
- **Taglish mixed input** works when the speech engine processes it as primarily English.

### 13.3 Behavior When STT Model Is Unavailable

```dart
// SpeechBridge.availability returns:
enum SpeechAvailability {
  available,          // On-device model loaded; voice input enabled
  unavailable,        // No on-device model; voice disabled; text fallback available
  permissionDenied,   // Mic permission not granted
  notSupported,       // Language not supported for on-device
}
```

When unavailable: the mic button shows in a disabled state with a tooltip/explanation. The text input path is highlighted as the primary input method.

---

## 14. Reminder Domain Model

### 14.1 Entities

```
Reminder (1) ──── (1) Trigger
Reminder (1) ──── (1) Action
Reminder (0..1) ── (0..n) Reminder   // parent → follow-ups (Post-MVP)
```

### 14.2 Reminder

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `title` | String | Reminder title text |
| `notes` | String? | Optional notes |
| `intent_type` | Enum | GENERAL, CALL, TEXT, EMAIL, OPEN_URL |
| `status` | Enum | PENDING, COMPLETED, SNOOZED, DISMISSED |
| `snooze_count` | int | Number of times snoozed (max 10) |
| `snooze_duration_minutes` | int | Last snooze duration (default 10) |
| `parent_reminder_id` | UUID? | FK to parent reminder (Post-MVP) |
| `depth` | int | Chain depth (0 = root; Post-MVP) |
| `version` | int | Optimistic locking version |
| `original_transcript` | String? | Raw transcript for display |
| `created_at` | DateTime (UTC) | Creation timestamp |
| `updated_at` | DateTime (UTC) | Last modification timestamp |
| `completed_at` | DateTime (UTC)? | Completion timestamp |
| `is_deleted` | bool | Soft delete flag |
| `deleted_at` | DateTime (UTC)? | Soft delete timestamp |

### 14.3 Trigger

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `reminder_id` | UUID | FK to Reminder |
| `trigger_type` | Enum | SCHEDULED_TIME (MVP), GEOFENCE (Post-MVP) |
| `scheduled_time_utc` | DateTime (UTC) | Fire time in UTC |
| `scheduled_time_timezone` | String | Timezone identifier (e.g., "Asia/Manila") |
| `notification_scheduled` | bool | Has a corresponding OS notification been scheduled? |
| `notification_id` | int? | Platform notification identifier |
| `fired_at` | DateTime (UTC)? | When the notification actually fired (null if unknown) |
| `delivery_status` | Enum | scheduled, delivery_uncertain, delivery_missed |
| `recurrence_rule` | String? | RFC 5545 RRULE (Post-MVP; nullable for future use) |

### 14.4 Action

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `reminder_id` | UUID | FK to Reminder |
| `action_type` | Enum | CALL, TEXT, EMAIL, OPEN_URL, GENERAL |
| `target_value` | String? | Phone number, URL, email address |
| `contact_name` | String? | Display name (always stored even without phone) |
| `contact_phone` | String? | Resolved phone number |
| `contact_id` | String? | Platform contact identifier |

### 14.5 AppMetadata (Key-Value)

| Field | Type | Description |
|-------|------|-------------|
| `key` | String | Metadata key |
| `value` | String | JSON-encoded value |

Keys:
- `last_reconciled_at` — ISO 8601 UTC datetime of last successful reconciliation
- `last_scheduling_event_at` — ISO 8601 UTC datetime of last notification scheduling event

### 14.6 Delivery Status Semantics

| Status | Meaning | When Set |
|--------|---------|----------|
| `scheduled` | Notification has been scheduled with the OS | After successful `NotificationBridge.schedule()` |
| `delivery_uncertain` | App was potentially inactive during fire time; notification may or may not have been delivered | During reconciliation when `last_reconciled_at` gap exceeds the reminder's scheduled time |
| `delivery_missed` | User confirmed they did not receive the notification (manual flag from UI) | User explicitly marks "I didn't see this" in the UI |

---

## 15. State Machine

### 15.1 States

```
PENDING     — Waiting for trigger time
COMPLETED   — User marked as done
SNOOZED     — Temporarily postponed
DISMISSED   — User dismissed without completing
```

### 15.2 Transitions

| From | To | Trigger | Guard |
|------|----|---------|-------|
| (new) | PENDING | Reminder created | — |
| PENDING | COMPLETED | User taps Done (in-app or notification) | — |
| PENDING | SNOOZED | User taps Snooze (in-app or notification) | snooze_count < 10 |
| PENDING | DISMISSED | User taps Dismiss | — |
| SNOOZED | PENDING | Snooze timer expires | — |
| SNOOZED | SNOOZED | User taps Snooze again | snooze_count < 10 |
| SNOOZED | COMPLETED | User taps Done | — |
| SNOOZED | DISMISSED | User taps Dismiss | — |
| DISMISSED | (terminal) | — | No further transitions |

### 15.3 Optimistic Locking

Every state transition uses optimistic locking:

```sql
UPDATE reminder
SET status = 'COMPLETED',
    completed_at = :now,
    version = version + 1,
    updated_at = :now
WHERE id = :id AND version = :expected_version
```

If `rows affected = 0`: another process modified this reminder concurrently. Re-read and retry the transition once. If the retry also fails, log and surface a conflict to the user on next app open.

---

## 16. Data Model

### 16.1 Schema (SQLite)

```sql
CREATE TABLE reminder (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  notes TEXT,
  intent_type TEXT NOT NULL CHECK (intent_type IN ('GENERAL', 'CALL', 'TEXT', 'EMAIL', 'OPEN_URL')),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'COMPLETED', 'SNOOZED', 'DISMISSED')),
  snooze_count INTEGER NOT NULL DEFAULT 0,
  snooze_duration_minutes INTEGER NOT NULL DEFAULT 10,
  parent_reminder_id TEXT REFERENCES reminder(id),
  depth INTEGER NOT NULL DEFAULT 0,
  version INTEGER NOT NULL DEFAULT 1,
  original_transcript TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT
);

CREATE TABLE trigger (
  id TEXT PRIMARY KEY,
  reminder_id TEXT NOT NULL UNIQUE REFERENCES reminder(id),
  trigger_type TEXT NOT NULL CHECK (trigger_type IN ('SCHEDULED_TIME', 'GEOFENCE')),
  scheduled_time_utc TEXT NOT NULL,
  scheduled_time_timezone TEXT NOT NULL DEFAULT 'UTC',
  notification_scheduled INTEGER NOT NULL DEFAULT 0,
  notification_id INTEGER,
  fired_at TEXT,
  delivery_status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (delivery_status IN ('scheduled', 'delivery_uncertain', 'delivery_missed')),
  recurrence_rule TEXT
);

CREATE TABLE action (
  id TEXT PRIMARY KEY,
  reminder_id TEXT NOT NULL UNIQUE REFERENCES reminder(id),
  action_type TEXT NOT NULL CHECK (action_type IN ('CALL', 'TEXT', 'EMAIL', 'OPEN_URL', 'GENERAL')),
  target_value TEXT,
  contact_name TEXT,
  contact_phone TEXT,
  contact_id TEXT
);

CREATE TABLE app_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX idx_reminder_status ON reminder(status) WHERE is_deleted = 0;
CREATE INDEX idx_reminder_parent ON reminder(parent_reminder_id);
CREATE INDEX idx_trigger_scheduled_time ON trigger(scheduled_time_utc);
CREATE INDEX idx_trigger_notification_scheduled ON trigger(notification_scheduled);
```

### 16.2 Database Configuration

- **WAL mode:** `PRAGMA journal_mode=WAL;` — required for cross-process access on iOS
- **Foreign keys:** `PRAGMA foreign_keys=ON;`
- **Busy timeout:** `PRAGMA busy_timeout=3000;` (3 seconds)
- **Database file location:** App Group shared container on iOS; default database directory on Android
- **Backup exclusion:** Database excluded from device backups by default. Opt-in via Settings with privacy notice.

---

## 17. Persistence (Drift/SQLite)

### 17.1 Technology

Use **Drift** (formerly moor) for type-safe SQLite access in the main app.

For the iOS Notification Service Extension, use a **lightweight raw SQLite access layer** (not Drift) to avoid pulling in the full Drift dependency stack into the extension binary. See §23.

### 17.2 Repository Pattern

Repositories are in the Data layer. They handle persistence and querying only — NOT notification scheduling, NOT business logic.

```dart
// Data layer — repository interface
abstract class ReminderRepository {
  Future<Reminder> insert(ValidatedReminder reminder);
  Future<void> update(Reminder reminder);
  Future<Reminder?> getById(String id);
  Future<List<Reminder>> getPending({DateTime? before});
  Future<List<Reminder>> getOverdue();
  Future<int> transitionState(String id, int expectedVersion, ReminderStatus newStatus);
  Future<void> softDelete(String id, int expectedVersion);
}
```

### 17.3 Startup Integrity Check

On every app launch:
1. Run `PRAGMA integrity_check;`
2. If result != "ok": show error screen with options "Restore from backup" and "Reset database"
3. Run `PRAGMA quick_check;` if integrity_check passes, for faster startup

### 17.4 Migration Strategy

- Drift schema versioning with migration callbacks
- Every schema change increments version number
- Test migrations from v1 → vN in automated tests
- Lightweight extension SQLite layer keeps its own simple migration tracking

### 17.5 Soft Delete & Retention

- Soft delete only (set `is_deleted = 1`, `deleted_at = now`)
- Hard delete reminders with `is_deleted = 1 AND deleted_at < (now - 30 days)` during periodic cleanup
- Cleanup runs during reconciliation, not on a timer

---

## 18. Conflict Detection

### 18.1 Algorithm

When creating a reminder with a scheduled time:

1. Query all PENDING and SNOOZED reminders with `scheduled_time_utc` within ±15 minutes of the new reminder's time
2. If any found → conflict
3. Sort conflicting reminders by proximity to new time
4. Find the nearest gap of ≥ 30 minutes before or after the new time

### 18.2 Conflict Warning UX

```
┌──────────────────────────────────┐
│  ⚠ Schedule Conflict            │
│                                  │
│  You have 2 reminders at 2:00 PM │
│  • Call Adam                     │
│  • Submit report                 │
│                                  │
│  ┌────────────────────────────┐  │
│  │  Move to 2:30 PM           │  │  ← Primary (recommended)
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  Save Anyway at 2:00 PM    │  │  ← Secondary
│  └────────────────────────────┘  │
│  ┌────────────────────────────┐  │
│  │  Pick Another Time         │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

---

## 19. Notification Architecture

### 19.1 Platform Bridge

`NotificationBridge` is the abstraction. Platform implementations:

| Method | iOS | Android |
|--------|-----|---------|
| `schedule(reminder)` | UNUserNotificationCenter.add | AlarmManager.setExactAndAllowWhileIdle |
| `cancel(notificationId)` | UNUserNotificationCenter.remove | AlarmManager.cancel |
| `reconcile()` | getPending + getDelivered → compare + fix | AlarmManager.iterate + compare + fix |
| `getScheduledIds()` | UNUserNotificationCenter.getPending | Query AlarmManager (best-effort) |
| `configureCategories()` | UNNotificationCategory registration | NotificationChannel + actions in manifest |

### 19.2 Notification Categories

Define one notification category per intent type:

```dart
enum NotificationCategory {
  general,  // [✓ Done] [⏰ Snooze]
  call,     // [📞 Call Now] [⏰ Snooze] [✓ Done]
  text,     // [💬 Text Now] [⏰ Snooze] [✓ Done]
  url,      // [🔗 Open Link] [✓ Done]
}
```

Categories must be registered at app initialization before any notifications are scheduled. If categories change between versions, already-scheduled notifications reference the old category definition — handle this by re-scheduling on version migration.

### 19.3 Notification Actions

Each category defines actions:

| Category | Actions |
|----------|---------|
| GENERAL | ✓ Done, ⏰ Snooze (10 min), ✏️ Edit |
| CALL | 📞 Call Now, ⏰ Snooze (10 min), ✓ Done |
| TEXT | 💬 Text Now, ⏰ Snooze (10 min), ✓ Done |
| URL | 🔗 Open Link, ✓ Done |

### 19.4 iOS Dynamic Scheduling (64-Notification Limit)

iOS limits apps to 64 pending notifications. Strategy:

1. On every scheduling event (create, edit, delete, complete, snooze, reconcile):
   - Query all PENDING/SNOOZED reminders with future trigger times
   - Sort by `scheduled_time_utc` ascending
   - Take the first **60** (nearest in time)
   - Cancel any currently-scheduled notification whose `reminder_id` is NOT in the top 60
   - Schedule notifications for any reminder in the top 60 that doesn't already have one
   - Update `trigger.notification_scheduled` flags
2. The 4-slot buffer prevents churn from constant cancel+reschedule near the boundary.

### 19.5 Android Alarm Scheduling

- Use `AlarmManager.setExactAndAllowWhileIdle` for precise timing
- Schedule individual PendingIntent per reminder
- Notification ID = hash of reminder UUID → int (within Android's range)
- On BOOT_COMPLETED: re-query all PENDING/SNOOZED reminders and re-schedule all alarms
- BOOT_COMPLETED receiver uses `goAsync()` if initialization takes > 1 second; fallback: enqueue a OneTimeWorkRequest for the actual re-scheduling

### 19.6 Notification Behavior Matrix

| Scenario | iOS | Android |
|----------|-----|---------|
| App in foreground | Notification delivered; action handled in-app | Same |
| App in background | Notification delivered; action handled by extension or background launch | Notification delivered; action via BroadcastReceiver |
| App killed (not force-stopped) | Extension handles action; or iOS launches app in background (~5s window) | BroadcastReceiver handles action |
| App force-stopped | N/A (iOS doesn't have force-stop) | All alarms cancelled; BOOT_COMPLETED receiver disabled; no notifications until user re-opens app |
| Device reboot | BGAppRefreshTask on next schedule; reconciliation on foreground | BOOT_COMPLETED receiver re-schedules |
| Doze (Android) | N/A | Alarms deferred to maintenance windows; `setExactAndAllowWhileIdle` mitigates |
| Silent mode | Katala respects mute switch; no Critical Alerts entitlement | Same |

---

## 20. Notification Source of Truth & Reconciliation

### 20.1 Authoritative State

```
DATABASE = AUTHORITATIVE STATE
OS NOTIFICATION SCHEDULER = DERIVED STATE
```

The database is always correct. OS notifications are a best-effort reflection.

### 20.2 Reconciliation Algorithm

Run on: (1) every foreground entry, (2) after any notification action, (3) after any reminder create/edit/delete/complete, (4) daily background wake.

```
function reconcile():
  // 1. Cancel orphaned OS notifications
  for each scheduledNotification in OS.getScheduledIds():
    reminder = db.getByNotificationId(scheduledNotification.id)
    if reminder == null or reminder.is_deleted or reminder.status in [COMPLETED, DISMISSED]:
      OS.cancel(scheduledNotification.id)
      if reminder: db.updateTriggerNotificationScheduled(reminder.id, false)

  // 2. Schedule missing notifications
  pendingReminders = db.getPendingRemindersSortedByTime(limit=60 on iOS)
  for each reminder in pendingReminders:
    if reminder.trigger.notification_scheduled == false:
      try:
        OS.schedule(reminder)
        db.updateTriggerNotificationScheduled(reminder.id, true, notificationId)
      catch SchedulingError:
        // Reminder stays in DB; will retry on next reconciliation

  // 3. Detect missed deliveries
  now = Clock.now()
  gap = now - db.getMetadata('last_reconciled_at')
  if gap > 6 hours:
    missedReminders = db.getPendingRemindersScheduledBetween(
      db.getMetadata('last_reconciled_at'), now
    )
    for each reminder in missedReminders:
      if reminder.trigger.fired_at == null:
        db.updateTriggerDeliveryStatus(reminder.id, 'delivery_uncertain')

  // 4. Update reconciliation timestamp
  db.setMetadata('last_reconciled_at', now.toUtcIso8601())
```

### 20.3 Idempotency

- `schedule()` is idempotent: cancels existing notification for the same reminder before re-scheduling
- `cancel()` is idempotent: no error if notification doesn't exist
- Reconciliation can run multiple times without side effects

### 20.4 Scheduling Failure Handling

If `NotificationBridge.schedule()` fails:
1. The reminder is already persisted (DB is source of truth)
2. Log the failure
3. Set `trigger.notification_scheduled = false`
4. Return a partial success to the user: "Reminder saved. Notification scheduling will retry."
5. Next reconciliation will attempt to schedule it

---

## 21. Missed Notification Tracking

### 21.1 Design Rationale

Katala cannot know with certainty whether the OS displayed a notification. The OS does not provide delivery confirmation. Instead, Katala tracks what it can observe and communicates uncertainty honestly.

### 21.2 Delivery Status State Machine

```
scheduled ──────────────────────────────────────────┐
   │                                                  │
   │  (notification fires; OS delivers)               │
   │  trigger.fired_at = now                          │
   │  delivery_status stays 'scheduled'               │
   │  (scheduled = "we scheduled it; we have          │
   │   no evidence it failed")                        │
   │                                                  │
   ▼                                                  │
(reminder becomes COMPLETED/SNOOZED/DISMISSED         │
 via notification action)                             │
   │                                                  │
   ▼                                                  │
(no further delivery_status change needed)            │
                                                      │
                                                      │
scheduled ──(reconciliation: gap > 6 hrs, fire time   │
             in past, fired_at is null)──► delivery_uncertain
                                                      │
                                                      │
delivery_uncertain ──(user explicitly flags)──► delivery_missed
delivery_uncertain ──(user completes reminder)──► (done)
```

### 21.3 Database Fields

| Field | Type | Meaning |
|-------|------|---------|
| `delivery_status` | enum | `scheduled`, `delivery_uncertain`, `delivery_missed` |
| `fired_at` | DateTime? | Set to `now` when notification fires (OS callback). `null` if the app never observed the fire. |
| `last_reconciled_at` | DateTime (app_metadata) | When reconciliation last ran. Used to compute the "blackout gap." |

### 21.4 UI Behavior

| Scenario | UI |
|----------|-----|
| Reminder is overdue, delivery_status = `scheduled`, fired_at is set | Normal overdue display (red indicator). User probably ignored it. |
| Reminder is overdue, delivery_status = `delivery_uncertain` | Overdue with ⚠️ "May not have been delivered" badge. |
| Reminder is overdue, delivery_status = `delivery_missed` | Overdue with ❌ "Not delivered" badge. |
| Multiple delivery_uncertain reminders | Banner: "Katala was inactive for [duration]. [N] reminders may have been missed." |

### 21.5 Cleanup

- When a reminder transitions to COMPLETED or DISMISSED, delivery_status is no longer relevant
- `delivery_uncertain` reminders stay visible until the user acknowledges them
- No automatic escalation or re-notification beyond what reconciliation already does

---

## 22. Action System

### 22.1 Supported Actions (MVP)

| Action | Behavior |
|--------|----------|
| CALL | Open phone dialer with number pre-filled using `tel:` URL scheme. Use `ACTION_DIAL`, never `ACTION_CALL`. |
| TEXT | Open SMS compose screen with number pre-filled using `sms:` URL scheme. Never auto-send. |
| OPEN_URL | Open URL in default browser. Whitelist http:// and https:// only. Validate before opening. |
| GENERAL | No special action; simple reminder notification. |

### 22.2 Action Execution

When user taps an action button (in notification or in-app):

```
function executeAction(reminder, actionType):
  switch actionType:
    case CALL:
      validatePhoneNumber(reminder.action.contact_phone)
      launchUrl('tel:${reminder.action.contact_phone}')
      completeReminder(reminder)

    case TEXT:
      validatePhoneNumber(reminder.action.contact_phone)
      launchUrl('sms:${reminder.action.contact_phone}')
      completeReminder(reminder)

    case OPEN_URL:
      validateUrl(reminder.action.target_value)  // http/https only
      launchUrl(reminder.action.target_value)
      completeReminder(reminder)

    case GENERAL:
      completeReminder(reminder)
```

### 22.3 URL Validation

Before storing AND before opening:
- Only `http://` and `https://` schemes are allowed
- `javascript:`, `file:`, `data:`, and other schemes are rejected
- URL length ≤ 2048 characters

---

## 23. iOS Notification Extension Architecture

### 23.1 Why This Section Exists

Katala's FR-8 requires notification actions (Done, Snooze) to work without opening the app. On iOS, this requires a Notification Service Extension — a separate binary that runs in a separate process. This section defines exactly how the extension accesses the database and performs state transitions.

### 23.2 Xcode Targets

The iOS project must contain **two** targets:

| Target | Type | Purpose |
|--------|------|---------|
| `Katala` | Main App | Full Flutter application |
| `KatalaNotificationExtension` | Notification Service Extension | Background notification action handling |

### 23.3 App Group

Both targets share a container via App Group capability:

- **App Group identifier:** `group.com.katala.app` (replace with actual bundle prefix)
- In Xcode: both targets have the App Group capability added under Signing & Capabilities
- The App Group identifier is added to both targets' entitlements

### 23.4 Shared Database

**Location:** The SQLite database file is stored in the App Group shared container, not the main app's sandbox.

```swift
// Path construction in both targets:
let containerURL = FileManager.default
  .containerURL(forSecurityApplicationGroupIdentifier: "group.com.katala.app")!
let dbURL = containerURL.appendingPathComponent("katala.db")
```

**Drift in main app:** Configure Drift to use this shared path instead of the default:

```dart
// In main app Drift configuration:
final dbPath = await _getSharedContainerPath() + '/katala.db';
// Pass to drift's constructor
```

**Extension data access:** The extension uses a **lightweight raw SQLite layer** (not Drift). This is intentional:
- Drift's full code generation and reactive stream layer are unnecessary in the extension
- The extension only needs: open DB, run one UPDATE, close DB
- Keeping the extension binary small improves launch time

### 23.5 Extension Database Layer

The extension includes a minimal SQLite access class (in Swift):

```swift
// KatalaNotificationExtension/DB/ExtensionDatabase.swift
class ExtensionDatabase {
    private var db: OpaquePointer?

    init() throws {
        let containerURL = FileManager.default
          .containerURL(forSecurityApplicationGroupIdentifier: "group.com.katala.app")!
        let dbURL = containerURL.appendingPathComponent("katala.db")
        if sqlite3_open_v2(dbURL.path, &db,
                           SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_WAL,
                           nil) != SQLITE_OK {
            throw ExtensionError.databaseOpenFailed
        }
        sqlite3_busy_timeout(db, 3000)  // 3 second busy timeout
    }

    func transitionReminderState(
      reminderId: String,
      expectedVersion: Int,
      newStatus: String,
      completedAt: String
    ) throws -> Bool {
        let sql = """
            UPDATE reminder
            SET status = ?, completed_at = ?,
                version = version + 1, updated_at = ?
            WHERE id = ? AND version = ?
        """
        // ... bind, step, check rows affected
        return rowsAffected > 0
    }

    func getReminderAction(reminderId: String) throws -> (actionType: String, targetValue: String?)? {
        // ... query action table
    }

    deinit {
        sqlite3_close(db)
    }
}
```

### 23.6 Extension Initialization Sequence

When a notification action is tapped:

1. iOS launches the extension process
2. `didReceive(_:completionHandler:)` is called
3. Extension:
   a. Creates `ExtensionDatabase` instance (opens shared WAL-mode SQLite)
   b. Reads the reminder and its current version
   c. Attempts optimistic-lock state transition (e.g., PENDING → COMPLETED)
   d. If rows affected = 0: another process modified it; read new state and retry once
   e. Dismisses the notification
   f. Calls `contentHandler(modifiedContent)` to update/dismiss
   g. SQLite connection closes when `ExtensionDatabase` is deallocated
4. Extension terminates

**Total runtime target:** < 1 second for a simple state transition.

### 23.7 Concurrency: Extension vs. Main App

| Concern | Handling |
|---------|----------|
| SQLite concurrent writes | WAL mode allows concurrent reads + one writer. SQLITE_BUSY is handled by `busy_timeout=3000` and optimistic locking at the app level. |
| Extension writes while app is reading | WAL mode: reader sees the state before the write began. No blocking. |
| App writes while extension writes | SQLite serializes writes. The second writer waits for `busy_timeout` then gets SQLITE_BUSY. Both extension and app must retry once. |
| Same reminder modified by both | Optimistic locking (`WHERE version = ?`) ensures only one transition succeeds. The loser re-reads and retries. |

### 23.8 SQLite WAL Configuration

```
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=3000;
```

WAL mode is critical: it allows the main app and extension to read concurrently without blocking each other.

### 23.9 Database File Protection

iOS file protection: `NSFileProtectionCompleteUnlessOpen`

This allows the extension to access the database even when the device is locked (notification actions must work on the lock screen). The main app opens the database on launch, which holds the file handle.

### 23.10 Entitlements

Both targets require:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.katala.app</string>
</array>
```

### 23.11 Info.plist Requirements

Extension's Info.plist:
- `NSExtension` → `NSExtensionPrincipalClass` → `$(PRODUCT_MODULE_NAME).NotificationService`
- `UNNotificationExtensionCategory` — the category identifiers configured in §19.2

### 23.12 Testing the Extension

1. **Unit test:** Simulate extension database operations with a test SQLite file in the shared container
2. **Integration test:** On a real device: kill the main app, trigger a notification, tap a notification action, verify the database state changed
3. **Concurrent access test:** Script rapid alternation between main app writes and extension writes; verify no corruption and optimistic lock works

### 23.13 Extension Failure Behavior

If the extension fails (crash, database error, timeout):
- iOS dismisses the notification (default behavior for handled actions)
- The reminder state is NOT changed
- Next time the main app launches, reconciliation runs and the reminder is still in its previous state
- If the user opens the app, they see the reminder as if the action was never taken
- No data corruption — the optimistic lock either succeeds or no change occurs
- The user may need to tap the action again from the app

---

## 24. Android OEM Reliability Strategy

### 24.1 The Problem

Android devices in the Philippine market (Xiaomi, OPPO, realme, Huawei, Samsung budget models) use aggressive battery optimization. The OS may:
- Kill Katala's process minutes after the user leaves the app
- Clear all scheduled alarms on force-stop
- Disable BOOT_COMPLETED broadcast receiver after force-stop
- Delay or prevent WorkManager tasks during Doze

Katala cannot prevent this. It can only detect, mitigate, and communicate.

### 24.2 What Katala Can Detect

| Observable | How |
|------------|-----|
| App was force-stopped | All alarms are gone on next foreground; `last_reconciled_at` gap > expected |
| Notification may have been missed | `trigger.fired_at` is null but `scheduled_time_utc` is in the past |
| Device reboot occurred | BOOT_COMPLETED received (if not force-stopped); or gap detection |
| Battery optimization is enabled | Check `PowerManager.isIgnoringBatteryOptimizations()` |

### 24.3 What Katala Cannot Detect

| Unobservable | Why |
|-------------|-----|
| Whether a notification was actually displayed | Android does not provide delivery confirmation for local notifications |
| When exactly the process was killed | No callback for process death |
| Whether the user saw and ignored a notification | No read-receipt for notifications |
| Whether OEM-specific "auto-start" permission is disabled | No standard API; varies by manufacturer |

### 24.4 Architecture

**Normal behavior:**
- Alarms scheduled via `AlarmManager.setExactAndAllowWhileIdle`
- On device reboot, `BOOT_COMPLETED` receiver reschedules all alarms
- Daily `WorkManager` periodic task reconciles the notification queue
- On every foreground entry, foreground reconciliation runs (§20.2)

**After force-stop:**
- All alarms are cleared. BOOT_COMPLETED receiver is disabled.
- Next foreground: reconciliation detects gap. Sets `delivery_uncertain` on affected reminders. Shows reliability banner.
- User is guided to disable battery optimization for Katala.

**Boot receiver implementation:**
```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Use goAsync() for up to ~10 seconds
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    RescheduleAllAlarmsUseCase(context).execute()
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }
}
```

If database initialization is too slow for `goAsync()`, enqueue a `OneTimeWorkRequest` that does the actual re-scheduling.

### 24.5 User-Facing Reliability Status

**In Settings → Notifications:**

```
Notification Reliability

Status: ● Good — All systems normal
        ● Fair — Battery optimization may delay notifications
        ● Poor — Notifications may not fire reliably

[Disable Battery Optimization]  → Opens system settings
[View Manufacturer Guide]       → Shows device-specific instructions
```

**Status determination:**
- **Good:** No `delivery_uncertain` events in the past 7 days; `last_reconciled_at` gap never exceeds 6 hours
- **Fair:** Battery optimization is enabled; or `last_reconciled_at` gap was between 6-24 hours
- **Poor:** Multiple `delivery_uncertain` events in the past 7 days; or `last_reconciled_at` gap > 24 hours; or user reported `delivery_missed`

### 24.6 Onboarding Guidance (Android)

During onboarding on Android, after notification permission is granted:

> "For reliable notifications, Katala needs to stay active in the background. Some Android devices limit background apps to save battery. Would you like to optimize Katala for reliability?"

Options: [Optimize Now] [Set Up Later]

"Optimize Now" guides the user through:
1. Disable battery optimization for Katala
2. Enable "Auto-start" permission (Xiaomi, OPPO, Huawei — device-specific instructions)

### 24.7 Foreground Service — Deferred

A foreground service (persistent notification: "Katala is keeping your reminders active") is the only reliable way to prevent Android from killing the app. This is **deferred to Post-MVP** because:
- Significant UX cost (persistent notification)
- Battery impact
- Permission implications
- Not required to prove MVP value

If user feedback indicates reliability is a major issue, the foreground service will be added as an optional, opt-in feature in Post-MVP P3.

For MVP, the reliability communication is honest: Katala tells users when notifications may have been missed and guides them to manually optimize their device.

### 24.8 Manufacturer-Specific Guidance

#### Xiaomi (MIUI)
- Settings → Apps → Manage Apps → Katala → Battery Saver → "No restrictions"
- Settings → Apps → Manage Apps → Katala → Auto-start → Enable
- Security app → Permissions → Auto-start → Enable Katala

#### OPPO / realme (ColorOS)
- Settings → Battery → App Battery Management → Katala → "Don't optimize"
- Settings → Apps → Katala → Battery → "Allow background activity"
- Security app → Startup Manager → Enable Katala

#### Samsung (One UI)
- Settings → Apps → Katala → Battery → "Unrestricted"
- Settings → Battery and device care → Battery → Background usage limits → Add Katala to "Never sleeping apps"

#### Huawei (EMUI)
- Settings → Battery → App launch → Katala → Manage manually → Enable all three toggles
- Settings → Apps → Katala → Battery → "Don't optimize"

These guides are displayed contextually based on `Build.MANUFACTURER`.

---

## 25. Application Layer — Use Cases

### 25.1 Purpose

The Application layer orchestrates operations that span multiple layers (Data, Platform Bridges) or multiple domain entities. The UI never directly calls repositories or platform bridges for business operations.

### 25.2 Use Cases (MVP)

| Use Case | Responsibility |
|----------|---------------|
| `CreateReminderUseCase` | Validate NLP output, resolve contacts, persist + schedule, detect conflicts |
| `HandleNotificationActionUseCase` | Receive notification action, execute state transition, dismiss notification |
| `SnoozeReminderUseCase` | Transition to SNOOZED, schedule re-notification |
| `CompleteReminderUseCase` | Transition to COMPLETED, cancel notification |
| `DeleteReminderUseCase` | Soft-delete, cancel notification |
| `EditReminderUseCase` | Update reminder fields, cancel old notification, schedule new one |
| `ReconcileNotificationsUseCase` | Run reconciliation algorithm (§20.2), detect missed deliveries |
| `ResolveContactsUseCase` | Query ContactBridge for a name string, handle disambiguation |

### 25.3 CreateReminderUseCase — Full Flow

```
CreateReminderUseCase.execute(parsedReminder, clock):
  1. VALIDATE (Domain layer):
     - Check parsedReminder.issues.isEmpty
     - If issues exist → return ValidationFailed with issues (UI shows clarification card)

  2. RESOLVE CONTACTS (Application → Platform):
     - If parsedReminder.contactName != null:
       - contact = contactBridge.resolve(parsedReminder.contactName)
       - If multiple matches → return ContactDisambiguationRequired
       - If contact found → attach to validatedReminder

  3. VALIDATE URL (Domain layer):
     - If parsedReminder.url != null:
       - Validate http/https scheme
       - If invalid → strip URL, add issue

  4. CHECK CONFLICTS (Domain layer):
     - Query for conflicting reminders within ±15 minutes
     - If conflicts exist → return ConflictDetected with alternatives

  5. PERSIST (Data layer):
     - BEGIN TRANSACTION
     - INSERT reminder, trigger, action
     - COMMIT

  6. SCHEDULE NOTIFICATION (Application → Platform):
     - Try notificationBridge.schedule(reminder)
     - If success: UPDATE trigger.notification_scheduled = true, trigger.notification_id = id
     - If failure: trigger stays notification_scheduled = false (reconciliation will retry)

  7. RETURN RESULT:
     - Success: reminder persisted, notification scheduled (or will retry)
     - PartialSuccess: reminder persisted, notification scheduling failed
     - Failure: persistence failed (UI shows error + retry)
```

### 25.4 HandleNotificationActionUseCase

```
HandleNotificationActionUseCase.execute(action, reminderId):
  1. LOAD reminder from database
  2. IF reminder is null or deleted → cancel notification, return

  3. SWITCH action:
     case DONE:
       CompleteReminderUseCase.execute(reminderId)
     case SNOOZE:
       SnoozeReminderUseCase.execute(reminderId, duration: 10)
     case CALL_NOW:
       Execute CALL action (§22.2), then CompleteReminderUseCase.execute(reminderId)
     case OPEN_LINK:
       Execute OPEN_URL action (§22.2), then CompleteReminderUseCase.execute(reminderId)

  4. Dismiss the notification
```

### 25.5 Responsibility Boundaries

| Layer | Owns | Does NOT Own |
|-------|------|-------------|
| **UI** | Widgets, screens, navigation, confirmation/clarification card rendering | Business logic, persistence, notification scheduling |
| **Application** | Use cases, orchestration, transaction boundaries | NLP parsing, raw SQL, platform-specific notification APIs |
| **Domain** | NLP pipeline, state machine, conflict detection, validation, entity definitions | Persistence, platform APIs, UI rendering |
| **Data** | Repositories, Drift DAOs, query building, optimistic locking SQL | Notification scheduling, contact resolution, NLP |
| **Platform Bridges** | Native STT, native notifications, native contacts, file paths | Business logic, NLP, state machine, persistence |

**Critical rule:** Data layer does NOT call Platform Bridges. Data layer persists and queries. Application layer orchestrates: first persist, then schedule notifications via Platform Bridges. The repository returns the persisted entity; the use case schedules the notification.

---

## 26. Background Initialization

### 26.1 The Problem

Notification action callbacks, BOOT_COMPLETED receivers, and daily reconciliation tasks run without a Flutter UI lifecycle. Riverpod's `ProviderScope` is typically created by the Flutter app widget tree. In background contexts, the widget tree does not exist.

### 26.2 Background Execution Contexts

| Context | Platform | Trigger |
|---------|----------|---------|
| Notification action (main app) | iOS / Android | User taps notification action while app is backgrounded |
| Notification Service Extension | iOS | User taps notification action while app is killed |
| BOOT_COMPLETED receiver | Android | Device reboot |
| WorkManager periodic task | Android | Daily reconciliation |
| BGAppRefreshTask | iOS | Periodic background refresh |

### 26.3 Minimal Initialization Path

All background execution paths initialize a **minimum required dependency set** — NOT the full application:

```
Background Service Locator
│
├── Database (raw SQLite or Drift depending on context)
├── Clock (SystemClock)
├── ReminderRepository (Data layer — persistence only)
├── NotificationBridge (Platform)
│
└── (NO: UI, Riverpod, MaterialApp, WidgetsBinding, Animations, Navigation)
```

### 26.4 Static Service Locator

Background contexts use a static service locator instead of Riverpod:

```dart
/// Minimal service locator for background execution.
/// Not a full DI container — just the minimum dependencies.
class BackgroundServiceLocator {
  static Database? _db;
  static ReminderRepository? _reminderRepo;
  static NotificationBridge? _notificationBridge;

  static Future<void> initialize({
    required String databasePath,
    required NotificationBridge notificationBridge,
  }) async {
    _db = await _openDatabase(databasePath);
    _reminderRepo = ReminderRepositoryImpl(_db!);
    _notificationBridge = notificationBridge;
  }

  static ReminderRepository get reminderRepo => _reminderRepo!;
  static NotificationBridge get notificationBridge => _notificationBridge!;

  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
    _reminderRepo = null;
    _notificationBridge = null;
  }
}
```

### 26.5 iOS Notification Extension Initialization

The extension uses its own Swift implementation (§23.5) and does NOT run Dart. The extension's database layer is a lightweight SQLite wrapper, not Riverpod.

### 26.6 Android BOOT_COMPLETED Initialization

```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pendingResult = goAsync()

        // Initialize Flutter engine (if using Flutter background isolate)
        // OR initialize native Kotlin path for re-scheduling
        // For MVP: use native Kotlin for alarm re-scheduling
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = openDatabase(getSharedDbPath(context))
                val reminders = db.queryPendingReminders()
                val alarmManager = context.getSystemService(AlarmManager::class.java)
                for (reminder in reminders) {
                    scheduleAlarm(alarmManager, reminder)
                }
                db.updateMetadata("last_reconciled_at", Instant.now().toString())
                db.close()
            } finally {
                pendingResult.finish()
            }
        }
    }
}
```

### 26.7 Android WorkManager Reconciliation

```kotlin
class ReconciliationWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val db = openDatabase(getSharedDbPath(context))
        try {
            val reminders = db.queryPendingRemindersSortedByTime(limit = 60)
            val alarmManager = applicationContext.getSystemService(AlarmManager::class.java)

            // Cancel orphans, schedule missing, detect missed
            reconcile(db, alarmManager, reminders)

            db.updateMetadata("last_reconciled_at", Instant.now().toString())
            return Result.success()
        } catch (e: Exception) {
            return Result.retry()
        } finally {
            db.close()
        }
    }
}
```

Schedule: `PeriodicWorkRequestBuilder<ReconciliationWorker>(24, TimeUnit.HOURS)`

### 26.8 Error Handling in Background

- All background operations are wrapped in try/catch
- Database operations use `busy_timeout=3000` to handle SQLITE_BUSY
- If the database is unavailable: log, return, try again on next wake
- If the operation fails: log, return, try again on next wake
- Background failures are silent to the user (no UI to show errors)
- The next foreground reconciliation will catch any missed work

---

## 27. Failure Atomicity & Reconciliation

### 27.1 The Cross-System Transaction Problem

There is no distributed transaction that spans the SQLite database and the OS notification scheduler. The system must handle each failure scenario explicitly and converge back to a consistent state.

### 27.2 Scenario: Database Save Succeeds, Notification Scheduling Fails

```
State: Reminder persisted. Trigger.notification_scheduled = false.
Recovery: Next reconciliation (foreground or daily background) finds PENDING reminder
          with notification_scheduled = false. Schedules notification.
          Updates notification_scheduled = true.
User impact: Reminder is saved. Notification fires late (at next reconciliation).
             User sees "Reminder saved. Notification will fire soon." on save.
```

### 27.3 Scenario: Notification Scheduling Succeeds, Database Update Fails

```
State: OS has notification. Database has notification_scheduled = false
       (update failed after scheduling).
Recovery: Next reconciliation: OS.getScheduledIds() finds notification.
          DB says notification_scheduled = false for this reminder.
          Reconciliation sets notification_scheduled = true, notification_id = from OS.
User impact: Notification fires on time. No data inconsistency.
```

### 27.4 Scenario: Database Transaction Fails

```
State: Reminder NOT persisted. No notification scheduled.
Recovery: UI shows error + retry button. User re-initiates save.
User impact: User must tap Save again. No partial state.
```

### 27.5 Scenario: Notification Action Succeeds at OS Level, Domain Update Fails

```
State: Notification dismissed (OS). Reminder still PENDING (DB).
Cause: Extension crashed, database locked, or optimistic lock conflict.
Recovery: Reminder stays PENDING. Next foreground: user sees reminder still pending.
          User can complete/snooze from the app.
User impact: User tapped Done on notification but reminder is still pending.
             Annoying but not data-destroying.
```

### 27.6 Scenario: App Crashes Between Operations

```
State: Depends on when crash occurred.
Recovery: On next startup:
          1. DB integrity check
          2. Reconciliation runs (§20.2)
          3. Any partial state converges to consistent state
          (DB is authoritative; OS state is repaired from DB)
User impact: No permanent inconsistency. At worst, notification fires late
             or a Done action didn't persist and must be re-done.
```

### 27.7 Convergence Guarantee

The system guarantees eventual consistency under all failure scenarios:

- **DB is always authoritative.** OS state is rebuilt from DB during reconciliation.
- **Reminders cannot be lost.** Persistence failures are retried or reported to user.
- **Notifications may be delayed** but will eventually be scheduled.
- **Duplicate notification actions are safe** — optimistic locking ensures idempotent state transitions.
- **The system never reaches a state where DB says COMPLETED but OS notification is still scheduled** — reconciliation cancels orphaned OS notifications.

---

## 28. UX Specification

### 28.1 Design Principles

| Principle | Description |
|-----------|-------------|
| **Bird Eye Vigilance** | Clean, focused dashboard like a bird surveying from above |
| **Fast Interaction** | Voice-to-persisted-reminder in < 5 seconds |
| **Minimal Friction** | Remove unnecessary steps between intent and saved reminder |
| **Calm Notifications** | Non-intrusive but actionable |
| **Dark-Mode-First** | Default to dark theme; light mode available |
| **Subtle Bird Identity** | Bird-inspired design elements without being cartoonish |
| **Honest Communication** | Never hide platform limitations; clearly communicate reliability status |

### 28.2 Color System

**Dark Theme (Default):**

| Token | Value | Usage |
|-------|-------|-------|
| `surface-bg` | #0F0F14 | Main background |
| `surface-card` | #1A1A24 | Cards, bottom sheets |
| `surface-elevated` | #252535 | Elevated elements, dialogs |
| `text-primary` | #F0F0F5 | Primary text |
| `text-secondary` | #8888A0 | Secondary/muted text |
| `accent-primary` | #6C5CE7 | Primary actions, mic button |
| `accent-secondary` | #A29BFE | Secondary highlights |
| `success` | #00D2A0 | Completed reminders, save confirmations |
| `warning` | #FDCB6E | Conflicts, overdue indicators |
| `error` | #FF6B6B | Errors, destructive actions |
| `snooze` | #74B9FF | Snooze-related UI |
| `uncertain` | #E8A838 | delivery_uncertain indicators |

**Light Theme:**

| Token | Value | Usage |
|-------|-------|-------|
| `surface-bg` | #F8F9FA | Main background |
| `surface-card` | #FFFFFF | Cards |
| `surface-elevated` | #FFFFFF | Elevated elements |
| `text-primary` | #1A1A2E | Primary text |
| `text-secondary` | #666680 | Secondary text |
| (Accent colors remain the same) | | |

### 28.3 Typography

Use **Inter** (bundled as asset — no runtime font download). Fallback to system default (San Francisco on iOS, Roboto on Android).

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Headline | 28sp | Bold (700) | Screen titles |
| Title | 20sp | SemiBold (600) | Section headers, reminder titles in detail |
| Body | 16sp | Regular (400) | Body text, reminder titles in list |
| Caption | 14sp | Regular (400) | Timestamps, secondary info |
| Small | 12sp | Medium (500) | Badges, labels |

### 28.4 Screens

#### 28.4.1 Onboarding (First Launch Only)

**3-screen carousel:**

**Screen 1: Welcome**
- Katala logo (stylized bird silhouette)
- "Katala" title
- "Your voice, your reminders, your device. Nothing leaves your phone."
- [Get Started] button

**Screen 2: How It Works**
- Animated mic icon
- "Tap the mic and speak naturally. Katala understands you."
- Example: "Remind me to call Adam tomorrow at 3pm"
- [Next] button

**Screen 3: Permissions**
- 🎤 Microphone — "For voice input"
- 🔔 Notifications — "To alert you at the right time"
- [Grant] buttons
- "You can change these anytime in Settings"
- [Done] button

**Permission timing:** Only request Microphone and Notifications on onboarding. Request Contacts when user first creates a CALL/TEXT reminder.

#### 28.4.2 Home Screen (Timeline)

The primary screen. Shows upcoming reminders in chronological order, grouped by time.

```
┌──────────────────────────────────┐
│  Katala                    ⚙️    │
├──────────────────────────────────┤
│ ⚠ Katala was inactive for 14h   │  ← Reliability banner (when applicable)
│   2 reminders may be missed      │
│                                  │
│  ▸ OVERDUE (2)                   │  ← Red accent, expanded by default
│  ┌────────────────────────────┐  │
│  │ ⚠️ Call dentist       9 AM │  │  ← delivery_uncertain indicator
│  │ 🔴 Submit report    10 AM │  │
│  └────────────────────────────┘  │
│                                  │
│  ▸ TODAY                         │
│  ┌────────────────────────────┐  │
│  │ 📞 Call Adam          2 PM │  │
│  │ 🔗 Check report       8 PM │  │
│  └────────────────────────────┘  │
│                                  │
│  ▸ TOMORROW                      │
│  ▸ THIS WEEK                     │
│  ▸ LATER                         │
│                                  │
│         ┌──────────┐             │
│         │   🎤 Mic  │             │  ← FAB (primary accent)
│         └──────────┘             │
└──────────────────────────────────┘
```

**Timeline grouping:**
- **Overdue:** trigger_time < now AND status = PENDING. Red indicator.
- **Today:** trigger_time is today.
- **Tomorrow:** trigger_time is tomorrow.
- **This Week:** trigger_time is this week (after tomorrow).
- **Later:** trigger_time is beyond this week.

**Gestures:**
- Swipe right on reminder → Mark as COMPLETED (green confirmation)
- Swipe left on reminder → Delete → 5-second undo snackbar
- Tap reminder → Open detail view
- Pull down → Refresh (reconcile notifications)

**Empty state:**
```
[Stylized bird illustration]
"No reminders yet"
"Tap the mic to create one"
```

#### 28.4.3 Voice Input State

Pulsing mic icon with waveform animation. Live transcript appears as spoken. Manual tap-to-stop.

#### 28.4.4 Confirmation Card

Shows parsed reminder: title, time, contact (if any), URL (if any). [Save] [Edit] buttons. Never auto-saves — user must explicitly tap Save.

#### 28.4.5 Clarification Card

Shows original transcript + specific question + quick-pick chips + manual input. Save disabled until required fields filled.

#### 28.4.6 Reminder Detail View

Full reminder information with action buttons, edit capability, and status history.

#### 28.4.7 Settings Screen

- Default snooze duration
- Theme (Dark / Light / System)
- Language (English)
- Notification reliability status (Android)
- Database backup (opt-in)
- Privacy policy
- About

### 28.5 Swipe Gestures

- Swipe right → Complete (green confirmation stripe)
- Swipe left → Delete (red confirmation stripe) → 5-second undo snackbar
- Long press → Alternative to swipe for accessibility

### 28.6 Undo Snackbar

After completing or deleting a reminder:
```
┌──────────────────────────────────┐
│  ✓ "Call Adam" completed         │
│  ┌────────┐                      │
│  │  UNDO  │                      │  ← 5 second countdown bar
│  └────────┘                      │
└──────────────────────────────────┘
```

Undo reverses the state transition. After 5 seconds, the snackbar dismisses and the change is final.

### 28.7 Empty States

- **No reminders:** Bird illustration + "No reminders yet. Tap the mic to create one."
- **All done:** Bird illustration + "All caught up! 🎉"
- **Voice unavailable:** Mic button disabled + explanation + text input highlighted

---

## 29. Accessibility

- Target: WCAG 2.1 AA equivalent for mobile
- All tappable targets ≥ 48×48 dp
- Minimum contrast ratio: 4.5:1 for normal text, 3:1 for large text
- All interactive elements have accessibility labels
- Voice input: captions (live transcript) shown during speech
- Screen reader: all screens navigable via TalkBack/VoiceOver
- Long-press alternatives for all swipe gestures
- Haptic feedback for key actions (save, complete, error)
- Do not rely solely on color to convey state (use icons + text alongside color)

---

## 30. Privacy

### 30.1 Privacy Guarantees

1. **No Katala servers exist.** No data is transmitted to any server operated by Katala.
2. **No analytics.** No Firebase, Google Analytics, Mixpanel, Amplitude, or any telemetry.
3. **No crash reporting SDKs.** No Sentry, Crashlytics, Bugsnag.
4. **No advertising SDKs.**
5. **No user accounts.** No OAuth, no sign-in.
6. **No cloud speech recognition.** STT is configured for on-device only.
7. **No audio storage.** Audio streams to STT engine and is discarded immediately. No .wav/.m4a files.
8. **No runtime font downloads.** Inter font is bundled as an asset.
9. **Database excluded from device backups by default.** Users may opt in via Settings with a privacy notice.

### 30.2 Documented Privacy Exceptions

| Scenario | What Happens | Why |
|----------|-------------|-----|
| iOS speech recognition | Audio may be sent to Apple servers if on-device model is unavailable and `requiresOnDeviceRecognition` is false. Katala sets `requiresOnDeviceRecognition = true` to prevent this. If on-device is unavailable, voice is disabled entirely. | Platform behavior; Katala cannot bypass SFSpeechRecognizer architecture. |
| Android speech recognition | `EXTRA_PREFER_OFFLINE` is set, but on Android < 13 this is a preference, not a guarantee. On Android 13+, on-device is enforced. | Platform limitation; documented honestly. |
| Device backups (if user opts in) | Database may be included in iCloud/Google Drive backups. | User choice; default is excluded. |
| Contacts access | Contact names and phone numbers are read to resolve voice input. Stored in the database with the reminder. | Required for CALL/TEXT reminder functionality. |
| URL opening | URLs in reminders are opened in the user's default browser. | Required for OPEN_URL action. |

### 30.3 Network Safety — Automated Enforcement

- `flutter build` must not introduce any dependency that makes network calls
- CI pipeline includes a network traffic audit:
  - Run the app in simulator with network monitoring
  - Any HTTP/TCP connection initiated by Katala code fails the build
- Dependency review:
  - Every pub.dev package must be reviewed for network behavior before inclusion
  - `google_fonts` must be configured with bundled fonts only (no runtime fetching)

### 30.4 Permissions

| Permission | When Requested | If Denied |
|------------|---------------|-----------|
| Microphone | Onboarding | Mic button disabled; text input available |
| Notifications | Onboarding | Notifications won't fire; reminders still visible in-app; overdue shown prominently |
| Contacts | First CALL/TEXT reminder creation | Contact names stored as strings only; user can type phone number manually |
| Location | Post-MVP (geofencing) | Geofencing disabled; time-based reminders still work |

---

## 31. Security

### 31.1 URL Validation

- Only `http://` and `https://` schemes allowed for OPEN_URL
- `javascript:`, `file:`, `data:`, and custom schemes are rejected
- Validate before storing AND before opening
- URL length ≤ 2048 characters

### 31.2 Phone Number Handling

- Use `ACTION_DIAL` (not `ACTION_CALL`) on Android — opens dialer without auto-calling
- Use `tel:` URL scheme on iOS — shows confirmation before calling
- Never auto-initiate calls
- Never auto-send SMS

### 31.3 Database Security

- SQLite with parameterized queries (Drift) — no SQL injection
- Database excluded from backups by default
- Database encryption (SQLCipher) deferred to Post-MVP
- File protection: `NSFileProtectionCompleteUnlessOpen` (iOS) — allows lock-screen access for notification actions

### 31.4 Optimistic Locking

All state transitions use `WHERE version = ?` — prevents lost updates, double-complete, and edit+notify races.

### 31.5 No Logging of Personal Data

- Release builds must not log reminder content, contact names, phone numbers, or transcripts
- Debug builds may log for development purposes only

---

## 32. Offline Behavior

### 32.1 Fully Offline

All MVP features work with airplane mode enabled:
- Voice input (on-device STT)
- Text input
- NLP parsing
- Database persistence
- Notification scheduling (OS-local)
- Notification actions (background processing)
- Reconciliation

### 32.2 What Requires Network (Future / Optional)

- Map tiles for geofencing location picker (Post-MVP; Apple/Google Maps SDK)
- Device backups (if user opts in; platform-managed)
- Nothing in MVP requires network

---

## 33. Platform Architecture

### 33.1 Layer Architecture

```
┌─────────────────────────────────────────┐
│                 UI Layer                 │  ← Flutter Widgets, Screens, Navigation
│  (Riverpod providers for state)         │
├─────────────────────────────────────────┤
│           Application Layer             │  ← Use Cases, Orchestration
│  CreateReminderUseCase                  │
│  HandleNotificationActionUseCase        │
│  ReconcileNotificationsUseCase          │
├─────────────────────────────────────────┤
│             Domain Layer                │  ← Pure Dart, no platform deps
│  NLP Pipeline (5 stages)                │
│  State Machine                          │
│  Conflict Detection                     │
│  Validation Rules                       │
│  Entity Definitions                     │
├──────────────────────┬──────────────────┤
│     Data Layer       │  Platform Bridges│
│  Repositories        │  SpeechBridge    │  ← Abstract interfaces
│  Drift DAOs          │  NotificationBridge│   in Domain layer
│  SQLite (raw, ext.)  │  ContactBridge   │
│                      │  Clock (injectable)│
└──────────────────────┴──────────────────┘
```

### 33.2 Dependency Rules

1. **UI → Application → Domain:** Standard downward dependency.
2. **Data → Domain:** Data layer depends on Domain entities. Domain does NOT depend on Data.
3. **Platform Bridges → Domain:** Platform bridges implement Domain-defined abstract interfaces. Domain does NOT depend on platform implementations.
4. **Application → Data + Platform Bridges:** Application orchestrates across both.
5. **Cross-layer prohibition:** Data layer does NOT call Platform Bridges. UI does NOT call repositories or bridges directly for business operations.

### 33.3 Identical Business Logic

All business logic (NLP pipeline, state machine, conflict detection, validation) produces identical results on iOS and Android. Platform-specific code is confined to Platform Bridges.

### 33.4 Background Service Locator (Non-Riverpod)

Background execution contexts (§26) use a static service locator instead of Riverpod. This is intentional because Riverpod's `ProviderScope` requires a Flutter widget tree lifecycle.

---

## 34. Platform Bridge Contracts

### 34.1 SpeechBridge

```dart
/// Abstract interface defined in Domain layer.
/// Implemented per-platform using native STT APIs.
abstract class SpeechBridge {
  /// Whether on-device speech recognition is currently available.
  Future<SpeechAvailability> get availability;

  /// Whether on-device recognition is available (stricter than availability).
  /// Returns false if only cloud recognition is available.
  Future<bool> get isOnDeviceAvailable;

  /// Start listening. Returns a stream of partial transcripts.
  /// Throws [SpeechPermissionDenied] if mic permission not granted.
  /// Throws [SpeechUnavailable] if no on-device model is available.
  Stream<String> startListening();

  /// Stop listening and return the final transcript.
  Future<String> stopListening();

  /// Cancel listening without returning a transcript.
  Future<void> cancel();

  /// Dispose resources.
  Future<void> dispose();
}

enum SpeechAvailability {
  available,         // On-device model loaded; ready
  unavailable,       // No on-device model; voice disabled
  permissionDenied,  // Mic permission not granted
  notSupported,      // Language not supported for on-device
}

/// Errors
class SpeechPermissionDenied implements Exception {}
class SpeechUnavailable implements Exception {
  final String reason;  // e.g., "On-device model not available for en-US"
}
class SpeechRecognitionFailed implements Exception {
  final String reason;  // e.g., "No speech detected", "Timeout"
}
class SpeechTimeout implements Exception {}  // No speech for N seconds
class SpeechNoSpeech implements Exception {} // Silence detected
```

### 34.2 NotificationBridge

```dart
abstract class NotificationBridge {
  /// Configure categories at app init.
  Future<void> configureCategories();

  /// Schedule a notification for a reminder.
  /// Returns the platform notification ID.
  /// Idempotent: cancels existing notification for same reminder before scheduling.
  /// Throws [NotificationSchedulingFailed] on failure.
  Future<int> schedule(ValidatedReminder reminder);

  /// Cancel a notification by platform notification ID.
  /// Idempotent: no error if notification doesn't exist.
  Future<void> cancel(int notificationId);

  /// Cancel all notifications for a reminder.
  Future<void> cancelForReminder(String reminderId);

  /// Get the set of currently scheduled notification IDs (best-effort on Android).
  Future<Set<int>> getScheduledIds();

  /// Full reconciliation: compare DB state with OS state, fix discrepancies.
  /// Returns reconciliation result.
  Future<ReconciliationResult> reconcile(
    List<Reminder> pendingReminders, {
    required int maxScheduled,  // 60 on iOS, unlimited on Android
  });

  /// Clean up orphaned notifications (IDs not in the provided set of reminder IDs).
  Future<int> cleanupOrphans(Set<String> activeReminderIds);

  /// Dismiss a currently displayed notification.
  Future<void> dismiss(int notificationId);
}

class ReconciliationResult {
  final int scheduled;
  final int cancelled;
  final int failed;
  final List<String> deliveryUncertainReminderIds;
  final List<String> errors;
}

class NotificationSchedulingFailed implements Exception {
  final String reason;
}
```

### 34.3 ContactBridge

```dart
abstract class ContactBridge {
  /// Resolve a contact name string to device contacts.
  /// Returns empty list if no match or permission denied.
  Future<List<ResolvedContact>> resolve(String name);

  /// Get contact by platform ID.
  Future<ResolvedContact?> getById(String contactId);
}

class ResolvedContact {
  final String platformId;
  final String displayName;
  final String? phoneNumber;  // Primary phone number
  final List<String>? allPhoneNumbers;
}
```

### 34.4 Clock

```dart
abstract class Clock {
  DateTime now();
  String localTimezone();
}

class SystemClock implements Clock {
  @override DateTime now() => DateTime.now();
  @override String localTimezone() => DateTime.now().timeZoneName;
}

class FakeClock implements Clock {
  DateTime _now;
  String _timezone;
  FakeClock(this._now, {String? timezone}) : _timezone = timezone ?? 'UTC';
  @override DateTime now() => _now;
  @override String localTimezone() => _timezone;
  void advance(Duration d) => _now = _now.add(d);
}
```

---

## 35. Error Handling & Failure Modes

### 35.1 Error Taxonomy

| Category | Examples | Handling |
|----------|---------|----------|
| **Recoverable (retry)** | DB busy, transient lock conflict | Retry once, then report |
| **Recoverable (user action)** | Permission denied, STT unavailable | Show explanation + action button (Settings, retry) |
| **Recoverable (delayed)** | Notification scheduling failed | Persist; retry on next reconciliation |
| **Non-recoverable** | Database corruption | Show recovery screen (restore/reset) |
| **Background silent** | Extension crash, worker killed | Log; retry on next wake; surface on next foreground |

### 35.2 User-Facing Error States

| Error | UI |
|-------|-----|
| Mic permission denied | "Microphone access needed. Enable in Settings." [Open Settings] |
| Notification permission denied | "Notifications are disabled. Reminders will only appear when you open the app." |
| STT unavailable (no on-device model) | "Voice input unavailable — on-device speech model not found. Use text input below." |
| STT recognition failed | "I didn't catch that. Try again or type your reminder." [Retry] [Type Instead] |
| NLP parse failed | Show transcript + "I couldn't understand that. Edit below." with editable fields |
| Database write failed | "Couldn't save. Try again." [Retry] |
| Database corruption | "Database integrity check failed." [Restore from Backup] [Reset Database] |
| Contact permission denied | Store name string only; show "(no phone number)" in confirmation |
| Contact not found | Store name string only; show "(no phone number found)" |
| Notification scheduling failed (partial) | "Reminder saved. Notification scheduling will retry." |
| Multiple reminders may be missed | "Katala was inactive for [duration]. [N] reminders may have been missed." [View] |
| URL invalid | Strip URL; show warning in confirmation card |
| Conflict detected | Show conflict card with alternative time |

---

## 36. Lifecycle, Reboot & Background Behavior

### 36.1 App Foreground

1. Database integrity check (`PRAGMA integrity_check`)
2. `ReconcileNotificationsUseCase` runs:
   - Cancel orphans
   - Schedule missing
   - Detect missed deliveries
   - Update `last_reconciled_at`
3. UI renders timeline

### 36.2 App Background

- No special behavior
- Scheduled notifications fire via OS
- Notification actions handled by extension (iOS) or BroadcastReceiver (Android)

### 36.3 App Killed (iOS)

- Scheduled notifications still fire via OS
- Notification actions handled by Notification Service Extension (§23)
- BGAppRefreshTask may wake app for reconciliation (best-effort)

### 36.4 App Killed (Android — Normal)

- Scheduled alarms fire via AlarmManager
- Notification actions handled by BroadcastReceiver
- BOOT_COMPLETED receiver re-schedules alarms on reboot

### 36.5 App Force-Stopped (Android)

- All alarms cancelled
- BOOT_COMPLETED receiver disabled
- WorkManager tasks cancelled
- **No recovery until user manually opens the app**
- On next foreground: reconciliation detects gap, sets `delivery_uncertain`, shows reliability banner

### 36.6 Device Reboot

**iOS:** No special handling; BGAppRefreshTask re-scheduled by OS on next opportunity.

**Android:** `BOOT_COMPLETED` receiver:
1. Opens database
2. Queries all PENDING/SNOOZED reminders
3. Re-schedules all alarms
4. Updates `last_reconciled_at`
5. Completes within 10 seconds (via `goAsync()`) or delegates to `OneTimeWorkRequest`

### 36.7 Daily Background Wake

**iOS:** `BGAppRefreshTask` — runs reconciliation. Best-effort; OS may delay or skip.

**Android:** `WorkManager` periodic task (24-hour interval) — runs reconciliation. Subject to Doze and OEM restrictions.

---

## 37. Build Configuration

### 37.1 Flutter & Dart

| Requirement | Version |
|-------------|---------|
| Flutter SDK | ≥ 3.24 (stable channel) |
| Dart SDK | ≥ 3.5 |
| Flutter version policy | Pin to a specific stable Flutter version in CI; test upgrades before adopting |

### 37.2 Platform Deployment Targets

| Platform | Minimum Version |
|----------|----------------|
| iOS | 16.0 |
| Android (minSdkVersion) | 26 (Android 8.0) |
| Android (targetSdkVersion) | 34 (Android 14) |
| Android (compileSdkVersion) | 34 |

### 37.3 Native Languages

| Platform | Language | Minimum Version |
|----------|----------|----------------|
| iOS | Swift | 5.9 |
| Android | Kotlin | 1.9 |

### 37.4 Build Tools

| Tool | Version |
|------|---------|
| Xcode | ≥ 15.0 |
| Android Gradle Plugin | ≥ 8.2 |
| Gradle | ≥ 8.4 |
| CocoaPods | Not used (Swift Package Manager preferred) |

### 37.5 iOS-Specific Configuration

#### Entitlements (Main App)

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.katala.app</string>
</array>
```

#### Entitlements (Notification Extension)

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.katala.app</string>
</array>
```

#### Info.plist (Main App)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Katala needs microphone access to convert your voice into reminders. All processing happens on-device.</string>

<key>NSContactsUsageDescription</key>
<string>Katala uses contacts to match names in your reminders to phone numbers for calling and texting.</string>

<key>UIApplicationSupportsIndirectInputEvents</key>
<true/>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>        <!-- For speech recognition -->
    <string>fetch</string>        <!-- For BGAppRefreshTask -->
</array>
```

#### Info.plist (Notification Extension)

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.usernotifications.service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
</dict>

<key>UNNotificationExtensionCategory</key>
<array>
    <string>REMINDER_GENERAL</string>
    <string>REMINDER_CALL</string>
    <string>REMINDER_TEXT</string>
    <string>REMINDER_URL</string>
</array>
```

### 37.6 Android-Specific Configuration

#### AndroidManifest.xml Permissions

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />  <!-- Post-MVP -->
```

#### AndroidManifest.xml Receivers

```xml
<receiver
    android:name=".BootReceiver"
    android:exported="true"
    android:enabled="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>

<receiver
    android:name=".NotificationActionReceiver"
    android:exported="false">
</receiver>
```

### 37.7 Dependency Version Policy

- All dependencies pinned to exact versions (no `^` or `~` in pubspec.yaml)
- Security patches applied within 30 days
- Breaking changes evaluated against MVP stability requirements
- New dependencies require code comment justifying inclusion

---

## 38. Testing Strategy

### 38.1 Architecture-Level Acceptance Tests

#### iOS

| Test | Description |
|------|-------------|
| `ios_notification_action_while_killed` | Kill app, deliver notification, tap Done on lock screen, launch app, verify reminder COMPLETED |
| `ios_notification_action_while_running` | App in foreground, deliver notification, tap Done, verify COMPLETED |
| `ios_database_concurrent_access` | Rapid alternation: main app writes + extension writes; verify no corruption, optimistic lock works |
| `ios_extension_initialization` | Extension launches, opens shared DB, transitions state, dismisses — all < 1 second |
| `ios_app_group_configuration` | Both targets can read/write to shared container |

#### Android

| Test | Description |
|------|-------------|
| `android_boot_receiver` | Simulate BOOT_COMPLETED, verify all PENDING reminders re-scheduled |
| `android_doze_behavior` | Device enters Doze, verify alarms still fire (setExactAndAllowWhileIdle) |
| `android_process_death` | Kill process, verify alarms still fire, verify reconciliation on foreground |
| `android_notification_reconciliation` | Manually clear alarms, open app, verify reconciliation re-schedules |
| `android_oem_restrictions` | Test on Xiaomi/OPPO/Samsung devices; verify guidance is correct |

#### Core

| Test | Description |
|------|-------------|
| `duplicate_notification_action` | Two rapid Done taps on same notification; verify only one transition succeeds |
| `concurrent_reminder_edit` | Edit reminder in-app while extension processes action; verify optimistic lock |
| `scheduling_failure` | Mock NotificationBridge failure; verify reminder persists, reconciliation schedules |
| `database_failure` | Trigger write failure; verify error reported, no partial state, retry works |
| `reconciliation_convergence` | Create inconsistent DB+OS state; run reconciliation; verify convergence |
| `nlp_determinism` | Run NLP pipeline 100× with same input + FakeClock; verify identical output |
| `all_validator_issues` | For each `ValidationIssue` enum value: verify produced when expected |
| `state_machine_all_transitions` | For each transition in §15.2: verify it works, verify guards |

### 38.2 Unit Tests

- **NLP Pipeline:** Each stage tested independently with FakeClock. Known inputs → expected outputs.
- **State Machine:** All transitions + guards + optimistic lock conflicts.
- **Conflict Detection:** Mocked repository returning known reminders; verify conflicts and alternative times.
- **Temporal Resolution:** FakeClock at known datetimes; verify resolution of every expression type (§11.2).
- **Repository:** In-memory SQLite; test CRUD, optimistic locking, soft delete.
- **Validation:** Every `ValidationIssue` produced for corresponding input.

### 38.3 Integration Tests

- **Full voice→persist flow:** Mocked STT produces known transcript → NLP → confirmation → save → DB has correct row.
- **Notification scheduling:** Full flow from create to OS notification (integration test on device/simulator).
- **Background action handling:** Trigger notification action via OS; verify DB state.

### 38.4 Test Constraints

- Tests must not depend on: real time (use FakeClock), GPS, real speech audio, external applications, network
- Tests must be runnable in CI without physical devices for unit + widget tests
- Device-dependent tests (notification actions, STT) may require physical device or simulator; document which tests need real hardware

### 38.5 Network Traffic Audit (CI)

```bash
# In CI pipeline:
# 1. Build release app
# 2. Run on simulator with network proxy (mitmproxy or similar)
# 3. Perform all MVP use cases
# 4. Assert zero network connections initiated by app process
# 5. Fail build if any connection detected
```

---

## 39. Acceptance Criteria

### 39.1 Voice Input

| ID | Criterion |
|----|----------|
| AC-1 | User can create a reminder from voice input in < 5 seconds (mic tap to persisted) on a mid-range device |
| AC-2 | User can see live transcript as they speak |
| AC-3 | User must explicitly tap Save to persist a reminder |
| AC-4 | When STT is unavailable, voice input is disabled and text input is presented as the primary path |

### 39.2 NLP

| ID | Criterion |
|----|----------|
| AC-5 | "Remind me to call Adam tomorrow at 3 PM" extracts: title="call Adam", action=CALL, contact_name="Adam", time="tomorrow 3:00 PM" |
| AC-6 | "Pa-remind mo ko tumawag kay Mama bukas ng 9 AM" extracts: intent=CREATE_REMINDER, title="tumawag kay Mama", action=CALL, contact_name="Mama", time="tomorrow 9:00 AM" |
| AC-7 | Missing time → clarification card with time picker, not a generic error |
| AC-8 | Bare number 1-12 → AM/PM toggle shown; no auto-resolution |
| AC-9 | "Remind me to buy groceries" → missing time → clarification card; Save disabled until time set |

### 39.3 Notifications

| ID | Criterion |
|----|----------|
| AC-10 | Notification fires at scheduled time with contextual action buttons |
| AC-11 | Tapping Done on notification marks reminder COMPLETED without opening app |
| AC-12 | Tapping Snooze on notification marks reminder SNOOZED and schedules re-notification |
| AC-13 | On iOS, up to 60 nearest reminders have notifications scheduled; beyond 64, farther reminders are unscheduled but remain in DB |
| AC-14 | On Android, alarms reschedule after device reboot |

### 39.4 Reconciliation

| ID | Criterion |
|----|----------|
| AC-15 | On every foreground entry, reconciliation cancels orphaned OS notifications and schedules missing ones |
| AC-16 | When app detects it was inactive during reminder fire times, sets delivery_status to `delivery_uncertain` |
| AC-17 | Reliability banner shown when missed deliveries are detected |

### 39.5 Database

| ID | Criterion |
|----|----------|
| AC-18 | Database integrity check runs on startup; failure shows recovery screen |
| AC-19 | Concurrent state transitions (app + extension) use optimistic locking; only one succeeds |
| AC-20 | Database excluded from device backups by default |

### 39.6 Privacy

| ID | Criterion |
|----|----------|
| AC-21 | Zero network requests initiated by Katala code during MVP use cases |
| AC-22 | STT configured for on-device only on both platforms |
| AC-23 | Audio is never stored to disk |
| AC-24 | Font is bundled; no runtime font download |

### 39.7 Conflict Detection

| ID | Criterion |
|----|----------|
| AC-25 | Creating reminder within 15 min of existing PENDING reminder triggers conflict warning |
| AC-26 | Conflict warning offers alternative time as primary option |
| AC-27 | "Save Anyway" is available as secondary option |

### 39.8 Reliability

| ID | Criterion |
|----|----------|
| AC-28 | iOS notification actions work while main app is killed (extension handles state transition) |
| AC-29 | Android missed-notification detection works after force-stop |
| AC-30 | Reliability status is visible in Settings on Android |
| AC-31 | User guidance for battery optimization is device-specific (matches Build.MANUFACTURER) |

---

## 40. Implementation Constraints

### 40.1 Absolute Prohibitions

| ID | Constraint |
|----|-----------|
| CC-1 | **No network requests.** No HTTP, no WebSocket, no TCP socket connections initiated by Katala code. |
| CC-2 | **No analytics SDKs.** No Firebase, Google Analytics, Mixpanel, Amplitude, or any telemetry. |
| CC-3 | **No crash reporting SDKs.** No Sentry, Crashlytics, Bugsnag. |
| CC-4 | **No advertising SDKs.** |
| CC-5 | **No user authentication.** No accounts, no OAuth, no biometric app lock (MVP). |
| CC-6 | **No cloud STT.** Always enforce on-device recognition. If on-device unavailable, disable voice — do NOT silently fall back. |
| CC-7 | **Use Drift for persistence** in main app. Extension uses lightweight raw SQLite. |
| CC-8 | **Rule-based NLP only.** No TensorFlow Lite, ONNX, or ML inference. |
| CC-9 | **Never auto-initiate calls.** Use ACTION_DIAL / tel: URL. Never ACTION_CALL. |
| CC-10 | **Never auto-send messages.** Open compose screen only. |
| CC-11 | **Never store audio.** Stream to STT, discard immediately. No .wav/.m4a files. |
| CC-12 | **Never log personal data in release builds.** |
| CC-13 | **Always store times as UTC with timezone.** |

### 40.2 Dependency Whitelist

Allowed pub.dev packages:

| Package | Purpose | Notes |
|---------|---------|-------|
| `drift`, `drift_flutter` | Database | Main app only |
| `flutter_riverpod` | State management + DI | Main app only; NOT in background contexts |
| `uuid` | UUID generation | |
| `intl` | Date formatting | |
| `path_provider` | File paths | Main app only |
| `url_launcher` | URL/dialer/sms opening | |
| `permission_handler` | Runtime permissions | |
| `flutter_local_notifications` | Notification scheduling abstraction | Verify background action handling on both platforms |

**Removed from V2:**
- ~~`speech_to_text`~~ — Does not expose on-device-only enforcement. Replaced by custom native STT bridge.
- ~~`google_fonts`~~ — Replaced with bundled Inter font asset (no runtime download).

Any package not on this list requires a code comment justifying its inclusion.

### 40.3 Code Quality

| ID | Constraint |
|----|-----------|
| CC-14 | All NLP functions must be pure: deterministic output for deterministic input |
| CC-15 | Use dependency injection for Clock, Database, and Platform Bridges |
| CC-16 | Write tests for all NLP pipeline stages, state machine, conflict detection |
| CC-17 | Document any design decision that deviates from this spec |
| CC-18 | Business logic must produce identical results on iOS and Android |
| CC-19 | Data layer does NOT call Platform Bridges; Application layer orchestrates |

---

## 41. Architectural Decisions

| ID | Decision | Rationale | Alternatives Rejected |
|----|----------|-----------|----------------------|
| ADR-1 | Flutter cross-platform | Single codebase for iOS + Android | Native Swift + Kotlin (higher quality but 2x work) |
| ADR-2 | Drift for persistence (main app) | Type-safe SQLite wrapper, migration support, reactive streams | Isar (deprecated), Hive (NoSQL, no queries) |
| ADR-3 | Native OS speech engines via custom bridge | Zero-cost, on-device, enforceable on-device-only. Custom bridge required because no Flutter package exposes `requiresOnDeviceRecognition` (iOS) and `EXTRA_PREFER_OFFLINE` (Android) simultaneously. | `speech_to_text` package (cannot enforce on-device-only; violates CC-6) |
| ADR-4 | Rule-based regex NLP | Deterministic, fast, offline, testable | ML/NLU (non-deterministic, model size, offline challenges) |
| ADR-5 | Riverpod for state management (main app) | Compile-safe DI, testable, Flutter-native | BLoC (more boilerplate), Provider (less type-safe) |
| ADR-6 | Never auto-save | One mistimed auto-saved reminder destroys more trust than one extra tap | Auto-save at HIGH confidence (V1 approach — rejected) |
| ADR-7 | Exclude database from backups by default | Aligns with "data never leaves device" promise; user can opt in | Include by default (V1 approach — conflicts with privacy claims) |
| ADR-8 | Always show AM/PM toggle for bare numbers | Getting it wrong causes missed reminders; one tap is cheap | Heuristic 1-6 ask, 7-11 auto (V1 approach — error-prone) |
| ADR-9 | Geofencing is Post-MVP | Reduces MVP surface area while preserving core voice→notification value | Include in MVP (increases scope by ~3 weeks) |
| ADR-10 | Custom STT native bridge mandatory | `speech_to_text` package cannot enforce CC-6 (on-device-only). Custom bridge uses `SFSpeechRecognizer.requiresOnDeviceRecognition = true` (iOS) and `RecognizerIntent.EXTRA_PREFER_OFFLINE` (Android) | Using `speech_to_text` package (silently violates privacy requirement) |
| ADR-11 | Notification scheduling is Application-layer concern | Data layer persists and queries. Application layer orchestrates: first persist, then schedule/cancel via Platform Bridges. Repository returns the persisted entity; the caller schedules the notification. | Repository calls bridge internally (layer violation, harder to test) |
| ADR-12 | iOS Notification Service Extension with App Group + lightweight SQLite | Required for FR-8 (background notification actions). Extension uses raw SQLite, not Drift, to minimize binary size and launch time. App Group shared container for database file. | Foreground-only notification actions (violates FR-8); UNNotificationAction with foreground option (opens app — violates FR-8) |
| ADR-13 | Static service locator for background execution | Background contexts (notification callbacks, BOOT_COMPLETED, WorkManager) run without Flutter UI lifecycle. Riverpod requires widget tree. A minimal static service locator provides just the dependencies needed. | Initialize full Riverpod graph in background (slow, fragile, depends on WidgetsBinding) |
| ADR-14 | Database file protection: `NSFileProtectionCompleteUnlessOpen` | Allows lock-screen notification actions to access the database. Main app holds file handle after first launch. | `NSFileProtectionComplete` (blocks lock-screen access; notification actions fail) |
| ADR-15 | Android foreground service deferred to Post-MVP | Significant UX cost (persistent notification), battery impact, and permission implications. MVP communicates reliability honestly and guides users to optimize. | Include foreground service in MVP (adds scope, may not be needed for all users) |
| ADR-16 | No confidence scores; explicit validation issues instead | V2's 0.0–1.0 field was undefined and unactionable. Replacement: `List<ValidationIssue>` with specific UX mappings. Deterministic, testable, no pseudo-ML. | Define a calculation formula (fragile, untestable, arbitrary thresholds) |
| ADR-17 | Typed accessor methods for UserPreference | MVP has < 20 preferences. Store as key-value JSON. Access through typed getter/setter methods with unit tests. | Full typed schema (too heavy for MVP); raw string access (error-prone) |
| ADR-18 | Database = authoritative state; OS scheduler = derived state | Only the database knows the truth. OS notification state is rebuilt from DB during reconciliation. | OS as source of truth (unreliable; alarms cleared on force-stop, reboot) |
| ADR-19 | NLP pipeline outputs `ParsedReminder` with contact names as strings; Application layer resolves via `ContactBridge` | Keeps NLP pure and platform-independent. Contact resolution requires platform APIs and permissions. | Contact resolution inside NLP (violates purity; hard to test; platform-dependent) |

---

## 42. Implementation Roadmap

### Phase 1: Project Setup (Week 1)
- Flutter project scaffold (`flutter create`)
- Xcode workspace with main app target + Notification Service Extension target
- App Group configuration (both targets)
- Drift database setup with full schema including V3 fields (delivery_status, version, app_metadata)
- Swift extension database layer (lightweight SQLite)
- Platform bridge interfaces defined in Dart
- CI pipeline (lint, test, build, network traffic audit)
- Bundled Inter font

### Phase 2: Platform Bridges — STT + Notifications (Weeks 2-3)
- iOS SpeechBridge (`SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`)
- Android SpeechBridge (`SpeechRecognizer` with `EXTRA_PREFER_OFFLINE`)
- iOS NotificationBridge (`UNUserNotificationCenter`, categories, BGAppRefreshTask)
- iOS Notification Service Extension (state transition, App Group database access)
- Android NotificationBridge (`AlarmManager`, `BOOT_COMPLETED` receiver, `WorkManager`)
- Notification action handlers (Done, Snooze, Call, Open Link)
- Bridge integration tests

### Phase 3: Domain Layer — NLP Pipeline (Weeks 4-5)
- Pre-Processor (Stage 1)
- Intent Detector (Stage 2) with English + Taglish patterns
- Entity Extractor (Stage 3): contact name (as string), URL, phone, action
- Temporal Resolver (Stage 4): all expression types
- Validator (Stage 5): `ValidationIssue` enum → UX mapping
- `ParsedReminder` output (no platform dependencies)
- Unit tests for all stages with `FakeClock` injection

### Phase 4: Data Layer (Week 6)
- Drift DAOs for Reminder, Trigger, Action, AppMetadata
- Repository pattern
- State machine transitions with optimistic locking
- Conflict detection + alternative suggestion
- Soft-delete + retention cleanup
- Database integrity check on startup
- Data layer tests

### Phase 5: Application Layer — Use Cases (Week 7)
- `CreateReminderUseCase` (validate → resolve contacts → check conflicts → persist → schedule)
- `HandleNotificationActionUseCase`
- `CompleteReminderUseCase`
- `SnoozeReminderUseCase`
- `DeleteReminderUseCase`
- `EditReminderUseCase`
- `ReconcileNotificationsUseCase` (with delivery status detection)
- `ResolveContactsUseCase`
- ContactBridge (iOS: CNContactStore; Android: ContactsContract)
- Use case integration tests

### Phase 6: UI — Core Screens (Weeks 8-9)
- Home screen timeline with grouping (overdue, today, tomorrow, later)
- Reliability banner for missed notifications
- Delivery status indicators (⚠️ for `delivery_uncertain`)
- Voice input UI (mic, waveform, live transcript, tap-to-stop)
- Confirmation card (parsed fields, Save/Edit)
- Clarification card (specific questions, quick-pick chips)
- Reminder detail view
- Reminder edit form
- Onboarding carousel (permissions: mic + notifications only)
- Settings screen (including notification reliability on Android)
- Empty/error states
- Swipe gestures with long-press alternatives
- Undo snackbar
- Dark/light theme

### Phase 7: Android OEM Reliability (Week 10)
- `last_reconciled_at` tracking in AppMetadata
- Reliability status determination (good/fair/poor)
- Manufacturer-specific guidance content
- Battery optimization detection + Settings shortcut
- Notification reliability screen in Settings
- `delivery_uncertain` banner on home screen
- Android background initialization (Kotlin native for boot receiver + WorkManager)

### Phase 8: Polish & Testing (Weeks 11-12)
- Accessibility audit and fixes
- Animations (mic pulse, save confirmation, swipe)
- Haptic feedback
- Network traffic audit (zero requests verification)
- Release build testing on iOS and Android devices
- iOS: test notification actions while app killed
- Android: test on Xiaomi/OPPO/Samsung devices
- Performance: voice-to-save < 5 seconds
- Edge case testing (all failure scenarios from §27)
- Bug fixes

### Post-MVP Phases

- **Phase 9:** Geofencing
- **Phase 10:** Follow-Up Engine
- **Phase 11:** Enhanced NLP (Filipino full intent, voice EDIT/DELETE/QUERY)
- **Phase 12:** Foreground service (Android, opt-in)
- **Phase 13:** Database encryption, data export, tablet layout

---

## 43. Open Product Decisions

| ID | Question | Default | Options |
|----|----------|---------|---------|
| PD-1 | Should the database be excluded from device backups? | **Yes, exclude.** Aligns with privacy promise. Users who want backups can opt in via Settings. | (a) Exclude by default (recommended), (b) Include by default with disclosure |
| PD-2 | Should "tomorrow" without a time always ask or use a default? | **Ask with quick-pick chips.** No default time. Save is disabled until user sets a time. | (a) Always ask (current), (b) Use 9:00 AM default with option to change |
| PD-3 | What is the exact notification chirp sound? | Royalty-free bird chirp < 5 seconds. Source TBD. | (a) Source from freesound.org, (b) Commission custom sound, (c) Use simple tone |
| PD-4 | Should the Katala logo be realistic or stylized? | Stylized/minimal cockatoo silhouette. Monochrome. | Designer decision |
| PD-5 | Should compound commands be split? | **No for MVP.** Treat as single reminder. | (a) Single reminder (MVP), (b) Split into multiple (Post-MVP) |
| PD-6 | Should completed reminders be visible on the home timeline? | **Hidden by default.** Accessible via "Completed" filter. | (a) Hidden (current), (b) Show with strikethrough |
| PD-7 | What is the app store name, subtitle, and description? | Deferred to launch prep. | — |
| PD-8 | Should Katala support pure Filipino voice input by using cloud STT? | **No.** On-device only. Filipino text input works. Evaluate Post-MVP if platform support improves. | (a) No cloud STT (current), (b) Offer opt-in cloud STT (privacy trade-off) |

---

## 44. Architecture Review Resolution Matrix

### Critical Findings

| Finding | Decision | Resolution | Section Changed |
|---------|----------|------------|-----------------|
| **C1:** iOS notification extension database access undefined | ACCEPT | New §23: Xcode targets, App Group, shared container, lightweight SQLite layer, extension initialization sequence, WAL mode, SQLITE_BUSY handling, optimistic locking, concurrency model, failure behavior, entitlements, Info.plist, testing strategy | §23 (new), §17, §26, §37 |
| **C2:** Android notification reliability undefined for force-stop/OEM kill | ACCEPT | New §24: normal behavior, Doze, force-stop, boot receiver timing, WorkManager strategy, `last_reconciled_at` gap detection, delivery status states, reliability status UI, manufacturer-specific guidance, foreground service decision (deferred) | §24 (new), §21 (new), §26, §36, §37 |
| **C3:** `speech_to_text` package cannot enforce on-device-only | ACCEPT | Removed from dependency whitelist. ADR-10 mandates custom native STT bridge. SpeechBridge contract expanded with `isOnDeviceAvailable`, error types. | §34.1, §40.2, §41 (ADR-3, ADR-10) |

### High-Priority Findings

| Finding | Decision | Resolution | Section Changed |
|---------|----------|------------|-----------------|
| **A1:** Application layer boundaries undefined | ACCEPT | New §25: explicit Use Cases defined (`CreateReminderUseCase`, `HandleNotificationActionUseCase`, etc.). Layer responsibility boundaries clarified. ADR-11: notification scheduling is Application-layer concern. | §25 (new), §33, §41 (ADR-11) |
| **A3:** Contact resolution violates NLP purity | ACCEPT | NLP pipeline now outputs `ParsedReminder` with contact names as strings. Application layer resolves via `ContactBridge`. `ParsedReminder` → `ValidatedReminder` split. | §8.2, §8.3, §10.4 |
| **B1:** SpeechBridge contract underspecified | ACCEPT | Expanded §34.1: availability, isOnDeviceAvailable, start, stop, cancel, error types (SpeechPermissionDenied, SpeechUnavailable, SpeechRecognitionFailed, SpeechTimeout, SpeechNoSpeech) | §34.1 |
| **B2:** NotificationBridge `reconcile()` underspecified | ACCEPT | Expanded §34.2: `ReconciliationResult` return type, `cleanupOrphans()`, `dismiss()`, idempotency guarantees, notification identifier mapping | §34.2 |
| **DE1:** `speech_to_text` incompatible with CC-6 | ACCEPT | Package removed. Custom bridge mandated. | §40.2, §41 (ADR-10) |
| **BR1:** iOS notification extension target not defined | ACCEPT | Defined in §23.2: `KatalaNotificationExtension` target with explicit Xcode configuration. | §23 |
| **AI1:** Agent will treat `speech_to_text` as equivalent to custom bridge | ACCEPT | Package removed from whitelist. Custom bridge explicitly mandated with rationale. | §40.2, §41 (ADR-10) |
| **I1:** BGAppRefreshTask not reliable enough for reconciliation role | ACCEPT | Documented as best-effort. Primary reconciliation happens on foreground + WorkManager (Android). iOS foreground reconciliation is the main recovery path. | §36.7, §19.4 |
| **AN1:** `EXTRA_PREFER_OFFLINE` not a guarantee on Android < 13 | ACCEPT | Documented in §30.2. On Android < 13, this is a preference, not a guarantee. On Android 13+, on-device is enforced. | §30.2 |
| **AN2:** OEM background restrictions in Philippine market not addressed | ACCEPT | Full §24: reliability strategy, detection, user guidance, manufacturer-specific instructions, foreground service deferred to Post-MVP. | §24 (new) |
| **NO1:** Reconciliation does not detect past missed notifications | ACCEPT | New §21: `delivery_status` field on Trigger with states (`scheduled`, `delivery_uncertain`, `delivery_missed`). Reconciliation algorithm updated. UI banner for missed-notification visibility. | §21 (new), §14.6, §16.1, §20.2 |
| **F1:** Riverpod scoping for background callbacks undefined | ACCEPT | New §26: static service locator for background execution. Does not depend on Riverpod or Flutter UI lifecycle. ADR-13. | §26 (new), §33.4, §41 (ADR-13) |
| **AI2:** Agent will put notification scheduling inside repository | ACCEPT | ADR-11: explicit prohibition. Data layer does not call Platform Bridges. Use Cases orchestrate. | §25.5, §33.2, §41 (ADR-11) |
| **AI3:** Agent will not handle iOS 64-notification limit correctly | ACCEPT | Clarified dynamic scheduling algorithm as priority queue with explicit replacement semantics. Top 60 nearest reminders; cancel those not in top 60; schedule those in top 60 missing notifications. | §19.4 |

### Medium Findings — Accepted

| Finding | Decision | Resolution | Section Changed |
|---------|----------|------------|-----------------|
| A2: Google Fonts runtime download risk | ACCEPT | Bundled Inter font as asset. No `google_fonts` package. No runtime font download. | §30.1, §40.2 |
| D1: Database encryption dependency can be deferred | ACCEPT | Deferred to Post-MVP. Noted. | §5 |
| F2: CI network traffic verification undefined | ACCEPT | Defined in §38.5: automated CI check with network proxy. | §38.5 |
| C2 (duplicate) | MERGED with C2 above | — | — |

### Rejected / Deferred Findings

| Finding | Decision | Explanation |
|---------|----------|-------------|
| Android foreground service for MVP | DEFER to Post-MVP | Significant UX cost (persistent notification), battery impact, and permission implications. MVP communicates honestly and guides users to optimize. If user feedback indicates this is essential, add as opt-in in P3. |
| Notification group summary format | DEFER | Minor UX polish. Not architecturally blocking. |
| UserPreference type safety | KEEP key-value for MVP | < 20 preferences. Typed accessor methods with unit tests. Full typed schema would be overengineered for MVP. |
| NLP pipeline notification categories per intent type | KEEP as specified | Four categories with 3-4 actions each is reasonable. Simplifying to one category with dynamic actions is riskier across platforms. |

### Findings Already Resolved in V2 (Verified Still Present in V3)

| V2 Change # | Finding | Status |
|-------------|---------|--------|
| 1 | Auto-save removed | ✓ Still removed |
| 2 | AM/PM always toggle | ✓ Maintained |
| 3 | "Later" capped at 10 PM / 8 AM | ✓ Maintained |
| 4 | DISMISSED checked in follow-up | ✓ Maintained (Post-MVP) |
| 5 | SNOOZED → SNOOZED transition | ✓ Maintained |
| 6 | depth field added | ✓ Maintained |
| 7 | Optimistic locking | ✓ Maintained + expanded for cross-process |
| 8 | Jaro-Winkler removed | ✓ Maintained (exact → partial → contains) |
| 9 | Filler word stripping reduced | ✓ Maintained |
| 10 | Database excluded from backups | ✓ Maintained |
| 11 | Background reconciliation | ✓ Expanded with delivery tracking |
| 12 | Database integrity check | ✓ Maintained |
| 13 | Silent mode documented | ✓ Maintained |
| 14 | URL scheme whitelist | ✓ Maintained + validate before open |
| 15 | Undo snackbar | ✓ Maintained |
| 16 | Follow-up does not inherit action | ✓ Maintained (Post-MVP) |
| 17 | Injectable Clock | ✓ Maintained |
| 18 | Onboarding only mic + notifications | ✓ Maintained |
| 19 | Taglish patterns | ✓ Maintained |
| 20 | Filipino STT honesty | ✓ Maintained + expanded |
| 21 | Geofencing Post-MVP | ✓ Maintained |
| 22 | Riverpod mandated | ✓ Maintained (main app only) |
| 23 | Conflict "Move to" primary | ✓ Maintained |
| 24 | Voice EDIT/DELETE deferred | ✓ Maintained |
| 25 | recurrence_rule nullable column | ✓ Maintained |
| 26 | Android force-stop documented | ✓ Expanded with full §24 |

---

## 45. Changes From V2

| # | V2 | V3 Change | Reason |
|---|-----|-----------|--------|
| 1 | `speech_to_text` in dependency whitelist | Removed. Custom native STT bridge mandated. ADR-10. | Package cannot enforce on-device-only (CC-6). |
| 2 | `google_fonts` in dependency whitelist | Removed. Inter font bundled as asset. | Prevents accidental runtime font download. |
| 3 | Confidence scores (0.0–1.0) used for UX branching | Removed. Replaced with explicit `ValidationIssue` enum. ADR-16. | Undefined calculation; replaced with deterministic validation rules. |
| 4 | `ReminderDraft` single intermediate | Split into `ParsedReminder` (NLP output, contact names as strings) and `ValidatedReminder` (Application output, resolved contacts). | NLP purity: NLP must not depend on platform contacts. |
| 5 | No iOS notification extension specification | Full §23: Xcode targets, App Group, lightweight SQLite, initialization, concurrency, entitlements. ADR-12. | Required for FR-8. Was undefined — implementer would invent. |
| 6 | No `delivery_status` tracking | New `delivery_status` field: `scheduled`, `delivery_uncertain`, `delivery_missed`. New §21. `last_reconciled_at` tracking. | Cannot distinguish "user ignored" from "never fired." |
| 7 | No Application layer use cases defined | New §25: 8 explicit use cases with responsibility boundaries and data flow diagrams. ADR-11. | Undefined orchestration → inconsistent implementations. |
| 8 | No background initialization path | New §26: static service locator for background execution. ADR-13. | Background callbacks have no Flutter UI lifecycle. |
| 9 | SpeechBridge contract minimal | Expanded: availability, isOnDeviceAvailable, start, stop, cancel, 4 error types, no-speech, timeout. | Undefined contracts → inconsistent implementations. |
| 10 | NotificationBridge contract minimal | Expanded: ReconciliationResult, cleanupOrphans, dismiss, idempotency, notification ID mapping. | Undefined contracts → inconsistent implementations. |
| 11 | No Android OEM reliability strategy | Full §24: detection, mitigation, user communication, manufacturer-specific guidance, foreground service deferred. | Philippine-market devices kill background apps aggressively. |
| 12 | No failure atomicity specification | New §27: 6 failure scenarios with state analysis, recovery path, convergence guarantee. | Cross-system transactions don't exist; must converge. |
| 13 | No build configuration | New §37: Flutter/Dart versions, deployment targets, Xcode/Gradle versions, entitlements, permissions, Info.plist, AndroidManifest. | Reproducibility requirement. |
| 14 | No network traffic audit in CI | New §38.5: automated CI check with network proxy. | Privacy guarantee must be machine-verifiable. |
| 15 | Vague iOS 64-notification limit strategy | Clarified: priority queue with explicit replacement semantics. Top 60 nearest; cancel if not in top 60; schedule if in top 60 and missing. | Previous language allowed "append" misinterpretation. |
| 16 | Notification reconciliation algorithm underspecified | Full algorithm in §20.2 with idempotency guarantees and scheduling failure handling. | Undefined algorithm → divergent implementations. |
| 17 | No notification source-of-truth declaration | Explicit: DATABASE = AUTHORITATIVE STATE; OS SCHEDULER = DERIVED STATE. Reconciliation directions specified. | Without this, implementer might treat OS as authoritative. |

---

## Appendix A: Language Patterns Reference

### A.1 English Intent Patterns

```
"remind me"
"set a reminder"
"add reminder"
"reminder to"
"don't forget"
"i need to"
"remember to"
```

### A.2 Taglish Intent Patterns

```
"pa-remind"
"remind mo ko"
"remind mo ako"
"mag-remind"
"ipaalala mo"
"paremind"
"paalala"
"remind mo naman"
```

### A.3 English Action Patterns

```
"call [Name]"
"text [Name]"
"message [Name]"
"email [Name]"
```

### A.4 Taglish Action Patterns

```
"tawagan si [Name]"
"tumawag kay [Name]"
"i-text si [Name]"
"itext mo si [Name]"
"i-email si [Name]"
```

### A.5 English Temporal Keywords

```
"today", "tomorrow", "tonight", "this morning", "this afternoon", "this evening"
"next week", "next month", "next Monday", "next Tuesday" (etc.)
"in [N] minutes", "in [N] hours", "in [N] days"
"at [H]:[MM]", "at [H] [AM/PM]", "noon", "midnight"
"on [Month] [Day]", "on [Day] of [Month]"
"later", "soon", "right now"
```

### A.6 Filipino Temporal Keywords

```
"ngayon" (today), "ngayong araw" (this day), "ngayong umaga" (this morning)
"bukas" (tomorrow), "bukas ng umaga" (tomorrow morning)
"mamaya" (later), "mamayang [time]" (later at [time])
"sa susunod na linggo" (next week), "sa susunod na buwan" (next month)
"sa [Day]" (on [Day] — e.g., "sa Lunes" = on Monday)
"ngayong [Day]" (this [Day] — e.g., "ngayong Biyernes" = this Friday)
```

---

## Appendix B: Error Representation Reference

```dart
sealed class AppError {
  String get userMessage;
  String? get technicalDetails;
}

class SpeechPermissionDeniedError extends AppError { ... }
class SpeechUnavailableError extends AppError { ... }
class SpeechRecognitionFailedError extends AppError { ... }
class SpeechTimeoutError extends AppError { ... }
class SpeechNoSpeechError extends AppError { ... }
class NlpParseFailedError extends AppError { ... }  // General parse failure
class NlpValidationError extends AppError {          // Specific issues
  List<ValidationIssue> issues;
}
class DatabaseWriteError extends AppError { ... }
class DatabaseCorruptionError extends AppError { ... }
class NotificationSchedulingError extends AppError { ... }
class ContactPermissionDeniedError extends AppError { ... }
class ContactNotFoundError extends AppError { ... }
class InvalidUrlError extends AppError { ... }
class ConflictDetectedError extends AppError {
  List<Reminder> conflicts;
  DateTime? suggestedAlternative;
}
class OptimisticLockError extends AppError { ... }
class ReconciliationError extends AppError { ... }
```

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| **App Group** | iOS capability allowing the main app and extension to share a container directory |
| **BGAppRefreshTask** | iOS background task for periodic app refresh (best-effort) |
| **delivery_status** | Katala's tracking of whether a notification was likely delivered |
| **delivery_uncertain** | Status indicating the notification may not have been delivered because the app was inactive |
| **delivery_missed** | Status indicating the user confirmed they did not see the notification |
| **Notification Service Extension** | iOS binary that runs in a separate process to handle notification actions |
| **optimistic locking** | Concurrency control using `version` column: writes fail if version changed since read |
| **Reconciliation** | Process of comparing database state to OS notification state and fixing discrepancies |
| **Service Locator** | Simple dependency container for background execution (non-Riverpod) |
| **WAL (Write-Ahead Logging)** | SQLite journal mode allowing concurrent reads + one writer |

---

*End of KATALA_SPEC_V3.md*
