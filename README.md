# ssid_resolver_flutter - "Get my Wi-Fi Name"

A flutter plugin to resolve the SSID of the connected wireless LAN, or simply: "Get my Wi-Fi Name".

[![Pub Version](https://img.shields.io/pub/v/ssid_resolver_flutter?style=flat-square)](https://pub.dev/packages/ssid_resolver_flutter)

**Flutter UDP device discovery broken on your network? Your broadcast address is probably wrong.**
Dart's `NetworkInterface` exposes no **netmask**, so nearly every Flutter app computes its UDP
**broadcast address** as "first three octets + `.255`". That is correct only on a `/24` and silently
wrong on `/20`, `/22`, `/16` - the subnets corporate, campus, guest and mesh networks hand out. The
send succeeds, nothing throws, and the packet reaches nobody. This package returns the **real netmask
and the correct broadcast address** on iOS and Android, with **no runtime permission** - nothing for
the user to grant, and nothing to add on Android.

> [!WARNING]
> **The permissions live in YOUR app, not in this package.** A Flutter plugin cannot inject
> `Info.plist` keys or entitlements. On **iOS** your app must declare
> `NSLocationWhenInUseUsageDescription` and the Access WiFi Information capability for SSID
> resolution, and `NSLocalNetworkUsageDescription` if you send UDP to the broadcast address - without
> that last one the system prompt appears with no explanation at all. On **Android** you add nothing;
> the plugin's manifest merges into yours.
> See [What your app has to declare](#what-your-app-has-to-declare).

### Setup, in one paste

**Android:** nothing. Skip to the usage below.

**iOS:** add to `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to read the name of the Wi-Fi network you are connected to.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Used to find your devices on the local network.</string>
```

and to `ios/Runner/Runner.entitlements` (only for SSID resolution, not for the netmask API)

```xml
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

Then in Xcode add the **Access WiFi Information** capability to the Runner target, so the entitlement
is provisioned. It is a standard capability on a paid Apple Developer team and takes a minute; a free
personal team cannot provision it.

**Usage:**

```dart
final resolver = SSIDResolver();

// Correct broadcast addresses. No runtime permission, no setup, works on both platforms.
for (final address in await resolver.broadcastAddresses()) {
  socket.send(payload, InternetAddress(address), port);
}

// SSID. This is the part that needs everything above.
final ssid = await resolver.resolveSSID();
```

Nothing in the netmask and broadcast API needs any of the iOS setup - it is only SSID resolution that
does. If all you want is a correct broadcast address, add the package and call it.

**When it does not work, run the example app.** Permission setup is the blocker with this kind of
plugin, and the example exists to end the guessing: it lists **Granted Permissions** and **Denied
Permissions** by name, and when a lookup fails it names exactly which one is missing rather than
saying "failed". Run it on the device that is giving you trouble and compare its lists with yours -
that is usually a two-minute answer to a problem that otherwise costs an evening. The screenshots
below are that flow, end to end, on a physical phone.


> [!WARNING]
> SSID resolution (`resolveSSID()`) only works on **physical devices** — it is not supported on iOS Simulators or Android Emulators. The network interface API added in 1.5.0 (below) also works on simulators and emulators.

> [!IMPORTANT]
> **1.5.0 - the delta: device discovery now works on networks that are not `/24`.**
>
> One caveat the summary above leaves out: this does **not** defeat client isolation or a separate
> IoT VLAN - those are routing decisions no app can override. What it fixes is the case where the
> devices are reachable and the broadcast address was simply pointing at nothing.
> [The details, with the numbers](#the-netmask-problem-in-detail).

---

> [!IMPORTANT]
> **Version 1.4.0**: Added missing `ACCESS_NETWORK_STATE` permission, upgraded **Kotlin to 2.1.0**, and improved examples.

---

> [!IMPORTANT]
> **Version 1.3.0**: Fixed Android SSID resolution timeout on modern Android (API 29+) and fixed compatibility with newer Flutter versions.

---

> [!TIP]
> **TLDR**: Add the mixin class `SSIDResolverMixin` to your view and implement the `onSSIDChanged` method. This will trigger the permission request dialog if needed and resolve the SSID in one step.
See below: [Using SSIDResolver Mixin](#1-using-ssidresolver-mixin).

---

### Network interfaces, netmask and broadcast

In plain words: it reads the subnet mask of every network interface from the OS and derives the
directed broadcast address from it, instead of guessing.

```dart
final resolver = SSIDResolver();

// Where to send UDP discovery: real LAN interfaces only, loopback, link-local,
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

`NetworkInterfaceInfo` also exposes `isLoopback`, `isLinkLocal`, `isTunnel`, `isCellular` and
`isUsableLan` so you can filter differently if `broadcastAddresses()` is not the split you want.
Sending to a tunnel's broadcast address is worth avoiding specifically: the production code this
package grew out of carries a comment warning that on iOS an unreachable broadcast can close the
socket for the sends that follow it - inherited from that code, not re-measured here, but cheap to
respect.

---

Over the years, the number of permissions required to access the wireless network name has increased
in both iOS and Android, and getting them right is the entire problem this plugin deals with: a set
of static declarations in your app's config files, plus the user's consent to Location, which both
systems tie to Wi-Fi identity.

The contained example app: [debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart) 
is a perfect starting point, to figure out any permission issues you might have. It will show you exactly what you are missing.

The example app in action is further down: [The example app, on a real phone](#the-example-app-on-a-real-phone).

This plugin is based on my two standalone implementations for [iOS](https://github.com/raoulsson/ssid-resolver-ios)
and [Android](https://github.com/raoulsson/ssid-resolver-android), both available on GitHub.

### The example app, on a real phone

Captured on a physical Android device on a `/20` network. This is the permission diagnostic
described above: the app names every granted and denied permission, so you can see at a glance
what your own app is missing. Run `example/` on a phone to reproduce it.

|                                                                                                                        |                                                                                                                        |
|------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-1-home.jpeg" alt="Example home" width="400"/><br />The four SSID examples, with the 1.5.0 interface harness at the bottom | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-2-ssid-helper.jpeg" alt="SSID resolved" width="400"/><br />`SSIDHelper` resolving `ZH1082Guest` |
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-3-mixin.jpeg" alt="Mixin example" width="400"/><br />`SSIDResolverMixin` auto-resolving on load | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-4-interfaces.jpeg" alt="Interfaces" width="400"/><br />`broadcastAddresses()` returns one address; the naive guess would have been `10.8.2.255` |
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/example-5-udp-proof.jpeg" alt="UDP proof" width="400"/><br />**Both sends succeed** - see below | |

**The last screenshot is the whole point.** A real UDP send to the correct broadcast `10.8.15.255`
reports `sent OK`. A send to the naive `10.8.2.255` **also** reports `sent OK`. The socket accepts it,
nothing throws, nothing logs - the packet simply leaves and reaches nobody, because on a `/20` that
address belongs to no host. That is why this bug survives for years in a codebase: there is no error
to find. Discovery quietly returns nothing and the network gets the blame.

The interface list also shows why filtering is correctness rather than tidiness: `wlan0` is tagged
USABLE LAN, `lo` loopback, and `rmnet_data9` cellular on a `/30`. Broadcasting to the cellular
interface would push discovery traffic over mobile data to reach nothing at all.

## The netmask problem in detail

**What you could not do:** get a netmask. Dart's `NetworkInterface` gives you interface names and
addresses and stops there. So code that needs a UDP broadcast address guesses it the only way
available - take the first three octets, append `.255`. This is near-universal, and it is worth
checking whatever you currently call for a broadcast address: the helper you are using very likely
does exactly this internally.

That guess is right on a `/24` and silently wrong on anything wider. On a `/20`, a host at `10.8.2.76` has
its broadcast at `10.8.15.255`; the guessed `10.8.2.255` is an ordinary host address in the middle
of the range, so the packet is unicast to a host that does not exist and dies. **No error, no
exception, no log line** - discovery just finds nothing, which looks exactly like an empty network.
There is no escape hatch either: the limited broadcast `255.255.255.255` came back `EADDRNOTAVAIL`
on Darwin when tried during this work, bound to `0.0.0.0` and to the interface address alike.

**What you can do now:** ask the OS. `fetchNetworkInterfaces()` returns every IPv4 interface with
its real `netmask`, `prefixLength` and computed `broadcast` - `getifaddrs` on iOS,
`java.net.NetworkInterface` on Android. `broadcastAddresses()` returns just the ones worth sending
to.

**The two platforms derive the answer in opposite directions**, and that is the best reason to trust
the numbers: iOS counts the leading one bits of the mask the kernel reports, Android expands the
kernel's prefix length into a mask. When an iPhone and an Android phone on the same `/20` print the
same broadcast address, that is a real cross-check, not one implementation echoed twice. The
arithmetic was also checked on both platforms against an independent reference implementation during
development, including the high-bit prefixes where signed 32-bit shifts go wrong.

- **No runtime permission - nothing for the user to grant.** SSID resolution needs Location; when it
  is denied, `resolveSSID()` throws and the mixin reports `"Unknown"`. Reading the interface table
  has no such gate on either platform (Android's install-time `ACCESS_NETWORK_STATE`, covered below,
  is the one declaration involved), so it keeps working on a device where Location is denied - and
  on simulators and emulators, unlike `resolveSSID()`.
- **Every interface, not only Wi-Fi**: ethernet, tunnels and cellular, which is what makes correct
  filtering possible rather than accidental.
- **Cellular is excluded from `broadcastAddresses()` deliberately.** iOS cellular carries a `/32`,
  where the derived broadcast equals the interface's own address; Android cellular sits on a tiny
  point-to-point subnet - a `/30` in the screenshot above. Either way the derived address reaches no
  discovery target. Unfiltered, the list would send discovery over mobile data into nothing - the
  same silent hole, one interface over.

## What your app has to declare

The netmask and broadcast API needs **no runtime permission** on either platform - nothing is prompted
and nothing can be denied. What it does need differs by platform, and only one side asks anything of
you:

**Android: nothing.** The plugin's own `AndroidManifest.xml` declares `ACCESS_NETWORK_STATE` (and the
Wi-Fi and location permissions used by SSID resolution), and Android's manifest merger folds them into
your app automatically. `ACCESS_NETWORK_STATE` is a normal permission - granted at install, never
prompted - and it is what `ConnectivityManager` requires on devices where
`NetworkInterface.getNetworkInterfaces()` returns null.

**iOS: you must add these yourself.** A plugin cannot inject `Info.plist` keys or entitlements, so
these live in your app or nothing works:

| What | Needed for |
|---|---|
| `NSLocationWhenInUseUsageDescription` | SSID resolution (iOS ties Wi-Fi identity to Location) |
| Access WiFi Information capability | SSID resolution - a standard capability on a paid team |
| `NSLocalNetworkUsageDescription` | **only if you send UDP on the LAN**, which is the point of the broadcast address |

`fetchNetworkInterfaces()` and `broadcastAddresses()` need none of the three: reading the interface
table is not privileged on either platform, which is why the list still works on a device where the
user denied everything and the SSID cannot be resolved at all. The moment you *send* to one of those
addresses on iOS, the system shows the Local Network prompt - without
`NSLocalNetworkUsageDescription` it appears with no explanation, which App Review notices.

## Fixed in 1.5.0

Found by running the example app on physical phones, not by reading the code.

- **Android: the interface list was always empty on modern devices.**
  `NetworkInterface.getNetworkInterfaces()` returns `null` on Android builds where the Android 11
  `/proc/net` restrictions apply - observed on a Samsung running Android 15, where it returns null
  rather than throwing. `Collections.list(null)` then throws `NullPointerException`, which was caught
  and turned into an empty list, so a crash on every call looked like "this device has no network
  interfaces". `ConnectivityManager`/`LinkProperties` is now the fallback and reports the prefix
  length directly.
- **iOS: a failed SSID lookup blamed the wrong thing.** `NEHotspotNetwork.fetchCurrent()` returning
  `nil` was reported as a missing Access WiFi Information entitlement. It returns `nil` for at least
  three reasons - no entitlement, no Wi-Fi connection, or a network that withholds its name, which
  captive portals, enterprise and guest networks do - so on a guest network it sent you looking for an
  entitlement you already had. The pre-flight "entitlement check" was itself a `fetchCurrent()` call,
  so it could only ever reach that one conclusion; it is gone rather than patched.

**Behaviour change worth knowing:** a failed iOS lookup now reports its real cause. What a Dart
caller catches is unchanged - an `Exception` whose message carries the native error text - but the
text itself is different: where every failure used to claim a missing WiFi permission, a lookup with
no Wi-Fi connection or on a network that withholds its name now says so. If you match on the message
string, adjust; the exception type stays the same.

## Android SSID Resolution

On Android, the plugin resolves the SSID using a three-tier approach:
1. **`NetworkCapabilities.transportInfo`** (API 29+) — synchronous, instant result
2. **`WifiManager.connectionInfo`** — fallback for older devices
3. **Async `registerNetworkCallback`** — last resort with 5-second timeout

The plugin does **not** use `WifiManager.startScan()`, which is deprecated and throttled/broken on modern Android.

# Usage and Configuration

Note on failure behaviour, because the layers differ. `resolveSSID()` throws an `Exception` whose
message names the cause when permission is missing (both platforms) or when the iOS lookup fails for
another reason; on Android a lookup that runs with permission granted but cannot get a name resolves
to the string `"Unknown"`. The convenience layers absorb the exception case: `SSIDResolverMixin`
reports `"Unknown"` through `onSSIDChanged` when permission is denied, and `SSIDHelper.getSSID()`
returns `null` then.

## SSID Resolution Flow

The SSID resolver provides three key methods:

- `resolveSSID()`: Returns the connected WiFi SSID; throws with the cause in the message when
  permission is missing, and on Android reports `"Unknown"` when a permitted lookup gets no name
- `checkPermissionStatus()`: Verifies required permissions
- `requestPermission()`: Handles permission requests

### Typical Usage Flow
1. Check permission status
2. Request permissions if needed
3. Resolve SSID

Note: On iOS, WiFi access requires location permissions, even with the Xcode WiFi capability configured.

# Usage

The plugin is available on [pub.dev](https://pub.dev/packages/ssid_resolver_flutter). To use the plugin 
in your project, add `ssid_resolver_flutter` as a dependency in your pubspec.yaml file:

```yaml
  ssid_resolver_flutter: ^x.y.z
```

In the folder [example/lib](https://github.com/raoulsson/ssid_resolver_flutter/tree/master/example/lib) you can 
find example apps that use this plugin, see below for a more detailed discussion. The important configuration 
parts for iOS and Android are listed below.

## iOS Permission Configuration

Needs these permissions in the `Info.plist` file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to determine the WiFi information.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location to determine the WiFi information.</string>
```

The `com.apple.developer.networking.wifi-info` entitlement belongs in `Runner.entitlements`, not in
`Info.plist` - Xcode writes it there for you: open `<project_root>/ios/Runner/Runner.xcodeproj` in
Xcode, go to "Signing & Capabilities" and add the "Access WiFi Information" capability.

| Add WiFi Capability 1                                                                                                                                        | Add WiFi Capability 2                                                                                                                                        |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/add-wifi-capability-1.png" alt="Add WiFi Capability 1" width="400"/> | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res/add-wifi-capability-2.png" alt="Add WiFi Capability 2" width="400"/> |      

This should produce the file `<project_root>/ios/Runner/Runner.entitlements` with this content:

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

## Android Permission Configuration

For Android, the `AndroidManifest.xml` file needs these permissions: 

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

And also the following queries:

```xml
<queries>
    <package android:name="com.google.android.gms" />
    <package android:name="com.android.settings" />
</queries>
```

# Examples

All examples are available in the [example/lib](https://github.com/raoulsson/ssid_resolver_flutter/tree/master/example/lib) folder. 
Use the [debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart)
to fix your permissions issues. The example app demonstrates the usage of the plugin in a simple way, 
showing all the granted and missing permissions. 

Note that only the location permissions need user consent and the other ones have to be granted in the 
`AndroidManifest.xml` for Android, and `Info.plist` and `Runner.entitlements` files in the case of iOS, 
as mentioned above. It's important to note that the permissions are given by the client code of this 
plugin, not the plugin itself. 

Just follow the examples and the permission files of the "example app", 
[here for Android](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/android/app/src/main/AndroidManifest.xml)
and [here](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Info.plist) 
and [here for iOS](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Runner.entitlements).

## 1. Using SSIDResolver Mixin

Add the mixin class `SSIDResolverMixin` to your view and implement the `onSSIDChanged` method.

```dart
  class _SSIDMixinExampleState extends State<SSIDMixinExample> with SSIDResolverMixin<SSIDMixinExample> {
        ...
        @override
        void onSSIDChanged(String ssid) {
          ...
        }
        ...
  }
```

This will trigger the permission request dialog if needed and resolve the SSID in one step.

Here is the full client code that takes full advantage of the plugin for Wi-Fi SSID resolution:

```dart
    class SSIDMixinExample extends StatefulWidget {
      const SSIDMixinExample({super.key});
      @override
      State<SSIDMixinExample> createState() => _SSIDMixinExampleState();
    }
    
    class _SSIDMixinExampleState extends State<SSIDMixinExample> with SSIDResolverMixin<SSIDMixinExample> {
      String _ssid = '';
    
      @override
      void onSSIDChanged(String ssid) {
        setState(() => 
          _ssid = ssid
        );
      }
    
      @override
      Widget build(BuildContext context) {
        return Center(
          child: Text(_ssid),
        );
      }
    }
```

The source code is here: [ssidresolver_mixin_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/ssidresolver_mixin_example.dart).
If you need more fine-grained control, on when the SSID is resolved or when the permission dialog should 
be shown, look below at the "Do It Yourself" example.

## 2. Using SSIDHelper

Once the user gives the "location permission", the SSID can be resolved. And because the "location 
permission" step only has to happen once in your app's lifetime, why bother and make things complicated?
If there are other screens that appear in your app before you trigger the SSID resolution, you can 
use the `SSIDHelper` class to do the initialization and permission request way before you actually 
need the SSID.

This greatly simplifies the flow of your app, as you don't need to handle the "re-entry" event, after 
the phone operating system is handing you back the control and the result of the permission dialog.

Use the `SSIDHelper` class to do the initialization and permission request (or do the same that it 
does internally) after your app starts up. The call to `_ssidHelper.initialize()` will trigger the 
permission request dialog if needed.

On subsequent screens, you can then call `getSSID()` to get the SSID without having to worry about 
the permission dialog.

```dart
    final _ssidHelper = SSIDHelper();
    
    @override
    void initState() {
      super.initState();
      _ssidHelper.initialize();
    }
```

Don't forget to call `_ssidHelper.dispose();` in your `dispose` method.

Now, on the screen where you need the SSID, you can simply call `_ssidHelper.getSSID()`. It returns
`Future<String?>` and yields `null` while the permission is missing, so decide what your UI shows
for that case:

```dart
    Future<void> _resolveSSID() async {
      final ssid = await _ssidHelper.getSSID();
      setState(() => _ssid = ssid ?? 'Permission missing');
    }
```

These two steps are combined in the example app: [ssidhelper_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/ssidhelper_example.dart).
You will notice that the SSID only resolves after you click the button for the second time.

## 3. "Do It Yourself"

This example shows how to use the plugin "hands-on". To get the permissions, the OS opens its own 
modal dialog and later returns to the app. If you need full control over the process, you therefore need
to use the `WidgetsBindingObserver`, register your class as an observer and implement the `didChangeAppLifecycleState` method.
Have a look at the "Do It Yourself" implementation that can be found in the example app folder 
here: [do_it_yourself_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/do_it_yourself_example.dart).

Below is part of the source code. In the case permissions are not yet granted, the OS will 
take over and show the permission dialog. Thus, when the app is resumed, the observer will check 
the permission status and continue the flow.

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          ...
          // SSID Result Display
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
          ...
    );
  }
}
```

# Troubleshooting

If you run into permissions issues, make sure to check the permissions in the `AndroidManifest.xml` 
and `Info.plist` files as described above and try running the app on a real device instead of the emulator. 
iOS will not give you an SSID on the simulator. 

Also run the example app: [debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart) and check the output. 
That should show which permissions are missing.

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
