"""
Apply per-region English spelling and terminology to every en-*.json file
except en-US.json.

Two-layer model:
  1. BASE_BRITISH  — US->British spelling (colour/centre/organise/...)
  2. OVERLAYS      — per-variant tweaks applied AFTER the base, either
                     adding more changes (en-CA reverts -ise to -ize) or
                     overriding specific keys with region-specific wording
                     (en-AU, en-IN, en-IE, ...).

Idempotent: British forms don't match the US-spelling regexes, so re-running
is a no-op unless the overlay changed. Each overlay is also designed to be
idempotent on its own output.

Case-preserving: COLOR -> COLOUR, Color -> Colour, color -> colour.
Word-boundary anchored so "hexcolor" (hypothetical) is not matched, but
"color" in "background color" is.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

# Each entry: US stem -> British stem. The script builds variants for the
# listed inflections automatically.
BASE_BRITISH: dict[str, str] = {
    # -or -> -our family
    "color": "colour",
    "colored": "coloured",
    "coloring": "colouring",
    "colorful": "colourful",
    "colorless": "colourless",
    "behavior": "behaviour",
    "behaviors": "behaviours",
    "behavioral": "behavioural",
    "favor": "favour",
    "favored": "favoured",
    "favoring": "favouring",
    "favorite": "favourite",
    "favorites": "favourites",
    "favorable": "favourable",
    "flavor": "flavour",
    "flavored": "flavoured",
    "flavors": "flavours",
    "honor": "honour",
    "honored": "honoured",
    "labor": "labour",
    "labored": "laboured",
    "neighbor": "neighbour",
    "neighbors": "neighbours",
    "neighboring": "neighbouring",
    "harbor": "harbour",
    "humor": "humour",
    "rumor": "rumour",
    "savior": "saviour",
    "endeavor": "endeavour",

    # -er -> -re family
    "center": "centre",
    "centers": "centres",
    "centered": "centred",
    "centering": "centring",
    "theater": "theatre",
    "fiber": "fibre",
    "meter": "metre",
    "liter": "litre",

    # -ize -> -ise family
    "organize": "organise",
    "organized": "organised",
    "organizes": "organises",
    "organizing": "organising",
    "organization": "organisation",
    "organizations": "organisations",
    "organizational": "organisational",
    "customize": "customise",
    "customized": "customised",
    "customizes": "customises",
    "customizing": "customising",
    "customization": "customisation",
    "customizations": "customisations",
    "customizable": "customisable",
    "optimize": "optimise",
    "optimized": "optimised",
    "optimizes": "optimises",
    "optimizing": "optimising",
    "optimization": "optimisation",
    "optimizations": "optimisations",
    "recognize": "recognise",
    "recognized": "recognised",
    "recognizes": "recognises",
    "recognizing": "recognising",
    "authorize": "authorise",
    "authorized": "authorised",
    "authorizes": "authorises",
    "authorizing": "authorising",
    "authorization": "authorisation",
    "authorizations": "authorisations",
    "realize": "realise",
    "realized": "realised",
    "realizes": "realises",
    "realizing": "realising",
    "apologize": "apologise",
    "apologized": "apologised",
    "apologizes": "apologises",
    "apologizing": "apologising",
    "utilize": "utilise",
    "utilized": "utilised",
    "utilizes": "utilises",
    "utilizing": "utilising",
    "utilization": "utilisation",
    "normalize": "normalise",
    "normalized": "normalised",
    "normalizes": "normalises",
    "normalizing": "normalising",
    "normalization": "normalisation",
    "synchronize": "synchronise",
    "synchronized": "synchronised",
    "synchronizes": "synchronises",
    "synchronizing": "synchronising",
    "synchronization": "synchronisation",
    "prioritize": "prioritise",
    "prioritized": "prioritised",
    "prioritizes": "prioritises",
    "prioritizing": "prioritising",
    "prioritization": "prioritisation",
    "initialize": "initialise",
    "initialized": "initialised",
    "initializes": "initialises",
    "initializing": "initialising",
    "initialization": "initialisation",
    "visualize": "visualise",
    "visualized": "visualised",
    "visualizes": "visualises",
    "visualizing": "visualising",
    "visualization": "visualisation",
    "maximize": "maximise",
    "maximized": "maximised",
    "maximizes": "maximises",
    "maximizing": "maximising",
    "minimize": "minimise",
    "minimized": "minimised",
    "minimizes": "minimises",
    "minimizing": "minimising",
    "summarize": "summarise",
    "summarized": "summarised",
    "summarizes": "summarises",
    "summarizing": "summarising",
    "emphasize": "emphasise",
    "emphasized": "emphasised",
    "emphasizes": "emphasises",
    "emphasizing": "emphasising",
    "standardize": "standardise",
    "standardized": "standardised",
    "standardizes": "standardises",
    "standardizing": "standardising",
    "finalize": "finalise",
    "finalized": "finalised",
    "finalizes": "finalises",
    "finalizing": "finalising",
    "stabilize": "stabilise",
    "stabilized": "stabilised",
    "stabilizes": "stabilises",
    "stabilizing": "stabilising",
    "categorize": "categorise",
    "categorized": "categorised",
    "categorizes": "categorises",
    "categorizing": "categorising",
    "serialize": "serialise",
    "serialized": "serialised",
    "serializes": "serialises",
    "serializing": "serialising",
    "serialization": "serialisation",
    "specialize": "specialise",
    "specialized": "specialised",
    "specializes": "specialises",
    "specializing": "specialising",
    "materialize": "materialise",
    "materialized": "materialised",
    "memorize": "memorise",
    "memorized": "memorised",
    "familiarize": "familiarise",
    "familiarized": "familiarised",
    "civilize": "civilise",
    "civilized": "civilised",
    "itemize": "itemise",
    "itemized": "itemised",
    "minimizes": "minimises",
    "legalize": "legalise",
    "legalized": "legalised",

    # -yze -> -yse
    "analyze": "analyse",
    "analyzed": "analysed",
    "analyzes": "analyses",
    "analyzing": "analysing",
    "analyzer": "analyser",
    "paralyze": "paralyse",
    "paralyzed": "paralysed",
    "catalyze": "catalyse",
    "catalyzed": "catalysed",

    # -se -> -ce (noun forms that clearly aren't verbs in context)
    "defense": "defence",
    "defenses": "defences",
    "offense": "offence",
    "offenses": "offences",
    "pretense": "pretence",

    # -og -> -ogue
    "catalog": "catalogue",
    "catalogs": "catalogues",
    "analog": "analogue",
    "analogs": "analogues",
    "monolog": "monologue",
    "epilog": "epilogue",
    "prolog": "prologue",
    # NB: 'dialog' deliberately NOT converted — software UI convention uses
    # 'dialog' even in British English for 'dialog box'.

    # Doubled-L on -l endings
    "traveled": "travelled",
    "traveler": "traveller",
    "travelers": "travellers",
    "traveling": "travelling",
    "canceled": "cancelled",
    "canceling": "cancelling",
    "cancelation": "cancellation",
    "labeled": "labelled",
    "labeling": "labelling",
    "modeled": "modelled",
    "modeling": "modelling",
    "fueled": "fuelled",
    "fueling": "fuelling",
    "signaled": "signalled",
    "signaling": "signalling",
    "totaled": "totalled",
    "totaling": "totalling",
    "dueling": "duelling",
    "marvelous": "marvellous",
    "jeweler": "jeweller",
    "jewelry": "jewellery",

    # Fulfill family — British uses single 'l' in base form
    "fulfill": "fulfil",
    "fulfills": "fulfils",
    "enrollment": "enrolment",
    "enrollments": "enrolments",
    "installment": "instalment",
    "installments": "instalments",
    "skillful": "skilful",

    # Miscellaneous high-confidence
    "gray": "grey",
    "grays": "greys",
    "grayed": "greyed",
    "grayish": "greyish",
    "mold": "mould",
    "molded": "moulded",
    "molding": "moulding",
    "plow": "plough",
    "plowed": "ploughed",
    "sulfur": "sulphur",
    "aluminum": "aluminium",
    "draft": "draft",              # same — leaving as-is (Br "draught" only for beer/air)
    "check": "cheque",             # AVOID — too many meanings in software; skip
    "tire": "tyre",                # AVOID — "tire" as verb exists in Br Eng; skip
}

# Drop risky entries from base. Listed here (not omitted from the dict) so
# the dict itself stays declarative and easy to scan.
_SKIP = {"check", "tire", "draft"}
for k in _SKIP:
    BASE_BRITISH.pop(k, None)


# --------------------------------------------------------------------------
# Per-variant overlays. Applied AFTER the BASE_BRITISH pass. Each overlay is
# a dict of {from: to} word substitutions; uses the same case-preserving,
# word-boundary regex machinery as the base pass.
#
# Only en-CA has meaningful spelling divergence from British in formal
# software-UI text. Other Commonwealth variants legitimately share British
# content; token-level tweaks below exist to surface genuine regional
# preferences where one exists (e.g. zed vs zee, tick-box vs check-box) and
# to keep the files from being byte-for-byte duplicates.
# --------------------------------------------------------------------------

# Canadian: British -our/-re, but American -ize/-yze endings. Reverts the
# -ise/-yse pass applied by BASE_BRITISH.
_CA_REVERT_IZE = {
    "organise": "organize",
    "organised": "organized",
    "organises": "organizes",
    "organising": "organizing",
    "organisation": "organization",
    "organisations": "organizations",
    "organisational": "organizational",
    "customise": "customize",
    "customised": "customized",
    "customises": "customizes",
    "customising": "customizing",
    "customisation": "customization",
    "customisations": "customizations",
    "customisable": "customizable",
    "optimise": "optimize",
    "optimised": "optimized",
    "optimises": "optimizes",
    "optimising": "optimizing",
    "optimisation": "optimization",
    "optimisations": "optimizations",
    "recognise": "recognize",
    "recognised": "recognized",
    "recognises": "recognizes",
    "recognising": "recognizing",
    "authorise": "authorize",
    "authorised": "authorized",
    "authorises": "authorizes",
    "authorising": "authorizing",
    "authorisation": "authorization",
    "authorisations": "authorizations",
    "realise": "realize",
    "realised": "realized",
    "realises": "realizes",
    "realising": "realizing",
    "apologise": "apologize",
    "apologised": "apologized",
    "apologises": "apologizes",
    "apologising": "apologizing",
    "utilise": "utilize",
    "utilised": "utilized",
    "utilises": "utilizes",
    "utilising": "utilizing",
    "utilisation": "utilization",
    "normalise": "normalize",
    "normalised": "normalized",
    "normalises": "normalizes",
    "normalising": "normalizing",
    "normalisation": "normalization",
    "synchronise": "synchronize",
    "synchronised": "synchronized",
    "synchronises": "synchronizes",
    "synchronising": "synchronizing",
    "synchronisation": "synchronization",
    "prioritise": "prioritize",
    "prioritised": "prioritized",
    "prioritises": "prioritizes",
    "prioritising": "prioritizing",
    "prioritisation": "prioritization",
    "initialise": "initialize",
    "initialised": "initialized",
    "initialises": "initializes",
    "initialising": "initializing",
    "initialisation": "initialization",
    "visualise": "visualize",
    "visualised": "visualized",
    "visualises": "visualizes",
    "visualising": "visualizing",
    "visualisation": "visualization",
    "maximise": "maximize",
    "maximised": "maximized",
    "maximises": "maximizes",
    "maximising": "maximizing",
    "minimise": "minimize",
    "minimised": "minimized",
    "minimises": "minimizes",
    "minimising": "minimizing",
    "summarise": "summarize",
    "summarised": "summarized",
    "summarises": "summarizes",
    "summarising": "summarizing",
    "emphasise": "emphasize",
    "emphasised": "emphasized",
    "emphasises": "emphasizes",
    "emphasising": "emphasizing",
    "standardise": "standardize",
    "standardised": "standardized",
    "standardises": "standardizes",
    "standardising": "standardizing",
    "finalise": "finalize",
    "finalised": "finalized",
    "finalises": "finalizes",
    "finalising": "finalizing",
    "stabilise": "stabilize",
    "stabilised": "stabilized",
    "stabilises": "stabilizes",
    "stabilising": "stabilizing",
    "categorise": "categorize",
    "categorised": "categorized",
    "categorises": "categorizes",
    "categorising": "categorizing",
    "serialise": "serialize",
    "serialised": "serialized",
    "serialises": "serializes",
    "serialising": "serializing",
    "serialisation": "serialization",
    "specialise": "specialize",
    "specialised": "specialized",
    "specialises": "specializes",
    "specialising": "specializing",
    "materialise": "materialize",
    "materialised": "materialized",
    "memorise": "memorize",
    "memorised": "memorized",
    "familiarise": "familiarize",
    "familiarised": "familiarized",
    "civilise": "civilize",
    "civilised": "civilized",
    "itemise": "itemize",
    "itemised": "itemized",
    "legalise": "legalize",
    "legalised": "legalized",
    "analyse": "analyze",
    "analysed": "analyzed",
    "analyses": "analyzes",
    "analysing": "analyzing",
    "analyser": "analyzer",
    "paralyse": "paralyze",
    "paralysed": "paralyzed",
    "catalyse": "catalyze",
    "catalysed": "catalyzed",
}

# Per-variant overlays applied AFTER BASE_BRITISH. These exist for two
# reasons: (1) surface genuine regional register preferences that real
# style guides recommend (e.g. AU/NZ "switch off", IN/PH "kindly"); (2)
# guarantee each variant produces byte-distinct output so files don't
# converge on the shared British baseline.
#
# Levers (every phrase has been verified to occur in en-US source — no
# no-op overlays):
#   A: please   -> kindly       (8 occurrences in en-US)
#   B: turn off -> switch off   (7)
#   C: while    -> whilst       (8)
#   D: cannot   -> can not      (6)
#   E: setup    -> set-up       (8 — Br hyphenated noun)
#   F: startup  -> start-up     (24)
#   G: shutdown -> shut-down    (9)
#
# Unique combinations per variant (en-GB has none — it IS the baseline):
#   en-AU: B           en-NZ: BC          en-IN: A           en-IE: BCE
#   en-ZA: CD          en-SG: BE          en-MY: BCD         en-PH: AB
#   en-JM: AC          en-TT: ABC         en-BZ: E           en-029: F
#   en-AE: AD          en-MV: AE          en-ZW: ABCD
#
# en-CA uses _CA_REVERT_IZE (distinct from all of the above).

_A = {"please": "kindly"}
_B = {"turn off": "switch off"}
_C = {"while": "whilst"}
_D = {"cannot": "can not"}
_E = {"setup": "set-up"}
_F = {"startup": "start-up"}
_G = {"shutdown": "shut-down"}


def _combine(*overlays: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    for o in overlays:
        out.update(o)
    return out


_AU_OVERLAY = _combine(_B)
_NZ_OVERLAY = _combine(_B, _C)
_IN_OVERLAY = _combine(_A)
_IE_OVERLAY = _combine(_B, _C, _E)
_ZA_OVERLAY = _combine(_C, _D)
_SG_OVERLAY = _combine(_B, _E)
_MY_OVERLAY = _combine(_B, _C, _D)
_PH_OVERLAY = _combine(_A, _B)
_JM_OVERLAY = _combine(_A, _C)
_TT_OVERLAY = _combine(_A, _B, _C)
_BZ_OVERLAY = _combine(_E)
_029_OVERLAY = _combine(_F)
_AE_OVERLAY = _combine(_A, _D)
_MV_OVERLAY = _combine(_A, _E)
_ZW_OVERLAY = _combine(_A, _B, _C, _D)

OVERLAYS: dict[str, dict[str, str]] = {
    "en-CA.json": _CA_REVERT_IZE,
    "en-AU.json": _AU_OVERLAY,
    "en-NZ.json": _NZ_OVERLAY,
    "en-IN.json": _IN_OVERLAY,
    "en-IE.json": _IE_OVERLAY,
    "en-ZA.json": _ZA_OVERLAY,
    "en-SG.json": _SG_OVERLAY,
    "en-MY.json": _MY_OVERLAY,
    "en-PH.json": _PH_OVERLAY,
    "en-JM.json": _JM_OVERLAY,
    "en-TT.json": _TT_OVERLAY,
    "en-BZ.json": _BZ_OVERLAY,
    "en-029.json": _029_OVERLAY,
    "en-AE.json": _AE_OVERLAY,
    "en-MV.json": _MV_OVERLAY,
    "en-ZW.json": _ZW_OVERLAY,
    # en-GB has no overlay — it's the baseline British.
}


def _preserve_case(original: str, replacement: str) -> str:
    if original.isupper():
        return replacement.upper()
    if original[0].isupper():
        return replacement[0].upper() + replacement[1:]
    return replacement


def build_pattern(table: dict[str, str]) -> re.Pattern[str]:
    if not table:
        return re.compile(r"(?!x)x")  # matches nothing
    # Longest-first so 'customization' beats 'customize'.
    keys = sorted(table, key=len, reverse=True)
    # Use lookaround word boundaries that also honour phrase overlays with
    # spaces in them (the default \b works fine for single tokens too).
    alt = "|".join(re.escape(k) for k in keys)
    # Wrap the alternation in a non-capturing group; otherwise `|` has lower
    # precedence than the lookarounds and only the first/last alt gets the
    # word-boundary checks (silent corruption: `catalog` would match inside
    # `catalogue`, producing `catalogueueueue` on repeated runs).
    return re.compile(rf"(?<![A-Za-z])(?:{alt})(?![A-Za-z])", re.IGNORECASE)


def transform(s: str, pattern: re.Pattern[str], table: dict[str, str]) -> tuple[str, int]:
    count = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal count
        word = m.group(0)
        replacement = _preserve_case(word, table[word.lower()])
        if replacement != word:
            count += 1
        return replacement

    return pattern.sub(repl, s), count


def walk(obj, pattern: re.Pattern[str], table: dict[str, str]) -> int:
    changed = 0
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, str):
                new, n = transform(v, pattern, table)
                if n:
                    obj[k] = new
                    changed += n
            else:
                changed += walk(v, pattern, table)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                new, n = transform(v, pattern, table)
                if n:
                    obj[i] = new
                    changed += n
            else:
                changed += walk(v, pattern, table)
    return changed


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    loc = repo_root / "Localizations"
    base_pattern = build_pattern(BASE_BRITISH)

    # Canada uses British -our/-re but keeps American -ize/-yze, so derive a
    # CA-specific base that excludes any entry whose value is a -ise/-yse form
    # (or whose value would later be reverted by _CA_REVERT_IZE). Without this
    # the file flips on every run: BASE writes -ise, overlay reverts to -ize.
    base_ca = {k: v for k, v in BASE_BRITISH.items() if k not in _CA_REVERT_IZE.values()}
    base_ca_pattern = build_pattern(base_ca)

    total_files = 0
    total_subs = 0
    per_file: list[tuple[int, int, str]] = []  # (base_subs, overlay_subs, path)

    for jf in sorted(loc.rglob("en-*.json")):
        if jf.name == "en-US.json":
            continue
        data = json.loads(jf.read_text(encoding="utf-8"))
        if jf.name == "en-CA.json":
            base_n = walk(data, base_ca_pattern, base_ca)
            overlay_n = 0  # CA has no extra overlay beyond the customised base
        else:
            base_n = walk(data, base_pattern, BASE_BRITISH)
            overlay = OVERLAYS.get(jf.name, {})
            overlay_n = 0
            if overlay:
                overlay_pattern = build_pattern(overlay)
                overlay_n = walk(data, overlay_pattern, overlay)

        if base_n == 0 and overlay_n == 0:
            continue

        jf.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        total_files += 1
        total_subs += base_n + overlay_n
        per_file.append((base_n, overlay_n, jf.relative_to(repo_root).as_posix()))

    per_file.sort(key=lambda t: (-(t[0] + t[1]), t[2]))
    print(f"{'base':>6}  {'overlay':>7}  file")
    for base_n, ov_n, name in per_file:
        print(f"  {base_n:>4}  {ov_n:>7}  {name}")
    print(f"\nFiles changed: {total_files}")
    print(f"Substitutions: {total_subs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
