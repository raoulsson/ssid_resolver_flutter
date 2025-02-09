// lib/ssid_resolver_flutter.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ssid_resolver_flutter/permission_status.dart';
import 'ssid_resolver_flutter_platform_interface.dart';

class SSIDResolver {
  static const MethodChannel _channel = MethodChannel('ssid_resolver_flutter');

  Future<String?> getPlatformVersion() {
    return SsidResolverFlutterPlatform.instance.getPlatformVersion();
  }

  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('checkPermissionStatus');
      return PermissionStatus.fromMap(Map<String, dynamic>.from(result!));
    } on PlatformException catch (e) {
      return PermissionStatus(
        status: 'Error',
        grantedPermissions: [],
        deniedPermissions: [],
        errorMessage: e.message,
      );
    }
  }

  Future<PermissionStatus> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('requestPermission');
      return PermissionStatus.fromMap(Map<String, dynamic>.from(result!));
    } on PlatformException catch (e) {
      return PermissionStatus(
        status: 'Error',
        grantedPermissions: [],
        deniedPermissions: [],
        errorMessage: e.message,
      );
    }
  }

  Future<String> resolveSSID() async {
    try {
      final String result = await _channel.invokeMethod('fetchSsid');
      return result;
    } on PlatformException catch (e) {
      throw Exception(e.message);
    }
  }
}