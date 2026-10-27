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
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        state = .requesting
        attempts = 0
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // iOS only asks once: after a refusal, the button opens Lemora's Settings to turn location on.
            state = .denied
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default:
            manager.requestLocation()
        }
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
        guard let location = locations.last else { return }
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
        var code = try? await CLGeocoder().reverseGeocodeLocation(location).first?.postalCode
        if code == nil {
            try? await Task.sleep(for: .seconds(1))
            code = try? await CLGeocoder().reverseGeocodeLocation(location).first?.postalCode
        }
        if let code {
            state = .resolved(code)
        } else {
            state = .failed
        }
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
