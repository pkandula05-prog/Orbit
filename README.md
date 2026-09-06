# Orbit

A compass that points at your friends.

Orbit is a native SwiftUI app for iOS, built from the *Compass Face* design study. It is a
north-up dial: each tracked friend sits on the ring at their true bearing from you, a red body
marks where the phone is currently pointing, and a blue arc sweeps from north to that heading.
Under the heading readout each friend gets a signed delta — how far to turn to face them —
which flips from red to green once you are within 10°.

## Running it

Requires Xcode 16 or newer (the project uses file-system synchronized groups) and iOS 17.

```sh
open Orbit.xcodeproj
```

Pick the **Orbit** scheme and Run. Two things to set once, in *Signing & Capabilities*:

1. Choose your team. The bundle identifiers are `com.orbit.compass` and
   `com.orbit.compass.widgets`; change the prefix if that pair is taken.
2. Both targets declare the App Group `group.com.orbit.compass`, which is how the widgets see
   the dial. A free personal team cannot create App Groups — if signing fails, delete the
   capability from both targets, or remove the **OrbitWidgets** target entirely. The app falls
   back to standard user defaults on its own and keeps working; only the widgets go quiet.

**The compass needs real hardware.** On a device Orbit asks for location-when-in-use and reads
true heading from the magnetometer. In the Simulator there is no magnetometer, so the dial
sweeps at a steady 7°/s — enough to review layout and watch the deltas and on-target colours
change, but it is not a real bearing.

Long-press the **Compass** title on the dial to replay the onboarding flow from the start.

## The flow

Artboards 02–09 are steps of one journey, so the app animates between steps of a single view
rather than pushing navigation destinations. `Phase` in `Orbit/AppModel.swift` is the whole
map:

| Artboard | Screen | File |
| --- | --- | --- |
| 01 | App icon | `Tools/make_icon.py` → `Orbit/Assets.xcassets` |
| 02 | Launch | `Views/Onboarding/LaunchView.swift` |
| 03 | Your number | `Views/Onboarding/SignInView.swift` |
| 04 | Enter the code | `Views/Onboarding/VerifyView.swift` |
| 05 | Two permissions | `Views/Onboarding/PermissionsView.swift` |
| 06 | Invite friends | `Views/Onboarding/InviteView.swift` |
| 07 | Invites out | `Views/Onboarding/InviteSentView.swift` |
| 08 | Sharing request | `Views/Onboarding/ShareRequestView.swift` |
| 09 / 5a / 5b | Compass face | `Views/Compass/CompassFaceView.swift` |
| 6a / 6b / 6c | Widgets | `OrbitWidgets/OrbitWidget.swift` |

`5a` and `5b` are the same screen at different roster sizes, so the app switches on the tracked
count rather than routing between two screens: at three or more friends the numeral shrinks
from 66pt to 56pt and the deltas move from stacked rows to a two-column grid. Tap any tile in
the tracking row to add or drop someone and the layout follows.

## How the dial stays smooth

The magnetometer reports in bursts and jitters by a degree or two. Drawing those samples
directly makes the dial twitch, so nothing draws the sensor:

- `DeviceCompass` treats each sample as a *target* and runs a `CADisplayLink` at up to 120 Hz,
  easing the drawn angle toward it with a critically damped step (`Services/DeviceCompass.swift`).
  Frame-rate independent, and it never overshoots — on a compass, overshoot reads as the dial
  wobbling past the bearing. Turns take the shortest path, so 359° → 001° crosses north.
- The dial itself is one `Canvas` (`Shared/Dial.swift`), not a stack of shape views, so a
  heading change is a single redraw with no view-tree diffing and no layout.
- Text is bound to `wholeHeading` instead, which only changes when the whole degree does. The
  numbers never show fractions, so there is nothing to gain from recomputing them 120 times a
  second.

Everything else moves on springs rather than linear timings: the 5a → 5b numeral shift, the
step transitions, the tracking tiles, the request card dropping in.

## Where the friend locations come from

**Apple's Find My has no public API.** It is a closed system — there is no supported way for a
third-party app to read the locations of your Find My friends, and anything that claims to is
driving a private iCloud endpoint with your Apple ID credentials, which breaks as soon as Apple
changes it and puts your account at risk. Orbit does not do that.

Instead Orbit reads any feed you control, behind one protocol (`Orbit/Services/FriendSource.swift`):

- **`MockFriendSource`** — the roster from the artboards (Ana, Miles, Jae, Priya + four more) at
  the bearings and distances the design was drawn with, drifting slowly so the dial behaves like
  a live feed. It scatters that roster around *your* position once a real fix arrives, so the
  dial is useful wherever you run it. This is the default, so the app runs with no backend.
- **`RESTFriendSource`** — polls a JSON endpoint you host:

  ```json
  { "friends": [ { "id": "ana", "name": "Ana", "latitude": 37.7859,
                   "longitude": -122.4062, "updatedAt": 1757030400000 } ] }
  ```

Point the app at a real feed with build settings — no code change. Set `ORBIT_FEED_URL` (and
optionally `ORBIT_FEED_TOKEN`, sent as a bearer token) on the Orbit target; they are read
through `Info.plist` at launch.

If you want Find My-*like* behaviour, the shape that actually works is friends running Orbit and
opting into sharing, posting their own fixes to a backend you host, which then serves the
endpoint above. Everything on the client is already written against that.

## Sign-in and invites

There is no Orbit server in this repository, so `LocalAccountStore` stands in for one behind the
`AccountBackend` protocol: any six digits verify, invitations go out as *pending*, the artboard
roster is already sharing, and one invitee accepts a few seconds later so the "waiting on them"
state resolves in front of you. State persists to the App Group, so the flow is only walked
once per install. Swapping in a real backend means writing one more conformance to
`AccountBackend` and choosing it in `OrbitApp` — no screen changes.

## Widgets

`OrbitWidgets` ships all three widget artboards from one `Widget`: small (6a), medium (6b) and
lock-screen circular (6c). A widget cannot read the compass — an extension is woken for a
timeline, not run continuously — so the app writes the last dial it drew into the App Group and
the widgets render that. The heading on a widget is the last one you saw, not a live one.

WidgetKit archives a widget's view tree and replays it out of process, where `Canvas` cannot be
relied on to draw, so `Shared/StaticDialView.swift` builds the same dial from shapes. Both read
the same `DialStyle`, so the two cannot drift apart on geometry.

## Layout

```
Shared/          Geo, the compass model, theme tokens, both dial renderers, the App Group
                 snapshot, and Archivo — compiled into the app and the widget extension
Orbit/           The app: AppModel (the flow), Services (compass, feeds, accounts), Views
OrbitWidgets/    The widget extension
Config/          Info.plists and entitlements for both targets
Tools/           make_icon.py — renders the app icon from the artboard's geometry
```

`Shared/Geo.swift` holds pure functions — bearings, haversine distance, signed turn, formatting
— so the dial's numbers can be reasoned about without rendering anything.

## Known gaps

- The `modernist` design system's `styles.css` was not reachable when this was built, so the
  neutral ramp in `Shared/Theme.swift` and the button, field and tag styles are matched by eye
  against the values they sit between. Swap in the real ones if you have them.
- No friend-detail or map screen — the design study only covers the compass face.
- Stale fixes (older than five minutes) dim their ring marker but are not called out in text.
- The invite list is the demo roster, not the device's real contacts; reading those means
  adding `Contacts` and a usage string.
