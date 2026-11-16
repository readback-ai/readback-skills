#!/usr/bin/env bash
# Runs quiz-me against the fixture repo, with a persona agent playing the
# developer, then has an LLM judge check each run and summarize the session.
#
# Usage: run-tests.sh [--branch B] [--persona P] [--runs N] [--baseline]
#   Default: all five personas on add-response-cache, the expert persona on the
#   other branches, 3 runs each. --branch and --persona narrow that down.
#   --baseline also runs every case against plain Claude, which gets the
#   plain-language request in prompts/baseline.md instead of /quiz-me, so the
#   report can show scores with and without the skill.
#
# Up to MAX_PARALLEL cases run at once. Each case gets its own fixture repo,
# deleted when the case ends.
#
# Results go to tests/runs/<date>/ (git ignores this folder): one folder per
# run, <branch>/<persona>-<n> for quiz-me and <branch>/<persona>-<n>-baseline
# for plain Claude. build-report.py builds the tables in report.md, and the
# summary AI adds the notes. The temp fixture repos and the answer keys this
# session created are deleted at the end.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS="$TESTS_DIR/prompts"
KEY_DIR="$HOME/.readback/answer_keys"
MAX_TURNS=15
MAX_PARALLEL=4
ALL_PERSONAS="expert vague wrong hint-seeker override"
MAIN_CASE="add-response-cache"

# The quiz session needs git, file access, subagents, and write access to the key folder.
QUIZ_TOOLS=("Bash(git *)" Read Grep Glob Write Edit Agent Task)
# The persona plays the developer: it can read the code, never the answer key.
PERSONA_TOOLS=("Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" Read Grep Glob)
PERSONA_DENY=("Read(~/.readback/**)")
JUDGE_TOOLS=(Read Grep Glob)

# A baseline run ends at a "Total: X/Y" line, which prompts/baseline.md asks
# for. Markdown around it (bold, a table row) is allowed. build-report.py uses
# the same pattern to read the score.
BASELINE_END='^[[:space:]*_#>|-]*total( score)?[[:space:]*_|]*:?[[:space:]*_|]*[0-9]+(\.[0-9]+)?[[:space:]]*/[[:space:]]*[0-9]+'

branch_filter="" persona_filter="" runs=3 modes="skill"
while [ $# -gt 0 ]; do
  case "$1" in
    --branch)   branch_filter="$2"; shift 2 ;;
    --persona)  persona_filter="$2"; shift 2 ;;
    --runs)     runs="$2"; shift 2 ;;
    --baseline) modes="skill baseline"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v claude >/dev/null || { echo "The claude CLI isn't on PATH. Install Claude Code's CLI first." >&2; exit 1; }
PY=""
for c in python3 python; do
  if "$c" -c "import sys" >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "Python 3 is required to read claude's JSON output." >&2; exit 1; }
export PYTHONIOENCODING=utf-8

# --- helpers ---------------------------------------------------------------

# json_get <field> <json>: print one top-level field of claude's JSON output.
json_get() {
  "$PY" -c 'import json, sys
d = json.loads(sys.stdin.read())
v = d.get(sys.argv[1])
print("" if v is None else v)' "$1" <<<"$2"
}

# section <file> <name>: print the body of the "## <name>" section.
section() {
  awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"
}

# key_path <branch>: the exact answer key path quiz-me uses for this fixture branch.
key_path() {
  echo "$KEY_DIR/${1//\//-}-$(git -C "$FIXTURE" rev-parse --short "$1").md"
}

quiz_say() {  # quiz_say <session id or ""> <message>
  local args=(-p "$2" --output-format json --add-dir "$HOME/.readback")
  [ -n "$1" ] && args+=(--resume "$1")
  # On Windows, Git Bash rewrites arguments that start with "/" into Windows
  # paths, which turns "/quiz-me" into "C:/Program Files/Git/quiz-me".
  (cd "$FIXTURE" && MSYS2_ARG_CONV_EXCL="/quiz-me" claude "${args[@]}" --allowedTools "${QUIZ_TOOLS[@]}")
}

# Plain Claude for baseline runs: the same tools as the quiz session, so the
# only difference is the opening request. quiz-me sets
# disable-model-invocation, so plain Claude can't load it on its own, but it
# can still use other skills.
baseline_say() {  # baseline_say <session id or ""> <message>
  local args=(-p "$2" --output-format json)
  [ -n "$1" ] && args+=(--resume "$1")
  (cd "$FIXTURE" && claude "${args[@]}" --allowedTools "${QUIZ_TOOLS[@]}")
}

persona_say() {  # persona_say <session id or ""> <message>
  local args=(-p "$2" --output-format json)
  [ -n "$1" ] && args+=(--resume "$1")
  (cd "$FIXTURE" && claude "${args[@]}" --disallowedTools "${PERSONA_DENY[@]}" --allowedTools "${PERSONA_TOOLS[@]}")
}

log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

# --- set up cleanup and list the cases -------------------------------------

