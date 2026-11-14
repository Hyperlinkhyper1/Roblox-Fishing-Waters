# Client performance

Boat effects keep motion smooth while bounding work that does not need to run every frame.

| Work | Previous behavior at 60 FPS | Current behavior |
| --- | --- | --- |
| Audio and rowing boat discovery | Each controller scans the boat folder 60 times/second | At most 4 times/second; folder replacement is detected immediately |
| Wave hull bounds | Full geometry measurement 60 times/second per boat | At most 2 times/second nearby; cached boxes follow root translation and rotation every frame |
| Motor spray settings and water samples | Up to 60 updates/second per boat | At most 20 updates/second, without catch-up bursts |
| Inactive effects | Repeated velocity reads, oar writes, emitter writes and particle clears | Silent engines, resting oars and unchanged emitters stop doing that work |
| Invisible surface ribbons | Continue calculating wave geometry | Skip hull measurements and wave samples underwater and above the surface viewing range |

Newly streamed boats can take up to 0.25 seconds plus one frame to acquire audio/rowing effects. Hull geometry changes, including refits, refresh within 0.5 seconds plus one frame. Root replacement invalidates the cached coordinate frame immediately. Active audio, rowing and wave motion still update every frame. Particle emitters continue simulating between settings updates.

Run the focused checks with `LUTE` pointing to an installed Lute runtime:

```powershell
node scripts/check-boat-audio.mjs
node scripts/check-rowing-animation.mjs
node scripts/check-boat-spray.mjs
node scripts/check-water-waves.mjs
```

Recording mocks verify operation budgets at 30, 60 and 144 FPS, idle behavior, streaming recovery, hull motion/turns, refits and water clearance. These are operation counts, not measured frame-rate gains. Verify rendering, sound and MicroProfiler timings in Roblox Studio with several nearby boats, storm weather, dismount/remount, refits and underwater camera transitions.

## Client startup

`src/client/init.client.luau` used to start all 63 client modules in a single frame. On slow devices that frame, plus 16 per-frame visual systems animating behind an opaque loading screen, took CPU time away from streaming in the world the loading screen waits for. Startup now runs in three stages:

1. **Required gear** (`Boating`, `Fishing`, `Oxygen`, `RodPhysics`, `PlayerMenu`) starts immediately, so `FishingWatersClientReady` arrives as early as possible.
2. **Other gameplay and UI** starts in list order with an 8 ms per-frame budget, which keeps the loading screen and streaming responsive.
3. **World animation and ambience** (water surfaces, shore waves, seabed carpet, clouds and storms, ambient fish, sharks, pedestrians, boat audio/spray/oars, environment audio and music) starts once `ReplicatedFirst/Loading` sets `FishingWatersLoadingSeconds`, or after 90 seconds if it never does. Each of these modules polls every frame and picks up existing instances when it starts.

Any module that holds the startup frame for more than 50 ms before its first yield prints `[Client] <name> held startup for N ms`. Use these lines on a low-end device to find the next module to optimize.

```powershell
node scripts/check-startup.mjs
```

## Streaming radius

`Workspace.StreamingTargetRadius` is 256 studs and `StreamingMinRadius` is 64 in `default.project.json`. The former 512-stud target streamed a much larger area of the dense city at once on metro arrival; halving it cuts the nominal horizontal target area to one quarter. The engine can retain content beyond the target, and island pieces are pinned until the LOD service releases distant pins, so this is not a hard cap on loaded scenery. Distant islands still use persistent LOD shells, and boats keep requesting 400 studs ahead while driving. Full-detail scenery now appears closer throughout the map, so sailing and fast travel need an in-game check for visible gaps.

## Character mesh rebuilds and low-end devices

Roblox batches each Humanoid model's parts into one mesh (`FastCluster` in the MicroProfiler). Changing a part's transparency, colour or shadow inside a character, or re-parenting the model, rebuilds the whole batch on the render thread. Low-end MicroProfiler captures showed `updateInvalidatedFastClusters` → `FastCluster::update` → `upload` spikes on the main thread.

