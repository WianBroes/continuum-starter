# AGENTS.md — Continuum

> Système de mémoire et d'apprentissage pour agents IA, en fichiers texte. Il apprend de son utilisateur — comment il travaille, vérifie, décide, se trompe — et l'agent se comporte différemment à cause de ce qu'il a appris. Il guide aussi l'utilisateur dans l'usage de l'IA : une astuce à chaque démarrage, jusqu'à ce que le système soit rodé.
> Pensé pour **plusieurs agents en ligne de commande qui travaillent en même temps** dans ce dossier (Claude Code, Codex, pi, Gemini CLI, opencode…, plusieurs terminaux) sans se marcher dessus — c'est son objet. Linux, macOS et Windows : `outils/` (bash) détecte l'OS et s'installe au premier démarrage sur chaque machine (`protocols/installation.md`).
> **Gabarit vierge** : rien n'est encore appris, aucune règle n'est livrée d'avance. `PROFIL.md`, `TRAITS.md`, `OBSERVATIONS.md`, `BASE.md`, `DIRECTIVES.md` sont vides : le système devient ce que l'utilisateur veut qu'il fasse pour lui. La première règle est proposée à la première session (`protocols/premiere-session.md`), jamais imposée.

## 0. Principe

- **Trois paliers, jamais mélangés** — on doit toujours pouvoir voir ce que le système sait, et pourquoi :
  1. **Enregistré** — `OBSERVATIONS.md` : ce qui a été constaté sur l'utilisateur, brut, tagué par source.
  2. **Déduit** — la boucle d'apprentissage (automatique, à la clôture) regroupe les observations : un motif recoupé sur **3 sessions distinctes** devient une directive ou un trait.
  3. **Appliqué** — `DIRECTIVES.md` §Actives : ce qui a été appris — **actif tout de suite, sans attendre de « oui »**, puis annoncé à l'utilisateur. Il dit que quelque chose le gêne → retiré aussitôt, jamais re-proposé. C'est le seul fichier qui change réellement le comportement de l'agent d'une session à l'autre.
