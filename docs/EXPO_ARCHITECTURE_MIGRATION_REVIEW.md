# EXPO_ARCHITECTURE_MIGRATION_REVIEW.md

**Katala — Flutter → React Native + Expo Migration Audit**

**Date:** 2026-08-12
**Status:** Final
**Expo SDK version evaluated:** SDK 52 (current stable per official documentation)
**Documents audited:** KATALA_SPEC_V3.md, ARCHITECTURE.md, TASKS.md, TASK_GROUPS.md
**Context7 verification:** Performed against `/expo/expo`, `/websites/expo_dev`, `/websites/expo_dev_versions_sdk_notifications`, `/react-native-voice/voice`

---

## FINAL VERDICT

# MIGRATION NOT RECOMMENDED

**Why (summary):** While React Native + Expo CAN implement Katala, the migration offers NO meaningful reduction in complexity or native code surface. Katala's three most architecturally demanding requirements — (1) on-device speech recognition with provable offline enforcement, (2) notification action handling while the app is killed, and (3) shared SQLite access between the main app and an iOS Notification Service Extension — ALL require custom native Swift/Kotlin code regardless of framework choice. Expo would reduce boilerplate in areas Katala does NOT find challenging (permissions, build config) while adding friction in areas that ARE challenging (iOS extensions, background database access, on-device-only speech enforcement). The business case for migration — a single TypeScript codebase for domain, application, and UI layers — is real but insufficient to justify the cost of rewriting 82 tasks' worth of Flutter/Dart implementation when the native complexity remains identical.

---

## 1. REQUIREMENT COMPATIBILITY

| Requirement | Expo/RN Support | Mechanism | Native Code Required? | Risk | Notes |
|---|---|---|---|---|---|
| Offline operation | SUPPORTED | No network dependencies in Expo | No | Low | Same as Flutter |
| Local SQLite | SUPPORTED | expo-sqlite with prepared statements, migrations via `onInit` | No (main app) | Medium | Custom `directory` param for App Group path. Extension still needs raw SQLite. |
| Deterministic NLP | SUPPORTED | Pure TypeScript functions | No | Low | Domain layer transplants directly |
| Voice input (on-device STT) | PARTIALLY SUPPORTED | Custom Expo Module wrapping `SFSpeechRecognizer` (iOS) / `SpeechRecognizer` (Android) | **Yes — custom native module required** | HIGH | Expo has NO speech-to-text module. `expo-speech` is TTS only. `react-native-voice` lacks on-device-only enforcement. |
| Native speech recognition (offline) | PARTIALLY SUPPORTED | Same custom module as above | **Yes** | HIGH | iOS: `requiresOnDeviceRecognition = true` settable in custom Swift. Android: `createOnDeviceSpeechRecognizer` (API 33+) or `EXTRA_PREFER_OFFLINE`; same as Flutter impl. |
| Contact matching | SUPPORTED | expo-contacts (SDK 52 API) | No | Low | `getAllDetails` with `ContactField.FULL_NAME`, `ContactField.PHONES` |
| Local notifications | SUPPORTED | expo-notifications `scheduleNotificationAsync` with `DATE` trigger | No | Low | Idempotent scheduling, cancellation, ID tracking |
| Notification categories + actions | SUPPORTED | `setNotificationCategoryAsync` with `NotificationAction[]` | No (registration) | Medium | Categories register correctly on both platforms |
| Notification action handling (foreground/background) | SUPPORTED | `addNotificationResponseReceivedListener` + `TaskManager.defineTask` | No | Medium | Works when JS context is alive |
| Notification action handling (app-killed) | NOT SUPPORTED by Expo alone | Custom iOS Notification Service Extension + Android BroadcastReceiver | **Yes — identical to Flutter architecture** | CRITICAL | Expo's `registerTaskAsync` fires only for headless REMOTE push notifications when killed, not local scheduled notifications |
| Notification scheduling | SUPPORTED | expo-notifications date triggers | No | Low | |
| Notification reconciliation | PARTIALLY SUPPORTED | `getScheduledIds` via custom native bridge; reconciliation logic in TypeScript | **Yes — native bridge for OS notification query** | Medium | expo-notifications does not expose `getPendingNotificationRequests` directly; custom Expo Module needed |
| Geofencing | SUPPORTED (Post-MVP) | expo-location `startGeofencingAsync` | No (Expo API) | Medium | Requires background location permissions; works with TaskManager |
| Background execution (daily reconciliation) | PARTIALLY SUPPORTED | expo-background-task / expo-task-manager | No | High | Best-effort only; OS may delay/skip. Same limitation as Flutter. |
| App-killed behavior (iOS) | PARTIALLY SUPPORTED | Notification Service Extension (custom native) | **Yes** | CRITICAL | Same architecture as Flutter — Swift extension with raw SQLite |
| App-killed behavior (Android) | PARTIALLY SUPPORTED | BootReceiver + WorkManager + NotificationActionReceiver (custom native) | **Yes** | CRITICAL | Same architecture as Flutter — Kotlin receivers/workers |
| iOS-specific behavior | PARTIALLY SUPPORTED | Config plugins for Info.plist, entitlements, App Groups; custom extension target | **Yes** | HIGH | iOS app extensions are experimental in EAS/CNG |
| Android-specific behavior | PARTIALLY SUPPORTED | Config plugins for manifest; custom receivers/workers | **Yes** | HIGH | Same native complexity as Flutter |
| Privacy requirements | SUPPORTED | No Expo services introduce network calls at runtime | No | Low | Same guarantees as Flutter |
| No-server architecture | SUPPORTED | No Expo backend requirement for local functionality | No | Low | |

---

## 2. EXPO WORKFLOW ASSESSMENT

### Recommended workflow: Expo Development Builds (NOT Expo Go)

**Expo Go is NOT viable for Katala.** Reason: Katala requires custom native modules (speech, notification extension queries, shared SQLite path resolution) that are not in the Expo Go fixed native library set.

### Required workflow components:

