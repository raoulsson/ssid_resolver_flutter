import 'package:example/simulator_warning.dart';
import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_helper.dart';

void main() {
  runApp(const MaterialApp(home: SSIDExample()));
}

/// Simple example using SSIDHelper with a button to resolve the SSID on demand.
///
/// For an even simpler approach that auto-resolves on load, see
/// SSIDMixinExample in ssidresolver_mixin_example.dart which uses SSIDResolverMixin.
class SSIDExample extends StatefulWidget {
  const SSIDExample({super.key});

  @override
  State<SSIDExample> createState() => _SSIDExampleState();
}

class _SSIDExampleState extends State<SSIDExample> {
  final _ssidHelper = SSIDHelper();
  String _ssid = '';

  @override
  void initState() {
    super.initState();
    _ssidHelper.initialize();
  }

  @override
  void dispose() {
    _ssidHelper.dispose();
    super.dispose();
  }

  Future<void> _resolveSSID() async {
    if (await _ssidHelper.requestPermissionIfNeeded()) {
      final ssid = await _ssidHelper.getSSID();
      setState(() => _ssid = ssid ?? 'Unknown');
    } else {
      setState(() => _ssid = 'Permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF142467),
      bottomNavigationBar: const SimulatorWarning(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'SSID Resolver',
                    style: TextStyle(
                      color: const Color(0xFFFFA500),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

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
    );
  }
}
