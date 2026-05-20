import Flutter
import UIKit
import ZendeskSDKMessaging
import ZendeskSDK

public class ZendeskMessagingFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private let bridge = ZendeskBridge.shared

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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {

        case "initialize":
            guard let channelKey = args?["channelKey"] as? String else {
                return result(FlutterError(code: "INVALID_ARGS", message: "channelKey is required", details: nil))
            }
            if Zendesk.instance != nil { return result(nil) }
            Zendesk.initialize(
                withChannelKey: channelKey,
                messagingFactory: DefaultMessagingFactory()
            ) { _ in result(nil) }

        case "loginUser":
            guard let jwt = args?["jwt"] as? String,
                  let zendesk = Zendesk.instance else {
                return result(FlutterError(code: "INVALID_ARGS", message: "jwt required / SDK not initialized", details: nil))
            }
            bridge.loginUser(zendesk, jwt: jwt) { _, _ in result(nil) }

        case "logoutUser":
            guard let zendesk = Zendesk.instance else { return result(nil) }
            bridge.logoutUser(zendesk) { _ in result(nil) }

        case "show":
            guard let vc = Zendesk.instance?.messaging?.messagingViewController() else {
                return result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
            }
            let fullScreen = args?["fullScreen"] as? Bool ?? true
            DispatchQueue.main.async {
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = fullScreen ? .fullScreen : .pageSheet
                UIApplication.shared.topViewController?.present(nav, animated: true)
                result(nil)
            }

        case "getUnreadMessageCount":
            let count = Zendesk.instance.map { bridge.fetchUnreadCount($0) } ?? 0
            result(count)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        guard let zendesk = Zendesk.instance else { return nil }
        zendesk.addEventObserver(self) { [weak self] event in
            guard let self = self else { return }
            let sink = self.eventSink
            DispatchQueue.main.async {
                switch event {
                case .сonversationUnreadCountChanged(id: _, timestamp: _, data: let data):
                    sink?(["type": "unreadMessageCountChanged", "count": data.totalUnreadMessagesCount])
                case .authenticationFailed:
                    sink?(["type": "authenticationFailed"])
                default:
                    break
                }
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        Zendesk.instance?.removeEventObserver(self)
        eventSink = nil
        return nil
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
        if let presented = vc.presentedViewController {
            return findTopViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return findTopViewController(from: top)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTopViewController(from: selected)
        }
        return vc
    }
}
