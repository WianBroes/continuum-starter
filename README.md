# Continuum — gabarit vierge

Une mémoire pour ton assistant IA, en simples fichiers texte, qui **apprend de toi** et devient ce que tu veux qu'il fasse pour toi.

- Il remarque ta façon de travailler : ce que tu corriges, ce que tu répètes, ce qui t'agace.
- Quand un motif revient sur plusieurs sessions, il **en tire une règle et s'y tient**, tout seul, et te dit à chaque fois ce qu'il a appris. Si quelque chose te gêne, tu le dis et c'est retiré.
- Il part vide : aucune règle imposée. À chaque démarrage, une astuce sur l'usage de l'IA et ses pièges (`ASTUCES.md`), jusqu'à ce que le système soit rodé.
- Tout est lisible et modifiable par toi, à tout moment. Tout reste sur ta machine.
- Plusieurs agents peuvent y travailler **en même temps** (plusieurs terminaux, des outils différents) sans se marcher dessus.

## Il te faut

- **Un agent IA en ligne de commande** : Claude Code, Codex, Gemini CLI, pi, opencode… n'importe lequel qui lit `AGENTS.md` (ou `CLAUDE.md`) et peut lancer des commandes.
- **git** : sous Windows, installe [Git for Windows](https://git-scm.com), qui apporte aussi Git Bash, nécessaire à Continuum ; sous macOS, lance `xcode-select --install` ; sous Linux, il est généralement déjà là.

## Démarrer

1. Mets ce dossier où tu veux.
2. Ouvre ton agent IA **dans ce dossier**.
3. Dis bonjour.

La première fois, l'agent installe Continuum pour ton système (Linux, macOS ou Windows) et vérifie que tout fonctionne. Tu n'as rien à faire, il te donne le résultat en une ligne. Ensuite, il se présente, te dit quelques pièges de l'IA, puis te pose quelques questions à cocher (ta langue, ton nom, ton âge, ton usage de l'IA, ce que tu attends de lui) ; chacune se passe, ou se remplit à ta façon. L'une d'elles te propose une première règle : pas de flatterie. S'il est encore relié au dépôt en ligne d'où tu l'as copié, il coupe ce lien tout seul : rien de toi ne peut partir là-bas.

C'est tout. Pas besoin de lire la suite : l'agent t'apprendra les gestes au moment où ils servent.

## Les six gestes

| Tu dis | Ce qui se passe |
|---|---|
| « clôture » | fin de session : ce qui a été appris part en mémoire |
| « retire ça », « ça me gêne » | ce qu'il a appris est retiré, et ne reviendra pas |
| « à partir de maintenant… » | règle proposée tout de suite |
| « lance l'apprentissage » | l'agent relit ses observations tout de suite (sinon, il le fait tout seul de temps en temps) |
| « qu'as-tu appris ? » | bilan : ce qui est noté, ce qui est déduit, ce qui est appliqué |
| « pourquoi tu fais ça ? » | l'agent cite la règle qui l'a guidé |

## Comment il apprend

```
tu travailles ──► OBSERVATIONS.md   ce qui a été remarqué (brut)
                      │  même motif sur 3 sessions différentes
                      ▼
                  Apprises          règle déduite, appliquée tout de suite (DIRECTIVES.md)
                      │  il te le dit
                      ▼
                  toi               « ça me gêne » → retiré, et ne revient pas
```

Il y a trois étages, toujours séparés : tu peux voir à tout moment ce qu'il a noté, ce qu'il en tire et ce qu'il applique. Ce que tu déclares toi-même (qui tu es, tes objectifs) va dans `PROFIL.md`. Ce qu'il recoupe sur ta façon de faire va dans `TRAITS.md`.

Au départ, `DIRECTIVES.md` est vide : chaque règle vient de toi, parce que tu l'as demandée ou parce qu'il l'a recoupée sur ta façon de faire.

## Les fichiers

| Fichier | Contenu |
|---|---|
| `AGENTS.md` | les règles du système, lues par l'agent à chaque démarrage |
| `PROFIL.md` | ce que tu as dit de toi |
| `TRAITS.md` | ce qu'il a recoupé sur ta façon de travailler |
| `DIRECTIVES.md` | comment il se comporte : règles apprises |
| `ASTUCES.md` | les astuces du démarrage (gestes, pièges de l'IA) |
| `OBSERVATIONS.md` | ses notes brutes |
| `BASE.md` | mémoire des sessions récentes et des décisions |
| `sessions/` | une trace par session |
| `NN_NomProjet/` | tes projets (un dossier numéroté par projet) |
| `protocols/` | procédures rares, lues par l'agent quand il en a besoin |
| `outils/` | scripts du rituel ; `outils/os/` contient ce qui change d'un système à l'autre |

## Plusieurs agents en même temps

C'est ce qui fait Continuum. Chaque agent ouvre sa propre session, un dossier dans `sessions/`, et n'écrit que là. La mémoire commune ne s'écrit que sous un verrou, un agent à la fois, et elle est fusionnée automatiquement à chaque clôture. Un agent planté est détecté et sa session est close. Enfin, un projet déclaré par un agent est protégé contre les commits des autres.

Les scripts (`outils/`, en bash) marchent sous Linux, macOS et Windows (via Git Bash). Ils sont installés et testés automatiquement au premier démarrage sur chaque machine (`outils/installer.sh`).

## Confidentialité

- Rien ne sort de ta machine, en dehors de ce que ton agent IA envoie à son fournisseur pendant la conversation.
- N'écris jamais de mot de passe ou de clé dans ces fichiers.
- Évite d'y mettre des informations sur d'autres personnes.
- Garde le dépôt privé.
