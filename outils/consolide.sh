#!/usr/bin/env bash
# Fusion mécanique Continuum — voir AGENTS.md §3.
# Sous verrou : pour chaque dossier de sessions/closed/ (ordre de clôture), copie
# ses sections fixes dans les fichiers communs, applique les plafonds de BASE.md
# (surplus → _archive/), déplace le dossier vers sealed/, puis commit.
# Aucune réécriture sémantique ici (ça reste à un agent, sous verrou).
#   ## Pour BASE       → BASE.md §Historique (entrée « orphelin » si vide ; rien si vide et
#                        suite_de — reprise après clôture : btw, question, pane coupé)
#   ## Faits durables  → BASE.md §Décidé
#   ## Retour          → fin d'OBSERVATIONS.md (## Observations, ancien nom, accepté aussi)
#   ## STATUT +        → lignes « | … | » en fin de STATUT.md
#   ## Apprises        → DIRECTIVES.md §Actives › Apprises (automatique) — actif sans attendre
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLAFOND_HISTORIQUE=5
PLAFOND_DECIDE=5
ARCHIVE=$RACINE/_archive/$(date +%F)_purge.md
TMP=$(mktemp -d)

MOI=$(mon_pid)
rendre() { verrou_rendre "$MOI" || true; rm -rf "$TMP"; }
verrou_prendre "$MOI" consolide || { echo "Verrou occupé : la prochaine fusion prendra sessions/closed/."; rm -rf "$TMP"; exit 0; }
trap rendre EXIT

# section <fichier> <titre> : contenu sous « ## titre », sans lignes vides en tête/queue
section() {
  awk -v t="## $2" '$0==t {on=1; next} /^## / {on=0} on {l[++n]=$0}
    END {d=1; while (d<=n && l[d]=="") d++; f=n; while (f>=d && l[f]=="") f--; for (i=d; i<=f; i++) print l[i]}' "$1"
}

