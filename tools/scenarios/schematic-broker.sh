#!/usr/bin/env bash
# Phase 2.2: schematic broker. The bot talks to the broker (conversation screens); the oracle buys
# through the screenplay's public purchase() (SUI windows cannot be driven by the bot); the bot then
# uses the datapad with the real "Learn Schematic" radial (id 50) and the oracle confirms the draft
# schematic is known and the cash was taken. Also checks the refusal path: a schematic whose
# requiredSkill the character lacks must not be sold.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NPC=fb_schematic_broker
# positive path: Throw Pillow (Furniture & Decor), needs crafting_artisan_domestic_01
BUY_NAME="Throw Pillow"; BUY_PRICE=400; BUY_SKILL=crafting_artisan_domestic_01
BUY_DRAFT="object/draft_schematic/furniture/furniture_throwpillow.iff"
BUY_TEMPLATE="loot_schematic/throwpillow_schematic"
# refusal path: Cantina Chair needs crafting_artisan_master
NO_NAME="Cantina Chair"

# --- stage: find the broker, stand next to them ------------------------------------------------
LINE=$(lab "npc:$NPC" | grep '^INFO npc ' | head -1)
OID=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
ZONE=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]zone=\([a-z0-9_]*\).*/\1/p')
NX=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
NY=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
check "broker_spawned" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "oid=$OID zone=$ZONE at $NX,$NY"
[ -n "$OID" ] || die "no $NPC spawn found"

bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:$ZONE:$((NX - 2)):$NY" >/dev/null
wait "$BOT_PID"

# --- act 1: the conversation ------------------------------------------------------------------
bot --wait 2 --converse "$OID" --options 1 --wait 1    # option 1 = "How does a bought schematic work?"
check_eq "converse_client_exit_0" "$?" "0"
check "greeting_mentions_schematics" "$(grep -aqi 'schematics, friend' "$BOTLOG" && echo 1 || echo 0)"
check "explain_screen_reached" "$(grep -aqi 'labelled with the profession box' "$BOTLOG" && echo 1 || echo 0)"

# --- act 2: refusal without the skill, then purchase with it (character must be online) -------
bot_bg --wait 20
wait_online || die "$CHAR never came back online"
CASH0=$(lab_kv "cash:$CHAR" cash)
check_eq "refused_without_skill" "$(lab_kv "buySchematic:$CHAR:$NO_NAME" result)" "no_skill"
check_eq "refusal_took_no_credits" "$(lab_kv "cash:$CHAR" cash)" "$CASH0"

HAS=$(lab_kv "skill:$CHAR:$BUY_SKILL" has)         # awardSkill grants the prerequisite boxes too; no-op if known
check_eq "skill_granted_for_purchase" "$HAS" "true" "$BUY_SKILL has=$HAS"
RESULT=$(lab_kv "buySchematic:$CHAR:$BUY_NAME" result)
check_eq "purchase_ok" "$RESULT" "ok" "purchase() -> $RESULT"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "price_deducted" "$(( CASH0 - CASH1 ))" "$BUY_PRICE" "cash $CASH0 -> $CASH1"
SOID=$(lab_kv "findItem:$CHAR:$BUY_TEMPLATE" oid)
check "schematic_item_in_inventory" "$( [ -n "$SOID" ] && echo 1 || echo 0 )" "oid=$SOID"
wait "$BOT_PID"

# --- act 3: learn it through the real radial -------------------------------------------------
if [ -n "$SOID" ]; then
	bot --wait 2 --radial "$SOID" 50 --radial-settle 1500 --wait 1   # 50 = "Learn Schematic" (LootSchematicMenuComponent)
	check_eq "use_client_exit_0" "$?" "0"
fi
check_eq "draft_schematic_known" "$(lab_kv "hasSchematic:$CHAR:$BUY_DRAFT" has)" "1"

finish
