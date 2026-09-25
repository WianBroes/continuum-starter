# Couche OS Windows — sourcée par outils/lib.sh, qui tourne dans Git Bash (livré avec Git for Windows).
# Les harnais sont des process Windows natifs : tout se fait en PID Windows, lus par PowerShell (CIM).
# Le coreutils GNU de Git Bash sert pour les fichiers (stat, date, touch).

# Conversion de chemins MSYS coupée pour PowerShell seulement ($p, $env: ne sont pas des chemins) —
# jamais globalement : git.exe a besoin de recevoir C:/… et non /c/… (CI du 2026-09-23).
ps1() { MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -NonInteractive -Command "$1" 2>/dev/null | tr -d '\r'; }

_BOOT_ID=$(ps1 '(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks')
boot_id() { echo "$_BOOT_ID"; }

# Heure de démarrage en ticks UTC. Vide si le process n'existe pas (ou n'est pas lisible).
starttime() {
  PID_CIBLE=$1 ps1 'try { (Get-Process -Id ([int]$env:PID_CIBLE) -ErrorAction Stop).StartTime.ToUniversalTime().Ticks } catch {}'
}

zombie() { return 1; }   # pas de zombies sous Windows

# PID Windows du shell courant (le PID MSYS de $$ n'existe pas pour Windows).
mon_pid() { cat "/proc/$$/winpid"; }

# Ancêtres en PID Windows, « pid nom » par ligne, du plus proche au plus lointain.
# 1. D'abord l'arbre MSYS (/proc/<pid>/ppid) : fork/exec y sont émulés par des process Windows
#    intermédiaires qui meurent aussitôt, le parent Windows d'un bash a souvent disparu (CI du 2026-09-23).
# 2. La racine MSYS (ppid 1) a été lancée par un process Windows natif — le harnais, vivant :
#    on remonte à partir d'elle la chaîne Windows (CIM), en une seule requête.
chaine_parents() {
  local p=$$ pp
  while pp=$(cat "/proc/$p/ppid" 2>/dev/null) && [ -n "$pp" ] && [ "$pp" -gt 1 ]; do
    echo "$(cat "/proc/$pp/winpid") $(basename "$(cat "/proc/$pp/exename")")"
    p=$pp
  done
  PID_CIBLE=$(cat "/proc/$p/winpid") ps1 '
    $t = @{}; Get-CimInstance Win32_Process | ForEach-Object { $t[[int]$_.ProcessId] = $_ }
    $p = [int]$env:PID_CIBLE
    for ($i = 0; $i -lt 40; $i++) {
      $x = $t[$p]; if (-not $x) { break }
      $p = [int]$x.ParentProcessId; $y = $t[$p]
      if (-not $y -or $p -le 4) { break }
      "$p $($y.Name)"
    }'
}

nom() { PID_CIBLE=$1 ps1 'try { (Get-Process -Id ([int]$env:PID_CIBLE) -ErrorAction Stop).ProcessName } catch {}'; }
mtime() { stat -c %Y "$1"; }
date_fichier() { date -r "$1" '+%F %H:%M'; }
date_epoch() { date -d "@$1" '+%F %H:%M'; }
vieillir() { touch -d "@$(( $(date +%s) - $2 ))" "$1"; }

# « binaire|dernière écriture|début du process » (époques). Windows n'a pas de ctime : LastWriteTime.
maj_harnais() {
  PID_CIBLE=$1 ps1 'try {
      $x = Get-Process -Id ([int]$env:PID_CIBLE) -ErrorAction Stop
      $f = Get-Item -LiteralPath $x.Path -ErrorAction Stop
      "{0}|{1}|{2}" -f $x.Path, ([DateTimeOffset]$f.LastWriteTimeUtc).ToUnixTimeSeconds(), ([DateTimeOffset]$x.StartTime.ToUniversalTime()).ToUnixTimeSeconds()
    } catch {}'
}

# Le dossier de travail d'un autre process n'est pas lisible sous Windows sans outil tiers :
# la détection des agents sans dossier de session n'est pas disponible (AGENTS.md, limites).
CWD_SUPPORTE=0
pids_nommes() { :; }
cwd_de() { :; }

# Pane (herdr/tmux) d'un autre process : non pris en charge — pas de reprise d'une conversation
# après un redémarrage (protocols/orphelins.md, limites).
pane_de() { :; }
