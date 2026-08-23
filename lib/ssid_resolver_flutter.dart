// lib/ssid_resolver_flutter.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:ssid_resolver_flutter/network_interface_info.dart';
import 'package:ssid_resolver_flutter/permission_status.dart';
import 'ssid_resolver_flutter_platform_interface.dart';

export 'network_interface_info.dart';

class SSIDResolver {
  static const MethodChannel _channel = MethodChannel('ssid_resolver_flutter');

  /// Emit per-call diagnostics to `dart:developer`. Off by default so the
  /// package stays quiet in someone else's app.
  ///
  /// Turn this on when discovery is not finding devices: it prints every
  /// interface the OS reported and which of them survived filtering, which is
  /// the difference between "no devices answered" and "we broadcast to the
  /// wrong address". Those two look identical from the outside and are the
  /// reason this switch exists.
  static bool verbose = false;

  static void _log(String message) {
    if (verbose) developer.log(message, name: 'ssid_resolver_flutter');
  }

  /// Failures are reported even when [verbose] is off. The methods below
  /// deliberately return an empty list rather than throwing, and an empty list
  /// that never says why is how a broken platform channel gets mistaken for an
  /// empty network.
  static void _logFailure(String message) {
    developer.log(message, name: 'ssid_resolver_flutter', level: 900);
  }

  Future<String?> getPlatformVersion() {
    return SsidResolverFlutterPlatform.instance.getPlatformVersion();
  }

  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('checkPermissionStatus');
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
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('requestPermission');
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

  /// Every IPv4 interface with its real netmask and directed broadcast address.
  ///
  /// Unlike [resolveSSID] this needs no permission at all — it reads the local
  /// interface table rather than the WiFi identity — so it works on a device
  /// where the user declined Location.
  ///
  /// Returns an empty list rather than throwing when the platform cannot answer:
  /// callers use this to decide where to send discovery traffic, and an
  /// exception at that point tends to become a dead scan rather than a message.
  Future<List<NetworkInterfaceInfo>> fetchNetworkInterfaces() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('fetchNetworkInterfaces');
      if (result == null) {
        _logFailure('fetchNetworkInterfaces: native side returned null, treating as no interfaces');
        return const <NetworkInterfaceInfo>[];
      }
      final maps = result.whereType<Map<Object?, Object?>>().toList(growable: false);
      if (maps.length != result.length) {
        // A shape mismatch between the native payload and this Dart layer would
        // otherwise vanish into whereType and look like a quiet network.
        _logFailure('fetchNetworkInterfaces: ${result.length - maps.length} of ${result.length} entries were not maps and were dropped');
      }
      final interfaces = maps.map(NetworkInterfaceInfo.fromMap).toList(growable: false);
      if (interfaces.isEmpty) {
        _logFailure('fetchNetworkInterfaces: native side reported no IPv4 interfaces');
      } else {
        for (final i in interfaces) {
          _log('interface $i usableLan=${i.isUsableLan}');
        }
      }
      return interfaces;
    } on PlatformException catch (e) {
      _logFailure('fetchNetworkInterfaces failed: ${e.code} ${e.message}');
      return const <NetworkInterfaceInfo>[];
    } on MissingPluginException {
      _logFailure('fetchNetworkInterfaces: plugin not registered on this platform, returning no interfaces');
      return const <NetworkInterfaceInfo>[];
    }
  }

  /// Broadcast addresses worth sending UDP discovery to: real LAN interfaces
  /// only, with loopback, link-local and VPN tunnels filtered out.
  ///
  /// Each address is computed from the interface's actual netmask, so a /20
  /// yields 10.8.15.255 rather than the 10.8.2.255 you get from the widespread
  /// "replace the last octet with 255" shortcut. That shortcut is not a
  /// broadcast address on anything but a /24, and sending to it reaches nothing.
  Future<List<String>> broadcastAddresses() async {
    final interfaces = await fetchNetworkInterfaces();
    final seen = <String>{};
    for (final i in interfaces) {
      if (i.isUsableLan && i.broadcast.isNotEmpty) seen.add(i.broadcast);
    }
    if (seen.isEmpty && interfaces.isNotEmpty) {
      // Every interface was filtered out. On a VPN-only or loopback-only device
      // that is correct, but it is also what a wrong filter looks like, so name
      // the rejects instead of returning a bare empty list.
      _logFailure('broadcastAddresses: all ${interfaces.length} interfaces filtered out '
          '(${interfaces.map((i) => '${i.name}:${i.ip}').join(', ')})');
    } else {
      _log('broadcastAddresses -> ${seen.join(', ')}');
    }
    return seen.toList(growable: false);
  }
}
