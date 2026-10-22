#!/usr/bin/env bash
# probe: a talk after a login at the spot (no teleport in the session) vs after a lab teleport in the session
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# A: at the spot with the enemy beside, then log out
bot_bg --wait 25
wait_online || die "never online"
lab "attunementReset:$CHAR" >/dev/null
lab "attunementFlag:$CHAR:padawan:1" >/dev/null; lab "attunementFlag:$CHAR:alignment:light" >/dev/null; lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
lab "jediMasterTake:$CHAR" >/dev/null; for t in stillness shadows rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done
lab "knightGive:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:4100:-4700" >/dev/null
CHIEF=$(lab "knightBossHere:$CHAR" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
say "chief=$CHIEF  $(lab "objectPos:$CHIEF" | sed 's/.*zone=/zone=/' | cut -c1-70)"
wait "$BOT_PID"
# B: login at the spot, no teleport, talk
bot --wait 10 --converse "$CHIEF" --options 0 --wait 2 >/dev/null 2>&1 || true
say "B no-teleport talk: $(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-140)"
say "B state: $(lab "knight:$CHAR" | head -n1 | cut -c1-160)"
# C: a fresh enemy (the first may be gone), login, teleport 30 m in the session, enemy beside, talk
lab "knightGive:$CHAR" >/dev/null 2>&1   # a second enemy if the first was spared
bot_bg --wait 24 --converse "$(lab "knight:$CHAR" | sed -n 's/.*boss=\([0-9]*\).*/\1/p' | head -n1)" --options 0 --wait 2
wait_online || die "never back"
lab "travel:$CHAR:tatooine:4130:-4700" >/dev/null
CHIEF2=$(lab "knightBossHere:$CHAR" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
wait "$BOT_PID"
say "C teleport-in-session talk (chief2=$CHIEF2): $(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-140)"
say "C positions: chief $(lab "objectPos:$CHIEF2" | sed 's/.*zone=/zone=/' | cut -c1-60) char $(lab "where:$CHAR" | sed 's/.*zone=/zone=/' | cut -c1-70)"
check "probe_ran" 1
finish
