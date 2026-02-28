// example/lib/with_ssidresolver_mixin_example.dart
import 'package:example/simulator_warning.dart';
import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_mixin.dart';

void main() {
  runApp(const MixinExampleApp());
}

class MixinExampleApp extends StatelessWidget {
  const MixinExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SSIDMixinExample(),
    );
  }
}

class SSIDMixinExample extends StatefulWidget {
  const SSIDMixinExample({super.key});

  @override
  State<SSIDMixinExample> createState() => _SSIDMixinExampleState();
}

class _SSIDMixinExampleState extends State<SSIDMixinExample>
    with SSIDResolverMixin<SSIDMixinExample> {
  String _ssid = '';

  @override
  void onSSIDChanged(String ssid) {
    setState(() => _ssid = ssid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Your Wi-Fi SSID is: $_ssid"),
      ),
      bottomNavigationBar: const SimulatorWarning(),
    );
  }
}