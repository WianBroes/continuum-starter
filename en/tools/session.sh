#!/usr/bin/env bash
# Continuum ritual — see AGENTS.md §1 to §3.
#   session.sh open <harness> [model]   creates sessions/open/<id>/, closes dead folders, shows the status
#   session.sh status                   who is open (alive/dead/uncertain), on what, merges pending
#   session.sh me                       id of my open session (found by fingerprint)
#   session.sh work <NN_Project>        declares a project I am working on (read by the pre-commit hook)
#   session.sh close                    closes my session (open → closed) then runs the merge
#   session.sh lock take|release        lock for shared writes, for a rewrite by hand
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MY_PID=$(harness_pid) || { echo "Harness PID not found (set CONTINUUM_PID)" >&2; exit 1; }
MY_FP=$(fingerprint "$MY_PID")
mkdir -p "$SESSIONS/open" "$SESSIONS/closed" "$SESSIONS/sealed"

now() { date '+%F %H:%M'; }

my_folder() {
  local d
  for d in "$SESSIONS"/open/*/; do
    [ "$(field fingerprint "$d/SESSION.md")" = "$MY_FP" ] && { basename "$d"; return; }
  done
  # my conversation, resumed after a reboot (stale fingerprint): its folder is attached to me
  [ -n "$MY_CONV" ] || return 1
  local f
  while IFS= read -r f; do
    resume "$f" >/dev/null && { basename "$(dirname "$f")"; return; }
  done < <(grep -lsxF "conversation: $MY_CONV" "$SESSIONS"/open/*/SESSION.md "$SESSIONS"/closed/*/SESSION.md)
  return 1
}

# most_recent: among the paths read on stdin (one per line), the last modified; nothing if none.
# ls -t (GNU and BSD, sub-second precision); no xargs -r (GNU only); paths may contain spaces
most_recent() {
  local f l=()
  while IFS= read -r f; do [ -z "$f" ] || l+=("$f"); done
  [ ${#l[@]} -eq 0 ] || ls -t "${l[@]}" | head -1
}

# close_orphan <id> <reason> — certainly dead: closed without asking (protocols/orphans.md)
close_orphan() {
  local f=$SESSIONS/open/$1/SESSION.md
  printf '\n## End\n\n> Closed after the fact on %s by pid %s — %s.\nend: %s\n' "$(now)" "$MY_PID" "$2" "$(now)" >> "$f"
  if mv "$SESSIONS/open/$1" "$SESSIONS/closed/$1" 2>/dev/null; then echo "  closed (orphan): $1 — $2"; fi
}

# Harnesses active on this machine whose working directory is in the vault
# but that have no session folder (ritual never run). Linux, macOS (CWD_SUPPORTED).
KNOWN_HARNESSES=${CONTINUUM_HARNESSES:-claude|pi|codex|opencode|gemini|aider|hermes}

# --- Resuming a conversation that survived a reboot of the machine -----------------------
# The fingerprint (machine boot_id pid starttime) changes on reboot, while herdr relaunches the
# conversation (`--resume <id>`) in a new process. The exact link is the harness's conversation
# identifier, which herdr keeps per pane (`agent_session`, reported by its claude/pi/… integrations):
# same id = same conversation; a new agent in the same pane, or a /clear, has another id. The pane
# alone is not enough. Without herdr (or without integration, or outside Linux): no id, no
# resuming — the folder is closed « harness dead » as before.

# conversation <pid> — identifier of the conversation this process carries (via herdr), empty if unknown
conversation() {
  local pane
  pane=$(pane_of "$1"); [ -n "$pane" ] || return 0
  command -v "${CONTINUUM_HERDR:-herdr}" >/dev/null || return 0
  { timeout 3 "${CONTINUUM_HERDR:-herdr}" agent get "$pane" 2>/dev/null |
      grep -o '"agent_session":{[^}]*}' | sed -n 's/.*"value":"\([^"]*\)".*/\1/p' | head -1; } || true
}
MY_CONV=$(conversation "$MY_PID")

