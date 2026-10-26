# Loot kits (Phase 2.4) — the quality ladder, draft for sign-off

_Drafted and **signed off by Chuck 2026-10-26** (all six points). Shipped as Phase 2.4 the same day. Numbers are the game's own units: armor
"effectiveness" is the percentage of damage the piece stops, "integrity" is the condition pool a piece wears down
through, weapon damage is the template's damage range scaled._

## The problem the ladder solves

On a solo server one person is the hunter and the crafter. Gear today comes from two places: the Trade Hall shops,
which hand out the raw templates (padded 15 %, bone 20 % energy, nothing above), and crafting, where a good run of
resources and experimentation reaches 60–80 % on composite. Nothing sits between: a hunter who never crafts is stuck
with shop gear, and a crafter has no reason to hunt for anything but resources. Loot kits are the rung between: gear
you earn by fighting, clearly better than any shop, clearly below what a skilled crafter makes.

The rule in one line: **kit gear tops out around two thirds of the best crafted gear, and every kit tier beats every shop.**

## The ladder

| Rung | How you get it | Armor effectiveness (all types) | Integrity | Weapon damage (vs. a well-crafted one) | Purpose |
|---|---|---|---|---|---|
| Shop | Trade Hall vendors (raw templates, as today) | padded 15 %, bone 20 % (energy only) | template default (~1 000–5 000) | CDEF-class, ~35 % | the first hour; never upgraded |
| Stock loot | stock drops (tantel, zam, bh pieces) | 4–19 % | 18 000–31 000 | — | flavour; left as is |
| **Kit I — Scavenged** | kit + 3 parts from level 5–25 mobs | **30 %** (28–33) | 15 000 | **45 %** | the first real set: padded, bone, tatooine-local looks |
| **Kit II — Field** | kit + 4 parts from level 25–55 mobs | **45 %** (42–48) + one special type at +10 % per set | 25 000 | **60 %** | the working set for most of the game: composite, ubese, chitin |
| **Kit III — Veteran** | kit + 5 parts from level 55+ mobs and named enemies, rarer | **55 %** (52–58) + one special at +15 % | 35 000 | **70 %** | the ceiling for a non-crafter: advanced composite, mabari looks |
| Crafted, decent | a crafter with ordinary resources, little experimentation | 50–60 % | 30 000–45 000 | 75–85 % | where a kit III and a plain crafter meet |
| Crafted, good | good resources, experimentation, layers | 65–80 % | 45 000+ | 100 % | the best gear on the server stays crafted |

Specials: composite sets get the +10 % / +15 % on kinetic, ubese on energy, chitin on blast; kit I has none.
Encumbrance follows the template's class (padded light, composite heavy); kits do not improve it.

What kit gear never has: skill-mod sockets, experimentation, repair above its integrity. Those stay crafting's.

## Parts and kits

- **Parts are generic by class and tier**, not per piece: *armor plating* and *armor mesh* (I / II / III), *weapon
  mechanism* and *power cell* (I / II / III). Any kit of that class and tier takes them. Fewer dead drops; a hunter
  always moves toward *some* kit.
- **Kits are per piece**: "Bone Armor Chest Plate Kit (I)", "Composite Armor Boots Kit (II)", "DL44 Pistol Kit (II)".
  Drag parts into the kit (the stock Pre-CU loot-kit object); when the last part lands the finished piece pops out
  with the tier's stats rolled inside its band.
- **Counts**: kit I wants 3 parts, kit II 4, kit III 5. The stock kit object cannot ask for two of the same part, so the
  parts are five *kinds* per class — armor: plating, mesh, fasteners, lining, trim; weapon: mechanism, power cell, barrel
  assembly, reinforcement core, sight — and a tier wants the first 3 / 4 / 5 of them.

## Drops

| What | From | Chance per kill |
|---|---|---|
| Parts I | any humanoid or creature level 5–25 | 7 % |
| Parts II | any humanoid or creature level 25–55 | 6 % |
| Parts III | level 55+, named enemies, the story camps, convoy guards, invasion troops | 5 % |
| Kit I | humanoids level 10–25 (raiders, thugs, pirates) | 3 % |
| Kit II | humanoids level 25–55 (mercenaries, faction troops, Nym's, the park gangs) | 2.5 % |
| Kit III | level 55+ humanoids, named enemies, bounty hunters (4c), the Knight trial bosses | 2 % |

A kit matches its source's armor: Tusken raiders drop bone and padded kits, stormtroopers composite, Nightsisters
chitin. Creatures drop parts, never kits.

## Scope at launch

1. Armor first: padded and bone (I), composite and ubese (II), advanced composite (III), every slot.
2. Weapons second, one line per class: a pistol (DL44), a carbine (DH17), a rifle (E11), a sword, a polearm, a
   one-hand melee.
3. Not now: clothing, droids, vehicles, Jedi gear.

## Engine work

The stock loot-kit object builds its reward straight from the template, which is why stock uses it for rugs and
gongs only. One small change: a kit template may name a *loot item* for its reward, and the kit then asks the loot
manager to make it, so the piece gets the tier's rolled stats. Everything else is data: kit and part templates, loot
items per tier, loot groups by level band, and a lab scenario that drops the parts, assembles a kit through the real
container path and reads the stats.

## Sign-off

- [x] the percentages in the ladder
- [x] generic parts by class and tier
- [x] three tiers, 3 / 4 / 5 parts
- [x] the drop chances
- [x] armor first, then the six weapon lines (both shipped together)
- [x] no skill mods on kit gear
