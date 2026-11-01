---
name: quiz-me
description: Quiz the developer on the changes in their current branch before they open a PR, record the questions and answers to a file, then grade the answers and give feedback. Use when the user runs /quiz-me or asks to be quizzed on their branch's changes.
---

# Quiz Me

Quiz the developer on the pending changes in their current branch to check their comprehension of the code, record every question and answer to a file, then grade the answers and give feedback.

In the commands below, `BASE` means the base branch found in Step 0.

## Step 0: Preflight checks

1. **Get the current branch:** `git branch --show-current`. If it's empty (detached HEAD) or is the base branch itself, tell the user to switch to their feature branch and stop.
2. **Find the base branch:** try `git symbolic-ref refs/remotes/origin/HEAD`. If that fails, use `main` if it exists, else `master`. If neither exists, ask the user.
3. **Check for uncommitted work:** `git status --porcelain`. If there's any output, list the files and ask: "These changes aren't committed and won't be included in the quiz. Commit them first, or continue anyway?"
4. **Check there's something to quiz on:** if `git diff BASE...HEAD` is empty, tell the user and stop.

## Step 1: Gather context

Gather everything before asking questions, and show none of it to the developer. Base everything on the code itself.

1. **Overview:** `git diff --stat BASE...HEAD`. Skip lockfiles, generated files, binaries, and vendored code from here on.
2. **The changes:** `git diff BASE...HEAD`.
3. **Full files:** read the current version of every changed file in full. For deleted files, rely on the diff.
4. **Callers:** for each added or modified function, class, or method, search the repo for where it's called, excluding its own definition.
5. **Dependencies:** for the key changed functions, open the definitions of functions they call when needed to understand an assumption or invariant.

## Step 2: Write the answer key

Before asking anything, plan every question in Step 3, including the specific input, design choice, or edge case for each context-specific part. Then write the ideal answer to each question.

- Base each ideal answer on the code itself, citing `file:line` for every claim.
- Keep the answer key private. Do not show it to the developer, and do not write it to any file in the repo.

## Step 3: Ask the questions

Each question has two parts:

- **[generic]:** the base question, worded roughly the same on every branch.
- **[context-specific]:** a follow-up you build from the Step 1 context, naming a real input, choice, or edge case from this diff.

Ask the generic part first, wait for the answer, then ask the context-specific part.

### What
- **[generic]** What does it change? Explain the change and then trace what happens from input to output.
- **[context-specific]** Pick a specific input from the diff and ask what the code does in that case. Example: "What does `export_csv()` return when the table has zero rows?"

### Why
- **[generic]** Why this design over reasonable alternatives? Explain key design decisions.
- **[context-specific]** Pick a specific design choice in the diff and name a real alternative. Example: "Why does it load all rows into memory instead of streaming them?"

### Failure
- **[generic]** How can it fail? What would the user see?
- **[context-specific]** Pick a specific edge case or changed assumption and ask what happens. Example: "What happens if a cell contains a newline?"

### Upstream Dependency
- **[generic]** What key invariants, assumptions, or functions does it rely on?

### Side effects
- **[generic]** Besides its main purpose, what else does this change do? Does it modify existing functions, change shared settings or data, or touch files outside the feature?
- Goal: check that the developer knows whether the agent changed code beyond their main request, perhaps unnecessarily.

### Adjusting for the branch type
Use the questions above on every branch, adjusted as follows:
- **Bug fix:** for What, ask: "What was the bug, what caused it, and what does the fix change?" Skip Why unless the fix involves a real design choice (e.g. it changes an interface, adds a retry or fallback, works around a library bug instead of fixing it, or changes a data format).
- **Performance:** for What, ask how much it improves performance and where. Ask for the input-to-output trace only if it helps explain the improvement. For Failure, ask what it could break, if anything.
- **Refactor:** for What, ask what was refactored. For Failure, ask what it could break, if anything.
- **Config, dependencies, or infra:** for What, ask only what it changes; skip the input-to-output trace.
- **Low-logic** (docs-only, formatting-only, reverts, lockfile or generated files only, pure renames or moves, copy/text changes, assets): skip the questions above and ask one question: "What does this change, and does anything else depend on it?"

### Asking rules
- Ask in plain text, one question at a time, and wait for the answer before the next.
- Do not use the AskUserQuestion tool.
- Absolutely no hints, options, or example answers.
- Do not grade, react to, or correct any answer until every question has been answered.

## Step 4: Record the results

Write the file once, in a single write, after the last question has been answered. Don't write to it between questions, so the next question comes right away; keep the Q/A pairs in the conversation until then.

1. **File name:** `comp_check_[branch name].md` at the repo root, with `/` replaced by `-`.
2. **Header:**
   ```
   # Comprehension check: [branch name]
   Base: [base branch] | Commit: [short HEAD hash] | Date: [date and time]
   Files covered: [list]
   ```
3. **Body:**
   ```
   Q: ....
   A: ....

   Q: ....
   A: ....
   ```
   Record questions exactly as asked and answers exactly as typed.

## Step 5: Grade

Only after every question has been answered, grade each Q/A pair against the answer key from Step 2.

**Scale:**
- **0:** wrong or no answer
- **1:** generic; could describe any code
- **2:** partially correct; misses a key detail
- **3:** correct and specific to this code

**Evidence:** for each grade, quote the part of the developer's answer being judged inline, and cite the code (`file:line`) that confirms or contradicts it. If the code is ambiguous and you can't grade confidently, mark the grade as **unsure** and say why.

## Step 6: Give feedback

For each Q/A pair, state what the developer got right, what they missed, and the correct answer, citing `file:line`.

Then:

1. **Append** the grades and feedback to the end of the same `comp_check_[branch name].md` file. Never edit the original Q&A. Use this format:
   ```
   ## Grades

   Q1: [score]/3 — [one-line reason with inline evidence]
   Q2: [score]/3 — [one-line reason with inline evidence]
   ...
   Total: [sum]/[max]

   ## Feedback

   Q1: [what was right, what was missed, correct answer with file:line]
   Q2: ...
   ```
2. **Show** the same grades and feedback to the developer in chat.