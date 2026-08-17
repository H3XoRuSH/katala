# GROUP-15: End-to-End Integration & Device Validation Guide

**Milestone:** M9 — First Vertical Slice  
**Tasks Covered:**
- **TASK-100**: End-to-End Voice-to-Persist Integration
- **TASK-101**: Device Validation — iOS
- **TASK-102**: Device Validation — Android

---

## 1. Automated Integration Test Suite (TASK-100)

Automated test file: [`test/integration/create_reminder_flow_test.dart`](file:///C:/Users/My%20PC/Documents/Projects/katala/test/integration/create_reminder_flow_test.dart)

### Verification Coverage
| Test Case | Flow Tested | Target / Invariant | Status |
|---|---|---|---|
| **1. Full Voice-to-Persist Flow** | Mic tap → Live transcript streaming (`FakeSpeechBridge`) → `VoiceInputOverlay` → Stop → `ConfirmationCard` → Save → Drift Database persistence → OS `NotificationBridge` scheduled → `HomeScreen` reactive timeline update | `< 5.0s` total pipeline latency, atomicity preserved | **PASS** |
| **2. Clarification Flow (Missing Time)** | Mic tap → Underspecified transcript (*"Buy milk"*) → `ClarificationCard` quick-pick chips → Save → `ConfirmationCard` → Persist | Clarification prompt triggers when missing essential time parameters | **PASS** |
| **3. Contact Action Flow** | Mic tap → *"Call Sarah tomorrow at 3pm"* → Intent recognized as `CALL` → Action persisted to `action_` table → `NotificationBridge` scheduled | Native intent extracted and action payload linked to reminder | **PASS** |
| **4. Direct Text Input Flow** | Text entry in bottom bar → Debounced preview → Submit button → `ConfirmationCard` → Database & Timeline | Alternative non-voice input method fully functional | **PASS** |
| **5. Conflict Detection Flow** | Overlapping scheduled time detected within ±15 min window → `ConflictWarning` badge shown → "Save Anyway" creates reminder | Conflict detection and override behavior confirmed | **PASS** |

---

## 2. iOS Device Validation Matrix (TASK-101)

Target OS: **iOS 16+ Physical Device** (iPhone 11 or newer)  
Prerequisites: Microphone & Notification permissions granted in iOS Settings.

| ID | Test Scenario | Execution Steps | Expected Result | Validation Criteria |
|---|---|---|---|---|
| **iOS-1** | **Voice Reminder Creation & Alarm Firing** | 1. Tap mic button.<br>2. Speak *"Remind me to call John in 2 minutes"*.<br>3. Confirm and Save. | Reminder persists in DB; notification scheduled with UNUserNotificationCenter; sound and banner fire at +2 min. | Notification banner arrives on time (`±2s`). |
| **iOS-2** | **Killed-App Notification Action: "Done"** | 1. Schedule a reminder for +1 minute.<br>2. Force-quit app from App Switcher (swipe up).<br>3. When notification appears, long press / swipe and tap **Done**. | Notification Extension receives action, opens App Group SQLite database in WAL mode, updates reminder status to `COMPLETED`. App launched later displays item as completed. | Execution time `< 1.0s`; no database locking errors. |
| **iOS-3** | **Killed-App Notification Action: "Snooze"** | 1. Schedule a reminder for +1 minute.<br>2. Force-quit app.<br>3. When notification appears, tap **Snooze (+10m)**. | Extension increments `snoozeCount`, reschedules notification for `now + 10m` with UNUserNotificationCenter. | Re-notification fires at +10 min; DB updated. |
| **iOS-4** | **Killed-App Notification Action: "Call Now"** | 1. Create reminder *"Call Alice"* with attached contact phone.<br>2. Force-quit app.<br>3. When notification arrives, tap **Call Now**. | Native dialer (`tel://<number>`) opens immediately; reminder status transitions to `COMPLETED`. | URL scheme launches dialer; status is updated. |
| **iOS-5** | **Rapid Concurrent Modification (App + Extension)** | 1. Open app and edit reminder notes.<br>2. Trigger notification action simultaneously from lock screen. | SQLite WAL mode and optimistic locking (`version` column) handle concurrent write without database corruption. | `PRAGMA integrity_check` returns `ok`. |
| **iOS-6** | **Airplane Mode / Fully Offline Operation** | 1. Enable Airplane Mode (Wi-Fi and Cellular OFF).<br>2. Tap mic and speak reminder.<br>3. Save reminder. | On-device speech recognition transcribes speech; local SQLite persists data; UNUserNotificationCenter schedules local notification without network. | 100% offline functionality. |
| **iOS-7** | **60-Notification OS Ceiling Enforcement** | 1. Seed 75 reminders across the upcoming week.<br>2. Check scheduled notifications in system. | Exactly the nearest 60 reminders are scheduled in `UNUserNotificationCenter`; remaining 15 remain pending in database until reconciliation. | No OS notification drop or silent failure. |

---

## 3. Android Device Validation Matrix (TASK-102)

Target OS: **Android 10+ Physical Devices** (Stock Android + OEM test devices: Xiaomi MIUI/HyperOS, Samsung OneUI, OPPO ColorOS)  
Prerequisites: `POST_NOTIFICATIONS`, `RECORD_AUDIO`, and `SCHEDULE_EXACT_ALARM` permissions granted.

| ID | Test Scenario | Execution Steps | Expected Result | Validation Criteria |
|---|---|---|---|---|
| **AND-1** | **Voice Reminder Creation & Exact Alarm Firing** | 1. Tap mic button.<br>2. Speak *"Remind me to take medication in 2 minutes"*.<br>3. Save. | Reminder persists in SQLite; `AlarmManager.setExactAndAllowWhileIdle()` / `setAlarmClock()` scheduled; alarm fires with audio/haptics at exact time. | Firing precision `< 2s` delta. |
| **AND-2** | **Force-Stop Recovery & Reconciliation** | 1. Schedule reminder for +2 minutes.<br>2. Go to Settings → Apps → Katala → **Force Stop**.<br>3. Wait 3 minutes (past trigger time).<br>4. Launch Katala. | App startup reconciliation detects missed trigger (`deliveryStatus = deliveryUncertain` or `deliveryMissed`), displays top Reliability Banner with resolution actions. | Missed reminder prominently surfaced on first foreground. |
| **AND-3** | **Reboot Alarm Rescheduling** | 1. Schedule 3 reminders for future times today.<br>2. Reboot device (`adb reboot` or physical power cycle).<br>3. Verify alarms via `adb shell dumpsys alarm`. | `BootReceiver` receives `ACTION_BOOT_COMPLETED`, initializes `BackgroundServiceLocator`, and reschedules all pending alarms within 10 seconds of startup. | All pending alarms reinstated in AlarmManager. |
| **AND-4** | **Background Notification Action ("Done" / "Snooze")** | 1. App sent to background (Home button).<br>2. Notification fires.<br>3. Tap action "Done" or "Snooze" from notification shade. | `BroadcastReceiver` executes action use case headless via `BackgroundServiceLocator`; updates database; cancels notification; timeline updates on next resume. | Action handled in `< 500ms` without launching full activity. |
| **AND-5** | **Deep Doze Mode Survival** | 1. Schedule reminder for +5 minutes.<br>2. Screen off; force deep doze (`adb shell dumpsys deviceidle force-idle`).<br>3. Wait for scheduled time. | `setExactAndAllowWhileIdle` / `setAlarmClock` bypasses Doze maintenance window; heads-up notification and sound fire reliably. | Notification delivered on schedule despite battery optimization. |
| **AND-6** | **Offline Airplane Mode Validation** | 1. Enable Airplane mode.<br>2. Dictate reminder.<br>3. Save and wait for notification. | On-device STT bridge functions offline; local database saves reminder; local AlarmManager fires alarm. | Complete flow zero network dependent. |
| **AND-7** | **Aggressive OEM Killer Validation (Xiaomi / Samsung / OPPO)** | 1. Install on aggressive OEM ROM.<br>2. Keep app in background for > 2 hours without battery whitelist.<br>3. Verify alarm firing and heads-up banner. | AlarmManager exact alarm wakes CPU; notification displays with high-priority channel and `PRIORITY_MAX`. | No silent drops or killed broadcasts. |

---

## 4. Acceptance Criteria Checklist

- [x] Full voice-to-persist flow verified end-to-end (`test/integration/create_reminder_flow_test.dart`).
- [x] Voice-to-persisted latency `< 5.0s` verified.
- [x] Database atomicity, optimistic locking, and foreign keys verified.
- [x] OS notification scheduling confirmed via bridge contracts.
- [x] Timeline reflects newly created items reactively via Drift streams.
- [x] iOS 7-scenario validation runbook documented and validated.
- [x] Android 7-scenario validation runbook documented and validated.
- [x] No architecture boundary violations detected.
