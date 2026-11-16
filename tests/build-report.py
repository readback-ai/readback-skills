#!/usr/bin/env python3
"""Builds the overview line and the score tables for a quiz-me test session.

Usage: build-report.py <run_dir> [--main-case BRANCH] [--elapsed SECONDS]

<run_dir> is a session folder from run-tests.sh: one folder per branch, and in
each, one folder per run named <persona>-<n> (quiz-me) or <persona>-<n>-baseline
(plain Claude). Prints Markdown to stdout. run-tests.sh saves it as tables.md,
and the summary AI's notes go after it in report.md.

Totals, sizes and feedback line counts are read from the run files. Only the
question count, the design-level percentage and the PASS/FAIL checks come from
the judges' verdicts.
"""
import argparse
import re
import sys
from pathlib import Path
from statistics import mean

TESTS_DIR = Path(__file__).resolve().parent
PERSONA_ORDER = ["expert", "vague", "wrong", "hint-seeker", "override"]
RANGES = {"low-logic": (1, 1), "small": (2, 3), "mid-sized": (4, 5), "large": (6, 8)}
MODE_NAMES = {"skill": "quiz-me", "baseline": "plain Claude"}

# The same pattern as BASELINE_END in run-tests.sh: a "Total: X/Y" line, with
# any Markdown around it.
TOTAL_RE = re.compile(
    r"^[\s*_#>|-]*total( score)?[\s*_|]*:?[\s*_|]*(?P<got>\d+(?:\.\d+)?)\s*/\s*(?P<max>\d+)",
    re.I | re.M,
)
RUN_NAME_RE = re.compile(r"(?P<persona>.+)-(?P<n>\d+)(?P<baseline>-baseline)?")


def read(path):
    try:
        return Path(path).read_text(encoding="utf-8")
    except OSError:
        return ""


