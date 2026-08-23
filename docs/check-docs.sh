#!/bin/bash
#
# Validate the documentation tree against the rules in CLAUDE.md.
#
# Every path written inside docs/ is repo-relative and resolved from the repo
# root - not from the file that contains it - so the same string works whether
# it is followed by a person, a grep, or an agent that only knows where the repo
# starts. That is why this script cds to the root before checking anything.
#
# Exit 0 = clean. Warnings (unowned files, a node long against the code it owns)
# do not fail the run; a dangling path, an unreachable node, an oversized node or
# an annotated history do.

set -u

cd "$(dirname "$(readlink -f "$0")")/.." || exit 2

FAIL=0
WARN=0
err()  { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
warn() { echo "warn: $*"; WARN=$((WARN + 1)); }

INDEX=docs/INDEX.md
NODES=(docs/*.md)
LINKED=(docs/*.md CLAUDE.md README.md)

echo "=== every '> Owns:' path exists ==="
while IFS=: read -r file line rest; do
	path=$(echo "$rest" | sed 's/^> Owns:[[:space:]]*//; s/[[:space:]]*$//')
	[ -n "$path" ] || continue
	[ -e "$path" ] || err "$file:$line owns a path that does not exist: $path"
done < <(grep -Hn '^> Owns:' "${NODES[@]}")

echo "=== every markdown link resolves ==="
while IFS=: read -r file line rest; do
	target=${rest#*](}
	target=${target%)}
	target=${target%%#*}
	[ -n "$target" ] || continue
	case "$target" in
		http://*|https://*|mailto:*) continue ;;
	esac
	[ -e "$target" ] || err "$file:$line links to a missing path: $target"
done < <(grep -HnoE '\]\([^)]+\)' "${LINKED[@]}")

echo "=== every repo-relative path mentioned exists ==="
while IFS=: read -r file line rest; do
	path=$(echo "$rest" | sed 's/[.,:;)]*$//')
	[ -n "$path" ] || continue
	[ -e "$path" ] || err "$file:$line mentions a path that does not exist: $path"
done < <(grep -HnoE '(docs|src|scripts)/[A-Za-z0-9._/-]*' "${LINKED[@]}")

echo "=== every node is reachable from the index ==="
for f in "${NODES[@]}"; do
	[ "$f" = "$INDEX" ] && continue
	grep -qF "$(basename "$f")" "$INDEX" ||
		err "$f is not linked from $INDEX - an orphan node is a node nobody reads"
done

echo "=== no node links into planning/ ==="
# docs/ says what exists. A node that needs the plan in order to be understood has
# recorded the plan instead of the code.
if grep -HnE '(^|[^A-Za-z/])planning/' "${NODES[@]}"; then
	err "a node reaches into planning/ - state the constraint in the node (see CLAUDE.md)"
fi

# Lines of code a node owns, for the ratio below.
owned_lines() {
	local total=0 n
	while IFS= read -r p; do
		[ -f "$p" ] || continue
		n=$(wc -l < "$p")
		total=$((total + n))
	done < <(sed -n 's/^> Owns:[[:space:]]*//p' "$1")
	echo "$total"
}

echo "=== size, and length against the code owned ==="
# The cap is a limit and not a budget. The ratio is printed so a node that has started
# arguing rather than documenting is visible before it reaches the cap.
for f in "${NODES[@]}"; do
	cap=120
	[ "$f" = "$INDEX" ] && cap=60
	# The cap is on prose. A node owning many files spends a line each on the map
	# before it says anything, and that map is the part the rules most want kept.
	n=$(grep -cv '^> ' "$f")
	owned=$(owned_lines "$f")
	if [ "$owned" -gt 0 ]; then
		printf '  %-24s %3s lines, owns %5s\n' "$(basename "$f")" "$n" "$owned"
		[ "$n" -le $((owned / 2)) ] ||
			warn "$f is $n lines against $owned lines of code - re-read what a node must not carry"
	else
		printf '  %-24s %3s lines\n' "$(basename "$f")" "$n"
	fi
	[ "$n" -le "$cap" ] ||
		err "$f is $n lines, cap is $cap - cut it to what fails silently, or split it and link from $INDEX"
done

echo "=== no annotated history ==="
# Git holds the history; a node holds the present. Anything that marks text as
# outdated rather than deleting it defeats the point - a reader then has to work
# out which half is still in force.
BANNED='\b(previously|formerly|superseded)\b|\b(used|use) to be\b|\boriginally\b|\bas of 20[0-9][0-9]\b|^#+[[:space:]]*(History|Changelog)\b'
if grep -HnEi "$BANNED" "${NODES[@]}"; then
	err "docs must be replaced, not annotated - delete the stale text (see CLAUDE.md)"
fi

echo "=== coverage: which files no node owns ==="
OWNED=$(grep -h '^> Owns:' "${NODES[@]}" | sed 's/^> Owns:[[:space:]]*//; s/[[:space:]]*$//')
while IFS= read -r f; do
	[ -n "$f" ] || continue
	grep -qxF "$f" <<< "$OWNED" || warn "no node owns $f"
done < <(git ls-files src scripts CMakeLists.txt 2>/dev/null)

echo
if [ "$FAIL" -gt 0 ]; then
	echo "$FAIL failure(s), $WARN warning(s)"
	exit 1
fi
echo "docs OK ($WARN warning(s))"
