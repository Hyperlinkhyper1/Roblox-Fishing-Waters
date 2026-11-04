# Building and decorating

Go to your own base or company island and press **B**, or use the **Build** button. The build camera opens over the property. The bottom menu has three category tabs: **Furniture** for your bought items, **Decorate** for materials and paint, and **Build** for construction. The selected tab turns blue. **Done** or **B** returns to normal play.

The menu uses dark panels and light labels. Build mode hides the equipment hotbar while editing and restores its previous visibility when you leave.

Furniture is grouped into **All**, **Shop counters**, **Kitchen**, **Storage**, **Tables & seating**, **Lighting**, **Plants**, **Nautical**, and **Decorations** catalogues. Category counts show your unplaced stock. Cards use the actual furniture models; choosing a category filters your inventory without changing which items you own.

The Build tab has separate catalogues for **Walls**, **Rooms**, **Doors**, **Windows**, **Floors**, and **Roofs**. Each catalogue shows 3D item cards and prices. Selection, painting, and removal sit with the editing actions below those categories. Returning from Decorate to Build restores the last construction category. Stairs are no longer offered for new placement; existing saved stairs remain intact.

Decorate keeps its material and color palettes with a short Select / Paint / Remove toolbar. Moving, reshaping, and applying a finish appear when a selected object can use them. Undo and Redo stay in the compact header, and the pointer tooltip explains the next action without repeating instructions throughout the panel.

## Construction tools

| Tool | How to use it |
| --- | --- |
| Wall | Click a start point and an end point. Walls follow the horizontal or vertical grid. |
| Room | Click two opposite corners to build four walls and a floor together. The complete room saves as one edit. |
| Floor | Click two opposite corners to cover a rectangular area. |
| Roof | Choose a Gable, Flat, or Sloped roof card and click two opposite corners. Existing roofs become visible while using this tool. |
| Window | Choose Classic, Picture, Tall, Wide, Arched, or Round, then point at a wall and click to fit the window. |
| Door | Choose an Open, Timber, or Double doorway card, then point at a wall and click. |
| Select | Click an existing surface. Use Apply finish, or Move / Reshape for pieces you built yourself. |
| Paint | Choose a material and color, then click a surface to apply them. |
| Remove | Click a structural piece to remove it. Removing a wall also removes its attached doors and windows. |

Doors and windows create actual holes in their host wall. Window glass is transparent; doorways remain passable. Original house and shop walls, floor finishes, roof pieces, and window/door trim can be painted or removed. Original house surfaces keep their fixed geometry; use new pieces when you want to move or reshape the building.

Painting or removing any original roof piece edits that building's complete roof together, including its gables, tile courses, gutters, and edge boards. The house and shop roofs are separate groups. One Undo restores the complete roof. New roofs also select and edit as complete assemblies.

Painting changes the clicked surface immediately. You can continue painting other surfaces while earlier clicks save. The editor combines queued clicks into bounded batches and keeps the latest chosen finish for each target. Other edits wait for preceding paint to save. If a save is rejected, the affected surface returns to its saved finish and the editor shows a notice; newer queued paint remains visible and still saves.

Choose textures using the material buttons: plaster, brick, wood planks, wood, concrete, slate, marble, ceramic tiles, cobblestone, metal, shingles, smooth plastic, or glass. Pick a color swatch or enter a custom **#RRGGBB** color and click **Set color**. The selected finish applies to the next placement, to the Paint tool, or to **Apply finish** on a selected surface.

The placement preview shows the actual shape, material, and color with a translucent finish and outline. Furniture previews also show the footprint and facing direction. Window and door previews temporarily hide the original wall and show its proposed cutout, so an uncut wall does not obscure the new opening. Cancelling or leaving build mode restores the original wall visibility. Invalid positions show a red outline and an explanation. The server checks ownership, plot boundaries, openings, overlap, furniture, important equipment access, and available cash before saving anything.

The lavender construction grid follows the selected floor and grid size. Wall endpoints snap to its intersections, and the wall centerline follows the horizontal or vertical grid line between them. Pointer drawing uses that same visible grid plane, including from an angled camera. Surface picking follows the selected floor too, so editing an upper storey does not select walls underneath it.

## Controls

| Control | Action |
| --- | --- |
| WASD / arrows | Pan the camera |
| Q / E | Turn the camera |
| Right mouse drag | Pan the camera |
| Mouse wheel / + / − | Zoom |
| Touch drag / tap | Pan / select or place |
| R | Rotate the current furniture or construction preview by 90°; choose styles using catalogue cards |
| G | Cycle grid sizes: 4.5, 2.25, or 1.125 studs |
| Page Up / Page Down, or Floor + / − | Change the construction level, from floor 1 through 4 |
| Show roof / Hide roof | Toggle roof visibility while editing |
| X / Escape | Cancel the current placement or selection |
| Delete | Remove the selected structure |
| Ctrl + Z / Ctrl + Y, or Undo / Redo | Undo / redo structural edits |
| Home | Recenter the camera |
| B / Done | Exit build mode |

New walls cost **$12 per 4.5 studs**; floors cost **$6 per grid square**, roofs **$10 per grid square**, windows **$45–85**, and doors **$60–100** depending on style. Partial lengths/areas round up. Painting is free. Moving or enlarging a piece charges any increase in its construction price. Removing a piece gives no refund; undoing a purchase reverses its original cash charge. Undo/redo history holds the last 20 structural edits for each property during the current server session. A saved paint batch is one history entry.

## Saving and compatibility

Structural edits save under `Angler.Building.Home` and `Angler.Building.Company`. Each site contains stable custom piece IDs, the next available ID, and overrides for original house parts. Home and company layouts save independently. Existing players start with their current house unchanged.

Original shell parts stay in the model so existing room references, furniture, and gameplay fixtures remain intact. Removing one hides it and disables its collision. Doors/windows replace a host wall's collision with separated wall sections around the opening. Clearing the owner's edits restores the original appearance and physical properties.

The original home/yard and shop across the street are separate buildable areas. Construction cannot cross the road, extend onto someone else's property, or seal designated access routes. The company plot also reserves its entrance. Each property supports up to 350 custom pieces and four construction levels. Floor selection controls structural elevation. Existing furniture keeps its room-specific placement zones on the ground level.

## Verification

Set `LUTE` to your installed Lute executable, then run:

```powershell
node scripts/check-building.mjs
```

This executes the production construction rules and renderer with recording Roblox doubles. It checks finite remote input, material/color validation, plot boundaries, road separation, overlaps, real hosted cutouts, stair direction and floor openings, pristine-shell restoration, stable IDs across rotated plots, and preview collision. It also checks round trips through the real AnglerData and BoatData decoders and parses the complete service, renderer, editor, and BuildMode modules.

The editor interaction, asynchronous paint queue, and authoritative service have separate behavioral checks. Editor checks cover category navigation, catalogue previews, quarter-turn rotation, and wall drawing from an angled camera on rotated properties. Controlled delayed saves verify immediate painting, queued clicks, stale replication protection, rollback, batching, and paint ordering before Undo:

```powershell
node scripts/check-structure-editor.mjs
node scripts/check-build-paint-queue.mjs
node scripts/check-building-service.mjs
```

```powershell
node scripts/check-building.mjs --static
```

The static option checks module wiring only. Studio playtesting is still required for rendered appearance, camera/input feel, real physics, streaming, and live DataStore behavior.
