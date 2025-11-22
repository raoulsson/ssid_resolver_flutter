import 'package:flutter_test/flutter_test.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter_platform_interface.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSsidResolverFlutterPlatform
    with MockPlatformInterfaceMixin
    implements SsidResolverFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<Map<String, dynamic>> checkPermissionStatus() {
    // TODO: implement checkPermissionStatus
    throw UnimplementedError();
  }

  @override
  Future<String> resolveSSID() {
    // TODO: implement fetchSsid
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> requestPermission() {
    // TODO: implement requestPermission
    throw UnimplementedError();
  }
}

void main() {
  final SsidResolverFlutterPlatform initialPlatform = SsidResolverFlutterPlatform.instance;

  test('$MethodChannelSsidResolverFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSsidResolverFlutter>());
  });

  test('getPlatformVersion', () async {
    SSIDResolver ssidResolverFlutterPlugin = SSIDResolver();
    MockSsidResolverFlutterPlatform fakePlatform = MockSsidResolverFlutterPlatform();
    SsidResolverFlutterPlatform.instance = fakePlatform;

    expect(await ssidResolverFlutterPlugin.getPlatformVersion(), '42');
  });
}
