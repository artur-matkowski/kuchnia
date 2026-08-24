#!/bin/bash
#
# Measure the camera streams from outside the application, with ffmpeg alone.
#
#     scripts/probe-rtsp.sh                       # every camera-url in ./config.conf
#     scripts/probe-rtsp.sh URL [URL...]          # these instead, native beside proxied
#     scripts/probe-rtsp.sh report logs/rtsp-<stamp>
#
#     --config PATH   where camera-url is read from   (default ./config.conf)
#     --out DIR       where the capture goes          (default logs/rtsp-<stamp>)
#     --seconds N     length of the steady run        (default 30)
#     --cycles N      open/close repetitions          (default 5)
#
# Everything the application knows about these streams is inference from inside Qt. This is
# the measurement taken outside it: what the stream costs to open, whether it keeps arriving,
# and which of the three RTSP transports it will answer on. What a row means is docs/rtsp.md.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//' >&2; exit 1; }
die()   { echo "error: $*" >&2; exit 1; }

# A capture is pasted into a ticket, and every camera-url carries its password. Redaction is
# applied on the way IN - nothing under the capture directory ever holds a credential.
redact() { sed -E 's|://[^/@]*@|://***@|g' <<< "$1"; }

slug() { sed -E 's|rtsp://||; s|[^A-Za-z0-9]+|-|g; s|^-+||; s|-+$||' <<< "$(redact "$1")"; }

now_ms() { echo $(($(date +%s%N) / 1000000)); }

# ffmpeg and ffprobe write their diagnostics to stderr and their payload to stdout, and the
# wall clock is measured around the whole invocation: an RTSP open is nearly all handshake,
# so process startup is noise beside it.
timed() {
	local guard="$1" out="$2"; shift 2
	local start finish
	start=$(now_ms)
	timeout "$guard" "$@" > "$out.stdout" 2> "$out.stderr" || true
	finish=$(now_ms)
	echo $((finish - start))
}

# The three transports the demuxer can be asked for, and `auto` is the one that matters most:
# it is what Qt's backend uses, so it is the row the application's behaviour is read against.
transport_args() {
	case "$1" in
		auto) ;;
		*)    printf '%s\n%s\n' -rtsp_transport "$1" ;;
	esac
}

measure() {
	local url="$1" transport="$2" dir="$3" seconds="$4" cycles="$5"
	local safe base ms
	local -a targs
	safe="$(redact "$url")"
	base="$dir/$(slug "$url").$transport"

	mapfile -t targs < <(transport_args "$transport")

	# 1. The handshake. -show_streams is what makes a native stream and its proxied twin
	#    comparable at all: same codec, same size, same pixel format, or they are not the
	#    same picture and nothing below can be compared.
	ms=$(timed 30 "$base.probe" ffprobe -hide_banner -loglevel warning "${targs[@]}" \
		-select_streams v:0 -show_entries stream=codec_name,profile,width,height,pix_fmt,r_frame_rate,avg_frame_rate,has_b_frames \
		-of default=noprint_wrappers=1 "$url")
	local handshake=$ms

	local codec size pixfmt fps
	codec=$(sed -n 's/^codec_name=//p'  "$base.probe.stdout" | head -1)
	size="$(sed -n 's/^width=//p' "$base.probe.stdout" | head -1)x$(sed -n 's/^height=//p' "$base.probe.stdout" | head -1)"
	pixfmt=$(sed -n 's/^pix_fmt=//p'    "$base.probe.stdout" | head -1)
	fps=$(sed -n 's/^avg_frame_rate=//p' "$base.probe.stdout" | head -1)

	# An empty codec is the whole row's verdict: the handshake did not complete, and every
	# number after it would be a measurement of nothing.
	if [ -z "$codec" ]; then
		local why
		why=$(grep -oE '[A-Za-z].*' "$base.probe.stderr" | tail -1 | cut -c1-48)
		printf '%s\t%s\t%s\t%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tNO HANDSHAKE: %s\n' \
			"$(slug "$url")" "$safe" "$transport" "$handshake" "${why:-no answer}" >> "$dir/runs.tsv"
		return
	fi

	# 2. Time to first frame, and 3. the same again for a distribution. docs/media.md's "five
	#    to six seconds" to reopen a camera has never been checked against ffmpeg alone.
	local -a times=()
	local i
	for ((i = 0; i < cycles; i++)); do
		ms=$(timed 30 "$base.cycle$i" ffmpeg -hide_banner -nostdin -loglevel warning \
			"${targs[@]}" -i "$url" -frames:v 1 -an -f null -)
		times+=("$ms")
		cat "$base.cycle$i.stderr" >> "$base.cycles.log"
	done
	local sorted
	mapfile -t sorted < <(printf '%s\n' "${times[@]}" | sort -n)
	local cmin=${sorted[0]} cmax=${sorted[-1]} cmed=${sorted[$((cycles / 2))]}

	# 4. The steady run. A stream that opens and then stops being fed is the failure the
	#    application cannot see for itself - here it is a frame count that stops climbing.
	ms=$(timed $((seconds + 30)) "$base.run" ffmpeg -hide_banner -nostdin -loglevel warning \
		"${targs[@]}" -i "$url" -t "$seconds" -an -f null - -progress pipe:1)
	local frames rate errors
	frames=$(sed -n 's/^frame=//p' "$base.run.stdout" | tail -1)
	frames=${frames:-0}
	rate=$(awk -v f="${frames:-0}" -v s="$seconds" 'BEGIN { printf "%.1f", (s > 0 ? f / s : 0) }')
	errors=$(grep -cEi 'corrupt|missed|error|invalid|packet loss|timed out|max delay' "$base.run.stderr" || true)

	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$(slug "$url")" "$safe" "$transport" "$handshake" \
		"$codec" "$size" "$pixfmt" "$fps" \
		"$cmin" "$cmed" "$cmax" \
		"$frames" "$rate" "$errors" "ok" >> "$dir/runs.tsv"
}

