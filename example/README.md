# Examples for SSID Resolver Flutter Plugin

The plugin is used in the example app in the [example/lib](./lib) folder. Use the [debug_app.dart](./lib/debug_app.dart)
to fix your permissions issues. The example app demonstrates the usage of the plugin in a simple way, showing all the granted and missing permissions.
Note that only the location permissions need user consent and the other ones have to be granted in the `AndroidManifest.xml` and `Info.plist` files, as
mentioned above.

## 1. Using SSIDResolver Mixin

The easiest and fastest way to use the plugin is by applying the mixin: `SSIDResolverMixin`. This will handle the
permission requests and SSID resolution for you. Simply add the mixin to your view and implement
the `onSSIDResolved` method. Here the complete code:

```dart
    class MyClientOne extends StatefulWidget {
      const MyClientOne({super.key});
      @override
      State<MyClientOne> createState() => _MyClientOneState();
    }
    
    class _MyClientOneState extends State<MyClientOne> with SSIDResolverMixin<MyClientOne> {
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

This code will trigger the permission request dialog if needed and resolve the SSID in one step.
The source code is here: [ssidresolver_mixin_example.dart](./lib/ssidresolver_mixin_example.dart).

## 2. Using SSIDHelper

Usually the location permission is given once, after the app is downloaded and started for the first time.
Therefore, if you have multiple screens, before you need the SSID, you can request the permission on app
startup and then simply resolve the SSID later on in the code.

On a flutter screen that is shown after startup, do the initialization in the `initState` method:

```dart
    final ssidHelper = SSIDHelper();
    
    @override
    void initState() {
      super.initState();
      _ssidManager.initialize();
    }
    
    @override
    void dispose() {
      _ssidManager.dispose();
      super.dispose();
    }
```

This will trigger the permission request dialog if needed. After that, on a follow up screen, you can
do the actual resolving, which now should work on the first run, if granted:

```dart
    Future<void> _resolveSSID() async {
      final ssid = await ssidHelper.getSSID();
      setState(() => _ssid = ssid);
    }
```

These two steps are combined in the example app: [ssidhelper_example.dart](./lib/ssidhelper_example.dart).
You will notice that the SSID only resolves after you click the button for the second time.


## 3. "Do It Yourself"

This example shows how to use the plugin "hands-on". To get the permissions, the OS opens it's own
modal dialog and the later returns to the app. If you need full control over the process, you therefore need
to use the `WidgetsBindingObserver`, register your class as an observer and implement the `didChangeAppLifecycleState` method.
Have a look at the "Do It Yourself" implementation that can be found in  the example app folder
here: [do_it_yourself_example.dart](./lib/do_it_yourself_example.dart).

Below is part of the source code. In the case permissions are not yet granted, the OS will
take over and show the permission dialog. Thus, when the app is resumed, the observer will check
the permission status and continue the flow.

```dart
class _MyClientThreeState extends State<MyClientThree> with WidgetsBindingObserver {
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

If you need to know the SSID on load, you can call `_getSSID()` in the `initState` method.
