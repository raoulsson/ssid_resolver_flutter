// example/lib/with_ssidresolver_mixin_example.dart
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
      home: MyClientOne(),
    );
  }
}

class MyClientOne extends StatefulWidget {
  const MyClientOne({super.key});

  @override
  State<MyClientOne> createState() => _MyClientOneState();
}

class _MyClientOneState extends State<MyClientOne>
    with SSIDResolverMixin<MyClientOne> {
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
    );
  }
}