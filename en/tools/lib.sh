# Shared Continuum functions — sourced by session.sh, consolidate.sh, install.sh, tests.sh and hooks/pre-commit.
# Process fingerprint, liveness, lock for shared writes. See AGENTS.md §0.
# Portable (bash 3.2+): everything OS-dependent lives in tools/os/<os>.sh, chosen here.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SESSIONS=$ROOT/sessions
LOCK=$ROOT/.lock
LOCK_TTL=${CONTINUUM_LOCK_TTL:-900}          # seconds before a lock expires
LOCK_WAIT=${CONTINUUM_LOCK_WAIT:-30}         # max seconds to wait for it

case $(uname -s) in
  Linux) CONTINUUM_OS=linux ;;
  Darwin) CONTINUUM_OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) CONTINUUM_OS=windows ;;
  *) echo "Continuum: unsupported OS ($(uname -s)) — see protocols/installation.md" >&2; exit 1 ;;
esac
# OS layer: boot_id, starttime, zombie, my_pid, parent_chain, proc_name, mtime, file_date,
# epoch_date, age_file, harness_update, pids_named, cwd_of, CWD_SUPPORTED, pane_of.
. "$ROOT/tools/os/$CONTINUUM_OS.sh"

# Harness PID: first ancestor that is neither a shell nor a launcher utility.
# CONTINUUM_PID forces the value (tests, exotic harness).
harness_pid() {
  if [ -n "${CONTINUUM_PID:-}" ]; then echo "$CONTINUUM_PID"; return; fi
  local p c
  while read -r p c; do
    c=$(printf '%s' "${c%.[eE][xX][eE]}" | tr 'A-Z' 'a-z'); c=${c#-}
    case $c in
      bash|sh|dash|zsh|fish|timeout|env|nohup|setsid|flock|git|xargs|cmd|powershell|pwsh|conhost|winpty|winpty-agent) ;;
      *) echo "$p"; return ;;
    esac
  done < <(parent_chain)
  return 1
}

# Fingerprint = machine boot_id pid starttime
fingerprint() { echo "$(uname -n) $(boot_id) $1 $(starttime "$1")"; }

# liveness "<fingerprint>" → alive | dead | uncertain (other machine)
liveness() {
  set -- $1
  [ "${1:-}" = "$(uname -n)" ] || { echo uncertain; return; }
  if [ "${2:-}" = "$(boot_id)" ] && [ -n "${4:-}" ] && [ "$(starttime "$3")" = "$4" ] && ! zombie "$3"; then
    echo alive
  else
    echo dead
  fi
}

# field <key> <file>: value of « key: value », empty if absent. Always exit code 0: a missing
# field (header written by hand) must not stop a script running under set -e.
field() { { grep -m1 "^$1:" "$2" 2>/dev/null | cut -d' ' -f2-; } || true; }

# --- Lock for shared writes (BASE, OBSERVATIONS, STATUS, PROFILE, TRAITS, DIRECTIVES)
# mkdir is atomic on every OS: a single winner. Its content (owner) says who holds it and until when.

lock_stale() {
  [ -d "$LOCK" ] || return 1
  local fp exp
  fp=$(field fingerprint "$LOCK/owner")   # read once: owner can vanish between two reads
  if [ -z "$fp" ]; then
    # lock being created, holder died between mkdir and writing owner, or lock being released
    [ $(( $(date +%s) - $(mtime "$LOCK" 2>/dev/null || date +%s) )) -gt 60 ]
    return
  fi
  [ "$(liveness "$fp")" = dead ] && return 0
  exp=$(field expires "$LOCK/owner")
  [ -z "$exp" ] || [ "$(date +%s)" -gt "$exp" ]
}

# Break a stale lock. Serialized by a second mkdir (.lock-break): two agents that judge it stale
# at the same time cannot break the brand-new lock the first one just took again.
# A .lock-break older than 60 s comes from a dead breaker: removed, the next one retries.
# Never fails inside (callers run under set -e): a failed rmdir on a lock someone else is
# recreating at the same moment must not leave .lock-break behind.
lock_break() {
  local m=$ROOT/.lock-break
  if ! mkdir "$m" 2>/dev/null; then
    if [ $(( $(date +%s) - $(mtime "$m" 2>/dev/null || date +%s) )) -gt 60 ]; then rmdir "$m" 2>/dev/null || true; fi
    return 0
  fi
  if lock_stale; then
    { echo "--- $(date '+%F %T') broken by pid $(my_pid)"; cat "$LOCK/owner" 2>/dev/null; } >> "$SESSIONS/locks.log" || true
    rm -f "$LOCK/owner" || true; rmdir "$LOCK" 2>/dev/null || true
  fi
  rmdir "$m" 2>/dev/null || true
}

# lock_take <owner pid> <label> — takes it again (renews it) if it is already ours
lock_take() {
  local fp i=0
  fp=$(fingerprint "$1")
  until mkdir "$LOCK" 2>/dev/null; do
    if [ "$(field fingerprint "$LOCK/owner")" = "$fp" ]; then break; fi
    lock_stale && lock_break
    [ $((i++)) -ge "$LOCK_WAIT" ] && return 1
    sleep 1
  done
  printf 'fingerprint: %s\nexpires: %s\nlabel: %s\n' "$fp" $(( $(date +%s) + LOCK_TTL )) "$2" > "$LOCK/owner.tmp"
  mv "$LOCK/owner.tmp" "$LOCK/owner"
}

# lock_release <owner pid> — only releases one's own lock
lock_release() {
  [ "$(field fingerprint "$LOCK/owner")" = "$(fingerprint "$1")" ] || return 1
  rm -f "$LOCK/owner"; rmdir "$LOCK"
}
