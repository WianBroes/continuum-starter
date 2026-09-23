#!/usr/bin/env bash
# Rituel Continuum — voir AGENTS.md §1 à §3.
#   session.sh ouvrir <harnais> [modèle]   crée sessions/open/<id>/, clôt les dossiers morts, affiche l'état
#   session.sh etat                        qui est ouvert (vivant/mort/incertain), sur quoi, fusion en attente
#   session.sh moi                         id de ma session ouverte (retrouvé par empreinte)
#   session.sh travail <NN_Projet>         déclare un projet sur lequel je travaille (lu par le hook pre-commit)
#   session.sh clore                       clôt ma session (open → closed) puis lance la fusion
#   session.sh verrou prendre|rendre       verrou des écritures communes, pour une réécriture à la main
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MOI_PID=$(harnais_pid) || { echo "PID du harnais introuvable (définir CONTINUUM_PID)" >&2; exit 1; }
MOI_EMP=$(empreinte "$MOI_PID")
mkdir -p "$SESSIONS/open" "$SESSIONS/closed" "$SESSIONS/sealed"

maintenant() { date '+%F %H:%M'; }

mon_dossier() {
  local d
  for d in "$SESSIONS"/open/*/; do
    [ "$(champ empreinte "$d/SESSION.md")" = "$MOI_EMP" ] && { basename "$d"; return; }
  done
  return 1
}

# clore_orphelin <id> <raison> — mort certain : clos sans demander (protocols/orphelins.md)
clore_orphelin() {
  local f=$SESSIONS/open/$1/SESSION.md
  printf '\n## Fin\n\n> Clos a posteriori le %s par pid %s — %s.\nfin: %s\n' "$(maintenant)" "$MOI_PID" "$2" "$(maintenant)" >> "$f"
  if mv "$SESSIONS/open/$1" "$SESSIONS/closed/$1" 2>/dev/null; then echo "  clos (orphelin) : $1 — $2"; fi
}

# Harnais actifs sur cette machine dont le dossier de travail est dans le vault
# mais qui n'ont pas de dossier de session (rituel jamais lancé). Linux, macOS (CWD_SUPPORTE).
HARNAIS_CONNUS=${CONTINUUM_HARNAIS:-claude|pi|codex|opencode|gemini|aider|hermes}
# Un harnais dont la session est déjà close (pane laissé ouvert) n'est pas invisible :
# listé à part, il ouvrira une nouvelle session s'il reprend (AGENTS.md §3.3).
sans_dossier() {
  local p cwd emp clos n=0 inactifs=""
  [ "$CWD_SUPPORTE" = 1 ] || return 0
  for p in $(pids_nommes "$HARNAIS_CONNUS"); do
    cwd=$(cwd_de "$p") && [ -n "$cwd" ] || continue
    case $cwd/ in "$RACINE"/*) ;; *) continue ;; esac
    emp=$(empreinte "$p")
    grep -qsxF "empreinte: $emp" "$SESSIONS"/open/*/SESSION.md && continue
    # || true : aucune correspondance (ou motif closed/*/ vide) ne doit pas faire quitter le script (set -e + pipefail)
    clos=$(grep -lsxF "empreinte: $emp" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md | tail -1) || true
    if [ -n "$clos" ]; then
      inactifs+="  pid $p ($(nom "$p")) — session close : $(basename "$(dirname "$clos")")"$'\n'
      continue
    fi
    [ $n = 0 ] && echo "Agents actifs SANS dossier de session (invisibles, à signaler à l'utilisateur) :"
    echo "  pid $p ($(nom "$p")) — dossier de travail : $cwd"; n=$((n + 1))
  done
  [ -z "$inactifs" ] || printf 'Harnais encore ouverts après clôture (inactifs, nouvelle session s ils reprennent) :\n%s' "$inactifs"
  return 0
}

