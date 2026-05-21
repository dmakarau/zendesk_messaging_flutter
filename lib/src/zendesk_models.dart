class ZendeskUser {
  const ZendeskUser({
    required this.id,
    this.externalId,
    required this.authenticationType,
  });

  final String id;
  final String? externalId;

  /// One of: 'jwt', 'sessionToken', 'unauthenticated'
  final String authenticationType;

  factory ZendeskUser.fromMap(Map<Object?, Object?> map) => ZendeskUser(
        id: map['id'] as String,
        externalId: map['externalId'] as String?,
        authenticationType: map['authenticationType'] as String,
      );
}

// ── MessagingScreen ───────────────────────────────────────────────────────

enum ExitAction { close, returnToConversationList }

sealed class MessagingScreen {
  const MessagingScreen();

  Map<String, Object?> toMap();
}

final class MostRecentConversationScreen extends MessagingScreen {
  const MostRecentConversationScreen({this.exitAction = ExitAction.close});
  final ExitAction exitAction;

  @override
  Map<String, Object?> toMap() => {
        'screen': 'mostRecentConversation',
        'exitAction': exitAction.name,
      };
}

final class ConversationsListScreen extends MessagingScreen {
  const ConversationsListScreen();

  @override
  Map<String, Object?> toMap() => {'screen': 'conversationsList'};
}

final class NewConversationScreen extends MessagingScreen {
  const NewConversationScreen({this.exitAction = ExitAction.close});
  final ExitAction exitAction;

  @override
  Map<String, Object?> toMap() => {
        'screen': 'newConversation',
        'exitAction': exitAction.name,
      };
}

final class ConversationScreen extends MessagingScreen {
  const ConversationScreen(this.conversationId, {this.exitAction = ExitAction.close});
  final String conversationId;
  final ExitAction exitAction;

  @override
  Map<String, Object?> toMap() => {
        'screen': 'conversation',
        'conversationId': conversationId,
        'exitAction': exitAction.name,
      };
}

// ── Push ──────────────────────────────────────────────────────────────────

enum PushResponsibility {
  messagingShouldDisplay,
  messagingShouldNotDisplay,
  notFromMessaging;

  static PushResponsibility fromString(String v) => switch (v) {
        'MESSAGING_SHOULD_DISPLAY' || 'messagingShouldDisplay' => messagingShouldDisplay,
        'MESSAGING_SHOULD_NOT_DISPLAY' || 'messagingShouldNotDisplay' => messagingShouldNotDisplay,
        _ => notFromMessaging,
      };
}

// ── Events ────────────────────────────────────────────────────────────────

class ZendeskMessage {
  const ZendeskMessage({required this.id, required this.role, required this.timestamp});
  final String id;

  /// 'user' or 'business'
  final String role;
  final int timestamp;

  factory ZendeskMessage.fromMap(Map<Object?, Object?> map) => ZendeskMessage(
        id: map['id'] as String,
        role: map['role'] as String,
        timestamp: map['timestamp'] as int,
      );
}

sealed class ZendeskEvent {
  const ZendeskEvent();