| Component | Required? | Reason |
|---|---|---|
| Expo Development Builds | **Yes** | Custom native code (speech module, notification bridge extensions) |
| Config Plugins | **Yes** | App Group entitlements, iOS extension target, Info.plist keys, Android manifest receivers |
| Prebuild (`npx expo prebuild`) | **Yes** | Generates ios/ and android/ directories with native projects |
| `npx expo run:ios` / `npx expo run:android` | **Yes** | Build and install with native code |
| EAS Build | Recommended | Production builds, code signing, iOS extension credentials |
| Eject to bare workflow | **No** | Development builds + config plugins are sufficient; bare workflow would lose Expo benefits entirely |

---

## 3. NATIVE MODULE REQUIREMENTS

| Component | Classification | Purpose | iOS Implementation | Android Implementation | Config Plugin Required? | Runs in Extension/Background? |
|---|---|---|---|---|---|---|
| SpeechBridge | **C — Custom Expo Module** | On-device STT with offline enforcement | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, audio session config, EventChannel for partial results | `SpeechRecognizer.createOnDeviceSpeechRecognizer` (API 33+) or `createSpeechRecognizer` + `EXTRA_PREFER_OFFLINE` (API 29-32) | No (standard permissions) | No (foreground only) |
| NotificationBridge (scheduling) | **A — Expo API** | Schedule/cancel local notifications | expo-notifications wraps `UNUserNotificationCenter` | expo-notifications wraps `AlarmManager` + `NotificationManager` | No | N/A |
| NotificationBridge (query scheduled) | **C — Custom Expo Module** | `getScheduledIds()` for reconciliation | `UNUserNotificationCenter.getPendingNotificationRequests()` | Query `AlarmManager` pending intents | No | No |
| NotificationBridge (reconciliation) | **B + C hybrid** | Compare DB vs OS, fix discrepancies | TypeScript logic + custom native query bridge | TypeScript logic + custom native query bridge | No | No |
| iOS Notification Service Extension | **D — Direct native iOS** | Handle notification actions while app killed | Swift: raw SQLite UPDATE on shared App Group database, schema version guard, optimistic locking | N/A | **Yes** (extension target, entitlements, Info.plist) | This IS the extension |
| Android NotificationActionReceiver | **E — Direct native Android** | Handle notification actions while app killed | N/A | Kotlin: `BroadcastReceiver`, raw SQLite UPDATE via shared database path | **Yes** (manifest registration) | This IS the receiver |
| Android BootReceiver | **E — Direct native Android** | Re-schedule alarms after reboot | N/A | Kotlin: raw SQLite query → `AlarmManager` re-schedule | **Yes** (manifest registration) | This IS the receiver |
| Android ReconciliationWorker | **E — Direct native Android** | Daily reconciliation | N/A | Kotlin: `CoroutineWorker`, raw SQLite query → reconcile alarms | **Yes** (WorkManager init) | This IS the worker |
| ContactBridge | **A — Expo API** | Contact name → phone number resolution | expo-contacts wraps `CNContactStore` | expo-contacts wraps `ContactsContract` | No | No |
| ActionBridge | **A — Expo API** | Launch dialer, SMS, browser | expo-linking / react-native `Linking.openURL()` | Same | No | No |
| Shared SQLite access (extension) | **D/E — Direct native** | Extension/app read/write same database | Swift: raw sqlite3_open on App Group path, WAL mode | Kotlin: raw SQLiteOpenHelper on shared path, WAL mode | **Yes** (App Group entitlements) | Yes |

**Total custom native modules required:** 5 (SpeechBridge via Expo Modules API, NotificationQueryBridge via Expo Modules API, iOS Notification Service Extension, Android NotificationActionReceiver, Android BootReceiver + ReconciliationWorker)

---

## 4. ARCHITECTURE MAPPING

