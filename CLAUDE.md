# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`ssid_resolver_flutter` is a Flutter plugin (v1.4.0) that resolves the connected WiFi SSID on iOS and Android with full permission handling. Published at https://github.com/raoulsson/ssid_resolver_flutter.

## Common Commands

```bash
# Dependencies
flutter pub get

# Run all Dart tests
flutter test

# Run a single test file
flutter test test/ssid_resolver_flutter_test.dart

# Static analysis
flutter analyze

# Run example app (from example/ directory)
cd example && flutter run
```

Android-specific (from `android/` or `example/android/`):
```bash
./gradlew test          # Kotlin unit tests
./gradlew build         # Build plugin
```

## Architecture

This is a **Flutter platform plugin** using Method Channels. The method channel name is `'ssid_resolver_flutter'`.

### Dart Layer (`lib/`)

Three public API surfaces for consumers:
- **`SSIDResolver`** (`ssid_resolver_flutter.dart`) — Core API with `resolveSSID()`, `checkPermissionStatus()`, `requestPermission()`
- **`SSIDResolverMixin`** (`ssid_resolver_mixin.dart`) — Mixin for StatefulWidget States; auto-handles permissions and lifecycle, calls `onSSIDChanged(String ssid)` callback
- **`SSIDHelper`** (`ssid_helper.dart`) — Standalone helper class using `WidgetsBindingObserver` for simpler integration

Supporting classes:
- **`PermissionStatus`** (`permission_status.dart`) — Data class with `isGranted`/`isDenied`/`hasError` getters; constructed via `PermissionStatus.fromMap()`
- **`SsidResolverFlutterPlatform`** (`ssid_resolver_flutter_platform_interface.dart`) — Abstract platform interface (singleton with token verification)
- **`MethodChannelSsidResolverFlutter`** (`ssid_resolver_flutter_method_channel.dart`) — Method channel implementation; includes `_convertToStringDynamicMap()` helper for type-unsafe platform maps

### Method Channel Protocol

Four methods cross the platform boundary:

| Method | Returns |
|---|---|
| `getPlatformVersion` | `String` (e.g., "iOS 17.0") |
| `checkPermissionStatus` | `Map` with `status`, `grantedPermissions`, `deniedPermissions`, `errorMessage` |
| `requestPermission` | Same Map structure as above |
| `fetchSsid` | `String` (SSID name or "Unknown") |

### iOS Native (`ios/Classes/`)

- **`SsidResolverFlutterPlugin.swift`** — Plugin entry point, routes method channel calls
- **`CoreSSIDResolver.swift`** — Uses `CoreLocation` (CLLocationManager) + `NetworkExtension` (NEHotspotNetwork) to resolve SSID
- Requires iOS 15.0+, Swift 5.0
- Needs "Access WiFi Information" capability and location usage descriptions in Info.plist

### Android Native (`android/src/main/kotlin/.../`)

- **`SsidResolverFlutterPlugin.kt`** — Plugin entry point; implements `FlutterPlugin`, `ActivityAware`, `RequestPermissionsResultListener`; uses Kotlin coroutines for async
- **`CoreSSIDResolver.kt`** — Three-tier SSID resolution: (1) `NetworkCapabilities.transportInfo` synchronous lookup (API 29+), (2) `WifiManager.connectionInfo` fallback, (3) async `registerNetworkCallback` as last resort with 5s timeout. Does **not** use `WifiManager.startScan()` (deprecated/broken on modern Android).
- **`PermissionHandler.kt`** — Manages 6 required permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`
- Targets SDK 34, minimum SDK 21, Java 17 compatibility

### Key Patterns

- **Permission → SSID flow**: Check permissions → request if needed → handle lifecycle resume (user returns from settings) → resolve SSID
- **Lifecycle observation**: `SSIDHelper` uses `WidgetsBindingObserver` directly. `SSIDResolverMixin` delegates to an internal `_SSIDResolverLifecycleObserver` class (using `with WidgetsBindingObserver`) to avoid breaking when Flutter adds new observer methods.
- **Async patterns differ by platform**: Dart uses Futures, iOS uses completion handlers, Android uses Kotlin coroutines
- Custom exceptions: `MissingPermissionException` on both platforms

## Environment Requirements

- Dart SDK >=3.0.0 <4.0.0, Flutter >=3.0.0
- iOS 15.0+
- Android minSdk 21, compileSdk/targetSdk 34, Kotlin 2.1.0
- Linting: `flutter_lints` v6 (no custom rules in `analysis_options.yaml`)
