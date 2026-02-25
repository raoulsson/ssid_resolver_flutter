import 'dart:async';
import 'package:flutter/widgets.dart';
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

mixin SSIDResolverMixin<T extends StatefulWidget> on State<T> {
  static const String unknownSSID = "Unknown";
  final _ssidResolver = SSIDResolver();
  bool _isRequestingPermission = false;
  Timer? _permissionCheckTimer;
  late final _SSIDResolverLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _SSIDResolverLifecycleObserver(
      onResumed: () {
        if (_isRequestingPermission) {
          _checkPermissionAndContinue();
        }
      },
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    getSSID();
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
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
}

class _SSIDResolverLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;

  _SSIDResolverLifecycleObserver({required this.onResumed});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
