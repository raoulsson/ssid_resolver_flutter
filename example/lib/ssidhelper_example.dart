// example/lib/using_ssidhelper_example.dart
import 'package:ssid_resolver_flutter/ssid_helper.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyClientTwo());
}

/// Example class to demonstrate how to use the SSID Resolver plugin with the SSIDManager.
/// In practice, you would use the SSIDManager in your app to handle the location permission
/// once and then resolve the SSID whenever you need it. So this code is much simpler.
/// The initial call that triggers the OS permission dialog is done by the SSIDManager
/// on initialization. Thus, whe clicking the button, the SSID is resolved immediately.
class MyClientTwo extends StatefulWidget {
  const MyClientTwo({super.key});

  @override
  State<MyClientTwo> createState() => _MyClientTwoState();
}

class _MyClientTwoState extends State<MyClientTwo> {
  final _ssidManager = SSIDHelper();
  String _ssid = '';

  @override
  void initState() {
    super.initState();
    _ssidManager.initialize();
  }

  @override
  void dispose() {
    _ssidManager.dispose();
    super.dispose();
  }

  Future<void> _resolveSSID() async {
    if (await _ssidManager.requestPermissionIfNeeded()) {
      final ssid = await _ssidManager.getSSID();
      setState(() => _ssid = ssid ?? 'Unknown');
    } else {
      setState(() => _ssid = 'Permission denied');
    }
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
                      'SSID Resolver Simple',
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
                    onPressed: _resolveSSID,
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
