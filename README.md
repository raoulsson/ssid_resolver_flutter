# ssid_resolver_flutter - "Get my Wi-Fi Name"

A flutter plugin to resolve the SSID of the connected wireless LAN, or simply: "Get my Wi-Fi Name".

[![Pub Version](https://img.shields.io/pub/v/ssid_resolver_flutter?style=flat-square)](https://pub.dev/packages/ssid_resolver_flutter)

> [!WARNING]
> SSID resolution (`resolveSSID()`) only works on **physical devices** — it is not supported on iOS Simulators or Android Emulators. The network interface API added in 1.5.0 (below) works everywhere.

> [!IMPORTANT]
> **1.5.0 - the delta: device discovery now works on networks that are not `/24`.**
>
> You can read the **real netmask** and get a broadcast address derived from it, on both platforms,
> with no permission of any kind. Before this, every broadcast address in the Dart ecosystem was a
> guess - first three octets plus `.255` - because `NetworkInterface` never exposed a netmask.
>
> That guess is correct on a `/24` and silently wrong on a `/20`, `/22` or `/16`, which is what
> corporate, campus, guest and mesh networks routinely hand out. Wrong in the worst way: the send
> succeeds, nothing throws, and the packet reaches nobody.
>
> It does **not** defeat client isolation or a separate IoT VLAN - those are routing decisions no app
> can override. What it fixes is the case where the devices are reachable and the broadcast address
> was simply pointing at nothing. [The details, with the numbers](#the-netmask-problem-in-detail).

---

> [!IMPORTANT]
> **Version 1.4.0**: Added missing `ACCESS_NETWORK_STATE` permission, upgraded **Kotlin to 2.1.0**, and improved examples.

---

> [!IMPORTANT]
> **Version 1.3.0**: Fixed Android SSID resolution timeout on modern Android (API 29+) and fixed compatibility with newer Flutter versions.

---

> [!TIP]
> **TLDR**: Add the mixin class `SSIDResolverMixin` to your view and implement the `onSSIDResolved` method. This will trigger the permission request dialog if needed and resolve the SSID in one step.
See below: [Using SSIDResolver Mixin](#1-using-ssidresolver-mixin).

---

### Network interfaces, netmask and broadcast

```dart
final resolver = SSIDResolver();

// Where to send UDP discovery: real LAN interfaces only, loopback, link-local
// and VPN tunnels already filtered out.
for (final address in await resolver.broadcastAddresses()) {
  socket.send(payload, InternetAddress(address), port);
}

// Or the full picture, if you need to choose yourself.
for (final i in await resolver.fetchNetworkInterfaces()) {
  print('${i.name} ${i.ip}/${i.prefixLength} mask ${i.netmask} broadcast ${i.broadcast}');
  // en0 10.8.2.77/20 mask 255.255.240.0 broadcast 10.8.15.255
}
```

`NetworkInterfaceInfo` also exposes `isLoopback`, `isLinkLocal`, `isTunnel` and `isUsableLan` so you
can filter differently if `broadcastAddresses()` is not the split you want. Sending to a tunnel's
broadcast address is worth avoiding specifically: on iOS an unreachable broadcast can close the socket
for the sends that follow it.

---

Over the years, the number of permissions required to access the wireless network name has increased 
in both the iOS and Android Operating System and this implementation was tested successfully on both 
systems in early 2025. I couldn't get existing plugins to work or maybe failed to use them properly, 
so I created this one.

To resolve the name, the SSID of the Wi-Fi, your phone is connected to, you have to get a bunch of 
permission settings right that have to be statically set in your code for this plugin to work. Next 
you need the users consent to give you "Location Permissions".

The contained example app: [debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart) 
is a perfect starting point, to figure out any permission issues you might have. It will show you exactly what you are missing.

Below you can see the example app in action. On the left side you see the Android app and on the right side the iOS app.

| Android                                                                                                                                                                                                              | iOS                                                                                                                                                                                                              |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_android_1.jpeg" alt="Not all permissions granted" width="400"/><br />Not all permissions granted       | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_ios_1.jpeg" alt="Not all permissions granted" width="400"/><br />Not all permissions granted       |
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_android_2.jpeg" alt="OS dialog to grant permissions" width="400"/><br />OS dialog to grant permissions | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_ios_2.jpeg" alt="OS dialog to grant permissions" width="400"/><br />OS dialog to grant permissions |
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_android_3.jpeg" alt="All permissions granted" width="400"/><br />All permissions granted               | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_ios_3.jpeg" alt="All permissions granted" width="400"/><br />All permissions granted               |
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_android_4.jpeg" alt="Network SSID resolved" width="400"/><br />Network SSID resolved                   | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//ssid_resolver_flutter_ios_4.jpeg" alt="Network SSID resolved" width="400"/><br />Network SSID resolved                   |

This plugin is based on my two standalone implementations for [iOS](https://github.com/raoulsson/ssid-resolver-ios)
and [Android](https://github.com/raoulsson/ssid-resolver-android), both available on GitHub.

### The example app, on a real phone

Captured on a physical Android device on a `/20` network. Run `example/` on a phone to reproduce it.

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

That guess is right on a `/24` and wrong on everything else. On a `/20`, a host at `10.8.2.77` has
its broadcast at `10.8.15.255`; the guessed `10.8.2.255` is an ordinary host address in the middle
of the range, so the packet is unicast to a host that does not exist and dies. **No error, no
exception, no log line** - discovery just finds nothing, which looks exactly like an empty network.
There is no escape hatch either: the limited broadcast `255.255.255.255` returns `EADDRNOTAVAIL`
on Darwin, bound to `0.0.0.0` or to the interface address alike.

**What you can do now:** ask the OS. `fetchNetworkInterfaces()` returns every IPv4 interface with
its real `netmask`, `prefixLength` and computed `broadcast` - `getifaddrs` on iOS,
`java.net.NetworkInterface` on Android. `broadcastAddresses()` returns just the ones worth sending
to.

- **No permission required.** SSID resolution needs Location and returns "Unknown" when the user
  denies it. The interface table needs nothing, so this keeps working on a device where Location is
  denied - and on simulators and emulators, unlike `resolveSSID()`.
- **Every interface, not only Wi-Fi**: ethernet, tunnels and cellular, which is what makes correct
  filtering possible rather than accidental.
- **Cellular is excluded from `broadcastAddresses()` deliberately.** iOS cellular carries a `/32`,
  and for a `/32` the derived broadcast equals the interface's own address. Unfiltered, the list
  would hand you your own phone and send discovery over mobile data into nothing - the same silent
  hole, one interface over.

The two platforms derive the answer in opposite directions - iOS counts the leading one bits of the
mask the kernel reports, Android builds the mask from the kernel's prefix length - so their
agreement is a real cross-check. Verified against Python's `ipaddress` across every prefix `/0` to
`/32` for six host addresses, including the high-bit cases where signed 32-bit shifts go wrong.

## Android SSID Resolution

On Android, the plugin resolves the SSID using a three-tier approach:
1. **`NetworkCapabilities.transportInfo`** (API 29+) — synchronous, instant result
2. **`WifiManager.connectionInfo`** — fallback for older devices
3. **Async `registerNetworkCallback`** — last resort with 5-second timeout

The plugin does **not** use `WifiManager.startScan()`, which is deprecated and throttled/broken on modern Android.

# Usage and Configuration

Note: When no SSID is found, the String "Unknown" is returned (also always the case on iOS simulator).

## SSID Resolution Flow

The SSID resolver provides three key methods:

- `resolveSSID()`: Returns the connected WiFi SSID or 'Unknown'
- `checkPermissionStatus()`: Verifies required permissions
- `requestPermission()`: Handles permission requests

### Typical Usage Flow
1. Check permission status
2. Request permissions if needed
3. Resolve SSID

Note: On iOS, WiFi access requires location permissions, even with XCode WiFi capability configured.

# Usage

The plugin is available on [pub.dev](https://pub.dev/packages/ssid_resolver_flutter). To use the plugin 
in your project, add `ssid_resolver_flutter` as a dependency in your pubspec.yaml file:

```yaml
  ssid_resolver_flutter: ^x.y.z
```

In the folder [example/lib](https://github.com/raoulsson/ssid_resolver_flutter/tree/master/example/lib) you can 
find examples app that use this plugin, see below for a more detailed discussion. The important configuration 
parts for iOS and Android are listed below.

## iOS Permission Configuration

Needs these permissions in the `Info.plist` file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location to determine the WiFi information.</string>
<key>NSLocationUsageDescription</key>
<string>This app needs access to location to determine the WiFi information.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location to determine the WiFi information.</string>
<key>com.apple.developer.networking.wifi-info</key>
<true/>
```

And also the "Access WiFi Information". Either open `<project_root>/ios/Runner/Runner.xcodeproj` in XCode 
and go to "Signing & Capabilities". Add the "Access WiFi Information" capability.

| Add WiFi Capability 1                                                                                                                                        | Add WiFi Capability 2                                                                                                                                        |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//add-wifi-capability-1.png" alt="Add WiFi Capability 1" width="400"/> | <img src="https://raw.githubusercontent.com/raoulsson/ssid_resolver_flutter/master/res//add-wifi-capability-2.png" alt="Add WiFi Capability 2" width="400"/> |      

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
as mentioned above. It's important to note, that the permissions are given by the client code of this 
plugin, not the plugin itself. 

Just follow the examples and the permission files of the "example app", 
[here for Android](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/android/app/src/main/AndroidManifest.xml)
and [here](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Info.plist) 
and [here for iOS](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/ios/Runner/Runner.entitlements).

## 1. Using SSIDResolver Mixin

Add the mixin class `SSIDResolverMixin` to your view and implement the `onSSIDResolved` method.

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
permission" step only has to happen once in your apps lifetime, why bother and make things complicated?
If there are other screens that appear in your app before you trigger the SSID resolution, you can 
use the `SSIDHelper` class to do the initialization and permission request way before you actually 
need the SSID.

This greatly simplifies the flow of your app, as you don't need to handle the "re-entry" event, after 
the phone operating system is handing you back the control and the result of the permission dialog.

Use the `SSIDHelper` class to do the initialization and permission request (or do the same that it 
does internally) after your app starts up. The call to `_ssidManager.initialize()` will trigger the 
permission request dialog if needed.

On subsequent screens, you can then call `getSSID()` to get the SSID without having to worry about 
the permission dialog.

```dart
    final ssidHelper = SSIDHelper();
    
    @override
    void initState() {
      super.initState();
      _ssidManager.initialize();
    }
```

Don't forget to call `_ssidManager.dispose();` in your `dispose` method.

Now, on the screen where you need the SSID, you can simply call `_ssidManager.getSSID()`:

```dart
    Future<void> _resolveSSID() async {
      final ssid = await _ssidManager.getSSID();
      setState(() => _ssid = ssid);
    }
```

These two steps are combined in the example app: [ssidhelper_example.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/ssidhelper_example.dart).
You will notice that the SSID only resolves after you click the button for the second time.

## 3. "Do It Yourself"

This example shows how to use the plugin "hands-on". To get the permissions, the OS opens it's own 
modal dialog and the later returns to the app. If you need full control over the process, you therefore need
to use the `WidgetsBindingObserver`, register your class as an observer and implement the `didChangeAppLifecycleState` method.
Have a look at the "Do It Yourself" implementation that can be found in  the example app folder 
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
iOS will not give you a SSID on the simulator. 

Also run the example app: [debug_app.dart](https://github.com/raoulsson/ssid_resolver_flutter/blob/master/example/lib/debug_app.dart) and check the output. 
That should show which permissions are missing.

I hope this helps.

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
