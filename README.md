# zendesk_messaging_flutter

A Flutter plugin for the Zendesk Messaging SDK (iOS + Android). Lets Flutter developers integrate Zendesk Messaging with 3 lines of Dart — no Xcode, no CocoaPods, no native code required.

> **Hackathon prototype.** Built during the SDKs Hackathon May 2026.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  zendesk_messaging_flutter:
    git:
      url: https://github.com/dmakarau/zendesk_messaging_flutter.git
```

Then run:

```bash
flutter pub get
```

CocoaPods pulls in `ZendeskSDKMessaging` automatically on the next iOS build.

### Android

The Android SDK is hosted on an internal JFrog repository. Add credentials to `~/.gradle/gradle.properties`:

```
ARTIFACTORY_USERNAME=<your-username>
ARTIFACTORY_API_KEY=<your-api-key>
```

## Usage

Channel keys are platform-specific — an iOS key will not work on Android. Use `--dart-define` to supply them:

```bash
flutter run \
  --dart-define=IOS_CHANNEL_KEY=your-ios-key \
  --dart-define=ANDROID_CHANNEL_KEY=your-android-key
```

Or use a `--dart-define-from-file` JSON file (recommended):

```bash
# Copy the example and fill in your keys
cp example/.dart_defines.example example/.dart_defines
cd example && flutter run --dart-define-from-file=.dart_defines
```

`.dart_defines` is gitignored — your keys stay local.

**VS Code**: a `launch.json` is included — just add your `.dart_defines` file and hit Run.

### Dart

```dart
import 'dart:io';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

const _iosChannelKey = String.fromEnvironment('IOS_CHANNEL_KEY');
const _androidChannelKey = String.fromEnvironment('ANDROID_CHANNEL_KEY');

// 1. Initialize once at app start
final channelKey = Platform.isAndroid ? _androidChannelKey : _iosChannelKey;
await ZendeskMessaging.initialize(channelKey: channelKey);

// 2. Optionally authenticate
await ZendeskMessaging.loginUser(jwt: 'USER_JWT');

// 3. Open the conversation UI
await ZendeskMessaging.show();
```

### Listen to events

```dart
ZendeskMessaging.events.listen((event) {
  if (event['type'] == 'unreadMessageCountChanged') {
    print('Unread: ${event['count']}');
  }
});
```

### Full API

| Method | Description |
|---|---|
| `initialize(channelKey:)` | Initialize the SDK. Call once at app start. |
| `loginUser(jwt:)` | Authenticate a user with a JWT. |
| `logoutUser()` | Log out the current user. |
| `show({fullScreen})` | Present the native conversation UI. Pass `fullScreen: false` for a page sheet (iOS only). |
| `getUnreadMessageCount()` | Returns total unread message count. |
| `events` | Stream of SDK events (unread count changes, auth failures). |

## Example App

The example app (`example/`) demonstrates the full flow:

- **Login / Logout** — tap the person icon in the app bar to paste a JWT and authenticate; tap the logout icon to sign out
- **Open conversation** — "Contact Support" button launches the native messaging UI full-screen
- **Open as sheet** — "Open as sheet" presents it as a page sheet (iOS only)
- **Unread badge** — red badge on the button updates when new messages arrive

## Requirements

- iOS 14.0+
- Android API 21+
- Flutter 3.0+

## How it works

The plugin bridges Flutter's `MethodChannel` / `EventChannel` to the native SDKs on each platform:

- **iOS** — Swift plugin wrapping `ZendeskSDKMessaging` via a small Obj-C bridge. `show()` presents the native `ConversationViewController` over the Flutter root view.
- **Android** — Kotlin plugin wrapping `zendesk.messaging:messaging-android`. `show()` launches the native messaging Activity.
