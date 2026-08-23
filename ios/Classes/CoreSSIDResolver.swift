import Foundation
import CoreLocation
import NetworkExtension

class MissingPermissionException: LocalizedError {
    let missingPermissions: [String]

    init(_ missingPermissions: [String]) {
        self.missingPermissions = missingPermissions
    }

    var errorDescription: String? {
        return "Missing permissions: \(missingPermissions.joined(separator: ", "))"
    }
}

enum SSIDResolverError: LocalizedError {
    case noWifiConnection
    case ssidWithheld
    case unknown

    var errorDescription: String? {
        switch self {
        case .noWifiConnection:
            return "Not connected to any WiFi network"
        case .ssidWithheld:
            // fetchCurrent() returning nil has more than one cause. Reporting the
            // entitlement as fact misleads users on captive and enterprise networks
            // that withhold the name no matter what the app is allowed to do.
            return "Connected to WiFi, but iOS did not return the network name. "
                + "This needs the Access WiFi Information entitlement; captive, "
                + "enterprise and some guest networks also withhold it."
        case .unknown:
            return "Unknown error occurred while fetching WiFi information"
        }
    }
}

class CoreSSIDResolver: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    private var permissionCompletion: ((Result<Bool, Error>) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            completion(.failure(MissingPermissionException(["Location Access"])))
        case .authorizedWhenInUse, .authorizedAlways:
            completion(.success(true))
        @unknown default:
            completion(.failure(SSIDResolverError.unknown))
        }
    }

    func checkAccessWiFiEntitlement(completion: @escaping (Bool) -> Void) {
        if #available(iOS 13.0, *) {
            NEHotspotNetwork.fetchCurrent { network in
                completion(network != nil)
            }
        } else {
            completion(false)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionCompletion?(.success(true))
        case .restricted, .denied:
            permissionCompletion?(.failure(MissingPermissionException(["Location"])))
        case .notDetermined:
            break
        @unknown default:
            permissionCompletion?(.failure(NSError(domain: "SSIDResolver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status"])))
        }
        permissionCompletion = nil
    }

    func fetchSSID(completion: @escaping (String?, Error?) -> Void) {
        let locationStatus = locationManager.authorizationStatus
        guard [.authorizedWhenInUse, .authorizedAlways].contains(locationStatus) else {
            completion(nil, MissingPermissionException(["Location"]))
            return
        }

        guard #available(iOS 13.0, *) else {
            completion(nil, SSIDResolverError.unknown)
            return
        }

        // No pre-flight entitlement probe: the probe was itself a fetchCurrent
        // call, so it could only ever report "nil" as "missing entitlement".
        // Attempt the real fetch, then explain a nil result honestly.
        NEHotspotNetwork.fetchCurrent { network in
            if let ssid = network?.ssid, !ssid.isEmpty {
                completion(ssid, nil)
                return
            }
            // The interface table needs no permission, so it can distinguish
            // "not on WiFi" from "on WiFi but the name is withheld" - which the
            // old code reported identically, as a missing permission.
            let onWifi = NetworkInterfaceResolver.fetchAll().contains { iface in
                iface.name.hasPrefix("en")
                    && !iface.ip.hasPrefix("169.254.")
                    && !iface.ip.hasPrefix("127.")
            }
            completion(nil, onWifi ? SSIDResolverError.ssidWithheld : SSIDResolverError.noWifiConnection)
        }
    }
}