# Pending reboot — remediation guide

This guide is linked from the preflight **Risk categories** surface when the operator console (or a remote target, when running in remote-console preflight) has a pending reboot recorded in one of:

- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
- `HKLM\SOFTWARE\Microsoft\Windows\WindowsUpdate\Auto Update\RebootRequired`
- `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager → PendingFileRenameOperations`
- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update → PostRebootReporting`

## Why Baseline flags this

Running tweaks on an OS that already has a pending reboot increases the chance of:

- Mid-run failures when Windows Update or CBS operations complete during the run.
- Registry writes reverted on reboot by PendingFileRenameOperations.
- Services that appear healthy but are in a "will restart on next boot" state.

## What to do before continuing

1. Restart Windows.
2. Re-run preflight after the reboot to confirm the pending-reboot flag clears.
3. If the reboot is disruptive right now, scope the run to low-risk items only (the preflight Results panel shows which categories are affected).

## Logs

- Preflight dialog → Risk categories → *Pending reboot* card.
- Support bundle → preflight JSON under `PendingReboot.PendingReasons`.
