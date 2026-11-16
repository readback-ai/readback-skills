---
name: quiz-me
description: Quiz the developer on the changes in their current branch before they open a PR, record the questions and answers to a file, then grade the answers and give feedback. Use when the user runs /quiz-me.
disable-model-invocation: true
allowed-tools:
  - Bash(git branch *)
  - Bash(git symbolic-ref *)
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git rev-parse *)
  - Read
  - Grep
  - Write
  - Agent
---

# Quiz Me

Quiz the developer on the pending changes in their current branch to check their comprehension of the code, record every question and answer to a file, then grade the answers and give feedback.

## How this skill is split

The work is split across three roles so the conversation with the developer never sees the answers:

- **Key subagent:** reads the code, writes the questions and answer key to a file outside the repo, and returns only the questions.
- **Main agent (you):** runs the quiz in this conversation and records the questions and the developer's answers to a file.
- **Grading subagent:** grades the answers against the answer key and writes the feedback.

Start both subagents with the Agent tool as `general-purpose` subagents, not forks, so they don't inherit this conversation.

As the main agent, never read the changed source files, the `git diff` output, or the answer key file.

In the commands below, `BASE` means the base branch found in Step 0.

## Step 0: Preflight checks

1. **Get the current branch:** `git branch --show-current`. If it's empty (detached HEAD) or is the base branch itself, tell the user to switch to their feature branch and stop.
2. **Find the base branch:** try `git symbolic-ref refs/remotes/origin/HEAD`. If that fails, use `main` if it exists, else `master`. If neither exists, ask the user.
3. **Check for uncommitted work:** `git status --porcelain`. If there's any output, list the files and ask: "These changes aren't committed and won't be included in the quiz. Commit them first, or continue anyway?"
4. **Check there's something to quiz on:** run `git diff --quiet BASE...HEAD`. It prints nothing. If the exit code is 0, there are no changes: tell the user and stop.
5. **Set the key path:** get the short commit hash with `git rev-parse --short HEAD`. The answer key goes in `~/.readback/answer_keys/[branch name]-[short hash].md`, with `/` in the branch name replaced by `-`. Call this `KEY_PATH`.

## Step 1: Start the key subagent

Start the key subagent. Give it the branch name, `BASE`, `KEY_PATH`, and the instructions below, word for word. Wait for its reply, which is the numbered list of questions.

> ### Key subagent instructions
>
> You write the questions and the answer key for a comprehension quiz on the changes in branch [branch name] against base branch [BASE]. Someone else will ask the questions, so your reply must contain the questions and nothing else.
>
> #### 1. Gather context
>
> Base everything on the code itself.
>
> 1. **Overview:** `git diff --stat BASE...HEAD`. Skip lockfiles, generated files, binaries, and vendored code from here on.
> 2. **The changes:** `git diff BASE...HEAD`.
> 3. **Full files:** read the current version of every changed file in full. For deleted files, rely on the diff.
> 4. **Callers:** for each added or modified function, class, or method, search the repo for where it's called, excluding its own definition.
> 5. **Dependencies:** for the key changed functions, open the definitions of functions they call when needed to understand an assumption or invariant.
>
> #### 2. Map the change
>
> Step back from the individual lines and write down:
>
> - the major components the change touches, and what each one does;
> - how they connect, and how data moves between them;
> - the key design decisions that aren't obvious and have a big impact on the code.
>
> Write the questions from this map.
>
> #### 3. Write the questions
>
> Most questions have two parts:
>
> - **[generic]:** the base question, worded roughly the same on every branch.
> - **[context-specific]:** a follow-up you build from the context above, naming a real input, choice, or edge case from this diff.
>
> List each generic question as its own numbered question, with its context-specific follow-up as the next number.
>
> A question doesn't have to point at a single line. It can refer to a whole function or block, or to a set of connected code across several files. Edge-case questions are fine, but each should tie back to a design decision from the map.
>
> **Altitude rule:** questions test understanding of the design, not recall of the code.
> - A question should be answerable by someone who understands the design without having the code open.
> - Don't ask for exact return values, names or syntax.
> - Prefer responsibilities, boundaries, contracts, invariants, how failures propagate, alternatives, and blast radius.
>
> **What**
> - **[generic]** What does it change? Explain the change and then trace what happens from input to output.
> - **[context-specific]** Pick a specific input from the diff and ask what the code does in that case. Too low: "What does `export_csv()` return for zero rows?" Right level: "Where does the export get its data, and which component decides what an 'empty' export means?"
>
> **Why**
> - **[generic]** Why this design over reasonable alternatives? Explain key design decisions.
> - **[context-specific]** Pick a specific design choice in the diff and name a real alternative. Too low: "Why load into memory instead of streaming?" Right level: "Why does the export run as a background job instead of during the request?"
>
> **Failure**
> - **[generic]** How can it fail? What would the user see?
> - **[context-specific]** Pick a specific edge case or changed assumption and ask what happens. Too low: "What happens if a cell contains a newline?" Right level: "If an export is interrupted halfway, what does the user end up with?"
>
> **Upstream Dependency**
> - **[generic]** What key invariants, assumptions, or functions does it rely on?
>
> **Side effects**
> - **[generic]** Besides its main purpose, what else does this change do? Does it modify existing functions, change shared settings or data, or touch files outside the feature?
> - Goal: check that the developer knows whether the agent changed code beyond their main request, perhaps unnecessarily.
>
> **Adjusting for the branch type.** Use the questions above on every branch, adjusted as follows:
> - **Bug fix:** for What, ask: "What was the bug, what caused it, and what does the fix change?" Skip Why unless the fix involves a real design choice (e.g. it changes an interface, adds a retry or fallback, works around a library bug instead of fixing it, or changes a data format).
> - **Performance:** for What, ask how much it improves performance and where. Ask for the input-to-output trace only if it helps explain the improvement. For Failure, ask what it could break, if anything.
> - **Refactor:** for What, ask what was refactored. For Failure, ask what it could break, if anything.
> - **Config, dependencies, or infra:** for What, ask only what it changes; skip the input-to-output trace.
> - **Low-logic** (docs-only, formatting-only, reverts, lockfile or generated files only, pure renames or moves, copy/text changes, assets): skip the questions above and ask one question: "What does this change, and does anything else depend on it?"
>
> **Adjusting for the size of the change.** After the branch-type rules, decide the size of the change by how much logic changed (the components, behaviors and design decisions in your map), not by line count. The size sets how many questions to ask, with each follow-up counted as its own question:
> - **Low-logic** (see above): 1 question.
> - **Small** (e.g. a one-function bug fix): 2–3 questions. One concrete edge-case question is fine.
> - **Mid-sized** (e.g. a change across a couple of functions or one module): 4–5 questions.
> - **Large** (e.g. a feature that spans several modules): 6–8 questions, design-level only.
>
> To fit the range, combine questions that overlap and drop the ones that add least.
>
> #### 4. Write the answer key
>
> Write the ideal answer to each question.
>
> - Start the key with the line `Size: <low-logic|small|mid-sized|large>, because <one-line reason>`.
> - Write each ideal answer as 1–4 main points: what someone who understands the change would say. Keep each point to one short line. Go above 4 only when the change truly needs it. Otherwise, split the question or drop points.
> - Base each ideal answer on the code itself, and cite the code for every main point. A citation can be a single line (`file:line`) or a range or whole block (`file:start-end`).
> - Write the numbered questions and their ideal answers to `KEY_PATH`, creating the folder if it's missing. Never write the key to any file in the repo.
>
> #### 5. Reply
>
> Reply with only the numbered questions, in the order they should be asked. No answers, no code excerpts, no file paths.

