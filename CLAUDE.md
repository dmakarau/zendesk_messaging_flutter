# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Overview

Flutter plugin that bridges the Zendesk Native Messaging SDK to Flutter apps. Exposes iOS and Android native SDKs via a single Dart API using `MethodChannel` + `EventChannel`.

## Project Structure

```
lib/
  zendesk_messaging_flutter.dart   # Dart API — three channels, typed events
  src/
    zendesk_models.dart            # ZendeskUser, MessagingScreen, ZendeskEvent, PushResponsibility
ios/
  Classes/
    ZendeskMessagingFlutterPlugin.swift   # iOS native implementation (pure Swift, no ObjC bridge)
android/
  build.gradle
  src/main/kotlin/com/zendesk/zendesk_messaging_flutter/
    ZendeskMessagingFlutterPlugin.kt      # Android native implementation
  src/main/AndroidManifest.xml
example/
  lib/main.dart                          # Sample app
  android/build.gradle.kts
  ios/
test/
  zendesk_messaging_flutter_test.dart               # ZendeskUser tests
  zendesk_messaging_flutter_method_channel_test.dart # Event/screen/push model tests
```

## Channel Architecture

Three Flutter channels:

| Channel | Direction | Purpose |
|---|---|---|
| `MethodChannel("zendesk_messaging")` | Dart → Native | All method calls |
| `EventChannel("zendesk_messaging/events")` | Native → Dart | All 24 SDK event types |
| `MethodChannel("zendesk_messaging/callbacks")` | Native → Dart | `shouldHandleURL`, `onInvalidAuth` |

The callbacks channel is a *reverse* MethodChannel — native calls Dart. Dart registers handlers via `ZendeskMessaging.setUrlHandler()` and `ZendeskMessaging.setAuthHandler()`.

## Dart API

See `lib/zendesk_messaging_flutter.dart` and `lib/src/zendesk_models.dart` for the full surface. Key types:

- `ZendeskUser` — `id`, `externalId`, `authenticationType`
- `MessagingScreen` — sealed class: `MostRecentConversationScreen`, `ConversationsListScreen`, `NewConversationScreen`, `ConversationScreen(id)`
- `ExitAction` — `close` | `returnToConversationList`
- `ZendeskEvent` — sealed class with 24 subclasses (one per SDK event)
- `PushResponsibility` — `messagingShouldDisplay` | `messagingShouldNotDisplay` | `notFromMessaging`

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
- Events use `Zendesk.instance.addEventObserver` directly (Swift enum API) — `ZendeskBridge` is removed
- `сonversationUnreadCountChanged` has labeled associated values (`id:`, `timestamp:`, `data:`) — wildcards require explicit labels: `case .сonversationUnreadCountChanged(id: _, timestamp: _, data: let data)`
- **The `с` in `сonversationUnreadCountChanged` is Cyrillic, not ASCII** — copy from source rather than typing
- Capture `eventSink` as a local `let` before `DispatchQueue.main.async` to avoid `self` capture issues
- `shouldHandleURL` (MessagingDelegate) is called on the **main thread** by `ConversationViewCoordinator` — do NOT `DispatchQueue.main.async` it again or you get a deadlock. Call `callbackChannel.invokeMethod` directly, then block with `DispatchSemaphore(value: 0)` with a 0.2s timeout
- `onInvalidAuth` (AuthenticationDelegate) is called on a background thread — dispatch to main before calling `invokeMethod`
- APNs token arrives as raw `Data`; Dart sends hex string → convert with the `Data(hexString:)` extension at the bottom of the Swift file
- `ZendeskRole` is an Int enum — compare as `$0.role == .user ? "user" : "business"`, not `.rawValue`

## Android Implementation Notes

- `Zendesk.instance` returns a stub — never nil, but unusable until initialized
- Double-init guard: `companion object { private var initialized = false }`
- `show` calls `Zendesk.instance.messaging.showMessaging(activity)` — always full-screen Activity; `fullScreen` param is ignored
- Event sink calls must be dispatched on main thread via `mainHandler.post { eventSink?.success(map) }` — but only the sink dispatch, not the when-expression
- `shouldHandleURL` (MessagingDelegate) is called from `Fragment.lifecycleScope.launch` which defaults to `Dispatchers.Main` — do NOT `mainHandler.post` the `invokeMethod` call or you get a deadlock. Call directly, block with `CountDownLatch(1)` with 200ms timeout
- `ZendeskAuthenticationDelegate` is set in `onAttachedToEngine` (before initialization) — uses `mainHandler.post` since it can be called from any thread
- `UrlSource` enum values are SCREAMING_SNAKE_CASE — use the explicit `urlSourceName()` function to map to camelCase, do NOT use `.name.lowercase()` (it produces `link_message_action` not `linkMessageAction`)
- SDK dependency: `zendesk.messaging:messaging-android:2.38.+` from `zendesk.jfrog.io/artifactory/repo` — no credentials required

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

# Run Dart tests (46 tests)
flutter test
```

## Public API Coverage

Overall: **~100%** of the native SDK public API is implemented.

| Category | Total | Covered | Notes |
|---|---|---|---|
| Core (init, invalidate, getCurrentUser, loginUser, logoutUser) | 5 | 5 | ✓ |
| UI / Navigation (`show` + `MessagingScreen` x4 + `ExitAction`) | 5 | 5 | ✓ |
| Unread count (total + per-conversation) | 2 | 2 | ✓ |
| Conversation metadata (fields, tags, clears) | 6 | 6 | ✓ |
| Events (24 types) | 24 | 24 | ✓ typed sealed class |
| Push notifications | 4 | 4 | ✓ Android: displayNotification, smallIcon |
| Delegates / URL interception | 1 | 1 | ✓ reverse MethodChannel |
| Auth delegate | 1 | 1 | ✓ reverse MethodChannel |
| Page view events | 1 | 1 | ✓ |
| Analytics | 1 | 1 | ✓ |
| **Total** | **50** | **50** | |

## Commit Style

Short imperative description, no ticket prefix:
```
Add download transcript feature
Fix Android double-init guard
```
