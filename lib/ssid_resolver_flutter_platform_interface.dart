import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'ssid_resolver_flutter_method_channel.dart';

abstract class SsidResolverFlutterPlatform extends PlatformInterface {
  /// Constructs a SsidResolverFlutterPlatform.
  SsidResolverFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static SsidResolverFlutterPlatform _instance =
      MethodChannelSsidResolverFlutter();

  /// The default instance of [SsidResolverFlutterPlatform] to use.
  static SsidResolverFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SsidResolverFlutterPlatform] when
  /// they register themselves.
  static set instance(SsidResolverFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<String, dynamic>> checkPermissionStatus() {
    throw UnimplementedError(
        'checkPermissionStatus() has not been implemented.');
  }

  Future<Map<String, dynamic>> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  Future<String> resolveSSID() {
    throw UnimplementedError('fetchSsid() has not been implemented.');
  }
}
