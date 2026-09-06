import SwiftUI

/// The empty dial. Nobody is on it, because nobody ever is by default — that is the whole
/// model. One action: start an orbit.
struct IdleView: View {
    @Environment(AppModel.self) private var model
    @State private var showingDurations = false

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width - 20, geometry.size.height * 0.46)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Orbit").caps(11, OrbitColor.ink)
                    Spacer()
                    Text("No orbit").caps(11, OrbitColor.neutral700)
                }
                .padding(.bottom, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
                .screenGutters()
                .padding(.top, 8)

                Spacer(minLength: 12)

                // The dial still turns with you, with nobody on it. It is a compass either way,
                // and a dead ring would make the app look broken before it has begun.
                DialView(heading: model.compass.heading, markers: [])
                    .frame(width: ringSize, height: ringSize)
                    .overlay {
                        VStack(spacing: 8) {
                            Text(Geo.formatHeading(Double(model.compass.wholeHeading)))
                                .tightHeading(ringSize * 0.15)
                                .foregroundStyle(OrbitColor.ink)
                                .monospacedDigit()
                            Text(Geo.cardinalName(Double(model.compass.wholeHeading)))
                                .caps(11, OrbitColor.blue)
                        }
                    }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Nobody is sharing with you")
                        .tightHeading(28)
                        .foregroundStyle(OrbitColor.ink)
                    Text("Start an orbit and send the link. It ends by itself — an hour, or a day at most.")
                        .font(OrbitFont.regular(15))
                        .lineSpacing(4)
                        .foregroundStyle(OrbitColor.neutral700)
                        .padding(.top, 14)

                    OrbitButton(title: "Start an orbit") { showingDurations = true }
                        .padding(.top, 24)
                }
                .padding(.top, 16)
                .overlay(alignment: .top) { Rectangle().fill(OrbitColor.ink).frame(height: Rule.heavy) }
                .screenGutters()
                .padding(.bottom, 32)
            }
        }
        .background(OrbitColor.bg)
        .sheet(isPresented: $showingDurations) {
            CreateOrbitView { showingDurations = false }
                .presentationDetents([.height(430)])
        }
    }
}

/// Creating one: a name, and how long it lives. Nothing else to decide.
struct CreateOrbitView: View {
    @Environment(AppModel.self) private var model
    var onDismiss: () -> Void
    @State private var hours = 6

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Start an orbit", trailing: "Cancel", trailingAction: onDismiss)
                .padding(.top, 20)

            OrbitField(label: "Your name", placeholder: "What people will see",
                       text: $model.displayName)
                .padding(.top, 24)

            Text("How long").caps(10, OrbitColor.neutral700).padding(.top, 24)

            HStack(spacing: 8) {
                ForEach(OrbitSession.durations, id: \.self) { option in
                    Button {
                        hours = option
                    } label: {
                        Text("\(option)h")
                            .font(OrbitFont.semibold(16))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(hours == option ? OrbitColor.bg : OrbitColor.ink)
                            .background(hours == option ? OrbitColor.ink : .clear)
                            .overlay {
                                if hours != option {
                                    Rectangle().strokeBorder(OrbitColor.neutral500, lineWidth: Rule.heavy)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: hours)

            Text("It ends by itself when the time is up. Twenty-four hours is the maximum, and there is no way to leave one running forever.")
                .font(OrbitFont.regular(13))
                .lineSpacing(3)
                .foregroundStyle(OrbitColor.neutral700)
                .padding(.top, 16)

            if let error = model.error {
                Text(error).caps(11, OrbitColor.red).padding(.top, 14)
            }

            Spacer(minLength: 16)

            OrbitButton(title: "Create and get a link",
                        isBusy: model.isWorking,
                        isEnabled: !model.displayName.trimmingCharacters(in: .whitespaces).isEmpty) {
                model.create(hours: hours)
            }
            .padding(.bottom, 24)
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }
}

/// A link was tapped before we knew what to call you. The name is asked for here, at the moment
/// it is first needed, and never before.
struct JoinNameView: View {
    @Environment(AppModel.self) private var model
    var token: String

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            StepHeader(title: "Joining an orbit")
                .padding(.top, 20)

            Text("What should they call you?")
                .tightHeading(30)
                .foregroundStyle(OrbitColor.ink)
                .padding(.top, 30)

            OrbitField(label: "Your name", placeholder: "First name is plenty",
                       text: $model.displayName)
                .padding(.top, 20)

            Text("Everyone in the orbit sees this, and everyone sees each other. Sharing is never one-way.")
                .font(OrbitFont.regular(14))
                .lineSpacing(3)
                .foregroundStyle(OrbitColor.neutral700)
                .padding(.top, 16)

            if let error = model.error {
                Text(error).caps(11, OrbitColor.red).padding(.top, 14)
            }

            Spacer(minLength: 16)

            OrbitButton(title: "Join", isBusy: model.isWorking,
                        isEnabled: !model.displayName.trimmingCharacters(in: .whitespaces).isEmpty) {
                model.join(token: token)
            }
            OrbitButton(title: "Not now", kind: .ghost) { model.pendingToken = nil }
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .screenGutters()
        .background(OrbitColor.bg)
    }
}
