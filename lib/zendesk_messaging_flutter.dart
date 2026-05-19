import 'dart:async';
import 'package:flutter/services.dart';

class ZendeskMessaging {
  static const _channel = MethodChannel('zendesk_messaging');
  static const _events = EventChannel('zendesk_messaging/events');

  static Stream<Map>? _eventStream;

  static Future<void> initialize({required String channelKey}) {
    return _channel.invokeMethod('initialize', {'channelKey': channelKey});
  }

  static Future<void> loginUser({required String jwt}) {
    return _channel.invokeMethod('loginUser', {'jwt': jwt});
  }

  static Future<void> logoutUser() {
    return _channel.invokeMethod('logoutUser');
  }

  static Future<void> show() {
    return _channel.invokeMethod('show');
  }

  static Future<int> getUnreadMessageCount() async {
    final count = await _channel.invokeMethod<int>('getUnreadMessageCount');
    return count ?? 0;
  }

  static Stream<Map> get events {
    _eventStream ??= _events.receiveBroadcastStream().cast<Map>();
    return _eventStream!;
  }
}
