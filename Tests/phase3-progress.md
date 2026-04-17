# Phase 3 Test Coverage Progress

Goal: add Pester unit tests for 43 region modules that currently have zero coverage.

## Baseline (before work)
- Unit layer: 2698 passed / 0 failed / 4 skipped

## Status
In progress.

## Tier 1 (execution path risk)
- [x] Applications.psm1 (Applications.Catalog.Tests.ps1 - 18 tests)
- [x] UWPApps.psm1 (20 tests)
- [x] Defender.Firewall.psm1 (10 tests)
- [x] Defender.Hardening.psm1 (16 tests)
- [x] Defender.Policies.psm1 (17 tests)
- [x] Gaming.psm1 (27 tests)
- [x] OneDrive.psm1 (8 tests)

## Tier 2 (system-mutating)
- [x] ContextMenu.psm1 (15 tests)
- [x] Cursors.psm1 (6 tests)
- [~] InitialActions.psm1 (skipped — one 876-line monolithic function performing P/Invoke type registration, CIM queries, network I/O, and `$Global:Error.Clear()` at entry. Not unit-testable in isolation.)
- [x] PostActions.psm1 (11 tests — nested helper functions only; outer function untestable)
- [x] System.Power.psm1 (14 tests)
- [x] System.FileAssociations.psm1 (5 tests — module is heavily GUI/dialog-driven; covered Export failure, Import cancel, WinPrtScrFolder paths)
- [~] System.WindowsFeatures.psm1 (skipped — entire module is WPF/XAML GUI; no non-GUI behaviour to test)

## Tier 3 (UI/personalization)
- [x] UIPersonalization.Appearance.psm1 (UIPersonalization.Appearance.Tests.ps1)
- [x] UIPersonalization.Explorer.psm1 (25 tests)
- [x] UIPersonalization.Icons.psm1 (UIPersonalization.Icons.Tests.ps1)
- [x] UIPersonalization.LockScreen.psm1 (13 tests)
- [x] UIPersonalization.Notifications.psm1 (14 tests)
- [x] UIPersonalization.Taskbar.psm1 (25 tests)
- [x] Taskbar.psm1 (Taskbar.Region.Tests.ps1 - 17 tests; NewsInterests + MeetNow + overlap smoke tests)
- [x] TaskbarClock.psm1 (8 tests)
- [x] SystemTweaks.Cleanup.psm1 (SystemTweaks.Cleanup.Tests.ps1)
- [x] SystemTweaks.General.psm1 (11 tests)
- [x] SystemTweaks.HardwarePower.psm1 (19 tests — RazerBlock, S3Sleep, ServicesManual, Teredo, WPBT)
- [x] SystemTweaks.SMBRepair.psm1 (17 tests + 1 env-conditional skip)

## Notes
Existing tests style:
- Use AST parsing to extract FunctionDefinitionAst nodes then Invoke-Expression the text.
- Define helper shims (Write-ConsoleStatus, LogInfo, LogWarning, LogError, Test-Path, etc.)
- Use $script: collections to capture side effects.
- AfterEach removes helper functions.
