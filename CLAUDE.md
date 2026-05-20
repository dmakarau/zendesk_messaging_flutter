# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Overview

Flutter plugin that bridges the Zendesk Native Messaging SDK to Flutter apps. Exposes iOS and Android native SDKs via a single Dart API using `MethodChannel` + `EventChannel`.

## Project Structure

```
lib/
  zendesk_messaging_flutter.dart   # Dart API (MethodChannel + EventChannel)
ios/
  Classes/
    ZendeskMessagingFlutterPlugin.swift   # iOS native implementation
    ZendeskBridge.h / .m                  # ObjC bridge for Swift/ObjC interop
android/
  build.gradle                          # Library build config, JFrog dep
  src/main/kotlin/com/zendesk/zendesk_messaging_flutter/
    ZendeskMessagingFlutterPlugin.kt      # Android native implementation
  src/main/AndroidManifest.xml
example/
  lib/main.dart                          # Sample app (Flutter)
  android/build.gradle.kts              # App-level build — contains JFrog repo
  ios/                                   # Standard Flutter iOS app wrapper
```

## Dart API

Five methods over `MethodChannel("zendesk_messaging")`:

| Method | Args | Notes |
|--------|------|-------|
| `initialize` | `channelKey: String` | Must be called before anything else |
| `loginUser` | `jwt: String` | Zendesk JWT auth |
| `logoutUser` | — | |
| `show` | `fullScreen: bool = true` | iOS-only distinction; Android ignores |
| `getUnreadMessageCount` | — | Returns `int` |

Events via `EventChannel("zendesk_messaging/events")`:
- `{"type": "unreadMessageCountChanged", "count": int}`
- `{"type": "authenticationFailed"}`

## Platform-Specific Channel Keys

**Critical**: Channel keys are platform-specific — an iOS key will not work on Android (and vice versa). Each key encodes a settings URL that maps to a specific `sunco_config.integration.type` (`ios` vs `android`). Using the wrong key results in permanent "Offline" state in the messaging UI.

Always use `Platform.isAndroid` to select the correct key:
```dart
import 'dart:io';
final channelKey = Platform.isAndroid ? _androidChannelKey : _iosChannelKey;
```

## iOS Implementation Notes

- `Zendesk.instance` is optional — check for `nil` before use
- `show` wraps the messaging VC in `UINavigationController` so the close button renders correctly
- `fullScreen` controls `modalPresentationStyle` (.fullScreen vs .pageSheet)
- Events come as integer codes via `ZendeskBridge`: 0 = unreadMessageCountChanged, 3 = authenticationFailed
- Dispatch event sink calls on main thread via `DispatchQueue.main`

## Android Implementation Notes

- `Zendesk.instance` returns a stub — never nil, but unusable until initialized
- Double-init guard: `companion object { private var initialized = false }`
- `show` calls `Zendesk.instance.messaging.showMessaging(activity)` — always full-screen Activity; `fullScreen` param is ignored silently
- Event sink calls must be dispatched on main thread via `Handler(Looper.getMainLooper()).post`
- SDK dependency: `zendesk.messaging:messaging-android:2.38.0` from JFrog

## Build Commands

```bash
# Copy and fill in channel keys before first run
cp example/.dart_defines.example example/.dart_defines

# Run example app on connected device/emulator
cd example && flutter run --dart-define-from-file=.dart_defines

# Build Android APK
cd example && flutter build apk --dart-define-from-file=.dart_defines

# Build iOS
cd example && flutter build ios --dart-define-from-file=.dart_defines

# Run Dart tests
flutter test
```

## Android JFrog Credentials

`messaging-android` is hosted on the internal JFrog repo (`zdrepo.jfrog.io`). Credentials must be set:

```
~/.gradle/gradle.properties:
  ARTIFACTORY_USERNAME=<username>
  ARTIFACTORY_API_KEY=<api_key>
```

Without these, the Android build will fail to resolve the `messaging-android` dependency.

## Commit Style

Short imperative description, no ticket prefix (personal hackathon repo):
```
Add download transcript feature
Fix Android double-init guard
```
