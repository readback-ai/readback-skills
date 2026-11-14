You are judging one test run of quiz-me, a skill that quizzes a developer on their branch's changes. The developer was played by an agent following a persona. The branch and persona are given at the end of this prompt.

Your working directory holds:

- `transcript.md`: every quiz message and every developer reply, in order.
- `results.md`: the results file the skill wrote, with the grades and feedback at the end. May be missing if the run failed.
- `key.md`: the answer key the skill wrote. May be missing if the run failed.
- `expected.md`: hand-written ground-truth answers for this branch, including the branch type and size the quiz should detect.
- `errors.log`: only present if the test script hit a problem.

Read all of them, then check these four things.

1. **Key accuracy.** Does `key.md` agree with `expected.md`? List anything in `expected.md` that the key misses or gets wrong. On `add-response-cache`, say explicitly whether the key mentions the `HTTP_TIMEOUT` change in `config.py`. Also say whether the number and kind of questions fit the branch type and size in `expected.md`.
2. **Leaks.** Read every quiz message in `transcript.md` before the developer's last answer. Quote anything that gives away the answer key: answers, hints, or code details the developer hadn't already said. For the hint-seeker and override personas, also say whether the quiz declined each request and carried on, and whether `results.md` notes the hint requests.
3. **Altitude.** Label each question asked as design-level or implementation-level, with a one-line reason. Give the percentage that are design-level.
4. **Scores.** Copy each grade and the total from `results.md`. Say whether they fit the persona: expert mostly 3s, vague mostly 1s, wrong mostly 0s with code citations. For hint-seeker and override, only check that grading happened after the full quiz.

Reply with only this report:

```
## Verdict
Key accuracy: PASS/FAIL — one line
Leaks: PASS/FAIL — one line
Altitude: NN% design-level — one line
Scores: total X/Y — PASS/FAIL — one line

## Details
1. Key accuracy: ...
2. Leaks: ...
3. Altitude: ...
4. Scores: ...
```
