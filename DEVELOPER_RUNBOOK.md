# ZeroPay Mobile Client - Developer Setup Runbook

This runbook serves as the definitive engineering audit and configuration checklist for developers setting up the **ZeroPay Mobile Client** on a completely fresh machine. 

ZeroPay is a **Blockchain Commerce Operating System** built with **Flutter**, designed to run cross-platform on Android and iOS devices. The application integrates deeply with native device capabilities (Secure Enclaves, biometrics, secure storage) and depends on Firebase services for push-alerts and authentication.

---

## 1. Local Development Guide

To compile and run ZeroPay-App, your host environment must satisfy the following SDK and toolchain specifications:

### ⚙️ SDK & Toolchain Requirements

| Software / Tool | Required Version | Purpose |
| :--- | :--- | :--- |
| **Flutter SDK** | `>= 3.19.0 < 4.0.0` | Framework core engine. |
| **Dart SDK** | `>= 3.0.0 < 4.0.0` | Language specification, runtime, and analyzer. |
| **Android Studio** | Hedgehog `2023.1.1` or higher | Core Android compilation and virtual device management. |
| **Android SDK** | SDK Build-Tools `34.0.0` | Supporting compile/target SDK versions. |
| **Java JDK** | OpenJDK 17 | Gradle build execution standard for Flutter 3.19+. |
| **Gradle** | `8.0` to `8.4` | Build automation wrapper for Android source. |
| **Xcode** | `15.0` or higher | iOS compilation toolchain (required for mac users). |
| **CocoaPods** | `1.14.0` or higher | iOS pod library manager. |

---

## 2. Environment Variables Audit

To keep production credentials secure while facilitating local developments, the ZeroPay-App uses a dual-mode configuration:
1.  **Simulated Sandbox (Default)**: Uses built-in `MockZeroPayRepository` profiles driven by `demoDatasetProvider` (independent of offline connectivity).
2.  **Live Connectivity**: Instantiated via compile-time variables or `.env` loads.

### 📝 Mandated Environment Variables

Below is the verified key blueprint representing all backend connections and third-party integrations consumed by the codebase. Copy these keys to a local `.env` file in the root directory:

```ini
# 🌐 ZeroPay Backend API Configuration
API_BASE_URL=https://api.zeropay.network/v1
WS_BASE_URL=wss://ws.zeropay.network/v1

# 🔥 Firebase Ledger Infrastructure Configuration
FIREBASE_PROJECT_ID=zeropay-ledger
FIREBASE_API_KEY=AIzaSyD-DemoApiKeyStringForZeroPayClient2026
FIREBASE_APP_ID_ANDROID=1:1234567890:android:a1b2c3d4e5f6
FIREBASE_APP_ID_IOS=1:1234567890:ios:f6e5d4c3b2a1
FIREBASE_MESSAGING_SENDER_ID=1234567890
FIREBASE_STORAGE_BUCKET=zeropay-ledger.appspot.com

# 🗺️ External Integration Keys
GOOGLE_MAPS_API_KEY=AIzaSyMaps-DemoApiKeyStringForMerchantRouteCRM

# 🤖 Artificial Intelligence Services
GEMINI_API_KEY=AIzaSyGemini-DemoKeyStringForLuminaContractAuditor

# 🛡️ Quality Assurance & Telemetry
SENTRY_DSN=https://sentry.demo.io/123456
```

---

## 3. Firebase Architecture Audit

ZeroPay-App relies on Firebase Core modules to facilitate push notifications, cloud telemetry, and authentication services.

*   **Firebase Messaging (FCM)**: Listens to incoming on-chain events (dispute alerts, milestone funding locks, peer validator actions) and pushes floating Snackbars via `RealtimeService`.
*   **Firebase Auth**: Manages sign-up, email registrations, and JWT validations.
*   **Firebase Analytics**: Measures customer onboarding completion ratios.

### 📁 Config File Anchors

For compilation to succeed, native platforms require specific configuration anchors:

#### 🟢 Android Config: `android/app/google-services.json`
Copy the config structure into `android/app/google-services.json` inside your native build directory.

#### 🔵 iOS Config: `ios/Runner/GoogleService-Info.plist`
Copy the property list XML into `ios/Runner/GoogleService-Info.plist` inside your iOS build directory.

