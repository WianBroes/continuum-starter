#!/usr/bin/env bash
# Mechanical Continuum merge — see AGENTS.md §3.
# Under lock: for each folder of sessions/closed/ (order of closing), copies
# its fixed sections into the shared files, applies the BASE.md caps
# (surplus → _archive/), moves the folder to sealed/, then commits.
# No semantic rewriting here (that stays with an agent, under lock).
#   ## For BASE        → BASE.md §History (« orphan » entry if empty and closed after the fact;
#                        nothing if empty and closed normally — nothing to pass on — or follows:
#                        resuming after close, btw, question, pane closed)
#   ## Durable facts   → BASE.md §Decided
#   ## Feedback        → end of OBSERVATIONS.md
#   ## STATUS +        → « | … | » lines at the end of STATUS.md (without the table header, already in STATUS.md)
#   ## Learned         → DIRECTIVES.md §Active › Learned (automatic) — active without waiting
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

HISTORY_CAP=5
DECIDED_CAP=5
ARCHIVE=$ROOT/_archive/$(date +%F)_purge.md
TMP=$(mktemp -d)

ME=$(my_pid)
release() { lock_release "$ME" || true; rm -rf "$TMP"; }
lock_take "$ME" consolidate || { echo "Lock busy: the next merge will take sessions/closed/."; rm -rf "$TMP"; exit 0; }
trap release EXIT

# section <file> <title>: content under « ## title », without leading/trailing blank lines.
# Title present several times (close rewritten after resuming): only the last one counts.
section() {
  awk -v t="## $2" '$0==t {on=1; n=0; next} /^## / {on=0} on {l[++n]=$0}
    END {d=1; while (d<=n && l[d]=="") d++; f=n; while (f>=d && l[f]=="") f--; for (i=d; i<=f; i++) print l[i]}' "$1"
}

# closed_after_the_fact <SESSION.md>: the last « ## End » section comes from session.sh (dead
# harness, same process), not from a real close.
closed_after_the_fact() {
  awk '/^## End/ {s=""} {s=s $0 "\n"} END {printf "%s", s}' "$1" | grep -q '^> Closed after the fact'
}

