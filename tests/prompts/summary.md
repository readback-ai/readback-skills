You are writing the notes for a quiz-me test session report. A script has already built the overview line and every table from the run files. They are in `tables.md`, and the final report is `tables.md` followed by your reply.

Your working directory has one folder per branch. Inside each are run folders:

- `<persona>-<n>`: a quiz-me run, with `judge-report.md`, `results.md`, `key.md`, `transcript.md` and `expected.md`.
- `<persona>-<n>-baseline`: plain Claude given a plain-language quiz request instead of `/quiz-me`, with `judge-report.md`, `transcript.md` and `expected.md`. These only exist if the session ran with `--baseline`.

Any run folder may also hold `errors.log`.

Read `tables.md` first, then the judge reports, and open the other files when you need them to explain something. Don't repeat the tables, and don't compute new totals, means or counts: point to the tables instead.

Reply with only these two sections, in Markdown:

```
## Notes
- Short bullets explaining the tables: why each failure happened, and whether failures share a cause.
- Anything in the tables that looks off, such as a judge's count that the transcript doesn't support.
- If there are baseline runs: what the with/without gap shows quiz-me adds, such as leaks, altitude, coverage of the expected points, and whether the scores separate expert, vague and wrong.

## Overall
One line: whether this session passes, and what to look at first if it doesn't.
```
