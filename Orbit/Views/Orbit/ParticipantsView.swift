import SwiftUI

/// Who is here, the link, and the ways out. Everything about the orbit's lifecycle is on this
/// one sheet, because they are the same decision from different ends.
struct ParticipantsView: View {
    @Environment(AppModel.self) private var model
    var onDismiss: () -> Void
    @State private var confirmingEnd = false

    private var link: URL? {
        guard let token = model.session?.joinToken else { return nil }
        return URL(string: "https://orbit.app/j/\(token)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "This orbit", trailing: "Done", trailingAction: onDismiss)
                .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.participants.enumerated()), id: \.element.id) { offset, person in
                        ListRow(isFirst: offset == 0, minHeight: 56) {
                            HStack(spacing: 14) {
                                InitialBadge(initial: person.initial, size: 20,
                                             filled: !person.hasLeft, fontSize: 11)
                                Text(person.isSelf ? "\(person.displayName) (you)" : person.displayName)
                                    .font(OrbitFont.semibold(16))
                                    .foregroundStyle(person.hasLeft ? OrbitColor.neutral700 : OrbitColor.ink)
                                Spacer(minLength: 8)
                                if person.hasLeft {
                                    Text("Left").caps(10, OrbitColor.neutral700)
                                } else if person.isHost {
                                    OrbitTag(title: "Host")
                                }
                            }
                        }
                    }

                    if model.isHost { hostControls }

                    ends
                }
                .padding(.bottom, 24)
            }
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }

    @ViewBuilder
    private var hostControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The link").caps(11, OrbitColor.ink)

            // The link is a capability, so it is short-lived on purpose: a day-long orbit does
            // not get a day-long joinable link, and it stops working once six people are in.
            Text(model.isFull
                 ? "The orbit is full, so the link has stopped working."
                 : linkStatus)
                .font(OrbitFont.regular(14))
                .lineSpacing(3)
                .foregroundStyle(OrbitColor.neutral700)

            if let link, model.session?.isLinkLive == true, !model.isFull {
                ShareLink(item: link) {
                    Text("Share link")
                        .font(OrbitFont.semibold(16))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(OrbitColor.bg)
                        .background(OrbitColor.red)
                }
                .buttonStyle(.plain)
            }

            OrbitButton(title: "New link", kind: .ghost) { model.regenerateLink() }

            Text("Add time").caps(11, OrbitColor.ink).padding(.top, 8)
            HStack(spacing: 8) {
                ForEach([1, 6, 12], id: \.self) { hours in
                    Button { model.extend(hours: hours) } label: {
                        Text("+\(hours)h")
                            .font(OrbitFont.semibold(15))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(OrbitColor.ink)
                            .overlay { Rectangle().strokeBorder(OrbitColor.neutral500, lineWidth: Rule.heavy) }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Never more than a day left, however often you add to it. \(model.timeRemaining).")
                .font(OrbitFont.regular(13))
                .foregroundStyle(OrbitColor.neutral700)
        }
        .padding(.top, 20)
        .overlay(alignment: .top) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
        .padding(.top, 28)
    }

    private var linkStatus: String {
        guard let expires = model.session?.tokenExpiresAt else { return "No link yet." }
        guard expires > Date() else { return "The link has expired. Make a new one to let anyone else in." }
        let minutes = max(1, Int(expires.timeIntervalSinceNow / 60))
        return "Anyone with the link can join for the next \(minutes) minutes. Six people is the limit."
    }

    private var ends: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitButton(title: "Leave", kind: .ghost) {
                model.leave()
                onDismiss()
            }

            if model.isHost {
                if confirmingEnd {
                    Text("Ending it closes the dial for everyone and deletes the positions.")
                        .font(OrbitFont.regular(13))
                        .foregroundStyle(OrbitColor.neutral700)
                    OrbitButton(title: "Yes, end it for everyone", kind: .secondary) {
                        model.endForEveryone()
                        onDismiss()
                    }
                } else {
                    OrbitButton(title: "End for everyone", kind: .secondary) { confirmingEnd = true }
                }
            }
        }
        .padding(.top, 20)
        .overlay(alignment: .top) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
        .padding(.top, 28)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: confirmingEnd)
    }
}

/// It is over, and it says so. An empty dial would read as "still going, nobody here" — which is
/// the ambiguity that gets somebody lost.
struct EndedOrbitView: View {
    @Environment(AppModel.self) private var model
    var ending: OrbitSession.Ending

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Orbit over").padding(.top, 8)

            Spacer(minLength: 0)

            Text(ending == .expired ? "Time was up" : "This orbit ended")
                .tightHeading(40)
                .foregroundStyle(OrbitColor.ink)

            Text(ending == .expired
                 ? "Orbits end by themselves — that is the point of them. Nobody can see where you are any more, and the positions are gone."
                 : "Nobody can see where you are any more, and the positions are gone. Nothing was kept.")
                .font(OrbitFont.regular(15))
                .lineSpacing(4)
                .foregroundStyle(OrbitColor.neutral700)
                .padding(.top, 16)

            Spacer(minLength: 0)

            OrbitButton(title: "Done") { model.dismissEnded() }
                .padding(.bottom, 46)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .screenGutters()
        .background(OrbitColor.bg)
    }
}
