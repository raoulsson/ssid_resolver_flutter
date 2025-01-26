import Foundation
import CoreLocation
import NetworkExtension

class MissingPermissionException: Error {
    let missingPermissions: [String]

    init(_ missingPermissions: [String]) {
        self.missingPermissions = missingPermissions
    }

    var localizedDescription: String {
        return "Missing permissions: \(missingPermissions.joined(separator: ", "))"
    }
}

enum SSIDResolverError: Error {
    case noWifiConnection
    case unknown

    var localizedDescription: String {
        switch self {
        case .noWifiConnection:
            return "Not connected to any WiFi network"
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

        checkAccessWiFiEntitlement { hasWiFi in
            guard hasWiFi else {
                completion(nil, MissingPermissionException(["WiFi"]))
                return
            }

            if #available(iOS 13.0, *) {
                NEHotspotNetwork.fetchCurrent { network in
                    completion(network?.ssid ?? "Unknown", nil)
                }
            } else {
                completion("Unknown", nil)
            }
        }
    }
}