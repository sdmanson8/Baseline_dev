"""Count residual mojibake markers per locale after the Fix-LocaleMojibake pass."""
from __future__ import annotations

import json
from pathlib import Path

MARKERS = ("Ã", "Â", "â€", "Å", "Ð", "Ñ", "ã", "ä", "å", "æ", "ç", "è", "é", "ê", "ë", "ì", "í", "î", "ï", "ð")


def count_mojibake(obj) -> int:
    if isinstance(obj, str):
        # Only count sequences of 2+ "mojibake-looking" chars in a row,
        # so legitimate single diacritics in e.g. Afrikaans don't inflate.
        if len(obj) < 2:
            return 0
        hits = 0
        i = 0
        while i < len(obj) - 1:
            a, b = obj[i], obj[i + 1]
            if (a in MARKERS and 0x80 <= ord(b) <= 0xFF) or (0x80 <= ord(a) <= 0xFF and b in MARKERS):
                hits += 1
                i += 2
            else:
                i += 1
        return hits
    if isinstance(obj, dict):
        return sum(count_mojibake(v) for v in obj.values())
    if isinstance(obj, list):
        return sum(count_mojibake(v) for v in obj)
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
        rows.append((count_mojibake(data), p.relative_to(root).as_posix()))
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