# pid_of_conversation <id> — live harness, working directory in the vault, carrying this conversation
pid_of_conversation() {
  local p cwd
  [ -n "$1" ] && [ "$CWD_SUPPORTED" = 1 ] || return 1
  for p in $(pids_named "$KNOWN_HARNESSES"); do
    cwd=$(cwd_of "$p") && [ -n "$cwd" ] || continue
    case $cwd/ in "$ROOT"/*) ;; *) continue ;; esac
    [ "$(conversation "$p")" = "$1" ] && { echo "$p"; return 0; }
  done
  return 1
}

# resumable <SESSION.md> — folder whose process died without a real close: open with a dead
# fingerprint, or closed after the fact « harness dead » — only the *last* « ## End » section
# counts (a folder resumed then closed normally is never reopened).
resumable() {
  case $1 in
    "$SESSIONS"/open/*) [ "$(liveness "$(field fingerprint "$1")")" = dead ] ;;
    "$SESSIONS"/closed/*) awk '/^## End/ {s=""} {s=s $0 "\n"} END {printf "%s", s}' "$1" |
                            grep -q '^> Closed after the fact.* — harness dead\.$' ;;
    *) return 1 ;;
  esac
}

# resume <SESSION.md> — resumable folder whose conversation still runs in a new process:
# fingerprint moved to that process, put back in open/ if it had been closed. Returns 0 if resumed.
resume() {
  local f=$1 d id conv p
  resumable "$f" || return 1
  conv=$(field conversation "$f"); [ -n "$conv" ] || return 1
  p=$(pid_of_conversation "$conv") || return 1
  # one folder per process: if it already has an open one, attach nothing
  grep -qsxF "fingerprint: $(fingerprint "$p")" "$SESSIONS"/open/*/SESSION.md && return 1
  d=$(dirname "$f"); id=$(basename "$d")
  # no sed -i (options differ between GNU and BSD)
  sed "s|^fingerprint: .*|fingerprint: $(fingerprint "$p")|" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  printf '\n> Resumed on %s by pid %s — conversation %s still running in pid %s (machine rebooted): folder attached to the resumed process.\n' \
    "$(now)" "$MY_PID" "$conv" "$p" >> "$f"
  case $d in
    "$SESSIONS"/closed/*) mv "$d" "$SESSIONS/open/$id" 2>/dev/null && echo "  reopened (resumed conversation): $id — pid $p" ;;
    *) echo "  resumed (resumed conversation): $id — pid $p" ;;
  esac
  return 0
}

# resume_all — every resumable folder whose conversation is still running
resume_all() {
  local f
  for f in "$SESSIONS"/open/*/SESSION.md "$SESSIONS"/closed/*/SESSION.md; do
    [ -e "$f" ] || continue
    resume "$f" || true
  done
}

# A harness whose session is already closed (pane left open) is not invisible:
# listed apart, it will open a new session if it resumes (AGENTS.md §3.4).
without_folder() {
  local p cwd fp closed conv n=0 idle=""
  [ "$CWD_SUPPORTED" = 1 ] || return 0
  for p in $(pids_named "$KNOWN_HARNESSES"); do
    cwd=$(cwd_of "$p") && [ -n "$cwd" ] || continue
    case $cwd/ in "$ROOT"/*) ;; *) continue ;; esac
    fp=$(fingerprint "$p")
    grep -qsxF "fingerprint: $fp" "$SESSIONS"/open/*/SESSION.md && continue
    # || true: no match (or empty closed/*/ glob) must not make the script exit (set -e + pipefail)
    closed=$(grep -lsxF "fingerprint: $fp" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md | tail -1) || true
    # after a reboot of the machine, the fingerprint matches nothing any more: the conversation makes the link
    conv=$(conversation "$p")
    if [ -z "$closed" ] && [ -n "$conv" ]; then
      closed=$(grep -lsxF "conversation: $conv" "$SESSIONS"/open/*/SESSION.md | head -1) || true
      if [ -n "$closed" ]; then
        idle+="  pid $p ($(proc_name "$p")) — resumed conversation, folder to be attached at the next ritual call: $(basename "$(dirname "$closed")")"$'\n'
        continue
      fi
      closed=$(grep -lsxF "conversation: $conv" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md | most_recent) || true
    fi
    if [ -n "$closed" ]; then
      idle+="  pid $p ($(proc_name "$p")) — session closed: $(basename "$(dirname "$closed")")"$'\n'
      continue
    fi
    [ $n = 0 ] && echo "Active agents WITHOUT a session folder (invisible, tell the user):"
    echo "  pid $p ($(proc_name "$p")) — working directory: $cwd"; n=$((n + 1))
  done
  [ -z "$idle" ] || printf 'Harnesses still open after closing (idle, new session if they resume):\n%s' "$idle"
  return 0
}

status() {
  local d id fp v f
  echo "Open sessions:"
  for d in "$SESSIONS"/open/*/; do
    [ -d "$d" ] || continue
    id=$(basename "$d"); f=$d/SESSION.md; fp=$(field fingerprint "$f")
    if [ "$fp" = "$MY_FP" ]; then v=me; else v=$(liveness "$fp"); fi
    printf '  %-45s %-9s %s | working on: %s | last activity: %s\n' "$id" "$v" \
      "$(field harness "$f")" "$(grep '^working_on:' "$f" | cut -d' ' -f2- | sort -u | paste -sd' ' -)" \
      "$(file_date "$f")"
  done
  without_folder
  echo "Waiting for merge (closed/): $(find "$SESSIONS/closed" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  [ -d "$LOCK" ] && echo "Lock held: $(field label "$LOCK/owner") ($(field fingerprint "$LOCK/owner"))"
  return 0
}

# Observations not yet consolidated (no [proposed …], [graduated] or [dismissed …] marker): past the
# threshold, the learning loop starts by itself at close (protocols/learning.md).
OBS_THRESHOLD=${CONTINUUM_OBS_THRESHOLD:-20}
to_consolidate() {
  local n
  n=$(grep '^\*\*\[' "$ROOT/OBSERVATIONS.md" 2>/dev/null | grep -vc '\[proposed\|\[graduated\]\|\[dismissed') || true
  [ "${n:-0}" -ge "$OBS_THRESHOLD" ] && echo "Unconsolidated observations: $n (threshold $OBS_THRESHOLD) — automatic learning loop at close (protocols/learning.md)"
  return 0
}

# Harness updated after it was launched: the process still runs the old version.
pending_update() {
  local r bin upd start
  r=$(harness_update "$MY_PID") && [ -n "$r" ] || return 0
  bin=${r%%|*}; r=${r#*|}; upd=${r%%|*}; start=${r#*|}
  [ -n "$upd" ] && [ -n "$start" ] && [ "$upd" -gt "$start" ] && echo "Harness updated after launch ($bin, $(epoch_date "$upd")): this process still runs the old version — tell the user (restart the harness)"
  return 0
}

# Tip of the day (TIPS.md): the n-th, n = sessions already opened before this one (open + closed + sealed).
# First session: none (it has its welcome); list exhausted: nothing more, the system is broken in.
tip() {
  local f=$ROOT/TIPS.md n total
  [ -f "$f" ] || return 0
  n=$(( $(find "$SESSIONS/open" "$SESSIONS/closed" "$SESSIONS/sealed" -mindepth 1 -maxdepth 1 -type d | wc -l) - 1 ))
  total=$(grep -c '^[0-9][0-9]*\. ' "$f")
  [ "$n" -ge 1 ] && [ "$n" -le "$total" ] || return 0
  echo "Tip $n/$total (pass it on to the user, one line): $(sed -n "s/^$n\. //p" "$f")"
}

open_session() {
  local harness=${1:?usage: session.sh open <harness> [model]} model=${2:-} d id fp pane suffix follows kept= n=1
  echo "Checking open folders:"
  # first the conversations resumed after a reboot (mine included): attached, not closed
  resume_all
  for d in "$SESSIONS"/open/*/; do
    [ -d "$d" ] || continue
    id=$(basename "$d"); fp=$(field fingerprint "$d/SESSION.md")
    if [ "$fp" = "$MY_FP" ]; then
      if [ -n "$MY_CONV" ] && [ "$(field conversation "$d/SESSION.md")" = "$MY_CONV" ]; then
        kept=$id   # same conversation (resumed, or ritual run again): it keeps its folder
      else
        close_orphan "$id" "same process as the new session (previous conversation, /clear or /new)"
      fi
    elif [ "$(liveness "$fp")" = dead ]; then
      close_orphan "$id" "harness dead"
    fi
  done
  if [ -n "$kept" ]; then
    echo "Session resumed: $kept (same conversation, folder kept)"
    status; to_consolidate; pending_update
    return 0
  fi
  # Resuming after close: follows the last closed session of this process, or of this conversation
  # (conversation resumed after a reboot, whose session had been closed normally)
  follows=$({ grep -lsxF "fingerprint: $MY_FP" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md || true
              [ -z "$MY_CONV" ] || grep -lsxF "conversation: $MY_CONV" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md || true
            } | sort -u | most_recent)
  [ -z "$follows" ] || follows=$(basename "$(dirname "$follows")")
  pane=${HERDR_PANE_ID:-${TMUX_PANE:-}}; pane=${pane//[:%]/}
  suffix=${pane:-p$MY_PID}
  id="$(date +%F_%H-%M)_${harness}-${suffix}"
  while [ -e "$SESSIONS/open/$id" ] || [ -e "$SESSIONS/closed/$id" ] || [ -e "$SESSIONS/sealed/$id" ]; do
    n=$((n + 1)); id="$(date +%F_%H-%M)_${harness}-${suffix}-$n"
  done
  # prepared outside open/ then moved: never visible half-created
  mkdir -p "$SESSIONS/.creating-$id/inbox"
  cat > "$SESSIONS/.creating-$id/SESSION.md" <<EOF
# Session $id

start: $(now)
harness: $harness
model: $model
pane: ${HERDR_PANE_ID:-${TMUX_PANE:-none}}
fingerprint: $MY_FP
conversation: $MY_CONV
follows: $follows

## Log

EOF
  mv "$SESSIONS/.creating-$id" "$SESSIONS/open/$id"
  echo "Session opened: $id"
  [ -z "$follows" ] || echo "Resuming after close: follows $follows (without « ## For BASE », no BASE entry)"
  status
  to_consolidate
  pending_update
  tip
}

case ${1:-} in
  open) shift; open_session "$@" ;;
  status) status ;;
  me) my_folder || { echo "no open session for this process" >&2; exit 1; } ;;
  work)
    id=$(my_folder) || { echo "no open session for this process" >&2; exit 1; }
    echo "working_on: ${2:?usage: session.sh work <NN_Project>}" >> "$SESSIONS/open/$id/SESSION.md" ;;
  close)
    id=$(my_folder) || { echo "no open session for this process" >&2; exit 1; }
    # separate section: otherwise « end: » would fall into the last closing section (→ BASE, DIRECTIVES)
    printf '\n## End\n\nend: %s\n' "$(now)" >> "$SESSIONS/open/$id/SESSION.md"
    mv "$SESSIONS/open/$id" "$SESSIONS/closed/$id"
    echo "Session closed: $id"
    "$(dirname "${BASH_SOURCE[0]}")/consolidate.sh"
    to_consolidate ;;   # threshold reached → the agent runs the loop now (AGENTS.md §3)
  lock)
    case ${2:-} in
      take) lock_take "$MY_PID" "rewrite ${3:-by hand}" && echo "lock taken (expires in ${LOCK_TTL}s)" ;;
      release) lock_release "$MY_PID" && echo "lock released" ;;
      *) echo "usage: session.sh lock take|release" >&2; exit 1 ;;
    esac ;;
  *) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
