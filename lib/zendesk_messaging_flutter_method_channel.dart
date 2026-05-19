import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zendesk_messaging_flutter_platform_interface.dart';

/// An implementation of [ZendeskMessagingFlutterPlatform] that uses method channels.
class MethodChannelZendeskMessagingFlutter extends ZendeskMessagingFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('zendesk_messaging_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
