# SWG Pre-CU Server: Vision & Roadmap

A solo-friendly, multiplayer-optional, Star Wars–immersive Pre-CU server. **Roadmap v0.1 — for discussion, not commitment.**

---

## Vision in one paragraph

A Star Wars Galaxies Pre-CU server where a single player can experience the full game — exploration, combat, crafting, Jedi training, the Galactic Civil War — without ever needing to coordinate with another human. The galaxy feels *lived in*: NPCs run businesses, faction patrols clash on planet roads, Imperial garrisons get hit by Rebel raids in real time, bounty hunters hunt loose Jedi. Multiplayer features still work — bazaars accept other players' goods, cities can be founded, groups can form for harder content — but nothing is *gated* behind needing other people. The economy and storyline run with or without players.

The Pre-CU rules and systems stay intact. We're not changing combat or skill trees or the resource system. We're filling in the social and economic gaps with NPCs and replacing player-required content with quest content.

---

## Design principles

Everything below the line should serve these.

1. **Solo-completable, multiplayer-rewarded.** Any system that locks behind needing other players gets an NPC alternative. Players who do team up should still get a slight bonus (faster, more loot, harder content unlocked) — but never required.  
2. **Living world.** The galaxy moves whether the player is online or not. Faction territories shift. Vendor stock rotates. NPCs travel. Even an empty server should feel populated.  
3. **Star Wars feels.** When something is canon (Hoth has Wampas, Mos Eisley has a Cantina full of weirdos, Bespin has carbonite), lean into it. When something contradicts canon (player-built cities on Coruscant), tweak or hide it.  
4. **Earned, not handed.** Solo-friendly ≠ trivial. Jedi unlock should feel like an actual training journey, not a vendor purchase. Loot should reward exploration. Boost XP rates *modestly* (2x, not 50x).  
5. **Reversible changes.** Every customization lives in its own git branch and feature flag. We can roll any of this back without bricking the server.

---

## Open design questions

These shape everything else. Pick now or revisit as we go — but flagging them so we don't accidentally lock in an answer.

