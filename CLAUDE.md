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
- Events use `Zendesk.instance.addEventObserver` directly (Swift enum API) — do NOT route through `ZendeskBridge`, which uses the deprecated ObjC enum and returns `NSNumber` payloads that cannot be cast to `ConversationUnreadCountChange`
- `сonversationUnreadCountChanged` has labeled associated values (`id:`, `timestamp:`, `data:`) — wildcards require explicit labels: `case .сonversationUnreadCountChanged(id: _, timestamp: _, data: let data)`
- Note: the `с` in `сonversationUnreadCountChanged` is Cyrillic, not ASCII — copy from source rather than typing
- Capture `eventSink` as a local `let` before `DispatchQueue.main.async` to avoid `self` capture issues inside the async block

## Android Implementation Notes

- `Zendesk.instance` returns a stub — never nil, but unusable until initialized
- Double-init guard: `companion object { private var initialized = false }`
- `show` calls `Zendesk.instance.messaging.showMessaging(activity)` — always full-screen Activity; `fullScreen` param is ignored silently
- Event sink calls must be dispatched on main thread via `Handler(Looper.getMainLooper()).post`
- SDK dependency: `zendesk.messaging:messaging-android:2.38.+` from the public Zendesk Maven repo (`zendesk.jfrog.io/artifactory/repo`) — no credentials required

## Build Commands

```bash
# Copy and fill in channel keys before first run
cp example/.dart_defines.example example/.dart_defines

# Run example app on connected device/emulator
cd example && flutter run --dart-define-from-file=.dart_defines

# Run from VS Code — launch.json is pre-configured, reads example/.dart_defines automatically

# Build Android APK
cd example && flutter build apk --dart-define-from-file=.dart_defines

# Build iOS
cd example && flutter build ios --dart-define-from-file=.dart_defines

# Run Dart tests
flutter test
```

## Public API Coverage

Overall: ~**15%** of the native SDK public API is currently implemented.

Dev docs:
- iOS: https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/
- Android: https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/

| Category | Total | Covered | % | Not covered |
|---|---|---|---|---|
| Core (init, invalidate, getCurrentUser, loginUser, logoutUser) | 5 | 3 | 60% | `invalidate`, `getCurrentUser` |
| UI / Navigation (`show` + `MessagingScreen` x4) | 5 | 1 | 20% | screen param, `ExitAction` |
| Unread count (total + per-conversation) | 2 | 1 | 50% | per-conversation overload |
| Conversation metadata (fields, tags, clears) | 6 | 0 | 0% | `setConversationFields`, `setConversationTags`, clears |
| Events (24 types) | 24 | 2 | 8% | 22 types — see [iOS](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/zendesk_sdk_events/) / [Android](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/zendesk_sdk_events/) docs |
| Push notifications | 4 | 0 | 0% | token registration, display, `shouldBeDisplayed`, icon — see [iOS](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/push_notifications/) / [Android](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/push_notifications/) docs |
| Delegates / URL interception | 1 | 0 | 0% | `MessagingDelegate.shouldHandleURL` |
| Page view events | 1 | 0 | 0% | `sendPageViewEvent` |
| **Total** | **48** | **7** | **~15%** | |

## Commit Style

Short imperative description, no ticket prefix:
```
Add download transcript feature
Fix Android double-init guard
```
