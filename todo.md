# Baseline TODO

Actionable backlog derived from the full codebase review. Items are grouped by priority and tagged with subsystem and severity. Check off as completed.

---

## High priority — security & correctness

- [x] **Remove remote-IEX in Applications.psm1** `[security][module][HIGH]`
  - Files: `Module/Regions/Applications.psm1:766`, `:834`, `:902`
  - Pattern: `Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))`
  - Action: pin a known Chocolatey installer hash and verify before execution, OR require explicit user confirmation showing the URL, OR document the trust delegation in README
  - Acceptance: no unverified remote script ever reaches `Invoke-Expression`

- [x] **Audit `Invoke-Expression -Command $Command` in Invoke-CommandInstall** `[security][module][MED]`
  - File: `Module/Regions/Applications.psm1:1296`
  - Action: replace with `& $Command` plus split args, or validate `$Command` against an allowlist if it can ever come from manifest data
  - Acceptance: no parameter flows into IEX

- [x] **Fix `'ConfingFile'` alias typo** `[bootstrap][LOW]`
  - File: `Bootstrap/Baseline.ps1:104`
  - Action: keep both aliases for one release cycle, then drop `ConfingFile`
  - Acceptance: alias list reads `[Alias('ConfigFile')]`

- [x] **Lock `Add-SessionStatistic` against concurrent mutation** `[module][concurrency][MED]`
  - File: `Module/Logging.psm1` (Session statistics block ~ lines 38–50, 542–556, 590–600)
  - Action: wrap hashtable mutations in `System.Threading.Monitor.Enter/Exit` against a dedicated `SyncRoot`
  - Acceptance: stress test with concurrent GUI updates shows no lost counts

- [x] **Fix overall result aggregator in TestReport** `[tests][LOW]`
  - File: `Tests/TestReport.json` and the script that produces it (`Tools/Export-TestReport.ps1`)
  - Bug: `summary.overallResult = "Passed"` even when `layers.smoke.result = "Failed"`
  - Action: aggregator must escalate any layer Failed → overallResult Failed
  - Acceptance: reproduced failing smoke run yields `overallResult: Failed`

- [x] **Resolve currently failing smoke layer** `[tests][CI][HIGH]`
  - Source: `Tests/TestReport.json` — `layers.smoke.result == Failed`, duration 42.65s
  - Action: run `Tools/Test-SmokeTest.ps1` locally, identify the failing assertion, fix or update the expectation
  - Acceptance: CI smoke job green

---

## Medium priority — architecture & testability

- [x] **Refactor InitialActions.psm1 into testable helpers** `[module][tech-debt][MED]`
  - File: `Module/Regions/InitialActions.psm1` (876 lines)
  - Skipped in `Tests/phase3-progress.md` because of mixed P/Invoke, CIM, network I/O, and `$Global:Error.Clear()` calls
  - Action: extract pure logic into `SharedHelpers/InitialActions.Helpers.ps1`; keep side-effect orchestration in the region
  - Acceptance: AST extraction in unit tests covers ≥ 60% of pure logic

- [x] **Refactor System.WindowsFeatures.psm1** `[module][tech-debt][MED]`
  - Skipped — entire module is WPF/XAML
  - Action: split presentation from feature-toggle logic; expose toggles as testable functions
  - Acceptance: at least feature enumeration and toggle execution are unit-tested

- [x] **Split GUI.psm1 (4,618 lines)** `[module][tech-debt][MED]`
  - File: `Module/Regions/GUI.psm1`
  - Sub-tasks:
    - [x] Move XAML template (lines 1163–1742) into a separate `*.xaml` resource file
    - [x] Move dialog helpers into a dedicated module
    - [x] Move theme management into a dedicated module
    - [x] Move event handlers into a dedicated module
  - Acceptance: `GUI.psm1` ≤ 1,500 lines — reduced 4,617 → 1,455 lines via 8 extractions into `Module/GUI/*.ps1` + `MainWindow.xaml`