  static ZendeskEvent? fromMap(Map<Object?, Object?> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'unreadMessageCountChanged' => UnreadMessageCountChangedEvent(
          totalUnreadCount: map['totalUnreadCount'] as int? ?? 0,
          conversationId: map['conversationId'] as String?,
          unreadInConversation: map['unreadInConversation'] as int? ?? 0,
        ),
      'authenticationFailed' => const AuthenticationFailedEvent(),
      'fieldValidationFailed' => const FieldValidationFailedEvent(),
      'connectionStatusChanged' => ConnectionStatusChangedEvent(status: map['status'] as String),
      'conversationAdded' => ConversationAddedEvent(conversationId: map['conversationId'] as String),
      'conversationStarted' => ConversationStartedEvent(
          id: map['id'] as String,
          conversationId: map['conversationId'] as String,
          timestamp: map['timestamp'] as int,
        ),
      'conversationOpened' => ConversationOpenedEvent(
          id: map['id'] as String,
          conversationId: map['conversationId'] as String?,
          timestamp: map['timestamp'] as int,
        ),
      'messagesShown' => MessagesShownEvent(
          id: map['id'] as String,
          conversationId: map['conversationId'] as String,
          timestamp: map['timestamp'] as int,
          messages: (map['messages'] as List?)
                  ?.map((m) => ZendeskMessage.fromMap(m as Map<Object?, Object?>))
                  .toList() ??
              [],
        ),
      'sendMessageFailed' => SendMessageFailedEvent(message: map['message'] as String?),
      'messagingOpened' => MessagingOpenedEvent(id: map['id'] as String, timestamp: map['timestamp'] as int),
      'messagingClosed' => MessagingClosedEvent(id: map['id'] as String, timestamp: map['timestamp'] as int),
      'newConversationButtonClicked' => NewConversationButtonClickedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          source: map['source'] as String,
        ),
      'proactiveMessageDisplayed' => ProactiveMessageDisplayedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          proactiveMessageId: map['proactiveMessageId'] as String,
          campaignId: map['campaignId'] as String,
        ),
      'proactiveMessageClicked' => ProactiveMessageClickedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          proactiveMessageId: map['proactiveMessageId'] as String,
          campaignId: map['campaignId'] as String,
        ),
      'conversationWithAgentRequested' => ConversationWithAgentRequestedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
        ),
      'conversationAgentAssigned' => ConversationAgentAssignedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
        ),
      'conversationServedByAgent' => ConversationServedByAgentEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
          agentId: map['agentId'] as String,
          agentDisplayName: map['agentDisplayName'] as String,
          agentMessageSource: map['agentMessageSource'] as String,
        ),
      'postbackButtonClicked' => PostbackButtonClickedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
          actionName: map['actionName'] as String,
        ),
      'conversationExtensionOpened' => ConversationExtensionOpenedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
          url: map['url'] as String,
        ),
      'conversationExtensionDisplayed' => ConversationExtensionDisplayedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
          url: map['url'] as String,
        ),
      'articleClicked' => ArticleClickedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          articleId: map['articleId'] as String,
          articleTitle: map['articleTitle'] as String?,
        ),
      'articleBrowserClicked' => ArticleBrowserClickedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          url: map['url'] as String,
        ),
      'notificationDisplayed' => NotificationDisplayedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
        ),
      'notificationOpened' => NotificationOpenedEvent(
          id: map['id'] as String,
          timestamp: map['timestamp'] as int,
          conversationId: map['conversationId'] as String,
        ),
      _ => null,
    };
  }
}

class UnreadMessageCountChangedEvent extends ZendeskEvent {
  const UnreadMessageCountChangedEvent({
    required this.totalUnreadCount,
    this.conversationId,
    required this.unreadInConversation,
  });
  final int totalUnreadCount;
  final String? conversationId;
  final int unreadInConversation;
}

class AuthenticationFailedEvent extends ZendeskEvent {
  const AuthenticationFailedEvent();
}

class FieldValidationFailedEvent extends ZendeskEvent {
  const FieldValidationFailedEvent();
}

class ConnectionStatusChangedEvent extends ZendeskEvent {
  const ConnectionStatusChangedEvent({required this.status});

  /// One of: 'disconnected', 'connected', 'connectingRealtime', 'connectedRealtime'
  final String status;
}

class ConversationAddedEvent extends ZendeskEvent {
  const ConversationAddedEvent({required this.conversationId});
  final String conversationId;
}

class ConversationStartedEvent extends ZendeskEvent {
  const ConversationStartedEvent({required this.id, required this.conversationId, required this.timestamp});
  final String id;
  final String conversationId;
  final int timestamp;
}

class ConversationOpenedEvent extends ZendeskEvent {
  const ConversationOpenedEvent({required this.id, this.conversationId, required this.timestamp});
  final String id;
  final String? conversationId;
  final int timestamp;
}

