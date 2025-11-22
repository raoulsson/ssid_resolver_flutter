// example/lib/do_it_yourself_example.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';

/// Example class to demonstrate how to use the SSID Resolver plugin. You need
/// the WidgetsBindingObserver and the state variable _isRequestingPermission to
/// handle the permission request flow.
/// If this looks too complicated, consider using the SimpleUsageExample.
void main() {
  runApp(const MyClientThree());
}

class MyClientThree extends StatefulWidget {
  const MyClientThree({super.key});

  @override
  State<MyClientThree> createState() => _MyClientThreeState();
}

class _MyClientThreeState extends State<MyClientThree>
    with WidgetsBindingObserver {
  final _ssidResolver = SSIDResolver();
  String _ssid = '';
  bool _isRequestingPermission = false;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> _checkPermissionAndContinue() async {
    _permissionCheckTimer?.cancel();
    _isRequestingPermission = false;

    final permissionStatus = await _ssidResolver.checkPermissionStatus();
    if (permissionStatus.isGranted) {
      final ssid = await _ssidResolver.resolveSSID();
      setState(() => _ssid = ssid);
    } else {
      setState(() => _ssid = "Permission denied");
    }
  }

  Future<void> _getSSID() async {
    setState(() => _ssid = "Checking permissions...");

    final initialStatus = await _ssidResolver.checkPermissionStatus();
    if (initialStatus.isGranted) {
      final ssid = await _ssidResolver.resolveSSID();
      setState(() => _ssid = ssid);
      return;
    }

    _isRequestingPermission = true;
    await _ssidResolver.requestPermission();

    // Check immediately in case no modal was shown
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isRequestingPermission) return;

    await _checkPermissionAndContinue();

    // Set up periodic checks in case the app didn't lose focus
    _permissionCheckTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _checkPermissionAndContinue(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF142467),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Center(
                    child: Text(
                      'SSID Resolver Involved',
                      style: TextStyle(
                        color: const Color(0xFFFFA500),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // SSID Result Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _ssid,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF142467),
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Request Permissions Button
                  ElevatedButton(
                    onPressed: _getSSID,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Resolve SSID'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
