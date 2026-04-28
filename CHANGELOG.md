# Full Change Log

All notable user-visible changes to Baseline are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project uses [Semantic Versioning](https://semver.org/).

---

## v4.0.0-beta

### Changed

- Version bumped from 3.1.0-beta to 4.0.0-beta across module manifest, entry scripts, and asset scripts.
- Unified process exit codes across headless and GUI paths via
  `Get-BaselineHeadlessExitCode` (tracked preset contract — `0`=clean,
  `1`=partial / all-failed, `2`=preflight-failed, plus a `Reason` field
  of `clean` / `no-tweaks-selected` / `partial` / `all-failed` /
  `preflight-failed`). The headless `-Functions` and `-ApplyProfile`
  pipelines in `Bootstrap/Baseline.ps1` now wrap the apply loop in
  `try { ... } finally { ... }` so `PostActions`, `Errors`, and
  `Write-AuditRecord` always run and the helper-driven exit code is
  always pinned, even if a tweak throws mid-loop; empty-set early
  returns and `-DryRun` / preview branches route through the same
  helper. The GUI-driven Apply pipeline
  (`Module/GUI/ExecutionOrchestration.ps1`) pins
  `$Global:LASTEXITCODE` at the dispatcher-timer run-completion site
  (after `Write-AuditRecord`, before `Complete-GuiExecutionRun`), with
  the helper lookup guarded by `Get-Command -ErrorAction SilentlyContinue`
  and an outer `try/catch` routed through
  `Write-DebugSwallowedException -Source 'ExecutionOrchestration.RunCompletion.ExitCode'`
  so a missing helper module never breaks the GUI completion path.
- Restructured the main GUI navigation into a top menu bar with `File`, `Actions`, `View`, `Tools`, and `Help` sections: renamed the View menu logs entry to `Open Logs` to match the dialog-based behavior, hid the Tools menu and advanced Actions items in Safe Mode, kept menu theme/localization refresh wired into the shared UI update path so labels and brushes follow live theme and language changes, and split the Help-menu `Getting Started` content away from the onboarding quick-start copy so Help acts as reference and rediscovery instead of mirroring the main Start Guide.
- Expanded Windows parity coverage across System, Privacy, Explorer, Taskbar, Start Menu, Notifications, and Appearance with new tweak handlers for IPv4 preference, Linux dual-boot UTC clock, ServicesPipeTimeout, Print Spooler, Remote Assistance, Explorer view/navigation options, taskbar acrylic opacity and small icons, Start menu recommendations, lock-screen and startup notifications, and Dynamic Lighting.
- Refined localization QA to treat stable shared labels, tags, and section names as intentional shared terms, and polished visible copy in Gaelic, Amharic, Icelandic, Gujarati, and Swedish (restore-defaults now uses `standardvärden` instead of the literal `standarder` calque).
- Popup pickers for UWP Apps, Windows Features, and Scheduled Tasks now show a tiny realtime progress strip above the action button while the selected command runs asynchronously, then close automatically on completion.
- Shared popup chrome now repaints live when Light or Dark mode is toggled so borderless dialogs follow the active theme instead of staying on their startup colors.
- Delivery Optimization now writes `DODownloadMode = 99` for the disabled state so the backend matches the GUI policy detection path instead of clearing into an ambiguous non-policy state.
- Feature update deferral and quality update deferral now live in the existing updates module, with manifest and preset wiring for the 365-day feature policy and the selectable quality-deferral dropdown (`Default`, `4 days`, `7 days`).
- Release contract is now enforced end-to-end. The Bootstrap self-update path selects exactly one release zip and one matching `.zip.sha256.json` manifest via anchored regex (`^Baseline(?:-portable)?-(v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+)?)\.zip$`) instead of a fuzzy `*.zip` glob, and CI now fails the build before artifact upload if `dist\` does not contain exactly one zip/manifest pair that matches the same pattern.
- Taskbar Widgets tweak no longer executes registry or policy mutations after its own "Skipped: WebExperience package absent" log line. Both the non-personalization and `UIPersonalization` variants now return immediately on the skip branch.
- GPU Hardware-Accelerated Scheduling detection no longer relies on a double-negated `-notmatch "Virtual"` check. Both sides of the condition share a new `Test-IsVirtualMachine` helper in `SharedHelpers/Environment.Helpers.ps1` (exported via `Baseline.SharedHelpers.Environment`) that inspects `Win32_ComputerSystem.Model` against the full list of VM signatures (VMware, VBOX, KVM, QEMU, Xen, Hyper-V).
- `Tools/New-ReleasePackage.ps1` now only hashes the installer and emits the `.zip.sha256.json` manifest inside the `ShouldProcess` branch and with `Test-Path` guards, so `-WhatIf` no longer throws by trying to hash a non-existent archive.
- Normalized imported module function help so the GUI/headless callable surface has `Get-Help`-ready `.SYNOPSIS` and `.DESCRIPTION` coverage, while removing generated-looking or machine-style comments from the maintained module surface.
- Split the P5 monolith targets into explicit loader parents and ordered helper files for bootstrap startup helpers and the main GUI helper groups, with the extraction contract documented in `Docs/P5-ExtractionMap.md`.
- Moved release installation into a verified archive handoff: the raw bootstrap now verifies the release zip and manifest, extracts the archive, then runs `Bootstrap.Install.ps1` from the verified payload; release packaging and CI now include and validate the install script and helper hashes.

---

### Added

- Microsoft Edge removal (tracked issues #540 / #538 / #567) — new
  `EdgeRemoval` Action-type entry in the UWPApps region
  (`Module/Regions/UWPApps.psm1`, `Module/Data/UWPApps.json`),
  Removes
  Legacy UWP Edge, Chromium Edge, EdgeUpdate, Edge folders, registry
  keys (direct / pattern / MuiCache), shortcuts, and Edge scheduled
  tasks. **EdgeWebView2 is preserved**: the folder cleanup pattern
  excludes `*EdgeWebView*`, and
  `HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState` is
  exported before EdgeUpdate uninstall and re-imported afterward
  (vendor's documented technique for keeping EdgeWebView2 alive). The
  `MSEdgeHTM` UserChoice gotcha is handled two ways: HKCU
  `FileExts\.html|.htm|.xml|.pdf\UserChoice` ProgId is captured before
  removal and restored afterward (skipping entries that were pointing
  at `MSEdgeHTM`, so a pre-existing non-Edge default browser
  preference survives), and `MSEdgeHTM` itself is rewritten via
  `ie_to_edge_stub.exe` so any UserChoice still pointing at it is
  forwarded to the actual default browser. Installs an `OpenWebSearch`
  redirect (stub + `OpenWebSearch.cmd` + repair scheduled task at
  `\Baseline\OpenWebSearchRepair`, runs at logon as SYSTEM) that
  re-applies the `microsoft-edge://` protocol handler and `MSEdgeHTM`
  shim if Edge or Windows Update overwrites them. DISM uses a
  30-second timeout with one retry. Logs to
  `%ProgramData%\Baseline\Logs\EdgeRemovalLog.txt` with 500 KB
  rotation. Action-type, Risk=High, PresetTier=Advanced, Caution=true,
  Restorable=false, RequiresRestart=true. Pester
  `Tests/Unit/EdgeRemoval.Tests.ps1` adds 25 contract tests covering
  function shape, nested-helper presence, renamed paths,
  EdgeWebView2 preservation, UserChoice backup/restore ordering, JSON
  entry shape, and reference fidelity (DISM timeout, MSEdgeHTM redirect,
  scheduled-task sweep exclusions).
- Custom power plan and Hybrid Sleep toggle — `Module/Regions/System/System.Power.psm1` gains a
  `-CustomPower` parameter set on `PowerPlan` that duplicates from
  Ultimate Performance, renames to `CustomPowerPlan`, and activates the
  canonical fixed GUID `57696e68-616e-6365-506f-776572000000`. Idempotent:
  re-running with `-CustomPower` reactivates the existing plan without
  re-duplicating. The new
  `HybridSleep` function adds Enable/Disable parameter sets that call
  `Set-PowerSchemeSettingVisibility` (unhide) followed by
  `Set-PowerSchemeChoiceSetting` against SUB_SLEEP / HYBRIDSLEEP
  (`238c9fa8-0aad-41ed-83f4-97be242c8f20` /
  `94ac6d29-73ce-41a6-809f-6363ba21b47e`); failures from unsupported
  hardware (laptops without S4) log a warning and continue rather than
  throwing. JSON entries added to `Module/Data/System.json`: `Custom`
  appended to PowerPlan Options / DisplayOptions, plus a new
  `HybridSleep` Toggle (PresetTier=Balanced, Caution=false). Pester
  `Tests/Unit/System.Power.Tests.ps1` covers custom-plan duplication,
  idempotent re-activation, hybrid on/off, visibility unhide, and the
  unsupported-hardware fallback (24 tests, all green).
- Window position persistence — Baseline now remembers
  its last window position and size between launches, with bounds
  validation against the current display layout so a window saved on a
  monitor that's no longer attached doesn't open off-screen. New
  shared helper slice `Module/SharedHelpers/WindowPosition.Helpers.ps1`
  exposes five functions through the
  `Baseline.SharedHelpers.WindowPosition` wrapper:
  `Get-BaselineDisplayWorkAreas` (enumerates monitor work areas via
  `[System.Windows.Forms.Screen]`),
  `Test-BaselineWindowRectVisible` requires 120 px × 40 px of overlap with at
  least one work area before accepting a saved rect),
  `Get-BaselineSavedWindowPlacement` /
  `Save-BaselineWindowPlacement` (round-trip Left / Top / Width /
  Height / Maximized / RememberWindowPosition through the existing
  `Baseline-user-prefs.json` store), and
  `Resolve-BaselineWindowPlacement` (orchestrator that returns the
  saved rect, the centred default, or a `Source`-tagged fallback when
  the saved rect is off-screen or persistence is disabled).
  `Module/GUI/WindowSetup.ps1` calls Resolve on startup, registers an
  `Add_Closing` handler that persists `RestoreBounds` when maximized
  (so the next launch comes up at a usable size), and adds a checkable
  "Remember Window Position" item to the title-bar context menu that
  toggles the user-pref key. Pester
  `Tests/Unit/WindowPosition.Helpers.Tests.ps1` covers all five
  helpers across 21 tests.
