#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SKILL_ROOT = Path(__file__).resolve().parents[1]
TEMPLATES_DIR = SKILL_ROOT / "assets" / "templates"


class RmmError(RuntimeError):
    pass


def eprint(*args: object) -> None:
    print(*args, file=sys.stderr)


def normalize_kebab(raw: str) -> str:
    value = raw.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    value = re.sub(r"-{2,}", "-", value)
    if not value:
        raise RmmError(f"Invalid name '{raw}': produced an empty filename after normalization")
    return value


def validate_output_var(output_var: str) -> str:
    output_var = output_var.strip()
    if not re.fullmatch(r"[A-Za-z0-9_]+", output_var):
        raise RmmError(
            f"Invalid --output-var '{output_var}'. Use only letters, digits, and underscore (example: Status)."
        )
    return output_var


def category_dir(category: str) -> str:
    mapping = {
        "applications": "Applications",
        "scripts": "Scripts",
        "monitors": "Monitors",
    }
    try:
        return mapping[category]
    except KeyError as exc:
        raise RmmError(f"Unknown category: {category}") from exc


def os_dir(os_name: str) -> str:
    mapping = {
        "windows": "Windows",
        "macos": "macOS",
        "linux": "Linux",
    }
    try:
        return mapping[os_name]
    except KeyError as exc:
        raise RmmError(f"Unknown OS: {os_name}") from exc


def template_path(os_name: str, category: str) -> Path:
    if os_name == "windows":
        return {
            "applications": TEMPLATES_DIR / "powershell-application.ps1.tmpl",
            "scripts": TEMPLATES_DIR / "powershell-script.ps1.tmpl",
            "monitors": TEMPLATES_DIR / "powershell-monitor.ps1.tmpl",
        }[category]
    return {
        "applications": TEMPLATES_DIR / "bash-application.sh.tmpl",
        "scripts": TEMPLATES_DIR / "bash-script.sh.tmpl",
        "monitors": TEMPLATES_DIR / "bash-monitor.sh.tmpl",
    }[category]


def destination_path(os_name: str, category: str, filename: str) -> Path:
    cat_dir = category_dir(category)
    if os_name == "windows":
        return REPO_ROOT / "components" / cat_dir / f"{filename}.ps1"
    if os_name == "macos":
        return REPO_ROOT / "components" / cat_dir / "macOS" / f"{filename}.sh"
    if os_name == "linux":
        return REPO_ROOT / "components" / cat_dir / "Linux" / f"{filename}.sh"
    raise RmmError(f"Unknown OS: {os_name}")


def render_template(template_text: str, substitutions: dict[str, str]) -> str:
    rendered = template_text
    for key, value in substitutions.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
    return rendered


def ensure_parent_dir(path: Path, dry_run: bool) -> None:
    if dry_run:
        return
    path.parent.mkdir(parents=True, exist_ok=True)


def copy_attachments(attachments_dir: Path, workdir: Path) -> None:
    if not attachments_dir.exists() or not attachments_dir.is_dir():
        raise RmmError(f"--attachments must be a directory: {attachments_dir}")
    for child in attachments_dir.iterdir():
        if child.is_file():
            shutil.copy2(child, workdir / child.name)


