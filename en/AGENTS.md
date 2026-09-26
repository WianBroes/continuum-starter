# AGENTS.md — Continuum

> A memory and learning system for AI agents, in text files. It learns from its user — how they work, check, decide, make mistakes — and the agent behaves differently because of what it has learned. It also guides the user in using AI: one tip at each startup, until the system is broken in.
> Built for **several command-line agents working at the same time** in this folder (Claude Code, Codex, pi, Gemini CLI, opencode…, several terminals) without stepping on each other — that is its purpose. Linux, macOS and Windows: `tools/` (bash) detects the OS and installs itself at first startup on each machine (`protocols/installation.md`).
> **Blank template**: nothing has been learned yet, no rule ships in advance. `PROFILE.md`, `TRAITS.md`, `OBSERVATIONS.md`, `BASE.md`, `DIRECTIVES.md` are empty: the system becomes what the user wants it to do for them. The first rule is proposed at the first session (`protocols/first-session.md`), never imposed.

## 0. Principle

- **Three levels, never mixed** — one must always be able to see what the system knows, and why:
  1. **Recorded** — `OBSERVATIONS.md`: what was observed about the user, raw, tagged by source.
  2. **Deduced** — the learning loop (automatic, at close) groups the observations: a pattern cross-checked over **3 distinct sessions** becomes a directive or a trait.
  3. **Applied** — `DIRECTIVES.md` §Active: what has been learned — **active right away, without waiting for a « yes »**, then announced to the user. They say something bothers them → removed at once, never proposed again. It is the only file that really changes the agent's behavior from one session to the next.
- **Shared files**:
  - `BASE.md` — shared memory: lasting decisions + recent history (capped, surplus → `_archive/`).
  - `PROFILE.md` — facts **stated** by the user (who, goals, level with AI, tools). Short, current state, no history.
  - `TRAITS.md` — behavioral traits **cross-checked** (how they check, decide, design). Used to read their requests, prescribes nothing.
  - `DIRECTIVES.md` — how the agent behaves: learned rules.
  - `TIPS.md` — tips (gestures, AI pitfalls) shown one per startup. Not rules, does not change the agent's behavior.
  - `OBSERVATIONS.md` — raw buffer. `STATUS.md` — open points of the system itself.
- **One folder per session**, and a session's state = where its folder is: `sessions/open/<id>/` → `sessions/closed/<id>/` → `sessions/sealed/<id>/`. Each change of state is a move (`mv`, atomic). During its session, an agent only writes in **its own folder**: `SESSION.md` (header, log, closing sections), its drafts, its `inbox/`.
- **Shared files: written only under lock** (`.lock/`, atomic `mkdir`, a single winner) — by the automatic merge (`tools/consolidate.sh`) or by a rewrite by hand (§3, last block).
- **Projects**: concrete work lives in a numbered folder at the root, `NN_ProjectName/` — one per project, with its `AGENTS.md` (context, pointer to its `CHANGELOG.md`) and a one-line `CLAUDE.md`, `@AGENTS.md`. Deliverables go there, never in the session folder.
- **Nothing is ever deleted**, only moved (`_archive/`, `sessions/sealed/`).
- **Privacy**: everything stays local, in a **private** git repository. No secret (API key, password, token) in any file of this folder. Other people's data (names, health, family or legal situation): the bare minimum, never in the observations.
- **Tools** (`tools/`, bash 3.2+ — on Windows, the Git Bash of Git for Windows): `session.sh` (ritual), `consolidate.sh` (merge), `install.sh` (first startup), `hooks/pre-commit` (declared projects), `tests.sh` (to run again after any change to `tools/` — never a commit that breaks them). What depends on the OS is isolated in `tools/os/<linux|macos|windows>.sh`. The scripts only do mechanical steps; everything that takes judgment stays with the agent.
- `protocols/`: rare procedures, never loaded by default, read only when their condition triggers (pointers below).

## 1. Startup — from the first message of the session, whatever it is

Not only on « hello »: a session opened directly on a command must also run this ritual, before handling the request.

1. Read this file in full.
   **No `.continuum/installed` file** (first use on this machine) → `protocols/installation.md` first, without asking anything: it is technical, the user only has to read the one-line result.
2. Open your session, first thing: `bash tools/session.sh open <harness> [model]` from the root of this folder (Windows, agent whose shell is PowerShell or cmd: `.\continuum.cmd open <harness> [model]`, same for every `session.sh` command). The script closes the folders whose agent is **dead** (and those of its own previous conversation), creates `sessions/open/<id>/`, and shows the status: open sessions (alive / uncertain), active agents without a session folder, sessions waiting for merge, lock, and two possible signals — **unconsolidated observations** past the threshold (20 by default, `CONTINUUM_OBS_THRESHOLD`), **harness updated** after it was launched. Plus, from the 2nd session until `TIPS.md` runs out, **the tip of the day**.
   A **sub-agent** never runs this ritual: it works in its parent's folder.