| Current Architecture (Flutter) | React Native/Expo Equivalent | Change Required? |
|---|---|---|
| **UI Layer** — Flutter Widgets, Riverpod | React Native components, React hooks, React Navigation | **Complete rewrite** |
| **UI State Management** — Riverpod | Zustand (recommended) or Redux Toolkit | **Rewrite** |
| **Application Layer** — Use Cases (Dart) | TypeScript use cases (same patterns) | **Transpile with minor syntax changes** |
| **Domain Layer** — Entities, Value Objects, Enums (Dart) | TypeScript types/interfaces/enums | **Minimal change** (syntax only) |
| **Domain Layer** — NLP Pipeline (Dart pure functions) | TypeScript pure functions | **Transpile** (regex is compatible, Date API differs slightly) |
| **Domain Layer** — State Machine (Dart sealed classes) | TypeScript discriminated unions | **Rewrite** (TypeScript pattern matching less ergonomic) |
| **Domain Layer** — Conflict Detection (pure functions) | TypeScript pure functions | **Transpile** |
| **Data Layer** — Drift ORM + `.drift` files | expo-sqlite with handwritten SQL + repository pattern | **Rewrite** (Drift's type-safe queries → raw SQL or Kysely/Drizzle) |
| **Data Layer** — Repository interface + DriftImpl | Repository interface + expo-sqlite implementation | **Rewrite** |
| **Data Layer** — Optimistic locking (SQL WHERE version=) | Same SQL pattern (database-agnostic) | **Transpile** |
| **Data Layer** — Database migrations | expo-sqlite `onInit` callback or manual migration framework | **Rewrite** |
| **Data Layer** — Integrity check (`PRAGMA integrity_check`) | Same SQL (database-agnostic) | **Transpile** |
| **Platform Bridges** — Flutter MethodChannel | Expo Modules API + React Native NativeModules | **Rewrite** (same native code, different bridge API) |
| **Dependency Injection (foreground)** — Riverpod | Zustand stores with manual DI or React Context | **Rewrite** |
| **Dependency Injection (background)** — BackgroundServiceLocator | Manual service locator (same pattern, JS) | **Transpile** |
| **iOS Notification Extension** — Swift + raw SQLite | Same Swift + raw SQLite | **No native code change** (only bridge registration differs) |
| **Android Receivers/Workers** — Kotlin + raw SQLite | Same Kotlin + raw SQLite | **No native code change** (only bridge registration differs) |
| **Testing** — flutter_test, mocktail | Jest, React Native Testing Library, jest-mock | **Rewrite** |

---

## 5. DOMAIN LAYER — Migration Assessment

### Can move essentially unchanged: YES

**Entities, value objects, enums:**
Dart classes with immutable fields → TypeScript `interface`/`type` with `readonly`. Near-zero conceptual change.

```typescript
// Example: Reminder entity
// Dart: class Reminder { final String id; final ReminderStatus status; ... }
// TypeScript:
interface Reminder {
  readonly id: string;
  readonly status: ReminderStatus;
  readonly title: string;
  readonly triggerTime: Date;
  // ...
}
```

**State machine:**
Dart sealed classes + pattern matching → TypeScript discriminated unions + switch. Less ergonomic but functionally identical.

**NLP pipeline (5 stages):**
Pure functions with injectable `Clock` → identical in TypeScript. Regex patterns are compatible. Date manipulation uses `date-fns` instead of Dart `DateTime`.

**Clock interface:**
```typescript
// Dart: abstract class Clock { DateTime now(); String localTimezone(); }
// TypeScript:
interface Clock {
  now(): Date;
  localTimezone(): string;
}
```

**Verdict:** The domain layer is the STRONGEST case for migration. It is pure logic, platform-agnostic, and would require minimal restructuring.

---

## 6. APPLICATION LAYER — Migration Assessment

All defined use cases can be implemented in TypeScript with the same patterns:

| Use Case | Migration Difficulty | Notes |
|---|---|---|
| CreateReminderUseCase | LOW | Orchestration pattern identical; async/await compatible |
| CompleteReminderUseCase | LOW | Same state machine call + repository + bridge pattern |
| SnoozeReminderUseCase | LOW | Same |
| DeleteReminderUseCase | LOW | Same |
| EditReminderUseCase | LOW | Same |
| HandleNotificationActionUseCase | MEDIUM | Must handle both JS context (foreground/background) and native-only (extension/receiver) paths |
| ReconcileNotificationsUseCase | MEDIUM | TypeScript logic identical; native query bridge needed |
| DetectConflictsUseCase | LOW | Pure function, same as domain |
| ResolveContactsUseCase | LOW | Wraps expo-contacts instead of custom ContactBridge |

**Verdict:** Application layer migrates cleanly. The only complication is `HandleNotificationActionUseCase` which now has TWO execution paths: JavaScript (when app is alive) vs. native (when app is killed — same Swift/Kotlin code as Flutter).

---

## 7. DATABASE — Migration Assessment

### Selected approach: expo-sqlite (main app) + raw SQLite (native extension/receivers)

**Why expo-sqlite:**
- First-party Expo module; maintained by Expo team
- Supports prepared statements (`prepareSync`/`executeSync`)
- Supports custom database directory (needed for App Group path on iOS)
- Migration support via `onInit` callback in `SQLiteProvider`
- `backupDatabaseAsync` works with WAL mode
- Cross-platform (iOS, Android)

**What expo-sqlite does NOT provide (requires custom native code):**
- WAL mode is not explicitly configurable (likely default, but must verify)
- `busy_timeout` pragma must be set manually
- No Drift-equivalent type-safe query builder (must write raw SQL or use a wrapper like Drizzle ORM)
- No built-in optimistic locking helper (same SQL pattern, different helper)

**Architectural requirements check:**

| Requirement | expo-sqlite Support | Notes |
|---|---|---|
| Transactions | ✅ `execAsync` with `BEGIN/COMMIT` or `withTransactionAsync` | |
| Migrations | ✅ `onInit` callback in `SQLiteProvider` | Manual SQL-based migrations |
| Concurrency | ✅ WAL mode (via pragma on init) | Must explicitly set `PRAGMA journal_mode=WAL` |
| Optimistic locking | ✅ Same SQL pattern (`WHERE version = :expectedVersion`) | Application-level, not ORM-level |
| Background access (main app) | ✅ JavaScript thread | |
| Background access (native extension) | ❌ Requires raw SQLite in Swift/Kotlin | Same as Flutter architecture |
| Reliability (integrity check) | ✅ `PRAGMA integrity_check` | |
| Offline operation | ✅ | |
| Testability | ✅ In-memory database option | |

**Database compatibility concern:** The iOS Notification Service Extension must access the SAME database file as the main app. expo-sqlite stores databases at a configurable path. By pointing both the main app (via `directory` param) and the extension (via raw SQLite in Swift) to the App Group shared container path, cross-process access is achieved — EXACTLY the same pattern as the Flutter architecture.

---

## 8. STATE MANAGEMENT — Recommendation

### Recommended: Zustand

**Why not Redux Toolkit:**
Katala's state is relatively simple (timeline of reminders, UI state for voice input). Redux Toolkit adds ceremony (slices, reducers, actions, selectors) disproportionate to the complexity.

**Why not React Context:**
Context triggers re-renders of all consumers on any change. Katala's timeline with many reminders would perform poorly. Context is inappropriate for frequently-updating data.

**Why Zustand:**
- Minimal API surface (create → get/set)
- No boilerplate (no actions, reducers, dispatch)
- Selective re-rendering (components subscribe to slices)
- Works outside React (background service locator compatibility)
- Tiny bundle size (< 1KB)
- TypeScript-first

**Zustand store sketch (equivalent to Riverpod providers):**

```typescript
interface ReminderStore {
  pendingReminders: Reminder[];
  overdueReminders: Reminder[];
  speechAvailability: SpeechAvailability;
  // Actions
  loadReminders: () => Promise<void>;
  setSpeechAvailability: (status: SpeechAvailability) => void;
}
```

**Dependency injection:** Manual service locator pattern for background contexts (identical to Flutter's `BackgroundServiceLocator`). For foreground, pass dependencies via Zustand store actions or a simple React Context for singleton services (database, bridges).

---

## 9. SPEECH ARCHITECTURE — Critical Section

### Expo has NO speech-to-text module

**Documentation checked:** `/expo/expo` — `expo-speech` is confirmed as text-to-speech (TTS) only. No `expo-speech-to-text` or equivalent exists.

**Third-party candidate: `@react-native-voice/voice`**

| Requirement | Support | Notes |
|---|---|---|
| on-device-only enforcement (iOS) | ❌ NOT EXPOSED | Library does not expose `requiresOnDeviceRecognition` parameter. Would need fork or custom module. |
| on-device preference (Android) | ❌ NOT EXPOSED | Library does not expose `EXTRA_PREFER_OFFLINE`. On Android, uses default system recognizer which may use cloud. |
| Partial results | ✅ `onSpeechPartialResults` | |
| Final results | ✅ `onSpeechResults` | |
| Start/stop/cancel | ✅ `Voice.start()`, `Voice.stop()`, `Voice.cancel()` | |
| Silence timeout | ❌ Manual implementation needed | |
| Audio session management | ❌ Manual implementation needed | |
| Error handling | ✅ `onSpeechError` | |

**Verdict:** `react-native-voice` CANNOT satisfy Katala's requirement CC-6 (on-device-only speech recognition). A custom Expo Module is required.

### Proposed TypeScript interface (custom Expo Module):

```typescript
// NativeSpeechModule.ts — Expo Modules API
import { requireNativeModule } from 'expo-modules-core';

interface SpeechAvailability {
  available: boolean;
  isOnDevice: boolean;
  reason?: string;
}

interface NativeSpeechModule {
  readonly isOnDeviceAvailable: boolean;
  startListening(silenceTimeout: number): Promise<void>;
  stopListening(): Promise<string>;
  cancelListening(): Promise<void>;
  getAvailability(): Promise<SpeechAvailability>;
  addListener(event: 'onPartialResult', listener: (text: string) => void): void;
  addListener(event: 'onFinalResult', listener: (text: string) => void): void;
  addListener(event: 'onError', listener: (error: string) => void): void;
}

export const NativeSpeech = requireNativeModule<NativeSpeechModule>('NativeSpeech');
```

**iOS implementation (Swift via Expo Modules API):**
```swift
// Uses SFSpeechRecognizer with requiresOnDeviceRecognition = true
// Same core logic as Flutter's SpeechBridgeImpl.swift
```

**Android implementation (Kotlin via Expo Modules API):**
```kotlin
// Uses SpeechRecognizer.createOnDeviceSpeechRecognizer (API 33+)
// or createSpeechRecognizer with EXTRA_PREFER_OFFLINE (API 29-32)
// Same core logic as Flutter's SpeechBridgeImpl.kt
```

---

## 10. NOTIFICATION ARCHITECTURE — Critical Section

### Complete flow analysis:

```
Database (expo-sqlite / raw SQLite)
    ↓
Notification Scheduler (expo-notifications scheduleNotificationAsync + custom native for getScheduledIds)
    ↓
OS notification (iOS UNNotificationRequest / Android AlarmManager + Notification)
    ↓
Notification Action (two paths):
    ├── App alive: expo-notifications addNotificationResponseReceivedListener → JS → use case → DB
    └── App killed:
         ├── iOS: Notification Service Extension (Swift, raw SQLite) → DB
         └── Android: NotificationActionReceiver (Kotlin, raw SQLite) → DB
    ↓
Database (same SQLite file)
```

### Expo notifications coverage:

| Capability | expo-notifications | Custom Native Required? |
|---|---|---|
| Schedule local notification (date trigger) | ✅ `scheduleNotificationAsync` with `DATE` trigger | No |
| Cancel notification by ID | ✅ `cancelScheduledNotificationAsync` | No |
| Notification categories (action buttons) | ✅ `setNotificationCategoryAsync` | No |
| Notification action identifiers | ✅ `NotificationAction.identifier` | No |
| Handle notification response (app alive) | ✅ `addNotificationResponseReceivedListener` | No |
| Handle notification response (app killed, iOS) | ❌ Requires Notification Service Extension | **Yes** |
| Handle notification response (app killed, Android) | ❌ Requires BroadcastReceiver | **Yes** |
| Get list of scheduled notification IDs | ❌ Not exposed | **Yes** (custom bridge) |
| Reconciliation (cancel orphans, schedule missing) | Partial (TypeScript logic + custom bridge for query) | **Yes** (custom bridge for OS query) |
| iOS 64-notification limit handling | ❌ Must implement priority queue | Application logic (TypeScript) |
| Notification dismissal | ✅ `dismissNotificationAsync` | No |

### Critical finding — app-killed notification actions:

**Documentation checked:** `/websites/expo_dev_versions_sdk_notifications`

Expo's `registerTaskAsync` documentation states: *"When the app is terminated, only Headless Background Notifications will trigger the task."*

"Headless Background Notifications" are **remote push notifications**, NOT local scheduled notifications. This means **Expo cannot handle local notification action taps while the app is killed** using JavaScript alone.

**The iOS Notification Service Extension and Android BroadcastReceiver remain REQUIRED** — same as the Flutter architecture. The native Swift/Kotlin code for these components is effectively identical; only the bridge registration mechanism changes (Flutter MethodChannel → Expo Modules API or direct native code).

### Idempotency guarantee:
Same as Flutter: `scheduleNotificationAsync` cancels existing notification for same identifier before scheduling (documented behavior). Notification ID mapping stored in `app_metadata` table.

---

## 11. iOS ARCHITECTURE

### Components and execution contexts:

| Component | Execution Context | Technology | Expo Support |
|---|---|---|---|
| Main App | Foreground / Background JS | React Native + Expo | ✅ Full |
| Speech Module | Foreground native | Custom Expo Module (Swift) | ✅ Expo Modules API |
| Notification Scheduling | Main app (JS → native) | expo-notifications | ✅ |
| Notification Service Extension | **Separate process, no JS** | Swift, raw SQLite | ❌ Requires custom native target + config plugin |
| BGAppRefreshTask | Background native → launches JS | expo-background-task | ✅ Partial (best-effort) |
| Shared SQLite (App Group) | Both main app + extension | expo-sqlite (main) + raw SQLite (extension) | ✅ Partial (config plugin for entitlements) |

### Config plugin requirements for iOS:

```typescript
// app.config.ts — custom config plugin
import { withEntitlementsPlist, withInfoPlist, withXcodeProject } from 'expo/config-plugins';

const withKatalaIos = (config) => {
  // 1. App Group entitlements
  config = withEntitlementsPlist(config, (cfg) => {
    cfg.modResults['com.apple.security.application-groups'] = ['group.com.katala.app'];
    return cfg;
  });

  // 2. Info.plist keys
  config = withInfoPlist(config, (cfg) => {
    cfg.modResults.NSMicrophoneUsageDescription = 'Katala needs microphone access...';
    cfg.modResults.NSContactsUsageDescription = 'Katala uses contacts...';
    cfg.modResults.NSSpeechRecognitionUsageDescription = 'Katala uses speech recognition...';
    cfg.modResults.UIBackgroundModes = ['audio', 'fetch'];
    return cfg;
  });

  // 3. Notification Service Extension target (experimental EAS support)
  // Declared in app.json extra.eas.build.experimental.ios.appExtensions
  // OR: manual Xcode project modification

  return config;
};
```

### iOS assessment:
Expo config plugins can handle Info.plist, entitlements, and basic Xcode project modifications. However, adding a Notification Service Extension target is **experimental** in EAS/CNG. For production reliability, manual Xcode target setup may be necessary — which means the "Expo handles all native config" promise doesn't fully hold for Katala.

---

## 12. ANDROID ARCHITECTURE

| Component | Execution Context | Technology | Expo Support |
|---|---|---|---|
| Main App | Foreground / Background JS | React Native + Expo | ✅ Full |
| Speech Module | Foreground native | Custom Expo Module (Kotlin) | ✅ Expo Modules API |
| Notification Scheduling | Main app (JS → native) | expo-notifications → AlarmManager | ✅ |
| NotificationActionReceiver | **Separate process, no JS** | Kotlin, raw SQLite | ❌ Requires custom native + manifest registration |
| BootReceiver | **System broadcast, no JS** | Kotlin, raw SQLite | ❌ Requires custom native + manifest registration |
| ReconciliationWorker | **WorkManager, no JS** | Kotlin, raw SQLite | ❌ Requires custom native + manifest registration |
| Exact Alarm permission | Foreground | expo-notifications handles | ✅ |

### Android assessment:
Android's background execution model (receivers, workers) is inherently native. Expo provides no JavaScript-based equivalent for `BOOT_COMPLETED` or `WorkManager` periodic tasks. These remain pure Kotlin implementations — identical to the Flutter architecture.

---

## 13. GEOFENCING

### Current status: Post-MVP (NOT in MVP scope)

Per KATALA_SPEC_V3.md §4.2: "Geofencing / location-based reminders (Post-MVP)."

**When implemented:** expo-location's `startGeofencingAsync` is documented and supported on both platforms. It integrates with `TaskManager` for background geofence events.

**Documentation checked:** `/expo/expo` — `expo-location` `LocationModule.kt`/`LocationModule.swift`

**Conclusion:** Geofencing is a non-issue for the MVP migration decision. When Post-MVP geofencing is needed, expo-location provides a viable Expo-native path.

---

## 14. BACKGROUND EXECUTION — High-Risk Area

### Every background entry point traced:

| Entry Point | Trigger | JS Running? | App Process? | DB Init | Expo Support | Same as Flutter? |
|---|---|---|---|---|---|---|
| Notification action (app backgrounded) | User taps notification action | ✅ Yes (JS context alive) | ✅ Yes | expo-sqlite | ✅ (addNotificationResponseReceivedListener) | Similar |
| iOS Notification Service Extension | User taps action while app killed | ❌ No JS | ❌ Separate extension process | Raw SQLite (Swift) | ❌ Custom native | **Identical** |
| Android NotificationActionReceiver | User taps action while app killed | ❌ No JS | ❌ Separate BroadcastReceiver | Raw SQLite (Kotlin) | ❌ Custom native | **Identical** |
| Android BOOT_COMPLETED | Device reboot | ❌ No JS | ❌ Separate receiver | Raw SQLite (Kotlin) | ❌ Custom native | **Identical** |
| Android WorkManager | 24h periodic | ❌ No JS | ❌ Separate worker | Raw SQLite (Kotlin) | ❌ Custom native | **Identical** |
| iOS BGAppRefreshTask | Periodic (best-effort) | ✅ Yes (launches JS) | ✅ Yes | expo-sqlite | ✅ (expo-background-task) | Similar |
| Foreground reconciliation | User opens app | ✅ Yes | ✅ Yes | expo-sqlite | ✅ | Similar |

**Key insight:** Four of seven background entry points execute NO JavaScript — they are pure native Swift/Kotlin. This is not an Expo limitation; it is a platform reality on both iOS and Android. Expo cannot "fix" this because the OS itself does not allow JavaScript execution in these contexts (Notification Service Extensions, BroadcastReceivers, WorkManager workers).

The Flutter architecture handles these identically: native code with raw SQLite access.

---

## 15. OFFLINE AND PRIVACY

### Risk assessment:

| Risk | Expo/RN Status | Mitigation |
|---|---|---|
| Network requests from Expo services | ✅ None | Expo's `expo-updates` (OTA updates) is opt-in; not included unless explicitly added |
| Cloud APIs in Expo modules | ✅ None | expo-notifications local-only mode does not require Expo push servers; expo-speech is TTS (not relevant); expo-sqlite is local |
| Analytics / telemetry | ✅ None | Expo does not include analytics by default; `expo-analytics` is opt-in |
| Runtime font downloads | ✅ Bundled | Inter font bundled as asset; no `expo-google-fonts` runtime fetching |
| Crash reporting | ✅ None | `expo-crashlytics` is opt-in; not included |
| expo-updates (OTA) | ⚠️ OPT-IN RISK | Must NOT be added; Katala has no server to serve updates from |
| EAS Build | ✅ Build-time only | No runtime component |

**Verdict:** Expo does not introduce forced network dependencies. The same privacy guarantees as the Flutter implementation can be maintained — provided `expo-updates` is NOT added and no Expo services requiring network are configured.

---

## 16. TESTING

| Test Type | Flutter Approach | React Native/Expo Approach | Runs on Windows? |
|---|---|---|---|
| Domain unit tests | `flutter test` (Dart VM) | Jest / Vitest | ✅ Yes |
| NLP corpus tests | `flutter test` | Jest / Vitest | ✅ Yes |
| Database integration tests | In-memory Drift | In-memory expo-sqlite or mock | ✅ Yes (with mock) |
| React component tests | Widget tests (`flutter_test`) | React Native Testing Library + Jest | ✅ Yes |
| Native module tests | Manual device tests | Manual device tests | ❌ No (requires device/simulator) |
| iOS device tests | Xcode + real device | Same | ❌ No (requires macOS + device) |
| Android device tests | Android Studio + real device | Same | ✅ Yes (requires device, not OS) |
| Notification tests | Manual device | Same | ❌ No |
| Background execution tests | Manual device | Same | ❌ No |

**Development environment:**

| Activity | Windows | macOS |
|---|---|---|
| TypeScript development | ✅ Full | ✅ Full |
| Android build + test | ✅ Full | ✅ Full |
| iOS build + test | ❌ Not possible | ✅ Required (Xcode) |
| iOS extension development | ❌ Not possible | ✅ Required |
| Production iOS build | ❌ Not possible | ✅ Required |
| Production Android build | ✅ Full | ✅ Full |

---

## 17. TASK MIGRATION

### Summary mapping (82 tasks from TASKS.md):

| Phase | Tasks | Migration Action |
|---|---|---|
| Phase 0 — Project Foundation (TASK-001 to 006) | 6 tasks | **REPLACE**: `flutter create` → `npx create-expo-app`; `pubspec.yaml` → `package.json`; Drift deps → expo-sqlite, Zustand deps; Flutter CI → Expo/RN CI |
| Phase 1 — Domain Foundation (TASK-010 to 015) | 6 tasks | **MODIFY**: Dart → TypeScript; same concepts, different syntax |
| Phase 2 — Persistence (TASK-020 to 024) | 5 tasks | **REPLACE**: Drift schema → expo-sqlite schema; Drift DAOs → handwritten SQL repositories; Drift migrations → expo-sqlite `onInit` |
| Phase 3 — NLP (TASK-030 to 036) | 7 tasks | **MODIFY**: Dart → TypeScript transpilation; regex compatible; Date API changes |
| Phase 4 — Bridge Interfaces (TASK-040 to 044) | 5 tasks | **REPLACE**: Flutter MethodChannel interfaces → Expo Modules API + TypeScript interfaces |
| Phase 5 — Application Layer (TASK-050 to 059) | 10 tasks | **MODIFY**: Dart → TypeScript; use case patterns identical |
| Phase 6 — iOS Native (TASK-060 to 066) | 7 tasks | **MODIFY**: Same Swift code; Flutter MethodChannel → Expo Modules API registration |
| Phase 7 — Android Native (TASK-070 to 078) | 9 tasks | **MODIFY**: Same Kotlin code; Flutter MethodChannel → Expo Modules API registration |
| Phase 8 — UI (TASK-080 to 093) | 14 tasks | **REPLACE**: Flutter widgets → React Native components; completely new implementation |
| Phase 9 — Vertical Slice (TASK-100 to 102) | 3 tasks | **REPLACE**: Integration test setup differs |
| Phase 10 — Notification Hardening (TASK-110 to 113) | 4 tasks | **MODIFY**: Same reconciliation logic; different notification API calls |
| Phase 11 — Testing (TASK-120 to 125) | 6 tasks | **REPLACE**: Flutter test framework → Jest/RNTL |
| Phase 12 — Release (TASK-130 to 133) | 4 tasks | **REPLACE**: Flutter build → EAS Build; same signing/privacy requirements |

**Task migration summary:**

| Action | Count | Notes |
|---|---|---|
| Tasks that remain unchanged (conceptually) | 0 | Every task requires at least syntax changes |
| Tasks that require MODIFY (same logic, different language) | ~40 | Domain, NLP, Application, Native (same Swift/Kotlin) |
| Tasks that must be REPLACED (completely different) | ~42 | UI (14), Foundation (6), Persistence (5), Bridge Interfaces (5), Testing (6), Release (4), Integration (3) |
| New tasks required | ~5 | Expo config plugin development, expo-sqlite schema definition, React Navigation setup, EAS Build configuration, Zustand store setup |
| Tasks that become unnecessary | 0 | All 82 tasks have equivalents |

---

## 18. DEPENDENCY AUDIT — Proposed Stack

### Core TypeScript dependencies:

| Package | Purpose | Why Required | Network at Runtime? |
|---|---|---|---|
| `react` / `react-native` | UI framework | Core technology | No |
| `expo` | Build tooling + SDK | Core technology | No (build-time only) |
| `typescript` | Type safety | Development | No |
| `zustand` | State management | DI + reactive state | No |
| `date-fns` | Date manipulation | Temporal resolution | No |
| `uuid` | ID generation | Reminder primary keys | No |
| `zod` (optional) | Runtime validation | NLP output validation | No |

### Expo dependencies:

| Package | Purpose | Required? | Network at Runtime? |
|---|---|---|---|
| `expo-sqlite` | SQLite database | **Yes** | No |
| `expo-notifications` | Local notifications | **Yes** | No (local mode) |
| `expo-contacts` | Contact resolution | **Yes** | No |
| `expo-linking` | URL/dialer/SMS launching | **Yes** | No |
| `expo-task-manager` | Background task registration | **Yes** | No |
| `expo-background-task` | Background fetch | **Yes** | No |
| `expo-location` | Geofencing (Post-MVP) | Post-MVP only | No |
| `expo-font` | Bundled font loading | **Yes** | No |
| `expo-haptics` | Haptic feedback | Recommended | No |
| `expo-device` | Device info (diagnostics) | Optional | No |

### Native modules:

| Module | Purpose | Platform | Network at Runtime? |
|---|---|---|---|
| `NativeSpeech` (custom Expo Module) | On-device STT | iOS + Android | No |
| `NativeNotificationQuery` (custom Expo Module) | Query scheduled notification IDs | iOS + Android | No |
| `KatalaNotificationExtension` (iOS target) | Handle notification actions while killed | iOS only | No |
| `NotificationActionReceiver` (Android) | Handle notification actions while killed | Android only | No |
| `BootReceiver` (Android) | Re-schedule alarms after reboot | Android only | No |
| `ReconciliationWorker` (Android) | Daily reconciliation | Android only | No |

### Development dependencies:

| Package | Purpose |
|---|---|
| `jest` | Test runner |
| `@testing-library/react-native` | Component testing |
| `eslint` + `prettier` | Linting + formatting |
| `eas-cli` | EAS Build submission |

---

## 19. ARCHITECTURE PRESERVATION

### What CAN remain conceptually unchanged:

| Architectural Boundary | Preserved? | Notes |
|---|---|---|
| Database as authoritative state | ✅ Yes | Same pattern; DB writes before notification scheduling |
| OS notifications as derived state | ✅ Yes | Reconciliation rebuilds OS state from DB |
| Deterministic NLP | ✅ Yes | Pure TypeScript functions; same algorithm |
| Platform isolation | ✅ Yes | Same bridge abstraction; Expo Modules API is conceptually similar |
| Domain layer: zero platform imports | ✅ Yes | TypeScript domain has no React/Expo/RN imports |
| Repository pattern | ✅ Yes | Interface + expo-sqlite implementation |
| Optimistic locking | ✅ Yes | Same SQL pattern |
| Notification-as-derived-state | ✅ Yes | Reconciliation logic identical |
| Background service locator (non-Riverpod) | ✅ Yes | Same static locator pattern in TypeScript |
| Offline guarantees | ✅ Yes | Same architecture; Expo doesn't add network dependencies |
| Testing strategy (pyramid) | ✅ Yes | Same layers; different tools |
| No cloud services | ✅ Yes | Same constraint |
| No telemetry | ✅ Yes | Same constraint |

### What MUST change:

| Change | Reason |
|---|---|
| UI framework: Flutter → React Native | Framework replacement |
| State management: Riverpod → Zustand | Ecosystem change |
| ORM: Drift → expo-sqlite + handwritten SQL | No Drift equivalent in RN ecosystem |
| Bridge API: MethodChannel → Expo Modules API | Native module registration mechanism differs |
| Build system: Flutter build → EAS Build / expo prebuild | Build pipeline differs |
| Language: Dart → TypeScript | Entire codebase language change |

---

## 20. RISK REGISTER

| Risk | Severity | Likelihood | Mitigation | Blocking? |
|---|---|---|---|---|
| **iOS Notification Service Extension in Expo** | CRITICAL | MEDIUM | iOS app extensions are experimental in EAS/CNG. Manual Xcode project management may be needed, negating Expo's abstraction benefit. | **Yes** — if extension can't be reliably built/deployed, MVP is blocked |
| **On-device speech enforcement** | CRITICAL | LOW | Custom Expo Module can set `requiresOnDeviceRecognition = true` (iOS) and `createOnDeviceSpeechRecognizer` (Android 13+). Well-documented APIs. | No (solvable with custom module) |
| **Android OEM background kill** | HIGH | HIGH | Same risk as Flutter. Expo provides no additional mitigation. Katala's multi-layer reliability strategy applies identically. | No (inherent platform limitation) |
| **expo-sqlite WAL mode + App Group compatibility** | HIGH | LOW | expo-sqlite uses native SQLite. WAL can be enabled via pragma. Custom `directory` param supports App Group path. Must be tested. | No (should work) |
| **Shared database between JS and native extension** | HIGH | MEDIUM | Same as Flutter architecture. WAL mode + busy_timeout + schema version guard. Proven pattern. | No (proven architecture) |
| **Expo SDK upgrade cadence** | MEDIUM | MEDIUM | Expo releases new SDKs quarterly. Katala's custom native modules must be compatible. Delayed upgrades acceptable. | No (can pin SDK version) |
| **Notification category mismatch** | MEDIUM | LOW | Same coordination problem as Flutter: Expo categories must match native extension categories. Integration test catches this. | No (testable) |
| **React Native performance (NLP on JS thread)** | MEDIUM | LOW | NLP is fast regex (< 50ms). Can run off main thread via `InteractionManager` or a simple worker. | No |
| **Flutter → RN learning curve for team** | LOW | N/A | Not applicable (analysis assumes team proficiency in both) | No |

### Top 5 Biggest Risks:

1. **iOS Notification Service Extension stability in Expo's CNG/EAS pipeline** — Experimental support for additional Xcode targets. If broken, requires manual Xcode management, defeating Expo's value proposition.
2. **On-device speech recognition enforcement** — Custom Expo Module required; `react-native-voice` insufficient. Development cost of custom native module.
3. **Android OEM background reliability** — Platform limitation, not framework-dependent. Same mitigation strategies apply. No improvement over Flutter.
4. **Shared database cross-process access** — Same architecture as Flutter. Risk is in expo-sqlite's WAL mode behavior with external native SQLite connections. Needs verification.
5. **Total rewrite cost** — 82 tasks, ~42 require complete replacement (especially UI). Domain/NLP/App layer code translatable but still requires manual effort.

---

## 21. MIGRATION COST — Qualitative

| Subsystem | Complexity | Rationale |
|---|---|---|
| Domain layer (entities, enums, state machine) | **LOW** | Near 1:1 Dart → TypeScript transpilation. Pure logic. |
| NLP pipeline (5 stages + corpus) | **LOW** | Regex-compatible; Date API changes only. Corpus is data, not code. |
| Application layer (use cases) | **LOW** | Same orchestration patterns. Async/await identical. |
| Data layer (repositories, migrations) | **MEDIUM** | Drift → expo-sqlite rewrite. SQL logic preserved; wrapper code different. |
| Platform bridges (TypeScript interfaces) | **MEDIUM** | Interface definitions translatable. Expo Modules API vs MethodChannel registration differs. |
| Native iOS code (bridges + extension) | **LOW** | Swift code is IDENTICAL. Only bridge registration (MethodChannel → Expo Modules API) changes. |
| Native Android code (bridges + receivers) | **LOW** | Kotlin code is IDENTICAL. Only bridge registration changes. |
| UI layer (screens, widgets, navigation) | **VERY HIGH** | Complete rewrite. Flutter widget tree → React component tree. Different layout, animation, navigation paradigms. 14 tasks' worth. |
| State management (Riverpod → Zustand) | **MEDIUM** | Zustand is simpler. Provider graph → flat stores. Less ceremony. |
| Testing infrastructure | **HIGH** | Different frameworks (flutter_test → Jest/RNTL). Test files must be rewritten even when logic is same. |
| Build & release pipeline | **MEDIUM** | EAS Build replaces Flutter build. Similar signing/entitlement requirements. |
| iOS config (extensions, App Groups) | **MEDIUM** | Config plugins can automate most but not all. Extension target may need manual Xcode work. |

---

## 22. FINAL RECOMMENDATION

### Verdict: MIGRATION NOT RECOMMENDED

### Why:

1. **Native code surface is IDENTICAL.** Katala's three most architecturally demanding features — on-device speech recognition, notification action handling while killed, and shared SQLite across app/extension — ALL require custom native Swift/Kotlin code regardless of framework. The Swift/Kotlin code itself changes minimally (only the bridge registration layer). Expo does not eliminate a single line of native code from Katala's critical path.

2. **Expo's value-add is misaligned with Katala's difficulty profile.** Expo excels at: permissions, build configuration, and standard native APIs (camera, location, contacts). Katala's hard problems are: iOS Notification Service Extensions, Android BroadcastReceivers, on-device-only speech enforcement, and cross-process SQLite. Expo provides the LEAST help in these areas.

3. **The iOS Notification Service Extension is experimental in Expo's build pipeline.** EAS/CNG support for additional Xcode targets (like a Notification Service Extension) is marked experimental. This is a P0 requirement for Katala. If Expo's tooling can't reliably build/deploy the extension, the project would need to maintain a bare workflow — eliminating most of Expo's benefits.

4. **The migration cost is dominated by the UI layer rewrite.** Of 82 tasks, ~42 require complete replacement (not adaptation). The 14 UI tasks alone represent a VERY HIGH complexity effort. The domain/application/native code that would benefit from TypeScript unity (LOW complexity to migrate) is outweighed by the UI and infrastructure rewrites.

5. **The business case does not close.** The stated motivation is replacing Flutter with React Native + Expo. The benefits would be:
   - Single language (TypeScript) across all layers — **real but modest** (Dart is already a single language across Flutter)
   - Expo's build tooling — **real for simpler apps, but Katala pushes Expo's boundaries**
   - React Native ecosystem — **real, but Katala uses few third-party packages by design**
   
   The costs would be:
   - Complete UI rewrite (14 tasks, VERY HIGH complexity)
   - Data layer rewrite (5 tasks, MEDIUM complexity)
   - Testing infrastructure rewrite (6 tasks, HIGH complexity)
   - Risk of iOS extension instability in Expo pipeline (CRITICAL severity)
   - Zero reduction in native code surface

### If migration were undertaken despite this recommendation:

The most defensible approach would be:
1. Keep the Flutter app as the production implementation
2. Extract the domain layer (entities, NLP, state machine) into a shared TypeScript package
3. Use this shared package to prototype a React Native UI
4. If the RN UI proves superior, then migrate the remaining layers

This incremental approach would validate the key risk areas (iOS extension in Expo, custom speech module) before committing to a full rewrite.

---

## 23. WHAT CAN STAY UNCHANGED

| Component | Migration Impact |
|---|---|
| iOS Notification Service Extension Swift code | **Unchanged** (only bridge registration differs) |
| Android NotificationActionReceiver Kotlin code | **Unchanged** |
| Android BootReceiver Kotlin code | **Unchanged** |
| Android ReconciliationWorker Kotlin code | **Unchanged** |
| NLP pipeline algorithm (5 stages) | **Unchanged** (transpile to TypeScript) |
| State machine transitions and guards | **Unchanged** (transpile to TypeScript) |
| Conflict detection logic | **Unchanged** (transpile to TypeScript) |
| Database schema (tables, constraints) | **Unchanged** (same SQL) |
| Optimistic locking strategy | **Unchanged** (same SQL pattern) |
| Reconciliation algorithm | **Unchanged** (transpile to TypeScript) |
| Notification category definitions | **Unchanged** (same identifiers) |
| App Group identifier and entitlements | **Unchanged** |
| Privacy guarantees | **Unchanged** |
| Offline architecture | **Unchanged** |
| Testing strategy (pyramid shape) | **Unchanged** (different tools, same layers) |
| UI design tokens (colors, typography) | **Unchanged** (apply to RN theme) |
| NLP test corpus | **Unchanged** (data, not code) |

---

## 24. REQUIRED ARCHITECTURE CHANGES (if migration proceeds)

1. **Data layer:** Drift ORM → expo-sqlite with handwritten SQL repositories. Type-safe queries lost; must implement manual type mapping.
2. **State management:** Riverpod Provider graph → Zustand flat stores. Background service locator pattern unchanged.
3. **Bridge layer:** Flutter MethodChannel contracts → Expo Modules API + React Native NativeModules. Same native code, different registration.
4. **iOS extension build:** Flutter-managed Xcode target → EAS experimental extension support or manual Xcode management.
5. **Navigation:** Flutter Navigator 2.0 → React Navigation.
6. **Dependency injection:** Riverpod `ProviderScope` → Zustand stores + manual DI for background.
7. **Date handling:** Dart `DateTime` → JavaScript `Date` + `date-fns`.
8. **Result type:** Dart sealed `Result<T, E>` → TypeScript discriminated union `{ success: true; value: T } | { success: false; error: E }`.

---

## 25. REQUIRED TASK CHANGES (if migration proceeds)

- **TASK-001:** `flutter create` → `npx create-expo-app`
- **TASK-002:** `pubspec.yaml` → `package.json`; Flutter deps → Expo/RN deps
- **TASK-003:** `analysis_options.yaml` → `tsconfig.json` + `eslint.config.mjs`
- **TASK-004/005:** Flutter platform config → Expo config plugins
- **TASK-006:** FakeClock → TypeScript; in-memory Drift → mock expo-sqlite
- **TASK-020-024:** Drift schema/migrations/repository → expo-sqlite schema/init/repository
- **TASK-040-044:** MethodChannel interfaces → Expo Modules API
- **TASK-060-066:** Same Swift code; different registration
- **TASK-070-078:** Same Kotlin code; different registration
- **TASK-080-093:** Complete UI rewrite in React Native
- **TASK-120-125:** Flutter test → Jest/RNTL
- **TASK-130-133:** Flutter build → EAS Build

**New tasks required:**
- Expo config plugin development (App Group, Info.plist, entitlements, extension target)
- expo-sqlite schema definition + migration framework
- React Navigation setup (stack, tab navigators)
- EAS Build configuration (`eas.json`)
- Custom Expo Module: NativeSpeech
- Custom Expo Module: NativeNotificationQuery

---

*End of EXPO_ARCHITECTURE_MIGRATION_REVIEW.md*
