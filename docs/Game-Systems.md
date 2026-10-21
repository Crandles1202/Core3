# Game systems the citizens must live inside — notes from the Core3 code

How the stock server runs resources, surveying, harvesters, crafting, travel and trade, read from the code on
2026-10-20 (file names given so the next reader can check), and what each system means for an AI citizen
(Phase 7). Append to this file whenever a mechanic is looked up; Chuck asked for these notes.

## 1. Resources (`managers/resource/`, `bin/scripts/managers/resource_manager.lua`)

**What spawns.** Resources are instances of classes in a tree (`resourcetree/`, loaded from the game's
`datatables/resource/resource_tree.iff`): metals (steel, copper, aluminum, iron), ores (extrusive, intrusive,
carbonate), gemstones, radioactives, petrochemical fuels (solid, liquid), inert petrochemicals (polymer,
lubricating oil), gases, water, and organics: meats, milks, hides, bones, eggs, seafood, grains, vegetables, fruits,
woods, plus energy (solar, wind) and fiberplast. Every spawn gets a random name and random attribute values
(overall quality, shock resistance, conductivity and so on, within the class's min–max, with a bias away from the
class's "breakpoint": `ResourceSpawner::randomizeValue`). The *stats* decide crafting results as much as the class.

**How many, where.** Ten active planets (`activeZones`). Four pools keep the galaxy stocked
(`resource_manager.lua` lines 100–122):
- *minimum pool*: at least one spawn of each key inorganic class always exists somewhere (steel, copper, aluminum,
  the three ores, two gemstone classes, a known radioactive, solid and liquid fuel, two polymers, two lube oils);
- *random pool*: 27 spawns drawn by weight (metal 32, gas 16, ore 13, gemstone 12, inert petrochem 8, liquid fuel 7,
  solid fuel 6, radioactive 4, water 2);
- *fixed pool*: iron ×14 (plus JTL space resources, off for us);
- *native pool*: the organics, solar, wind, fiberplast and water vapour, **on every planet** (per-planet variants
  such as "Tatooinian" classes are zone-restricted to that planet).
A non-restricted spawn lives on a random number of planets between its class's min and max (`getSpawnZones`),
so a given steel is on, say, three of the ten planets and nowhere else.

**Where on a planet.** Each spawn carries one *concentration map* per planet (`SpawnDensityMap`): simplex noise
over the whole planet with a random seed, a scale modifier and a density class (high / medium / low), so the
resource is patchy — blobs of 0–100 % concentration, often hundreds of metres across, with most of the planet
near zero. `ResourceSpawn:getDensityAt(zone, x, y)` is the ground truth; surveying reads the same function.

**How long.** The manager reshuffles every 2 h (`averageShiftTime`); a spawn lasts 6–22 days for organics and
6–11 days for inorganics (`aveduration` 86400 s × class multipliers), then despawns and something new appears.
The current state is persisted in the ODB and in `resource_manager_spawns.lua` (7 MB, written by the server).

**For a citizen.** Resources are a galaxy-wide, time-limited treasure hunt. Nothing in the game tells a player
where a resource is; real players used community spreadsheets (SWGCraft) fed by other players' surveys. Two
honest options for the cast: (a) a *resource intelligence* oracle (a Lua binding over `ResourceManager`
listing current spawns per planet with attributes and the best concentration spots) that stands in for the
community spreadsheet, and the citizen still has to travel there, survey and work it; (b) blind surveying,
which would take an AI days of walking. (a) is the plan; the gatherers' surveys could even feed a shared
"spreadsheet" file that crafters read, which is exactly how the real game's economy ran.

## 2. Surveying and sampling (`resourcespawner/ResourceSpawner.cpp` 820–1030, `SurveyCommand`, `SampleCommand`)

- A **survey tool** per resource family (mineral, chemical, flora, gas, water, wind, solar, lumber;
  `object/tangible/survey_tool/`) with a range (64 m up to 1024 m by tool grade) and a grid of 3–5 points per
  side. `/survey` with a resource chosen on the tool sends a `SurveyMessage` (0x877F79AC): the grid's x, y and
  percentage. The client draws it; a seat must decode it (not yet done).
- `/sample` at a spot: fails when the local density is under 10 % or under `32 − (surveying/20)·6` %; otherwise
  every few seconds it yields `density × (25–28) × surveying/100` units (×5 on a lucky "gamble" or a "rich node"
  event the server offers through a window). `surveying` is the Artisan survey skill mod (10 at novice, up to
  100 at master). Sampling into a resource container in the inventory; containers stack per spawn.
- The list of resources the tool can survey comes from the server (`ResourceListForSurveyMessage`
  0x8A64B1D5) when the tool is used; the choice is sent back as a command.

**For a citizen.** Needed seat primitives: `survey` (decode the grid → walk to the best point → re-survey until
the gradient flattens), `sample` (a loop with the rest timer). Both are plain commands plus two packets to
decode. Sampling is slow (a few hundred units an hour); it covers an artisan's own small batches, not an
armorsmith's output.

## 3. Harvesters, power and lots (`objects/installation/`, `bin/scripts/object/installation/`, `StructureManager`)

- **Deeds** for harvesters are crafted by Artisans/Architects or bought (the stock dealers do not sell them;
  our 2.2/2.3 brokers could). Templates: `mining_ore` (personal, style 1/2, heavy), `mining_gas`,
  `mining_liquid`, `mining_organic` (flora and creature harvesters), and `generators` (solar, wind, fusion) that
  make the power the harvesters burn.
- **Placing**: the `placeStructure` command with `"<deed oid> <x> <y> <angle 0–3>"`, within 100 m of the player,
  outdoors, not inside a stock city region, on a flat enough footprint, costing the structure's `lotSize` (1 for
  harvesters) of the character's lots (20 on our server). The real client has a placement mode; the seat can
  send the command directly.
