// example/lib/with_ssidresolver_mixin_example.dart
import 'package:flutter/cupertino.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_mixin.dart';

void main() {
  runApp(const MyClientOne());
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
    return Center(
      child: Text(_ssid),
    );
  }
}
