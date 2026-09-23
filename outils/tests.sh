#!/usr/bin/env bash
# Tests du rituel Continuum. Ne touche jamais au vault : clone jetable dans un
# dossier temporaire, agents simulés par de faux harnais (sleep) via CONTINUUM_PID.
#   outils/tests.sh            lance tout, affiche OK/KO, code de sortie = nb d'échecs
set -uo pipefail
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
V=$(cd "$(mktemp -d)" && pwd -P)/vault
git clone -q "$SRC" "$V" && git -C "$V" remote remove origin
rm -rf "$V/outils" && cp -r "$SRC/outils" "$V/outils"
git -C "$V" config user.name test && git -C "$V" config user.email test@local
# Fixtures : le gabarit est vierge (aucun projet, Historique vide) — on crée de quoi tester.
mkdir -p "$V/01_Exemple" "$V/02_Autre"; echo "# Exemple" > "$V/01_Exemple/CLAUDE.md"; echo "# Autre" > "$V/02_Autre/CLAUDE.md"
printf '\n**[2020-01-01 00:00–00:01] fixture** — JETON-FIXTURE, entrée la plus ancienne.\n' >> "$V/BASE.md"
git -C "$V" add 01_Exemple 02_Autre BASE.md && git -C "$V" commit -q --no-verify -m fixtures
unset HERDR_PANE_ID TMUX_PANE
export CONTINUUM_VERROU_ATTENTE=30
S=$V/sessions
ok=0; ko=0
# sans pipefail : `… | grep -q` ferme le tube tôt, SIGPIPE en amont ferait échouer un test réussi
# verifie <libellé> <condition> [diagnostic] : le diagnostic (commande) n'est affiché qu'en cas d'échec — faits bruts pour la CI
verifie() { if (set +o pipefail; eval "$2"); then ok=$((ok+1)); echo "  OK  $1"; else ko=$((ko+1)); echo "  KO  $1   [$2]"; [ -z "${3:-}" ] || eval "$3" 2>&1 | sed 's/^/        | /'; fi; }
. "$V/outils/lib.sh"   # couche OS du clone : starttime, mtime, vieillir, CWD_SUPPORTE…
echo "OS : $CONTINUUM_OS"
# Faux harnais vivant (détaché). Sous Windows, les harnais sont des process natifs : on rend le PID
# Windows du sleep, une fois l'exec fait (avant, /proc/<pid>/winpid est celui du bash forké).
if [ "$CONTINUUM_OS" = windows ]; then
  pid_windows() { local i; for i in $(seq 50); do case $(cat "/proc/$1/exename" 2>/dev/null) in *sleep*|*fauxharnais*) break ;; esac; sleep 0.1; done; cat "/proc/$1/winpid"; }
  harnais() { sleep 3600 >/dev/null 2>&1 & pid_windows $!; }
  tuer_pids() { local p; for p in "$@"; do taskkill //F //PID "$p" >/dev/null 2>&1; done; }
else
  harnais() { sleep 3600 >/dev/null 2>&1 & echo $!; }
  tuer_pids() { kill "$@" 2>/dev/null; }
fi
tuer() { tuer_pids "$@"; local p i; for p in "$@"; do for i in $(seq 50); do [ -n "$(starttime "$p")" ] || break; sleep 0.1; done; done; }
saute() { echo "  --  $1 (non pris en charge sous $CONTINUUM_OS)"; }
agent() { local p=$1; shift; CONTINUUM_PID=$p bash "$V/outils/session.sh" "$@"; }
dossier() { CONTINUUM_PID=$1 bash "$V/outils/session.sh" moi; }
nb() { find "$S/$1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; }   # wc BSD : espaces en tête
compte() { grep -c -- "$1" "$2" 2>/dev/null || true; }
PIDS=()
trap 'tuer_pids "${PIDS[@]}"; rm -rf "$(dirname "$V")"' EXIT

echo "T1 — deux ouvertures simultanées"
A=$(harnais); B=$(harnais); PIDS+=("$A" "$B")
agent "$A" ouvrir claude >/dev/null & agent "$B" ouvrir pi >/dev/null & wait
verifie "2 dossiers dans open/" '[ "$(nb open)" = 2 ]'
verifie "B voit A vivant" 'agent "$B" etat | grep -q "claude-p$A.*vivant"'
verifie "aucun dossier de création résiduel" '[ -z "$(ls -A "$S" | grep "^\.creation")" ]'

echo "T2 — orphelin mort clos automatiquement"
IDA=$(dossier "$A"); tuer "$A"
C=$(harnais); PIDS+=("$C")
sortie=$(agent "$C" ouvrir claude); grep -q "clos (orphelin) : $IDA" <<< "$sortie"; r=$?
verifie "C annonce la clôture de A" '[ $r = 0 ]'
verifie "A est dans closed/ avec la note" 'grep -q "harnais mort" "$S/closed/$IDA/SESSION.md"'
verifie "B (vivant) n a pas été touché" '[ -d "$S/open/$(dossier "$B")" ]'

echo "T7 — même process, nouvelle conversation (/clear, /new)"
IDB=$(dossier "$B")   # même minute : l'id reçoit un suffixe -2
agent "$B" ouvrir pi >/dev/null
verifie "ancienne conversation de B close" 'grep -q "même process" "$S/closed/$IDB/SESSION.md"'
verifie "B a un nouveau dossier ouvert" '[ -n "$(dossier "$B")" ] && [ "$(dossier "$B")" != "$IDB" ]'

echo "T3 — 12 clôtures simultanées + fusion"
tuer "$B" "$C"
avant=$(sed -n '/^## Historique/,$p' "$V/BASE.md" | grep '^\*\*\[' | sort | head -1)   # plus ancienne entrée existante (date de début)
N=12; AG=()
for i in $(seq 1 $N); do p=$(harnais); PIDS+=("$p"); AG+=("$p"); agent "$p" ouvrir claude >/dev/null; done
for i in $(seq 1 $N); do
  f=$S/open/$(dossier "${AG[$((i-1))]}")/SESSION.md
  echo "- entrée de journal $i" >> "$f"
  titre=Retour; [ $((i % 2)) = 1 ] && titre=Observations   # ancien nom de section toujours accepté
  printf '\n## Pour BASE\n\nJETON-BASE-%s fait ceci.\nSur deux lignes.\n\n## %s\n\n**[t]** [incident] — JETON-OBS-%s\n\n## STATUT +\n\n| JETON-STATUT-%s | 2026-09-23 | ouvert |\n' $i $titre $i $i >> "$f"
  [ $i -le 7 ] && printf '\n## Faits durables\n\nJETON-FAIT-%s\n' $i >> "$f"
  [ $i = 1 ] && printf '\n## Apprises\n\n**JETON-PROP-1** — directive apprise de test.\n' >> "$f"
done
for p in "${AG[@]}"; do agent "$p" clore >/dev/null 2>&1 & done; wait
CONTINUUM_PID=$$ bash "$V/outils/consolide.sh" >/dev/null   # rattrape un éventuel reliquat
verifie "open/ et closed/ vides" '[ "$(nb open)" = 0 ] && [ "$(nb closed)" = 0 ]'
tout=$(cat "$V/BASE.md" "$V"/_archive/*.md)
for i in $(seq 1 $N); do
  [ "$(grep -c "JETON-BASE-$i " <<< "$tout")" = 1 ] || { echo "    JETON-BASE-$i : $(grep -c "JETON-BASE-$i " <<< "$tout")"; manque=1; }
done
verifie "chaque entrée BASE exactement une fois (BASE + archive)" '[ -z "${manque:-}" ]'
verifie "Historique plafonné à 5" '[ "$(sed -n "/^## Historique/,\$p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'
verifie "Décidé plafonné à 5" '[ "$(sed -n "/^## Décidé/,/^## Historique/p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'
verifie "placeholder « vide » retiré de Décidé" '! grep -q "première clôture à venir" "$V/BASE.md"'
verifie "ancienne entrée archivée verbatim" 'grep -qxF -- "$avant" <(cat "$V"/_archive/*.md)'
verifie "entrée orpheline de A présente" '[ "$(grep -c "$IDA\*\* — Clos sans synthèse" <<< "$tout")" = 1 ]'
ob=0; st=0; for i in $(seq 1 $N); do [ "$(compte "JETON-OBS-$i\$" "$V/OBSERVATIONS.md")" = 1 ] || ob=1; [ "$(compte "JETON-STATUT-$i " "$V/STATUT.md")" = 1 ] || st=1; done
verifie "observations : chacune exactement une fois" '[ $ob = 0 ]'
verifie "STATUT : chaque ligne exactement une fois" '[ $st = 0 ]'
verifie "directive apprise insérée dans §Actives › Apprises (automatique)" 'awk "/^### Apprises \(automatique\)/{p=1;next} p&&/^##/{exit} p&&/JETON-PROP-1/{f=1} END{exit !f}" "$V/DIRECTIVES.md"'
verifie "aucune ligne « fin: » recopiée dans BASE, DIRECTIVES ou l archive" '! grep -q "^fin: " "$V/BASE.md" "$V/DIRECTIVES.md" "$V"/_archive/*.md'
verifie "sealed/ contient les 12 + A + 2 conversations de B" '[ "$(nb sealed)" -ge 15 ]'
verifie "verrou rendu" '[ ! -d "$V/.lock" ]'
verifie "fichiers communs committés" '[ -z "$(git -C "$V" status --porcelain -- BASE.md OBSERVATIONS.md STATUT.md DIRECTIVES.md _archive sessions/sealed sessions/closed)" ]'
verifie "au moins un commit « Fusion »" 'git -C "$V" log --oneline | grep -q "Fusion :"'

echo "T4 — verrous abandonnés, expirés, tenus"
prendre_faux() { mkdir "$V/.lock"; printf 'empreinte: %s\nexpire: %s\nlibelle: test\n' "$1" "$2" > "$V/.lock/owner"; }
futur=$(( $(date +%s) + 600 )); passe=$(( $(date +%s) - 10 ))
m=$(harnais); mort_emp=$(CONTINUUM_PID=$m bash -c ". $V/outils/lib.sh; empreinte $m"); tuer "$m"
prendre_faux "$mort_emp" "$futur"
verifie "détenteur mort → verrou cassé, fusion faite" 'CONTINUUM_PID=$$ bash "$V/outils/consolide.sh" | grep -q "Rien à fusionner"'
verifie "casse tracée dans verrous.log" 'grep -q "cassé par" "$S/verrous.log"'
prendre_faux "autre-machine x 1 1" "$futur"
verifie "autre machine non expiré → occupé" 'CONTINUUM_VERROU_ATTENTE=2 bash "$V/outils/consolide.sh" | grep -q "Verrou occupé"'
rm -rf "$V/.lock"; prendre_faux "autre-machine x 1 1" "$passe"
verifie "autre machine expiré → cassé" 'bash "$V/outils/consolide.sh" | grep -q "Rien à fusionner"'
v=$(harnais); PIDS+=("$v"); agent "$v" verrou prendre >/dev/null
verifie "tenu par un vivant → occupé" 'CONTINUUM_VERROU_ATTENTE=2 bash "$V/outils/consolide.sh" | grep -q "Verrou occupé"'
verifie "seul le détenteur peut rendre" '! agent "$$" verrou rendre 2>/dev/null && agent "$v" verrou rendre | grep -q rendu'
for i in $(seq 1 8); do CONTINUUM_PID=$$ bash "$V/outils/consolide.sh" >/dev/null & done; wait
verifie "8 fusions concurrentes → aucun verrou résiduel" '[ ! -d "$V/.lock" ]'

echo "T6 — hook pre-commit sur projet déclaré"
git -C "$V" config core.hooksPath outils/hooks
D=$(harnais); E=$(harnais); PIDS+=("$D" "$E")
agent "$D" ouvrir claude >/dev/null; agent "$E" ouvrir pi >/dev/null
agent "$D" travail 01_Exemple
echo test >> "$V/01_Exemple/CLAUDE.md"; git -C "$V" add 01_Exemple/CLAUDE.md
verifie "E refusé sur 01_Exemple déclaré par D" '! CONTINUUM_PID=$E git -C "$V" commit -q -m e 2>/dev/null'
verifie "D autorisé sur son propre projet" 'CONTINUUM_PID=$D git -C "$V" commit -q -m d'
echo test2 >> "$V/01_Exemple/CLAUDE.md"; git -C "$V" add 01_Exemple/CLAUDE.md
verifie "E autorisé avec --no-verify" 'CONTINUUM_PID=$E git -C "$V" commit -q --no-verify -m e2'
echo test3 >> "$V/01_Exemple/CLAUDE.md"; git -C "$V" add 01_Exemple/CLAUDE.md; tuer "$D"
verifie "D mort → E autorisé" 'CONTINUUM_PID=$E git -C "$V" commit -q -m e3'
echo test4 >> "$V/02_Autre/CLAUDE.md"; git -C "$V" add 02_Autre/CLAUDE.md
verifie "projet non déclaré → autorisé" 'CONTINUUM_PID=$E git -C "$V" commit -q -m e4'

echo "T9 — agent actif sans dossier de session (rituel jamais lancé)"
if [ "$CWD_SUPPORTE" != 1 ]; then saute "dossier de travail d'un autre process illisible"; else
export CONTINUUM_HARNAIS=sleep
F=$(cd "$V/01_Exemple" && harnais); G=$(cd "$V" && harnais); H=$(cd /tmp && harnais); PIDS+=("$F" "$G" "$H")
agent "$G" ouvrir claude >/dev/null
sortie=$(agent "$G" etat)
verifie "F (dans le vault, sans dossier) signalé" 'grep -q "pid $F " <<< "$sortie"'
verifie "G (dans le vault, avec dossier) non signalé" '! grep -q "pid $G " <<< "$sortie"'
verifie "H (hors du vault) ignoré" '! grep -q "pid $H " <<< "$sortie"'
(cd "$V" && CONTINUUM_PID=$G bash outils/session.sh clore >/dev/null)
sortie=$(agent "$F" etat)
verifie "G clos mais harnais encore ouvert : pas signalé comme « sans dossier »" '! sed -n "/SANS dossier/,/^[^ ]/p" <<< "$sortie" | grep -q "pid $G "'
verifie "G listé comme harnais ouvert après clôture" 'grep -q "pid $G .*clos" <<< "$sortie"'
unset CONTINUUM_HARNAIS
fi

echo "T10 — format de date d une entrée BASE (même jour → heure seule)"
verifie "entrée « [AAAA-MM-JJ HH:MM–HH:MM] id »" 'grep -qE "^\*\*\[[0-9-]{10} [0-9:]{5}–[0-9:]{5}\] " "$V/BASE.md"'

echo "T11 — reprises après clôture (suite_de)"
K=$(harnais); PIDS+=("$K")
agent "$K" ouvrir claude >/dev/null; K1=$(dossier "$K")
printf '\n## Pour BASE\n\nJETON-K1 vrai travail.\n' >> "$S/open/$K1/SESSION.md"; agent "$K" clore >/dev/null
agent "$K" ouvrir claude >/dev/null; K2=$(dossier "$K")
verifie "reprise marquée suite_de la session close" 'grep -qx "suite_de: $K1" "$S/open/$K2/SESSION.md"'
echo "- btw : une question, rien d autre" >> "$S/open/$K2/SESSION.md"; agent "$K" clore >/dev/null
verifie "suite sans « Pour BASE » → aucune entrée BASE" '! grep -q "\] $K2\*\*" "$V/BASE.md" "$V"/_archive/*.md'
verifie "journal de la suite conservé dans sealed/" 'grep -q "btw" "$S/sealed/$K2/SESSION.md"'
agent "$K" ouvrir claude >/dev/null; K3=$(dossier "$K")
printf '\n## Pour BASE\n\nJETON-K3 correction de la clôture.\n' >> "$S/open/$K3/SESSION.md"; agent "$K" clore >/dev/null
verifie "suite avec « Pour BASE » → entrée « (suite de … ) »" 'grep -q "\] $K3\*\* — (suite de $K2) JETON-K3" "$V/BASE.md"'
agent "$K" ouvrir claude >/dev/null; K4=$(dossier "$K"); tuer "$K"
L=$(harnais); PIDS+=("$L"); agent "$L" ouvrir claude >/dev/null; agent "$L" clore >/dev/null
verifie "suite orpheline (pane coupé sans reclôture) → aucune entrée BASE" '! grep -q "\] $K4\*\*" "$V/BASE.md" "$V"/_archive/*.md && [ -d "$S/sealed/$K4" ]'
verifie "première session (pas une suite) → pas de suite_de" '! grep -q "^suite_de: ." "$S/sealed/$K1/SESSION.md"'

echo "T12 — plafond par date de début, pas par position ; note « dernière purge » tenue par la fusion"
printf '\n**[2019-01-01 00:00–00:01] tres-ancien** — JETON-ANCIEN placé en dernière position.\n' >> "$V/BASE.md"
M=$(harnais); PIDS+=("$M"); agent "$M" ouvrir claude >/dev/null
printf '\n## Pour BASE\n\nJETON-T12.\n' >> "$S/open/$(dossier "$M")/SESSION.md"; agent "$M" clore >/dev/null
verifie "la plus ancienne par date (dernière du fichier) est archivée" '! grep -q JETON-ANCIEN "$V/BASE.md" && grep -q JETON-ANCIEN "$V"/_archive/*.md'
verifie "Historique trié par date de début" 'sed -n "/^## Historique/,\$p" "$V/BASE.md" | grep -o "^\*\*\[[0-9-]* [0-9:]*" | sort -c'
verifie "note « dernière purge » mise à jour par la fusion" 'grep -q "dernière purge : $(date +%F).*fusion automatique" "$V/BASE.md"'
verifie "Historique toujours à 5" '[ "$(sed -n "/^## Historique/,\$p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'

echo "T13 — en-tête d'ancien format (sans suite_de:) : la fusion ne doit pas planter"
N13=$(harnais); PIDS+=("$N13"); agent "$N13" ouvrir claude >/dev/null; D13=$(dossier "$N13")
grep -v '^suite_de:' "$S/open/$D13/SESSION.md" > "$S/open/$D13/SESSION.tmp" && mv "$S/open/$D13/SESSION.tmp" "$S/open/$D13/SESSION.md"
printf '\n## Pour BASE\n\nJETON-T13.\n' >> "$S/open/$D13/SESSION.md"
agent "$N13" clore >/dev/null 2>&1; r=$?
verifie "clore réussit (code 0)" '[ $r = 0 ]'
verifie "session fusionnée (sealed/) et entrée présente" '[ -d "$S/sealed/$D13" ] && grep -q JETON-T13 "$V/BASE.md"'

echo "T14 — seuil d'observations non consolidées signalé à l'ouverture"
printf '# OBSERVATIONS\n\n**[2026-01-01 00:00]** [incident] — a\n\n**[2026-01-01 00:01]** [incident] — b [proposé → DIRECTIVES.md]\n\n**[2026-01-01 00:02]** [réussite] — c\n\n**[2026-01-01 00:03]** [incident] [écarté : événement] — d\n' > "$V/OBSERVATIONS.md"
O=$(harnais); PIDS+=("$O")
verifie "2 non marquées, seuil 2 → signalé" 'CONTINUUM_SEUIL_OBS=2 agent "$O" ouvrir claude | grep -q "non consolidées : 2 "'
verifie "seuil 3 → rien" '! CONTINUUM_SEUIL_OBS=3 agent "$O" ouvrir claude | grep -q "non consolidées"'
verifie "seuil atteint → aussi signalé par clore, après la fusion" 'CONTINUUM_SEUIL_OBS=2 agent "$O" clore | grep -q "non consolidées : 2 .*à la clôture"'

echo "T15 — harnais mis à jour après son lancement"
# installé au moins 2 s avant le lancement : btime (/proc/stat) est arrondi à la seconde
EXE=""; [ "$CONTINUUM_OS" = windows ] && EXE=.exe
BIN=$(dirname "$V")/bin; mkdir -p "$BIN"; cp "$(command -v sleep)$EXE" "$BIN/fauxharnais$EXE"; sleep 2
if [ "$CONTINUUM_OS" = windows ]; then   # détaché : sinon le wait de T8 l'attendrait
  Q=$("$BIN/fauxharnais" 3600 >/dev/null 2>&1 & pid_windows $!)
else
  Q=$("$BIN/fauxharnais" 3600 >/dev/null 2>&1 & echo $!)
fi
PIDS+=("$Q")
verifie "exécutable inchangé → rien" '! PATH=$BIN:$PATH agent "$Q" ouvrir claude | grep -q "mis à jour après"'
sleep 2; touch "$BIN/fauxharnais$EXE"
verifie "exécutable remplacé après le lancement → signalé" 'PATH=$BIN:$PATH agent "$Q" ouvrir claude | grep -q "mis à jour après son lancement (.*fauxharnais"'

echo "T16 — verrou dont l'owner n'a pas (ou plus) d'empreinte : jamais de plantage"
# état vu par un agent quand le détenteur rend le verrou entre deux lectures d'owner
mkdir "$V/.lock"; echo "libelle: test" > "$V/.lock/owner"
verifie "owner sans empreinte, verrou récent → occupé, sans plantage" 'CONTINUUM_VERROU_ATTENTE=2 CONTINUUM_PID=$$ bash "$V/outils/consolide.sh" 2>&1 | grep -q "Verrou occupé"'
vieillir "$V/.lock" 120
age16=$(( $(date +%s) - $(mtime "$V/.lock") ))
sortie16=$(CONTINUUM_PID=$$ bash "$V/outils/consolide.sh" 2>&1)
verifie "owner sans empreinte, verrou de plus de 60 s → cassé, fusion faite" 'grep -q "Rien à fusionner\|Fusionné" <<< "$sortie16" && [ ! -d "$V/.lock" ]' \
  'echo "âge du verrou avant : $age16 s"; echo "sortie : $sortie16"; ls -la "$V/.lock" "$V/.lock-casse" 2>&1; tail -3 "$S/verrous.log" 2>&1'

echo "T17 — hook dans un projet à dépôt imbriqué (NN_Projet/.git)"
I=$V/07_Imbrique; mkdir "$I"; git -C "$I" init -q
git -C "$I" config user.name test; git -C "$I" config user.email test@local; git -C "$I" config core.hooksPath ../outils/hooks
R=$(harnais); U=$(harnais); PIDS+=("$R" "$U")
agent "$R" ouvrir claude >/dev/null; agent "$U" ouvrir pi >/dev/null; agent "$R" travail 07_Imbrique
echo a > "$I/f"; git -C "$I" add f
verifie "U refusé dans le dépôt imbriqué déclaré par R" '! CONTINUUM_PID=$U git -C "$I" commit -q -m u 2>/dev/null'
verifie "R autorisé dans son propre projet" 'CONTINUUM_PID=$R git -C "$I" commit -q -m r'

echo "T18 — détection du harnais sans CONTINUUM_PID (vrai process parent)"
# « fauxagent » = copie de bash : lance un bash qui cherche son harnais. « ; true » empêche l'exec direct.
cp "$(command -v bash)$EXE" "$BIN/fauxagent$EXE"
det=$(env -u CONTINUUM_PID "$BIN/fauxagent" -c "bash -c '. \"$V/outils/lib.sh\"; nom \"\$(harnais_pid)\"'; true" 2>&1)
verifie "le harnais détecté est le premier parent non-shell (fauxagent)" 'case $det in fauxagent*) true ;; *) false ;; esac' \
  'echo "détecté : [$det]"; env -u CONTINUUM_PID "$BIN/fauxagent" -c "bash -c '"'"'. \"$V/outils/lib.sh\"; echo mon_pid=\$(mon_pid); chaine_parents'"'"'; true"'

echo "T19 — astuce du jour : une différente à chaque ouverture, plus rien liste épuisée"
W=$(harnais); PIDS+=("$W")
avant=$(( $(nb open) + $(nb closed) + $(nb sealed) ))
printf '# ASTUCES\n\n'"$avant"'. ASTUCE-A\n' > "$V/ASTUCES.md"; for i in $(seq 1 $((avant - 1))); do echo "$i. x$i" >> "$V/ASTUCES.md"; done
echo "$((avant + 1)). ASTUCE-B" >> "$V/ASTUCES.md"
s1=$(agent "$W" ouvrir claude); s2=$(agent "$W" ouvrir claude); s3=$(agent "$W" ouvrir claude)
verifie "ouverture n°$((avant + 1)) : astuce $avant" 'grep -q "^Astuce $avant/$((avant + 1)) .*ASTUCE-A$" <<< "$s1"' 'echo "$s1" | tail -3'
verifie "ouverture suivante : astuce suivante" 'grep -q "^Astuce $((avant + 1))/.*ASTUCE-B$" <<< "$s2"' 'echo "$s2" | tail -3'
verifie "liste épuisée : plus d astuce" '! grep -q "^Astuce" <<< "$s3"' 'echo "$s3" | tail -3'

echo "T8 — 50 ajouts concurrents en >> (lignes de 1000 caractères)"
# 1000 : sous macOS, bash 3.2 écrit une ligne par morceaux de 1024 octets — au-delà, deux ajouts concurrents peuvent
# se couper (CI 2026-09-23 : à 3000 puis 1500, un morceau d'exactement 1024 octets déplacé dans une autre ligne).
# Sous Windows (MSYS), O_APPEND n'est pas atomique entre process : 2 lignes sur 50 entremêlées en CI
# (2026-09-23). Continuum n'en dépend pas : chaque agent n'ajoute qu'à son propre journal, les
# fichiers communs ne s'écrivent que sous verrou. Limite documentée (protocols/installation.md).
if [ "$CONTINUUM_OS" = windows ]; then saute "ajouts concurrents dans un même fichier non atomiques"; else
f=$V/ajouts.txt
for i in $(seq 1 50); do ( printf "L%02d:%s\n" $i "$(head -c 1000 /dev/zero | tr '\0' x)" >> "$f" ) & done; wait
# awk et pas grep x{1000} : le grep BSD (macOS) plafonne les répétitions à 255
intactes() { awk 'length($0) == 1004 && /^L[0-9][0-9]:x+$/' "$f" | wc -l | tr -d ' '; }
verifie "50 lignes, toutes intactes" '[ "$(wc -l < "$f")" -eq 50 ] && [ "$(intactes)" = 50 ]' \
  'echo "lignes : $(wc -l < "$f"), intactes : $(intactes)"; echo "longueurs (nb × longueur) :"; awk "{print length}" "$f" | sort -n | uniq -c | head -8'
fi

echo
echo "Résultat : $ok OK, $ko KO"
exit $ko
