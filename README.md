# ssid_resolver_flutter - "Get my Wi-Fi Name"

A Flutter plugin that resolves the SSID of the connected Wi-Fi network, or simply: "Get my Wi-Fi
Name". Supports Android and iOS.

[![Pub Version](https://img.shields.io/pub/v/ssid_resolver_flutter?style=flat-square)](https://pub.dev/packages/ssid_resolver_flutter)

Getting the SSID is mostly a permission problem, and that is what this README leads with: exactly
what your app has to declare, in one place, copy-pasteable. Since 1.5.0 the plugin also reads the
**real netmask** of every network interface and derives the correct **UDP broadcast address** from
it - if Flutter device discovery has ever silently failed for you on an office or campus network,
see [the netmask and the broadcast address](#the-netmask-and-the-broadcast-address) further down.

## Quick start

Add the dependency:

```yaml
dependencies:
  ssid_resolver_flutter: ^1.5.0
```

Then declare the permissions. They live in **your app**, not in this package - a Flutter plugin
cannot inject `Info.plist` keys or entitlements into the app that uses it.

### Android: nothing to add

The plugin's own `AndroidManifest.xml` declares everything it needs, and Android's manifest merger
folds it into your app automatically. For reference, this is what merges in:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<queries>
    <package android:name="com.google.android.gms" />
    <package android:name="com.android.settings" />
</queries>
```

Only the two location permissions are runtime permissions the user is prompted for; the plugin
requests them for you. The rest are granted at install and never prompted.

### iOS: three declarations

**1. Usage strings** - add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to read the name of the Wi-Fi network you are connected to.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Used to read the name of the Wi-Fi network you are connected to.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Used to find your devices on the local network.</string>
```

`NSLocalNetworkUsageDescription` is only needed if your app **sends** UDP on the local network -
which is the point of the broadcast API below. Without it the system's Local Network prompt appears
with no explanation at all, which App Review notices.

**2. The entitlement** - the `com.apple.developer.networking.wifi-info` key belongs in
`ios/Runner/Runner.entitlements`, and Xcode writes it there for you:

**3. The capability** - open `ios/Runner/Runner.xcodeproj` in Xcode, go to
"Signing & Capabilities" on the Runner target and add **Access WiFi Information**:

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/add-wifi-capability-1.png" alt="Add WiFi Capability 1" width="400"/>

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/add-wifi-capability-2.png" alt="Add WiFi Capability 2" width="400"/>

This should leave `ios/Runner/Runner.entitlements` looking like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.wifi-info</key>
    <true/>
</dict>
</plist>
```

The capability is standard on a paid Apple Developer team and takes a minute; a free personal team
cannot provision it. Note that iOS ties Wi-Fi identity to Location, so the user must also grant the
Location prompt at runtime - the capability alone is not enough.

### The three iOS gates, told apart

iOS has three separate gates in this area, and they are constantly confused - what looks like one
"network permission" is three different mechanisms with three different owners:

| Gate | What it unlocks | How you get it |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` + the **Access WiFi Information** capability | Reading the SSID | Self-serve in Xcode, as shown above. A paid Apple Developer team provisions the capability in about a minute; a free personal team cannot. |
| `NSLocalNetworkUsageDescription` | Sending on the local network - it supplies the text for the "find devices on your local network" prompt | Add the key to your `Info.plist`. Without it the prompt still appears, with no explanation text, which App Review notices. |
| **Multicast Networking Entitlement** (`com.apple.developer.networking.multicast`) | Multicast and broadcast networking, as Apple documents it | A request to Apple describing your use case; allow about a week. |

The third one deserves a correction, because it is usually framed wrong: it is **not** a
paid-versus-personal tier question. Apple reviews the **intent**. You submit a request describing
what your app does on the network, and Apple decides whether that is something legitimate - finding
and controlling your own devices on the user's own network - or something they do not want, like
sweeping a network to harvest data about other people's devices. If your use is the former, a
single independent developer gets it approved too. "Apple wants to know why", not "you need a
company".

Do you need it for the broadcast API below? Observed: on a physical iPhone 14 (iOS 26.6), the
example app sent UDP to a directed broadcast (`10.8.15.255`) and reported `sent OK` with only
`NSLocalNetworkUsageDescription` in play and no multicast entitlement. At the same time, Apple
documents the entitlement as required for multicast and broadcast, and App Review may require it
for an app whose whole purpose is local device discovery - so an app built around discovery should
expect to request it, even though a plain directed broadcast worked without it in our testing.

The example app's own config files are a working reference:
[AndroidManifest.xml](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/android/app/src/main/AndroidManifest.xml),
[Info.plist](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Info.plist),
[Runner.entitlements](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Runner.entitlements).

### Resolve the SSID

The shortest path is the mixin: add `SSIDResolverMixin` to your state class and implement
`onSSIDChanged`. It triggers the permission request dialog if needed and resolves the SSID in one
step.

```dart
class _SSIDMixinExampleState extends State<SSIDMixinExample>
    with SSIDResolverMixin<SSIDMixinExample> {
  String _ssid = '';

  @override
  void onSSIDChanged(String ssid) {
    setState(() => _ssid = ssid);
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(_ssid));
  }
}
```

Run it on a **physical device**: SSID resolution is not supported on iOS Simulators or Android
Emulators. (The network interface API further down works on simulators and emulators too.)

## When it does not work

Permission setup is the blocker with this kind of plugin, and the example app exists to end the
guessing: it lists **Granted Permissions** and **Denied Permissions** by name, and when a lookup
fails it names exactly which one is missing rather than saying "failed". Run
[debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart)
from [example/lib](https://github.com/raoulsson/ssid_resolver_flutter/tree/master/example/lib) on
the device that is giving you trouble and compare its lists with yours - that is usually a
two-minute answer to a problem that otherwise costs an evening.

Captured on a physical Android device:

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-1-home.jpeg" alt="Example home" width="400"/>

The four SSID examples, with the interface harness at the bottom

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-2-ssid-helper.jpeg" alt="SSID resolved" width="400"/>

`SSIDHelper` resolving a real network name

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-3-mixin.jpeg" alt="Mixin example" width="400"/>

`SSIDResolverMixin` resolving automatically on load

## Using the plugin, three ways

`SSIDResolver` provides three key methods - `resolveSSID()`, `checkPermissionStatus()` and
`requestPermission()` - and two convenience layers on top. Failure behaviour differs by layer, so
here it is once: `resolveSSID()` throws an `Exception` whose message names the cause when
permission is missing (both platforms) or when the iOS lookup fails for another reason; on Android
a lookup that runs with permission granted but cannot get a name resolves to the string
`"Unknown"`. The convenience layers absorb the exception case: `SSIDResolverMixin` reports
`"Unknown"` through `onSSIDChanged` when permission is denied, and `SSIDHelper.getSSID()` returns
`null` then.

### 1. SSIDResolverMixin

The one-step approach shown in the quick start: mix in `SSIDResolverMixin`, implement
`onSSIDChanged`, done. Full source:
[ssidresolver_mixin_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/ssidresolver_mixin_example.dart).

### 2. SSIDHelper

The location permission only has to be granted once in your app's lifetime, so if other screens
appear before you need the SSID, let `SSIDHelper` handle the request early. This spares you the
"re-entry" handling after the OS hands control back from its permission dialog.

At app startup:

```dart
final _ssidHelper = SSIDHelper();

@override
void initState() {
  super.initState();
  _ssidHelper.initialize(); // triggers the permission dialog if needed
}
```

Don't forget `_ssidHelper.dispose();` in your `dispose` method. Later, on the screen that needs
the SSID:

```dart
Future<void> _resolveSSID() async {
  final ssid = await _ssidHelper.getSSID();
  setState(() => _ssid = ssid ?? 'Permission missing');
}
```

`getSSID()` returns `Future<String?>` and yields `null` while the permission is missing, so decide
what your UI shows for that case. Both steps combined:
[ssidhelper_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/ssidhelper_example.dart) -
you will notice the SSID only resolves after you click the button for the second time.

### 3. "Do It Yourself"

For full control over when the permission dialog appears and when the SSID resolves. The OS opens
its own modal dialog and later returns to the app, so you register a `WidgetsBindingObserver` and
continue the flow in `didChangeAppLifecycleState`. Full source:
[do_it_yourself_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/do_it_yourself_example.dart).

```dart
class _DIYExampleState extends State<DIYExample> with WidgetsBindingObserver {
  final _ssidResolver = SSIDResolver();
  String _ssid = '';
  bool _isRequestingPermission = false;
  Timer? _permissionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRequestingPermission) {
      _checkPermissionAndContinue();
    }
  }

  Future<void> _checkPermissionAndContinue() async {
    _permissionCheckTimer?.cancel();
    _isRequestingPermission = false;

    final permissionStatus = await _ssidResolver.checkPermissionStatus();
    if (permissionStatus.isGranted) {
      final ssid = await _ssidResolver.resolveSSID();
      setState(() => _ssid = ssid);
    } else {
      setState(() => _ssid = "Permission denied");
    }
  }

  Future<void> _getSSID() async {
    setState(() => _ssid = "Checking permissions...");

    final initialStatus = await _ssidResolver.checkPermissionStatus();
    if (initialStatus.isGranted) {
      final ssid = await _ssidResolver.resolveSSID();
      setState(() => _ssid = ssid);
      return;
    }

    _isRequestingPermission = true;
    await _ssidResolver.requestPermission();

    // Check immediately in case no modal was shown
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_isRequestingPermission) return;

    await _checkPermissionAndContinue();

    // Set up periodic checks in case the app didn't lose focus
    _permissionCheckTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (_) => _checkPermissionAndContinue(),
    );
  }
  // build() omitted - see the linked example.
}
```

### How Android resolves the SSID

Three tiers, tried in order:

1. **`NetworkCapabilities.transportInfo`** (API 29+) - synchronous, instant result
2. **`WifiManager.connectionInfo`** - fallback for older devices
3. **Async `registerNetworkCallback`** - last resort with 5-second timeout

The plugin does **not** use `WifiManager.startScan()`, which is deprecated and throttled/broken on
modern Android.

## The netmask and the broadcast address

While building the SSID part, a related thing turned out to be quietly broken almost everywhere,
and 1.5.0 solves it too.

**The problem:** Dart's `NetworkInterface` gives you interface names and addresses and stops there -
no netmask. So Flutter code that needs a UDP broadcast address for device discovery guesses it the
only way available: take the first three octets, append `.255`. This is near-universal, and it is
worth checking whatever helper you currently call for a broadcast address - it very likely does
exactly this internally. The guess is right on a `/24` and silently wrong on anything **wider** -
the `/20`, `/22`, `/16` that corporate, campus, guest and mesh networks hand out. On a `/20`, a
host at `10.8.2.76` has its broadcast at `10.8.15.255`; the guessed `10.8.2.255` is an ordinary
host address in the middle of the range, so the packet is unicast to a host that does not exist and
dies. **No error, no exception, no log line** - discovery just finds nothing, which looks exactly
like an empty network. That is why this bug survives for years in a codebase, and the network gets
the blame.

**The fix:** ask the OS. The plugin reads the real netmask of every IPv4 interface - `getifaddrs`
on iOS, `java.net.NetworkInterface` with a `ConnectivityManager` fallback on Android - and derives
the directed broadcast address from it, instead of guessing.

```dart
final resolver = SSIDResolver();

// Where to send UDP discovery: real LAN interfaces only - loopback, link-local,
// VPN tunnels and cellular already filtered out.
for (final address in await resolver.broadcastAddresses()) {
  socket.send(payload, InternetAddress(address), port);
}

// Or the full picture, if you need to choose yourself.
for (final i in await resolver.fetchNetworkInterfaces()) {
  print('${i.name} ${i.ip}/${i.prefixLength} mask ${i.netmask} broadcast ${i.broadcast}');
  // en0 10.8.2.76/20 mask 255.255.240.0 broadcast 10.8.15.255
}
```

Seen on a physical Android phone on a real `/20` network:

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-4-interfaces.jpeg" alt="Interfaces" width="400"/>

One address returned. The naive guess would have been `10.8.2.255`

<img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-5-udp-proof.jpeg" alt="UDP proof" width="400"/>

Both sends succeed, including the wrong one. See below

The second screenshot is the whole point. A real UDP send to the correct broadcast `10.8.15.255`
reports `sent OK`. A send to the naive `10.8.2.255` **also** reports `sent OK`. The socket accepts
it, nothing throws, nothing logs - the packet simply leaves and reaches nobody, because on a `/20`
that address belongs to no host. There is no error to find.

Worth knowing, in decreasing order of surprise:

- **No runtime permission - nothing for the user to grant, nothing for you to add.** Reading the
  interface table has no runtime gate on either platform: Android needs `ACCESS_NETWORK_STATE` in
  the manifest, which is granted at install, never prompted, and merges in from the plugin
  automatically; iOS needs nothing - no entitlement, no capability. So the list keeps working on a
  device where Location is denied and the SSID cannot be resolved at all - and on simulators and
  emulators, unlike `resolveSSID()`. The one iOS declaration that becomes relevant is
  `NSLocalNetworkUsageDescription`, and only at the moment your app *sends* to one of those
  addresses - see [the three iOS gates](#the-three-ios-gates-told-apart) for that, and for where
  the multicast entitlement fits in.
- **Every interface, not only Wi-Fi**: ethernet, tunnels and cellular, which is what makes correct
  filtering possible rather than accidental. `NetworkInterfaceInfo` exposes `isLoopback`,
  `isLinkLocal`, `isTunnel`, `isCellular` and `isUsableLan` so you can filter differently if
  `broadcastAddresses()` is not the split you want.
- **Cellular is excluded from `broadcastAddresses()` deliberately.** iOS cellular carries a `/32`,
  where the derived broadcast equals the interface's own address; Android cellular sits on a tiny
  point-to-point subnet - a `/30` in the screenshot above (`rmnet_data9`). Either way the derived
  address reaches no discovery target; unfiltered, discovery traffic would go out over mobile data
  into nothing. Tunnels are excluded too - the production code this package grew out of carries a
  warning that on iOS an unreachable broadcast can close the socket for the sends that follow it.
- **The two platforms derive the answer in opposite directions**, and that is the best reason to
  trust the numbers: iOS counts the leading one bits of the mask the kernel reports, Android
  expands the kernel's prefix length into a mask. When an iPhone and an Android phone on the same
  `/20` print the same broadcast address, that is a real cross-check, not one implementation echoed
  twice. The arithmetic was also checked on both platforms against an independent reference
  implementation, including the high-bit prefixes where signed 32-bit shifts go wrong.

One caveat: this does **not** defeat client isolation or a separate IoT VLAN - those are
routing decisions no app can override. What it fixes is the case where the devices are reachable
and the broadcast address was simply pointing at nothing.

## What changed recently

**1.5.0** - the network interface API above, plus two fixes found by running the example app on
physical phones:

- **Android: the interface list was always empty on modern devices.**
  `NetworkInterface.getNetworkInterfaces()` returns `null` on Android builds where the Android 11
  `/proc/net` restrictions apply - observed on a Samsung running Android 15. `Collections.list(null)`
  then threw a `NullPointerException` that was caught and turned into an empty list, so a crash on
  every call looked like "this device has no network interfaces".
  `ConnectivityManager`/`LinkProperties` is now the fallback and reports the prefix length directly.
- **iOS: a failed SSID lookup blamed the wrong thing.** `NEHotspotNetwork.fetchCurrent()` returning
  `nil` was always reported as a missing Access WiFi Information entitlement, but it also returns
  `nil` with no Wi-Fi connection or on a network that withholds its name - which captive portals,
  enterprise and guest networks do. A failed lookup now reports its real cause. If you match on the
  exception's message string, adjust; the exception type is unchanged.

**1.4.0** - added the missing `ACCESS_NETWORK_STATE` permission, upgraded Kotlin to 2.1.0, improved
examples.

**1.3.0** - fixed the Android SSID resolution timeout on modern Android (API 29+) and compatibility
with newer Flutter versions.

## Related repositories

This plugin is based on my two standalone implementations, both on GitHub:
[ssid-resolver-ios](https://github.com/raoulsson/ssid-resolver-ios) and
[ssid-resolver-android](https://github.com/raoulsson/ssid-resolver-android). They are the native
proving grounds: if a value is right in the native app and wrong here, the fault is in the Dart
layer. `NetworkInterfaceResolver` is kept in lockstep between the repos; the SSID resolver classes
share their approach but have diverged in the details.

# License

Copyright 2025 Raoul Marc Schmidiger (hello@raoulsson.com)

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the “Software”),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
