import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

void main() {
  group('ZendeskUser.fromMap', () {
    test('parses all fields', () {
      final user = ZendeskUser.fromMap({
        'id': 'u-1',
        'externalId': 'ext-1',
        'authenticationType': 'jwt',
      });
      expect(user.id, 'u-1');
      expect(user.externalId, 'ext-1');
      expect(user.authenticationType, 'jwt');
    });

    test('externalId is nullable', () {
      final user = ZendeskUser.fromMap({'id': 'u-2', 'authenticationType': 'unauthenticated'});
      expect(user.externalId, isNull);
    });
  });
}
