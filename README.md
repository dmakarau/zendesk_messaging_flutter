# zendesk_messaging_flutter

A Flutter plugin for the Zendesk Messaging SDK (iOS + Android). Lets Flutter developers integrate Zendesk Messaging with a few lines of Dart — no Xcode, no CocoaPods, no native code required.

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

CocoaPods pulls in `ZendeskSDKMessaging` automatically on the next iOS build. The Android SDK is fetched from the public Zendesk Maven repository — no credentials required.

## Usage

Channel keys are platform-specific — an iOS key will not work on Android. Supply them via `--dart-define`:

```bash
flutter run \
  --dart-define=IOS_CHANNEL_KEY=your-ios-key \
  --dart-define=ANDROID_CHANNEL_KEY=your-android-key
```

Or use a `--dart-define-from-file` JSON file (recommended):

```bash
cp example/.dart_defines.example example/.dart_defines
# fill in your keys, then:
cd example && flutter run --dart-define-from-file=.dart_defines
```

`.dart_defines` is gitignored — your keys stay local. A VS Code `launch.json` is included that reads the file automatically.

### Initialize and show

```dart
import 'dart:io';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

const _iosKey     = String.fromEnvironment('IOS_CHANNEL_KEY');
const _androidKey = String.fromEnvironment('ANDROID_CHANNEL_KEY');

// Initialize once at app start
await ZendeskMessaging.initialize(
  channelKey: Platform.isAndroid ? _androidKey : _iosKey,
);

// Authenticate (optional)
await ZendeskMessaging.loginUser(jwt: 'USER_JWT');

// Open the conversation UI
await ZendeskMessaging.show();
```

### Navigation screens

```dart
// Open the conversations list
await ZendeskMessaging.show(screen: const ConversationsListScreen());

// Open a new conversation
await ZendeskMessaging.show(screen: const NewConversationScreen());

// Open the most recent conversation, with a back button to the list
await ZendeskMessaging.show(
  screen: const MostRecentConversationScreen(
    exitAction: ExitAction.returnToConversationList,
  ),
);

// Open a specific conversation by ID
await ZendeskMessaging.show(
  screen: ConversationScreen('conv-id'),
);
```

### Typed events

```dart
ZendeskMessaging.events.listen((event) {
  switch (event) {
    case UnreadMessageCountChangedEvent(:final totalUnreadCount):
      print('Unread: $totalUnreadCount');
    case AuthenticationFailedEvent():
      print('Auth failed — refresh JWT');
    case ConnectionStatusChangedEvent(:final status):
      print('Connection: $status');
    case MessagingClosedEvent():
      print('User closed messaging');
    default:
      break;
  }
});
```

### URL interception

```dart
ZendeskMessaging.setUrlHandler((url, source) async {
  // Return true to handle it yourself; false to let the SDK open it.
  if (url.startsWith('myapp://')) {
    handleDeepLink(url);
    return true;
  }
  return false;
});
```

### Authentication delegate

```dart
ZendeskMessaging.setAuthHandler(() async {
  // Called when the SDK's JWT expires. Return a fresh token.
  return await fetchFreshJwt();
});
```

### Conversation metadata

```dart
// Set custom fields before or after show()
await ZendeskMessaging.setConversationFields({'plan': 'enterprise', 'account_id': 42});
await ZendeskMessaging.setConversationTags(['mobile', 'flutter']);

await ZendeskMessaging.clearConversationFields();
await ZendeskMessaging.clearConversationTags();
```

### Unread count

```dart
final total = await ZendeskMessaging.getUnreadMessageCount();
final inConv = await ZendeskMessaging.getUnreadMessageCountForConversation(
  conversationId: 'conv-id',
);
```

### Push notifications

```dart
// Register token (call from your FCM/APNs token callback)
// iOS: pass the hex-encoded APNs device token
// Android: pass the FCM registration token
await ZendeskMessaging.updatePushNotificationToken(token);

// In your notification handler:
final responsibility = await ZendeskMessaging.shouldBeDisplayed(messageData);
if (responsibility == PushResponsibility.messagingShouldDisplay) {
  await ZendeskMessaging.displayNotification(messageData); // Android only
}

// Android only — set a custom small icon
await ZendeskMessaging.setNotificationSmallIconResourceName('ic_notification');
```

### Page view events (Guide analytics)

