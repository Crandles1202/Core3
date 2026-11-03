#!/usr/bin/env bash
# QoL: the FB-21 medical droid's buffs last eight hours and a second visit resets the clock (stock skipped a buff the
# character already carried). The oracle applies the enhance, reads the health buff's time left, waits, applies again
# and reads it again.
# covers: PlayerManager player_manager medical_droid enhance buff
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bot_bg --wait 25
wait_online || die "$CHAR never came online"
L1=$(lab_kv "enhance:$CHAR" left)
check "buff_lasts_eight_hours" "$( [ "${L1:-0}" -ge 28700 ] && [ "${L1:-0}" -le 28800 ] && echo 1 || echo 0 )" "health buff $L1 s left after the first visit (28800 asked)"
sleep 6
L2=$(lab_kv "buffLeft:$CHAR:2553454441" left)
check "clock_runs_down" "$( [ "${L2:-0}" -lt "${L1:-0}" ] && echo 1 || echo 0 )" "$L1 -> $L2 after six seconds"
L3=$(lab_kv "enhance:$CHAR" left)
check "second_visit_resets_the_clock" "$( [ "${L3:-0}" -gt "${L2:-0}" ] && [ "${L3:-0}" -ge 28700 ] && echo 1 || echo 0 )" "$L2 -> $L3 after the second visit"
wait "$BOT_PID"
finish
