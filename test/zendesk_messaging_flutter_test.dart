import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter_platform_interface.dart';
import 'package:zendesk_messaging_flutter/zendesk_messaging_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockZendeskMessagingFlutterPlatform
    with MockPlatformInterfaceMixin
    implements ZendeskMessagingFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ZendeskMessagingFlutterPlatform initialPlatform = ZendeskMessagingFlutterPlatform.instance;

  test('$MethodChannelZendeskMessagingFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelZendeskMessagingFlutter>());
  });

  test('getPlatformVersion', () async {
    ZendeskMessagingFlutter zendeskMessagingFlutterPlugin = ZendeskMessagingFlutter();
    MockZendeskMessagingFlutterPlatform fakePlatform = MockZendeskMessagingFlutterPlatform();
    ZendeskMessagingFlutterPlatform.instance = fakePlatform;

    expect(await zendeskMessagingFlutterPlugin.getPlatformVersion(), '42');
  });
}
