import Flutter
import UIKit
import CoreLocation
import NetworkExtension

public class SsidResolverFlutterPlugin: NSObject, FlutterPlugin {
    private let coreResolver = CoreSSIDResolver()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ssid_resolver_flutter", binaryMessenger: registrar.messenger())
        let instance = SsidResolverFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "checkPermissionStatus":
            checkPermissionStatus(result: result)
        case "requestPermission":
            requestPermission(result: result)
        case "fetchSsid":
            fetchSsid(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkPermissionStatus(result: @escaping FlutterResult) {
        self.coreResolver.checkAccessWiFiEntitlement { hasWiFi in
            let locationStatus = self.coreResolver.locationManager.authorizationStatus

            var grantedPermissions: [String] = []
            var deniedPermissions: [String] = []

            // Check location permission
            if [.authorizedWhenInUse, .authorizedAlways].contains(locationStatus) {
                grantedPermissions.append("Location")
            } else {
                deniedPermissions.append("Location")
            }

            // Check WiFi access
            if hasWiFi {
                grantedPermissions.append("WiFi")
            } else {
                deniedPermissions.append("WiFi")
            }

            // Determine status
            var status = "Unknown Permission Status"
            if deniedPermissions.isEmpty {
                status = "All permissions granted"
            } else if grantedPermissions.isEmpty {
                status = "All permissions denied"
            } else {
                status = "Some permissions denied"
            }

            result([
                "status": status,
                "grantedPermissions": grantedPermissions,
                "deniedPermissions": deniedPermissions,
                "errorMessage": NSNull()
            ])
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        coreResolver.requestLocationPermission { [weak self] permissionResult in
            guard let self = self else { return }

            switch permissionResult {
            case .success:
                self.checkPermissionStatus(result: result)
            case .failure(let error):
                result([
                    "status": "Permissions denied",
                    "grantedPermissions": [],
                    "deniedPermissions": ["Location"],
                    "errorMessage": error.localizedDescription
                ])
            }
        }
    }

    private func fetchSsid(result: @escaping FlutterResult) {
        coreResolver.fetchSSID { (ssid, error) in
            if let ssid = ssid {
                result(ssid)
            } else if let error = error {
                result(FlutterError(
                    code: "SSID_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(FlutterError(
                    code: "UNKNOWN_ERROR",
                    message: "Unknown error occurred",
                    details: nil
                ))
            }
        }
    }
}