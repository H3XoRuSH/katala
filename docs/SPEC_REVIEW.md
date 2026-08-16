# SPEC_REVIEW.md — Katala Adversarial Specification Review

**Review date:** 2026-08-10
**Documents reviewed:** PLAN.md (v1), KATALA_SPEC.md (v1.0.0-draft)
**Reviewer stance:** Hostile Principal Software Architect, Mobile Systems Engineer, Product Engineer, QA Architect

**Verdict:** NEEDS MAJOR REVISION

---

# CROSS-FINDING ANALYSIS (Top First — These Compound)

Before the individual findings, three compound risks demand immediate attention because they interact across multiple subsystems:

### Compound Risk A: Filipino/Taglish Voice Input Is a House of Cards
The spec promises Taglish support as a core differentiator targeting the Philippine market, but:
- iOS on-device STT may not support Filipino at all (§A.1 — "may not be on-device"), yet the spec mandates `requiresOnDeviceRecognition = true` and disables voice entirely when unavailable (§5.3, CC-6). **Net effect: Filipino voice input could be completely non-functional on iOS.**
- The intent detection patterns (§5.5) are 100% English. "Pa-remind naman ako bukas" matches zero intent trigger patterns and falls to the default `CREATE_REMINDER` only if a temporal entity is found. "Remind mo ko mamaya" likewise fails.
- The STT error correction table (§5.4) has 7 entries, all English-centric. Filipino/Taglish STT errors are unaddressed.
- Contact matching (§5.8) extracts names using English action verbs; "Tawagan si Adam" would not extract "Adam" because "tawagan" is not in the contact extraction regex.

**Combined severity: CRITICAL** — The primary market's primary input method is unreliable or unavailable.

### Compound Risk B: "100% Private" Meets OS Reality
The spec claims "No user data ever leaves the device" but:
- OQ-1 defaults to including the database in device backups, meaning all reminder data transits through Apple iCloud / Google Drive infrastructure.
- Map tile loading for geofence location selection (§14.3) sends viewport coordinates to Apple/Google.
- On Android, the Google speech engine may send audio fragments even with `EXTRA_PREFER_OFFLINE` — this parameter is a preference, not a guarantee.
- The spec honestly documents these exceptions (§14.3) but the marketing promise (§1.2: "No user data is transmitted to any server under any circumstance") conflicts with the technical reality.

**Combined severity: HIGH** — The privacy guarantee is overstated relative to OS constraints.

### Compound Risk C: Notification Reliability × Offline × App Killed
- Android alarms are NOT persistent across reboot (§8.4); the boot receiver must reschedule them. If the boot receiver fails (background restrictions, manufacturer-specific behavior, user force-stops), all reminders become silently undeliverable.
- iOS's 64-notification limit (§8.6) requires dynamic scheduling, which requires the app to run periodically. If the app is killed for days, beyond-64 reminders won't fire.
- The spec has no periodic background wake-up mechanism (no WorkManager/AlarmManager heartbeat, no BGTaskScheduler refresh task) to reconcile the notification queue.
- No mechanism detects that a notification was missed due to these failures. The user only discovers the problem when they open the app and see overdue reminders.

**Combined severity: CRITICAL** — Reminders can silently fail.

---

# 1. PRODUCT INTENT DRIFT

### [MEDIUM] Geofencing Demoted to Post-MVP
**Location:** §23 (Phases 10, 11), PLAN.md §5C, §6 Phase 3
**Problem:** PLAN.md lists "Geofencing & Location Triggers" as a core differentiator (§2) and Phase 3 deliverable. KATALA_SPEC.md pushes it to Post-MVP (Weeks 13-14). The original vision treats geofencing as a primary trigger type alongside time; the spec treats it as an optional add-on.
**Why it matters:** The user persona "may be driving, commuting" — geofencing reminders ("when I get home") are precisely the hands-free use case that differentiates Katala from a simple alarm app. Delaying geofencing reduces Katala to a voice-to-alarm converter for MVP.
**Recommendation:** Either accept the scope reduction explicitly and update PLAN.md, or bring geofencing into MVP with reduced scope (saved locations only, no map search).
**Implementation impact:** HIGH if brought into MVP; NONE if deferred.

### [LOW] "Zero server costs" vs. Map Tiles
**Location:** PLAN.md §1, KATALA_SPEC.md §14.3
**Problem:** PLAN.md claims "zero server costs." The spec acknowledges map tile loading requires HTTP requests to Apple/Google map servers. While these aren't Katala's servers, they are still server dependencies that cost money if Katala were to provide its own tile server. The claim is technically true but misleading.
**Recommendation:** Clarify: "Katala operates no backend of its own. Map tiles are served by the platform map provider (Apple/Google)."

### [INFORMATIONAL] Contact Matching Expanded
**Location:** §5.8, PLAN.md §5B
**Problem:** PLAN.md describes "Contact Matcher" as matching "names in speech to phone numbers/contacts." The spec adds fuzzy matching (Jaro-Winkler), nickname matching, and multi-contact disambiguation. This is a reasonable expansion, but it introduces complexity (Jaro-Winkler, multi-result handling) not implied by the original plan.
**Recommendation:** Accept the expansion; it's necessary. Document the decision.

---

# 2. MISSING REQUIREMENTS

### [HIGH] No Periodic Background Wake-Up for Notification Reconciliation
**Location:** §8.6, §15.2
**Problem:** The Dynamic Scheduling Window relies on the app running to reconcile notifications. The spec has no mechanism for periodic background execution. On iOS, if the user doesn't open the app for days, reminders beyond the 64-notification window vanish silently. On Android, if the boot receiver fails or the app is force-stopped, all alarms disappear.
**Recommendation:** Add an iOS `BGAppRefreshTaskRequest` or Android `WorkManager` periodic task (minimum once per day) that reconciles the notification queue. Design it to be battery-friendly (runs in seconds, no network).
**Implementation impact:** MEDIUM

### [HIGH] Undefined Behavior for Simultaneous Notification Actions
**Location:** §8.3, §8.7
**Problem:** What happens when a user taps [✓ Done] and [⏰ Snooze] simultaneously? Or when a notification action is processed in the background while the user is editing that reminder in the foreground? The spec has no concurrency model for these scenarios.
**Recommendation:** Add a concurrency section. Define that all notification action handlers are serialized per reminder ID. Use a mutex or database transaction to ensure only one state transition succeeds. Define that the app, on coming to foreground, reconciles by re-reading the database.
**Implementation impact:** MEDIUM

### [MEDIUM] No Data Migration Strategy
**Location:** §7 (Data Model), §17 (Database)
**Problem:** The spec defines a database schema but has zero migration strategy. SQLite schema changes between versions will require migrations. Drift supports migrations, but the spec doesn't mandate them or specify a versioning scheme.
**Recommendation:** Add a database versioning and migration section. Mandate that every schema change increments a version number and provides a migration callback. Test migrations from v1 → vN.
**Implementation impact:** MEDIUM

### [MEDIUM] No Handling for "Snooze While Snoozed"
**Location:** §6.8 (State Machine)
**Problem:** The state machine allows SNOOZED → PENDING (automatic when snooze timer fires). But what if the user taps Snooze again BEFORE the snooze timer fires? The current model says SNOOZED → DISMISSED or SNOOZED → COMPLETED, but not SNOOZED → SNOOZED (re-snooze). Users will try to "extend" a snooze.
**Recommendation:** Add SNOOZED → SNOOZED transition: cancel current snooze timer, increment snooze_count again, schedule new snooze notification. Or clarify that the user must wait for the re-notification to snooze again.
**Implementation impact:** LOW

### [MEDIUM] No Mechanism to Handle "Reminder Edited After Notification Scheduled"
**Location:** §8.5, §8.7
**Problem:** The spec says "Replacing/updating a notification is straightforward" but doesn't specify that editing a reminder's time MUST cancel the old notification and schedule a new one. Section 6.2 has `updated_at` but no trigger to re-schedule.
**Recommendation:** Add explicit requirement: when a reminder's trigger time changes, cancel the existing notification and schedule a new one. The reminder repository's update method must do this atomically.
**Implementation impact:** LOW

### [MEDIUM] No Requirements for Notification Group Summary
**Location:** §8.4 (iOS: threadIdentifier, Android: setGroup)
**Problem:** Both platforms support notification grouping. The spec sets group identifiers but never specifies a group summary notification. Without one, iOS will show stacked notifications without a summary, and Android will show individual notifications that may be collapsed without context.
**Recommendation:** Define a group summary notification format (e.g., "3 reminders upcoming") and schedule it alongside individual notifications.
**Implementation impact:** LOW

### [MEDIUM] No "Undo Delete" / Soft-Delete Visibility
**Location:** §6.2 (is_deleted), §12.4.2 (Swipe left → Delete)
**Problem:** The spec supports soft-delete with 30-day retention (§14.10). But the UX section (§12.4.2) says "Swipe left on reminder → Delete (with confirmation)" — implying immediate removal. There's no "Undo" toast, no "Recently Deleted" view, no way for a user to recover a mistakenly deleted reminder before the 30-day hard-delete.
**Recommendation:** Add an "Undo" toast (snackbar) after deletion. Optionally add a "Recently Deleted" filter in the timeline.
**Implementation impact:** LOW

