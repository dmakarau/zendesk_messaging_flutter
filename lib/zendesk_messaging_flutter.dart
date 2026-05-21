import 'dart:async';
import 'package:flutter/services.dart';

import 'src/zendesk_models.dart';
export 'src/zendesk_models.dart';

class ZendeskMessaging {
  static const _channel = MethodChannel('zendesk_messaging');
  static const _events = EventChannel('zendesk_messaging/events');
  static const _callbacks = MethodChannel('zendesk_messaging/callbacks');

  static Stream<ZendeskEvent>? _eventStream;

  // ── Delegate handlers ───────────────────────────────────────────────────

  static Future<bool> Function(String url, String source)? _urlHandler;
  static Future<String> Function()? _authHandler;
  static bool _callbackHandlerRegistered = false;

  static void _ensureCallbackHandler() {
    if (!_callbackHandlerRegistered) {
      _callbacks.setMethodCallHandler(_onCallback);
      _callbackHandlerRegistered = true;
    }
  }

  static void setUrlHandler(Future<bool> Function(String url, String source) handler) {
    _urlHandler = handler;
    _ensureCallbackHandler();
  }

  static void setAuthHandler(Future<String> Function() handler) {
    _authHandler = handler;
    _ensureCallbackHandler();
  }

  static Future<dynamic> _onCallback(MethodCall call) async {
    switch (call.method) {
      case 'shouldHandleURL':
        final args = call.arguments as Map;
        return _urlHandler?.call(args['url'] as String, args['source'] as String) ?? false;
      case 'onInvalidAuth':
        return _authHandler?.call() ?? '';
    }
  }

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
