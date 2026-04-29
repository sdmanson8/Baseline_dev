# Baseline v4.0.0 (beta)

<p align="center">
  <kbd>
    <a href="https://github.com/sdmanson8/Baseline_dev/releases/latest"><img src="https://img.shields.io/badge/Download_Beta_Release-green?labelColor=151B23&color=151B23&style=for-the-badge"></a>
    <a href="https://github.com/sdmanson8/Baseline/releases/latest"><img src="https://img.shields.io/badge/Download_Stable_Release-green?labelColor=151B23&color=151B23&style=for-the-badge"></a>
  </kbd>
</p>

<p align="center">
  PowerShell-based Windows configuration with manifest-driven tweaks, GUI, audit trails, and headless automation.
</p>

<p align="center">
  Baseline is a manifest-driven platform for applying, tracking, and reversing Windows configuration changes — with a full GUI, compliance drift detection, audit trails, snapshot/restore, and headless automation. Localization ships with 124 locale files at full key coverage; translation quality is machine-assisted and under active QA.
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/ef431953-c31f-4347-b62a-c51e381c5e69" alt="Baseline GUI hero screenshot" width="1072">
</p>

---

## Table of Contents

- [Overview](#overview)
- [Supported platforms](#supported-platforms)
- [Why Baseline is different](#why-baseline-is-different)
- [Key features](#key-features)
- [Presets](#presets)
- [Screenshots](#screenshots)
- [Installation & trust](#installation--trust)
- [Start Guide](#start-guide)
- [Repository layout](#repository-layout)
- [Developer tooling](#developer-tooling)
- [Quality & Validation](#quality--validation)
- [Known limitations](#known-limitations)
- [FAQ / troubleshooting](#faq--troubleshooting)

## Overview

Baseline is a PowerShell-based utility for configuring, auditing, hardening, and tracking Windows 10 and Windows 11 installations.

It includes:

- a WPF desktop GUI with search, filters, risk labels, preset selection, and per-monitor DPI awareness
- configuration tracking: compliance drift detection, system state snapshots, configuration profiles, and audit trails
- pre-flight checks, plan summary, and visual diff view before any changes are applied
- structured post-run results with per-tweak status, recovery hints, and filter pills
- headless execution for scripted or repeatable runs, including scheduled automation and lifecycle playbooks
- multi-machine targeting via PowerShell Remoting with WinRM preflight checks and per-target results
- modular manifests for tweaks, metadata, and presets
- logging, validation, and metadata tooling for maintainability
- coverage across privacy, telemetry, security, Defender, UI, taskbar, Start menu, OneDrive, UWP apps, networking, gaming, and system behavior

### Defender ASR note

The Take Ownership context-menu toggle is a shell convenience feature. On systems with Microsoft Defender Attack Surface Reduction rules enabled, that shell extension can trigger Microsoft-documented ASR behavior. Review the Defender metadata and Preview Run output before enabling it on hardened endpoints.

## Supported platforms

<table>
  <tr>
    <td align="center">Windows 10</td>
    <td align="center">Windows 11</td>
  </tr>
  <tr>
    <td align="left"><a href="https://support.microsoft.com/topic/windows-10-update-history-8127c2c6-6edf-4fdf-8b9f-0f7be1ef3562"><img src="https://img.shields.io/badge/Windows%2010%20x64-PowerShell%205.1-green?labelColor=151B23&color=151B23&style=for-the-badge"></a></td>
    <td align="left"><a href="https://support.microsoft.com/topic/windows-11-version-25h2-update-history-99c7f493-df2a-4832-bd2d-6706baa0dec0"><img src="https://img.shields.io/badge/Windows%2011-PowerShell%205.1-green?labelColor=151B23&color=151B23&style=for-the-badge"></a></td>
  </tr>
  <tr>
    <td align="left"><a href="https://support.microsoft.com/topic/windows-10-and-windows-server-2019-update-history-725fc2e1-4443-6831-a5ca-51ff5cbcb059"><img src="https://img.shields.io/badge/Windows%2010-LTSC%202019-green?labelColor=151B23&color=151B23&style=for-the-badge"></a></td>
    <td align="left"><a href="https://support.microsoft.com/topic/windows-11-version-24h2-update-history-0929c747-1815-4543-8461-0160d16f15e5"><img src="https://img.shields.io/badge/Windows%2011-ARM64-green?labelColor=151B23&color=151B23&style=for-the-badge"></a></td>
  </tr>
  <tr>
    <td></td>
    <td align="left"><a href="https://support.microsoft.com/topic/windows-11-version-24h2-update-history-0929c747-1815-4543-8461-0160d16f15e5"><img src="https://img.shields.io/badge/Windows%2011%20LTSC%202024-PowerShell%205.1-green?labelColor=151B23&color=151B23&style=for-the-badge"></a></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><img src="https://img.shields.io/badge/Windows%20Server%202016--2025-Best--effort%2C%20untested-gray?labelColor=151B23&color=151B23&style=for-the-badge"></td>
  </tr>
</table>

## Why Baseline is different

Most Windows tweak tools are opaque script blocks with no metadata, no preview, and no way to track what changed. Baseline structures everything through manifests:

- **Manifest-backed metadata** — every tweak carries risk labels, restart flags, reversibility metadata, and recovery guidance instead of living in opaque script blocks
- **Preview-first execution** — pre-flight checks, plan summary, and visual diff before anything runs
- **Configuration tracking** — compliance drift detection, system state snapshots, configuration profiles, and append-only audit trails
- **Preset semantics** — four named presets with clear scope and honest warnings instead of a single "run everything" button
- **Scenario modes** — purpose-built profiles for Game Mode, Workstation, Privacy, and Recovery that stay separate from the core preset ladder
- **Headless support** — scheduled automation and logging for repeatable setups without the GUI

## Presets

Recommended starting point: **Basic**

Safe Mode beginner starting point: **Minimal**

| Preset | Recommended for | Not recommended for | Summary |
| --- | --- | --- | --- |
| Minimal | Safe Mode beginners who want the most conservative first run | Users expecting broader tuning or privacy changes on the first pass | Recommended Safe Mode first step with small quality-of-life and maintenance changes |
| Basic | Most users and shared PCs | Users who want deeper, opinionated changes | Low-risk cleanup and usability improvements |
| Balanced | Enthusiasts who accept moderate tradeoffs | Work, family, or domain-managed PCs | Broader privacy, performance, and system changes |
| Advanced | Experienced users who knowingly accept higher-impact changes | Normal users and managed devices | Expert tuning, debloat, and hardening |

Balanced is the point where a restore point is a good idea. Advanced is the expert preset and should be treated as expert-only.

> Before you run **Advanced**
>
> Create a restore point if you can, review Preview Run carefully, and expect changes to Windows features, update behavior, networking, security, and compatibility.

Baseline ships with four built-in presets:

- **Minimal** — recommended first step in Safe Mode; smallest baseline of practical quality-of-life and maintenance tweaks
- **Basic** — lower-risk usability, privacy, and cleanup recommendations
- **Balanced** — broader privacy, performance, and system configuration changes
- **Advanced** — expert tuning, debloat, and hardening for experienced users

## Warning philosophy

Baseline is intentionally opinionated about when it warns and when it stays conservative.

- `Minimal` and `Basic` are meant to stay out of uninstall/remove and higher-friction hardening territory
- `Balanced` is where privacy, performance, and workflow tradeoffs become more noticeable, so Preview Run and a restore point are recommended
- `Advanced` is not the "best" preset. It is the expert preset for users who knowingly accept higher compatibility and recovery risk
- Risk labels, restart indicators, Preview Run, and restore guidance are part of the product, not decoration

## Key features

- **State tracking and compliance**
  - system state snapshots (pre-run and post-run capture, export, import)
  - portable configuration profiles (export your setup as JSON, reapply later)
  - compliance drift detection with one-click "Fix Drift" remediation
  - append-only audit trail with timeline view and HTML/Markdown export
  - scheduled automation via Windows Scheduled Tasks
  - multi-machine targeting via PowerShell Remoting with CLI and GUI workflows (Server remains best-effort)

- **UX clarity and safety**
  - automated pre-flight checks (admin, disk space, WMI, VSS, system restore)
  - plan summary panel showing what will change before execution
  - visual diff view (current state vs. planned post-run state)
  - structured post-run results with status filter pills and recovery hints
  - per-monitor DPI awareness for crisp rendering on high-DPI displays

- **Preset-driven configuration**
  - Minimal, Basic, Balanced, Advanced
  - Safe Mode / Expert Mode gating

- **GUI workflow**
  - category tabs with icon headers
  - quick search and multi-filter panel (risk, category, selected-only, gaming-related)
  - risk and impact labels with inline details and rationale
  - Light, Dark, and System theme with session persistence
  - localization with runtime language switching

- **Headless workflow**
  - run individual functions directly
  - automate repeatable configurations with presets
  - dry-run mode for inspecting planned changes
  - compliance checks with JSON profile input

- **Manifest-driven design**
  - tweak metadata stored in JSON (368 entries across 17 category files)
  - preset definitions stored separately from implementation
  - validation tooling for duplicate entries, missing metadata, and ownership mismatches

- **Scenario modes**
  - Game Mode with Casual, Competitive, Streaming, and Troubleshooting profiles
  - Workstation, Privacy, and Recovery scenario workflows
  - environment-aware recommendation text based on detected hardware and software
  - profile-driven defaults that stay separate from the core preset ladder

- **Operational tooling**
  - file logging with thread-safe Named Mutex protection
  - GUI log forwarding with color-coded viewer
  - bootstrap/launcher support
  - File -> Settings... dialog, GUI settings import/export, restore snapshot, and single-level undo
  - helper modules for environment, registry, packages, maintenance, taskbar, and error handling

## Screenshots

Windows 10 GUI
<p align="center">
  <img src="https://github.com/user-attachments/assets/1926b16f-8c18-4bf8-a149-a5b3ed2e67a0" alt="Windows 10 GUI" width="1072">
</p>

Windows 10 Non-Interactive
<p align="center">
  <img src="https://github.com/user-attachments/assets/4b21309f-f131-4909-b4c8-3fbe55d41be5" alt="Windows 10 Non-Interactive" width="1072">
</p>

Windows 11 GUI
<p align="center">
  <img src="https://github.com/user-attachments/assets/46dc692e-81ce-4400-a46a-ebb956c8f088" alt="Windows 11 GUI" width="1072">
</p>

Windows 11 Non-Interactive
<p align="center">
  <img src="https://github.com/user-attachments/assets/9fff35f8-a232-4044-b5ee-b831bda7430e" alt="Windows 11 Non-Interactive" width="1072">
</p>

## Installation & trust

Download `Baseline-<version>.zip` from the [GitHub Releases](https://github.com/sdmanson8/Baseline_dev/releases) page. The zip contains `Baseline-setup-<version>.exe`, which runs either as a per-machine installer or as a portable extract — you choose on the first wizard page.

> **Baseline 4.x public preview releases ship unsigned.** Code signing (HSM-held certificate, timestamp authority) is planned but not in place yet. See [dev_docs/Installer-Signing-Policy.md](dev_docs/Installer-Signing-Policy.md) for the full posture and the `-AllowUnsignedPreview` / `BASELINE_PREVIEW_UNSIGNED` opt-in used by the lifecycle tooling.

Because the installer is unsigned, Windows SmartScreen will show a **"Windows protected your PC"** dialog on first launch. To proceed:

1. Click **More info**.
2. Click **Run anyway**.

If you want to verify the download before running it, compare its SHA-256 against the published release hash manifest asset (`Baseline-<version>.zip.sha256.json`) on the same GitHub Release:

```powershell
Get-FileHash .\Baseline-setup-<version>.exe -Algorithm SHA256
```

Once 4.x is promoted to a signed release channel, this section and the policy doc will be updated and `BASELINE_PREVIEW_UNSIGNED` will no longer be accepted.

## Start Guide

### Safe Mode beginner start guide

1. Open Baseline
2. Select `Minimal`
3. Click `Preview Run`
4. Click `Apply Tweaks`
5. Restart if prompted

### Local launch (recommended)

```powershell
.\Baseline.exe
```

### Direct PowerShell launch

```powershell
.\Bootstrap\Baseline.ps1
```

> **Note:** If your execution policy blocks unsigned scripts, run `Set-ExecutionPolicy Bypass -Scope Process` first. This restricts the bypass to the current session only.

### Headless / noninteractive run

```powershell
.\Baseline.exe -Preset Basic
```
```powershell
.\Baseline.exe -Functions "DiagTrackService -Disable", "DiagnosticDataLevel -Minimal", "UWPApps -Uninstall"
```
```powershell
.\Baseline.exe -GameModeProfile Competitive
```

> **Note:** Headless runs may require `Set-ExecutionPolicy Bypass -Scope Process` if your execution policy blocks unsigned scripts.

### Unattended / scripted use

Baseline ships a stable CLI surface for unattended automation (clean-install pipelines, MDT/SCCM, scheduled tasks). All flags work with `Baseline.exe` (the launcher forwards every argument straight to `Bootstrap\Baseline.ps1`) or with `Bootstrap\Baseline.ps1` directly.

#### Apply an exported configuration profile

```powershell
.\Baseline.exe -ProfilePath .\baseline-profile.json
```

`-ProfilePath` alone implies apply — Baseline never silently no-ops a config-file argument. The run is headless: no GUI window, no modal dialogs, no input prompts.

#### Export a first-logon command for autounattend

Use the GUI's `Export First-Logon Command` action after you've saved a configuration profile. It prompts for the saved `*.json` profile path and writes an `autounattend.xml`-compatible `FirstLogonCommands` XML snippet that runs Baseline with that profile on first boot.

The generated snippet wraps the selected path into a `Baseline.exe --configfile "<saved-profile.json>" --apply` command line and XML-escapes it for pasting into your answer file.

Drop the generated XML and the saved profile onto install media together. If Baseline itself lives somewhere other than `Baseline.exe` on the target machine, update the generated `CommandLine` before you paste the snippet into your answer file.

#### Apply a named preset unattended

```powershell
.\Baseline.exe -ApplyPreset Balanced
```

`-ApplyPreset <name>` is the unattended shortcut for "apply preset <name> with no GUI". For interactive use, the original `-Preset <name>` flag still works.

#### List available presets

```powershell
.\Baseline.exe -ListPresets
```

Prints the preset catalog (Name / Description / Path / Tier) to stdout and exits 0. Safe to call from automation that needs to discover preset names; runs without loading the GUI or any heavy modules.

#### Force headless on a regular run

```powershell
.\Baseline.exe -Preset Basic -NoGui
```

`-NoGui` forces headless even when no other intent flag is present. Errors are written to the launch trace and daily log; no `MessageBox` is ever shown.

#### Redirect the daily log

```powershell
.\Baseline.exe -Preset Basic -LogPath C:\Logs\baseline-{date}.log
```

`-LogPath` accepts an absolute path, a relative path, or a directory. Missing parent directories are created on demand. If the override is unwritable, Baseline falls back to the default location (`%LOCALAPPDATA%\Baseline\UserState\Logs\`) with a warning.

#### Exit codes

Unattended runs emit structured exit codes so CI/CD or scheduled tasks can branch on the result:

| Code | Meaning |
|------|---------|
| `0` | Clean — every selected tweak applied successfully (or no tweaks were selected) |
| `1` | Partial — at least one tweak failed; daily log + classified errors describe which |
| `2` | Preflight fail — Baseline could not run (single-instance gate denied, missing dependencies, malformed CLI args) |

Exit codes are emitted from both the headless `-Functions` / `-ProfilePath` paths and the GUI-driven Apply path, so an embedded host (`Baseline.exe` invoked from a parent process) can read the result either way.

#### Combining flags

```powershell
.\Baseline.exe -ProfilePath .\my-profile.json -LogPath C:\Logs\baseline.log -NoGui
```

```powershell
.\Baseline.exe -ApplyPreset Minimal -DryRun
```

`-DryRun` works with every apply path and pins exit code `0`.

### Dry run (preview without applying)

```powershell
.\Baseline.exe -Preset Balanced -DryRun
```

### Compliance check

```powershell
.\Baseline.exe -ComplianceCheck -ProfilePath .\my-profile.json
```

### Remote targeting (preview)

```powershell
.\Baseline.exe -TargetComputer SERVER01,SERVER02 -ComplianceCheck -ProfilePath .\my-profile.json
```

### Managed remote workflow

Baseline remote targeting is GUI-capable for connected targets and includes the orchestration surface needed for pilot and preview deployment.

- supported today: CLI-based `-TargetComputer` runs over WinRM / PSSession with connectivity checks, preflight reachability checks, and per-machine results
- supported today: the GUI exposes `Connect to Computer...` / `Disconnect`, remote compliance checks, remote apply runs, saved approval policies, and a remote console for connected-target operations
- supported today: operator console safeguards cover allow/deny/confirm decisions, change windows, kill switch state, and live prompts for sensitive actions
- supported today: remote approval gates, audit retention controls, support bundle export, incident reproduction pack generation, release status visibility, and GPO conflict reporting for deployment review
- supported today: headless lifecycle verbs cover `Upgrade`, `Downgrade`, `Rollback`, `IncidentPack`, and `GpoConflictReport`
- supported today: read-only mode blocks persistence, audit, and registry write helpers when `-ReadOnly` is active
- managed-environment prerequisites still need explicit review: WinRM enablement, firewall access, credentials, Group Policy / domain restrictions, and audit requirements

### Remote bootstrap (advanced)

For convenience, you can download and install directly from GitHub:

```powershell
iwr https://raw.githubusercontent.com/sdmanson8/Baseline_dev/main/Bootstrap/Bootstrap.ps1 -UseBasicParsing | iex
```

The bootstrap pulls the latest release zip from GitHub, downloads the matching `Baseline-<version>.zip.sha256.json` manifest, verifies SHA-256 for both the zip and the extracted `Baseline-setup-<version>.exe`, and then runs the installer. After the installer exits, if an installed `Baseline.exe` can be found it is launched (honoring `-Preset` / `BASELINE_PRESET`). If it cannot be found, launch Baseline from the Start Menu.

> **Security note:** This still uses pipe-to-IEX for the bootstrap script itself. The release payload is hash-verified before execution, but the bootstrap entry script is not separately signature-validated or hash-pinned. For higher assurance, download the release assets manually from the Releases page, verify the published hash manifest yourself, and run `Baseline-setup-<version>.exe` directly.

### Interactive session / tab completion

```powershell
Set-ExecutionPolicy Bypass -Scope Process; .\Completion\Interactive.ps1
```

Then run commands such as:

```powershell
Baseline -Preset Basic
```
```powershell
Baseline -Preset .\Module\Data\Presets\Minimal.json
```
```powershell
Baseline -GameModeProfile Competitive
```
```powershell
Baseline -ScenarioProfile Privacy
```

To run a preset through the raw bootstrap flow, set `BASELINE_PRESET` first:

```powershell
$env:BASELINE_PRESET = 'Basic'
iwr https://raw.githubusercontent.com/sdmanson8/Baseline_dev/main/Bootstrap/Bootstrap.ps1 -UseBasicParsing | iex
```

The bootstrap flow downloads the release zip to `%USERPROFILE%\Downloads\Baseline-Bootstrap`, runs the bundled setup installer, then launches the installed `Baseline.exe`. When `BASELINE_PRESET` is present, the preset is forwarded into the noninteractive runner after install.

Preview Run lets you inspect every change before it is applied. In Safe Mode, the GUI surfaces `Minimal`, `Apply Tweaks`, and `Undo Selection Change` as the beginner path. Standard mode keeps the existing `Basic`, `Run Tweaks`, and `Restore Snapshot` wording, while Expert Mode keeps `Run Tweaks` but also uses `Undo Selection Change`. Scenario-mode actions for Workstation, Privacy, and Recovery remain available alongside Import Settings and Export Settings. Post-run summaries can also export a rollback profile when direct undo commands are available. That rollback export is separate from `Undo Selection Change` and from restoring Windows defaults.

## Repository layout

```text
Baseline.exe        Local launcher
Bootstrap/Baseline.ps1    Main launcher and GUI/headless entry point
Bootstrap/          Remote bootstrap script
Completion/         Interactive session bootstrap and tab completion
Tools/              Validation and maintenance scripts
Assets/             Bundled binaries, icons, and support scripts
Localizations/      Locale folders plus shared metadata
Module/             Feature modules, GUI logic, manifests, and data slices
docs/website/       GitHub Pages source for the project site
```

## Developer tooling

### Validate manifest ownership / duplicates

```powershell
powershell -File .\Tools\Validate-ManifestData.ps1
```

### Add generated metadata to manifests

```powershell
powershell -File .\Tools\Add-MissingMetadata.ps1
```

### Generate preset files from manifest metadata

```powershell
powershell -File .\Tools\Generate-PresetFiles.ps1 -DryRun
```

The generator currently targets the lower-risk preset tiers and is meant to reduce drift between metadata and curated preset files.

### Author custom preset files

Custom preset files live under `Module/Data/Presets/` and use the same JSON shape as the checked-in presets:

```json
{
  "Name": "MyPreset",
  "Entries": [
    "FunctionName",
    "AnotherFunction -Disable"
  ]
}
```

Each entry is a command string that starts with a manifest-referenced function name and then optional parameters. Use the checked-in `Minimal`, `Basic`, `Balanced`, and `Advanced` preset files as templates, and validate changes with:

```powershell
powershell -File .\Tools\Test-PresetGeneration.ps1
```

If you are generating presets from manifest metadata, `Tools/Generate-PresetFiles.ps1` can rebuild the curated low-risk tiers from the manifest data.

### Validate generated preset files

```powershell
powershell -File .\Tools\Test-PresetGeneration.ps1
```

This generates fresh `Minimal`, `Basic`, and `Balanced` preset files and validates them against manifest policy. The same check runs in GitHub Actions alongside validation of the checked-in preset files.

### Build a release zip

```powershell
powershell -File .\Tools\New-ReleasePackage.ps1
```

This produces `Baseline-<version>.zip` plus `Baseline-<version>.zip.sha256.json` in `dist/`.

### Build installer packages (per-user and per-machine)

```powershell
powershell -File .\Tools\New-InstallerPackage.ps1
```

This produces installer executables in `dist/` using the exact portable payload generated by `Tools/New-ReleasePackage.ps1`.

### Lifecycle playbooks

```powershell
powershell -File .\Tools\Invoke-LifecyclePlaybook.ps1 -Operation Upgrade -InstallerPath .\dist\Baseline-setup-4.0.0.exe
```
```powershell
powershell -File .\Tools\Invoke-LifecyclePlaybook.ps1 -Operation Rollback -RollbackProfilePath .\bundle\rollback.json -Execute
```

The lifecycle playbook tooling verifies the installer or rollback profile, emits a structured playbook, and can execute the requested upgrade, downgrade, or rollback workflow when `-Execute` is supplied.

### Incident reproduction pack

```powershell
powershell -File .\Tools\New-IncidentReproductionPack.ps1 -SupportBundlePath .\Bundle.zip
```

This turns a Baseline support bundle into a repro pack with incident metadata, preflight findings, recent audit context, and a markdown summary you can hand to operators or support staff.

### Installer signing policy

The formal release-signing policy is documented in [dev_docs/Installer-Signing-Policy.md](dev_docs/Installer-Signing-Policy.md). It defines the artifact trust contract Baseline expects before upgrade, downgrade, or rollback promotion.

### Developer docs

The developer reference notes are in:

- [dev_docs/MODELS.md](dev_docs/MODELS.md) - shared object shapes used by the GUI and helper modules
- [dev_docs/STATE.md](dev_docs/STATE.md) - GUI state containers, closures, and late-bound function captures
- [dev_docs/Roadmap.md](dev_docs/Roadmap.md) - roadmap framing and Tier-3 readiness interpretation
- [dev_docs/RuntimeCache.md](dev_docs/RuntimeCache.md) - launcher runtime-cache path, reuse rules, and growth behaviour

## Quality & Validation

Baseline includes 29 dedicated test scripts covering:

- **Unit tests**: registry helpers, environment detection, preset resolution, error handling, game mode helpers, package management
- **Contract tests**: manifest structure, tweak metadata, GUI function capture, observable state
- **Smoke tests**: full preset execution, module loading, GUI construction boundaries
- **Fixture tests**: execution summary with clean/partial/retryable/restore scenarios
- **Integration tests**: end-to-end execution on supported Windows editions

Automated CI runs on every push through GitHub Actions for structural validation and manifest checks. Desktop-specific tests (WPF rendering, service manipulation, package installation) require a local or self-hosted Windows VM — the tested matrix is documented in Tests/Integration/README.md.

The maintainer validation suite also includes a documentation consistency check that verifies the enterprise claims in the docs still have matching code and test evidence.

## Known limitations

- **Icon system**: The FluentSystemIcons UI architecture is built and the GUI loads it when available, with a safe fallback when the font cannot be resolved. Release Status now surfaces the icon-system state.
- **Remote deployment**: Multi-machine targeting via `-TargetComputer` works, and the GUI can connect to a target, manage approvals, and run compliance / apply workflows against it.
- **Managed remote workflow**: Baseline exposes the remote console, saved approval policies, release status visibility, version pinning, audit retention controls, support bundle export, and troubleshooting surfaces needed for connected-target operations.
- **Managed deployment readiness**: Baseline includes WinRM preflight checks, structured CLI output, read-only enforcement gates, GPO conflict reporting, operator policy safeguards, and incident reproduction pack generation for managed deployments.

## FAQ / troubleshooting

- Which preset should I start with? In Safe Mode, start with `Minimal` for the most conservative first run. Outside Safe Mode, `Basic` remains the default recommendation for most users.
- When should I use `Advanced`? Only after reviewing Preview Run and only when you are comfortable with feature removals, harder-to-reverse changes, and manual recovery if something conflicts with your setup.
- A tweak failed. What should I try first? Re-run Baseline as administrator, reboot, review the Preview Run output, and check the detailed log before retrying.
- Can Baseline automatically undo everything? No. Some changes expose direct undo commands, some only return to supported Windows defaults, and some still rely on restore points or manual recovery. Uninstall/remove actions deserve extra care.
- How do I run a compliance check? Export a configuration profile from the GUI (or create one from a preset via the CLI), then run `.\Baseline.exe -ComplianceCheck -ProfilePath .\profile.json`.

## Disclaimer / support scope

- Baseline is intended for the supported Windows versions listed above and for users with local admin control over the device.
- Review changes before applying them. Baseline is a configuration utility, not a risk-free cleanup button.
- Create a restore point or backup before `Balanced`, `Advanced`, large app removal, or unfamiliar changes.
- Managed, work, school, or domain-enrolled devices should be reviewed with the appropriate admin team before use.
- Third-party security suites, OEM utilities, and heavily customized images can change outcomes and may require manual troubleshooting.

## Notes

- Baseline is intended for users who want explicit control over Windows behavior.
- Some tweaks may require administrator rights.
- Some tweaks may require a restart to fully apply.
- Higher-risk and advanced changes should be reviewed carefully before use.

## License

See the repository license file for licensing information.
