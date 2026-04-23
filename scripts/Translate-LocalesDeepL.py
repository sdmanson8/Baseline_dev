"""
Re-translate locale files using DeepL, preserving placeholders like {0}, {1}, %s.

Modes:
  default  translate only strings that still contain residual mojibake markers
  --full   translate every key from the en-US source (ignores current content)

Env:
  DEEPL_API_KEY   required. If it ends in ':fx' the free endpoint is used.

Usage:
  python scripts/Translate-LocalesDeepL.py --dry-run
  python scripts/Translate-LocalesDeepL.py --locales el,ja,uk,bg,th,ru,ko,ar
  python scripts/Translate-LocalesDeepL.py --locales ru --full

Placeholder preservation:
  {0}, {1}, ... and %s, %d, %1$s are wrapped in <x>...</x> before sending and
  unwrapped after. DeepL is told to ignore <x> via tag_handling=xml ignore_tags=x.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# Locale directory name -> DeepL target language code.
# Only entries that DeepL actually supports as targets.
LOCALE_TO_DEEPL = {
    "Arabic": "AR",
    "Bulgarian": "BG",
    "Chinese (Simplified)": "ZH-HANS",
    "Chinese (Traditional)": "ZH-HANT",
    "Czech": "CS",
    "Danish": "DA",
    "Dutch": "NL",
    "Dutch (Belgium)": "NL",
    "Estonian": "ET",
    "Finnish": "FI",
    "French": "FR",
    "French (Canada)": "FR",
    "German": "DE",
    "Greek": "EL",
    "Hebrew": "HE",
    "Hungarian": "HU",
    "Indonesian": "ID",
    "Italian": "IT",
    "Japanese": "JA",
    "Korean": "KO",
    "Latvian": "LV",
    "Lithuanian": "LT",
    "Norwegian Bokmål": "NB",
    "Polish": "PL",
    "Portuguese": "PT-PT",
    "Portuguese (Brazil)": "PT-BR",
    "Romanian": "RO",
    "Russian": "RU",
    "Slovak": "SK",
    "Slovenian": "SL",
    "Spanish": "ES",
    "Spanish (Mexico)": "ES-419",
    "Swedish": "SV",
    "Thai": "TH",
    "Turkish": "TR",
    "Ukrainian": "UK",
    "Vietnamese": "VI",
}

# Filename stem -> locale dir, built by scanning. Users pass either the two/three
# letter code (el, ja, uk...) or the dir name on --locales.
MOJIBAKE_MARKERS = ("Ã", "Â", "â€", "Å", "Ð", "Ñ")

PLACEHOLDER_RE = re.compile(
    r"""
    (\{[0-9]+(?::[^}]*)?\})        |   # .NET-style {0}, {0:N2}
    (%[0-9]*\$?[sdifxX%])          |   # printf %s %1$s %d
    (\{\{[^}]+\}\})                    # mustache-ish {{name}}
    """,
    re.VERBOSE,
)


def needs_translation(value: str) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    return any(m in value for m in MOJIBAKE_MARKERS) or "�" in value


def wrap_placeholders(s: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def repl(m: re.Match) -> str:
        tokens.append(m.group(0))
        return f"<x id=\"{len(tokens) - 1}\"/>"

    return PLACEHOLDER_RE.sub(repl, s), tokens


def unwrap_placeholders(s: str, tokens: list[str]) -> str:
    def repl(m: re.Match) -> str:
        idx = int(m.group(1))
        if 0 <= idx < len(tokens):
            return tokens[idx]
        return m.group(0)

    # DeepL may echo back with self-closing or paired tags.
    s = re.sub(r"<x\s+id=\"(\d+)\"\s*/>", repl, s)
    s = re.sub(r"<x\s+id=\"(\d+)\"\s*>\s*</x>", repl, s)
    return s


class DeepLClient:
    def __init__(self, api_key: str):
        self.api_key = api_key
        host = "api-free.deepl.com" if api_key.endswith(":fx") else "api.deepl.com"
        self.endpoint = f"https://{host}/v2/translate"

    def translate_batch(self, texts: list[str], target: str) -> list[str]:
        # DeepL accepts multiple text[] params per request. Keep batches modest
        # so a bad input doesn't kill the whole run.
        data_pairs = [("target_lang", target), ("tag_handling", "xml"),
                      ("ignore_tags", "x"), ("preserve_formatting", "1")]
        data_pairs += [("text", t) for t in texts]
        body = urllib.parse.urlencode(data_pairs).encode("utf-8")
        req = urllib.request.Request(
            self.endpoint,
            data=body,
            headers={
                "Authorization": f"DeepL-Auth-Key {self.api_key}",
                "Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "Baseline-Locale-Retranslate/1.0",
            },
            method="POST",
        )
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=60) as resp:
                    payload = json.loads(resp.read().decode("utf-8"))
                return [item["text"] for item in payload["translations"]]
            except urllib.error.HTTPError as e:
                if e.code in (429, 503) and attempt < 4:
                    time.sleep(2 ** attempt)
                    continue
                body_text = e.read().decode("utf-8", errors="replace")
                raise RuntimeError(f"DeepL {e.code}: {body_text}") from e
            except urllib.error.URLError as e:
                if attempt < 4:
                    time.sleep(2 ** attempt)
                    continue
                raise RuntimeError(f"DeepL network error: {e}") from e
        raise RuntimeError("DeepL retries exhausted")


def collect_candidates(en_data: dict, target_data: dict, full: bool) -> list[str]:
    """Return the list of keys that need translating for this locale."""
    keys = []
    for k, v_en in en_data.items():
        if not isinstance(v_en, str):
            continue
        v_cur = target_data.get(k)
        if full:
            keys.append(k)
        elif isinstance(v_cur, str) and needs_translation(v_cur):
            keys.append(k)
        elif k not in target_data:
            keys.append(k)
    return keys


def find_locale_file(loc_dir: Path, selector: str) -> Path | None:
    selector = selector.strip().lower()
    # Match by DeepL code (el, ja, ...), by xml:lang file stem (el-GR), or dir.
    for sub in loc_dir.iterdir():
        if not sub.is_dir():
            continue
        json_files = list(sub.glob("*.json"))
        if not json_files:
            continue
        jf = json_files[0]
        stem = jf.stem.lower()
        if selector == stem:
            return jf
        if stem.split("-", 1)[0] == selector:
            return jf
        if sub.name.lower() == selector:
            return jf
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--locales", help="Comma-separated list (default: all DeepL-supported)")
    ap.add_argument("--full", action="store_true", help="Retranslate every key, not just broken ones")
    ap.add_argument("--dry-run", action="store_true", help="Report char count without calling DeepL")
    ap.add_argument("--batch", type=int, default=40, help="Strings per DeepL request")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    loc_dir = repo_root / "Localizations"
    en_file = loc_dir / "English (United States)" / "en-US.json"
    en_data = json.loads(en_file.read_text(encoding="utf-8"))

    if args.locales:
        wanted = [s.strip() for s in args.locales.split(",") if s.strip()]
    else:
        # Default: iterate the dirname keys so every DeepL-supported locale
        # dir gets processed exactly once (even when two dirs share a target,
        # e.g. French + French (Canada) both map to FR).
        wanted = list(LOCALE_TO_DEEPL.keys())

    api_key = os.environ.get("DEEPL_API_KEY", "")
    if not args.dry_run and not api_key:
        print("ERROR: DEEPL_API_KEY not set", file=sys.stderr)
        return 2

    client = DeepLClient(api_key) if not args.dry_run else None

    # Build dir-name -> deepl-target lookup keyed by multiple aliases.
    dirname_to_target: dict[str, str] = {}
    for dirname, target in LOCALE_TO_DEEPL.items():
        dirname_to_target[dirname.lower()] = target

    total_chars = 0
    total_strings = 0

    for selector in wanted:
        jf = find_locale_file(loc_dir, selector)
        if jf is None:
            print(f"SKIP {selector}: no locale dir/file matches")
            continue
        dirname = jf.parent.name
        target = dirname_to_target.get(dirname.lower())
        if target is None:
            # Maybe the user passed the DeepL code directly
            if selector.upper() in LOCALE_TO_DEEPL.values():
                target = selector.upper()
            else:
                print(f"SKIP {dirname}: not in DeepL supported set")
                continue

        target_data = json.loads(jf.read_text(encoding="utf-8"))
        candidates = collect_candidates(en_data, target_data, args.full)
        if not candidates:
            print(f"OK   {dirname}: nothing to translate")
            continue

        src_strings = [en_data[k] for k in candidates]
        chars = sum(len(s) for s in src_strings)
        print(f"  {dirname} -> {target}: {len(candidates)} strings, {chars:,} chars")
        total_chars += chars
        total_strings += len(candidates)

        if args.dry_run:
            continue

        wrapped: list[tuple[str, list[str]]] = [wrap_placeholders(s) for s in src_strings]
        wrapped_texts = [w[0] for w in wrapped]
        translated: list[str] = []
        for i in range(0, len(wrapped_texts), args.batch):
            chunk = wrapped_texts[i:i + args.batch]
            result = client.translate_batch(chunk, target)
            translated.extend(result)
            print(f"    batch {i // args.batch + 1}/{(len(wrapped_texts) + args.batch - 1) // args.batch}"
                  f" ({i + len(chunk)}/{len(wrapped_texts)})")

        for k, (_, tokens), out in zip(candidates, wrapped, translated):
            target_data[k] = unwrap_placeholders(out, tokens)

        jf.write_text(json.dumps(target_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  wrote {jf.relative_to(repo_root).as_posix()}")

    print()
    print(f"TOTAL: {total_strings:,} strings, {total_chars:,} chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
