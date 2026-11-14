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

## Company types and branches

Creating a save asks for a company type: a **Fishing company** (the harbour
dock and fish shop) or a **Café** in the city. The choice is saved as
`Branches` on the profile (`{ Fishing = true }` or `{ Cafe = true }`). Saves
from before branches have no `Branches` field and are fishing companies, so
every existing player stays on the fishing branch. Save cards show the type.

The office PC has a **BRANCHES** app (`client/BranchApp`, `server/BranchService`)
that buys the missing branch from the company wallet while sitting at your own
PC: the café branch costs $7,500 and the fishing branch $5,000
(`Shared.Branches`). A company with both branches fishes and runs a café.
Café-only companies have no harbour dock, cannot cast until they buy the
fishing branch, and spawn in their café. Buying the fishing branch claims a
dock right away; buying the café branch claims a café.

### Cafés

The city's café quarter is fifteen blocks (one per harbour plot) on both sides
of the avenue just south of the metro station (`ModernCity.cafeSites`,
`Map/CafePlots`). The blocks are built like the rest of the city: a mixed-use
building on the avenue with flats above, and a lower building behind it on the
back street. Each café is the avenue building's ground-floor unit: an empty
customer floor on the fishing house's 11 x 7 build lattice, a counter with a
till and a coffee machine, and a staff room with one storage rack and the same
office PC as the fishing bases. Members of a company share one café per server.

A café only exists while a company runs it. An unclaimed unit is an ordinary
closed shopfront; the café's frontage, furniture and lights wait in
`ServerStorage.CafeStash` and move into the building when the plot is claimed
(`CafePlots.setOpen`). When the last member leaves, the shopfront closes again
and anyone still inside is moved out onto the pavement.

Customers (`server/CafeService`) walk in off the avenue, queue at the till and
order a coffee. Hold the coffee machine's prompt to brew a cup, then serve the
customer at the front of the queue: $20 goes into the company wallet and the
barista earns 25 XP (`Shared.CafeCatalog`). Customers leave after two minutes
without coffee. Up to four are inside at a time.

### Café tutorial

A new café company gets a hands-on tour (`Shared.CafeTutorial`,
`server/CafeTutorialService`, shown by `client/Tutorial`). Bea, the café
mentor, stands on every claimed café's floor beside the open end of the
counter. The tracker, gold marker and floor arrow lead through seven steps:

1. Talk to Bea: what the café is, $20 and 25 XP per coffee.
2. Brew a coffee at the machine (`Brew` from `CafeService`).
3. Serve the customer at the front of the queue (`Serve`). While the player
   has no cup, the arrow points back to the coffee machine; with no customer
   yet, the goal says to wait.
4. Talk to Bea: one cup at a time, two-minute patience, four customers.
5. Serve three more customers (counted).
6. Sit at the office PC in the staff room (`OfficeComputerService.onSit`).
7. Talk to Bea: the BRANCHES app ($5,000 fishing branch), the STOCKS app and
   its trading license from Micro Harbour, multiplayer, the Companies board.
   Finishing pays $250 once per company.

Progress is saved on the company profile as `Cafe.TutorialStep`,
`TutorialDone`, `TutorialCount` and `TutorialRewarded`, so any member's brew,
serve or desk visit counts for everyone. A café that served coffee before
the tour existed starts with it finished. BoatService mirrors the state as
`CafeTutorialStep` / `CafeTutorialCount` / `CafeTutorialDone` attributes. Only
members of the café's company see Bea's prompt. The tour can be skipped from
the tracker, and `/tutorial` restarts it for any company with a café.

The café tour comes before the island tour while it is unfinished.
Café-only companies never see the island tour; buying the fishing branch
brings it up, so Captain Wren and the harbour guides then teach fishing.
A fishing company that buys the café branch gets the café tour too.

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
node scripts/check-cafe.mjs
lute run scripts/cafe-tutorial.luau
```

These execute production Luau against recording mocks. Published Roblox testing
is still required for live DataStores, friends, text filtering and teleports.
Test a migrated account, three different slots, five simultaneous members, a
sixth rejected join, owner-offline entry, independent carried catches, shared
spending, disabling multiplayer and a failed teleport followed by retry.