- **Running**: the owner picks the active resource from the spawns present at that spot
  (`HarvesterResourceDataMessage` → `setActiveResource`); the actual rate is `extractionRate × local density`
  per hour into a hopper (`hopperSizeMax`), while **maintenance** (`baseMaintenanceRate` 60–90 credits/h) and
  **power** (`basePowerRate` ~75 units/h, from generators or bought power) are paid from deposits; when either runs
  dry the harvester stops, and unpaid maintenance eventually destroys it. Emptying the hopper is one packet
  (ObjController 0xED `EmptyHopper`: harvester, resource, quantity, retrieve/discard). All of this is driven by
  radial options and server UI windows the seat can already answer (`--sui`), or by the packets directly.
- A spawn vanishing (section 1) leaves the harvester idle: an owner must come back and switch it or redeed it.

**For a citizen.** A gatherer's week: read the oracle, travel, survey to the blob's centre, place 2–4 harvesters,
deposit maintenance and power, come back every day or two to empty hoppers (a seat on a shuttle), list the
resource on the bazaar, move the harvesters when the spawn dies. That is a real player's life, and it is all
commands and windows the seat can send. Needed primitives: `place_structure`, `harvester_set_resource`,
`harvester_deposit`, `harvester_empty`, `redeed`.

**Built 2026-10-20 (7.6a).** `placeStructure` is one command (`PlaceStructureSession` builds the structure at once
and sends it; the deed is consumed; a lot is taken). The harvester's own commands: `harvesterGetResourceData`
(→ `HarvesterResourceDataMessage`, ObjController 0xEA: every spawn of the harvester's type on the planet with its
density *at the harvester*), `harvesterSelectResource <spawn oid>`, `harvesterActivate` / `harvesterDeactivate`;
the hopper is emptied with ObjController 0xED (`EmptyHopper`: harvester, spawn, units, retrieve/discard). Paying
maintenance and depositing power are the owner's radial options 129 and 51 on the structure: each opens a
**transfer box** whose answer carries two arguments, the second being the amount; power comes from the energy
resource containers (wind, solar, radiant…) in the inventory (`getAvailablePowerFromPlayer`, weighted by the
resource's potential energy). The hopper, the surpluses and the rates are not pushed to a bot client in a form
worth decoding (baseline 7 of the installation), so the citizens read them server-side (`FbLabTests:harvester`)
— the owner's status window, in effect. `tools/seat place` / `harvester` are the primitives; `redeed` is still to do.
Numbers from the first run (ore harvester style 1 at 4400,−4700 on Tatooine, a 17 % spot): maintenance 30/h, power
25/h, extraction rate 120 × 0.17 = 20.6 units/h; a crafted deed decides the rate and the hopper size (a lab deed has 0
until `deedValues`). Building is refused inside the city's no-build region, which reaches ~700 m past the Mos Eisley
walls (`canBuild` tells).

## 4. Crafting (`objects/player/sessions/crafting/CraftingSession*`, `commands/*Crafting*`, `*Schematic*`)

- A **crafting tool** per family (generic, weapon, armor, clothing, food, structure, droid, ship) in the
  inventory, plus a **crafting station** for anything above the tool's complexity limit (public stations stand in
  every city; private ones in houses). The draft schematics a character knows come from skill boxes (plus the
  loot schematics our 2.2 broker sells).
- **Flow** on the wire: `requestCraftingSession` (target = the tool, station found nearby) → the server pushes the
  schematic list → `selectDraftSchematic <index>` → the server pushes the ingredient slots (what class, how many)
  → `CraftingAddIngredient` (ObjController 0x107: slot, resource container or component, quantity) per slot →
  `nextCraftingStage <counter>` (assembly: success roll from assembly skill against complexity; the resource
  attributes weighted per schematic become the item's stats) → optional `CraftingExperiment` (0x106: points per
  stat line; the experimentation skill decides the odds) → `createPrototype <counter> <make item>` or
  `createManfSchematic` (a manufacturing schematic for a factory run) → the item lands in the inventory.
  Fourteen `ObjectControllerMessage`s and several delta messages come back during a session.
