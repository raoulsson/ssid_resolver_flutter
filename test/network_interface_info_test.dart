import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter.dart';
import 'package:ssid_resolver_flutter/ssid_resolver_flutter_method_channel.dart';

/// The exact shape the native sides send. Kept as a literal so a change to the
/// native contract shows up here as a failing test rather than as an empty list
/// at runtime.
Map<Object?, Object?> wire({
  String name = 'en0',
  String ip = '10.8.2.77',
  String netmask = '255.255.240.0',
  String broadcast = '10.8.15.255',
  Object? prefixLength = 20,
}) =>
    {'name': name, 'ip': ip, 'netmask': netmask, 'broadcast': broadcast, 'prefixLength': prefixLength};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ssid_resolver_flutter');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('NetworkInterfaceInfo.fromMap', () {
    test('parses a well-formed entry', () {
      final i = NetworkInterfaceInfo.fromMap(wire());
      expect(i.name, 'en0');
      expect(i.ip, '10.8.2.77');
      expect(i.netmask, '255.255.240.0');
      expect(i.broadcast, '10.8.15.255');
      expect(i.prefixLength, 20);
    });

    test('survives missing keys rather than throwing', () {
      final i = NetworkInterfaceInfo.fromMap(<Object?, Object?>{});
      expect(i.name, '');
      expect(i.ip, '');
      expect(i.prefixLength, 0);
    });

    test('survives null values', () {
      final i = NetworkInterfaceInfo.fromMap(wire(prefixLength: null));
      expect(i.prefixLength, 0);
    });

    test('accepts prefixLength arriving as a String', () {
      // Some channel codecs widen numbers; a String must not become 0 silently
      // when it carries a real value.
      expect(NetworkInterfaceInfo.fromMap(wire(prefixLength: '24')).prefixLength, 24);
    });

    test('falls back to 0 for an unparseable prefixLength', () {
      expect(NetworkInterfaceInfo.fromMap(wire(prefixLength: 'twenty')).prefixLength, 0);
    });

    test('accepts prefixLength arriving as a double', () {
      // Channel codecs can widen an int to a double; 20.0 must stay 20 and
      // not fall through string parsing to 0.
      expect(NetworkInterfaceInfo.fromMap(wire(prefixLength: 20.0)).prefixLength, 20);
    });

    test('round-trips through toMap', () {
      final i = NetworkInterfaceInfo.fromMap(wire());
      expect(NetworkInterfaceInfo.fromMap(i.toMap()), i);
    });
  });

  group('classification', () {
    NetworkInterfaceInfo of(String name, String ip) =>
        NetworkInterfaceInfo.fromMap(wire(name: name, ip: ip));

    test('loopback', () {
      expect(of('lo0', '127.0.0.1').isLoopback, isTrue);
      expect(of('lo0', '127.255.255.254').isLoopback, isTrue);
      expect(of('en0', '10.8.2.77').isLoopback, isFalse);
    });

    test('link-local means no usable network', () {
      expect(of('en0', '169.254.10.3').isLinkLocal, isTrue);
      expect(of('en0', '169.253.10.3').isLinkLocal, isFalse);
    });

    test('tunnels are excluded — broadcasting into a VPN closes iOS sockets', () {
      expect(of('utun4', '10.5.0.2').isTunnel, isTrue);
      expect(of('tun0', '10.5.0.2').isTunnel, isTrue);
      expect(of('ppp0', '10.5.0.2').isTunnel, isTrue);
      expect(of('ipsec0', '10.5.0.2').isTunnel, isTrue);
    });

    test('ordinary interfaces are not mistaken for tunnels', () {
      for (final n in ['en0', 'en1', 'wlan0', 'eth0', 'rmnet0', 'ap1']) {
        expect(of(n, '10.8.2.77').isTunnel, isFalse, reason: '$n must not be classified as a tunnel');
      }
      // rmnet0 is not a tunnel, but it is cellular and must still be rejected:
      // on a /32 its computed broadcast is its own IP, and sending there goes
      // out over mobile data and reaches nothing.
      expect(of('rmnet0', '10.8.2.77').isUsableLan, isFalse);
    });

    test('cellular interfaces are detected', () {
      for (final n in ['pdp_ip0', 'pdp_ip1', 'rmnet0', 'rmnet_data1', 'ccmni0', 'radio0', 'clat4']) {
        expect(of(n, '10.55.21.9').isCellular, isTrue, reason: '$n is cellular');
        expect(of(n, '10.55.21.9').isUsableLan, isFalse, reason: '$n must not be a usable LAN');
      }
    });

    test('LAN interfaces are not mistaken for cellular', () {
      for (final n in ['en0', 'wlan0', 'eth0', 'ap1']) {
        expect(of(n, '10.8.2.77').isCellular, isFalse, reason: '$n must not be classified as cellular');
      }
    });

    test('isUsableLan is the conjunction of the four', () {
      expect(of('en0', '10.8.2.77').isUsableLan, isTrue);
      expect(of('lo0', '127.0.0.1').isUsableLan, isFalse);
      expect(of('en0', '169.254.1.1').isUsableLan, isFalse);
      expect(of('utun4', '10.5.0.2').isUsableLan, isFalse);
      expect(of('pdp_ip0', '10.55.21.9').isUsableLan, isFalse);
    });
  });

  group('fetchNetworkInterfaces', () {
    test('maps a native list', () async {
      mock((_) => [wire(), wire(name: 'lo0', ip: '127.0.0.1', prefixLength: 8)]);
      final r = await SSIDResolver().fetchNetworkInterfaces();
      expect(r, hasLength(2));
      expect(r.first.broadcast, '10.8.15.255');
    });

    test('empty native list', () async {
      mock((_) => <Object?>[]);
      expect(await SSIDResolver().fetchNetworkInterfaces(), isEmpty);
    });

    test('null result', () async {
      mock((_) => null);
      expect(await SSIDResolver().fetchNetworkInterfaces(), isEmpty);
    });

    test('non-map entries are skipped, not fatal', () async {
      mock((_) => [wire(), 'garbage', 42, null]);
      final r = await SSIDResolver().fetchNetworkInterfaces();
      expect(r, hasLength(1));
    });

    test('a PlatformException yields an empty list, never a throw', () async {
      // A caller uses this to decide where to send discovery traffic. Throwing
      // here turns a recoverable "no info" into a dead scan.
      mock((_) => throw PlatformException(code: 'BOOM'));
      expect(await SSIDResolver().fetchNetworkInterfaces(), isEmpty);
    });

    test('a missing plugin yields an empty list', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await SSIDResolver().fetchNetworkInterfaces(), isEmpty);
    });

    test('calls the agreed method name', () async {
      String? seen;
      mock((call) {
        seen = call.method;
        return <Object?>[];
      });
      await SSIDResolver().fetchNetworkInterfaces();
      expect(seen, 'fetchNetworkInterfaces');
    });
  });

  group('broadcastAddresses', () {
    test('keeps only real LAN interfaces', () async {
      mock((_) => [
            wire(),
            wire(name: 'lo0', ip: '127.0.0.1', broadcast: '127.255.255.255', prefixLength: 8),
            wire(name: 'utun4', ip: '10.5.0.2', broadcast: '10.5.255.255', prefixLength: 16),
            wire(name: 'en1', ip: '169.254.3.3', broadcast: '169.254.255.255', prefixLength: 16),
          ]);
      expect(await SSIDResolver().broadcastAddresses(), ['10.8.15.255']);
    });

    test('deduplicates interfaces sharing a broadcast', () async {
      mock((_) => [wire(), wire(name: 'en1', ip: '10.8.2.78')]);
      expect(await SSIDResolver().broadcastAddresses(), ['10.8.15.255']);
    });

    test('drops entries with an empty broadcast', () async {
      mock((_) => [wire(broadcast: '')]);
      expect(await SSIDResolver().broadcastAddresses(), isEmpty);
    });

    test('does not produce the /24 guess on a /20', () async {
      // The regression this whole feature exists to prevent.
      mock((_) => [wire()]);
      final r = await SSIDResolver().broadcastAddresses();
      expect(r, contains('10.8.15.255'));
      expect(r, isNot(contains('10.8.2.255')));
    });
  });

  group('method channel layer', () {
    test('MethodChannelSsidResolverFlutter maps entries', () async {
      mock((_) => [wire()]);
      final r = await MethodChannelSsidResolverFlutter().fetchNetworkInterfaces();
      expect(r.single.prefixLength, 20);
    });

    test('honours the empty-list-never-throw contract on a PlatformException', () async {
      mock((_) => throw PlatformException(code: 'BOOM'));
      expect(await MethodChannelSsidResolverFlutter().fetchNetworkInterfaces(), isEmpty);
    });

    test('honours the contract when the plugin is missing', () async {
      messenger.setMockMethodCallHandler(channel, null);
      expect(await MethodChannelSsidResolverFlutter().fetchNetworkInterfaces(), isEmpty);
    });
  });
}
