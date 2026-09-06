import SwiftUI

/// The block inside the dial: heading, cardinal, and the signed turn to each tracked friend.
/// Laid out in the artboards' 373pt dial and scaled with it.
struct CompassReadout: View {
    var ringSize: CGFloat
    var heading: Int
    var tracked: [FriendReading]
    /// Artboard 5b: three or more tracked friends, so the deltas move to a two-column grid
    /// and the numeral gives up ten points to make room.
    var dense: Bool

    private func u(_ value: CGFloat) -> CGFloat { value / 373 * ringSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 5a draws the numeral at 66pt and 5b at 56pt. SwiftUI cannot interpolate
            // between two fonts, so it is always set at 66 and scaled — which animates, and
            // keeps the glyphs on one set of metrics.
            Text(Geo.formatHeading(Double(heading)))
                .tightHeading(u(66))
                .foregroundStyle(OrbitColor.ink)
                .monospacedDigit()
                .scaleEffect(dense ? 56.0 / 66.0 : 1, anchor: .topLeading)
                .frame(height: u(dense ? 56 : 66) * 0.84, alignment: .topLeading)

            Text(Geo.cardinalName(Double(heading)))
                .caps(u(11), OrbitColor.blue)
                .padding(.top, u(8))

            if !tracked.isEmpty {
                deltas
                    .frame(width: u(190), alignment: .leading)
                    .padding(.top, u(dense ? 10 : 12))
                    .overlay(alignment: .top) {
                        Rectangle().fill(OrbitColor.neutral400).frame(height: Rule.light)
                    }
                    .padding(.top, u(dense ? 14 : 18))
            }
        }
        .frame(width: u(200), alignment: .leading)
        .offset(x: u(84), y: u(dense ? 106 : 118))
        // Adding a third friend shrinks the numeral and lifts the block; the layout moves
        // rather than snapping between the two artboards.
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: dense)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var deltas: some View {
        if dense {
            // Two columns, name above the number — 5b.
            let columns = [GridItem(.flexible(), spacing: u(16), alignment: .leading),
                           GridItem(.flexible(), spacing: u(16), alignment: .leading)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: u(6)) {
                ForEach(tracked) { friend in
                    VStack(alignment: .leading, spacing: u(2)) {
                        Text(friend.name).caps(u(10), OrbitColor.neutral700).lineLimit(1)
                        delta(friend, size: u(17))
                    }
                }
            }
        } else {
            // Stacked rows, name left — 5a.
            VStack(alignment: .leading, spacing: u(2)) {
                ForEach(tracked) { friend in
                    HStack(alignment: .firstTextBaseline, spacing: u(12)) {
                        Text(friend.name).caps(u(11), OrbitColor.neutral700).lineLimit(1)
                        Spacer(minLength: 0)
                        delta(friend, size: u(19))
                    }
                }
            }
        }
    }

    private func delta(_ friend: FriendReading, size: CGFloat) -> some View {
        Text(Geo.formatDelta(friend.delta))
            .font(OrbitFont.mono(size))
            .monospacedDigit()
            .foregroundStyle(friend.onTarget ? OrbitColor.onTarget : OrbitColor.red)
            // Turning onto someone is the one moment the screen rewards you, so the flip to
            // green is eased rather than instant.
            .animation(.easeInOut(duration: 0.22), value: friend.onTarget)
    }
}