etat() {
  local d id emp v f
  echo "Sessions ouvertes :"
  for d in "$SESSIONS"/open/*/; do
    [ -d "$d" ] || continue
    id=$(basename "$d"); f=$d/SESSION.md; emp=$(champ empreinte "$f")
    if [ "$emp" = "$MOI_EMP" ]; then v=moi; else v=$(vivant "$emp"); fi
    printf '  %-45s %-9s %s | travaille sur : %s | dernière activité : %s\n' "$id" "$v" \
      "$(champ harnais "$f")" "$(grep '^travaille_sur:' "$f" | cut -d' ' -f2- | sort -u | paste -sd' ' -)" \
      "$(date_fichier "$f")"
  done
  sans_dossier
  echo "En attente de fusion (closed/) : $(find "$SESSIONS/closed" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  [ -d "$VERROU" ] && echo "Verrou tenu : $(champ libelle "$VERROU/owner") ($(champ empreinte "$VERROU/owner"))"
  return 0
}

# Observations pas encore consolidées (sans marqueur [proposé …], [gradué] ni [écarté …]) : au-delà du
# seuil, la boucle d'apprentissage se lance d'elle-même à la clôture (protocols/apprentissage.md).
SEUIL_OBS=${CONTINUUM_SEUIL_OBS:-20}
a_consolider() {
  local n
  n=$(grep '^\*\*\[' "$RACINE/OBSERVATIONS.md" 2>/dev/null | grep -vc '\[proposé\|\[gradué\]\|\[écarté') || true
  [ "${n:-0}" -ge "$SEUIL_OBS" ] && echo "Observations non consolidées : $n (seuil $SEUIL_OBS) — boucle d'apprentissage automatique à la clôture (protocols/apprentissage.md)"
  return 0
}

# Harnais mis à jour après son lancement : le process tourne encore sur l'ancienne version.
maj_en_attente() {
  local r bin maj debut
  r=$(maj_harnais "$MOI_PID") && [ -n "$r" ] || return 0
  bin=${r%%|*}; r=${r#*|}; maj=${r%%|*}; debut=${r#*|}
  [ -n "$maj" ] && [ -n "$debut" ] && [ "$maj" -gt "$debut" ] && echo "Harnais mis à jour après son lancement ($bin, $(date_epoch "$maj")) : ce process tourne sur l'ancienne version — à signaler à l'utilisateur (relancer le harnais)"
  return 0
}

# Astuce du jour (ASTUCES.md) : la n-ième, n = sessions déjà ouvertes avant celle-ci (open + closed + sealed).
# Première session : aucune (elle a son accueil) ; liste épuisée : plus rien, le système est rodé.
astuce() {
  local f=$RACINE/ASTUCES.md n total
  [ -f "$f" ] || return 0
  n=$(( $(find "$SESSIONS/open" "$SESSIONS/closed" "$SESSIONS/sealed" -mindepth 1 -maxdepth 1 -type d | wc -l) - 1 ))
  total=$(grep -c '^[0-9][0-9]*\. ' "$f")
  [ "$n" -ge 1 ] && [ "$n" -le "$total" ] || return 0
  echo "Astuce $n/$total (à transmettre à l'utilisateur, une ligne) : $(sed -n "s/^$n\. //p" "$f")"
}

ouvrir() {
  local harnais=${1:?usage: session.sh ouvrir <harnais> [modèle]} modele=${2:-} d id emp v pane suffixe suite n=1 clos f
  echo "Contrôle des dossiers ouverts :"
  for d in "$SESSIONS"/open/*/; do
    [ -d "$d" ] || continue
    id=$(basename "$d"); emp=$(champ empreinte "$d/SESSION.md")
    if [ "$emp" = "$MOI_EMP" ]; then
      clore_orphelin "$id" "même process que la nouvelle session (conversation précédente, /clear ou /new)"
    elif [ "$(vivant "$emp")" = mort ]; then
      clore_orphelin "$id" "harnais mort"
    fi
  done
  # Reprise après clôture (même process, pane resté ouvert) : suite de la dernière session close de ce harnais
  # ls -t (GNU et BSD, précision sub-seconde) ; pas de xargs -r (GNU seulement) ; chemins avec espaces possibles
  suite=""; clos=()
  while IFS= read -r f; do clos+=("$f"); done < <(grep -lsxF "empreinte: $MOI_EMP" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md)
  [ ${#clos[@]} -eq 0 ] || suite=$(basename "$(dirname "$(ls -t "${clos[@]}" | head -1)")")
  pane=${HERDR_PANE_ID:-${TMUX_PANE:-}}; pane=${pane//[:%]/}
  suffixe=${pane:-p$MOI_PID}
  id="$(date +%F_%H-%M)_${harnais}-${suffixe}"
  while [ -e "$SESSIONS/open/$id" ] || [ -e "$SESSIONS/closed/$id" ] || [ -e "$SESSIONS/sealed/$id" ]; do
    n=$((n + 1)); id="$(date +%F_%H-%M)_${harnais}-${suffixe}-$n"
  done
  # préparé hors de open/ puis déplacé : jamais visible à moitié créé
  mkdir -p "$SESSIONS/.creation-$id/inbox"
  cat > "$SESSIONS/.creation-$id/SESSION.md" <<EOF
# Session $id

debut: $(maintenant)
harnais: $harnais
modele: $modele
pane: ${HERDR_PANE_ID:-${TMUX_PANE:-aucun}}
empreinte: $MOI_EMP
suite_de: $suite

## Journal

EOF
  mv "$SESSIONS/.creation-$id" "$SESSIONS/open/$id"
  echo "Session ouverte : $id"
  [ -z "$suite" ] || echo "Reprise après clôture : suite de $suite (sans « ## Pour BASE », pas d'entrée BASE)"
  etat
  a_consolider
  maj_en_attente
  astuce
}

case ${1:-} in
  ouvrir) shift; ouvrir "$@" ;;
  etat) etat ;;
  moi) mon_dossier || { echo "aucune session ouverte pour ce process" >&2; exit 1; } ;;
  travail)
    id=$(mon_dossier) || { echo "aucune session ouverte pour ce process" >&2; exit 1; }
    echo "travaille_sur: ${2:?usage: session.sh travail <NN_Projet>}" >> "$SESSIONS/open/$id/SESSION.md" ;;
  clore)
    id=$(mon_dossier) || { echo "aucune session ouverte pour ce process" >&2; exit 1; }
    # section à part : sinon « fin: » tomberait dans la dernière section de clôture (→ BASE, DIRECTIVES)
    printf '\n## Fin\n\nfin: %s\n' "$(maintenant)" >> "$SESSIONS/open/$id/SESSION.md"
    mv "$SESSIONS/open/$id" "$SESSIONS/closed/$id"
    echo "Session close : $id"
    "$(dirname "${BASH_SOURCE[0]}")/consolide.sh"
    a_consolider ;;   # seuil atteint → l'agent lance la boucle maintenant (AGENTS.md §3)
  verrou)
    case ${2:-} in
      prendre) verrou_prendre "$MOI_PID" "réécriture ${3:-à la main}" && echo "verrou pris (expire dans ${VERROU_TTL}s)" ;;
      rendre) verrou_rendre "$MOI_PID" && echo "verrou rendu" ;;
      *) echo "usage: session.sh verrou prendre|rendre" >&2; exit 1 ;;
    esac ;;
  *) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
