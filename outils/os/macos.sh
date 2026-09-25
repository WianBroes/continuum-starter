# Couche OS macOS — sourcée par outils/lib.sh. Pas de /proc : ps, sysctl, lsof, stat/date BSD.
# Compatible avec le bash 3.2 livré par macOS.

_BOOT_ID=$(sysctl -n kern.boottime 2>/dev/null | sed 's/^{ sec = \([0-9]*\).*/\1/')
boot_id() { echo "$_BOOT_ID"; }

# Heure de démarrage (ps lstart, à la seconde), sans espaces pour tenir dans l'empreinte. Vide si absent.
starttime() { LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | awk '{$1=$1; gsub(/ /, "_"); print}'; }

zombie() { ps -o state= -p "$1" 2>/dev/null | grep -q Z; }

mon_pid() { echo $$; }

chaine_parents() {
  local p=$$
  while p=$(ps -o ppid= -p "$p" | tr -d ' ') && [ -n "$p" ] && [ "$p" -gt 1 ]; do
    echo "$p $(nom "$p")"
  done
}

nom() { basename "$(ps -o comm= -p "$1")"; }   # comm = chemin complet sous macOS
mtime() { stat -f %m "$1"; }
date_fichier() { date -r "$(stat -f %m "$1")" '+%F %H:%M'; }
date_epoch() { date -r "$1" '+%F %H:%M'; }
vieillir() { touch -t "$(date -r $(( $(date +%s) - $2 )) '+%Y%m%d%H%M.%S')" "$1"; }

maj_harnais() {
  local bin debut
  bin=$(command -v "$(nom "$1")") || return 0
  bin=$(realpath "$bin" 2>/dev/null || echo "$bin")
  debut=$(LC_ALL=C date -j -f '%a %b %d %T %Y' "$(LC_ALL=C ps -o lstart= -p "$1" | sed 's/^ *//')" +%s 2>/dev/null) || return 0
  echo "$bin|$(stat -f %c "$bin")|$debut"
}

CWD_SUPPORTE=1
pids_nommes() { pgrep -x "$1"; }
cwd_de() { lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'; }

# Pane (herdr/tmux) d'un autre process : non pris en charge (son environnement n'est pas lisible de façon
# fiable) — pas de reprise d'une conversation après un redémarrage (protocols/orphelins.md, limites).
pane_de() { :; }
