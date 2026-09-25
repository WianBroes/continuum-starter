# Protocol — Installation (first startup on a machine)

> Trigger (`AGENTS.md` §1.1): no `.continuum/installed` file at the root. Once per machine: this file is not versioned, a folder synced between two machines is installed on each. The agent does it alone, without asking: it is technical, and reversible.

1. **Run the installer** from the root of this folder:
   - Linux, macOS, and Windows when the agent's shell is bash (Claude Code on Windows uses Git Bash): `bash tools/install.sh`
   - Windows, agent whose shell is PowerShell: **never plain `bash`** (on Windows, it may be WSL's bash, another system). Go through the Git Bash of Git for Windows:
     `& (Join-Path (Resolve-Path "$(git --exec-path)/../../..") 'bin\bash.exe') tools/install.sh`

   The installer detects the OS and loads its layer (`tools/os/<os>.sh`), checks the dependencies, makes this folder the root of its own local git repository if it is not already (the English template ships as the `en/` folder of the continuum-starter repository: the user's memory must never be committed there), creates a git identity for the repository if none exists, enables the projects hook, removes the link to the online template if there is one (`origin` of a `git clone` pointing to a continuum-starter repository — a link to another repository is kept), creates `continuum.cmd` on Windows (entry point for agents under PowerShell/cmd), runs the test suite, then writes `.continuum/installed`.

2. **Depending on the result**:
   - « Installation validated » → tell the user **one line** (« Continuum is installed on this machine (macOS), everything works ») and resume the startup (`AGENTS.md` §1.2).
   - « Missing: … » → say in one sentence what to install, without jargon:
     - Windows: Git for Windows (git-scm.com — it brings Git Bash);
     - macOS: `xcode-select --install` (git and the basic tools);
     - Linux: the package of the missing command (often `procps`).
     Then run the installer again.
   - « unsupported OS » (neither Linux, nor macOS, nor Windows) → say so; Continuum cannot guarantee work by several agents on this machine. Don't hack together an OS layer without the user's agreement.
   - Failing tests (« Installation NOT validated ») → show the `KO` lines, don't run several agents at the same time on this machine, and note the problem for `## STATUS +` at close (OS, version, KO lines — `.continuum/tests.log`).

3. Log: an entry « installation on <machine> (<os>): validated / failed ».

## Known limits per OS

- **Windows**: two processes appending at the same time to the end of the **same** file can interleave their lines (no consequence: each agent only writes in its own log, the shared files go through the lock). Detection of active agents **without a session folder** is not available (another process's working directory cannot be read without a third-party tool) — so each agent must run the ritual. The calls to PowerShell make `session.sh` slower (a few seconds).
- **macOS**: process start time to the second (`ps`); enough to tell one process from another.
- **Linux only**: recognizing a conversation resumed after a reboot (herdr) — `protocols/orphans.md`.
- **All**: an agent launched outside this folder, which writes into it by absolute path, stays invisible (`protocols/orphans.md`).
