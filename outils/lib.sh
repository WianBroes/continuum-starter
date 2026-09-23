# Fonctions communes Continuum — sourcé par session.sh, consolide.sh, installer.sh, tests.sh et hooks/pre-commit.
# Empreinte de process, vivacité, verrou des écritures communes. Voir AGENTS.md §0.
# Portable (bash 3.2+) : tout ce qui dépend de l'OS est dans outils/os/<os>.sh, choisi ici.

RACINE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SESSIONS=$RACINE/sessions
VERROU=$RACINE/.lock
VERROU_TTL=${CONTINUUM_VERROU_TTL:-900}          # secondes avant expiration d'un verrou
VERROU_ATTENTE=${CONTINUUM_VERROU_ATTENTE:-30}   # secondes d'attente max pour le prendre

case $(uname -s) in
  Linux) CONTINUUM_OS=linux ;;
  Darwin) CONTINUUM_OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) CONTINUUM_OS=windows ;;
  *) echo "Continuum : OS non pris en charge ($(uname -s)) — voir protocols/installation.md" >&2; exit 1 ;;
esac
# Couche OS : boot_id, starttime, zombie, mon_pid, chaine_parents, nom, mtime, date_fichier,
# date_epoch, vieillir, maj_harnais, pids_nommes, cwd_de, CWD_SUPPORTE.
. "$RACINE/outils/os/$CONTINUUM_OS.sh"

# PID du harnais : premier ancêtre qui n'est ni un shell ni un utilitaire de lancement.
# CONTINUUM_PID force la valeur (tests, harnais exotique).
harnais_pid() {
  if [ -n "${CONTINUUM_PID:-}" ]; then echo "$CONTINUUM_PID"; return; fi
  local p c
  while read -r p c; do
    c=$(printf '%s' "${c%.[eE][xX][eE]}" | tr 'A-Z' 'a-z'); c=${c#-}
    case $c in
      bash|sh|dash|zsh|fish|timeout|env|nohup|setsid|flock|git|xargs|cmd|powershell|pwsh|conhost|winpty|winpty-agent) ;;
      *) echo "$p"; return ;;
    esac
  done < <(chaine_parents)
  return 1
}

# Empreinte = machine boot_id pid starttime
empreinte() { echo "$(uname -n) $(boot_id) $1 $(starttime "$1")"; }

# vivant "<empreinte>" → vivant | mort | incertain (autre machine)
vivant() {
  set -- $1
  [ "${1:-}" = "$(uname -n)" ] || { echo incertain; return; }
  if [ "${2:-}" = "$(boot_id)" ] && [ -n "${4:-}" ] && [ "$(starttime "$3")" = "$4" ] && ! zombie "$3"; then
    echo vivant
  else
    echo mort
  fi
}

# champ <clé> <fichier> : valeur de « clé: valeur », vide si absente. Toujours code 0 : un champ
# absent (en-tête écrit à la main) ne doit pas arrêter un script en set -e.
champ() { { grep -m1 "^$1:" "$2" 2>/dev/null | cut -d' ' -f2-; } || true; }

# --- Verrou des écritures communes (BASE, OBSERVATIONS, STATUT, PROFIL, TRAITS, DIRECTIVES)
# mkdir est atomique sur tous les OS : un seul gagnant. Le contenu (owner) dit qui le tient et jusqu'à quand.

verrou_perime() {
  [ -d "$VERROU" ] || return 1
  local emp exp
  emp=$(champ empreinte "$VERROU/owner")   # lu une seule fois : owner peut disparaître entre deux lectures
  if [ -z "$emp" ]; then
    # verrou en cours de création, détenteur mort entre mkdir et l'écriture d'owner, ou verrou en train d'être rendu
    [ $(( $(date +%s) - $(mtime "$VERROU" 2>/dev/null || date +%s) )) -gt 60 ]
    return
  fi
  [ "$(vivant "$emp")" = mort ] && return 0
  exp=$(champ expire "$VERROU/owner")
  [ -z "$exp" ] || [ "$(date +%s)" -gt "$exp" ]
}

# Casser un verrou périmé. Sérialisé par un second mkdir (.lock-casse) : deux agents qui le jugent
# périmé en même temps ne peuvent pas casser le verrou tout neuf que le premier vient de reprendre.
# Un .lock-casse de plus de 60 s vient d'un casseur mort : retiré, le suivant réessaie.
# Jamais d'échec à l'intérieur (appelants en set -e) : un rmdir raté sur un verrou qu'un autre
# recrée au même moment ne doit pas laisser .lock-casse derrière lui (CI macOS du 2026-09-23).
verrou_casser() {
  local m=$RACINE/.lock-casse
  if ! mkdir "$m" 2>/dev/null; then
    if [ $(( $(date +%s) - $(mtime "$m" 2>/dev/null || date +%s) )) -gt 60 ]; then rmdir "$m" 2>/dev/null || true; fi
    return 0
  fi
  if verrou_perime; then
    { echo "--- $(date '+%F %T') cassé par pid $(mon_pid)"; cat "$VERROU/owner" 2>/dev/null; } >> "$SESSIONS/verrous.log" || true
    rm -f "$VERROU/owner" || true; rmdir "$VERROU" 2>/dev/null || true
  fi
  rmdir "$m" 2>/dev/null || true
}

# verrou_prendre <pid propriétaire> <libellé> — reprend (renouvelle) s'il est déjà à nous
verrou_prendre() {
  local emp i=0
  emp=$(empreinte "$1")
  until mkdir "$VERROU" 2>/dev/null; do
    if [ "$(champ empreinte "$VERROU/owner")" = "$emp" ]; then break; fi
    verrou_perime && verrou_casser
    [ $((i++)) -ge "$VERROU_ATTENTE" ] && return 1
    sleep 1
  done
  printf 'empreinte: %s\nexpire: %s\nlibelle: %s\n' "$emp" $(( $(date +%s) + VERROU_TTL )) "$2" > "$VERROU/owner.tmp"
  mv "$VERROU/owner.tmp" "$VERROU/owner"
}

# verrou_rendre <pid propriétaire> — ne rend que son propre verrou
verrou_rendre() {
  [ "$(champ empreinte "$VERROU/owner")" = "$(empreinte "$1")" ] || return 1
  rm -f "$VERROU/owner"; rmdir "$VERROU"
}
