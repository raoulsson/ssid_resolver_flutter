import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'network_interface_info.dart';
import 'ssid_resolver_flutter_platform_interface.dart';

/// An implementation of [SsidResolverFlutterPlatform] that uses method channels.
class MethodChannelSsidResolverFlutter extends SsidResolverFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ssid_resolver_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<Map<String, dynamic>> checkPermissionStatus() async {
    final result = await methodChannel
        .invokeMethod<Map<Object?, Object?>>('checkPermissionStatus');
    return _convertToStringDynamicMap(result!);
  }

  @override
  Future<Map<String, dynamic>> requestPermission() async {
    final result = await methodChannel
        .invokeMethod<Map<Object?, Object?>>('requestPermission');
    return _convertToStringDynamicMap(result!);
  }

  @override
  Future<String> resolveSSID() async {
    final String result = await methodChannel.invokeMethod('fetchSsid');
    return result;
  }

  @override
  Future<List<NetworkInterfaceInfo>> fetchNetworkInterfaces() async {
    // Same "empty list, never throw" contract as SSIDResolver: callers use
    // this to decide where to send discovery traffic, and the two entry points
    // must not differ in error behaviour.
    try {
      final result = await methodChannel.invokeMethod<List<Object?>>('fetchNetworkInterfaces');
      if (result == null) return const <NetworkInterfaceInfo>[];
      return result
          .whereType<Map<Object?, Object?>>()
          .map(NetworkInterfaceInfo.fromMap)
          .toList(growable: false);
    } on PlatformException {
      return const <NetworkInterfaceInfo>[];
    } on MissingPluginException {
      return const <NetworkInterfaceInfo>[];
    }
  }

  // Helper method to convert Map<Object?, Object?> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(Map<Object?, Object?> map) {
    return map.map((key, value) {
      if (value is List) {
        return MapEntry(
            key.toString(), List<String>.from(value.map((e) => e.toString())));
      }
      return MapEntry(key.toString(), value);
    });
  }
}