- **Fichiers communs** :
  - `BASE.md` — mémoire commune : décisions durables + historique récent (plafonnés, surplus → `_archive/`).
  - `PROFIL.md` — faits **déclarés** par l'utilisateur (qui, objectifs, niveau avec l'IA, outils). Court, état courant, pas d'historique.
  - `TRAITS.md` — traits de comportement **recoupés** (comment il vérifie, décide, conçoit). Sert à interpréter ses demandes, ne prescrit rien.
  - `DIRECTIVES.md` — comment l'agent se comporte : règles apprises.
  - `ASTUCES.md` — astuces (gestes, pièges de l'IA) affichées une par démarrage. Pas des règles, ne change pas le comportement de l'agent.
  - `OBSERVATIONS.md` — buffer brut. `STATUT.md` — points ouverts du système lui-même.
- **Un dossier par session**, et l'état d'une session = l'endroit où est son dossier : `sessions/open/<id>/` → `sessions/closed/<id>/` → `sessions/sealed/<id>/`. Chaque changement d'état est un déplacement (`mv`, atomique). Pendant sa session, un agent n'écrit que dans **son propre dossier** : `SESSION.md` (en-tête, journal, sections de clôture), ses brouillons, son `inbox/`.
- **Fichiers communs : écrits uniquement sous verrou** (`.lock/`, `mkdir` atomique, un seul gagnant) — par la fusion automatique (`outils/consolide.sh`) ou par une réécriture à la main (§3, dernier bloc).
- **Projets** : le travail concret vit dans un dossier numéroté à la racine, `NN_NomProjet/` — un par projet, avec son `AGENTS.md` (contexte, pointeur vers son `CHANGELOG.md`) et un `CLAUDE.md` d'une ligne, `@AGENTS.md`. Les livrables vont là, jamais dans le dossier de session.
- **Rien n'est jamais supprimé**, seulement déplacé (`_archive/`, `sessions/sealed/`).
- **Confidentialité** : tout reste local, dans un dépôt git **privé**. Aucun secret (clé API, mot de passe, token) dans un fichier de ce dossier. Données de tiers (noms, santé, situation familiale ou juridique) : le strict nécessaire, jamais dans les observations.
- **Outils** (`outils/`, bash 3.2+ — sous Windows, le Git Bash de Git for Windows) : `session.sh` (rituel), `consolide.sh` (fusion), `installer.sh` (premier démarrage), `hooks/pre-commit` (projets déclarés), `tests.sh` (à relancer après toute modification d'`outils/` — jamais de commit qui les casse). Ce qui dépend de l'OS est isolé dans `outils/os/<linux|macos|windows>.sh`. Les scripts ne font que des gestes mécaniques ; tout ce qui demande du jugement reste à l'agent.
- `protocols/` : procédures rares, jamais chargées par défaut, lues seulement quand leur condition se déclenche (pointeurs ci-dessous).

## 1. Démarrage — dès le premier message de la session, quel qu'il soit

Pas seulement sur « bonjour » : une session ouverte directement sur une commande doit aussi faire ce rituel, avant de traiter la demande.

1. Lire ce fichier en entier.
   **Pas de fichier `.continuum/installe`** (première utilisation sur cette machine) → `protocols/installation.md` d'abord, sans rien demander : c'est technique, l'utilisateur n'a qu'à lire le résultat en une ligne.
2. Ouvrir sa session, en premier : `bash outils/session.sh ouvrir <harnais> [modèle]` depuis la racine de ce dossier (Windows, agent dont le shell est PowerShell ou cmd : `.\continuum.cmd ouvrir <harnais> [modèle]`, idem pour toutes les commandes `session.sh`). Le script clôt les dossiers dont l'agent est **mort** (et ceux de sa propre conversation précédente), crée `sessions/open/<id>/`, et affiche l'état : sessions ouvertes (vivant / incertain), agents actifs sans dossier de session, sessions en attente de fusion, verrou, et deux signaux éventuels — **observations non consolidées** au-delà du seuil (20 par défaut, `CONTINUUM_SEUIL_OBS`), **harnais mis à jour** après son lancement. Plus, à partir de la 2e session et jusqu'à épuisement de `ASTUCES.md`, **l'astuce du jour**.
   Un **sous-agent** ne lance jamais ce rituel : il travaille dans le dossier de son parent.
3. Annoncer à l'utilisateur ce que l'état montre, en une ou deux lignes : autres sessions actives, sessions **incertaines** et agents **sans dossier** (ne rien décider seul : `protocols/orphelins.md`), signaux ci-dessus. L'astuce du jour : une ligne, telle quelle, dans la langue de l'utilisateur.
4. Lire `BASE.md`, `PROFIL.md`, `TRAITS.md`, `DIRECTIVES.md` section **Actives** (appliquée pendant toute la session), et la section `## Pour BASE` de chaque dossier de `sessions/closed/`.
5. Regarder l'`inbox/` de son dossier.
6. **`PROFIL.md` §Qui encore vide** (et pas marqué « entretien refusé ») → `protocols/premiere-session.md`, avant tout le reste.
   Sinon : restituer en 2-3 lignes où on en est (`BASE.md`), plus **« Appris depuis ta dernière session »** : chaque entrée de `DIRECTIVES.md`, `TRAITS.md`, `PROFIL.md` marquée `non annoncé`, une ligne chacune (quoi, d'où ça vient), puis ces marqueurs passés à `annoncé AAAA-MM-JJ` (sous verrou, commit) ; plus **au plus un** rappel de guidage si sa condition est réunie (§4). Puis traiter la demande, ou attendre — pas de menu.

## 2. Pendant la session

- **Journal sur déclencheur net** : une entrée dans `SESSION.md` à chaque commit et à chaque demande terminée — ni « au fil de l'eau » (jamais tenu en pratique), ni reconstituée de mémoire à la clôture. Toujours par ajout en fin de fichier, jamais relire-puis-réécrire. En passant : regarder son `inbox/`.
- **Projets** : dès qu'on touche un `NN_NomProjet/`, le déclarer : `bash outils/session.sh travail NN_NomProjet`. Le hook pre-commit refuse alors un commit sur ce projet par un autre agent vivant. Un autre agent vivant a déjà déclaré le même projet → le signaler avant d'y toucher.
- **Commits** : toujours sur des chemins précis (`git add <chemins> && git commit -- <chemins>`), jamais `git add -A`/`.` ni `commit -a` — ça embarquerait le travail en cours des autres agents. Piège : un fichier supprimé ou renommé par `git rm`/`git mv` ne se passe plus à `git add` (erreur « ne correspond à aucun fichier »), seulement au pathspec du commit. Inverse avec `git rm --cached` (fichier laissé sur disque) : le pathspec du commit reprend le disque et annule le retrait — committer depuis l'index, après avoir vérifié `git diff --cached --name-only`.
- **Incidents et retours, notés sur le moment** — c'est ce qui nourrit l'apprentissage. Chaque fois que l'utilisateur **corrige, reprend la main, relance une vérification** (« t'es sûr ? », question courte de contrôle), **refuse**, ou dit « non / plutôt / en fait / je préfère » → une ligne de journal avec **sa phrase exacte**, ce que l'agent venait de faire, ce qu'il voulait à la place. Idem pour une réussite nette (validé du premier coup, salué). Ce qui **n'en est pas** : un événement (« projet créé », « tests OK » → journal ordinaire et `## Pour BASE`), un portrait psychologique, ce que l'agent a fait. Pourquoi : testé sur de vraies sessions, « que s'est-il passé / comment se comporte-t-il » donnait du récit et une seule règle ; les incidents ont donné une vingtaine de leçons actionnables.
  Tags : `[incident]`, `[réussite]`, `[écart]`, `[leçon]`, `[fait]` (dit par l'utilisateur sur lui-même) ; `[IA]` en plus quand c'est une interprétation de l'agent sans citation — jamais promu seul, garde-fou.
  Format : `**[AAAA-MM-JJ HH:MM]** [type] — texte`.
- **Langue** : parler à l'utilisateur dans la langue déclarée dans `PROFIL.md` §Qui ; tant qu'elle ne l'est pas, dans celle de son premier message.
- **Effet** : quand une directive **Active** a changé ce que l'agent aurait fait sans elle, noter au journal `[effet] <nom de la directive>` — une ligne. Sans cette trace, impossible de savoir si le système sert à quelque chose.
- **Voie rapide** : une consigne explicite de l'utilisateur sur le comportement de l'agent (« à partir de maintenant… », « ne fais plus jamais… », « retiens que… ») s'applique **tout de suite** — le dire en une ligne (« noté, je m'y tiens désormais ») ; à la clôture, elle part en `## Apprises`.
- **Objection** : l'utilisateur dit qu'un apprentissage le gêne (« retire ça », « ça me gêne », « non » sur un ajout annoncé) → retrait immédiat, sans discussion (`protocols/apprentissage.md` point 9).
- **Rien ne se « garde en tête »** : le contexte de conversation disparaît à la fin de la session. Ce qui doit survivre s'écrit immédiatement.

## 2bis. Directives de code (toujours actives, dès que la session touche du code)

- Avant d'implémenter : expliciter les hypothèses, présenter les interprétations possibles plutôt que trancher en silence, signaler une approche plus simple si elle existe, s'arrêter et demander si quelque chose n'est pas clair.
- Minimum de code qui résout le problème : pas de fonctionnalité non demandée, pas d'abstraction pour du code à usage unique, pas de gestion d'erreur pour des scénarios impossibles.
- Changements chirurgicaux : toucher seulement ce qui est nécessaire, ne pas « améliorer » le code adjacent, signaler le code mort repéré sans le supprimer.
- Définir un critère de succès vérifiable avant de boucler dessus (test qui reproduit le bug puis passe, tests avant/après un refactor…).

## 3. Clôture (« clôture », « on ferme », « close », « on a fini »)

1. Relire son journal et remplir, **en fin de `SESSION.md`**, les sections utiles (titres exacts ; une section absente = rien à transmettre ; un titre présent deux fois — clôture réécrite après une reprise — seule la dernière compte) :
   - `## Pour BASE` — ce qui a été fait, ce qui reste ouvert. **5 lignes max.** → `BASE.md` §Historique.
   - `## Faits durables` — décision ou fait qui doit survivre à la rotation de l'Historique. 3 lignes max. → `BASE.md` §Décidé.
   - `## Retour` — une ligne par élément, `**[AAAA-MM-JJ HH:MM]** [type] — …` (→ fin d'`OBSERVATIONS.md`), en répondant à :
     1. **Écart** `[écart]` — qu'attendait l'utilisateur (objectif de la session, des demandes importantes), qu'est-ce qui a été livré, où ça a divergé et pourquoi (la cause, pas un coupable) ;
     2. **Incidents** `[incident]` — chaque correction, reprise en main, relance, refus : citation exacte + heure, ce que l'agent venait de faire, ce qu'il voulait à la place (repris du journal) ;
     3. **Réussites** `[réussite]` — validé du premier coup ou salué, et quel choix de l'agent a marché ;
     4. **Leçons** `[leçon]` — pour chaque incident ou réussite significatif : « Quand <situation reconnaissable par un agent futur>, faire <action concrète> » + preuve (citation, heure). Seulement ce qui changerait le comportement d'un agent futur. Une leçon propre à un projet va dans le `CHANGELOG.md` du projet ;
     5. **Faits déclarés** `[fait]` — ce que l'utilisateur a dit de lui-même (→ `PROFIL.md` par la boucle).
     Pas d'événements ni de récit : ils vont dans `## Pour BASE`. Méthode : After Action Review, incidents critiques (Flanagan, 1954), leçons déclencheur → action (travaux ERL/ExpeL sur les agents qui apprennent de leur expérience).
   - `## STATUT +` — nouveaux points ouverts du **système**, une ligne de tableau chacun : `| point | ouvert depuis | état |`. Les points d'un projet vont dans son `CHANGELOG.md`.
   - `## Apprises` — voie rapide (§2) : la règle + son **Fondement** (citation ou contexte, 2-3 lignes) + `[auto AAAA-MM-JJ — annoncé AAAA-MM-JJ]` (déjà dite en séance). → `DIRECTIVES.md` §Actives › Apprises (automatique), active dès la fusion.
2. **Montrer à l'utilisateur, en 2-3 lignes, ce qui part en mémoire** : observations notées, règles apprises, `[effet]` constatés. Pas de boîte noire.
3. `bash outils/session.sh clore` : écrit `fin:`, déplace le dossier vers `closed/`, puis lance la fusion (`outils/consolide.sh`, sous verrou) qui traite **tous** les dossiers de `closed/` : copie des sections ci-dessus dans les fichiers communs, plafonds de `BASE.md` (§Historique 5 entrées, §Décidé 5 ; surplus → `_archive/`, verbatim), déplacement vers `sealed/`, commit sur ces seuls chemins. Verrou occupé → rien à faire, la fusion suivante prendra tout.
   **Si `clore` affiche « Observations non consolidées : N »** (seuil atteint) : lancer tout de suite la boucle d'apprentissage (`protocols/apprentissage.md`), sans demander — elle est automatique. Harnais qui sait déléguer (sous-agent) : la lui confier. Ses ajouts sont actifs aussitôt ; les dire à l'utilisateur en quelques lignes s'il est encore là, sinon ils seront annoncés à l'ouverture suivante.
4. **Reprise après clôture** (l'utilisateur reparle sans avoir fermé l'agent) : toujours `ouvrir` avant de répondre, jamais réécrire dans le dossier clos. Le script reconnaît le même process et marque la nouvelle session `suite_de: <id>`. **Après un redémarrage de la machine** (Linux, agents lancés dans herdr qui reprend les conversations) : le process est neuf, c'est l'**identifiant de conversation** (`conversation:` de l'en-tête) qui fait le lien — une conversation qui n'avait pas été close retrouve son propre dossier (`ouvrir` affiche « Session reprise »), une conversation close normalement puis reprise ouvre une nouvelle session `suite_de` ; un dossier clos par une vraie clôture n'est jamais rouvert (`protocols/orphelins.md`). À la reclôture, `## Pour BASE` seulement si la suite a changé quelque chose.

**Réécritures à la main** (n'importe quand, n'importe quel agent, jamais sans verrou) : `bash outils/session.sh verrou prendre` → modifier → committer les fichiers modifiés, sur leurs seuls chemins → `bash outils/session.sh verrou rendre`. Verrou occupé → réessayer plus tard ; il expire seul (15 min), `verrou prendre` à nouveau le renouvelle. Concerne : retirer un apprentissage sur objection ; marquer `annoncé` ; mettre à jour `PROFIL.md` (fait déclaré, une fois suffit) ou `TRAITS.md` ; corriger `STATUT.md` ; la boucle d'apprentissage (`protocols/apprentissage.md`).

## 4. Guidage — apprendre le système en s'en servant

But : l'utilisateur finit par connaître Continuum **sans avoir lu la documentation**. On lui montre chaque geste au moment où il sert, puis on n'en parle plus.

**Les gestes à connaître** — jamais présentés en bloc : chacun est montré, en une ligne, la première fois qu'il sert (« clôture » à la fin de la première session, « retire ça » au premier apprentissage annoncé, etc.) :

| L'utilisateur dit | Ce qui se passe |
|---|---|
| « clôture » | fin de session : ce qui a été appris part en mémoire |
| « retire ça », « ça me gêne » | l'apprentissage annoncé est retiré, et ne reviendra pas |
| « à partir de maintenant… » | règle proposée tout de suite (voie rapide) |
| « lance l'apprentissage » | l'agent relit les observations et propose des règles (`protocols/apprentissage.md`) |
| « qu'as-tu appris ? » | bilan en trois paliers (ci-dessous) |
| « pourquoi tu fais ça ? » | l'agent cite la directive qui l'a guidé |

**Rappels** : au plus **un** par session, en une ligne, jamais en menu, et seulement quand sa condition est réunie :
- premier apprentissage annoncé → expliquer qu'il s'applique déjà, et qu'il suffit de dire si ça gêne ;
- session longue dont le sujet est clos → rappeler que clôturer puis repartir coûte moins et ne perd rien.

**Échafaudage qui s'efface** : dès que l'utilisateur utilise un geste de lui-même, l'ajouter à `PROFIL.md` §Continuum (« gestes connus ») — on ne le lui rappelle plus. « Pas de rappels » → plus aucun (noté dans `PROFIL.md`).

**« Qu'as-tu appris ? »** — bilan en trois paliers, chiffres pris dans les fichiers, jamais de mémoire :
1. *Enregistré* : nombre d'observations, dont non consolidées ; les thèmes récents.
2. *Déduit* : directives et traits appris (avec leur date), révisions.
3. *Appliqué* : directives Actives ; `[effet]` récents (`sessions/sealed/`) ; directives qui n'ont jamais eu d'effet.

**Niveau** : adapter l'explication à ce que l'utilisateur a dit de lui dans `PROFIL.md` — pas de jargon sans une phrase d'explication tant qu'il n'a pas montré qu'il le connaît.
