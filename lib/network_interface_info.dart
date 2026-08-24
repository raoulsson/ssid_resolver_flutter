/// One IPv4 interface as the OS reports it.
///
/// This exists because Dart's own [NetworkInterface] gives you addresses but no
/// netmask, and without a netmask you cannot compute a broadcast address. The
/// usual workaround — take the first three octets and append ".255" — is only
/// correct on a /24, and silently sends UDP discovery into a black hole on the
/// /16 and /20 networks that plenty of routers hand out.
class NetworkInterfaceInfo {
  /// Interface name as the OS reports it, e.g. `en0`, `wlan0`, `utun3`.
  /// Callers usually want to skip VPN tunnels (`utun*`, `tun*`, `ppp*`).
  final String name;

  /// IPv4 address of this interface, e.g. `10.8.2.77`.
  final String ip;

  /// IPv4 netmask, e.g. `255.255.240.0`.
  final String netmask;

  /// Directed broadcast for this interface, computed natively as
  /// `(ip & netmask) | ~netmask` — e.g. `10.8.15.255` for a /20, NOT `10.8.2.255`.
  final String broadcast;

  /// Netmask as a prefix length, e.g. 20 for `255.255.240.0`.
  final int prefixLength;

  const NetworkInterfaceInfo({
    required this.name,
    required this.ip,
    required this.netmask,
    required this.broadcast,
    required this.prefixLength,
  });

  /// True for 127.0.0.0/8.
  bool get isLoopback => ip.startsWith('127.');

  /// True for 169.254.0.0/16 — a self-assigned address, meaning no usable network.
  bool get isLinkLocal => ip.startsWith('169.254.');

  /// True for interfaces that are typically VPN tunnels rather than the LAN the
  /// user's devices are on. Broadcasting into these is what closes iOS sockets.
  bool get isTunnel =>
      name.startsWith('utun') || name.startsWith('tun') || name.startsWith('ppp') || name.startsWith('ipsec');

  /// True for cellular data interfaces: `pdp_ip*` on iOS; `rmnet*`, `ccmni*`,
  /// `radio*` and vendor variants on Android; `clat*` for 464XLAT over cellular.
  /// iOS cellular carries a /32, whose computed broadcast is the interface's
  /// own address; Android cellular was observed on a /30, a point-to-point
  /// subnet with no discovery targets on it (never assume /32 universally).
  /// Either way, a UDP send to the derived broadcast goes out over mobile data
  /// and reaches nothing — which is why [isUsableLan] excludes cellular.
  bool get isCellular =>
      name.startsWith('pdp_ip') ||
      name.startsWith('rmnet') ||
      name.startsWith('ccmni') ||
      name.startsWith('radio') ||
      name.startsWith('clat');

  /// The interfaces worth broadcasting on: a real LAN, not loopback, not a
  /// self-assigned address, not a tunnel, not cellular.
  bool get isUsableLan => !isLoopback && !isLinkLocal && !isTunnel && !isCellular;

  factory NetworkInterfaceInfo.fromMap(Map<Object?, Object?> map) {
    return NetworkInterfaceInfo(
      name: (map['name'] ?? '').toString(),
      ip: (map['ip'] ?? '').toString(),
      netmask: (map['netmask'] ?? '').toString(),
      broadcast: (map['broadcast'] ?? '').toString(),
      // Channel codecs can widen an int to a double; `20.0` must stay 20, not
      // fall through string parsing to 0.
      prefixLength: (map['prefixLength'] is num)
          ? (map['prefixLength'] as num).toInt()
          : int.tryParse('${map['prefixLength']}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ip': ip,
        'netmask': netmask,
        'broadcast': broadcast,
        'prefixLength': prefixLength,
      };

  @override
  String toString() => 'NetworkInterfaceInfo($name, ip: $ip, netmask: $netmask, broadcast: $broadcast, /$prefixLength)';

  @override
  bool operator ==(Object other) =>
      other is NetworkInterfaceInfo && other.name == name && other.ip == ip && other.netmask == netmask;

  @override
  int get hashCode => Object.hash(name, ip, netmask);
}