3. Tell the user what the status shows, in one or two lines: other active sessions, **uncertain** sessions and agents **without a folder** (decide nothing alone: `protocols/orphans.md`), the signals above. The tip of the day: one line, as is, in the user's language.
4. Read `BASE.md`, `PROFILE.md`, `TRAITS.md`, `DIRECTIVES.md` **Active** section (applied for the whole session), and the `## For BASE` section of each folder in `sessions/closed/`.
5. Look at your folder's `inbox/`.
6. **`PROFILE.md` §Who still empty** (and not marked « interview declined ») → `protocols/first-session.md`, before anything else.
   Otherwise: sum up where things stand in 2-3 lines (`BASE.md`), plus **« Learned since your last session »**: each entry of `DIRECTIVES.md`, `TRAITS.md`, `PROFILE.md` marked `not announced`, one line each (what, where it comes from), then those markers switched to `announced YYYY-MM-DD` (under lock, commit); plus **at most one** guidance reminder if its condition is met (§4). Then handle the request, or wait — no menu.

## 2. During the session

- **Log on a clear trigger**: an entry in `SESSION.md` at each commit and each finished request — neither « as you go » (never kept up in practice), nor rebuilt from memory at close. Always by appending at the end of the file, never read-then-rewrite. In passing: look at your `inbox/`.
- **Projects**: as soon as you touch an `NN_ProjectName/`, declare it: `bash tools/session.sh work NN_ProjectName`. The pre-commit hook then refuses a commit on that project by another live agent. Another live agent has already declared the same project → say so before touching it.
- **Commits**: always on precise paths (`git add <paths> && git commit -- <paths>`), never `git add -A`/`.` nor `commit -a` — that would carry along the other agents' work in progress. Pitfall: a file deleted or renamed by `git rm`/`git mv` can no longer be passed to `git add` (« did not match any files » error), only to the commit's pathspec. Conversely with `git rm --cached` (file left on disk): the commit's pathspec takes the disk again and cancels the removal — commit from the index, after checking `git diff --cached --name-only`.
- **Incidents and feedback, noted on the spot** — that is what feeds the learning. Each time the user **corrects, takes over, asks for a check again** (« are you sure? », a short checking question), **refuses**, or says « no / rather / actually / I prefer » → a log line with **their exact words**, what the agent had just done, what they wanted instead. Same for a clear success (validated first time, praised). What it **is not**: an event (« project created », « tests OK » → ordinary log and `## For BASE`), a psychological portrait, what the agent did. Why: tested on real sessions, « what happened / how do they behave » gave a narrative and a single rule; incidents gave about twenty actionable lessons.
  Tags: `[incident]`, `[success]`, `[gap]`, `[lesson]`, `[fact]` (said by the user about themselves); plus `[AI]` when it is the agent's interpretation without a quote — never promoted on its own, a safeguard.
  Format: `**[YYYY-MM-DD HH:MM]** [type] — text`.
- **Language**: speak to the user in the language stated in `PROFILE.md` §Who; until it is stated, in the language of their first message.
- **Effect**: when an **Active** directive changed what the agent would have done without it, note `[effect] <directive name>` in the log — one line. Without that trace, there is no way to know whether the system is any use.
- **Fast track**: an explicit instruction from the user about the agent's behavior (« from now on… », « never again… », « remember that… ») applies **right away** — say so in one line (« noted, I'll stick to it from now on »); at close, it goes into `## Learned`.
- **Objection**: the user says something learned bothers them (« remove that », « that bothers me », « no » to an announced addition) → removed at once, no discussion (`protocols/learning.md` step 9).
- **Nothing is « kept in mind »**: the conversation context disappears at the end of the session. What must survive is written down immediately.

## 2bis. Code guidelines (always active, as soon as the session touches code)

- Before implementing: state the assumptions, present the possible interpretations rather than choosing silently, point out a simpler approach if there is one, stop and ask if something is unclear.
- Minimum code that solves the problem: no feature that wasn't asked for, no abstraction for single-use code, no error handling for impossible scenarios.
- Surgical changes: touch only what is necessary, don't « improve » the adjacent code, point out dead code you spot without deleting it.
- Define a verifiable success criterion before looping on it (a test that reproduces the bug then passes, tests before/after a refactor…).

## 3. Closing (« close », « let's wrap up », « we're done »)

