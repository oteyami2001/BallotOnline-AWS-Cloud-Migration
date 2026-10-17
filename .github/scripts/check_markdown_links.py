#!/usr/bin/env python3
"""Check that relative links and #anchors in Markdown files resolve.

External (http/https/mailto) links are not fetched. Anchors are compared
after GitHub-style slugging with emoji and punctuation removed.
"""
import pathlib
import re
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parents[2]
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|!\[[^\]]*\]\(([^)\s]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")


def slug(text: str) -> str:
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    out = []
    for ch in text.lower():
        cat = unicodedata.category(ch)
        if ch in " -":
            out.append("-" if ch == " " else ch)
        elif ch == "_" or cat[0] in ("L", "N"):
            out.append(ch)
    return "".join(out)


def normalize(anchor: str) -> str:
    return re.sub(r"^-+", "", anchor)


def body_lines(path: pathlib.Path):
    in_fence = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if not in_fence:
            yield line


def anchors(path: pathlib.Path) -> set:
    found, seen = set(), {}
    for line in body_lines(path):
        m = HEADING.match(line)
        if m:
            s = slug(m.group(1))
            n = seen.get(s, 0)
            seen[s] = n + 1
            found.add(normalize(s if n == 0 else f"{s}-{n}"))
    return found


def main() -> int:
    errors = []
    for md in sorted(ROOT.rglob("*.md")):
        if ".git" in md.parts:
            continue
        for line in body_lines(md):
            for m in LINK.finditer(line):
                target = m.group(1) or m.group(2)
                if re.match(r"^(https?:|mailto:)", target):
                    continue
                file_part, _, frag = target.partition("#")
                dest = md if not file_part else (md.parent / file_part).resolve()
                rel = md.relative_to(ROOT)
                if not dest.exists():
                    errors.append(f"{rel}: missing target '{target}'")
                    continue
                if frag and dest.is_file() and dest.suffix == ".md":
                    if normalize(slug(frag)) not in anchors(dest):
                        errors.append(f"{rel}: missing anchor '#{frag}' in {dest.relative_to(ROOT)}")
    for e in errors:
        print(e)
    print(f"{'FAIL' if errors else 'OK'}: {len(errors)} broken link(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
