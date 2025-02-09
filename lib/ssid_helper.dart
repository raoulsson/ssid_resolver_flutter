// lib/src/ssid_manager.dart
import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';

/// Helper class to manage the SSID resolution and permission handling.
/// The permission request flow is triggered "on-startup" when calling the initialize method.
/// Subsequent calls to getSSID will return the SSID if the permission is granted.
class SSIDHelper with WidgetsBindingObserver {
  final _ssidResolver = SSIDResolver();
  bool _initialized = false;
  bool _permissionGranted = false;

  /// Initializes the SSIDManager and triggers the permission request flow.
  /// Call this in your Widget's initState method. It will instantly open the
  /// permission dialog handled by the OS.
  Future<void> initialize() async {
    if (_initialized) return;

    WidgetsBinding.instance.addObserver(this);
    await _checkPermission();
    if (!_permissionGranted) {
      await requestPermissionIfNeeded();
    }
    _initialized = true;
  }

  Future<void> _checkPermission() async {
    final status = await _ssidResolver.checkPermissionStatus();
    _permissionGranted = status.isGranted;
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (_permissionGranted) return true;

    final status = await _ssidResolver.requestPermission();
    _permissionGranted = status.isGranted;
    return _permissionGranted;
  }

  Future<String?> getSSID() async {
    if (!_permissionGranted) return null;
    return _ssidResolver.resolveSSID();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }
}

