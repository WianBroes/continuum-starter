# Protocole — Import depuis une source externe

> Pas chargé par défaut. Consulté quand l'utilisateur veut faire venir ici un contenu d'un autre système : mémoire exportée d'un assistant IA, notes, ancien système de mémoire, profil écrit ailleurs. Souvent proposé à la première session (`protocols/premiere-session.md`).

## Deux échecs à éviter

- **Copier trop** : dupliquer une source volumineuse casse la brièveté des fichiers relus à chaque démarrage, et crée une deuxième vérité qui divergera en silence.
- **Pas assez tracer** : condenser sans dire d'où ça vient rend l'information invérifiable — un Fondement qu'on ne peut plus retracer n'est qu'une affirmation.

## Avant toute copie : lire en entier

Lire la source **entièrement** avant de copier quoi que ce soit — jamais sur la foi d'une recherche par mots-clés (`grep` sur « password », « token »…). Une recherche par motifs ne trouve que les secrets qui ont la forme attendue, et rien des **données de tiers** (noms, santé, situation familiale ou juridique, citations privées), qui se cachent souvent dans des exemples concrets en apparence pertinents. Si seule une partie de la source sert, construire directement un extrait réduit à cette partie.

## Les quatre couches

1. **Substance condensée, autosuffisante** — chaque élément importé (fait, trait, règle) est réécrit au format d'ici (constat + Fondement 2-3 lignes) et doit rester compréhensible **sans rouvrir la source**.
2. **Copie locale + origine notée** — les fichiers de synthèse réellement cités sont copiés dans `_sources/<nom-de-la-source>/`, avec leur chemin ou emplacement d'origine et la date. Rien ici ne doit casser si la source est déplacée ou supprimée. `_sources/README.md` tient l'inventaire (fichier, origine, date, rôle).
3. **Le distillé, jamais le brut** — les journaux bruts, historiques de conversation, logs ne sont pas copiés : seulement ce que la source a déjà synthétisé.
4. **Un instantané, pas une synchronisation** — un import est daté. Si la source évolue ensuite, c'est un écart normal, noté dans `STATUT.md` ; un nouvel import s'ajoute, il ne réécrit jamais l'ancien en silence.

## Où va quoi

| Contenu importé | Destination | Statut |
|---|---|---|
| Faits déclarés (qui, métier, outils, objectifs) | `PROFIL.md` | direct, si l'utilisateur les confirme |
| Traits de comportement déjà recoupés par la source | `TRAITS.md`, sous-section « Importés de <source> » | à confirmer en usage ici (révisables) |
| Règles de comportement pour l'IA | `DIRECTIVES.md` §Actives › Apprises (automatique), marquées `[auto … — non annoncé]` | actives aussitôt, annoncées ; l'utilisateur retire ce qui le gêne |

Écritures sous verrou (`AGENTS.md` §3). Journal : noter l'import (source, date, ce qui a été retenu, ce qui a été écarté et pourquoi).