| Source | Before | Now |
| --- | --- | --- |
| Black hole backpack fish (`BlackHoleBackpack`) | Smooth `LocalTransparencyModifier` fade written every frame, rebuilding the wearer's character every frame | Fish blink out at the horizon and back in at the rim: two writes per fish per 2.8 s orbit. Packs beyond 45 studs pose at 20 Hz |
| Rainbow / glitch fish in hands or NPC arms (`MutationEffects`) | Recoloured 20 times a second | 5 times a second while held by any Humanoid model; loose fish and menu previews still at 20 Hz |
| Townsfolk (`client/Pedestrians`) | Hidden rigs unparented and re-parented at every tier change; fades in 0.04 steps | Hidden rigs are parked out of sight and only leave the world when pooled; fades in 0.12 steps; bag colour only written on change |

### Automatic preset step-down

`PlayerSettings` picks a preset on join, but Roblox's Automatic graphics setting (the default) does not expose a quality level, so every computer got the Quality preset. `FrameRateGuard` starts 15 seconds after the loading screen lifts and judges 10-second windows of frame times (ignoring time spent unfocused). A window averaging under 40 FPS, or with six or more frames over 100 ms while under 55 FPS, lowers the preset one step (Quality → Balanced → Performance) and waits 20 seconds before judging again. Steady frame times without hitches look like a frame-rate cap and only count below 26 FPS. Options the player changed by hand that session are left alone, and the preset is never raised again until rejoin.

The current tier is published as the `GraphicsTier` attribute on the local player: layered water surfaces (`WaterQuality`) need tier 3, and the number of animated townsfolk drops from 14 to 10 (tier 2) or 6 (tier 1). The Settings ▸ Performance page shows the lowered values and says the preset was lowered. The output prints `[FrameRateGuard] N FPS over 10s; lowered graphics preset` each time.

### Ambient fish

The cosmetic schools use at most 8 / 5 / 3 schools on Quality / Balanced / Performance. School simulation still advances each rendered frame, but the welded fish poses move at most 30 times per second, with distant schools updated every third pose tick and schools behind the camera skipped. Opening build mode retires schools through the existing bounded recycler and pauses spawning and movement until it closes. This reduces the `AmbientFish/Move` and `BulkMoveTo` work shown in the base capture, at the cost of a lower animation rate and fewer fish on lower presets.

`node scripts/check-ambient-fish.mjs` checks the movement budget, build-mode transitions and lower-tier limit alongside the school behavior. Compare the same base and water views in Roblox Studio's MicroProfiler, including opening and closing build mode, to measure the actual frame-time change and check animation smoothness on device.

Ambient fish now use two visible primitive parts per fish rather than cloning the detailed catch models, while keeping species selection and size. Construction is spaced at least 0.3 seconds apart, pauses for eight seconds after a metro ride and backs off for one second after a frame longer than 50 ms. Existing schools still recycle incrementally. This targets the `AmbientFish/BuildOrReuse` cloning and parenting work seen during city arrival; actual frame times still require an in-game comparison.

## Memory: map pins follow the player

A low-end laptop's client log (Intel Iris Xe sharing 8 GB of RAM) showed a low-memory warning three seconds after launch and 4,850 `Calling mi_collect` lines in about an hour. Its MicroProfiler captures showed constant `Replicator GC Job` and `Part/Model Removals` blocks: the engine evicting streamed parts and streaming them back in.

Every island piece used to be pinned for a player (`AddPersistentPlayer`) as soon as it streamed in, for the rest of the session, so a player who explored ended up holding the whole map. Once memory ran out, the engine kept evicting everything that wasn't pinned (NPCs, boats, props) and fetching it again.

