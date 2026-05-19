import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

void main() {
  test('ZendeskMessaging API is accessible', () {
    expect(ZendeskMessaging.events, isNotNull);
  });
}