1. Reread your log and fill in, **at the end of `SESSION.md`**, the useful sections (exact titles; a missing section = nothing to pass on; a title present twice — close rewritten after resuming — only the last one counts):
   - `## For BASE` — what was done, what remains open. **5 lines max.** → `BASE.md` §History.
   - `## Durable facts` — a decision or fact that must survive the History rotation. 3 lines max. → `BASE.md` §Decided.
   - `## Feedback` — one line per item, `**[YYYY-MM-DD HH:MM]** [type] — …` (→ end of `OBSERVATIONS.md`), answering:
     1. **Gap** `[gap]` — what did the user expect (the session's goal, the important requests), what was delivered, where it diverged and why (the cause, not a culprit);
     2. **Incidents** `[incident]` — each correction, takeover, re-check, refusal: exact quote + time, what the agent had just done, what they wanted instead (taken from the log);
     3. **Successes** `[success]` — validated first time or praised, and which choice of the agent worked;
     4. **Lessons** `[lesson]` — for each significant incident or success: « When <situation a future agent can recognize>, do <concrete action> » + evidence (quote, time). Only what would change a future agent's behavior. A lesson specific to a project goes into the project's `CHANGELOG.md`;
     5. **Stated facts** `[fact]` — what the user said about themselves (→ `PROFILE.md` through the loop).
     No events or narrative: they go into `## For BASE`. Method: After Action Review, critical incidents (Flanagan, 1954), trigger → action lessons (ERL/ExpeL work on agents that learn from experience).
   - `## STATUS +` — new open points of the **system**, one table line each: `| point | open since | state |`. A project's points go into its `CHANGELOG.md`.
   - `## Learned` — fast track (§2): the rule + its **Basis** (quote or context, 2-3 lines) + `[auto YYYY-MM-DD — announced YYYY-MM-DD]` (already said during the session). → `DIRECTIVES.md` §Active › Learned (automatic), active as soon as it is merged.
2. **Show the user, in 2-3 lines, what goes into memory**: observations noted, rules learned, `[effect]` seen. No black box.
3. `bash tools/session.sh close`: writes `end:`, moves the folder to `closed/`, then runs the merge (`tools/consolidate.sh`, under lock), which handles **all** the folders of `closed/`: copies the sections above into the shared files (no `## For BASE`: no entry, except a folder closed after the fact, orphan → « Closed without summary »), `BASE.md` caps (§History 5 entries, §Decided 5; surplus → `_archive/`, verbatim), move to `sealed/`, commit on those paths only. Lock busy → nothing to do, the next merge will take everything.
   **If `close` shows « Unconsolidated observations: N »** (threshold reached): run the learning loop right away (`protocols/learning.md`), without asking — it is automatic. A harness that can delegate (sub-agent): hand it over. Its additions are active at once; tell the user in a few lines if they are still there, otherwise they will be announced at the next opening.
4. **Resuming after close** (the user speaks again without having closed the agent): always `open` before answering, never write again in the closed folder. The script recognizes the same process and marks the new session `follows: <id>`. **After a reboot of the machine** (Linux, agents launched in herdr, which resumes conversations): the process is new, it is the **conversation identifier** (`conversation:` in the header) that makes the link — a conversation that had not been closed finds its own folder again (`open` shows « Session resumed »), a conversation closed normally then resumed opens a new session with `follows`; a folder closed by a real close is never reopened (`protocols/orphans.md`). At the new close, `## For BASE` only if the follow-up changed something.

**Rewrites by hand** (any time, any agent, never without the lock): `bash tools/session.sh lock take` → edit → commit the modified files, on their paths only → `bash tools/session.sh lock release`. Lock busy → try again later; it expires on its own (15 min), `lock take` again renews it. Applies to: removing something learned on objection; marking `announced`; updating `PROFILE.md` (a stated fact, once is enough) or `TRAITS.md`; correcting `STATUS.md`; the learning loop (`protocols/learning.md`).

## 4. Guidance — learning the system by using it

Goal: the user ends up knowing Continuum **without having read the documentation**. Each gesture is shown to them when it is useful, then not mentioned again.

**The gestures to know** — never presented all at once: each one is shown, in one line, the first time it is useful (« close » at the end of the first session, « remove that » at the first announced learning, etc.):

| The user says | What happens |
|---|---|
| « close » | end of session: what was learned goes into memory |
| « remove that », « that bothers me » | the announced learning is removed, and won't come back |
| « from now on… » | rule proposed right away (fast track) |
| « run the learning » | the agent rereads the observations and proposes rules (`protocols/learning.md`) |
| « what have you learned? » | a summary in three levels (below) |
| « why are you doing that? » | the agent quotes the directive that guided it |

**Reminders**: at most **one** per session, in one line, never as a menu, and only when its condition is met:
- first announced learning → explain that it already applies, and that they only have to say if it bothers them;
- long session whose topic is over → remind them that closing then starting again costs less and loses nothing.

**Scaffolding that fades**: as soon as the user uses a gesture on their own, add it to `PROFILE.md` §Continuum (« known gestures ») — no more reminders about it. « No reminders » → none at all (noted in `PROFILE.md`).

**« What have you learned? »** — a summary in three levels, figures taken from the files, never from memory:
1. *Recorded*: number of observations, of which unconsolidated; recent themes.
2. *Deduced*: directives and traits learned (with their date), revisions.
3. *Applied*: Active directives; recent `[effect]` (`sessions/sealed/`); directives that never had any effect.

**Level**: adapt the explanation to what the user said about themselves in `PROFILE.md` — no jargon without a sentence of explanation until they have shown they know it.
