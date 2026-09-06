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
2. Nothing else. There are no entitlements and no App Group to provision — the Live Activity
   carries its own state — so a personal team is enough to build and run.

**The compass needs real hardware.** On a device Orbit asks for location-when-in-use and reads
true heading from the magnetometer. In the Simulator there is no magnetometer, so the dial
sweeps at a steady 7°/s — enough to review layout and watch the deltas and on-target colours
change, but it is not a real bearing.

Long-press the **Orbit** title on the dial to replay the onboarding flow from the start.

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
| 06 | Friends and invites | `Views/Friends/FriendsView.swift` |
| 07 | Invites out | `Views/Onboarding/InviteSentView.swift` |
| 08 | Sharing request | `Views/Friends/InvitesView.swift` (the bell's inbox) |
| 09 / 5a / 5b | Orbit (the dial) | `Views/Compass/CompassFaceView.swift` |
| — | Live Activity | `OrbitWidgets/OrbitLiveActivity.swift` |

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

## Sign-in, friends and invites

There is no Orbit server in this repository, so `LocalAccountStore` stands in for one behind
the `AccountBackend` protocol (`Orbit/Services/AccountService.swift`). Swapping in a real
backend means one more conformance and a line in `OrbitApp` — no screen changes. The contract
each method stands for:

| Call | Endpoint | Behaviour the client relies on |
| --- | --- | --- |
| `isUsernameAvailable` | `POST /username/check` | `{ "username": "ana" }` → `{ "available": false }`. Case-insensitive, unreserved, and **not** authoritative: the server must re-check at verify and reject a race with `409 username_taken`. |
| `sendCode` | `POST /auth/code` | `{ "phone": "+14155550134" }` → `{ "sent": true }`. Rate-limit per number. |
| `verify` | `POST /auth/verify` | `{ "phone", "code", "profile": { firstName, lastName, username } }` → session token; creates the account. Enforces username uniqueness here, not only at check time. |
| `match` | `POST /contacts/match` | `{ "hashes": ["<sha256(e164 + salt)>"] }` → the accounts that matched. Send hashes, never the address book in the clear, and never store the ones that miss. |
| `invites` | `GET /invites` | Both directions: `{ "incoming": [...], "outgoing": [...] }`. |
| `invite` | `POST /invites` | `{ "userIds": [...] }` → pending. **Creates no sharing relationship.** |
| `inviteByPhone` | `POST /invites/sms` | `{ "phone": "+1..." }` → sends an invite link to someone with no account; the relationship is created when they join and accept. |
| `respond` | `POST /invites/{id}/respond` | `{ "accept": true }` → sharing becomes mutual, in both directions, and both parties are notified. `false` shares nothing and tells the sender nothing beyond a decline. |
| `events` | SSE `GET /events` or a socket | `invited` and `accepted` pushes, so the bell's badge and the dial update without a poll. |

**Sharing is never implied.** Being matched from an address book, sending an invite, or
receiving one puts nobody on anybody's dial. `Contact.Relation.sharing` is the only state that
carries a location, and it is reached solely through `respond(to:accept: true)` — the server
must hold the same invariant, and should reject any location read for a pair that is not
mutually sharing.

Contacts are read only when someone taps **Match contacts** on the friends page
(`ContactsAccess.requestAndFetch`), and location and compass access are asked for only on the
permissions screen (05). Launching the app raises no system prompt.

## The Live Activity

There are no home screen widgets. A widget extension cannot read the compass — there is no API
— and WidgetKit reloads it on a budget of a few dozen times a day, so a dial that follows you
was never possible there. Rather than ship one that lies, the app ships the surface that does
work.

A **Live Activity** (`Shared/OrbitActivity.swift`, `OrbitWidgets/OrbitLiveActivity.swift`) is
pushed *by the app*, so `LiveDial` updates it on every whole degree of heading and every new
fix: the Lock Screen dial turns with the one on screen. It starts when you open the orbit with
someone tracked and ends when you stop tracking everyone.

- Starting one escalates location access from when-in-use to **always**. Without that it
  freezes as soon as the phone goes in a pocket, which is when a Lock Screen dial earns its
  place. Declining is fine — it then only updates with the app open.
- ActivityKit requires a Dynamic Island presentation and offers no way to decline one, so it is
  kept to the minimum the API accepts: the heading, nothing else.
- The app needs no App Group and no entitlements file: activity state travels through
  ActivityKit, not a shared container. Signing is a team selection and nothing more.

## Layout

```
Shared/          Geo, the compass model, theme tokens, both dial renderers, the dial snapshot
                 and Archivo — compiled into the app and the Live Activity extension
Orbit/           The app: AppModel (the flow), Services (compass, feeds, accounts), Views
OrbitWidgets/    The Live Activity extension
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

## Connecting it to Supabase

The app runs on `LocalAccountStore` and the mock feed with no configuration at all. Fill in two
build settings and it switches to a real backend — the code picks Supabase over the stand-in
automatically, so there is no flag to flip.

**1 · Create the project.** At [supabase.com](https://supabase.com) → *New project*. Pick a
region near you and save the database password somewhere.

**2 · Create the schema.** In the project, *SQL Editor* → *New query*. Paste the whole of
`Supabase/schema.sql`, run it. That builds the tables, the row level security policies and the
functions. Read the comments in it — the rule that a position is readable only where sharing is
mutual and accepted is a policy, so no bug in this app can leak a location.

**3 · Turn on SMS sign-in.** *Authentication → Sign In / Providers → Phone*, enable it, and give
it an SMS provider. Twilio is the usual choice: sign up, get the Account SID, Auth Token and a
sending number from its console, paste them in. A Twilio trial can only text numbers you have
verified with Twilio — fine for you and one friend, which is what testing sharing needs.

**4 · Copy the keys.** *Project Settings → API*. Take the **Project URL** and the **anon public**
key. Never the `service_role` key — that one bypasses every policy and must not ship in an app.

**5 · Put them in the build settings.** In Xcode select the **Orbit** target → *Build Settings*
→ search `SUPABASE`. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` on both Debug and Release. They
reach the app through `Info.plist`, so they stay out of source. (If you would rather not commit
them at all, move them to an untracked `.xcconfig`.)

**6 · Add the SDK.** In Xcode: *File → Add Package Dependencies…*, enter
`https://github.com/supabase/supabase-swift`, choose *Up to Next Major* from 2.0.0, and add the
**Supabase** product to the **Orbit** target only — the Live Activity extension does not talk to
the network.

**7 · Run it.** Sign up with a real number. Check the *Table Editor* in Supabase: your row
should be in `profiles`. Send an invite to a second account, accept it from that device, and
`locations` starts filling in.

### What still needs building

- **`invite-sms`** — inviting a number with no account calls a Supabase Edge Function of that
  name, which does not exist yet. Until it does, that button will fail. It needs to send an SMS
  with an install link and record the pending invite.
- **Push notifications** for invites. The app hears about them over Realtime while it is open;
  a closed app needs APNs, which your paid developer account covers.
- **Phone number normalisation** is deliberately naive (assumes +1 when no country code).
  Swap in libPhoneNumber before this meets anyone outside one country.
- **Contact matching sends numbers to the server** for the length of the call. Hashing them
  client-side would not fix it — the phone number space is small enough to brute-force — so the
  honest fix is private set intersection, which is out of scope here. The function does not
  store what it is given.
