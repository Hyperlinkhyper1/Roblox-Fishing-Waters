# Fish expansion

All 44 unique species requested are available: 43 new species modules and the existing Sockeye Salmon. Gulf Coney was listed twice and has one entry. Existing generic Sailfish, Swordfish, Seabass and Catfish keep their IDs, models and catch rules.

Weights, rarities, values and conditions are gameplay choices. Each species defines three cargo footprints, a fight modifier and a sale value in its module under `src/shared/Fish`.

## Models

Every entry has its own builder, colors and identifying fins or markings. `FishModels` registers the builders automatically and supplies body lofts to the existing client `FishMeshes` renderer. That renderer creates smooth bodies through `AssetService:CreateEditableMesh` and `CreateMeshPartAsync`, shares cached species skins, supports mutation painting, and preserves visible fallback geometry when the mesh API is unavailable or its budget is exhausted. No uploaded mesh IDs are needed.

Mesh & Image APIs must be allowed in Roblox experience security settings; `MeshFeatures.EditableMeshesEnabled` is already enabled in this project. Geometry checks use recording doubles; Studio play testing remains necessary for final appearance and device mesh budgets.

## Catch rules

These are the species' own pools. **Open Sea species are also inherited by every regional pool, including Gullhaven Sound**, following the existing catalog rules. Entries assigned only to named regional pools stay regional. Gullhaven Sound uses the existing `MainLake` pool ID.

Weather conditions listed with "or" are alternatives. Time requirements must also hold. Without an explicit weather or time requirement, any weather or time works. Only the listed seasons permit a bite. The bestiary reads these rules from the same catalog.

Rarity denominators are relative weights in the eligible pool, so an entry's actual catch chance depends on other eligible fish, junk chance, and rod luck.

