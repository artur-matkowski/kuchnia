#!/bin/bash
#
# Capture one freeze and say where the GUI thread was when it happened.
#
#     scripts/build.sh host
#     scripts/collect-freeze.sh
#     scripts/collect-freeze.sh report logs/freeze-<stamp>/run.log
#
#     --bin PATH      the binary to run      (default build/host/kuchnia)
#     --config PATH   its config             (default ./config.conf)
#     --out DIR       where the capture goes (default logs/freeze-<stamp>)
#
# It does not build. A binary older than the sources is refused rather than measured, because
# a capture of the wrong code reads exactly like a capture of the right one. What the report
# says, and what to press while it runs, is docs/diagnostics.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }
die()   { echo "error: $*" >&2; exit 1; }

# Both topics, and neither of them by raising everything: PERF carries the spans and the
# watchdog, QT carries the frame timings, and the other five stay at info so the log is
# readable. Qt prints those timings only for categories that are switched on, and they arrive
# as debug messages - so the rules and the topic are both needed, and either one alone
# answers nothing about frames. The four categories are named and not globbed: the fifth,
# qt.scenegraph.time.renderer, prints a line per frame saying what render= already said.
LEVEL='info,QT=debug,PERF=debug'
RULES='qt.scenegraph.time.renderloop=true;qt.scenegraph.time.glyph=true;qt.scenegraph.time.texture=true;qt.scenegraph.time.compilation=true'

strip() { sed -r 's/\x1b\[[0-9;]*m//g' "$1"; }

report() {
	local log="$1"
	local out="${2:-$(dirname "$log")/report.txt}"
	local clean
	clean="$(mktemp)"
	strip "$log" > "$clean"

	{
		echo "=== what drew it ==="
		[ -f "$(dirname "$log")/env.txt" ] && cat "$(dirname "$log")/env.txt"
		grep -E 'renderer:|DRAWN ON THE CPU|font:|key bindings:' "$clean" || true
		echo

		echo "=== every press, and what it cost ==="
		echo "    A stall inside a span names the function. A stall with no span open is the"
		echo "    render thread: read sync= and render= on the frame beside it."
		echo

		awk -f - "$clean" <<'AWK'
function seconds(field,   parts) {
	gsub(/[\[\]]/, "", field)
	split(field, parts, ":")
	return parts[1] * 3600 + parts[2] * 60 + parts[3]
}
{
	n++
	at[n]   = seconds($2)
	text[n] = $0
	if ($3 == "span" && $4 == "action.menu") {
		presses++
		ends[presses]  = at[n]
		costs[presses] = $5
		when[presses]  = $2
	}
}
END {
	if (presses == 0) {
		print "    no `span action.menu` in this log - the menu key was never pressed, or"
		print "    PERF was not at debug. Nothing below can be read."
		exit
	}

	printf "    %-3s %-14s %10s %10s  %s\n", "#", "at", "action ms", "stall ms", "where"
	for (i = 1; i <= presses; i++) {
		from = ends[i] - costs[i] / 1000 - 0.05
		to   = ends[i] + 3.0

		stall = 0; where = "-"; sync = 0; render = 0
		for (j = 1; j <= n; j++) {
			if (at[j] < from || at[j] > to)
				continue
			if (text[j] ~ /has been blocked for/) {
				split(text[j], f, "blocked for ")
				split(f[2], g, " ")
				if (g[1] + 0 > stall) {
					stall = g[1] + 0
					where = (text[j] ~ /inside /) \
						? substr(text[j], index(text[j], "inside"), 48) \
						: "no span open - the render thread or Qt itself"
				}
			}
			if (text[j] ~ /Frame rendered/) {
				if (match(text[j], /sync=[0-9]+/))
					{ v = substr(text[j], RSTART + 5, RLENGTH - 5) + 0; if (v > sync) sync = v }
				if (match(text[j], /render=[0-9]+/))
					{ v = substr(text[j], RSTART + 7, RLENGTH - 7) + 0; if (v > render) render = v }
			}
		}
		printf "    %-3s %-14s %10.1f %10d  %s\n", i, when[i], costs[i], stall, where
		printf "    %-3s %-14s worst frame in the 3 s after it: sync=%d ms render=%d ms\n", "", "", sync, render
	}
}
AWK
		echo

		echo "=== the timeline of each press ==="
		awk -f - "$clean" <<'AWK'
function seconds(field,   parts) {
	gsub(/[\[\]]/, "", field)
	split(field, parts, ":")
	return parts[1] * 3600 + parts[2] * 60 + parts[3]
}
{
	n++
	at[n] = seconds($2)
	text[n] = $0
	if ($3 == "span" && $4 == "action.menu") { presses++; ends[presses] = at[n]; costs[presses] = $5 }
}
END {
	for (i = 1; i <= presses; i++) {
		from = ends[i] - costs[i] / 1000 - 0.2
		to   = ends[i] + 3.0
		printf "\n--- press %d ---\n", i
		for (j = 1; j <= n; j++) {
			if (at[j] < from || at[j] > to)
				continue
			if (text[j] !~ /\[PERF\]/ && text[j] !~ /\[QT\]/)
				continue
			# A frame that took no time is not evidence of anything, and at sixty a second
			# there are two hundred of them per press.
			if (text[j] ~ /Frame rendered/) {
				if (!match(text[j], /in [0-9]+ms/))
					continue
				if (substr(text[j], RSTART + 3, RLENGTH - 5) + 0 < 8)
					continue
			}
			print "    " text[j]
		}
	}
}
AWK
		echo

		echo "=== the twenty slowest spans in the whole run ==="
		awk '$3 == "span" { printf "%10.2f ms  %-32s %s\n", $5, $4, $2 }' "$clean" |
			sort -rn | head -20
		echo

		echo "=== frames ==="
		if grep -q 'Frame rendered' "$clean"; then
			grep -c 'Frame rendered' "$clean" | sed 's/^/    frames timed: /'
		else
			echo "    NO FRAME TIMINGS IN THIS LOG. Qt printed none, so nothing here can say"
			echo "    whether the GUI thread was waiting on the render thread. Check that the"
			echo "    run had QT_LOGGING_RULES='$RULES' and --log-level with QT=debug."
		fi

		echo
		echo "=== every stall, in order ==="
		grep -E 'has been blocked for|answering again|ended with the gui thread' "$clean" |
			sed 's/^/    /' || echo "    none - the gui thread never went quiet for 250 ms"
	} > "$out"

	rm -f "$clean"
	echo "$out"
}

