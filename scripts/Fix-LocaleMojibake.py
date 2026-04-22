"""
Repair double-encoded UTF-8 in Localizations/**/*.json.

Mechanism: strings whose bytes were UTF-8 but read as Windows-1252/Latin-1 and
re-saved as UTF-8 end up with markers like 'Ã', 'Â', 'â€'. Running
    s.encode('latin-1').decode('utf-8')
reverses the damage exactly — but only when every character in the string has
a codepoint <= 0xFF (i.e. the string really is a Latin-1-interpreted view of
UTF-8 bytes). Strings that contain CJK, Cyrillic, Arabic, Devanagari, etc.
will raise UnicodeEncodeError on .encode('latin-1') and be left untouched.

Gate: we only *attempt* the fix when the original contains a mojibake marker,
so correctly-encoded text is never modified even if it happens to be Latin-1
safe.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

MARKERS = ("Ã", "Â", "â€", "#U00", "#x00", "Ã¢â‚¬")


def looks_like_mojibake(s: str) -> bool:
    return any(m in s for m in MARKERS)


def _decode_once(s: str) -> str | None:
    # Try cp1252 first (handles smart quotes, Å‘, Å½, etc.), then fall back
    # to latin-1 for strings whose bytes fit pure ISO-8859-1.
    for codec in ("cp1252", "latin-1"):
        try:
            recovered = s.encode(codec).decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
        if recovered != s:
            return recovered
    return None


def try_fix(s: str) -> str | None:
    current = s
    for _ in range(4):  # bounded in case of double-double encoding
        recovered = _decode_once(current)
        if recovered is None:
            break
        current = recovered
        if not looks_like_mojibake(current):
            break
    if current == s:
        return None
    return current


def walk(obj, path_log):
    if isinstance(obj, dict):
        fixed = 0
        for k, v in obj.items():
            fixed += walk_key(obj, k, v, path_log + [k])
        return fixed
    if isinstance(obj, list):
        fixed = 0
        for i, v in enumerate(obj):
            fixed += walk_key(obj, i, v, path_log + [str(i)])
        return fixed
    return 0


def is_plausible_fix(original: str, recovered: str) -> bool:
    # Reject replacement character — means decode was lossy.
    if "�" in recovered:
        return False
    # Require the original to have at least two high-bit characters
    # (otherwise it's likely clean ASCII-adjacent text whose bytes happen
    #  to be a coincidental UTF-8 sequence).
    high = sum(1 for c in original if ord(c) >= 0x80)
    if high < 2:
        return False
    return True


def walk_key(container, key, value, path_log):
    if isinstance(value, str):
        fixed = try_fix(value)
        if fixed is None or fixed == value:
            return 0
        if not is_plausible_fix(value, fixed):
            return 0
        container[key] = fixed
        return 1
    if isinstance(value, (dict, list)):
        return walk(value, path_log)
    return 0


def main():
    repo_root = Path(__file__).resolve().parent.parent
    loc_dir = repo_root / "Localizations"
    if not loc_dir.is_dir():
        print(f"ERROR: {loc_dir} not found", file=sys.stderr)
        sys.exit(2)

    total_files_changed = 0
    total_strings_fixed = 0
    per_file_report = []

    for json_path in sorted(loc_dir.rglob("*.json")):
        raw = json_path.read_text(encoding="utf-8")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            print(f"SKIP {json_path.relative_to(repo_root)}: JSON error {exc}")
            continue

        fixes = walk(data, [])
        if fixes == 0:
            continue

        new_text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        json_path.write_text(new_text, encoding="utf-8")
        total_files_changed += 1
        total_strings_fixed += fixes
        per_file_report.append((fixes, json_path.relative_to(repo_root).as_posix()))

    per_file_report.sort(reverse=True)
    for count, name in per_file_report:
        print(f"  {count:>5}  {name}")
    print(f"\nFiles changed: {total_files_changed}")
    print(f"Strings fixed: {total_strings_fixed}")


if __name__ == "__main__":
    main()