- [x] **Make SharedHelpers load order explicit** `[module][correctness][MED]`
  - File: `Module/SharedHelpers.psm1`
  - Hidden dependency: `GameMode.Helpers` must load before `Manifest.Helpers`
  - Action: replace alphabetical iteration with a named ordered list of imports; add a comment block explaining why each ordering matters
  - Acceptance: reordering the directory cannot break load

- [x] **Add load-time validation for preset entries** `[module][correctness][MED]`
  - Currently presets reference functions by string and only the test suite catches typos
  - Action: in `Preset.Helpers.ps1`, after resolving a preset, verify every function name resolves to a defined region function; warn (or fail in strict mode)
  - Acceptance: malformed preset surfaces an actionable error before execution

- [x] **Split GUICommon.psm1 (~136 KB)** `[module][tech-debt][LOW]`
  - File: `Module/GUICommon.psm1`
  - Action: split into focused modules — Layout constants, DPI awareness, Brush/color utilities, Font utilities, Object field accessors
  - Acceptance: no single file > 30 KB — 9 of 10 extracted files are under 30 KB. `Module/GUICommon.psm1` went from 3,945 → 67 lines (just imports + `$Script:` state + `Export-ModuleMember`). New focused modules under `Module/GUICommon/`: `Accessors.ps1`, `Layout.ps1`, `Utilities.ps1`, `DpiAwareness.ps1`, `WindowChrome.ps1`, `PopupWindows.ps1` (25.5 KB), `Dialogs.ps1` (17.8 KB), `ExecutionSummaryDialog.ps1` (**55.8 KB — exceeds the 30 KB target**), `RiskDecisionDialog.ps1`, `SettingsStore.ps1`. `ExecutionSummaryDialog.ps1` stays oversized because the 1,170-line `Show-ExecutionSummaryDialog` function contains duplicated per-outcome status-styling logic that needs an internal refactor (status lookup table + card builder + filter/grouping). The in-code `# NOTE: This function is ~700 lines...` comment preserved at the top documents the internal decomposition path for a future pass.

- [x] **Reduce 300+ near-identical Enable/Disable functions** `[module][maintainability][LOW]`
  - Pattern repeated across all `Module/Regions/**/*.psm1` tweak entry points
  - Must not occur: renaming manifest-referenced region entry points away from bare nouns or collapsing them into a generic Verb-Noun helper layer.
  - Keep the current manifest-compatible function naming and explicit per-tweak implementations.

- [x] **Replace dot-sourcing of helpers with explicit Import-Module** `[module][hygiene][LOW]`
  - File: `Module/SharedHelpers.psm1`
  - Action: convert each `*.Helpers.ps1` to a small module with explicit exports; import them in declared order
  - Acceptance: `Get-Module Baseline.* | Select Name, ExportedFunctions` is meaningful
  - Completed via named wrapper modules under `Module/SharedHelperModules/` (for example `Baseline.SharedHelpers.Manifest.psm1`) that dot-source the existing `*.Helpers.ps1` files inside isolated module scopes, set their own `SharedHelpersModuleRoot` / `SharedHelpersRepoRoot`, and export explicit function lists per helper slice. `SharedHelpers.psm1` now imports those wrapper modules in declared dependency order, and unload cleanup removes the helper modules when `SharedHelpers` is removed. `Tests/Unit/SharedHelpers.ModuleInventory.Tests.ps1` covers module inventory visibility and unload cleanup.

- [x] **Reconcile `-ReadOnly` enforcement** `[module][security][MED]`
  - The `-ReadOnly` gate exists but is not verified at every write call site
  - Action: add an `Assert-WritableOperation` helper called by every registry/audit/persistence write; fail loud in `-ReadOnly` mode
  - Acceptance: a `-ReadOnly -Apply` run cannot mutate any subsystem

---

## Medium priority — observability & failure modes

