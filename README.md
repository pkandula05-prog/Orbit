# Orbit

A compass that points at the people you are with, for as long as you are with them.

Orbit is a native SwiftUI app for iOS. It is a north-up dial: everyone in your orbit sits on the
ring at their true bearing from you, a red body marks where the phone is pointing, and a blue arc
sweeps from north to that heading. Under the heading, each person gets a signed delta — how far
to turn to face them — which flips from red to green once you are within 10°.

**Nobody is ever on your dial by default.** There is no friend list, no username, no contact
matching, no follow request. You create an *orbit*, share a link, and it ends: by expiry, by the
host closing it, or by everyone leaving. Sharing that has to be revoked is sharing you forgot
about; an orbit expires whether or not anyone remembers it.

## Running it

Requires Xcode 16 or newer and iOS 17. There are no entitlements to provision and no App Group —
signing is picking your team.

```sh
open Orbit.xcodeproj
```

**The compass needs real hardware.** In the Simulator there is no magnetometer, so the dial
sweeps at a steady 7°/s — enough to review layout and watch the deltas change, but not a real
bearing. With no Supabase project configured the app runs on `LocalOrbitService`: three people
walk around you, and one of them goes quiet after a minute so the staleness tiers are visible
without waiting for a friend to lose signal.

## The model

| | |
| --- | --- |
| Duration | 1, 6, 12 or 24 hours, chosen at creation. **No indefinite option.** |
| Extending | Host only, from inside the app, capped so remaining time never exceeds 24 hours |
| Size | 6 including the host |
| Visibility | Symmetric. Everyone sees everyone; there is no one-directional sharing |
| Joining | Tap the link, grant permissions, type a name. **No accept step** |
| The link | Dies after ~1 hour, or when the orbit fills, whichever is first. The host can regenerate it, which revokes the old one |
| Leaving | One tap, any participant, without ending it for anyone else. Announced by name |
| Ending | Host ends it · the clock runs out · everyone leaves |
| After | Positions are deleted. No history, no replay, no "last seen" outside an orbit |

Identity is **anonymous**. The app signs the device in with no account at all, because the link
is the identity mechanism. A display name is asked for at the moment you first create or join —
free text, not unique, and never before it is needed.

## What the dial says, and how honestly

The number under someone's name has to degrade with what is actually known about them, or it
lies. Three things vary:

**Distance.** Under a kilometre, a precise delta and a precise distance — turn your head and
you are facing them. Beyond that a degree is not actionable, so the row shows an eight-point
bearing and a rounded distance instead. Nothing is ever cut off: a far participant is not
inactive, and marking them so would wrongly say they dropped out.

**Freshness**, by the age of their last fix:

| Age | State | Treatment |
| --- | --- | --- |
| under 90s | Fresh | Full precision |
| 90s – 10 min | Degraded | Marker dims; distance becomes a band, not a figure |
| over 10 min | Ghost | Drops out of the readout; stays on the ring, dashed, with how long ago |

Ghosts stay on the ring deliberately. Removing the dot reads as "they left" and sends people the
wrong way. **Far and stale are visually distinct** — far means we know where they are and it is
not a turn-your-head number; stale means we do not know where they are.

**Crowding.** In a real crowd several people sit within a few degrees and their dots merge, so
overlapping markers are nudged apart on the ring — and only on the ring. `DialMarker.bearing`
keeps the truth and the readout quotes that, so a nudged dot never makes the numbers lie.

The readout shows four rows, ordered by how far you would have to turn, so it reorders as you
turn and answers "who is that way". With more than four, tapping it pages through.

**Cold open**: opening the app draws the last positions it saw, greyed and marked stale, then
lets them resolve. Stale-but-labelled beats empty.

## Viewing and publishing are different problems

- **Viewing is foreground-only.** No widget, no Live Activity, no Dynamic Island. Heading is
  foreground-only at the OS level anyway, and a home screen widget cannot read the compass at
  all — there is no API, and WidgetKit reloads an extension a few dozen times a day. A live dial
  there was never possible, so there isn't one.
- **Publishing runs in the background.** If people only published while looking at the app,
  everyone would go stale the moment they pocketed their phone. An active orbit turns on
  background updates; the foreground uses a tighter interval and better accuracy, because the
  person actually reading the dial is the one who needs precision and can see the battery cost.
- **No orbit, no location updates at all.** Background access is asked for in the context of
  joining, and publishing stops the moment the last orbit ends.

The publish interval and the freshness tiers only mean something together: if the background
interval were longer than the fresh window, everyone would be permanently degraded. Verify that
on a real device in a real pocket, not on a desk.

## Connecting it to Supabase

The app runs with no configuration. Fill in two build settings and it switches to the real
backend automatically — there is no flag.

1. **Create a project** at [supabase.com](https://supabase.com).
2. **Run `Supabase/schema.sql`** in *SQL Editor → New query*. Read it: the rules the app depends
   on are policies and functions there, not Swift.
3. **Turn on anonymous sign-ins**: *Authentication → Sign In / Providers → Anonymous*. This is
   the whole identity system; no SMS provider is needed.
4. **Copy the keys** from *Project Settings → API* — the Project URL and the **anon public** key.
   Never the `service_role` key; it bypasses every policy.
5. **Set them in Xcode**: Orbit target → *Build Settings* → `SUPABASE_URL` and
   `SUPABASE_ANON_KEY`, on Debug and Release.
6. **Add the SDK**: *File → Add Package Dependencies…* → `https://github.com/supabase/supabase-swift`
   → Up to Next Major from 2.0.0 → add **Supabase** to the Orbit target.

### What the database enforces, so the app cannot get it wrong

- A position row is readable **only** by a fellow participant of the same orbit, **only** while
  that orbit is active, and **only** if the reader has not left. Realtime honours the same
  policy, so the client subscribes to everything and is handed only what it may see.
- Writes are refused once an orbit ends, whatever a client believes about the time.
- The join token is checked server-side for liveness, orbit liveness, and the six-person cap in
  a single function. A patched client cannot argue its way past any of the three.
- Extension is capped against `now()`, not against the previous expiry, so repeated calls can
  never push an orbit past a day of remaining life.

## Layout

```
Shared/    Geo (bearings, distance, banding), the orbit model and its readings, the dial,
           theme tokens, the app mark, Archivo
Orbit/     AppModel (the whole lifecycle), Services (compass, OrbitService + Supabase), Views
Supabase/  schema.sql — tables, policies, and the operations as functions
Tools/     check_project.py, check_swift.py, make_icon.py
```

`Shared/Geo.swift` and `Shared/Orbit.swift` are pure functions and values — every number the dial
shows can be reasoned about without rendering anything.

## Deliberately not built

Be sceptical when these come up again: arrival or proximity notifications, geofences, location
history or replay, "last seen" outside an active orbit, any map view, messaging, places, groups,
and home screen widgets.

## Known gaps

- The `modernist` design system's `styles.css` was not reachable when this was built, so the
  neutral ramp and the button, field and tag styles in `Shared/Theme.swift` are matched by eye.
- Deep links use the `orbit://` scheme. Shipping needs a universal link and an
  `apple-app-site-association` file, so a tap opens the App Store for someone without the app.
- Optional accounts, so orbits survive a reinstall, are not built. Anonymous identity is lost
  with the app.
- Compass confidence is not surfaced. Magnetic interference in stadiums and malls is severe, and
  the dial should say when it does not trust itself rather than smoothing over it.
- No vertical axis: someone a floor above reads as on top of you.
- Host leaving ends the orbit, rather than transferring to the longest-present participant.
