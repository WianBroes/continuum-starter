#!/usr/bin/env bash
# Installation de Continuum sur CETTE machine — premier démarrage (protocols/installation.md).
# Détecte l'OS, vérifie les dépendances, crée le point d'entrée propre à l'OS, active le hook
# git, lance les tests, puis écrit .continuum/installe (non versionné : une installation par machine).
#   bash outils/installer.sh              installation complète (tests : 1 à 10 min selon l'OS)
#   bash outils/installer.sh --sans-tests sans la suite de tests (déconseillé)
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"   # choisit outils/os/<os>.sh selon l'OS détecté
echo "OS détecté : $CONTINUUM_OS ($(uname -s), bash $BASH_VERSION)"

manque=""
for c in git awk sed grep sort date mkdir mv; do command -v "$c" >/dev/null || manque="$manque $c"; done
case $CONTINUUM_OS in
  linux) for c in ps pgrep; do command -v "$c" >/dev/null || manque="$manque $c"; done ;;
  macos) for c in ps pgrep lsof sysctl; do command -v "$c" >/dev/null || manque="$manque $c"; done ;;
  windows) command -v powershell.exe >/dev/null || manque="$manque powershell.exe" ;;
esac
[ -z "$manque" ] || { echo "Manquant :$manque — installation interrompue."; exit 1; }
[ -n "$(boot_id)" ] || { echo "Identifiant de démarrage illisible — installation interrompue."; exit 1; }

if p=$(harnais_pid); then echo "Agent détecté : pid $p ($(nom "$p"))"
else echo "Aucun agent détecté parmi les process parents (normal si lancé à la main ; sinon définir CONTINUUM_PID)"; fi

# Dépôt git : le filet de sécurité (ASTUCES.md, piège « travailler sans filet ») et la base des tests. Local, privé.
if ! git -C "$RACINE" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$RACINE" init -q && echo "Dépôt git local créé"
fi
if [ -z "$(git -C "$RACINE" config user.name)" ]; then
  git -C "$RACINE" config user.name "$(id -un 2>/dev/null || echo continuum)"
  git -C "$RACINE" config user.email "$(id -un 2>/dev/null || echo continuum)@$(uname -n)"
  echo "Identité git locale au dépôt : $(git -C "$RACINE" config user.name)"
fi
if ! git -C "$RACINE" rev-parse -q --verify HEAD >/dev/null; then
  git -C "$RACINE" add -A && git -C "$RACINE" commit -q --no-verify -m "Gabarit Continuum" && echo "Premier commit fait"
fi
git -C "$RACINE" config core.hooksPath outils/hooks && echo "Hook git activé (projets déclarés)"
# Lien vers le gabarit : `git clone` enregistre l'adresse d'origine (« origin ») ; un push y enverrait la mémoire de
# l'utilisateur. Coupé d'office s'il pointe vers un dépôt continuum-starter ; un lien vers un autre dépôt (le sien) est laissé.
if u=$(git -C "$RACINE" remote get-url origin 2>/dev/null); then
  case $(printf '%s' "$u" | tr 'A-Z' 'a-z') in
    *continuum-starter|*continuum-starter.git|*continuum-starter/)
      git -C "$RACINE" remote remove origin && echo "Lien vers le gabarit en ligne retiré ($u) : rien d'ici ne peut y partir" ;;
  esac
fi

# Point d'entrée pour les agents dont le shell n'est pas bash (PowerShell, cmd) : passe par le
# Git Bash de cette machine. Chemin propre à la machine → généré ici, jamais versionné.
if [ "$CONTINUUM_OS" = windows ]; then
  b=$(cygpath -w /usr/bin/bash.exe)
  printf '@echo off\r\n"%s" "%%~dp0outils\\session.sh" %%*\r\n' "$b" > "$RACINE/continuum.cmd"
  echo "Créé : continuum.cmd → $b"
fi

mkdir -p "$RACINE/.continuum"
res="non lancés"
if [ "${1:-}" != --sans-tests ]; then
  echo "Tests en cours (1 à 10 min selon l'OS)…"
  bash "$RACINE/outils/tests.sh" > "$RACINE/.continuum/tests.log" 2>&1; ko=$?
  res=$(grep '^Résultat' "$RACINE/.continuum/tests.log")
  echo "$res (détail : .continuum/tests.log)"
  if [ "$ko" != 0 ]; then grep -E '^  KO' "$RACINE/.continuum/tests.log"; echo "Installation NON validée."; exit 1; fi
fi
printf 'os: %s\nmachine: %s\ndate: %s\nbash: %s\ntests: %s\n' "$CONTINUUM_OS" "$(uname -n)" "$(date '+%F %H:%M')" "$BASH_VERSION" "$res" > "$RACINE/.continuum/installe"
echo "Installation validée sur $(uname -n)."
