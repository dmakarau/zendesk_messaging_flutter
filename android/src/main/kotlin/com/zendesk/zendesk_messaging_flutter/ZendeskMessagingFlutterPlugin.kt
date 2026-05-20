package com.zendesk.zendesk_messaging_flutter

import android.app.Activity
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
import zendesk.messaging.android.DefaultMessagingFactory

class ZendeskMessagingFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private var initialized = false
    }

    private val eventListener = ZendeskEventListener { event ->
        mainHandler.post {
            when (event) {
                is ZendeskEvent.UnreadMessageCountChanged ->
                    eventSink?.success(
                        mapOf(
                            "type" to "unreadMessageCountChanged",
                            "count" to event.data.totalUnreadMessagesCount
                        )
                    )
                is ZendeskEvent.AuthenticationFailed ->
                    eventSink?.success(mapOf("type" to "authenticationFailed"))
                else -> {}
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "zendesk_messaging")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "zendesk_messaging/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val channelKey = call.argument<String>("channelKey")
                    ?: return result.error("INVALID_ARGS", "channelKey is required", null)
                val ctx = activity?.applicationContext
                    ?: return result.error("NO_ACTIVITY", "No activity available", null)

                if (initialized) return result.success(null)

                Zendesk.initialize(
                    context = ctx,
                    channelKey = channelKey,
                    successCallback = { initialized = true; result.success(null) },
                    failureCallback = { result.error("INIT_FAILED", it.message, null) },
                    messagingFactory = DefaultMessagingFactory()
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
                val act = activity
                    ?: return result.error("NO_ACTIVITY", "No activity available", null)
                // fullScreen param is iOS-only; Android always launches a full Activity
                Zendesk.instance.messaging.showMessaging(act)
                result.success(null)
            }

            "getUnreadMessageCount" -> {
                val count = Zendesk.instance.messaging.getUnreadMessageCount()
                result.success(count)
            }

            else -> result.notImplemented()
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

