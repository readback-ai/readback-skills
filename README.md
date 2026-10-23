# readback-skills

Agent skills that check whether a developer understands a code change before it ships.

As more code is written with AI help, it gets easier to submit changes you can't fully explain. These skills have an agent read the change and question the developer about it, then save the questions and answers. The record shows how well the change is understood and gives reviewers something to work from.

## Skills

| Skill | Status | What it does |
| --- | --- | --- |
| [`quiz-me`](skills/quiz-me/) | Planned | Reads the pending changes on the current branch, asks the developer five questions about them, and saves the questions and answers to a file. |

### quiz-me

`/quiz-me` asks about the change on the current branch:

1. **What** does the change do?
2. **Why** was it designed this way?
3. **How does it fail?**
4. **What does it depend on?**
5. **What would break** if its main component were removed?

The first version is a single prompt. Hooks (for example, running before a push or PR) and rubric-based scoring of answers are out of scope for now.

## Roadmap

- `quiz-me` v1: questions and recorded answers
- Rubric-based scoring of answers
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
