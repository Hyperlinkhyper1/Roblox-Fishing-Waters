Original export: `Ingenious Lappi.zip`, supplied 23 October 2026.

The original OBJ/MTL files are retained here. `node scripts/import-shop-models.cjs`
generates `ShopDeskGeometry.luau` and `CashRegisterGeometry.luau`; add `--check`
to verify the bundled data against the original exports.

The source bundle retains 48 vertices, 72 faces, six pieces and its original palette.
The placed desk uses walnut wood grain, lighter cabinet doors, a dark desktop and
brass-colored metal handles. Original colors remain in `SourceColor` metadata.
At 7.5 studs wide it is 3 studs tall and 3.046875 studs deep. Its cabinet handles
face local +Z. `ShopDesk` places it in the front-right corner of the wooden shop
floor at house-local (16, 0.16, 10.675), rotated 90 degrees to meet the window sill, opposite the left-wall freezer.

One register sits on the desktop at desk-local (-2.325, 3, 0), facing the same way.
Negative X is the left side when looking at the desk from its front. Existing
saved shops receive the assembly without rebuilding the house or freezer.
Fixture version 4 scales both the desk and register down by 25%, retaining the
window-sill alignment and replacing older saved assemblies in place.

`node scripts/check-base-house.cjs` verifies source transfer, placement, register
support/overhang, clear routes, rotated plots and saved-map repair/idempotence.
These checks do not exercise Roblox Studio rendering or live gameplay.
