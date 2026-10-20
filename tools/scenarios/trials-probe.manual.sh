#!/usr/bin/env bash
# Diagnostic (manual): the riddle conversation after a long logout gap, with positions.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bot_bg --wait 100
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null; sleep 8
lab "attunementReset:$CHAR" >/dev/null; lab "attunementSet:$CHAR:100" >/dev/null; lab "attunementAccept:$CHAR" >/dev/null
lab "attunementWorlds:$CHAR:naboo,corellia,talus,rori,lok,tatooine" >/dev/null; lab "trialsUnlock:$CHAR" >/dev/null
lab "trialSetDone:$CHAR:stillness,restraint,strength,mercy,farwalk" >/dev/null
lab "travel:$CHAR:tatooine:-6506:-3668" >/dev/null; sleep 3
T=$(lab "trialTick:$CHAR"); RIDDLE=$(sed -n 's/.*riddle=\([1-3]\).*/\1/p' <<<"$T" | head -n1)
say "--- word: riddle $RIDDLE"
say "--- spirit: $(lab "trialTick:$CHAR" | grep -a trialTick)"
sleep 14
SPIRIT=$(lab "findNpc:fb_trial_spirit" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
say "--- spirit: $(lab "objectPos:$SPIRIT" | cut -c1-160)"
say "--- goto: $(lab "gotoNpc:$CHAR:fb_trial_spirit" | tail -n1 | cut -c1-120)"
say "--- where before logout: $(lab "where:$CHAR" | cut -c1-140)"
for t in 5 20 40; do sleep 15; say "--- spirit +$t s: $(lab "objectPos:$SPIRIT" | sed 's/.*zone=/zone=/' | cut -c1-80)"; done
say "--- screenlog mentions: $(grep -a "$SPIRIT" "$REPO/MMOCoreORB/bin/screenlog.0" | grep -av 'runLuaFunction\|INFO' | tail -n2 | cut -c1-160)"
wait "$BOT_PID"
sleep 8
say "--- spirit while logged out: $(lab "objectPos:$SPIRIT" | cut -c1-160)"
case "$RIDDLE" in 1) RIGHT=0 ;; 2) RIGHT=1 ;; 3) RIGHT=2 ;; *) RIGHT=0 ;; esac
bot_bg --wait 6 --converse "$SPIRIT" --options "$RIGHT" --wait 6
sleep 4
say "--- where after login: $(lab "where:$CHAR" | cut -c1-140)"
say "--- spirit after login: $(lab "objectPos:$SPIRIT" | cut -c1-160)"
wait "$BOT_PID"
say "--- converse: $(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1)"
say "--- $(lab "trials:$CHAR" | cut -c1-200)"
finish
