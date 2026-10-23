Source: `C:\Users\ayden\Downloads\Smashing Elzing-Habbi.zip`, supplied 23 October 2026.

`tinker.obj` and `obj.mtl` are the original Tinkercad export. Rebuild the bundled
Luau geometry with `node scripts/import-fish-freezer.cjs`; verify it with `--check`.
The importer retains all 166 vertices, 288 faces, 11 objects and four opaque colors.
Eight complete cuboids render as solid Parts; other faces render as thin WedgeParts.
This allows Rojo/server startup to build the supplied model without an uploaded mesh.

`FishFreezer.build` maps source Z to Roblox Y, centers the footprint, and uniformly
scales the 150-unit width to 9 studs (height 4.02, depth 3.6009). Thin surface skins
extend 0.01 studs inward. The original MTL declares every color opaque.

`BaseHouse` places one freezer near the shop's left wall, with about 1.2 studs of clearance with its curved front
facing the customer aisle. Saved houses receive it in place through `ensure`.
Run `node scripts/check-base-house.cjs` for placement, source-object retention,
walkway clearance, rotated plots, saved-house repair and idempotence checks.
These are recording-mock checks; Roblox Studio rendering/play is not exercised.

Placed fixture version 2 uses teal metal, tinted glass, an icy shelf and salmon
packages with cream fabric wrapping. These are Roblox's built-in material textures;
the original four colors remain in `SourceColor` metadata. Existing saved freezers
receive the finishes through `ensure`. Version 3 reduces the whole fixture by 25%
and moves its center to house-local (-19, 0.16, 7) for wall clearance.
