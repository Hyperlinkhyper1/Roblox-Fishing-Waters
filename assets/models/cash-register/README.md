Original export: `Cash Register.zip`, supplied 23 October 2026.

The original OBJ/MTL files are retained here. Rebuild/verify both shop assets with
`node scripts/import-shop-models.cjs` (or `--check`). The bundle retains all 523
vertices and 1,058 faces from the one source object, separated into its four
original material/color groups. Its 32 zero-area source faces remain in the data
but do not create invalid Roblox parts.

The register is uniformly scaled to 2.4 studs wide. `ImportedModel` uses native
solid boxes, merged coplanar rectangles and thin triangle skins so no uploaded
mesh is required. Triangle dimensions below Roblox's 0.001-stud minimum are
clamped; skins extend 0.01 studs inward. Source-transfer checks account for that
minimum size and check original vertices against their material's emitted surface.

`ShopDesk` places one register on the left side of the supplied desktop. Its
visual pieces are anchored and have collision disabled; the desk remains solid.
The placed register uses charcoal and teal metal, silver trim and ivory keys.
Its original four colors remain in `SourceColor` metadata. Fixture version 2
updates the register together with the desk in existing saved shops.
