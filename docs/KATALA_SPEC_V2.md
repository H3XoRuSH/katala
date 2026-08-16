# KATALA — Product & Technical Specification V2

**Version:** 2.0.0
**Date:** 2026-08-10
**Status:** Implementation-Ready (post adversarial review)
**Replaces:** KATALA_SPEC.md v1.0.0-draft
**Sources reconciled:** PLAN.md, KATALA_SPEC.md v1, SPEC_REVIEW.md

---

> **Purpose:** This specification answers: "If I gave this document to a capable coding agent with an empty repository, could it build Katala without inventing major product behavior or architecture?" The answer must be **yes**.

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
12. [Confidence Scoring & UX Decisions](#12-confidence-scoring--ux-decisions)
13. [Language Support & Limitations](#13-language-support--limitations)
14. [Reminder Domain Model](#14-reminder-domain-model)
15. [State Machine](#15-state-machine)
16. [Data Model](#16-data-model)
17. [Persistence (Drift/SQLite)](#17-persistence-driftsqlite)
18. [Conflict Detection](#18-conflict-detection)
19. [Notification Architecture](#19-notification-architecture)
20. [Action System](#20-action-system)
21. [Follow-Up System](#21-follow-up-system)
22. [Geofencing (Post-MVP)](#22-geofencing-post-mvp)
23. [UX Specification](#23-ux-specification)
24. [Accessibility](#24-accessibility)
25. [Privacy](#25-privacy)
26. [Security](#26-security)
27. [Offline Behavior](#27-offline-behavior)
28. [Platform Architecture](#28-platform-architecture)
29. [Platform Bridge Contracts](#29-platform-bridge-contracts)
30. [Error Handling & Failure Modes](#30-error-handling--failure-modes)
31. [Lifecycle, Reboot & Background Behavior](#31-lifecycle-reboot--background-behavior)
32. [Testing Strategy](#32-testing-strategy)
33. [Acceptance Criteria](#33-acceptance-criteria)
34. [Implementation Constraints](#34-implementation-constraints)
35. [Architectural Decisions](#35-architectural-decisions)
36. [Implementation Roadmap](#36-implementation-roadmap)
37. [Open Product Decisions](#37-open-product-decisions)
38. [Changes From V1](#38-changes-from-v1)

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
| **Privacy-guaranteed** | All personal data processing occurs on-device. No reminder content, contact data, or location data is sent to any server operated by Katala. OS speech engines and device backups are documented exceptions (see §25). |
| **Fast** | Voice-to-persisted-reminder in under 5 seconds for simple commands on mid-range devices. |

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
| NG11 | Server-side speech recognition | On-device STT required; cloud fallback requires explicit user opt-in per language |
| NG12 | Location-based reminders (MVP) | Deferred to Post-MVP to reduce MVP complexity (see §5, §22) |

---

## 4. MVP Scope

### 4.1 Core MVP Features

| Feature | Classification | Rationale |
|---------|---------------|-----------|
| Voice input → text via on-device STT | **MVP** | Central value proposition |
| Text input fallback | **MVP** | Required for accessibility and degradation |
| NLP: CREATE_REMINDER with time, contact, URL, notes | **MVP** | Minimum viable voice reminder |
| NLP: CALL action + contact resolution | **MVP** | Key differentiator |
| NLP: URL detection + OPEN_URL action | **MVP** | Simple regex, high value |
| NLP: TEXT action + contact resolution | **MVP** | Natural extension of CALL |
| Notification scheduling with Done, Snooze, Call, Open Link actions | **MVP** | Core notification interaction |
| Home screen timeline (overdue, today, tomorrow, later) | **MVP** | Primary UI |
| Reminder detail view with action buttons | **MVP** | Required for non-notification interaction |
| Manual reminder creation/edit form | **MVP** | Text fallback and editing |
| Settings screen (defaults, appearance, language) | **MVP** | Configurable user preferences |
| Onboarding (permissions education, mic + notifications) | **MVP** | Critical for permission acceptance |
| Conflict detection | **MVP** | PLAN.md Phase 2; relatively simple |
| Dark mode (default) + light mode | **MVP** | Design principle |
| Accessibility (WCAG 2.1 AA equivalent) | **MVP** | Required for inclusive product |
| English (en-US) full NLP + STT support | **MVP** | Primary supported language |
| Taglish temporal + action keyword support | **MVP** | Primary market need |
| Filipino temporal keyword support | **MVP** | Parse Filipino time expressions |

### 4.2 What MVP Does NOT Include

- Geofencing / location-based reminders (Post-MVP)
- Follow-up engine / conditional chaining (Post-MVP)
- Voice EDIT, DELETE, QUERY, or SNOOZE intents (UI-only for MVP)
- Recurring reminders (Post-MVP)
- Data export (Post-MVP)
- Database encryption at rest (Post-MVP)
- Tablet/iPad layouts (phone-only)
- Filipino full NLP intent patterns (temporal keywords only in MVP)

---

## 5. Post-MVP Scope

| Feature | Priority | Notes |
|---------|----------|-------|
| Geofencing + saved locations | P1 | PLAN.md Phase 3; deferred to limit MVP surface |
| Follow-up engine (conditional chaining) | P1 | PLAN.md differentiator |
| Voice EDIT, DELETE, QUERY, SNOOZE intents | P2 | Complex; needs robust reminder disambiguation |
| Recurring reminders (UI creation) | P2 | Common user expectation |
| Filipino full NLP intent patterns | P2 | Requires expanded regex coverage |
| Database encryption (SQLCipher) | P2 | Privacy enhancement |
| Data export (JSON) | P3 | User data portability |
| Tablet/iPad layouts | P3 | Larger screen adaptation |
| App-level biometric lock | P3 | Additional privacy layer |
| Notification quiet hours | P3 | "Later" capping, geofence quiet sounds |

---

## 6. User Journeys

### 6.1 Journey: Creating a Simple Reminder by Voice

**Trigger:** User opens app and speaks "Remind me to buy groceries tomorrow at 5 PM"

| Step | User Action | System Response | UI State | Failure | Recovery |
|------|------------|-----------------|----------|---------|----------|
| 1 | Opens app | Home screen with prominent mic button | Timeline view | App crashes | Re-open app |
| 2 | Taps mic button | Audio session activates. Listening animation begins. Haptic feedback. | Pulsing mic icon, waveform | Mic permission denied | Show "Microphone access needed" with Settings button |
| 3 | Speaks command | STT converts to text. Live transcript appears. | Transcript streaming | STT unavailable | Fall back to text input with explanation |
| 4 | Stops speaking (silence or tap) | NLP pipeline processes: intent=CREATE_REMINDER, title="buy groceries", time="tomorrow 5:00 PM". Confidence HIGH (>0.85). | Brief processing indicator (<500ms) | Parse fails | Show transcript with "I didn't understand that — edit below" |
| 5 | Reviews confirmation card | Shows: "Buy groceries — Tomorrow at 5:00 PM" with parsed fields | Confirmation card with [Save] [Edit] | N/A | N/A |
| 6 | Taps [Save] | Reminder persisted. Notification scheduled. Haptic + chirp sound. Returns to timeline. | Success → timeline shows new reminder | DB write fails | Retry once; on failure, show error with retry |
| 7 | Next day at 5:00 PM | Notification fires with [✓ Done] [⏰ Snooze] | System notification | Notification permission denied | Reminder shows as overdue when app next opened |

### 6.2 Journey: Creating a Call Reminder

**Trigger:** "Remind me to call Adam at 2 PM"

Steps 1-4 as in 6.1. NLP extracts: intent=CREATE_REMINDER, action=CALL, contact="Adam", time="2:00 PM today".

| Step | What Happens |
|------|-------------|
| 5 | System resolves "Adam" against device contacts. One match → attaches phone number. Multiple matches → disambiguation sheet. No match → stores name only, shows "(no phone number found)". Contacts permission denied → stores name only. |
| 6 | User taps [Save]. Reminder persisted with intent_type=CALL. |
| 7 | At 2:00 PM, notification: "Call Adam" with [📞 Call Now] [⏰ Snooze] [✓ Done]. |
| 8 | User taps [📞 Call Now]. Dialer opens with Adam's number pre-filled. Reminder marked COMPLETED. |

### 6.3 Journey: Creating by Text Input

| Step | What Happens |
|------|-------------|
| 1 | User taps "+" or swipes mic → keyboard icon. Text field appears with cursor focused. |
| 2 | Types: "Call dentist Monday 9am". Real-time NLP parses as user types (debounced 300ms). Shows parsed preview below input. |
| 3 | User optionally edits fields using form controls (date picker, time picker, contact picker). |
| 4 | Taps [Save]. Reminder persisted, notification scheduled. |

### 6.4 Journey: URL Reminder

**Trigger:** "Remind me to check this link at 8 PM — https://example.com/report"

Extracts: title="check this link", action=OPEN_URL, target="https://example.com/report", time="8:00 PM today". Notification at 8 PM with [🔗 Open Link] [✓ Done]. User taps [🔗 Open Link] → opens in default browser, reminder marked COMPLETED.

---

## 7. Functional Requirements

### 7.1 Reminder Creation

| ID | Requirement |
|----|------------|
| FR-1 | User MUST be able to create a reminder by voice (primary) or text input (fallback) |
| FR-2 | Voice creation MUST extract: title, time/date, contact (if CALL/TEXT), URL (if present), notes |
| FR-3 | When a required entity is missing, system MUST ask a specific clarification question (not a generic error) |
| FR-4 | User MUST explicitly confirm every reminder before it is saved (no auto-save) |
| FR-5 | Created reminders MUST be persisted to local SQLite database atomically with their Trigger and Action |

### 7.2 Notification Delivery

| ID | Requirement |
|----|------------|
| FR-6 | Time-based reminders MUST fire a local notification at the scheduled time |
| FR-7 | Notifications MUST include contextual action buttons based on reminder type |
| FR-8 | Notification actions (Done, Snooze) MUST work without opening the app |
| FR-9 | On Android, the app MUST reschedule all pending alarms after device reboot |
| FR-10 | On iOS, the app MUST manage the 64-pending-notification limit via dynamic scheduling |
| FR-11 | The app MUST reconcile the notification queue on every foreground entry |

### 7.3 Conflict Detection

| ID | Requirement |
|----|------------|
| FR-12 | When a new reminder's time is within ±15 minutes of an existing PENDING/SNOOZED reminder, system MUST show a conflict warning |
| FR-13 | Conflict warning MUST display the conflicting reminders and offer: save anyway, move to suggested alternative time, or pick another time |

### 7.4 Reminder Management

| ID | Requirement |
|----|------------|
| FR-14 | User MUST be able to mark a reminder as Done (COMPLETED) from notification or in-app |
| FR-15 | User MUST be able to Snooze a reminder (default 10 min, configurable) up to 10 times from notification or in-app |
| FR-16 | User MUST be able to Dismiss a reminder (permanently silence) |
| FR-17 | User MUST be able to edit a reminder's title, time, notes, and contact |
| FR-18 | User MUST be able to delete a reminder (soft-delete, 30-day retention) |
| FR-19 | User MUST be able to undo a complete or delete within 5 seconds via snackbar |

### 7.5 Data Integrity

| ID | Requirement |
|----|------------|
| FR-20 | All times MUST be stored as UTC with IANA timezone identifier |
| FR-21 | Multi-entity writes (Reminder + Trigger + Action) MUST use database transactions |
| FR-22 | Database integrity MUST be checked on app startup (PRAGMA integrity_check) |

---

## 8. NLP Architecture

### 8.1 Pipeline Overview

```
[User Voice] → [STT Engine] → [Raw Text]
    → [Pre-Processing] → [Normalized Text]
    → [Intent Detection] → Intent
    → [Entity Extraction] → Entities
    → [Temporal Resolution] → Absolute DateTime
    → [Contact Resolution] → ContactRef
    → [Semantic Validation] → Errors/Warnings
    → [Confidence Scoring] → Score + Level
    → [ReminderDraft]
```

Each stage is an independently testable function. All NLP functions MUST be pure: same input always produces same output. Time-dependent functions accept an injectable `Clock` interface.

### 8.2 Stage 1: Speech-to-Text

**iOS:**
- `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
- Check `supportsOnDeviceRecognition` before starting
- Maximum session: 30 seconds
- Auto-stop on 2 seconds of silence (configurable)

**Android:**
- `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE = true`
- For Android 13+: check recognition support via platform API
- For Android < 13: `EXTRA_PREFER_OFFLINE` is a preference, not a guarantee. Document this limitation honestly (see §25.3).
- Auto-stop on 2 seconds of silence

**Error handling:**

| Error | Behavior |
|-------|----------|
| Mic permission denied | Show rationale + Settings link |
| No on-device STT available | Disable voice input; show "Voice unavailable — type your reminder" with explanation |
| STT engine unavailable | Show error + text fallback |
| No speech detected | "I didn't hear anything. Try again?" |
| Session timeout (30s) | Process whatever was captured |

### 8.3 Stage 2: Pre-Processing

Operations in order:
1. Trim whitespace
2. Lowercase (intent matching is case-insensitive)
3. Expand contractions ("don't" → "do not", "I'll" → "I will")
4. Apply STT error correction (see table below)
5. Normalize written numbers ("five" → "5", "two thirty" → "2:30")
6. Normalize time formats ("5 p m" → "5 pm")
7. Strip filler words cautiously: only "um", "uh" when preceded/followed by silence markers. Do NOT strip "like", "actually", "basically" — they can carry meaning.
8. Preserve original transcript

**STT error correction table:**

| STT Output | Corrected | Context Condition |
|------------|-----------|-------------------|
| "rewind me" | "remind me" | Always |
| "remainder" | "reminder" | Always |
| "coal" | "call" | When followed by a name-like token |
| "for" | "4" | When followed by "am"/"pm" or preceded by "at" |
| "ate" | "8" | When in time context (near "at", "am", "pm", "oclock") |
| "won" | "1" | When in time context |
| "to" | "2" | When in time context and followed by "am"/"pm"/"oclock" |
| "tree" / "free" | "3" | When in time context |
| "too" | "2" | When in time context |
| "for tea" / "forty" | "4:30" | When in time context |
| "our" | "hour" | When preceded by "in an" or "in one" |

> The correction dictionary MUST be easy to extend. Store it as a data structure, not hardcoded conditionals.

### 8.4 Design Principle: Modularity

Each pipeline stage is a separate class/function with explicit input and output types:

```
RawTranscript → PreProcessor → NormalizedTranscript
NormalizedTranscript → IntentDetector → DetectedIntent
NormalizedTranscript → EntityExtractor → ExtractedEntities
ExtractedEntities + Clock → TemporalResolver → ResolvedTime
ExtractedEntities + ContactsDB → ContactResolver → ContactRef
DetectedIntent + ExtractedEntities → SemanticValidator → ValidationResult
All results → ConfidenceScorer → ConfidenceScore
All results → ReminderDraftBuilder → ReminderDraft
```

---

## 9. Intent Detection

### 9.1 Supported Intents (MVP)

| Intent | Trigger Patterns (English) | Trigger Patterns (Taglish) |
|--------|---------------------------|---------------------------|
| `CREATE_REMINDER` | "remind me", "set a reminder", "add reminder", "reminder to", "don't forget", "i need to", "remember to" | "pa-remind", "remind mo ko", "remind mo ako", "mag-remind", "ipaalala mo", "paremind", "paalala" |
| `UNKNOWN` | Fallback when no pattern matches | — |

**MVP limitation:** Only `CREATE_REMINDER` is supported via voice. EDIT, DELETE, COMPLETE, SNOOZE, QUERY, and CREATE_FOLLOWUP intents are UI-only in MVP. If a user attempts these by voice, the system treats it as `CREATE_REMINDER` and the user can adjust in the confirmation card.

### 9.2 Fallback Detection

If no explicit intent pattern matches, but temporal or action entities are found, assume `CREATE_REMINDER` with confidence 0.7.

### 9.3 Compound Command Handling

MVP does NOT split compound commands (e.g., "call Adam and text Maria"). Treat as a single reminder with the first detected action. The user can create a second reminder manually. This is documented in the UX.

---

## 10. Entity Extraction

### 10.1 Entity Types

| Entity | Pattern Approach | Example Input → Output |
|--------|-----------------|----------------------|
| `TEMPORAL` | See §11 (Temporal Resolution) | "tomorrow at 3pm" → 2026-08-11T15:00:00+08:00 |
| `CONTACT` | Action verb + following name | "call Adam" → contact_name="Adam" |
| `PHONE_NUMBER` | Regex for intl, PH, US formats | "+639171234567" → phone_number |
| `URL` | http/https/www patterns | "https://example.com" → url |
| `ACTION` | Action verb detection | "call" → CALL, "text" → TEXT |
| `NOTES` | Everything remaining after extraction | "about the wifi setup" → notes |

### 10.2 Contact Extraction

Pattern (English):
```
(?:call|text|message|email|contact|phone|ring|dial)\s+(.+?)(?:\s+(?:at|on|in|by|tomorrow|today|tonight|later|about|regarding)|$)
```

Pattern (Taglish):
```
(?:tawagan|tumawag\s+kay|i-text|mag-text\s+kay|i-email|mag-email\s+kay|tawagan\s+si|tumawag\s+sa)\s+(.+?)(?:\s+(?:at|on|in|by|bukas|mamaya|ngayon|tungkol|sa)|$)
```

Extraction process:
1. Identify action verb
2. Extract the name following the verb
3. Remove trailing temporal/location phrases and noise words
4. Pass to Contact Resolution (§10.3)

### 10.3 Contact Resolution

**Algorithm (ordered by priority):**

```
function resolveContact(name, contactsDB):
  if contactsPermission is DENIED:
    return ContactRef(name: name, resolved: false, reason: NO_PERMISSION)

  // 1. Exact display-name match (case-insensitive)
  exact = contactsDB.exactMatch(name)
  if exact.length == 1: return exact[0] with confidence 1.0
  if exact.length > 1: return ambiguous(matches: exact)

  // 2. First-name or last-name startsWith
  partial = contactsDB.partialMatch(name)
  if partial.length == 1: return partial[0] with confidence 0.9
  if partial.length > 1: return ambiguous(matches: partial)

  // 3. Contains match (name appears anywhere in display name)
  contains = contactsDB.containsMatch(name)
  if contains.length == 1: return contains[0] with confidence 0.8
  if contains.length > 1: return ambiguous(matches: contains)

  // 4. No match
  return ContactRef(name: name, resolved: false, reason: NOT_FOUND)
```

**Disambiguation UX:** Bottom sheet listing matching contacts with name and phone number. "None of these" option stores name as unresolved text.

> **Design note:** Jaro-Winkler fuzzy matching (from V1) is removed from MVP. It adds complexity, is computationally expensive on large contact lists, and partial matching covers the common cases. It can be added in Post-MVP if needed.

### 10.4 Action Detection

| Action | English Triggers | Taglish Triggers |
|--------|-----------------|------------------|
| CALL | "call", "phone", "ring", "dial" | "tawagan", "tumawag" |
| TEXT | "text", "message", "sms" | "i-text", "mag-text" |
| EMAIL | "email", "mail" | "i-email", "mag-email" |
| OPEN_URL | "open", "check", "visit" + URL | "buksan", "i-open", "tingnan" |
| NONE | (default when no action verb detected) | — |

### 10.5 Title Generation

Title is generated from entities, never null:
1. If CALL/TEXT/EMAIL + contact: `"[ActionVerb] [ContactName]"` (e.g., "Call Adam")
2. If OPEN_URL: first meaningful words before URL (e.g., "Check report")
3. Otherwise: first 100 characters of notes/transcript, truncated at word boundary
4. Fallback: `"Reminder"` (should be rare — only if transcript is truly empty)

---

## 11. Temporal Resolution

### 11.1 Reference Time

All temporal resolution uses an injectable `Clock` interface. Production uses `DateTime.now()`. Tests inject a fixed clock.

### 11.2 Relative Time

| Expression | Resolution |
|-----------|-----------|
| "in X minutes/hours" | now + X minutes/hours |
| "in half an hour" | now + 30 minutes |
| "in an hour" | now + 60 minutes |

### 11.3 Named Days

| Expression | Resolution |
|-----------|-----------|
| "today" | Today; if no time given, ask for time |
| "tonight" | Today at 8:00 PM |
| "tomorrow" | Tomorrow; if no time given, ask for time |
| "tomorrow morning" | Tomorrow at 9:00 AM |
| "tomorrow afternoon" | Tomorrow at 1:00 PM |
| "tomorrow evening" | Tomorrow at 6:00 PM |
| "tomorrow night" | Tomorrow at 8:00 PM |
| "day after tomorrow" | 2 days from now; ask for time if none given |

### 11.4 Named Weekdays

| Expression | Rule |
|-----------|------|
| "this Friday" | Friday of current week |
| "next Monday" | Monday of NEXT week |
| "on Wednesday" | Nearest future Wednesday |
| "on [today's day]" | Today if future time given; otherwise ask for clarification |

### 11.5 Absolute Time

| Expression | Resolution |
|-----------|-----------|
| "at 3 pm" / "at 3:00 pm" | Today if future; tomorrow if past |
| "at 8" (no AM/PM) | **Always ask for clarification.** Show the resolved time with an AM/PM toggle on the confirmation card. Never auto-resolve bare numbers 1-12. |
| "at 15:00" (24-hour) | Today at 15:00 if future; tomorrow if past |
| "tomorrow at 8" | Tomorrow at 8:00 AM (morning default with AM/PM toggle) |
| "on August 15" | Aug 15 current year if future; next year if past |
| "on 8/15" | Locale-dependent (M/D for en-US) |

> **V2 change:** V1 used a heuristic (1-6 ask, 7-11 auto-resolve). This was error-prone. V2 always shows an AM/PM toggle for bare numbers. The toggle takes one tap; getting it wrong causes missed reminders.

### 11.6 Fuzzy Time

| Expression | Default | Configurable |
|-----------|---------|:-----------:|
| "morning" | 9:00 AM | Yes |
| "after lunch" | 1:00 PM | Yes |
| "afternoon" | 2:00 PM | Yes |
| "end of day" | 5:00 PM | Yes |
| "evening" | 6:00 PM | Yes |
| "tonight" | 8:00 PM | Yes |
| "later" | now + 2 hours | Yes |
| "soon" | now + 30 minutes | No |

### 11.7 Filipino/Taglish Temporal Expressions

| Expression | Resolution |
|-----------|-----------|
| "bukas" | tomorrow |
| "mamaya" | later (now + 2 hours) |
| "mamayang gabi" | tonight (8:00 PM) |
| "mamayang hapon" | this afternoon (2:00 PM) |
| "sa makalawa" | day after tomorrow |
| "sa susunod na linggo" | next week |
| "sa Lunes" | on Monday (nearest future) |
| "ngayong gabi" | tonight |
| "tanghali" | noon (12:00 PM) |
| "ngayon" | today |
| "alas tres" | 3:00 |
| "alas kwatro" | 4:00 |

### 11.8 Past Time Handling

1. If resolved time is within the last 12 hours: assume user meant next occurrence (tomorrow). Show confirmation: "Did you mean tomorrow at X?"
2. If resolved time is more than 12 hours in the past: reject. "That time has already passed."
3. If resolved date is in the past: reject. "That date has passed."

### 11.9 Timezone and DST

- ALL DateTime values stored as UTC with IANA timezone identifier (e.g., "Asia/Manila")
- Display: convert UTC → device's current local timezone
- DST spring-forward gap: fire at next valid time (e.g., 3:00 AM when 2:30 AM doesn't exist)
- DST fall-back overlap: fire at first occurrence
- If device timezone changes between creation and firing: reminder fires at the wall-clock time in the NEW timezone (the UTC instant doesn't change, but the displayed local time does). This matches user expectation: "3 PM" means 3 PM wherever you are.

### 11.10 "Later" Quiet Hours Cap

If "later" (now + 2 hours) would land between 10:00 PM and 7:00 AM, move to 8:00 AM the next day. Show the resolved time in the confirmation card so the user can adjust.

---

## 12. Confidence Scoring & UX Decisions

### 12.1 Confidence Levels

| Level | Score Range | UX Behavior |
|-------|-----------|-------------|
| HIGH | ≥ 0.85 | Show confirmation card with all parsed fields. User MUST tap [Save] to confirm. |
| MEDIUM | 0.50 – 0.84 | Show confirmation card. Highlight ambiguous or missing fields. User MUST tap [Save]. |
| LOW | < 0.50 | Show clarification. Ask specific questions for missing entities. Offer text edit. |

> **V2 change:** V1 auto-saved HIGH-confidence reminders after 2 seconds. This is removed. ALL reminders require explicit user confirmation regardless of confidence. One mistimed auto-saved reminder destroys trust more than one extra tap.

### 12.2 Clarification UX

When entities are missing or ambiguous, ask specific questions:

| Missing Entity | Clarification |
|---------------|--------------|
| No time | "When should I remind you?" with quick-pick chips: [Morning (9 AM)] [Afternoon (2 PM)] [Evening (6 PM)] [Pick a time] |
| No title | "What should I remind you about?" with text input |
| CALL without contact | "Who should I call?" with text input |
| Ambiguous contact | "Which [Name]?" with contact list |
| Bare number time | "8:00 AM or 8:00 PM?" with AM/PM toggle |

Never show a generic "I didn't understand." Always say what WAS understood and what's missing.

---

## 13. Language Support & Limitations

### 13.1 Honest Capability Matrix

| Language | NLP Intent Patterns | Temporal Patterns | Action Keywords | STT (iOS) | STT (Android) |
|----------|:---:|:---:|:---:|:---:|:---:|
| English (en-US) | ✅ Full | ✅ Full | ✅ Full | ✅ On-device | ✅ Usually on-device |
| Taglish (tl-en mix) | ✅ Common patterns | ✅ Full (en+tl) | ✅ Common patterns | ⚠️ Depends on English model availability | ⚠️ Depends on English model |
| Filipino (tl/fil) | ⚠️ Temporal only | ✅ Full | ⚠️ Temporal only | ❌ On-device NOT available | ⚠️ Varies by device |

### 13.2 Platform Reality for Filipino STT

**iOS:** As of iOS 16-18, `SFSpeechRecognizer` on-device recognition does NOT support Filipino (tl-PH). `supportsOnDeviceRecognition` will return `false`. Under Katala's policy, voice input is disabled when on-device STT is unavailable. **This means pure Filipino voice input does not work on iOS.** Users who speak primarily in Filipino on iOS must use text input.

**Android:** Offline Filipino speech model availability varies by manufacturer and Google app version. On Pixel and recent Android One devices, it is often available. On Samsung, Xiaomi, OPPO, and other devices common in the Philippines, it may not be available.

### 13.3 What This Means for Users

- **English commands work fully on both platforms.**
- **Taglish commands work** as long as the STT engine recognizes the English portions (which carry the intent and action keywords). Filipino temporal words ("bukas", "mamaya") are parsed by Katala's NLP regardless of STT language.
- **Pure Filipino commands have limited support.** Temporal expressions are parsed. Intent and action keywords in pure Filipino are NOT supported in MVP NLP.
- The app MUST display a language support notice during onboarding: "Katala works best in English and Taglish. Full Filipino support is coming in a future update. You can always type reminders in any language."

### 13.4 Language Configuration

- User sets preferred language in Settings (default: English)
- Taglish patterns are active when language is English or Filipino
- NLP does NOT auto-detect language; it applies patterns for the configured language
- Filipino temporal patterns are ALWAYS active regardless of language setting

---

## 14. Reminder Domain Model

### 14.1 Core Concepts

```
Reminder (root entity)
  ├── has one Trigger   (when/where to fire)
  ├── has one Action    (what external operation)
  └── has zero/one FollowUpRule (conditional chaining, Post-MVP)
```

### 14.2 Entity Definitions

#### Reminder

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID v4 | Yes | Primary key |
| title | String (max 200) | Yes | Display title |
| notes | String? (max 1000) | No | Additional notes |
| intent_type | Enum: GENERAL, CALL, TEXT, EMAIL, LINK, LOCATION | Yes | Determines notification actions |
| status | Enum: PENDING, SNOOZED, COMPLETED, DISMISSED | Yes | Lifecycle state |
| snooze_count | int (default 0) | Yes | Times snoozed (max 10) |
| depth | int (default 0) | Yes | Chain depth for follow-ups (0 = root, max 3) |
| parent_reminder_id | UUID? | No | For follow-up children |
| version | int (default 0) | Yes | Optimistic locking version |
| created_at | DateTime (UTC) | Yes | Creation timestamp |
| updated_at | DateTime (UTC) | Yes | Last modification |
| completed_at | DateTime? (UTC) | No | When marked COMPLETED |
| is_deleted | bool (default false) | Yes | Soft-delete flag |
| deleted_at | DateTime? (UTC) | No | When soft-deleted |
| original_transcript | String? | No | Raw STT output (for display/debug) |

#### Trigger

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID v4 | Yes | PK |
| reminder_id | UUID (FK) | Yes | Parent |
| trigger_type | Enum: SCHEDULED_TIME | Yes | Only time triggers in MVP |
| scheduled_time | DateTime (UTC) | Yes | When to fire |
| timezone | String | Yes | IANA timezone ID |
| notification_id | int? | No | Platform notification ID |
| notification_scheduled | bool (default false) | No | Whether OS notification is confirmed scheduled. Set to true after successful scheduling. Set to false if scheduling fails or notification is cancelled. Checked during reconciliation. |
| fired_at | DateTime? (UTC) | No | When trigger actually fired |

> **MVP note:** `trigger_type` only has `SCHEDULED_TIME` in MVP. `GEOFENCE` is added in Post-MVP. The Trigger entity has `geofence_*` columns added via migration at that time.

#### Action

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID v4 | Yes | PK |
| reminder_id | UUID (FK) | Yes | Parent |
| action_type | Enum: CALL, TEXT, EMAIL, OPEN_URL, NONE | Yes | What to do |
| target_value | String? | Conditional | Phone number, URL, or email |
| contact_name | String? | No | Display name |
| contact_phone | String? | No | Resolved phone number |
| contact_email | String? | No | Resolved email |

#### UserPreference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| key | String | Yes | PK |
| value | String | Yes | JSON-encoded value |
| updated_at | DateTime (UTC) | Yes | Last modified |

Key defaults:

| Key | Type | Default |
|-----|------|---------|
| `snooze_duration_minutes` | int | 10 |
| `silence_timeout_seconds` | int | 2 |
| `fuzzy_time_morning` | String (HH:mm) | "09:00" |
| `fuzzy_time_afternoon` | String (HH:mm) | "14:00" |
| `fuzzy_time_evening` | String (HH:mm) | "18:00" |
| `fuzzy_time_tonight` | String (HH:mm) | "20:00" |
| `fuzzy_time_eod` | String (HH:mm) | "17:00" |
| `fuzzy_time_later_hours` | int | 2 |
| `theme` | "dark" or "light" | "dark" |
| `language` | String | "en" |
| `completed_retention_days` | int | 30 |
| `haptics_enabled` | bool | true |
| `confirmation_sound_enabled` | bool | true |
| `backup_enabled` | bool | false |

### 14.3 Relationship Rules

| Relationship | Rule |
|-------------|------|
| Reminder → Trigger | 1:1 |
| Reminder → Action | 1:1 (NONE for general reminders) |
| Reminder → FollowUpRule | 1:0..1 (Post-MVP) |
| Deletion cascade (soft) | Soft-deleting a parent soft-deletes children |
| Deletion cascade (hard) | Hard-deleting physically removes Trigger, Action, FollowUpRule, and child Reminders |

---

## 15. State Machine

### 15.1 Reminder States and Transitions

```
                 ┌──────────┐
         Create  │ PENDING  │
    ───────────► │          │
                 └────┬─────┘
          ┌───────────┼───────────┐
          ▼           ▼           ▼
    ┌─────────┐ ┌──────────┐ ┌───────────┐
    │COMPLETED│ │ SNOOZED  │ │ DISMISSED │
    │(terminal*│ │          │ │(terminal) │
    │ except   │ │          │ │           │
    │ undo)    │ │          │ │           │
    └─────────┘ └────┬─────┘ └───────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
    ┌─────────┐ ┌──────────┐ ┌───────────┐
    │ PENDING │ │ SNOOZED  │ │ DISMISSED │
    │(re-fire)│ │(re-snooze)│ │(terminal) │
    └─────────┘ └──────────┘ └───────────┘
```

### 15.2 Defined Transitions

| From | To | Trigger | Guard |
|------|----|---------|-------|
| — | PENDING | Reminder created | — |
| PENDING | COMPLETED | User taps Done | Always allowed |
| PENDING | SNOOZED | User taps Snooze | snooze_count < 10 |
| PENDING | DISMISSED | User taps Dismiss | Always allowed |
| SNOOZED | PENDING | Snooze timer fires | Automatic |
| SNOOZED | COMPLETED | User taps Done | Always allowed |
| SNOOZED | SNOOZED | User taps Snooze again | snooze_count < 10 |
| SNOOZED | DISMISSED | User taps Dismiss | Always allowed |
| COMPLETED | PENDING | Undo (within 5s window) | Only via in-app undo snackbar |
| Any | (soft-deleted) | User deletes | Sets is_deleted=true |

### 15.3 Transition Effects

| Transition | Effects |
|-----------|---------|
| → COMPLETED | Set completed_at. Cancel notification. Status = COMPLETED. |
| → SNOOZED | Cancel current notification. Increment snooze_count. Schedule new notification at now + snooze_duration. Status = SNOOZED. |
| → DISMISSED | Cancel notification. Status = DISMISSED. (Does NOT trigger follow-up evaluation.) |
| SNOOZED → PENDING | New notification replaces old. Status = PENDING. (snooze_count unchanged.) |
| → Deleted | Set is_deleted=true, deleted_at=now. Cancel notification. Cascade soft-delete to children. |

### 15.4 Concurrency: Optimistic Locking

Every Reminder has a `version` integer. All state transitions use:

```sql
UPDATE reminders
SET status = ?, version = version + 1, updated_at = ?
WHERE id = ? AND version = ?
```

If the update affects 0 rows, the transition failed (version mismatch). Retry once by re-reading the current state and re-evaluating the transition. If the guard no longer allows the transition (e.g., reminder was already COMPLETED), abort silently.

This handles:
- User taps Done twice simultaneously
- Notification action + in-app edit race
- Two notifications firing simultaneously for the same reminder

---

## 16. Data Model

### 16.1 ReminderDraft (Intermediate, Not Persisted)

```
ReminderDraft {
  title: String
  notes: String?
  intentType: IntentType           // GENERAL, CALL, TEXT, EMAIL, LINK
  actionType: ActionType?           // CALL, TEXT, EMAIL, OPEN_URL, NONE
  triggerType: TriggerType          // Always SCHEDULED_TIME in MVP
  triggerTime: DateTime?            // Resolved absolute time (UTC)
  triggerTimezone: String?          // IANA timezone
  contactName: String?
  contactRef: ContactRef?           // Resolved contact or null
  phoneNumber: String?
  url: String?
  confidence: double                // 0.0-1.0
  confidenceLevel: ConfidenceLevel  // HIGH, MEDIUM, LOW
  originalTranscript: String
  normalizedTranscript: String
  validationErrors: List<ValError>
  conflicts: List<Conflict>
  unresolvedFields: List<String>
}
```

---

## 17. Persistence (Drift/SQLite)

### 17.1 Chosen Database: Drift (formerly Moor)

**Rationale:** SQLite wrapper for Flutter with type-safe queries, migration support, and reactive streams. Replaces the PLAN.md suggestion of Isar (which was deprecated).

### 17.2 Database Integrity

On app startup, before any queries:
```sql
PRAGMA integrity_check;
```

If check fails:
- Attempt to restore from last known-good state (if backup mechanism exists)
- If no backup: show error screen: "Katala's data has been corrupted. Your reminders may be lost. [Reset Katala] [Contact Support]"
- Do NOT silently continue with a corrupted database

### 17.3 Migrations

- Every schema change increments a version number
- Each version provides an `onUpgrade` migration callback
- Migrations are tested: create DB at vN, run migration, verify schema matches vN+1
- Drift handles this natively via its migration API

### 17.4 Soft-Delete Retention

- Soft-deleted reminders (is_deleted=true) are retained for 30 days
- A periodic cleanup (on app foreground, at most once per day) hard-deletes rows where `deleted_at < now - 30 days`
- "Delete All Data" in Settings: hard-deletes everything immediately (requires confirmation with "Type DELETE to confirm" dialog)

---

## 18. Conflict Detection

### 18.1 Definition

Two reminders **conflict** when their scheduled times are within ±15 minutes of each other, AND both are PENDING or SNOOZED, AND neither is soft-deleted.

### 18.2 Detection Algorithm

```
function detectConflicts(newTime, excludeReminderId?):
  windowStart = newTime - 15 min
  windowEnd = newTime + 15 min

  return db.query(
    SELECT r.id, r.title, t.scheduled_time
    FROM reminders r JOIN triggers t ON r.id = t.reminder_id
    WHERE t.trigger_type = 'SCHEDULED_TIME'
      AND t.scheduled_time BETWEEN windowStart AND windowEnd
      AND r.status IN ('PENDING', 'SNOOZED')
      AND r.is_deleted = false
      AND r.id != COALESCE(excludeReminderId, '')
    ORDER BY t.scheduled_time ASC
  )
```

### 18.3 Alternative Time Suggestion

```
function suggestAlternative(requestedTime):
  candidate = requestedTime + 30 min
  while detectConflicts(candidate).isNotEmpty:
    candidate += 15 min
    if candidate > requestedTime + 4 hours:
      return null  // Give up
  return candidate
```

### 18.4 Conflict UX

Show a conflict card with:
- ⚠️ "Schedule overlap" heading
- List of conflicting reminders with times
- Primary action: "Move to [suggested time]" (prominent button)
- Secondary: "Save at [original time] anyway"
- Tertiary: "Pick another time" → opens time picker

The suggested time is the DEFAULT. "Save anyway" requires a deliberate choice.

---

## 19. Notification Architecture

### 19.1 Notification Categories

| Category ID | Display Name | Actions | Sound |
|-------------|-------------|---------|-------|
| `reminder_general` | Reminders | [✓ Done] [⏰ Snooze] | Custom chirp |
| `reminder_call` | Call Reminders | [📞 Call Now] [⏰ Snooze] [✓ Done] | Custom chirp |
| `reminder_link` | Link Reminders | [🔗 Open Link] [⏰ Snooze] [✓ Done] | Custom chirp |
| `reminder_text` | Text Reminders | [💬 Text] [⏰ Snooze] [✓ Done] | Custom chirp |

### 19.2 Notification Content

```
Title: [Reminder title]
Body: [Notes, if any]
Subtitle (iOS): Contact phone number or URL
```

### 19.3 Notification Actions

| Action ID | Label | Opens App? | Background Work |
|-----------|-------|-----------|-----------------|
| `action_done` | ✓ Done | No | Mark COMPLETED, cancel notification |
| `action_snooze` | ⏰ Snooze | No | Mark SNOOZED, schedule new notification |
| `action_call` | 📞 Call Now | Yes (dialer) | Mark COMPLETED, open tel:// URL |
| `action_open_url` | 🔗 Open Link | Yes (browser) | Mark COMPLETED, open URL |
| `action_text` | 💬 Text | Yes (messages) | Mark COMPLETED, open sms:// URL |
| `action_dismiss` | ✕ Dismiss | No | Mark DISMISSED, cancel notification |

### 19.4 Notification ID Strategy

Use a hash of the Reminder UUID truncated to fit in a 32-bit signed integer, with collision detection on scheduling. Store the resulting ID in `trigger.notification_id`. Each reminder maps to exactly one notification.

### 19.5 Platform-Specific Implementation

#### iOS

| Aspect | Behavior |
|--------|----------|
| Max pending | 64 notifications |
| Strategy | Schedule nearest 60 PENDING reminders. Keep 4 slots as buffer. |
| After reboot | Automatic (OS preserves) |
| Reconciliation | On app foreground, after notification action, and via BGAppRefreshTask (daily) |
| BGAppRefreshTask | Register one daily background refresh. It reconciles: ensures nearest 60 reminders have notifications. Runs in < 5 seconds. **Limitation:** BGAppRefreshTask does NOT run if the app has been force-quit by the user. In that case, reconciliation only occurs on next app foreground. |
| Background action handling | UNNotificationAction processed in extension. Must use shared App Group container for SQLite access. |
| Time-sensitive | Enable for all reminder notifications (iOS 15+) to break through Focus modes |
| Sound | Custom .caf file, max 30 seconds |

#### Android

| Aspect | Behavior |
|--------|----------|
| Exact alarms | Use `SCHEDULE_EXACT_ALARM` permission. Check `canScheduleExactAlarms()` before scheduling. |
| Fallback | If exact alarm permission revoked, use inexact alarm + show persistent notification: "Katala reminders may be delayed. [Enable exact alarms]" |
| After reboot | `BOOT_COMPLETED` receiver reschedules all PENDING alarms. Best-effort: not guaranteed on all manufacturers. |
| Reconciliation | On app foreground + via WorkManager periodic task (minimum daily). |
| WorkManager | Schedule a periodic `DailyReconciliationWorker` that runs once per day (flexible timing). Reschedules all PENDING reminder alarms. |
| Doze mode | Use `setExactAndAllowWhileIdle()` for reminder alarms |
| Battery optimization | Prompt user to exempt Katala during onboarding. Not required but strongly recommended. |
| Background action handling | BroadcastReceiver triggered by Notification PendingIntent. Must complete within ~10 seconds. |
| Foreground service | Not used. Notification actions use BroadcastReceiver with `goAsync()`. |
| Sound | Custom sound in `res/raw/` |

### 19.6 Notification Behavior Matrix

| Scenario | Behavior |
|----------|----------|
| App in foreground | In-app alert card instead of system notification |
| App in background | System notification banner |
| App terminated | System notification banner |
| Device locked | Lock screen notification |
| Do Not Disturb | Break through if Time-Sensitive (iOS) / HIGH priority alarm category (Android) |
| User taps notification body | Opens app → reminder detail |
| Notification expires unacted | Reminder stays PENDING; shows as overdue in app |
| Silent mode (mute switch) | Respect device silent mode. Katala does NOT use Critical Alerts. |
| Reboot (iOS) | Automatic |
| Reboot (Android) | Best-effort via BOOT_COMPLETED. Reconcile on next app open. |

---

## 20. Action System

### 20.1 CALL Action

| Aspect | Spec |
|--------|------|
| Trigger | [📞 Call Now] on notification or in-app button |
| iOS | `tel://[number]` URL → dialer |
| Android | `Intent(ACTION_DIAL, tel:[number])` → dialer |
| Permission | None (dialer opens; user must tap Call) |
| Missing number | Show in-app error: "No phone number stored for [Name]" |
| After action | Reminder → COMPLETED |

### 20.2 TEXT Action

| Aspect | Spec |
|--------|------|
| Trigger | [💬 Text] on notification or in-app button |
| iOS | `sms:[number]` URL → Messages |
| Android | `Intent(ACTION_SENDTO, smsto:[number])` → messages app |
| After action | Reminder → COMPLETED |

### 20.3 OPEN_URL Action

| Aspect | Spec |
|--------|------|
| Trigger | [🔗 Open Link] |
| URL validation | Only `http://` and `https://` schemes allowed. Reject `javascript:`, `file:`, and all others. |
| Missing scheme | Prepend `https://` |
| After action | Reminder → COMPLETED |

### 20.4 EMAIL Action

| Aspect | Spec |
|--------|------|
| Trigger | In-app only (no notification action for email in MVP — notification actions limited to 3-4) |
| iOS | `mailto:[address]` URL |
| Android | `Intent(ACTION_SENDTO, mailto:[address])` |

### 20.5 Action Safety Rules

1. **Never auto-dial.** Always open dialer; user must tap Call.
2. **Never auto-send.** Open compose screen; user must tap Send.
3. **Whitelist URL schemes.** Only http and https.
4. **Display URLs before opening.** URL visible in notification body and reminder detail.
5. **Graceful failure.** Missing data → helpful error, not crash.

---

## 21. Follow-Up System (Post-MVP)

> The follow-up engine is specified here for architectural completeness and will be implemented post-MVP. It is NOT part of the MVP build.

### 21.1 Supported Conditions

| Condition | Meaning |
|-----------|---------|
| `PARENT_NOT_COMPLETED` | If the parent reminder is still PENDING or SNOOZED at the deadline, create a follow-up reminder. If the parent is COMPLETED or DISMISSED, resolve (do nothing). |
| `TIME_ELAPSED` | Always create a follow-up reminder at the deadline (unconditional). |

### 21.2 Unsupported Conditions

Katala cannot observe: incoming calls, incoming texts, emails, weather, or calendar events. When a user's voice input implies these, Katala converts to `PARENT_NOT_COMPLETED` and explains the limitation.

### 21.3 Follow-Up Evaluation Algorithm

```
function evaluateFollowUp(rule):
  if rule.status != PENDING: return

  parent = db.getReminder(rule.parent_reminder_id)

  if parent == null or parent.is_deleted or parent.status == DISMISSED:
    rule.status = CANCELLED
    return

  switch rule.condition_type:
    case PARENT_NOT_COMPLETED:
      if parent.status == COMPLETED:
        rule.status = RESOLVED
        return
      else:
        rule.status = TRIGGERED
        createFollowUpReminder(rule, parent)

    case TIME_ELAPSED:
      rule.status = TRIGGERED
      createFollowUpReminder(rule, parent)
```

> *COMPLETED is terminal except for the 5-second undo window after completing a reminder. After the undo window expires, COMPLETED is permanently terminal.
>
> *DISMISSED is permanently terminal.

### 21.4 Follow-Up Reminder Defaults

Follow-up reminders default to `GENERAL` intent (no action). The user wanted to be reminded to CHECK on something, not necessarily repeat the original action. The follow-up notification shows [✓ Done] [⏰ Snooze] only.

### 21.5 Chain Depth

Maximum chain depth: 3 (parent → child → grandchild → great-grandchild). Enforced by `Reminder.depth`.

---

## 22. Geofencing (Post-MVP)

> Geofencing is specified here for architectural completeness and will be implemented post-MVP. It is NOT part of the MVP build.

### 22.1 Capabilities

- Saved locations (Home, Office, custom)
- Geofence reminders: trigger on ENTER or EXIT
- Map picker for location selection (requires network for tiles; coordinate input fallback when offline)
- OS region monitoring (20 regions iOS, 100 regions Android)
- Warning at 18/90 active geofences, block at limit

### 22.2 Accuracy Disclaimer

Geofence events have typical accuracy of 50-200m. They can be delayed by minutes. This is an inherent OS limitation that Katala documents to users.

---

## 23. UX Specification

### 23.1 Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Fast** | One-tap mic, parse within 500ms, explicit save (one tap) |
| **Calm** | Dark default, subtle animations, bird-inspired sounds |
| **Clear** | Every state has visible feedback. Errors say what went wrong and what to do. |
| **Forgiving** | Undo within 5 seconds for complete and delete. |

### 23.2 Screens

#### Onboarding (First Launch)

3-screen carousel:

1. **Welcome:** Logo, tagline "Your voice, your reminders, your device."
2. **How It Works:** Animated mic demo. "Tap the mic and speak naturally."
3. **Permissions:** Microphone (required for voice) and Notifications (required for reminders). [Grant] or [Skip] per permission. "Contacts and Location can be enabled later when needed."

> **V2 change:** Onboarding only requests Microphone and Notifications. Contacts and Location are requested contextually when the user creates a call reminder or location reminder respectively.

#### Home Screen (Timeline)

```
┌──────────────────────────────────┐
│  Katala                    ⚙️    │
├──────────────────────────────────┤
│  ▸ OVERDUE (2)                   │
│  ┌────────────────────────────┐  │
│  │ 🔴 Call dentist       9 AM │  │
│  │ 🔴 Submit report    10 AM │  │
│  └────────────────────────────┘  │
│  ▸ TODAY                         │
│  ┌────────────────────────────┐  │
│  │ 📞 Call Adam          2 PM │  │
│  │ 🔗 Check report       8 PM │  │
│  └────────────────────────────┘  │
│  ▸ TOMORROW                      │
│  ▸ LATER                         │
│                                  │
│         ┌──────────┐             │
│         │   🎤 Mic  │             │
│         └──────────┘             │
│  [🏠 Home] [✓ Completed] [⚙️]   │
└──────────────────────────────────┘
```

**Gestures (with alternatives):**
- Swipe right on reminder → Mark COMPLETED (also: long-press → "Mark Done")
- Swipe left on reminder → Delete with confirmation (also: long-press → "Delete")
- Tap reminder → Detail view
- Pull down → Refresh/reconcile notifications

**Empty state:** Bird illustration + "No reminders yet. Tap the mic to create one."

**Overdue indicators:** Red accent dot + "Overdue" label. Semantically labeled for screen readers: "Overdue: [title], scheduled [time]."

#### Confirmation Card

Appears after successful NLP parse:
- Title with intent icon (📞/🔗/📝)
- Resolved time with AM/PM indicator
- Contact/phone/URL if applicable
- Notes
- **[Save]** (primary) and **[Edit]** (secondary) buttons
- No auto-save timer

#### Clarification Card

Appears when entities are missing or confidence is LOW:
- "Here's what I understood:" showing parsed fields
- "I need to know:" showing missing fields with specific prompts
- Quick-pick chips for common answers
- Manual input for custom answers

#### Reminder Detail View

- Title, status badge, time, contact/URL, notes, creation info, original transcript
- Action buttons: [✓ Mark Done] [⏰ Snooze] [📞 Call Now] (if CALL), [🔗 Open Link] (if LINK)
- [Edit] button → edit form
- [🗑️ Delete] (destructive, at bottom)
- [Add Follow-up] (Post-MVP)

### 23.3 Voice Input State

```
┌──────────────────────────────────┐
│        [Pulsing mic icon]        │
│     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │  ← Waveform
│     "remind me to call adam      │  ← Live transcript
│      tomorrow at 3 pm"          │
│         [Tap to stop]            │
└──────────────────────────────────┘
```

The entire screen is tap-to-stop. Auto-stop after silence_timeout_seconds.

### 23.4 Color System

**Dark Theme (Default):**
- Background: #0F0F14
- Cards: #1A1A24
- Primary text: #F0F0F5
- Secondary text: #8888A0
- Accent (mic, primary actions): #6C5CE7
- Success: #00D2A0
- Warning (conflicts, overdue): #FDCB6E
- Error/Destructive: #FF6B6B
- Snooze: #74B9FF

### 23.5 Typography

Use Inter (Google Fonts), fallback to SF Pro (iOS) / Roboto (Android).

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Headline | 28sp | Bold 700 | Screen titles |
| Title | 20sp | SemiBold 600 | Section headers, detail title |
| Body | 16sp | Regular 400 | Body text, list titles |
| Caption | 14sp | Regular 400 | Timestamps, secondary |
| Small | 12sp | Medium 500 | Badges, labels |

### 23.6 Animations

- Mic tap: scale + glow ring, 200ms
- Listening: pulsing ring + waveform, continuous
- Confirmation card: slide up + fade, 300ms ease-out
- Save success: checkmark + chirp sound, 400ms
- Swipe complete: green slide, 300ms
- Swipe delete: red slide + trash icon, 300ms
- **Reduced motion:** Respect OS setting. Replace animations with instant fades (150ms).

### 23.7 Sounds

- Confirmation chirp: < 1 second bird chirp on save. `.caf` (iOS) / `.ogg` (Android)
- Notification sound: < 5 seconds bird-inspired tone

### 23.8 "Undo" Snackbar

After completing or deleting a reminder, show a snackbar for 5 seconds:
- "Reminder completed. [Undo]" / "Reminder deleted. [Undo]"
- Undo reverts the state transition
- After 5 seconds, the action is permanent

---

## 24. Accessibility

### 24.1 Screen Reader Labels

| Element | Label | Hint |
|---------|-------|------|
| Mic button | "Create reminder by voice" | "Double tap to start listening" |
| Reminder in list | "[Title], [Time], [Status]" | "Double tap to view details. Swipe right to complete." |
| Confirmation card | "New reminder: [Title] at [Time]" | "Review and save or edit" |
| Delete button | "Delete reminder" | "This will permanently remove the reminder" |
| Overdue indicator | "Overdue" (not just a red dot) | — |

### 24.2 Dynamic Text

- Support iOS Dynamic Type and Android font scaling
- All text reflows at up to 200% size
- Minimum text size: 12sp

### 24.3 Touch Targets

- All interactive elements: minimum 48×48 dp
- Spacing between targets: minimum 8dp

### 24.4 Non-Voice Path

Every action achievable by voice MUST also be achievable via text input or form controls. Voice is never the only way.

### 24.5 Reduced Motion

When OS "reduce motion" is active:
- No animations except simple fades (150ms)
- Waveform → static mic with "Listening..." text
- Pulsing mic → static glowing mic

### 24.6 Haptic Alternatives

All haptic events have visual equivalents. Users can disable haptics in Settings. Screen reader announces state changes.

---

## 25. Privacy

### 25.1 What Katala Promises

> Katala does not operate any backend servers. No reminder content, contact data, location data, or voice recordings are transmitted to any server operated by Katala. All personal data processing occurs on-device.

### 25.2 Data Inventory

| Data | Stored Where | Leaves Device? |
|------|-------------|:---:|
| Reminder content | Local SQLite | No |
| Voice audio | NOT stored (streamed, discarded) | No |
| Transcripts | Local SQLite (optional) | No |
| Contact matches | Local SQLite (snapshot at creation) | No |
| User preferences | Local SQLite | No |

### 25.3 Documented Exceptions

These are limitations Katala MUST disclose honestly to users:

| Scenario | What May Leave Device | Mitigation |
|----------|----------------------|------------|
| Device backup (iCloud/Google) | SQLite database if backup is enabled | **Default: backups disabled.** User can opt in via Settings with clear privacy notice. |
| Map tile loading (Post-MVP) | Viewport coordinates to Apple/Google Maps | Only during location picker usage. Geofencing uses on-device GPS only. |
| Android STT (pre-13 or non-Pixel devices) | Audio may be sent to Google for server-side processing | Katala sets `EXTRA_PREFER_OFFLINE`. On Android 13+, checks model availability. Documents that for some devices, voice privacy cannot be technically guaranteed. |
| Notification actions (Call, Text, Navigate) | Phone number/URL sent to system apps (dialer, messages, maps, browser) | Inherent to the feature. Data goes to system apps, not to Katala. |
| App store analytics | Apple/Google collect standard download/usage metrics | Outside Katala's control. Katala includes zero analytics SDKs. |

### 25.4 What Katala Does NOT Include

- ❌ Analytics SDKs (Firebase, Mixpanel, etc.)
- ❌ Crash reporting SDKs (Sentry, Crashlytics, etc.)
- ❌ Advertising SDKs
- ❌ User authentication
- ❌ Network requests initiated by Katala code
- ❌ Audio file persistence
- ❌ Background location tracking (GPS polling)

### 25.5 Database Backup Policy

**Default: Database is excluded from iCloud and Android Auto Backup.**

Rationale: The privacy model promises data never leaves the device. Including backups sends all reminder data through Apple/Google infrastructure without explicit user consent.

Users can enable backups in Settings → Privacy → "Include in device backups." When toggled on, show: "Your reminders will be included in your device backup (iCloud or Google Drive). The backup is encrypted, but the data will be stored on Apple/Google servers."

### 25.6 Logging Policy

- **Debug builds:** Verbose NLP pipeline logging. No audio. No contact data in logs.
- **Release builds:** Only aggregate operational events (e.g., "notification_scheduled", count=1). No reminder IDs, titles, times, contact names, phone numbers, or transcript content in release logs.
- **No log transmission.** Logs stay on device.

### 25.7 App Uninstall

On uninstall, the OS deletes all app data. No residual data remains.

---

## 26. Security

### 26.1 Local Storage

- SQLite database protected by OS sandbox (iOS: NSFileProtectionComplete, Android: app sandbox)
- No database encryption in MVP (Post-MVP: SQLCipher)
- `NSFileProtectionComplete` ensures database is encrypted at rest when device is locked (iOS)

### 26.2 URL Handling

- Only `http://` and `https://` schemes are allowed
- `javascript:`, `file:`, `data:`, and all custom schemes are rejected
- Validate BEFORE storing AND before opening

### 26.3 Contact Data

- Contact data is a snapshot taken at reminder creation time
- If the contact is later deleted or contacts permission revoked, the stored snapshot remains usable
- No proactive contact scanning; only accessed during reminder creation

### 26.4 Deep Links

Katala does NOT register any custom URL schemes in MVP. This is explicitly out of scope.

### 26.5 Input Validation

- Reminder title: max 200 chars, reject empty
- Notes: max 1000 chars
- Phone numbers: validate format before storing
- URLs: validate scheme and format

---

## 27. Offline Behavior

### 27.1 Core Functionality

All MVP features work with airplane mode enabled:
- Voice input (on-device STT)
- NLP parsing (100% local)
- Reminder persistence (local SQLite)
- Notification scheduling (OS local notifications)
- Notification actions (Done, Snooze, Call, Open Link)
- Timeline viewing, editing, deleting

### 27.2 What Requires Network (Limited)

| Feature | Network Needed? | Offline Behavior |
|---------|:---:|-----------------|
| Map tile loading (Post-MVP) | Yes | Coordinate input + saved locations available offline |
| Contact photo loading | Yes (if using OS contact photos) | Show initials placeholder |
| Google Fonts (Inter) | First launch only | Bundle font in app; no runtime download |

### 27.3 Offline Map Tiles (Post-MVP)

When selecting a location for geofencing and no network is available: show numeric coordinate input (latitude/longitude) and list of saved locations. Do NOT show an empty map.

---

## 28. Platform Architecture

### 28.1 Flutter Architecture

```
┌────────────────────────────────────────────────┐
│                  UI Layer (Flutter)              │
│  Screens, Widgets, Animations, Theme            │
├────────────────────────────────────────────────┤
│              Application Layer (Dart)            │
│  ReminderService, NotificationService,          │
│  SettingsService, ConflictDetector              │
├────────────────────────────────────────────────┤
│                Domain Layer (Dart)               │
│  NLP Pipeline, State Machine,                   │
│  Entity Extraction, Temporal Resolution,        │
│  Contact Resolution, Confidence Scoring         │
├────────────────────────────────────────────────┤
│                 Data Layer (Dart)                │
│  Drift DAOs, Repository pattern                 │
├────────────────────────────────────────────────┤
│            Platform Bridges (Dart interface)     │
│  SpeechBridge, NotificationBridge,              │
│  ContactBridge, ActionBridge                    │
├──────────────────────┬─────────────────────────┤
│   iOS Implementation │  Android Implementation   │
│   (Swift)            │  (Kotlin)                 │
└──────────────────────┴─────────────────────────┘
```

### 28.2 State Management: Riverpod

Use `flutter_riverpod` for dependency injection and reactive state management. All services are provided via Riverpod providers. UI observes state via `ref.watch()`.

### 28.3 Layer Rules

| Rule | Description |
|------|------------|
| Domain has no Flutter imports | Pure Dart; testable without Flutter |
| Data layer depends on Domain | Not vice versa |
| Application layer depends on Domain + Data | Orchestrates use cases |
| UI depends on Application | Never directly on Data |
| Platform bridges are abstract in Domain | Implemented in platform-specific code |
| Business logic identical on both platforms | Only platform bridges differ |

### 28.4 Platform-Specific Implementation Notes

#### iOS

- Minimum: iOS 16+
- Language: Swift 5.9+
- Speech: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`
- Notifications: `UNUserNotificationCenter`
- Background: `BGAppRefreshTask` for notification reconciliation
- Database: Shared App Group container for notification extension access

#### Android

- Minimum: Android 10 (API 29)
- Language: Kotlin 1.9+
- Speech: `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE`
- Notifications: `NotificationManager` + `AlarmManager`
- Background: `WorkManager` for periodic reconciliation + `BOOT_COMPLETED` receiver + `BroadcastReceiver` for notification actions
- Database: App-internal storage (no shared container needed)

---

## 29. Platform Bridge Contracts

### 29.1 SpeechBridge

```dart
abstract class SpeechBridge {
  Future<bool> get isAvailable;
  Future<bool> get isOnDeviceAvailable;
  Future<String?> get unavailableReason; // Human-readable explanation
  Stream<String> startListening({Duration? silenceTimeout});
  Future<void> stopListening();
  Future<void> dispose();
}
```

### 29.2 NotificationBridge

```dart
abstract class NotificationBridge {
  Future<bool> requestPermission();
  Future<bool> get hasPermission;
  Future<int> schedule(Reminder reminder);
  Future<void> cancel(int notificationId);
  Future<List<int>> getScheduledNotificationIds(); // Best-effort
  Future<void> reconcile(List<Reminder> pendingReminders);
  void configureCategories(); // Called at app init
}
```

### 29.3 ContactBridge

```dart
abstract class ContactBridge {
  Future<bool> requestPermission();
  Future<bool> get hasPermission;
  Future<List<ContactEntry>> searchByName(String query);
}

class ContactEntry {
  final String id;
  final String displayName;
  final String? firstName;
  final String? lastName;
  final List<String> phoneNumbers;
  final List<String> emailAddresses;
}
```

### 29.4 ActionBridge

```dart
abstract class ActionBridge {
  Future<bool> openDialer(String phoneNumber);
  Future<bool> openSms(String phoneNumber);
  Future<bool> openEmail(String emailAddress);
  Future<bool> openUrl(String url);
  Future<bool> openMaps(double lat, double lng, String? label);
}
```

---

## 30. Error Handling & Failure Modes

### 30.1 Per-Subsystem Failure Table

| Subsystem | Failure | Detection | User-Facing | Recovery |
|-----------|---------|-----------|-------------|----------|
| STT | No on-device model | `isOnDeviceAvailable == false` | "Voice unavailable — type instead" + reason | Text input fallback |
| STT | Permission denied | Permission check | Rationale + Settings button | User grants permission |
| STT | No speech detected | Empty transcript | "I didn't hear anything. Try again?" | Try again |
| NLP | Parse failed (LOW confidence) | Confidence < 0.50 | Clarification card with specific questions | User fills missing fields |
| NLP | Semantic contradiction | Validation error V9 | "That time has already passed" + edit | User adjusts time |
| Database | Write failure | Transaction rollback | "Couldn't save. Try again?" + retry | Retry once |
| Database | Corruption on startup | `PRAGMA integrity_check` fails | "Data corrupted. [Reset] [Contact Support]" | Reset or manual recovery |
| Notification | Schedule failure | Platform error | Silent (retry on next reconciliation) | Reconcile on app open / periodic task |
| Notification | Permission denied | Permission check | "Notifications off — you might miss reminders" + Settings button | User enables |
| Contact | Permission denied | Permission check | Store name only; show "Grant contacts access to add phone numbers" | User grants permission |
| Contact | Not found | ContactRef.resolved == false | Store name as text; no phone number | User can manually add number in edit |
| Action | Missing phone/URL | Null check before opening | In-app error: "No [phone/URL] stored" | User adds data in edit |

### 30.2 General Error Principles

1. Every error has a user-facing message explaining what went wrong
2. Every error message includes a concrete next action
3. Never show raw exception messages to users
4. Database errors: retry once, then surface
5. No silent failures in release builds

---

## 31. Lifecycle, Reboot & Background Behavior

### 31.1 App Startup Sequence

1. Check database integrity (`PRAGMA integrity_check`)
2. Run pending database migrations
3. Initialize platform bridges
4. Configure notification categories
5. Reconcile notification queue (ensure nearest N reminders are scheduled)
6. Hard-delete reminders past retention period (once per day)
7. Render UI

### 31.2 App Foreground

1. Reconcile notification queue
2. Refresh timeline from database (reactive via Drift streams)
3. Check for overdue reminders → update badge

### 31.3 App Background

- iOS: No guaranteed background time beyond brief tasks
- Android: Notification actions handled via BroadcastReceiver

### 31.4 App Termination

- Notifications remain scheduled (iOS: automatic, Android: alarms persist until reboot)
- No cleanup needed beyond what the OS handles
- On next launch, reconciliation catches any missed notifications

### 31.5 Device Reboot

**iOS:** Notifications preserved automatically. No action needed.

**Android:** `BOOT_COMPLETED` receiver registered. On receive:
1. Query all PENDING reminders with time triggers
2. Reschedule all alarms
3. If the receiver does NOT fire (manufacturer restriction), notifications are lost until next app open
4. Daily `WorkManager` task provides secondary reconciliation path

### 31.6 Timezone Change

- Reminders stored as UTC + timezone ID
- On timezone change, the wall-clock time for display changes but the UTC instant does NOT change
- A reminder set for "3:00 PM Asia/Manila" will fire at the same absolute moment even if the user travels to Tokyo (where it displays as 4:00 PM JST)
- On next app open or reconciliation, verify scheduled notification times match intended wall-clock times and reschedule if needed

### 31.7 DST Transition

- Spring-forward: reminder at 2:30 AM fires at 3:00 AM
- Fall-back: reminder at 1:30 AM fires at the first occurrence
- Reconciliation after a DST transition verifies and corrects scheduled times

---

## 32. Testing Strategy

### 32.1 Test Pyramid

```
        ┌──────┐
        │ E2E  │  Manual / integration (real devices)
        ├──────┤
        │ UI   │  Widget tests (Flutter)
        ├──────┤
        │ Unit │  Domain, NLP, State Machine, Data
        └──────┘
```

### 32.2 Unit Tests (Must Have)

| Component | What to Test | How |
|-----------|-------------|-----|
| Pre-Processor | Contraction expansion, number normalization, STT correction | Given raw transcript → expect normalized text |
| Intent Detector | All trigger patterns (English + Taglish), fallback | Given normalized text → expect intent + score |
| Entity Extractor | Contact, URL, phone, action extraction | Given normalized text → expect entities |
| Temporal Resolver | All expression types, past-time handling, DST boundaries | Given text + fixed clock → expect UTC DateTime + timezone |
| Contact Resolver | Exact, partial, no match, ambiguous | Given name + mock contacts DB → expect ContactRef |
| Semantic Validator | Missing time, missing contact, past time | Given entities → expect validation errors |
| Confidence Scorer | HIGH, MEDIUM, LOW thresholds | Given full parse result → expect confidence level |
| State Machine | All defined transitions, guards, illegal transitions | Given state + event → expect new state or rejection |
| Conflict Detector | Conflict found, no conflict, edge of window | Given new time + mock DB → expect conflict list |
| Alternative Suggester | Next slot, no slot available | Given time + conflicts → expect suggested time or null |
| ReminderDraft Builder | All fields populated correctly | Given all parse results → expect correct draft |

### 32.3 Test Corpus (English)

```
"remind me to buy groceries tomorrow at 5 pm"
"call Adam at 2"
"text Maria tomorrow morning about the project"
"check https://example.com/report at 8 pm"
"remind me in 20 minutes to call John"
"remind me next Monday at 9 am about the presentation"
"don't forget to submit the report by end of day"
"remind me to call dentist on August 15 at 10 am"
"remind me tonight to pack for the trip"
```

### 32.4 Test Corpus (Taglish/Filipino)

```
"pa-remind naman bukas ng 3 pm na tawagan si Adam"
"remind mo ko mamaya to call boss"
"bukas ng umaga remind me about the meeting"
"mag-remind ka sa akin sa Lunes tungkol sa presentation"
"ipaalala mo sa akin mamayang gabi"
"tawagan si Maria at 2 pm"
```

### 32.5 NLP Testability

ALL NLP functions MUST accept an injectable `Clock` interface. Tests inject a `FakeClock` with a fixed time. Without this, temporal resolution tests are non-deterministic.

### 32.6 Platform Bridge Testing

- Dart-side logic tested with fake bridge implementations
- Real bridge implementations tested on physical devices (manual + integration)
- Fake bridges return pre-configured responses for known test scenarios

### 32.7 Acceptance Test Checklist

See §33 Acceptance Criteria.

---

## 33. Acceptance Criteria

### 33.1 Voice Input

| ID | Criterion |
|----|----------|
| AC-1 | Tapping the mic starts listening within 500ms |
| AC-2 | Transcript appears in real-time during speech |
| AC-3 | After silence timeout, NLP processes and shows confirmation within 500ms |
| AC-4 | All test corpus commands (English) parse with ≥ HIGH confidence |
| AC-5 | All test corpus commands (Taglish) parse with ≥ MEDIUM confidence |
| AC-6 | "at 8" (no AM/PM) shows AM/PM toggle, does NOT auto-resolve |
| AC-7 | Past time is detected and user is informed |
| AC-8 | Missing required entity triggers a specific clarification question |
| AC-9 | Confidence is never the sole trigger for auto-saving (never auto-save) |

### 33.2 Notifications

| ID | Criterion |
|----|----------|
| AC-10 | Time-based reminder fires notification within ±1 minute of scheduled time |
| AC-11 | Notification shows correct category actions (Done, Snooze, Call, Open Link) based on intent_type |
| AC-12 | Tapping Done on notification marks reminder COMPLETED without opening app |
| AC-13 | Tapping Snooze on notification schedules a new notification at now + snooze_duration |
| AC-14 | Tapping Call Now opens dialer with correct number |
| AC-15 | Tapping Open Link opens browser with correct URL |
| AC-16 | On Android reboot, pending notifications are rescheduled (or reconciled on next app open) |
| AC-17 | iOS notification queue never exceeds 64 pending |

### 33.3 Data Integrity

| ID | Criterion |
|----|----------|
| AC-18 | Creating a reminder atomically persists Reminder + Trigger + Action |
| AC-19 | All times stored as UTC with IANA timezone |
| AC-20 | Database integrity check passes on startup |
| AC-21 | Soft-deleted reminders are retained for 30 days, then hard-deleted |
| AC-22 | Undo within 5 seconds reverts COMPLETED and DELETE operations |

### 33.4 Privacy

| ID | Criterion |
|----|----------|
| AC-23 | Release build makes zero network requests (verified by network traffic audit) |
| AC-24 | No audio files exist in app storage at any time |
| AC-25 | Release logs contain no reminder titles, contact names, phone numbers, or transcript content |
| AC-26 | Database is excluded from device backups by default |
| AC-27 | Privacy Information screen is accessible from Settings and accurately describes all data handling |

### 33.5 Platform & Accessibility

| ID | Criterion |
|----|----------|
| AC-28 | App runs on iOS 16+ and Android 10+ |
| AC-29 | All interactive elements have accessibility labels |
| AC-30 | Dynamic text at 200% does not break layout |
| AC-31 | All features work in airplane mode (except map tiles in Post-MVP) |
| AC-32 | Voice unavailable → text input is available and obvious |

### 33.6 Conflict Detection

| ID | Criterion |
|----|----------|
| AC-33 | Creating reminder within 15 min of existing PENDING reminder triggers conflict warning |
| AC-34 | Conflict warning offers alternative time as default option |
| AC-35 | "Save anyway" is available as secondary option |

---

## 34. Implementation Constraints

### 34.1 Absolute Prohibitions

| ID | Constraint |
|----|-----------|
| CC-1 | **No network requests.** No HTTP, no WebSocket, no TCP socket connections initiated by Katala code. |
| CC-2 | **No analytics SDKs.** No Firebase, Google Analytics, Mixpanel, Amplitude, or any telemetry. |
| CC-3 | **No crash reporting SDKs.** No Sentry, Crashlytics, Bugsnag. |
| CC-4 | **No advertising SDKs.** |
| CC-5 | **No user authentication.** No accounts, no OAuth, no biometric app lock (MVP). |
| CC-6 | **No cloud STT.** Always enforce on-device recognition. If unavailable, disable voice — do NOT silently fall back. |
| CC-7 | **Use Drift for persistence.** Not Isar, not Hive for structured data. |
| CC-8 | **Rule-based NLP only.** No TensorFlow Lite, ONNX, or ML inference. |
| CC-9 | **Never auto-initiate calls.** Use ACTION_DIAL / tel: URL. Never ACTION_CALL. |
| CC-10 | **Never auto-send messages.** Open compose screen only. |
| CC-11 | **Never store audio.** Stream to STT, discard immediately. No .wav/.m4a files. |
| CC-12 | **Never log personal data in release builds.** |
| CC-13 | **Always store times as UTC with timezone.** |

### 34.2 Dependency Whitelist

Allowed pub.dev packages:
- `drift`, `drift_flutter` — Database
- `flutter_local_notifications` — Notifications
- `speech_to_text` or custom native bridge — STT
- `flutter_riverpod` — State management + DI
- `uuid` — UUID generation
- `intl` — Date formatting
- `path_provider` — File paths
- `url_launcher` — URL/dialer/sms opening
- `permission_handler` — Runtime permissions
- `google_fonts` — Typography (bundle Inter font)

Any package not on this list requires a code comment justifying its inclusion.

### 34.3 Code Quality

| ID | Constraint |
|----|-----------|
| CC-14 | All NLP functions must be pure: deterministic output for deterministic input |
| CC-15 | Use dependency injection for Clock, Database, and Platform Bridges |
| CC-16 | Write tests for all NLP pipeline stages, state machine, conflict detection |
| CC-17 | Document any design decision that deviates from this spec |
| CC-18 | Business logic must produce identical results on iOS and Android |

---

## 35. Architectural Decisions

| ID | Decision | Rationale | Alternatives Rejected |
|----|----------|-----------|----------------------|
| ADR-1 | Flutter cross-platform | Single codebase for iOS + Android | Native Swift + Kotlin (higher quality but 2x work) |
| ADR-2 | Drift for persistence | Type-safe SQLite wrapper, migration support, reactive streams | Isar (deprecated), Hive (NoSQL, no queries) |
| ADR-3 | Native OS speech engines | Zero-cost, on-device, no third-party dependency | Whisper.cpp (model download required), Vosk (limited language support) |
| ADR-4 | Rule-based regex NLP | Deterministic, fast, offline, testable | ML/NLU (non-deterministic, model size, offline challenges) |
| ADR-5 | Riverpod for state management | Compile-safe DI, testable, Flutter-native | BLoC (more boilerplate), Provider (less type-safe) |
| ADR-6 | Remove auto-save | One mistimed auto-saved reminder destroys more trust than one extra tap | Auto-save at HIGH confidence (V1 approach — rejected) |
| ADR-7 | Exclude database from backups by default | Aligns with "data never leaves device" promise; user can opt in | Include by default (V1 approach — conflicts with privacy claims) |
| ADR-8 | Always ask for AM/PM on bare numbers | Getting it wrong causes missed reminders; one tap is cheap | Heuristic 1-6 ask, 7-11 auto (V1 approach — error-prone) |
| ADR-9 | Geofencing is Post-MVP | Reduces MVP surface area while preserving core voice→notification value | Include in MVP (increases scope by ~3 weeks) |

---

## 36. Implementation Roadmap

### Phase 1: Project Setup (Week 1)
- Flutter project scaffold
- Drift database setup with schema
- Riverpod configuration
- Platform bridge interfaces (abstract)
- CI pipeline (lint, test, build)

### Phase 2: Domain Layer — NLP Pipeline (Weeks 2-3)
- Pre-Processor (Stage 2)
- Intent Detector (Stage 3) with English + Taglish patterns
- Entity Extractor (Stage 4): contact, URL, phone, action
- Temporal Resolver (Stage 5): all expression types
- Contact Resolver (Stage 6): exact, partial, contains matching
- Semantic Validator (Stage 7)
- Confidence Scorer (Stage 8)
- ReminderDraft Builder
- Unit tests for all stages with fixed-clock injection

### Phase 3: Data Layer (Week 4)
- Drift DAOs for Reminder, Trigger, Action, UserPreference
- Repository pattern
- State machine transitions with optimistic locking
- Conflict detection + alternative suggestion
- Soft-delete + retention cleanup
- Data layer tests

### Phase 4: Platform Bridges — STT + Notifications (Weeks 5-6)
- iOS SpeechBridge (SFSpeechRecognizer, on-device)
- Android SpeechBridge (SpeechRecognizer, offline preference)
- iOS NotificationBridge (UNNotificationCenter, categories, BGAppRefreshTask)
- Android NotificationBridge (AlarmManager, BOOT_COMPLETED, WorkManager)
- Notification action handlers (background Done/Snooze/Call/Open)
- Bridge integration tests

### Phase 5: UI — Core Screens (Weeks 7-8)
- Home screen timeline with grouping (overdue, today, tomorrow, later)
- Voice input UI (mic, waveform, live transcript, tap-to-stop)
- Confirmation card (parsed fields, Save/Edit)
- Clarification card (specific questions, quick-pick chips)
- Reminder detail view
- Reminder edit form
- Onboarding carousel
- Settings screen
- Empty/error states
- Swipe gestures with long-press alternatives
- Undo snackbar
- Dark/light theme

### Phase 6: Contact Resolution & Actions (Week 9)
- iOS ContactBridge (CNContactStore)
- Android ContactBridge (ContactsContract)
- Contact disambiguation UI
- CALL, TEXT, EMAIL, OPEN_URL action implementation
- Action error handling

### Phase 7: Conflict Detection Integration (Week 10)
- Integrate conflict detection into voice + text creation flows
- Conflict warning UI
- Alternative time suggestion UI
- Integration tests

### Phase 8: Polish & Testing (Weeks 11-12)
- Accessibility audit and fixes
- Animations (mic pulse, save confirmation, swipe)
- Haptic feedback
- Network traffic audit (zero requests verification)
- Release build testing on iOS and Android devices
- Performance: voice-to-save < 5 seconds
- Edge case testing (all failure scenarios)
- Bug fixes

### Post-MVP Phases

**Phase 9: Geofencing (Weeks 13-14)**
**Phase 10: Follow-Ups (Weeks 15-16)**
**Phase 11: Enhanced NLP (Week 17+)**

---

## 37. Open Product Decisions

The following decisions require product-owner input. Default assumptions are provided.

| ID | Question | Default | Options |
|----|----------|---------|---------|
| PD-1 | Should the database be excluded from device backups? | **Yes, exclude.** Aligns with privacy promise. Users who want backups can opt in via Settings. | (a) Exclude by default (recommended), (b) Include by default with disclosure |
| PD-2 | Should "tomorrow" without a time always ask or use a default? | **Ask with quick-pick chips.** | (a) Always ask (current), (b) Use 9:00 AM default with option to change |
| PD-3 | What is the exact notification chirp sound? | Royalty-free bird chirp < 5 seconds. Source TBD. | (a) Source from freesound.org, (b) Commission custom sound, (c) Use simple tone |
| PD-4 | Should the Katala logo be realistic or stylized? | Stylized/minimal cockatoo silhouette. Monochrome. | Designer decision |
| PD-5 | Should compound commands be split? | **No for MVP.** Treat as single reminder. | (a) Single reminder (MVP), (b) Split into multiple (Post-MVP) |
| PD-6 | Should completed reminders be visible on the home timeline? | **Hidden by default.** Accessible via "Completed" tab. | (a) Hidden (current), (b) Show with strikethrough |
| PD-7 | What is the app store name, subtitle, and description? | Deferred to launch prep. | — |
| PD-8 | Should Katala support pure Filipino voice input by using cloud STT? | **No for MVP.** This requires explicit user consent and a privacy trade-off. Evaluate for Post-MVP. | (a) No cloud STT, Filipino text-only on iOS (current), (b) Offer opt-in cloud STT for Filipino |

---

## 38. Changes From V1

| # | Original (V1) | Review Finding | Decision | New Behavior (V2) | Reason |
|---|--------------|---------------|----------|-------------------|--------|
| 1 | Auto-save HIGH confidence reminders after 2s | UX Attack: dangerous; user may be about to edit | ACCEPT | Never auto-save. All reminders require explicit [Save] tap. | Trust > one less tap |
| 2 | AM/PM heuristic for bare numbers (1-6 ask, 7-11 auto) | Ambiguity: wrong direction; creates schedule errors | ACCEPT | Always show AM/PM toggle for bare numbers 1-12. | One tap is cheap; getting it wrong breaks trust |
| 3 | "Later" = now + 2 hours, no cap | Ambiguity: could fire at midnight | ACCEPT | Cap "later": if result > 10 PM or < 7 AM, move to 8 AM next day. | Prevents middle-of-night notifications |
| 4 | DISMISSED not checked in follow-up evaluation | State Machine: algorithm only checks is_deleted and COMPLETED | ACCEPT | Follow-up evaluation also checks `parent.status == DISMISSED` → CANCELLED. | Consistency with state machine principle |
| 5 | SNOOZED → SNOOZED transition missing | State Machine: user can't re-snooze from notification | ACCEPT | Add SNOOZED → SNOOZED transition with guard snooze_count < 10. | Users naturally re-snooze |
| 6 | Reminder.depth field missing | Data Model: follow-up chain limiting references parent.depth but Reminder has no depth | ACCEPT | Add `depth` int field to Reminder (0 = root, max 3). | Enables chain depth limiting |
| 7 | No optimistic locking / concurrency model | Concurrency: undefined race behavior | ACCEPT | Add `version` int field. All state transitions use optimistic locking. | Prevents double-complete, edit+notify races |
| 8 | Contact resolution used Jaro-Winkler fuzzy matching | Architecture: expensive, error-prone on large contact lists | ACCEPT | Remove Jaro-Winkler. Use: exact → partial → contains matching. | Simpler, faster, covers common cases |
| 9 | Filler word removal stripped "like", "actually", "basically" | NLP: can strip meaningful words | ACCEPT | Only strip "um" and "uh" when adjacent to silence markers. Keep all other words. | Avoids information loss |
| 10 | Database included in device backups by default | Privacy: conflicts with "no data ever leaves device" | ACCEPT | Exclude from backups by default. Opt-in via Settings with privacy notice. | Honest privacy guarantee |
| 11 | No periodic background notification reconciliation | Platform: reminders silently fail after reboot or 64-limit | ACCEPT | iOS: BGAppRefreshTask daily. Android: WorkManager daily + BOOT_COMPLETED receiver. | Catches missed notifications |
| 12 | No database integrity check on startup | Failure Mode: corrupted DB used silently | ACCEPT | Run PRAGMA integrity_check on startup. If fails, show recovery options. | Prevent silent data corruption |
| 13 | Notification sound during silent mode not specified | Ambiguity: behavior undefined | ACCEPT | Document: Katala respects mute switch. No Critical Alerts entitlement. | Honest about platform limitation |
| 14 | URL scheme validation not specified | Security: javascript/file URLs could be opened | ACCEPT | Whitelist only http:// and https://. Validate before storing AND opening. | Security |
| 15 | No "Undo" for complete/delete | UX: accidental swipe is permanent | ACCEPT | 5-second undo snackbar after complete and delete. | Forgiving UX |
| 16 | Follow-up reminders inherit parent's action | Product: follow-up about checking, not re-doing action | ACCEPT | Follow-up reminders default to GENERAL intent (no action). | Matches user intent |
| 17 | NLP functions use DateTime.now() directly | Testability: non-deterministic tests | ACCEPT | All temporal functions accept injectable Clock interface. | Deterministic testing |
| 18 | Onboarding requests all 4 permissions upfront | UX: over-requests; may cause denial | ACCEPT | Onboarding only requests Mic + Notifications. Contacts and Location requested contextually. | Better permission acceptance |
| 19 | Taglish/Filipino NLP patterns insufficient | NLP Attack: "Pa-remind", "Remind mo ko" don't match | ACCEPT | Add Taglish intent patterns: "pa-remind", "remind mo ko", "mag-remind", etc. Add Taglish contact extraction. | Primary market coverage |
| 20 | Filipino on-device STT implicitly assumed available | Platform Reality: not available on iOS | ACCEPT | Document honestly: Filipino STT not on-device on iOS. Voice disabled for pure Filipino on iOS. Text input available. | Honesty about platform limitations |
| 21 | Geofencing treated as core in user journeys but Post-MVP in roadmap | Product Intent Drift: PLAN.md has it in Phase 3 | DEFER | Geofencing stays Post-MVP. User journeys marked accordingly. PLAN.md Phase 3 re-interpreted as "post initial launch." | Reduce MVP surface area |
| 22 | No state management architecture specified | AI Agent Failure: inconsistent patterns | ACCEPT | Mandate Riverpod for DI + state management. Define layer structure. | Consistent architecture |
| 23 | Conflict "Save Anyway" is first/primary option | UX: defeats purpose of conflict detection | ACCEPT | "Move to [suggested time]" is primary. "Save Anyway" is secondary. | Encourages resolution |
| 24 | EDIT, DELETE, QUERY voice intents in MVP | Scope: high complexity, high risk | DEFER | Move to Post-MVP. MVP is voice CREATE_REMINDER only. | Reduced MVP surface |
| 25 | Recurring reminders excluded without data model prep | Future-proofing: schema migration needed later | ACCEPT | Add nullable `recurrence_rule` column to Trigger (RFC 5545 RRULE) for future use. Default null. | No migration needed later |
| 26 | Notification actions on Android may not survive force-stop | Platform Reality: common on Chinese OEMs | ACCEPT | Document limitation. Provide WorkManager fallback. Guide users to disable battery optimization. | Honest about reliability |

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
"pa-remind naman"
```

### A.3 Filipino Temporal Keywords (Always Active)

```
"bukas" → tomorrow
"mamaya" → later (now + 2 hrs)
"mamayang gabi" → tonight (8 PM)
"mamayang hapon" → this afternoon (2 PM)
"sa makalawa" → day after tomorrow
"sa susunod na linggo" → next week
"sa Lunes/Martes/Miyerkules/Huwebes/Biyernes/Sabado/Linggo" → day of week
"ngayong gabi" → tonight
"ngayon" → today
"tanghali" → noon (12 PM)
"alas [number]" → [number]:00 (e.g., "alas tres" = 3:00)
"ng umaga" → AM modifier
"ng gabi" → PM modifier
"ng hapon" → PM modifier (afternoon)
```

### A.4 Taglish Action Keywords

```
CALL: "tawagan", "tumawag", "tawagan si"
TEXT: "i-text", "mag-text", "mag-text kay"
EMAIL: "i-email", "mag-email"
OPEN: "buksan", "i-open", "tingnan"
```

---

## Appendix B: ReminderDraft → Reminder Mapping

```
ReminderDraft                    →  Reminder
─────────────────────────────────────────────────
title                           →  title
notes                           →  notes
intentType                      →  intent_type
confidence, originalTranscript  →  (not persisted; metadata for audit)
triggerTime, triggerTimezone    →  Trigger.scheduled_time, Trigger.timezone
actionType, target_value,       →  Action.action_type, Action.target_value,
contactName, contactPhone       →  Action.contact_name, Action.contact_phone
```

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| STT | Speech-to-Text |
| NLP | Natural Language Processing |
| ReminderDraft | Intermediate representation between NLP output and persisted Reminder |
| Trigger | Condition that causes a reminder to fire |
| Action | External operation associated with a reminder |
| Geofence | Virtual geographic boundary (Post-MVP) |
| Follow-up | Conditional reminder based on parent state (Post-MVP) |
| Confidence | 0.0–1.0 score of NLP interpretation certainty |
| Platform Bridge | Dart abstract interface implemented natively per platform |
| Drift | SQLite wrapper for Flutter (formerly Moor) |
| Taglish | Mixed Tagalog-English commonly spoken in the Philippines |
| Optimistic Locking | Concurrency control using version column; writers check version before committing |

---

*End of KATALA_SPEC_V2.md — Version 2.0.0*
