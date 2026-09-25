# Protocol — Import from an external source

> Not loaded by default. Looked at when the user wants to bring content here from another system: memory exported from an AI assistant, notes, an older memory system, a profile written elsewhere. Often offered at the first session (`protocols/first-session.md`).

## Two failures to avoid

- **Copying too much**: duplicating a large source breaks the brevity of the files reread at every startup, and creates a second truth that will silently diverge.
- **Not tracing enough**: condensing without saying where it comes from makes the information unverifiable — a Basis that can no longer be traced is only a claim.

## Before any copy: read it all

Read the source **in full** before copying anything — never on the strength of a keyword search (`grep` for « password », « token »…). A pattern search only finds the secrets that have the expected shape, and none of the **other people's data** (names, health, family or legal situation, private quotes), which often hide in concrete examples that look relevant. If only part of the source is useful, build an extract reduced to that part directly.

## The four layers

1. **Condensed, self-sufficient substance** — each imported element (fact, trait, rule) is rewritten in the format used here (statement + 2-3 line Basis) and must stay understandable **without reopening the source**.
2. **Local copy + origin noted** — the summary files actually cited are copied into `_sources/<source-name>/`, with their original path or location and the date. Nothing here must break if the source is moved or deleted. `_sources/README.md` keeps the inventory (file, origin, date, role).
3. **The distilled, never the raw** — raw logs, conversation histories, logs are not copied: only what the source has already summarized.
4. **A snapshot, not a sync** — an import is dated. If the source changes afterwards, that is a normal gap, noted in `STATUS.md`; a new import is added, it never silently rewrites the old one.

## What goes where

| Imported content | Destination | Status |
|---|---|---|
| Stated facts (who, job, tools, goals) | `PROFILE.md` | direct, if the user confirms them |
| Behavioral traits already cross-checked by the source | `TRAITS.md`, sub-section « Imported from <source> » | to be confirmed by use here (revisable) |
| Behavior rules for the AI | `DIRECTIVES.md` §Active › Learned (automatic), marked `[auto … — not announced]` | active at once, announced; the user removes what bothers them |

Writes under lock (`AGENTS.md` §3). Log: note the import (source, date, what was kept, what was dropped and why).
