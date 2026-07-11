import Flutter
import UIKit
import ZendeskSDKMessaging
import ZendeskSDK

public class ZendeskMessagingFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
    MessagingDelegate {

    private var eventSink: FlutterEventSink?

    // URL handling policy (set from Dart via setUrlPolicy). Native decides
    // synchronously; intercepted links are forwarded as a `urlClicked` event.
    private var urlPolicy: String = "sdkOpens"
    private var urlPatterns: [String] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "zendesk_messaging",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "zendesk_messaging/events",
            binaryMessenger: registrar.messenger()
        )
        let instance = ZendeskMessagingFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - Method handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {

        case "initialize":
            guard let channelKey = args?["channelKey"] as? String else {
                return result(FlutterError(code: "INVALID_ARGS", message: "channelKey is required", details: nil))
            }
            if Zendesk.instance != nil { return result(nil) }
            Zendesk.initialize(withChannelKey: channelKey, messagingFactory: DefaultMessagingFactory()) { [weak self] initResult in
                switch initResult {
                case .success:
                    Messaging.delegate = self
                    result(nil)
                case .failure(let error):
                    result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
                }
            }

        case "invalidate":
            Zendesk.invalidate()
            result(nil)

        case "getCurrentUser":
            guard let zendesk = Zendesk.instance,
                  let u = zendesk.getCurrentUser() else { return result(nil) }
            result([
                "id": u.id,
                "externalId": u.externalId,
                "authenticationType": authTypeName(u.authenticationType),
            ])

        case "loginUser":
            guard let jwt = args?["jwt"] as? String,
                  let zendesk = Zendesk.instance else {
                return result(FlutterError(code: "INVALID_ARGS", message: "jwt required / SDK not initialized", details: nil))
            }
            zendesk.loginUser(with: jwt) { loginResult in
                switch loginResult {
                case .success: result(nil)
                case .failure(let e): result(FlutterError(code: "LOGIN_FAILED", message: e.localizedDescription, details: nil))
                }
            }

        case "logoutUser":
            guard let zendesk = Zendesk.instance else { return result(nil) }
            zendesk.logoutUser { logoutResult in
                switch logoutResult {
                case .success: result(nil)
                case .failure(let e): result(FlutterError(code: "LOGOUT_FAILED", message: e.localizedDescription, details: nil))
                }
            }

        case "show":
            guard let messaging = Zendesk.instance?.messaging else {
                return result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
            }
            let fullScreen = args?["fullScreen"] as? Bool ?? true
            let screen = buildMessagingScreen(from: args)
            let vc: UIViewController
            if let screen = screen {
                vc = messaging.messagingViewController(screen)
            } else {
                vc = messaging.messagingViewController()
            }
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = fullScreen ? .fullScreen : .pageSheet
                UIApplication.shared.topViewController?.present(nav, animated: true)
                result(nil)
            }

        case "getUnreadMessageCount":
            let count = Zendesk.instance?.messaging?.getUnreadMessageCount() ?? 0
            result(count)

        case "getUnreadMessageCountForConversation":
            guard let id = args?["conversationId"] as? String else {
                return result(FlutterError(code: "INVALID_ARGS", message: "conversationId is required", details: nil))
            }
            let count = Zendesk.instance?.messaging?.getUnreadMessageCount(conversationId: id) ?? 0
            result(count)

        case "setConversationFields":
            guard let fields = args?["fields"] as? [String: AnyHashable] else { return result(nil) }
            Zendesk.instance?.messaging?.setConversationFields(fields)
            result(nil)

        case "clearConversationFields":
            Zendesk.instance?.messaging?.clearConversationFields()
            result(nil)

        case "setConversationTags":
            guard let tags = args?["tags"] as? [String] else { return result(nil) }
            Zendesk.instance?.messaging?.setConversationTags(tags)
            result(nil)

        case "clearConversationTags":
            Zendesk.instance?.messaging?.clearConversationTags()
            result(nil)

        case "sendPageViewEvent":
            guard let pageTitle = args?["pageTitle"] as? String,
                  let url = args?["url"] as? String,
                  let zendesk = Zendesk.instance else {
                return result(FlutterError(code: "INVALID_ARGS", message: "pageTitle, url, and initialized SDK required", details: nil))
            }
            zendesk.sendPageViewEvent(PageView(pageTitle: pageTitle, url: url)) { sendResult in
                switch sendResult {
                case .success: result(nil)
                case .failure(let e): result(FlutterError(code: "PAGE_VIEW_FAILED", message: e.localizedDescription, details: nil))
                }
            }

        case "updatePushNotificationToken":
            guard let tokenHex = args?["token"] as? String else {
                return result(FlutterError(code: "INVALID_ARGS", message: "token is required", details: nil))
            }
            guard let tokenData = Data(hexString: tokenHex) else {
                return result(FlutterError(code: "INVALID_ARGS", message: "token is not valid hex", details: nil))
            }
            PushNotifications.updatePushNotificationToken(tokenData)
            result(nil)

        case "shouldBeDisplayed":
            guard let messageData = args?["messageData"] as? [AnyHashable: Any] else {
                return result("notFromMessaging")
            }
            let responsibility = PushNotifications.shouldBeDisplayed(messageData)
            result(pushResponsibilityName(responsibility))

        case "enableAnalyticsTracking":
            let enabled = args?["enabled"] as? Bool ?? true
            Zendesk.instance?.messaging?.enableInternalAnalytics(enabled: enabled)
            result(nil)

        case "setUrlPolicy":
            urlPolicy = args?["policy"] as? String ?? "sdkOpens"
            urlPatterns = args?["patterns"] as? [String] ?? []
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - MessagingDelegate

    // Called synchronously on the main thread. `true` = SDK opens the URL,
    // `false` = the app is responsible. We decide from the pre-registered
    // policy (no Dart round-trip) and, when the app is responsible, emit a
    // `urlClicked` event fire-and-forget so Dart can act on it.
    public func messaging(_ messaging: Messaging, shouldHandleURL url: URL, from source: URLSource) -> Bool {
        let appHandles: Bool
        switch urlPolicy {
        case "appHandlesAll":
            appHandles = true
        case "appHandlesMatching":
            let absolute = url.absoluteString
            appHandles = urlPatterns.contains { absolute.contains($0) }
        default:  // "sdkOpens"
            appHandles = false
        }
        if appHandles {
            let sink = eventSink
            let payload: [String: Any] = ["type": "urlClicked", "url": url.absoluteString, "source": urlSourceName(source)]
            DispatchQueue.main.async { sink?(payload) }
        }
        return !appHandles  // SDK handles the URL only if the app does not
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        guard let zendesk = Zendesk.instance else { return nil }
        zendesk.addEventObserver(self) { [weak self] event in
            guard let self else { return }
            let sink = self.eventSink
            let map = self.eventToMap(event)
            guard let map else { return }
            DispatchQueue.main.async { sink?(map) }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Zendesk.instance?.removeEventObserver(self)
        eventSink = nil
        return nil
    }

    // MARK: - Event mapping

    private func eventToMap(_ event: ZendeskEvent) -> [String: Any?]? {
        switch event {
        case .сonversationUnreadCountChanged(id: _, timestamp: _, data: let data):
            return [
                "type": "unreadMessageCountChanged",
                "totalUnreadCount": data.totalUnreadMessagesCount,
                "conversationId": data.conversationId,
                "unreadInConversation": data.unreadCountInConversation,
            ]
        case .authenticationFailed:
            return ["type": "authenticationFailed"]
        case .connectionStatusChanged(connectionStatus: let status):
            return ["type": "connectionStatusChanged", "status": connectionStatusName(status)]
        case .conversationAdded(conversationId: let cid):
            return ["type": "conversationAdded", "conversationId": cid]
        case .conversationStarted(id: let id, timestamp: let ts, conversationId: let cid):
            return ["type": "conversationStarted", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": cid]
        case .conversationOpened(id: let id, timestamp: let ts, conversationId: let cid):
            return ["type": "conversationOpened", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": cid as Any]
        case .messagesShown(id: let id, timestamp: let ts, conversationId: let cid, messages: let msgs):
            return [
                "type": "messagesShown",
                "id": id.uuidString,
                "timestamp": Int(ts.timeIntervalSince1970 * 1000),
                "conversationId": cid,
                "messages": msgs.map { ["id": $0.id, "role": $0.role == .user ? "user" : "business", "timestamp": Int($0.timestamp.timeIntervalSince1970 * 1000)] },
            ]
        case .sendMessageFailed(error: let e):
            return ["type": "sendMessageFailed", "message": e.localizedDescription]
        case .messagingOpened(id: let id, timestamp: let ts):
            return ["type": "messagingOpened", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000)]
        case .messagingClosed(id: let id, timestamp: let ts):
            return ["type": "messagingClosed", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000)]
        case .newConversationButtonClicked(id: let id, timestamp: let ts, data: let data):
            return ["type": "newConversationButtonClicked", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "source": newConversationSourceName(data.newConversationSource)]
        case .proactiveMessageDisplayed(id: let id, timestamp: let ts, data: let data):
            return ["type": "proactiveMessageDisplayed", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "proactiveMessageId": data.proactiveMessageId, "campaignId": data.campaignId]
        case .proactiveMessageClicked(id: let id, timestamp: let ts, data: let data):
            return ["type": "proactiveMessageClicked", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "proactiveMessageId": data.proactiveMessageId, "campaignId": data.campaignId]
        case .conversationWithAgentRequested(id: let id, timestamp: let ts, data: let data):
            return ["type": "conversationWithAgentRequested", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId]
        case .conversationAgentAssigned(id: let id, timestamp: let ts, data: let data):
            return ["type": "conversationAgentAssigned", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId]
        case .conversationServedByAgent(id: let id, timestamp: let ts, data: let data):
            return ["type": "conversationServedByAgent", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId, "agentId": data.agentId, "agentDisplayName": data.agentDisplayName, "agentMessageSource": agentMessageSourceName(data.agentMessageSource)]
        case .postbackButtonClicked(id: let id, timestamp: let ts, data: let data):
            return ["type": "postbackButtonClicked", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId, "actionName": data.actionName]
        case .conversationExtensionDisplayed(id: let id, timestamp: let ts, data: let data):
            return ["type": "conversationExtensionDisplayed", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId, "url": data.url]
        case .conversationExtensionOpened(id: let id, timestamp: let ts, data: let data):
            return ["type": "conversationExtensionOpened", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId, "url": data.url]
        case .articleClicked(id: let id, timestamp: let ts, data: let data):
            return ["type": "articleClicked", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "articleId": data.articleId, "articleTitle": data.articleTitle as Any]
        case .articleBrowserClicked(id: let id, timestamp: let ts, data: let data):
            return ["type": "articleBrowserClicked", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "url": data.url]
        case .notificationDisplayed(id: let id, timestamp: let ts, data: let data):
            return ["type": "notificationDisplayed", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId]
        case .notificationOpened(id: let id, timestamp: let ts, data: let data):
            return ["type": "notificationOpened", "id": id.uuidString, "timestamp": Int(ts.timeIntervalSince1970 * 1000), "conversationId": data.conversationId]
        case .metadataSuccess:
            return ["type": "metadataSuccess"]
        case .metadataFailure:
            return ["type": "metadataFailure"]
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private func buildMessagingScreen(from args: [String: Any]?) -> MessagingScreen? {
        guard let screen = args?["screen"] as? String else { return nil }
        let exitActionStr = args?["exitAction"] as? String ?? "close"
        let exitAction: ExitAction = exitActionStr == "returnToConversationList" ? .returnToConversationList : .close
        switch screen {
        case "mostRecentConversation":
            return .showMostRecentConversation(exitAction: exitAction)
        case "conversationsList":
            return .showConversationList
        case "newConversation":
            return .showNewConversation(exitAction: exitAction)
        case "conversation":
            let cid = args?["conversationId"] as? String
            return .showConversation(conversationId: cid, exitAction: exitAction)
        default:
            return nil
        }
    }

    private func authTypeName(_ type: AuthenticationType) -> String {
        switch type {
        case .jwt: return "jwt"
        case .sessionToken: return "sessionToken"
        case .unauthenticated: return "unauthenticated"
        @unknown default: return "unauthenticated"
        }
    }

    private func connectionStatusName(_ status: ZendeskConnectionStatus) -> String {
        switch status {
        case .disconnected: return "disconnected"
        case .connected: return "connected"
        case .connectingRealtime: return "connectingRealtime"
        case .connectedRealtime: return "connectedRealtime"
        @unknown default: return "disconnected"
        }
    }

    private func pushResponsibilityName(_ r: PushResponsibility) -> String {
        switch r {
        case .messagingShouldDisplay: return "messagingShouldDisplay"
        case .messagingShouldNotDisplay: return "messagingShouldNotDisplay"
        case .notFromMessaging: return "notFromMessaging"
        @unknown default: return "notFromMessaging"
        }
    }

    private func agentMessageSourceName(_ s: AgentMessageSource) -> String {
        switch s {
        case .agentWorkspace: return "agentWorkspace"
        case .agentCopilot: return "agentCopilot"
        @unknown default: return "agentWorkspace"
        }
    }

    private func urlSourceName(_ s: URLSource) -> String {
        switch s {
        case .text: return "text"
        case .carousel: return "carousel"
        case .file: return "file"
        case .image: return "image"
        case .linkMessageAction: return "linkMessageAction"
        case .webViewMessageAction: return "webViewMessageAction"
        @unknown default: return "text"
        }
    }

    private func newConversationSourceName(_ s: NewConversationSource) -> String {
        switch s {
        case .conversationList: return "conversationList"
        @unknown default: return "conversationList"
        }
    }
}

// MARK: - UIApplication extension

private extension UIApplication {
    var topViewController: UIViewController? {
        guard let rootVC = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        return findTopViewController(from: rootVC)
    }

    private func findTopViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return findTopViewController(from: presented) }
        if let nav = vc as? UINavigationController, let top = nav.topViewController { return findTopViewController(from: top) }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController { return findTopViewController(from: selected) }
        return vc
    }
}

// MARK: - Data hex extension

private extension Data {
    /// Parses an even-length, fully hexadecimal string. Returns `nil` for any
    /// malformed input rather than silently forwarding a truncated token.
    init?(hexString: String) {
        let clean = hexString.replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty, clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
