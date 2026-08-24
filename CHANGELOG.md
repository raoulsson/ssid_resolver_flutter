## 1.5.1

* Documentation only, no code change. The README was rewritten around the question people actually
  arrive with - how do I read the SSID, and what permissions does that need - with the netmask and
  broadcast-address work as the secondary topic it is. The previous version made the same argument
  about `.255` guessing four times before telling anyone how to use the package.
* Deeper detail that belonged next to the code rather than in a README moved into source comments.

## 1.5.0

* **Network interface info**: `fetchNetworkInterfaces()` returns every IPv4 interface with its `name`,
  `ip`, `netmask`, `broadcast` and `prefixLength`. Dart's own `NetworkInterface` exposes addresses but
  no netmask, and without a netmask you cannot compute a broadcast address.
* **`broadcastAddresses()`**: the directed broadcast of each real LAN interface, with loopback,
  link-local and VPN tunnels filtered out. Computed from the actual netmask, so a /20 host at
  `10.8.2.77` yields `10.8.15.255` and not the `10.8.2.255` produced by the widespread
  "replace the last octet with 255" shortcut. That shortcut is only correct on a /24; on anything
  wider it is an ordinary host address and UDP sent there reaches nothing.
* Needs **no permission** on either platform: this reads the local interface table (`getifaddrs` on
  iOS, `java.net.NetworkInterface` on Android), not the WiFi identity that SSID resolution needs
  Location for. It therefore also works on the iOS Simulator and Android emulators, unlike
  `resolveSSID()`.
* Both new methods return an empty list instead of throwing when the platform cannot answer. Callers
  use this to decide where to send discovery traffic, and an exception there becomes a dead scan
  rather than a message.
* Note for anyone with their own `SsidResolverFlutterPlatform`: the new member is added with a
  default `UnimplementedError` body, so subclasses that `extends` it keep compiling untouched. A class
  that `implements` the interface instead must add `fetchNetworkInterfaces`. `extends` is the
  supported form for exactly this reason (see `plugin_platform_interface`).

## 1.4.0

* Added missing `ACCESS_NETWORK_STATE` permission to plugin and example manifests.
* Upgraded Kotlin from 1.9.0 to 2.1.0.
* Improved example for pub.dev: `main.dart` is now a self-contained example instead of a proxy.
* Renamed example classes for clarity (`SSIDMixinExample`, `SSIDHelperExample`, `DIYExample`).
* Added persistent simulator/emulator warning to all example screens and README.

## 1.3.0

* Fixed Android SSID resolution timeout on modern Android (API 29+). Replaced deprecated `WifiManager.startScan()` with synchronous `NetworkCapabilities.transportInfo` lookup, fixing 5-second timeouts on Android 16 (API 36) and other recent versions.
* Fixed `SSIDResolverMixin` compatibility with newer Flutter versions. Replaced fragile `implements WidgetsBindingObserver` with an internal observer class, fixing missing override errors (e.g. `handleStatusBarTap`).
* Upgraded `flutter_lints` from v5 to v6.

## 1.2.2

* Fixed typo in README.md


## 1.2.1

* Issues with dependencies for the Android part should be resolved now. Could not test for all cases though.

## 1.1.1

* Fixed gradle scripts on plugin level

## 1.0.12

* Removed android dependency "io.flutter:flutter_embedding_debug:1.0.0-dbec018f4d83ae4b7b97eb8c5a066c61832e12df"

## 1.0.11

* Improved discussion and depth of app documentation in README.md

## 1.0.10

* Fixed another Typo in README

## 1.0.9

* Fixed Typo in README

## 1.0.8

* Updated README

## 1.0.7

* Fixed format of CHANGELOG.md

## 1.0.6

* Fixed format of LICENSE file

## 1.0.5

* Fixed format of README.md

## 1.0.4

* Fixed urls in README.md

## 1.0.3

* Fixed urls in README.md

## 1.0.2

* Added absolute image and source file urls to README.md

## 1.0.1

* Fixed formatting
* Fixed image urls in README.md

## 1.0.0

* Initial release
* Added basic SSID resolution functionality for iOS and Android
* Examples for correct usage. All documented in the README.md file












