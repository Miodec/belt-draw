#!/bin/bash
# Runs the in-game tests: starts a separate Factorio instance (own mods and write folder, so it doesn't touch
# your normal game) with the hidden "belt-draw-run-tests" setting on. The main menu simulation then runs
# tests/cases.lua and logs the results, which this script reads.
#
# Usage: tests/run.sh
#   FACTORIO=/path/to/factorio  binary to use (defaults to the Steam install on macOS)
#   TIMEOUT=300                 seconds to wait for the tests to finish
#   ONLY=drawing                only run one file of tests/cases/, or the cases whose name contains this text
#   KEEP_OPEN=1                 leave the game running after the tests, to look at the result
#   FACTORIO_ARGS="..."         extra command line parameters for Factorio
#   WORK=/path                  folder for the test instance's config, mods and caches
#                               (defaults to belt-draw-tests in the temp folder, kept between runs for the sprite cache)

set -u

MOD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO:-$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio}"
TIMEOUT="${TIMEOUT:-300}"
KEEP_OPEN="${KEEP_OPEN:-0}"

# kept between runs: Factorio caches the sprite atlas in it, which skips most of the loading
TEMP_ROOT="${TMPDIR:-/tmp}"
WORK="${WORK:-${TEMP_ROOT%/}/belt-draw-tests}"
WORK="${WORK%/}"
# a test instance left open by KEEP_OPEN still holds the folder
pkill -f -- "--mod-directory $WORK/mods" 2> /dev/null && sleep 1
mkdir -p "$WORK/config" "$WORK/mods"
rm -f "$WORK/factorio-current.log" "$WORK/stdout.log"

# without the version line Factorio says the config is invalid and asks to reset it
cat > "$WORK/config/config.ini" <<EOF
; version=13
[path]
read-data=__PATH__system-read-data__
write-data=$WORK
EOF

ln -sfn "$MOD_DIR" "$WORK/mods/belt-draw"

cat > "$WORK/mods/mod-list.json" <<'EOF'
{
  "mods": [
    { "name": "base", "enabled": true },
    { "name": "elevated-rails", "enabled": false },
    { "name": "quality", "enabled": false },
    { "name": "space-age", "enabled": false },
    { "name": "belt-draw", "enabled": true }
  ]
}
EOF

# mod-settings.dat with belt-draw-run-tests = true. Factorio's property tree format:
# version (4x u16) + a zero byte, then a dictionary of startup / runtime-global / runtime-per-user
python3 - "$WORK/mods/mod-settings.dat" "${ONLY:-}" <<'EOF'
import struct, sys

def string(s):
    if not s:
        return b"\x01"  # the empty flag, no length follows
    data = s.encode()
    assert len(data) < 255
    return b"\x00" + bytes([len(data)]) + data

def boolean(value):
    return b"\x01\x00" + (b"\x01" if value else b"\x00")

def text(value):
    return b"\x03\x00" + string(value)

def dictionary(entries):
    out = b"\x05\x00" + struct.pack("<I", len(entries))
    for key, value in entries.items():
        out += string(key) + value
    return out

settings = dictionary({
    "startup": dictionary({
        "belt-draw-run-tests": dictionary({"value": boolean(True)}),
        "belt-draw-test-filter": dictionary({"value": text(sys.argv[2])}),
    }),
    "runtime-global": dictionary({}),
    "runtime-per-user": dictionary({}),
})
with open(sys.argv[1], "wb") as f:
    f.write(struct.pack("<4H", 2, 1, 23, 2) + b"\x00" + settings)
EOF

LOG="$WORK/factorio-current.log"
echo "Starting Factorio, logs in $LOG"
# startup flags, see https://wiki.factorio.com/Command_line_parameters: the sprite atlas cache skips most of
# the loading; very-low graphics makes rebuilding that cache (after sprites change) about twice as fast
# Steam wants to relaunch the game through itself (dropping these arguments), unless steam_appid.txt
# is in the working directory
echo 427520 > "$WORK/steam_appid.txt"
(cd "$WORK" && exec "$FACTORIO" --config "$WORK/config/config.ini" --mod-directory "$WORK/mods" \
  --cache-sprite-atlas=true --disable-audio --force-graphics-preset=very-low ${FACTORIO_ARGS:-}) \
  > "$WORK/stdout.log" 2>&1 &
PID=$!

result=""
for ((i = 0; i < TIMEOUT; i++)); do
  if ! kill -0 "$PID" 2> /dev/null; then
    echo "Factorio exited early (closed, or a mod error), last log lines:"
    tail -n 30 "$LOG" 2> /dev/null || tail -n 30 "$WORK/stdout.log"
    exit 2
  fi
  result="$(grep -o "BELT-DRAW-TEST DONE.*" "$LOG" 2> /dev/null)"
  [ -n "$result" ] && break
  sleep 1
done

if [ "$KEEP_OPEN" = 1 ]; then
  echo "Leaving Factorio open, its files are in $WORK"
else
  kill "$PID" 2> /dev/null
  wait "$PID" 2> /dev/null
fi

grep -o "BELT-DRAW-TEST .*" "$LOG" | grep -v "BELT-DRAW-TEST ERROR" | sed "s/^BELT-DRAW-TEST //"
# mod errors, with the traceback lines that follow them
grep -A 12 "BELT-DRAW-TEST ERROR" "$LOG" | sed "s/^.*BELT-DRAW-TEST //"
# log lines start with seconds since launch
started="$(grep -m1 "BELT-DRAW-TEST START" "$LOG" | awk '{print $1}')"
finished="$(grep -m1 "BELT-DRAW-TEST DONE" "$LOG" | awk '{print $1}')"
[ -n "$started" ] && echo "Loading took ${started}s, tests took $(echo "${finished:-$started} - $started" | bc)s"
# anything the mod prints (debug output) ends up on stdout
[ "${SHOW_STDOUT:-0}" = 1 ] && cat "$WORK/stdout.log"
# mod errors are caught by tests/control.lua and logged with their traceback. Anything else that goes wrong
# (an error in the tests themselves, a crash) shows up in the log as an Error line
grep -E -A 12 "Error|error" "$LOG" | grep -v "Failed to load player data\|BELT-DRAW-TEST" | head -n 40

if [ -z "$result" ]; then
  echo "Timed out after ${TIMEOUT}s"
  exit 2
fi
case "$result" in
  *" 0 failed"*) exit 0 ;;
  *) exit 1 ;;
esac
