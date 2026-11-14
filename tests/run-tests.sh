#!/usr/bin/env bash
# Runs quiz-me against the fixture repo, with a persona agent playing the
# developer, then has an LLM judge check each run and summarize the session.
#
# Usage: run-tests.sh [--branch B] [--persona P] [--runs N]
#   Default: all five personas on add-response-cache, the expert persona on the
#   other branches, 3 runs each. --branch and --persona narrow that down.
#
# Results go to tests/runs/<date>/ (git ignores this folder). The temp fixture
# repo and the answer keys this session created are deleted at the end.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPTS="$TESTS_DIR/prompts"
KEY_DIR="$HOME/.readback/answer_keys"
MAX_TURNS=15
ALL_PERSONAS="expert vague wrong hint-seeker override"
MAIN_CASE="add-response-cache"

# The quiz session needs git, file access, subagents, and write access to the key folder.
QUIZ_TOOLS=("Bash(git *)" Read Grep Glob Write Edit Agent Task)
# The persona plays the developer: it can read the code, never the answer key.
PERSONA_TOOLS=("Bash(git diff *)" "Bash(git log *)" "Bash(git show *)" Read Grep Glob)
PERSONA_DENY=("Read(~/.readback/**)")
JUDGE_TOOLS=(Read Grep Glob)

branch_filter="" persona_filter="" runs=3
while [ $# -gt 0 ]; do
  case "$1" in
    --branch)  branch_filter="$2"; shift 2 ;;
    --persona) persona_filter="$2"; shift 2 ;;
    --runs)    runs="$2"; shift 2 ;;
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

persona_say() {  # persona_say <session id or ""> <message>
  local args=(-p "$2" --output-format json)
  [ -n "$1" ] && args+=(--resume "$1")
  (cd "$FIXTURE" && claude "${args[@]}" --disallowedTools "${PERSONA_DENY[@]}" --allowedTools "${PERSONA_TOOLS[@]}")
}

log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

# --- build the fixture and set up cleanup ----------------------------------

FIXTURE="$(mktemp -d)"
KEY_FILES=()

cleanup() {
  # Delete only the exact key files built from this session's fixture commits.
  for f in ${KEY_FILES[@]+"${KEY_FILES[@]}"}; do rm -f -- "$f"; done
  if [ -n "${FIXTURE:-}" ] && [ -d "$FIXTURE" ]; then rm -rf -- "$FIXTURE"; fi
}
trap cleanup EXIT

bash "$TESTS_DIR/make-fixture.sh" "$FIXTURE" >/dev/null
mkdir -p "$KEY_DIR"

all_branches=()
while IFS= read -r b; do
  [ "$b" = main ] && continue
  all_branches+=("$b")
  KEY_FILES+=("$(key_path "$b")")
done < <(git -C "$FIXTURE" for-each-ref --format='%(refname:short)' refs/heads/)

if [ -n "$branch_filter" ]; then
  git -C "$FIXTURE" rev-parse --verify -q "$branch_filter" >/dev/null \
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

run_one() {  # run_one <branch> <persona> <n>
  local b="$1" p="$2" n="$3"
  local out="$RUN_DIR/$b/$p-$n"
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

  printf '# Transcript: %s / %s / run %s\n' "$b" "$p" "$n" > "$transcript"

  local json msg answer prompt qs="" ps="" turn=0
  if ! json="$(quiz_say "" "/quiz-me")"; then echo "The first quiz call failed." >> "$out/errors.log"; return 0; fi
  qs="$(json_get session_id "$json")"; msg="$(json_get result "$json")"

  # The key subagent writes the key before the first question. No key means
  # the skill didn't start, so stop instead of chatting for MAX_TURNS.
  if [ ! -f "$key" ]; then
    printf '\n### Quiz\n\n%s\n' "$msg" >> "$transcript"
    echo "quiz-me didn't start: no answer key after the first reply." >> "$out/errors.log"
    return 0
  fi

  while :; do
    printf '\n### Quiz\n\n%s\n' "$msg" >> "$transcript"
    if grep -q '^## Grades' <<<"$msg" || { [ -f "$results" ] && grep -q '^## Grades' "$results"; }; then
      break
    fi
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

    if ! json="$(quiz_say "$qs" "$answer")"; then echo "Quiz call failed on turn $turn." >> "$out/errors.log"; break; fi
    qs="$(json_get session_id "$json")"; msg="$(json_get result "$json")"
  done

  if [ -f "$results" ]; then cp -- "$results" "$out/results.md"; else echo "No results file at $results." >> "$out/errors.log"; fi
  if [ -f "$key" ]; then cp -- "$key" "$out/key.md"; else echo "No answer key at $key." >> "$out/errors.log"; fi
  # Copied only after the quiz ends, so neither the quiz nor the persona could see it.
  cp -- "$TESTS_DIR/expected/$b.md" "$out/expected.md"
}

judge_one() {  # judge_one <branch> <persona> <n>
  local out="$RUN_DIR/$1/$2-$3" json
  if json="$(cd "$out" && claude -p "$(cat "$PROMPTS/judge.md")

Branch: $1
Persona: $2" --output-format json --allowedTools "${JUDGE_TOOLS[@]}")"; then
    json_get result "$json" > "$out/judge-report.md"
  else
    echo "The judge call failed." >> "$out/errors.log"
  fi
}

# --- main ------------------------------------------------------------------

log "Fixture built at $FIXTURE"
log "Results will go to $RUN_DIR"

for b in "${branches[@]}"; do
  for p in $(personas_for "$b"); do
    for n in $(seq 1 "$runs"); do
      log "$b / $p / run $n: quiz"
      run_one "$b" "$p" "$n"
      log "$b / $p / run $n: judge"
      judge_one "$b" "$p" "$n"
    done
  done
done

log "Summarizing"
if json="$(cd "$RUN_DIR" && claude -p "$(cat "$PROMPTS/summary.md")" --output-format json --allowedTools "${JUDGE_TOOLS[@]}")"; then
  json_get result "$json" > "$RUN_DIR/report.md"
  log "Report: $RUN_DIR/report.md"
else
  log "The summary call failed. Per-run reports are in $RUN_DIR."
fi
