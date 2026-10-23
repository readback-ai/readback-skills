# AGENTS.md

Guidance for coding agents (and people) working in this repo.

## What this repo is

A collection of agent skills for Readback, which checks whether developers understand the code changes they submit. Each skill lives in `skills/<name>/`. See `README.md` for the project overview and roadmap.

## Skill layout

- `skills/<name>/SKILL.md`: the skill itself, with YAML frontmatter (`name`, `description`) followed by the prompt. This is what Claude Code loads.
- `skills/<name>/README.md`: short usage notes for humans.
- Keep any helper files next to `SKILL.md` in the same directory.

## Conventions

- **Keep skills small.** Prefer a single clear prompt over scripts or extra tooling until there is a reason for more.
- **Stay in scope.** Build only what the current version calls for. For `quiz-me` v1, that means no hooks and no scoring.
- **Agree on prompts first.** Changes to the questions a skill asks, or to its output format, should be shared as a draft and agreed on before they are implemented.
- **Read-only toward the user's code.** Skills inspect the repo (diffs, logs, files) but must not modify the user's source, commit, or push. Writing their own output file is fine.
- **Plain output formats.** Write records as Markdown (or JSON when it needs to be machine-read) so people can read and diff them.
- **Test on a real branch.** A skill is done when it has been run on a real branch in one of our repos and the output looks right.

## Workflow

- Work on a feature branch and open a PR against `main`.
- Update the skills table in `README.md` when you add a skill or change its status.
