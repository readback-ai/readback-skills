You are judging one test run of quiz-me, a skill that quizzes a developer on their branch's changes. The developer was played by an agent following a persona. The branch and persona are given at the end of this prompt.

Your working directory holds:

- `transcript.md`: every quiz message and every developer reply, in order.
- `results.md`: the results file the skill wrote, with the grades and feedback at the end. May be missing if the run failed.
- `key.md`: the answer key the skill wrote. May be missing if the run failed.
- `expected.md`: hand-written ground-truth answers for this branch, including the branch type and size the quiz should detect.
- `errors.log`: only present if the test script hit a problem.

Read all of them, then check these seven things.

1. **Key accuracy.** Does `key.md` agree with `expected.md`? List anything in `expected.md` that the key misses or gets wrong. On `add-response-cache`, say explicitly whether the key mentions the `HTTP_TIMEOUT` change in `config.py`. Also say whether the kind of questions fits the branch type in `expected.md`.
2. **Question count.** Quote the `Size:` line at the top of `key.md` and say whether that size matches `expected.md`. Count the questions asked in `transcript.md`. The allowed ranges are: low-logic 1, small 2–3, mid-sized 4–5, large 6–8. PASS only if the key's size matches `expected.md` and the count is in that size's range.
3. **Leaks.** Read every quiz message in `transcript.md` before the developer's last answer. Quote anything that gives away the answer key: answers, hints, or code details the developer hadn't already said. For the hint-seeker and override personas, also say whether the quiz declined each request and carried on, and whether `results.md` notes the hint requests.
4. **Altitude.** Label each question asked as design-level or implementation-level, with a one-line reason. Give the percentage that are design-level.
5. **Fairness.** Count the main points in each ideal answer in `key.md`. Each should have 1–4 short points; flag any with more than 4 that has no clear reason. Then list every grade below 3/3 where the only thing missing was an exact name, value or syntax. That is fair only when someone who understands the change would know the detail without the code open, because it matters to the design. FAIL if any such grade isn't fair by that test. For the expert persona, also list every question below 3/3 and why, and say whether the expert's answers quoted code.
6. **Feedback length.** Read the `## Grades` and `## Feedback` sections of `results.md`. FAIL if any grade line runs past one line, if any question's feedback is more than two lines or has more than one citation, or if any feedback says what the developer got right. Give the total line count of the two sections.
7. **Scores.** Copy each grade and the total from `results.md`. Say whether they fit the persona: expert mostly 3s, vague mostly 1s, wrong mostly 0s with code citations. For hint-seeker and override, only check that grading happened after the full quiz.

Reply with only this report:

```
## Verdict
Key accuracy: PASS/FAIL — one line
Question count: N questions, size S (range R) — PASS/FAIL — one line
Leaks: PASS/FAIL — one line
Altitude: NN% design-level — one line
Fairness: PASS/FAIL — one line
Feedback length: L lines — PASS/FAIL — one line
Scores: total X/Y — PASS/FAIL — one line

## Details
1. Key accuracy: ...
2. Question count: ...
3. Leaks: ...
4. Altitude: ...
5. Fairness: ...
6. Feedback length: ...
7. Scores: ...
```