### [LOW] No Requirements for Notification Sound When Device Is Silent
**Location:** §8.4, §12.6
**Problem:** The spec defines custom sounds but doesn't specify behavior when the device is in silent/vibrate mode. iOS critical alerts (which bypass silent mode) require a special entitlement that Apple rarely grants. The spec's "Time-sensitive" (§8.4) on iOS 15+ does NOT bypass the mute switch — only Critical Alerts do.
**Recommendation:** Document that Katala respects the device silent mode. Reminders will vibrate (if haptics enabled) but not play sound when the mute switch is active. This is a known limitation.
**Implementation impact:** NONE (documentation only)

### [LOW] No "Tomorrow" Without Time — Default Behavior Undefined in Code
**Location:** §5.7.2, OQ-4
**Problem:** OQ-4 says "tomorrow" without a time should "Always ask for time." But §5.7.2 says "requires time clarification if no time given." The resolution algorithm isn't specified — what question exactly does Katala ask? Via voice? Via the clarification card?
**Recommendation:** Specify the exact UX: show clarification card with time suggestions. Do not re-prompt via voice.
**Implementation impact:** NONE (clarification only)

---

# 3. AMBIGUITY AUDIT

### [HIGH] "at 2" Without AM/PM — Heuristic Is Wrong Direction
**Location:** §5.7.4
**Ambiguity:** Numbers 1-6 "always ask," numbers 7-11 use heuristic. But at 8 AM, "at 2" most likely means 2 PM (6 hours away), yet the heuristic would ask for clarification because 2 is 1-6. At 10 AM, "at 2" also means 2 PM (4 hours from now), and at 7 PM, "at 2" likely means 2 AM (7 hours from now). The heuristic rule (1-6 = ask, 7-11 = heuristic) doesn't correlate with user intent.
**Recommendation:** Always show resolved time with an [AM/PM] toggle. Never auto-resolve bare numbers 1-12 without AM/PM. The toggle takes one tap; getting it wrong causes missed reminders.
**Implementation impact:** LOW

### [HIGH] What Does "Dismiss" Mean for Follow-Up Rules?
**Location:** §6.8, §11.4
**Ambiguity:** The state machine says DISMISSED does NOT evaluate follow-ups. But the follow-up lifecycle says `CANCELLED` when parent is deleted or user cancels. What happens when a parent reminder is DISMISSED? The spec says DISMISSED stops follow-up evaluation (§6.8 note), but the follow-up evaluation algorithm (§11.5) only checks `is_deleted` and `COMPLETED` — it doesn't check DISMISSED.
**Recommendation:** The follow-up evaluation algorithm must also check `parent.status == DISMISSED` and treat it as CANCELLED. Or explicitly allow DISMISSED parents to still trigger follow-ups. Pick one.
**Implementation impact:** LOW

### [MEDIUM] What Happens When Two Saved Locations Have the Same Name?
**Location:** §6.6, §3.5
**Ambiguity:** SavedLocation has a `name` field but no uniqueness constraint. A user could have two "Office" locations. When voice says "when I get to the office," which one is used?
**Recommendation:** Enforce unique names on SavedLocation. Or ask for disambiguation.
**Implementation impact:** LOW

### [MEDIUM] "Remind me on Friday" — What Time?
**Location:** §5.7.3
**Ambiguity:** "On Friday" without a time. The spec defaults to asking for time (consistent with OQ-4). But this is a natural, frequent input. Always asking for time adds friction. Some users expect a default time (e.g., 9 AM).
**Recommendation:** Use the configurable "morning" default (9:00 AM) as the default for day-without-time, and show it in the confirmation card. Let users change it if wrong, rather than always asking.
**Implementation impact:** LOW

### [MEDIUM] What Happens When the App Is Killed During Snooze Countdown?
**Location:** §6.8, §8.3
**Ambiguity:** A reminder is SNOOZED. The spec schedules a new notification for now + snooze_duration. If the app is killed before that notification fires, does the snooze still work? Yes — because the notification is scheduled with the OS. But what about the snooze_count and status? They were already persisted. OK. But what if the snoozed notification fires and the user taps an action — does the background handler work if the app was killed?
**Recommendation:** This is a platform capability question. Document that on iOS, UNNotification actions launch the app in the background. On Android, BroadcastReceiver/PendingIntent handles this. Both work if app was killed. But if the app was FORCE-STOPPED on Android, notifications may not fire at all.
**Implementation impact:** NONE (documentation)

### [MEDIUM] Follow-Up Deadline Timezone When User Travels
**Location:** §11.2, §5.7.8
**Ambiguity:** A follow-up rule stores `deadline_timezone`. If the user creates a follow-up in Manila ("remind me at 5 PM") and then flies to Tokyo, does the follow-up deadline fire at 5 PM Manila time or 5 PM Tokyo time?
**Recommendation:** Follow the same rule as reminders: use the timezone at creation time. If the user is in Tokyo when 5 PM Manila time arrives, fire then (which would be 6 PM Tokyo).
**Implementation impact:** NONE (clarification only; already implied by §5.7.8)

### [LOW] "Later" = +2 Hours — But What Time Is It Now?
**Location:** §5.7.5
**Ambiguity:** "Later" resolves to `now + 2 hours`. If the user says "remind me later to call Adam" at 10 PM, the reminder fires at midnight. Is that intended?
**Recommendation:** Cap "later" resolution so it never lands between 10 PM and 7 AM (configurable quiet hours). If it would, move to the next morning at the "morning" default time.
**Implementation impact:** MEDIUM

### [LOW] "Remind Me Friday" on Friday
**Location:** §5.7.3
**Ambiguity:** If today is Friday and the user says "Remind me Friday," does that mean today or next Friday?
**Recommendation:** If today IS the named day and no time is given, ask for clarification (consistent with §5.7.3). If today IS the named day and a time is given that is still in the future, use today.
**Implementation impact:** LOW

---

# 4. iOS / ANDROID REALITY CHECK

### [CRITICAL] iOS On-Device Speech for Filipino (tl-PH) Is NOT Guaranteed
**Location:** §5.3, Appendix A.1
**Claim:** The spec mandates `requiresOnDeviceRecognition = true` and says to disable voice if not available.
**Reality:** As of iOS 16+, `SFSpeechRecognizer` supports on-device recognition for a limited set of languages: English (US, UK, AU, IN), Spanish, French, German, Italian, Portuguese, Russian, Chinese (Mandarin), Japanese, Korean, Arabic, Turkish, and a few others. **Filipino (Tagalog) is NOT on the supported on-device list.** `supportsOnDeviceRecognition` will return `false` for `tl-PH`.
**Net effect:** Filipino voice input is completely non-functional on iOS under this spec. The spec's own rules disable it.
**Classification:** DEVICE/OS DEPENDENT — NOT RELIABLE for `tl-PH` on iOS.
**Recommendation:** Options: (a) Accept that Filipino voice input requires cloud STT on iOS and add a user-facing consent dialog explaining this, (b) Drop Filipino voice support claims and restrict to English/Taglish-English on iOS, (c) Integrate an offline-first third-party engine like Vosk with a Filipino model (contradicts CC-8/CC-9).
**Implementation impact:** HIGH — whichever path is chosen affects architecture.

### [CRITICAL] Android `EXTRA_PREFER_OFFLINE` Is a Preference, Not a Guarantee
**Location:** §5.3
**Claim:** Use `EXTRA_PREFER_OFFLINE = true` to guarantee on-device speech.
**Reality:** `EXTRA_PREFER_OFFLINE` is a hint. Google's SpeechRecognizer may still use network recognition if:
- The offline model is not downloaded for the user's locale
- The offline model is outdated
- The recognition confidence falls below a threshold
- The manufacturer uses a different speech implementation (Samsung, Xiaomi, Huawei often ship their own)
**Classification:** NOT RELIABLE
**Recommendation:** The spec already acknowledges model availability checks via `checkRecognitionSupport()` (Android 13+). For Android < 13, there is no programmatic way to verify offline-only mode. Add a runtime check: if the device has no offline model, show the same "voice unavailable" fallback as iOS. Do not silently allow cloud STT.
**Implementation impact:** MEDIUM

### [HIGH] iOS Notification Actions in Background Are Limited
**Location:** §8.3, §9.2.6, §9.2.7
**Claim:** Background execution for SNOOZE and COMPLETE "must work without opening the app."
**Reality:** iOS `UNNotificationAction` with `UNNotificationActionOption.foreground` = NO processes the action in a background extension. The app gets a short execution time (~5-10 seconds). The spec's background work (DB write, cancel/schedule notification) should fit in this window, but heavy operations (follow-up evaluation, contact query) might not. Also, the iOS background extension is a SEPARATE PROCESS from the main app. It must access the same SQLite database, which requires proper file coordination (or using App Groups / shared container).
**Recommendation:** Add explicit iOS background extension architecture. Define that DB writes in notification extensions must use coordinated access (NSFileCoordinator or App Group container). Test the worst-case background execution time.
**Implementation impact:** MEDIUM

### [HIGH] Android Boot Receiver Is NOT Guaranteed on All Devices
**Location:** §8.4, §15.2
**Claim:** "Must register RECEIVE_BOOT_COMPLETED receiver to reschedule all pending alarms."
**Reality:** Many Android manufacturers (Xiaomi, OPPO, Vivo, Huawei — precisely the brands common in the Philippines) delay or suppress BOOT_COMPLETED broadcasts for non-system apps. Some require the user to explicitly add the app to an "Auto-start" whitelist. The boot receiver is a best-effort mechanism, not a guarantee.
**Recommendation:** Add a fallback: when the app opens, always reconcile notifications (already specified in §8.6 step 3). Additionally, guide users (especially on affected brands) to disable battery optimization and enable auto-start. Accept that on some devices, reminders may not survive reboot until the app is manually opened.
**Implementation impact:** LOW (already partially handled)

