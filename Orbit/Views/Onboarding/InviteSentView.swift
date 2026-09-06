import SwiftUI

/// 07 · Invites out. Pending until they accept and share back — the dial only shows people
/// who have.
struct InviteSentView: View {
    @Environment(AppModel.self) private var model

    private var pending: [Contact] { model.contacts.filter { $0.relation == .invitedByMe } }
    private var accepted: [Contact] { model.contacts.filter { $0.relation == .sharing } }
    private var listed: [Contact] { pending + accepted.prefix(max(0, 3 - pending.count)) }

    private var headline: String {
        switch pending.count {
        case 0: "Invites out"
        case 1: "One invite out"
        case 2: "Two invites out"
        default: "\(pending.count) invites out"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Invite · sent")
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(headline)
                    .tightHeading(38)
                    .foregroundStyle(OrbitColor.ink)

                Text("They appear on your dial as soon as they accept and share back.")
                    .font(OrbitFont.regular(15))
                    .lineSpacing(4)
                    .foregroundStyle(OrbitColor.neutral700)
                    .padding(.top, 16)
            }
            .padding(.top, 62)

            VStack(spacing: 0) {
                ForEach(Array(listed.enumerated()), id: \.element.id) { offset, contact in
                    ListRow(isFirst: offset == 0, minHeight: 60) {
                        HStack(spacing: 14) {
                            InitialBadge(initial: contact.initial, size: 20,
                                         fill: contact.relation == .sharing ? OrbitColor.onTarget : OrbitColor.red,
                                         fontSize: 11)
                            Text(contact.name)
                                .font(OrbitFont.semibold(16))
                                .foregroundStyle(OrbitColor.ink)
                            Spacer(minLength: 8)
                            if contact.relation == .sharing {
                                Text("Accepted").caps(10, OrbitColor.onTarget)
                            } else {
                                OrbitTag(title: "Pending")
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 40)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: listed)

            VStack(alignment: .leading, spacing: 12) {
                Text("Message sent").caps(11, OrbitColor.ink)
                Text("“Sharing my direction with you on Orbit — accept and I'll show up on your dial.”")
                    .font(OrbitFont.regular(14))
                    .lineSpacing(3)
                    .foregroundStyle(OrbitColor.neutral700)
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
            }
            .padding(.top, 32)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                OrbitButton(title: "Open orbit") { model.openOrbit() }
                OrbitButton(title: "Invite more", kind: .ghost) { model.phase = .invite }
            }
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }
}