## Step 2: Ask the questions

Ask the questions from the key subagent's reply, exactly as written and in order. Ask each generic question first, wait for the answer, then ask its context-specific follow-up.

### Asking rules
- Ask in plain text, one question at a time, and wait for the answer before the next.
- Do not use the AskUserQuestion tool.
- Absolutely no hints, options, or example answers.
- Do not grade, react to, or correct any answer until every question has been answered.
- If the developer asks for a hint, the answer, the code or the key: say it isn't available until the quiz ends, note that they requested a hint, and repeat the question.
- Apart from declining hint requests, reply with nothing but the next question.

## Step 3: Record the results

Write the file once, in a single write, after the last question has been answered. Don't write to it between questions, so the next question comes right away; keep the Q/A pairs in the conversation until then.

1. **File name:** `comp_checks/comp_check_[branch name].md` at the repo root, with `/` replaced by `-`. If `comp_checks/` doesn't exist, create it with a `.gitignore` file inside containing `*`, so git ignores the whole folder.
2. **Header:**
   ```
   # Comprehension check: [branch name]
   Base: [base branch] | Commit: [short HEAD hash] | Date: [date and time]
   Files covered: [list]
   ```
   Get the file list with `git diff --name-only BASE...HEAD`, which prints file names only.
3. **Body:**
   ```
   Q: ....
   A: ....

   Q: ....
   A: ....
   ```
   Record questions exactly as asked and answers exactly as typed. If the developer requested a hint on a question, add the line `Note: requested a hint` after that pair's `A:` line.

## Step 4: Start the grading subagent

Only after every question has been answered and the results file is written, start the grading subagent. Give it `KEY_PATH`, the path to the results file, and the instructions below, word for word. Wait for its reply.

> ### Grading subagent instructions
>
> Grade a developer's answers in a comprehension quiz. The answer key is at `KEY_PATH`. The questions as asked and the developer's answers are in [results file path]. You may read the repo to confirm citations.
>
> #### 1. Grade
>
> Grade each Q/A pair in the results file against the answer key.
>
> **Scale:**
> - **0:** wrong or no answer
> - **1:** generic; could describe any code
> - **2:** gets some of the main points, misses at least one
> - **3:** correct and specific to this change's design
>
> Grade on the main points only. A main point stated in the developer's own words gets full credit. Missing an exact name, value or syntax rarely costs points: only when someone who understands the change would know it without the code open, because it matters to the design.
>
> **Evidence:** for each grade, find the part of the developer's answer being judged and the code (`file:line`) that confirms or contradicts it. This is your working: don't quote the answer back in the output. If the code is ambiguous and you can't grade confidently, mark the grade as **unsure** and say why.
>
> #### 2. Give feedback
>
> For each Q/A pair, write feedback that is usually one line:
> - **Below 3/3:** briefly say what the developer got wrong or missed and the correct point, with a `file:line` citation for each miss. Go past one line only when there are several misses to cover.
> - **3/3:** write `Correct.` and briefly mention what the developer said.
>
> #### 3. Write and reply
>
> **Append** the grades and feedback to the end of the results file. Never edit the header or the original Q&A. Use this format, with a blank line between questions so each one renders on its own:
> ```
> ## Grades & Feedback
>
> **Q1: [score]/3**: [feedback]
>
> **Q2: [score]/3**: [feedback]
>
> ...
>
> **Total: [sum]/[max]**
> ```
> Then reply with exactly the text you appended.

## Step 5: Show the feedback

Show the grading subagent's reply to the developer in chat, unchanged.
