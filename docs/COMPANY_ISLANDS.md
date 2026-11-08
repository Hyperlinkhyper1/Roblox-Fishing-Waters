# Company islands

Fifteen islands surround Gullhaven. Unlock **The Company**, sail to an unoccupied
island, and use the sale board on its beach to buy it for **$50,000**. Each player
can own one island in addition to their harbour home.

## How an island looks

Every island has the same landform: a wide beach in front, a ragged terrace whose cliffs
are stacked, tumbled rock blocks (dropping straight into the sea round the back), two
rocky knolls on its flanks and sea stacks offshore. The stair climbs through a cut in
the cliff front between rock cheeks. A free island is plain wild land on top of that:
rough rock steps in the cut, a wooded terrace, rocks scattered unevenly along the shore,
and one old jetty beside the sale board.

While someone owns it (after buying, or when an owner joins and is assigned it)
the island turns into a harbour village: a planked quay and two piers with rope
rails, lanterns, bollards and ladders, a stone harbour wall along the cliff front, a
lantern-lit stone stair in the cut, a village square (well, fire pit, market stall, notice board,
string lights) and, on the terrace, an **empty fenced plot**. When the owner
leaves and the island is free again it goes back to wild land.

The ground, sale board and boat marker are permanent. The rest is the island's
`Dressing` model, rebuilt off-map by `Map/CompanyIslands.dress` and cut into
streaming pieces (`Lod.pin`) before it replaces the old one.

## The plot and the company kit

There are no built-in houses. Buying an island puts its kit in the owner's
furniture inventory, placed from build mode (press **B** on the island's plot):

- **4 storage racks:** 12 fish each, sharing one storage pool with home racks.
- **2 prep benches:** independent saved cooking jobs (keys `CompanyPrep1/2`); the
  company chef cooks here.
- **Kitchen storage:** rarity targets and taking fish, as at home.
- **Company desk:** opens Home > Staff for company management.

Racks, kitchen storage, the weather radar and decorations bought at Harbour Home
can also go on the plot. Shop fixtures stay at the harbour. The plot is a 108 x 63
stud grid (`FurnitureCatalog.PLOT`) with its gate kept clear. Placements save in
`Angler.CompanyFurniture`, in the plot's own frame (`CompanyIslands.plotFrame`).

Owners from before the kit get it once on their next load (`Angler.CompanyKit`).
Their stored fish stay saved, but storage only counts placed racks, so they place
their racks to store more.

The hired fisherman uses the island dock. The island porter walks catches up the
stairs to the first placed rack or kitchen storage, and restocks kitchen storage
from saved storage.

## Saved ownership and server plots

`Angler.CompanyIsland` stores the preferred island ID in the existing wallet save.
Purchases recheck the Company path, cash, and existing ownership inside the wallet
transaction. A server reserves the plot before saving, preventing concurrent buyers
from acquiring the same island.

On rejoining, an owner gets their preferred island if available, otherwise another
free island, without another charge. Placed furniture follows the owner to whichever
island they get. If all fifteen are occupied, paid ownership stays saved and the
player waits for a released plot.

## Map integration

The shared `CompanyIslands` module controls count, price, names, the hand-placed
`Sites` (bearing, distance and dock turn per island, deliberately not a ring) and
the plot frame. Each island's landform comes from `shapeOf(id)` in the map module:
only the quay front, the square's beach, the cliff front and the terrace round the
plot are fixed; the outline, hill, knolls and sea stacks grow from the island's seed.
Fresh generation reserves their footprints before placing procedural
scenery. Startup adds or upgrades the islands on older Studio-baked maps (version 3
replaced the houses, version 4 the landform, version 5 the scattered sites and
per-island shapes), clearing overlapping procedural scenery without touching
player bases.

## Validation

```text
lute run scripts/company-islands.luau
node scripts/check-company-islands.mjs [--preview out.png]
lute run scripts/business-paths.luau
node scripts/check-company-startup.mjs
node scripts/check-world-startup.mjs
```

The company checker executes production geometry and transaction code with
recording Roblox doubles. It checks both dressings and the swaps between them,
stair risers, the empty plot, streaming-piece sizes, island spacing, map migration,
purchase races, allocation on rejoin, dock authorization, porter routes to placed
racks, and kitchen benches. `--preview` draws the wild and the owned island from
above. Studio play is still needed for appearance, streaming, boat physics and real
NPC navigation.
