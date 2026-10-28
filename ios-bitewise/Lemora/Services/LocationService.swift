import Foundation
import CoreLocation
import UIKit

/// One-shot, when-in-use location lookup that resolves a postal code. Never tracks continuously:
/// updates run only until a usable position is found (at most `fixTimeout`), then stop.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum State: Equatable {
        case idle, requesting, resolved(String), denied, failed
    }

    private(set) var state: State = .idle
    private let manager = CLLocationManager()
    /// Best position received so far during the current lookup.
    private var best: CLLocation?
    private var resolving = false
    private var timeoutTask: Task<Void, Never>?
    /// Indoors or right after launch the first fix can take a while: wait this long before using what we have.
    private let fixTimeout: Duration = .seconds(12)

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
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // iOS only asks once: after a refusal, the button opens Lemora's Settings to turn location on.
            state = .denied
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default:
            startFix()
        }
    }

    /// Finds the position without asking anything when the person already allowed it before.
    func requestIfAuthorized() {
        guard isAuthorized, state != .requesting else { return }
        state = .requesting
        startFix()
    }

    private func startFix() {
        best = nil
        resolving = false
        manager.startUpdatingLocation()
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.fixTimeout)
            guard !Task.isCancelled, self.state == .requesting, !self.resolving else { return }
            self.manager.stopUpdatingLocation()
            if let best = self.best {
                await self.resolve(best)
            } else {
                self.state = .failed
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.state == .requesting else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.startFix()
            case .denied, .restricted: self.state = .denied
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        Task { @MainActor in
            guard self.state == .requesting, !self.resolving else { return }
            if self.best == nil || location.horizontalAccuracy < (self.best?.horizontalAccuracy ?? .infinity) {
                self.best = location
            }
            // Good enough for a postal code, or "Precise Location" is off and this is as good as it gets.
            let reduced = self.manager.accuracyAuthorization == .reducedAccuracy
            if location.horizontalAccuracy <= 1_000 || reduced {
                self.timeoutTask?.cancel()
                self.manager.stopUpdatingLocation()
                await self.resolve(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // "Location unknown" only means no fix yet: keep waiting until the timeout.
        guard (error as? CLError)?.code == .denied else { return }
        Task { @MainActor in
            guard self.state == .requesting else { return }
            self.timeoutTask?.cancel()
            self.manager.stopUpdatingLocation()
            self.state = .denied
        }
    }

    private func resolve(_ location: CLLocation) async {
        guard !resolving else { return }
        resolving = true
        defer { resolving = false }
        // Apple's geocoder sometimes fails on the first call (network, rate limit): try a few times.
        var mark: CLPlacemark?
        for attempt in 0..<3 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(Double(attempt))) }
            mark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            if mark != nil { break }
        }
        if let code = mark?.postalCode, !code.isEmpty {
            state = .resolved(code)
            return
        }
        // "Precise Location" off: Apple gives the town but no postal code. Use the town's postal code instead.
        if let mark, let town = mark.locality ?? mark.subAdministrativeArea {
            let place = [town, mark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            if let found = await Self.postalCode(forCity: place, country: mark.isoCountryCode ?? "CA") {
                state = .resolved(found.postal)
                return
            }
        }
        state = .failed
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
