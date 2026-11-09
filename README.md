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

The first three each get a follow-up specific to the change. Questions focus on design, not exact code, and their number and altitude scale with the size and type of the change.

- **Answer protection:** a subagent writes the questions and answer key to `~/.readback/answer_keys/`, outside the repo. The agent asking the questions never sees the key or the code. Hint requests are declined and noted in the record.
- **Grading:** a separate subagent grades each answer 0–3 and adds feedback.
- **Output:** `comp_checks/comp_check_<branch>.md`, in a folder the skill makes git ignore.

## Roadmap

- ~~`quiz-me` v1: questions and recorded answers~~ (done)
- Rubric-based scoring of answers (done)
- Hooks that run the quiz at submit time
- Analysis of agent session transcripts to see how the developer and the agent split the work
- A broader agent-led comprehension audit built from these pieces

## Layout

```
skills/
  <skill-name>/
    SKILL.md     # the skill prompt
    README.md    # usage notes
```

## Installing a skill (Claude Code)

Copy or symlink a skill directory into your project's `.claude/skills/` or your user `~/.claude/skills/`:

```sh
ln -s "$(pwd)/skills/quiz-me" ~/.claude/skills/quiz-me
```

Then run `/quiz-me` from a branch with pending changes.
