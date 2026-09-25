# Continuum — blank template

A memory for your AI assistant, in plain text files, that **learns from you** and becomes what you want it to do for you.

- It notices how you work: what you correct, what you repeat, what annoys you.
- When a pattern comes back over several sessions, it **draws a rule from it and sticks to it**, on its own, and tells you each time what it has learned. If something bothers you, you say so and it's removed.
- It starts empty: no rule imposed. At each startup, a tip about using AI and its pitfalls (`TIPS.md`), until the system is broken in.
- Everything is readable and editable by you, at any time. Everything stays on your machine.
- Several agents can work in it **at the same time** (several terminals, different tools) without stepping on each other.

## You need

- **A command-line AI agent**: Claude Code, Codex, Gemini CLI, pi, opencode… any one that reads `AGENTS.md` (or `CLAUDE.md`) and can run commands.
- **git**: on Windows, install [Git for Windows](https://git-scm.com), which also brings Git Bash, needed by Continuum; on macOS, run `xcode-select --install`; on Linux, it's usually already there.

## Getting started

1. Copy this `en/` folder wherever you like (you can rename it).
2. Open your AI agent **in that folder**.
3. Say hello.

The first time, the agent installs Continuum for your system (Linux, macOS or Windows) and checks that everything works. You have nothing to do, it gives you the result in one line. It turns the folder into its own private git repository, separate from the template it came from: nothing of yours can go back there. Then it introduces itself, tells you a few AI pitfalls, and asks you a few questions to tick (your language, your name, your age, your use of AI, what you expect from it); each one can be skipped, or answered your own way. One of them proposes a first rule: no flattery.

That's all. No need to read further: the agent will teach you the gestures when they're useful.

## The six gestures

| You say | What happens |
|---|---|
| « close » | end of session: what was learned goes into memory |
| « remove that », « that bothers me » | what it learned is removed, and won't come back |
| « from now on… » | rule proposed right away |
| « run the learning » | the agent rereads its observations right away (otherwise, it does it on its own from time to time) |
| « what have you learned? » | summary: what's noted, what's deduced, what's applied |
| « why are you doing that? » | the agent quotes the rule that guided it |

## How it learns

```
you work ──► OBSERVATIONS.md   what was noticed (raw)
                  │  same pattern over 3 different sessions
                  ▼
              Learned          rule deduced, applied right away (DIRECTIVES.md)
                  │  it tells you
                  ▼
              you              « that bothers me » → removed, and doesn't come back
```

There are three levels, always kept apart: at any time you can see what it has noted, what it draws from it and what it applies. What you state yourself (who you are, your goals) goes into `PROFILE.md`. What it cross-checks about the way you work goes into `TRAITS.md`.

At the start, `DIRECTIVES.md` is empty: every rule comes from you, because you asked for it or because it cross-checked it on the way you work.

## The files

| File | Content |
|---|---|
| `AGENTS.md` | the system's rules, read by the agent at every startup |
| `PROFILE.md` | what you've said about yourself |
| `TRAITS.md` | what it has cross-checked about the way you work |
| `DIRECTIVES.md` | how it behaves: learned rules |
| `TIPS.md` | the startup tips (gestures, AI pitfalls) |
| `OBSERVATIONS.md` | its raw notes |
| `BASE.md` | memory of recent sessions and decisions |
| `sessions/` | one trace per session |
| `NN_ProjectName/` | your projects (one numbered folder per project) |
| `protocols/` | rare procedures, read by the agent when it needs them |
| `tools/` | ritual scripts; `tools/os/` holds what changes from one system to another |

## Several agents at the same time

That's what makes Continuum. Each agent opens its own session, a folder in `sessions/`, and only writes there. The shared memory is only written under a lock, one agent at a time, and it's merged automatically at every close. A crashed agent is detected and its session is closed. And a project declared by one agent is protected against the others' commits.

The scripts (`tools/`, in bash) work on Linux, macOS and Windows (through Git Bash). They're installed and tested automatically at the first startup on each machine (`tools/install.sh`).

## Privacy

- Nothing leaves your machine, apart from what your AI agent sends to its provider during the conversation.
- Never write a password or a key in these files.
- Avoid putting information about other people in them.
- Keep the repository private.
