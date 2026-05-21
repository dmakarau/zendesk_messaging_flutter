import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

void main() {
  group('ZendeskEvent.fromMap', () {
    test('parses unreadMessageCountChanged', () {
      final event = ZendeskEvent.fromMap({
        'type': 'unreadMessageCountChanged',
        'totalUnreadCount': 3,
        'conversationId': 'conv-1',
        'unreadInConversation': 2,
      });
      expect(event, isA<UnreadMessageCountChangedEvent>());
      final e = event as UnreadMessageCountChangedEvent;
      expect(e.totalUnreadCount, 3);
      expect(e.conversationId, 'conv-1');
      expect(e.unreadInConversation, 2);
    });

    test('parses authenticationFailed', () {
      final event = ZendeskEvent.fromMap({'type': 'authenticationFailed'});
      expect(event, isA<AuthenticationFailedEvent>());
    });

    test('returns null for unknown type', () {
      final event = ZendeskEvent.fromMap({'type': 'unknownEvent'});
      expect(event, isNull);
    });
  });

  group('MessagingScreen.toMap', () {
    test('mostRecentConversation', () {
      const screen = MostRecentConversationScreen();
      expect(screen.toMap(), {'screen': 'mostRecentConversation', 'exitAction': 'close'});
    });

    test('conversationsList', () {
      const screen = ConversationsListScreen();
      expect(screen.toMap(), {'screen': 'conversationsList'});
    });

    test('conversation with returnToList', () {
      const screen = ConversationScreen('abc', exitAction: ExitAction.returnToConversationList);
      expect(screen.toMap(), {
        'screen': 'conversation',
        'conversationId': 'abc',
        'exitAction': 'returnToConversationList',
      });
    });
  });

  group('PushResponsibility.fromString', () {
    test('parses Android enum name', () {
      expect(PushResponsibility.fromString('MESSAGING_SHOULD_DISPLAY'), PushResponsibility.messagingShouldDisplay);
    });

    test('parses iOS camel name', () {
      expect(PushResponsibility.fromString('messagingShouldNotDisplay'), PushResponsibility.messagingShouldNotDisplay);
    });

    test('unknown defaults to notFromMessaging', () {
      expect(PushResponsibility.fromString('garbage'), PushResponsibility.notFromMessaging);
    });
  });
}
