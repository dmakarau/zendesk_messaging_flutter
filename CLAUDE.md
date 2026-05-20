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

# Run from VS Code — launch.json is pre-configured, reads example/.dart_defines automatically

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

## Public API Coverage

Overall: ~**15%** of the native SDK public API is currently implemented.

Dev docs reference:
- iOS: https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/
- Android: https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/

| Category | Total | Covered | % | Notes |
|---|---|---|---|---|
| Core (init, invalidate, getCurrentUser, loginUser, logoutUser) | 5 | 3 | 60% | Missing: `invalidate`, `getCurrentUser` |
| UI / Navigation (`show` + `MessagingScreen` x4) | 5 | 1 | 20% | Missing: screen param, ExitAction |
| Unread count (total + per-conversation) | 2 | 1 | 50% | Missing: per-conversation overload |
| Conversation metadata (fields, tags, clears) | 6 | 0 | 0% | `setConversationFields`, `setConversationTags`, clears |
| Events (24 types) | 24 | 2 | 8% | Only `unreadMessageCountChanged` + `authenticationFailed` |
| Push notifications | 4 | 0 | 0% | Skip for simulator/emulator demos |
| Delegates / URL interception | 1 | 0 | 0% | `MessagingDelegate.shouldHandleURL` |
| Page view events | 1 | 0 | 0% | `sendPageViewEvent` |
| **Total** | **48** | **7** | **~15%** | |

### Demoable on simulator/emulator (no push required)

Next-priority features — all work without a real device or push setup:

1. **`MessagingScreen` navigation** — pass screen destination to `show()` ([iOS docs](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/multi_conversations_navigation_apis/), [Android docs](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/multi_conversations_navigation_apis/))
2. **Conversation metadata** — `setConversationFields`, `setConversationTags`, clears ([iOS](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/conversation_fields_and_tags/), [Android](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/conversation_fields_and_tags/))
3. **Full event forwarding** — 13 additional demoable event types ([iOS](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/ios/zendesk_sdk_events/), [Android](https://developer.zendesk.com/documentation/zendesk-web-widget-sdks/sdks/android/zendesk_sdk_events/))
4. **`getCurrentUser()`** — returns authenticated user details
5. **`invalidate()`** — SDK teardown
6. **`getUnreadMessageCount(conversationId:)`** — per-conversation unread count

Implementing all 6 would bring coverage to ~**65%**.

## Commit Style

Short imperative description, no ticket prefix (personal hackathon repo):
```
Add download transcript feature
Fix Android double-init guard
```
