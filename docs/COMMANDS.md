# Chat Commands

All commands are typed in the in-game chat. They are registered as `TextChatCommand`s on the server.

## Access

> **All admin commands are restricted to `hyperlinkhyper` (UserId `2541746813`) only.**
> That covers everything below except `/tutorial`, including `/tp`, `/set cash`, `/fly`, `/gamepass`, `/mutation`, `/event`, `/health` and the rest of `/set`.

- For any other player an admin command does nothing: no reply and no effect. The commands are hidden from chat autocomplete.
- The check runs **on the server**, against the sender's UserId from `TextChatCommand`'s `TextSource`. The client can't fake it.
- The functions that make the changes check the UserId again themselves, so a future caller can't skip the gate by accident:
  - `BoatService.setCashFromCommand`
  - `CargoService.addHeldMutation`
  - `CargoService.setHeldWeight`
  - `GamepassService.grantForSession`
- Flight is gated twice. The server only sets `AdminFlyEnabled` for the admin, and the client `AdminFly` script won't start for any other UserId.
- No RemoteEvent exposes these actions to clients. The only other thing that can force weather or grant passes is the operator dashboard (`DashboardService`). It is server-to-server HTTP, so players can't reach it.

### Changing who is admin

Admin accounts are listed in one place: [src/shared/Admin.luau](../src/shared/Admin.luau). Every check above calls `Admin.isAdmin(player)`. To add or remove an admin, edit `Admin.UserIds`, for example:

```lua
Admin.UserIds = table.freeze({
	[2541746813] = true, -- hyperlinkhyper
})
```

Arguments are not case-sensitive.

## Everyone

| Command | What it does |
|---|---|
| `/tutorial` | Restart your company's tutorial from the beginning: the island tour for fishing companies, the cafe tour for cafe companies (both for a company with both branches). |

## Admin

### General

| Command | What it does |
|---|---|
| `/commands` | Show the command list in chat. |
| `/health` | Show this server's memory, uptime and worst frame. |

### Movement

| Command | What it does |
|---|---|
| `/fly` | Toggle flight. WASD to move, Space up, Ctrl down. |
| `/fly speed <studs/s>` | Set flight speed (default 50). Must be a positive number. |
| `/tp city` | Teleport to the city. |
| `/tp models` | Teleport to the full-size scale models showcase (outside the ocean; builds the pier if needed). The pier's east end opens onto a Pets deck with an animated scarlet macaw. |

### Economy and passes

| Command | What it does |
|---|---|
| `/set cash <amount>` | Set your cash. Whole number, 0 or higher. |
| `/set level <amount>` | Set your level to a whole number from 1 to 155. Resets progress within that level. |
| `/gamepass list` | List gamepasses. |
| `/gamepass get <name>` | Enable a gamepass for you for this server session only. |

Gamepasses: `2x XP`, `Auto Store`, `Black Hole Backpack`, `Boat Customization` (spaces optional, the internal key also works, e.g. `DoubleXP`).

### Fish

| Command | What it does |
|---|---|
| `/mutation list` | List fish mutations. |
| `/mutation <mutation>` | Add a mutation to your equipped fish. |
| `/dbtreasure` | Make your next catch Dreadbeard's treasure. Restricted to `hyperlinkhyper` specifically; the pending catch resets when you leave. |
| `/set weight <kg>` | Change your equipped fish's weight (and size). |

Mutations: Corrupted, Void Touched, Windy, Ascended, Floral, Snowy, Tryhard, Jack O' Fish, Jack's Pet, Zeus Struck, Nightmare, Obsidian, Gusty, Astral, Rainbow, Neon, Albino. Spaces and punctuation are ignored, so `/mutation zeusstruck` works.

### World

| Command | What it does |
|---|---|
| `/set weather list` | List weather types. |
| `/set weather <type>` | Force the weather. `Supercell` spawns the cell circling you. |
| `/set season <spring\|summer\|autumn\|winter>` | Pin the season. |
| `/set season auto` | Let the season follow the clock again. |
| `/set date <month-day> [hh:mm]` | Jump the in-game calendar to that moment, e.g. `/set date 10-31 23:50`. |
| `/set date auto` | Return to the shared calendar. |
| `/event list` | List events. |
| `/event spawn <event>` | Start an event for the rest of the in-game day. |

Weather types: `Clear`, `Foggy`, `LightRain`, `Rain`, `Storm`, `Supercell`.
Events: `halloween`.

## Where they live

- [AdminCommands.luau](../src/server/AdminCommands.luau): `/commands`, `/mutation`, `/event`, `/health`, `/fly`, `/tp`, `/gamepass`
- [BoatService.luau](../src/server/BoatService.luau): `/set` (cash, weight, weather, season, date)
- [TutorialService.luau](../src/server/TutorialService.luau): `/tutorial` (cafe tour: [CafeTutorialService.luau](../src/server/CafeTutorialService.luau))