# The report renders what was stored and measures nothing, so a capture can be re-read after
# the cameras have moved on.
report() {
	local dir="$1"
	local tsv="$dir/runs.tsv"
	[ -f "$tsv" ] || die "no runs.tsv in $dir - that is not a capture directory"

	{
		echo "=== what was measured ==="
		[ -f "$dir/env.txt" ] && cat "$dir/env.txt"
		echo

		echo "=== the streams themselves ==="
		echo "    Two streams of the same picture must agree on all four, or the rows below are"
		echo "    not comparing one thing carried two ways."
		echo
		printf '    %-46s %-6s %-7s %-11s %-9s %s\n' url transport codec size pix_fmt fps
		awk -F'\t' '{ printf "    %-46s %-6s %-7s %-11s %-9s %s\n", substr($2,1,46), $3, $5, $6, $7, $8 }' "$tsv"
		echo

		echo "=== opening one ==="
		echo "    handshake is ffprobe to stream parameters; the three after it are open to one"
		echo "    decoded picture, over every cycle. The application budgets 20 s for this and"
		echo "    holds a stream off screen rather than pay it again - docs/media.md."
		echo
		printf '    %-46s %-6s %10s %10s %10s %10s\n' url transport 'shake ms' 'min ms' 'med ms' 'max ms'
		awk -F'\t' '{ printf "    %-46s %-6s %10s %10s %10s %10s\n", substr($2,1,46), $3, $4, $9, $10, $11 }' "$tsv"
		echo

		echo "=== keeping one ==="
		echo "    A stream that opens and then quietly stops being fed is the failure the panel"
		echo "    cannot see. Here it is a frame count short of the run."
		echo
		printf '    %-46s %-6s %8s %8s %8s  %s\n' url transport frames fps errors verdict
		awk -F'\t' '{ printf "    %-46s %-6s %8s %8s %8s  %s\n", substr($2,1,46), $3, $12, $13, $14, $15 }' "$tsv"
		echo

		echo "=== every line ffmpeg wrote that was not a frame ==="
		local f
		for f in "$dir"/*.run.stderr "$dir"/*.cycles.log; do
			[ -s "$f" ] || continue
			echo "--- $(basename "$f")"
			sort -u "$f" | sed 's/^/    /'
		done
	} > "$dir/report.txt"

	echo "$dir/report.txt"
}

MODE=run
CONFIG="$ROOT/config.conf"
OUT=""
SECONDS_RUN=30
CYCLES=5
URLS=()

while [ $# -gt 0 ]; do
	case "$1" in
		report)     MODE=report; shift; OUT="${1:-}"; [ $# -gt 0 ] && shift ;;
		--config)   CONFIG="$2"; shift 2 ;;
		--out)      OUT="$2"; shift 2 ;;
		--seconds)  SECONDS_RUN="$2"; shift 2 ;;
		--cycles)   CYCLES="$2"; shift 2 ;;
		-h|--help)  usage ;;
		rtsp://*)   URLS+=("$1"); shift ;;
		*)          echo "error: unknown argument $1" >&2; usage ;;
	esac
done

if [ "$MODE" = report ]; then
	[ -n "$OUT" ] || die "report needs a capture directory"
	[ -d "$OUT" ] || die "no such directory: $OUT"
	echo "==> $(report "$OUT")"
	exit 0
fi

command -v ffprobe >/dev/null || die "no ffprobe - apt install ffmpeg"
command -v ffmpeg  >/dev/null || die "no ffmpeg - apt install ffmpeg"

if [ ${#URLS[@]} -eq 0 ]; then
	[ -f "$CONFIG" ] || die "no config at $CONFIG, and no URL given"
	mapfile -t URLS < <(sed -n 's/^camera-url://p' "$CONFIG" | tr ',' '\n' | sed '/^$/d')
	[ ${#URLS[@]} -gt 0 ] || die "no camera-url in $CONFIG"
fi

OUT="${OUT:-$ROOT/logs/rtsp-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
: > "$OUT/runs.tsv"

{
	echo "    when:     $(date '+%F %T %Z')"
	echo "    commit:   $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
	echo "    host:     $(uname -srm)"
	echo "    ffmpeg:   $(ffmpeg -version 2>/dev/null | head -1)"
	echo "    streams:  ${#URLS[@]}, ${CYCLES} open cycles each, ${SECONDS_RUN} s steady run"
} > "$OUT/env.txt"

echo "==> capturing into $OUT"
for url in "${URLS[@]}"; do
	for transport in auto tcp udp; do
		echo "    $(redact "$url")  [$transport]"
		measure "$url" "$transport" "$OUT" "$SECONDS_RUN" "$CYCLES"
	done
done

echo "==> $(report "$OUT")"
sed -n '/=== opening one/,/=== keeping one/p' "$OUT/report.txt"