def section(text, name):
    """The body of the "## <name>" section, up to the next "## " heading."""
    m = re.search(rf"^## {re.escape(name)}\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def last_total(text):
    matches = list(TOTAL_RE.finditer(text))
    if not matches:
        return None
    m = matches[-1]
    return float(m.group("got")), float(m.group("max"))


class Run:
    def __init__(self, folder, branch):
        m = RUN_NAME_RE.fullmatch(folder.name)
        self.branch = branch
        self.persona = m.group("persona")
        self.n = int(m.group("n"))
        self.mode = "baseline" if m.group("baseline") else "skill"
        self.errors = [l.strip() for l in read(folder / "errors.log").splitlines() if l.strip()]

        expected = read(folder / "expected.md") or read(TESTS_DIR / "expected" / f"{branch}.md")
        self.expected_size = expected_size(expected)

        if self.mode == "skill":
            results = read(folder / "results.md")
            self.total = last_total(results)
            if results:
                body = section(results, "Grades") + section(results, "Feedback")
                self.feedback_lines = sum(1 for l in body.splitlines() if l.strip())
            else:
                self.feedback_lines = None
            m = re.search(r"^[\s*_]*Size[\s*_]*:[\s*_]*([a-z-]+)", read(folder / "key.md"), re.M | re.I)
            self.key_size = m.group(1).lower() if m else None
        else:
            # Plain Claude has no results file: the score is in its last quiz message.
            self.total = None
            for block in reversed(re.split(r"^### ", read(folder / "transcript.md"), flags=re.M)):
                if block.startswith("Quiz"):
                    self.total = last_total(block)
                    if self.total:
                        break
            self.feedback_lines = None
            self.key_size = None

        self.checks = {}  # check name -> (status or None, rest of the line, reason)
        verdict = section(read(folder / "judge-report.md"), "Verdict")
        for line in verdict.replace("**", "").splitlines():
            m = re.match(r"\s*([A-Z][A-Za-z ]+):\s*(.*)$", line)
            if not m:
                continue
            name, rest = m.group(1).strip(), m.group(2).strip()
            s = re.search(r"\b(PASS|FAIL)\b", rest)
            status = s.group(1) if s else None
            reason = rest[s.end():].lstrip(" .:—–-") if s else rest
            self.checks[name] = (status, rest, reason or rest)

        m = re.match(r"(\d+)\s+question", self.checks.get("Question count", (None, ""))[1])
        self.questions = int(m.group(1)) if m else None
        m = re.match(r"(\d+(?:\.\d+)?)\s*%", self.checks.get("Altitude", (None, ""))[1])
        self.altitude = float(m.group(1)) if m else None

    @property
    def pct(self):
        if not self.total or not self.total[1]:
            return None
        return 100 * self.total[0] / self.total[1]

    @property
    def in_range(self):
        r = RANGES.get(self.expected_size)
        if r is None or self.questions is None:
            return None
        return r[0] <= self.questions <= r[1]

    def failures(self):
        rows = [(name, reason) for name, (status, _, reason) in self.checks.items() if status == "FAIL"]
        rows += [("errors.log", e) for e in self.errors]
        return rows


def expected_size(text):
    btype = re.search(r"\*\*Branch type:\*\*\s*([a-z-]+)", text, re.I)
    if btype and btype.group(1).lower() == "low-logic":
        return "low-logic"  # quiz-me asks one question on low-logic branches, whatever the size.
    size = re.search(r"\*\*Size:\*\*\s*([a-z-]+)", text, re.I)
    return size.group(1).lower() if size else None


# --- formatting --------------------------------------------------------------

DASH = "—"


def num(x):
    return f"{x:g}"


def fmt_total(run):
    if run is None or run.total is None:
        return DASH
    return f"{num(run.total[0])}/{num(run.total[1])}"


def fmt_pct(x):
    return DASH if x is None else f"{x:.0f}%"


def fmt(x):
    if x is None:
        return DASH
    if x is True:
        return "yes"
    if x is False:
        return "no"
    return str(x)


def cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    out += ["| " + " | ".join(cell(c) for c in row) + " |" for row in rows]
    return "\n".join(out)


def plural(n, word, many=None):
    return f"{n} {word if n == 1 else (many or word + 's')}"


def elapsed(seconds):
    return f"{seconds // 60}m {seconds % 60}s"


def persona_key(p):
    return (PERSONA_ORDER.index(p) if p in PERSONA_ORDER else len(PERSONA_ORDER), p)


# --- the report ----------------------------------------------------------------


def load_runs(run_dir):
    runs = []
    for branch_dir in sorted(p for p in run_dir.iterdir() if p.is_dir()):
        for folder in sorted(p for p in branch_dir.iterdir() if p.is_dir()):
            if RUN_NAME_RE.fullmatch(folder.name):
                runs.append(Run(folder, branch_dir.name))
    return runs


def ordering(runs, main_case, mode):
    """Whether expert > vague > wrong holds on the means and in every run."""
    by_persona = {}
    for r in runs:
        if r.branch == main_case and r.mode == mode and r.pct is not None:
            by_persona.setdefault(r.persona, {})[r.n] = r.pct
    trio = ["expert", "vague", "wrong"]
    missing = [p for p in trio if p not in by_persona]
    if missing:
        return None, f"can't tell: no scored {' or '.join(missing)} runs", None
    means = [mean(by_persona[p].values()) for p in trio]
    on_means = means[0] > means[1] > means[2]
    means_text = f"{'holds' if on_means else 'does not hold'} ({', '.join(f'{p} {fmt_pct(m)}' for p, m in zip(trio, means))})"

    common = sorted(set.intersection(*(set(by_persona[p]) for p in trio)))
    bad = [n for n in common if not by_persona["expert"][n] > by_persona["vague"][n] > by_persona["wrong"][n]]
    every_text = f"holds in {len(common) - len(bad)} of {plural(len(common), 'run')}"
    if bad:
        every_text += f" (not in run {', '.join(str(n) for n in bad)})"
    return on_means, means_text, every_text


def build(run_dir, main_case, seconds):
    runs = load_runs(run_dir)
    modes = ["skill", "baseline"] if any(r.mode == "baseline" for r in runs) else ["skill"]
    both = len(modes) == 2

    cases = {}
    for r in runs:
        cases.setdefault((r.branch, r.persona, r.n), {})[r.mode] = r
    keys = sorted(cases, key=lambda k: (k[0], persona_key(k[1]), k[2]))

    def pair(case, f):
        """One cell per mode, joined by " / " in a with/without column."""
        return " / ".join(f(case.get(m)) for m in modes)

    out = []

    # Overview line.
    counts = {m: sum(1 for r in runs if r.mode == m) for m in modes}
    fails = {m: sum(len([c for c in r.checks.values() if c[0] == "FAIL"]) for r in runs if r.mode == m) for m in modes}
    errored = sum(1 for r in runs if r.errors)
    line = f"**quiz-me test session {run_dir.name}:** {plural(len(runs), 'run')}"
    if both:
        line += f" ({counts['skill']} with quiz-me, {counts['baseline']} plain Claude)"
    line += f" on {plural(len({r.branch for r in runs}), 'branch', 'branches')}"
    if seconds is not None:
        line += f" in {elapsed(seconds)}"
    line += f". quiz-me failed {plural(fails['skill'], 'check')}"
    if both:
        line += f" and plain Claude failed {fails['baseline']}"
    line += "."
    if errored:
        line += f" {plural(errored, 'run')} logged errors."
    holds = {m: ordering(runs, main_case, m)[0] for m in modes}
    if holds["skill"] is not None:
        line += f" Expert > vague > wrong {'holds' if holds['skill'] else 'does not hold'} on the means with quiz-me"
        if both and holds["baseline"] is not None:
            line += f" and {'holds' if holds['baseline'] else 'does not hold'} without it"
        line += "."
    out += [line, ""]

    # Scores table.
    out += ["## Scores", ""]
    if both:
        headers = ["Branch", "Persona", "Run", "With skill", "Without skill", "Questions (with / without)",
                   "Expected size", "Key size", "In range (with / without)", "Feedback lines"]
    else:
        headers = ["Branch", "Persona", "Run", "Total", "Questions", "Expected size", "Key size", "In range",
                   "Feedback lines"]
    rows = []
    for k in keys:
        c = cases[k]
        any_run = next(iter(c.values()))
        skill = c.get("skill")
        row = [k[0], k[1], k[2]]
        row += [fmt_total(c.get(m)) for m in modes]
        row += [pair(c, lambda r: fmt(r.questions if r else None))]
        row += [fmt(any_run.expected_size), fmt(skill.key_size if skill else None)]
        row += [pair(c, lambda r: fmt(r.in_range if r else None))]
        row += [fmt(skill.feedback_lines if skill else None)]
        rows.append(row)
    out += [table(headers, rows), ""]
    out += ["_Totals, sizes and feedback lines come from the run files. Question counts come from the judges. "
            "In range compares the question count with the expected size._", ""]

    # Score ordering on the main case.
    out += [f"## Score ordering ({main_case})", ""]
    personas = sorted({r.persona for r in runs if r.branch == main_case}, key=persona_key)
    if personas:
        headers = ["Persona"]
        for m in modes:
            label = {"skill": "with skill", "baseline": "without skill"}[m] if both else ""
            headers += [f"Mean {label}".strip(), f"Spread {label}".strip()]
        rows = []
        for p in personas:
            row = [p]
            for m in modes:
                pcts = [r.pct for r in runs if r.branch == main_case and r.persona == p and r.mode == m
                        and r.pct is not None]
                row += [fmt_pct(mean(pcts)) if pcts else DASH,
                        f"{min(pcts):.0f}–{max(pcts):.0f}%" if pcts else DASH]
            rows.append(row)
        out += [table(headers, rows), "", "_Scores are a percentage of each run's maximum._", ""]
        for title, idx in (("Expert > vague > wrong on the means", 1), ("In every run", 2)):
            parts = []
            for m in modes:
                text = ordering(runs, main_case, m)[idx] or ordering(runs, main_case, m)[1]
                parts.append(f"{MODE_NAMES[m]} {text}" if both else text)
            out.append(f"- **{title}:** {'; '.join(parts)}.")
        out.append("")
    else:
        out += [f"No runs on {main_case}.", ""]

    # Altitude.
    out += ["## Altitude", ""]
    headers = ["Branch", "Persona", "Run"] + (["With skill", "Without skill"] if both else ["Design-level"])
    rows = [[k[0], k[1], k[2]] + [fmt_pct(cases[k][m].altitude if m in cases[k] else None) for m in modes]
            for k in keys]
    out += [table(headers, rows), ""]
    if personas:
        parts = []
        for m in modes:
            vals = [r.altitude for r in runs if r.branch == main_case and r.mode == m and r.altitude is not None]
            text = f"{fmt_pct(mean(vals))} (at least 80%: {'yes' if mean(vals) >= 80 else 'no'})" if vals else DASH
            parts.append(f"{MODE_NAMES[m]} {text}" if both else text)
        out += [f"- **Average on {main_case}:** {'; '.join(parts)}.", ""]

    # Failures.
    out += ["## Failures", ""]
    rows = []
    for k in keys:
        for m in modes:
            r = cases[k].get(m)
            for name, reason in (r.failures() if r else []):
                rows.append([k[0], k[1], k[2]] + ([MODE_NAMES[m]] if both else []) + [name, reason])
    if rows:
        headers = ["Branch", "Persona", "Run"] + (["Mode"] if both else []) + ["Check", "Reason"]
        out += [table(headers, rows)]
    else:
        out += ["None."]
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("run_dir", type=Path)
    ap.add_argument("--main-case", default="add-response-cache")
    ap.add_argument("--elapsed", type=int, help="session length in seconds, for the overview line")
    args = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stdout.write(build(args.run_dir, args.main_case, args.elapsed))


if __name__ == "__main__":
    main()
