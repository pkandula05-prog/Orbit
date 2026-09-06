import SwiftUI

/// The roster along the bottom. Tapping a tile adds or drops that friend, and the dial's
/// layout follows the count.
struct TrackingRow: View {
    var friends: [FriendReading]
    var trackedIDs: [String]
    var isAtCapacity: (String) -> Bool
    var onToggle: (String) -> Void

    /// The artboards show four tiles and a `+N More` counter rather than a long scroll.
    private let visible = 4

    private var shown: [FriendReading] {
        let tracked = friends.filter(\.tracked)
        let rest = friends.filter { !$0.tracked }
        return Array((tracked + rest).prefix(visible))
    }

    private var overflow: Int { max(0, friends.count - shown.count) }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(shown) { friend in
                let atCapacity = isAtCapacity(friend.id)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        onToggle(friend.id)
                    }
                } label: {
                    VStack(spacing: 6) {
                        InitialBadge(initial: friend.initial, size: 54, filled: friend.tracked)
                        Text(friend.name)
                            .caps(11, friend.tracked ? OrbitColor.ink : OrbitColor.neutral700)
                            .lineLimit(1)
                    }
                    .frame(width: 54)
                    .opacity(atCapacity ? 0.35 : 1)
                }
                .buttonStyle(.plain)
                .disabled(atCapacity)
                .accessibilityLabel("Track \(friend.name)")
                .accessibilityAddTraits(friend.tracked ? [.isSelected] : [])
            }

            if overflow > 0 {
                VStack(spacing: 6) {
                    InitialBadge(initial: "+\(overflow)", size: 54, filled: false)
                    Text("More").caps(11, OrbitColor.neutral700)
                }
                .frame(width: 54)
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: trackedIDs)
    }
}