def parse_env_file(env_path: Path) -> dict[str, str]:
    if not env_path.exists():
        raise RmmError(f"--vars file not found: {env_path}")
    env: dict[str, str] = {}
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            raise RmmError(f"Invalid env line (expected KEY=VALUE): {raw_line}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            raise RmmError(f"Invalid env line (empty key): {raw_line}")
        if value.startswith(("'", '"')):
            try:
                # shlex handles simple quoted strings and escapes
                parsed = shlex.split(value, posix=True)
                if len(parsed) == 1:
                    value = parsed[0]
            except ValueError:
                # Fall back to raw value if quoting is malformed
                pass
        env[key] = value
    return env


@dataclass(frozen=True)
class MonitorValidationResult:
    ok: bool
    errors: list[str]


def validate_monitor_output(text: str, output_var: str) -> MonitorValidationResult:
    errors: list[str] = []
    output_var = validate_output_var(output_var)

    lines = text.splitlines()

    def find_all(marker: str) -> list[int]:
        return [idx for idx, line in enumerate(lines) if line.strip() == marker]

    diag_start = find_all("<-Start Diagnostic->")
    diag_end = find_all("<-End Diagnostic->")
    res_start = find_all("<-Start Result->")
    res_end = find_all("<-End Result->")

    if len(diag_start) != 1:
        errors.append("Expected exactly one '<-Start Diagnostic->' line.")
    if len(diag_end) != 1:
        errors.append("Expected exactly one '<-End Diagnostic->' line.")
    if len(res_start) != 1:
        errors.append("Expected exactly one '<-Start Result->' line.")
    if len(res_end) != 1:
        errors.append("Expected exactly one '<-End Result->' line.")

    if errors:
        return MonitorValidationResult(ok=False, errors=errors)

    ds, de, rs, re_ = diag_start[0], diag_end[0], res_start[0], res_end[0]
    if not (ds < de < rs < re_):
        errors.append(
            "Marker order must be: Start Diagnostic -> End Diagnostic -> Start Result -> End Result."
        )
        return MonitorValidationResult(ok=False, errors=errors)

    result_lines = [line.rstrip("\n") for line in lines[rs + 1 : re_]]
    non_empty = [ln for ln in result_lines if ln.strip() != ""]
    if not non_empty:
        errors.append("Result block is empty; expected one output variable line.")
        return MonitorValidationResult(ok=False, errors=errors)

    pattern = re.compile(rf"^{re.escape(output_var)}=.+$")
    matching = [ln for ln in non_empty if pattern.match(ln)]
    if len(matching) != 1:
        errors.append(
            f"Expected exactly one '{output_var}=...' line inside the result block; found {len(matching)}."
        )
        errors.append("Example: Status=OK: All checks passed")
        return MonitorValidationResult(ok=False, errors=errors)

    other_lines = [ln for ln in non_empty if ln is not matching[0]]
    if other_lines:
        errors.append("Result block must contain exactly one non-empty line (the output variable line).")
        errors.append(f"Unexpected additional lines: {other_lines}")
        return MonitorValidationResult(ok=False, errors=errors)

    value = matching[0][len(output_var) + 1 :]
    if value[:1].isspace():
        errors.append("Do not include spaces around '=' (use 'Status=OK: ...', not 'Status= OK: ...').")
        return MonitorValidationResult(ok=False, errors=errors)

    return MonitorValidationResult(ok=True, errors=[])


def cmd_scaffold(args: argparse.Namespace) -> int:
    os_name: str = args.os
    category: str = args.category
    raw_name: str = args.name
    output_var: str = args.output_var
    force: bool = args.force
    dry_run: bool = args.dry_run

    filename = normalize_kebab(raw_name)
    if category == "monitors":
        output_var = validate_output_var(output_var)

    dest = destination_path(os_name=os_name, category=category, filename=filename)
    tmpl_path = template_path(os_name=os_name, category=category)

    if not tmpl_path.exists():
        raise RmmError(f"Template not found: {tmpl_path}")

    if dest.exists() and not force:
        raise RmmError(f"Refusing to overwrite existing file: {dest} (use --force to overwrite)")

    subs = {
        "NAME": raw_name.strip() or filename,
        "FILENAME": filename,
        "CATEGORY": category_dir(category),
        "OS": os_dir(os_name),
        "OUTPUT_VAR": output_var,
        "VERSION": args.version,
    }
    rendered = render_template(tmpl_path.read_text(encoding="utf-8"), subs)

    print(f"Repo root: {REPO_ROOT}")
    print(f"Template:  {tmpl_path.relative_to(REPO_ROOT)}")
    print(f"Target:    {dest.relative_to(REPO_ROOT)}")

    if dry_run:
        print("Dry run: not writing files.")
        return 0

    ensure_parent_dir(dest, dry_run=False)
    dest.write_text(rendered, encoding="utf-8")
    if dest.suffix == ".sh":
        dest.chmod(0o755)

    print("")
    print("Next steps:")
    print(f"- Edit: {dest.relative_to(REPO_ROOT)}")
    print(
        f"- Run locally: python3 {Path('skills/datto-rmm-component-dev/scripts/rmm.py')} run --script {dest.relative_to(REPO_ROOT)}"
    )
    if category == "monitors":
        print(
            f"- Validate output: python3 {Path('skills/datto-rmm-component-dev/scripts/rmm.py')} run --script {dest.relative_to(REPO_ROOT)} --validate-monitor --output-var {output_var}"
        )
        print(f"- Ensure Datto monitor Output Variable is set to: {output_var}")

    return 0


def cmd_validate_monitor_output(args: argparse.Namespace) -> int:
    output_var = args.output_var
    if args.input == "-":
        text = sys.stdin.read()
        source = "<stdin>"
    else:
        path = Path(args.input)
        text = path.read_text(encoding="utf-8", errors="replace")
        source = str(path)

    result = validate_monitor_output(text, output_var=output_var)
    if result.ok:
        print(f"OK: Monitor output is valid ({source})")
        return 0

    eprint(f"INVALID: Monitor output failed validation ({source})")
    for err in result.errors:
        eprint(f"- {err}")
    return 2


def cmd_run(args: argparse.Namespace) -> int:
    script_path = Path(args.script)
    if not script_path.is_absolute():
        script_path = (REPO_ROOT / script_path).resolve()
    if not script_path.exists():
        raise RmmError(f"--script not found: {script_path}")

    output_var = args.output_var

    workdir = Path(args.workdir).resolve() if args.workdir else Path(tempfile.mkdtemp(prefix="rmm-run-"))
    workdir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    if args.vars:
        env.update(parse_env_file(Path(args.vars)))

    if args.attachments:
        copy_attachments(Path(args.attachments), workdir)

    stdout_path = workdir / "stdout.txt"
    stderr_path = workdir / "stderr.txt"

    if script_path.suffix.lower() == ".ps1":
        cmd = ["pwsh", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(script_path)]
    elif script_path.suffix.lower() == ".sh":
        cmd = ["bash", str(script_path)]
    else:
        raise RmmError(f"Unsupported script extension: {script_path.suffix}")

    print(f"Workdir: {workdir}")
    print(f"Script:  {script_path}")
    print(f"Cmd:     {' '.join(shlex.quote(c) for c in cmd)}")

    try:
        with stdout_path.open("wb") as stdout_f, stderr_path.open("wb") as stderr_f:
            proc = subprocess.run(
                cmd,
                cwd=str(workdir),
                env=env,
                stdout=stdout_f,
                stderr=stderr_f,
                check=False,
            )
    except FileNotFoundError as exc:
        raise RmmError(f"Command not found: {cmd[0]} (install it and try again)") from exc

    print(f"Exit code: {proc.returncode}")
    print(f"Stdout:    {stdout_path}")
    print(f"Stderr:    {stderr_path}")

    should_validate = bool(args.validate_monitor)
    if not should_validate and "Monitors" in script_path.parts:
        should_validate = True

    if should_validate:
        stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
        validation = validate_monitor_output(stdout_text, output_var=output_var)
        if validation.ok:
            print(f"Monitor output: OK ({output_var}=...)")
        else:
            eprint(f"Monitor output: INVALID (expected '{output_var}=...')")
            for err in validation.errors:
                eprint(f"- {err}")
            # If the script itself already failed, keep its exit code. Otherwise, surface validation failure.
            if proc.returncode == 0:
                return 2

    return proc.returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="rmm.py", description="Datto RMM component helper (repo-patterned)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    scaffold = sub.add_parser("scaffold", help="Scaffold a new component file from templates")
    scaffold.add_argument("--os", required=True, choices=["windows", "macos", "linux"])
    scaffold.add_argument("--category", required=True, choices=["applications", "scripts", "monitors"])
    scaffold.add_argument("--name", required=True, help="Component name (normalized to kebab-case filename)")
    scaffold.add_argument("--output-var", default="Status", help="Monitor output variable name (default: Status)")
    scaffold.add_argument("--version", default="0.1.0", help="Component build/version placeholder")
    scaffold.add_argument("--force", action="store_true", help="Overwrite an existing file if present")
    scaffold.add_argument("--dry-run", action="store_true", help="Print intended actions without writing files")
    scaffold.set_defaults(func=cmd_scaffold)

    run = sub.add_parser("run", help="Run a component locally and capture stdout/stderr")
    run.add_argument("--script", required=True, help="Path to .ps1 or .sh (relative to repo root or absolute)")
    run.add_argument("--vars", help="Path to .env-style KEY=VALUE file to inject into environment")
    run.add_argument("--workdir", help="Working directory for execution (default: temp dir)")
    run.add_argument("--attachments", help="Directory of files to copy into workdir (simulate Datto attachments)")
    run.add_argument("--validate-monitor", action="store_true", help="Validate monitor markers/output line")
    run.add_argument("--output-var", default="Status", help="Monitor output variable name (default: Status)")
    run.set_defaults(func=cmd_run)

    validate = sub.add_parser("validate-monitor-output", help="Validate Datto monitor output markers and result line")
    validate.add_argument(
        "--input",
        required=True,
        help="File path to validate, or '-' to read from stdin",
    )
    validate.add_argument("--output-var", default="Status", help="Monitor output variable name (default: Status)")
    validate.set_defaults(func=cmd_validate_monitor_output)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except RmmError as exc:
        eprint(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
