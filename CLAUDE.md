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

Two Flutter channels:

| Channel | Direction | Purpose |
|---|---|---|
| `MethodChannel("zendesk_messaging")` | Dart → Native | All method calls |
| `EventChannel("zendesk_messaging/events")` | Native → Dart | All SDK event types + synthetic `urlClicked` |

There is **no reverse callbacks channel**. The native `MessagingDelegate.shouldHandleUrl` is a *synchronous* `Bool` called on the main thread, so it cannot round-trip to Dart without deadlocking. Instead:
- **URL taps** — Dart declares a policy via `ZendeskMessaging.setUrlPolicy(UrlHandlingPolicy, {patterns})`. Native decides synchronously (`sdkOpens` / `appHandlesAll` / `appHandlesMatching` by substring); when the app is responsible it emits a `urlClicked` event and returns `false` so the SDK doesn't open the link.
- **Auth expiry** — no delegate. The SDK emits `authenticationFailed`; Dart listens, fetches a fresh JWT, and calls `loginUser` again.

## Dart API

See `lib/zendesk_messaging_flutter.dart` and `lib/src/zendesk_models.dart` for the full surface. Key types:

- `ZendeskUser` — `id`, `externalId`, `authenticationType`
- `MessagingScreen` — sealed class: `MostRecentConversationScreen`, `ConversationsListScreen`, `NewConversationScreen`, `ConversationScreen(id)`
- `ExitAction` — `close` | `returnToConversationList`
- `ZendeskEvent` — sealed class with 26 SDK subclasses + synthetic `UrlClickedEvent`
- `UrlHandlingPolicy` — `sdkOpens` | `appHandlesAll` | `appHandlesMatching`
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
- `shouldHandleURL` (MessagingDelegate) is a **synchronous** `Bool` called on the main thread — do NOT block it on a Dart round-trip (deadlock). Decide from the stored `urlPolicy`/`urlPatterns`; on interception emit a `urlClicked` event and return `false`
- No `AuthenticationDelegate` — the SDK emits an `.authenticationFailed` event which flows through the event stream; Dart re-`loginUser`s
- APNs token arrives as raw `Data`; Dart sends hex string → convert with the **failable** `Data(hexString:)` extension (returns `nil` on odd-length/non-hex input; the handler errors instead of forwarding garbage)
- `ZendeskRole` is an Int enum — compare as `$0.role == .user ? "user" : "business"`, not `.rawValue`
- The ObjC `ZendeskBridge` is deleted; the plugin is pure Swift

## Android Implementation Notes

- `Zendesk.instance` returns a stub — never nil, but unusable until initialized
- Double-init guard: `companion object { private var initialized = false }`
- `show` calls `Zendesk.instance.messaging.showMessaging(activity)` — always full-screen Activity; `fullScreen` param is ignored
- Event sink calls must be dispatched on main thread via `mainHandler.post { eventSink?.success(map) }` — but only the sink dispatch, not the when-expression
- `shouldHandleUrl` (MessagingDelegate) is a **synchronous** `Bool` called on `Dispatchers.Main` — do NOT block on a Dart round-trip (deadlock). Decide from the stored `urlPolicy`/`urlPatterns`; on interception `mainHandler.post` a `urlClicked` event and return `false`
- No `ZendeskAuthenticationDelegate` — rely on the `ZendeskEvent.AuthenticationFailed` event; Dart re-`loginUser`s. `Messaging.setDelegate(null)` is cleared in `onDetachedFromEngine`
- `initialize` / `displayNotification` / `setNotificationSmallIconResourceName` use the `applicationContext` captured in `onAttachedToEngine` — they do **not** require an attached Activity (only `show` does)
- Emit `event.id.toString()` and normalize enum names with `enumToCamel(...)` so wire values match iOS camelCase (`CONNECTING_REALTIME` → `connectingRealtime`). Never `.name.lowercase()`
- `UrlSource` keeps its own explicit `urlSourceName()` map (the WebView casing `webViewMessageAction` doesn't fall out of `enumToCamel`)
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

# Run Dart tests (61 tests)
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
| Events (26 types) | 26 | 26 | ✓ typed sealed class (`fieldValidationFailed` Android-only; `metadataSuccess`/`metadataFailure` added) |
| Push notifications | 4 | 4 | ✓ Android: displayNotification, smallIcon |
| URL interception | 1 | 1 | ✓ policy + `urlClicked` event (no reverse channel) |
| Auth expiry | 1 | 1 | ✓ `authenticationFailed` event → re-`loginUser` |
| Page view events | 1 | 1 | ✓ |
| Analytics | 1 | 1 | ✓ |
| **Total** | **52** | **52** | |

## Commit Style

Short imperative description, no ticket prefix:
```
Add download transcript feature
Fix Android double-init guard
```
