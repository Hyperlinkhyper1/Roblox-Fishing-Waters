# Business paths

The **Paths** tab in the Home menu shows the road a player's business follows.
Every player starts as a **Fish Shop**. When the active stage reaches **100%**
(every goal done), the player buys the next stage with coins. Stages **stack**:
everything an earlier stage unlocked keeps working.

```
Fish Shop ──► Fish Supermarket ──► The Restaurant ─┐
                                └► The Company ────┴─► (the other branch)
```

After the Supermarket, the player chooses Restaurant **or** Company first. The
other branch opens once the first one reaches 100%.

All rules live in [`src/shared/Paths.luau`](../src/shared/Paths.luau). It is pure
Luau, so the server, the menu and the tests read the same table.

## Where things live

| What | File |
| --- | --- |
| Stages, prices, goals, grants | `src/shared/Paths.luau` |
| Saved path state (`Angler.Paths`) and `choosePath` | `src/server/AnglerData.luau` |
| "ChoosePath" / "AssignBoat" menu actions | `src/server/AnglerService.luau` |
| Paths tab UI (the road) | `paths()` in `src/client/PlayerMenu.luau` |
| Recipes and kitchen stations | `src/shared/Recipes.luau`, `src/server/KitchenService.luau` |
| Food display case, kitchen stations, dishes (3D) | `src/server/Map/Kitchen.luau` |
| Dining room and tables (3D), diners | `src/server/Map/DiningRoom.luau`, `src/server/RestaurantService.luau` |
| Hired fisherman | `src/server/CompanyService.luau` |
| Tests | `lute run scripts/business-paths.luau` |

## Saved data

`Angler.Paths` is filled in automatically for old profiles:

```lua
Paths = {
	Active = "Fishshop",               -- the stage being worked on
	Unlocked = { Fishshop = true },    -- every stage bought so far
	Completed = {},                    -- stages that were finished and moved past
	Baseline = {},                     -- Stats copied when the active stage started
}
```

`Stat` goals count `Stats[stat] - Baseline[stat]`, so a stage only counts
progress made while it is active. The Fish Shop's baseline is empty, so a
veteran's lifetime totals count towards it.

## Adding a goal

Add an entry to a stage's `Goals` list in `src/shared/Paths.luau`. `Text` is a
`string.format` pattern; `%d` (or `%s` with `Money = true`) receives `Target`.

| Kind | Fields | Done when |
| --- | --- | --- |
| `Stat` | `Stat`, `Target`, optional `Money` | `Stats[Stat]` grew by `Target` since the stage started |
| `Staff` | `Role` | that staff member is hired |
| `Furniture` | `Item`, `Target` | at least `Target` of that item are placed |
| `Boat` | `Boat` | the player owns that boat |
| `RodUpgrade` | `Upgrade`, `Target` | the rod stat is at level `Target` or higher |
| `Upgrade` | `Upgrade`, `Target` | `Angler.Upgrades[Upgrade]` is `Target` or higher |

```lua
{ Kind = "Stat", Stat = "FishSold", Target = 25, Text = "Sell %d fish to customers" },
{ Kind = "Stat", Stat = "CoinsEarned", Target = 10000, Money = true, Text = "Earn $%s" },
{ Kind = "RodUpgrade", Upgrade = "Luck", Target = 3, Text = "Upgrade your rod's luck to level %d" },
```

Counters that `Stat` goals can use: every key in `Stats`. The paths added
`FishSold`, `FoodCooked`, `FoodSold`, `DinersServed` and `FishermanCatches`
(see `defaults` in `AnglerData.luau`). A new counter needs a default there and an
increment wherever it happens on the server.

## Adding required upgrades

Home upgrades (the empty **Upgrades** tab) don't exist yet. The `Upgrade` goal
kind is ready for them:

1. Store each upgrade's level in `Angler.Upgrades` (a `{ [upgradeId]: number }`
   table). It is already created, saved and validated by `AnglerData.decode`.
2. When the player buys an upgrade, raise its level inside a
   `BoatService.updateProgress` transaction (charge the price there too, like
   `AnglerService`'s `HireStaff`).
3. Require it on a stage:

```lua
{ Kind = "Upgrade", Upgrade = "BiggerFreezer", Target = 1, Text = "Buy the bigger freezer upgrade" },
```

The Paths tab, the percentage and the 100% unlock check all pick it up with no
other changes. Run `lute run scripts/business-paths.luau` afterwards.

## Changing prices or adding a stage

- **Price**: the stage's `Price`. It is charged when the player picks that path.
- **Grants**: `Grants = { FoodCase = 1 }` puts furniture into the player's build
  mode stock once, when the stage is bought.
- **New stage**: add it to `Paths.Stages` and `Paths.Order`, and list what has to
  be finished first in `Requires`. A stage with two `Requires` opens only when
  both are done. The Paths tab draws stages in `Order`, with a fork after the
  Supermarket; a new branch also needs a place in `paths()` in `PlayerMenu.luau`.
- **Locking content**: furniture (`Requires` in `FurnitureCatalog`) and staff
  (`Requires` in `StaffCatalog`) take a stage id. Server code checks
  `Paths.unlocked(profile, "StageId")`.

## Gameplay per stage

- **Fish Shop**: customers buy raw fish from your freezers; hire a Seller and a Porter.
- **Fish Supermarket**: two prep benches appear in the gray-tiled processing room.
  Take a fish from a freezer (**F**), carry it to a bench, press **Cook** and pick a
  recipe. Better recipes need rarer fish and a bought station (grill, smokehouse,
  sushi bar). Collect the dish onto the kitchen pass (6 dishes, plus 6 per food
  display case). Shop customers buy dishes from placed food display cases.
- **The Restaurant**: a dining room is built behind the processing room. Place
  dining tables there. Diners sit down and order one specific dish. Serve it to
  earn 1.5x the dish value (`Recipes.RESTAURANT_MARKUP`).
- **The Company**: hire a Fisherman (Home ▸ Staff) and assign one of your boats.
  He sails it out, fishes into its hold and moors beside the right pier when the
  hold is full; your Porter unloads it. You can't launch that boat yourself
  while he has it. Assign another boat to free it.
