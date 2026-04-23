"""Count residual mojibake per locale after Fix-LocaleMojibake.

A string is "mojibake-looking" only if it contains a high-confidence signature:
a cp1252/latin-1 re-encode of plausible UTF-8 bytes. We re-encode the string
through cp1252 (with our 5-byte pass-through patch) and check whether the
resulting byte stream *validly decodes as UTF-8*. If it does — and the decoded
form differs from the original — the string is still double-encoded. Pure
native-diacritic text (é, ñ, ç, ä...) will encode to cp1252 cleanly but the
bytes won't form a valid UTF-8 multi-byte sequence, so it won't false-positive.
"""
from __future__ import annotations

import json
from pathlib import Path

CP1252_PASSTHROUGH = {0x81, 0x8D, 0x8F, 0x90, 0x9D}


def _encode_cp1252_permissive(s: str) -> bytes:
    out = bytearray()
    for c in s:
        cp = ord(c)
        if cp in CP1252_PASSTHROUGH:
            out.append(cp)
        else:
            out.extend(c.encode("cp1252"))
    return bytes(out)


def is_mojibake(s: str) -> bool:
    if not s or "�" in s:
        return "�" in s  # U+FFFD always counts as damage
    try:
        b = _encode_cp1252_permissive(s)
    except UnicodeEncodeError:
        return False
    try:
        recovered = b.decode("utf-8")
    except UnicodeDecodeError:
        return False
    if recovered == s:
        return False
    # Require at least two high-bit chars to avoid coincidental ASCII-adjacent
    # inputs that happen to form a valid UTF-8 decode.
    if sum(1 for c in s if ord(c) >= 0x80) < 2:
        return False
    return True


def count_in(obj) -> int:
    if isinstance(obj, str):
        return 1 if is_mojibake(obj) else 0
    if isinstance(obj, dict):
        return sum(count_in(v) for v in obj.values())
    if isinstance(obj, list):
        return sum(count_in(v) for v in obj)
    return 0


def main():
    root = Path(__file__).resolve().parent.parent
    loc = root / "Localizations"
    rows = []
    for p in sorted(loc.rglob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        rows.append((count_in(data), p.relative_to(root).as_posix()))
    rows.sort(reverse=True)
    residual = [r for r in rows if r[0] > 0]
    clean = [r for r in rows if r[0] == 0]
    print(f"Clean locales: {len(clean)}")
    print(f"Locales with residual mojibake: {len(residual)}")
    print()
    for count, name in residual:
        print(f"  {count:>5}  {name}")


if __name__ == "__main__":
    main()