- Quality: each schematic weights resource stats (a rifle's damage leans on the steel's conductivity and
  quality, armour on shock resistance…), so a crafter needs the *right* resource, not just the class.

**For a citizen.** The crafter playbook is the biggest seat job of all: decode the session's messages, keep the
inventory model (containers, quantities), pick resources by the schematic's weights. Plan it as its own item
(7.6b) after gathering (7.6a); until then crafters can buy the 2.2/2.3 brokers' goods and list loot.

## 5. Travel (`managers/planet/PlanetManagerImplementation.cpp` 515–548, `PurchaseTicketCommand`, `BoardShuttleCommand`)

- Fares come from `datatables/travel/travel.iff` per planet pair (symmetric); a ticket is bought near a travel
  terminal with the command `purchaseTicket <from planet> <from point> <to planet> <to point> [single]` and
  boarded with `boardShuttle` next to the shuttle while it is landed (our shuttle away time is 60 s, 1.7).
  Points are the stock shuttleports/starports (`travel points` per planet); starports go off-world,
  shuttleports stay on the planet.
- For a seat both are plain commands plus the inventory ticket; the zone switch is a login-like reload the
  client already survives (the scene restarts; our packet handler acks the teleport).

**For a citizen.** `travel_to(planet, city)` = walk to the terminal, buy, walk to the shuttle, board, wait for
the scene. Credits matter: fares are hundreds of credits, harvesters cost thousands a week.

**Built 2026-10-20 (7.6a).** The terminals are not in the world snapshot: they are `childObjects` of the port
building's template (`object/building/<planet>/starport_<planet>.lua`, `shuttleport_<planet>.lua`), spawned by
the server with the building. A **starport's four ticket terminals stand inside the building (cell 4)**; a
**shuttleport's one stands outdoors** by the pad. So an interplanetary trip means walking through the starport
door: `findPath` now takes cells and returns cell-local rows, and the seat's `walk` sends
`DataTransformWithParent` for them. `purchaseTicket` wants the character within 8 m of a travel terminal and
answers with `@base_player:prose_pay_acct_success` plus a plain message box; the ticket is a `TRAVELTICKET`
(0x2012) object in the inventory. `boardShuttle` wants the shuttle within 25 m and, when it is away, says
"The next shuttle will be ready to board in N minutes and M seconds." (our away time 60 s, landed 120 s,
landing 11/14 s). Boarding is `switchZone`: the character is destroyed from the old world and a second
`CmdStartScene` starts the new one (same planet or not), so a client must treat the old scene's objects as
gone. `tools/seat travel` strings it together; `FbLabTests:travelPoints:<planet>` is the lookup.

## 6. Trade (`AuctionManager`, 2.5 bazaar limits, 2.10 vendors)

- Bazaar terminals in every city: up to 100 listings per character for a year (our 2.5), price caps as stock;
  resource containers, components and finished goods all list. The bot already sells, buys and retrieves
  (`--sell/--buy/--retrieve`). Player vendors need an owned structure (2.10).
- Mail and `/tell` carry requests; the citizens' `directory.json` says who makes what.

**For a citizen.** The economy loop is: gatherers list resources → crafters buy, craft, list goods → fighters buy
goods and sell loot. Credits start at 100k on this server, so the loop can run from day one.

## 6a. Combat on the wire (read 2026-10-21, `CombatQueueCommand`, `AttackCommand`, `LootCommand`)

- `attack <target>` is a queue command that starts combat and lands one swing of the equipped weapon; the SWG client
  re-sends it while auto-attack is on. `defaultattack` is the AI's command (`AiAgentImplementation` queues it); a
  player sending it is refused with INVALIDLOCOMOTION. Range: `max(10, weapon max range)` (unarmed ~5 m), else
  `@error_message:target_out_of_range`. The defender's swings come back as combat spam the bot client does not decode,
  so a seat reads its own HAM and the target's death from the server (`ham`, `objectAlive`).
- `loot <corpse> all` (`PlayerManager::lootAll`) empties a dead AI agent's inventory into yours within range; it
  sends no queue acknowledgement on success.

**For a citizen.** `hunt` = nearest matching creature → walk to reach → attack every 3 s → loot; retreat at a third of
health. Grouping, assist and follow (7.4 proper) are next.

## 7. What this means for the cast (decision 2026-10-20)

Resources are transient and scattered, so a crafter who never leaves town has nothing to craft with. Two
things, both: (1) every crafter can survey and sample (the Artisan line gives it) and will travel for what the
bazaar lacks; (2) **gatherer citizens** who live on the road, run harvesters galaxy-wide and feed the bazaar —
two added to the cast (Wex Toren, Osra Brenn; `docs/Citizens-Cast.md` 11–12). The oracle (section 1) is their
spreadsheet; the trips, surveys and hopper runs are real. Roadmap: 7.6 split into 7.6a gathering (survey,
sample, harvesters, travel, resource oracle) and 7.6b crafting sessions.
