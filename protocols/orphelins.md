# Protocole — Sessions orphelines et agents sans dossier

> Pas chargé par défaut. Consulté quand l'état affiché par `outils/session.sh ouvrir|etat` (`AGENTS.md` §1) montre une session **incertaine** ou un **agent actif sans dossier de session**.

Une session orpheline = un dossier resté dans `sessions/open/` sans clôture : agent planté, terminal fermé, conversation remplacée (`/clear`, `/new`) sans repasser par le rituel.

## Détection

L'en-tête de `SESSION.md` porte l'empreinte de l'agent : `machine boot_id pid starttime`. Le verdict ne dépend d'aucun agent en particulier :

- **même machine** : vivant si le process existe, avec la même heure de démarrage, et n'est pas zombie ; sinon **mort, certain** (process disparu, PID réutilisé, machine redémarrée) ;
- **autre machine** : **incertain**.

## Action selon le cas

- **Mort certain** → clos automatiquement par `session.sh ouvrir` (note « Clos a posteriori… — harnais mort », déplacement vers `closed/`). La fusion suivante en fait une entrée `BASE.md` « Clos sans synthèse — journal brut : `sessions/sealed/<id>/` » : rien n'est inventé au-delà de ce qui est écrit. Aucune décision à prendre.
- **Ma propre empreinte** (conversation précédente du même process) → même traitement, automatique.
- **Incertain** → ne toucher à rien. Le signaler à l'utilisateur (depuis quand, dernière activité = date de modification de `SESSION.md`) et attendre sa confirmation. S'il confirme qu'elle est terminée : ajouter en fin de `SESSION.md` « Clos a posteriori le … — confirmé terminé par l'utilisateur », puis `## Fin` / `fin: …`, et la déplacer vers `closed/` à la main.
- **Agent actif sans dossier de session** (agent connu dont le dossier de travail est ici, mais qui n'a jamais lancé le rituel) → le signaler : il est invisible pour les autres et ne respecte peut-être ni le verrou ni les déclarations de projet. Ne rien faire à sa place.
- Deux agents qui clôturent le même orphelin en même temps : le second déplacement échoue (dossier déjà parti), rien d'autre ne se passe.

## Limites connues

- Un agent lancé **hors** de ce dossier qui y écrit par chemin absolu reste invisible.
- La liste des agents reconnus (`HARNAIS_CONNUS` dans `outils/session.sh`, surchargeable par `CONTINUUM_HARNAIS`) doit suivre les nouveaux outils.
