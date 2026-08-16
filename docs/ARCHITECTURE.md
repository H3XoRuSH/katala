# ARCHITECTURE.md — Katala Implementation Architecture

**Version:** 1.0.0
**Date:** 2026-08-10
**Status:** Implementation-Ready
**Derived from:** KATALA_SPEC_V3.md (authoritative WHAT), ARCHITECTURE_REVIEW.md (adversarial review)

---

> **Purpose:** This document defines HOW Katala will be implemented. It is the engineering contract for any developer or AI coding agent. KATALA_SPEC_V3.md is the source of truth for WHAT the application must do. Do not redesign the product. Do not expand the MVP. Do not invent new product behavior unless required to implement an existing specification requirement.

---

## Table of Contents

1. [Architectural Principles](#1-architectural-principles)
2. [System Architecture](#2-system-architecture)
3. [Project Directory Structure](#3-project-directory-structure)
4. [Dependency Direction](#4-dependency-direction)
5. [Application Layer](#5-application-layer)
6. [Domain Model](#6-domain-model)
7. [Database Architecture](#7-database-architecture)
8. [Concurrency Model](#8-concurrency-model)
9. [NLP Architecture](#9-nlp-architecture)
10. [NLP Test Architecture](#10-nlp-test-architecture)
11. [Speech Architecture](#11-speech-architecture)
12. [Notification Architecture](#12-notification-architecture)
13. [Notification Reconciliation](#13-notification-reconciliation)
14. [iOS Architecture](#14-ios-architecture)
15. [Android Architecture](#15-android-architecture)
16. [Flutter ↔ Native Bridge Contracts](#16-flutter--native-bridge-contracts)
17. [Background Execution](#17-background-execution)
18. [State Management](#18-state-management)
19. [Error Architecture](#19-error-architecture)
20. [Permission Architecture](#20-permission-architecture)
21. [Security / Privacy Architecture](#21-security--privacy-architecture)
22. [Dependency Architecture](#22-dependency-architecture)
23. [Test Architecture](#23-test-architecture)
24. [Build Architecture](#24-build-architecture)
25. [Observability](#25-observability)
26. [Implementation Order](#26-implementation-order)
27. [Architectural Risks](#27-architectural-risks)
28. [Architectural Decision Records](#28-architectural-decision-records)
29. [AI Coding-Agent Contract](#29-ai-coding-agent-contract)
30. [Final Architecture Validation](#30-final-architecture-validation)

---

## 1. Architectural Principles

These principles are **non-negotiable**. Every implementation decision must be consistent with them.

### 1.1 Database as Authoritative State

```
DATABASE = AUTHORITATIVE STATE
OS NOTIFICATION SCHEDULER = DERIVED STATE
```

The SQLite database is always correct. OS notifications are a best-effort reflection. Any discrepancy between database state and OS notification state is resolved in favor of the database. The notification scheduler is rebuilt from the database during reconciliation.

### 1.2 OS Notifications as Derived State

OS-level notifications (UNNotificationRequest on iOS, PendingIntent/AlarmManager on Android) are a cache. They can be cleared by the OS at any time (force-stop, reboot, OEM kill). The application does not rely on OS notification state for correctness.

### 1.3 Deterministic NLP

All NLP pipeline stages are deterministic functions. Same input string + same injectable Clock = same output. There is no ML inference, no ONNX, no TensorFlow Lite, no cloud NLP. See §9.

### 1.4 Platform Isolation

Business logic never references iOS or Android APIs directly. Platform-specific code is confined to bridge implementations behind Dart interfaces. The domain layer has zero platform imports.

### 1.5 Dependency Injection

- **Foreground (UI) path:** Riverpod for DI and state management.
- **Background path:** A static `BackgroundServiceLocator` (not Riverpod) for notification action callbacks, boot receivers, and reconciliation workers. See §17.

### 1.6 Testability

Every component is designed for isolated testing:
- Pure NLP functions: injectable Clock, no side effects.
- Repositories: interface abstracts Drift; in-memory SQLite for tests.
- Platform bridges: Dart interface with fake implementations for tests.
- Use cases: inject repositories and bridges as constructor parameters.

### 1.7 Offline Operation

All MVP features work with airplane mode enabled. No network requests are initiated by Katala code during normal operation. The only exceptions are user-initiated actions (opening a URL in browser, launching the dialer) and OS-level services outside Katala's control (push notification registration, map tiles in Post-MVP).

### 1.8 No Cloud Services

There is no Katala backend. No user accounts. No server costs. No analytics. No crash reporting. No cloud STT fallback.

### 1.9 Minimal Dependencies

Every dependency must justify its inclusion. Prefer implementing internally over adding a package for convenience. See §22.

### 1.10 Identical Business Behavior Across Platforms

The same domain logic, the same state machine transitions, the same validation rules, and the same NLP pipeline must produce identical results on iOS and Android. Platform differences are confined to: STT engine availability, notification scheduling mechanics, contact store access, and UI chrome.

### 1.11 Explicit Platform Differences

Where platforms genuinely differ (iOS 64-notification limit, Android force-stop behavior, Filipino STT availability), the difference is explicitly documented and communicated to the user. Katala never pretends platform capabilities are symmetric when they are not.

---

## 2. System Architecture

### 2.1 High-Level Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        FLUTTER UI LAYER                           │
│  Screens, Widgets, Navigation, Confirmation Cards, Clarification  │
│  Cards, Timeline, Settings, Onboarding                            │
│  Observes state via Riverpod ref.watch().                         │
│  Dispatches user actions to Application Layer use cases.          │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                             │
│  Use Cases (orchestration):                                       │
│  CreateReminderUseCase  HandleNotificationActionUseCase           │
│  SnoozeReminderUseCase  CompleteReminderUseCase                   │
│  DeleteReminderUseCase  EditReminderUseCase                       │
│  ReconcileNotificationsUseCase  ResolveContactsUseCase            │
│                                                                   │
│  Owns: transaction boundaries, cross-layer orchestration.         │
│  Does NOT own: NLP, raw SQL, platform-specific notification APIs. │
└────────┬───────────────────────────────────┬─────────────────────┘
         │                                   │
         ▼                                   ▼
┌──────────────────────┐        ┌──────────────────────────────────┐
│    DOMAIN LAYER       │        │       PLATFORM BRIDGES            │
│  NLP Pipeline (pure)  │        │  Dart interfaces:                 │
│  State Machine        │        │  SpeechBridge                     │
│  Conflict Detector    │        │  NotificationBridge               │
│  Entity Definitions   │        │  ContactBridge                    │
│  Validation Rules     │        │  ActionBridge                     │
│  Temporal Resolution  │        │                                   │
│  Temporal Resolution  │        │  Implementations:                 │
│                       │        │  iOS: Swift native                │
│  ZERO platform deps.  │        │  Android: Kotlin native           │
└───────────┬───────────┘        └──────────────┬───────────────────┘
            │                                   │
            ▼                                   ▼
┌──────────────────────┐        ┌──────────────────────────────────┐
│     DATA LAYER        │        │       NATIVE PLATFORM             │
│  ReminderRepository   │        │  iOS: SFSpeechRecognizer,         │
│  Drift DAOs           │        │    UNUserNotificationCenter,       │
│  SQLite (WAL mode)    │        │    CNContactStore,                │
│  Migrations           │        │    App Group container            │
│                       │        │  Android: SpeechRecognizer,       │
│  Does NOT call        │        │    AlarmManager, WorkManager,     │
│  Platform Bridges.    │        │    BroadcastReceiver,             │
│                       │        │    ContactsContract               │
└───────────────────────┘        └──────────────────────────────────┘
```

### 2.2 Layer Ownership

| Layer | Owns | Does NOT Own |
|-------|------|-------------|
| **UI** | Widgets, screens, navigation, confirmation/clarification card rendering, theme, animations | Business logic, persistence, notification scheduling, NLP |
| **Application** | Use cases, orchestration, transaction boundaries, calling bridges after persistence | NLP parsing, raw SQL, platform-specific notification APIs |
| **Domain** | NLP pipeline, state machine, conflict detection, validation, entity definitions, temporal resolution | Persistence, platform APIs, UI rendering |
| **Data** | Repositories, Drift DAOs, query building, optimistic locking SQL, migrations, integrity checks | Notification scheduling, contact resolution, NLP |
| **Platform Bridges** | Native STT, native notifications, native contacts, file paths, URL launching | Business logic, NLP, state machine, persistence |

---

## 3. Project Directory Structure

```
katala/
├── lib/
│   ├── main.dart                          # Entry point, ProviderScope, app widget
│   ├── app.dart                           # MaterialApp, theme, routing
│   │
│   ├── ui/                                # UI Layer
│   │   ├── screens/
│   │   │   ├── home_screen.dart           # Timeline (overdue, today, tomorrow, later)
│   │   │   ├── onboarding_screen.dart     # Permissions education
│   │   │   ├── settings_screen.dart       # Preferences, reliability status
│   │   │   └── reminder_detail_screen.dart # View/edit a single reminder
│   │   ├── widgets/
│   │   │   ├── mic_button.dart            # Voice input trigger
│   │   │   ├── voice_input_overlay.dart   # Listening animation, transcript streaming
│   │   │   ├── confirmation_card.dart     # Parsed reminder review before save
│   │   │   ├── clarification_card.dart    # Missing entity resolution
│   │   │   ├── conflict_warning.dart      # Schedule conflict display
│   │   │   ├── timeline_group.dart        # Grouped reminder list section
│   │   │   ├── reminder_tile.dart         # Single reminder row
│   │   │   ├── text_input_field.dart      # Manual text entry with live preview
│   │   │   └── reliability_banner.dart    # "Katala was inactive..." banner
│   │   └── theme/
│   │       ├── colors.dart                # Color tokens
│   │       └── typography.dart            # Inter font styles
│   │
│   ├── application/                       # Application Layer
│   │   └── use_cases/
│   │       ├── create_reminder_use_case.dart
│   │       ├── handle_notification_action_use_case.dart
│   │       ├── snooze_reminder_use_case.dart
│   │       ├── complete_reminder_use_case.dart
│   │       ├── delete_reminder_use_case.dart
│   │       ├── edit_reminder_use_case.dart
│   │       ├── reconcile_notifications_use_case.dart
│   │       └── resolve_contacts_use_case.dart
│   │
│   ├── domain/                            # Domain Layer
│   │   ├── entities/
│   │   │   ├── reminder.dart              # Reminder entity
│   │   │   ├── trigger.dart               # Trigger value object
│   │   │   ├── action.dart                # Action value object
│   │   │   └── contact_ref.dart           # Resolved contact reference
│   │   ├── enums/
│   │   │   ├── reminder_status.dart       # PENDING, COMPLETED, SNOOZED, DISMISSED
│   │   │   ├── intent_type.dart           # GENERAL, CALL, TEXT, EMAIL, OPEN_URL
│   │   │   ├── trigger_type.dart          # SCHEDULED_TIME, GEOFENCE
│   │   │   ├── action_type.dart           # CALL, TEXT, EMAIL, OPEN_URL, GENERAL
│   │   │   ├── delivery_status.dart       # scheduled, delivery_uncertain, delivery_missed
│   │   │   └── validation_issue.dart      # missingTitle, missingTime, ambiguousTime, etc.
│   │   ├── nlp/                           # NLP Pipeline (pure functions)
│   │   │   ├── pre_processor.dart         # Stage 1: normalize text
│   │   │   ├── intent_detector.dart       # Stage 2: classify intent
│   │   │   ├── entity_extractor.dart      # Stage 3: extract entities
│   │   │   ├── temporal_resolver.dart     # Stage 4: resolve times
│   │   │   ├── validator.dart             # Stage 5: validate completeness
│   │   │   ├── clock.dart                 # Injectable Clock interface
│   │   │   ├── stt_corrections.dart       # STT error correction dictionary
│   │   │   └── models/                    # NLP intermediate types
│   │   │       ├── raw_transcript.dart
│   │   │       ├── normalized_transcript.dart
│   │   │       ├── intent_classification.dart
│   │   │       ├── extracted_entities.dart
│   │   │       ├── temporal_expression.dart
│   │   │       ├── parsed_reminder.dart    # NLP output (contact names as strings)
│   │   │       └── validated_reminder.dart # Application output (resolved contacts)
│   │   ├── state_machine.dart             # Reminder state transitions with guards
│   │   └── conflict_detector.dart         # ±15 min conflict detection
│   │
│   ├── data/                              # Data Layer
│   │   ├── database/
│   │   │   ├── database.dart              # Drift database definition
│   │   │   ├── tables/
│   │   │   │   ├── reminder_table.dart    # Drift table definition
│   │   │   │   ├── trigger_table.dart
│   │   │   │   ├── action_table.dart
│   │   │   │   └── app_metadata_table.dart
│   │   │   └── migrations/
│   │   │       └── schema_versions.dart   # Drift schema migration callbacks
│   │   ├── repositories/
│   │   │   ├── reminder_repository.dart   # Interface
│   │   │   └── reminder_repository_impl.dart # Drift implementation
│   │   └── daos/
│   │       ├── reminder_dao.dart
│   │       ├── trigger_dao.dart
│   │       └── action_dao.dart
│   │
│   ├── platform/                          # Platform Bridge Layer (Dart side)
│   │   ├── bridges/
│   │   │   ├── speech_bridge.dart         # Dart interface
│   │   │   ├── notification_bridge.dart   # Dart interface
│   │   │   ├── contact_bridge.dart        # Dart interface
│   │   │   └── action_bridge.dart         # Dart interface
│   │   └── fakes/                         # Fake implementations for tests
│   │       ├── fake_speech_bridge.dart
│   │       ├── fake_notification_bridge.dart
│   │       └── fake_contact_bridge.dart
│   │
│   ├── services/                          # Application-scoped services
│   │   ├── background_service_locator.dart # Static DI for background contexts
│   │   └── database_path_provider.dart    # Platform-specific DB path resolution
│   │
│   └── shared/                            # Shared utilities
│       ├── result.dart                    # Result<T, E> type for error handling
│       └── logging.dart                   # Debug-only, redacted logging
│
├── ios/                                   # iOS Native
│   ├── Runner/                            # Main Flutter app target
│   │   ├── AppDelegate.swift
│   │   └── Info.plist
│   ├── KatalaNotificationExtension/       # Notification Service Extension target
│   │   ├── NotificationService.swift      # UNNotificationServiceExtension
│   │   ├── DB/
│   │   │   └── ExtensionDatabase.swift    # Lightweight SQLite access
│   │   └── Info.plist
│   ├── Bridges/                           # Platform bridge implementations
│   │   ├── SpeechBridgeImpl.swift         # SFSpeechRecognizer wrapper
│   │   ├── NotificationBridgeImpl.swift   # UNUserNotificationCenter wrapper
│   │   ├── ContactBridgeImpl.swift        # CNContactStore wrapper
│   │   └── ActionBridgeImpl.swift         # UIApplication openURL, etc.
│   ├── Katala.entitlements                # App Group entitlement
│   └── KatalaNotificationExtension.entitlements
│
├── android/                               # Android Native
│   ├── app/src/main/kotlin/com/katala/app/
│   │   ├── MainActivity.kt
│   │   ├── bridges/
│   │   │   ├── SpeechBridgeImpl.kt        # SpeechRecognizer wrapper
│   │   │   ├── NotificationBridgeImpl.kt  # AlarmManager wrapper
│   │   │   ├── ContactBridgeImpl.kt       # ContactsContract wrapper
│   │   │   └── ActionBridgeImpl.kt        # Intent launchers
│   │   ├── receivers/
│   │   │   └── BootReceiver.kt            # BOOT_COMPLETED handler
│   │   └── workers/
│   │       └── ReconciliationWorker.kt    # WorkManager periodic task
│   └── app/src/main/AndroidManifest.xml
│
├── test/                                  # Unit & Widget Tests
│   ├── forbidden_imports_test.dart        # Enforces layer dependency rules (§4.3)
│   ├── domain/
│   │   ├── nlp/
│   │   │   ├── pre_processor_test.dart
│   │   │   ├── intent_detector_test.dart
│   │   │   ├── entity_extractor_test.dart
│   │   │   ├── temporal_resolver_test.dart
│   │   │   └── validator_test.dart
│   │   ├── state_machine_test.dart
│   │   └── conflict_detector_test.dart
│   ├── application/
│   │   └── use_cases/
│   │       ├── create_reminder_use_case_test.dart
│   │       └── reconcile_notifications_use_case_test.dart
│   ├── data/
│   │   └── repositories/
│   │       └── reminder_repository_test.dart
│   └── ui/
│       └── widgets/
│           ├── confirmation_card_test.dart
│           └── timeline_group_test.dart
│
├── test_corpus/                           # NLP Test Corpus
│   ├── english/
│   │   ├── create_reminder_basic.txt      # One transcript per line
│   │   ├── create_reminder_with_time.txt
│   │   ├── create_reminder_with_contact.txt
│   │   └── create_reminder_with_url.txt
│   ├── taglish/
│   │   ├── create_reminder_taglish.txt
│   │   └── temporal_filipino.txt
│   └── stt_errors/                        # Simulated STT error transcripts
│       └── common_misrecognitions.txt
│
├── assets/
│   ├── fonts/
│   │   ├── Inter-Regular.ttf
│   │   ├── Inter-Medium.ttf
│   │   ├── Inter-SemiBold.ttf
│   │   └── Inter-Bold.ttf
│   └── sounds/
│       ├── chirp_save.caf                 # iOS format
│       └── chirp_save.ogg                 # Android format
│
├── pubspec.yaml
├── analysis_options.yaml
└── ARCHITECTURE.md                        # This document
```

### 3.1 Directory Responsibility

| Directory | Responsibility | Key Constraint |
|-----------|---------------|----------------|
| `lib/ui/` | Visual presentation only. Observes state. Dispatches to use cases. | Must NOT call repositories or platform bridges directly. |
| `lib/application/` | Orchestration. Each use case is a single class with `execute()` method. | The only layer that calls both repositories AND platform bridges. |
| `lib/domain/` | Pure business rules. NLP pipeline, state machine, validation, conflict detection. | ZERO imports from `ui/`, `data/`, `platform/bridges/`. Imports only `platform/fakes/` in tests. |
| `lib/data/` | Persistence. Repository implementations, Drift DAOs, queries. | Must NOT call Platform Bridges. Must NOT contain business logic. |
| `lib/platform/bridges/` | Dart interfaces for platform capabilities. | Interfaces only. Implementations live in `ios/Bridges/` and `android/.../bridges/`. |
| `lib/services/` | Application-scoped singletons. Background service locator. | Not a dumping ground. Only `BackgroundServiceLocator` and `DatabasePathProvider`. |
| `lib/shared/` | Generic utilities with zero domain knowledge. `Result` type, debug logging. | No business types. No imports from other lib directories. |

---

## 4. Dependency Direction

### 4.1 Allowed Dependencies

```
UI ─────────────────────────────► Application ──────► Platform Bridges (interfaces)
                                      │                         ▲
                                      │                         │
                                      ▼                         │
                                  Domain ◄──────────────────────┘
                                      ▲
                                      │
                                      ▼
                                  Data ◄──────────────────────────┘
```

### 4.2 Forbidden Dependencies

| Layer | Must NOT depend on |
|-------|--------------------|
| **Domain** | Flutter widgets, Drift, iOS APIs, Android APIs, `package:flutter/material.dart`, any platform channel code |
| **Data** | Platform bridges, notification scheduling, contact resolution, `package:flutter` (except for path_provider equivalent for DB path) |
| **Application** | Flutter widgets, `BuildContext`, raw iOS/Android APIs |
| **UI** | (May depend on Application for use cases and Domain for types, but not Data or Platform Bridges directly) |

### 4.3 Compile-Time Enforcement

- Domain layer: verified by `import` analysis — no `dart:ui`, `package:flutter`, `package:drift`, or platform channel imports.
- Data layer: verified by `import` analysis — no `SpeechBridge`, `NotificationBridge`, `ContactBridge`, or `ActionBridge` imports.
- CI check: a `forbidden_imports_test.dart` that uses `dart:mirrors` or a custom lint to verify layer boundaries.

---

## 5. Application Layer

### 5.1 Use Cases (MVP Only)

Every use case is a single-responsibility class with:
- Constructor injection of dependencies
- A single public `execute()` method
- Typed input (either positional parameters or a small input DTO)
- Typed output (either a value or a `Result<T, E>`)

| Use Case | Input | Output | Dependencies | Transaction Boundary | Side Effects | Idempotency |
|----------|-------|--------|-------------|---------------------|-------------|-------------|
| `CreateReminderUseCase` | `ParsedReminder` | `Result<Reminder, CreateError>` | `ReminderRepository`, `NotificationBridge`, `ContactBridge`, `ConflictDetector` | DB transaction for insert; scheduling outside transaction | Notification scheduled via OS | Double-tap prevented by UI debounce (button disabled after first tap). DB has no duplicate-creation guard beyond UUID PK. |
| `CompleteReminderUseCase` | `String reminderId` | `Result<void, TransitionError>` | `ReminderRepository`, `NotificationBridge` | Optimistic lock UPDATE | Notification cancelled via OS | Idempotent: if already COMPLETED, returns success (no-op). |
| `SnoozeReminderUseCase` | `String reminderId, int durationMinutes` | `Result<void, TransitionError>` | `ReminderRepository`, `NotificationBridge` | Optimistic lock UPDATE | New notification scheduled for now + duration | Guard: `snooze_count < 10`. Fails if exceeded. |
| `DeleteReminderUseCase` | `String reminderId, int expectedVersion` | `Result<void, TransitionError>` | `ReminderRepository`, `NotificationBridge` | Optimistic lock UPDATE (soft delete) | Notification cancelled via OS | Idempotent: if already deleted, returns success. |
| `EditReminderUseCase` | `String reminderId, EditedFields` | `Result<Reminder, EditError>` | `ReminderRepository`, `NotificationBridge` | Optimistic lock UPDATE | Old notification cancelled, new one scheduled | Fails if version mismatch. |
| `HandleNotificationActionUseCase` | `String actionId, String reminderId` | `Result<void, ActionError>` | `ReminderRepository`, `NotificationBridge`, `ActionBridge` | Optimistic lock UPDATE (delegates to Complete/Snooze) | Dismisses notification; may launch dialer/browser | Idempotent via optimistic lock retry. |
| `ReconcileNotificationsUseCase` | (none) | `ReconciliationResult` | `ReminderRepository`, `NotificationBridge` | Multiple UPDATEs outside a single transaction | Cancels orphans, schedules missing, detects missed | Fully idempotent. |
| `ResolveContactsUseCase` | `String contactName` | `Result<List<ContactRef>, ContactError>` | `ContactBridge` | None (read-only) | None | Deterministic for a given contacts DB state. |

### 5.2 CreateReminderUseCase — Full Specification

```
CreateReminderUseCase.execute(parsedReminder, clock):
  1. VALIDATE (Domain layer):
     - Check parsedReminder.issues.isEmpty
     - If issues exist → return ValidationFailed(issues)
       (UI shows clarification card)

  2. RESOLVE CONTACTS (Application → Platform):
     - If parsedReminder.contactName != null:
       - matches = contactBridge.resolve(parsedReminder.contactName)
       - If matches.length > 1 → return ContactDisambiguationRequired(matches)
       - If matches.length == 1 → attach to validatedReminder
       - If matches.isEmpty → store name only, no phone number

  3. VALIDATE URL (Domain layer):
     - If parsedReminder.url != null:
       - Validate http/https scheme, length ≤ 2048
       - If invalid → strip URL, add issue to result

  4. CHECK CONFLICTS (Domain layer):
     - conflicts = conflictDetector.detect(parsedReminder.scheduledTime, repository)
     - If conflicts.isNotEmpty → return ConflictDetected(conflicts, suggestedTime)
       (UI shows conflict warning card; user may accept suggestion or save anyway)

  5. PERSIST (Data layer):
     - reminder = await reminderRepository.insert(validatedReminder)
     - This is ONE transaction: INSERT reminder + INSERT trigger + INSERT action
     - On failure → return PersistenceFailed (UI shows error + retry)

  6. SCHEDULE NOTIFICATION (Application → Platform):
     - TRY notificationBridge.schedule(reminder)
     - On success: UPDATE trigger.notification_scheduled = true, trigger.notification_id = id
     - On failure: trigger.notification_scheduled stays false
       (next reconciliation will schedule it)

  7. RETURN:
     - Full success: reminder persisted + notification scheduled
     - Partial success: reminder persisted, notification scheduling failed
       (user sees "Reminder saved. Notification will fire soon.")
     - Failure: nothing persisted (user sees error + retry)
```

### 5.3 Critical Rule

**The UI must NOT directly orchestrate domain + repository + notification operations.** The only path to create a reminder is through `CreateReminderUseCase.execute()`. Button callbacks call the use case; the use case calls the repository and bridges.

---

## 6. Domain Model

### 6.1 Entity vs. DTO Distinction

| Classification | Types | Description |
|---------------|-------|-------------|
| **Persisted Entities** | `Reminder`, `Trigger`, `Action` | Stored in SQLite via Drift. Have `id`, `version`, timestamps. |
| **Temporary Domain Objects** | `ParsedReminder`, `ValidatedReminder`, `ExtractedEntities`, `IntentClassification` | Created during NLP pipeline or use case orchestration. Never persisted directly. |
| **Platform DTOs** | `SpeechResult`, `ContactEntry`, `ReconciliationResult` | Passed across the platform bridge boundary. Simple data carriers. |

### 6.2 Core Entities

#### Reminder

```dart
class Reminder {
  final String id;              // UUID v4
  final String title;
  final String? notes;
  final IntentType intentType;  // GENERAL, CALL, TEXT, EMAIL, OPEN_URL
  final ReminderStatus status;  // PENDING, COMPLETED, SNOOZED, DISMISSED
  final int snoozeCount;
  final int snoozeDurationMinutes;
  final String? parentReminderId; // Post-MVP
  final int depth;              // Post-MVP
  final int version;            // Optimistic locking
  final String? originalTranscript;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final Trigger trigger;
  final Action action;
}
```

#### Trigger

```dart
class Trigger {
  final String id;
  final String reminderId;
  final TriggerType triggerType;       // SCHEDULED_TIME (MVP), GEOFENCE (Post-MVP)
  final DateTime scheduledTimeUtc;
  final String scheduledTimeTimezone;  // e.g., "Asia/Manila"
  final bool notificationScheduled;
  final int? notificationId;
  final DateTime? firedAt;
  final DeliveryStatus deliveryStatus; // scheduled, delivery_uncertain, delivery_missed
}
```

#### Action

```dart
class Action {
  final String id;
  final String reminderId;
  final ActionType actionType;
  final String? targetValue;   // Phone number, URL, email
  final String? contactName;   // Display name (always stored)
  final String? contactPhone;
  final String? contactId;     // Platform contact identifier
}
```

#### ContactRef (Domain)

```dart
class ContactRef {
  final String displayName;
  final String? phoneNumber;
  final String? contactId;     // Platform identifier
}
```

#### Conflict (Domain)

```dart
class Conflict {
  final Reminder conflictingReminder;
  final Duration proximity;    // Time difference from new reminder
}
```

### 6.3 Enums

```dart
enum ReminderStatus { pending, completed, snoozed, dismissed }
enum IntentType { general, call, text, email, openUrl }
enum TriggerType { scheduledTime, geofence }
enum ActionType { call, text, email, openUrl, general }
enum DeliveryStatus { scheduled, deliveryUncertain, deliveryMissed }
enum ValidationIssue { missingTitle, missingTime, ambiguousTime, ambiguousContact, unresolvedContact, invalidUrl, timeInPast }
```

### 6.4 NLP Intermediate Types

```dart
class RawTranscript { final String text; }
class NormalizedTranscript { final String text; }
class IntentClassification { final IntentType intent; }
class ExtractedEntities {
  final String? title;
  final String? contactName;        // String, NOT ContactRef
  final String? url;
  final String? phoneNumber;        // Raw from transcript
  final String? notes;
  final List<TemporalExpression> temporalExpressions;
}
class ParsedReminder {
  final String title;
  final String? contactName;        // Still a string — to be resolved
  final String? url;
  final String? phoneNumber;
  final String? notes;
  final DateTime? scheduledTime;    // null if no time specified
  final String? timezone;
  final IntentType intentType;
  final List<ValidationIssue> issues;
}
class ValidatedReminder {
  final String title;
  final ContactRef? resolvedContact;
  final Uri? validatedUrl;
  final String? phoneNumber;
  final String? notes;
  final DateTime scheduledTime;
  final String timezone;
  final IntentType intentType;
}
```

### 6.5 State Machine

```
PENDING ──[Done]──► COMPLETED
PENDING ──[Snooze]──► SNOOZED (guard: snooze_count < 10)
PENDING ──[Dismiss]──► DISMISSED
SNOOZED ──[Timer expires]──► PENDING
SNOOZED ──[Snooze]──► SNOOZED (guard: snooze_count < 10)
SNOOZED ──[Done]──► COMPLETED
SNOOZED ──[Dismiss]──► DISMISSED
DISMISSED ──► (terminal)
COMPLETED ──► (terminal)
```

Every state transition uses optimistic locking:

```sql
UPDATE reminder
SET status = :newStatus,
    version = version + 1,
    updated_at = :now
    [, completed_at = :now]  -- if COMPLETED
WHERE id = :id AND version = :expectedVersion
```

If `rows affected = 0`: another process modified this reminder concurrently. Re-read and retry once. If retry also fails, log and surface a conflict to the user on next app open.

---

## 7. Database Architecture

### 7.1 Technology

**Drift** (formerly moor) for type-safe SQLite access in the main Flutter app.

**Lightweight raw SQLite** for the iOS Notification Service Extension (not Drift — see §14.4). The extension only needs: open DB, run one UPDATE, close DB. Drift's full generated code and reactive streams are unnecessary overhead in the extension binary.

### 7.2 Schema

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

CREATE TABLE trigger_ (
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

CREATE TABLE action_ (
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
CREATE INDEX idx_trigger_scheduled_time ON trigger_(scheduled_time_utc);
CREATE INDEX idx_trigger_notification_scheduled ON trigger_(notification_scheduled);
CREATE INDEX idx_trigger_delivery_status ON trigger_(delivery_status);
```

> Note: Table names `trigger_` and `action_` with trailing underscore because `trigger` and `action` may be reserved words in some SQLite contexts/Drift.

### 7.3 PRAGMA Configuration

```sql
PRAGMA journal_mode=WAL;          -- Required for cross-process access on iOS
PRAGMA foreign_keys=ON;
PRAGMA busy_timeout=3000;         -- 3 seconds
```

WAL mode is critical: it allows the main app and iOS notification extension to read concurrently without blocking each other.

### 7.4 Indexes

| Index | Purpose |
|-------|---------|
| `idx_reminder_status` (partial, where is_deleted=0) | Timeline queries, pending count |
| `idx_reminder_parent` | Follow-up chain queries (Post-MVP) |
| `idx_trigger_scheduled_time` | Conflict detection (±15 min range), reconciliation sorting |
| `idx_trigger_notification_scheduled` | Find reminders needing scheduling |
| `idx_trigger_delivery_status` | Missed-notification queries |

### 7.5 Repository Pattern

```dart
abstract class ReminderRepository {
  Future<Reminder> insert(ValidatedReminder reminder);          // One transaction: reminder + trigger + action
  Future<void> update(Reminder reminder);                       // Optimistic lock
  Future<Reminder?> getById(String id);
  Future<List<Reminder>> getPending({DateTime? before});        // PENDING/SNOOZED, not deleted, ordered by time
  Future<List<Reminder>> getOverdue();                          // PENDING/SNOOZED where scheduled_time < now
  Future<int> transitionState(String id, int expectedVersion, ReminderStatus newStatus);
  Future<void> softDelete(String id, int expectedVersion);      // Optimistic lock
  Future<void> updateTriggerScheduling(String reminderId, bool scheduled, int? notificationId);
  Future<void> updateTriggerDeliveryStatus(String reminderId, DeliveryStatus status);
  Future<void> updateTriggerFiredAt(String reminderId, DateTime firedAt);
  Future<String?> getMetadata(String key);
  Future<void> setMetadata(String key, String value);
  Future<List<Reminder>> getConflicting(DateTime scheduledTime, {int windowMinutes = 15});
  Future<List<Reminder>> getPendingSortedByTime({int? limit});  // For reconciliation
  Future<List<Reminder>> getByNotificationId(int notificationId);
}
```

### 7.6 Transaction Ownership

**The repository owns database transactions.** Each repository method that modifies multiple tables wraps them in a single transaction:

```dart
Future<Reminder> insert(ValidatedReminder v) async {
  return db.transaction(() async {
    final reminderId = uuid.v4();
    await db.into(db.reminder).insert(ReminderCompanion(/* ... */));
    await db.into(db.trigger).insert(TriggerCompanion(/* ... */));
    await db.into(db.action).insert(ActionCompanion(/* ... */));
    return /* constructed Reminder */;
  });
}
```

The Application layer does NOT manage transactions. It calls repository methods, and each method manages its own transaction boundary.

### 7.7 Optimistic Locking

Every UPDATE to `reminder` includes `WHERE version = :expectedVersion`. The repository's `transitionState()` returns the number of rows affected (0 or 1). The caller (Application layer) handles the retry:

```dart
int affected = await repository.transitionState(id, expectedVersion, newStatus);
if (affected == 0) {
  // Another process modified this reminder. Re-read and retry once.
  final current = await repository.getById(id);
  if (current == null || !canTransition(current.status, newStatus)) {
    return; // Abort silently — the other process already achieved the desired outcome
  }
  affected = await repository.transitionState(id, current.version, newStatus);
}
```

### 7.8 Soft Deletion

- Set `is_deleted = 1`, `deleted_at = now()`. Use optimistic locking.
- All queries filter `WHERE is_deleted = 0` by default.
- Hard delete runs during reconciliation: `DELETE FROM reminder WHERE is_deleted = 1 AND deleted_at < datetime('now', '-30 days')`.

### 7.9 Startup Integrity Check

On every app launch:
1. Run `PRAGMA integrity_check;`
2. If result != "ok": show error screen with "Restore from backup" and "Reset database" options.
3. Run `PRAGMA quick_check;` if integrity_check passes (faster for routine starts).

### 7.10 Migrations

- Drift schema versioning: each schema change increments the version number.
- Migration callbacks handle schema changes between consecutive versions.
- Tests must verify migrations from v1 → current version.
- The iOS extension's lightweight SQLite layer maintains its own simple migration tracking (a `schema_version` key in `app_metadata`).

---

## 8. Concurrency Model

### 8.1 Concurrent Access Scenarios

| Scenario | Processes Involved | Handling |
|----------|-------------------|----------|
| UI thread + notification action (main app backgrounded) | 1 process, 2 isolates/threads | SQLite serializes writes. Optimistic locking resolves logical conflicts. |
| iOS: Main app + notification extension | 2 processes, shared WAL-mode SQLite | WAL allows concurrent reads. SQLite serializes writes internally. `busy_timeout=3000` handles SQLITE_BUSY. Optimistic locking resolves logical conflicts. |
| Android: App + BroadcastReceiver | 1 process, possibly different threads | Serialized by SQLite. Optimistic locking for logical conflicts. |
| Double notification action tap | Same action processed twice | Optimistic locking: second attempt reads stale version, retry detects state already changed, aborts silently. |
| Simultaneous edit + notification action | Different reminders | No conflict — different rows. |
| Simultaneous edit + notification action on SAME reminder | 2 writers, same row | Optimistic locking: one wins, other retries and reads new state. |

### 8.2 Optimistic Locking Retry Behavior

```
function transitionState(reminderId, expectedVersion, newStatus):
  affected = db.update(reminderId, newStatus, expectedVersion)
  if affected == 1:
    return success
  else:
    // Re-read current state
    current = db.getById(reminderId)
    
    // Check if transition is still valid
    if current.status == newStatus:
      return success  // Other process already did it — desired outcome achieved
    
    if !stateMachine.canTransition(current.status, newStatus):
      return abortSilently  // Transition no longer valid, e.g., was SNOOZED now PENDING
    
    // Retry once with new version
    affected = db.update(reminderId, newStatus, current.version)
    if affected == 1:
      return success
    else:
      return giveUp  // Log for manual reconciliation on next foreground
```

### 8.3 Transaction Boundaries

- **Short-lived transactions:** Each transaction spans a single reminder's worth of writes (reminder + trigger + action for insert; single UPDATE for state transitions).
- **No cross-reminder transactions.** Editing reminder A and completing reminder B are separate transactions.
- **Notification scheduling is OUTSIDE the database transaction.** The pattern is: (1) DB transaction, (2) if success → schedule notification. If scheduling fails, the reminder is already persisted; reconciliation will schedule it.

### 8.4 Serialization of Reconciliation

Reconciliation uses a simple in-process lock (a Dart `Completer` or `Mutex`) to prevent concurrent reconciliation runs. If reconciliation is already running when a new request comes (e.g., from a notification action), the second request waits or is skipped (a "reconciliation needed" flag is set and checked on next foreground).

---

## 9. NLP Architecture

### 9.1 Design Principles

- **Deterministic:** Rule-based regex + temporal resolution. No ML inference.
- **Pure:** NLP stages are pure functions. No side effects. No platform dependencies. No contact database access.
- **Testable:** Each stage independently testable with known inputs and expected outputs.
- **Pipeline:** Sequential stages operating on typed intermediate representations.

### 9.2 NLP Data Boundary

NLP parsing is pure. Contact resolution is platform-dependent. The NLP pipeline outputs a `ParsedReminder` that contains **contact names as strings**, not resolved contacts. The Application layer resolves those names via `ContactBridge` to produce a `ValidatedReminder`.

```
User Transcript
       │
       ▼  (Pure NLP — no platform dependencies)
┌──────────────────────────────┐
│ Stage 1: Pre-Processor       │ → NormalizedTranscript
│ Stage 2: Intent Detector     │ → IntentClassification
│ Stage 3: Entity Extractor    │ → ExtractedEntities (contact_name: String, not Contact object)
│ Stage 4: Temporal Resolver   │ → ResolvedDateTime
│ Stage 5: Validator           │ → ValidationResult (list of ValidationIssue)
└──────────────────────────────┘
       │
       ▼  ParsedReminder (contact names as strings; no phone numbers)
       │
       ▼  (Application layer — platform-dependent)
┌──────────────────────────────┐
│ ContactBridge.resolve(name)  │ → List<ContactRef>
│ URL validation               │ → Validated URL
└──────────────────────────────┘
       │
       ▼  ValidatedReminder (ready for persistence)
```

### 9.3 Pipeline Stages

#### Stage 1: Pre-Processor

```dart
abstract class PreProcessor {
  NormalizedTranscript process(RawTranscript input);
}
```

- Lowercase.
- Collapse multiple whitespace to single space.
- Normalize quotes (curly → straight).
- Strip "um"/"uh" only when adjacent to silence markers (post-STT).
- Apply STT error correction dictionary (see §9.7).
- Do NOT strip content words.

#### Stage 2: Intent Detector

```dart
abstract class IntentDetector {
  IntentClassification detect(NormalizedTranscript input);
}
```

- Match regex patterns for CREATE_REMINDER (the only MVP intent).
- English: `remind me`, `set a reminder`, `add reminder`, `reminder to`, `don't forget`, `i need to`, `remember to`.
- Taglish: `pa-remind`, `remind mo ko`, `remind mo ako`, `mag-remind`, `ipaalala mo`, `paremind`, `paalala`, `remind mo naman`.
- If no pattern matches → UNKNOWN intent (UI shows: "I didn't understand that. Try: 'Remind me to...'").

#### Stage 3: Entity Extractor

```dart
abstract class EntityExtractor {
  ExtractedEntities extract(NormalizedTranscript input);
}
```

Extraction order (critical for correctness):
1. **URL** — `https?://[^\s]+`
2. **TEMPORAL** — see §9.4
3. **ACTION** — `call`, `tawagan`, `tumawag`, `text`, `message`, `sms`, `i-text`, `itext`, `email`, `i-email`
4. **CONTACT NAME** — anchored by action verbs: `call [Name]`, `text [Name]`, `tawagan si [Name]`, `i-text si [Name]`
5. **PHONE NUMBER** — `\+?[0-9]{7,15}`
6. **NOTES** — everything remaining after the above extractions plus title extraction

#### Stage 4: Temporal Resolver

```dart
abstract class TemporalResolver {
  ResolvedDateTime resolve(List<TemporalExpression> expressions, Clock clock);
}
```

- Injects `Clock` interface for determinism.
- Resolves: absolute datetime, relative minutes/hours, named times (noon, midnight), day+time, next weekday, bare time, "later", Filipino equivalents (mamaya, bukas, ngayon).
- Bare numbers 1-12 without AM/PM: returns `ambiguous` flag → UI shows AM/PM toggle.
- If time is in the past for "today" patterns: auto-advances to tomorrow.
- "Later": now + 2 hours; cap: if result > 10 PM or < 7 AM → move to 8 AM next day.
- No time specified: returns null scheduledTime → UI requires user to pick.

#### Stage 5: Validator

```dart
abstract class Validator {
  List<ValidationIssue> validate(ParsedReminder parsed);
}
```

- Produces explicit `ValidationIssue` enum values (not a generic confidence score).
- The UI maps issues to specific clarification cards.

### 9.4 Temporal Expression Resolution

| Type | Example | Resolution |
|------|---------|-----------|
| Absolute datetime | "January 15 at 3 PM" | Exact |
| Relative minutes | "in 15 minutes" | now + 15 min |
| Relative hours | "in 2 hours" | now + 2 hrs |
| Named time | "noon", "midnight" | 12:00 PM, 12:00 AM |
| Day + time | "tomorrow at 5 PM" | Next day, 5:00 PM |
| Day without time | "on Friday" | No default — UI clarification |
| Next weekday | "next Monday" | Upcoming Monday |
| Bare time | "at 3 PM" | Today at 3 PM (or tomorrow if past) |
| "Later" | "later" | now + 2 hours (capped) |
| Filipino relative | "mamaya" | now + 2 hours |
| Filipino day | "bukas" | Tomorrow |
| Filipino day | "ngayon" | Today |

### 9.5 Clock Interface

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
  final DateTime fixedNow;
  final String timezone;
  FakeClock(this.fixedNow, {this.timezone = 'UTC'});
  @override DateTime now() => fixedNow;
  @override String localTimezone() => timezone;
}
```

### 9.6 Validation Issues → UX Mapping

| Issue | UX Behavior |
|-------|------------|
| `missingTitle` | Clarification card: "What's the reminder about?" |
| `missingTime` | Clarification card with time picker + quick-pick chips [9:00 AM] [12:00 PM] [5:00 PM] |
| `ambiguousTime` | AM/PM toggle on confirmation card |
| `ambiguousContact` | Disambiguation sheet with matching contacts |
| `unresolvedContact` | "(no phone number found)" next to contact name; allow manual pick |
| `invalidUrl` | Strip URL; show warning |
| `timeInPast` | Show warning; allow save anyway or pick new time |

### 9.7 STT Error Correction Dictionary

A data structure (not hardcoded conditionals) mapping common STT misrecognitions → corrections:

```dart
const sttCorrections = {
  'rewind me': 'remind me',
  'remain me': 'remind me',
  'remainder': 'reminder',
  'to morrow': 'tomorrow',
  'to day': 'today',
  'at the': 'at three',
  'for pm': '4 PM',
  // These are placeholders — must be expanded during empirical testing
  // with Filipino-accented English and Taglish speakers.
};
```

Applied in Pre-Processor stage. Exact string matching (case-insensitive after normalization). This table is English-only for MVP. Taglish-specific corrections must be added during Phase 4 testing.

---

## 10. NLP Test Architecture

### 10.1 Test Corpus Structure

Tests operate on transcripts without requiring real speech.

```
test_corpus/
├── english/
│   ├── create_reminder_basic.txt
│   ├── create_reminder_with_time.txt
│   ├── create_reminder_with_contact.txt
│   ├── create_reminder_with_url.txt
│   └── ambiguous_times.txt
├── taglish/
│   ├── create_reminder_taglish.txt
│   └── temporal_filipino.txt
└── stt_errors/
    └── common_misrecognitions.txt
```

Each file contains one transcript per line:
```
Remind me to buy groceries
Call Adam tomorrow at 2 PM
Check report at https://example.com at 8 PM
```

### 10.2 Test Harness

```dart
void testNlpCorpus(String corpusPath, IntentType expectedIntent, {
  bool hasTime = true,
  bool hasContact = false,
  bool hasUrl = false,
}) {
  final lines = File(corpusPath).readAsLinesSync();
  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    
    final raw = RawTranscript(line);
    final normalized = PreProcessor().process(raw);
    final intent = IntentDetector().detect(normalized);
    
    expect(intent.intent, equals(expectedIntent));
    
    final entities = EntityExtractor().extract(normalized);
    if (hasTime) expect(entities.temporalExpressions, isNotEmpty);
    if (hasContact) expect(entities.contactName, isNotNull);
    if (hasUrl) expect(entities.url, isNotNull);
  }
}
```

### 10.3 Test Categories

| Category | What It Tests | How |
|----------|--------------|-----|
| **English** | Full intent + entity + temporal for en-US | Corpus files of ~50 transcripts |
| **Taglish** | Intent patterns + temporal keywords + contact extraction | Corpus files of ~30 transcripts |
| **Filipino temporal** | "mamaya", "bukas", "ngayon", "sa susunod na linggo" | Dedicated temporal resolver tests |
| **STT errors** | Pre-processor corrections for common misrecognitions | Input: misrecognized text; Output: corrected text |
| **Ambiguous times** | AM/PM ambiguity flag for bare numbers 1-12 | Assert `ambiguousTime` issue is set |
| **Missing fields** | Validation issues for incomplete transcripts | Assert correct `ValidationIssue` for each missing entity |
| **Conflicts** | ±15 min conflict detection against seeded DB | In-memory SQLite with pre-seeded reminders |
| **Invalid input** | Garbage text → UNKNOWN intent or graceful degradation | Random strings, empty string, very long string |

### 10.4 Clock Injection in Tests

All temporal resolver tests use `FakeClock`:

```dart
test('"tomorrow at 5 PM" at 2026-08-10 2:00 PM UTC', () {
  final clock = FakeClock(DateTime.utc(2026, 8, 10, 14, 0));
  final resolver = TemporalResolver(clock: clock);
  final result = resolver.resolve(/* parsed temporal expression */);
  expect(result.scheduledTime, equals(DateTime.utc(2026, 8, 11, 17, 0)));
});
```

### 10.5 DST Boundary Tests

```dart
test('spring-forward: "in 2 hours" at 1:30 AM EST', () {
  // 2026-03-08 01:30 AM EST → 2 hours later is 03:30 AM EDT (not 03:30 EST which doesn't exist)
  final clock = FakeClock(DateTime.utc(2026, 3, 8, 6, 30)); // 1:30 AM EST = 6:30 UTC
  // ... resolve and verify
});
```

---

## 11. Speech Architecture

### 11.1 Design Decision

**Custom native STT bridge is mandatory.** The `speech_to_text` Flutter package (v6.x) does NOT expose:
- `requiresOnDeviceRecognition` on iOS
- `EXTRA_PREFER_OFFLINE` on Android
- On-device model availability checks

Using it would violate CC-6 (No cloud STT). Katala MUST implement its own native bridge for speech recognition.

### 11.2 Dart Interface

```dart
enum SpeechAvailability { available, unavailable, permissionDenied, notSupported }

class SpeechResult {
  final String text;
  final bool isFinal;
}

abstract class SpeechBridge {
  /// Check if on-device STT is available for the current locale.
  Future<SpeechAvailability> get availability;

  /// Start listening. Returns a stream of partial/final results.
  /// [silenceTimeout] seconds of silence auto-stops the session (default 2.0).
  /// The bridge internally enforces a 30-second max session.
  Stream<SpeechResult> startListening({Duration silenceTimeout = const Duration(seconds: 2)});

  /// Stop listening gracefully. The stream emits a final result and closes.
  Future<void> stopListening();

  /// Cancel listening immediately. The stream closes without emitting final result.
  Future<void> cancelListening();
}
```

### 11.3 iOS Implementation

**Technology:** `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`

```swift
class SpeechBridgeImpl: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        speechRecognizer.requiresOnDeviceRecognition = true  // CRITICAL: enforces on-device
    }

    func checkAvailability() -> SpeechAvailability {
        guard speechRecognizer.isAvailable else { return .unavailable }
        guard speechRecognizer.supportsOnDeviceRecognition else { return .notSupported }
        // Check permission status...
        return .available
    }

    // startListening, stopListening, cancelListening...
    // Handles audio interruptions via AVAudioSession.interruptionNotification
}
```

- **Permissions:** `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` in Info.plist.
- **Audio session:** Uses `AVAudioSession` with `.playAndRecord` category.
- **Lifecycle interruption:** On phone call arrival, the audio session is deactivated. The bridge emits `AudioInterruptedError`. Partial transcript (if any) is emitted as a final result.
- **No cloud fallback:** If `supportsOnDeviceRecognition` returns `false`, the bridge returns `SpeechAvailability.notSupported`. Voice input is disabled; text fallback is available.

### 11.4 Android Implementation

**Technology:** `SpeechRecognizer` with `EXTRA_PREFER_OFFLINE = true`

```kotlin
class SpeechBridgeImpl(private val context: Context) {
    private val speechRecognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
    // Note: createOnDeviceSpeechRecognizer requires Android 13+.
    // On Android 10-12, use SpeechRecognizer.createSpeechRecognizer(context)
    // with EXTRA_PREFER_OFFLINE. See §11.5 for version-specific behavior.

    fun checkAvailability(): SpeechAvailability {
        // Android 13+: check on-device model availability
        // Android 10-12: return best-effort available
    }

    // startListening, stopListening, cancelListening...
    // Handles audio focus via AudioManager.OnAudioFocusChangeListener
}
```

- **Permissions:** `RECORD_AUDIO` in AndroidManifest.xml.
- **Intent:** Uses `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` with `EXTRA_PREFER_OFFLINE = true`.
- **Audio focus:** Requests `AudioManager.AUDIOFOCUS_GAIN_TRANSIENT`. Releases on stop.

### 11.5 Android Version-Specific STT Privacy

| Android Version | Behavior |
|----------------|---------|
| **13+** | Use `SpeechRecognizer.createOnDeviceSpeechRecognizer()`. Check for model availability. If unavailable, disable voice input. |
| **10-12** | Use `SpeechRecognizer.createSpeechRecognizer()` with `EXTRA_PREFER_OFFLINE`. Cannot technically enforce on-device-only. Onboarding shows a notice: "On this Android version, Katala requests on-device speech recognition but cannot guarantee it." |

### 11.6 Behavior When STT Is Unavailable

- Mic button shows in disabled state with tooltip/explanation.
- Text input path is highlighted as the primary input method.
- In onboarding, the disabled mic is explained: "Voice input requires an on-device speech model. Your device doesn't have one available."

---

## 12. Notification Architecture

### 12.1 Design Principle

```
DATABASE IS AUTHORITATIVE → NOTIFICATION SCHEDULER IS DERIVED
```

### 12.2 Dart Interface

```dart
class ReconciliationResult {
  final List<String> scheduledIds;    // Reminder IDs newly scheduled
  final List<String> failedIds;       // Reminder IDs that failed to schedule
  final List<int> cancelledIds;       // Orphaned notification IDs cancelled
  final List<String> errors;
}

abstract class NotificationBridge {
  /// Schedule a notification for a reminder.
  /// Idempotent: cancels any existing notification for this reminder first.
  /// Returns the platform notification ID.
  Future<int> schedule(Reminder reminder);

  /// Cancel a notification by platform notification ID.
  Future<void> cancel(int notificationId);

  /// Cancel the notification for a specific reminder.
  Future<void> cancelForReminder(String reminderId);

  /// Get all currently scheduled notification IDs (best-effort).
  Future<List<int>> getScheduledIds();

  /// Reconcile: cancel orphans, schedule missing.
  /// [toSchedule] = reminders that SHOULD have notifications.
  /// [knownIds] = all notification IDs currently tracked.
  Future<ReconciliationResult> reconcile({
    required List<Reminder> toSchedule,
    required List<int> knownIds,
  });

  /// Register notification categories. Called once at app init.
  Future<void> configureCategories();

  /// Get the maximum number of pending notifications (64 on iOS, unlimited on Android).
  int get maxPendingNotifications;
}
```

### 12.3 Notification Categories

| Category | Identifier | Actions |
|----------|-----------|---------|
| GENERAL | `general` | ✓ Done, ⏰ Snooze (10 min), ✏️ Edit |
| CALL | `call` | 📞 Call Now, ⏰ Snooze (10 min), ✓ Done |
| TEXT | `text` | 💬 Text Now, ⏰ Snooze (10 min), ✓ Done |
| URL | `url` | 🔗 Open Link, ✓ Done |

Categories are registered at app initialization BEFORE any notifications are scheduled.

### 12.4 Notification Action Handling

```
User taps notification action
  → OS invokes handler (iOS extension or Android BroadcastReceiver)
  → Handler loads reminder from DB
  → Maps action to domain operation:
      DONE       → CompleteReminderUseCase
      SNOOZE     → SnoozeReminderUseCase(duration: 10)
      CALL_NOW   → ActionBridge.launchDialer(phone) + CompleteReminderUseCase
      TEXT_NOW   → ActionBridge.launchSms(phone) + CompleteReminderUseCase
      OPEN_LINK  → ActionBridge.launchUrl(url) + CompleteReminderUseCase
      EDIT       → Launch main app with reminder ID
  → Dismisses notification
```

### 12.5 iOS Dynamic Scheduling (64-Notification Limit)

Algorithm:
1. Query all PENDING/SNOOZED reminders with future trigger times.
2. Sort by `scheduled_time_utc` ascending.
3. Take the first **60** (nearest in time).
4. Cancel any currently-scheduled notification whose `reminder_id` is NOT in the top 60.
5. Schedule notifications for any reminder in the top 60 that doesn't already have one.
6. Update `trigger.notification_scheduled` flags.

The 4-slot buffer prevents churn from constant cancel+reschedule near the boundary.

### 12.6 Android Alarm Scheduling

- Use `AlarmManager.setExactAndAllowWhileIdle()` for precise timing.
- Also use `AlarmManager.setAlarmClock()` where possible (higher priority, survives some OEM restrictions).
- Notification ID: hash of reminder UUID → positive 32-bit integer.
- Individual `PendingIntent` per reminder (unique `requestCode`).
- On BOOT_COMPLETED: re-query all PENDING/SNOOZED reminders and re-schedule all alarms.

### 12.7 Notification Payload

Each notification includes:
- **Content title:** Reminder title
- **Content body:** Action-specific text ("Call Adam at 555-0123")
- **Category:** Based on intent type
- **User info:** `reminder_id`, `reminder_version` (for optimistic locking in action handler)

---

## 13. Notification Reconciliation

### 13.1 Algorithm

Run on: (1) every foreground entry, (2) after any notification action, (3) after any reminder create/edit/delete/complete, (4) daily background wake.

```
function reconcile(notificationBridge, repository, clock):
  // 1. Cancel orphaned OS notifications
  scheduledIds = notificationBridge.getScheduledIds()
  for each id in scheduledIds:
    reminder = repository.getByNotificationId(id)
    if reminder == null or reminder.isDeleted or reminder.status in [COMPLETED, DISMISSED]:
      notificationBridge.cancel(id)
      if reminder != null:
        repository.updateTriggerScheduling(reminder.id, false, null)

  // 2. Schedule missing notifications
  limit = notificationBridge.maxPendingNotifications  // 64 on iOS, unlimited on Android
  pendingReminders = repository.getPendingSortedByTime(limit: limit)
  for each reminder in pendingReminders:
    if !reminder.trigger.notificationScheduled:
      TRY:
        notificationId = notificationBridge.schedule(reminder)
        repository.updateTriggerScheduling(reminder.id, true, notificationId)
      CATCH SchedulingError:
        // Reminder stays in DB; will retry on next reconciliation

  // 3. Detect missed deliveries
  now = clock.now()
  lastReconciled = repository.getMetadata('last_reconciled_at')
  if lastReconciled != null:
    gap = now - DateTime.parse(lastReconciled)
    if gap > Duration(hours: 6):
      missedReminders = repository.getPendingScheduledBetween(
        DateTime.parse(lastReconciled), now
      )
      for each reminder in missedReminders:
        if reminder.trigger.firedAt == null:
          repository.updateTriggerDeliveryStatus(reminder.id, 'delivery_uncertain')
      showBanner("Katala was inactive for ${gap.inHours} hours. " +
                 "${missedReminders.length} reminders may have been missed.")

  // 4. Update reconciliation timestamp
  repository.setMetadata('last_reconciled_at', now.toUtc().toIso8601String())

  // 5. Hard-delete old soft-deleted reminders
  repository.hardDeleteOlderThan(now.subtract(Duration(days: 30)))
```

### 13.2 Idempotency Guarantees

- `schedule()` is idempotent: cancels existing notification for the same reminder before re-scheduling.
- `cancel()` is idempotent: no error if notification doesn't exist.
- Reconciliation can run multiple times without side effects.
- The `last_reconciled_at` timestamp prevents missed-delivery detection from firing multiple times for the same gap.

### 13.3 Serialization

Reconciliation uses a simple in-process lock. If reconciliation is already running when triggered again (e.g., from a notification action while foreground reconciliation is in progress), the second trigger is skipped. A boolean flag `_reconciliationPending = true` ensures reconciliation runs again after the current one completes.

### 13.4 Recovery from Scheduling Failure

If `NotificationBridge.schedule()` fails:
1. Reminder is already persisted (DB is source of truth).
2. Log the failure.
3. `trigger.notification_scheduled` stays `false`.
4. Return `PartialSuccess` to UI if called from `CreateReminderUseCase`.
5. Next reconciliation will attempt to schedule it.

### 13.5 Background vs. Foreground Reconciliation

**Foreground reconciliation** (full): Runs the complete algorithm in §13.1 including step 3 (missed delivery detection with gap analysis) and UI banner display. Runs in the main Dart isolate with full Application layer access.

**Background reconciliation** (limited): Runs only steps 1-2 (cancel orphans, schedule missing) plus step 4 (update timestamp). Does NOT run step 3 (missed delivery detection requires UI context for the banner). Does NOT attempt to show UI. Background reconciliation happens in:
- iOS Notification Service Extension (Swift, not Dart — only state transitions on single reminders, no batch reconciliation)
- Android BOOT_COMPLETED receiver (Kotlin, native SQLite — reschedule all alarms)
- Android WorkManager periodic task (Kotlin, native SQLite — cancel orphans, schedule missing)
- iOS BGAppRefreshTask (Dart background isolate — limited reconciliation)

Step 3 (missed delivery detection) only runs during foreground reconciliation because it may need to display a banner. If background reconciliation detects a gap, it sets a flag `reconciliation_full_needed = true` in `app_metadata` that foreground reconciliation checks on next launch.

---

## 14. iOS Architecture

### 14.1 Xcode Targets

| Target | Type | Purpose |
|--------|------|---------|
| `Katala` | Main App | Full Flutter application |
| `KatalaNotificationExtension` | Notification Service Extension | Background notification action handling |

### 14.2 App Group

Both targets share a container via App Group capability:

- **App Group identifier:** `group.com.katala.app`
- Both targets have the App Group capability added under Signing & Capabilities.
- The entitlement is added to both targets' entitlements files:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.katala.app</string>
</array>
```

### 14.3 Shared Database Path

```swift
let containerURL = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: "group.com.katala.app")!
let dbURL = containerURL.appendingPathComponent("katala.db")
```

The main Flutter app configures Drift to use this shared path:

```dart
// In main app Drift configuration:
final dbPath = await DatabasePathProvider.getSharedContainerPath() + '/katala.db';
```

The `DatabasePathProvider` uses a MethodChannel to retrieve the shared container URL from native Swift code.

### 14.4 Extension Database Layer (Lightweight SQLite)

The extension does NOT use Drift. It uses a lightweight raw SQLite access layer in Swift:

```swift
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
        sqlite3_busy_timeout(db, 3000)
    }

    func transitionReminderState(
        reminderId: String,
        expectedVersion: Int,
        newStatus: String,
        completedAt: String?
    ) throws -> Bool {
        let sql = """
            UPDATE reminder
            SET status = ?, completed_at = ?,
                version = version + 1, updated_at = ?
            WHERE id = ? AND version = ?
        """
        // bind, step, check rows affected
        return rowsAffected > 0
    }

    func getReminderAction(reminderId: String) throws -> (actionType: String, targetValue: String?)? {
        // query action table
    }

    func getReminderVersion(reminderId: String) throws -> Int? {
        // SELECT version FROM reminder WHERE id = ?
    }

    deinit {
        sqlite3_close(db)
    }
}
```

### 14.5 Extension Initialization Sequence

When a notification action is tapped:

1. iOS launches the extension process.
2. `didReceive(_:completionHandler:)` is called.
3. Extension:
   a. Creates `ExtensionDatabase` instance (opens shared WAL-mode SQLite).
   b. Reads the reminder and its current version.
   c. Attempts optimistic-lock state transition (e.g., PENDING → COMPLETED).
   d. If rows affected = 0: another process modified it; read new state and retry once.
   e. Dismisses the notification.
   f. Calls `contentHandler(modifiedContent)`.
4. Extension terminates.

**Total runtime target:** < 1 second for a simple state transition.

### 14.6 Concurrency: Extension vs. Main App

| Concern | Handling |
|---------|----------|
| SQLite concurrent writes | WAL mode allows concurrent reads + one writer. SQLITE_BUSY handled by `busy_timeout=3000`. |
| Extension writes while app is reading | WAL mode: reader sees state before write began. No blocking. |
| Same reminder modified by both | Optimistic locking (`WHERE version = ?`) ensures only one transition succeeds. |
| Lock screen access | `NSFileProtectionCompleteUnlessOpen` allows DB access after first unlock. |

### 14.7 Database File Protection

Use `NSFileProtectionCompleteUnlessOpen`. This allows the extension to access the database when the device is locked (notification actions must work on the lock screen), provided the device has been unlocked at least once since boot.

### 14.8 Extension Failure Behavior

If the extension fails (crash, database error, timeout):
- iOS dismisses the notification (default behavior for handled actions).
- The reminder state is NOT changed.
- Next time the main app launches, reconciliation runs and the reminder is still in its previous state.
- No data corruption — the optimistic lock either succeeds or no change occurs.

### 14.9 Entitlements

**Main app (`Katala.entitlements`):**
- `com.apple.security.application-groups`: `group.com.katala.app`
- `com.apple.developer.usernotifications.time-sensitive`: YES (for Time-Sensitive notifications)

**Extension (`KatalaNotificationExtension.entitlements`):**
- `com.apple.security.application-groups`: `group.com.katala.app`

### 14.10 Info.plist Requirements

**Main app:**
- `NSMicrophoneUsageDescription`: "Katala listens to your voice to create reminders. Audio is processed on-device and never leaves your phone."
- `NSSpeechRecognitionUsageDescription`: "Katala uses on-device speech recognition to convert your voice to text."

**Extension:**
- `NSExtension` → `NSExtensionPrincipalClass` → `$(PRODUCT_MODULE_NAME).NotificationService`
- `UNNotificationExtensionCategory`: the four category identifiers from §12.3

### 14.11 iOS Background Execution

**BGAppRefreshTask:** Used for daily reconciliation. Scheduled with `BGTaskScheduler.shared.register(forTaskWithIdentifier:launchHandler:)`. Runs best-effort (system decides timing). Does NOT run if the app has been force-quit.

**Limitations:**
- Not guaranteed to run daily.
- Low Power Mode deprioritizes it.
- ~30 second execution window.
- Reconciliation must complete within this window.

Because of these limitations, foreground reconciliation (on every app open) is the primary reliability mechanism. BGAppRefreshTask is a secondary best-effort path.

---

## 15. Android Architecture

### 15.1 Key Components

| Component | Role |
|-----------|------|
| `MainActivity.kt` | Flutter host activity |
| `SpeechBridgeImpl.kt` | `SpeechRecognizer` wrapper with on-device enforcement |
| `NotificationBridgeImpl.kt` | `AlarmManager` + notification channel management |
| `ContactBridgeImpl.kt` | `ContactsContract` queries |
| `ActionBridgeImpl.kt` | Intent-based dialer, SMS, browser launching |
| `BootReceiver.kt` | `BOOT_COMPLETED` handler → reschedule all alarms |
| `ReconciliationWorker.kt` | `WorkManager` periodic task (24-hour interval) |

### 15.2 Manifest Configuration

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.VIBRATE" />

<application>
    <!-- Boot receiver -->
    <receiver android:name=".receivers.BootReceiver"
              android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>

    <!-- Notification action receiver (for BroadcastReceiver-based action handling) -->
    <receiver android:name=".receivers.NotificationActionReceiver"
              android:exported="false" />
</application>
```

### 15.3 SpeechRecognizer

```kotlin
class SpeechBridgeImpl(private val context: Context) {
    fun checkAvailability(): SpeechAvailability {
        // Android 13+: SpeechRecognizer.createOnDeviceSpeechRecognizer()
        // Android 10-12: check isRecognitionAvailable() with EXTRA_PREFER_OFFLINE
    }

    fun startListening(silenceTimeoutSec: Double): Flow<SpeechResult> {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)  // CRITICAL
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        // ... create SpeechRecognizer, set listener, start listening
    }
}
```

### 15.4 AlarmManager

```kotlin
fun scheduleAlarm(context: Context, reminder: Reminder, trigger: Trigger) {
    val alarmManager = context.getSystemService(AlarmManager::class.java)
    val intent = Intent(context, AlarmReceiver::class.java).apply {
        putExtra("reminder_id", reminder.id)
    }
    val pendingIntent = PendingIntent.getBroadcast(
        context, reminder.id.hashCode(), intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val triggerTime = trigger.scheduledTimeUtc.toInstant().toEpochMilli()

    // Primary: setExactAndAllowWhileIdle
    alarmManager.setExactAndAllowWhileIdle(
        AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
    )

    // Secondary: setAlarmClock (higher priority, survives more OEM restrictions)
    val alarmInfo = AlarmManager.AlarmClockInfo(triggerTime, pendingIntent)
    alarmManager.setAlarmClock(alarmInfo, pendingIntent)
}
```

### 15.5 BOOT_COMPLETED Receiver

```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pendingResult = goAsync()

        // Use native Kotlin path for alarm re-scheduling
        // (faster than spinning up Flutter engine)
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

### 15.6 WorkManager Reconciliation

```kotlin
class ReconciliationWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val db = openDatabase(getSharedDbPath(context))
        try {
            val reminders = db.queryPendingRemindersSortedByTime(limit = 60)
            val alarmManager = applicationContext.getSystemService(AlarmManager::class.java)
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

Schedule with: `PeriodicWorkRequestBuilder<ReconciliationWorker>(24, TimeUnit.HOURS)`.

### 15.7 OEM Reliability Strategy

The architecture acknowledges that on Philippine-market devices (Xiaomi, OPPO, realme, Samsung budget, Huawei), background processes may be killed aggressively. Katala uses multiple layers to mitigate this:

1. **`setAlarmClock()`** in addition to `setExactAndAllowWhileIdle()` — higher priority, survives some OEM restrictions.
2. **BOOT_COMPLETED receiver** — reschedules all alarms after reboot.
3. **WorkManager periodic task** — daily reconciliation (best-effort, subject to Doze/OEM restrictions).
4. **Foreground reconciliation** — runs every time the user opens the app (the primary reliability mechanism).
5. **Missed-notification detection** — detects when the app was inactive during reminder fire times.
6. **User guidance** — per-manufacturer instructions for disabling battery optimization (Xiaomi, OPPO, Samsung, Huawei).
7. **Reliability status indicator** — in Settings, shows Good/Fair/Poor based on observed delivery behavior.
8. **Foreground service** — deferred to Post-MVP. Persistent notification "Katala is keeping your reminders active."

---

## 16. Flutter ↔ Native Bridge Contracts

### 16.1 SpeechBridge

| Attribute | Specification |
|-----------|--------------|
| **Dart interface** | `lib/platform/bridges/speech_bridge.dart` |
| **iOS implementation** | `ios/Bridges/SpeechBridgeImpl.swift` |
| **Android implementation** | `android/.../bridges/SpeechBridgeImpl.kt` |
| **Method channel** | `com.katala.app/speech` |
| **Request** | `startListening({silenceTimeout: double})`, `stopListening()`, `cancelListening()`, `getAvailability()` |
| **Response** | Stream of JSON `{"text": "...", "isFinal": bool}` |
| **Errors** | `SPEECH_NOT_AVAILABLE`, `PERMISSION_DENIED`, `NO_SPEECH_DETECTED`, `SPEECH_TIMEOUT`, `AUDIO_INTERRUPTED` |
| **Lifecycle** | Bridge is stateless between sessions. Each `startListening()` creates a new native session. |
| **Cancellation** | `cancelListening()` stops the mic and closes the stream without a final result. |
| **Timeout** | Bridge internally enforces 30-second max session and configurable silence timeout. |
| **Thread/isolate** | Native runs on platform UI thread. Dart receives events on main isolate. |

### 16.2 NotificationBridge

| Attribute | Specification |
|-----------|--------------|
| **Dart interface** | `lib/platform/bridges/notification_bridge.dart` |
| **iOS implementation** | `ios/Bridges/NotificationBridgeImpl.swift` |
| **Android implementation** | `android/.../bridges/NotificationBridgeImpl.kt` |
| **Method channel** | `com.katala.app/notifications` |
| **Request** | `schedule(reminderJson)`, `cancel(notificationId)`, `cancelForReminder(reminderId)`, `getScheduledIds()`, `reconcile(toScheduleJson, knownIdsJson)`, `configureCategories(categoriesJson)` |
| **Response** | `schedule` returns `int` (notification ID). `getScheduledIds` returns `List<int>`. `reconcile` returns `ReconciliationResult` JSON. |
| **Errors** | `SCHEDULING_FAILED`, `PERMISSION_DENIED`, `NOTIFICATION_LIMIT_REACHED` |
| **Lifecycle** | Platform bridge initializes notification channels/categories on first `configureCategories()` call. |
| **Cancellation** | N/A — schedule/cancel are one-shot operations. |
| **Thread/isolate** | Native runs on platform UI thread. |

### 16.3 ContactBridge

| Attribute | Specification |
|-----------|--------------|
| **Dart interface** | `lib/platform/bridges/contact_bridge.dart` |
| **iOS implementation** | `ios/Bridges/ContactBridgeImpl.swift` |
| **Android implementation** | `android/.../bridges/ContactBridgeImpl.kt` |
| **Method channel** | `com.katala.app/contacts` |
| **Request** | `resolve(name: String)` |
| **Response** | `List<Map<String, String?>>` — each with `displayName`, `phoneNumber`, `contactId` |
| **Errors** | `PERMISSION_DENIED` (returns empty list, no error thrown) |
| **Lifecycle** | Stateless — queries the contact store on each call. |
| **Search strategy** | 1. Exact display-name match (case-insensitive). 2. First-name or last-name startsWith. 3. Contains match. Results sorted by relevance; max 20 returned. |

### 16.4 ActionBridge

| Attribute | Specification |
|-----------|--------------|
| **Dart interface** | `lib/platform/bridges/action_bridge.dart` |
| **iOS implementation** | `ios/Bridges/ActionBridgeImpl.swift` |
| **Android implementation** | `android/.../bridges/ActionBridgeImpl.kt` |
| **Method channel** | `com.katala.app/actions` |
| **Request** | `launchDialer(phoneNumber)`, `launchSms(phoneNumber)`, `launchUrl(url)` |
| **Response** | `bool` (success/failure) |
| **Errors** | `INVALID_PHONE`, `INVALID_URL`, `CANNOT_LAUNCH` |
| **Lifecycle** | Stateless. |

### 16.5 Notification Category Coordination

Both `flutter_local_notifications` (Dart side) and the native notification systems (iOS `UNUserNotificationCenter`, Android `NotificationManager`) must register identical notification categories. The coordination strategy:

1. **`NotificationBridge.configureCategories()` is the single source of truth for category registration.**
2. On iOS: the native implementation registers categories via `UNUserNotificationCenter.setNotificationCategories()`.
3. On Android: the native implementation creates `NotificationChannel` instances and registers action intents.
4. `flutter_local_notifications` is configured with the SAME category identifiers during its `initialize()` call, but does NOT independently create categories — it references the already-registered native categories.
5. The iOS Notification Service Extension's `Info.plist` declares `UNNotificationExtensionCategory` with the same identifiers.

If categories change between app versions, `configureCategories()` must be called before any notification scheduling (already ensured by startup sequence: configure categories THEN reconcile).

### 16.6 Bridge Rules

1. **No business logic in native implementations.** Native bridges are thin wrappers around OS APIs.
2. **All errors are mapped to domain-agnostic error codes** before crossing the bridge to Dart.
3. **Native exceptions are never exposed directly to Dart.** They are caught, logged, and mapped to bridge-specific error types.
4. **Bridges do not call each other.** Each bridge is independent.

---

## 17. Background Execution

### 17.1 Background Execution Contexts

| Context | Platform | Trigger | What Runs |
|---------|----------|---------|-----------|
| Notification action (app backgrounded) | iOS / Android | User taps notification action | `BackgroundServiceLocator` → use case → repository → bridge |
| Notification Service Extension | iOS | User taps action while app killed | Swift `ExtensionDatabase` (lightweight SQLite) — no Dart |
| BOOT_COMPLETED receiver | Android | Device reboot | Kotlin `BootReceiver` — native SQLite query + AlarmManager |
| WorkManager periodic task | Android | 24-hour interval | Kotlin `ReconciliationWorker` — native SQLite |
| BGAppRefreshTask | iOS | Periodic (best-effort) | Dart `ReconcileNotificationsUseCase` via background isolate |

### 17.2 Background Service Locator

Background contexts that run Dart (notification action callbacks) use a static service locator — NOT Riverpod:

```dart
class BackgroundServiceLocator {
  static Database? _db;
  static ReminderRepository? _reminderRepo;
  static NotificationBridge? _notificationBridge;
  static ActionBridge? _actionBridge;
  static Clock _clock = SystemClock();

  static bool _initialized = false;

  static Future<void> initialize({
    required String databasePath,
    required NotificationBridge notificationBridge,
    required ActionBridge actionBridge,
  }) async {
    if (_initialized) return;

    _db = await _openDatabase(databasePath);
    _reminderRepo = ReminderRepositoryImpl(_db!);
    _notificationBridge = notificationBridge;
    _actionBridge = actionBridge;
    _initialized = true;
  }

  static ReminderRepository get reminderRepo {
    _ensureInitialized();
    return _reminderRepo!;
  }

  static NotificationBridge get notificationBridge {
    _ensureInitialized();
    return _notificationBridge!;
  }

  static ActionBridge get actionBridge {
    _ensureInitialized();
    return _actionBridge!;
  }

  static Clock get clock => _clock;

  // No UI, no Riverpod, no WidgetsBinding, no MaterialApp.

  static Future<void> dispose() async {
    await _db?.close();
    _db = null;
    _reminderRepo = null;
    _notificationBridge = null;
    _actionBridge = null;
    _initialized = false;
  }
}
```

### 17.3 Initialization Sequence (Background Dart)

```
1. Platform invokes Dart callback (notification action handler)
2. Open SQLite database at shared container path
3. Configure WAL mode + busy timeout
4. Create ReminderRepository with the database instance
5. Create use case instances (injected with repository + bridges)
6. Execute use case
7. Close database
8. Return result
```

### 17.4 What Is NOT Initialized in Background

- Riverpod `ProviderScope`
- Flutter widget tree
- `WidgetsBinding`
- `MaterialApp`
- Any UI-related service
- Navigation router
- Theme/data

### 17.5 Error Handling in Background

- All operations wrapped in try/catch.
- `SQLITE_BUSY`: `busy_timeout=3000` handles it. If it still fails, abort and retry on next wake.
- Database unavailable: log, return, try again on next wake.
- Background failures are silent to the user (no UI to show errors).
- Next foreground reconciliation catches missed work.

---

## 18. State Management

### 18.1 Riverpod Architecture (Foreground Only)

```dart
// Providers — defined in provider files near their consumers

// Database (singleton)
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

// Repositories
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepositoryImpl(ref.watch(databaseProvider));
});

// Platform Bridges
final speechBridgeProvider = Provider<SpeechBridge>((ref) {
  throw UnimplementedError('Must be overridden with platform implementation');
});

final notificationBridgeProvider = Provider<NotificationBridge>((ref) {
  throw UnimplementedError('Must be overridden with platform implementation');
});

final contactBridgeProvider = Provider<ContactBridge>((ref) {
  throw UnimplementedError('Must be overridden with platform implementation');
});

final actionBridgeProvider = Provider<ActionBridge>((ref) {
  throw UnimplementedError('Must be overridden with platform implementation');
});

// Clock
final clockProvider = Provider<Clock>((ref) => SystemClock());

// Use Cases
final createReminderUseCaseProvider = Provider<CreateReminderUseCase>((ref) {
  return CreateReminderUseCase(
    repository: ref.watch(reminderRepositoryProvider),
    notificationBridge: ref.watch(notificationBridgeProvider),
    contactBridge: ref.watch(contactBridgeProvider),
    conflictDetector: ConflictDetector(ref.watch(reminderRepositoryProvider)),
  );
});

// UI State — reactive
final pendingRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchPending();
});

final overdueRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchOverdue();
});

final speechAvailabilityProvider = FutureProvider<SpeechAvailability>((ref) {
  return ref.watch(speechBridgeProvider).availability;
});
```

### 18.2 Provider Scoping

- `ProviderScope` is created at the root of the widget tree in `main.dart`.
- Platform bridge providers are overridden at app startup with real implementations.
- In widget tests, providers are overridden with fake implementations.
- In background contexts, Riverpod is NOT used — see §17.2.

### 18.3 UI State Rules

1. **UI state must not become the source of truth for reminders.** The database is always authoritative.
2. **UI observes state via `ref.watch()`** — it never polls or caches reminder state independently.
3. **Drift's reactive streams** power the timeline: `watchPending()` returns a `Stream<List<Reminder>>` that automatically updates when the underlying tables change.
4. **Optimistic UI updates are prohibited** for reminder state transitions. The UI shows the state after the database confirms the transition.

---

## 19. Error Architecture

### 19.1 Error Taxonomy

| Category | Examples | Layer |
|----------|---------|-------|
| **Domain Errors** | `ValidationFailed`, `ConflictDetected`, `InvalidStateTransition`, `TimeInPast` | Domain |
| **Application Errors** | `ContactDisambiguationRequired`, `SchedulingFailed`, `PersistenceFailed`, `NotificationActionFailed` | Application |
| **Persistence Errors** | `DatabaseCorrupted`, `MigrationFailed`, `OptimisticLockFailed`, `SqliteBusy` | Data |
| **Platform Errors** | `SpeechNotAvailable`, `PermissionDenied`, `NotificationLimitReached`, `CannotLaunchUrl` | Platform Bridges |
| **NLP Errors** | `UnrecognizedIntent`, `NoEntitiesExtracted`, `AmbiguousTimeResolution` | Domain |
| **Permission Errors** | `MicrophonePermissionDenied`, `NotificationPermissionDenied`, `ContactsPermissionDenied` | Platform Bridges |

### 19.2 Error Propagation

```
Native Exception
  → (caught in native bridge implementation)
  → Mapped to bridge-specific error code (String)
  → Crosses MethodChannel as error response
  → Dart bridge interface catches platform exception
  → Maps to typed Dart error/sealed class
  → Application layer maps to Result<T, E>
  → UI maps to user-facing message
```

### 19.3 Result Type

```dart
sealed class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
```

### 19.4 Error → User Message Mapping

| Error | User-Facing Message |
|-------|-------------------|
| `ValidationFailed` | Shows clarification card with specific questions |
| `ConflictDetected` | Shows conflict warning with alternatives |
| `PersistenceFailed` | "Couldn't save your reminder. Tap to retry." |
| `SchedulingFailed` | "Reminder saved. Notification will fire soon." (partial success) |
| `SpeechNotAvailable` | "Voice input is not available. Type your reminder below." |
| `PermissionDenied` (microphone) | "Microphone access needed. [Open Settings]" |
| `PermissionDenied` (notifications) | "Notifications are off — you might miss reminders. [Open Settings]" |
| `PermissionDenied` (contacts) | Stores name only; no error shown |

### 19.5 Raw Exceptions Rule

**Raw native exceptions must NOT be exposed directly to the UI.** The bridge layer catches native exceptions and maps them to typed error codes. The Application layer maps error codes to user-facing messages.

---

## 20. Permission Architecture

### 20.1 Permission Request Timing

| Permission | When Requested | Rationale |
|-----------|---------------|-----------|
| Microphone | During onboarding (with explanation of value) | Required for core functionality; spec §28.4.1 mandates onboarding request |
| Speech Recognition | Same time as microphone (iOS bundles them) | Required for STT |
| Notifications | During onboarding, after explaining value | Critical for app function; educate first |
| Contacts | First time NLP resolves a contact name | Contextual: user understands why when "Call Adam" triggers it |
| Exact Alarm (Android) | During onboarding | Required for notification scheduling on Android 12+ |

### 20.2 Permission State Checking

```dart
// Permission status is checked reactively via Riverpod providers
final microphonePermissionProvider = FutureProvider<PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkMicrophonePermission();
});
```

### 20.3 Denial Handling

| Denial Type | Behavior |
|------------|----------|
| First denial | Show explanation of why permission is needed + "Try Again" button |
| Permanent denial | Show "Open Settings" button that deep-links to app settings |
| Revoked after grant | Detected on next foreground. Show banner: "Microphone access was disabled. [Enable]" |

### 20.4 Android Exact Alarm Permission

- Check `AlarmManager.canScheduleExactAlarms()` before scheduling.
- If denied: direct user to Settings → Apps → Katala → "Allow exact alarms."
- This permission can be revoked by the user at any time. Check on every foreground entry.

---

## 21. Security / Privacy Architecture

### 21.1 No Network Requests

**CC-1:** Katala code must make ZERO network requests during normal operation.

Exclusions (not initiated by Katala code):
- User-initiated actions: `tel:` dialer, `sms:` messages, `https://` browser.
- OS-level services: push notification registration (outside Katala's control), map tiles (Post-MVP).

Implementation:
- No `http` package dependency.
- No `dio` package dependency.
- `url_launcher` used ONLY for user-initiated actions.
- `google_fonts` package NOT used (fonts bundled).
- CI step: build release IPA/APK, run on device with network proxy, assert zero unexpected requests.

### 21.2 No Analytics or Crash Reporting

- No Firebase. No Sentry. No Crashlytics. No Amplitude. No Mixpanel.
- Debug logging is stripped from release builds.
- Local crash logs may be written to a file (not transmitted). Opt-in sharing via manual export.

### 21.3 No Cloud STT

- Custom native STT bridge with on-device-only enforcement.
- iOS: `requiresOnDeviceRecognition = true`.
- Android 13+: `SpeechRecognizer.createOnDeviceSpeechRecognizer()`.
- Android 10-12: `EXTRA_PREFER_OFFLINE` with honest disclosure that guarantee cannot be technically enforced.
- If on-device STT is unavailable, voice input is disabled — no cloud fallback.

### 21.4 No Runtime Font Downloads

- Inter font files (.ttf) bundled in `assets/fonts/`.
- Four weights only: Regular 400, Medium 500, SemiBold 600, Bold 700.
- No `google_fonts` package.
- Standard Flutter font declarations in `pubspec.yaml`.

### 21.5 Sensitive Data Logging

- Debug logs: NLP stage names, timing, entity counts. NOT raw transcript text, contact names, or resolved times.
- Release builds: debug logging stripped entirely.
- Logging wrapper enforces: `assert(!kReleaseMode || !log.contains(sensitiveData))`.

### 21.6 Database File Protection

- iOS: `NSFileProtectionCompleteUnlessOpen` — accessible after first unlock.
- Database excluded from device backups by default. Opt-in via Settings with privacy notice.
- Database encryption (SQLCipher) deferred to Post-MVP.

### 21.7 Release Build Verification

CI pipeline must:
1. Build release IPA and APK/AAB.
2. Install on test device.
3. Run mitmproxy/Charles to monitor all network traffic.
4. Assert: zero unexpected HTTP/HTTPS requests from Katala code.
5. Fail the build if any unexpected requests are detected.

---

## 22. Dependency Architecture

### 22.1 Dependency List

| Dependency | Purpose | Layer | Justification |
|-----------|---------|-------|--------------|
| `flutter` (SDK) | Cross-platform framework | All | Core technology choice |
| `drift` | Type-safe SQLite ORM | Data | Compile-time SQL verification, migrations, reactive streams |
| `sqlite3_flutter_libs` | SQLite native libraries | Data | Required by Drift for FFI-based SQLite |
| `flutter_riverpod` | Dependency injection + state management | UI, Application | Compile-safe DI, reactive state observation |
| `riverpod_annotation` | Code generation for Riverpod | UI, Application | Reduces boilerplate |
| `path_provider` | App documents directory path | Data | Required for database file path resolution |
| `permission_handler` | Runtime permission requests | UI, Application | Used directly (no abstraction — package is thin enough). Check permissions on foreground. |
| `url_launcher` | Open dialer, SMS, browser | Platform Bridges | User-initiated actions only |
| `uuid` | UUID v4 generation | Domain, Data | Reminder primary keys |
| `intl` | Date/time formatting | UI, Domain | Human-readable time display |
| `timezone` | Timezone database | Domain | Required for IANA timezone resolution |
| `flutter_local_notifications` | Notification display + action handling | Platform Bridges | Wraps UNUserNotificationCenter (iOS) and NotificationManager (Android). Background action callbacks handled via this package's `onDidReceiveNotificationResponse`. |
| `shared_preferences` | Small key-value storage | Data | Onboarding completion flag, last app version. NOT for UserPreferences (those go in `app_metadata` table). |
| `build_runner` (dev) | Code generation | Dev | Required by Drift, Riverpod |
| `drift_dev` (dev) | Drift code generation | Dev | Generates Dart code from SQL |
| `mocktail` (dev) | Mocking | Dev | Unit test mocking |
| `flutter_test` (dev) | Widget testing | Dev | Flutter test framework |

### 22.2 Explicitly Excluded Dependencies

| Package | Reason for Exclusion |
|---------|---------------------|
| `speech_to_text` | Cannot enforce on-device-only STT. Violates CC-6. Custom native bridge required. |
| `google_fonts` | Default behavior fetches fonts from Google at runtime. Violates CC-1. Fonts bundled instead. |
| `http` / `dio` | No network requests. Not needed. |
| `firebase_*` | No cloud services. Violates offline-first principle. |
| `sentry` / `firebase_crashlytics` | No telemetry. Local logging only. |
| `shared_preferences` (for large data) | Used only for trivial flags (< 5 keys). UserPreferences stored in `app_metadata` table. |

### 22.3 Dependency Addition Process

Before adding any pub.dev package:
1. Verify it makes no network requests (read source code or test in isolation).
2. Verify it does not depend on cloud services.
3. Verify it is compatible with the minimum OS versions (iOS 16+, Android 10/API 29).
4. Document the justification in this section of ARCHITECTURE.md.

---

## 23. Test Architecture

### 23.1 Test Pyramid

```
         ┌─────────┐
         │ Device  │  ~5 tests: real notification delivery, STT on real device,
         │ Tests   │  cross-process DB access (iOS extension)
         ├─────────┤
         │Integrat.│  ~20 tests: CreateReminderUseCase end-to-end,
         │ Tests   │  reconciliation end-to-end, DB migrations
         ├─────────┤
         │ Widget  │  ~30 tests: ConfirmationCard, ClarificationCard,
         │ Tests   │  TimelineGroup, VoiceInputOverlay
         ├─────────┤
         │  Unit   │  ~100 tests: NLP pipeline (each stage), state machine,
         │  Tests  │  conflict detector, repository, use cases (mocked deps)
         └─────────┘
```

### 23.2 Unit Tests

**What:** Every pure function, every NLP stage, every use case (with mocked dependencies), every repository method.

**Mocking strategy:**
- `FakeClock` for temporal tests.
- `FakeSpeechBridge` (returns pre-configured transcripts).
- `FakeNotificationBridge` (in-memory tracking of scheduled notifications).
- `FakeContactBridge` (accepts `Map<String, List<ContactRef>>` in constructor).
- In-memory Drift database (`NativeDatabase.memory()`) for repository tests.

**Key unit test files:**
```
test/domain/nlp/pre_processor_test.dart
test/domain/nlp/intent_detector_test.dart
test/domain/nlp/entity_extractor_test.dart
test/domain/nlp/temporal_resolver_test.dart
test/domain/nlp/validator_test.dart
test/domain/state_machine_test.dart
test/domain/conflict_detector_test.dart
test/application/use_cases/create_reminder_use_case_test.dart
test/application/use_cases/reconcile_notifications_use_case_test.dart
test/data/repositories/reminder_repository_test.dart
```

### 23.3 Widget Tests

**What:** Key widgets rendered with `ProviderScope.overrides` injecting fake services.

**Key widget test files:**
```
test/ui/widgets/confirmation_card_test.dart
test/ui/widgets/clarification_card_test.dart
test/ui/widgets/timeline_group_test.dart
test/ui/widgets/conflict_warning_test.dart
```

**Widget tests verify:** UI renders correctly given pre-built `ParsedReminder`/`Reminder` objects. They do NOT test NLP pipeline logic (covered by unit tests).

### 23.4 Integration Tests

**What:** Multi-layer tests with real Drift (in-memory) and fake bridges.

```
test/integration/create_reminder_flow_test.dart      // NLP → UseCase → Repository → Bridge
test/integration/notification_action_flow_test.dart   // Action handler → Repository → State transition
test/integration/reconciliation_flow_test.dart         // Reconciliation with pre-seeded DB
test/integration/background_service_locator_test.dart  // Background initialization
```

### 23.5 Device Tests

**What:** Tests that require a real device.

| Test | Platform | Description |
|------|----------|-------------|
| Notification delivery | Both | Schedule notification, kill app, wait, verify notification appears |
| Notification action (app killed) | iOS | Tap Done on notification while app killed, open app, verify COMPLETED |
| Notification action (app killed) | Android | Same, accounting for OEM behavior |
| BOOT_COMPLETED | Android | Reboot device, verify alarms are re-scheduled |
| STT on-device | Both | Record known phrase, verify correct transcription (no cloud) |
| Cross-process DB access | iOS | Extension writes to DB, main app reads updated state |
| Permission flows | Both | Deny/allow each permission, verify correct UI state |
| OEM background kill | Android | Install on Xiaomi/OPPO, create reminder, kill app, wait, check missed notification detection |

### 23.6 NLP Corpus Tests

Tests operate on transcripts without requiring real speech. See §10.

### 23.7 CI Pipeline

```
1. flutter analyze         (static analysis)
2. flutter test            (unit + widget tests)
3. flutter test --integration  (integration tests on simulator/emulator)
4. flutter build ios --release  (verify build succeeds)
5. flutter build apk --release  (verify build succeeds)
6. Network traffic audit   (manual step: mitmproxy check on release build)
```

---

## 24. Build Architecture

### 24.1 Flutter & Dart

- **Flutter:** ≥ 3.24.0 (latest stable at implementation start)
- **Dart:** ≥ 3.5.0
- **Channel:** stable
- **Version policy:** Use the latest stable Flutter version at implementation start. Pin in `pubspec.yaml` with a minimum constraint. Commit `pubspec.lock`.

### 24.2 iOS

- **Minimum deployment target:** iOS 16.0
- **Swift:** 5.9+
- **Xcode:** Latest stable (15.x+)
- **Targets:** Main app + Notification Service Extension
- **App Group:** `group.com.katala.app`
- **Entitlements:** App Group, Time-Sensitive Notifications
- **Signing:** Apple Developer account with provisioning profiles for both targets
- **Fonts:** Inter .ttf bundled in app bundle
- **Sounds:** .caf format for custom notification sounds

### 24.3 Android

- **Minimum SDK:** API 29 (Android 10)
- **Target SDK:** API 34+ (latest stable)
- **Kotlin:** 1.9+
- **Gradle:** Use the version bundled with Flutter's stable release
- **Signing:** Release keystore for production builds
- **ProGuard/R8:** Enabled for release builds
- **Fonts:** Inter .ttf bundled in APK/AAB
- **Sounds:** .ogg format for custom notification sounds

### 24.4 Platform-Specific Assets

| Asset | iOS Format | Android Format |
|-------|-----------|---------------|
| Custom notification sound (chirp_save) | `.caf` | `.ogg` |
| Fonts (Inter) | `.ttf` | `.ttf` |
| App icon | AppIcon asset catalog | `mipmap-*` densities |

### 24.5 pubspec.yaml Dependency Constraints

All dependencies use caret constraints (`^`):
```yaml
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.21.0
  sqlite3_flutter_libs: ^0.5.0
  flutter_riverpod: ^2.5.0
  path_provider: ^2.1.0
  permission_handler: ^11.0.0
  url_launcher: ^6.2.0
  uuid: ^4.4.0
  intl: ^0.19.0
  timezone: ^0.9.0
  flutter_local_notifications: ^17.0.0
  shared_preferences: ^2.3.0
```

### 24.6 Reproducible Builds

- Commit `pubspec.lock`.
- Pin Flutter version in CI configuration.
- Use `--frozen` flag with `flutter pub get` in CI to ensure lock file is respected.
- Document exact Xcode and Android SDK versions in repository README.

---

## 25. Observability

### 25.1 Design Principle

Katala has no telemetry. All observability is local-only and opt-in.

### 25.2 Debug Logging

```dart
class AppLogger {
  static void debug(String message, {String? category}) {
    if (kDebugMode) {
      // Redact sensitive data before logging
      final sanitized = _sanitize(message);
      print('[${category ?? 'APP'}] $sanitized');
    }
  }

  static String _sanitize(String message) {
    // Strip anything that looks like a transcript, phone number, or contact name
    // In practice: log structure, not content
    return message;
  }
}
```

**Logging policy:**
- Debug builds: verbose NLP pipeline logging (stage names, timing, entity counts). NOT raw transcripts or contact data.
- Release builds: debug logging stripped entirely.
- No logging of: transcript text, contact names, phone numbers, URL targets, resolved times in plaintext.

### 25.3 Release Logging

Release builds log only fatal errors to a local file (not transmitted). Format:

```
[2026-08-10T14:00:00Z] FATAL: Database integrity check failed: "database disk image is malformed"
[2026-08-10T14:01:00Z] INFO: Reconciliation completed. Scheduled: 3, Cancelled: 1, Missed: 0
```

### 25.4 Diagnostic Screen

Accessible from Settings → About → Diagnostics (long-press on version number for 3 seconds to reveal):

- Database size
- Reminder counts by status
- Last reconciliation timestamp
- Notification reliability status (Good/Fair/Poor)
- `delivery_uncertain` / `delivery_missed` count
- STT availability status
- Permission statuses
- Last 20 log entries (sanitized)

### 25.5 Notification Reliability Diagnostics

The Settings screen shows:

```
Notification Reliability

Status: ● Good — All systems normal

Last reconciled: 2 minutes ago
Pending reminders: 12
Scheduled notifications: 12
Uncertain deliveries: 0
Missed deliveries: 0

[Battery optimization: Disabled]
[Exact alarm permission: Granted]
[Auto-start: Enabled]
```

No diagnostic information may be transmitted remotely.

---

## 26. Implementation Order

### 26.1 Phases (Minimizing Blocking Dependencies)

#### Phase 1: Project Scaffold & Domain Model (Week 1)
1. Flutter project creation (`flutter create katala`)
2. Directory structure setup
3. Domain entities and enums (no dependencies)
4. Clock interface, SystemClock, FakeClock
5. State machine implementation and tests
6. `Result<T, E>` type

**Milestone:** All domain types compile. State machine tests pass.

#### Phase 2: Database (Week 1-2)
1. Drift setup, table definitions, schema creation
2. Repository interface and Drift implementation
3. Migration framework
4. In-memory database for tests
5. Repository unit tests
6. Startup integrity check

**Milestone:** Can persist and query reminders. Repository tests pass against in-memory DB.

#### Phase 3: NLP Pipeline (Week 2-3)
1. Pre-Processor + STT corrections
2. Intent Detector (CREATE_REMINDER only)
3. Entity Extractor (ordered extraction)
4. Temporal Resolver with Clock injection
5. Validator (ValidationIssue production)
6. NLP intermediate types (ParsedReminder, etc.)
7. Full NLP corpus tests

**Milestone:** All NLP tests pass against test corpus. FakeClock-based temporal tests pass.

#### Phase 4: Platform Bridges — Dart Side (Week 3-4)
1. SpeechBridge Dart interface + FakeSpeechBridge
2. NotificationBridge Dart interface + FakeNotificationBridge
3. ContactBridge Dart interface + FakeContactBridge
4. ActionBridge Dart interface
5. Permission abstraction

**Milestone:** Bridge interfaces defined. Fake implementations available for testing.

#### Phase 5: Application Layer (Week 4)
1. `CreateReminderUseCase` (full flow)
2. `CompleteReminderUseCase`
3. `SnoozeReminderUseCase`
4. `DeleteReminderUseCase`
5. `EditReminderUseCase`
6. `HandleNotificationActionUseCase`
7. `ReconcileNotificationsUseCase`
8. `ResolveContactsUseCase`
9. `BackgroundServiceLocator`
10. Use case unit tests (with fake bridges + in-memory DB)

**Milestone:** All use cases compile and pass tests. Reminder creation flow works end-to-end with fakes.

#### Phase 6: Native Bridges — iOS (Week 5-6)
1. iOS project configuration (App Group, entitlements)
2. SpeechBridgeImpl (SFSpeechRecognizer with on-device enforcement)
3. NotificationBridgeImpl (UNUserNotificationCenter)
4. ContactBridgeImpl (CNContactStore)
5. ActionBridgeImpl (UIApplication openURL)
6. Notification Service Extension target
7. ExtensionDatabase (lightweight SQLite)
8. Extension notification action handling
9. iOS integration tests on real device

**Milestone:** Voice → STT → NLP → DB → notification → action works on iOS device.

#### Phase 7: Native Bridges — Android (Week 6-7)
1. Android project configuration (permissions, manifest)
2. SpeechBridgeImpl (SpeechRecognizer with on-device preference)
3. NotificationBridgeImpl (AlarmManager)
4. ContactBridgeImpl (ContactsContract)
5. ActionBridgeImpl (Intents)
6. BootReceiver (BOOT_COMPLETED)
7. ReconciliationWorker (WorkManager)
8. Notification action handling (BroadcastReceiver)
9. Android integration tests on real device

**Milestone:** Voice → STT → NLP → DB → notification → action works on Android device.

#### Phase 8: UI (Week 7-9)
1. Theme (colors, typography, Inter font)
2. Home screen (timeline: overdue, today, tomorrow, later)
3. Mic button + VoiceInputOverlay
4. Confirmation card + Clarification card
5. Text input fallback
6. Reminder detail screen
7. Conflict warning display
8. Settings screen
9. Onboarding flow
10. Reliability banner
11. Widget tests

**Milestone:** Full UI implemented. Widget tests pass.

#### Phase 9: Integration & Polish (Week 9-10)
1. End-to-end integration tests
2. Platform-specific edge case handling
3. Performance profiling (< 5s voice-to-persisted)
4. Accessibility audit
5. Network traffic audit
6. Manufacturer-specific guidance content
7. App store metadata

**Milestone:** Feature-complete, tested, and ready for TestFlight/Internal Testing.

### 26.2 Dependency Graph

```
Phase 1 (Domain) ─────────────────────────────────────────────────────┐
    │                                                                  │
    ├──► Phase 2 (Database) ──► Phase 5 (Application) ──► Phase 8 (UI)
    │                              │                                   │
    ├──► Phase 3 (NLP) ───────────┘                                   │
    │                                                                  │
    └──► Phase 4 (Bridge Interfaces) ──► Phase 6 (iOS) ──► Phase 9 (Integration)
                                     ──► Phase 7 (Android) ───────────┘
```

Phases 6 and 7 (iOS and Android native) can be done in parallel.

---

## 27. Architectural Risks

| # | Risk | Likelihood | Impact | Mitigation | Blocks Implementation? |
|---|------|-----------|--------|-----------|----------------------|
| 1 | iOS notification extension cannot access shared DB reliably under all lock-screen scenarios | Medium | High | Use `NSFileProtectionCompleteUnlessOpen`. Test on real device with locked/unlocked states. Document limitation: lock-screen actions work only after first unlock. | No |
| 2 | Android OEM background killing makes notifications unreliable on majority of Philippine-market devices | High | High | Multi-layered approach: setAlarmClock, boot receiver, foreground reconciliation, missed-notification detection, user guidance, reliability status. Foreground service deferred to Post-MVP. | No (mitigations are architectural) |
| 3 | Taglish NLP accuracy is unknown until tested with real speakers | Medium | Medium | STT corrections table is a placeholder — must be expanded empirically. Taglish corpus tests verify NLP parser but not STT→NLP pipeline. Real-device testing with Filipino-accented speakers required in Phase 6-7. | No |
| 4 | Android < 13 cannot technically enforce on-device-only STT | High | Medium | Honest disclosure during onboarding. On Android 13+ use `createOnDeviceSpeechRecognizer`. On Android 10-12 use `EXTRA_PREFER_OFFLINE` with caveat notice. | No |
| 5 | Drift cross-process access (iOS main app + extension) may reveal edge cases under heavy concurrent write load | Low | Medium | WAL mode + `busy_timeout=3000` + optimistic locking. Concurrent access test in Phase 6. | No |
| 6 | Flutter background isolate initialization time may exceed iOS ~5s background execution window | Medium | Medium | Background path initializes minimal dependencies (no Riverpod, no UI). If still too slow, fall back to native-only action handling (Swift/Kotlin directly, no Dart). | No |
| 7 | `flutter_local_notifications` may not support all required notification action behaviors | Low | High | Verify during Phase 4. If gaps found, implement notification actions natively (bypassing the package for action handling). The package's primary role is notification display; action handling can be native. | No |
| 8 | 64-notification iOS limit causes churn for users with many reminders | Low | Low | Dynamic scheduling window maintains nearest 60. Users with 65+ reminders see all, but farthest 5+ won't have notifications until space frees. Honest communication in UI. | No |

---

## 28. Architectural Decision Records

### ADR-1: Flutter for Cross-Platform

**Decision:** Use Flutter as the UI framework for both iOS and Android.

**Context:** Katala targets iOS and Android with a single codebase. Native iOS (SwiftUI) and native Android (Jetpack Compose) were considered.

**Alternatives:** (a) Separate native apps (iOS SwiftUI + Android Compose), (b) React Native, (c) Kotlin Multiplatform.

**Why chosen:** Flutter provides a single codebase for business logic, NLP, and UI. Platform bridges handle OS-specific capabilities. The Drift + Riverpod ecosystem integrates well with Flutter. Flutter's test framework supports unit, widget, and integration testing.

**Consequences:** Platform-specific code is required for STT, notifications, and contacts. Platform bridge maintenance overhead is accepted. App size is larger than pure native but acceptable for MVP.

---

### ADR-2: Drift for Database

**Decision:** Use Drift (SQLite ORM) for type-safe database access.

**Context:** Katala needs a local relational database for reminders, triggers, actions, and metadata.

**Alternatives:** (a) Raw `sqflite`, (b) Isar, (c) Hive, (d) ObjectBox.

**Why chosen:** Drift provides compile-time SQL verification, typed queries, reactive streams (critical for timeline auto-update), and a robust migration system. It integrates with Riverpod's stream providers. WAL mode support is critical for iOS cross-process access.

**Consequences:** Drift code generation adds build complexity (`build_runner`). The iOS extension cannot use Drift (too heavy) and uses raw SQLite instead — this is an accepted duplication.

---

### ADR-3: Riverpod for State Management

**Decision:** Use Riverpod for dependency injection and reactive state management in the foreground (UI) path only.

**Context:** Katala needs a way to provide dependencies to widgets and reactively observe database state.

**Alternatives:** (a) Provider, (b) BLoC, (c) GetX, (d) Manual service locator everywhere.

**Why chosen:** Riverpod is compile-safe (no runtime `ProviderNotFoundException`), supports auto-disposal, and integrates with Drift's reactive streams. It is the successor to Provider and is widely adopted in the Flutter ecosystem.

**Consequences:** Riverpod does NOT work in background contexts (notification callbacks, boot receivers). A separate `BackgroundServiceLocator` pattern is required for those contexts. This is an accepted architectural trade-off.

---

### ADR-4: Custom Native STT Bridge

**Decision:** Implement a custom native STT bridge (Swift/Kotlin) rather than using the `speech_to_text` Flutter package.

**Context:** Katala's privacy requirement CC-6 mandates on-device-only speech recognition. The `speech_to_text` package does not expose `requiresOnDeviceRecognition` (iOS) or `EXTRA_PREFER_OFFLINE` (Android) and cannot enforce on-device-only behavior.

**Alternatives:** (a) Use `speech_to_text` with documented privacy caveat, (b) Custom native bridge.

**Why chosen:** Custom native bridge is the only option that satisfies CC-6. The bridge is thin — it wraps the OS speech recognition API and enforces on-device mode. The additional implementation effort (~3-4 days of iOS + Android development) is justified by the privacy guarantee.

**Consequences:** More native code to maintain. Version-specific Android behavior (10-12 vs. 13+). The bridge must handle audio interruptions, permissions, and unavailability states on both platforms.

---

### ADR-5: Rule-Based NLP (No ML)

**Decision:** Use deterministic, rule-based NLP (regex patterns + explicit temporal resolution) rather than ML-based approaches.

**Context:** Katala must work fully offline with deterministic, testable behavior. The NLP handles a constrained domain (reminder creation with time, contact, URL).

**Alternatives:** (a) TensorFlow Lite on-device model, (b) ONNX runtime, (c) Regex + rule-based.

**Why chosen:** Rule-based NLP is deterministic, testable, debuggable, and sufficient for the constrained reminder-creation domain. It requires no model files, no inference runtime, and no training data. It works identically on iOS and Android.

**Consequences:** Cannot handle complex or ambiguous natural language outside the defined patterns. Post-MVP NLP improvements limited to expanding regex coverage and STT correction dictionary. Filipino full-intent patterns deferred to Post-MVP.

---

### ADR-6: Database as Source of Truth

**Decision:** The SQLite database is the authoritative system state. OS notifications are derived state rebuilt from the database.

**Context:** OS notification schedulers can lose state (force-stop, reboot, OEM kill). Katala cannot rely on OS notification state for correctness.

**Alternatives:** (a) OS notifications as co-equal state (requires sync protocol), (b) Database as sole source, OS as cache.

**Why chosen:** Database as source of truth is simpler and more reliable. It eliminates the need for a synchronization protocol between two potentially divergent state stores. The reconciliation algorithm repairs OS state from the database.

**Consequences:** Notification scheduling is a separate step after persistence. Scheduling failures do not prevent reminder creation. Reconciliation adds complexity but is required for reliability.

---

### ADR-7: Notification Reconciliation on Foreground

**Decision:** Run full notification reconciliation on every foreground entry (primary) plus daily background wake (secondary).

**Context:** Notifications can be lost due to force-stop, reboot, OEM kill, or iOS 64-limit churn. Reconciliation detects and repairs these gaps.

**Alternatives:** (a) Background-only reconciliation, (b) Foreground-only, (c) Both.

**Why chosen:** Foreground reconciliation is the most reliable trigger (user action is guaranteed). Background reconciliation is a best-effort supplement. Together they provide defense in depth.

**Consequences:** Every app open triggers a reconciliation pass. This is fast (< 100ms for typical reminder counts) but adds a startup step. The reconciliation algorithm is idempotent so multiple runs are safe.

---

### ADR-8: iOS Cross-Process Architecture (App Group + Extension)

**Decision:** Use App Group shared container for SQLite database, with a Notification Service Extension using lightweight raw SQLite for background notification action handling.

**Context:** FR-8 requires notification actions to work without opening the app. On iOS, this requires a separate extension process that can access the database.

**Alternatives:** (a) Extension with full Drift (heavy, complex), (b) Foreground-only notification actions (violates FR-8), (c) UNNotificationAction with foreground option (opens app).

**Why chosen:** Lightweight SQLite in the extension is the simplest approach that satisfies FR-8. The extension only needs to run a single UPDATE with optimistic locking. Duplicating a subset of the data layer in Swift is an accepted maintenance trade-off.

**Consequences:** Two code paths modify the database (main app via Drift, extension via raw SQLite). Both use the same optimistic locking pattern. Extension code must be kept in sync with schema changes. WAL mode is mandatory.

---

### ADR-9: Android OEM Reliability Strategy

**Decision:** Use multiple overlapping mechanisms (setAlarmClock, BOOT_COMPLETED, WorkManager, foreground reconciliation, missed-notification detection, per-manufacturer user guidance) to maximize notification reliability on aggressive-OEM devices.

**Context:** On Philippine-market Android devices (Xiaomi, OPPO, realme, etc.), background processes are killed aggressively, alarms are cleared, and BOOT_COMPLETED receivers are disabled.

**Alternatives:** (a) Accept unreliability and document it, (b) Foreground service (guarantees reliability but has UX cost), (c) Multi-layered approach.

**Why chosen:** Multi-layered approach provides the best reliability without the UX cost of a mandatory foreground service. The foreground service remains an optional Post-MVP enhancement.

**Consequences:** Android implementation is more complex than iOS. Per-manufacturer guidance must be maintained as OEMs update their OS. The app honestly communicates reliability status to users.

---

### ADR-10: Optimistic Locking for Concurrent State Transitions

**Decision:** Use an integer `version` column on the `reminder` table with `WHERE version = :expectedVersion` on every UPDATE. Retry once on conflict.

**Context:** Notification actions (from extension/BroadcastReceiver) and in-app actions can modify the same reminder concurrently. Without locking, one action could silently overwrite the other.

**Alternatives:** (a) Pessimistic locking (not supported well across processes on iOS), (b) Last-write-wins, (c) Optimistic locking.

**Why chosen:** Optimistic locking works across processes (iOS extension + main app), is simple to implement, and handles the expected concurrency patterns correctly. Retry-once is sufficient for the low contention rate (a user can't tap two actions simultaneously).

**Consequences:** Every UPDATE on reminder includes a version check. Callers must handle the "0 rows affected" case with retry logic. The version column increments on every state transition.

---

### ADR-11: Background Service Locator (Not Riverpod)

**Decision:** Use a static service locator (`BackgroundServiceLocator`) for background execution contexts instead of Riverpod.

**Context:** Notification action callbacks, BOOT_COMPLETED receivers, and background tasks run without a Flutter widget tree. Riverpod's `ProviderScope` requires a widget tree ancestor.

**Alternatives:** (a) Create separate `ProviderScope` for each background context, (b) Initialize full Riverpod graph in background, (c) Static service locator.

**Why chosen:** Static service locator is the lightest-weight approach. Background contexts only need database + repositories + bridges — not the full DI graph. It initializes faster (critical for iOS ~5s background window) and is explicit about what's available.

**Consequences:** Two DI mechanisms in the app (Riverpod for foreground, service locator for background). This is an accepted trade-off documented in the code. Background service locator must be kept in sync with Riverpod provider registrations for the shared dependencies.

---

## 29. AI Coding-Agent Contract

### 29.1 What You MUST NOT Change

- **The product specification.** KATALA_SPEC_V3.md defines WHAT. This document defines HOW. Do not add features, change behaviors, or expand MVP scope.
- **The architectural principles** in §1. They are non-negotiable.
- **The layer dependency rules** in §4. Domain must not depend on Flutter. Data must not call Platform Bridges.
- **The entity definitions** in §6. Do not add or remove fields from `Reminder`, `Trigger`, or `Action`.
- **The database schema** in §7.2. Any schema change requires a migration.
- **The state machine** in §6.5. Do not add transitions or change guard conditions.
- **The NLP pipeline boundary** — NLP is pure. Contact resolution happens in the Application layer.
- **The notification reconciliation algorithm** in §13.
- **The custom native STT bridge requirement** — do not use `speech_to_text` package.
- **The privacy constraints** in §21. Zero network requests. No analytics. No cloud STT.

### 29.2 What You MUST NOT Invent

- New use cases not listed in §5.1.
- New NLP stages or intent types (CREATE_REMINDER is the only MVP intent).
- New notification categories beyond the four defined in §12.3.
- New platform bridge interfaces.
- New database tables not in the schema.
- "Convenience" dependencies not in §22.1.
- Cloud fallback for STT.
- Recurring reminders (Post-MVP).
- Geofencing (Post-MVP).
- Follow-up engine (Post-MVP).

### 29.3 Where Platform-Specific Code Belongs

- **iOS native:** `ios/Bridges/` for bridge implementations, `ios/KatalaNotificationExtension/` for the extension.
- **Android native:** `android/app/src/main/kotlin/com/katala/app/bridges/`, `receivers/`, `workers/`.
- **Dart platform interfaces:** `lib/platform/bridges/`.
- **Business logic never goes in native code.** Native bridges are thin wrappers around OS APIs.

### 29.4 How Dependencies Are Added

1. Verify the dependency makes no network requests.
2. Verify it does not depend on cloud services.
3. Verify it is compatible with iOS 16+ and Android API 29+.
4. Add it to the approved list in §22.1 of this document.
5. Run `flutter pub add <package>`.
6. Run the network traffic audit on a release build.

### 29.5 How Tests Are Expected

- Every use case has a unit test with mocked dependencies.
- Every NLP stage has a unit test with the test corpus.
- Repository tests use in-memory Drift database.
- Widget tests use `ProviderScope.overrides` with fake services.
- Integration tests verify the create-reminder flow end-to-end.
- Device tests verify notification delivery and background action handling on real hardware.

### 29.6 How Deviations Are Documented

If a deviation from this architecture is necessary:
1. Add a comment in the code explaining WHY: `// ARCHITECTURE DEVIATION: ... because ...`
2. Add an entry to the deviation log at the bottom of this document.
3. If the deviation is permanent, update the relevant section of ARCHITECTURE.md.
4. If the deviation affects the spec, update KATALA_SPEC_V3.md.

---

## 30. Final Architecture Validation

Before declaring ARCHITECTURE.md complete, I mentally simulated the implementation of every critical flow:

### 30.1 Can the app create a reminder?
**YES.** User speaks → SpeechBridge (native STT) → NLP pipeline (pure, 5 stages) → ParsedReminder → CreateReminderUseCase → contact resolution (ContactBridge) → conflict detection → persistence (Drift transaction) → notification scheduling (NotificationBridge). Defined in §5.2 and §9-§11.

### 30.2 Can it persist it?
**YES.** Reminder + Trigger + Action inserted in a single Drift transaction. WAL-mode SQLite. Defined in §7.

### 30.3 Can it schedule it?
**YES.** NotificationBridge.schedule() → iOS: UNUserNotificationCenter, Android: AlarmManager (setExactAndAllowWhileIdle + setAlarmClock). Defined in §12 and §14-§15.

### 30.4 Can it survive app termination?
**YES.** Database is source of truth. On next launch: integrity check → reconciliation → missed-notification detection. iOS: BGAppRefreshTask (best-effort). Android: BOOT_COMPLETED receiver. Defined in §13, §17, §26-§27.

### 30.5 Can it reconcile notifications?
**YES.** Reconciliation algorithm in §13.1: cancel orphans, schedule missing, detect missed deliveries, update timestamp. Runs on every foreground and daily background wake.

### 30.6 Can the user tap Done without opening the app?
**YES.** On iOS: Notification Service Extension with App Group shared SQLite (optimistic lock UPDATE). On Android: BroadcastReceiver. Defined in §14.4-§14.6 and §15.

### 30.7 Can concurrent writes be resolved?
**YES.** Optimistic locking with `version` column. `WHERE version = :expectedVersion`. Retry-once on conflict. Concurrent writes serialized at SQLite level (WAL mode). Defined in §8.

### 30.8 Can speech operate fully offline?
**YES.** Custom native STT bridge with on-device enforcement. iOS: `requiresOnDeviceRecognition = true`. Android 13+: `createOnDeviceSpeechRecognizer()`. No cloud fallback. If model unavailable, voice disabled, text fallback available. Defined in §11.

### 30.9 Can the same domain logic work on iOS and Android?
**YES.** Domain layer has zero platform imports. NLP pipeline, state machine, conflict detector, validation — all pure Dart. Platform differences confined to bridges. Defined in §1.10, §4, §6, §9.

### 30.10 Can every major subsystem be unit tested?
**YES.** NLP stages: injectable Clock, pure functions. Repository: in-memory Drift DB. Use cases: fake bridges. State machine: pure transitions. Conflict detector: seeded in-memory DB. Defined in §10 and §23.

### 30.11 Can the application be built from a clean repository?
**YES.** `flutter pub get` → `flutter build ios --release` → `flutter build apk --release`. `pubspec.lock` committed. Dependency versions pinned. CI pipeline defined in §23.7 and §24.6.

---

**All 11 validation questions answer YES.** The architecture is complete and implementation-ready.

---

## Deviation Log

| Date | Deviation | Reason | Approved By |
|------|-----------|--------|------------|
| (none) | — | — | — |

---

*End of ARCHITECTURE.md*
