import Foundation
import CoreLocation
import NetworkExtension

class SSIDResolverViewModel {
    private let coreResolver = CoreSSIDResolver()
    private(set) var ssid: String = "Unknown SSID Status"
    private(set) var permissionStatus: String = "Unknown Permission Status"
    private(set) var errorMessage: String?
    private(set) var grantedPermissions: [String] = []
    private(set) var deniedPermissions: [String] = []

    func checkPermissionStatus(completion: @escaping () -> Void) {
        coreResolver.checkAccessWiFiEntitlement(completion: { hasWiFi in
            let locationStatus = self.coreResolver.locationManager.authorizationStatus

            self.updateLocationPermission(status: locationStatus)
            self.updateWiFiPermission(hasAccess: hasWiFi)

            self.updatePermissionStatus()
            completion()
        })
    }

    private func updateLocationPermission(status: CLAuthorizationStatus) {
        let locationGranted = [.authorizedWhenInUse, .authorizedAlways].contains(status)

        if locationGranted {
            grantedPermissions = grantedPermissions.contains("Location")
                ? grantedPermissions
                : grantedPermissions + ["Location"]
            deniedPermissions.removeAll { $0 == "Location" }
        } else {
            grantedPermissions.removeAll { $0 == "Location" }
            if !deniedPermissions.contains("Location") {
                deniedPermissions.append("Location")
            }
        }
    }

    private func updateWiFiPermission(hasAccess: Bool) {
        if hasAccess {
            grantedPermissions = grantedPermissions.contains("WiFi")
                ? grantedPermissions
                : grantedPermissions + ["WiFi"]
            deniedPermissions.removeAll { $0 == "WiFi" }
        } else {
            grantedPermissions.removeAll { $0 == "WiFi" }
            if !deniedPermissions.contains("WiFi") {
                deniedPermissions.append("WiFi")
            }
        }
    }

    private func updatePermissionStatus() {
        if deniedPermissions.isEmpty {
            permissionStatus = "All permissions granted"
        } else if grantedPermissions.isEmpty {
            permissionStatus = "All permissions denied"
        } else {
            permissionStatus = "Some permissions denied"
        }
    }

    func requestPermission(completion: @escaping () -> Void) {
        coreResolver.requestLocationPermission { [weak self] permissionResult in
            guard let self = self else { return }

            switch permissionResult {
            case .success:
                self.updateLocationPermission(
                    status: self.coreResolver.locationManager.authorizationStatus
                )
                self.coreResolver.checkAccessWiFiEntitlement(completion: { hasWiFi in
                    self.updateWiFiPermission(hasAccess: hasWiFi)

                    if !self.deniedPermissions.isEmpty {
                        self.errorMessage = "Missing permissions: \(self.deniedPermissions.joined(separator: ", "))"
                    }

                    completion()
                })
            case .failure(let error):
                self.updateLocationPermission(
                    status: self.coreResolver.locationManager.authorizationStatus
                )
                self.updateWiFiPermission(hasAccess: false)

                self.errorMessage = error.localizedDescription
                completion()
            }
        }
    }

    func fetchSSID(completion: @escaping (String?, Error?) -> Void) {
        coreResolver.fetchSSID(completion: { (ssid, error) in
            self.ssid = ssid ?? "Unknown"
            self.errorMessage = error?.localizedDescription
            completion(ssid, error)
        })
    }
}