# inserer <fichier> <titre de section> <fichier texte> : insère le texte en fin de section
# (avant le titre suivant de niveau 2 ou 3), en retirant un éventuel « *(vide… » de la section.
inserer() {
  awk -v t="$2" -v src="$3" '
    function vider() { while ((getline x < src) > 0) print x; print ""; dans = 0 }
    $0 == t { dans = 1; print; next }
    dans && /^##+ / { vider() }
    dans && /^\*\(vide/ { next }
    { print }
    END { if (dans) { print ""; while ((getline x < src) > 0) print x } }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# plafonner <fichier> <titre de section> <max> : au-delà du max, les entrées « **[ » les plus
# anciennes PAR DATE DE DÉBUT ([AAAA-MM-JJ HH:MM) → fin de l'archive, verbatim. La section est
# réécrite triée par date : l'ordre du fichier n'est pas fiable (héritage v0 arbitraire, 2026-09-23).
# Met à jour la note « dernière purge : … » de la section si elle existe.
plafonner() {
  [ -f "$ARCHIVE" ] || printf '# Archive — purge du %s\n\n> Contenu déplacé tel quel (plafonds, protocols/apprentissage.md point 5). Le plus ancien d'"'"'abord, jamais réécrit.\n' "$(date +%F)" > "$ARCHIVE"
  awk -v t="$2" -v max="$3" -v arch="$ARCHIVE" -v quand="$(date '+%F %H:%M')" -v nom="$(basename "$ARCHIVE")" '
    function bloc(k,   i) { for (i = st[k]; i < st[k + 1]; i++) if (l[i] != "") print l[i] }
    function bloc_arch(k,   i) { for (i = st[k]; i < st[k + 1]; i++) if (l[i] != "") print l[i] >> arch }
    { l[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (l[i] == t) s = i
        else if (s && !e && l[i] ~ /^## /) e = i
      }
      if (!e) e = NR + 1
      n = 0
      if (s) for (i = s + 1; i < e; i++) if (l[i] ~ /^\*\*\[/) st[++n] = i
      trop = n - max
      if (trop <= 0) { for (i = 1; i <= NR; i++) print l[i]; exit }
      st[n + 1] = e
      for (k = 1; k <= n; k++) { cle[k] = substr(l[st[k]], 4, 16) sprintf("%05d", k); o[k] = k }
      for (a = 2; a <= n; a++) { v = o[a]; b = a - 1; while (b >= 1 && cle[o[b]] > cle[v]) { o[b + 1] = o[b]; b-- } o[b + 1] = v }
      print "" >> arch; print "<!-- depuis " t " -->" >> arch
      for (r = 1; r <= trop; r++) { bloc_arch(o[r]); print "" >> arch }
      for (i = 1; i < st[1]; i++) {
        x = l[i]
        if (i > s && x ~ /dernière purge : /)
          sub(/dernière purge : .*/, "dernière purge : " quand " (" trop " entrée(s), les plus anciennes par date de début, fusion automatique → `_archive/" nom "`).", x)
        print x
      }
      for (r = trop + 1; r <= n; r++) { bloc(o[r]); print "" }
      for (i = e; i <= NR; i++) print l[i]
    }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

traites=()
# ordre de clôture (champ fin:), puis nom
while IFS='|' read -r _ d; do
  [ -n "$d" ] || continue
  id=$(basename "$d"); f=$d/SESSION.md
  debut=$(champ debut "$f"); fin=$(grep '^fin:' "$f" | tail -1 | cut -d' ' -f2-)
  fin_court=$fin; [ "${debut%% *}" = "${fin%% *}" ] && fin_court=${fin#* }   # même jour : heure seule

  base=$(section "$f" "Pour BASE"); suite=$(champ suite_de "$f")
  if [ -n "$base" ] || [ -z "$suite" ]; then
    [ -n "$base" ] || base="Clos sans synthèse (orphelin ou clôture incomplète) — journal brut : \`sessions/sealed/$id/\`."
    [ -z "$suite" ] || base="(suite de $suite) $base"
    printf '**[%s–%s] %s** — %s\n' "$debut" "$fin_court" "$id" "$base" | sed '/^$/d' > "$TMP/base"
    inserer "$RACINE/BASE.md" "## Historique" "$TMP/base"
  fi

  section "$f" "Faits durables" > "$TMP/faits"
  if [ -s "$TMP/faits" ]; then
    { printf '**[%s] %s** — ' "$fin" "$id"; cat "$TMP/faits"; } | sed '/^$/d' > "$TMP/faits2"
    inserer "$RACINE/BASE.md" "## Décidé" "$TMP/faits2"
  fi

  for t in Observations Retour; do
    section "$f" "$t" > "$TMP/obs"
    [ -s "$TMP/obs" ] && { echo; cat "$TMP/obs"; } >> "$RACINE/OBSERVATIONS.md"
  done

  section "$f" "STATUT +" | { grep '^|' || true; } > "$TMP/statut"
  [ -s "$TMP/statut" ] && cat "$TMP/statut" >> "$RACINE/STATUT.md"

  section "$f" "Apprises" > "$TMP/prop"
  [ -s "$TMP/prop" ] && inserer "$RACINE/DIRECTIVES.md" "### Apprises (automatique)" "$TMP/prop"

  mv "$d" "$SESSIONS/sealed/$id"
  traites+=("$id")
done < <(for d in "$SESSIONS"/closed/*/; do [ -d "$d" ] && echo "$(grep '^fin:' "$d/SESSION.md" | tail -1)|${d%/}"; done | sort)

if [ ${#traites[@]} -eq 0 ]; then echo "Rien à fusionner."; exit 0; fi

plafonner "$RACINE/BASE.md" "## Historique" "$PLAFOND_HISTORIQUE"
plafonner "$RACINE/BASE.md" "## Décidé" "$PLAFOND_DECIDE"
echo "Fusionné : ${traites[*]}"

# Commit limité aux chemins touchés (jamais -A global : d'autres agents travaillent à côté).
if [ -z "${CONTINUUM_SANS_GIT:-}" ] && git -C "$RACINE" rev-parse --git-dir >/dev/null 2>&1; then
  chemins=()
  # PROFIL/TRAITS : réécrits à la main sous verrou ; un oubli de commit est rattrapé ici (le verrou est à nous)
  for p in BASE.md OBSERVATIONS.md STATUT.md DIRECTIVES.md PROFIL.md TRAITS.md _archive sessions/closed sessions/sealed; do
    # seulement ce que git connaît ou peut ajouter, sinon le pathspec fait échouer tout le commit
    [ -n "$(git -C "$RACINE" ls-files -co --exclude-standard -- "$p")" ] && chemins+=("$p")
  done
  for essai in 1 2 3 4 5; do
    if erreur=$(git -C "$RACINE" add -A -- "${chemins[@]}" 2>&1 &&
                git -C "$RACINE" commit -q --no-verify -m "Fusion : ${traites[*]}" -- "${chemins[@]}" 2>&1); then
      echo "Commit : $(git -C "$RACINE" log --oneline -1)"; break
    fi
    [ "$essai" = 5 ] && echo "Commit échoué (fusion faite, à committer à la main) : $erreur" >&2
    sleep 1   # index.lock d'un commit concurrent
  done
fi
