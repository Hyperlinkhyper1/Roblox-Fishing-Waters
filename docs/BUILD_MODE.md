# Building and decorating

Go to your own base or company island and press **B**, or use the **Build** button. The build camera opens over the property. **Done** (top right) or **B** returns to normal play. Build mode hides the equipment hotbar while editing and restores it when you leave.

## Layout

The editor follows the Restaurant Tycoon 3 pattern: everything you place lives in one dock along the bottom, and the actions for what you clicked appear right next to it.

| Area | What it holds |
| --- | --- |
| Bottom dock, left | **Select**, **Paint** and **Delete** tools, plus **Undo**, **Redo** and **Roof** (show/hide). |
| Bottom dock, tabs | **Furniture**, **Walls**, **Rooms**, **Floors**, **Doors**, **Windows**, **Roofs** and **Paint**. The open tab is blue. |
| Bottom dock, catalogue | Cards with a live 3D thumbnail and price (or unplaced stock) for the open tab. Paint shows materials, colours, a custom **#RRGGBB** field and **Paint all walls**. |
| Floating action bar | Appears above whatever you select: **Rotate**, **Move**, **Pick up** / **Delete**, **Reshape**, **Apply finish**, **Edit rack**, **Cancel**. While placing, it sits above the dock with **Rotate** and **Cancel**. |
| Top left | Cash, floor (− / +) and grid size, and one line telling you what the next click does. |
| Top right | **?** (controls), zoom − / +, **Home** (recenter) and **Done**. |

**Select** and **Delete** work on furniture and building pieces alike: click a freezer or a wall and you get the same floating actions. Picking a catalogue card switches to placing that item; finishing or cancelling returns to Select.

Furniture is grouped into **All**, **Shop counters**, **Kitchen**, **Storage**, **Tables & seating**, **Lighting**, **Plants**, **Nautical**, and **Decorations** chips. Chips only show groups you have unplaced stock in, with counts. Selected furniture can be rotated in place, moved or picked up.

Stairs are no longer offered for new placement; existing saved stairs remain intact.

## Construction tools

| Tool | How to use it |
| --- | --- |
| Wall | Click a start point and an end point. Walls follow the horizontal or vertical grid. |
| Room | Click two opposite corners to build four walls and a floor together. The complete room saves as one edit. |
| Floor | Click two opposite corners to cover a rectangular area. |
| Roof | Choose a Gable, Flat, or Sloped roof card and click two opposite corners. Existing roofs become visible while using this tool. |
| Window | Choose Classic, Picture, Tall, Wide, Arched, or Round, then point at a wall and click to fit the window. |
| Door | Choose an Open, Timber, or Double doorway card, then point at a wall and click. |
| Select | Click a surface or piece of furniture. The floating bar offers Move, Reshape, Apply finish and Delete (or Rotate / Move / Pick up for furniture). |
| Paint | Choose a material and color, then click a surface to apply them. |
| Delete | Click a structural piece to remove it, or furniture to pick it up. Removing a wall also removes its attached doors and windows. |

Doors and windows create actual holes in their host wall. Window glass is transparent; doorways remain passable. Original house and shop walls, floor finishes, roof pieces, and window/door trim can be painted or removed. Original full-height wall sections can also be **moved** or **reshaped**: the first move hides the original and saves an equivalent wall of your own in its new position, as one undoable edit. Doors and windows you added to that wall move with it. Lintels, sills and other partial wall sections stay paint/remove only.

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
| R | Rotate the furniture or construction preview, or turn the selected furniture in place |
| M | Move the selected furniture or wall |
| G | Cycle grid sizes: 4.5, 2.25, or 1.125 studs |
| Page Up / Page Down, or the top-left − / + | Change the construction level, from floor 1 through 4 |
| Roof (dock) | Toggle roof visibility while editing |
| X / Escape | Cancel the current placement or selection |
| Delete | Remove the selected structure, or pick up the selected furniture |
| Ctrl + Z / Ctrl + Y, or Undo / Redo | Undo / redo structural edits |
| Home | Recenter the camera |
| B / Done | Exit build mode |

New walls cost **$12 per 4.5 studs**; floors cost **$6 per grid square**, roofs **$10 per grid square**, windows **$45–85**, and doors **$60–100** depending on style. Partial lengths/areas round up. Painting is free. Moving or enlarging a piece charges any increase in its construction price (moving an original wall to an equal length is free). Removing a piece gives no refund; undoing a purchase reverses its original cash charge. Undo/redo history holds the last 20 structural edits for each property during the current server session. A saved paint batch is one history entry.

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
