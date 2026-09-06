import CoreLocation
import Observation
import QuartzCore
import SwiftUI

/// True heading and position for the dial.
///
/// The magnetometer reports in bursts and jitters by a degree or two; drawing those samples
/// directly makes the dial twitch. So sensor samples only ever move a *target*, and a display
/// link eases the drawn angle toward it once per frame — the dial is then as smooth as the
/// screen refreshes, on ProMotion as well as 60 Hz, no matter how the sensor is behaving.
@MainActor
@Observable
final class DeviceCompass: NSObject {
    /// Continuous, unwrapped angle in degrees. Redrawn every frame — read this for geometry.
    private(set) var heading: Double = 0
    /// Whole degrees, 0–359. Changes a few times a second, so text bound to it does not
    /// re-render at the display's refresh rate.
    private(set) var wholeHeading: Int = 0

    private(set) var coordinate: CLLocationCoordinate2D?
    /// A lock-guarded copy of the same fix. The friend feed runs off the main actor and needs
    /// to read the origin at every tick; this lets it do that without hopping back.
    nonisolated let lastFix = LocationBox()
    private(set) var altitude: Double?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// False where there is no magnetometer — the Simulator, and Macs — and the dial sweeps
    /// instead, so the screens can still be reviewed.
    private(set) var hasCompass = false

    /// Matches the sweep speed the artboards animate at.
    private let simulatedDegreesPerSecond = 7.0
    /// Time constant of the easing: higher follows the sensor harder, lower glides more.
    private let responsiveness = 11.0

    private let manager = CLLocationManager()
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var target: Double = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = kCLHeadingFilterNone
        authorization = manager.authorizationStatus
    }

    /// Starts the dial, not the permission. Nothing is asked for here — the flow only prompts
    /// on the location access screen, so launching the app never raises a system alert.
    func start() {
        guard link == nil else { return }
        beginUpdates()

        let link = CADisplayLink(target: self, selector: #selector(step))
        // Let the system run us at the panel's full rate where one is available.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        lastFrame = CACurrentMediaTime()
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    /// Called by the permissions screen; the system prompt only ever appears once.
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    private func beginUpdates() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = min(max(now - lastFrame, 0), 1.0 / 20)
        lastFrame = now

        if !hasCompass {
            target += simulatedDegreesPerSecond * dt
        }

        // Critically damped approach: frame-rate independent, and it never overshoots, which
        // on a compass would read as the dial wobbling past the bearing.
        heading += (target - heading) * (1 - exp(-responsiveness * dt))

        let whole = Int(Geo.normalize(heading).rounded()) % 360
        if whole != wholeHeading { wholeHeading = whole }
    }

    /// Move the target by the *shortest* turn, so 359° → 001° crosses north instead of
    /// unwinding the long way round the dial.
    private func aim(at degrees: Double) {
        target += Geo.signedDelta(from: target, to: degrees)
    }
}

extension DeviceCompass: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let raw = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard raw >= 0 else { return }
        MainActor.assumeIsolated {
            if !hasCompass {
                hasCompass = true
                // First real sample: jump rather than sweep round from wherever the
                // simulated dial had wandered to.
                target = raw
                heading = raw
            }
            aim(at: raw)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        lastFix.set(last.coordinate)
        MainActor.assumeIsolated {
            coordinate = last.coordinate
            altitude = last.verticalAccuracy >= 0 ? last.altitude : nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorization = status
            beginUpdates()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}


/// The device's last fix, readable from any thread.
final class LocationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: CLLocationCoordinate2D?

    var coordinate: CLLocationCoordinate2D? { lock.withLock { value } }

    func set(_ coordinate: CLLocationCoordinate2D) {
        lock.withLock { value = coordinate }
    }
}
