# City parliament

The parliament stands on Civic Square, east of the city station. Its curved colonnade and
public entrance face the avenue to the south, behind a reflecting pool. The building frame
is `(7319.5, 8.9, 6752)`; the footprint is 144 by 126 studs, three storeys under a glass
dome. City version 18 rebuilds older generated or baked cities with it on server startup.

## The building

A round drum under the dome holds the Tweede Kamer. Two three-storey wings flank it, the
curved Statenhal bulges out in front of it, and the Wandelgang runs behind it. Stairs are at
the south end of each wing.

| Where | Rooms |
| --- | --- |
| Centre | **Statenhal** (reception, security, seat board), **Tweede Kamer** (150 members in six rows, the Speaker, **vak K** with 13 cabinet seats, public gallery ring one storey up), **Wandelgang** with two palm courts |
| East, ground | **Stemlokaal** (four voting booths), Bezoekerscentrum, Statenrestaurant, Keuken |
| West, ground | Garderobe & Postkamer, Perscentrum Nieuwspoort, Handelingenkamer (library), Koffiehuis, Beveiliging |
| East, first | Thorbeckezaal, Troelstrazaal, De Ruyterzaal (committee rooms), two party rooms |
| West, first | Trêveszaal (nine cabinet seats), Voorzitterskamer & Griffie, **Eerste Kamer** (75 senators and the President, two storeys tall) |
| East, second | Aletta Jacobszaal, four party rooms |
| West, second | Ledenlounge, Griffie offices, the Eerste Kamer's gallery |

`Shared/ParliamentLayout` is the single plan: dimensions, the 279 real seats, every room
with the places people sit or stand in it, and the walking graph (nodes and links) through
the doors, corridors and stairs.

## Who builds what

- `Map/CityLandmark` (server) builds what every player needs: shell, floors, stair ramps,
  collision, transparent multiplayer Seats, the voting booth prompts and the division bell.
  About 900 parts in streaming pieces of at most 200.
- `Shared/ParliamentInterior` holds everything that is only looked at, in zones (the facade,
  the hall, each chamber, each corridor, each room). `client/Parliament` builds the facade
  and hall zones while the square is in view and all other zones only once a living
  character is inside, nearest zone first, at most 40 parts per Heartbeat within 2 ms.
  Leaving, dying or streaming the building out detaches the interior at once and cancels
  its builder; disposal is paced over later frames. Local details have no collision, touch,
  query or shadow cost.

### Detailed and performance mode

Settings → Performance → **Parliament performance mode** (on by default on the Performance
preset). It rebuilds the local half on the spot:

| | Detailed | Performance |
| --- | --- | --- |
| Furniture | several shapes per piece (about 8,900 parts) | one block per piece (about 940 parts) |
| Ornament, dome ribs, roof gardens | yes | no |
| People | seven parts each, walking and sitting poses | one block each, a third of the members |
| Aura | yes | no |

**Aura** is what the Tweede Kamer and the Eerste Kamer hold in detailed mode: a model
named `Aura` with shafts of light from above (Beams), drifting gold dust (a
ParticleEmitter), a warm glow and a halo of light rings under the dome or ceiling.

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
every member walks to their own bench and the cabinet to vak K. After 40 seconds the house
votes (each occupied desk lights green or red), the boards show the result at 55 seconds,
and at 85 seconds everyone goes back to what they were doing.

## Elections

`Shared/Parties` holds the rules; `ElectionService` runs them for the whole game.

- A term is four in-game years (about 24 real days). Polls are open from 1 September of
  the fourth year until it ends (about two real days).
- Each player has one vote per term, cast at a booth in the Stemlokaal. The vote is saved
  on the profile as `ElectionVote`; ballots from every server are added to one DataStore
  record per term (`FishingWatersElections_v1`).
- The party with the most votes governs the whole next term, on every server. The 150
  seats are divided by the D'Hondt method, and the chamber's members sit accordingly.
- The governing party's policy applies to every player. It is published as `Policy<Kind>`
  attributes on ReplicatedStorage, which gameplay reads directly.

| Party | Policy | Effect |
| --- | --- | --- |
| Vissersbond | Vakmanschapswet | +15% XP for every catch |
| Vrije Kooplieden | Vrijhandelsakkoord | +10% on fish sold over a shop counter |
| Partij van de Smaak | Keukensubsidie | +12% on every dish sold (shop and restaurant) |
| Groene Golf | Schone Zeewet | +4% luck on every cast |
| Gouden Anker | Kweekprogramma | +10% size boost |
| Rustige Wateren | Kalmtewet | +8% reel power and handling |

Until a first election has been counted nobody governs and no policy applies. To try an
election in Studio, jump the calendar with `/set date 12-30 23:00`; the term ends at
midnight.

## Checks

With `LUTE` set to the installed Lute executable, run:

```powershell
node scripts/check-parliament.mjs
node scripts/check-city-street-life.mjs
```

`check-parliament` runs the real shell, furnishings, crowd, election rules and local
controller against recording mocks: seat counts, streaming piece sizes, an avatar's
clearance and a floor along every link of the walking graph, both detail modes, the Aura,
seat allocation and the election calendar, that the bell seats every member before the
vote, and entry, exit, death, streaming and mode-switch transitions with their build
budgets. Add `--geometry <file.json>` to dump the parts for a rendered preview.

It does not measure device FPS and cannot see Roblox's own rendering, lighting, sound,
sitting, DataStores or replication; those still need an in-game Studio check.
