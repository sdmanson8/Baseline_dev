# Locale audit — 2026-04-22

## Summary

- **Locale files:** 125
- **Schema key count (en-US source):** 2,421
- **Files matching schema key count exactly:** 125 / 125
- **Files with missing or extra keys:** 0
- **Literal English fallback (non-en locales, exempt keys excluded):**
  - Cherokee (`chr`): 166 keys (6.857%) — unfinished translation
  - All other non-English locales: 0 keys (0.0%)
- **English variants (`en-*`):** 18 (expected to largely mirror `en-US`)

Structurally the locale set is complete. Key coverage is 100%.

## Translation readability — mechanical repair pass

The archive was imported with double-encoded UTF-8 (bytes that were UTF-8 were
read as Windows-1252/Latin-1 and re-saved as UTF-8). Surface symptom: `Installé`
appears as `InstallÃ©`, `‘` appears as `â€˜`, etc.

A mechanical repair (`scripts/Fix-LocaleMojibake.py`) recovered every string
where the damage was reversible — 90,754 strings across 121 files. Repair
strategy: for each string, try `s.encode('cp1252').decode('utf-8')` and
`s.encode('latin-1').decode('utf-8')`; accept the result only when it decodes
cleanly (no replacement character), differs from the input, and the input had
≥ 2 high-bit characters to avoid incidental false positives on clean ASCII-
adjacent text.

## Irrecoverable residual

Several locales still contain corruption after the mechanical pass. The
original bad decoder dropped undefined Windows-1252 bytes (`0x81`, `0x8D`,
`0x8F`, `0x90`, `0x9D`) silently. Those bytes are embedded in the UTF-8
encoding of most Cyrillic, CJK, Devanagari, Brahmic, Thai, Lao, Georgian,
Arabic and similar script characters — once dropped, the original character is
lost. Affected locales cannot be mechanically repaired and are scheduled for
re-translation from the en-US source.

Locales with ≥ 1,000 irrecoverable strings (approximate, counted as strings
containing U+FFFD or raw undefined cp1252 bytes):

| Locale | Irrecoverable strings |
|---|---|
| Georgian (`ka`) | 2,215 |
| Tamil (`ta`) | 2,201 |
| Malayalam (`ml`) | 2,199 |
| Kannada (`kn`) | 2,176 |
| Telugu (`te`) | 2,152 |
| Bangla (`bn`) | 2,086 |
| Bangla (BD) (`bn-BD`) | 2,084 |
| Cherokee (`chr`) | 2,059 |
| Nepali (`ne`) | 2,055 |
| Assamese (`as`) | 2,033 |
| Hindi (`hi`) | 2,011 |
| Tigrinya (`ti`) | 2,003 |
| Gujarati (`gu`) | 1,995 |
| Amharic (`am`) | 1,987 |
| Marathi (`mr`) | 1,947 |
| Belarusian (`be`) | 1,944 |
| Greek (`el`) | 1,918 |
| Japanese (`ja`) | 1,873 |
| Ukrainian (`uk`) | 1,841 |
| Lao (`lo`) | 1,839 |
| Sinhala (`si`) | 1,838 |
| Bulgarian (`bg`) | 1,826 |
| Mongolian (`mn`) | 1,816 |
| Thai (`th`) | 1,814 |
| Russian (`ru`) | 1,810 |
| Korean (`ko`) | 1,784 |
| Konkani (`kok`) | 1,736 |
| Odia (`or`) | 1,733 |
| Kazakh (`kk`) | 1,696 |
| … | … |

Full list in the output of `scripts/Audit-LocaleResidual.py`.

## Plain-English verdict

Structurally complete, quality-incomplete.

- Safe claim: "125 locale files, full key coverage (2,421 keys each)."
- Not-safe claim: "99% translated" — misleading for any locale in the
  irrecoverable table above, because the files are filled with content that
  no reader of the target language can use.

## Actions taken

1. `scripts/Fix-LocaleMojibake.py` applied — 90,754 strings recovered.
2. `scripts/Audit-LocaleResidual.py` added so residual mojibake can be
   monitored going forward.
3. README.md and CHANGELOG.md wording corrected to drop the "99% / 2,289 keys
   / 1% English fallback" language.

## Follow-up

- Re-translate the locales in the irrecoverable table from the en-US source.
  Machine translation from en-US is the fastest path since the files already
  have correct keys and correct structure.
- After re-translation, re-run `scripts/Audit-LocaleResidual.py`; target is
  zero residual per locale except intentional un-translated locales
  (Cherokee).
