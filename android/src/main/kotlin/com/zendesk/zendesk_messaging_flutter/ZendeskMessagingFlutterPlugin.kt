package com.zendesk.zendesk_messaging_flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import zendesk.android.Zendesk
import zendesk.android.events.ZendeskEvent
import zendesk.android.events.ZendeskEventListener
import zendesk.android.messaging.MessagingDelegate
import zendesk.android.messaging.UrlSource
import zendesk.android.pageviewevents.PageView
import zendesk.messaging.android.DefaultMessagingFactory
import zendesk.messaging.android.push.PushNotifications
import zendesk.android.messaging.MessagingScreen as ZDKMessagingScreen

class ZendeskMessagingFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // URL handling policy (set from Dart via setUrlPolicy). Native decides
    // synchronously; intercepted links are forwarded as a `urlClicked` event.
    private var urlPolicy: String = "sdkOpens"
    private var urlPatterns: List<String> = emptyList()

    companion object {
        private var initialized = false
    }

    private val eventListener = ZendeskEventListener { event ->
        val map: Map<String, Any?> = when (event) {
            is ZendeskEvent.UnreadMessageCountChanged -> mapOf(
                "type" to "unreadMessageCountChanged",
                "totalUnreadCount" to event.data.totalUnreadMessagesCount,
                "conversationId" to event.data.conversationId,
                "unreadInConversation" to event.data.unreadCountInConversation,
            )
            is ZendeskEvent.AuthenticationFailed -> mapOf("type" to "authenticationFailed")
            is ZendeskEvent.FieldValidationFailed -> mapOf("type" to "fieldValidationFailed")
            is ZendeskEvent.ConnectionStatusChanged -> mapOf(
                "type" to "connectionStatusChanged",
                "status" to enumToCamel(event.connectionStatus.name),
            )
            is ZendeskEvent.ConversationAdded -> mapOf(
                "type" to "conversationAdded",
                "conversationId" to event.conversationId,
            )
            is ZendeskEvent.ConversationStarted -> mapOf(
                "type" to "conversationStarted",
                "id" to event.id.toString(),
                "conversationId" to event.conversationId,
                "timestamp" to event.timestamp,
            )
            is ZendeskEvent.ConversationOpened -> mapOf(
                "type" to "conversationOpened",
                "id" to event.id.toString(),
                "conversationId" to event.conversationId,
                "timestamp" to event.timestamp,
            )
            is ZendeskEvent.MessagesShown -> mapOf(
                "type" to "messagesShown",
                "id" to event.id.toString(),
                "conversationId" to event.conversationId,
                "timestamp" to event.timestamp,
                "messages" to event.messages.map {
                    mapOf("id" to it.id, "role" to enumToCamel(it.role.name), "timestamp" to it.timestamp)
                },
            )
            is ZendeskEvent.SendMessageFailed -> mapOf(
                "type" to "sendMessageFailed",
                "message" to event.cause.message,
            )
            is ZendeskEvent.MessagingOpened -> mapOf(
                "type" to "messagingOpened",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
            )
            is ZendeskEvent.MessagingClosed -> mapOf(
                "type" to "messagingClosed",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
            )
            is ZendeskEvent.NewConversationButtonClicked -> mapOf(
                "type" to "newConversationButtonClicked",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "source" to enumToCamel(event.data.newConversationSource.name),
            )
            is ZendeskEvent.ProactiveMessageDisplayed -> mapOf(
                "type" to "proactiveMessageDisplayed",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "proactiveMessageId" to event.data.proactiveMessageId.toString(),
                "campaignId" to event.data.campaignId,
            )
            is ZendeskEvent.ProactiveMessageClicked -> mapOf(
                "type" to "proactiveMessageClicked",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "proactiveMessageId" to event.data.proactiveMessageId.toString(),
                "campaignId" to event.data.campaignId,
            )
            is ZendeskEvent.ConversationWithAgentRequested -> mapOf(
                "type" to "conversationWithAgentRequested",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
            )
            is ZendeskEvent.ConversationAgentAssigned -> mapOf(
                "type" to "conversationAgentAssigned",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
            )
            is ZendeskEvent.ConversationServedByAgent -> mapOf(
                "type" to "conversationServedByAgent",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
                "agentId" to event.data.agentId,
                "agentDisplayName" to event.data.agentDisplayName,
                "agentMessageSource" to enumToCamel(event.data.agentMessageSource.name),
            )
            is ZendeskEvent.PostbackButtonClicked -> mapOf(
                "type" to "postbackButtonClicked",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
                "actionName" to event.data.actionName,
            )
            is ZendeskEvent.ConversationExtensionOpened -> mapOf(
                "type" to "conversationExtensionOpened",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
                "url" to event.data.url,
            )
            is ZendeskEvent.ConversationExtensionDisplayed -> mapOf(
                "type" to "conversationExtensionDisplayed",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
                "url" to event.data.url,
            )
            is ZendeskEvent.ArticleClicked -> mapOf(
                "type" to "articleClicked",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "articleId" to event.data.articleId.toString(),
                "articleTitle" to event.data.articleTitle,
            )
            is ZendeskEvent.ArticleBrowserClicked -> mapOf(
                "type" to "articleBrowserClicked",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "url" to event.data.url,
            )
            is ZendeskEvent.NotificationDisplayed -> mapOf(
                "type" to "notificationDisplayed",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
            )
            is ZendeskEvent.NotificationOpened -> mapOf(
                "type" to "notificationOpened",
                "id" to event.id.toString(),
                "timestamp" to event.timestamp,
                "conversationId" to event.data.conversationId,
            )
            is ZendeskEvent.MetadataSuccess -> mapOf("type" to "metadataSuccess")
            is ZendeskEvent.MetadataFailure -> mapOf("type" to "metadataFailure")
            else -> return@ZendeskEventListener
        }
        mainHandler.post { eventSink?.success(map) }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "zendesk_messaging")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "zendesk_messaging/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // Drop the process-global delegate so a torn-down plugin isn't retained/invoked.
        zendesk.android.messaging.Messaging.setDelegate(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }

    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            "initialize" -> {
                val channelKey = call.argument<String>("channelKey")
                    ?: return result.error("INVALID_ARGS", "channelKey is required", null)
                val ctx = applicationContext
                    ?: return result.error("NO_CONTEXT", "Plugin not attached to engine", null)
                if (initialized) return result.success(null)

                Zendesk.initialize(
                    context = ctx,
                    channelKey = channelKey,
                    successCallback = {
                        initialized = true
                        installMessagingDelegate()
                        result.success(null)
                    },
                    failureCallback = { result.error("INIT_FAILED", it.message, null) },
                    messagingFactory = DefaultMessagingFactory()
                )
            }

            "invalidate" -> {
                Zendesk.invalidate()
                initialized = false
                result.success(null)
            }

            "getCurrentUser" -> {
                Zendesk.instance.getCurrentUser(
                    successCallback = { user ->
                        result.success(user?.let {
                            mapOf(
                                "id" to it.id,
                                "externalId" to it.externalId,
                                "authenticationType" to enumToCamel(it.authenticationType.name),
                            )
                        })
                    },
                    // no failure callback variant — just return null on error
                )
            }

            "loginUser" -> {
                val jwt = call.argument<String>("jwt")
                    ?: return result.error("INVALID_ARGS", "jwt is required", null)
                Zendesk.instance.loginUser(
                    jwt = jwt,
                    successCallback = { result.success(null) },
                    failureCallback = { result.error("LOGIN_FAILED", it.message, null) }
                )
            }

            "logoutUser" -> {
                Zendesk.instance.logoutUser(
                    successCallback = { result.success(null) },
                    failureCallback = { result.error("LOGOUT_FAILED", it.message, null) }
                )
            }

            "show" -> {
                val act = activity ?: return result.error("NO_ACTIVITY", "No activity available", null)
                val screen = buildMessagingScreen(call)
                if (screen != null) {
                    Zendesk.instance.messaging.showMessaging(act, screen)
                } else {
                    Zendesk.instance.messaging.showMessaging(act)
                }
                result.success(null)
            }

            "getUnreadMessageCount" -> {
                result.success(Zendesk.instance.messaging.getUnreadMessageCount())
            }

            "getUnreadMessageCountForConversation" -> {
                val id = call.argument<String>("conversationId")
                    ?: return result.error("INVALID_ARGS", "conversationId is required", null)
                result.success(Zendesk.instance.messaging.getUnreadMessageCount(id))
            }

            "setConversationFields" -> {
                val fields = call.argument<Map<String, Any>>("fields") ?: emptyMap()
                Zendesk.instance.messaging.setConversationFields(fields)
                result.success(null)
            }

            "clearConversationFields" -> {
                Zendesk.instance.messaging.clearConversationFields()
                result.success(null)
            }

            "setConversationTags" -> {
                val tags = call.argument<List<String>>("tags") ?: emptyList()
                Zendesk.instance.messaging.setConversationTags(tags)
                result.success(null)
            }

            "clearConversationTags" -> {
                Zendesk.instance.messaging.clearConversationTags()
                result.success(null)
            }

            "sendPageViewEvent" -> {
                val pageTitle = call.argument<String>("pageTitle")
                    ?: return result.error("INVALID_ARGS", "pageTitle is required", null)
                val url = call.argument<String>("url")
                    ?: return result.error("INVALID_ARGS", "url is required", null)
                Zendesk.instance.sendPageView(
                    pageView = PageView(url = url, pageTitle = pageTitle),
                    successCallback = { result.success(null) },
                    failureCallback = { result.error("PAGE_VIEW_FAILED", it.message, null) }
                )
            }

            "updatePushNotificationToken" -> {
                val token = call.argument<String>("token")
                    ?: return result.error("INVALID_ARGS", "token is required", null)
                PushNotifications.updatePushNotificationToken(token)
                result.success(null)
            }

            "shouldBeDisplayed" -> {
                val messageData = call.argument<Map<String, String>>("messageData") ?: emptyMap()
                val responsibility = PushNotifications.shouldBeDisplayed(messageData)
                result.success(responsibility.name)
            }

            "displayNotification" -> {
                val ctx = applicationContext
                    ?: return result.error("NO_CONTEXT", "Plugin not attached to engine", null)
                val messageData = call.argument<Map<String, String>>("messageData") ?: emptyMap()
                PushNotifications.displayNotification(ctx, messageData)
                result.success(null)
            }

            "setNotificationSmallIconResourceName" -> {
                val resourceName = call.argument<String>("resourceName")
                    ?: return result.error("INVALID_ARGS", "resourceName is required", null)
                val ctx = applicationContext
                    ?: return result.error("NO_CONTEXT", "Plugin not attached to engine", null)
                val resId = ctx.resources.getIdentifier(resourceName, "drawable", ctx.packageName)
                PushNotifications.setNotificationSmallIconId(if (resId != 0) resId else null)
                result.success(null)
            }

            "enableAnalyticsTracking" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                Zendesk.instance.messaging.enableAnalyticsTracking(enabled)
                result.success(null)
            }

            "setUrlPolicy" -> {
                urlPolicy = call.argument<String>("policy") ?: "sdkOpens"
                urlPatterns = call.argument<List<String>>("patterns") ?: emptyList()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun buildMessagingScreen(call: MethodCall): ZDKMessagingScreen? {
        val screen = call.argument<String>("screen") ?: return null
        val exitActionStr = call.argument<String>("exitAction") ?: "close"
        val exitAction = if (exitActionStr == "returnToConversationList")
            ZDKMessagingScreen.ExitAction.ReturnToConversationList
        else
            ZDKMessagingScreen.ExitAction.Close
        return when (screen) {
            "mostRecentConversation" -> ZDKMessagingScreen.MostRecentActiveConversation(onExit = exitAction)
            "conversationsList" -> ZDKMessagingScreen.ConversationsList
            "newConversation" -> ZDKMessagingScreen.NewConversation(onExit = exitAction)
            "conversation" -> {
                val id = call.argument<String>("conversationId") ?: return null
                ZDKMessagingScreen.Conversation(id = id, onExit = exitAction)
            }
            else -> null
        }
    }

    private fun installMessagingDelegate() {
        zendesk.android.messaging.Messaging.setDelegate(object : MessagingDelegate() {
            // Called synchronously on the main thread. Return true = SDK opens the
            // URL, false = the app is responsible. We decide from the pre-registered
            // policy (no Dart round-trip) and, when the app is responsible, emit a
            // `urlClicked` event fire-and-forget so Dart can act on it.
            override fun shouldHandleUrl(url: String, urlSource: UrlSource): Boolean {
                val appHandles = when (urlPolicy) {
                    "appHandlesAll" -> true
                    "appHandlesMatching" -> urlPatterns.any { url.contains(it) }
                    else -> false  // "sdkOpens"
                }
                if (appHandles) {
                    val payload = mapOf(
                        "type" to "urlClicked",
                        "url" to url,
                        "source" to urlSourceName(urlSource),
                    )
                    mainHandler.post { eventSink?.success(payload) }
                }
                return !appHandles  // SDK handles the URL only if the app does not
            }
        })
    }

    private fun urlSourceName(source: UrlSource): String = when (source) {
        UrlSource.TEXT -> "text"
        UrlSource.CAROUSEL -> "carousel"
        UrlSource.FILE -> "file"
        UrlSource.IMAGE -> "image"
        UrlSource.LINK_MESSAGE_ACTION -> "linkMessageAction"
        UrlSource.WEBVIEW_MESSAGE_ACTION -> "webViewMessageAction"
    }

    // Normalizes an SDK enum constant (SCREAMING_SNAKE_CASE) to the exact
    // camelCase string the iOS side emits and the Dart layer expects — e.g.
    // CONNECTING_REALTIME -> "connectingRealtime", SESSION_TOKEN -> "sessionToken".
    // (UrlSource keeps its own explicit mapping above for the WebView casing.)
    private fun enumToCamel(name: String): String {
        val parts = name.lowercase().split("_")
        return parts.first() + parts.drop(1).joinToString("") { part ->
            part.replaceFirstChar { it.uppercaseChar() }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Zendesk.instance.addEventListener(eventListener)
    }

    override fun onCancel(arguments: Any?) {
        Zendesk.instance.removeEventListener(eventListener)
        eventSink = null
    }
}
