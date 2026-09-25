# Protocol — Orphan sessions and agents without a folder

> Not loaded by default. Looked at when the status shown by `tools/session.sh open|status` (`AGENTS.md` §1) shows an **uncertain** session or an **active agent without a session folder**.

An orphan session = a folder left in `sessions/open/` without a close: agent crashed, terminal closed, conversation replaced (`/clear`, `/new`) without going through the ritual again.

## Detection

The `SESSION.md` header carries the agent's fingerprint: `machine boot_id pid starttime`. The verdict depends on no agent in particular:

- **same machine**: alive if the process exists, with the same start time, and is not a zombie; otherwise **dead, certainly** (process gone, PID reused, machine rebooted);
- **other machine**: **uncertain**.

## Action for each case

- **Certainly dead** → closed automatically by `session.sh open` (note « Closed after the fact… — harness dead », moved to `closed/`). The next merge turns it into a `BASE.md` entry « Closed without summary — raw log: `sessions/sealed/<id>/` »: nothing is invented beyond what is written. No decision to make.
- **Dead by fingerprint but conversation still running** → **not dead**: the machine rebooted and herdr relaunched the conversation (`--resume`) in a new process, so the fingerprint no longer matches. The exact link is the **conversation identifier** (`conversation:` in the header, the `agent_session` herdr keeps per pane — `herdr agent get <pane>`): a live agent, working directory here, carrying that same identifier → the folder is **attached** to it (fingerprint updated, a `> Resumed on …` line), and **reopened** if it had been closed after the fact « harness dead » (only the last `## End` section counts). Same pane but another identifier (new agent, `/clear`) → another conversation: normal « harness dead » close, no `follows`. If it is the resumed conversation itself that runs the ritual, it keeps its folder (« Session resumed »). A folder closed by a real close is never reopened: the resumed conversation opens a new session with `follows`. Tests: `T20` (`tools/tests.sh`).
- **My own fingerprint** (previous conversation of the same process) → same treatment, automatic.
- **Uncertain** → touch nothing. Tell the user (since when, last activity = modification date of `SESSION.md`) and wait for their confirmation. If they confirm it is over: add at the end of `SESSION.md` « Closed after the fact on … — confirmed over by the user », then `## End` / `end: …`, and move it to `closed/` by hand.
- **Active agent without a session folder** (known agent whose working directory is here, but which has never run the ritual) → report it: it is invisible to the others and may respect neither the lock nor the project declarations. Do nothing in its place.
- Two agents closing the same orphan at the same time: the second move fails (folder already gone), nothing else happens.

## Known limits

- An agent launched **outside** this folder that writes into it by absolute path stays invisible.
- The list of recognized agents (`KNOWN_HARNESSES` in `tools/session.sh`, can be overridden by `CONTINUUM_HARNESSES`) must keep up with new tools.
- Recognizing a conversation resumed after a reboot requires **Linux** and herdr with the agent's integration installed (`herdr integration status` — it is what reports the identifier). Without herdr (tmux alone, bare terminal), without integration, or on macOS/Windows: no identifier, previous behavior (automatic « harness dead » close). The pane alone is not enough: it cannot tell a resumed conversation from a new one in the same pane.
