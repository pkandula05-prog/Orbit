import SwiftUI

/// 06 · Who should show on your dial? People already on Orbit sit above the ones who need an
/// invite; both are selected the same way.
struct InviteView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private var onOrbit: [Contact] {
        matching.filter { $0.status == .sharing }
    }

    private var invitable: [Contact] {
        matching.filter { $0.status != .sharing }
    }

    private var matching: [Contact] {
        guard !query.isEmpty else { return model.contacts }
        return model.contacts.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Invite", trailing: "Skip") { model.openCompass() }
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("Who should show on your dial?")
                    .tightHeading(34)
                    .foregroundStyle(OrbitColor.ink)

                OrbitField(label: "", placeholder: "Search contacts", text: $query)
                    .padding(.top, 22)
            }
            .padding(.top, 60)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !onOrbit.isEmpty {
                        section("Already on Orbit · \(onOrbit.count)", top: 22)
                        ForEach(Array(onOrbit.enumerated()), id: \.element.id) { offset, contact in
                            row(contact, isFirst: offset == 0, trailing: "Sharing")
                        }
                    }

                    if !invitable.isEmpty {
                        section("Invite by message · \(model.selectedInvites.count) selected", top: 22)
                        ForEach(Array(invitable.enumerated()), id: \.element.id) { offset, contact in
                            row(contact, isFirst: offset == 0, trailing: contact.phone)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 8)

            OrbitButton(title: model.selectedInvites.isEmpty
                        ? "Send invites"
                        : "Send \(model.selectedInvites.count) invite\(model.selectedInvites.count == 1 ? "" : "s")",
                        isBusy: model.isWorking,
                        isEnabled: !model.selectedInvites.isEmpty) {
                model.sendInvites()
            }
            .padding(.top, 12)
            .padding(.bottom, 46)
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }

    private func section(_ title: String, top: CGFloat) -> some View {
        Text(title)
            .caps(11, OrbitColor.neutral700)
            .padding(.top, top)
            .padding(.bottom, 10)
            .animation(.none, value: model.selectedInvites)
    }

    private func row(_ contact: Contact, isFirst: Bool, trailing: String) -> some View {
        let sharing = contact.status == .sharing
        let selected = sharing || model.selectedInvites.contains(contact.id)

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
                Text(contact.name)
                    .font(OrbitFont.semibold(16))
                    .foregroundStyle(selected ? OrbitColor.ink : OrbitColor.neutral700)
                Spacer(minLength: 8)
                if sharing {
                    Text(trailing).caps(10, OrbitColor.neutral700)
                } else {
                    Text(trailing)
                        .font(OrbitFont.mono(12, weight: .regular))
                        .foregroundStyle(OrbitColor.neutral700)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !sharing else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                model.toggleInvite(contact.id)
            }
        }
    }
}
