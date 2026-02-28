import 'package:example/simulator_warning.dart';
import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_mixin.dart';

void main() {
  runApp(const MaterialApp(home: SSIDExample()));
}

/// Simplest way to resolve the WiFi SSID: use SSIDResolverMixin.
/// It handles permissions, lifecycle, and calls onSSIDChanged() automatically.
///
/// For more control (e.g. manual permission requests, on-demand resolution),
/// see SSIDHelperExample in ssidhelper_example.dart which uses SSIDHelper.
class SSIDExample extends StatefulWidget {
  const SSIDExample({super.key});

  @override
  State<SSIDExample> createState() => _SSIDExampleState();
}

class _SSIDExampleState extends State<SSIDExample>
    with SSIDResolverMixin<SSIDExample> {
  String _ssid = 'Resolving...';

  @override
  void onSSIDChanged(String ssid) {
    setState(() => _ssid = ssid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSID Resolver')),
      body: Center(
        child: Text(
          _ssid,
          style: const TextStyle(fontSize: 24),
        ),
      ),
      bottomNavigationBar: const SimulatorWarning(),
    );
  }
}
