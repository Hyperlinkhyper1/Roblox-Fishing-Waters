# Seasonal fish expansion

This expansion adds 50 species and variants beyond the existing fish catalog. The exact regression list is [scripts/seasonal-fish.mjs](../scripts/seasonal-fish.mjs); each fish lives in its own module under [src/shared/Fish](../src/shared/Fish).

Each entry defines encounter rarity and weight, a positive min/average/max weight range, sale value, fight modifier, and connected Normal, Big and Huge cargo footprints that grow with size. These values and habitat choices are gameplay design choices.

## Real fish identities

All 50 additions represent living fish species or real varieties. Each module records its ScientificName, which is preserved in AnglerCatalog. Mirror Carp is a scale-pattern variety of common carp (Cyprinus carpio), so this is 50 fish entries rather than 50 distinct biological species. Generic labels are pinned to specific species: Red Lionfish (Pterois volitans), Great Barracuda (Sphyraena barracuda), and Bluespine Unicornfish (Naso unicornis). IDs remain stable for saved catches.

Reference examples: [Alaska fish species](https://www.adfg.alaska.gov/index.cfm?adfg=animals.listfish), [Australian Museum blue tang](https://australian.museum/learn/animals/fishes/blue-tang-paracanthurus-hepatus/), [Australian Museum unicornfish](https://lifg.australian.museum/Group.html?groupId=4h45V1Tl&hierarchyId=PVWrQCLG), [Florida Museum species profiles](https://www.floridamuseum.ufl.edu/discover-fish/species-profiles/), [mirror carp identification](https://www.mdb.fish/fish-fact-sheets/carp), [mandarinfish observation](https://lkcnhm.nus.edu.sg/wp-content/uploads/sites/10/2022/05/NIS-2022-0054.pdf).

The calendar, game regions, weights, rarity and prices are gameplay settings; they do not describe natural geographic ranges, migration calendars or biological records.

## Registration and 3D meshes

[FishSpecies](../src/shared/FishSpecies.luau) automatically loads the modules. [AnglerCatalog](../src/shared/AnglerCatalog.luau) registers their catch data, pool membership and bestiary entries; [FishModels](../src/shared/FishModels.luau) registers each model builder. No separate runtime species list or uploaded mesh ID is needed.

Every new builder supplies a body loft to the existing [FishMeshes](../src/client/FishMeshes.luau) client renderer. It uses [AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService) and the Roblox EditableMesh API to create smooth body geometry through CreateEditableMesh and CreateMeshPartAsync, with seven color bands supporting mutation colors. Species use their own body proportions, fins, tails and markings. Full catch models and bestiary viewports use these mesh skins. Shared skin caching, serialized temporary allocations and the existing mesh budget remain in place; visible fallback body geometry remains available if mesh creation fails.

The experience must allow Mesh & Image APIs in its security settings. [MeshFeatures.EditableMeshesEnabled](../src/shared/MeshFeatures.luau) is enabled in this project. Actual Studio rendering, appearance and device memory budgets still require Studio play testing.

## Areas and seasons

All 50 fish have explicit regional pools and restricted seasons. None joins OpenSea, whose entries are inherited by every region. The new fish therefore bite only in the listed areas and seasons, subject to any additional requirements below. Gullhaven Sound is the displayed name of the MainLake pool. Spring/Winter and Spring/Autumn/Winter windows wrap across the end of the calendar year.

[FishCatch.inSeason](../src/shared/FishCatch.luau) enforces seasons and catch conditions when a bite is selected. The bestiary reads the same catalog data. Rarity denominators provide relative encounter weights; actual catch probability also depends on the other eligible fish, junk chance and rod luck.

[AmbientFish](../src/client/AmbientFish.luau) selects background schools from the same regional pool and allowed season, and retires schools when their season ends or they leave their habitat. These cosmetic schools use lightweight silhouettes. They do not use full catch mesh models. Fish with extra catch requirements are excluded from ambient schools, so Red Lionfish and Mandarinfish remain nighttime catches and bestiary entries without appearing as unrestricted background schools.

| Fish | Scientific name | Areas | Seasons | Additional requirements |
|---|---|---|---|---|
| Brook Trout | *Salvelinus fontinalis* | Frostmere Expanse | Spring, Autumn, Winter | Any weather or time |
| Brown Trout | *Salmo trutta* | Gullhaven Sound, Frostmere Expanse | Spring, Autumn, Winter | Any weather or time |
| Lake Trout | *Salvelinus namaycush* | Frostmere Expanse | Autumn, Winter | Any weather or time |
| Arctic Char | *Salvelinus alpinus* | Frostmere Expanse | Spring, Winter | Any weather or time |
| Dolly Varden | *Salvelinus malma* | Frostmere Expanse | Summer, Autumn, Winter | Any weather or time |
| Mountain Whitefish | *Prosopium williamsoni* | Gullhaven Sound, Frostmere Expanse | Spring, Autumn, Winter | Any weather or time |
| Arctic Grayling | *Thymallus arcticus* | Frostmere Expanse | Spring, Summer | Any weather or time |
| Burbot | *Lota lota* | Frostmere Expanse, The Sodden Mire | Autumn, Winter | Any weather or time |
| Arctic Cisco | *Coregonus autumnalis* | Frostmere Expanse | Spring, Winter | Any weather or time |
| Lake Whitefish | *Coregonus clupeaformis* | Frostmere Expanse, Gullhaven Sound | Autumn, Winter | Any weather or time |
| Golden Perch | *Macquaria ambigua* | Gullhaven Sound | Spring, Summer, Autumn | Any weather or time |
| White Crappie | *Pomoxis annularis* | Gullhaven Sound, The Sodden Mire | Spring, Summer | Any weather or time |
| Black Crappie | *Pomoxis nigromaculatus* | Gullhaven Sound, The Sodden Mire | Spring, Autumn, Winter | Any weather or time |
| Pumpkinseed | *Lepomis gibbosus* | Gullhaven Sound | Spring, Summer | Any weather or time |
| Roach | *Rutilus rutilus* | Gullhaven Sound | Spring, Autumn, Winter | Any weather or time |
| Rudd | *Scardinius erythrophthalmus* | Gullhaven Sound, The Sodden Mire | Spring, Summer, Autumn | Any weather or time |
| Tench | *Tinca tinca* | The Sodden Mire | Spring, Summer, Autumn | Any weather or time |
| Grass Carp | *Ctenopharyngodon idella* | Gullhaven Sound, The Sodden Mire | Summer, Autumn | Any weather or time |
| Mirror Carp | *Cyprinus carpio* | Gullhaven Sound | Autumn, Winter | Any weather or time |
| Crucian Carp | *Carassius carassius* | The Sodden Mire | Spring, Summer | Any weather or time |
| Chain Pickerel | *Esox niger* | The Sodden Mire | Spring, Autumn, Winter | Any weather or time |
| Muskellunge | *Esox masquinongy* | Gullhaven Sound | Autumn, Winter | Any weather or time |
| Bowfin | *Amia calva* | The Sodden Mire | Summer, Autumn | Any weather or time |
| Longnose Gar | *Lepisosteus osseus* | The Sodden Mire | Spring, Summer | Any weather or time |
| Alligator Gar | *Atractosteus spatula* | The Sodden Mire | Summer, Autumn | Any weather or time |
| Blue Tang | *Paracanthurus hepatus* | Coral Shallows | Spring, Summer | Any weather or time |
| Powder Blue Tang | *Acanthurus leucosternon* | Coral Shallows | Spring, Winter | Any weather or time |
| Yellow Tang | *Zebrasoma flavescens* | Coral Shallows | Summer, Autumn | Any weather or time |
| Moorish Idol | *Zanclus cornutus* | Coral Shallows, Pirate Cove | Spring, Summer, Autumn | Any weather or time |
| Copperband Butterflyfish | *Chelmon rostratus* | Coral Shallows | Spring, Summer | Any weather or time |
| Raccoon Butterflyfish | *Chaetodon lunula* | Pirate Cove | Autumn, Winter | Any weather or time |
| Emperor Angelfish | *Pomacanthus imperator* | Coral Shallows, Cinder Isles | Summer, Autumn | Any weather or time |
| Queen Angelfish | *Holacanthus ciliaris* | Pirate Cove | Spring, Winter | Any weather or time |
| Flame Angelfish | *Centropyge loricula* | Cinder Isles | Summer, Autumn | Any weather or time |
| Red Lionfish | *Pterois volitans* | Pirate Cove, Cinder Isles | Autumn, Winter | Night |
| Mandarinfish | *Synchiropus splendidus* | Coral Shallows | Spring, Summer | Night |
| Royal Gramma | *Gramma loreto* | Pirate Cove | Autumn, Winter | Any weather or time |
| Fire Goby | *Nemateleotris magnifica* | Cinder Isles | Spring, Summer | Any weather or time |
| Banggai Cardinalfish | *Pterapogon kauderni* | Pirate Cove | Spring, Winter | Any weather or time |
| Sergeant Major | *Abudefduf saxatilis* | Coral Shallows | Summer, Autumn | Any weather or time |
| Picasso Triggerfish | *Rhinecanthus aculeatus* | Cinder Isles | Spring, Summer | Any weather or time |
| Clown Triggerfish | *Balistoides conspicillum* | Cinder Isles | Autumn, Winter | Any weather or time |
| Bluespine Unicornfish | *Naso unicornis* | Coral Shallows | Spring, Winter | Any weather or time |
| Humphead Wrasse | *Cheilinus undulatus* | Coral Shallows, Cinder Isles | Summer, Autumn | Any weather or time |
| Hogfish | *Lachnolaimus maximus* | Pirate Cove | Spring, Summer, Autumn | Any weather or time |
| Great Barracuda | *Sphyraena barracuda* | Pirate Cove | Summer, Autumn | Any weather or time |
| Wahoo | *Acanthocybium solandri* | Cinder Isles | Autumn, Winter | Any weather or time |
| Queen Triggerfish | *Balistes vetula* | Pirate Cove | Autumn, Winter | Any weather or time |
| Cobia | *Rachycentron canadum* | Cinder Isles | Spring, Summer | Any weather or time |
| Bonefish | *Albula vulpes* | Coral Shallows | Spring, Summer, Autumn | Any weather or time |

## Validation

Run with Node.js and Lute available (or set LUTE to the Lute executable path):

```text
node scripts/check-fish-expansion.mjs --seasonal
node scripts/check-seasonal-fish-meshes.mjs
node scripts/check-fish-models.mjs
node scripts/check-fish-meshes.mjs
node scripts/check-ambient-fish.mjs
```

The seasonal expansion check passed 75,867 geometry, condition, weight and cargo checks across 560 physical spawn combinations. The real builders and real client renderer also passed the EditableMesh recording-double test for all 50 species: 350 hydrated skin bands, 320,888 vertices and 522,412 triangles across the complete fixture. Those aggregate fixture totals are not per-fish costs or an estimate of normal simultaneous gameplay rendering.

The 50 new fallback models contain at most 169 BaseParts each. The full catalog model check, ambient school checks (including metro transitions), existing mesh allocation/failure checks, and a Rojo project build also passed. Sample fallback geometry previews were inspected; they do not show the client mesh skins.

These checks validate program behavior and geometry against recording doubles. They do not verify engine rendering, visual quality or real device mesh budgets.

