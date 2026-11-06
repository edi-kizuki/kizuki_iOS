#!/usr/bin/env python3
"""G13 workflow credential isolation. Related: [[014-b03-environment-pinning]]."""
from pathlib import Path
import sys
import yaml
from remote.kz_guard import DENIED_REFS
ROOT = Path(__file__).resolve().parents[1]
TOKEN = "SUPABASE_" + "ACCESS_TOKEN"
ASSERTION = 'test -z "${' + TOKEN + '+x}"'


def check_text(text):
    problems = []
    if any(ref in text.lower() for ref in DENIED_REFS): problems.append("denied ref in workflow")
    if TOKEN in text.replace(ASSERTION, ""): problems.append("management token reference")
    try:
        # BaseLoader keeps YAML's 'on' key a string (YAML 1.1 bool coercion is unsafe here).
        workflow = yaml.load(text, Loader=yaml.BaseLoader)
        events = workflow.get("on", {})
        if isinstance(events, str): events = [events]
        for name, job in workflow.get("jobs", {}).items():
            environment = job.get("environment", "")
            if isinstance(environment, dict): environment = environment.get("name", "")
            if environment:
                if environment != "staging" or set(events) != {"workflow_dispatch"}:
                    problems.append("environment exposed outside manual staging workflow")
                if "github.ref == 'refs/heads/main'" not in job.get("if", ""):
                    problems.append("staging requires main guard")
            steps = job.get("steps", [])
            if not any(step.get("run", "").strip() == ASSERTION for step in steps):
                problems.append("missing token absence assertion: " + name)
    except Exception: problems.append("invalid workflow")
    return problems


def check(root=ROOT):
    return [str(path.relative_to(root)) + ": " + error
            for path in (root / ".github/workflows").glob("*.y*ml") for error in check_text(path.read_text())]


if __name__ == "__main__":
    problems = check()
    print("\n".join(problems) if problems else "Workflow credential policy OK.")
    sys.exit(bool(problems))
