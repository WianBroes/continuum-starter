# Protocol — First session

> Trigger (`AGENTS.md` §1.6): `PROFILE.md` §Who still empty, and not marked « interview declined » in §Continuum. After the installation (`protocols/installation.md`) and the session opening, before the user's request.
> **Short.** Seen in testing: a first message that piles up an introduction, a technical warning, five questions and the table of gestures drowns a beginner — who had just said that long answers annoy them. A short message, then multiple-choice questions; the rest comes later, when it is useful.
> **The system starts blank**: no rule ships in advance. This message *says* a few pitfalls without writing anything, and *proposes* a first rule — it is the user who decides what the system becomes.

1. **A short message (8 lines max)**, in the language of the user's first message:
   - 2-3 lines of introduction, in their words: this folder is your memory, in text files you can read; it starts empty and becomes what you want it to do for you — I learn how you work, adapt to it, and tell you each time what I have learned; **if something bothers you, say so and I'll remove it**.
   - **A few AI pitfalls, one line each** — said, never written into the system (neither `DIRECTIVES.md`, nor anywhere else):
     - an AI produces what sounds plausible, not necessarily what's true: ask it where it got it from;
     - it tends to agree with you and flatter you;
     - never paste a password or a secret key into the conversation;
     - sending, publishing, paying, deleting: you make the final move.
   - « A few questions to get started, you can skip any of them. »

   No table of gestures, no technical explanation.

   **Then the questions, multiple choice, in a series** — an answer is never lost in a crowded message: each question waits for its choice or a written answer. Seen in testing: a proposal slipped in among five open questions got no answer, so it was lost; questions to tick, asked one after the other, force a choice or a written answer.
   **Harness with a multiple-choice question tool** (Claude Code: `AskUserQuestion` — up to 4 questions per send, 2 to 4 options each, free answer always possible): use it. Otherwise: one question per message, numbered options (« answer 1, 2, 3 or write your own answer »). Each question has a « Skip » option.
   - **Send 1**:
     - *Language* — « Which language do you want me to speak to you in? »: the language of their first message, 1-2 other common ones, Skip.
     - *Name* — « What should I call you? »: their system user name (`id -un`) if it looks like a first name, Skip (free answer for the rest).
     - *Age* — « Your age? »: under 18, 18-40, over 40, Skip (free answer for the exact age).
     - *Use* — « What do you use AI for? »: work, studies, personal projects, Skip.
   - **Send 2**:
     - *First rule*, **a question on its own, never drowned** — it is the example of the principle: « AIs tend to flatter and agree. Shall I keep from now on *no flattery, I tell you when I disagree*? That's how this system becomes yours: a rule said once, applied from then on. »: Yes (recommended), No.
     - *Expectations* — « What would you like me to do for you? »: 2-3 options drawn from the use chosen in send 1, Skip.

   Everything « Skip », or the interview declined → « interview declined (date) » in `PROFILE.md` §Continuum, don't offer it again, move on to their request.

2. **Do what was accepted, without handing back a command to type**:
   - answers → `PROFILE.md` (§Who: name, language, age; §Goals: use, what they expect from the agent), under lock, then commit (`AGENTS.md` §3, rewrites) — a stated fact is enough once. **The language applies from the next answer on**, and at every session (`AGENTS.md` §2).
   - « yes » to the proposal → write it in `DIRECTIVES.md` §Active › Learned (automatic), under lock, commit:
     **No flattery, disagreement said** — don't compliment or validate by reflex; when the agent disagrees, it says so, with its reasons.
     *Basis*: accepted at the first session (date, the user's answer quoted); models tend to agree with whoever they are talking to. `[auto YYYY-MM-DD — announced YYYY-MM-DD]`
     Say it in one line (« noted, I'll stick to it. If it ever bothers you, say so. ») and apply it **from the next answer on**. « No » or « Skip » → nothing is written, don't propose it again.
   - « what would you like me to do for you » contains an instruction about the agent's behavior (« be brief », « explain it to me like a beginner ») → same treatment as the proposal (fast track, `AGENTS.md` §2); the rest goes into `PROFILE.md` §Goals.

3. **Later, when it is useful** (`AGENTS.md` §4): « close » at the end of the session; « remove that » at the first announced learning; importing an existing memory if the user mentions one (`protocols/external-import.md`). The other pitfalls and gestures arrive one by one, a tip at each startup (`TIPS.md`).

4. **Adapt what follows to what they said about themselves** (age, use): no jargon (neither « commit », nor « repository ») without a sentence of explanation, until they have shown they know it.

5. Log: « first session, interview done / declined, proposal accepted / not » (an event, not an observation — `AGENTS.md` §2). Then handle their request, if they have one.
