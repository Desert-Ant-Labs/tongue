"""Set the version everywhere it is written down, and prove none was missed.

    python3 scripts/set_version.py 0.2.0

Two artifacts carry a version (the Maven jar and the npm package), but the string
also appears in the telemetry `sdk.version` constants and in every install snippet
a reader might copy. Missing one is not cosmetic: the SDK_VERSION constants are
what the usage turnstile reports, so a stale one makes every release after the
first look like 0.1.0 in billing.

Nothing here is clever. The value is the final sweep: after rewriting, it greps
the whole repo for the old version and fails if anything still carries it, so a
new place to write the version cannot be forgotten silently.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (path, regex with one capture group around the version, description)
SITES: list[tuple[str, str, str]] = [
    ("packages/tongue-kotlin/build.gradle.kts", r'^version = "(.+)"$', "Maven artifact version"),
    ("packages/tongue-js/package.json", r'^  "version": "(.+)",$', "npm package version"),
    (
        "packages/tongue-kotlin/src/main/kotlin/ai/desertant/tongue/usage/UsageTurnstile.kt",
        r'^internal const val SDK_VERSION: String = "(.+)"$',
        "Kotlin telemetry sdk.version",
    ),
    ("packages/tongue-js/src/index.ts", r'^const SDK_VERSION = "(.+)";$', "JS telemetry sdk.version"),
    ("README.md", r'\.package\(url: "https://github\.com/Desert-Ant-Labs/tongue\.git", from: "(.+)"\)', "SwiftPM snippet"),
    ("README.md", r'· version (.+)\*', "README last-updated line"),
    ("README.md", r'implementation\("ai\.desertant:tongue:(.+)"\)', "README Gradle snippet"),
    ("llms.txt", r'verified against version (.+);', "llms.txt version statement"),
    ("llms.txt", r'from: "(.+)"', "llms.txt SwiftPM line"),
    ("llms.txt", r'ai\.desertant:tongue:(.+)`', "llms.txt Gradle line"),
    ("packages/tongue-kotlin/README.md", r'implementation\("ai\.desertant:tongue:(.+)"\)', "Gradle snippet"),
    ("Examples/TongueAndroidExample/app/build.gradle.kts", r'implementation\("ai\.desertant:tongue:(.+)"\)', "Android example dependency"),
    # Examples/TongueAndroidExample/README.md deliberately names the coordinate
    # without a version ("Until ai.desertant:tongue is on Maven Central…"), so
    # there is nothing here to rewrite. The sweep below still covers it: if a
    # version ever appears there, the run fails until it is listed.
]

# Prose that legitimately names a historical version rather than the current one.
SWEEP_EXCLUDE = {
    "PUBLISHING.md",
    "docs/USAGE.md",
    # A copy of docs/USAGE.md, shipped in the npm tarball. Its example body names
    # a version in prose, like the original.
    "packages/tongue-js/USAGE.md",
    # Comments here explain past releases by number.
    "mise.toml",
}


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"\d+\.\d+\.\d+", sys.argv[1]):
        print("usage: set_version.py X.Y.Z", file=sys.stderr)
        return 2
    version = sys.argv[1]

    previous: set[str] = set()
    for relative, pattern, description in SITES:
        path = ROOT / relative
        text = path.read_text(encoding="utf-8")
        match = re.search(pattern, text, re.MULTILINE)
        if not match:
            print(f"error: no version found in {relative} ({description})", file=sys.stderr)
            print(f"       pattern: {pattern}", file=sys.stderr)
            return 1
        old = match.group(1)
        previous.add(old)
        start, end = match.span(1)
        path.write_text(text[:start] + version + text[end:], encoding="utf-8")
        print(f"  {relative:72} {old} -> {version}")

    # Everything must have been on the same version to begin with, or one of the
    # sites had already drifted and this is the moment to say so.
    previous.discard(version)
    if len(previous) > 1:
        print(f"warning: sites were not in step before this run: {sorted(previous)}", file=sys.stderr)

    stale = sweep(previous, version)
    if stale:
        print("\nerror: the old version still appears in:", file=sys.stderr)
        for relative, line_number, line in stale:
            print(f"  {relative}:{line_number}: {line.strip()}", file=sys.stderr)
        print("\nAdd it to SITES in scripts/set_version.py, or to SWEEP_EXCLUDE if it is prose.", file=sys.stderr)
        return 1

    npm = json.loads((ROOT / "packages/tongue-js/package.json").read_text(encoding="utf-8"))
    assert npm["version"] == version, "package.json did not take the rewrite"
    print(f"\n  ai.desertant:tongue            {version}")
    print(f"  @desert-ant-labs/tongue        {version}")
    return 0


def sweep(previous: set[str], version: str) -> list[tuple[str, int, str]]:
    """Every tracked file still carrying one of the old versions."""
    if not previous:
        return []
    skip_dirs = {".git", ".build", "node_modules", "build", "dist", ".gradle"}
    # Generated and gitignored; npm rewrites it from package.json on install.
    skip_files = {"packages/tongue-js/package-lock.json"}
    hits: list[tuple[str, int, str]] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in {".md", ".kts", ".ts", ".kt", ".swift", ".json", ".toml", ".yml", ".txt"}:
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        relative = str(path.relative_to(ROOT))
        if relative in SWEEP_EXCLUDE or relative in skip_files:
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(lines, 1):
            if any(re.search(rf"(?<![\d.]){re.escape(old)}(?![\d.])", line) for old in previous):
                hits.append((relative, number, line))
    return hits


if __name__ == "__main__":
    raise SystemExit(main())