| Species | Rarity | Weight kg (min / average / max) | Own pools | Seasons | Additional conditions |
|---|---|---|---|---|---|
| Atlantic Sailfish | Epic | 8 / 28 / 100 | Open Sea | Summer, Autumn | clear, day |
| Black Marlin | Legendary | 40 / 180 / 750 | Cinder Isles | Summer, Autumn | day |
| Blue Marlin | Legendary | 30 / 140 / 650 | Open Sea | Summer, Autumn | clear, day |
| Broadbill Swordfish | Epic | 15 / 85 / 600 | Open Sea | Spring, Summer, Autumn | night |
| Longbill Spearfish | Rare | 3 / 12 / 55 | Coral Shallows | Spring, Summer | clear, day |
| Striped Marlin | Epic | 12 / 55 / 220 | Open Sea | Spring, Summer, Autumn | day |
| White Marlin | Epic | 8 / 25 / 90 | Pirate Cove | Spring, Summer | day |
| Black Grouper | Epic | 3 / 14 / 90 | Coral Shallows, Pirate Cove | Spring, Summer, Autumn | night |
| Black Seabass | Uncommon | 0.3 / 1.2 / 4.5 | Gullhaven Sound, Coral Shallows | Spring, Summer | day |
| Calico Grouper | Rare | 1.5 / 7 / 25 | Coral Shallows, Cinder Isles | Summer, Autumn | clear |
| Broomtail Grouper | Epic | 4 / 20 / 100 | Coral Shallows | Autumn, Winter | night |
| Giant Seabass | Legendary | 12 / 70 / 250 | Cinder Isles, Pirate Cove | Spring, Summer | rain or storm, night |
| Gulf Coney | Common | 0.08 / 0.35 / 1.3 | Coral Shallows | Spring, Summer, Autumn | Any weather or time |
| Graysby | Uncommon | 0.1 / 0.65 / 2.5 | Coral Shallows, Pirate Cove | Summer, Autumn | night |
| Nassau Grouper | Rare | 1 / 5 / 25 | Coral Shallows | Spring, Winter | day |
| Red Hind Grouper | Uncommon | 0.2 / 1.4 / 5.5 | Coral Shallows, Pirate Cove | Spring, Summer | day |
| Tripletail | Rare | 0.5 / 4 / 20 | Gullhaven Sound, Coral Shallows | Summer, Autumn | clear, day |
| Tiger Grouper | Epic | 2 / 9 / 35 | Coral Shallows, Cinder Isles | Summer, Autumn | night |
| Yellowfin Grouper | Rare | 1 / 5 / 25 | Coral Shallows | Spring, Summer | clear, day |
| Alabama Bass | Uncommon | 0.2 / 1.4 / 5.5 | Gullhaven Sound | Spring, Summer, Autumn | day |
| Yellow Bass | Common | 0.08 / 0.35 / 1.6 | Gullhaven Sound | Spring, Summer | Any weather or time |
| Peacock Bass | Rare | 0.4 / 2.2 / 10 | Gullhaven Sound, Sodden Mire | Summer | clear, day |
| Redeye Bass | Uncommon | 0.1 / 0.45 / 2 | Gullhaven Sound | Spring, Summer | clear |
| Largemouth Bass | Rare | 0.3 / 2.3 / 11 | Gullhaven Sound, Sodden Mire | Spring, Summer, Autumn | Any weather or time |
| Blue Catfish | Rare | 1 / 12 / 65 | Gullhaven Sound, Sodden Mire | Spring, Summer, Autumn | night |
| Black Bullhead | Common | 0.1 / 0.65 / 3.5 | Gullhaven Sound, Sodden Mire | Spring, Summer, Autumn | night |
| Brown Bullhead | Uncommon | 0.15 / 0.85 / 4 | Gullhaven Sound, Sodden Mire | Spring, Summer, Autumn | rain, night |
| Gafftopsail Catfish | Rare | 0.4 / 2.8 / 8 | Coral Shallows, Pirate Cove | Spring, Summer | night |
| Yellow Bullhead | Common | 0.1 / 0.55 / 3 | Gullhaven Sound, Sodden Mire | Summer, Autumn | rain |
| White Catfish | Uncommon | 0.2 / 1.8 / 9 | Gullhaven Sound | Spring, Summer, Autumn | night |
| Aurora Rockfish | Rare | 0.3 / 0.8 / 2.5 | Frostmere Expanse | Autumn, Winter | night |
| Black Rockfish | Uncommon | 0.4 / 1.5 / 5 | Gullhaven Sound, Frostmere Expanse | All year | Any weather or time |
| Blackgill Rockfish | Rare | 0.5 / 2.2 / 6 | Cinder Isles, Pirate Cove | Autumn, Winter | night |
| Bocaccio | Rare | 0.8 / 3.5 / 12 | Frostmere Expanse, Cinder Isles | Spring, Autumn, Winter | Any weather or time |
| Canary Rockfish | Rare | 0.4 / 1.8 / 5.5 | Frostmere Expanse, Cinder Isles | Spring, Summer | day |
| Cowcod | Epic | 1.5 / 7 / 18 | Cinder Isles | Autumn, Winter | night |
| Chilipepper | Uncommon | 0.2 / 0.9 / 3 | Cinder Isles | Summer, Autumn | day |
| Treefish | Rare | 0.2 / 0.7 / 2 | Coral Shallows, Pirate Cove | Spring, Summer, Autumn | night |
| Yelloweye Rockfish | Epic | 0.8 / 4 / 12 | Frostmere Expanse | Autumn, Winter | clear, day |
| Atlantic Salmon | Rare | 1 / 4.5 / 25 | Gullhaven Sound, Frostmere Expanse | Spring, Autumn, Winter | rain |
| Chinook Salmon | Epic | 3 / 12 / 60 | Frostmere Expanse | Spring, Summer, Autumn | day |
| Coho Salmon | Rare | 0.8 / 3.5 / 15 | Gullhaven Sound, Frostmere Expanse | Autumn, Winter | rain, day |
| Sockeye Salmon | Rare | 1 / 2.7 / 7 | Open Sea | Autumn | Any weather or time |
| Pink Salmon | Uncommon | 0.5 / 1.8 / 6.5 | Gullhaven Sound, Frostmere Expanse | Summer, Autumn | Any weather or time |

## Verification

Run these from the repository root with Lute available (`LUTE` can point to its executable for the Node scripts):

```powershell
node scripts/check-fish-expansion.mjs
node scripts/check-fish-models.mjs
node scripts/check-fish-meshes.mjs
node scripts/check-catch-stats.mjs
node scripts/check-freezers.mjs
```

The expansion check exercises the requested species' spawn eligibility, smooth body geometry, weight/value behavior, and cargo shapes. The remaining checks cover all catalog model builders, mesh allocation and fallback, saved catch statistics, and freezer packing.

All five checks pass: 44 requested species across 560 spawn combinations, all 117 catalog model builders, mesh allocation/fallback, catch statistics, and freezer packing. Representative fallback geometry previews are in `.tmp/fish-expansion-preview/overview-fallback.png`.

The older `lute run scripts/fish-catch.luau` suite stops at `Tire lists its seasons`. This also reproduces with only the 74 pre-expansion species: the existing Tire entry omits `Seasons`, which the harness requires. No existing catch rules were changed for this expansion.
