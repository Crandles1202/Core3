#!/usr/bin/env bash
# Phase 2.9 stop audit (manual: not part of `swg test all`, ~3 min). Places the traveling merchant
# at every stop in turn, teleports the character next to him and runs a two-screen conversation.
# A stop where the greeting arrives but the option pick gets no reply means the NPC is unreachable
# there (underground, inside geometry) — exactly what the first Bestine spawn looked like before
# getTerrainHeightAt existed. Leaves the merchant at the last stop.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NPC=fb_traveling_merchant
N=$(lab "merchantStops" | grep -c '^INFO merchant_stop ')
check_gt "stops_known" "$N" 0 "$N stops"

for idx in $(seq 1 "$N"); do
	STATUS=$(lab "merchantMove:$idx" | grep '^INFO merchant ' | head -1)
	PLANET=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]planet=\([a-z0-9_]*\).*/\1/p')
	LABEL=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]label=\(.*\) x=.*/\1/p')
	MX=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]x=\([-0-9]*\).*/\1/p')
	MY=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]y=\([-0-9]*\).*/\1/p')
	OID=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
	TAG=$(printf '%s' "$LABEL" | tr ' ' '_' | tr -cd 'A-Za-z0-9_')
	if [ -z "$OID" ] || [ "$OID" = "0" ]; then
		check "stop${idx}_${TAG}_spawned" 0 "$STATUS"
		continue
	fi
	Z=$(lab "npc:$NPC" | grep "oid=$OID " | head -1)
	check "stop${idx}_${TAG}_spawned" "$( [ -n "$Z" ] && echo 1 || echo 0 )" "$STATUS"

	bot_bg --wait 12
	wait_online || die "$CHAR never came online"
	lab "travel:$CHAR:$PLANET:$((MX + 2)):$MY" >/dev/null
	wait "$BOT_PID"

	bot --wait 3 --converse "$OID" --options 1 --wait 1    # option 1 = "Where are you headed next?"
	RC=$?
	OK=$( [ "$RC" = 0 ] && grep -aq 'shuttles are cheap' "$BOTLOG" && echo 1 || echo 0 )
	check "stop${idx}_${TAG}_conversable" "$OK" "exit=$RC at $PLANET $MX,$MY"
done

finish