`server/Map/Lod` now sweeps every 4 seconds, in small time-budgeted steps. It releases pins on pieces more than 1,100 studs from the player (horizontal distance to the piece's centre). Within 450 studs on a return visit, it asks the client which released pieces are still loaded and repins those. Missing pieces stream normally and report their arrival; eagerly repinning them forced whole atomic models back in at once. Deferred client reports also discard pieces that have already streamed out. Pieces close to the player stay pinned exactly as before, so nearby towns still never stream out and reload.

`client/Lod` brings a far island's shell back once the island is short of ground again. Within 900 studs a shell that has given way still never returns, so drawn towns don't flicker.

### Layered clothing on crowd NPCs

The same log showed `Wrap-deformer fetching meshes resulted in error` about every three seconds. `AvatarLite.strip` already removes layered clothing from crowd descriptions, but its call is guarded and can fail silently. `AvatarLite.stripModel` now also removes any `WrapLayer` accessory and `WrapTarget` cage from built rigs: townsfolk templates (`client/Pedestrians`) plus pedestrian-visitor and random-avatar customers (`CustomerService`). Other players' own avatars are untouched, so some of these warnings can still come from them.

## Traversal: scenery batches and audio terrain probes

`SeabedCarpet` used to sample, clone, scale and parent up to 24 patches in one Heartbeat every 0.2 seconds. Moving into new water continually triggered these batches, and teleporting could destroy every old patch in one frame. It now attempts at most two cells and removes at most two entries per Heartbeat, stopping further work after a 1 ms budget. Individual patch operations are atomic and can exceed that budget. Persistent cursors limit inspections and resume on later frames; placement rules, density and retry behavior are unchanged. At 60 FPS the maximum attempt throughput remains 120 cells/second; lower frame rates spend less time building scenery.

`EnvironmentAudio` and `CoastalAmbience` still cast terrain rays around the listener after the water and seabed renderers had switched to voxel reads. On fresh terrain chunks those rays could build collision shapes synchronously (`RaycastTerrain` / `buildKDTree`). Water, beach and terrain-roof estimates now use `TerrainProbe.surfaceAt` at four-stud voxel resolution. Remaining roof rays exclude Terrain and detect only parts; terrain caves retain shelter through the voxel check. Failed reads and unstreamed air are retried at the normal sampling interval.

```powershell
node scripts/check-seabed-details.mjs
node scripts/check-environment-audio.mjs
node scripts/check-coastal-ambience.mjs
node scripts/check-lod.mjs
```

The scenery checks cover sustained travel at 100 studs/second at 30, 60 and 144 FPS, teleport cleanup, and simulated expensive operations. Audio checks cover shoreline mixing, part and terrain roofs, missing terrain, failed reads and recovery. LOD checks cover released, retained and missing pieces on revisit. These verify work limits and behavior, not measured frame-rate gains; compare the same sailing route in Roblox's MicroProfiler to confirm the device-level result.

## City street life

The port city's traffic is simulated on each client (`client/CityTraffic`, rules in `Shared/CityTraffic`). The server builds the signals and street furniture once and publishes the avenue network as one `TrafficNetwork` attribute on the city model; nothing about the cars replicates.

| Work | Budget |
| --- | --- |
| Simulation | Runs only while the camera is within 700 studs of the avenue grid. Vehicles within 650 studs step every frame and brake for players in the road; the rest step four times a second. A 160-vehicle step costs about 0.1 ms all near and 0.02 ms all far in lute; the city carries fewer |
| Drawing | One vehicle per 85 / 115 / 170 studs of lane by graphics tier (about 120 / 90 / 60 on the city's 42 lanes), at most 36 / 24 / 14 drawn, chosen twice a second from those within 220 studs. Pooled local models, welded to an anchored root; cars and taxis use the body as their only box collider, while other traffic is non-colliding; one `BulkMoveTo` per frame, every other frame past 200 studs; only vehicles within 90 studs cast shadows. At most one new vehicle model per selection pass; traffic sleeps during metro rides and while the camera is underground. |
| Lights | Head, tail/brake and taxi lights written only when they change. Signal lamps checked four times a second from the shared server-clock plan and written only when a lamp changes; tower beacons blink with two writes per 1.6 s, only after dark |
| Street furniture | Built once on the server inside each block's streaming piece; small props skip shadows, decorative ones are non-colliding. One slow particle emitter per fountain |

```powershell
node scripts/check-city-traffic.mjs
node scripts/check-city-street-life.mjs
```

`check-city-traffic` covers the signal plan, lanes, queueing without overlap or overtaking, no junction entry on red, bus calls, braking for a player and steady flow at 144, 60 and 20 FPS. `check-city-street-life` builds the real city and checks that every lane and junction path runs on asphalt with nothing solid in it, furniture stands on clear pavement, every shelter is served and streaming pieces stay within 260 parts. Neither measures rendering; check the `CityTraffic` label in the MicroProfiler downtown at night.

## City shadows and signs

A MicroProfiler capture in the city (including inside the metro station) showed most frame time in rendering (`Perform` / `Scene` on the main thread, `CullJob` / `queryOcclusion` on the workers). The city is about 27,700 parts, and 17,900 of them cast shadows. Each shadow caster in range is drawn again into every sun shadow cascade, even when the camera is underground.

`ModernCity.trimRendering` now turns off `CastShadow` on the ground itself: unnamed LowPoly facets and level slabs at most one stud thick in the hills, land fill, roads, kerbs, farm track and circuit. The ground still receives shadows. Ground above an underground (`LodSkip`) piece keeps its shadows so sunlight does not leak into HafenMitte. Every city `SurfaceGui` gets `MaxDistance = 200`. The pass runs at the end of `City.build` and again on every server start (`Map.ensureCity`), so a city saved in the place gets it without a version bump.

| | Before | After |
| --- | --- | --- |
| Shadow casters | 17,856 | 7,592 |
| Signs drawn at any distance | 75 | 0 |

These are instance counts from the Lute build, not frame timings. Compare the same downtown and metro spots in Roblox's MicroProfiler to confirm the device-level result.

### Street lamps after dark

The city has 677 `NightLight` lamps (street lamps at a 60-stud range, plus canopy downlights). Every one switched on at dusk, and up to 259 stand within 320 studs of the busiest downtown spot. `client/CityNightLights` now enables only the nearest 64 / 40 / 24 (Quality / Balanced / Performance `GraphicsTier`) within 320 studs of the camera, once the darkness passes each lamp's `GlowAt`. Every lamp head still turns Neon, so distant streets still look lit; only their light pools are dropped. The choice is refreshed twice a second, and only after the camera moves 16 studs, the darkness or tier changes, or lamps stream in or out. Lamps arrive disabled until the next choice. The server builds the lamps unchanged, so a city saved in the place needs no rebuild.

On Quality the 64 nearest reach about 160 studs downtown; pools further out are dark. Raise `MAX_LIT` if that looks too sparse in Studio.

## Micro Harbour showroom

The industrial-district megastore occupies a reserved 460 × 360 stud campus south of Harbour Road, opposite the container terminal. Its 360 × 225 stud showroom is over 23 times the previous floor area, with 18 warehouse racks across six component departments, six monitor comparison bays and a video wall, six complete PC demo islands, software displays, eight checkout lanes and a build desk. Three departments rotate their racks by 90 degrees; two branching walking loops and short crossovers weave between the departments and angled prebuilt islands. Path widths and connectivity to every price tag are checked against the actual server collision. The campus includes parking and loading bays; its driveway joins Harbour Road, clear of the refinery access road and CountryRoad. City version 15 reserves the site before spawning fields or trees and restores the former café-quarter lot; store version 6 keeps the bare fixtures visible outside. All 34 PC parts, two licenses and six complete PCs have individual models, catalog specifications and price tags. Complete PCs charge only for missing components and install all seven slots; already-owned configurations can be installed again for free. They use the existing component ownership save, so licenses and previous purchases remain available. Hold E for 0.8 seconds at a tag to buy; owned parts can be installed again for free. Included and installed items keep their native E prompt with an ownership label, rather than disabling the prompt. The server validates the character is alive, inside the store and within seven studs of that specific catalog display before charging the company save.

`TechStoreFixtures` builds the bare racks, tables, counters, paths, signs and 12 unshadowed lights on the server. These remain visible whenever the shop is streamed in, including while the player is outside. Its 1,023 fixture parts skip extra collision, touch, queries and shadows; 40 separate simple colliders provide stable collision. Including the shell and collision, 1,326 parts remain on the server. No sale merchandise or purchase prompts replicate.

`client/TechStoreInterior` builds only merchandise while the local character is inside the store's rotated bounds: detailed components, complete PC setups, boxed stock, price tags and purchase prompts. Leaving, dying, losing the character or streaming out destroys these contents and cancels any suspended build; bare racks and furniture remain. Re-entry generates fresh contents. Creation is capped at 12 parts or 1.5 ms per Heartbeat (individual instance registrations can exceed the time budget). The 2,438 local content parts are anchored and skip collisions, touch, queries and shadows. Outside players render none of these contents.

```powershell
node scripts/check-tech-store.mjs
node scripts/check-tech-store-interior.mjs
node scripts/check-tech-store-district.mjs
```

These checks build the real city to verify mainland placement, road access, scenery clearance and old-store migration, and cover catalog behavior, compilation, actual geometry, walkable approaches to every product, rotated occupancy, partial-build cancellation, death and stream-out recovery, creation budgets, exact-product proximity, charges, license unlocks, complete-PC purchases, credits for owned parts and free reinstalling of complete builds. Counts are mock measurements, not frame-rate results. Check lighting, prompt selection, text readability and entry/exit in a Roblox Studio play session.

## City building detail

The city keeps the solid building cores and complex or interactive pieces on the server. On both generated and baked cities, `Map/CityDetail` packs the ordinary non-colliding facade parts into a description on each building and removes those parts from replication. A client initially sees the building cores, then `client/CityDetail` reconstructs nearby facade pieces, closest buildings first, at up to six parts or two milliseconds of work per heartbeat. On frames slower than 30 FPS it makes at most one part every quarter second. Night-glow and aviation-beacon tags are retained, and local detail is removed when its building streams out. The distant city shell remains in use outside streaming range.

`node scripts/check-city-detail.mjs` checks migration, bounded reconstruction, lighting metadata and stream-out cleanup. These are mock checks; metro arrival and frame times still need profiling on the affected device in Roblox.

The city metro stop is persistent per passenger and therefore arrives as one atomic model. Its non-colliding, non-queryable decorations without children are now packed the same way, while platforms, controls, signs and lights remain in the replicated station. Local building and station detail waits through the metro ride and eight seconds after it ends. The client constructs the destination train directly in the world in groups of at most eight parts per step, cancels unfinished builds when the stop streams out, disables train-part shadows, and limits train pose updates to 30 Hz. These changes reduce individual bursts but do not prove a frame-rate result; compare the same journey on the affected device.

## Parliament

The parliament's shell is about 900 server parts in streaming pieces of at most 200. Its
furniture, ornament and people are local (`client/Parliament`, see `docs/PARLIAMENT.md`):
the facade and hall build while the square is in view, the rest only once a character is
inside, nearest zone first, at most 40 parts per frame within 2 ms. Rigs have no Humanoid
and move through one `BulkMoveTo` call per frame; only walkers are moved.

**Parliament performance mode** (Settings → Performance, on by default on the Performance
preset and after an automatic step down to it) rebuilds the local half as single blocks:
about 940 parts instead of 8,900, 87 one-block people instead of 229 seven-part ones, and
no ornament, dome ribs or Aura.
