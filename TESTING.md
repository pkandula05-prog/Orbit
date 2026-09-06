# Setting Orbit up and testing it

The order matters. Each phase assumes the one before it worked, and the point of the sequence is
that when something breaks you know which layer it is in.

---

## Phase 0 · Unstick Xcode

Do this first if Xcode has thrown anything vague — "Invalid argument", "damaged", a build that
fails with no message. In order, stopping when it works:

```sh
python3 Tools/check_project.py          # is the project file itself sound?
```
```sh
rm -rf ~/Library/Developer/Xcode/DerivedData/Orbit-*
```

Then quit Xcode entirely, reopen it, and re-pick the destination in the toolbar. A destination
that has gone away — an unpaired phone, a deleted simulator — produces exactly that error, and
so does a stale derived-data folder after a package is added.

---

## Phase 1 · Make it compile

The code has `import Supabase`, so **nothing compiles until the package is added**, whether or
not you intend to use a backend yet.

1. `git pull`
2. Open `Orbit.xcodeproj`.
3. **File → Add Package Dependencies…** → `https://github.com/supabase/supabase-swift` →
   Dependency Rule **Up to Next Major** from `2.0.0` → add the **Supabase** product to the
   **Orbit** target.
4. Build (⌘B).

If there is a wall of errors, hand the loop to a local Claude Code session rather than clicking
through them:

```sh
cd ~/Orbit && claude
```

> Read README.md. Build the Orbit scheme for the iOS Simulator and fix every compile error until
> it builds and launches. Check the real supabase-swift v2 API rather than guessing at it. Run
> `python3 Tools/check_swift.py` and `python3 Tools/check_project.py` after edits.

Do not go to Phase 2 until it launches.

---

## Phase 2 · Test the dial, with no backend

With no Supabase keys the app runs on `LocalOrbitService` — three people walking around you, and
one of them deliberately stops reporting so the staleness ladder is visible without waiting for a
friend to lose signal. Test this before adding a backend, so a broken dial and a broken database
can never be confused for each other.

**On a real device.** The Simulator has no magnetometer, so the dial sweeps at a steady 7°/s
instead of following you — useful for layout, useless for judging whether the compass works.

| Check | What you should see |
| --- | --- |
| Launch → Allow both | The empty dial, ring turning as you turn |
| Start an orbit → name → 1h | A link, and three people on the ring |
| Turn on the spot | Readout rows reorder — nearest-to-facing first |
| Face one of them | Their delta goes green within 10° |
| Wait ~90s, watch **Jae** | Marker dims, distance becomes a band ("500 m–1 km") |
| Wait ~10 min | Jae goes dashed, drops out of the readout, stays on the ring |
| Sheet → Leave | The explicit **ended** screen — not an empty dial |

The last one matters more than it looks. "Over" and "nobody here yet" being indistinguishable is
the failure that gets somebody lost.

---

## Phase 3 · Supabase

1. New project at [supabase.com](https://supabase.com).
2. **SQL Editor → New query** → paste all of `Supabase/schema.sql` → Run.
3. **Authentication → Sign In / Providers → Anonymous → enable.** Easy to miss, and nothing
   works without it: anonymous sign-in *is* the identity system.
4. **Project Settings → API** → copy the **Project URL** and the **anon public** key. Never the
   `service_role` key — it bypasses every policy in the schema.
5. Xcode → **Orbit** target → **Build Settings** → search `SUPABASE` → set `SUPABASE_URL` and
   `SUPABASE_ANON_KEY` on **both** Debug and Release.
6. Rebuild, start an orbit, and check **Table Editor → orbits** has a row. If it does, the client
   is talking to the database and everything after this is about behaviour, not wiring.

---

## Phase 4 · Two people

You do not need a second person. **Your phone plus a Simulator** is a real two-participant test.

1. Run on your **real iPhone**. Start an orbit. Share the link to yourself and copy the token —
   the part after `/j/`.
2. Run the same build on a **Simulator**.
3. Give the simulator a position: **Features → Location → Custom Location**, a few hundred metres
   from you. The fourth decimal of latitude is about 11 metres.
4. Hand it the link:

```sh
xcrun simctl openurl booted "orbit://join/PASTE_TOKEN_HERE"
```

5. Type a name on the simulator. On your phone you should get **"<name> joined"**, a new marker
   at the right bearing, and a marker that moves when you change the simulator's location.
6. Leave on the simulator → your phone announces **"<name> left"** and dims them.
7. End the orbit on your phone → the simulator lands on the ended screen, and **Table
   Editor → positions** is empty for that orbit.

### Try to break it

These are the rules the database is supposed to hold on its own, so they are worth attacking:

- Use the join link **after the orbit ends** → "That orbit has ended."
- Use a link **over an hour old** while the orbit is still alive → refused. The link is a
  shorter-lived capability than the orbit on purpose.
- **Extend twice** on a 24-hour orbit → remaining time never exceeds 24 hours.
- Get a **seventh** person in → refused at six.

---

## When something is wrong

| Symptom | Where to look |
| --- | --- |
| "Anonymous sign-ins are disabled" | Phase 3, step 3 |
| Orbit creates, but nobody ever appears | Is there a row in `positions`? If yes, it is a read policy; if no, it is publishing |
| Everyone permanently "degraded" | The publish interval is slower than the 90s fresh window. `AppModel.publish` sets 5s foreground / 45s background — those are guesses and want tuning against reality |
| Dial does not move on a device | Location permission, then compass calibration. In the Simulator it sweeps by design |
| Xcode says "damaged" or "Invalid argument" | Phase 0 |

The foreground and background publish intervals are the numbers most likely to be wrong. They
are only meaningful relative to the staleness tiers, and the only way to settle them is a real
phone in a real pocket — not a desk.
