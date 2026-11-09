You are summarizing a full test session of quiz-me. Your working directory has one folder per branch, and inside each, one folder per run named `<persona>-<n>`. Each run folder holds `judge-report.md` (the verdict for that run) and `results.md` (the skill's grades).

Read every `judge-report.md` and `results.md`, then write a report with these sections:

1. **Scores table:** one row per run, with branch, persona, run number and total score.
2. **Score ordering:** on `add-response-cache`, the mean and the spread (lowest to highest) of the total score for each persona. Say whether expert > vague > wrong holds on the means, and whether it holds in every run.
3. **Altitude:** the design-level percentage for each run, and the average on `add-response-cache`. Say whether that average is at least 80%.
4. **Failures:** every check marked FAIL in any judge report, with the branch, persona, run and the judge's one-line reason.
5. **Overall:** one line saying whether this session passes, and what to look at first if it doesn't.

Reply with only the report, in Markdown.
