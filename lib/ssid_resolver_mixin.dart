import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';

// Mixin for usage in client code. This code will on load ask for user permissions and update the ssid if permissions are granted.
// Usage example:
/*
class MyClient extends StatefulWidget {
  const MyClient({super.key});
  @override
  State<MyClient> createState() => _MyClientState();
}

class _MyClientState extends State<MyClient> with SSIDResolverMixin<MyClient> {
  String _ssid = '';

  @override
  void onSSIDChanged(String ssid) {
    setState(() => _ssid = ssid);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(_ssid),
    );
  }
}
*/

mixin SSIDResolverMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  static const String unknownSSID = "Unknown";
  final _ssidResolver = SSIDResolver();
  bool _isRequestingPermission = false;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getSSID();
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRequestingPermission) {
      _checkPermissionAndContinue();
    }
  }

  void onSSIDChanged(String ssid);

  Future<void> _checkPermissionAndContinue() async {
    _permissionCheckTimer?.cancel();
    _isRequestingPermission = false;

    final permissionStatus = await _ssidResolver.checkPermissionStatus();
    if (permissionStatus.isGranted) {
      final newSsid = await _ssidResolver.resolveSSID();
      onSSIDChanged(newSsid);
    } else {
      onSSIDChanged(unknownSSID);
    }
  }

  Future<void> getSSID() async {
    onSSIDChanged(unknownSSID);

    final initialStatus = await _ssidResolver.checkPermissionStatus();
    if (initialStatus.isGranted) {
      final newSsid = await _ssidResolver.resolveSSID();
      onSSIDChanged(newSsid);
      return;
    }

    _isRequestingPermission = true;
    await _ssidResolver.requestPermission();

    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isRequestingPermission) return;

    await _checkPermissionAndContinue();

    _permissionCheckTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _checkPermissionAndContinue(),
    );
  }

  // WidgetsBindingObserver implementations
  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  Future<bool> didPopRoute() async => false;

  @override
  Future<bool> didPushRoute(String route) async => false;

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      false;

  @override
  void didChangeViewFocus(ViewFocusEvent event) {}

  @override
  Future<AppExitResponse> didRequestAppExit() {
    throw UnimplementedError();
  }

  @override
  void handleCancelBackGesture() {}

  @override
  void handleCommitBackGesture() {}

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    throw UnimplementedError();
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {}
}