# insert <file> <section title> <text file>: inserts the text at the end of the section
# (before the next level 2 or 3 title), removing a possible « *(empty… » line from the section.
insert() {
  awk -v t="$2" -v src="$3" '
    function flush() { while ((getline x < src) > 0) print x; print ""; inside = 0 }
    $0 == t { inside = 1; print; next }
    inside && /^##+ / { flush() }
    inside && /^\*\(empty/ { next }
    { print }
    END { if (inside) { print ""; while ((getline x < src) > 0) print x } }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# cap <file> <section title> <max>: past the max, the « **[ » entries that are oldest
# BY START DATE ([YYYY-MM-DD HH:MM) → end of the archive, verbatim. The section is
# rewritten sorted by date: the order in the file is not reliable.
# Updates the section's « last purge: … » note if there is one.
cap() {
  # Header written by awk on the first addition only: no empty archive when nothing overflows.
  local header="# Archive — purge of $(date +%F)\\n\\n> Content moved as is (caps, protocols/learning.md). Oldest first, never rewritten."
  awk -v t="$2" -v max="$3" -v arch="$ARCHIVE" -v header="$header" -v when="$(date '+%F %H:%M')" -v name="$(basename "$ARCHIVE")" '
    function block(k,   i) { for (i = st[k]; i < st[k + 1]; i++) if (l[i] != "") print l[i] }
    function block_arch(k,   i) { for (i = st[k]; i < st[k + 1]; i++) if (l[i] != "") print l[i] >> arch }
    { l[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (l[i] == t) s = i
        else if (s && !e && l[i] ~ /^## /) e = i
      }
      if (!e) e = NR + 1
      n = 0
      if (s) for (i = s + 1; i < e; i++) if (l[i] ~ /^\*\*\[/) st[++n] = i
      over = n - max
      if (over <= 0) { for (i = 1; i <= NR; i++) print l[i]; exit }
      st[n + 1] = e
      for (k = 1; k <= n; k++) { key[k] = substr(l[st[k]], 4, 16) sprintf("%05d", k); o[k] = k }
      for (a = 2; a <= n; a++) { v = o[a]; b = a - 1; while (b >= 1 && key[o[b]] > key[v]) { o[b + 1] = o[b]; b-- } o[b + 1] = v }
      if ((getline y < arch) < 0) print header >> arch; else close(arch)
      print "" >> arch; print "<!-- from " t " -->" >> arch
      for (r = 1; r <= over; r++) { block_arch(o[r]); print "" >> arch }
      for (i = 1; i < st[1]; i++) {
        x = l[i]
        if (i > s && x ~ /last purge: /)
          sub(/last purge: .*/, "last purge: " when " (" over " entry(ies), the oldest by start date, automatic merge → `_archive/" name "`).", x)
        print x
      }
      for (r = over + 1; r <= n; r++) { block(o[r]); print "" }
      for (i = e; i <= NR; i++) print l[i]
    }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

done_ids=()
# order of closing (end: field), then name
while IFS='|' read -r _ d; do
  [ -n "$d" ] || continue
  id=$(basename "$d"); f=$d/SESSION.md
  start=$(field start "$f"); end=$(grep '^end:' "$f" | tail -1 | cut -d' ' -f2-)
  end_short=$end; [ "${start%% *}" = "${end%% *}" ] && end_short=${end#* }   # same day: time only

  base=$(section "$f" "For BASE"); follows=$(field follows "$f")
  if [ -n "$base" ] || { [ -z "$follows" ] && closed_after_the_fact "$f"; }; then
    [ -n "$base" ] || base="Closed without summary (orphan, closed after the fact) — raw log: \`sessions/sealed/$id/\`."
    [ -z "$follows" ] || base="(follows $follows) $base"
    printf '**[%s–%s] %s** — %s\n' "$start" "$end_short" "$id" "$base" | sed '/^$/d' > "$TMP/base"
    insert "$ROOT/BASE.md" "## History" "$TMP/base"
  fi

  section "$f" "Durable facts" > "$TMP/facts"
  if [ -s "$TMP/facts" ]; then
    { printf '**[%s] %s** — ' "$end" "$id"; cat "$TMP/facts"; } | sed '/^$/d' > "$TMP/facts2"
    insert "$ROOT/BASE.md" "## Decided" "$TMP/facts2"
  fi

  section "$f" "Feedback" > "$TMP/obs"
  [ -s "$TMP/obs" ] && { echo; cat "$TMP/obs"; } >> "$ROOT/OBSERVATIONS.md"

  # without the table header (line followed by |---|) or the separator: STATUS.md already has its own
  section "$f" "STATUS +" | { grep '^|' || true; } |
    awk '{l[NR]=$0} END {for (i=1; i<=NR; i++) if (l[i] !~ /^\|[-: |]+$/ && l[i+1] !~ /^\|[-: |]+$/) print l[i]}' > "$TMP/status"
  [ -s "$TMP/status" ] && cat "$TMP/status" >> "$ROOT/STATUS.md"

  section "$f" "Learned" > "$TMP/learned"
  [ -s "$TMP/learned" ] && insert "$ROOT/DIRECTIVES.md" "### Learned (automatic)" "$TMP/learned"

  mv "$d" "$SESSIONS/sealed/$id"
  done_ids+=("$id")
done < <(for d in "$SESSIONS"/closed/*/; do [ -d "$d" ] && echo "$(grep '^end:' "$d/SESSION.md" | tail -1)|${d%/}"; done | sort)

if [ ${#done_ids[@]} -eq 0 ]; then echo "Nothing to merge."; exit 0; fi

cap "$ROOT/BASE.md" "## History" "$HISTORY_CAP"
cap "$ROOT/BASE.md" "## Decided" "$DECIDED_CAP"
echo "Merged: ${done_ids[*]}"

# Commit limited to the paths touched (never a global -A: other agents work alongside).
if [ -z "${CONTINUUM_NO_GIT:-}" ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  paths=()
  # PROFILE/TRAITS: rewritten by hand under lock; a forgotten commit is caught here (the lock is ours)
  for p in BASE.md OBSERVATIONS.md STATUS.md DIRECTIVES.md PROFILE.md TRAITS.md _archive sessions/closed sessions/sealed; do
    # only what git knows or can add, otherwise the pathspec makes the whole commit fail
    [ -n "$(git -C "$ROOT" ls-files -co --exclude-standard -- "$p")" ] && paths+=("$p")
  done
  for attempt in 1 2 3 4 5; do
    if err=$(git -C "$ROOT" add -A -- "${paths[@]}" 2>&1 &&
             git -C "$ROOT" commit -q --no-verify -m "Merge: ${done_ids[*]}" -- "${paths[@]}" 2>&1); then
      echo "Commit: $(git -C "$ROOT" log --oneline -1)"; break
    fi
    [ "$attempt" = 5 ] && echo "Commit failed (merge done, commit it by hand): $err" >&2
    sleep 1   # index.lock of a concurrent commit
  done
fi
