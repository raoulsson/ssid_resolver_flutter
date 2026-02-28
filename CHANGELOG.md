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












