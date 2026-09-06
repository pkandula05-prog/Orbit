import CoreLocation
import Foundation

/// Pure geometry for the dial. Everything the compass shows — bearings, distances, the
/// signed turn to a friend, the formatted numerals — is derived here, so the numbers can be
/// reasoned about (and tested) without rendering anything.
public enum Geo {
    public static let earthRadiusM = 6_371_008.8
    /// Within this many degrees of a friend, the readout flips from red to green.
    public static let onTargetDegrees = 10.0

    public static func normalize(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Signed shortest turn from `from` to `to`, in (-180, 180]. Positive is clockwise.
    public static func signedDelta(from: Double, to: Double) -> Double {
        var delta = normalize(to) - normalize(from)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return delta
    }

    /// Initial great-circle bearing from `a` to `b`, degrees clockwise from true north.
    public static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return normalize(atan2(y, x) * 180 / .pi)
    }

    /// Great-circle distance in metres (haversine).
    public static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let h = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
        return 2 * earthRadiusM * asin(min(1, sqrt(h)))
    }

    /// Point reached by travelling `metres` from `origin` along `bearing`.
    public static func destination(from origin: CLLocationCoordinate2D, bearing: Double, metres: Double) -> CLLocationCoordinate2D {
        let angular = metres / earthRadiusM
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let brg = bearing * .pi / 180

        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(brg))
        let lon2 = lon1 + atan2(sin(brg) * sin(angular) * cos(lat1),
                                cos(angular) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: (lon2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180
        )
    }

    private static let cardinals = ["North", "Northeast", "East", "Southeast",
                                    "South", "Southwest", "West", "Northwest"]

    public static func cardinalName(_ heading: Double) -> String {
        cardinals[Int((normalize(heading) / 45).rounded()) % 8]
    }

    public static func isOnTarget(_ delta: Double) -> Bool { abs(delta) <= onTargetDegrees }

    public static func formatHeading(_ heading: Double) -> String {
        let degrees = Int(normalize(heading).rounded()) % 360
        return String(format: "%03d°", degrees)
    }

    /// The design writes the turn with a typographic minus, not a hyphen.
    public static func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : "−"
        return sign + String(format: "%03d°", Int(abs(delta).rounded()))
    }

    private static let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    /// Eight-point bearing — what a distance gives you once degrees stop being actionable.
    public static func compassPoint(_ bearing: Double) -> String {
        points[Int((normalize(bearing) / 45).rounded()) % 8]
    }

    /// A band rather than a figure, for a fix too old to be precise about. Saying "1.4 km" of a
    /// six-minute-old position claims an accuracy nobody has.
    public static func bandedDistance(_ metres: Double) -> String {
        switch metres {
        case ..<200: "under 200 m"
        case ..<500: "200–500 m"
        case ..<1000: "500 m–1 km"
        case ..<3000: "1–3 km"
        case ..<10_000: "3–10 km"
        default: "over 10 km"
        }
    }

    public static func formatDistance(_ metres: Double) -> String {
        guard metres.isFinite else { return "—" }
        if metres < 1000 { return "\(Int((metres / 10).rounded()) * 10) m" }
        if metres < 10_000 { return String(format: "%.1f km", metres / 1000) }
        return "\(Int((metres / 1000).rounded())) km"
    }
}
