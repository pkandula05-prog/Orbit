import SwiftUI

/// 09 / 5a / 5b · The orbit. One screen at two roster sizes: `5a` up to two tracked friends,
/// `5b` at three or more, so the app switches on the count rather than routing between two
/// screens. The bell opens the invite inbox; `+` opens the friends page, the same view the
/// flow uses, rather than a second copy of the invite logic.
struct CompassFaceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let compassModel = model.model

        GeometryReader { geometry in
            let ringSize = min(geometry.size.width - 20, geometry.size.height * 0.46)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    // Long-press the title to replay the whole flow from the launch screen.
                    Text("Orbit")
                        .caps(11, OrbitColor.ink)
                        .onLongPressGesture(minimumDuration: 1.2) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                                model.resetOnboarding()
                            }
                        }
                    Spacer(minLength: 8)
                    Text(model.headerRight).caps(11, OrbitColor.neutral700)

                    InviteBell(count: model.incomingInvites.count) { model.showingInvites = true }

                    Button { model.showingFriends = true } label: {
                        // A plus built from the same two rules as everything else on screen.
                        ZStack {
                            Rectangle().fill(OrbitColor.ink).frame(width: 17, height: 2)
                            Rectangle().fill(OrbitColor.ink).frame(width: 2, height: 17)
                        }
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add people")
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
                }
                .screenGutters()
                .padding(.top, 8)

                Spacer(minLength: 12)

                ZStack {
                    // Redrawn every frame from the eased heading; the readout beside it is
                    // bound to whole degrees, so only the geometry pays the frame rate.
                    DialView(heading: model.compass.heading,
                             markers: compassModel.tracked.map { DialMarker($0) })
                        .frame(width: ringSize, height: ringSize)

                    CompassReadout(ringSize: ringSize,
                                   heading: model.compass.wholeHeading,
                                   tracked: compassModel.tracked,
                                   dense: model.dense)
                        .frame(width: ringSize, height: ringSize, alignment: .topLeading)
                }
                .frame(width: ringSize, height: ringSize)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 0) {
                    Text(compassModel.readings.isEmpty ? "Waiting for friend feed" : "Tracking · tap to toggle")
                        .caps(11, OrbitColor.neutral700)
                        .padding(.bottom, 12)

                    TrackingRow(friends: compassModel.readings,
                                trackedIDs: model.trackedIDs,
                                isAtCapacity: model.isAtCapacity,
                                onToggle: model.toggleTracked)

                    HStack(alignment: .firstTextBaseline) {
                        Text(footerLeft(compassModel)).caps(11, OrbitColor.ink)
                        Spacer(minLength: 12)
                        Text(footerRight(compassModel)).caps(11, OrbitColor.neutral700)
                    }
                    .lineLimit(1)
                    .padding(.top, 14)
                    .overlay(alignment: .top) {
                        Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
                    }
                    .padding(.top, 20)
                }
                .screenGutters()
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(OrbitColor.bg)
        .sheet(isPresented: Binding(get: { model.showingInvites },
                                    set: { model.showingInvites = $0 })) {
            InvitesView { model.showingInvites = false }
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(get: { model.showingFriends },
                                    set: { model.showingFriends = $0 })) {
            FriendsView(isSheet: true) { model.showingFriends = false }
                .presentationDragIndicator(.visible)
        }
    }

    /// `5a` names each friend and their distance; `5b` has no room, so it reduces to the two
    /// ends of the roster.
    private func footerLeft(_ compassModel: CompassModel) -> String {
        guard !compassModel.tracked.isEmpty else { return "Nobody tracked" }
        if model.dense { return summarise(compassModel.nearest, prefix: "Nearest") }
        return summarise(compassModel.tracked.first)
    }

    private func footerRight(_ compassModel: CompassModel) -> String {
        if model.dense { return summarise(compassModel.farthest, prefix: "Farthest") }
        guard compassModel.tracked.count > 1 else { return "" }
        return summarise(compassModel.tracked[1])
    }

    private func summarise(_ friend: FriendReading?, prefix: String? = nil) -> String {
        guard let friend else { return "—" }
        let label = prefix.map { "\($0) \(friend.name)" } ?? friend.name
        return "\(label) \(Geo.formatDistance(friend.distanceM))"
    }
}