```dart
await ZendeskMessaging.sendPageViewEvent(
  pageTitle: 'Help Center',
  url: 'https://support.example.com',
);
```

### Other

```dart
// Get current authenticated user
final user = await ZendeskMessaging.getCurrentUser();
print('${user?.id} (${user?.authenticationType})');

// Tear down (e.g. on logout)
await ZendeskMessaging.invalidate();

// Analytics
await ZendeskMessaging.enableAnalyticsTracking(enabled: true);
```

## Full API Reference

| Method | Returns | Description |
|---|---|---|
| `initialize(channelKey:)` | `Future<void>` | Initialize the SDK. Call once at app start. |
| `invalidate()` | `Future<void>` | Tear down the SDK. |
| `getCurrentUser()` | `Future<ZendeskUser?>` | Returns the authenticated user, or null. |
| `loginUser(jwt:)` | `Future<void>` | Authenticate with a JWT. |
| `logoutUser()` | `Future<void>` | Log out the current user. |
| `show({fullScreen, screen})` | `Future<void>` | Present the native conversation UI. |
| `getUnreadMessageCount()` | `Future<int>` | Total unread count across all conversations. |
| `getUnreadMessageCountForConversation(conversationId:)` | `Future<int>` | Unread count for one conversation. |
| `setConversationFields(fields)` | `Future<void>` | Set custom conversation fields. |
| `clearConversationFields()` | `Future<void>` | Clear custom conversation fields. |
| `setConversationTags(tags)` | `Future<void>` | Set conversation tags. |
| `clearConversationTags()` | `Future<void>` | Clear conversation tags. |
| `sendPageViewEvent(pageTitle:url:)` | `Future<void>` | Send a Guide analytics page view. |
| `updatePushNotificationToken(token)` | `Future<void>` | Register APNs/FCM token. |
| `shouldBeDisplayed(messageData)` | `Future<PushResponsibility>` | Check if a push belongs to Zendesk. |
| `displayNotification(messageData)` | `Future<void>` | Display notification (Android only). |
| `setNotificationSmallIconResourceName(name)` | `Future<void>` | Set notification icon (Android only). |
| `enableAnalyticsTracking(enabled:)` | `Future<void>` | Toggle internal analytics. |
| `setUrlHandler(handler)` | `void` | Intercept URL taps in the messaging UI. |
| `setAuthHandler(handler)` | `void` | Provide a fresh JWT on auth expiry. |
| `events` | `Stream<ZendeskEvent>` | Stream of all typed SDK events. |

### Event types

`ZendeskEvent` is a sealed class. All 24 SDK events are covered:

`UnreadMessageCountChangedEvent`, `AuthenticationFailedEvent`, `FieldValidationFailedEvent`, `ConnectionStatusChangedEvent`, `ConversationAddedEvent`, `ConversationStartedEvent`, `ConversationOpenedEvent`, `MessagesShownEvent`, `SendMessageFailedEvent`, `MessagingOpenedEvent`, `MessagingClosedEvent`, `NewConversationButtonClickedEvent`, `ProactiveMessageDisplayedEvent`, `ProactiveMessageClickedEvent`, `ConversationWithAgentRequestedEvent`, `ConversationAgentAssignedEvent`, `ConversationServedByAgentEvent`, `PostbackButtonClickedEvent`, `ConversationExtensionOpenedEvent`, `ConversationExtensionDisplayedEvent`, `ArticleClickedEvent`, `ArticleBrowserClickedEvent`, `NotificationDisplayedEvent`, `NotificationOpenedEvent`

## Requirements

- iOS 14.0+
- Android API 21+
- Flutter 3.0+

## How it works

Three Flutter channels bridge Dart to the native SDKs:

| Channel | Direction | Purpose |
|---|---|---|
| `MethodChannel("zendesk_messaging")` | Dart → Native | All method calls |
| `EventChannel("zendesk_messaging/events")` | Native → Dart | SDK events |
| `MethodChannel("zendesk_messaging/callbacks")` | Native → Dart | URL interception, auth delegate |

- **iOS** — Swift plugin conforming to `MessagingDelegate` and `AuthenticationDelegate`. `show()` presents the native `ConversationViewController` wrapped in a `UINavigationController`.
- **Android** — Kotlin plugin using the public `zendesk.messaging:messaging-android` SDK. `show()` launches the native messaging Activity (always full-screen on Android).