class MessagesShownEvent extends ZendeskEvent {
  const MessagesShownEvent({
    required this.id,
    required this.conversationId,
    required this.timestamp,
    required this.messages,
  });
  final String id;
  final String conversationId;
  final int timestamp;
  final List<ZendeskMessage> messages;
}

class SendMessageFailedEvent extends ZendeskEvent {
  const SendMessageFailedEvent({this.message});
  final String? message;
}

class MessagingOpenedEvent extends ZendeskEvent {
  const MessagingOpenedEvent({required this.id, required this.timestamp});
  final String id;
  final int timestamp;
}

class MessagingClosedEvent extends ZendeskEvent {
  const MessagingClosedEvent({required this.id, required this.timestamp});
  final String id;
  final int timestamp;
}

class NewConversationButtonClickedEvent extends ZendeskEvent {
  const NewConversationButtonClickedEvent({required this.id, required this.timestamp, required this.source});
  final String id;
  final int timestamp;
  final String source;
}

class ProactiveMessageDisplayedEvent extends ZendeskEvent {
  const ProactiveMessageDisplayedEvent({
    required this.id,
    required this.timestamp,
    required this.proactiveMessageId,
    required this.campaignId,
  });
  final String id;
  final int timestamp;
  final String proactiveMessageId;
  final String campaignId;
}

class ProactiveMessageClickedEvent extends ZendeskEvent {
  const ProactiveMessageClickedEvent({
    required this.id,
    required this.timestamp,
    required this.proactiveMessageId,
    required this.campaignId,
  });
  final String id;
  final int timestamp;
  final String proactiveMessageId;
  final String campaignId;
}

class ConversationWithAgentRequestedEvent extends ZendeskEvent {
  const ConversationWithAgentRequestedEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
  });
  final String id;
  final int timestamp;
  final String conversationId;
}

class ConversationAgentAssignedEvent extends ZendeskEvent {
  const ConversationAgentAssignedEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
  });
  final String id;
  final int timestamp;
  final String conversationId;
}

class ConversationServedByAgentEvent extends ZendeskEvent {
  const ConversationServedByAgentEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
    required this.agentId,
    required this.agentDisplayName,
    required this.agentMessageSource,
  });
  final String id;
  final int timestamp;
  final String conversationId;
  final String agentId;
  final String agentDisplayName;

  /// 'agentWorkspace' or 'agentCopilot'
  final String agentMessageSource;
}

class PostbackButtonClickedEvent extends ZendeskEvent {
  const PostbackButtonClickedEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
    required this.actionName,
  });
  final String id;
  final int timestamp;
  final String conversationId;
  final String actionName;
}

class ConversationExtensionOpenedEvent extends ZendeskEvent {
  const ConversationExtensionOpenedEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
    required this.url,
  });
  final String id;
  final int timestamp;
  final String conversationId;
  final String url;
}

class ConversationExtensionDisplayedEvent extends ZendeskEvent {
  const ConversationExtensionDisplayedEvent({
    required this.id,
    required this.timestamp,
    required this.conversationId,
    required this.url,
  });
  final String id;
  final int timestamp;
  final String conversationId;
  final String url;
}

class ArticleClickedEvent extends ZendeskEvent {
  const ArticleClickedEvent({
    required this.id,
    required this.timestamp,
    required this.articleId,
    this.articleTitle,
  });
  final String id;
  final int timestamp;
  final String articleId;
  final String? articleTitle;
}

class ArticleBrowserClickedEvent extends ZendeskEvent {
  const ArticleBrowserClickedEvent({required this.id, required this.timestamp, required this.url});
  final String id;
  final int timestamp;
  final String url;
}

class NotificationDisplayedEvent extends ZendeskEvent {
  const NotificationDisplayedEvent({required this.id, required this.timestamp, required this.conversationId});
  final String id;
  final int timestamp;
  final String conversationId;
}

class NotificationOpenedEvent extends ZendeskEvent {
  const NotificationOpenedEvent({required this.id, required this.timestamp, required this.conversationId});
  final String id;
  final int timestamp;
  final String conversationId;
}
