# Saves and companies

Players choose a save before a character spawns. Each account owns at most three
slots. Existing plots automatically become an **Existing plot** save in slot 1
when the selector loads; new accounts start with empty slots. Registration adds
save metadata to the original record and preserves its buildings, furniture,
company island, settings, inventory and money.
The creator can rename a save, set its company icon, enable/disable multiplayer,
and remove members from its settings in the selection screen. Rejoin to change
saves or settings.

The save remote opens at server boot (`BoatService.openSaves()` in
`init.server.luau`), before the harbour is built, so saves list within a second
of joining. Listing, creating and editing work immediately; pressing Play waits
on the server until the wallet service has started. The three slot reads run in
parallel and the discovery-index repair runs after the response.

Behind the selector the camera slowly circles the main island under a
`BlurEffect` (parented to the camera, removed on entry). The window sits below
Roblox's top bar using `GuiService.TopbarInset`.

## Company icons

`SaveInfo.Icon` is an optional Roblox decal or image asset ID. The settings
screen accepts a bare ID, `rbxassetid://` or a Creator Store / library link and
previews it live; an empty field clears it. Published servers reject assets
whose type is not Image or Decal (if the catalog lookup fails the ID is kept).
Cards render `rbxthumb://type=Asset&id=<id>&w=150&h=150`, which works for both
decals and images. The icon is copied into the discovery directory so friends
see it in the companies sidebar.

Every named save is a company on the new **Companies** leaderboard. Enabling
multiplayer lets the creator's Roblox friends join from the selection screen's
company sidebar, including while the creator is offline. Companies have at most
five persistent members, including their creator. A member can return when the
company is full. Existing members retain access if they later stop being friends;
the creator can remove them or turn multiplayer off.

Only the creator uses an owned save slot. Other players keep a membership pointer
in their sidebar, and all company progress is saved under the creator's save key.
Members share money, business progression, stock, boats and other company assets.
Carried fish and backpack contents are kept per angler so members can fish at the
same time. Hired staff run once per company in a server.

Published multiplayer saves persist one reserved server ID. All members are
routed to that company server; Roblox can start it again when no members are
online. Joining and destination arrival both validate the saved membership.
Unpublished Studio uses server-session storage; Studio skips teleports so local
multiplayer tests can run together. Negative Studio test IDs may join each other
without a Roblox friendship lookup.

## Larger multiplayer plots

Multiplayer saves use five larger waterfront plots in their company server.
The house and yard build area is 99 studs wide, twice its original 49.5-stud
width. The shop keeps its original footprint to clear the curving ring road.
Saved buildings and furniture keep their original local coordinates. Added
side foundations support the extra land; the road between the house and shop,
the piers and boat approaches stay clear. Normal public
servers retain their fifteen original plots.

Before anyone spawns, the server selects five separated properties using their
rotated footprints and checks the added land against roads, public buildings,
landmarks and scenery. Only noninteractive scenery may be cleared. If a map
cannot safely fit five properties, selection reports the problem before
spawning or changing a player's plot. Construction and furniture checks use
the same enlarged footprint, and staff navigation and the build camera cover
the new space.

`SaveInfo.PlotExpanded` persists the land upgrade. Turning multiplayer off
prevents friends from entering while keeping the larger plot and its saved
construction available to the creator.

## Storage and transactions

The existing `WalletAndBoats_v1` store remains authoritative (published Studio
uses `WalletAndBoats_Studio_v1`). Slot 1 retains `Player_<creator>`; slots 2 and 3
use `Player_<creator>_Slot_<slot>`. Profiles add `SaveInfo` for the creator, name,
multiplayer setting, roster, reserved server ID, timestamps and revision.
`CompanyCrew` holds guest-carried inventory; the creator's existing carried
inventory keeps its original fields.

Gameplay transactions and membership changes use `UpdateAsync` on the same save
record. Transactions validate membership, read the latest wallet, and increment
the revision. A per-save queue serializes concurrent actions in one server.
Committed updates immediately refresh online members; periodic reads reconcile
separate Roblox cross-play instances and settings changes from another server.
Members whose access is revoked are asked to rejoin and select a different save.

`SaveDirectory_v1_<user>` contains discovery summaries and joined-company pointers,
never an extra copy of company progress. Creator selection repairs its summaries
after an interrupted index update. Offline friend discovery uses a shared cache
and a paced read lane. It may take time to populate a long friend list.
Roblox text filtering runs before save/company names are persisted.

## Company rankings

The plaza has a seventh board, **Companies**, and the player list has a Companies
tab. Entries use the save name and count each company's assets once. Net worth
includes cash, owned boats, furniture, backpack, company island, unsold fish/dishes
and the current value of stocks. It excludes lifetime earnings and cosmetics.
Global scores can decrease and refresh every two minutes from saved profiles.
The on-screen company tab groups the current server's crew members and shared
wallet instead of summing the same money once per player.

## Fishing companies

All companies use the harbour dock and fishing business. Existing café-only
saves retain their company data and can use the fishing business. The retired
café progress remains in existing profiles for compatibility.

## Verification

Set `LUTE` to the Luau runner, then run:

```powershell
node scripts/check-saves.mjs
node scripts/check-save-selection.mjs
node scripts/check-companies.mjs
node scripts/check-boats.mjs
node scripts/check-boats.mjs --company-wallet-only
node scripts/check-company-staff.mjs
node scripts/check-multiplayer-plots.mjs
node scripts/check-building.mjs
node scripts/check-building-service.mjs
node scripts/check-build-camera.mjs
node scripts/check-furniture-shop.mjs
node scripts/check-npc-navigation.mjs
node scripts/check-leaderboards.mjs
node scripts/check-loading.mjs
node scripts/check-startup.mjs
node scripts/check-world-startup.mjs
```

These execute production Luau against recording mocks. Published Roblox testing
is still required for live DataStores, friends, text filtering and teleports.
Test a migrated account, three different slots, five simultaneous members, a
sixth rejected join, owner-offline entry, independent carried catches, shared
spending, disabling multiplayer and a failed teleport followed by retry.