### [HIGH] Android Exact Alarm Permission Can Be Revoked
**Location:** §8.4
**Claim:** "Use SCHEDULE_EXACT_ALARM permission. Check canScheduleExactAlarms() before scheduling."
**Reality:** On Android 14+, the user can revoke exact alarm permission at any time. The spec mentions a fallback to inexact alarms but doesn't specify what "inexact" means for user experience. Inexact alarms can be delayed by minutes to hours depending on Doze mode.
**Recommendation:** If exact alarms are unavailable, show a persistent notification or in-app banner: "Katala reminders may be delayed — enable exact alarms in Settings." The fallback to inexact should be a conscious UX decision, not silent degradation.
**Implementation impact:** LOW

### [MEDIUM] iOS 64-Notification Limit — App Killed for Extended Period
**Location:** §8.6
**Claim:** "Whenever a notification fires or is cancelled, check if there are unscheduled reminders and schedule the next batch."
**Reality:** If the app is killed and no notifications fire (because none were scheduled for the active 64), the app never gets CPU time to schedule the next batch. The spec's step 3 ("When the app comes to foreground") is the ONLY recovery. If the user has 100 reminders and doesn't open the app for a month, ~36 reminders (100 - 64) have no notifications scheduled and will never fire.
**Recommendation:** Add a periodic background refresh task (BGAppRefreshTask or BGProcessingTask) that wakes the app at least daily to reconcile. This is not guaranteed by iOS but significantly increases reliability. Or simply document this as a known iOS limitation.
**Implementation impact:** MEDIUM

### [MEDIUM] Geofencing Limits and Behavior
**Location:** §3.5, §10
**Reality check on §3.5 claim "Platform constraint: iOS limits apps to 20 monitored geofence regions. Android limits to 100":
- iOS 20 region limit: CORRECT for `startMonitoring(for:)`. Additionally, iOS may silently not monitor regions if the user denies "Always" location or if the device is in Low Power Mode.
- Android 100 limit: CORRECT. But on Android, geofence re-registration after reboot uses the BOOT_COMPLETED receiver, which has the same reliability problems noted above.
- **Geofence accuracy:** On both platforms, geofence enter/exit events have typical accuracy of 50-200 meters but can be worse in urban canyons or with weak GPS. The spec's default radius of 200m is reasonable but won't be precise.
- **NOT RELIABLE:** Geofence events can be delayed by minutes. A "when I leave home" reminder may fire after the user is already blocks away.
**Recommendation:** Document accuracy expectations. Add a disclaimer in the location resolution flow.

### [MEDIUM] Notification Sound Customization
**Location:** §8.4, §12.6
**Reality:** The spec mandates custom `.caf` (iOS) and `.wav`/`.ogg` (Android) notification sounds. This is fine. But on Android, custom notification sounds require the file to be in `res/raw/` at build time. Dynamic sound changes would require a different approach. On iOS, custom sounds have a 30-second limit — the spec's "< 5 seconds" is fine.

### [LOW] Flutter Platform Channel Latency for Voice
**Location:** §5.2 (Pipeline), §20.2 (Platform Bridges)
**Reality:** The spec requires streaming audio from native STT to Flutter for real-time transcript display. Platform channel round-trips add latency (typically 1-5ms per message on modern devices). For streaming transcripts, this is acceptable. But if the NLP pipeline Stage 2-5 runs in Dart on the main isolate, it could cause jank. The spec mentions "processing state: brief spinner (< 500ms)" but doesn't mandate running NLP off the main isolate.
**Recommendation:** Mandate that NLP Stages 2-8 run on a Dart isolate or via `compute()`. The UI thread must only handle display.
**Implementation impact:** MEDIUM

### [LOW] Device Reboot — No Reminder Reconciliation on iOS
**Location:** §8.4
**Reality:** iOS automatically preserves scheduled notifications across reboot. This IS guaranteed. Android does NOT. The spec correctly distinguishes these. No issue.

---

# 5. OFFLINE / PRIVACY AUDIT

### [HIGH] Database Backup Inclusion Conflicts with Privacy Promise
**Location:** §14.6, OQ-1
**Problem:** The spec defaults to including the database in iCloud/Android backups. All reminder content, contact references, and saved locations would transit through Apple/Google servers. This directly conflicts with §1.2: "No user data is transmitted to any server under any circumstance during normal operation."
**Recommendation:** Either (a) exclude the database from backups and accept that users lose data when switching devices, or (b) change the privacy guarantee from "no user data ever leaves the device" to "no user data leaves the device except through your personal device backup (which is encrypted)." The current stance says both things simultaneously and is dishonest.
**Implementation impact:** LOW (either way is a one-line config change)

### [HIGH] Android Speech Engine May Transmit Audio Despite EXTRA_PREFER_OFFLINE
**Location:** §5.3, §14.3
**Problem:** The spec says "Katala guards against this by checking supportsOnDeviceRecognition and refusing to use cloud STT." On Android, `EXTRA_PREFER_OFFLINE` is a preference, not a hard block. There is no equivalent of iOS's `requiresOnDeviceRecognition` on Android. The check `SpeechRecognizer.checkRecognitionSupport()` (Android 13+) doesn't distinguish between on-device and server-side support.
**Recommendation:** For Android 13+: attempt to verify offline model presence before starting. For Android < 13: document that voice privacy cannot be technically guaranteed and that audio may be sent to Google's servers for processing. Offer a setting: "Allow network-assisted recognition (faster but less private)" — default OFF.
**Implementation impact:** MEDIUM

### [MEDIUM] Notification Content Visible on Lock Screen
**Location:** §8.2, §14.7
**Problem:** Reminder titles like "Dr. appointment about test results" appear on the lock screen where anyone can read them. This is a known OS-level concern, but the spec doesn't address it.
**Recommendation:** On iOS, use `UNNotificationContent` with `summaryArgument` only for the summary. Offer a setting: "Hide reminder details on lock screen" that sets notification content to "New reminder — open Katala to view."
**Implementation impact:** LOW

### [MEDIUM] Logging Policy Allows "Operational Metrics" Without Defining Them
**Location:** §14.8
**Problem:** Release logs allow "operational metrics (e.g., 'notification scheduled', 'reminder saved') without identifying content." But what counts as "identifying"? A log line "notification scheduled for reminder_id=abc123 at time=14:00" links an identifier and time. If someone access the device logs, they can reconstruct reminder timing patterns.
**Recommendation:** Define release log format precisely: only aggregate counts ("3 notifications scheduled") or anonymized IDs. No timestamps, no reminder IDs, no entity data.
**Implementation impact:** LOW

### [MEDIUM] External Intent Leakage via Notification Actions
**Location:** §9.2
**Problem:** When the user taps [📞 Call Now], the phone number is sent via an Android Intent or iOS URL scheme to the dialer app. This is necessary for the feature, but it means the phone number leaves Katala's sandbox. The spec should acknowledge this.
**Recommendation:** Add to §14.3: a row documenting that notification actions (Call, Text, Navigate) send the phone number/coordinates to the corresponding system app. This is inherent to the feature.
**Implementation impact:** NONE (documentation)

### [LOW] Maps Intent Sends Coordinates to External App
**Location:** §9.2.5
**Problem:** The NAVIGATE action opens maps with lat/lng. On Android, the intent goes to the default maps app. If using the browser fallback (`google.com/maps`), coordinates are sent via HTTPS to Google. This is a privacy consideration.
**Recommendation:** Document in §14.3. Prioritize platform-native maps URLs (`maps.apple.com`, `geo:` intent) over the web fallback.
**Implementation impact:** NONE (already specified)

---

# 6. NLP / VOICE ATTACK

### [CRITICAL] Taglish/Filipino Command Recognition Is Structurally Broken
**Location:** §5.5, Appendix A
**Test commands and results:**

