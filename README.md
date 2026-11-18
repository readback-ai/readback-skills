# readback-skills

Agent skills that check whether a developer understands a code change before it ships.

As more code is written with AI help, it gets easier to submit changes you can't fully explain. These skills have an agent read the change and question the developer about it, then save the questions and answers. The record shows how well the change is understood and gives reviewers something to work from.

## Skills

| Skill | Status | What it does |
| --- | --- | --- |
| [`quiz-me`](skills/quiz-me/) | Available | Quizzes the developer on the current branch's changes, grades the answers, and saves the record. |

### quiz-me

Run `/quiz-me` from a feature branch with committed changes. It only runs when "/quiz-me" is typed.

It asks about the change on the current branch:

1. **What** does the change do?
2. **Why** was it designed this way?
3. **How does it fail?**
4. **What does it depend on?**
5. **What else does it change** besides its main purpose?

The first three each get a follow-up specific to the change. Questions focus on design, not exact code. Their number scales with the size and type of the change, from 1 for a docs-only change to 8 for a large feature.

- **Answer protection:** a subagent writes the questions and answer key to `~/.readback/answer_keys/`, outside the repo. The agent asking the questions never sees the key or the code. Hint requests are declined and noted in the record.
- **Grading:** a separate subagent grades each answer 0–3 on its main points, not on exact names or values, and adds a line or two on what was missed.
- **Output:** `comp_checks/comp_check_<branch>.md`, in a folder the skill makes git ignore.
- **Feedback (optional):** at the end, you can rate the quiz in one line or reply "n" to skip. Replying sends your ratings: they're saved to `comp_checks/feedback/<branch>.txt`, and the agent sends that file to the maintainers' Google Form with `curl`. The file holds your ratings and notes plus the skill version, model, change size, question count, score and number of hints. It never contains code, file paths, branch names, questions or answers. Reply "n" and nothing is sent.

#### Setup (Claude Code)

1. Copy or symlink the skill directory into your user `~/.claude/skills/` or your project's `.claude/skills/`. The hook script, `quiz-gate.sh`, comes with it.
   ```sh
   ln -s "$(pwd)/skills/quiz-me" ~/.claude/skills/quiz-me
   ```

Steps 2–4 are optional. They add a hook that brings up the quiz when the agent runs `gh pr create`, controlled by `QUIZ_ON_PR`:

- `off` (default): nothing changes; `/quiz-me` stays voluntary.
- `ask`: you're asked "Quiz on this PR or move on?" before the PR is created.
- `require`: the PR is blocked until you've run `/quiz-me`.

Either way the PR goes through once a graded quiz exists for the current commit.

2. (Optional) Pick a settings file from the table below and open it, creating it if it doesn't exist:
   - In VS Code: press `Ctrl+P` and paste the file's path, such as `~/.claude/settings.json`.
   - From a terminal: run `code ~/.claude/settings.json`.
3. (Optional) Add the snippet below. If the file already has `env` or `hooks`, merge these in rather than replacing them.
4. (Optional) Start a new Claude Code session.

| File | Applies to | Shared through git? |
| --- | --- | --- |
| `~/.claude/settings.json` | You, in every project | No |
| `<repo>/.claude/settings.json` | Everyone working in that repo | Yes, commit it |
| `<repo>/.claude/settings.local.json` | You, in that repo only | No, git ignores it |

If more than one file sets `QUIZ_ON_PR`, the most specific wins: `settings.local.json`, then the repo's `settings.json`, then `~/.claude/settings.json`. So a developer can turn off a quiz their team turned on.

```json
{
  "env": { "QUIZ_ON_PR": "ask" },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/skills/quiz-me/quiz-gate.sh" }]
      }
    ]
  }
}
```

If you installed the skill into the project's `.claude/skills/` instead, use `bash "$CLAUDE_PROJECT_DIR/.claude/skills/quiz-me/quiz-gate.sh"` as the command.

## Roadmap

- ~~`quiz-me` v1: questions and recorded answers~~ (done)
- Rubric-based scoring of answers (done)
- Hooks that run the quiz at submit time (done)
- Analysis of agent session transcripts to see how the developer and the agent split the work
- A broader agent-led comprehension audit built from these pieces

## Layout

```
skills/
  <skill-name>/
    SKILL.md     # the skill prompt
    README.md    # usage notes
```

