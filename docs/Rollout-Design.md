# Galaxy-wide rollout (Phase 3.13) — design for sign-off

_Drafted 2026-10-27; built the same day on the recommended defaults (Chuck: "get back to what you were doing"); the sign-off list below is what shipped, deviations in the roadmap row._ The seven living-world systems run on Tatooine (patrols 3.2, convoys 3.11, invasions 3.1, territory 3.4,
HoloNet 3.10, ambient cantinas 3.7/3.8, weather events 3.9). This makes each one read **city data** and fills that data for the
stock cities of the other nine planets._

## What the code already does, and what has to change

| System | Today | Change |
|---|---|---|
| Territory | three hand-listed regions | regions come from the city files (one per city), with a default lean |
| Patrols | a route table (key, planet, faction, region, points) | routes come from the city files; unchanged engine |
| HoloNet | a location table (cantina / starport spots) | locations come from the city files; the **sector report and the cantina gossip list only the relay's own planet** (today every relay reads the whole galaxy's three regions) |
| Ambient cantinas | a location table with hand-placed seats | seats become **presets per cantina building template** (the three stock cantina shells share one floor plan; Mos Eisley's seats fit every Tatooine cantina, Coronet's every Corellian one, Naboo gets one audited set) and the city file names the cantina |
| Invasions | a city table, one 6-hour tick starts **every** idle city at once | cities from the city files; the tick starts **one city per planet at most, round robin**, so the galaxy does not go to war on the hour |
| Convoys | one screenplay, one route, keys without a city name | a per-city instance (keys carry the city); the route is **computed on the navmesh at spawn time** from the city's starport to its plaza, so no hand-drawn legs |
| Weather events | Tatooine sandstorms with Tusken parties | a **per-planet table**: Tatooine as today; Dathomir storms bring Nightsister outcasts to the outposts' edges; Endor storms bring Marauders; Naboo and Corellia rain is cosmetic (the broadcast only); the rest none |
| Story ticker, galaxy chatter | galaxy-wide, three Tatooine stories | one new story per planet (nine), same engine |

## The city file

`screenplays/tasks/cities/<planet>_<city>.lua`, one per city, data only, loaded by a small `FbCities` registry before the systems start:

```lua
FbCities:add {
  key = "theed", planet = "naboo", label = "Theed",
  lean = 70,                               -- default Imperial %, from the stock stronghold list (Imperial 80 / Rebel 35 / else per planet)
  centre = { -5262, 4252 }, radius = 836,  -- the stock city region
  starport = "Theed Starport",             -- travel point name; the convoy and the starport relay hang off it
  plaza = { -5473, 4225 },                 -- the stock GCW landing spot where there is one, else the city centre
  cantina = { building = 88 },             -- the stock cantina building (its main room is cell building+3); nil for an outpost without one
  factions = { imperial = { leader = "stormtrooper_squad_leader", troops = { "stormtrooper_black_hole", "stormtrooper_black_hole" } },
               rebel    = { leader = "rebel_resistance_leader", troops = { "rebel_gungan_bomber", "rebel_trooper" } } },
  patrols  = { imperial = "stock:npc_3",   -- reuse a stock walking route of the city file
               rebel    = "ring:200" },    -- a loop outside the walls, generated on land at radius+200 m
  invasion = { staging = "outside:400:E" },  -- 400 m outside the walls on the given side; plaza and muster derive from `plaza`
  convoy = true, relays = { "starport", "cantina" },
}
```

Every derived point (ring loops, staging, relay spots, convoy routes) is **generated once by a tool against the running
server** (terrain height, water, no-build, line of sight through the lab's placement audit) and written into the city
file as plain numbers, so the shipped data is explicit and reviewable, and nothing is computed at boot except the convoy's
navmesh path.

## Which cities

| Planet | Cities (with cantina) | Outposts (no cantina: patrols, relay at the shuttle, territory only) |
|---|---|---|
| Naboo | Theed, Keren, Moenia, Kaadara, Dee'ja Peak | — |
| Corellia | Coronet, Tyrena, Kor Vella, Doaba Guerfel, Vreni Island, Bela Vistal | — |
| Talus | Dearic, Nashal | Imperial outpost |
| Rori | Narmle, Restuss | Rebel outpost |
| Lok | Nym's stronghold (its own cantina) | — |
| Dantooine | — | Agro, Imperial, Mining outposts |
| Dathomir | — | Science, Trade outposts |
| Endor | — | Research, Smuggler outposts |
| Yavin 4 | — | Labor, Mining outposts |
| Tatooine | as today, moved into city files (Mos Eisley, Bestine, Anchorhead) + Mos Espa, Mos Entha, Wayfar | — |

Invasions only where a garrison makes sense: one contested city per planet to start (Keren, Tyrena, Dearic, Restuss, plus
Bestine) — the others get patrols, convoys, relays and cantinas. Convoys only in cities with a starport.

## Tests

One scenario per planet (`rollout-<planet>`): every city's relays and patrons answer the placement audit (line of sight,
terrain, not in a wall — the furniture check from the planner for indoor seats), each patrol leader walks its first leg,
the convoy's path exists from starport to plaza, the invasion's three points stand on land outside no-build. The existing
Tatooine scenarios keep passing unchanged, which proves the refactor.

## Sign-off

- [ ] one city file per city, derived points generated and written as numbers
- [ ] cantina seats as presets per building template
- [ ] HoloNet and gossip talk about their own planet
- [ ] invasions one city per planet per tick; the contested-city list above
- [ ] convoys in every starport city, route on the navmesh
- [ ] weather: Dathomir and Endor storms with raiders, Naboo/Corellia cosmetic
- [ ] the city list and the outposts' reduced set
