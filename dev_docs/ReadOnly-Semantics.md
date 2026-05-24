# `-ReadOnly` mode — end-to-end semantics

`-ReadOnly` is a global gate that turns Baseline into a strictly observational tool.
It is intended for **compliance-only scans on production endpoints** where any
state mutation is unacceptable. When enabled, every canonical write helper refuses
to mutate state and throws `System.InvalidOperationException` instead.

## How the mode is set

| Surface | Mechanism |
| --- | --- |
| Bootstrap (`Bootstrap/Baseline.ps1`) | `-ReadOnly` switch (line 112). |
| Module global | `Set-BaselineOperationMode -Mode 'ReadOnly'` (Environment.Helpers.ps1). |
| Process env var | `BASELINE_OPERATION_MODE=ReadOnly` (set automatically; survives child processes). |

`Get-BaselineOperationMode` returns the active mode (defaulting to `ReadWrite`).
`Test-BaselineReadOnlyMode` returns `$true` when the gate is active.

## What it blocks

The gate is enforced by `Assert-BaselineWriteAllowed`, which is called from the
canonical write helpers below. Any write performed through these helpers fails
loud in ReadOnly mode.

| Subsystem | Helper | Blocked operation |
| --- | --- | --- |
| Registry | `Set-RegistryValueSafe` (Registry.Helpers.ps1:422) | Any `Set-ItemProperty` write to `HKLM:`/`HKCU:`. |
| Registry | `Remove-RegistryValueSafe` (Registry.Helpers.ps1:534) | Removal of registry values. |
| Persistence | `Write-BaselineDocument` (Persistence.Helpers.ps1:70) | Writing schema-tagged JSON documents (manifests, profiles). |
| Audit | `Add-BaselineAuditRecord` (Persistence.Helpers.ps1:174) | Appending records to the audit ledger. |

When the gate fires, the exception message is:

```
Baseline is running in ReadOnly mode; '<operation>' is not permitted.
```

The `<operation>` token includes the call site context (e.g.
`Set-RegistryValueSafe(HKLM:\SOFTWARE\...\Foo)`), so the audit/log of a blocked
attempt is actionable.

## What it does **not** block

ReadOnly is enforced at the **canonical write helpers**, not at every cmdlet.
The following are not directly gated:

- Direct `Set-ItemProperty` / `New-Item` / `Remove-Item` calls outside the
  canonical helpers. Region tweaks must call the safe helpers; bypassing them
  bypasses ReadOnly. (See "Reconcile -ReadOnly enforcement" task in `todo.md`.)
- Side effects from external tools (Chocolatey installs, DISM, `winget`).
  Tweaks that delegate to native installers should refuse to run in ReadOnly
  mode at the region level.
- Telemetry/log file writes — the local log file under
  `%LOCALAPPDATA%\Baseline\Logs\` continues to receive entries so the run is
  still observable. ReadOnly suppresses *target-system* mutation, not *local
  observability* state.
- Filesystem state under `%LOCALAPPDATA%\Baseline\` (preset cache, runtime
  cache) — these are local-only and required for execution.

## Operator checklist

- For a `-ReadOnly -Apply` run, expect every region that would mutate registry,
  audit, or persistence state to throw `InvalidOperationException`. The launcher
  reports them as failures, but the underlying system stays unchanged.
- For a `-ReadOnly -Preview` run (no `-Apply`), no writes are attempted in the
  first place; ReadOnly is redundant but harmless.
- Compliance scans should pair `-ReadOnly` with `-OutputFormat Json` or
  `-OutputFormat Ndjson` to capture the diagnostic stream for later analysis.

## Adding a new write call site

Any new function that mutates registry, audit, or persistence state **must**:

1. Call `Assert-BaselineWriteAllowed -Operation '<descriptive context>'`
   before the mutation. The descriptive context is what surfaces in the
   exception and audit log when ReadOnly fires.
2. Use the existing `Set-RegistryValueSafe` / `Remove-RegistryValueSafe` /
   `Write-BaselineDocument` / `Add-BaselineAuditRecord` helpers rather than
   inlining `Set-ItemProperty`/`Set-Content` calls.
3. Be covered by a unit test that flips `Set-BaselineOperationMode -Mode
   'ReadOnly'` and asserts the call throws.
