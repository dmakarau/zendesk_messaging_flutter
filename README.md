# zendesk_messaging_flutter

A Flutter plugin for the Zendesk Messaging SDK (iOS). Lets Flutter developers integrate Zendesk Messaging with 3 lines of Dart — no Xcode, no CocoaPods, no native code required.

> **Hackathon prototype.** iOS only. Built during the SDKs Hackathon May 2026.

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

That's it. CocoaPods pulls in `ZendeskSDKMessaging` automatically on the next build.

## Usage

```dart
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

// 1. Initialize once at app start
await ZendeskMessaging.initialize(channelKey: 'YOUR_CHANNEL_KEY');

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
| `show()` | Present the native conversation UI. |
| `getUnreadMessageCount()` | Returns total unread message count. |
| `events` | Stream of SDK events (unread count changes, auth failures). |

## Requirements

- iOS 14.0+
- Flutter 3.0+

## How it works

The plugin bridges Flutter's `MethodChannel` / `EventChannel` to the native `ZendeskSDKMessaging` iOS framework via a small Obj-C bridge. Calling `show()` presents the native `ConversationViewController` over the Flutter root view — the full native SDK UI, zero Flutter rebuilds.
