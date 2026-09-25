# Linux OS layer — sourced by tools/lib.sh. Reads /proc; no dependency beyond coreutils/procps.

boot_id() { cat /proc/sys/kernel/random/boot_id; }

# Process start time (field 22 of /proc/<pid>/stat), read after the last ')'
# to survive command names containing spaces/parentheses. Empty if the process does not exist.
starttime() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20; }

# Zombie (Z) or dying (X): keeps its /proc/<pid>/stat but counts as dead.
zombie() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f1 | grep -q '[ZX]'; }

my_pid() { echo $$; }

# Ancestors of the current shell, « pid name » per line, nearest first.
parent_chain() {
  local p=$$
  while p=$(ps -o ppid= -p "$p" | tr -d ' ') && [ -n "$p" ] && [ "$p" -gt 1 ]; do
    echo "$p $(proc_name "$p")"
  done
}

proc_name() { ps -o comm= -p "$1"; }
mtime() { stat -c %Y "$1"; }
file_date() { date -r "$1" '+%F %H:%M'; }
epoch_date() { date -d "@$1" '+%F %H:%M'; }
age_file() { touch -d "@$(( $(date +%s) - $2 ))" "$1"; }   # tests: moves the modification date back

# « binary|ctime|process start » (epochs). ctime, not mtime: npm freezes package mtimes.
harness_update() {
  local bin
  bin=$(command -v "$(proc_name "$1")") || return 0
  bin=$(readlink -f "$bin")
  echo "$bin|$(stat -c %Z "$bin")|$(( $(awk '/^btime/ {print $2}' /proc/stat) + $(starttime "$1") / $(getconf CLK_TCK) ))"
}

CWD_SUPPORTED=1
pids_named() { pgrep -x "$1"; }
cwd_of() { readlink "/proc/$1/cwd" 2>/dev/null; }

# Pane of the terminal multiplexer (herdr, else tmux) this process runs in, read from its environment. Empty if none.
pane_of() {
  local env
  env=$(tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null) || return 0
  { sed -n 's/^HERDR_PANE_ID=//p' <<< "$env" | grep . || sed -n 's/^TMUX_PANE=//p' <<< "$env"; } | head -1
}
