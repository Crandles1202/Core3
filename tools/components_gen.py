#!/usr/bin/env python3
"""components_gen.py — the component depot's catalogue (Final Boss 2.15), generated from the game's own data.

Every loot item whose object is a crafting component (object/tangible/component/**, plus the lightsaber crystals and the
krayt pearl) becomes a row made through createLoot, so the part carries real rolled stats; every component *template*
no loot item makes (droid, structure, vehicle, food, munition …) becomes a raw row given from the template, which the
schematics accept but which carries no experimental values. Edit this generator, not the Lua it writes.

  tools/components_gen.py            # writes MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_component_depot_catalogue.lua
  tools/components_gen.py --list     # prints the catalogue
"""
import glob, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MMOCoreORB", "bin", "scripts")
OUT = os.path.join(ROOT, "screenplays", "tasks", "tatooine", "fb_component_depot_catalogue.lua")
COMPONENT = "object/tangible/component/"
SKIP_FOLDERS = ("dna", "bio", "item/quest_item", "food/secrets", "base", "vehicle/base")
LOOT_LEVEL, ADVANCED_LEVEL = 50, 70
PRICES = {"loot": 2000, "advanced": 6000, "chemistry": 1000, "lightsaber": 5000, "raw": 500}
FOLDER_NAMES = {
    "weapon": "Weapon parts", "weapon/lightsaber": "Lightsaber parts", "armor": "Armor parts", "chemistry": "Chemistry parts",
    "clothing": "Clothing parts", "munition": "Munitions", "droid": "Droid parts", "droid/repair": "Droid repair parts",
    "structure": "Structure parts", "vehicle": "Vehicle parts", "food": "Food parts", "item": "General parts",
    "instrument": "Instrument parts", "scope_weapon": "Weapon parts",
}
WORDS = {"enhancement": "enhancement", "max": "max", "min": "min", "hp": "HP", "dmg": "damage", "dna": "DNA", "cdef": "CDEF", "e11": "E11", "dh17": "DH17", "dl44": "DL44", "x34": "X-34", "av21": "AV-21", "x31": "X-31"}

# ---- the game's own names: a template's objectName is "@table:key"; the table lives in string/en/<table>.stf inside one of the
# stock archives (the first archive in Core3.TreFiles that has it wins, like the server and the client)
import importlib.machinery
_TRE = None
_TABLES = {}
_ARCHIVES = None

def _tre():
    global _TRE
    if _TRE is None:
        _TRE = importlib.machinery.SourceFileLoader("tre", os.path.join(os.path.dirname(os.path.abspath(__file__)), "tre")).load_module()
    return _TRE

def _archives():
    global _ARCHIVES
    if _ARCHIVES is None:
        cfg = open(os.path.join(ROOT, "..", "conf", "config.lua")).read()
        m = re.search(r"TreFiles\s*=\s*\{(.*?)\}", cfg, re.S)
        names = re.findall(r'"([^"]+\.tre)"', m.group(1)) if m else []
        # the archive folder: config-local.lua (the real one, git-ignored), then config.lua, then /tre
        tre_path = None
        for cf in (os.path.join(ROOT, "..", "conf", "config-local.lua"), os.path.join(ROOT, "..", "conf", "config.lua")):
            if os.path.exists(cf):
                mm = re.search(r'TrePath\s*=\s*"([^"]+)"', open(cf).read())
                if mm and os.path.isdir(mm.group(1)):
                    tre_path = mm.group(1)
                    break
        tre_path = tre_path or "/tre"
        _ARCHIVES = []
        for n in names:
            f = os.path.join(tre_path, n)
            if os.path.exists(f):
                try:
                    with open(f, "rb") as fh:
                        _ARCHIVES.append(_tre().tre_read(fh.read()))
                except Exception:
                    pass
    return _ARCHIVES

def stf_table(table):
    if table not in _TABLES:
        _TABLES[table] = {}
        want = "string/en/%s.stf" % table
        for recs in _archives():
            rec = next((r for r in recs if r.name == want), None)   # (tre's own _find exits the process on a miss)
            if rec is not None:
                _TABLES[table] = dict(_tre().stf_decode(rec.data()))
                break
    return _TABLES[table]

# the server's component templates carry no objectName (it lives in the client template inside the archives), but the
# stock string keys are the template's file stem in the folder's crafting table — tried in that order, then the others
FOLDER_TABLES = {
    "item": "craft_item_ingredients_n", "droid": "craft_droid_ingredients_n", "droid/repair": "craft_droid_ingredients_n",
    "weapon": "craft_weapon_ingredients_n", "weapon/lightsaber": "craft_weapon_ingredients_n", "armor": "craft_armor_ingredients_n",
    "clothing": "craft_clothing_ingredients_n", "chemistry": "craft_medicine_ingredients_n", "food": "craft_food_ingredients_n",
    "structure": "craft_structure_ingredients_n", "munition": "craft_munition_ingredients_n", "vehicle": "craft_vehicle_ingredients_n",
    "instrument": "craft_instrument_ingredients_n",
}
ALL_TABLES = ["craft_item_ingredients_n", "craft_droid_ingredients_n", "craft_weapon_ingredients_n", "craft_armor_ingredients_n",
              "craft_clothing_ingredients_n", "craft_medicine_ingredients_n", "craft_food_ingredients_n", "craft_structure_ingredients_n",
              "craft_munition_ingredients_n", "craft_vehicle_ingredients_n", "craft_tissue_ingredients_n", "craft_furniture_ingredients_n",
              "craft_instrument_ingredients_n", "item_n"]