MODE=run
BIN="$ROOT/build/host/kuchnia"
CONFIG="$ROOT/config.conf"
OUT=""
LOG=""

while [ $# -gt 0 ]; do
	case "$1" in
		report)     MODE=report; shift; LOG="${1:-}"; [ $# -gt 0 ] && shift ;;
		--bin)      BIN="$2"; shift 2 ;;
		--config)   CONFIG="$2"; shift 2 ;;
		--out)      OUT="$2"; shift 2 ;;
		-h|--help)  usage ;;
		*)          echo "error: unknown argument $1" >&2; usage ;;
	esac
done

if [ "$MODE" = report ]; then
	[ -n "$LOG" ] || die "report needs a run.log"
	[ -f "$LOG" ] || die "no such log: $LOG"
	echo "==> $(report "$LOG")"
	exit 0
fi

[ -x "$BIN" ] || die "no binary at $BIN - run: scripts/build.sh host"
[ -f "$CONFIG" ] || die "no config at $CONFIG - kuchnia is always run against a local one"

# A binary older than the tree measures code nobody is looking at, and the report says nothing
# about which. Refuse rather than mislead.
STALE="$(find "$ROOT/src" "$ROOT/CMakeLists.txt" -type f -newer "$BIN" -print -quit)"
[ -z "$STALE" ] || die "$(basename "$BIN") is older than $STALE - run: scripts/build.sh host"

OUT="${OUT:-$ROOT/logs/freeze-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"

{
	echo "    when:     $(date '+%F %T %Z')"
	echo "    commit:   $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
	echo "    dirty:    $(git -C "$ROOT" status --short 2>/dev/null | tr '\n' ' ')"
	echo "    host:     $(uname -srm)"
	echo "    qt:       $(qmake6 -query QT_VERSION 2>/dev/null || qmake -query QT_VERSION 2>/dev/null || echo unknown)"
	echo "    binary:   $BIN"
	echo "    config:   $CONFIG"
} > "$OUT/env.txt"

cat <<EOF

==> capturing into $OUT

    While it is up:

      1. wait for the cameras to come up
      2. press the MENU key - SPACE unless you have rebound it
      3. press CONFIRM to open the card the strip is standing on
      4. repeat 2 and 3 twice more, so there are THREE presses

    Three, because that is the measurement: a cost paid only on the first press is the
    scene graph being built, and one paid on all three is the state machine or a stream.

    Then close the window, and the report is written.

EOF

if [ -t 0 ]; then
	printf '    press ENTER to start... '
	read -r _
fi

set +e
QT_LOGGING_RULES="$RULES" QSG_RENDER_TIMING=1 \
	"$BIN" --configpath "$CONFIG" --log-level "$LEVEL" 2>&1 | tee "$OUT/run.log"
STATUS=${PIPESTATUS[0]}
set -e

echo
echo "==> kuchnia exited $STATUS, $(wc -l < "$OUT/run.log") lines"
report "$OUT/run.log" > /dev/null
sed -n '/=== every press/,/=== the timeline/p' "$OUT/report.txt"
echo "==> $OUT/report.txt"
