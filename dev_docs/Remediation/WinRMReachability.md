# WinRM reachability — remediation guide

This guide is linked from the preflight **Risk categories** surface when WinRM reachability is either fully failed or in a partial-coverage state (some targets reachable, some not).

## Partial coverage (Warning)

Baseline now distinguishes between *all targets unreachable* (Failed, blocks the run) and *some targets reachable* (Warning, run permitted). The warning exists because rolling out to a mixed-reachability set is a common cause of partial-success runs.

### Recommended steps

1. Before re-running, confirm DNS resolution and routing for the unreachable target(s). Try `Test-WSMan -ComputerName <target>` from the operator console.
2. Verify the WinRM listener on each unreachable target: `winrm e winrm/config/listener`.
3. Check the `Windows Remote Management` firewall group is enabled:
   ```powershell
   Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management'
   ```
4. If the unreachable targets cannot be remediated right now, scope them out of the run or stage them separately.

## Full failure (Failed)

If the WinRM service itself is not running on the operator console, the preflight returns Failed with a pointer to:

```powershell
Start-Service WinRM
Enable-PSRemoting -SkipNetworkProfileCheck -Force
```

Re-run preflight once the service is running.

## Logs

- Remote-console log lines tagged `WinRMReachability`.
- Support bundle: remote-target transcripts under `RemoteTarget.Transcripts`.
