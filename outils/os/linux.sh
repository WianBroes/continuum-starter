# Couche OS Linux — sourcée par outils/lib.sh. Lit /proc ; aucune dépendance hors coreutils/procps.

boot_id() { cat /proc/sys/kernel/random/boot_id; }

# Heure de démarrage du process (champ 22 de /proc/<pid>/stat), lue après la dernière ')'
# pour résister aux noms de commande contenant espaces/parenthèses. Vide si le process n'existe pas.
starttime() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f20; }

# Zombie (Z) ou mourant (X) : garde son /proc/<pid>/stat mais compte comme mort.
zombie() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f1 | grep -q '[ZX]'; }

mon_pid() { echo $$; }

# Ancêtres du shell courant, « pid nom » par ligne, du plus proche au plus lointain.
chaine_parents() {
  local p=$$
  while p=$(ps -o ppid= -p "$p" | tr -d ' ') && [ -n "$p" ] && [ "$p" -gt 1 ]; do
    echo "$p $(nom "$p")"
  done
}

nom() { ps -o comm= -p "$1"; }
mtime() { stat -c %Y "$1"; }
date_fichier() { date -r "$1" '+%F %H:%M'; }
date_epoch() { date -d "@$1" '+%F %H:%M'; }
vieillir() { touch -d "@$(( $(date +%s) - $2 ))" "$1"; }   # tests : recule la date de modification

# « binaire|ctime|début du process » (époques). ctime et pas mtime : npm fige les mtime des paquets.
maj_harnais() {
  local bin
  bin=$(command -v "$(nom "$1")") || return 0
  bin=$(readlink -f "$bin")
  echo "$bin|$(stat -c %Z "$bin")|$(( $(awk '/^btime/ {print $2}' /proc/stat) + $(starttime "$1") / $(getconf CLK_TCK) ))"
}

CWD_SUPPORTE=1
pids_nommes() { pgrep -x "$1"; }
cwd_de() { readlink "/proc/$1/cwd" 2>/dev/null; }
