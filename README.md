# Orbit

A compass that points at your friends.

Orbit is an Expo / React Native phone app built from artboards **5a** and **5b** of the
*Compass Face* design study. It is a north-up dial: each tracked friend sits on the ring at
their true bearing from you, a red body marks where the phone is currently pointing, and a
blue arc sweeps from north to that heading. Under the heading readout, each friend gets a
signed delta — how far to turn to face them — which flips from red to green once you are
within 10°.

## The two states

`5a` and `5b` are the same screen at different roster sizes, so the app switches between
them on the tracked count rather than routing between two screens:

| | `5a` — up to 2 tracked | `5b` — 3 or more tracked |
| --- | --- | --- |
| Heading numeral | 66pt | 56pt |
| Deltas | stacked rows, name left | two-column grid, name above |
| Header right | altitude | tracked count |
| Footer | each friend's distance | nearest / farthest |

Tap any tile in the tracking row to add or drop a friend and the layout follows.

## Where the friend locations come from

**Apple's Find My has no public API.** It is a closed system — there is no supported way for
a third-party app to read the locations of your Find My friends, and anything that claims to
do so is driving a private iCloud endpoint with your Apple ID credentials, which breaks as
soon as Apple changes it and puts your account at risk. Orbit does not do that.

Instead Orbit reads any feed you control, behind one interface:

```ts
interface FriendLocationSource {
  readonly id: string;
  readonly label: string;
  subscribe(onUpdate: (friends: FriendLocation[]) => void): () => void;
}
```

Two implementations ship with the app:

- **`createMockSource()`** (`src/services/mockSource.ts`) — the roster from the artboards
  (Ana, Miles, Jae, Priya + four more) at the bearings and distances the design was drawn
  with, drifting slowly so the dial behaves like a live feed. It scatters that roster around
  *your* position once a real fix arrives, so the dial is useful wherever you run it. This is
  the default, so the app runs with no backend.
- **`createRestSource()`** (`src/services/friendLocations.ts`) — polls a JSON endpoint:

  ```json
  {
    "friends": [
      { "id": "ana", "name": "Ana", "latitude": 37.7859, "longitude": -122.4062, "updatedAt": 1757030400000 }
    ]
  }
  ```

Point the app at a real feed with environment variables — no code change:

```sh
EXPO_PUBLIC_ORBIT_FEED_URL=https://your-service.example/friends
EXPO_PUBLIC_ORBIT_FEED_TOKEN=…   # optional, sent as a bearer token
```

If you want Find My-*like* behaviour, the shape that actually works is friends running Orbit
and opting into sharing, posting their own fixes to a backend you host, which then serves the
endpoint above. Everything on the client is already written against that.

## Running it

```sh
npm install
npm start        # then press i / a, or scan the QR code with Expo Go
npm run web      # renders through react-native-web
```

The compass needs real hardware. On a device Orbit asks for location-when-in-use and reads
true heading from the magnetometer via `expo-location`. On web and in simulators there is no
compass, so the dial sweeps at a steady 7°/s — enough to review layout and see the deltas and
on-target colours change, but it is not a real bearing.

## Layout

```
src/
  components/     CompassRing (the SVG dial), CompassReadout, TrackingRow
  hooks/          useHeading, useOwnLocation, useFriendLocations
  lib/            geo.ts (bearing, distance, formatting), compassModel.ts
  screens/        CompassFaceScreen
  services/       FriendLocationSource, the mock and REST feeds
  theme/          colours and type from the modernist design system
```

`src/lib/` holds pure functions — bearings, haversine distance, signed turn, formatting — so
the dial's numbers can be reasoned about without rendering anything.

## Known gaps

- The `modernist` design system's `styles.css` was not reachable when this was built, so the
  neutral ramp in `src/theme/tokens.ts` is matched by eye against the background and ink
  values it sits between. Swap in the real values if you have them.
- No friend-detail or map screen yet — the design study only covers the compass face.
- Stale fixes (older than five minutes) dim their ring marker but are not called out in text.
