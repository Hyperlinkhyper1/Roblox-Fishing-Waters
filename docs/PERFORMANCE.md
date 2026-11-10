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

`Workspace.StreamingTargetRadius` is 512 studs (previously 1024) in `default.project.json`. Island pieces are pinned for each player once they stream in (see `server/Map/Lod.luau`), so everything inside the target radius at spawn stays in that device's memory for the whole session. Halving the radius cuts the area streamed and held at join by about 4×. Distant islands are still shown by the persistent LOD shells, and boats keep requesting 400 studs ahead while driving.

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