- Take Ownership ASR copy refresh — JSON tooltip /
  detail copy for the Attack Surface Reduction toggle in the Defender
  region clarifies the Microsoft-documented mitigation language and
  notes that the Take-Ownership shell extension (when enabled) can
  trigger certain ASR rules; the README's Defender section gains a
  matching callout. No behavioural change to the rule itself.
- `windows_hardening.cmd` parity sweep — closed the remaining Priority 1–3
  parity backlog items tracked for the Windows hardening import.
  - **LOLBin outbound firewall ruleset** is now a Toggle. The 44
    per-LOLBin block rules in
    `Module/Regions/Defender/Defender.Firewall.psm1` are tagged with
    `-Group 'Baseline-LOLBin-Block'` so disable is a single
    `Remove-NetFirewallRule -Group 'Baseline-LOLBin-Block'` call, and
    the `Module/Data/Defender.json` manifest entry was promoted to
    `Type=Toggle`, `Restorable=true`, `OnParam=Enable` /
    `OffParam=Disable`, `RecoveryLevel=Direct`. Coverage:
    `Tests/Unit/Defender.Firewall.Tests.ps1` 13 / 13.
  - **Mount Manager hardening** — new `MountManagerAutoMount` Toggle in
    `Module/Regions/OSHardening/ProtectionHardening.psm1` writes
    `HKLM:\SYSTEM\CurrentControlSet\Services\MountMgr\NoAutoMount=1`
    on Enable (blocks automatic mount of newly attached volumes / USB /
    ISO / VHD content; programmatic mount via `mountvol`,
    `Mount-DiskImage`, or Disk Management still works) and removes
    the value on Disable. Manifest entry "Mount Manager NoAutoMount"
    in `Module/Data/OSHardening.json` (Toggle, Restorable=true,
    Caution=true, Risk=Medium, PresetTier=Advanced,
    RequiresRestart=true). Coverage:
    `Tests/Unit/ProtectionHardening.MountManager.Tests.ps1`.
  - **Lock-screen biometric hardening** — two new Toggles in
    `Module/Regions/UIPersonalization/UIPersonalization.LockScreen.psm1`.
    `LockScreenCamera` writes `NoLockScreenCamera=1` under
    `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization` to
    block camera access from the lock screen; `BlockDomainPINLogon`
    writes `AllowDomainPINLogon=0` under
    `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System` to disable
    convenience-PIN sign-in for domain accounts. Both are Restorable
    Toggles with manifest entries in
    `Module/Data/UIPersonalization.json` ("Lock Screen Camera" Risk=Low
    PresetTier=Balanced; "Block Domain PIN Logon" Caution=true,
    Risk=Medium, PresetTier=Advanced). Coverage:
    `Tests/Unit/UIPersonalization.LockScreen.Tests.ps1` 19 / 19 (8 new).
  - **Firewall logging upgraded to per-profile** —
    `WindowsFirewallLogging` in `Defender.Firewall.psm1` now loops over
    `domainprofile|privateprofile|publicprofile` and writes a separate
    `pfirewall_<profile>.log` (16 MB cap, dropped + allowed connections
    enabled) per profile via 12 `netsh advfirewall` calls (4 settings ×
    3 profiles), replacing the single
    `set allprofiles logging ...` block.
  - **Defender scan tuning toggles** — two new Toggles in
    `Module/Regions/Defender/Defender.CoreProtection.psm1`.
    `DefenderScanCPULimit` calls
    `Set-MpPreference -ScanAvgCPULoadFactor 25` on Enable and 50 on
    Disable; `DefenderSignatureUpdateInterval` calls
    `-SignatureUpdateInterval 1` (hourly) on Enable and 0 (WU-managed)
    on Disable. Both honour the `$Script:DefenderEnabled` short-circuit.
    Manifest entries added to `Module/Data/Defender.json` ("Defender
    Scan CPU Limit" Risk=Low PresetTier=Safe; "Defender Signature
    Update Interval" Risk=Low PresetTier=Balanced). Coverage:
    `Tests/Unit/Defender.CoreProtection.ScanTuning.Tests.ps1` 10 / 10.
  Detect scriptblocks added to `Module/GUI/DetectScriptblocks.ps1` for
  every new toggle (`MountManagerAutoMount`, `LockScreenCamera`,
  `BlockDomainPINLogon`, `DefenderScanCPULimit`,
  `DefenderSignatureUpdateInterval`). The Adobe Reader DC STIG entry is
  implemented in `Module/Regions/OSHardening/ProtectionHardening.psm1`.
- WSL install flow back-end and GUI picker — new shared helper slice
  `Module/SharedHelpers/Wsl.Helpers.ps1` exposing nine functions
  through the new `Baseline.SharedHelpers.Wsl` module wrapper:
  `Get-BaselineWslDistributionCatalogUrl` (returns the canonical
  configured `DistributionInfo.json` URL,
  honours a `BASELINE_WSL_CATALOG_URL` env override),
  `ConvertFrom-BaselineWslDistributionCatalogJson` (pure projector to
  `[pscustomobject]@{Distribution, Alias}` sorted by FriendlyName,
  defensive on empty / malformed / missing-`Distributions` payloads
  so a stale CDN copy cannot crash the host),
  `Get-BaselineWslDistributionCatalog` (Invoke-WebRequest wrapper with
  a `-Fetcher` test-hook scriptblock, returns `@()` on any network
  failure), `Test-BaselineWslPrerequisite` (gates on Windows 10 build
  ≥ 19041 / 2004 — the minimum for the single-line `wsl --install`
  flow — defers to `Get-BaselineSystemPlatformInfo` when present and
  falls back to `Get-CimInstance` otherwise),
  `Get-BaselineWslInstallationState` (resolves `wsl.exe`, parses
  `wsl --list --quiet` output via a `-ListInvoker` test hook),
  `Install-BaselineWslDistribution` (runs
  `wsl.exe --install --distribution <Alias>` with
  `SupportsShouldProcess`, validates the alias against an optional
  `-Catalog`, captures exit code and exceptions through a
  `-StartProcessInvoker` test hook),
  `Enable-BaselineMicrosoftUpdateDelivery` (writes
  `HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings\AllowMUUpdateService=1`
  via `Set-RegistryValueSafe` so WSL kernel updates flow through
  Windows Update — the "Receive updates for other Microsoft
  products" toggle), and `Invoke-BaselineWindowsUpdateScan` (runs
  `UsoClient.exe StartInteractiveScan` with `SupportsShouldProcess`
  so the new MU delivery setting is picked up immediately). The GUI
  distro picker dialog is exposed via `Module/GUI/DialogHelpers.ps1`
  and the runner is implemented by
  `Module/SharedHelpers/Wsl.Helpers.ps1::Invoke-BaselineWslInstallFlow`.
- Connect-to-Computer dialog rewrite — the Tools menu's `Connect to
  Computer` action now opens a themed WPF dialog (replacing the legacy
  `Microsoft.VisualBasic.Interaction.InputBox` + `Get-Credential`
  prompts). The dialog accepts multiple targets in one box (commas,
  semicolons, pipes, or whitespace), surfaces invalid tokens before any
  WinRM call, exposes a `Connection method` dropdown
  (WinRM HTTP / WinRM HTTPS / SSH), and offers `Use current` /
  `Use alternate` credential modes with a `Domain\Username` +
  `PasswordBox` grid that toggles enabled state. A new `Test Connection`
  button runs `Test-BaselineRemoteConnectivity` on a background runspace
  (DispatcherTimer-polled) and renders ✔ / ❌ / ⛔ rows per target so
  the user sees what is reachable before connecting.
- Persistent Remote Mode banner in the main window — once a remote
  connection is established, a dedicated banner row above the tab host
  shows `Remote Mode (METHOD): targets` and carries a one-click
  `Disconnect` button that shares the menu's handler. Banner appears
  for WinRM, WinRM/HTTPS, and SSH connections and clears automatically
  on disconnect.
- Support Bundle now captures the most recent connectivity probe results
  alongside the existing remote-orchestration history. When the Connect
  dialog's `Test Connection` button has been used, exporting a Support
  Bundle includes a new `remote-connectivity.json`
  (`Baseline.RemoteConnectivity` schema, version 1) listing each target's
  reachability, status, error, failure category, policy-block flag, and
  connection method, plus a `Files.RemoteConnectivity` pointer in the
  bundle index.
- SSH and WinRM-over-HTTPS reachability probes —
  `Test-BaselineRemoteConnectivity` gained a `-ConnectionMethod`
  parameter (`WinRM` / `WinRMHttps` / `SSH`). HTTPS routes through
  `Test-WSMan -UseSSL`; SSH performs a 5-second TCP/22 probe via
  `System.Net.Sockets.TcpClient` so users can verify OpenSSH-based
  PowerShell remoting before committing to a session. Method is echoed
  on every result row.
- Browser enterprise policies back-end — new shared helper slice
  `Module/SharedHelpers/BrowserPolicies.Helpers.ps1` exposing
  `Get-BaselineBrowserPolicySettings`,
  `Get-BaselineBrowserPolicyBackupRoot`,
  `ConvertTo-BaselineBrowserPolicyBackupKey`,
  `Set-BaselineBrowserPolicySettings`,
  `Restore-BaselineBrowserPolicySettings`, and
  `Get-BaselineBrowserPolicyStatus` through the new
  `Baseline.SharedHelpers.BrowserPolicies` module wrapper. Catalog covers
  Edge (5 entries: SmartScreenEnabled, SitePerProcess, SSLVersionMin
  `tls1.2`, PasswordManagerEnabled, AutofillCreditCardEnabled at
  `HKLM:\Software\Policies\Microsoft\Edge`) and Chrome (6 entries:
  BlockThirdPartyCookies, DnsOverHttpsMode `automatic`,
  SafeBrowsingProtectionLevel, PasswordManagerEnabled,
  AutofillCreditCardEnabled, AutofillAddressEnabled at
  `HKLM:\Software\Policies\Google\Chrome`). Each apply snapshots the
  prior live value plus an `Existed=0/1` flag into a Baseline-owned
  backup key so `Restore-` can either rewrite the original or remove
  the live entry; idempotent re-apply preserves the genuine original.
  Honours `-WhatIf`. Firefox / Brave deferred (their `policies.json`
  surface is non-registry).
- Authentication / domain hardening back-end — new shared helper slice
  `Module/SharedHelpers/AuthHardening.Helpers.ps1` exposing
  `Get-BaselineAuthHardeningSettings`,
  `Get-BaselineAuthHardeningBackupRoot`,
  `ConvertTo-BaselineAuthHardeningBackupKey`,
  `Set-BaselineAuthHardeningSettings`,
  `Restore-BaselineAuthHardeningSettings`, and
  `Get-BaselineAuthHardeningStatus` through the new
  `Baseline.SharedHelpers.AuthHardening` module wrapper. 12 catalog
  entries spanning Kerberos (`SupportedEncryptionTypes = 0x18`, AES
  only), NTLM restrict (sending + receiving = 1, audit-only),
  LDAP signing (`LDAPClientIntegrity = 2`), four Netlogon secure-channel
  settings, smart-card removal lock (`ScRemoveOption = "1"`), DLL search
  hardening (`SafeDllSearchMode = 1` and `CWDIllegalInDllSearch = 0xFFFFFFFF`),
  and `PSLockdownPolicy = 4` (system-wide CLM). NTLM restrict and
  PSLockdownPolicy carry `Caution = $true` and are skipped by the apply
  unless `-IncludeCaution` is supplied — this enforces the
  audit-then-deny pattern on NTLM and explicit opt-in on system-wide
  Constrained Language Mode, which routinely breaks third-party tooling.
  Same backup / restore primitive as the browser policy slice.
- `Tests/Unit/BrowserPolicies.Helpers.Tests.ps1` — 24 tests covering
  the catalog, env-overridable backup root, colon-to-double-underscore
  backup key converter, DWord and string apply paths, prior-value
  snapshot, `Existed=0` round-trip, idempotent re-apply,
  `-WhatIf`, restore (Existed=1 / Existed=0 / NoBackup), and status
  classification (Hardened / Drift / NotSet, BackupPresent).
- `Tests/Unit/AuthHardening.Helpers.Tests.ps1` — 27 tests covering the
  12-entry catalog (Caution flags, AES-only Kerberos value, NTLM = 1
  audit-not-deny, REG_SZ `ScRemoveOption`, `0xFFFFFFFF` encoded as
  int32 -1, all documented HKLM paths), env-overridable backup root,
  dotted-Id key converter, apply paths including Caution-skip and
  `-IncludeCaution` opt-in, restore round-trips, and status
  classification with the `Caution` flag forwarded to UI.
- OS Hardening protection actions from `windows_hardening.cmd` - eleven
  new `Action` manifest entries in `Module/Data/OSHardening.json`
  backed by `Module/Regions/OSHardening/ProtectionHardening.psm1`:
  - Office macro/document hardening: `MacroRuntimeScanScope` forces
    Office AMSI runtime macro scanning; `RtfDocuments` blocks legacy RTF
    documents in Word; `OneNoteEmbeds` blocks embedded-file launch from
    OneNote policy hives.
  - Credential theft hardening: `WDigestCaching` disables WDigest
    credential caching; `ProtectedCreds` enables protected credentials
    delegation.
  - Auditing baseline: `AuditingBaseline` enables command-line process
    creation logging and applies the `auditpol` baseline for process
    creation, logon, special logon, removable storage, IPsec Driver,
    security state change, system integrity, and sensitive privilege use.
  - PowerShell hardening: `PowerShellTranscription` enables
    transcription with invocation headers under `%SystemDrive%\PSTranscripts`;
    `PowerShellV2` disables the Windows PowerShell 2.0 optional feature
    pair without forcing a restart.
  - CVE-specific mitigations: `CertPaddingCheck` enables Authenticode
    padding checks for native and Wow6432Node Wintrust config; `ActiveXLockdown`
    sets ActiveX zone `1004=3` across zones 0-4; `MsMsdtHandler` removes
    the `HKCR\ms-msdt` protocol handler idempotently.
- `Tests/Unit/ProtectionHardening.Office.Tests.ps1`,
  `Tests/Unit/ProtectionHardening.Credentials.Tests.ps1`,
  `Tests/Unit/ProtectionHardening.Auditing.Tests.ps1`,
  `Tests/Unit/ProtectionHardening.PowerShell.Tests.ps1`, and
  `Tests/Unit/ProtectionHardening.CVE.Tests.ps1` - 32 focused Pester
  tests covering path creation, registry writes, per-subcategory
  `auditpol` dispatch, optional-feature dispatch, idempotent protocol
  handler removal, and fail-closed error reporting.
- OS Hardening Tweaks GUI surface for the previously-shipped Ransomware
  ftype and Networking surface-reduction back-ends — four new
  `Toggle` manifest entries in `Module/Data/OSHardening.json`, each
  `Restorable=true`, `Risk=High`, `Impact=High`, `RecoveryLevel=Direct`,
  `CompatibilitySensitivity=High`, `PresetTier=Advanced`:
  - "Ransomware Script Extension Lockdown"
    (`Function: RansomwareScriptLockdown`) — Notepad redirection across
    the canonical 11-extension list (`.bat .cmd .js .vbs .hta .wsf
    .reg .msc .rdg .application .deploy`); includes the CVE-2020-0765
    RDCMan mitigation. Delegates to
    `Set-/Restore-BaselineRansomwareFtypeMitigation`.
  - "NetBIOS over TCP/IP Disable"
    (`Function: NetbiosOverTcpip`) — walks
    `HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces`
    and writes `NetbiosOptions=2` per adapter. Delegates to
    `Disable-/Restore-BaselineNetBiosOverTcpip`.
  - "Network Surface Hardening (TCP/IP, LLMNR, mDNS, RPC)"
    (`Function: NetworkHardeningRegistry`) — applies the 10-setting
    registry catalog (TCP/IP DoS hardening: IGMPLevel,
    DisableIPSourceRouting, EnableICMPRedirect,
    TcpMaxDataRetransmissions, KeepAliveTime, PerformRouterDiscovery,
    EnableDeadGWDetect; LLMNR + mDNS disable; RPC endpoint-mapper
    authentication). Delegates to
    `Set-/Restore-BaselineNetworkHardeningRegistrySettings`.
  - "WinRM Service Disable"
    (`Function: WinRMService`) — captures prior `StartType` + `Status`
    into `HKLM:\Software\Baseline\NetworkHardening\WinRMService`,
    stops the service, and sets startup to Disabled. Delegates to
    `Disable-/Restore-BaselineWinRMService`.
- `Tests/Unit/ProtectionHardening.RansomwareScriptLockdown.Tests.ps1` —
  12 Pester tests asserting per-extension dispatch, summary-line tally
  (mitigated / already / skipped on Enable, restored / skipped on
  Disable), `SkipReason` propagation, fail-closed behaviour on helper
  throw, and parameter contract (rejects empty invocation and
  `-Enable -Disable` together). Mocks the helper layer
  (`Set-/Restore-BaselineRansomwareFtypeMitigation`) rather than
  registry primitives.
- `Tests/Unit/ProtectionHardening.NetworkHardening.Tests.ps1` — 21
  Pester tests covering the three Networking toggle handlers
  (`NetworkHardeningRegistry`, `NetbiosOverTcpip`, `WinRMService`) on
  the same axes (per-record dispatch, applied / restored / skipped
  tally including adapter count for NetBIOS, `SkipReason` logging,
  WinRM `NotInstalled` and `NoBackup` skip paths, fail-closed on
  helper throw, parameter contract).
- `Tests/Unit/Bootstrap.ReleaseIntegrity.Tests.ps1` — asserts the Bootstrap release-contract regex, manifest hash lookup, and algorithm-unsupported failure paths.
- `Tests/Unit/Environment.Helpers.Tests.ps1` — new `Describe 'Test-IsVirtualMachine'` block with cases for generic Virtual Machine model strings, VMware/VBOX, physical hardware, and CIM failure.
- `Tests/Unit/Taskbar.Region.Tests.ps1` and `Tests/Unit/UIPersonalization.Taskbar.Tests.ps1` — skip-path tests that assert no registry or policy writes occur when the WebExperience package is absent.
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
- I also implemented the refinement you asked for: the manifest validator now warns when an entry has OS-sensitive Tags but no PlatformSupport. That change is in `Module/SharedHelpers/Manifest.Helpers.ps1`, with tests added in `Tests/Unit/Manifest.Helpers.PlatformSupport.Tests.ps1`. The runtime rule still defaults missing PlatformSupport to available; the warning is dev-time validation only.
- Improved existing Windows Update Features and added new ones
 - Added the Windows Update notification level selector plus privacy/security controls for blocking Workplace Join / AAD device join messages and preventing BitLocker auto encryption, with matching GUI detection, manifest wiring, preset coverage, and tests.
 - Added Windows Update repair flow plus NFS, Legacy Media, Hyper-V tools, and app catalog parity for `uv`, `Cryptomator`, `Hugo`, and `VeraCrypt`.
 - Added focused execution tests for route resolution, adapter dispatch, batch deduping, update-all delegation, and GUI forwarding.
 - Added Windows Update metered-connection control and Microsoft Store app auto-download control to the existing updates module, plus GUI state detection, manifest wiring, Advanced preset coverage, and focused tests for both paths.
 - Added the dedicated `Updates` tab manifest entries for `Security Updates Only Mode` and `Pause Windows Updates`, along with date-selection GUI/session-state plumbing and manifest-contract coverage for `Date`-typed controls.
- Log file is now deleted and recreated on each launch, matching the previous `run.cmd` behavior.
- Auto-update on launch — Baseline now checks GitHub Releases on every startup; if a newer version is available it streams the release zip to a temp directory while showing live download progress on the existing splash screen progress bar, extracts the new `Baseline.exe`, then relaunches automatically via a self-deleting batch script.
- Comprehensive localization coverage across the GUI: installer setup wizard language selector (plain language names, no locale-code suffix), execution view (run titles, progress labels, status bar messages with format-string placeholders), Save Session dialog, "Mode: Custom Selection" indicator, execution summary result labels, post-run dialog titles (Run Complete, Run Failed, Defaults Restore, Game Mode Undo variants), detail panel section headers and body text (checked/unchecked, choices, state descriptions, level/recovery), risk filter dropdown (with index-based internal mapping to preserve filter logic), footer action buttons (Export/Import Settings, Export System State, Export Config Profile, Undo Last Run, Check Compliance, Audit Log), preset panel (Quick Start, Recommended, "Start here"), Game Mode UI and gaming profile names/descriptions (Casual, Competitive, Streaming / Content, Troubleshooting), splash screen "Please wait - opening GUI..." text, and pause/resume button labels with running/paused status text.
- 124 locale files now carry full key coverage against the English source (2,487 keys per file). Translations are machine-assisted and still undergoing QA; quality varies by locale and some non-Latin locales are known to contain residual encoding corruption from an earlier import pass — those are flagged in `dev_docs/locale_audit_2026-04-22.md` and scheduled for re-translation.
- Added 79 new languages.
- Completed the Apps view localization and chrome coverage, including UWP install/uninstall prompts, help/log viewers, compliance rows, system feature rows, and scheduled-task rows.
- Application catalog and execution overhaul
  - Split the app catalog into `Module/Data/AppsCategory/*.json` and removed `Module/Data/Applications.json`.
  - Normalized app entries with `EntityType` and `SupportsExecution` so the catalog distinguishes `winget`, `choco`, `placeholder`, and future non-executable types.
  - Added shared package-ID candidate resolution so semicolon-delimited Chocolatey IDs resolve consistently in both state detection and execution.
  - Added separate WinGet and Chocolatey installed/update caches, then wired the Apps view to show installed, update-available, and unsupported states from that mixed model.
  - Reworked install, uninstall, update, and batch actions to route through the shared execution worker with friendly display names and mixed-package support.
  - Kept the card-based Apps UI while preserving single-item buttons, per-card selection checkboxes, and bulk actions for selected entries.
- The themed Readme viewer now repaints correctly on open and on live theme toggle. A new `$setMarkdownViewerTheme` closure applies the active foreground to the `FlowDocumentScrollViewer` and to every block in the document, restoring readability on both the text and FlowDocument rendering paths that previously ignored the theme brush.

---

### Fixed

- Restored the full Pester regression suite to green after the P5 split
  work: inspection tests now read each parent loader plus its explicit
  split children in load order, safe-registry test doubles match the
  current `Remove-RegistryValueSafe` paths, and the suite verifies at
  4,889 passed / 5 skipped / 0 failed under Windows PowerShell 5.1.
- Remote-target helper module import no longer fails under `Set-StrictMode`
  when cache variables have not been initialized yet; the remote session
  cache and orchestration defaults are now created through guarded
  `Get-Variable` checks at module load.
- GUI footer and style refresh now keep the Export First-Logon Command
  button synchronized with localization, tooltips, and enabled state.
- Non-fatal GUI dialog and theme fallbacks now route through
  `Write-DebugSwallowedException` breadcrumbs, including changelog/README
  path resolution, release-status setup, remote-console support bundle
  export cleanup, header toggle chrome, and menu/scrollbar theme logging.
- Aborted GUI runs no longer silently report exit code `0` / `clean`
  when the user cancels mid-run with some tweaks unstarted. When
  `$abortedRun` is set, no failures were recorded, and the succeeded
  count is below the total, the unstarted remainder is now rolled into
  the failed count so the helper surfaces `partial` / `all-failed`
  instead of masking the abort as a clean run.
- Restored the completed HKCU safe-registry sweep after corruption drift:
  remaining current-user writes/removals in System, StartMenuApps,
  ContextMenu, Gaming, Defender hardening, PrivacyTelemetry, and
  file-association paths now route through `Set-RegistryValueSafe` /
  `Remove-RegistryValueSafe`. `Set-RegistryValueSafe` now supports
  `REG_NONE` values used by OpenWithProgids file-association entries.
- GUI composition and menu localization now stay aligned after runtime refreshes.
- Localization schema metadata now matches the current en-US key set after the logs-label rename.
- Launcher elevation metadata now matches the bootstrap path by requesting administrator rights.
- Manifest validation data now matches the current region ownership and recovery classifications.
- Test report export now resolves the repository root from the live invocation directory so `Export-TestReport.ps1` and `Run-ValidationSuite.ps1` report the same passing test totals as the direct validation runs.
- Language switching no longer throws in deferred WPF dispatcher callbacks; the language selector now invokes captured localization helpers for the empty-state text and language-changed log message.
- Execution orchestration no longer throws when a `DispatcherTimer` tick fires after cleanup clears the mutable pump function; both execution paths now invoke a captured tick handler.
- Updated matching unit tests, including the StartMenuApps, System, and System.FileAssociations paths.

---

## 3.1.0-beta | 2026-04-26

### Changed

- Version bumped from 3.0.0-beta to 3.1.0-beta across module manifest, entry scripts, and asset scripts.

### Fixed

- **Explorer file-extension toggle** (`Module/Regions/UIPersonalization/UIPersonalization.Explorer.psm1`) — `FileExtensions -Show`/`-Hide` no longer fails on fresh user profiles or `LocalSystem` execution contexts where `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` does not yet exist. Both code paths now create the key with `New-Item -Force` when missing before writing `HideFileExt`. (#2)
- **GUI module load in bare shells** (`Module/GUICommon.psm1`) — `[System.Windows.Media.BrushConverter]::new()` was instantiated at module-load before any WPF assembly was loaded, throwing `TypeNotFound` in headless / integration-test PowerShell hosts. Added `Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction SilentlyContinue` ahead of the instantiation so the WPF type system is available when `Import-Module Baseline` is run outside the embedded launcher. (#3)
- **DispatcherTimer null-pump crash on cleanup** (`Module/GUI/ExecutionOrchestration.ps1`) — the run timer's `Add_Tick` handler invoked `$Script:ExecutionPumpTickFn` by reference. If a tick fired after cleanup cleared the script-scope variable, the dispatcher threw `Cannot invoke null`. The handler now captures the function in a local closure (`$executionPumpTickFn = $Script:ExecutionPumpTickFn` + `.GetNewClosure()`) so any in-flight tick after cleanup still resolves to the original scriptblock and exits cleanly. (#4)
- **HKCU subkey-guard sweep across 14 region modules** — all bare `New-ItemProperty -Path "HKCU:\..."` writes that targeted subkeys not guaranteed to exist on fresh user profiles or under `LocalSystem` were converted to the existing `Set-RegistryValueSafe` helper (`Module/SharedHelpers/Registry.Helpers.ps1`), which internally creates the parent key with `New-Item -Force` when missing. Affected files: `Module/Regions/UIPersonalization/UIPersonalization.Explorer.psm1` (37 sites: 13 to `Explorer\Advanced`, 6 to `Explorer\ControlPanel`, 2 to `Explorer\OperationStatusManager`, plus base-key writes) (#5); `Module/Regions/UIPersonalization/UIPersonalization.Appearance.psm1` (4 sites: `Explorer\Advanced\DisallowShaking`, `Themes\Personalize\AppsUseLightTheme`) (#6); `Module/Regions/UIPersonalization/UIPersonalization.Icons.psm1` (6 sites: `Explorer\Advanced\SnapAssist`, `Themes\Personalize\SystemUsesLightTheme`, `Explorer\StuckRects3\Settings`) (#7); `Module/Regions/UIPersonalization/UIPersonalization.Taskbar.psm1` (TaskbarAl, SearchboxTaskbarMode, IsDynamicSearchBoxEnabled, ShowTaskViewButton, TaskbarGlomLevel, ShowCopilotButton, TaskbarCompanion, TaskbarEndTask) plus a parent-side `Test-Path`/`New-Item` guard before the `& powershell_temp.exe -Command {…}` subshell since the subshell cannot see `Set-RegistryValueSafe` (#8); `Module/Regions/StartMenu.psm1` (5 sites: `Start_AccountNotifications`, `Start_IrisRecommendations`, `Start_Layout`) (#9); `Module/Regions/Taskbar.psm1` plus a parent-side guard before the `Invoke-UCPDBypassed -ScriptBlock {…}` wrapper for the same reason (#10); `Module/Regions/TaskbarClock.psm1` (4 sites: `ShowClockInNotificationCenter`, `ShowSecondsInSystemClock`) (#11); `Module/Regions/Cursors.psm1` (59 sites under `HKCU:\Control Panel\Cursors` — largest single offender) (#12); `Module/Regions/Gaming.psm1` (2 sites: `GameBar\ShowStartupPanel`) (#13); `Module/Regions/ContextMenu.psm1` (1 site: `MultipleInvokePromptMinimum`) (#14); `Module/Regions/Defender/Defender.CoreProtection.psm1` (2 sites: `Windows Security Health\State\AccountProtection_MicrosoftAccount_Disconnected`, `AppAndBrowser_EdgeSmartScreenOff`) (#15); `Module/Regions/PrivacyTelemetry/PrivacyTelemetry.TelemetryServices.psm1` (3 sites: `DiagTrack\ShowedToastAtLevel`, `Windows Error Reporting\Disabled`) (#16); `Module/Regions/PrivacyTelemetry/PrivacyTelemetry.PrivacySettings.psm1` (3 sites: `AdvertisingInfo\Enabled`, `HttpAcceptLanguageOptOut`) (#17); `Module/Regions/PrivacyTelemetry/PrivacyTelemetry.SystemSettings.psm1` (2 sites: `TailoredExperiencesWithDiagnosticDataEnabled`) (#18). All sites that already used inline `Test-Path`/`New-Item` guards were left unchanged.
- **Swallowed exceptions in actionable startup paths** — `catch { $null = $_ }` blocks around `Initialize-GuiDetectCache`, `Initialize-BaselineUserPreferences`, `Initialize-NewBadgeService`, and the GUI version-detection regex now emit `LogWarning` with the underlying `Exception.Message` so first-launch initialization failures surface in the daily log instead of being silently dropped. Cleanup/dispose paths (timer stops, dispatcher invocations, splash window close) remain silent because their exceptions are non-actionable. (#19)
- **Popup pickers for UWP Apps, Windows Features (capabilities + features), and Scheduled Tasks** (`Module/Regions/UWPApps.psm1`, `Module/Regions/System/System.WindowsFeatures.psm1`, `Module/Regions/PrivacyTelemetry/PrivacyTelemetry.TelemetryServices.psm1`) — picker windows did not call `Set-GuiWindowChromeTheme` after loading their XAML, so the OS-drawn title bar stayed on the default light Windows chrome regardless of the GUI's current theme. In dark mode this produced the visual mismatch the rest of the GUI did not show (every other dialog already routed through this helper). All 5 picker XAML loads now invoke `Set-GuiWindowChromeTheme` against `$Script:CurrentThemeName` immediately after `XamlReader.Load`, behind a `Get-Command` guard so it no-ops if the helper isn't loaded in a child runspace. (#1)

---

## 3.0.0-beta | 2026-04-06

### Changed

- Version bumped from 2.0.0-beta to 3.0.0-beta across module manifest, entry scripts, and asset scripts
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

---

### Added

- **State Tracking & Compliance**
  - System state snapshots: pre-run and post-run capture, export, import, and comparison
  - Configuration profiles: portable JSON profiles built from presets or manual selection
  - Compliance drift detection: scan system state against a profile, highlight Compliant/Drifted/Unknown, one-click "Fix Drift"
  - Audit trail: append-only JSON Lines log of every execution with timestamp, tweak, old/new values, user, and machine
  - Audit viewer: GUI timeline with filter-by-action, HTML/Markdown export, and clear-old-entries
  - Scheduled automation: register/unregister Baseline as a Windows Scheduled Task for recurring compliance checks
  - Multi-machine targeting: deploy profiles or run compliance checks against remote machines via PowerShell Remoting

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

---

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

## 2.0.0-beta | 2026-03-21

- Minor changes to the GUI

## 1.0.0-beta | 2026-03-17

- Initial Commit
