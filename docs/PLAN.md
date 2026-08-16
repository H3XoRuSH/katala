# katala-app-plan

Complete architecture and development plan for Katala, an offline, voice-driven, context-aware smart reminder app for iOS and Android.

---

## Instructions

# PLAN.md — Katala (Voice-Driven Contextual Reminder App)

## 1. Executive Summary & Vision

Katala is a fast, offline-first, voice-driven contextual reminder app inspired by the native Philippine Red-vented Cockatoo (Katala), known for its intelligence, clear voice, and distinct call.

Unlike traditional static alarm apps or cloud-heavy voice assistants, Katala converts natural speech into actionable, context-rich notification payloads completely on-device. It requires zero cloud APIs, zero user accounts, incurs zero server costs, and guarantees 100% data privacy.

---

## 2. Core Value Proposition & Key Differentiators

- **On-Device Speech & Parsing ($0 Cost, 100% Private):** Hooks into native OS speech engines (SFSpeechRecognizer / Google On-Device Speech) and runs local NLP without cloud LLMs.
- **Actionable Notification Payloads:** Extracts entities from natural speech (contacts, phone numbers, map coordinates) to attach 1-tap action buttons directly to native notification banners (e.g., [📞 Call Adam Now]).
- **Smart Conflict Detection & Stacking:** Detects schedule overlap instantly upon voice input ("You already have 2 tasks at 2:00 PM—set for 2:30 PM instead?").
- **Conditional Chaining & Follow-Ups:** Allows users to set child tasks directly from notification triggers ("If no reply by tomorrow, remind me again").
- **Geofencing & Location Triggers:** Supports local GPS boundary triggers using on-device location APIs without external server calls.

---

## 3. Recommended Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (for high-performance cross-platform iOS/Android development) or Native Swift (iOS-first) |
| **Local Storage** | SQLite via Isar / Drift (Flutter) or SwiftData / GRDB (iOS) |
| **Speech-to-Text** | `speech_to_text` package / Native OS speech recognition bridge |
| **On-Device NLP** | Rule-based regex tokenizers + Chrono date parser + native OS NLP (NaturalLanguage / Google ML Kit) |
| **Notifications** | `flutter_local_notifications` (Flutter) or UserNotifications framework (iOS) |
| **Geofencing** | `geolocator` + `flutter_background_service` / native location region monitoring |

---

## 4. System Architecture Pipeline

```
[ User Voice Input ]
        │
        ▼
[ On-Device Speech Recognition Engine ]
  (iOS: SFSpeechRecognizer | Android: Google On-Device STT)
        │
        ▼
[ Raw Text String ]
        │
        ▼
[ Local Intent & Entity Extraction Engine (Katala NLP) ]
  ├── Intent Classifier   ➔ (e.g., CREATE_REMINDER, SNOOZE, CHAIN_FOLLOWUP)
  ├── Date/Time Parser    ➔ Absolute, Relative ("in 10m", "next Monday"), or Geofence
  ├── Entity Extractor    ➔ Contact Matcher, Phone Numbers, Web URLs, Notes
  └── Conflict Detector   ➔ Checks local database for overlapping schedule windows
        │
        ▼
[ Local Database (SQLite / Isar) ]
        │
        ▼
[ OS Local Notification Scheduler ]
  └── Generates Actionable Banners (UNNotificationAction / PendingIntent)
```

---

## 5. Detailed Feature Specifications

### A. Voice Quick-Logging & Local NLP

- Parse relative times ("in 15 mins", "tomorrow at 8am", "end of day").
- Parse contact actions ("call [Name]", "text [Name]", "email [Name]").
- Parse fuzzy locations ("when I reach home", "when I get to office").

### B. Actionable Payloads

When a reminder triggers, the notification banner includes context-specific quick actions:

| Task Type | Actions |
|---|---|
| **Call Task** | [ Call Now ] \| [ Snooze 10m ] \| [ Mark Done ] |
| **URL / Link Task** | [ Open Link ] \| [ Mark Done ] |
| **Location Task** | [ Open Directions ] \| [ Mark Done ] |

### C. Follow-Up Chaining Logic

Long-pressing or tapping [ Follow-up ] on a completed or snoozed task opens a voice prompt: "Set follow-up rule".

> Example: "If he doesn't call back by 5 PM, remind me again".

---

## 6. Implementation Roadmap & Phases

### Phase 1: MVP Core (Voice Input & Local Parsing)

- [ ] Set up local project structure and local SQLite/Isar database schema.
- [ ] Implement on-device speech-to-text bridge.
- [ ] Build local date-time parser (handling relative phrases like "in X minutes/hours", "tomorrow at Y").
- [ ] Integrate local notification scheduler for basic time triggers.

### Phase 2: Entity Matching & Rich Notifications

- [ ] Implement contact matcher (locally match names in speech to phone numbers/contacts).
- [ ] Add interactive notification categories (UNNotificationAction for Call, Open Link, Snooze).
- [ ] Implement schedule overlap conflict checker prior to saving reminders.

### Phase 3: Geofencing & Advanced Context

- [ ] Integrate on-device region monitoring (geofences for home/office/saved spots).
- [ ] Implement conditional follow-up chaining UI and database relations.
- [ ] Polish Katala bird-inspired minimal audio feedback and custom notification sounds.

---

## 7. Data Models & Schemas

### Reminder Entity

```json
{
  "id": "UUID-STRING",
  "title": "Call Adam",
  "notes": "Discuss Wi-Fi setup",
  "intent_type": "CALL",
  "target_entity": "+639171234567",
  "trigger_type": "SCHEDULED_TIME",
  "trigger_time": "2026-08-10T14:00:00Z",
  "geofence_lat_lng": null,
  "parent_reminder_id": null,
  "status": "PENDING",
  "created_at": "2026-08-10T02:57:49Z"
}
```

> `intent_type`: `CALL` | `LINK` | `LOCATION` | `GENERAL`
> `trigger_type`: `SCHEDULED_TIME` | `GEOFENCE`
> `status`: `PENDING` | `COMPLETED` | `SNOOZED` | `DISMISSED`

---

## 8. UX & Design Principles

- **Bird Eye Vigilance:** Clean, dark-mode default dashboard showcasing an upcoming timeline view.
- **One-Tap Mic:** Instant audio listening state upon app open with animated haptic feedback.
- **Non-Intrusive Nudges:** Smooth, low-friction sound cues and subtle animations.