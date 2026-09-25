# Windows OS layer — sourced by tools/lib.sh, which runs in Git Bash (shipped with Git for Windows).
# Harnesses are native Windows processes: everything uses Windows PIDs, read through PowerShell (CIM).
# Git Bash's GNU coreutils handle files (stat, date, touch).

# MSYS path conversion turned off for PowerShell only ($p, $env: are not paths) —
# never globally: git.exe must receive C:/… and not /c/….
ps1() { MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -NonInteractive -Command "$1" 2>/dev/null | tr -d '\r'; }

_BOOT_ID=$(ps1 '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks')
boot_id() { echo "$_BOOT_ID"; }

# Start time in UTC ticks. Empty if the process does not exist (or cannot be read).
starttime() {
  TARGET_PID=$1 ps1 'try { (Get-Process -Id ([int]$env:TARGET_PID) -ErrorAction Stop).StartTime.ToUniversalTime().Ticks } catch {}'
}

zombie() { return 1; }   # no zombies on Windows

# Windows PID of the current shell (the MSYS PID in $$ does not exist for Windows).
my_pid() { cat "/proc/$$/winpid"; }

# Ancestors as Windows PIDs, « pid name » per line, nearest first.
# 1. First the MSYS tree (/proc/<pid>/ppid): fork/exec are emulated there by intermediate Windows
#    processes that die at once, so a bash's Windows parent has often vanished.
# 2. The MSYS root (ppid 1) was launched by a native Windows process — the harness, alive:
#    from it we walk up the Windows chain (CIM), in a single query.
parent_chain() {
  local p=$$ pp
  while pp=$(cat "/proc/$p/ppid" 2>/dev/null) && [ -n "$pp" ] && [ "$pp" -gt 1 ]; do
    echo "$(cat "/proc/$pp/winpid") $(basename "$(cat "/proc/$pp/exename")")"
    p=$pp
  done
  TARGET_PID=$(cat "/proc/$p/winpid") ps1 '
    $t = @{}; Get-CimInstance Win32_Process | ForEach-Object { $t[[int]$_.ProcessId] = $_ }
    $p = [int]$env:TARGET_PID
    for ($i = 0; $i -lt 40; $i++) {
      $x = $t[$p]; if (-not $x) { break }
      $p = [int]$x.ParentProcessId; $y = $t[$p]
      if (-not $y -or $p -le 4) { break }
      "$p $($y.Name)"
    }'
}

proc_name() { TARGET_PID=$1 ps1 'try { (Get-Process -Id ([int]$env:TARGET_PID) -ErrorAction Stop).ProcessName } catch {}'; }
mtime() { stat -c %Y "$1"; }
file_date() { date -r "$1" '+%F %H:%M'; }
epoch_date() { date -d "@$1" '+%F %H:%M'; }
age_file() { touch -d "@$(( $(date +%s) - $2 ))" "$1"; }

# « binary|last write|process start » (epochs). Windows has no ctime: LastWriteTime.
harness_update() {
  TARGET_PID=$1 ps1 'try {
      $x = Get-Process -Id ([int]$env:TARGET_PID) -ErrorAction Stop
      $f = Get-Item -LiteralPath $x.Path -ErrorAction Stop
      "{0}|{1}|{2}" -f $x.Path, ([DateTimeOffset]$f.LastWriteTimeUtc).ToUnixTimeSeconds(), ([DateTimeOffset]$x.StartTime.ToUniversalTime()).ToUnixTimeSeconds()
    } catch {}'
}

# Another process's working directory cannot be read on Windows without a third-party tool:
# detection of agents without a session folder is not available (AGENTS.md, limits).
CWD_SUPPORTED=0
pids_named() { :; }
cwd_of() { :; }

# Pane (herdr/tmux) of another process: not supported — no resuming of a conversation
# after a reboot (protocols/orphans.md, limits).
pane_of() { :; }
