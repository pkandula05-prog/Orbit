import SwiftUI

/// The invite inbox, reached from the bell on the dial. Requests to share sit here until they
/// are answered — accepting is what starts the two-way share, declining shares nothing.
struct InvitesView: View {
    @Environment(AppModel.self) private var model
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Requests", trailing: "Done", trailingAction: onDismiss)
                .padding(.top, 20)

            if model.incomingInvites.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nothing waiting")
                        .tightHeading(32)
                        .foregroundStyle(OrbitColor.ink)
                    Text("Requests to share direction land here. Until you accept one, nobody sees where you are.")
                        .font(OrbitFont.regular(15))
                        .lineSpacing(4)
                        .foregroundStyle(OrbitColor.neutral700)
                }
                .padding(.top, 40)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(model.incomingInvites.enumerated()), id: \.element.id) { offset, contact in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 14) {
                                    InitialBadge(initial: contact.initial, size: 20, fontSize: 11)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(contact.shortName) wants to share direction")
                                            .font(OrbitFont.semibold(16))
                                            .foregroundStyle(OrbitColor.ink)
                                        Text("@\(contact.username)")
                                            .font(OrbitFont.mono(11, weight: .regular))
                                            .foregroundStyle(OrbitColor.neutral700)
                                    }
                                    Spacer(minLength: 0)
                                }

                                Text("If you accept, you each see the other's bearing and distance. Either of you can stop it, and the other is told.")
                                    .font(OrbitFont.regular(14))
                                    .lineSpacing(3)
                                    .foregroundStyle(OrbitColor.neutral700)

                                HStack(spacing: 10) {
                                    OrbitButton(title: "Accept") { respond(contact, accept: true) }
                                    OrbitButton(title: "Decline", kind: .secondary) { respond(contact, accept: false) }
                                }
                            }
                            .padding(.vertical, 18)
                            .overlay(alignment: .top) {
                                Rectangle()
                                    .fill(offset == 0 ? OrbitColor.ink : OrbitColor.neutral400)
                                    .frame(height: offset == 0 ? Rule.heavy : Rule.light)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.top, 24)
                }
            }

            Spacer(minLength: 0)
        }
        .screenGutters()
        .padding(.bottom, 24)
        .background(OrbitColor.bg)
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: model.incomingInvites)
    }

    private func respond(_ contact: Contact, accept: Bool) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            model.respond(to: contact, accept: accept)
        }
        if model.incomingInvites.isEmpty { onDismiss() }
    }
}

/// The bell on the dial, with the count of requests waiting on an answer.
struct InviteBell: View {
    var count: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // A bell drawn the way everything else here is: rules and blocks, no icon font.
                VStack(spacing: 0) {
                    Rectangle().fill(OrbitColor.ink).frame(width: 3, height: 3)
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 15, height: 12)
                        .overlay { Rectangle().strokeBorder(OrbitColor.ink, lineWidth: 2) }
                    Rectangle().fill(OrbitColor.ink).frame(width: 19, height: 2)
                    Rectangle().fill(OrbitColor.ink).frame(width: 5, height: 3)
                }
                .frame(width: 26, height: 24)

                if count > 0 {
                    Text("\(count)")
                        .font(OrbitFont.heading(9))
                        .foregroundStyle(OrbitColor.bg)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(OrbitColor.red)
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "\(count) sharing requests" : "Sharing requests")
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: count)
    }
}
