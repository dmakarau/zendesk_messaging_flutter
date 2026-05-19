import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zendesk_messaging_flutter_method_channel.dart';

abstract class ZendeskMessagingFlutterPlatform extends PlatformInterface {
  /// Constructs a ZendeskMessagingFlutterPlatform.
  ZendeskMessagingFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZendeskMessagingFlutterPlatform _instance = MethodChannelZendeskMessagingFlutter();

  /// The default instance of [ZendeskMessagingFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelZendeskMessagingFlutter].
  static ZendeskMessagingFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZendeskMessagingFlutterPlatform] when
  /// they register themselves.
  static set instance(ZendeskMessagingFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
