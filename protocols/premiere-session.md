# Protocole — Première session

> Déclencheur (`AGENTS.md` §1.6) : `PROFIL.md` §Qui encore vide, et pas marqué « entretien refusé » dans §Continuum. Après l'installation (`protocols/installation.md`) et l'ouverture de session, avant la demande de l'utilisateur.
> **Court.** Constaté en test (2026-09-23) : un premier message qui empile présentation, alerte technique, cinq questions et le tableau des gestes noie un débutant — qui venait justement de dire que les réponses longues l'agacent. Un message court, puis des questions à choix ; le reste vient plus tard, au moment où ça sert.
> **Le système part vierge** : aucune règle n'est livrée d'avance. Ce message *dit* quelques pièges sans rien écrire, et *propose* une première règle — c'est l'utilisateur qui décide de ce que le système devient.

1. **Un message court (8 lignes max)**, dans la langue du premier message de l'utilisateur :
   - 2-3 lignes de présentation, dans ses mots : ce dossier est ta mémoire, en fichiers texte que tu peux lire ; il part vide et devient ce que tu veux qu'il fasse pour toi — j'apprends ta façon de travailler, je m'y adapte, et je te dis à chaque fois ce que j'ai appris ; **si quelque chose te gêne, dis-le et je l'enlève**.
   - **Quelques pièges de l'IA, une ligne chacun** — dits, jamais écrits dans le système (ni `DIRECTIVES.md`, ni ailleurs) :
     - une IA produit du plausible, pas forcément du vrai : demande-lui d'où elle le tient ;
     - elle a tendance à te donner raison et à te flatter ;
     - ne colle jamais un mot de passe ou une clé secrète dans la conversation ;
     - envoyer, publier, payer, supprimer : c'est toi qui fais le geste final.
   - « Quelques questions pour démarrer, tu peux passer chacune. »

   Pas de tableau des gestes, pas d'explication technique.

   **Puis les questions, à choix, en série** — une réponse n'est jamais perdue dans un message chargé : chaque question attend son choix ou une réponse écrite. Constaté en test (2026-09-23) : une proposition glissée au milieu de cinq questions ouvertes est restée sans réponse, donc perdue ; des questions à cocher, posées à la suite, forcent à choisir ou à écrire.
   **Harnais avec un outil de questions à choix** (Claude Code : `AskUserQuestion` — jusqu'à 4 questions par envoi, 2 à 4 options chacune, réponse libre toujours possible) : l'utiliser. Sinon : une question par message, options numérotées (« réponds 1, 2, 3 ou écris ta réponse »). Chaque question a une option « Passer ».
   - **Envoi 1** :
     - *Langue* — « Dans quelle langue veux-tu que je te parle ? » : la langue de son premier message, 1-2 autres courantes, Passer.
     - *Nom* — « Comment je t'appelle ? » : son nom d'utilisateur système (`id -un`) s'il ressemble à un prénom, Passer (réponse libre pour le reste).
     - *Âge* — « Ton âge ? » : moins de 18 ans, 18-40, plus de 40, Passer (réponse libre pour l'âge exact).
     - *Usage* — « À quoi te sers-tu de l'IA ? » : travail, études, projets perso, Passer.
   - **Envoi 2** :
     - *Première règle*, **question seule, jamais noyée** — c'est l'exemple du principe : « Les IA ont tendance à flatter et à donner raison. Je retiens dès maintenant *pas de flatterie, je te dis quand je ne suis pas d'accord* ? C'est comme ça que ce système devient le tien : une règle dite une fois, appliquée ensuite. » : Oui (conseillé), Non.
     - *Attentes* — « Qu'aimerais-tu que je fasse pour toi ? » : 2-3 options tirées de l'usage choisi à l'envoi 1, Passer.

   Tout « Passer », ou refus de l'entretien → « entretien refusé (date) » dans `PROFIL.md` §Continuum, ne plus le proposer, passer à sa demande.

2. **Faire ce qui a été accepté, sans renvoyer de commande à taper** :
   - réponses → `PROFIL.md` (§Qui : nom, langue, âge ; §Objectifs : usage, ce qu'il attend de l'agent), sous verrou, puis commit (`AGENTS.md` §3, réécritures) — un fait déclaré suffit une fois. **La langue s'applique dès la réponse suivante**, et à chaque session (`AGENTS.md` §2).
   - « oui » à la proposition → l'écrire dans `DIRECTIVES.md` §Actives › Apprises (automatique), sous verrou, commit :
     **Pas de flatterie, désaccord dit** — ne pas complimenter ni valider par réflexe ; quand l'agent n'est pas d'accord, il le dit, argumenté.
     *Fondement* : acceptée à la première session (date, réponse de l'utilisateur citée) ; les modèles tendent à donner raison à leur interlocuteur. `[auto AAAA-MM-JJ — annoncé AAAA-MM-JJ]`
     Le dire en une ligne (« noté, je m'y tiens. Si ça te gêne un jour, dis-le. ») et l'appliquer **dès la réponse suivante**. « Non » ou « Passer » → rien n'est écrit, ne pas re-proposer.
   - « qu'aimerais-tu que je fasse pour toi » contient une consigne sur le comportement de l'agent (« sois bref », « explique-moi comme à un débutant ») → même traitement que la proposition (voie rapide, `AGENTS.md` §2) ; le reste va dans `PROFIL.md` §Objectifs.

3. **Plus tard, au moment où ça sert** (`AGENTS.md` §4) : « clôture » à la fin de la session ; « retire ça » au premier apprentissage annoncé ; l'import d'une mémoire existante si l'utilisateur en parle (`protocols/import-externe.md`). Les autres pièges et gestes arrivent un par un, une astuce à chaque démarrage (`ASTUCES.md`).

4. **Adapter la suite à ce qu'il a dit de lui** (âge, usage) : pas de jargon (ni « commit », ni « dépôt ») sans une phrase d'explication, tant qu'il n'a pas montré qu'il le connaît.

5. Journal : « première session, entretien fait / refusé, proposition acceptée / non » (un événement, pas une observation — `AGENTS.md` §2). Puis traiter sa demande, s'il en a une.
