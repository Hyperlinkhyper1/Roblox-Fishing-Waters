# Why Fisch feels chill — and what Fishing Waters borrows

Living research notes. Come back here before touching ambience, music, water
visuals or "world feels empty" problems. Add to the log at the bottom whenever
something is tried, kept or reverted.

Started 2026-11-01 from playtest screenshots of Fisch (Moosewood, Roslit
Hamlet, night, Fischfright/Halloween event) compared side by side with Fishing
Waters.

---

## 1. What makes Fisch feel the way it does

### 1.1 Sound does most of the work

- **Real field recordings, layered.** Wind, waves lapping on docks and beaches,
  and gulls are recorded sounds, not synthesized noise. Several quiet layers
  play at once and none of them is the "main" sound. That is the standard
  game-audio approach: a continuous **bed** (water lap, air) plus **one-shots**
  sprinkled on top (gull calls, creaks). Randomized timing, pitch and position
  hide the loop, so you never notice the bed repeating
  ([CRI ambience design](https://blog.criware.com/index.php/2020/12/14/ambience-design-in-atom-craft-part-1-2/),
  [bugnet: ambient sound layers](https://bugnet.io/blog/how-to-design-ambient-sound-layers),
  [Designing Sound: room tone](https://designingsound.org/2012/11/15/room-tone-emotional-tone-the-importance-of-hearing-ambience)).
- **The sea sounds different from the shore.** On a dock you hear water slapping
  wood. On a beach you hear waves rolling up the sand. Out at sea it is a wide,
  soft wash with wind. Changing the layers by location is what makes moving
  around feel like travelling.
- **Music is slow and never has a strong beat.** On land it is warm acoustic
  guitar. At sea it turns ominous: dark drones and sparse piano that make the
  open water feel deep and a little threatening. No big hits or percussion
  builds, so it still sits *under* the waves instead of on top of them.
- **Music leaves room.** Music sits low in the mix and the ambience carries the
  space between tracks. Minecraft-style breathing room keeps the music from
  becoming wallpaper.

### 1.2 The water is alive

- **You see fish swimming.** Fisch's *Roaming Fish* update made fish visibly
  swim in every body of water, and casting near one strongly favours that
  species. Roaming fish are the existing species shown in the world, still bound
  to each island's bestiary — not a separate catalogue
  ([allthings.how: Roaming Fish update](https://allthings.how/fisch-roaming-fish-update-waterpark-and-crews-changes-explained/),
  [ProGameGuides: Roaming fish & spear guide](https://progameguides.com/roblox/complete-roaming-fish-spear-hunting-guide-fisch/),
  [patch notes](https://allthings.how/fisch-roaming-fish-update-patch-notes/)).
  Even without the gameplay hook, motion under the surface tells you there is
  something to catch here.
- **Shallow, readable water near docks.** You can see the bottom and the
  pilings next to the piers, so the shoreline has depth instead of being a flat
  sheet.

### 1.3 The towns are dense and hand-placed

From the screenshots: every few studs there is a prop — barrels, crates,
lanterns, pumpkins, flower patches, cobwebs, fences, string lights, rods
leaning on walls, a rowboat at the dock. Warm point lights pool on paths at
night. NPCs (Merchant, Shipwright, Angler [Quests]) stand at their stalls with
floating name tags, so the town reads as *inhabited*. Paths are textured sand
with ripples, not flat colour.

### 1.4 Low-pressure loop, small HUD

- The developer drew on Stardew Valley and Animal Crossing for the relaxed
  pace, against Roblox fishing games that felt grindy
  ([Roblox Wiki: Fisch](https://roblox.fandom.com/wiki/Fisching/Fisch)).
  Island-to-island progression from Moosewood, with a bestiary per island
  ([esports.gg: Moosewood bestiary](https://esports.gg/guides/roblox/moosewood-bestiary-in-fisch-a-complete-list-and-guide/)).
- Fish need bait, weather, time of day and the right spot, so *waiting* for the
  right moment is part of the game instead of downtime.
- A small HUD: compass at the top, hotbar at the bottom, level and cash in the
  corner, an area title ("• Moosewood •") that fades in when you arrive.
- The global catch feed in chat ("X caught a Divine Secret 1/250000") is
  constant social proof that rare things happen, without interrupting anyone.

### 1.5 Caveat on sources

Web coverage of Fisch is mostly thin or SEO filler. Treat 1.1 and 1.3 as
first-hand playtest observations, and 1.2 and 1.4 as backed by the cited guides
and patch notes. No developer postmortem was found.

---

## 2. Gap analysis vs Fishing Waters (2026-11-01)

| Fisch has | Fishing Waters before | Status |
| --- | --- | --- |
| Recorded surf, water lap, gulls | `EnvironmentAudio` played Roblox's bundled *falling wind* clip through an EQ as "OceanWaves" | **Added** recorded layers in `CoastalAmbience` (kept the synthetic bed underneath) |
| Shore vs dock vs open sea sound | One wash whose volume depends on distance to water | **Added**: surf near land, lap bed on open water, hull lap when close to the water |
| Gulls by day, crickets at night | Nothing | **Added**: positional gull one-shots in daytime near land, crickets at night near land |
| Piano + guitar ~80 BPM at sea | Orchestral KPM "Soft Horizons" | **Replaced** the Ocean playlist with acoustic piano/guitar APM tracks |
| Breathing room between tracks | 3 s gap | **Changed** to a random 10–25 s gap at sea |
| Visible fish swimming | No fish in the water (sharks only) | **Added** `AmbientFish`: client-only schools of species from the local pool |
| Area title on arrival | Exists (`BiomeAtmosphere`) | Already there |
| Dense hand-placed props, warm lights | Sparser towns | Backlog |
| Roaming fish affect catch odds | — | Backlog (gameplay, needs server) |

---

## 3. What was built (and where)

### 3.1 `src/client/CoastalAmbience.luau`

Recorded layers on top of `EnvironmentAudio`'s synthetic wash. Every 0.5 s it
samples Terrain around the camera (two rings of 8 probes at 45 and 110 studs,
one probe straight down and one roof check) to estimate how much land and how
much water is nearby. Test: `node scripts/check-coastal-ambience.mjs`.

| Layer | Plays when | Asset |
| --- | --- | --- |
| `SeaLap` bed | Over or near open water, louder close to the surface (docks, boats) | `9116203162` Lake Lap Water Movement 2 (46 s) |
| `HullLap` | Camera within ~10 studs of the surface | `9113665498` Calm Water Lap 2, against side of boat (54 s) |
| `ShoreSurf` | Land and water both nearby (beaches, harbour edges) | `9119676800` Surf Medium CU, Tide Rollup 3 (57 s) |
| `Crickets` | Night, land nearby | `9112762877` Crickets And Frogs 3 (41 s) |
| Gull one-shots | Day, land within range, not raining; every 9–26 s, random position 35–80 studs away and 12–35 up, random pitch | `9118858259`, `9118858279`, `9118858265` Seagull Squawks 1–3 |

Underwater and indoor (roof overhead) both duck everything. Storms raise the
surf and silence the gulls. All sounds use `AudioCategory = "Effects"`, so the
Effects slider applies.

### 3.2 `src/client/BackgroundMusic.luau` — Ocean playlist

Made ominous on 2026-11-07 (was soft piano/guitar). All APM, slow or
no-tempo beds without jump-scare hits.

| Asset | Track | Why |
| --- | --- | --- |
| `9039978890` | Ominous (Bruton TV Series) | "Evolving atmospheric pads and foreboding drones beneath scratching string pulses" |
| `1837115429` | Foreboding (Bibliotheque) | "Dark, sparse piano bed with atmospheric elements drifting in and out. Minimal and edgy." |
| `9042795293` | Feeling Of Foreboding (Kosinus) | "SLOW - Ominous, Bleak, Evolving Drone, Synth Pulse, Sustained Strings, Sparse Piano" |
| `1838762089` | Tactics of the Sublime (Kingdom 2) | "Deep and ominous synth tones drone on throughout alien atmospheres" |
| `1837598570` | Dark Deep Sea | Title only (no store description) |
| `1847182538` | Deep Sea Mystery (Henri Poch) | Title only (no store description) |
| `1842765800` | Deep Foreboding (James Asher) | Title only; same composer as the island's *Twilight Beach* |

Ocean volume went from 0.2 to 0.26 because drones are mastered quieter.

**Not yet listen-tested in Studio.** Only the store metadata was checked. If a
track turns out too horror-ish (big hits, screams), swap it for a spare in §5.

The old acoustic sea picks (`1838786430` The Grace and the Gamble,
`1846315728` Andante for Guitar and Piano, `9045573146` No Clouds Outside,
`1839919231` Lonely Promises, `1839967674` In Five (b), `1837380492` Happy
Birds Fly) would still suit a calm-weather or lagoon playlist.

### 3.3 `src/client/AmbientFish.luau`

- Client-only and cosmetic: no server load, no replication.
- Up to 6 schools of 3–6 fish within ~150 studs of the camera, recycled when
  they fall behind. Each school picks a species from the pool the camera is in
  (`MainLake` inside the bay, `OpenSea` elsewhere), weighted by
  `1 / RarityDenominator`, so commons are what you usually see. Crabs, mussels,
  sea cucumbers, shrimp, plants and junk never swim.
- Fish swim 1.5–5 studs under the surface where the seabed is deep enough, so
  they read through the 0.3 water transparency. Each school wanders, the fish
  hold loose offsets around the school centre, the bodies wiggle by yawing,
  and schools scatter away from the local character when it swims close.
- Performance: every visible part is welded to one anchored root, so a frame
  moves ~30 roots with a single `BulkMoveTo`, not every fin. Fish parts are
  `SeasonExempt` so `SeasonFoliage` doesn't keep references to recycled fish.
- Test: `node scripts/check-ambient-fish.mjs`.
- Knobs at the top of the file: `MAX_SCHOOLS`, `SCHOOL_SIZE`, `DEPTH`,
  `SPEED`, `SPAWN_DISTANCE`.

---

## 4. Backlog (ranked by feel-per-effort)

1. **Listen-test and look-test in Studio**: the music picks and layer volumes
   (`VOLUMES` / `MIX` tables). Recorded loops can have a click at the seam. If
   one does, swap it for a sibling take (most PSE assets come in 1/2/3
   versions). If the fish are hard to see from a dock, the first knob is
   surface `WaterTransparency` (0.3 in `BiomeAtmosphere` and `Map/init`).
   Fisch's water near docks reads clearer, so try around 0.45. Second knob:
   lower `DEPTH`.
2. **Prop density pass on the harbour and beach**: barrels, crates, lanterns,
   rope coils, leaning rods, flower patches every few studs along paths, with
   warm `PointLight`s on lanterns that turn on at dusk.
3. **Shallow-water shelf around docks**: raise the seabed near piers so the
   bottom is visible, and add pilings into the water.
4. **Roaming fish → gameplay**: casting near a school boosts that species
   (needs a server-authoritative fish position or a seeded shared simulation).
   Spear fishing could target them directly.
5. **Dock creaks**: positional one-shot wood creaks on piers and moored boats
   (`9114496654` "Floor Creaks, Possible Use: Rope or Boat Creaks").
6. **Global catch feed**: rare catches announced in chat like Fisch's
   `[Global]` lines.
7. **Biome-specific beds**: jungle birds in Tropical, volcanic rumble near the
   Volcanic island, ice creaks in Ice.

---

## 5. Finding licensed audio (how these IDs were found)

Roblox licenses two libraries every experience can use for free:

- **ProSoundEffects** (creator `ProSoundEffects`): sound effects and
  ambiences, IDs around `911xxxxxxx`–`912xxxxxxx`. Descriptions list the
  recording location and whether the clip loops.
- **APM Music** (creator `APMOfficial`): music. Descriptions often include
  genre, library and album, sometimes BPM.

The Creator Store search API works without auth:

```
https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=Audio&query=<words>&maxPageSize=100
```

Filter `creatorStoreAssets[].creator.name` to `ProSoundEffects` /
`APMOfficial`, then read `asset.durationSeconds` and `asset.description`. For a
single asset: `https://economy.roblox.com/v2/assets/<id>/details`.

Other candidates found but not used yet:

| Asset | What | Possible use |
| --- | --- | --- |
| `9112829678` | Marina Ambience 5 — rigging, boat creaks, gulls (62 s) | Harbour bed (has distant traffic) |
| `9113592288` | British Surf Birds 7 — gulls, waves on rocks (56 s) | Rocky coast bed |
| `9117131996` | Oahu Surf on Rocks, sloshy (112 s) | Rocky island shores |
| `9120571364` | Water Lap Deep Glugs 2 — under dock, distant birds (58 s) | Under-pier bed |
| `9112750614` | Bow Wash, diesel fishing boat, trolling (36 s) | Boat motion layer |
| `9112865277` | Sailboat Wake 3 — middle-of-ocean ambience (66 s) | Sailing |
| `9112870623` | Seagulls 1 — flock overhead, distant (34 s) | Busy harbour |
| `1838786269` etc. | Rest of *Charming and Sincere* (Merced Falls, Sonora, Ypsilanti, Angels Camp…) | Calm acoustic sea music — untested tempo |
| `9045015599` | Vortex, drone only mix ("dark and eerie soundscapes") | Ominous sea spare |
| `92305230618831` | Ominous Presence AMBIENT MIX (179 s) | Ominous sea spare |
| `125322520450801` | Haunting Memory Underscore Ambient Only (188 s) | Ominous sea spare |
| `1847648166` | Lurking Depths B | Ominous sea spare (no description) |
| `1841178209` | Black Tide (a) | Ominous sea spare (no description) |
| `9040206659` | Spatial Abyss (a): "deep, intense hybrid drone… sparse sub booms" | Storms / deep water — may be too heavy |
| `1842613995` etc. | Easy Acoustic Chill (current Island playlist) | Already used on land |

---

## 6. Log

- **2026-11-01**: First pass. Wrote this doc and added `CoastalAmbience` and
  `AmbientFish`. Replaced the orchestral sea playlist with piano/guitar and
  made the sea gaps longer. Kept `EnvironmentAudio`'s synthetic wash as a quiet
  bed under the recordings (its tests deliberately forbid a looping clip with
  splash impacts as its own sound). Both new modules pass their mock checks;
  the existing environment-audio, shark-swim, loading and world-startup checks
  still pass. Not yet heard or seen in Studio.