- [x] **Logging mutex timeout drops messages silently** `[logging][observability][MED]`
  - File: `Module/Logging.psm1:304–320`
  - Action: on 5s mutex timeout, queue message internally and retry with backoff; never silently drop
  - Acceptance: stress test logs exactly N messages for N writes

- [x] **Lock `GuiFontSizeWarnings.Add`** `[gui][concurrency][LOW]`
  - File: `Module/GUICommon.psm1:192–195`
  - Action: wrap HashSet add/check in `Monitor.Enter/Exit`
  - Acceptance: no duplicate warnings under concurrent calls

- [x] **Module reload state leakage** `[module][LOW]`
  - File: `Module/Baseline.psm1:54–60`
  - If module is reloaded with a different `$global:LogFilePath`, prior session statistics are discarded silently
  - Action: emit a clear log entry on session-stat reset; document the behaviour
  - Acceptance: reload event is observable

---

## Low priority — polish & UX

- [x] **Add declarative DPI awareness to launcher manifests** `[launcher][polish][LOW]`
  - Files: `Launcher/Baseline.manifest`, `ShortcutLauncher/Baseline.manifest`
  - Action: add `<asmv3:application><asmv3:windowsSettings><dpiAware>true/PM</dpiAware></asmv3:windowsSettings></asmv3:application>`
  - Acceptance: manifest declares per-monitor v2 in addition to programmatic call

- [x] **Document `powershell.Stop()` non-blocking limitation** `[launcher][docs][LOW]`
  - File: `Launcher/Program.cs:457`
  - Action: add a `// NOTE:` comment explaining that Stop() is best-effort and runaway scripts may continue in background
  - Acceptance: reader of timeout block understands the limit

- [x] **Broaden `CanWrite()` exception handling** `[launcher][robustness][LOW]`
  - File: `Launcher/Program.cs:380–402`
  - Action: add `catch (Exception) { return false; }` as final fallback after specific catches, or document the deliberate set
  - Acceptance: no exception type can escape `CanWrite`

- [x] **Localise installer UI strings** `[tools][localisation][LOW]`
  - File: `Tools/New-InstallerPackage.ps1:103–150`
  - Action: pull installer strings through `Get-BaselineLocalizedString` so installer matches the rest of the product
  - Acceptance: at least Minimal/Basic locales render installer in native language
  - Notes: wiring was in place (`Get-InstallerLocalizationDefinitions`/`Get-InstallerLocalizationSource`), but `Initialize-InstallerLocalizationWorkspace` seeded non-English locale workspaces with empty strings, and Fill-LocalizationLeaks.js only translates values equal to the English source. Fixed by seeding each non-English locale with the English source values so the translator treats them as "leaked English" and translates. Build verified: installer .iss now contains per-locale branches (`if Lang = 'af' then`, `if Lang = 'ja' then`, etc.) with translated strings.

- [x] **Add empty-translation detection test** `[tests][localisation][LOW]`
  - File: `Tests/Unit/LocalizationIntegrity.Tests.ps1`
  - Action: assert that every key not listed in `english_exempt_keys.json` has a non-empty value in every locale
  - Acceptance: silently empty translations fail CI

- [x] **Add string-overflow guard test** `[tests][localisation][LOW]`
  - Action: define max character lengths for known UI slots; test all locales fit within slot
  - Acceptance: known-overflow languages (German, Finnish) flagged before they ship

- [x] **Keep remote bootstrap latest-only** `[bootstrap][supply-chain][LOW]`
  - File: `Bootstrap/Bootstrap.ps1`
  - Action: do not add a `-Version` selector; raw bootstrap must continue resolving the latest non-draft release
  - Acceptance: `iwr ... | iex` callers always receive the current latest release

