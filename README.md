<p align="center">
  <img src="assets/icons/app_icon.png" alt="Katala Logo" width="128" />
</p>

<h1 align="center">Katala</h1>

<p align="center">
  <strong>Offline-first, voice-driven, context-aware smart reminders for iOS and Android.</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.5+-02569B?logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey" alt="Platforms" /></a>
  <a href="docs/KATALA_SPEC_V3.md"><img src="https://img.shields.io/badge/Privacy-100%25%20On--Device-success" alt="Privacy" /></a>
  <a href="docs/MVP_FINAL_GATE_VERIFICATION.md"><img src="https://img.shields.io/badge/Network-Zero%20Permission-blueviolet" alt="Zero Network" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
</p>

Katala 🦜 (named after the Philippine Red-vented Cockatoo, *Cacatua haematuropygia*) is a fast, privacy-guaranteed reminder application built with Flutter. It converts natural speech into actionable, context-rich reminders entirely on-device with **zero cloud APIs, zero user accounts, and zero network data transmission**.

---

## 🌟 Key Features & Core Pillars

- 🔒 **Provable Zero-Network Privacy**
  - Completely offline: `android.permission.INTERNET` is absent from the Android Manifest.
  - Zero analytics, zero crash loggers, zero ads, zero user accounts.
  - Audio streams are processed in-memory for speech-to-text and never written to disk or transmitted off-device.
  
- 🎙️ **Voice-First & Deterministic NLP**
  - High-speed parsing in under 5 seconds from speech capture to persisted reminder.
  - Deterministic rule-based Natural Language Processing engine supporting **English** and **Taglish** (Filipino-English mixed) expressions.
  - Handles relative times (*"in 20 minutes"*), specific dates (*"tomorrow at 3pm"*, *"sa Lunes 9am"*), and contextual action triggers (*"call Mom"*, *"text Kuya"*).

- ⚡ **Actionable Notifications**
  - Notifications carry actionable payloads: 1-tap phone calls, SMS messaging, URL opening, or map directions.
  - Seamless, privacy-preserving local contact resolution.

- 🛡️ **Authoritative Persistence & System Resilience**
  - **SQLite (Drift)** acts as the single source of truth; OS-level notifications are treated as derived state.
  - Automatic notification reconciliation across device reboots and app updates.
  - Exact alarm scheduling on Android and native notification action extension on iOS.

- ⏱️ **Schedule Conflict Awareness**
  - Automatically flags schedule overlaps within ±15 minutes of existing reminders during creation.

- ♿ **Accessible & Minimalist UX**
  - Clean, responsive Flutter UI adhering to WCAG 2.1 AA contrast and screen-reader accessibility guidelines.
  - Full Light and Dark theme support with locally bundled offline typography (`Inter`).

---

## 🏗️ Architecture Overview

Katala follows Clean Architecture principles with unidirectional data flow:

```
┌─────────────────────────────────────────────────────────┐
│                    UI & Presentation                    │
│   (Screens, Widgets, Design System, Riverpod Providers) │
└────────────────────────────┬────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────┐
│                    Application Layer                    │
│      (Use Cases, Reminder Orchestrator, Controllers)    │
└──────────────┬───────────────────────────┬──────────────┘
               │                           │
┌──────────────▼─────────────┐ ┌───────────▼──────────────┐
│       Domain Layer         │ │    Services & NLP Engine │
│ (Entities, Value Objects,  │ │ (Rule-Based Parsers,     │
│    Repository Contracts)   │ │  Temporal Resolvers)     │
└──────────────▲─────────────┘ └──────────────────────────┘
               │
┌──────────────┴───────────────────────────┬──────────────┐
│             Data & Persistence           │    Platform  │
│        (Drift / SQLite Database,         │    Bridges   │
│           Local Repositories)            │  (STT, OS)   │
└──────────────────────────────────────────┴──────────────┘
```

---

## 📁 Project Structure

```
katala/
├── android/            # Native Android configuration (Exact alarms, BootReceiver, zero internet)
├── ios/                # Native iOS configuration (Notification service extension, App Group)
├── assets/             # Bundled offline fonts (Inter) and audio assets
├── docs/               # Technical specs, architecture diagrams, and review documents
│   ├── KATALA_SPEC_V3.md
│   ├── ARCHITECTURE.md
│   └── MVP_FINAL_GATE_VERIFICATION.md
├── lib/
│   ├── application/    # Application use cases and controllers
│   ├── data/           # Drift SQLite database schema and repository implementations
│   ├── domain/         # Core business entities, value objects, and repository interfaces
│   ├── platform/       # Native platform bridges (Speech recognition, notification hooks)
│   ├── services/       # Rule-based NLP parser, tokenizers, temporal resolvers
│   ├── shared/         # Common utilities, error handling, result types
│   ├── ui/             # Flutter UI widgets, screens, and themes
│   ├── app.dart        # Root MaterialApp widget & global providers
│   └── main.dart       # Application entry point & service initialization
└── test/               # Unit, widget, and NLP corpus test suites
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: `>= 3.5.0 < 4.0.0`
- **Dart SDK**: `>= 3.5.0 < 4.0.0`
- **Android Studio** (Android SDK 26+, Java 17 target) or **Xcode** (iOS 15.0+)

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/H3XoRuSH/katala.git
   cd katala
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate code (Drift & Riverpod):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

Katala has a comprehensive test suite including unit tests, integration tests, and rule-based NLP corpus evaluations:

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

---

## 📖 Documentation

For detailed architectural and design specifications, refer to the documentation in [docs/](docs/):

- [KATALA_SPEC_V3.md](docs/KATALA_SPEC_V3.md): Product and technical specification.
- [ARCHITECTURE.md](docs/ARCHITECTURE.md): System architecture, dependency contracts, and concurrency design.
- [MVP_FINAL_GATE_VERIFICATION.md](docs/MVP_FINAL_GATE_VERIFICATION.md): Verification audits for release configuration, privacy compliance, and test passes.

---

## 📄 License

This project is licensed under the terms defined in the repository.
