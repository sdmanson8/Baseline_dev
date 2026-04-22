# Full Change Log

All notable user-visible changes to Baseline are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project uses [Semantic Versioning](https://semver.org/).

---

## 4.0.0 | 2026-04-17

### Changed

- Release contract is now enforced end-to-end. The Bootstrap self-update path selects exactly one release zip and one matching `.zip.sha256.json` manifest via anchored regex (`^Baseline(?:-portable)?-(v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+)?)\.zip$`) instead of a fuzzy `*.zip` glob, and CI now fails the build before artifact upload if `dist\` does not contain exactly one zip/manifest pair that matches the same pattern.
- Taskbar Widgets tweak no longer executes registry or policy mutations after its own "Skipped: WebExperience package absent" log line. Both the non-personalization and `UIPersonalization` variants now return immediately on the skip branch.
- GPU Hardware-Accelerated Scheduling detection no longer relies on a double-negated `-notmatch "Virtual"` check. Both sides of the condition share a new `Test-IsVirtualMachine` helper in `SharedHelpers/Environment.Helpers.ps1` (exported via `Baseline.SharedHelpers.Environment`) that inspects `Win32_ComputerSystem.Model` against the full list of VM signatures (VMware, VBOX, KVM, QEMU, Xen, Hyper-V).
- `Tools/New-ReleasePackage.ps1` now only hashes the installer and emits the `.zip.sha256.json` manifest inside the `ShouldProcess` branch and with `Test-Path` guards, so `-WhatIf` no longer throws by trying to hash a non-existent archive.

### Fixed

- The themed Readme viewer now repaints correctly on open and on live theme toggle. A new `$setMarkdownViewerTheme` closure applies the active foreground to the `FlowDocumentScrollViewer` and to every block in the document, restoring readability on both the text and FlowDocument rendering paths that previously ignored the theme brush.

### Added

- `Tests/Unit/Bootstrap.ReleaseIntegrity.Tests.ps1` — asserts the Bootstrap release-contract regex, manifest hash lookup, and algorithm-unsupported failure paths.
- `Tests/Unit/Environment.Helpers.Tests.ps1` — new `Describe 'Test-IsVirtualMachine'` block with cases for generic Virtual Machine model strings, VMware/VBOX, physical hardware, and CIM failure.
- `Tests/Unit/Taskbar.Region.Tests.ps1` and `Tests/Unit/UIPersonalization.Taskbar.Tests.ps1` — skip-path tests that assert no registry or policy writes occur when the WebExperience package is absent.

---

## 4.0.0-beta | 2026-04-14

### Changed

- Version bumped from 3.0.0 to 4.0.0 across module manifest, entry scripts, and asset scripts.
- Restructured the main GUI navigation into a top menu bar with `File`, `Actions`, `View`, `Tools`, and `Help` sections.
- Renamed the View menu logs entry to `Open Logs` so the label matches the current dialog-based behavior.
- Kept Safe Mode focused on a reduced surface by hiding the Tools menu and advanced Actions items.
- Kept menu theme state and localization refresh wired into the shared UI update path so labels and brushes follow live theme and language changes.
- Split the Help-menu `Getting Started` content away from the onboarding quick-start copy so Help acts as reference and rediscovery instead of mirroring the main Start Guide.
- Expanded Windows parity coverage across System, Privacy, Explorer, Taskbar, Start Menu, Notifications, and Appearance with new tweak handlers for IPv4 preference, Linux dual-boot UTC clock, ServicesPipeTimeout, Print Spooler, Remote Assistance, Explorer view/navigation options, taskbar acrylic opacity and small icons, Start menu recommendations, lock-screen and startup notifications, and Dynamic Lighting.
- Refined localization QA to treat stable shared labels, tags, and section names as intentional shared terms, and polished visible copy in Gaelic, Amharic, Icelandic, and Gujarati.
- Polished the Swedish restore-defaults copy to use `standardvärden` instead of the literal `standarder` calque.
- Popup pickers for UWP Apps, Windows Features, and Scheduled Tasks now show a tiny realtime progress strip above the action button while the selected command runs asynchronously, then close automatically on completion.
- Shared popup chrome now repaints live when Light or Dark mode is toggled so borderless dialogs follow the active theme instead of staying on their startup colors.
- Delivery Optimization now writes `DODownloadMode = 99` for the disabled state so the backend matches the GUI policy detection path instead of clearing into an ambiguous non-policy state.
- Feature update deferral and quality update deferral now live in the existing updates module, with manifest and preset wiring for the 365-day feature policy and the selectable quality-deferral dropdown (`Default`, `4 days`, `7 days`).

### Added

- Hardened the managed remote workflow path with WinRM preflight checks, structured CLI output, read-only enforcement gates, GPO conflict reporting, operator policy safeguards, release status visibility, support bundle export, and incident reproduction pack generation.
- Expanded the headless lifecycle dispatcher to cover `Upgrade`, `Downgrade`, `Rollback`, `IncidentPack`, and `GpoConflictReport` verbs for managed deployments.
- Added desktop-session CI on `windows-2022` so the embedded PowerShell host is validated in the same environment used by GUI-heavy automation.
- Formalized the installer signing policy with HSM/KMS-backed key storage, RFC 3161 timestamps, verification steps, and incident handling guidance.
- Renamed the Help-menu documentation entry to `Readme`, added `FAQ`, and wired the help menu to themed Readme, FAQ, Release Status, and Troubleshooting dialogs.
- Behavioral coverage for Safe Mode visibility, duplicate action collapse, theme label state, and localization refresh.
- `-ApplyProfile` CLI flag — `Baseline.exe -ProfilePath .\MyConfig.json -ApplyProfile` reads a saved configuration profile and applies every setting to the local machine without opening the GUI. Supports `-DryRun` for a preview-only pass. This enables unattended deployment of a saved configuration to a fresh Windows installation.
- Per-app queued-action system — `Set-AppQueuedAction`, `Get-AppQueuedAction`, `Clear-AppsQueuedActions`, and `Start-AppsModuleQueuedActionAsync` added to the Apps module. Each app can now carry an explicit intent (Install, Uninstall, or DoNothing) that is stored independently of the checkbox selection state, enabling config-file-driven install/uninstall workflows.
- `BtnApplyQueuedActions` and `BtnClearQueuedActions` handler wiring — ActionHandlers now registers click handlers for these two button names. Clicking Apply Queued Actions dispatches the per-app intent queue in a single pass (Install group first, then Uninstall group).
- `Get-CategoryDefaultRunList` — new helper that wraps `Get-WindowsDefaultRunList` and filters by manifest category. Used by per-page reset buttons.
- Per-page "Reset to defaults" button support — `ActionHandlers` now auto-registers click handlers for any XAML button whose name matches `BtnPageReset_<CategoryName>` (spaces replaced by underscores). Clicking one restores Windows defaults for that page's category only, with a confirmation dialog. `Invoke-PageResetToDefaults -Category <string>` provides the same flow programmatically.
- ARM64 support in the launcher project — `RunLauncher.csproj` now targets `net48;net10.0-windows` with `RuntimeIdentifiers` set to `win-x64;win-x86;win-arm64`, enabling the launcher to be compiled and published for ARM64 Windows (e.g., Parallels on Apple Silicon).
- Preset name aliases — `Minimal` now accepts `light` / `conservative`; `Basic` accepts `safe`; `Balanced` accepts `gaming` / `game` / `gaming-only` / `optimized-for-gaming`; `Advanced` accepts `extreme` / `all-on`. Pass any alias to `-Preset` on the command line or in headless mode.
- Added more built-in parity coverage for shell customizations including Take Ownership context-menu integration, file-extension visibility controls, Explorer navigation-pane cleanup for 3D Objects/Home/Gallery, and Quick Access / menu-bar / status-bar visibility controls.
- Improved existing Windows Update Features and added new ones
 - Added the Windows Update notification level selector plus privacy/security controls for blocking Workplace Join / AAD device join messages and preventing BitLocker auto encryption, with matching GUI detection, manifest wiring, preset coverage, and tests.
 - Added Windows Update repair flow plus NFS, Legacy Media, Hyper-V tools, and app catalog parity for `uv`, `Cryptomator`, `Hugo`, and `VeraCrypt`.
 - Added focused execution tests for route resolution, adapter dispatch, batch deduping, update-all delegation, and GUI forwarding.
 - Added Windows Update metered-connection control and Microsoft Store app auto-download control to the existing updates module, plus GUI state detection, manifest wiring, Advanced preset coverage, and focused tests for both paths.
 - Added the dedicated `Updates` tab manifest entries for `Security Updates Only Mode` and `Pause Windows Updates`, along with date-selection GUI/session-state plumbing and manifest-contract coverage for `Date`-typed controls.
- Log file is now deleted and recreated on each launch, matching the previous `run.cmd` behavior.
- Auto-update on launch — Baseline now checks GitHub Releases on every startup; if a newer version is available it streams the release zip to a temp directory while showing live download progress on the existing splash screen progress bar, extracts the new `Baseline.exe`, then relaunches automatically via a self-deleting batch script.
- Comprehensive Localization Coverage
  - Language selector in the installer setup wizard now shows plain language names without the locale code suffix (e.g. `English (US)` instead of `English (en)`).
  - Localized execution view: titles ("Running Selected Tweaks", "Restoring Windows Defaults", "Running Game Mode Workflow"), progress labels (Done, Aborted, Failed, Partially Complete, Starting), and all status bar messages with format-string placeholders.
  - Localized Save Session dialog: title, message, Save/Discard buttons.
  - Localized "Mode: Custom Selection" status indicator.
  - Localized result labels in execution summary (success/failed/skipped).
  - Localized all post-run dialog titles (Run Complete, Run Failed, Defaults Restore, Game Mode Undo variants).
  - Localized detail panel section headers: Behavior, Default, Current State, Impact, Why This Matters, Recovery.
  - Localized detail panel text: checked/unchecked labels, choices, state descriptions, level/recovery labels.
  - Localized risk filter dropdown items (All, Low, Medium, High) with index-based internal mapping to preserve filter logic.
  - Localized footer action buttons: Export Settings, Import Settings, Export System State, Export Config Profile, Undo Last Run, Check Compliance, Audit Log.
  - Localized preset panel: Quick Start, Recommended names and descriptions, "Start here" emphasis text.
  - Localized Game Mode UI: intro text, profile descriptions note, scan note, GAME MODE ACTIVE status message.
  - Localized gaming profile names and descriptions: Casual Gaming, Competitive Gaming, Streaming / Content, Troubleshooting.
  - Localized splash screen "Please wait - opening GUI..." text (when localization data is available).
- Localized pause/resume button labels and running/paused status text.
- 125 locale files now carry full key coverage against the English source (2,421 keys per file). Translations are machine-assisted and still undergoing QA; quality varies by locale and some non-Latin locales are known to contain residual encoding corruption from an earlier import pass — those are flagged in `dev_docs/locale_audit_2026-04-22.md` and scheduled for re-translation.
- Added 79 new languages.
- Completed the Apps view localization and chrome coverage, including UWP install/uninstall prompts, help/log viewers, compliance rows, system feature rows, and scheduled-task rows.
- Application catalog and execution overhaul
  - Split the app catalog into `Module/Data/AppsCategory/*.json` and removed `Module/Data/Applications.json`.
  - Normalized app entries with `EntityType` and `SupportsExecution` so the catalog distinguishes `winget`, `choco`, `placeholder`, and future non-executable types.
  - Added shared package-ID candidate resolution so semicolon-delimited Chocolatey IDs resolve consistently in both state detection and execution.
  - Added separate WinGet and Chocolatey installed/update caches, then wired the Apps view to show installed, update-available, and unsupported states from that mixed model.
  - Reworked install, uninstall, update, and batch actions to route through the shared execution worker with friendly display names and mixed-package support.
  - Kept the card-based Apps UI while preserving single-item buttons, per-card selection checkboxes, and bulk actions for selected entries.

### Fixed

- GUI composition and menu localization now stay aligned after runtime refreshes.
- Localization schema metadata now matches the current en-US key set after the logs-label rename.
- Launcher elevation metadata now matches the bootstrap path by requesting administrator rights.
- Manifest validation data now matches the current region ownership and recovery classifications.
- Test report export now resolves the repository root from the live invocation directory so `Export-TestReport.ps1` and `Run-ValidationSuite.ps1` report the same passing test totals as the direct validation runs.
- Popup pickers for UWP Apps, Windows Features, and Scheduled Tasks transparent windows fixed (#1).
- Language switching no longer throws in deferred WPF dispatcher callbacks; the language selector now invokes captured localization helpers for the empty-state text and language-changed log message.
- Execution orchestration no longer throws when a `DispatcherTimer` tick fires after cleanup clears the mutable pump function; both execution paths now invoke a captured tick handler.

---

## 3.0.0-beta | 2026-04-06

### Added

- **State Tracking & Compliance**
  - System state snapshots: pre-run and post-run capture, export, import, and comparison
  - Configuration profiles: portable JSON profiles built from presets or manual selection
  - Compliance drift detection: scan system state against a profile, highlight Compliant/Drifted/Unknown, one-click "Fix Drift"
  - Audit trail: append-only JSON Lines log of every execution with timestamp, tweak, old/new values, user, and machine
  - Audit viewer: GUI timeline with filter-by-action, HTML/Markdown export, and clear-old-entries
  - Scheduled automation: register/unregister Baseline as a Windows Scheduled Task for recurring compliance checks
  - Multi-machine targeting (CLI preview, untested on Server): deploy profiles or run compliance checks against remote machines via PowerShell Remoting

- **UX Clarity & Flow Redesign**
  - Pre-flight checks: admin elevation, disk space, WMI health, VSS service, event log, system restore validation
  - Plan summary panel: grouped view of Will Change / Already Set / Requires Restart / High Risk before execution
  - Visual diff view: side-by-side current state vs. planned post-run state
  - Structured post-run results: color-coded result cards with status filter pills, lazy loading, and per-tweak recovery hints
  - Per-monitor DPI awareness (V2 with shcore fallback) for crisp rendering on high-DPI displays
  - Runtime language switching with session persistence and auto-detection from system locale
  - Localization framework with per-language JSON files
  - Deterministic execution labeling and dependency surfacing

- **Icon UX System**
  - FluentSystemIcons font architecture with IconRegistry and IconFactory
  - Icon usage tiers: Primary Actions (mandatory), Navigation (mandatory), Status (conditional)
  - Icon size system: 16-20px buttons, 16px tabs, 12-14px status, 12px logs
  - Semantic color rules inheriting from theme palette
  - Screen-by-screen integration for header, tabs, presets, search/filter, gaming, preview, execution, and dialogs
  - Text-only fallback for graceful degradation when font is unavailable
  - Spacing, responsive, and accessibility rules

- **Preset Redesign & Governance**
  - Renamed expert preset to Advanced with `Advanced.json`
  - Tightened Basic to better match its low-risk promise
  - Added preset policy linting: Minimal, Basic, and Balanced reject uninstall/remove/delete actions
  - Added `WorkflowSensitivity` normalization and validation
  - Advanced warning modal with impact categories, restore-point guidance, and recommended buttons
  - Preset explanation cards with honest descriptions of scope and risk

- **GUI & UX Polish**
  - Impact summary bar with visual differentiation for toggles, choices, actions, and uninstall/remove
  - Selected-only, high-risk-only, restorable-only, and gaming-related filters
  - Badges and state chips for toggle/action/remove behavior, restart, reversibility, and current state
  - Scenario tags, blast-radius explanations, grouped Preview Run sections
  - Safe Mode as conservative default, clearing hidden advanced selections when Expert Mode turns off
  - Compact "Details" toggle replacing verbose "Why this matters" blocks
  - Consistent row spacing between tabs
  - Persistent state indicators for Expert Mode and Light/Dark Mode
  - Compact language-popup search box with live filtering by language name or code

- **Execution, Logging & Recovery**
  - Separated failed, skipped, not applicable, and restart-pending outcomes
  - Run summaries that surface successful changes and restart-required outcomes explicitly
  - Linked restore-point creation before larger or higher-risk guided runs
  - Concrete remediation hints for recovery guidance

- **Gaming Tab Expansion**
  - New tweak implementations for gaming performance
  - Data and manifest wiring for gaming entries
  - Normal vs Expert Mode classification for gaming tweaks

- **Architecture Hardening**
  - Eliminated false `failed!` outcomes in restore/default flows
  - Eliminated mid-run interactive dialogs for batch execution
  - Metadata consistency sweep across all manifest entries
  - Naming and repo standardization sweep
  - Post-run remediation text for common failure classes (access denied, reboot required, missing dependency, network)
  - Retry support limited to Direct-recovery, restorable, non-removal, non-action items only
  - Package/install/uninstall operations shown as a distinct summary category

- **Security & Architecture**
  - Per-monitor DPI awareness via SetProcessDpiAwarenessContext P/Invoke (user32.dll) with SetProcessDpiAwareness fallback (shcore.dll)
  - SHA-256 checksum validation for all remote downloads (C++ Redistributables, .NET runtimes)
  - DWM window chrome interop for native dark/light title bar and Win11 rounded corners
  - AST-based command parsing replacing all Invoke-Expression usage

- **Testing & Validation**
  - Headless GUI composition/contract tests for dialog creation paths
  - Headless tests for Safe/Expert/Game Mode transitions
  - Headless tests for responsive tab/dropdown switching
- Headless tests for preview count generation
- Headless tests for restore/default wording paths
- Headless tests for icon/text fallback behavior
- Focused unit coverage for localization directory resolution and language selector icon family/glyph wiring
- Focused unit coverage for application execution routing, adapter dispatch, batch deduping, update-all handling, and GUI forwarding
- Focused unit coverage for Delivery Optimization policy routing and cache cleanup behavior
- Focused unit coverage for feature update deferral and quality update deferral routing
- Focused unit coverage for metered-connection update handling and Microsoft Store app auto-download routing
- Desktop integration matrix validated: Win10 + Win11

- **Codebase Audit Remediation**
  - Resolved public positioning contradiction between README and release strategy
  - Cleaned launch trust surface: local launch primary, iwr|iex demoted to advanced
  - Added historical context note to changelog
  - Automated GUI test layer added: 6 test categories
  - Desktop integration matrix run and documented: Win10 + Win11 validated
  - GUI state surface reduction across top 5 files by $Script: references
  - Large module extraction: 14 sub-modules extracted from System, UIPersonalization, PrivacyTelemetry, SystemTweaks, Defender
  - Runtime Write-Host audit across 10 files
  - ExecutionPolicy Bypass audit across 6 files with documentation
  - Invoke-Expression/iex audit with safety comments
  - Quality & Validation section added to README
  - Release/documentation pack labeled and separated

### Changed

- Version bumped from 2.0.0 to 3.0.0 across module manifest, entry scripts, and asset scripts
- Window sizing now clamps MinWidth, MinHeight, and dimensions to the available work area so the GUI fits on low-resolution screens (e.g. 1024x768)
- GUI.psm1 further modularized: 35 extracted scripts in Module/GUI/ (up from 14), core orchestrator at ~2,970 lines
- Region modules extracted: System.psm1 (5 sub-modules), UIPersonalization.psm1 (3), PrivacyTelemetry.psm1 (2), SystemTweaks.psm1 (2), Defender.psm1 (2)
- Tab content architecture: TabControl used as header-only strip with manual content management via single ScrollViewer
- Button styling rebuilt with programmatic ControlTemplate via FrameworkElementFactory (7 variants)
- CheckBox toggle-switch implemented as custom XAML ControlTemplate with animated thumb
- Brush caching system with frozen SolidColorBrush instances for thread-safe WPF rendering
- ObservableState pub/sub system dispatches to UI thread via Dispatcher.Invoke at DataBind priority
- Filter cache invalidation consolidated to single FilterGeneration integer
- Session state schema upgraded to version 9
- Execution background runspace uses fresh module import with ConcurrentQueue-only communication
- Localization strings corrected: "Windows 11 23H2" changed to "Windows 10 (1903 and later) and Windows 11" across 46 language files
- Local launch promoted to primary path in README; remote bootstrap demoted to advanced section
- Preview Run and execution summary dialog chrome now source their labels from the active localization set

### Fixed

- GUI window no longer overflows screen on high-DPI displays due to missing DPI awareness
- GUI now fits 1024x768 and other low-resolution screens by clamping to available work area
- Header toolbar no longer clips the language button — dynamic MinWidth adjustment measures actual header width at render time
- Language selector now resolves bundled localization files reliably across module and extracted GUI roots, restores saved language from the same resolved path, and keeps the header globe icon on the shared Fluent System Icons pipeline
- GUI localization no longer falls back to English when a non-English language is selected; hashtable-backed localization lookups now resolve correctly across the live interface
- Restored sessions and startup initialization now reapply the selected language to active controls instead of leaving existing GUI content in English
- Light theme no longer makes the custom minimize, maximize, and close buttons effectively disappear; caption buttons now restyle with the active title-bar theme
- Zero remaining Invoke-Expression usage in production code (AST-based parsing throughout)
- Eliminated false `failed!` outcomes on edge cases where registry values were never created
- Eliminated mid-run interactive dialogs blocking batch execution
- Logging no longer silently broken after module force-import in background runspace
- WPF event handler function scope resolution fixed for dispatcher closures
- Manifest options array double-nesting resolved
- Preset/scenario button active state now syncs correctly across tabs
- Preview Run status summaries, action labels, and expand/collapse hints no longer remain hard-coded in English when another language is active

---

## 2.1.0-beta | 2026-03-25

### Added

- GUI with search, filters, risk labels, preset selection, and preview-before-run workflow
- Four built-in presets: Minimal, Basic, Balanced, Advanced
- Game Mode with Casual, Competitive, Streaming, and Troubleshooting profiles
- Scenario modes for Workstation, Privacy, and Recovery workflows
- Environment-aware recommendation text based on detected gaming hardware and software
- Preview Run showing what will change, what is already desired, what is risky, and what can be undone
- Post-run summary with outcome classification, remediation hints, retry guidance, and next-step actions
- Headless execution with preset, function, Game Mode profile, and scenario profile support
- Interactive session bootstrap with tab completion for functions, presets, and profiles
- Remote bootstrap one-liner for downloading and launching from GitHub
- Manifest-driven tweak metadata with risk, recovery, restart, and preset-tier classification
- Manifest validation tooling for duplicates, missing metadata, and ownership mismatches
- Preset generation from manifest metadata for Minimal, Basic, and Balanced tiers
- Release packaging helper for building clean public zip archives
- Recovery metadata: RecoveryLevel (Direct, DefaultsOnly, RestorePoint, Manual) and Restorable flags
- Retry support limited to trustworthy failure categories with explicit reasoning
- Blast radius and scenario-impact text in preview and detail views
- File logging, GUI log forwarding, and structured execution outcome tracking
- Settings import/export and restore snapshot actions
- Helper modules for environment, registry, packages, maintenance, taskbar, error handling, and advanced startup
- Coverage across privacy, telemetry, security, Defender, UI, taskbar, Start menu, context menu, cursors, OneDrive, UWP apps, networking, gaming, and system behavior
- Windows AI removal helper with non-interactive and GUI execution support
- Support for Windows 10, Windows 11, and Windows Server 2016 through 2025

### Changed

- Renamed the project to Baseline across all scripts, modules, and documentation
- Replaced all bare `Remove-ItemProperty -ErrorAction Stop` restore paths with `Remove-RegistryValueSafe` across every region module (ContextMenu, Gaming, StartMenuApps, System, SystemTweaks, Taskbar added to previously converted StartMenu, UIPersonalization, PrivacyTelemetry, OSHardening)
- Guarded `RawUI.WindowTitle` and interactive host assumptions behind `Test-InteractiveHost` checks
- Downgraded optional sub-step misses in coarse wrapper actions (e.g., Performance Tuning) to skipped or not applicable instead of failed
- Improved post-run remediation text for common failure classes including access denied, reboot required, missing dependency, and network failures
- Limited retry to Direct-recovery, restorable, non-removal, non-action items only
- Batch execution now runs fully headless with no mid-run interactive dialogs
- Package/install/uninstall operations shown as a distinct summary category with heavier treatment than simple toggles
- Extracted Game Mode logic from Manifest.Helpers into dedicated GameMode.Helpers module
- Extracted Scenario Mode logic into dedicated ScenarioMode.Helpers module
- Extracted preset resolution logic from entry script into Preset.Helpers module
- Extracted recovery/undo logic into dedicated Recovery.Helpers module
- Moved Game Mode data files into organized Module/Data/GameMode/ subdirectory
- Reduced Manifest.Helpers from 1,760 to 641 lines by splitting responsibilities
- Reduced Baseline.ps1 from 548 to 443 lines — now purely a launcher/dispatcher
- Reduced GUI.psm1 from 14,172 to 9,892 lines by extracting five function groups into Module/GUI/ (ExecutionSummary, PreviewBuilders, PresetManagement, GameModeUI, SessionState)
- Added shared state documentation (Module/GUI/STATE.md) classifying all 111 $Script: variables
- Added shared object models reference (Module/GUI/MODELS.md) documenting 6 canonical object shapes
- Added smoke-test script (Tools/Test-SmokeTest.ps1) for release validation
- Added scenario expansion policy documentation in ScenarioMode.Helpers.ps1

## 2.1.0-beta | 2026-03-21

- Minor changes to the GUI

## 1.0.0-beta | 2026-03-17

- Initial Commit
