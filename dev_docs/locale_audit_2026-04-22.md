# Locale audit — 2026-04-22

## Summary

- **Locale files:** 124 (Cherokee removed in this release)
- **Schema key count (en-US source):** 2,421
- **Files matching schema key count exactly:** 124 / 124
- **Files with missing or extra keys:** 0
- **Literal English fallback (non-en locales):** 0 keys across all shipped locales
- **Residual mojibake after mechanical repair:** 0 strings, 0 files
- **English variants (`en-*`):** 18 (expected to largely mirror `en-US`)

Structurally and mechanically complete. Human translation quality has not
been separately audited.

## Background — the corruption

The archive was imported with double-encoded UTF-8: bytes that were UTF-8
were read as Windows-1252 and re-saved as UTF-8. Surface symptom: `Installé`
appeared as `InstallÃ©`, `‘` appeared as `â€˜`, and whole non-Latin-script
locales turned into pages of `ã‚¢ã‚¯ã‚·ãƒ§ãƒ³`-style noise.

Key insight about the bad decoder: it was a cp1252 decoder that kept the
five "undefined" bytes (`0x81`, `0x8D`, `0x8F`, `0x90`, `0x9D`) as
pass-through codepoints rather than dropping them. That preserved every
byte of the original UTF-8, making full recovery possible — but only with
a cp1252 *encoder* that also pass-es through those five codepoints.
Python's stock cp1252 codec refuses them, which is why the first repair
pass left ~100k strings looking "irrecoverable".

## Mechanical repair

`scripts/Fix-LocaleMojibake.py` repairs double-encoded UTF-8 by re-encoding
each string through a permissive cp1252 (pass-through for U+0081, U+008D,
U+008F, U+0090, U+009D), then UTF-8-decoding the result. Accepted only when
the result decodes cleanly (no U+FFFD), differs from the input, and the
input has ≥ 2 high-bit characters.

After two passes:

- **Pass 1** (strict cp1252 + latin-1 fallback): 90,754 strings across 121 files.
- **Pass 2** (permissive cp1252 with C1 pass-through): 86,082 additional strings
  across 72 files — including every locale previously classified irrecoverable
  (Japanese, Russian, Hindi, Tamil, Telugu, Georgian, Korean, Thai, Bangla,
  Greek, Ukrainian, Bulgarian, Arabic, Mongolian, Sinhala, Lao, etc.).

Total: **176,836 strings recovered.**

## Residual verification

`scripts/Audit-LocaleResidual.py` uses a high-confidence signature: re-encode
the string through permissive cp1252, and flag it only if the result decodes
validly as UTF-8 *and* differs from the input. Pure native-diacritic text
(Portuguese `ç`, Finnish `ä`, Icelandic `ð`, etc.) encodes to cp1252 cleanly
but doesn't form a valid UTF-8 multi-byte sequence, so it isn't false-flagged.

Current result: **0 residual strings in 0 files.**

## Cherokee removed

Cherokee (`chr`) was never completed — the imported file was ~93% English
fallback (166 untranslated keys) and neither DeepL nor Azure Translator
support Cherokee as a target language. Rather than ship a half-English
locale or machine-translate from an unsupported backend, Cherokee was
removed from the shipped set in this release. Re-adding it is blocked on
a formal translation partnership (e.g. Cherokee Nation Language Department).

## Plain-English verdict

- Safe claim: "124 locale files, full key coverage (2,421 keys each), all
  strings mechanically verified clean of double-encoded UTF-8."
- Translation *quality* (idiomatic accuracy, tone) was not separately
  audited — that's machine-assisted content under ongoing QA.

## Actions taken

1. `scripts/Fix-LocaleMojibake.py` — two-pass fixer; cp1252/latin-1 pass,
   then permissive cp1252 pass for C1 pass-through bytes.
2. `scripts/Audit-LocaleResidual.py` — precise mojibake detector using a
   cp1252-roundtrip signature; zero false positives on clean diacritic text.
3. `scripts/Translate-LocalesDeepL.py` — DeepL-based translator, kept in the
   tree for future mojibake incidents or idiomatic quality passes on
   DeepL-supported locales.
4. README.md and CHANGELOG.md wording corrected to drop the "99% / 2,289
   keys / 1% English fallback" language.
5. Cherokee locale removed: `Localizations/Cherokee/` deleted; references
   purged from the installer script, GUI language picker, locale map, and
   localization QA tooling.

## Follow-up

- Consider a translation-quality review pass on the recovered locales —
  mechanical recovery restored the *bytes*, not the *choice* of
  translation, and machine-translated material may still benefit from
  idiomatic cleanup.