def game_name(template_path):
    lua = os.path.join(ROOT, template_path[:-4] + ".lua")
    if os.path.exists(lua):
        m = re.search(r'objectName\s*=\s*"@([^:"]+):([^"]+)"', open(lua).read())
        if m:
            text = stf_table(m.group(1)).get(m.group(2))
            if text:
                return text.strip()
    stem = os.path.basename(template_path)[:-4]
    folder = folder_of(template_path)
    for table in [FOLDER_TABLES.get(folder)] + ALL_TABLES:
        if table and stem in stf_table(table) and stf_table(table)[stem].strip():
            return stf_table(table)[stem].strip()
    return None

def human(stem):
    parts = [WORDS.get(p, p) for p in stem.split("_") if p]
    return " ".join(p if p.isupper() or "-" in p else p.capitalize() for p in parts)

def folder_of(path):
    rest = path[len(COMPONENT):]
    return rest.rsplit("/", 1)[0] if "/" in rest else "item"   # a template at the component root is a general part

def loot_items():
    rows = {}
    for f in glob.glob(os.path.join(ROOT, "loot", "items", "**", "*.lua"), recursive=True):
        s = open(f).read()
        for m in re.finditer(r'^(\w+)\s*=\s*\{(.*?)\n\}', s, re.S | re.M):
            name, body = m.group(1), m.group(2)
            t = re.search(r'directObjectTemplate\s*=\s*"([^"]+)"', body)
            if not t or not t.group(1).startswith(COMPONENT) or "/quest_item/" in t.group(1):
                continue
            if not re.search(r'addLootItemTemplate\("%s"' % re.escape(name), s):
                continue
            rows[name] = t.group(1)
    return rows

def templates():
    out = []
    for f in glob.glob(os.path.join(ROOT, "object", "tangible", "component", "**", "*.lua"), recursive=True):
        base = os.path.basename(f)
        if base in ("serverobjects.lua", "objects.lua") or base.startswith("base_") or base.endswith("_base.lua"):
            continue
        rel = os.path.relpath(f, os.path.join(ROOT, "object", "tangible", "component")).replace(os.sep, "/")
        folder = rel.rsplit("/", 1)[0] if "/" in rel else "item"
        if any(folder == s or folder.startswith(s + "/") for s in SKIP_FOLDERS):
            continue
        path = COMPONENT + rel[:-4] + ".iff"
        if not re.search(r'addTemplate\(', open(f).read()):
            continue
        out.append((folder, path))
    return out

def build():
    loot = loot_items()
    made = set(loot.values())
    cats = {}
    for name, path in sorted(loot.items()):
        folder = folder_of(path)
        cat = FOLDER_NAMES.get(folder, human(folder)) 
        adv = name.endswith("_advanced")
        price = PRICES["advanced"] if adv else PRICES["lightsaber"] if "lightsaber" in folder else PRICES["chemistry"] if folder == "chemistry" else PRICES["loot"]
        base = game_name(path) or human(name[:-9] if adv else name)
        shown = base + " (advanced)" if adv and not base.lower().startswith("advanced") else base   # the game's name often says Advanced already
        cats.setdefault(cat, []).append(dict(name=shown, loot=name, level=ADVANCED_LEVEL if adv else LOOT_LEVEL, price=price, template=path))
    for folder, path in sorted(templates()):
        if path in made:
            continue
        cat = FOLDER_NAMES.get(folder, human(folder)) + " (raw)"
        cats.setdefault(cat, []).append(dict(name=game_name(path) or human(os.path.basename(path)[:-4]), template=path, price=PRICES["raw"]))
    for items in cats.values():
        seen = {}
        for it in items:
            n = it["name"]
            if n in seen:
                it["name"] = "%s [%s]" % (n, os.path.basename(it["template"])[:-4])
            seen[n] = True
    order = sorted(cats, key=lambda c: (c.endswith("(raw)"), c))
    return [(c, cats[c]) for c in order]

def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def write(cats):
    lines = ["-- fb_component_depot_catalogue.lua — GENERATED by tools/components_gen.py (Final Boss 2.15); edit the generator.",
             "-- Rows with `loot` are made through createLoot at `level` (real rolled stats); rows without are the bare template (raw).",
             "FbComponentDepotCatalogue = {"]
    for cat, items in cats:
        lines.append("\t{ name = %s, items = {" % lua_str(cat))
        for it in items:
            if "loot" in it:
                lines.append("\t\t{ name = %s, loot = %s, level = %d, price = %d, template = %s }," % (lua_str(it["name"]), lua_str(it["loot"]), it["level"], it["price"], lua_str(it["template"])))
            else:
                lines.append("\t\t{ name = %s, template = %s, price = %d }," % (lua_str(it["name"]), lua_str(it["template"]), it["price"]))
        lines.append("\t} },")
    lines.append("}")
    open(OUT, "w").write("\n".join(lines) + "\n")

def main(argv):
    cats = build()
    if "--list" in argv:
        for cat, items in cats:
            print("%s (%d)" % (cat, len(items)))
            for it in items:
                print("   %-48s %6d cr  %s" % (it["name"], it["price"], it.get("loot", "raw")))
        return 0
    write(cats)
    print("wrote %s: %d categories, %d rows (%d with stats, %d raw)" % (os.path.relpath(OUT), len(cats), sum(len(i) for _, i in cats),
          sum(1 for _, i in cats for it in i if "loot" in it), sum(1 for _, i in cats for it in i if "loot" not in it)))
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
