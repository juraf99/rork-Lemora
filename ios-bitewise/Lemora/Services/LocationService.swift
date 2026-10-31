import Foundation
import CoreLocation
import UIKit

/// One-shot, when-in-use location lookup that resolves a postal code. Never tracks continuously.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle, requesting, resolved(String), denied, failed
    }

    private(set) var state: State = .idle
    /// "Montreal, QC" from the same lookup, so the screen can show the place and not only a code.
    private(set) var resolvedPlace: String = ""
    private let manager = CLLocationManager()
    /// GPS often has no fix on the first try (indoors, right after launch): retry before giving up.
    private var attempts = 0

    /// True once Lemora may use the location: no iOS prompt is shown again, even after an app update.
    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        state = .requesting
        attempts = 0
        resolvedPlace = ""
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // The Allow tap can resolve before the callback is observed. Ask again once iOS has answered.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                self.startFixIfAllowed()
            }
        case .denied, .restricted:
            // iOS only asks once: after a refusal, the button opens Lemora's Settings to turn location on.
            state = .denied
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default:
            manager.requestLocation()
        }
    }

    private func startFixIfAllowed() {
        guard state == .requesting else { return }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.requestLocation()
    }

    /// Finds the position without asking anything when the person already allowed it before.
    func requestIfAuthorized() {
        guard isAuthorized, state != .requesting else { return }
        state = .requesting
        attempts = 0
        manager.requestLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.state == .requesting else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.state = .denied
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            await self.resolve(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let refused = (error as? CLError)?.code == .denied
        Task { @MainActor in
            guard self.state == .requesting else { return }
            if !refused && self.attempts < 3 {
                self.attempts += 1
                try? await Task.sleep(for: .seconds(2))
                if self.state == .requesting { self.manager.requestLocation() }
            } else {
                self.state = refused ? .denied : .failed
            }
        }
    }

    private func resolve(_ location: CLLocation) async {
        guard state == .requesting else { return }
        var mark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        if mark == nil {
            try? await Task.sleep(for: .seconds(1))
            guard state == .requesting else { return }
            mark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        }
        guard let mark else {
            state = .failed
            return
        }
        resolvedPlace = Self.placeLine(mark)
        if let code = mark.postalCode, !code.isEmpty {
            state = .resolved(code)
            return
        }
        // "Precise Location" off: Apple gives the town but no postal code. Use the town's postal code instead.
        if let town = mark.locality ?? mark.subAdministrativeArea {
            let place = [town, mark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            if let found = await Self.postalCode(forCity: place, country: mark.isoCountryCode ?? "CA") {
                if resolvedPlace.isEmpty { resolvedPlace = found.place }
                state = .resolved(found.postal)
                return
            }
        }
        state = .failed
    }

    private static func placeLine(_ mark: CLPlacemark) -> String {
        [mark.locality ?? mark.subAdministrativeArea ?? mark.name, mark.administrativeArea]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// "Montréal" → a postal code near that city's centre, for people who'd rather not give theirs.
    static func postalCode(forCity city: String, country: String) async -> (postal: String, place: String)? {
        let countryName = country == "CA" ? "Canada" : country == "AU" ? "Australia" : "United States"
        guard let mark = try? await CLGeocoder().geocodeAddressString("\(city), \(countryName)").first,
              let location = mark.location else { return nil }
        var code = mark.postalCode
        if code == nil { code = try? await CLGeocoder().reverseGeocodeLocation(location).first?.postalCode }
        guard let code else { return nil }
        let place = [mark.locality ?? mark.name, mark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
        return (code, place)
    }
}