# Each case builds its fixture at $FIXTURE_ROOT/<case #> and adds its answer
# key path to $FIXTURE_ROOT/keys, so cleanup can find both.
FIXTURE_ROOT="$(mktemp -d)"
SESSION_START="$(date +%s)"

# Job control gives each case its own process group, so cleanup can stop a
# case along with its claude calls without touching whatever started this script.
set -m

cleanup() {
  for pid in $(jobs -p); do kill -TERM -- "-$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  # Delete only the exact key files built from this session's fixture commits.
  if [ -f "$FIXTURE_ROOT/keys" ]; then
    while IFS= read -r f; do rm -f -- "$f"; done < "$FIXTURE_ROOT/keys"
  fi
  rm -rf -- "$FIXTURE_ROOT"
}
trap cleanup EXIT

mkdir -p "$KEY_DIR"

# Fixture branches are the folders in tests/branches/, except base (main).
all_branches=()
for dir in "$TESTS_DIR"/branches/*/; do
  b="$(basename "$dir")"
  [ "$b" = base ] || all_branches+=("$b")
done

if [ -n "$branch_filter" ]; then
  [[ " ${all_branches[*]} " == *" $branch_filter "* ]] \
    || { echo "No fixture branch named $branch_filter" >&2; exit 1; }
  branches=("$branch_filter")
else
  branches=("${all_branches[@]}")
fi

personas_for() {
  if [ -n "$persona_filter" ]; then echo "$persona_filter"
  elif [ "$1" = "$MAIN_CASE" ]; then echo "$ALL_PERSONAS"
  else echo expert
  fi
}

RUNS_ROOT="$TESTS_DIR/runs"
mkdir -p "$RUNS_ROOT"
[ -f "$RUNS_ROOT/.gitignore" ] || printf '*\n' > "$RUNS_ROOT/.gitignore"
RUN_DIR="$RUNS_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"

# --- one quiz run ----------------------------------------------------------

run_path() {  # run_path <branch> <persona> <n> <mode>: this run's results folder
  if [ "$4" = baseline ]; then echo "$RUN_DIR/$1/$2-$3-baseline"; else echo "$RUN_DIR/$1/$2-$3"; fi
}

# quiz_done <mode> <last quiz message> <results file>: true once grading is in.
quiz_done() {
  if [ "$1" = baseline ]; then
    grep -Eiq "$BASELINE_END" <<<"$2"
  else
    grep -q '^## Grades' <<<"$2" || { [ -f "$3" ] && grep -q '^## Grades' "$3"; }
  fi
}

run_one() {  # run_one <branch> <persona> <n> <mode>
  local b="$1" p="$2" n="$3" mode="$4"
  local out; out="$(run_path "$b" "$p" "$n" "$mode")"
  local results="$FIXTURE/comp_checks/comp_check_${b//\//-}.md"
  local key; key="$(key_path "$b")"
  local transcript="$out/transcript.md"
  mkdir -p "$out"

  # Start clean so a failed run can't pick up the previous run's files.
  rm -f -- "$results" "$key"
  git -C "$FIXTURE" checkout -q "$b"

  local persona_text
  persona_text="$(section "$PROMPTS/personas.md" common)

$(section "$PROMPTS/personas.md" "$p")"
  [ -n "$(section "$PROMPTS/personas.md" "$p")" ] || { echo "Unknown persona: $p" > "$out/errors.log"; return 0; }

  local say=quiz_say request="/quiz-me" label="quiz-me"
  if [ "$mode" = baseline ]; then
    say=baseline_say request="$(cat "$PROMPTS/baseline.md")" label="plain Claude"
  fi
  printf '# Transcript: %s / %s / run %s / %s\n' "$b" "$p" "$n" "$label" > "$transcript"
  [ "$mode" = baseline ] && printf '\n### Request\n\n%s\n' "$request" >> "$transcript"

  local json msg answer prompt qs="" ps="" turn=0
  if ! json="$("$say" "" "$request")"; then echo "The first quiz call failed." >> "$out/errors.log"; return 0; fi
  qs="$(json_get session_id "$json")"; msg="$(json_get result "$json")"

  # The key subagent writes the key before the first question. No key means
  # the skill didn't start, so stop instead of chatting for MAX_TURNS.
  # Plain Claude writes no key, so baseline runs skip this check.
  if [ "$mode" = skill ] && [ ! -f "$key" ]; then
    printf '\n### Quiz\n\n%s\n' "$msg" >> "$transcript"
    echo "quiz-me didn't start: no answer key after the first reply." >> "$out/errors.log"
    return 0
  fi

  while :; do
    printf '\n### Quiz\n\n%s\n' "$msg" >> "$transcript"
    quiz_done "$mode" "$msg" "$results" && break
    turn=$((turn + 1))
    if [ "$turn" -gt "$MAX_TURNS" ]; then echo "Stopped after $MAX_TURNS turns without grades." >> "$out/errors.log"; break; fi

    if [ -z "$ps" ]; then
      prompt="$persona_text

The quiz says:

$msg"
    else
      prompt="$msg"
    fi
    if ! json="$(persona_say "$ps" "$prompt")"; then echo "Persona call failed on turn $turn." >> "$out/errors.log"; break; fi
    ps="$(json_get session_id "$json")"; answer="$(json_get result "$json")"
    printf '\n### Developer (%s)\n\n%s\n' "$p" "$answer" >> "$transcript"

    if ! json="$("$say" "$qs" "$answer")"; then echo "Quiz call failed on turn $turn." >> "$out/errors.log"; break; fi
    qs="$(json_get session_id "$json")"; msg="$(json_get result "$json")"
  done

  if [ "$mode" = skill ]; then
    if [ -f "$results" ]; then cp -- "$results" "$out/results.md"; else echo "No results file at $results." >> "$out/errors.log"; fi
    if [ -f "$key" ]; then cp -- "$key" "$out/key.md"; else echo "No answer key at $key." >> "$out/errors.log"; fi
  fi
  # Copied only after the quiz ends, so neither the quiz nor the persona could see it.
  cp -- "$TESTS_DIR/expected/$b.md" "$out/expected.md"
}

judge_one() {  # judge_one <branch> <persona> <n> <mode>
  local out json judge="$PROMPTS/judge.md"
  out="$(run_path "$@")"
  # The baseline judge works from the transcript alone: there's no key or results file.
  [ "$4" = baseline ] && judge="$PROMPTS/judge-baseline.md"
  if json="$(cd "$out" && claude -p "$(cat "$judge")

Branch: $1
Persona: $2" --output-format json --allowedTools "${JUDGE_TOOLS[@]}")"; then
    json_get result "$json" > "$out/judge-report.md"
  else
    echo "The judge call failed." >> "$out/errors.log"
  fi
}

elapsed() {  # elapsed <seconds>: print as "Xm Ys"
  echo "$(($1 / 60))m $(($1 % 60))s"
}

# --- one case: its own fixture, the quiz, the judge -----------------------

run_case() {  # run_case <case #> <branch> <persona> <n> <mode>
  local i="$1" b="$2" p="$3" n="$4" mode="$5" start=$SECONDS key out
  local name="$b / $p / run $n"
  [ "$mode" = baseline ] && name="$name / baseline"
  # Runs in the background, so this FIXTURE is only this case's.
  FIXTURE="$FIXTURE_ROOT/$i"

  # Repos built in the same second would get the same commit SHAs, and so the
  # same answer key path. Dating each case's commits SESSION_START + i keeps
  # them apart.
  local date="$((SESSION_START + i)) +0000"
  if ! GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
      bash "$TESTS_DIR/make-fixture.sh" "$FIXTURE" >/dev/null; then
    out="$(run_path "$b" "$p" "$n" "$mode")"
    mkdir -p "$out"
    echo "Couldn't build the fixture repo." >> "$out/errors.log"
    log "$name: failed to build fixture"
    return 0
  fi
  key="$(key_path "$b")"
  echo "$key" >> "$FIXTURE_ROOT/keys"

  run_one "$b" "$p" "$n" "$mode"
  judge_one "$b" "$p" "$n" "$mode"

  rm -rf -- "$FIXTURE"
  rm -f -- "$key"
  log "$name: done in $(elapsed $((SECONDS - start)))"
}

# --- main ------------------------------------------------------------------

log "Results will go to $RUN_DIR"

i=0
for b in "${branches[@]}"; do
  for p in $(personas_for "$b"); do
    for n in $(seq 1 "$runs"); do
      for mode in $modes; do
        # Wait for a free spot. (wait -n doesn't count jobs that already ended,
        # so check the running count first.)
        while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do wait -n || true; done
        i=$((i + 1))
        log "$b / $p / run $n$([ "$mode" = baseline ] && echo " / baseline"): started (case $i)"
        # No stdin: with job control on, a background case would otherwise share
        # the terminal, and claude waits 3s for stdin when it isn't a terminal.
        run_case "$i" "$b" "$p" "$n" "$mode" </dev/null &
      done
    done
  done
done
wait || true
log "All $i cases done in $(elapsed "$SECONDS")"

# The script builds every table and the overview line, so no numbers in the
# report come from an AI. The summary AI only adds the notes after them.
log "Building tables"
if ! "$PY" "$TESTS_DIR/build-report.py" "$RUN_DIR" --main-case "$MAIN_CASE" --elapsed "$SECONDS" > "$RUN_DIR/tables.md"; then
  log "build-report.py failed. Per-run reports are in $RUN_DIR."
  exit 1
fi

log "Summarizing"
if json="$(cd "$RUN_DIR" && claude -p "$(cat "$PROMPTS/summary.md")" --output-format json --allowedTools "${JUDGE_TOOLS[@]}")"; then
  { cat "$RUN_DIR/tables.md"; printf '\n'; json_get result "$json"; } > "$RUN_DIR/report.md"
else
  { cat "$RUN_DIR/tables.md"; printf '\n_The summary call failed, so this report has no notes._\n'; } > "$RUN_DIR/report.md"
  log "The summary call failed, so the report has tables only."
fi
log "Report: $RUN_DIR/report.md"
