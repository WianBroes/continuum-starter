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
  # ma conversation, reprise après un redémarrage (empreinte périmée) : son dossier m'est rattaché
  [ -n "$MOI_CONV" ] || return 1
  local f
  while IFS= read -r f; do
    reprendre "$f" >/dev/null && { basename "$(dirname "$f")"; return; }
  done < <(grep -lsxF "conversation: $MOI_CONV" "$SESSIONS"/open/*/SESSION.md "$SESSIONS"/closed/*/SESSION.md)
  return 1
}

# plus_recent : parmi les chemins lus sur l'entrée (un par ligne), le dernier modifié ; rien si aucun.
# ls -t (GNU et BSD, précision sub-seconde) ; pas de xargs -r (GNU seulement) ; chemins avec espaces possibles
plus_recent() {
  local f l=()
  while IFS= read -r f; do [ -z "$f" ] || l+=("$f"); done
  [ ${#l[@]} -eq 0 ] || ls -t "${l[@]}" | head -1
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

# --- Reprise d'une conversation qui a survécu à un redémarrage de la machine -------------
# L'empreinte (machine boot_id pid starttime) change au redémarrage, alors que herdr relance la
# conversation (`--resume <id>`) dans un process neuf. Le lien exact est l'identifiant de
# conversation du harnais, que herdr tient par pane (`agent_session`, rapporté par ses intégrations
# claude/pi/…) : même id = même conversation ; un nouvel agent dans le même pane, ou un /clear, a
# un autre id. Le pane seul ne suffit pas. Sans herdr (ou sans intégration, ou hors Linux) : pas
# d'id, pas de reprise — le dossier est clos « harnais mort » comme avant.

# conversation <pid> — identifiant de la conversation portée par ce process (via herdr), vide si inconnu
conversation() {
  local pane
  pane=$(pane_de "$1"); [ -n "$pane" ] || return 0
  command -v "${CONTINUUM_HERDR:-herdr}" >/dev/null || return 0
  { timeout 3 "${CONTINUUM_HERDR:-herdr}" agent get "$pane" 2>/dev/null |
      grep -o '"agent_session":{[^}]*}' | sed -n 's/.*"value":"\([^"]*\)".*/\1/p' | head -1; } || true
}
MOI_CONV=$(conversation "$MOI_PID")

# pid_de_conversation <id> — harnais vivant, dossier de travail dans le vault, qui porte cette conversation
pid_de_conversation() {
  local p cwd
  [ -n "$1" ] && [ "$CWD_SUPPORTE" = 1 ] || return 1
  for p in $(pids_nommes "$HARNAIS_CONNUS"); do
    cwd=$(cwd_de "$p") && [ -n "$cwd" ] || continue
    case $cwd/ in "$RACINE"/*) ;; *) continue ;; esac
    [ "$(conversation "$p")" = "$1" ] && { echo "$p"; return 0; }
  done
  return 1
}

# reprenable <SESSION.md> — dossier dont le process est mort sans vraie clôture : ouvert à empreinte
# morte, ou clos a posteriori « harnais mort » — seule la *dernière* section « ## Fin » compte (un
# dossier repris puis clos normalement n'est jamais rouvert).
reprenable() {
  case $1 in
    "$SESSIONS"/open/*) [ "$(vivant "$(champ empreinte "$1")")" = mort ] ;;
    "$SESSIONS"/closed/*) awk '/^## Fin/ {s=""} {s=s $0 "\n"} END {printf "%s", s}' "$1" |
                            grep -q '^> Clos a posteriori.* — harnais mort\.$' ;;
    *) return 1 ;;
  esac
}

# reprendre <SESSION.md> — dossier reprenable dont la conversation tourne encore dans un process neuf :
# empreinte remise sur ce process, rendu à open/ s'il avait été clos. Renvoie 0 si repris.
reprendre() {
  local f=$1 d id conv p
  reprenable "$f" || return 1
  conv=$(champ conversation "$f"); [ -n "$conv" ] || return 1
  p=$(pid_de_conversation "$conv") || return 1
  # un dossier par process : s'il en a déjà un ouvert, ne rien rattacher
  grep -qsxF "empreinte: $(empreinte "$p")" "$SESSIONS"/open/*/SESSION.md && return 1
  d=$(dirname "$f"); id=$(basename "$d")
  # pas de sed -i (options différentes GNU/BSD)
  sed "s|^empreinte: .*|empreinte: $(empreinte "$p")|" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  printf '\n> Repris le %s par pid %s — conversation %s toujours en cours dans le pid %s (redémarrage de la machine) : dossier rattaché au process repris.\n' \
    "$(maintenant)" "$MOI_PID" "$conv" "$p" >> "$f"
  case $d in
    "$SESSIONS"/closed/*) mv "$d" "$SESSIONS/open/$id" 2>/dev/null && echo "  rouvert (conversation reprise) : $id — pid $p" ;;
    *) echo "  repris (conversation reprise) : $id — pid $p" ;;
  esac
  return 0
}

# reprendre_tous — tous les dossiers reprenables dont la conversation tourne encore
reprendre_tous() {
  local f
  for f in "$SESSIONS"/open/*/SESSION.md "$SESSIONS"/closed/*/SESSION.md; do
    [ -e "$f" ] || continue
    reprendre "$f" || true
  done
}

# Un harnais dont la session est déjà close (pane laissé ouvert) n'est pas invisible :
# listé à part, il ouvrira une nouvelle session s'il reprend (AGENTS.md §3.3).
sans_dossier() {
  local p cwd emp clos conv n=0 inactifs=""
  [ "$CWD_SUPPORTE" = 1 ] || return 0
  for p in $(pids_nommes "$HARNAIS_CONNUS"); do
    cwd=$(cwd_de "$p") && [ -n "$cwd" ] || continue
    case $cwd/ in "$RACINE"/*) ;; *) continue ;; esac
    emp=$(empreinte "$p")
    grep -qsxF "empreinte: $emp" "$SESSIONS"/open/*/SESSION.md && continue
    # || true : aucune correspondance (ou motif closed/*/ vide) ne doit pas faire quitter le script (set -e + pipefail)
    clos=$(grep -lsxF "empreinte: $emp" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md | tail -1) || true
    # après un redémarrage de la machine, l'empreinte ne correspond plus à rien : la conversation fait le lien
    conv=$(conversation "$p")
    if [ -z "$clos" ] && [ -n "$conv" ]; then
      clos=$(grep -lsxF "conversation: $conv" "$SESSIONS"/open/*/SESSION.md | head -1) || true
      if [ -n "$clos" ]; then
        inactifs+="  pid $p ($(nom "$p")) — conversation reprise, dossier à rattacher au prochain appel du rituel : $(basename "$(dirname "$clos")")"$'\n'
        continue
      fi
      clos=$(grep -lsxF "conversation: $conv" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md | plus_recent) || true
    fi
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
  local harnais=${1:?usage: session.sh ouvrir <harnais> [modèle]} modele=${2:-} d id emp pane suffixe suite garde= n=1
  echo "Contrôle des dossiers ouverts :"
  # d'abord les conversations reprises après un redémarrage (la mienne comprise) : rattachées, pas closes
  reprendre_tous
  for d in "$SESSIONS"/open/*/; do
    [ -d "$d" ] || continue
    id=$(basename "$d"); emp=$(champ empreinte "$d/SESSION.md")
    if [ "$emp" = "$MOI_EMP" ]; then
      if [ -n "$MOI_CONV" ] && [ "$(champ conversation "$d/SESSION.md")" = "$MOI_CONV" ]; then
        garde=$id   # même conversation (reprise, ou rituel relancé) : elle garde son dossier
      else
        clore_orphelin "$id" "même process que la nouvelle session (conversation précédente, /clear ou /new)"
      fi
    elif [ "$(vivant "$emp")" = mort ]; then
      clore_orphelin "$id" "harnais mort"
    fi
  done
  if [ -n "$garde" ]; then
    echo "Session reprise : $garde (même conversation, dossier conservé)"
    etat; a_consolider; maj_en_attente
    return 0
  fi
  # Reprise après clôture : suite de la dernière session close de ce process, ou de cette conversation
  # (conversation reprise après un redémarrage, dont la session avait été close normalement)
  suite=$({ grep -lsxF "empreinte: $MOI_EMP" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md || true
            [ -z "$MOI_CONV" ] || grep -lsxF "conversation: $MOI_CONV" "$SESSIONS"/closed/*/SESSION.md "$SESSIONS"/sealed/*/SESSION.md || true
          } | sort -u | plus_recent)
  [ -z "$suite" ] || suite=$(basename "$(dirname "$suite")")
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
conversation: $MOI_CONV
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
