import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';

void main() {
  // ── ZendeskEvent.fromMap ────────────────────────────────────────────────

  group('ZendeskEvent.fromMap', () {
    test('unreadMessageCountChanged', () {
      final e = ZendeskEvent.fromMap({
        'type': 'unreadMessageCountChanged',
        'totalUnreadCount': 3,
        'conversationId': 'conv-1',
        'unreadInConversation': 2,
      }) as UnreadMessageCountChangedEvent;
      expect(e.totalUnreadCount, 3);
      expect(e.conversationId, 'conv-1');
      expect(e.unreadInConversation, 2);
    });

    test('unreadMessageCountChanged — missing fields default to 0', () {
      final e = ZendeskEvent.fromMap({'type': 'unreadMessageCountChanged'})
          as UnreadMessageCountChangedEvent;
      expect(e.totalUnreadCount, 0);
      expect(e.conversationId, isNull);
      expect(e.unreadInConversation, 0);
    });

    test('authenticationFailed', () {
      expect(ZendeskEvent.fromMap({'type': 'authenticationFailed'}),
          isA<AuthenticationFailedEvent>());
    });

    test('fieldValidationFailed', () {
      expect(ZendeskEvent.fromMap({'type': 'fieldValidationFailed'}),
          isA<FieldValidationFailedEvent>());
    });

    test('connectionStatusChanged', () {
      final e = ZendeskEvent.fromMap(
              {'type': 'connectionStatusChanged', 'status': 'connected'})
          as ConnectionStatusChangedEvent;
      expect(e.status, 'connected');
    });

    test('conversationAdded', () {
      final e = ZendeskEvent.fromMap(
              {'type': 'conversationAdded', 'conversationId': 'c-1'})
          as ConversationAddedEvent;
      expect(e.conversationId, 'c-1');
    });

    test('conversationStarted', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationStarted',
        'id': 'ev-1',
        'conversationId': 'c-1',
        'timestamp': 1000,
      }) as ConversationStartedEvent;
      expect(e.id, 'ev-1');
      expect(e.conversationId, 'c-1');
      expect(e.timestamp, 1000);
    });

    test('conversationOpened — nullable conversationId', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationOpened',
        'id': 'ev-2',
        'timestamp': 2000,
      }) as ConversationOpenedEvent;
      expect(e.conversationId, isNull);
    });

    test('messagesShown — parses messages list', () {
      final e = ZendeskEvent.fromMap({
        'type': 'messagesShown',
        'id': 'ev-3',
        'conversationId': 'c-1',
        'timestamp': 3000,
        'messages': [
          {'id': 'm-1', 'role': 'user', 'timestamp': 100},
          {'id': 'm-2', 'role': 'business', 'timestamp': 200},
        ],
      }) as MessagesShownEvent;
      expect(e.messages.length, 2);
      expect(e.messages[0].role, 'user');
      expect(e.messages[1].id, 'm-2');
    });

    test('messagesShown — empty messages list', () {
      final e = ZendeskEvent.fromMap({
        'type': 'messagesShown',
        'id': 'ev-4',
        'conversationId': 'c-1',
        'timestamp': 4000,
      }) as MessagesShownEvent;
      expect(e.messages, isEmpty);
    });

    test('sendMessageFailed', () {
      final e = ZendeskEvent.fromMap(
              {'type': 'sendMessageFailed', 'message': 'network error'})
          as SendMessageFailedEvent;
      expect(e.message, 'network error');
    });

    test('sendMessageFailed — nullable message', () {
      final e = ZendeskEvent.fromMap({'type': 'sendMessageFailed'})
          as SendMessageFailedEvent;
      expect(e.message, isNull);
    });

    test('messagingOpened', () {
      final e = ZendeskEvent.fromMap(
              {'type': 'messagingOpened', 'id': 'ev-5', 'timestamp': 5000})
          as MessagingOpenedEvent;
      expect(e.id, 'ev-5');
      expect(e.timestamp, 5000);
    });

    test('messagingClosed', () {
      final e = ZendeskEvent.fromMap(
              {'type': 'messagingClosed', 'id': 'ev-6', 'timestamp': 6000})
          as MessagingClosedEvent;
      expect(e.timestamp, 6000);
    });

    test('newConversationButtonClicked', () {
      final e = ZendeskEvent.fromMap({
        'type': 'newConversationButtonClicked',
        'id': 'ev-7',
        'timestamp': 7000,
        'source': 'conversationList',
      }) as NewConversationButtonClickedEvent;
      expect(e.source, 'conversationList');
    });

    test('proactiveMessageDisplayed', () {
      final e = ZendeskEvent.fromMap({
        'type': 'proactiveMessageDisplayed',
        'id': 'ev-8',
        'timestamp': 8000,
        'proactiveMessageId': 'pm-1',
        'campaignId': 'camp-1',
      }) as ProactiveMessageDisplayedEvent;
      expect(e.proactiveMessageId, 'pm-1');
      expect(e.campaignId, 'camp-1');
    });

    test('proactiveMessageClicked', () {
      final e = ZendeskEvent.fromMap({
        'type': 'proactiveMessageClicked',
        'id': 'ev-9',
        'timestamp': 9000,
        'proactiveMessageId': 'pm-2',
        'campaignId': 'camp-2',
      }) as ProactiveMessageClickedEvent;
      expect(e.proactiveMessageId, 'pm-2');
    });

    test('conversationWithAgentRequested', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationWithAgentRequested',
        'id': 'ev-10',
        'timestamp': 10000,
        'conversationId': 'c-2',
      }) as ConversationWithAgentRequestedEvent;
      expect(e.conversationId, 'c-2');
    });

    test('conversationAgentAssigned', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationAgentAssigned',
        'id': 'ev-11',
        'timestamp': 11000,
        'conversationId': 'c-3',
      }) as ConversationAgentAssignedEvent;
      expect(e.conversationId, 'c-3');
    });

    test('conversationServedByAgent', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationServedByAgent',
        'id': 'ev-12',
        'timestamp': 12000,
        'conversationId': 'c-4',
        'agentId': 'a-1',
        'agentDisplayName': 'Alice',
        'agentMessageSource': 'agentWorkspace',
      }) as ConversationServedByAgentEvent;
      expect(e.agentId, 'a-1');
      expect(e.agentDisplayName, 'Alice');
      expect(e.agentMessageSource, 'agentWorkspace');
    });

    test('postbackButtonClicked', () {
      final e = ZendeskEvent.fromMap({
        'type': 'postbackButtonClicked',
        'id': 'ev-13',
        'timestamp': 13000,
        'conversationId': 'c-5',
        'actionName': 'book',
      }) as PostbackButtonClickedEvent;
      expect(e.actionName, 'book');
    });

    test('conversationExtensionOpened', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationExtensionOpened',
        'id': 'ev-14',
        'timestamp': 14000,
        'conversationId': 'c-6',
        'url': 'https://example.com',
      }) as ConversationExtensionOpenedEvent;
      expect(e.url, 'https://example.com');
    });

    test('conversationExtensionDisplayed', () {
      final e = ZendeskEvent.fromMap({
        'type': 'conversationExtensionDisplayed',
        'id': 'ev-15',
        'timestamp': 15000,
        'conversationId': 'c-7',
        'url': 'https://ext.example.com',
      }) as ConversationExtensionDisplayedEvent;
      expect(e.url, 'https://ext.example.com');
    });

    test('articleClicked', () {
      final e = ZendeskEvent.fromMap({
        'type': 'articleClicked',
        'id': 'ev-16',
        'timestamp': 16000,
        'articleId': 'art-1',
        'articleTitle': 'Help Article',
      }) as ArticleClickedEvent;
      expect(e.articleId, 'art-1');
      expect(e.articleTitle, 'Help Article');
    });

    test('articleClicked — nullable title', () {
      final e = ZendeskEvent.fromMap({
        'type': 'articleClicked',
        'id': 'ev-17',
        'timestamp': 17000,
        'articleId': 'art-2',
      }) as ArticleClickedEvent;
      expect(e.articleTitle, isNull);
    });

    test('articleBrowserClicked', () {
      final e = ZendeskEvent.fromMap({
        'type': 'articleBrowserClicked',
        'id': 'ev-18',
        'timestamp': 18000,
        'url': 'https://help.example.com',
      }) as ArticleBrowserClickedEvent;
      expect(e.url, 'https://help.example.com');
    });

    test('notificationDisplayed', () {
      final e = ZendeskEvent.fromMap({
        'type': 'notificationDisplayed',
        'id': 'ev-19',
        'timestamp': 19000,
        'conversationId': 'c-8',
      }) as NotificationDisplayedEvent;
      expect(e.conversationId, 'c-8');
    });

    test('notificationOpened', () {
      final e = ZendeskEvent.fromMap({
        'type': 'notificationOpened',
        'id': 'ev-20',
        'timestamp': 20000,
        'conversationId': 'c-9',
      }) as NotificationOpenedEvent;
      expect(e.conversationId, 'c-9');
    });

    test('unknown type returns null', () {
      expect(ZendeskEvent.fromMap({'type': 'unknownEvent'}), isNull);
    });

    test('missing type returns null', () {
      expect(ZendeskEvent.fromMap({}), isNull);
    });
  });

  // ── MessagingScreen.toMap ────────────────────────────────────────────────

  group('MessagingScreen.toMap', () {
    test('mostRecentConversation — default exitAction', () {
      expect(const MostRecentConversationScreen().toMap(),
          {'screen': 'mostRecentConversation', 'exitAction': 'close'});
    });

    test('mostRecentConversation — returnToConversationList', () {
      expect(
          const MostRecentConversationScreen(
                  exitAction: ExitAction.returnToConversationList)
              .toMap(),
          {
            'screen': 'mostRecentConversation',
            'exitAction': 'returnToConversationList'
          });
    });

    test('conversationsList has no exitAction', () {
      expect(const ConversationsListScreen().toMap(),
          {'screen': 'conversationsList'});
    });

    test('newConversation — default exitAction', () {
      expect(const NewConversationScreen().toMap(),
          {'screen': 'newConversation', 'exitAction': 'close'});
    });

    test('newConversation — returnToConversationList', () {
      expect(
          const NewConversationScreen(
                  exitAction: ExitAction.returnToConversationList)
              .toMap(),
          {
            'screen': 'newConversation',
            'exitAction': 'returnToConversationList'
          });
    });

    test('conversation — includes conversationId', () {
      expect(
          const ConversationScreen('abc').toMap(),
          {
            'screen': 'conversation',
            'conversationId': 'abc',
            'exitAction': 'close',
          });
    });

    test('conversation — returnToConversationList', () {
      expect(
          const ConversationScreen('abc',
                  exitAction: ExitAction.returnToConversationList)
              .toMap(),
          {
            'screen': 'conversation',
            'conversationId': 'abc',
            'exitAction': 'returnToConversationList',
          });
    });
  });

  // ── PushResponsibility.fromString ────────────────────────────────────────

  group('PushResponsibility.fromString', () {
    test('Android SCREAMING_SNAKE_CASE — should display', () {
      expect(PushResponsibility.fromString('MESSAGING_SHOULD_DISPLAY'),
          PushResponsibility.messagingShouldDisplay);
    });

    test('Android SCREAMING_SNAKE_CASE — should not display', () {
      expect(PushResponsibility.fromString('MESSAGING_SHOULD_NOT_DISPLAY'),
          PushResponsibility.messagingShouldNotDisplay);
    });

    test('Android SCREAMING_SNAKE_CASE — not from messaging', () {
      expect(PushResponsibility.fromString('NOT_FROM_MESSAGING'),
          PushResponsibility.notFromMessaging);
    });

    test('iOS camelCase — should display', () {
      expect(PushResponsibility.fromString('messagingShouldDisplay'),
          PushResponsibility.messagingShouldDisplay);
    });

    test('iOS camelCase — should not display', () {
      expect(PushResponsibility.fromString('messagingShouldNotDisplay'),
          PushResponsibility.messagingShouldNotDisplay);
    });

    test('iOS camelCase — not from messaging', () {
      expect(PushResponsibility.fromString('notFromMessaging'),
          PushResponsibility.notFromMessaging);
    });

    test('unknown defaults to notFromMessaging', () {
      expect(PushResponsibility.fromString('garbage'),
          PushResponsibility.notFromMessaging);
    });
  });
}
