import 'package:example/network_interfaces_example.dart';
import 'package:example/ssidhelper_example.dart';
import 'package:example/ssidresolver_mixin_example.dart';
import 'package:example/do_it_yourself_example.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ssid_resolver_flutter/ssid_helper.dart';

import 'simulator_warning.dart';

void main() {
  runApp(const MaterialApp(home: ExampleHome()));
}

/// Entry point listing every example screen in this app. Added alongside the
/// 1.5.0 network-interface screen so that screen -- and every example that
/// was already here -- stays reachable rather than one of them replacing the
/// other as the thing main() launches.
class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ssid_resolver_flutter examples'),
        backgroundColor: const Color(0xFF142467),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const SimulatorWarning(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _tile(
              context,
              title: 'SSID via SSIDHelper',
              subtitle: 'Button-triggered SSID resolve using SSIDHelper',
              builder: (_) => const SSIDExample(),
            ),
            _tile(
              context,
              title: 'SSID via SSIDResolverMixin',
              subtitle: 'Auto-resolves on load using SSIDResolverMixin',
              builder: (_) => const SSIDMixinExample(),
            ),
            _tile(
              context,
              title: 'SSID via SSIDHelperExample',
              subtitle: 'SSIDManager-driven permission flow',
              builder: (_) => const SSIDHelperExample(),
            ),
            _tile(
              context,
              title: 'SSID do-it-yourself',
              subtitle: 'Manual permission handling without SSIDHelper',
              builder: (_) => const DIYExample(),
            ),
            _tile(
              context,
              title: 'Network Interfaces (1.5.0)',
              subtitle: 'Hardware validation for fetchNetworkInterfaces() / broadcastAddresses()',
              builder: (_) => const NetworkInterfacesExample(),
            ),
            const SizedBox(height: 8),
            // Below the examples rather than among them: the repository is not
            // one more thing to try, it is where you go after trying them.
            _repoLink(),
          ],
        ),
      ),
    );
  }

  Widget _repoLink() {
    return Center(
      child: TextButton.icon(
        onPressed: () => launchUrl(
          Uri.parse('https://github.com/raoulsson/ssid_resolver_flutter'),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: const Text('github.com/raoulsson/ssid_resolver_flutter'),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required WidgetBuilder builder,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
      ),
    );
  }
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
      // Pushed from the home list, so it needs its own bar to get back from.
      appBar: AppBar(
        title: const Text('SSID via SSIDHelper'),
        backgroundColor: const Color(0xFF142467),
        foregroundColor: Colors.white,
      ),
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
