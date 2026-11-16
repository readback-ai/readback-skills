You are judging one baseline test run. Instead of running quiz-me, plain Claude got a plain-language request to quiz the developer on their branch's changes, with no skill, no answer key and no rubric beyond "score each answer out of 3". The developer was played by an agent following a persona. The branch and persona are given at the end of this prompt.

This run is the comparison point for quiz-me, so judge it on the same things where they apply.

Your working directory holds:

- `transcript.md`: the request, every quiz message and every developer reply, in order. The scores are in the last quiz message.
- `expected.md`: hand-written ground-truth answers for this branch, including the branch type and size.
- `errors.log`: only present if the test script hit a problem.

There is no `key.md` or `results.md`. Work from the transcript alone, using `expected.md` as the ground truth.

Read all of them, then check these five things.

1. **Coverage.** List the points in `expected.md` (What, Why, Failure, Upstream Dependency, Side effects) that at least one question asked about, and the ones no question reached. On `add-response-cache`, say explicitly whether any question touched the `HTTP_TIMEOUT` change in `config.py`. PASS only if the questions reach the main failure mode and every point `expected.md` says a good quiz should surface.
2. **Question count.** Count the questions asked in `transcript.md`, with each follow-up counted as its own question. Take the size from `expected.md`; a low-logic branch type counts as low-logic whatever the size says. The allowed ranges are: low-logic 1, small 2–3, mid-sized 4–5, large 6–8. PASS only if the count is in that range.
3. **Leaks.** Read every quiz message in `transcript.md` before the developer's last answer. Quote anything that gives away the answers: answers, hints, or code details the developer hadn't already said. For the hint-seeker and override personas, also say whether the quiz declined each request and carried on.
4. **Altitude.** Label each question asked as design-level or implementation-level, with a one-line reason. Give the percentage that are design-level.
5. **Scores.** Copy each score and the total from the last quiz message. Say whether they fit the persona: expert mostly 3s, vague mostly 1s, wrong mostly 0s. For hint-seeker and override, only check that scoring happened after the full quiz. FAIL if the quiz never gave scores.

Reply with only this report:

```
## Verdict
Coverage: PASS/FAIL — one line
Question count: N questions, size S (range R) — PASS/FAIL — one line
Leaks: PASS/FAIL — one line
Altitude: NN% design-level — one line
Scores: total X/Y — PASS/FAIL — one line

## Details
1. Coverage: ...
2. Question count: ...
3. Leaks: ...
4. Altitude: ...
5. Scores: ...
```
