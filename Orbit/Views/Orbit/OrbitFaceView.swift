import SwiftUI

/// The dial, in an orbit. Everyone on the ring, four of them in the readout, and how long the
/// orbit has left.
struct OrbitFaceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width - 20, geometry.size.height * 0.44)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Orbit").caps(11, OrbitColor.ink)
                    Spacer(minLength: 8)
                    Text(model.timeRemaining).caps(11, OrbitColor.neutral700)
                    Button { model.showingParticipants = true } label: {
                        Text("\(model.activeCount) here").caps(11, OrbitColor.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
                .screenGutters()
                .padding(.top, 8)

                Spacer(minLength: 8)

                ZStack {
                    DialView(heading: model.compass.heading, markers: model.markers)
                        .frame(width: ringSize, height: ringSize)

                    OrbitReadout(ringSize: ringSize,
                                 heading: model.compass.wholeHeading,
                                 rows: model.visibleRows,
                                 canPage: model.canPageReadout,
                                 total: model.model.readoutRows.count) {
                        model.readoutPage += 1
                    }
                    .frame(width: ringSize, height: ringSize, alignment: .topLeading)
                }
                .frame(width: ringSize, height: ringSize)

                Spacer(minLength: 8)

                footer
                    .screenGutters()
                    .padding(.bottom, 26)
            }
            .overlay(alignment: .top) {
                // Joins and departures, by name. A stranger on the link should be conspicuous.
                if let notice = model.notice {
                    Text(notice)
                        .caps(11, OrbitColor.bg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(OrbitColor.ink)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.notice)
        }
        .background(OrbitColor.bg)
        .sheet(isPresented: Binding(get: { model.showingParticipants },
                                    set: { model.showingParticipants = $0 })) {
            ParticipantsView { model.showingParticipants = false }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.model.readings.isEmpty ? "Waiting for the first positions" : "In this orbit")
                .caps(11, OrbitColor.neutral700)
                .padding(.bottom, 12)

            HStack(spacing: 10) {
                ForEach(model.participants.filter { !$0.isSelf }) { person in
                    VStack(spacing: 6) {
                        InitialBadge(initial: person.initial, size: 46,
                                     filled: !person.hasLeft, fontSize: 17)
                        Text(person.displayName)
                            .caps(10, person.hasLeft ? OrbitColor.neutral700 : OrbitColor.ink)
                            .lineLimit(1)
                    }
                    .frame(width: 54)
                    .opacity(person.hasLeft ? 0.4 : 1)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline) {
                if let nearest = model.model.nearest {
                    Text("Nearest \(nearest.name) \(nearest.distanceText)").caps(11, OrbitColor.ink)
                } else {
                    Text("Nobody placed yet").caps(11, OrbitColor.ink)
                }
                Spacer(minLength: 12)
                Button { model.showingParticipants = true } label: {
                    Text("Manage").caps(11, OrbitColor.neutral700)
                }
                .buttonStyle(.plain)
            }
            .lineLimit(1)
            .padding(.top, 14)
            .overlay(alignment: .top) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
            .padding(.top, 18)
        }
    }
}

/// The block inside the dial: heading, cardinal, and up to four people ordered by how far you
/// would have to turn to face them.
struct OrbitReadout: View {
    var ringSize: CGFloat
    var heading: Int
    var rows: [ParticipantReading]
    var canPage: Bool
    var total: Int
    var onPage: () -> Void

    private func u(_ value: CGFloat) -> CGFloat { value / 373 * ringSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Geo.formatHeading(Double(heading)))
                .tightHeading(u(66))
                .foregroundStyle(OrbitColor.ink)
                .monospacedDigit()
                .scaleEffect(rows.count > 2 ? 56.0 / 66.0 : 1, anchor: .topLeading)
                .frame(height: u(rows.count > 2 ? 56 : 66) * 0.84, alignment: .topLeading)

            Text(Geo.cardinalName(Double(heading)))
                .caps(u(11), OrbitColor.blue)
                .padding(.top, u(8))

            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: u(6)) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: u(10)) {
                            VStack(alignment: .leading, spacing: u(1)) {
                                Text(row.name).caps(u(10), OrbitColor.neutral700).lineLimit(1)
                                Text(row.distanceText)
                                    .font(OrbitFont.mono(u(10), weight: .regular))
                                    .foregroundStyle(OrbitColor.neutral700)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            // Beyond a kilometre there is no turn worth quoting, so the row
                            // carries a compass point and a distance instead of a false
                            // precision.
                            if let delta = row.deltaText {
                                Text(delta)
                                    .font(OrbitFont.mono(u(16)))
                                    .foregroundStyle(row.onTarget ? OrbitColor.onTarget : OrbitColor.red)
                                    .animation(.easeInOut(duration: 0.22), value: row.onTarget)
                            } else {
                                Text(Geo.compassPoint(row.bearing))
                                    .font(OrbitFont.mono(u(14)))
                                    .foregroundStyle(OrbitColor.neutral700)
                            }
                        }
                        .opacity(row.freshness == .degraded ? 0.65 : 1)
                    }

                    if canPage {
                        Text("\(rows.count) of \(total) · tap")
                            .caps(u(9), OrbitColor.neutral700)
                            .padding(.top, u(2))
                    }
                }
                .frame(width: u(196), alignment: .leading)
                .padding(.top, u(10))
                .overlay(alignment: .top) {
                    Rectangle().fill(OrbitColor.neutral400).frame(height: Rule.light)
                }
                .padding(.top, u(14))
                .contentShape(Rectangle())
                .onTapGesture { if canPage { onPage() } }
            }
        }
        .frame(width: u(206), alignment: .leading)
        .offset(x: u(80), y: u(rows.count > 2 ? 100 : 118))
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: rows.count)
    }
}
