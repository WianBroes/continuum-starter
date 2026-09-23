# Protocole — Installation (premier démarrage sur une machine)

> Déclencheur (`AGENTS.md` §1.1) : pas de fichier `.continuum/installe` à la racine. Une fois par machine : ce fichier n'est pas versionné, un dossier synchronisé entre deux machines s'installe sur chacune. L'agent le fait seul, sans demander : c'est technique, et réversible.

1. **Lancer l'installeur** depuis la racine de ce dossier :
   - Linux, macOS, et Windows quand le shell de l'agent est bash (Claude Code sous Windows utilise Git Bash) : `bash outils/installer.sh`
   - Windows, agent dont le shell est PowerShell : **jamais `bash` tout court** (sous Windows, ce peut être le bash de WSL, un autre système). Passer par le Git Bash de Git for Windows :
     `& (Join-Path (Resolve-Path "$(git --exec-path)/../../..") 'bin\bash.exe') outils/installer.sh`

   L'installeur détecte l'OS et charge sa couche (`outils/os/<os>.sh`), vérifie les dépendances, crée le dépôt git local s'il manque (et une identité git propre au dépôt si aucune n'existe), active le hook des projets, coupe le lien vers le gabarit en ligne s'il existe (`origin` d'un `git clone` pointant vers un dépôt continuum-starter — un lien vers un autre dépôt est laissé), crée sous Windows `continuum.cmd` (point d'entrée pour les agents sous PowerShell/cmd), lance la suite de tests, puis écrit `.continuum/installe`.

2. **Selon le résultat** :
   - « Installation validée » → dire à l'utilisateur **une ligne** (« Continuum est installé sur cette machine (macOS), tout fonctionne ») et reprendre le démarrage (`AGENTS.md` §1.2).
   - « Manquant : … » → dire en une phrase quoi installer, sans jargon :
     - Windows : Git for Windows (git-scm.com — il apporte Git Bash) ;
     - macOS : `xcode-select --install` (git et les outils de base) ;
     - Linux : le paquet de la commande manquante (souvent `procps`).
     Puis relancer l'installeur.
   - « OS non pris en charge » (ni Linux, ni macOS, ni Windows) → le dire ; Continuum ne peut pas garantir le travail à plusieurs agents sur cette machine. Ne pas bricoler une couche OS sans l'accord de l'utilisateur.
   - Tests en échec (« Installation NON validée ») → montrer les lignes `KO`, ne pas lancer plusieurs agents en même temps sur cette machine, et noter le problème pour `## STATUT +` à la clôture (OS, version, lignes KO — `.continuum/tests.log`).

3. Journal : une entrée « installation sur <machine> (<os>) : validée / échec ».

## Limites connues par OS

- **Windows** : deux process qui ajoutent en même temps à la fin d'un **même** fichier peuvent entremêler leurs lignes (sans conséquence : chaque agent n'écrit que dans son propre journal, les fichiers communs passent par le verrou). La détection des agents actifs **sans dossier de session** n'est pas disponible (le dossier de travail d'un autre process n'est pas lisible sans outil tiers) — chaque agent doit donc lancer le rituel. Les appels à PowerShell rendent `session.sh` plus lent (quelques secondes).
- **macOS** : heure de démarrage des process à la seconde près (`ps`) ; suffisant pour distinguer un process d'un autre.
- **Tous** : un agent lancé hors de ce dossier, qui y écrit par chemin absolu, reste invisible (`protocols/orphelins.md`).
