import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';

import 'simulator_warning.dart';

/// Hardware validation screen for the 1.5.0 network-interface API.
///
/// This exists to make a pass/fail judgement possible by eye, on a phone,
/// with no debugger attached: list every interface and how it was
/// classified, show what broadcastAddresses() actually returns, compare it
/// against the naive "last octet .255" guess so the fix this release makes
/// is visible rather than asserted, and finally prove the socket side by
/// actually sending UDP to each candidate address.
class NetworkInterfacesExample extends StatefulWidget {
  const NetworkInterfacesExample({super.key});

  @override
  State<NetworkInterfacesExample> createState() => _NetworkInterfacesExampleState();
}

/// Outcome of one address we attempted to send a UDP probe to.
class _SendResult {
  final String address;
  final bool naive;
  final bool ok;
  final String? error;

  const _SendResult({
    required this.address,
    required this.naive,
    required this.ok,
    this.error,
  });
}

class _NetworkInterfacesExampleState extends State<NetworkInterfacesExample> {
  final _resolver = SSIDResolver();

  List<NetworkInterfaceInfo> _interfaces = const [];
  List<String> _broadcasts = const [];
  String? _loadError;
  bool _loading = false;

  List<_SendResult>? _sendResults;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    SSIDResolver.verbose = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _sendResults = null;
    });
    try {
      final interfaces = await _resolver.fetchNetworkInterfaces();
      final broadcasts = await _resolver.broadcastAddresses();
      setState(() {
        _interfaces = interfaces;
        _broadcasts = broadcasts;
      });
    } catch (e) {
      setState(() => _loadError = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  /// First three octets of an IPv4 address plus ".255" -- the shortcut that
  /// is only correct on a /24 network. Returns null for anything not shaped
  /// like an IPv4 address.
  String? _naiveGuess(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}.255';
  }

  Future<void> _sendProbes() async {
    setState(() {
      _sending = true;
      _sendResults = [];
    });

    // (address, isNaiveGuess) pairs to probe: every real broadcast address,
    // plus any naive /24 guess that isn't already one of them -- so a /24
    // network (where the two coincide) doesn't send the same address twice.
    final addressesToTry = <MapEntry<String, bool>>[];
    for (final address in _broadcasts) {
      addressesToTry.add(MapEntry(address, false));
    }
    for (final iface in _interfaces) {
      if (!iface.isUsableLan) continue;
      final naive = _naiveGuess(iface.ip);
      if (naive != null && !_broadcasts.contains(naive)) {
        addressesToTry.add(MapEntry(naive, true));
      }
    }

    RawDatagramSocket? socket;
    final results = <_SendResult>[];
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final payload = 'ssid_resolver_flutter probe ${DateTime.now().millisecondsSinceEpoch}'.codeUnits;

      for (final entry in addressesToTry) {
        final address = entry.key;
        final isNaive = entry.value;
        try {
          final sent = socket.send(payload, InternetAddress(address), 7891);
          results.add(_SendResult(address: address, naive: isNaive, ok: sent > 0, error: sent > 0 ? null : 'send() returned 0 bytes'));
        } catch (e) {
          results.add(_SendResult(address: address, naive: isNaive, ok: false, error: e.toString()));
        }
        if (mounted) setState(() => _sendResults = List.of(results));
      }

      // Keep the socket open briefly in case anything answers -- nothing is
      // required to, this only proves the sends themselves, but a short
      // listen window costs nothing and occasionally shows a live reply.
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (e) {
      results.add(_SendResult(address: '(bind)', naive: false, ok: false, error: e.toString()));
    } finally {
      socket?.close();
      if (mounted) {
        setState(() {
          _sendResults = results;
          _sending = false;
        });
      }
    }
  }

  Color _classificationColor(NetworkInterfaceInfo i) {
    if (i.isUsableLan) return const Color(0xFF2E7D32); // green
    if (i.isLoopback) return const Color(0xFF757575); // grey
    if (i.isLinkLocal) return const Color(0xFFB71C1C); // red
    if (i.isTunnel) return const Color(0xFF6A1B9A); // purple
    if (i.isCellular) return const Color(0xFFE65100); // orange
    return const Color(0xFF757575);
  }

  String _classificationLabel(NetworkInterfaceInfo i) {
    if (i.isUsableLan) return 'USABLE LAN';
    final reasons = <String>[
      if (i.isLoopback) 'loopback',
      if (i.isLinkLocal) 'link-local',
      if (i.isTunnel) 'tunnel',
      if (i.isCellular) 'cellular',
    ];
    return reasons.isEmpty ? 'filtered' : reasons.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Interfaces (1.5.0)'),
        backgroundColor: const Color(0xFF142467),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      bottomNavigationBar: const SimulatorWarning(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (_loadError != null) _errorBanner(_loadError!),
                    _sectionTitle('Broadcast addresses returned'),
                    _broadcastsCard(),
                    const SizedBox(height: 16),
                    _sectionTitle('Computed vs. naive /24 guess'),
                    ..._interfaces.where((i) => i.isUsableLan).map(_comparisonCard),
                    if (_interfaces.where((i) => i.isUsableLan).isEmpty) _emptyNote('No usable LAN interfaces to compare.'),
                    const SizedBox(height: 16),
                    _sectionTitle('Live UDP proof'),
                    _udpProofCard(),
                    const SizedBox(height: 16),
                    _sectionTitle('All interfaces (${_interfaces.length})'),
                    ..._interfaces.map(_interfaceRow),
                    if (_interfaces.isEmpty && _loadError == null) _emptyNote('No interfaces reported.'),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF142467)),
        ),
      );

  Widget _errorBanner(String message) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB71C1C)),
        ),
        child: Text(message, style: const TextStyle(color: Color(0xFFB71C1C))),
      );

  Widget _emptyNote(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );

  Widget _broadcastsCard() {
    if (_broadcasts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('broadcastAddresses() returned nothing -- no usable LAN interface was found.'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _broadcasts
            .map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    b,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _comparisonCard(NetworkInterfaceInfo iface) {
    final naive = _naiveGuess(iface.ip);
    final differs = naive != null && naive != iface.broadcast;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: differs ? const Color(0xFFFFF8E1) : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: differs ? const Color(0xFFF9A825) : const Color(0xFF9CCC65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${iface.name}  ${iface.ip}/${iface.prefixLength}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('computed broadcast:  ${iface.broadcast}', style: const TextStyle(fontFamily: 'monospace')),
          Text('naive /24 guess:     ${naive ?? '(unparseable)'}', style: const TextStyle(fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text(
            differs
                ? 'DIFFERENT -- this is a /${iface.prefixLength} network, and the naive guess would have missed the real broadcast. This is exactly the bug 1.5.0 fixes.'
                : 'SAME -- this is a /24 network, so the naive guess happens to be correct here. Expected, not a sign the fix does nothing.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: differs ? const Color(0xFFE65100) : const Color(0xFF33691E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _udpProofCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Binds a UDP socket and sends a small probe to every address from '
            'broadcastAddresses() plus any naive /24 guess not already in that '
            'list. Nothing needs to answer -- this only proves whether the '
            'send itself succeeds or throws (e.g. EADDRNOTAVAIL).',
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _sending ? null : _sendProbes,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF142467),
              foregroundColor: Colors.white,
            ),
            child: Text(_sending ? 'Sending...' : 'Send UDP probes'),
          ),
          if (_sendResults != null) ...[
            const SizedBox(height: 12),
            ..._sendResults!.map(_sendResultRow),
          ],
        ],
      ),
    );
  }

  Widget _sendResultRow(_SendResult r) {
    final color = r.ok ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(r.ok ? Icons.check_circle : Icons.error, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${r.address}${r.naive ? ' (naive /24)' : ''}: ',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: color),
                  ),
                  TextSpan(
                    text: r.ok ? 'sent OK' : (r.error ?? 'error'),
                    style: TextStyle(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interfaceRow(NetworkInterfaceInfo i) {
    final color = _classificationColor(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 5)),
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _classificationLabel(i),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('ip: ${i.ip}/${i.prefixLength}', style: const TextStyle(fontFamily: 'monospace')),
          Text('netmask: ${i.netmask}', style: const TextStyle(fontFamily: 'monospace')),
          Text('broadcast: ${i.broadcast}', style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
