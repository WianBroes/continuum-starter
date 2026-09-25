#!/usr/bin/env bash
# Tests of the Continuum ritual. Never touches the vault: throwaway copy in a
# temporary folder, agents simulated by fake harnesses (sleep) through CONTINUUM_PID.
#   tools/tests.sh            runs everything, prints OK/KO, exit code = number of failures
set -uo pipefail
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
V=$(cd "$(mktemp -d)" && pwd -P)/vault
# Copy of the files git tracks in this folder (not a clone: this folder may still be a sub-folder of
# the template's repository), with tools/ as it is on disk — the tests check the current scripts.
mkdir -p "$V"
( cd "$SRC" && git ls-files -z | tar --null -T - -cf - 2>/dev/null ) | ( cd "$V" && tar -xf - )
rm -rf "$V/tools" && cp -R "$SRC/tools" "$V/tools"
rm -rf "$V"/sessions/open/*/ "$V"/sessions/closed/*/
git -C "$V" init -q && git -C "$V" config user.name test && git -C "$V" config user.email test@local
# Fixtures: the template is blank (no project, empty History) — create something to test.
mkdir -p "$V/01_Example" "$V/02_Other"; echo "# Example" > "$V/01_Example/CLAUDE.md"; echo "# Other" > "$V/02_Other/CLAUDE.md"
printf '\n**[2020-01-01 00:00–00:01] fixture** — TOKEN-FIXTURE, oldest entry.\n' >> "$V/BASE.md"
git -C "$V" add -A && git -C "$V" commit -q --no-verify -m fixtures
unset HERDR_PANE_ID TMUX_PANE
export CONTINUUM_LOCK_WAIT=30
S=$V/sessions
ok=0; ko=0
# without pipefail: `… | grep -q` closes the pipe early, SIGPIPE upstream would fail a passing test
# check <label> <condition> [diagnostic]: the diagnostic (command) is only shown on failure — raw facts for CI
check() { if (set +o pipefail; eval "$2"); then ok=$((ok+1)); echo "  OK  $1"; else ko=$((ko+1)); echo "  KO  $1   [$2]"; [ -z "${3:-}" ] || eval "$3" 2>&1 | sed 's/^/        | /'; fi; }
. "$V/tools/lib.sh"   # OS layer of the copy: starttime, mtime, age_file, CWD_SUPPORTED…
echo "OS: $CONTINUUM_OS"
# Fake live harness (detached). On Windows, harnesses are native processes: we return the
# Windows PID of the sleep, once the exec is done (before that, /proc/<pid>/winpid is the forked bash's).
if [ "$CONTINUUM_OS" = windows ]; then
  windows_pid() { local i; for i in $(seq 50); do case $(cat "/proc/$1/exename" 2>/dev/null) in *sleep*|*fakeharness*) break ;; esac; sleep 0.1; done; cat "/proc/$1/winpid"; }
  harness() { sleep 3600 >/dev/null 2>&1 & windows_pid $!; }
  kill_pids() { local p; for p in "$@"; do taskkill //F //PID "$p" >/dev/null 2>&1; done; }
else
  harness() { sleep 3600 >/dev/null 2>&1 & echo $!; }
  kill_pids() { kill "$@" 2>/dev/null; }
fi
kill_wait() { kill_pids "$@"; local p i; for p in "$@"; do for i in $(seq 50); do [ -n "$(starttime "$p")" ] || break; sleep 0.1; done; done; }
skip() { echo "  --  $1 (not supported on $CONTINUUM_OS)"; }
agent() { local p=$1; shift; CONTINUUM_PID=$p bash "$V/tools/session.sh" "$@"; }
folder() { CONTINUUM_PID=$1 bash "$V/tools/session.sh" me; }
nb() { find "$S/$1" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '; }   # BSD wc: leading spaces
count() { grep -c -- "$1" "$2" 2>/dev/null || true; }
PIDS=()
trap 'kill_pids "${PIDS[@]}"; rm -rf "$(dirname "$V")"' EXIT

echo "T1 — two simultaneous openings"
A=$(harness); B=$(harness); PIDS+=("$A" "$B")
agent "$A" open claude >/dev/null & agent "$B" open pi >/dev/null & wait
check "2 folders in open/" '[ "$(nb open)" = 2 ]'
check "B sees A alive" 'agent "$B" status | grep -q "claude-p$A.*alive"'
check "no leftover creation folder" '[ -z "$(ls -A "$S" | grep "^\.creating")" ]'

echo "T2 — dead orphan closed automatically"
IDA=$(folder "$A"); kill_wait "$A"
C=$(harness); PIDS+=("$C")
out=$(agent "$C" open claude); grep -q "closed (orphan): $IDA" <<< "$out"; r=$?
check "C announces closing A" '[ $r = 0 ]'
check "A is in closed/ with the note" 'grep -q "harness dead" "$S/closed/$IDA/SESSION.md"'
check "B (alive) was not touched" '[ -d "$S/open/$(folder "$B")" ]'

echo "T7 — same process, new conversation (/clear, /new)"
IDB=$(folder "$B")   # same minute: the id gets a -2 suffix
agent "$B" open pi >/dev/null
check "B's previous conversation closed" 'grep -q "same process" "$S/closed/$IDB/SESSION.md"'
check "B has a new open folder" '[ -n "$(folder "$B")" ] && [ "$(folder "$B")" != "$IDB" ]'

echo "T3 — 12 simultaneous closes + merge"
kill_wait "$B" "$C"
before=$(sed -n '/^## History/,$p' "$V/BASE.md" | grep '^\*\*\[' | sort | head -1)   # oldest existing entry (start date)
N=12; AG=()
for i in $(seq 1 $N); do p=$(harness); PIDS+=("$p"); AG+=("$p"); agent "$p" open claude >/dev/null; done
for i in $(seq 1 $N); do
  f=$S/open/$(folder "${AG[$((i-1))]}")/SESSION.md
  echo "- log entry $i" >> "$f"
  printf '\n## For BASE\n\nTOKEN-BASE-%s did this.\nOn two lines.\n\n## Feedback\n\n**[t]** [incident] — TOKEN-OBS-%s\n\n## STATUS +\n\n| TOKEN-STATUS-%s | 2026-09-23 | open |\n' $i $i $i >> "$f"
  [ $i -le 7 ] && printf '\n## Durable facts\n\nTOKEN-FACT-%s\n' $i >> "$f"
  [ $i = 1 ] && printf '\n## Learned\n\n**TOKEN-LEARNED-1** — test learned directive.\n' >> "$f"
done
for p in "${AG[@]}"; do agent "$p" close >/dev/null 2>&1 & done; wait
CONTINUUM_PID=$$ bash "$V/tools/consolidate.sh" >/dev/null   # catches any leftover
check "open/ and closed/ empty" '[ "$(nb open)" = 0 ] && [ "$(nb closed)" = 0 ]'
all=$(cat "$V/BASE.md" "$V"/_archive/*.md)
for i in $(seq 1 $N); do
  [ "$(grep -c "TOKEN-BASE-$i " <<< "$all")" = 1 ] || { echo "    TOKEN-BASE-$i: $(grep -c "TOKEN-BASE-$i " <<< "$all")"; missing=1; }
done
check "each BASE entry exactly once (BASE + archive)" '[ -z "${missing:-}" ]'
check "History capped at 5" '[ "$(sed -n "/^## History/,\$p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'
check "Decided capped at 5" '[ "$(sed -n "/^## Decided/,/^## History/p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'
check "« empty » placeholder removed from Decided" '! grep -q "first close to come" "$V/BASE.md"'
check "old entry archived verbatim" 'grep -qxF -- "$before" <(cat "$V"/_archive/*.md)'
check "A's orphan entry present" '[ "$(grep -c "$IDA\*\* — Closed without summary" <<< "$all")" = 1 ]'
ob=0; st=0; for i in $(seq 1 $N); do [ "$(count "TOKEN-OBS-$i\$" "$V/OBSERVATIONS.md")" = 1 ] || ob=1; [ "$(count "TOKEN-STATUS-$i " "$V/STATUS.md")" = 1 ] || st=1; done
check "observations: each exactly once" '[ $ob = 0 ]'
check "STATUS: each line exactly once" '[ $st = 0 ]'
check "learned directive inserted in §Active › Learned (automatic)" 'awk "/^### Learned \(automatic\)/{p=1;next} p&&/^##/{exit} p&&/TOKEN-LEARNED-1/{f=1} END{exit !f}" "$V/DIRECTIVES.md"'
check "no « end: » line copied into BASE, DIRECTIVES or the archive" '! grep -q "^end: " "$V/BASE.md" "$V/DIRECTIVES.md" "$V"/_archive/*.md'
check "sealed/ holds the 12 + A + B's 2 conversations" '[ "$(nb sealed)" -ge 15 ]'
check "lock released" '[ ! -d "$V/.lock" ]'
check "shared files committed" '[ -z "$(git -C "$V" status --porcelain -- BASE.md OBSERVATIONS.md STATUS.md DIRECTIVES.md _archive sessions/sealed sessions/closed)" ]'
check "at least one « Merge » commit" 'git -C "$V" log --oneline | grep -q "Merge:"'

echo "T4 — abandoned, expired, held locks"
fake_take() { mkdir "$V/.lock"; printf 'fingerprint: %s\nexpires: %s\nlabel: test\n' "$1" "$2" > "$V/.lock/owner"; }
future=$(( $(date +%s) + 600 )); past=$(( $(date +%s) - 10 ))
m=$(harness); dead_fp=$(CONTINUUM_PID=$m bash -c ". $V/tools/lib.sh; fingerprint $m"); kill_wait "$m"
fake_take "$dead_fp" "$future"
check "dead holder → lock broken, merge done" 'CONTINUUM_PID=$$ bash "$V/tools/consolidate.sh" | grep -q "Nothing to merge"'
check "break logged in locks.log" 'grep -q "broken by" "$S/locks.log"'
fake_take "other-machine x 1 1" "$future"
check "other machine not expired → busy" 'CONTINUUM_LOCK_WAIT=2 bash "$V/tools/consolidate.sh" | grep -q "Lock busy"'
rm -rf "$V/.lock"; fake_take "other-machine x 1 1" "$past"
check "other machine expired → broken" 'bash "$V/tools/consolidate.sh" | grep -q "Nothing to merge"'
v=$(harness); PIDS+=("$v"); agent "$v" lock take >/dev/null
check "held by a live process → busy" 'CONTINUUM_LOCK_WAIT=2 bash "$V/tools/consolidate.sh" | grep -q "Lock busy"'
check "only the holder can release" '! agent "$$" lock release 2>/dev/null && agent "$v" lock release | grep -q released'
for i in $(seq 1 8); do CONTINUUM_PID=$$ bash "$V/tools/consolidate.sh" >/dev/null & done; wait
check "8 concurrent merges → no leftover lock" '[ ! -d "$V/.lock" ]'

echo "T6 — pre-commit hook on a declared project"
git -C "$V" config core.hooksPath tools/hooks
D=$(harness); E=$(harness); PIDS+=("$D" "$E")
agent "$D" open claude >/dev/null; agent "$E" open pi >/dev/null
agent "$D" work 01_Example
echo test >> "$V/01_Example/CLAUDE.md"; git -C "$V" add 01_Example/CLAUDE.md
check "E refused on 01_Example declared by D" '! CONTINUUM_PID=$E git -C "$V" commit -q -m e 2>/dev/null'
check "D allowed on its own project" 'CONTINUUM_PID=$D git -C "$V" commit -q -m d'
echo test2 >> "$V/01_Example/CLAUDE.md"; git -C "$V" add 01_Example/CLAUDE.md
check "E allowed with --no-verify" 'CONTINUUM_PID=$E git -C "$V" commit -q --no-verify -m e2'
echo test3 >> "$V/01_Example/CLAUDE.md"; git -C "$V" add 01_Example/CLAUDE.md; kill_wait "$D"
check "D dead → E allowed" 'CONTINUUM_PID=$E git -C "$V" commit -q -m e3'
echo test4 >> "$V/02_Other/CLAUDE.md"; git -C "$V" add 02_Other/CLAUDE.md
check "undeclared project → allowed" 'CONTINUUM_PID=$E git -C "$V" commit -q -m e4'

echo "T9 — active agent without a session folder (ritual never run)"
if [ "$CWD_SUPPORTED" != 1 ]; then skip "another process's working directory unreadable"; else
export CONTINUUM_HARNESSES=sleep
F=$(cd "$V/01_Example" && harness); G=$(cd "$V" && harness); H=$(cd /tmp && harness); PIDS+=("$F" "$G" "$H")
agent "$G" open claude >/dev/null
out=$(agent "$G" status)
check "F (in the vault, no folder) reported" 'grep -q "pid $F " <<< "$out"'
check "G (in the vault, with folder) not reported" '! grep -q "pid $G " <<< "$out"'
check "H (outside the vault) ignored" '! grep -q "pid $H " <<< "$out"'
(cd "$V" && CONTINUUM_PID=$G bash tools/session.sh close >/dev/null)
out=$(agent "$F" status)
check "G closed but harness still open: not reported as « without a folder »" '! sed -n "/WITHOUT a session/,/^[^ ]/p" <<< "$out" | grep -q "pid $G "'
check "G listed as a harness still open after closing" 'grep -q "pid $G .*closed" <<< "$out"'
unset CONTINUUM_HARNESSES
fi

echo "T10 — date format of a BASE entry (same day → time only)"
check "entry « [YYYY-MM-DD HH:MM–HH:MM] id »" 'grep -qE "^\*\*\[[0-9-]{10} [0-9:]{5}–[0-9:]{5}\] " "$V/BASE.md"'

echo "T11 — resuming after close (follows)"
K=$(harness); PIDS+=("$K")
agent "$K" open claude >/dev/null; K1=$(folder "$K")
printf '\n## For BASE\n\nTOKEN-K1 real work.\n' >> "$S/open/$K1/SESSION.md"; agent "$K" close >/dev/null
agent "$K" open claude >/dev/null; K2=$(folder "$K")
check "resumed session marked follows the closed one" 'grep -qx "follows: $K1" "$S/open/$K2/SESSION.md"'
echo "- btw: a question, nothing else" >> "$S/open/$K2/SESSION.md"; agent "$K" close >/dev/null
check "follow-up without « For BASE » → no BASE entry" '! grep -q "\] $K2\*\*" "$V/BASE.md" "$V"/_archive/*.md'
check "follow-up log kept in sealed/" 'grep -q "btw" "$S/sealed/$K2/SESSION.md"'
agent "$K" open claude >/dev/null; K3=$(folder "$K")
printf '\n## For BASE\n\nTOKEN-K3 correction of the close.\n' >> "$S/open/$K3/SESSION.md"; agent "$K" close >/dev/null
check "follow-up with « For BASE » → « (follows … ) » entry" 'grep -q "\] $K3\*\* — (follows $K2) TOKEN-K3" "$V/BASE.md"'
agent "$K" open claude >/dev/null; K4=$(folder "$K"); kill_wait "$K"
L=$(harness); PIDS+=("$L"); agent "$L" open claude >/dev/null; agent "$L" close >/dev/null
check "orphan follow-up (pane closed without re-closing) → no BASE entry" '! grep -q "\] $K4\*\*" "$V/BASE.md" "$V"/_archive/*.md && [ -d "$S/sealed/$K4" ]'
check "first session (not a follow-up) → no follows" '! grep -q "^follows: ." "$S/sealed/$K1/SESSION.md"'

echo "T12 — cap by start date, not by position; « last purge » note kept by the merge"
printf '\n**[2019-01-01 00:00–00:01] very-old** — TOKEN-OLD placed in last position.\n' >> "$V/BASE.md"
M=$(harness); PIDS+=("$M"); agent "$M" open claude >/dev/null
printf '\n## For BASE\n\nTOKEN-T12.\n' >> "$S/open/$(folder "$M")/SESSION.md"; agent "$M" close >/dev/null
check "the oldest by date (last in the file) is archived" '! grep -q TOKEN-OLD "$V/BASE.md" && grep -q TOKEN-OLD "$V"/_archive/*.md'
check "History sorted by start date" 'sed -n "/^## History/,\$p" "$V/BASE.md" | grep -o "^\*\*\[[0-9-]* [0-9:]*" | sort -c'
check "« last purge » note updated by the merge" 'grep -q "last purge: $(date +%F).*automatic merge" "$V/BASE.md"'
check "History still at 5" '[ "$(sed -n "/^## History/,\$p" "$V/BASE.md" | grep -c "^\*\*\[")" = 5 ]'

echo "T13 — old-format header (no follows:): the merge must not crash"
N13=$(harness); PIDS+=("$N13"); agent "$N13" open claude >/dev/null; D13=$(folder "$N13")
grep -v '^follows:' "$S/open/$D13/SESSION.md" > "$S/open/$D13/SESSION.tmp" && mv "$S/open/$D13/SESSION.tmp" "$S/open/$D13/SESSION.md"
printf '\n## For BASE\n\nTOKEN-T13.\n' >> "$S/open/$D13/SESSION.md"
agent "$N13" close >/dev/null 2>&1; r=$?
check "close succeeds (code 0)" '[ $r = 0 ]'
check "session merged (sealed/) and entry present" '[ -d "$S/sealed/$D13" ] && grep -q TOKEN-T13 "$V/BASE.md"'

echo "T14 — threshold of unconsolidated observations reported at opening"
printf '# OBSERVATIONS\n\n**[2026-01-01 00:00]** [incident] — a\n\n**[2026-01-01 00:01]** [incident] — b [proposed → DIRECTIVES.md]\n\n**[2026-01-01 00:02]** [success] — c\n\n**[2026-01-01 00:03]** [incident] [dismissed: event] — d\n' > "$V/OBSERVATIONS.md"
O=$(harness); PIDS+=("$O")
check "2 unmarked, threshold 2 → reported" 'CONTINUUM_OBS_THRESHOLD=2 agent "$O" open claude | grep -q "Unconsolidated observations: 2 "'
check "threshold 3 → nothing" '! CONTINUUM_OBS_THRESHOLD=3 agent "$O" open claude | grep -q "Unconsolidated"'
check "threshold reached → also reported by close, after the merge" 'CONTINUUM_OBS_THRESHOLD=2 agent "$O" close | grep -q "Unconsolidated observations: 2 .*at close"'

echo "T15 — harness updated after it was launched"
# installed at least 2 s before launch: btime (/proc/stat) is rounded to the second
EXE=""; [ "$CONTINUUM_OS" = windows ] && EXE=.exe
BIN=$(dirname "$V")/bin; mkdir -p "$BIN"; cp "$(command -v sleep)$EXE" "$BIN/fakeharness$EXE"; sleep 2
if [ "$CONTINUUM_OS" = windows ]; then   # detached: otherwise T8's wait would wait for it
  Q=$("$BIN/fakeharness" 3600 >/dev/null 2>&1 & windows_pid $!)
else
  Q=$("$BIN/fakeharness" 3600 >/dev/null 2>&1 & echo $!)
fi
PIDS+=("$Q")
check "executable unchanged → nothing" '! PATH=$BIN:$PATH agent "$Q" open claude | grep -q "updated after launch"'
sleep 2; touch "$BIN/fakeharness$EXE"
check "executable replaced after launch → reported" 'PATH=$BIN:$PATH agent "$Q" open claude | grep -q "updated after launch (.*fakeharness"'

echo "T16 — lock whose owner has no (or no longer a) fingerprint: never a crash"
# state seen by an agent when the holder releases the lock between two reads of owner
mkdir "$V/.lock"; echo "label: test" > "$V/.lock/owner"
check "owner without fingerprint, recent lock → busy, no crash" 'CONTINUUM_LOCK_WAIT=2 CONTINUUM_PID=$$ bash "$V/tools/consolidate.sh" 2>&1 | grep -q "Lock busy"'
age_file "$V/.lock" 120
age16=$(( $(date +%s) - $(mtime "$V/.lock") ))
out16=$(CONTINUUM_PID=$$ bash "$V/tools/consolidate.sh" 2>&1)
check "owner without fingerprint, lock older than 60 s → broken, merge done" 'grep -q "Nothing to merge\|Merged" <<< "$out16" && [ ! -d "$V/.lock" ]' \
  'echo "lock age before: $age16 s"; echo "output: $out16"; ls -la "$V/.lock" "$V/.lock-break" 2>&1; tail -3 "$S/locks.log" 2>&1'

echo "T17 — hook in a project with a nested repository (NN_Project/.git)"
I=$V/07_Nested; mkdir "$I"; git -C "$I" init -q
git -C "$I" config user.name test; git -C "$I" config user.email test@local; git -C "$I" config core.hooksPath ../tools/hooks
R=$(harness); U=$(harness); PIDS+=("$R" "$U")
agent "$R" open claude >/dev/null; agent "$U" open pi >/dev/null; agent "$R" work 07_Nested
echo a > "$I/f"; git -C "$I" add f
check "U refused in the nested repository declared by R" '! CONTINUUM_PID=$U git -C "$I" commit -q -m u 2>/dev/null'
check "R allowed in its own project" 'CONTINUUM_PID=$R git -C "$I" commit -q -m r'

echo "T18 — harness detection without CONTINUUM_PID (real parent process)"
# « fakeagent » = copy of bash: runs a bash that looks for its harness. « ; true » prevents a direct exec.
cp "$(command -v bash)$EXE" "$BIN/fakeagent$EXE"
det=$(env -u CONTINUUM_PID "$BIN/fakeagent" -c "bash -c '. \"$V/tools/lib.sh\"; proc_name \"\$(harness_pid)\"'; true" 2>&1)
check "the detected harness is the first non-shell parent (fakeagent)" 'case $det in fakeagent*) true ;; *) false ;; esac' \
  'echo "detected: [$det]"; env -u CONTINUUM_PID "$BIN/fakeagent" -c "bash -c '"'"'. \"$V/tools/lib.sh\"; echo my_pid=\$(my_pid); parent_chain'"'"'; true"'

echo "T19 — tip of the day: a different one at each opening, nothing once the list is exhausted"
W=$(harness); PIDS+=("$W")
before=$(( $(nb open) + $(nb closed) + $(nb sealed) ))
printf '# TIPS\n\n'"$before"'. TIP-A\n' > "$V/TIPS.md"; for i in $(seq 1 $((before - 1))); do echo "$i. x$i" >> "$V/TIPS.md"; done
echo "$((before + 1)). TIP-B" >> "$V/TIPS.md"
s1=$(agent "$W" open claude); s2=$(agent "$W" open claude); s3=$(agent "$W" open claude)
check "opening no. $((before + 1)): tip $before" 'grep -q "^Tip $before/$((before + 1)) .*TIP-A$" <<< "$s1"' 'echo "$s1" | tail -3'
check "next opening: next tip" 'grep -q "^Tip $((before + 1))/.*TIP-B$" <<< "$s2"' 'echo "$s2" | tail -3'
check "list exhausted: no more tips" '! grep -q "^Tip" <<< "$s3"' 'echo "$s3" | tail -3'

echo "T20 — conversation resumed after a reboot of the machine (conversation identifier)"
# another process's pane is read from its environment: Linux only (tools/os/*.sh, pane_of)
if [ "$CONTINUUM_OS" != linux ]; then skip "resuming by conversation identifier (herdr)"; else
export CONTINUUM_HARNESSES=sleep
# fake herdr: `herdr agent get <pane>` → the conversation identifier of that pane, read from $CONV
CONV=$(dirname "$V")/conversations; : > "$CONV"
cat > "$(dirname "$V")/herdr" <<EOS
#!/usr/bin/env bash
c=\$(sed -n "s/^\$3 //p" "$CONV" | tail -1)
[ -n "\$c" ] && echo "{\"result\":{\"agent\":{\"agent_session\":{\"kind\":\"id\",\"value\":\"\$c\"},\"pane_id\":\"\$3\"}}}"
exit 0
EOS
chmod +x "$(dirname "$V")/herdr"; export CONTINUUM_HERDR=$(dirname "$V")/herdr
conv() { echo "$1 $2" >> "$CONV"; }                          # conv <pane> <id>: conversation running in that pane
in_pane() { (cd "$V" && HERDR_PANE_ID=$1 harness); }        # live harness launched from that pane
agent_pane() { local p=$1 pane=$2; shift 2; CONTINUUM_PID=$p HERDR_PANE_ID=$pane bash "$V/tools/session.sh" "$@"; }
reboot() { sed -i "s|^fingerprint: .*|fingerprint: $(uname -n) stale-boot $2 1|" "$1"; }   # fingerprint of a past boot
# case 1 — another agent opens after the reboot: the resumed conversation keeps its folder
conv w6:p1 conv-A; P=$(in_pane w6:p1); PIDS+=("$P")
agent_pane "$P" w6:p1 open claude >/dev/null; IDP=$(folder "$P")
check "conversation written in the header" 'grep -qx "conversation: conv-A" "$S/open/$IDP/SESSION.md"'
reboot "$S/open/$IDP/SESSION.md" "$P"; kill_wait "$P"; P2=$(in_pane w6:p1); PIDS+=("$P2")   # herdr relaunches conv-A
Q=$(harness); PIDS+=("$Q")
out=$(agent "$Q" open pi)
check "folder resumed instead of being closed" 'grep -q "resumed (resumed conversation): $IDP" <<< "$out"'
check "the resumed process finds its folder" '[ "$(agent_pane "$P2" w6:p1 me)" = "$IDP" ]'
# case 2 — same pane, NEW conversation (not a resume): the old folder is closed, no follows
reboot "$S/open/$IDP/SESSION.md" "$P2"; kill_wait "$P2"; conv w6:p1 conv-B; P3=$(in_pane w6:p1); PIDS+=("$P3")
out=$(agent_pane "$P3" w6:p1 open claude); IDP3=$(agent_pane "$P3" w6:p1 me)
check "new conversation in the same pane: old folder closed « harness dead »" 'grep -q "closed (orphan): $IDP — harness dead" <<< "$out"'
check "… and new session without follows" '[ "$IDP3" != "$IDP" ] && grep -qx "follows: " "$S/open/$IDP3/SESSION.md"'
# case 3 — closed « harness dead » by another agent while the conversation comes back later: reopened
X=$(in_pane w9:p3); PIDS+=("$X"); conv w9:p3 conv-X
agent_pane "$X" w9:p3 open claude >/dev/null; IDX=$(folder "$X")
reboot "$S/open/$IDX/SESSION.md" "$X"; kill_wait "$X"; grep -v '^w9:p3 ' "$CONV" > "$CONV.tmp"; mv "$CONV.tmp" "$CONV"
agent "$Q" open pi >/dev/null                                       # conversation not relaunched yet: closed
check "no live conversation: closed « harness dead »" 'grep -q "harness dead" "$S/closed/$IDX/SESSION.md"'
conv w9:p3 conv-X; X2=$(in_pane w9:p3); PIDS+=("$X2")
check "the returning conversation finds its folder without rerunning the ritual (me)" '[ "$(agent_pane "$X2" w9:p3 me)" = "$IDX" ] && [ -d "$S/open/$IDX" ]'
# case 4 — my own conversation reruns the ritual: folder kept, no new one
reboot "$S/open/$IDX/SESSION.md" "$X2"
out=$(agent_pane "$X2" w9:p3 open claude)
check "my resumed conversation: « Session resumed », same folder" 'grep -q "Session resumed: $IDX" <<< "$out" && [ "$(agent_pane "$X2" w9:p3 me)" = "$IDX" ]'
check "a single open folder for this pane" '[ "$(grep -lx "pane: w9:p3" "$S"/open/*/SESSION.md | wc -l)" = 1 ]'
# case 5 — /clear in the same process: another conversation → old folder closed, new session
conv w9:p3 conv-X-clear
out=$(agent_pane "$X2" w9:p3 open claude); IDX2=$(agent_pane "$X2" w9:p3 me)
check "/clear: previous conversation closed « same process », new session" 'grep -q "same process" "$S/closed/$IDX/SESSION.md" && [ "$IDX2" != "$IDX" ]'
# case 6 — reopened then closed normally: never reopened; after a reboot, exact follows
agent_pane "$X2" w9:p3 close >/dev/null
reboot "$S/sealed/$IDX2/SESSION.md" "$X2" 2>/dev/null || reboot "$S/closed/$IDX2/SESSION.md" "$X2"
kill_wait "$X2"; X3=$(in_pane w9:p3); PIDS+=("$X3")
out=$(agent_pane "$X3" w9:p3 open claude); IDX3=$(agent_pane "$X3" w9:p3 me)
check "normal close never reopened" '[ "$IDX3" != "$IDX2" ] && [ ! -d "$S/open/$IDX2" ]'
check "conversation resumed after a real close → exact follows" 'grep -qx "follows: $IDX2" "$S/open/$IDX3/SESSION.md"'
# case 7 — a folder resumed then closed normally is not reopened because of its old « harness dead » line
check "resumed folder (old harness dead line) not reopened" '[ ! -d "$S/open/$IDX" ]'
# case 8 — status: process of a closed conversation recognized, not announced « without a folder »
agent_pane "$X3" w9:p3 close >/dev/null
f=$(ls "$S"/*/"$IDX3"/SESSION.md); reboot "$f" "$X3"
out=$(agent "$Q" status)
check "closed session recognized by conversation, not « without a folder »" '! sed -n "/WITHOUT a session/,/^[^ ]/p" <<< "$out" | grep -q "pid $X3 " && grep -q "pid $X3 .*session closed: $IDX3" <<< "$out"'
unset CONTINUUM_HARNESSES CONTINUUM_HERDR
fi

echo "T21 — rewritten close (two « ## For BASE »): only the last one goes to BASE"
Z=$(harness); PIDS+=("$Z"); agent "$Z" open claude >/dev/null
printf '\n## For BASE\n\nTOKEN-T21-BEFORE.\n\n## For BASE\n\nTOKEN-T21-AFTER.\n' >> "$S/open/$(folder "$Z")/SESSION.md"
agent "$Z" close >/dev/null
check "last section kept, the first one ignored" 'grep -q TOKEN-T21-AFTER "$V/BASE.md" && ! grep -q TOKEN-T21-BEFORE "$V/BASE.md"'

echo "T8 — 50 concurrent >> appends (lines of 1000 characters)"
# 1000: on macOS, bash 3.2 writes a line in chunks of 1024 bytes — beyond that, two concurrent appends can
# split each other (a chunk of exactly 1024 bytes moved into another line).
# On Windows (MSYS), O_APPEND is not atomic between processes: 2 lines out of 50 interleaved in CI.
# Continuum does not depend on it: each agent only appends to its own log, the shared files are only
# written under lock. Documented limit (protocols/installation.md).
if [ "$CONTINUUM_OS" = windows ]; then skip "concurrent appends to the same file not atomic"; else
f=$V/appends.txt
for i in $(seq 1 50); do ( printf "L%02d:%s\n" $i "$(head -c 1000 /dev/zero | tr '\0' x)" >> "$f" ) & done; wait
# awk and not grep x{1000}: BSD grep (macOS) caps repetitions at 255
intact() { awk 'length($0) == 1004 && /^L[0-9][0-9]:x+$/' "$f" | wc -l | tr -d ' '; }
check "50 lines, all intact" '[ "$(wc -l < "$f")" -eq 50 ] && [ "$(intact)" = 50 ]' \
  'echo "lines: $(wc -l < "$f"), intact: $(intact)"; echo "lengths (count × length):"; awk "{print length}" "$f" | sort -n | uniq -c | head -8'
fi

echo
echo "Result: $ok OK, $ko KO"
exit $ko