| Command | Expected Intent | Actual Result | Problem |
|---------|----------------|---------------|---------|
| "Pa-remind naman ako bukas ng alas tres na tawagan si Adam" | CREATE_REMINDER + CALL + time | UNKNOWN or low-confidence CREATE_REMINDER | No intent pattern matches "pa-remind." Falls through to entity-based default. Temporal "bukas ng alas tres" may or may not parse. Contact "Adam" won't extract because "tawagan" is not in the contact extraction regex. |
| "Remind mo ko mamaya to call Adam" | CREATE_REMINDER + CALL + time | UNKNOWN | "Remind mo ko" does not match "remind me" pattern. "mamaya" may parse as temporal but intent is lost. |
| "Remind me to call Adam" (no time) | CREATE_REMINDER + CALL, validation error for missing time | MEDIUM confidence, asks for time | OK — correct behavior |
| "Remind me tomoro at tree to call adam" | CREATE_REMINDER + CALL + time | Depends on STT correction | "tomoro" → "tomorrow" (not in correction table). "tree" → "3" (in table, if context matches). "adam" may match contact. |
| "Call John" (multiple Johns) | CREATE_REMINDER + CALL + disambiguation | WORKS if contact resolution is triggered | But "Call John" with no "remind me" prefix — does the intent detector catch bare "call" as CREATE_REMINDER? The fallback path checks `hasActionEntity(normalizedText)` which DOES catch "call." OK. |
| "Remind me Friday" | CREATE_REMINDER + temporal (Friday, no time) | Should ask for time per OQ-4 | OK |
| "Remind me tomorrow morning" | CREATE_REMINDER + "tomorrow at 9:00 AM" | MEDIUM confidence | OK — but "morning" = 9 AM might not be what the user expects on a Sunday. |
| "Remind me to call Adam" (no time) | Validation error | Asks "When should I remind you?" | OK |
| "Remind me tomorrow at 3 yesterday" | Should REJECT | Unclear — temporal parser may resolve "tomorrow" and then encounter "yesterday" | The parser extracts entities independently. It might extract both "tomorrow" and "yesterday" and silently pick one. This should trigger validation error V9 or semantic contradiction detection. |
| "Remind me in 20 minutes" | CREATE_REMINDER + now + 20 min | HIGH confidence, auto-save | OK |
| "Tomorrow after lunch remind me to call Adam and if he doesn't answer remind me again at 5" | CREATE_REMINDER + CALL + FOLLOW-UP | Unclear — does the parser handle compound sentences? | The spec says compound commands should be treated as a single reminder (OQ-6). But "if he doesn't answer" is a follow-up condition that the spec explicitly cannot observe (§11.3). The parser must downgrade this gracefully. Risk: it extracts "tomorrow after lunch" + "call Adam" + "at 5" and creates one reminder at 5 PM, losing the "after lunch" part. |

**Recommendation:** The NLP pipeline needs a major revision for Taglish/Filipino:
1. Add Filipino intent trigger patterns: "pa-remind," "remind mo ko," "mag-remind," "remind mo ako," "ipaalala mo"
2. Expand contact extraction to include Filipino action verbs
3. Add STT error correction entries for common Filipino/Taglish misrecognitions
4. Add compound sentence detection that either splits or flags for user clarification
5. Add semantic contradiction detection (e.g., "tomorrow" + "yesterday" in same input)
**Implementation impact:** HIGH

### [HIGH] "at 2" Heuristic Creates Schedule Errors
**Location:** §5.7.4
**Test:** User says "Remind me at 2 to call Adam" at 8 AM. Heuristic asks for clarification because 2 is in 1-6 range. User is confused — "2 PM obviously." Meanwhile, "Remind me at 8" at 8 AM would resolve to 8 PM (because heuristic for 7-11: current is before noon, 8 AM is not in future → 8 PM). But "at 8" at 8 AM most likely means 8 PM today or 8 AM tomorrow. The heuristic produces wrong answers in edge cases.
**Recommendation:** As above — never auto-resolve bare numbers. Always show AM/PM toggle.

### [MEDIUM] STT Error Correction Is Insufficient
**Location:** §5.4
**Problem:** The correction table has 7 entries. Real-world STT errors are far more diverse. Examples that will cause failures:
- "remind me at free to call Adam" (free → three → 3)
- "remind me to call Adam at too" (too → two → 2)
- "remind me to coal Adam" (coal → call — in table)
- "remind me to call atom" (atom → Adam)
- "remind me on Monday" (on → at, but "on Monday" is valid temporal, should work)
**Recommendation:** Expand the correction dictionary significantly. Better: after temporal parsing, check if the STT raw transcript contains near-homophones for numbers and times, and present the RESOLVED time to the user (which the spec already does via confirmation card).
**Implementation impact:** LOW

### [MEDIUM] Intent "EDIT_REMINDER" Requires Identifying Which Reminder — Unspecified Algorithm
**Location:** §5.5
**Problem:** "Change my reminder" or "reschedule" requires identifying WHICH reminder. The spec says "by recency, content match, or explicit reference" but gives no algorithm, no tiebreaker, and no UX for when matching fails.
**Recommendation:** For MVP, either remove EDIT_REMINDER and DELETE_REMINDER from voice intents (requiring UI interaction instead), or specify: (1) Match by recency: "change my reminder" → the most recently created/modified PENDING reminder. (2) Match by content: "change my reminder about Adam" → search PENDING reminders for "Adam" in title/notes. (3) If ambiguous, show disambiguation list. (4) EDIT and DELETE via voice are HIGH risk — users may accidentally delete the wrong reminder.
**Implementation impact:** MEDIUM

