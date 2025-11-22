// example/lib/debug_app.dart
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';

void main() {
  runApp(const DebugApp());
}

/// Example to use for debugging the permissions.
class DebugApp extends StatefulWidget {
  const DebugApp({super.key});

  @override
  State<DebugApp> createState() => _DebugAppState();
}

class _DebugAppState extends State<DebugApp> {
  final _ssidResolver = SSIDResolver();
  String _ssid = 'Unknown SSID Status';
  String _status = 'Unknown Permission Status';
  String _errorMessage = '';
  bool _isLoading = false;
  List<String> _grantedPermissions = [];
  List<String> _deniedPermissions = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _status = 'Requesting...';
      _errorMessage = '';
    });

    try {
      final permissionStatus = await _ssidResolver.requestPermission();
      setState(() {
        _status = permissionStatus.status;
        _grantedPermissions = permissionStatus.grantedPermissions;
        _deniedPermissions = permissionStatus.deniedPermissions;
        _errorMessage = permissionStatus.errorMessage ?? '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _getSsid() async {
    setState(() {
      _isLoading = true;
      _ssid = 'Resolving...';
      _errorMessage = '';
    });

    try {
      final ssid = await _ssidResolver.resolveSSID();
      setState(() {
        _ssid = ssid;
      });
    } on PlatformException catch (e) {
      developer.log('Failed to get Wifi Name', error: e);
      setState(() {
        _ssid = 'Unknown SSID Status';
        _errorMessage = 'Error getting SSID: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _ssid = 'Unknown SSID Status';
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPlatform() {
    if (Platform.isAndroid) {
      return ' (Android)';
    } else if (Platform.isIOS) {
      return ' (iOS)';
    }
    return ' (Unknown)';
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
                      'WiFi SSID Resolver',
                      style: TextStyle(
                        color: const Color(0xFFFFA500),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Flutter Plugin${_getPlatform()}',
                      style: TextStyle(
                        color: const Color(0xFFFFA500),
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
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

                  // Get SSID Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getSsid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isLoading ? 'Resolving...' : 'Resolve SSID'),
                  ),

                  // Divider
                  Divider(
                    color: const Color(0xFFFFA500),
                    thickness: 1,
                    height: 36,
                  ),

                  // Permission Status
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF142467),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Request Permissions Button
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Request Location Permissions'),
                  ),

                  const SizedBox(height: 16),

                  // Granted Permissions
                  const Text(
                    'Granted Permissions:',
                    style: TextStyle(
                      color: Color(0xFFC0C0C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8E6C9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _grantedPermissions.isEmpty
                          ? 'None'
                          : _grantedPermissions.join('\n'),
                      style: const TextStyle(
                        color: Color(0xFF142467),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Denied Permissions
                  const Text(
                    'Denied Permissions:',
                    style: TextStyle(
                      color: Color(0xFFC0C0C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCDD2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _deniedPermissions.isEmpty
                          ? 'None'
                          : _deniedPermissions.join('\n'),
                      style: const TextStyle(
                        color: Color(0xFF142467),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
