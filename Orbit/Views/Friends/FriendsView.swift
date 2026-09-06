import SwiftUI

/// 06 · The friends page. Who is here, who has asked for you, and who still needs an invite.
///
/// Nothing on this page shares a location. Matching your address book, inviting someone, even
/// being invited — none of it puts a dot on anyone's dial. Only an accepted, two-way invite
/// does, which is `AppModel.respond(to:accept:)`.
///
/// It is the same view in the flow (06) and as a sheet from the dial, so the invite logic
/// lives in one place.
struct FriendsView: View {
    @Environment(AppModel.self) private var model
    var isSheet = false
    var onDismiss: (() -> Void)?

    @State private var query = ""

    private var results: [Contact] { model.contacts.filter { $0.matches(query) } }
    private var invitedMe: [Contact] { results.filter { $0.relation == .invitedMe } }
    private var sharing: [Contact] { results.filter { $0.relation == .sharing } }
    private var invitable: [Contact] {
        results.filter { $0.relation == .none || $0.relation == .invitedByMe }
    }

    /// A query that is mostly digits is someone typing a number to invite, not a name.
    private var typedPhone: String? {
        let digits = query.filter(\.isNumber)
        guard digits.count >= 7, !query.contains(where: { $0.isLetter }) else { return nil }
        guard !model.contacts.contains(where: { $0.phone.filter(\.isNumber).hasSuffix(digits.suffix(7)) })
        else { return nil }
        return query
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: isSheet ? "Friends" : "Invite",
                       trailing: isSheet ? "Done" : "Skip") {
                if isSheet { onDismiss?() } else { model.openOrbit() }
            }
            .padding(.top, isSheet ? 20 : 8)

            VStack(alignment: .leading, spacing: 0) {
                if !isSheet {
                    Text("Who should show on your dial?")
                        .tightHeading(34)
                        .foregroundStyle(OrbitColor.ink)
                }

                OrbitField(label: "", placeholder: "Name, username or number", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.top, isSheet ? 8 : 22)
            }
            .padding(.top, isSheet ? 0 : 56)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let phone = typedPhone { inviteByPhone(phone) }

                    if !invitedMe.isEmpty {
                        section("Asked to share with you · \(invitedMe.count)")
                        ForEach(Array(invitedMe.enumerated()), id: \.element.id) { offset, contact in
                            ListRow(isFirst: offset == 0, minHeight: 60) {
                                HStack(spacing: 14) {
                                    InitialBadge(initial: contact.initial, size: 20, fontSize: 11)
                                    names(contact)
                                    Spacer(minLength: 8)
                                    Button("Accept") { model.respond(to: contact, accept: true) }
                                        .buttonStyle(.plain)
                                        .caps(10, OrbitColor.onTarget)
                                    Button("Decline") { model.respond(to: contact, accept: false) }
                                        .buttonStyle(.plain)
                                        .caps(10, OrbitColor.neutral700)
                                }
                            }
                        }
                    }

                    if !sharing.isEmpty {
                        section("Sharing with you · \(sharing.count)")
                        ForEach(Array(sharing.enumerated()), id: \.element.id) { offset, contact in
                            ListRow(isFirst: offset == 0) {
                                HStack(spacing: 14) {
                                    InitialBadge(initial: contact.initial, size: 20, fontSize: 11)
                                    names(contact)
                                    Spacer(minLength: 8)
                                    Text("Sharing").caps(10, OrbitColor.neutral700)
                                }
                            }
                        }
                    }

                    if !invitable.isEmpty {
                        section("Invite · \(model.selectedInvites.count) selected")
                        ForEach(Array(invitable.enumerated()), id: \.element.id) { offset, contact in
                            row(contact, isFirst: offset == 0)
                        }
                    }

                    if !model.hasMatchedContacts { matchContacts }
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 8)

            if !model.selectedInvites.isEmpty {
                OrbitButton(title: "Send \(model.selectedInvites.count) invite\(model.selectedInvites.count == 1 ? "" : "s")",
                            isBusy: model.isWorking) {
                    model.sendInvites()
                    if isSheet { onDismiss?() }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .padding(.bottom, isSheet ? 24 : 46)
        .screenGutters()
        .background(OrbitColor.bg)
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: model.selectedInvites.isEmpty)
    }

    private func names(_ contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(contact.name)
                .font(OrbitFont.semibold(16))
                .foregroundStyle(OrbitColor.ink)
            Text("@\(contact.username)")
                .font(OrbitFont.mono(11, weight: .regular))
                .foregroundStyle(OrbitColor.neutral700)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .caps(11, OrbitColor.neutral700)
            .padding(.top, 22)
            .padding(.bottom, 10)
    }

    private func row(_ contact: Contact, isFirst: Bool) -> some View {
        let invited = contact.relation == .invitedByMe
        let selected = model.selectedInvites.contains(contact.id)

        return ListRow(isFirst: isFirst) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(selected ? OrbitColor.red : .clear)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if !selected {
                            Rectangle().strokeBorder(OrbitColor.neutral500, lineWidth: Rule.heavy)
                        }
                    }
                names(contact)
                Spacer(minLength: 8)
                if invited {
                    OrbitTag(title: "Pending")
                } else if !contact.isOnOrbit {
                    Text("By message").caps(10, OrbitColor.neutral700)
                } else {
                    Text(contact.phone)
                        .font(OrbitFont.mono(12, weight: .regular))
                        .foregroundStyle(OrbitColor.neutral700)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !invited else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                model.toggleInvite(contact.id)
            }
        }
    }

    /// Someone with no account yet: they get an SMS with a link and appear once they join.
    private func inviteByPhone(_ phone: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Not on Orbit yet")
            ListRow(isFirst: true, minHeight: 60) {
                HStack(spacing: 14) {
                    InitialBadge(initial: "+", size: 20, filled: false, fontSize: 12)
                    Text(phone)
                        .font(OrbitFont.semibold(16))
                        .foregroundStyle(OrbitColor.ink)
                    Spacer(minLength: 8)
                    Button("Text invite") { model.inviteByPhone(phone) }
                        .buttonStyle(.plain)
                        .caps(10, OrbitColor.red)
                }
            }
        }
    }

    private var matchContacts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.contactsDenied
                 ? "Contacts access is off. Turn it on in Settings to match your address book."
                 : "Match your contacts to find people already here. Numbers are matched, never uploaded in the clear.")
                .font(OrbitFont.regular(14))
                .lineSpacing(3)
                .foregroundStyle(OrbitColor.neutral700)

            if !model.contactsDenied {
                OrbitButton(title: "Match contacts", kind: .ghost) { model.matchContacts() }
            }
        }
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy)
        }
        .padding(.top, 28)
    }
}