### [MEDIUM] FOLLOW-UP Intent Cannot Be Expressed Naturally
**Location:** §5.5, §11
**Problem:** The intent `CREATE_FOLLOWUP` has trigger patterns "if … remind me," "follow up," "check back" — but these patterns are only active when there IS parent reminder context (§5.5: "Must have parent reminder context"). How does the system know there IS parent context? The user must have just completed or snoozed a reminder. But the intent detection runs on raw text input — it doesn't know the UI context unless the UI passes it.
**Recommendation:** Define that CREATE_FOLLOWUP intent requires an explicit UI context flag (e.g., `parentReminderId` is passed to the NLP pipeline when launched from a reminder's "Follow-up" button). Voice-only follow-up creation (without tapping a specific reminder first) should be treated as CREATE_REMINDER.
**Implementation impact:** LOW

### [LOW] Filler Word Removal May Strip Meaningful Words
**Location:** §5.4, Step 7
**Problem:** "Strip filler words: um, uh, like, you know, basically, actually." But "like" in "apps like Instagram" or "actually" in "actually at 3 PM not 2" carries meaning. The spec says "only when not part of a meaningful phrase" — how does a regex-based system determine this?
**Recommendation:** Remove filler-word stripping entirely. It adds negligible value and risks information loss. The NLP pipeline should be robust to filler words in entity extraction patterns.
**Implementation impact:** LOW

---

# 7. REMINDER DOMAIN MODEL AUDIT

### [HIGH] Reminder Has `parent_reminder_id` but No `depth` Field
**Location:** §6.2, §11.7
**Problem:** The follow-up engine limits chain depth to 3 (§11.7: `parent.depth + 1 <= 3`). But the `depth` field is on `FollowUpRule` (§6.5), not on `Reminder` (§6.2). The validation check references `parent.depth` — but Reminder has no `depth`. This means the depth check can't be implemented as written.
**Recommendation:** Either add a `depth` field to Reminder (denormalized from the FollowUpRule that created it) or calculate depth dynamically by walking the `parent_reminder_id` chain (up to 3 levels, negligible performance cost in SQLite).
**Implementation impact:** LOW

### [MEDIUM] No Way to Represent "Remind Me Every Monday at 9 AM"
**Location:** §6.3, §7.6
**Problem:** The spec explicitly excludes recurring reminders (NG9 for voice, §7.6 says "not applicable for MVP"). The Trigger and Reminder entities have no recurrence fields. This is a legitimate scope decision, but users WILL expect this. The data model should at least leave room for recurrence (e.g., an `rrule` string field on Trigger) so the database doesn't need migration when recurrence is added.
**Recommendation:** Add a nullable `recurrence_rule` (String, RFC 5545 RRULE format) field to the Trigger entity, defaulting to null. It costs nothing and prevents a schema migration later.
**Implementation impact:** NONE (add column only)

### [MEDIUM] Title Is Max 200 Chars but Generated from Transcript
**Location:** §6.2, §5.12
**Problem:** The spec generates titles from entities ("Call Adam"). But what if the user says a long sentence and no clear title emerges? The ReminderDraft has `title: String?` — nullable. But Reminder.title is NOT nullable (required). What is the fallback title?
**Recommendation:** Define a fallback title generation: if no title can be extracted, use first 200 characters of the notes/transcript, or "Reminder" with a timestamp suffix.
**Implementation impact:** LOW

### [MEDIUM] `notification_id` on Trigger Is Ambiguous
**Location:** §6.3, §8.5
**Problem:** The Trigger entity has `notification_id: int?`. But §8.5 says "Use the reminder's database integer auto-increment ID as the notification ID" or "derive it from the UUID hash." If using auto-increment, that's on Reminder, not Trigger. If using UUID hash, it's computed. The field placement is confusing and the generation strategy is undefined.
**Recommendation:** Move `notification_id` to Reminder (one notification per reminder). Define generation: use a hash of the Reminder UUID truncated to fit in a 32-bit int, with collision detection on scheduling.
**Implementation impact:** LOW

### [LOW] `snooze_count` Max 10 — No Rationale
**Location:** §6.2
**Problem:** Snooze is limited to 10 times. Why 10? Is this to prevent infinite snoozing? A user might genuinely need to snooze a daily nag (like "take medication") more than 10 times.
**Recommendation:** Make the max configurable (default 10) or remove it entirely. If kept, document the rationale.
**Implementation impact:** LOW

### [LOW] Soft-Delete with `is_deleted` but No Cascade for Children
**Location:** §6.2, §6.10
**Problem:** §6.10 says "Deleting a reminder deletes its Trigger, Action, FollowUpRule, and all child Reminders." But deletion is soft-delete (§14.10: 30-day retention). Soft-deleting a parent should also soft-delete children. The cascade rule doesn't distinguish hard vs. soft delete.
**Recommendation:** Explicitly define: soft-delete cascades to children (all get `is_deleted = true`). Hard-delete (after 30 days, or "Delete All Data") physically removes rows.
**Implementation impact:** LOW

---

# 8. STATE MACHINE AUDIT

### [HIGH] SNOOZED → SNOOZED Transition Missing
**Location:** §6.8
**Problem:** Covered in §2 Missing Requirements above. A user who receives a snoozed reminder notification and taps Snooze again has no valid transition.
**Recommendation:** Add: SNOOZED → SNOOZED (re-snooze). Cancel current snooze notification, increment snooze_count, schedule new notification for now + snooze_duration.

### [MEDIUM] COMPLETED → PENDING (Re-open) Not Defined
**Location:** §6.8
**Problem:** The state machine says COMPLETED is terminal. But what if the user accidentally completes a reminder (swipe-right on the timeline) and wants to undo? The "Undo" toast could revert to PENDING.
**Recommendation:** Add a time-limited undo window (5-10 seconds) where COMPLETED → PENDING is allowed. After the window, COMPLETED is terminal.
**Implementation impact:** LOW

### [MEDIUM] What About PENDING → DELETED?
**Location:** §6.8
**Problem:** The state machine has no DELETED state. The spec uses `is_deleted` flag instead. But what's the relationship between DISMISSED and deleted? Can a DISMISSED reminder be deleted? Can a COMPLETED reminder be deleted? (Yes — soft-delete with 30-day retention.)
**Recommendation:** The `is_deleted` flag is orthogonal to `status`. Document that deletion is independent of state: any reminder in any state (except already hard-deleted) can be soft-deleted. Or if there are restrictions, specify them.

### [LOW] Race: Notification Action vs. In-App Edit
**Location:** §8.3, §6.8
**Problem:** User edits a reminder on the detail screen. Simultaneously, the reminder's notification fires and the user taps [✓ Done] from the lock screen. Two writes race to update the same row.
**Recommendation:** Use optimistic locking: add a `version` (int) column to Reminder. Both the edit and the notification handler read the version, then UPDATE WHERE version = old_version. The loser retries or the UI refreshes to show the new state.
**Implementation impact:** MEDIUM

---

# 9. NOTIFICATION AUDIT

### [CRITICAL] Android: No Reminder Recovery After Force-Stop or Boot Receiver Failure
**Location:** §8.4, §15.2
**Problem:** Covered in Compound Risk C and Platform Reality Check. Android alarms are not persistent. If the device reboots and the boot receiver fails (common on Chinese-manufacturer devices prevalent in the Philippines), ALL reminders silently disappear from the notification queue.
**Recommendation:** 
1. Schedule a daily `WorkManager` periodic task to reconcile notifications.
2. On app open, always reconcile (already specified).
3. Show a persistent low-priority notification: "Katala is keeping track of your reminders" (ugly but honest).
4. In onboarding, guide users to disable battery optimization for Katala.
**Implementation impact:** MEDIUM

### [HIGH] iOS 64-Notification Limit — Long-Term App Inactivity
**Location:** §8.6
**Problem:** Covered above. If user has 100 reminders and doesn't open the app for a month, 36 reminders never fire.
**Recommendation:** Same as above: add BGAppRefreshTask. Or cap the number of schedulable reminders to 60 and show a warning when the user tries to create the 61st: "You have many reminders. Open Katala regularly to keep them active."

### [MEDIUM] No Deduplication Mechanism for Snooze Notifications
**Location:** §8.7, §9.2.6
**Problem:** The spec says "One notification per reminder ID. Scheduling replaces existing." When SNOOZED → PENDING (snooze timer fires), a new notification is scheduled with the same notification ID. This correctly replaces the old one. But what if the old notification had already been displayed and was sitting in the notification center? The replacement may not clear the old one from the notification center on all Android versions.
**Recommendation:** Explicitly cancel the old notification before scheduling the new one (don't rely on replacement alone). Test on Android 10, 11, 12, 13, 14.
**Implementation impact:** LOW

### [MEDIUM] "Dismiss" Action Should Confirm on Notification
**Location:** §8.3
**Problem:** The DISMISS action on follow-up notifications is marked "Destructive? Yes (red)." On iOS, destructive UNNotificationAction options make the action red. On Android, there's no native "destructive" styling for notification actions. The platform should use a different color or an icon to distinguish it.
**Recommendation:** Use [✕ Dismiss] label instead of just "Dismiss." On Android, use a distinct PendingIntent with a different request code.
**Implementation impact:** LOW

### [LOW] Notification Sound for Geofence Reminders Unclear
**Location:** §8.1
**Problem:** `reminder_location` category exists and has a custom sound. But geofence reminders may fire at any time (e.g., 2 AM when arriving home late). A loud notification at 2 AM while the user is walking to their door is unnecessary.
**Recommendation:** Geofence reminders should use a quieter sound or vibration-only by default during quiet hours.
**Implementation impact:** LOW

---

# 10. GEOFENCING AUDIT

### [MEDIUM] Geofencing Is Post-MVP but the Spec Makes It Sound Core
**Location:** §10, §23, PLAN.md §2
**Problem:** Geofencing is presented with full architectural detail in §10 but scheduled for Weeks 13-14 (Post-MVP). The spec's own implementation roadmap treats it as a later phase, yet the user journeys (§3.5, §3.6) and product identity (§1.2: "Location-based triggers") treat geofencing as a first-class feature. This misalignment will cause scope confusion during implementation.
**Recommendation:** Move geofencing user journeys to a "Post-MVP" section or add a clear label: "This section describes Post-MVP behavior. MVP does not include geofencing."

### [MEDIUM] Geofence Re-registration After Reboot (Android)
**Location:** §10 (implicit)
**Problem:** The spec's geofencing section (§10) doesn't address reboot re-registration for geofences. The notification section (§8.4) mentions boot receiver for alarms, but geofences have the same problem on Android — they must be re-registered after reboot. The Phase 10 task list (§23) mentions "Implement reboot re-registration (Android)" but this is just a task title with no specification.
**Recommendation:** Specify that on Android, the boot receiver must also re-register all active geofences from the database. On iOS, geofences persist across reboot automatically.

### [LOW] Offline Map Tiles for Location Selection
**Location:** §3.5, §14.3
**Problem:** The location picker uses map tiles that require network access. When offline, the spec says "show coordinate input or saved locations only." This means a user creating their first geofence reminder while offline cannot use the map picker. Acceptable for MVP/Post-MVP, but the UX should guide the user clearly.
**Recommendation:** Add an explicit "Map unavailable offline" state to the UX spec (§12.4.8 already has this).

---

# 11. FOLLOW-UP ENGINE AUDIT

### [HIGH] Follow-Up Evaluation Race: Parent Completed Between Evaluation and Notification
**Location:** §11.5, §11.8
**Problem:** The follow-up deadline fires, evaluates the parent (finds it not completed), creates a follow-up reminder, and schedules its notification. Between the evaluation and when the user sees the follow-up notification, the user could complete the original reminder via the app. Now the follow-up notification is "stale" — it reminds the user about something they already did.
**Recommendation:** When the follow-up notification is tapped or its [✓ Done] action is used, re-check the parent's status. If the parent is now COMPLETED, suppress the follow-up and show a brief toast: "Already taken care of." Or, more simply: schedule the follow-up reminder but don't auto-notify immediately; check parent status first.
**Implementation impact:** MEDIUM

### [HIGH] `PARENT_NOT_COMPLETED` Is the Only Meaningful Condition
**Location:** §11.2, §11.3
**Problem:** The spec supports two conditions: `PARENT_NOT_COMPLETED` and `TIME_ELAPSED`. `TIME_ELAPSED` is unconditional ("always trigger after X time") and is functionally identical to just creating a new timed reminder. `PARENT_NOT_COMPLETED` is the only condition that adds value over basic reminders. The original vision ("If he doesn't call back by 5 PM") is explicitly unsupported because call monitoring is impossible (§11.3). The follow-up engine is dramatically reduced from the vision.
**Recommendation:** Accept this reduction explicitly. The follow-up feature as specified is: "If I haven't marked this reminder as done by [time], remind me again." This is still useful but should be described accurately. Update PLAN.md to reflect this reality.

### [MEDIUM] Follow-Up Creates a New Reminder but Inherits the Same Action — Is This Always Correct?
**Location:** §11.6
**Problem:** `createFollowUpReminder` copies the parent's action_type, target_value, contact_name, and contact_phone. The follow-up title is "Follow-up: Call Adam." The user sees a notification with [📞 Call Now]. But the follow-up is about CHECKING whether Adam called back — calling Adam again immediately may not be the user's intent.
**Recommendation:** Follow-up reminders should default to `GENERAL` intent_type with no action. The user wanted to be reminded to check, not to repeat the action. If they want to call again, they can open the app and tap [📞 Call Now] from the detail view.
**Implementation impact:** LOW

### [LOW] Cascade Cancellation Race
**Location:** §11.5
**Problem:** The evaluation algorithm checks `parent.is_deleted`. But what if the parent is deleted AFTER the follow-up evaluation starts but BEFORE `createFollowUpReminder` runs? The race window is small but real.
**Recommendation:** Use a database transaction: `evaluateFollowUp` should lock the parent row, check status, and only create the follow-up reminder if the parent is still valid. Or accept the race and let the follow-up reminder be created; the user can dismiss it.
**Implementation impact:** LOW

---

# 12. CONCURRENCY / RACE CONDITION AUDIT

### [HIGH] Multiple Notifications Firing Simultaneously
**Location:** §8.7, §9.2
**Problem:** Two reminders at 2:00 PM fire simultaneously. On iOS, each notification action is processed in a separate extension instance. On Android, two PendingIntents fire. Both try to write to the database simultaneously. SQLite handles concurrent writes with serialization, but if one writes and the other reads stale data before the write, inconsistent states can occur.
**Recommendation:** Use database transactions with SERIALIZABLE isolation for all state transitions. Drift supports this. Mandate in CC-15 (already requires transactions but doesn't specify isolation level).

### [MEDIUM] Edit + Notification Fire Simultaneously
**Location:** §6.8, §8.7
**Problem:** Covered in State Machine Audit above. Use optimistic locking.

### [MEDIUM] Geofence Fires While Reminder Is Being Deleted
**Location:** §10 (implicit)
**Problem:** User deletes a geofence reminder. Before the geofence is unregistered with the OS, the user physically enters the geofence area. The OS delivers the geofence event. The handler checks the database — the reminder is deleted. But the handler must handle this gracefully.
**Recommendation:** All trigger handlers (time and geofence) must check `reminder.is_deleted == false && reminder.status == PENDING` before acting. This is implied by the evaluation algorithm but should be explicit for geofence triggers too.

### [LOW] Migration Starts While Background Notification Handler Runs
**Location:** §17 (Database)
**Problem:** If the database schema is being migrated (on app update) and a notification action handler tries to write to the database simultaneously, corruption could occur.
**Recommendation:** Migration must run before ANY other database access. On app start, run migrations synchronously before initializing notification handlers or UI. This is standard practice but should be mandated in the spec.

---

# 13. FAILURE-MODE AUDIT

### [HIGH] What Happens When the Database Is Corrupted?
**Location:** §17
**Problem:** No database corruption recovery strategy. SQLite databases can corrupt due to disk-full errors, sudden termination, or OS bugs. The spec has no integrity check, no repair strategy, no user-facing recovery.
**Recommendation:** On app startup, run `PRAGMA integrity_check`. If it fails: (1) attempt to restore from the most recent backup (if any), (2) if no backup, show a user-facing error and offer to reset. Do NOT silently continue with a corrupted database.
**Implementation impact:** MEDIUM

### [MEDIUM] What Happens When Speech Recognition Produces Empty or Garbage Text?
**Location:** §5.3, §5.4
**Problem:** The STT error handling covers "No speech detected" but not "STT produced garbage" — e.g., background noise transcribed as random words. This would pass through the NLP pipeline and potentially create a nonsense reminder at HIGH confidence if random words match patterns.
**Recommendation:** Add a pre-NLP quality check: if the transcript is entirely non-dictionary words or the word count is very high relative to audio duration (noise trigger), reject with "I couldn't understand that clearly. Try again?"
**Implementation impact:** MEDIUM

### [MEDIUM] What Happens When the Notification Scheduling Itself Fails?
**Location:** §8.5, §8.6
**Problem:** The reminder is persisted, but the notification scheduling call to the OS fails (e.g., iOS 64-limit reached exactly at that moment, Android permission revoked between check and schedule). The reminder exists in the database but has no notification. The user won't be reminded.
**Recommendation:** After scheduling, verify the notification is scheduled (platform-dependent). If scheduling fails, persist an `notification_scheduled = false` flag on the Trigger. On next reconciliation, retry. Show an in-app indicator that some reminders couldn't be scheduled.

### [MEDIUM] What Happens When Contact Database Changes?
**Location:** §5.8
**Problem:** A reminder created with a resolved contact ("Adam Smith, +63917...") stores the phone number at creation time. If Adam changes his number, the reminder has the old number. This is acceptable behavior, but what if the contact is DELETED? The reminder still has the stored phone number — that's fine. What if the contact permission is revoked later? The reminder should still work because the number was stored.
**Recommendation:** This is already handled by storing contact data at creation time. Document that contact data is a snapshot, not a live reference.

### [LOW] What Happens When the App Is Uninstalled and Reinstalled?
**Location:** §14.6
**Problem:** All data is deleted on uninstall (standard OS behavior). No backup restore means all reminders are lost. This is a user expectation issue: users might assume "app data" persists like other apps that use cloud backup.
**Recommendation:** Document in the app description and onboarding that reminders are stored only on-device and will be lost if the app is deleted.

---

# 14. UX ATTACK

### [HIGH] Auto-Save at HIGH Confidence Is Dangerous
**Location:** §5.10, §3.1 (Step 6)
**Problem:** The spec says HIGH confidence reminders auto-save after 2 seconds. The user hears the chirp and the reminder disappears from the confirmation card. But:
- The user might be reading the confirmation and about to tap [Edit] when the 2-second timer expires.
- The user might have made a mistake in speech but the parser got HIGH confidence on the WRONG interpretation.
- "Remind me tomorrow at 3 to call Adam" — if the parser resolves "at 3" to 3 AM (because the heuristic got it wrong), auto-saves, and the user was about to correct it.
**Recommendation:** Never auto-save. Always require explicit confirmation (tap [Save]) regardless of confidence. The 2-second auto-save saves one tap at the cost of incorrect reminders. The product promise is reliability, not minimal taps.
**Implementation impact:** LOW (config change)

### [MEDIUM] Conflict Warning Is Shown but Can Be Ignored
**Location:** §7.5
**Problem:** The conflict UX shows existing reminders and offers "Save at 2:00 PM Anyway." This option is listed first and is the path of least resistance. Users will habitually tap it, defeating the purpose of conflict detection. The product intent was "Smart Conflict Detection & Stacking" — smart detection followed by easy dismissal is not smart.
**Recommendation:** Make "Move to 2:30 PM" the primary (prominent) option. "Save Anyway" should be a secondary/tertiary option. The spec mentions suggesting "next available 30-minute slot" — make that the default.
**Implementation impact:** LOW

### [MEDIUM] "I Couldn't Understand That" with No Guidance
**Location:** §5.10, §12.4.8
**Problem:** The error states include "Parse failed: Card: 'I didn't understand that' with [Try Again] [Type Instead]." This gives the user no information about WHAT went wrong. They don't know if they spoke too fast, used an unsupported phrase, or if the parser is simply limited.
**Recommendation:** Show a more helpful error: "I didn't catch a time or date in that. Try: 'Remind me to [task] [when]'." Or show the raw transcript with the parsed fields highlighted so the user can see what was (and wasn't) understood.
**Implementation impact:** LOW

### [MEDIUM] Permission Request Flood on Onboarding
**Location:** §12.4.1
**Problem:** The onboarding lists 4 permissions. The spec wisely says to only request Microphone and Notifications on onboarding. But the screen shows all 4 with [Grant]/[Skip] buttons. Users might feel pressured to grant all, or might reflexively deny all.
**Recommendation:** Onboarding screen 3 should only show Microphone and Notifications. Add a sentence: "Later, Katala may ask for Contacts and Location to enable call reminders and location-based reminders." The current design over-requests.

### [LOW] Bottom Navigation: "Done" Tab Unclear
**Location:** §12.4.2
**Problem:** The bottom navigation shows [🏠 Home] [✓ Done] [⚙️ More]. "Done" presumably shows completed reminders. But "Done" could also be interpreted as "Mark as done" — a verb, not a noun. Standard mobile patterns use labels like "Completed" or "History."
**Recommendation:** Rename to "Completed" with a checkmark or clock icon.

### [LOW] Voice Input State: "Tap to Stop" Is Too Subtle for Driving
**Location:** §12.4.3
**Problem:** The voice input screen shows "[Tap to stop]" as a hint. The primary persona "may be driving." A small text hint is not glanceable. The user needs a large, obvious way to stop recording.
**Recommendation:** Make the entire screen a tap-to-stop target, or make the mic button very large with a clear "Stop" label. Better: auto-stop on silence (already specified as 2 seconds) and make manual stop a secondary option.

---

# 15. ACCESSIBILITY AUDIT

### [MEDIUM] Waveform Visualization Not Accessible
**Location:** §12.4.3, §13.5
**Problem:** The listening state shows "pulsing mic icon" and "audio waveform visualization." The reduced motion section says to replace the waveform with "Listening..." text. But what about screen reader users during normal (non-reduced-motion) mode? They get no indication that the mic is active beyond the initial "Double tap to start listening."
**Recommendation:** Announce "Listening" when the mic activates. Announce live transcript as it appears. Announce "Processing" when listening stops. The accessibility labels should cover all state transitions, not just static elements.

### [MEDIUM] Swipe Gestures Are Not Accessible
**Location:** §12.4.2, §13.4
**Problem:** §13.4 says "provide alternative button actions (not swipe-only)." But §12.4.2 defines swipe-right for complete and swipe-left for delete as the primary interaction. The alternative button actions are not specified — where are they? In the detail view? On long-press?
**Recommendation:** Long-press on a reminder should show a context menu with "Mark Done," "Snooze," "Delete." Screen reader users navigate via actions, not swipes.

### [LOW] Color-Only Indicators for Overdue/Conflict
**Location:** §12.4.2, §7.5
**Problem:** Overdue reminders use a "Red accent" dot (🔴). Conflict warnings use a ⚠️ icon. These are decorative emoji, not semantic indicators for screen readers. The emoji may not be announced meaningfully.
**Recommendation:** Use semantic accessibility labels: "Overdue: [title]" not just "🔴 [title]." Conflict cards should have `semanticsLabel: "Schedule conflict warning"`. Test with TalkBack and VoiceOver.

---

# 16. SECURITY AUDIT

### [MEDIUM] URL Handling — No Validation Against Javascript/File URLs
**Location:** §9.2.4
**Problem:** The OPEN_URL action opens any URL. The spec says "Ensure URL has scheme. If missing, prepend https://." But what about `javascript:` URLs? `file://` URLs? These could be injected via a malicious reminder (if the app ever imports reminders, or if contact names contain URL-like strings).
**Recommendation:** Whitelist URL schemes: only allow `http://` and `https://`. Reject all others. Validate before storing and before opening.
**Implementation impact:** LOW

### [MEDIUM] Phone Number Injection via Contact Names
**Location:** §5.8, §9.2.1
**Problem:** The contact matcher resolves names to phone numbers. If a contact is named something that parses as a different phone number (unlikely but possible with creative naming), the extracted number could differ from the matched contact's actual number. Low risk, but the spec doesn't validate that the action's target_value matches the resolved contact's number.
**Recommendation:** When both contact_phone and target_value exist, prefer contact_phone (from OS contact database, which is validated). target_value (from speech extraction) should be treated as fallback only.

### [LOW] Deep Link / Custom URL Scheme Handling
**Location:** Not addressed in spec
**Problem:** The spec doesn't define if Katala responds to any custom URL schemes (e.g., `katala://`). This is probably out of scope for MVP, but if added later, deep links need validation to prevent intent injection.
**Recommendation:** Explicitly state: "Katala does not register any custom URL schemes for MVP." Add this to non-goals.

### [LOW] No Biometric/App Lock
**Location:** Not addressed
**Problem:** The spec assumes the device's lock screen is sufficient protection. But within an unlocked device, anyone can open Katala and see all reminders. For a privacy-focused app, an optional app-level lock (Face ID / fingerprint) might be expected.
**Recommendation:** Add as a Post-MVP consideration. Not blocking for MVP.

---

# 17. TESTABILITY AUDIT

### [HIGH] NLP Pipeline Is Tightly Coupled to DateTime.now()
**Location:** §5.7, §5.8
**Problem:** The temporal parser uses `DateTime.now()` as reference time (§5.7: "Reference time: Always DateTime.now() at the moment of parsing."). This makes deterministic testing impossible without mocking. CC-23 requires dependency injection for the clock, but §5.7 hardcodes `now()`.
**Recommendation:** All NLP functions that use the current time must accept an injectable `Clock` interface. The default implementation uses `DateTime.now()`. Tests inject a `FakeClock` with a fixed time.
**Implementation impact:** LOW (refactoring existing function signatures)

### [MEDIUM] No Test Harness for Platform Bridges
**Location:** §18, §20
**Problem:** The spec defines platform bridges (§20) but doesn't specify how to test code that depends on them without a physical device. The NLP pipeline can be tested with pure Dart. But notification scheduling, contact resolution, and speech recognition require platform APIs.
**Recommendation:** Define mock/fake interfaces for all platform bridges in Dart. The real implementation lives in the platform channel. Tests use the fake implementation. This is implied by the bridge pattern but should be mandated.

### [MEDIUM] Geofence Trigger Testing Has No Strategy
**Location:** §18.2.5
**Problem:** The test strategy mentions geofence tests but provides no mocking strategy for GPS coordinates or region monitoring. Testing "user enters geofence" currently requires a physical device or simulator with GPS simulation.
**Recommendation:** The GeofenceBridge must be mockable. Tests inject fake locations and verify that the trigger evaluation logic fires correctly. The OS-level geofence registration is tested via integration/manual tests.

### [LOW] Voice Input Testing Circular Dependency
**Location:** §18.2.1
**Problem:** Testing the voice pipeline end-to-end requires speech. The spec proposes a "corpus of test transcripts" which bypasses STT. That's good. But testing the STT integration itself is inherently manual. Accept this limitation.
**Recommendation:** Document that STT integration is tested via manual QA on target devices. The rest of the pipeline is testable with text input.

---

# 18. MVP SCOPE AUDIT

### Scope Classification (Ruthless)

| Feature | Classification | Rationale |
|---------|---------------|-----------|
| Voice input → text transcript | **CORE MVP** | Central value proposition |
| Text input fallback | **CORE MVP** | Accessibility + degradation |
| NLP: CREATE_REMINDER with time | **CORE MVP** | Minimum viable voice reminder |
| NLP: CALL action + contact resolution | **CORE MVP** | Key differentiator |
| NLP: URL detection | **MVP IF LOW COST** | Simple regex, high value |
| NLP: Location triggers (geofence) | **POST-MVP** | Already in post-MVP |
| NLP: EDIT/DELETE/QUERY intents | **POST-MVP** | High complexity, high risk (delete wrong reminder) |
| NLP: CREATE_FOLLOWUP intent | **POST-MVP** | Dependent on follow-up engine |
| Notification scheduling (time) | **CORE MVP** | Reminders must fire |
| Notification actions (Done, Snooze) | **CORE MVP** | Interactive notifications are core |
| Notification actions (Call, Open Link) | **CORE MVP** | Key differentiator |
| Conflict detection | **MVP IF LOW COST** | Nice to have; not essential for proving value |
| Follow-up engine | **POST-MVP** | Already in post-MVP |
| Geofencing | **POST-MVP** | Already in post-MVP |
| Custom notification sounds | **MVP IF LOW COST** | Polish item |
| Onboarding carousel | **CORE MVP** | Permission education is critical |
| Settings screen | **CORE MVP** | Configurable defaults required |
| Taglish/Filipino support | **CORE MVP** | Primary market requirement — but assessed above as unreliable |
| Dark mode | **CORE MVP** | Default theme |
| Accessibility | **CORE MVP** | Must meet WCAG 2.1 AA |
| Database encryption | **POST-MVP** | Reasonable for MVP |
| Data export | **POST-MVP** | Spec already defers this |

### [HIGH] "Smallest Version That Proves Value"
**Problem:** The spec defines MVP as Phases 1-9 (Weeks 1-12) including contact resolution, action system, conflict detection, and full UI polish. The core value proposition — "speak a reminder, get a notification with a 1-tap action" — can be demonstrated with:
1. Voice input → text (Phase 1-2)
2. NLP: CREATE_REMINDER with time + CALL + URL (Phase 2-4, scope-reduced)
3. Notification scheduling with Done/Snooze/Call/Open actions (Phase 5)
4. Basic timeline UI (Phase 6, simplified)
5. Text input fallback

This is Phases 1-6, reduced scope, approximately 6-8 weeks. Conflict detection, the full NLP intent set, elaborate polish, and extensive testing could follow as "MVP v1.1."
**Recommendation:** Define a "Core MVP" (Phases 1-6, reduced) and an "Enhanced MVP" (Phases 1-9 as specified). Ship Core MVP to test the concept, then iterate.

---

# 19. AI CODING AGENT FAILURE AUDIT

### [HIGH] Agent Will Invent a Notification Reconciliation Strategy
**Location:** §8.6
**Problem:** The spec describes WHAT (dynamic scheduling window) but the implementation details are sparse. The agent will need to invent: the exact timing of reconciliation, how to detect which notifications are scheduled (platform-specific and unreliable on Android), and how to handle edge cases. Different agents will build radically different reconciliation systems.
**Recommendation:** Specify the reconciliation trigger points explicitly: (1) on app foreground, (2) after any notification action, (3) after reminder create/edit/delete, (4) daily background task. Specify that `getScheduledNotificationIds()` is a platform bridge that returns best-effort results; the database is the source of truth.

### [HIGH] Agent Will Choose Inconsistent State Management
**Location:** §17, §22
**Problem:** The spec mentions Riverpod in the allowed packages list (CC-21) but never specifies state management architecture. The agent might use Riverpod, BLoC, Provider, or vanilla setState across different features. The result would be a patchwork of state management patterns.
**Recommendation:** Specify the state management approach: Riverpod for dependency injection + state management. Define the layer structure (presentation → application/notifier → domain → data) and mandate consistency.

### [MEDIUM] Agent Will Add a Cloud API "Just for Emergencies"
**Location:** §24.1 (CC-1)
**Problem:** When the agent discovers that on-device STT doesn't support Filipino on iOS, it may "temporarily" add cloud STT as a fallback "to make it work." The constraint CC-6 tries to prevent this, but the agent may rationalize that the user needs it.
**Recommendation:** Add an explicit test in the acceptance criteria: a network traffic audit that fails the build if any HTTP request is made. Automate this in CI.

### [MEDIUM] Agent Will Create Different Behavior on iOS vs. Android
**Location:** §20 (Platform Architecture)
**Problem:** The platform bridge pattern is well-defined, but the agent might implement different NLP behavior, different state transitions, or different UX on each platform "because that's the platform convention." The spec says "single codebase" but doesn't mandate behavioral consistency.
**Recommendation:** Add a constraint: "All business logic (NLP, state machine, conflict detection, follow-up engine) must produce identical results on iOS and Android. Platform bridges are the ONLY place where platform-specific code is allowed."

### [MEDIUM] Agent Will Over-Engineer the NLP with an Internal DSL
**Location:** §5 (NLP Architecture)
**Problem:** A highly capable agent might decide the regex-based approach is "not scalable" and build an internal rule engine, a mini-DSL, or a pattern-matching framework. The spec says "rule-based regex tokenizers" but an ambitious agent may ignore this.
**Recommendation:** Add an explicit constraint: "The NLP pipeline must use simple regex patterns + the temporal resolution function. Do not create a custom DSL, rule engine framework, or pattern-matching abstraction. Keep it simple enough that a junior developer can add a new pattern."

### [LOW] Agent Will Add `flutter_background_service` for Periodic Work
**Location:** §15.2, §20.1
**Problem:** The PLAN.md mentions `flutter_background_service` as a geofencing dependency. The spec doesn't include it in the allowed packages. An agent following PLAN.md might add it, while an agent following the spec would not.
**Recommendation:** Resolve the conflict: either remove `flutter_background_service` from PLAN.md or add it (with justification) to the spec's allowed packages.

---

# 20. ARCHITECTURAL SMELL AUDIT

### [HIGH] NLP Pipeline Is a God Function
**Location:** §5.2-5.11
**Problem:** The NLP pipeline is described as 9 sequential stages operating on text. The spec describes each stage but doesn't define clear module boundaries, interfaces, or error propagation between stages. An agent might implement this as a single `NlpPipeline.run()` method that does everything, making it untestable and unmaintainable.
**Recommendation:** Define each stage as a separate class/function with explicit input/output types. Stage 1 outputs `RawTranscript`. Stage 2 outputs `NormalizedTranscript`. Each stage can be tested independently with known inputs and expected outputs.

### [MEDIUM] Reminder Entity Has Too Many Responsibilities
**Location:** §6.2
**Problem:** The Reminder entity combines: identity (id), content (title, notes), classification (intent_type), lifecycle (status, snooze_count), relationships (parent_reminder_id), timestamps (created_at, updated_at, completed_at), deletion (is_deleted, deleted_at), and audit trail (original_transcript). This is a single table with 12+ columns mixing domain concerns.
**Recommendation:** This is acceptable for SQLite/MVP. The separation of Trigger and Action already addresses the biggest concern. But note that `original_transcript` is audit/display data that could be in a separate `ReminderAudit` table. For MVP, acceptable as-is.

### [MEDIUM] Follow-Up Engine Is Tightly Coupled to Reminder Creation
**Location:** §11.6
**Problem:** `createFollowUpReminder` knows about Reminder, Trigger, Action, and notification scheduling. It's a cross-cutting concern that spans the domain layer, data layer, and platform layer.
**Recommendation:** Split: the follow-up evaluation (domain) decides IF a follow-up should fire. A separate `FollowUpActionHandler` (application layer) creates the reminder and schedules the notification. This separates the "should we?" from the "how do we?"

### [MEDIUM] No Separation Between Domain Logic and Platform Scheduling
**Location:** §5.10, §8
**Problem:** The NLP confidence scoring determines UX behavior (auto-save, confirm, clarify). §5.10 is in the NLP section but dictates UI behavior. This couples the parser to the UI.
**Recommendation:** The NLP pipeline should output a ReminderDraft with a confidence score. The UI layer decides how to present it based on confidence. The NLP should not know about auto-save timers or confirmation cards.

### [LOW] `UserPreference` as a Key-Value Store Loses Type Safety
**Location:** §6.7
**Problem:** Preferences are stored as JSON strings keyed by name. This means type validation happens at runtime. A migration that changes a preference's format requires manual handling.
**Recommendation:** Acceptable for MVP (small number of preferences). For future: consider a typed preferences class with serialization/deserialization at the boundary.

### [LOW] Platform Bridges Are Well-Specified but Boundary Is Fuzzy
**Location:** §20
**Problem:** The platform bridge interface definitions are clear. But the spec doesn't define which layer OWNS the bridge interfaces. Does the domain layer define `SpeechBridge` as an abstract interface, or does the platform layer define it?
**Recommendation:** Domain layer defines abstract interfaces. Platform layer implements them. This is standard dependency inversion. State it explicitly.

---

# PRIORITIZATION

## Must Fix Before Implementation

1. **[CRITICAL]** Filipino/Taglish voice input strategy — define what's actually achievable on iOS and Android, and either change the NLP patterns or change the product claims.
2. **[CRITICAL]** Android notification persistence — add periodic background reconciliation (WorkManager) and boot-receiver fallback guidance.
3. **[CRITICAL]** iOS 64-notification limit — add BGAppRefreshTask for periodic reconciliation.
4. **[HIGH]** Resolve the database backup privacy contradiction (OQ-1).
5. **[HIGH]** Android on-device speech verification — define how to actually guarantee offline STT.
6. **[HIGH]** Auto-save at HIGH confidence — remove or make opt-in.
7. **[HIGH]** SNOOZED → SNOOZED transition missing from state machine.
8. **[HIGH]** DISMISSED behavior for follow-up rules (evaluation algorithm doesn't check it).
9. **[HIGH]** Reminder `depth` field missing for follow-up chain limiting.

## Should Fix Before MVP

1. **[HIGH]** Define concurrency model for simultaneous notification actions + in-app edits.
2. **[HIGH]** Add explicit notification scheduling on reminder edit.
3. **[MEDIUM]** Expand STT error correction dictionary.
4. **[MEDIUM]** Add EDIT_REMINDER/DELETE_REMINDER voice intent algorithms or remove them from MVP.
5. **[MEDIUM]** Add database integrity check on startup.
6. **[MEDIUM]** Define notification sound behavior in silent mode.
7. **[MEDIUM]** Add URL scheme whitelist (http/https only).
8. **[MEDIUM]** Define state management architecture (Riverpod or alternative).
9. **[MEDIUM]** Add NLP pipeline injectable clock for testability.
10. **[MEDIUM]** Define "Undo delete" UX.
11. **[MEDIUM]** Remove geofencing user journeys from MVP documentation or clearly mark them as Post-MVP.

## Can Defer

1. **[LOW]** Recurring reminder data model preparation.
2. **[LOW]** Filler word removal — remove or defer.
3. **[LOW]** Custom URL scheme handling.
4. **[LOW]** App-level biometric lock.
5. **[LOW]** Database encryption (already Post-MVP).
6. **[LOW]** Notification group summary format.
7. **[LOW]** Quiet hours for "later" resolution.

## Product Decisions Required

1. **OQ-1: Database backups** — Privacy vs. data portability. This is genuinely a product decision, not an engineering one.
2. **OQ-4: "Tomorrow" without time** — Always ask vs. use default. Affects UX friction.
3. **OQ-5: "at 8" without AM/PM** — Heuristic vs. always ask. This review recommends "always ask."
4. **Geofencing scope** — Is it core MVP or Post-MVP? PLAN.md and the spec disagree.
5. **Filipino voice support** — Accept degraded iOS experience, add cloud STT with consent, or drop the claim.
6. **Auto-save behavior** — Speed vs. accuracy. This review recommends removing auto-save.

---

# FINAL VERDICT

## NEEDS MAJOR REVISION

KATALA_SPEC.md is detailed, well-structured, and clearly the product of serious engineering thought. Many sections — the data model, action system, platform bridge architecture, and privacy documentation — are specific enough that a competent agent could implement them without ambiguity.

**However**, three fundamental problems prevent it from being implementation-ready:

### 1. Filipino/Taglish Voice Input Is Broken on Arrival
The primary market differentiator — natural voice input for the Philippine market — is architecturally impossible as specified. The NLP patterns are English-only. iOS on-device STT for Filipino doesn't exist. Android offline STT for Filipino is unreliable. The spec simultaneously mandates on-device-only STT and claims Filipino support, which cannot both be true on current hardware. This is the spec's most serious flaw because it undermines the product's reason to exist.

### 2. Notification Delivery Has No Safety Net
Android's alarm impermanence and iOS's 64-notification cap are known platform constraints. The spec acknowledges them but provides only best-effort recovery (reconcile on app open). Without a periodic background wake-up mechanism, reminders can silently fail on both platforms. A reminder app that sometimes doesn't remind is not a reminder app — it's a todo list.

### 3. Privacy Claims Overstate Technical Reality
The spec documents the privacy exceptions honestly in §14.3, but the product definition (§1.2) makes absolute claims ("No user data is transmitted to any server under any circumstance") that the technical sections contradict (backups, map tiles, potential STT leakage on Android). The product's core identity is privacy; overclaiming here is an existential risk.

---

**What the spec does well:**
- The data model (Reminder/Trigger/Action/FollowUpRule) is clean and well-normalized.
- The ReminderDraft intermediate representation is an excellent design pattern.
- The platform bridge abstraction is correctly specified for testability.
- The state machine (PENDING → COMPLETED/SNOOZED/DISMISSED) is complete except for the noted missing transition.
- The Open Questions section honestly surfaces ambiguous decisions.
- The Coding-Agent Constraints section anticipates common agent failure modes.

**What must change before implementation begins:**
1. Resolve the Filipino/Taglish voice strategy with a technically honest assessment of what's possible.
2. Add periodic background reconciliation for notifications on both platforms.
3. Align privacy claims with technical reality — either change the claim or change the backup/STT defaults.
4. Remove auto-save at HIGH confidence (or make it opt-in, off by default).
5. Fix the five HIGH-severity specification bugs (depth field, DISMISSED + follow-up, snooze re-snooze, notification on edit, concurrency model).

**With these changes, the specification would move to NEEDS MINOR REVISION and would be a solid foundation for implementation.**

---

*End of SPEC_REVIEW.md*
