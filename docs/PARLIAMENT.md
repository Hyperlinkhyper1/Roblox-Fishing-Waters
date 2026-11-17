# City parliament

The parliament stands on Civic Square, a nine-block plaza bounded by four avenues (only minor
streets were dropped, so traffic is unaffected). Its curved colonnade and public entrance face
the avenue to the south, behind a reflecting pool. The footprint is about 218 by 190 studs,
three 18-stud storeys under a glass dome, on a 0.6-stud plinth so the floor never shares a
surface with the paving. City version 19 rebuilds older cities with it on server startup.

## The building

A round chamber under the dome holds the House of Representatives (Tweede Kamer). Two
three-storey wings flank it, the curved Great Hall bulges out in front of it, and the Members'
Lobby runs behind it with palm courts at its corners. Stairs are at the front of each wing.

| Where | Rooms |
| --- | --- |
| Centre | **Great Hall** (reception, security, seat board), **House of Representatives** (150 members in six raked rows, the Speaker's dais and blue wall, **vak K** with 13 cabinet seats, public gallery one storey up), **Members' Lobby** |
| East, ground | **Polling Station** (four voting booths), Visitor Centre, Members' Restaurant, Kitchen |
| West, ground | Cloakroom & Post Room, Press Room, Library, Coffee Bar, Security Office |
| East, first | Committee Rooms 1–3 (horseshoe tables), two party rooms |
| West, first | Cabinet Room (nine seats), Speaker's Office, **Senate** (Eerste Kamer: 75 senators and the President, two storeys tall) |
| East, second | Committee Room 4, four party rooms |
| West, second | Members' Lounge, Clerks' Office, the Senate's public gallery |

Text is kept to a minimum and in English: small brass door plaques, each party's banner in its
own room, the seat board in the hall and the two division boards in the chamber.

`Shared/ParliamentLayout` is the single plan: dimensions, the 279 real seats, every room
with the places people sit or stand in it, and the walking graph through the doors,
corridors and stairs.

## Who builds what

- `Map/CityLandmark` (server) builds what every player needs: shell, floors, stair ramps,
  collision, transparent multiplayer Seats, the voting booth prompts and the division bell.
  About 1,050 parts in streaming pieces of at most 200.
- `Shared/ParliamentInterior` holds everything that is only looked at, in zones (the facade,
  the hall, each chamber, each corridor, each room). `client/Parliament` builds the facade
  and hall zones while the square is in view and all other zones only once a living
  character is inside, nearest zone first, at most 40 parts per Heartbeat within 2 ms.
  While you are inside, exposure eases down by 0.25 so the interior keeps its darker mood.
  Leaving, dying or streaming the building out detaches the interior at once and cancels
  its builder; disposal is paced over later frames. Local details have no collision, touch,
  query or shadow cost.

### Detailed and performance mode

Settings → Performance → **Parliament performance mode** (on by default on the Performance
preset). It rebuilds the local half on the spot:

| | Detailed | Performance |
| --- | --- | --- |
| Furniture | several shapes per piece (about 9,150 parts) | one block per piece (about 980 parts) |
| Ornament, finishes, dome ribs, roof gardens | yes | no |
| Lights | one per room and corridor, chandeliers, chamber spots | only the essential ones |
| People | seven parts each, walking and sitting poses | one block each, a third of the members |
| Aura | yes | no |

**Aura** is what the House (Tweede Kamer) and the Senate (Eerste Kamer) hold in detailed
mode: a model named `Aura` with shafts of light from the oculus or ceiling (Beams), drifting
gold dust (a ParticleEmitter), a warm glow and halo rings of light.

## People

`Shared/ParliamentCrowd` decides who is where; `client/Parliament` only draws it, and only
while you are inside. The roster is 150 members in their party's colour (seated in wedges
by the last election's seat count), the cabinet, the Speaker, senators and staff: 229
people, 87 in performance mode.

The day runs in two-hour blocks. Each block everyone picks something that suits their job:
a debate at their own bench, a committee, their party's room, lunch in the restaurant,
coffee, the library, a talk in the hall. They walk there along the graph. Staff keep
their posts. At night only security is in.

Rigs are anchored parts with no Humanoid, created eight per frame and moved with one
`BulkMoveTo` call per frame. Seated and standing people cost nothing after they arrive.

### The division bell

The bell rings by the clock at 11:00, 15:30 and 20:00 in-game, and when a player rings it
from the Speaker's desk (once per three minutes, `ElectionService`). Corridor lamps flash,
every member walks to their own bench and the cabinet to vak K. After 55 seconds the house
votes (each occupied desk lights green or red), the boards show the result at 70 seconds,
and at 100 seconds everyone goes back to what they were doing.

## Elections

`Shared/Parties` holds the rules; `ElectionService` runs them for the whole game.

- A term is four in-game years (about 24 real days). Polls are open from 1 September of
  the fourth year until it ends (about two real days).
- Each player has one vote per term, cast at a booth in the Polling Station. The vote is saved
  on the profile as `ElectionVote`; ballots from every server are added to one DataStore
  record per term (`FishingWatersElections_v1`).
- The party with the most votes governs the whole next term, on every server. The 150
  seats are divided by the D'Hondt method, and the chamber's members sit accordingly.
- The governing party's policy applies to every player. It is published as `Policy<Kind>`
  attributes on ReplicatedStorage, which gameplay reads directly.

| Party | Policy | Effect |
| --- | --- | --- |
| Anglers' Union | Craftsmanship Act | +15% XP for every catch |
| Free Traders | Free Trade Deal | +10% on fish sold over a shop counter |
| Good Food Party | Kitchen Subsidy | +12% on every dish sold (shop and restaurant) |
| Green Wave | Clean Seas Act | +4% luck on every cast |
| Golden Anchor | Breeding Programme | +10% size boost |
| Calm Waters | Calm Waters Act | +8% reel power and handling |

Until a first election has been counted nobody governs and no policy applies. To try an
election in Studio, jump the calendar with `/set date 12-30 23:00`; the term ends at
midnight.

## Checks

With `LUTE` set to the installed Lute executable, run:

```powershell
node scripts/check-parliament.mjs
node scripts/check-elections.mjs
node scripts/check-city-street-life.mjs
```

`check-parliament` runs the real shell, furnishings, crowd, election rules and local
controller against recording mocks: no two parts share a visible face (z-fighting) in the
shell, detailed or performance look; seat counts, streaming piece sizes, an avatar's
clearance and a floor along every link of the walking graph, both detail modes, the Aura,
seat allocation and the election calendar, that the bell seats every member before the
vote, and entry, exit, death, streaming and mode-switch transitions with their build
budgets. Add `--geometry <file.json>` to dump the parts for a rendered preview.

It does not measure device FPS and cannot see Roblox's own rendering, lighting, sound,
sitting, DataStores or replication; those still need an in-game Studio check.
