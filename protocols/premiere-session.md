# Protocole — Première session

> Déclencheur (`AGENTS.md` §1.6) : `PROFIL.md` §Qui encore vide, et pas marqué « entretien refusé » dans §Continuum. Après l'installation (`protocols/installation.md`) et l'ouverture de session, avant la demande de l'utilisateur.
> **Court.** Constaté en test (2026-09-23) : un premier message qui empile présentation, alerte technique, cinq questions et le tableau des gestes noie un débutant — qui venait justement de dire que les réponses longues l'agacent. Un seul message court, le reste vient plus tard, au moment où ça sert.
> **Le système part vierge** : aucune règle n'est livrée d'avance. Ce message *dit* quelques pièges sans rien écrire, et *propose* une première règle — c'est l'utilisateur qui décide de ce que le système devient.

1. **Un seul message, 15 lignes max**, dans la langue du premier message de l'utilisateur :
   - 2-3 lignes de présentation, dans ses mots : ce dossier est ta mémoire, en fichiers texte que tu peux lire ; il part vide et devient ce que tu veux qu'il fasse pour toi — j'apprends ta façon de travailler, je m'y adapte, et je te dis à chaque fois ce que j'ai appris ; **si quelque chose te gêne, dis-le et je l'enlève**.
   - **Quelques pièges de l'IA, une ligne chacun** — dits, jamais écrits dans le système (ni `DIRECTIVES.md`, ni ailleurs) :
     - une IA produit du plausible, pas forcément du vrai : demande-lui d'où elle le tient ;
     - elle a tendance à te donner raison et à te flatter ;
     - ne colle jamais un mot de passe ou une clé secrète dans la conversation ;
     - envoyer, publier, payer, supprimer : c'est toi qui fais le geste final.
   - **La proposition, qui sert d'exemple du principe** : « Justement, pour la flatterie : veux-tu que je retienne dès maintenant *pas de flatterie, et je te dis quand je ne suis pas d'accord* ? C'est comme ça que ce système devient le tien : une règle dite une fois, appliquée ensuite. »
   - Questions, réponses facultatives :
     - Comment je t'appelle ?
     - Dans quelle langue veux-tu que je te parle ?
     - Ton âge ?
     - À quoi te sers-tu de l'IA (travail, études, projets perso…) ?
     - Qu'aimerais-tu que je fasse pour toi ?

   Pas de tableau des gestes, pas d'explication technique. Refus de l'entretien → « entretien refusé (date) » dans `PROFIL.md` §Continuum, ne plus le proposer, passer à sa demande.

2. **Faire ce qui a été accepté, sans renvoyer de commande à taper** :
   - réponses → `PROFIL.md` (§Qui : nom, langue, âge ; §Objectifs : usage, ce qu'il attend de l'agent), sous verrou, puis commit (`AGENTS.md` §3, réécritures) — un fait déclaré suffit une fois. **La langue s'applique dès la réponse suivante**, et à chaque session (`AGENTS.md` §2).
   - « oui » à la proposition → l'écrire dans `DIRECTIVES.md` §Actives › Apprises (automatique), sous verrou, commit :
     **Pas de flatterie, désaccord dit** — ne pas complimenter ni valider par réflexe ; quand l'agent n'est pas d'accord, il le dit, argumenté.
     *Fondement* : acceptée à la première session (date, réponse de l'utilisateur citée) ; les modèles tendent à donner raison à leur interlocuteur. `[auto AAAA-MM-JJ — annoncé AAAA-MM-JJ]`
     Le dire en une ligne (« noté, je m'y tiens. Si ça te gêne un jour, dis-le. ») et l'appliquer **dès la réponse suivante**. Pas de réponse ou « non » → rien n'est écrit, ne pas re-proposer.
   - « qu'aimerais-tu que je fasse pour toi » contient une consigne sur le comportement de l'agent (« sois bref », « explique-moi comme à un débutant ») → même traitement que la proposition (voie rapide, `AGENTS.md` §2) ; le reste va dans `PROFIL.md` §Objectifs.

3. **Plus tard, au moment où ça sert** (`AGENTS.md` §4) : « clôture » à la fin de la session ; « retire ça » au premier apprentissage annoncé ; l'import d'une mémoire existante si l'utilisateur en parle (`protocols/import-externe.md`). Les autres pièges et gestes arrivent un par un, une astuce à chaque démarrage (`ASTUCES.md`).

4. **Adapter la suite à ce qu'il a dit de lui** (âge, usage) : pas de jargon (ni « commit », ni « dépôt ») sans une phrase d'explication, tant qu'il n'a pas montré qu'il le connaît.

5. Journal : « première session, entretien fait / refusé, proposition acceptée / non » (un événement, pas une observation — `AGENTS.md` §2). Puis traiter sa demande, s'il en a une.