| \# | Question | Options | My lean |
| :---- | :---- | :---- | :---- |
| Q1 | **Timeline / era** | (a) Original Trilogy era between ANH and ESB (the SWG default). (b) Alternate timeline — pick the divergence point. (c) Empire-dominant ("Empire in Flames"–style). | (a) — keeps canon assets working, lets us add OT moments as quests |
| Q2 | **Jedi rarity** | (a) Common — anyone who completes the quest line becomes one. (b) Rare — gated by hidden traits at character creation (Awakening model). (c) Gated by major story milestone — must defeat X first. | (a) for solo accessibility, but make the quest *long* |
| Q3 | **Sith implementation** | (a) Alignment within Jedi profession (light/dark choice during training). (b) Separate Sith profession with own quest chain. (c) Dark-side path is fully canon-named (Master/Apprentice rule of two, etc.). | (a) — much less work, still feels meaningful |
| Q4 | **NPC bounty hunters** | (a) Always-on threat once you're a Jedi — they appear at intervals. (b) Triggered by player actions (using saber in public, killing certain NPCs). (c) Reputation system — visibility level rises and falls. | (c) — canonical "visibility" mechanic with NPC threat scaling |
| Q5 | **XP rates** | (a) 1x stock SWG. (b) 2x (Tarkin's Revenge default). (c) 3-5x. (d) Variable per profession. | (b) 2x — solo-friendly without trivializing |
| Q6 | **Crafting balance** | (a) Crafted gear is best, NPC gear is filler. (b) Roughly equivalent — NPC gear is convenient, crafted is customized. (c) Quest reward gear is best, both crafting and NPC are mid-tier. | (b) — preserves crafting profession value |
| Q7 | **PvP / Death** | (a) No PvP, gentle death penalty. (b) Faction PvP allowed but opt-in. (c) Full canon — Special Forces flag \= PvP everywhere. | (b) — opt-in faction PvP, gentle death |
| Q8 | **GCW progression** | (a) Static — Empire always slightly winning, like OT. (b) Player actions slowly tilt it. (c) Story arc — Empire wins early, Rebels gain ground over months. | (c) — feels alive over real-world time |
| Q9 | **Custom planets** | (a) Stick to canon 12\. (b) Add 1–2 canon planets (Hoth, Bespin). (c) Add 3+ canon planets. (d) Add custom-designed planets (Empire in Flames model). | (b) start, expand to (c) over time |
| Q10 | **Server-wide pacing** | (a) Single-player game pacing (\~100 hours total content). (b) MMO pacing (1000+ hours). (c) Sandbox — no defined endgame. | (c) with strong (a)-flavored opening |

---

## The roadmap

Six phases, ordered by dependencies and momentum. The numbers in `[brackets]` are rough effort estimates: `[T]` tiny (\<1hr) · `[S]` small (1–4hr) · `[M]` medium (1–3 days) · `[L]` large (1–2 weeks) · `[XL]` massive (1–3 months) · `[XXL]` huge (3+ months)

### Phase 0 — Foundation (do this BEFORE customizing anything)

Lock in the dev environment so we don't shoot ourselves in the foot.

- **0.1 \[T\] Enable WSL2 mirrored networking.** End the WSL2-IP-reboot pain. `C:\Users\rac35\.wslconfig` → `networkingMode=mirrored`, `wsl --shutdown`, then revert galaxy table \+ login.cfg to `127.0.0.1`.  
- **0.2 \[T\] Change DBSecret in config-local.lua.** It's currently the published default `swgemus3cr37!`. Pick a long random string. Re-hash existing accounts.  
- **0.3 \[S\] Set up database backups.** Cronjob inside Debian to `mysqldump swgemu` to `~/backups/` daily, keep last 7 days. One bad migration without backups \= full restart.  
- **0.4 \[S\] Set up a sane branching strategy.** Stay on `unstable` as the base. Each feature on a `feature/<name>` branch. Tag stable known-good commits as `chuck-stable-YYYYMMDD`.  
- **0.5 \[T\] Feature-flag everything.** Add a `~/workspace/Core3/MMOCoreORB/bin/conf/custom-features.lua` that any of our customizations check before activating. Lets us turn things off without rolling back code.  
- **0.6 \[S\] Set up an admin character that's separate from your "play" character.** Standard practice — admin-level 15 character used only for ops, level-0 character for playing.

### Phase 1 — Quick wins (build momentum, see real changes fast)

Cheap, visible improvements. Most are single-file Lua tweaks. Stealing liberally from Tarkin's Revenge.

- **1.1 \[T\] 2x XP rate** across all professions.  
- **1.2 \[T\] Generous starting credits** for new characters (5,000 or 10,000 instead of stock 100).  
- **1.3 \[T\] Starter gear pack** — every new character gets a basic ranged weapon, melee weapon, basic clothes, 10 stimpacks.  
- **1.4 \[S\] Mission terminals show level \+ direction choice.** Tarkin's Revenge has this in their Lua — port it.  
- **1.5 \[T\] Increased inventory and lots.** Tarkin: 100 base inventory (up from 80), 20 lots per character.  
- **1.6 \[T\] Resource stack size to 10M.** Removes container management busywork.  
- **1.7 \[T\] Faster shuttle / starport times.** Reduce travel-time waiting.  
- **1.8 \[T\] Vehicle/pet call cooldown to 5 seconds.** From 30\.  
- **1.9 \[S\] Stimpacks heal mind damage.** Pre-CU mind damage required an entertainer, which is a multiplayer dependency. This single change is huge for solo play.  
- **1.10 \[T\] No-grind entertainer profession.** XP gain works even when nobody's watching you play.  
- **1.11 \[T\] Group XP/loot bonus when you ARE grouped.** Carrot for multiplayer, not stick for solo. \~25% bonus.

>   
> ☞ The buff-vendor system was originally here as "medical terminals." It got promoted to its own section in Phase 2 — see **2.6 NPC buff providers** below. Buff terminals are unsatisfying compared to actual NPCs you walk up to and interact with.

**Branch:** `feature/qol-pack`. One commit per change. Test each on its own branch first.

### Phase 2 — Solo Enablement (NPC economy)

The big "make crafting solo-friendly without nerfing it" phase. This is where your vision starts taking shape.

- **2.1 \[M\] NPC shopkeepers selling crafted-equivalent gear.** Place vendors in starter cities (Mos Eisley, Theed, Coronet). Each sells a curated rotating inventory: basic armor sets, basic weapons, basic clothing. **Pricing higher than player-crafted equivalents** to preserve player-crafter value. Stock rotates weekly (real time).  
    
- **2.2 \[M\] Schematic vendors.** NPCs in major cities sell starter and intermediate schematics for credits. Master-tier schematics still require quest rewards or rare drops — preserves the chase.  
    
- **2.3 \[S\] Component vendors.** Some sub-components (chassis, basic power packs, generic loot kits) sold by NPCs to let solo crafters complete chains without a buddy in every profession.  
    
- **2.4 \[M\] Loot kits (system-generated crafted-equivalent items).** When mobs drop "Jedi Robes Kit" or "Composite Armor Schematic Fragment", anyone — not just a crafter — can assemble it. Doesn't replace crafting; provides an alternative path.  
    
- **2.5 \[S\] Bazaar improvements.** Item search filters, 1-year listing times, 100 listings per character (per Tarkin). Bazaars remain the canonical player-economy hub.  
    
- **2.6 \[L\] NPC buff providers (location-based, immersive).** Replace the "terminal vending machine" model with actual NPCs you visit where it makes sense for them to be. Walking up to a medical droid in a medcenter to buy a Doctor buff. Sitting in a cantina watching an entertainer to gain a Mind buff. This is *the* signature solo-immersion feature.  
    
  **The roster:**


| NPC type | Where they spawn | What they provide | Player-profession parallel |
| :---- | :---- | :---- | :---- |
| **Medical droid / NPC doctor** | Medcenters in every major city | Strength / Constitution / Quickness / Stamina / Focus / Willpower enhancement buffs. Wound treatment. | Doctor |
| **NPC medic** | Medcenters, military outposts | Basic healing, wound packs, stimpacks for sale | Medic / Combat Medic |
| **Cantina entertainer (musician)** | Mos Eisley Cantina, Theed Spaceport Cantina, etc. | Mind wound healing, Focus/Willpower mind buff | Musician / Entertainer |
| **Cantina entertainer (dancer)** | Same cantinas | Mind wound healing, alternate mind buff flavor | Dancer / Entertainer |
| **Image designer / stylist** | Tailor shops in major cities | Cosmetic services (hair, makeup, body sculpt) | Image Designer |
| **Recruitment officer** | Imperial / Rebel military bases | Tactical buffs (defense, accuracy) — faction-aligned | Squad Leader (group-buff equivalents) |
| **Slicer / tech contact** | Shadier parts of starport districts | Slicing services for weapons/armor (durability/damage boost) | Smuggler |


  **The cantina mechanic specifically (this one's special):**


  - Walk into a cantina with an NPC entertainer on stage.  
  - Sit at a chair / on the floor within range of the stage.  
  - A "Listening / Watching" status appears.  
  - Mind wounds heal at \~3x normal rate while seated.  
  - After 2 minutes of continuous watching, the Mind buff applies and you can stand up.  
  - Paying a tip to the entertainer NPC (right-click → tip) shortens the wait or grants a stronger buff.


  **The medcenter mechanic:**


  - Walk up to medical droid / NPC doctor.  
  - Right-click → "Request medical service" → menu of available buffs with prices.  
  - Pay credits → buff applied \+ wounds healed.  
  - Costs scale with buff power. Healing wounds is cheaper than enhancement buffs.


  **Critical balance: NPC buffs are deliberately weaker / pricier than player-crafter equivalents.**


  - NPC doctor: enhancement of \+500, lasts 1 hour, costs 5,000 credits  
  - Player Master Doctor (with quality docs): enhancement of \+2000, lasts 3 hours, costs whatever they want  
  - This keeps the Doctor profession economically valuable to a multiplayer server while letting solo players function.  
  - Same principle for entertainers: NPC entertainer gives a fixed-quality mind buff; player entertainers can produce much better buffs.


  **Faction-aligned variants:**


  - Imperial medcenters have Imperial NPC medical droids (free buffs for Imperial-affiliated characters, paid for neutral)  
  - Rebel safehouses have Rebel NPC medics (mirror of above)  
  - Neutral cities have neutral NPCs that charge everyone the same  
  - Adds a meaningful reason to declare for a faction beyond PvP

  > 

  > ☞ The NPC framework built here directly enables **Phase 3.7 (ambient public-space life)** and **Phase 3.8 (cantina personality differentiation)**. Once you can spawn an NPC entertainer on a cantina stage that gives buffs, you can spawn ambient patrons in the same building, and you can vary the entertainer and patron mix by location to make Mos Eisley feel different from Theed.


- **2.7 \[M\] NPC pet trainers.** Creature Handler is already solo-friendly, but pre-Master CH players (and other professions who want a pet) can buy basic combat / utility pets from NPC trainers in stables outside major cities. Pet quality and variety scale with the trainer's reputation tier. Player Master CHs still dominate the elite/exotic pet market — NPCs sell common stock, players sell custom-bred specialists.  
    
- **2.8 \[M\] NPC architects / decor vendors.** Solo players need housing too. NPC vendors in residential districts sell basic decor (paintings, furniture, plants, signage, lighting). Player Architects still own the high-end custom-build market (multi-story, signature furniture, themed houses). Same balance pattern as the buff providers.  
    
- **2.9 \[M\] Traveling Merchant NPC.** A wandering merchant that shows up in random cities for a few hours at a time selling rare/unusual items (cosmetic, low-power but interesting). Borrowed from Tarkin's Revenge. Massive immersion boost.  
    
- **2.11 \[M\] Mos Eisley Trade Hall (server-placed building, proof of concept).** A stock building shell spawned by a screenplay on an empty lot by the starport, with the Final Boss vendors moved inside (armory, armor, medical supplies, parts, schematics, pets, property, speeders…), a greeter at the door and a line on the HoloNet so players find it. Proves the pattern for every later shop, enclave or quest site: pick a flat lot from the world snapshot, spawn the building each boot (stock screenplay pattern, not persisted), spawn the NPCs into its cells, audit floors and line of sight, walk the bot through the door. Custom names/signage for the building come with the TRE object-template work (Phase 4.0 follow-up). Decided with Chuck 2026-10-18.
- **2.10 \[S\] Vendor maintenance auto-skim.** Vendors automatically retain 5% of each sale to top up maintenance. Solves "player goes on vacation, vendor decays, items disappear" — particularly painful for solo players running their own shops.

**Branch:** `feature/npc-economy`.

### Phase 3 — Living Galaxy (NPCs make the world go)

Make the galaxy feel populated even when you're the only player online.

- **3.1 \[M\] GCW invasion events.** NPC-driven faction invasions of cities. Three cities at first (Bestine on Tatooine, Keren on Naboo, Dearic on Talus). Two-phase battles (Construction → Combat). The canonical SWG GCW invasion system, but the invasion fires automatically every X hours regardless of player count. Players can participate but aren't required.  
    
- **3.2 \[M\] Faction patrols.** Imperial and Rebel patrols wander between key POIs on each planet. Encountering enemy patrol \= combat. Solo players get appropriate-level patrols; aware of recent player level.  
    
- **3.3 \[M\] Dynamic mob density.** Spawn density tied to time of day / weather / events. Tatooine at night has Tusken raids. Endor during a storm has Ewoks gathering at villages.  
    
- **3.4 \[L\] Faction territory map.** Each region has a faction control %. Player actions and NPC events shift it. Affects patrol density, vendor faction, mission types available.  
    
- **3.5 \[M\] Story event ticker.** Once a week (real time), a galaxy-wide event fires — "Death Star sighted in Yavin sector", "Rebel cell captured on Corellia", "Bounty placed on senator X". These spawn limited-time quests anyone can grab.  
    
- **3.6 \[M\] Galaxy chatter.** NPCs in cantinas, on shuttles, near major landmarks say things relevant to current events. "Did you hear about the Imperial garrison on Naboo?" Static for now, eventually dynamic.  
    
- **3.7 \[M\] Ambient cantina / public-space life.** Cantinas, starports, hospitals, military bases — every social location gets ambient NPC patrons. They drink, eat, gamble, dance, argue, react to events.  
    
  - **Cantina patrons:** sit at tables nursing drinks, occasional "huttese chatter" emotes, react when a fight breaks out, look up when a new player enters  
  - **Starport travelers:** queue near shuttles, sit on benches checking datapads, react when shuttle arrives/departs  
  - **Hospital wounded:** sit on benches with bandaged sprites — periodically replaced as "patients" get "treated"  
  - **Military base soldiers:** drill formations, patrol the perimeter, salute officers  
  - **The point:** every location should *feel populated* even on an empty server. No more sterile rooms.


- **3.8 \[M\] Cantina personality differentiation.** Every cantina shouldn't feel like every other cantina. Use the cantina-entertainer system from Phase 2.6 as the foundation; layer on location-specific flavor.  
    
  - **Mos Eisley Cantina (Tatooine):** the canonical "wretched hive." Figrin D'an's band on stage. Diverse alien clientele. Bartender (Wuher) sells drinks. Occasional NPC-vs-NPC bar fights. Smuggler contacts hang out here.  
  - **Theed Spaceport Cantina (Naboo):** elegant, refined. Live string musician. Mostly humans and Gungans. No fights — security guards eject troublemakers fast.  
  - **Coronet Cantina (Corellia):** working-class, pilot-heavy. Slightly louder, gambling tables in the back. Pazaak or Sabacc if we can wire it up.  
  - **Dearic Cantina (Talus):** sleepy backwater feel. Few patrons. Cheaper drinks. Local NPCs gossip about events on other planets.  
  - **Bestine Cantina (Tatooine, alt):** Imperial-leaning. Stormtroopers occasionally drop in. Quieter than Mos Eisley but tenser.  
  - Same framework, different inputs — each location is a Lua data file describing patron mix, ambient events, music type, average tip rate.


- **3.9 \[M\] Weather as world events.** Real-time weather that *matters* mechanically, not just visually.  
    
  - **Tatooine sandstorms:** reduce visibility for everyone in the zone, spawn extra Tusken Raider patrols, slow vehicle speed  
  - **Hoth blizzards** (post-Phase 5): freeze unprepared travelers (cold-damage tick), reduce visibility, Wampa spawns increase  
  - **Naboo rain:** purely cosmetic, but lush  
  - **Endor wind storms:** Ewok villages temporarily lock doors; certain creatures hide  
  - Creates "remember when we got caught in that sandstorm" moments. Weather is otherwise wasted potential in SWG.


- **3.10 \[M\] HoloNet news broadcasts.** Public terminals in every starport and cantina play looping "broadcasts" — current GCW status, recent story events, a "this week's wanted" segment, ambient propaganda from the dominant faction. Makes the world feel like it has news media. Same pipeline as galaxy chatter (3.6) but more produced — has a narrator voice, music sting, fixed-length segments. Players can stand near a terminal and listen.  
    
- **3.11 \[L\] Convoy events.** Imperial supply convoys and Rebel resistance convoys (3–5 NPCs traveling between cities on set routes). Two flavors:  
    
  - **Ambush mode** — players opposite the convoy's faction can attack. Successful ambush → loot drops, faction rep gain. Unsuccessful ambush → reinforcements arrive.  
  - **Escort mode** — players aligned with the convoy can take a quest to protect it. Bandit / opposite-faction NPC ambushers fire midway. Successful escort → credit \+ rep reward.  
  - Pure emergent content. Convoys run on a schedule (every 30–60 min real time), so something is always happening on the main roads.


- **3.12 \[L\] Tatooine podracing.** Recurring social-hub event at Mos Espa Grand Arena. NPC racers compete in scheduled races; players can:  
    
  - **Spectate and bet credits** on race outcomes (lowest barrier, immediate immersion)  
  - **Sponsor an NPC racer** (mid-game — pay credits, get a cut of winnings)  
  - **Race themselves** (endgame — requires owning a podracer, which becomes a custom mount/vehicle quest)  
  - Pure Star Wars vibe. Quest content, gambling sink, social hub all in one.

**Branch:** `feature/living-galaxy`. Depends on Phase 1.4 (mission terminal improvements) and Phase 2.6 (NPC buff providers — uses same NPC framework).

### Phase 4 — Jedi/Sith Rework

The big one. Replace the Village grind with a quest-driven training path. Add a parallel Sith path with light/dark choice.

This phase has more sub-phases than the others because it's the most ambitious change.

**Design decisions (Chuck, 2026-10-18)** — these override the item text below where they differ:

- **Village:** stays on Dathomir as optional content, never part of the unlock or the rank path. No time-gated mechanics anywhere in Phase 4.
- **Unlock = hidden Force attunement score (0–100), `/checkForceStatus` shows vague tiers, never a number.** Sources, each capped so none unlocks alone: *places* (cap 50) — first visit to any of the 48 stock `force_shrine` regions 3, meditating there 6, big Force sites 8 each (Dantooine Jedi temple ruins and Force crystal cave, Exar Kun temple, both Yavin 4 enclaves, Nightsister stronghold, Ben Kenobi's house, krayt graveyard); *learning* (cap 30) — each mastered profession 10; *deeds* (cap 30) — win a fight after being incapacitated in it 5 (daily), kill a Dark Jedi / Nightsister elder / krayt dragon 10, survive a Force power 3; *quests* (cap 40) — Hero of Tatooine 15, any theme park (Jabba, Nym, Imperial, Rebel, Nightsister, Marauder) 10, Warren / Corvette / Death Watch bunker / Geonosian lab 5, krayt skull epic 10; *items* (cap 20) — colour crystal from a crystal cave 10, found holocron 10. Quests pre-tilt alignment (Hero of Tatooine, Rebel light; Jabba, Nightsister, Imperial dark). **Force ghost visits at 25 / 50 / 75**: a robed spirit appears after a fight or at a shrine, speaks, names the nearest unvisited site, fades. At 100 the Old Man comes (stock Sith Shadow ambush may follow). No login-triggered events.
- **Shrines (4a.2):** the stock shrines are the shrines; "6 shrines unlock the trials" = meditate at a shrine on 6 different planets (10 stock planets now, 12 after Phase 5).
- **Alignment / rank (4b.3, Q3/Q4):** FRS voting and enclave politics are off (solo server). The FRS rank skill trees (`force_rank_light_*` / `force_rank_dark_*`) become the visible Jedi / Sith ladder; each promotion is a quest from your Master. Switching sides (redemption / temptation) is a quest chain open at every rank, Knights and Lords included, and drops you to the lowest rank of the new side; Jedi skill boxes are kept.
- **Masters (4b.1/4b.2):** custom characters, canon figures only in visions (4a.4). Jedi Master in the Light Jedi Enclave (Yavin 4, −5575 4910), Sith Master in the Dark Jedi Enclave (Yavin 4, 5068 310). Enclave doors open to anyone on the path (stock admits FRS members only).
- **Crystals (4a.0 / 4b.6):** colour stays cosmetic (stock: colour crystals carry only a colour; power crystals and krayt pearls carry the stats). Crystal caves yield colour crystals by rarity plus rare power crystals. Abilities, Jedi XP and saber crafting stay stock; only the way you earn the Padawan box changes.
- **Death (Q7):** no Jedi-specific death penalty.
- **Bounty (4c):** hunters open fire, they never talk. Hunter frequency and strength scale with visibility and rank, up to a squad for a high-visibility Master. Visibility fades with time (stock), the bounty itself never shrinks; it can be paid off through a shady fixer in a cantina for a markup.
- **Custom TRE (4.0, prerequisite):** `finalboss.tre` built from `tre-src/` by `tools/tre`, shipped to the server's TrePath and the client folder, carries every custom string (skill names, rank titles, item names, quest journal text, system messages). Everyone who connects needs the file.
- **Fresh start:** no migration of Village progress; the server is declared playable later.

#### 4a — Force Sensitive intro (replaces Village hologrind)

- **4a.0 \[M\] Lightsaber crystal hunting.** Pre-Jedi but Jedi-curious players can explore caves on Dantooine, Lok, Dathomir, Tatooine to find rare crystal nodes. Crystals are collectibles at first — you don't know what they're for yet. Different colors (blue, green, yellow, purple, cyan) drop at different rarities and from different caves. Solves the "what do I do *before* unlocking Jedi" gap perfectly — players have something Force-adjacent to chase from day one, even if they never go full Jedi. Crystals later become lightsaber components and signature-ability gates (see 4b.6).  
- **4a.1 \[L\] "The Old Man" intro quest chain.** Triggered by hitting certain mastered professions (e.g. Master Marksman \+ Master Brawler) OR a discoverable artifact (a Force-resonant crystal from 4a.0 in your inventory works too — natural progression). A mysterious NPC contacts the player, gives them their first Force-sensitive task.  
- **4a.2 \[L\] Hidden Force shrines on every planet.** 12 shrines (one per planet). Visit, meditate, learn one fragment of the Jedi lore. Encourages exploration. Completing 6+ unlocks Padawan trials.  
- **4a.3 \[L\] Padawan trials.** A series of 8–16 small quests (skill checks, fights, decisions) that test the character's discipline. **Critical decision point in this phase:** at trial 4 or 5, a moral choice (kill the prisoner / spare them) sets your starting light/dark alignment.  
- **4a.4 \[L\] Force vision quest line.** Dream sequences triggered at major milestones (after the Old Man visit, after each shrine, before key trials). The player enters a vision — a small instanced area — where canonical Force users appear (Yoda, Obi-Wan, Vader, etc.) and deliver short bits of lore or counsel. Crucially, **they never appear in the physical game world** — only in visions. Lets us use canon characters for immersion without breaking lore (no "Yoda is in Theed Cantina" weirdness). Vader visions skew dark, Yoda visions skew light, etc.

#### 4b — Master/Apprentice quest chain

- **4b.1 \[L\] Jedi Master NPC.** Once Padawan trials complete, the player is assigned a Jedi Master NPC. Each Master is a unique character (canonical or custom — your choice). Master gives quests that advance Jedi training.  
- **4b.2 \[L\] Sith Master NPC alternate path.** If you chose the dark path in 4a, you instead encounter a Sith Master who corrupts you. Different quest chain, different abilities focus.  
- **4b.3 \[M\] Light/Dark alignment system.** Actions in-game shift alignment. Certain abilities lock/unlock based on alignment. Both paths can reach Knight rank but with different signature abilities.  
- **4b.4 \[L\] Knight trial quest.** Final exam to graduate from Padawan to Knight. A single, hard, narrative dungeon. Tied to chosen alignment.  
- **4b.5 \[L\] Companion Padawan / Apprentice.** Once you reach Knight, you can take on a companion of your own — same framework, different feel by alignment:  
  - **Light path: Padawan companion.** An NPC apprentice that follows you, fights alongside you, comments on events, and slowly levels up. Treated as a story-driven version of a CH pet. Capstone quest: your Padawan attempts their own Padawan trials (you have to escort them through). Successful completion \= the Padawan becomes a Knight and goes their own way, leaving you with a unique reward.  
  - **Dark path: Apprentice companion.** Mechanically similar, but the relationship is canonically corrupt. At any time you can **betray your apprentice** — kill them and absorb their power (one-time stat boost, alignment shift further dark). Alternative: **train them fully** and one day they betray *you* (random chance scaling with their level — they kill you, take your stuff, you respawn with a permanent narrative "former master" title). Pure Sith canon. Risk and consequence built in.  
- **4b.6 \[M\] Lightsaber color \= ability flavor.** The crystal you slot into your saber (from 4a.0) determines your signature ability flavor, not just cosmetics:  
  - **Blue (common)** — balanced; small boost to all saber attacks  
  - **Green (uncommon)** — defensive; better saber block, longer parry windows  
  - **Yellow (uncommon)** — stamina-focused; lower action cost per swing  
  - **Purple (rare)** — aggressive; higher damage at cost of accuracy  
  - **Cyan (rare)** — utility; minor force-power regen boost  
  - **Red (dark only, rare)** — pure damage; significant boost but locks you out of light-side abilities  
  - Crystals can be swapped, but recrafting a saber is expensive — choices have weight.

#### 4c — NPC bounty hunters

- **4c.1 \[M\] Visibility system.** Canonical SWG mechanic — actions raise your "visibility". Using saber in public, killing imperial NPCs as a Jedi, etc. High visibility → bounty placed.  
- **4c.2 \[M\] NPC bounty hunter spawns.** When a bounty is active, NPC BH(s) hunt the player. Bounty hunter difficulty scales with player level and visibility. Defeat one → cooldown before next.  
- **4c.3 \[S\] Bounty hunter NPC tracking missions for BH profession players.** BH players can take NPC bounty contracts independently — gives the BH profession solo content too.  
- **4c.4 \[M\] Dark Jedi spawns hunt light-aligned players** and vice versa, at high alignment. Adds risk to picking a side hard.

**Branch:** `feature/jedi-rework`. Depends on Phase 3 (living galaxy) for ambient world.

### Phase 5 — New Planets

The hardest content to add. Requires terrain data, POIs, spawns, quests. **Don't build from scratch** — use existing community TRE compilations.

- **5.1 \[L–XL\] Hoth.** Most common community addition. Terrain \+ Wampa caves \+ Echo Base ruins. Available in the [ModTheGalaxy TRE compilation](https://modthegalaxy.com/) — port their planet data, add custom spawns and quests on top. Themed quest chain: "What happened to Echo Base?"  
- **5.2 \[XL\] Bespin / Cloud City.** Atmospheric flying city. Vendor-heavy, low-combat planet — perfect for a "social hub" alternative. Boss fight: carbonite-freeze chamber.  
- **5.3 \[XL\] Mustafar.** Volcanic, high-level. Endgame zone. Boss fight: dueling on lava platforms. Themed around uncovering Sith ruins.  
- **5.4 \[XXL\] Mandalore (custom).** No canonical SWG terrain — requires custom build. Lower priority. Mandalorian armor crafting, lore-rich.  
- **5.5 \[M\] Galactic travel map update.** Once a new planet ships, update shuttle routes, fares, the map artwork. Mostly a config job.

**Branch:** `feature/new-planets`. Each planet on its own sub-branch.

### Phase 6 — Story Content

The cherry on top. Once the systems work, the story should write itself.

- **6.0 \[L\] Tutorial revamp — "you crashed on Tatooine".** Replace stock SWG tutorial (which is a sterile space-station orientation) with a narrative starter. Your shuttle is shot down over Tatooine; you wake up near a moisture farm. The farmer points you at Mos Eisley. As you walk, the tutorial introduces every signature system: NPC vendors, cantina entertainers, faction NPCs, mission terminals, the buff system. By the time you arrive in Mos Eisley you've experienced the world we built rather than just been told about it. **This sets the tone for every new player and is probably the single highest-ROI piece of story content we can produce.**  
- **6.1 \[L\] Timeline event chain.** A linear story across the OT timeline. ANH events (Death Star plans, Battle of Yavin) occur in months 1–2 of real time. ESB events in months 3–5. RotJ in months 6+. Players who reach max level can participate in capstone events.  
- **6.2 \[M\] Named NPC interactions.** Han Solo at Mos Eisley cantina (gives smuggling missions). Leia on Yavin (gives Rebel missions). Vader appears as a periodic high-level threat. NOT player-killable — they're story characters.  
- **6.3 \[L\] Themepark dungeons.** Boss-fight instanced content. Death Star Trench (space → ground). Carbonite Chamber (Bespin). Endor Bunker. Two Suns Cantina mystery.  
- **6.4 \[M\] Faction quest chains.** Long-form Imperial and Rebel quest arcs, 20+ missions each, tied into the GCW progression in Phase 3\.  
- **6.5 \[L\] Smuggler / fringe content.** Han Solo–style content. Cargo runs, dodging Imperial patrols, hidden Rebel sympathizer NPCs.

**Branch:** `feature/story-content`.

### Cross-cutting — Polish & Lore (ships continuously)

Doesn't fit a single phase. These ship alongside everything else, a little at a time.

- **P.1 \[M\] Lore codex.** A `/codex` slash command opens an in-game encyclopedia. Each entry unlocks the first time the player encounters the thing (a person, planet, creature, event, faction, weapon). Categories: People, Places, Creatures, Factions, Force Lore, Events. Aim for 200+ entries over the project lifetime, all sourced from canon. Makes the world feel deep — even passive walking around becomes content discovery. Crucially, entries can be added retroactively when we add new content; the codex grows with the server.

**Branch:** `feature/polish-lore`. No phase dependency — start any time after Phase 0\.

---

## Inspiration credit

Where the ideas come from. Worth visiting these sites if you want to see specific implementations.

- [**Tarkin's Revenge**](https://home.tarkinswg.com/) — solo/small-group focus, gold standard for QoL changes, source for medical terminals, traveling merchant, mission terminal improvements  
- [**Sentinels Republic**](https://forum.swgsremu.com/) — gold standard Jedi quest revamp (Old Man → Force Sensitive → Padawan trials)  
- [**SWG Awakening**](https://swgr.org/) — mysterious Jedi unlock, improved BH vs Jedi balance  
- [**SWG Infinity**](https://www.swginfinity.com/about-infinity/) — solid Pre-CU base server, custom content  
- [**Sunrunner 2**](https://swgsunrunner2.com/) — best example of added planets (custom Hoth, Bespin)  
- [**Empire in Flames**](https://www.empireinflames.com/) — alternate timeline \+ custom Schisms of the Force Jedi/Sith system, custom planet Taanab  
- [**Mod The Galaxy**](https://modthegalaxy.com/) — TRE compilation source for added planet data (Lasko's repository)  
- [**SWG Legends**](https://swglegends.com/wiki/) — canonical GCW Invasion system reference (Bestine/Keren/Dearic) — this is post-Pre-CU but ports cleanly  
- [**ProjectSWGCore (Holocore)**](https://github.com/ProjectSWGCore/Holocore) — different era (CU/NGE) but useful for NPC behavior patterns

---

## Dependency graph (what blocks what)

Phase 0 (Foundation) ──┬──\> Phase 1 (Quick wins)

                       │

                       └──\> Phase 2 (NPC economy) ──\> Phase 3 (Living galaxy)

                                                              │

                                                              v

                                                      Phase 4 (Jedi/Sith)

                                                              │

                                                              v

                                            Phase 5 (Planets) \<──\> Phase 6 (Story)

Phases 5 and 6 can interleave — a new planet can ship with story content baked in.

Phases 1 and 2 can run in parallel after Phase 0\.

---

## Concrete next 3 steps

If we did nothing else this week, what would maximize "feeling like progress"?

1. **Phase 0.1 — mirrored networking** (15 minutes). Stops the WSL IP pain. Has to happen anyway.  
2. **Phase 0.2 — change DBSecret \+ rotate passwords** (15 minutes). Security debt that gets harder to fix the longer we wait.  
3. **Pick ONE Phase 1 quick win** to ship end-to-end as a learning exercise. My pick: **2x XP rate** (1.1). It's a single Lua tweak, easy to verify by playing for 10 minutes, teaches the full edit → commit → push → reload workflow.

After that we can pick a direction — knock out the rest of Phase 1 first for visible progress, or jump to Phase 2/3 for the headline solo/immersive features that define your server.

---

## Future ideas / parking lot

Brainstormed but **deliberately not on the initial roadmap.** These got pushed off either because they're nice-to-have polish, dependent on something larger, or scope creep we want to avoid for the first cut. Living list — promote items to the main roadmap whenever they earn it.

### Quick polish (would slot into Phase 1 or as cross-cutting)

- Auto-stand after combat  
- Improved character creator with backstory pick that grants a thematic starter item ("Smuggler" → holster, "Survivor" → med-pack, etc.)  
- Faster pet/mount summon (sub-5-second)  
- NPC fence / junk dealer for low-value loot  
- Surveyor droid rental for solo resource gathering  
- Reliable NPC cloning facility (already-canon but worth verifying it works without depending on a player Doctor)  
- Achievements / titles system (light gamification — "Killed 100 Tuskens", "Visited every cantina", "First Jedi on the server")  
- Photo mode (pause-and-pose for screenshots)  
- In-cantina jukebox NPC — tip to request specific cantina-music tracks

### Living world depth (Phase 3 expansion)

- Day/night cycle drives NPC behavior (vendors close at night, cantinas get rowdier after dusk, nocturnal predators come out)  
- Passive ambient creatures (banthas grazing in the distance, lizards on rocks, birds — visual richness beyond combat mobs)

### Jedi/Sith depth (Phase 4 expansion)

- Holocron discovery system — rare lore drops, some corrupted Sith holocrons shift alignment when used  
- Krayt Dragon hunt as Jedi/endgame capstone — drops a unique lightsaber crystal

### Additional planets (Phase 5 expansion)

- **Kashyyyk** — Wookiee homeworld, mid-tier difficulty, Trandoshan slaver heroic  
- **Dagobah** — Yoda's planet, secret high-level Jedi training, lore-dense one-zone planet, Force vision quest culmination  
- **Felucia** — alien jungle endgame, color-saturated mushroom world

### Story expansion (Phase 6 expansion)

- Death Star plans courier arc — multi-quest chain culminating in the Battle of Yavin  
- Boba Fett bounty board — repeatable high-level NPC bounty contracts themed around famous SW criminals  
- Bothan spy network — stealth/intel quest line for non-combat players  
- Improved mail system — NPC-sent letters tied to story events ("a letter from Mon Mothma...")

When any of these graduates to "let's do it", we'll move it up into the appropriate phase and replace the parking-lot entry with a forward reference.

---

## What I want to know from you

Before we sink real time into any phase, I'd love your gut on:

- **Top 3 phases by excitement.** Where do you most want to see progress first?  
- **Open design questions (Q1–Q10).** Even a "lean toward (a)" is enough.  
- **Time horizon.** Building toward a public launch in 6 months? Or pure private playground, ship-when-ready?  
- **Server name and lore.** What's this place called? What's the elevator pitch when someone asks "what's different about your server?"  
- **Hard "no"s.** Anything in here that you actively *don't* want? (E.g. some folks hate alignment systems, or strongly oppose adding canonical named NPCs.)

We can iterate on this roadmap freely — version it, branch it, throw out phases that don't fit. The point is to argue about it before we write code.

---

*Roadmap v0.1 — generated 2026-05-22 from your stated goals and research across 8 active Pre-CU servers.*  
