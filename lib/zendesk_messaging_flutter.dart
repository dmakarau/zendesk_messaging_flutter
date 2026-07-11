import 'dart:async';
import 'package:flutter/services.dart';

import 'src/zendesk_models.dart';
export 'src/zendesk_models.dart';

class ZendeskMessaging {
  static const _channel = MethodChannel('zendesk_messaging');
  static const _events = EventChannel('zendesk_messaging/events');

  static Stream<ZendeskEvent>? _eventStream;

  // ── Core ────────────────────────────────────────────────────────────────

  static Future<void> initialize({required String channelKey}) {
    return _channel.invokeMethod('initialize', {'channelKey': channelKey});
  }

  static Future<void> invalidate() {
    _eventStream = null;
    return _channel.invokeMethod('invalidate');
  }

  static Future<ZendeskUser?> getCurrentUser() async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>>('getCurrentUser');
    return map == null ? null : ZendeskUser.fromMap(map);
  }

  static Future<void> loginUser({required String jwt}) {
    return _channel.invokeMethod('loginUser', {'jwt': jwt});
  }

  static Future<void> logoutUser() {
    return _channel.invokeMethod('logoutUser');
  }

  // ── UI / Navigation ─────────────────────────────────────────────────────

  static Future<void> show({
    bool fullScreen = true,
    MessagingScreen screen = const MostRecentConversationScreen(),
  }) {
    return _channel.invokeMethod('show', {
      'fullScreen': fullScreen,
      ...screen.toMap(),
    });
  }

  // ── URL handling ────────────────────────────────────────────────────────

  /// Declares how the native SDK should treat links tapped inside the
  /// messaging UI. See [UrlHandlingPolicy]. When native decides the app is
  /// responsible for a link, it is delivered as a [UrlClickedEvent] on the
  /// [events] stream (fire-and-forget — the SDK never blocks waiting for Dart).
  ///
  /// For [UrlHandlingPolicy.appHandlesMatching], [patterns] are substrings
  /// matched against each tapped link's absolute URL string.
  static Future<void> setUrlPolicy(
    UrlHandlingPolicy policy, {
    List<String> patterns = const [],
  }) {
    return _channel.invokeMethod('setUrlPolicy', {
      'policy': policy.name,
      'patterns': patterns,
    });
  }

  // ── Unread count ────────────────────────────────────────────────────────

  static Future<int> getUnreadMessageCount() async {
    final count = await _channel.invokeMethod<int>('getUnreadMessageCount');
    return count ?? 0;
  }

  static Future<int> getUnreadMessageCountForConversation({required String conversationId}) async {
    final count = await _channel.invokeMethod<int>(
      'getUnreadMessageCountForConversation',
      {'conversationId': conversationId},
    );
    return count ?? 0;
  }

  // ── Conversation metadata ───────────────────────────────────────────────

  static Future<void> setConversationFields(Map<String, Object> fields) {
    return _channel.invokeMethod('setConversationFields', {'fields': fields});
  }

  static Future<void> clearConversationFields() {
    return _channel.invokeMethod('clearConversationFields');
  }

  static Future<void> setConversationTags(List<String> tags) {
    return _channel.invokeMethod('setConversationTags', {'tags': tags});
  }

  static Future<void> clearConversationTags() {
    return _channel.invokeMethod('clearConversationTags');
  }

  // ── Page view events ────────────────────────────────────────────────────

  static Future<void> sendPageViewEvent({required String pageTitle, required String url}) {
    return _channel.invokeMethod('sendPageViewEvent', {'pageTitle': pageTitle, 'url': url});
  }

  // ── Push notifications ──────────────────────────────────────────────────

  /// [token] is a hex-encoded APNs token (iOS) or FCM registration token (Android).
  static Future<void> updatePushNotificationToken(String token) {
    return _channel.invokeMethod('updatePushNotificationToken', {'token': token});
  }

  /// [messageData] is the notification payload map from FCM (Android) or
  /// the userInfo dictionary converted to `Map<String,String>` (iOS).
  static Future<PushResponsibility> shouldBeDisplayed(Map<String, String> messageData) async {
    final raw = await _channel.invokeMethod<String>('shouldBeDisplayed', {'messageData': messageData});
    return PushResponsibility.fromString(raw ?? '');
  }

  /// Android only — displays the notification using the SDK's default UI.
  static Future<void> displayNotification(Map<String, String> messageData) {
    return _channel.invokeMethod('displayNotification', {'messageData': messageData});
  }

  /// Android only — sets the small icon used in the notification tray.
  /// [resourceName] must match a drawable resource name in the host app.
  static Future<void> setNotificationSmallIconResourceName(String resourceName) {
    return _channel.invokeMethod('setNotificationSmallIconResourceName', {'resourceName': resourceName});
  }

  // ── Analytics ───────────────────────────────────────────────────────────

  static Future<void> enableAnalyticsTracking({bool enabled = true}) {
    return _channel.invokeMethod('enableAnalyticsTracking', {'enabled': enabled});
  }

  // ── Events ──────────────────────────────────────────────────────────────

  static Stream<ZendeskEvent> get events {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .cast<Map<Object?, Object?>>()
        .map(ZendeskEvent.fromMap)
        .where((e) => e != null)
        .cast<ZendeskEvent>();
    return _eventStream!;
  }
}