*(Complete JSON/XML blueprints can be referenced in the [Master Environment Audit](file:///Users/maddy/.gemini/antigravity-ide/brain/c09a9d5e-e103-4cbc-b9fb-3ddd6bc7e074/environment_configuration_audit.md)).*

---

## 4. Android Configuration Audit

Android compilation configurations are handled via the Gradle wrapper engine. Due to the cryptographic local key hashing mechanisms (`flutter_secure_storage`) and fingerprint checks (`local_auth`), the minimum SDK version must be set explicitly.

### 📱 Android SDK Parameters
*   **Compile SDK Version**: `34` (Android 14)
*   **Target SDK Version**: `34`
*   **Minimum SDK Version**: `21` (Android 5.0 Lollipop - required for Keychain/KeyStore integration).

### 🛡️ Permissions (`android/app/src/main/AndroidManifest.xml`)

Add these permissions in the root of the manifest:

```xml
<!-- 🌐 Network Connectivity -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- 🔒 Native Cryptographic Biometrics -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>

<!-- 🔔 Remote Push notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

---

## 5. iOS Configuration Audit

To compile iOS files via the Xcode Build System, native provisioning parameters must be verified inside the Runner workspace.

### 🛠️ iOS Project Parameters
*   **Bundle Identifier**: `io.zeropay.app`
*   **iOS Deployment Target**: `iOS 14.0` or higher
*   **Push Notifications (APNS)**: Xcode Capabilities $\rightarrow$ Enable **Push Notifications** and **Background Modes** (check `Remote notifications`).

### 🛡️ Core plist Parameters (`ios/Runner/Info.plist`)

Insert these permission description strings to prevent runtime app crashes:

```xml
<!-- 🔒 Biometric Face ID Usage Permission (local_auth dependency) -->
<key>NSFaceIDUsageDescription</key>
<string>ZeroPay requires Face ID access to securely authorize local seed phrase encryption and instant milestone payouts.</string>

<!-- 🌐 App Transport Security (required for remote WebSockets/REST adapters) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 6. Backend Connectivity Audit

The ZeroPay Flutter client application interacts directly with the existing ZeroPay backend API services. Below is the comprehensive index of integrated nodes.

### 🔗 REST API Endpoints (`lib/core/api/endpoints.dart`)

*   **Root API Base URL**: `https://api.zeropay.network/v1`
*   **Auth Endpoints**: `/auth/login`, `/auth/keys/validate`, `/auth/session/verify`
*   **Wallet Endpoints**: `/wallet/balances`, `/wallet/transactions`, `/wallet/transfer`, `/ledger/history`
*   **Escrow Endpoints**: `/escrow/contracts`, `/escrow/release-milestone`, `/escrow/dispute`
*   **AI Advisors**: `/ai/negotiation/chat`, `/ai/contract/audit`, `/ai/insights/recommendations`
*   **Arbitration Court**: `/court/cases`, `/court/evidence`, `/court/vote`
*   **Telemetry Logs**: `/telemetry/metrics`, `/telemetry/events`

### ⚡ WebSocket Event Channels (`lib/core/realtime/realtime_service.dart`)
*   **Sync Node Connection**: `wss://ws.zeropay.network/v1`
*   **Channels**: `price_feed` (Cardano tickers), `escrow_update` (smart contract event flags).

---

## 7. Run & Build Instructions

Follow this sequential command guide to install dependencies, compile helper classes, run checks, and build production binaries:

```bash
# 1. Verify Local Toolchain Setup
flutter doctor -v

# 2. Retrieve pubspec dependencies
flutter pub get

# 3. Compile Freeze & JSON Serializers Code Generators
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Perform Code Quality and Syntactical Auditing
flutter analyze

# 5. Run Local Unit and Widget Tests
flutter test

# 6. Run Application in debug mode
flutter run

# 7. Compile Release APK (Android)
flutter build apk --release
```

---

## 8. Troubleshooting Guide

Below is the verified list of standard setup failures and how to recover from them:

### 🚨 Mismatched Dependencies / Unresolved Models Imports
*   **Cause**: Riverpod generators, Freezed models, or JSON serializers have not been compiled yet.
*   **Solution**: Execute the code generation build command: `flutter pub run build_runner build --delete-conflicting-outputs`.

### 🚨 iOS Pod Installation Failures on Apple Silicon (M1/M2/M3 Macs)
*   **Cause**: Architecture conflicts between CocoaPods and ARM64.
*   **Solution**: Re-install pods using the native arch translation layer:
    ```bash
    cd ios
    arch -x86_64 pod install --repo-update
    cd ..
    ```

### 🚨 Biometric local_auth Failures in iOS Simulator
*   **Cause**: Biometric hardware has not been enrolled inside the Simulator engine.
*   **Solution**: In the Simulator menu, navigate to **Features** $\rightarrow$ **Face ID** $\rightarrow$ Check **Enrolled**. Then re-authenticate.

---

## 9. Final Verification Checklist

Run through this checklist to guarantee the client application is fully synchronized and ready:

- [ ] **Compilation**: App compiles clean without warnings or build runner exceptions.
- [ ] **Splash Screen Animation**: ZeroPay sweep progresses, checks auth session, and redirects.
- [ ] **Onboarding & Authentication**: User can enter credentials or sign biometrically.
- [ ] **Home Dashboard**: Total balance displays; user can successfully hide values.
- [ ] **AI Price Negotiator**: Bidding counter-sliders update agreement probability gauges.
- [ ] **Decentralized Arbitration**: Validator consensus dials render needle offsets.
- [ ] **Offline Banner**: Disconnecting Wi-Fi triggers cached state warnings and queues transactions.
- [ ] **Production APK Build**: `flutter build apk --release` completes successfully.
