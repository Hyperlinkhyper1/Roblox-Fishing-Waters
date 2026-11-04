# Fifteen-player lobby

Gullhaven has 15 player bases and 15 buyable company islands. The harbour's
coastline is about 18% larger in each horizontal direction, expanding around
the plaza so its shops, metro entrance and public spawn retain their positions.
The first six base and company property IDs remain valid.

The new bases occupy unused bay shoreline. The bathing beach, repair channel
and western bay entrance remain clear. Company islands sit farther offshore
with room between their docks. The 22 small procedural islets around Gullhaven
are removed, and open-sea rock generation is reduced from 55 to 28.

## Roblox place setting

Set the place's maximum player count to **15** in Creator Dashboard before
publishing. Roblox's `Players.MaxPlayers` is read-only in game scripts and is
configured through the place settings:
[Players.MaxPlayers documentation](https://create.roblox.com/docs/reference/engine/classes/Players#MaxPlayers).

## Baked maps

On startup, before character spawning and profile furniture loading,
`Harbour.ensureCapacity` replaces an older six-base harbour with the current
layout, refreshes the public spawn and removes small nearby or intersecting
procedural scenery. Company island generation also upgrades its saved layout.
Player wallet/progress data and existing property entitlements are retained.
Obsolete LOD shells are removed and rebuilt through the existing deferred repair.
Saving a fresh map bake avoids repeating these upgrades on each server start.

## Validation

With `LUTE` set to the Luau test runtime, run:

```powershell
node scripts/check-world-startup.mjs
node scripts/check-harbour-layout.mjs
node scripts/check-drydock.mjs --base-layout-only
node scripts/check-company-islands.mjs
lute run scripts/company-islands.luau
node scripts/check-lod.mjs
node scripts/check-dock-access.mjs
```

The recording tests cover all 15 assignments, release/reclaim, plot spacing,
ground support, launch routes, property purchases and baked-map upgrades.
They do not verify Roblox rendering, live DataStores or a 15-client Studio run.
