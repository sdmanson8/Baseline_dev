# Source Quality Staged Refactor Plan

This plan tracks maintainability work that is intentionally not claimed as fully remediated in one pass. Each extraction below must preserve public function names, parameter names, parameter sets, aliases, return shapes, and default values.

## Function Length Inventory

Measured with the Windows PowerShell 5.1 parser after the oversized-function extraction pass. The enforced limit is 400 lines per PowerShell function.

| Function | Lines | File |
|---|---:|---|
| Resolve-ApplicationExecutionRoute | 400 | Module/Regions/Applications.psm1 |
| Show-GuiSettingsDialog | 393 | Module/GUI/DialogHelpers/SettingsDialogs.ps1 |
| New-GameModeComparisonPanel | 383 | Module/GUI/GameModeUI.ps1 |
| Get-SelectedTweakRunList | 378 | Module/GUI/PreviewBuilders.ps1 |
| Show-LogDialog | 370 | Module/GUI/DialogHelpers/ContentDialogs.ps1 |
| Add-GuiPopupWindowChrome | 368 | Module/GUICommon/PopupWindows.ps1 |
| Prompt-GuiRemoteTargetConnection | 365 | Module/GUI/SessionState.ps1 |
| Test-TweakManifestIntegrity | 361 | Module/SharedHelpers/Manifest.Helpers.ps1 |
| Start-GuiExecutionRun | 356 | Module/GUI/ExecutionOrchestration/ExecutionRunOrchestration.ps1 |
| Invoke-GuiExecutionRunQueueEntry | 349 | Module/GUI/ExecutionOrchestration/ExecutionRunOrchestration.ps1 |

## Stage 1: Execution Failure Semantics

Target: `Start-GuiExecutionRun`

Status: Implemented for this target. The public function name and parameters are unchanged.

Extract helpers:

| Helper | Contract |
|---|---|
| `Invoke-GuiExecutionRemoteRun` | Handles connected remote apply runs and returns `$true` only when the local run path should stop. |
| `Resolve-GuiExecutionRunnableTweaks` | Marks unavailable entries as `Not applicable` and returns the filtered runnable list. |
| `Set-GuiExecutionGameModeRunContext` | Builds the Game Mode execution context without changing caller parameters. |
| `Initialize-GuiExecutionRunState` | Initializes GUI busy state, progress state, and synchronized run state. |
| `Save-GuiExecutionPreRunSnapshot` | Captures and persists the pre-run snapshot with the existing warning behavior on failure. |
| `Add-GuiExecutionRunLogLine` | Appends one execution log line using the existing theme and scroll behavior. |
| `Invoke-GuiExecutionRunQueueEntry` | Handles one queued execution event while preserving the previous event contracts. |
| `Invoke-GuiExecutionRunQueueDrain` | Drains the run queue and preserves the previous per-entry error recovery. |

Tests:

- Existing execution orchestration and ForceUnsupported tests pass.
- `Tests/Unit/ExecutionOrchestration.Tests.ps1` now pins `Start-GuiExecutionRun` to 400 lines or less.

## Stage 2: Settings Dialog Composition

Target: `Show-GuiSettingsDialog`

Status: Implemented for the oversized-function limit. The public function name and parameters are unchanged.

Extraction contract:

- Settings dialog label/palette initialization, XAML construction, control wiring, language rendering, update state, log folder state, storage state, cache clearing, and save handling are dot-sourced from `Module/GUI/DialogHelpers/SettingsDialogs/Show-GuiSettingsDialog/` in explicit order.
- Dot-sourced parts execute in the original caller scope so local variables, event closures, return shape, and default values remain unchanged.

Tests:

- Preserve current settings dialog source tests.
- Enforce the 400-line function limit in `Tests/Unit/SourceQuality.Guards.Tests.ps1`.

## Stage 3: GUI Shell Startup

Target: `Show-TweakGUI`

Status: Implemented for the oversized-function limit. The public function name and parameters are unchanged.

Extraction contract:

- GUI startup, manifest loading, category/index setup, theme setup, action wiring, first-run state, startup splash handling, and WPF show/close handling are dot-sourced from `Module/GUI/Show-TweakGUI/` in explicit order.
- Extracted parts preserve the original caller scope. Parts that contain original caller-level returns bridge that return back to `Show-TweakGUI`.

Tests:

- Parser and GUI composition tests.
- Startup failure classification tests.

## Stage 4: File Association Privileged Writes

Target: `Set-Association`

Extract helpers:

| Helper | Contract |
|---|---|
| `New-AssociationUserChoiceModel` | Returns ProgId/hash/key model; throws on invalid extension or missing program. |
| `Set-AssociationUserChoiceValues` | Throws on failed registry writes. |
| `Set-AssociationUserChoiceAcl` | Throws on ACL failure. |
| `Invoke-AssociationUcpdWrite` | Throws on process failure; uses temporary `.ps1` files, not `-Command`. |

Tests:

- Source guard for no `-Command` in the UCPD write path.
- Unit tests for generated registry model values.

## Stage 5: AIRemoval Split

Target: `AIRemoval.ps1`

Extract files in fixed order:

1. `AIRemoval.TrustedInstaller.ps1`
2. `AIRemoval.Registry.ps1`
3. `AIRemoval.Packages.ps1`
4. `AIRemoval.Files.ps1`
5. `AIRemoval.BackupRestore.ps1`

Contracts:

- TrustedInstaller helpers throw on service mutation failure and always attempt restore in `finally`.
- Registry helpers throw on failed mandatory writes and log explicit warning for documented best-effort cleanup.
- Package/file helpers return structured result objects with `Succeeded`, `Skipped`, and `Warnings`.

Tests:

- Source guard for no unprofessional comments.
- Source guard for no `[void](Invoke-BaselineProcess ...)`.
- Unit tests for TrustedInstaller restore command generation.

## Source Quality Guards

`Tests/Unit/SourceQuality.Guards.Tests.ps1` now rejects duplicate function names in module source. The current scan is clean, so new duplicate helpers fail Pester instead of being added to a reviewed debt list.

The same guard file now rejects any non-vendor PowerShell function over 400 lines across `Module`, `Tools`, `Bootstrap`, and `Tests`.

## Status

Implemented. The oversized-function refactor is complete against the 400-line threshold, and the threshold is enforced by Pester.
