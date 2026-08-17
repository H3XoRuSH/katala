# Katala Zero-Network Traffic Audit Guide

## Objective
To strictly guarantee that Katala has a **100% zero-network footprint** with no network telemetry, no cloud dependencies, and zero unsolicited HTTP/HTTPS or socket connections originating from the application.

---

## 1. Automated Architecture Audit Test

Katala includes a continuous code and dependency audit test that verifies no networking packages (e.g. `http`, `dio`, `firebase`, analytics) or background socket handlers exist in the runtime bundle:

```bash
flutter test test/network_audit/network_audit_test.dart
```

---

## 2. Mitmproxy Traffic Interception Audit (Manual & CI Gate)

### Prerequisites:
- `mitmproxy` installed (`pip install mitmproxy` or `brew install mitmproxy`)
- Simulator (iOS Simulator / Android Emulator) or physical device on the same local network.

### Step 1: Start mitmproxy in assertion mode
Run `mitmdump` with the Katala audit addon:
```bash
mitmdump -s test/network_audit/mitmproxy_audit.py -p 8080
```

### Step 2: Configure Proxy on Device / Simulator
1. **iOS Simulator**: Route host network via proxy `localhost:8080`.
2. **Android Emulator**: Start emulator with `-http-proxy http://127.0.0.1:8080`.
3. Install the mitmproxy CA certificate if inspecting encrypted traffic (`mitm.it`).

### Step 3: Exercise Full App Lifecycle
Perform all standard interactions in Katala:
1. Complete onboarding.
2. Grant microphone, notifications, and contacts permissions.
3. Record 10+ voice reminders (including relative times, contacts, and email/text intents).
4. Mark reminders complete, snooze, edit, and delete reminders.
5. Trigger local notification delivery and action executions.
6. Launch external URL actions (asserting that URL launches happen strictly via OS browser intent, not internal HTTP client).

### Step 4: Verify Zero Network Violations
- When tests conclude, stop `mitmdump` (`Ctrl+C`).
- Verify the final summary reports:
  ```
  KATALA NETWORK TRAFFIC AUDIT SUMMARY
  SUCCESS: Zero network requests detected from Katala.
  Audit Verdict: PASSED (100% Zero Network Footprint verified).
  ```

---

## 3. Alternative / Direct Socket Inspection (`lsof` / `netstat`)

When testing locally without setting up proxy certificates:

### On macOS / Linux:
```bash
# Obtain PID of Katala process
PID=$(pgrep -f katala)

# Assert no ESTABLISHED or SYN_SENT network sockets exist
lsof -i -a -p $PID
```
*(Should return empty output or only local X11/Wayland/IPC sockets).*

### On Android ADB:
```bash
adb shell "netstat -tlpn | grep com.katala.app"
```
*(Should return 0 listening or active network sockets).*

---

## 4. Policy for Network Audit in CI
Per **TASK-125** / **TASK_GROUPS.md**:
- Unit and static dependency audit tests run unconditionally on all CI builds.
- Dynamic proxy audits (`mitmdump`) are run as a manual gate prior to production release tags or in runners with simulator proxy capabilities enabled.