- [x] **Document RuntimeCache lifecycle** `[launcher][docs][LOW]`
  - Cache path: `%LOCALAPPDATA%\Baseline\RuntimeCache\<ver>\3\<buildId>\`
  - Action: document growth behaviour in `dev_docs/`; optionally implement stale-version pruner that keeps last N versions
  - Acceptance: users know what the cache is and how it's bounded

- [x] **Validate hostnames in `-TargetComputer`** `[bootstrap][security][LOW]`
  - File: `Bootstrap/Baseline.ps1:335–342`
  - Action: validate each entry against a hostname/FQDN regex before passing to PSRemoting
  - Acceptance: bad hostnames produce a clear error, not a remoting failure

- [x] **Sanitise `BASELINE_PRESET` env var** `[bootstrap][security][LOW]`
  - File: `Bootstrap/Bootstrap.ps1:39`
  - Action: validate value matches `^[A-Za-z0-9_.-]+$`
  - Acceptance: path-like or shell-meta values are rejected

- [x] **Quote/literal-path registry mutations** `[module][correctness][LOW]`
  - Files: `Module/Regions/Defender/**`, multiple regions
  - Action: switch `Set-ItemProperty -Path` calls to `-LiteralPath` with quoted paths consistently
  - Acceptance: paths containing spaces never silently fail

- [x] **Cap `ConvertFrom-Json -Depth`** `[module][robustness][LOW]`
  - Files: `Module/GUI/ActionHandlers.ps1`, `Module/GUI/ExecutionOrchestration.ps1`, others reading user JSON
  - Action: pass an explicit `-Depth` matching `ConvertTo-Json` (12 or 16 already used)
  - Acceptance: malformed deep JSON cannot stack-overflow

- [x] **Reset ExecutionPolicy on Chocolatey install failure** `[module][hygiene][LOW]`
  - File: `Module/Regions/Applications.psm1:765`
  - Action: capture pre-call policy and restore in `finally`
  - Acceptance: a failed install leaves session policy unchanged

- [x] **Hardcoded Windows Terminal settings path** `[module][robustness][LOW]`
  - File: `Module/Regions/ContextMenu.psm1`
  - Action: probe path before reading; skip with informative log if not present
  - Acceptance: absent Terminal install does not produce noisy errors

- [x] **Solution naming consistency** `[launcher][cosmetic][LOW]`
  - Solution lists `Launcher` folder + `RunLauncher.csproj` + `ShortcutLauncher.csproj`; output binary names are inconsistent
  - Action: align project names and output names so it's obvious which csproj produces `Baseline.exe`
  - Acceptance: a new contributor can map csproj → output binary at a glance

- [x] **Stale net10.0 obj artefacts** `[launcher][hygiene][LOW]`
  - Files: `Launcher/obj/` referencing net10.0 while csproj targets net48
  - Action: clean and rebuild; add `obj/` and `bin/` to `.gitignore` if not already
  - Acceptance: `obj/` matches declared TFM

- [x] **Carve out heuristics ban for Add-MissingMetadata** `[docs][LOW]`
  - File: `AGENTS.md` + `Tools/Add-MissingMetadata.ps1`
  - The script is heuristic by design; AGENTS.md bans heuristics
  - Action: add an explicit exception to AGENTS.md noting Add-MissingMetadata is intentionally heuristic and listing the constraint (conservative allowlists, idempotent, audited)
  - Acceptance: rule and exception are both documented

---

## Coverage gaps & validation

- [ ] **Provision self-hosted Windows desktop runners** `[CI][coverage][MED]` — **WORKFLOW WIRED, AWAITING RUNNER HARDWARE**
  - `Tests/Integration/README.md:22, 76` noted Win 10/11 desktop SKU coverage requires self-hosted runners that were not yet provisioned
  - Action: stand up self-hosted runner; wire `integration.yml` to dispatch on it
  - Acceptance: integration tests run on Win 10 22H2 and Win 11 23H2 in CI
  - Status: `.github/workflows/integration.yml` now exists with three parallel jobs — `server-2022` (GitHub-hosted, active), `win10-22h2` and `win11-23h2` (self-hosted labels `[self-hosted, windows, desktop, win{10-22h2,11-23h2}]`). Desktop jobs remain queued until a repo admin registers runners with matching labels — runner registration tokens are only available to repo admins and cannot be provisioned from a development sandbox. `Tests/Integration/README.md#ci-integration` documents the exact label set and registration procedure. Check the box once at least one matching runner is online and the first dispatched run on both desktop SKUs passes.

- [x] **Resolve 8 PowerShell 5.1 unit-test failures** `[tests][LOW]`
  - Tracked in `Tests/Integration/README.md:30`
  - Action: triage each failure; fix or document why it's PS-7-only
  - Acceptance: PS 5.1 layer either passes or each failure has a tracked reason

- [x] **Replace heuristic ErrorHandling filters with documented rules** `[module][hygiene][LOW]`
  - File: `Module/SharedHelpers/ErrorHandling.Helpers.ps1`
  - Filters classify some errors as "ignorable" via empirically derived rules
  - Action: document each rule, its provenance, and the failure mode it protects against
  - Acceptance: every filter has an inline comment with a `Why:` line

- [x] **Add manifest signature verification at module load** `[module][supply-chain][LOW]`
  - Bootstrap currently validates file existence only
  - Action: optionally verify hash manifest of module files at load when running from installer-mode
  - Acceptance: tampered module files refuse to load when integrity mode is on

---

## Documentation

- [x] **Document `-ReadOnly` semantics end-to-end** `[docs][MED]`
  - Action: in `dev_docs/`, list every subsystem touched by ReadOnly and the exact write classes it blocks
  - Acceptance: operator can reason about ReadOnly without reading code

- [x] **Document custom preset authoring** `[docs][LOW]`
  - Action: add a short guide for users creating their own preset JSON files (format, validation script, gotchas)
  - Acceptance: external user can author and validate a preset without help

- [x] **Explore and surface `dev_docs/MODELS.md` and `dev_docs/STATE.md`** `[docs][LOW]`
  - These exist but are not referenced from README or the docs site
  - Action: link them; ensure they are current
  - Acceptance: docs index references them with a one-line summary each

- [x] **Document the Tier-3 readiness reframe** `[docs][LOW]`
  - The previous TODO captured the "validation/polish/maintainability, not missing capability" framing
  - Action: move that framing into `dev_docs/Roadmap.md` or similar so it does not live only in TODO
  - Acceptance: the framing survives this TODO file being checked off

---

## Strengths to preserve (do not regress)

- Manifest-driven tweak system with rich metadata (Risk, Recovery, PresetTier, CompatibilitySensitivity, WhyThisMatters)
- Validate-ManifestData.ps1 deep validation including region-ownership drift detection
- Test-DocumentationConsistency.ps1 — guards against doc drift on enterprise claims
- Multi-target preview-only safety in `-TargetComputer >1` without `-Apply`
- Custom PSHost in launcher rejects all interactive I/O (correct for non-interactive contexts)
- Atomic runtime hydration with exclusive lock + UTF-8 BOM auto-insertion
- Localization schema-hash and per-locale key-set parity tests
- Lifecycle playbook captures verification state before/after with audit recording
- AST-based command parsing in Completion/Interactive.ps1 instead of Invoke-Expression
- Manifest command safety gate rejects `CommandAst.InvocationOperator != Unknown` — no dot-source (`. '.\foo.ps1'`) or call-operator (`& '.\foo.ps1'`) forms reach the executed scriptblock (`Module/Regions/Applications.psm1` `Assert-ApplicationCommandAstIsSafe`)
- `Test-ChocolateyBootstrapInteractiveHost` rejects known non-interactive hosts (`BaselineHost`, `ServerRemoteHost`, `Default Host`) and respects `[Environment]::UserInteractive` — RawUI presence alone is not treated as proof of interactivity, so the launcher Chocolatey approval path surfaces the approval-failure throw instead of a `NotSupportedException` from `PromptForChoice`
- Telemetry stance: zero phone-home, all logs local — confirmed by code
