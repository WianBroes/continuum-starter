#!/usr/bin/env bash
# Installs Continuum on THIS machine — first start (protocols/installation.md).
# Detects the OS, checks dependencies, creates the OS-specific entry point, enables the git
# hook, runs the tests, then writes .continuum/installed (not versioned: one install per machine).
#   bash tools/install.sh              full install (tests: 1 to 10 min depending on the OS)
#   bash tools/install.sh --no-tests   without the test suite (not recommended)
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"   # picks tools/os/<os>.sh for the detected OS
echo "Detected OS: $CONTINUUM_OS ($(uname -s), bash $BASH_VERSION)"

missing=""
for c in git awk sed grep sort date mkdir mv tar; do command -v "$c" >/dev/null || missing="$missing $c"; done
case $CONTINUUM_OS in
  linux) for c in ps pgrep; do command -v "$c" >/dev/null || missing="$missing $c"; done ;;
  macos) for c in ps pgrep lsof sysctl; do command -v "$c" >/dev/null || missing="$missing $c"; done ;;
  windows) command -v powershell.exe >/dev/null || missing="$missing powershell.exe" ;;
esac
[ -z "$missing" ] || { echo "Missing:$missing — installation stopped."; exit 1; }
[ -n "$(boot_id)" ] || { echo "Boot identifier unreadable — installation stopped."; exit 1; }

if p=$(harness_pid); then echo "Agent detected: pid $p ($(proc_name "$p"))"
else echo "No agent detected among parent processes (normal if run by hand; otherwise set CONTINUUM_PID)"; fi

# Git repository: the safety net (TIPS.md, « working without a net » pitfall) and the basis of the tests. Local, private.
# This folder must be the root of its own repository: the English template ships as the en/ folder of the
# continuum-starter repository, and the user's memory must never be committed into that one.
top=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null) && top=$(cd "$top" && pwd -P) || top=""
if [ "$top" != "$ROOT" ]; then
  git -C "$ROOT" init -q && echo "Local git repository created"
fi
if [ -z "$(git -C "$ROOT" config user.name)" ]; then
  git -C "$ROOT" config user.name "$(id -un 2>/dev/null || echo continuum)"
  git -C "$ROOT" config user.email "$(id -un 2>/dev/null || echo continuum)@$(uname -n)"
  echo "Git identity local to the repository: $(git -C "$ROOT" config user.name)"
fi
if ! git -C "$ROOT" rev-parse -q --verify HEAD >/dev/null; then
  git -C "$ROOT" add -A && git -C "$ROOT" commit -q --no-verify -m "Continuum template" && echo "First commit done"
fi
git -C "$ROOT" config core.hooksPath tools/hooks && echo "Git hook enabled (declared projects)"
# Link to the template: `git clone` records the source address (« origin »); a push would send the
# user's memory there. Removed outright if it points to a continuum-starter repository; a link to another one (theirs) is kept.
if u=$(git -C "$ROOT" remote get-url origin 2>/dev/null); then
  case $(printf '%s' "$u" | tr 'A-Z' 'a-z') in
    *continuum-starter|*continuum-starter.git|*continuum-starter/)
      git -C "$ROOT" remote remove origin && echo "Link to the online template removed ($u): nothing from here can go there" ;;
  esac
fi

# Entry point for agents whose shell is not bash (PowerShell, cmd): goes through this machine's
# Git Bash. Machine-specific path → generated here, never versioned.
if [ "$CONTINUUM_OS" = windows ]; then
  b=$(cygpath -w /usr/bin/bash.exe)
  printf '@echo off\r\n"%s" "%%~dp0tools\\session.sh" %%*\r\n' "$b" > "$ROOT/continuum.cmd"
  echo "Created: continuum.cmd → $b"
fi

mkdir -p "$ROOT/.continuum"
res="not run"
if [ "${1:-}" != --no-tests ]; then
  echo "Running tests (1 to 10 min depending on the OS)…"
  bash "$ROOT/tools/tests.sh" > "$ROOT/.continuum/tests.log" 2>&1; ko=$?
  res=$(grep '^Result' "$ROOT/.continuum/tests.log")
  echo "$res (details: .continuum/tests.log)"
  if [ "$ko" != 0 ]; then grep -E '^  KO' "$ROOT/.continuum/tests.log"; echo "Installation NOT validated."; exit 1; fi
fi
printf 'os: %s\nmachine: %s\ndate: %s\nbash: %s\ntests: %s\n' "$CONTINUUM_OS" "$(uname -n)" "$(date '+%F %H:%M')" "$BASH_VERSION" "$res" > "$ROOT/.continuum/installed"
echo "Installation validated on $(uname -n)."
