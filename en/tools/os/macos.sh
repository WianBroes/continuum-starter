# macOS OS layer — sourced by tools/lib.sh. No /proc: ps, sysctl, lsof, BSD stat/date.
# Compatible with the bash 3.2 shipped with macOS.

_BOOT_ID=$(sysctl -n kern.boottime 2>/dev/null | sed 's/^{ sec = \([0-9]*\).*/\1/')
boot_id() { echo "$_BOOT_ID"; }

# Start time (ps lstart, to the second), without spaces so it fits in the fingerprint. Empty if absent.
starttime() { LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | awk '{$1=$1; gsub(/ /, "_"); print}'; }

zombie() { ps -o state= -p "$1" 2>/dev/null | grep -q Z; }

my_pid() { echo $$; }

parent_chain() {
  local p=$$
  while p=$(ps -o ppid= -p "$p" | tr -d ' ') && [ -n "$p" ] && [ "$p" -gt 1 ]; do
    echo "$p $(proc_name "$p")"
  done
}

proc_name() { basename "$(ps -o comm= -p "$1")"; }   # comm = full path on macOS
mtime() { stat -f %m "$1"; }
file_date() { date -r "$(stat -f %m "$1")" '+%F %H:%M'; }
epoch_date() { date -r "$1" '+%F %H:%M'; }
age_file() { touch -t "$(date -r $(( $(date +%s) - $2 )) '+%Y%m%d%H%M.%S')" "$1"; }

harness_update() {
  local bin start
  bin=$(command -v "$(proc_name "$1")") || return 0
  bin=$(realpath "$bin" 2>/dev/null || echo "$bin")
  start=$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$(LC_ALL=C ps -o lstart= -p "$1" | sed 's/^ *//')" +%s 2>/dev/null) || return 0
  echo "$bin|$(stat -f %c "$bin")|$start"
}

CWD_SUPPORTED=1
pids_named() { pgrep -x "$1"; }
cwd_of() { lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'; }

# Pane (herdr/tmux) of another process: not supported (its environment cannot be read reliably)
# — no resuming of a conversation after a reboot (protocols/orphans.md, limits).
pane_of() { :; }
