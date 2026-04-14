# Pre-flight validation checks that run before execution begins.
# Catches system-level problems early instead of mid-run.

<#
    .SYNOPSIS
    Internal function New-PreflightCheckResult.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-PreflightCheckResult
{
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('Passed', 'Failed', 'Warning')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('System', 'Storage', 'Services', 'Security', 'Recovery')]
        [string]$Category,

        [object[]]$RemediationActions = @()
    )

    $result = [pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Message  = $Message
        Category = $Category
    }

    if ($RemediationActions -and @($RemediationActions).Count -gt 0)
    {
        $result | Add-Member -NotePropertyName RemediationActions -NotePropertyValue @($RemediationActions) -Force
    }

    return $result
}

<#
    .SYNOPSIS
    Internal function Test-PreflightAdminElevation.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightAdminElevation
{
    try
    {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameAdmin' -Fallback 'Administrator') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightAdminPassed' -Fallback 'Running as administrator') -Category 'Security')
        }
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameAdmin' -Fallback 'Administrator') -Status 'Failed' -Message (Get-UxLocalizedString -Key 'GuiPreflightAdminFailed' -Fallback 'Not running as administrator') -Category 'Security')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameAdmin' -Fallback 'Administrator') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightAdminError' -Fallback 'Could not verify elevation: {0}') -f $_.Exception.Message) -Category 'Security')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightDiskSpace.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightDiskSpace
{
    $minFreeBytes = 500MB
    try
    {
        $systemDriveLetter = $env:SystemDrive[0]
        $volume = Get-Volume -DriveLetter $systemDriveLetter -ErrorAction Stop
        $freeGB = [math]::Round($volume.SizeRemaining / 1GB, 1)

        if ($volume.SizeRemaining -ge $minFreeBytes)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameDisk' -Fallback 'Disk space') -Status 'Passed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightDiskPassed' -Fallback '{0} GB free') -f $freeGB) -Category 'Storage')
        }
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameDisk' -Fallback 'Disk space') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightDiskFailed' -Fallback 'Only {0} GB free on {1}: (minimum 500 MB required)') -f $freeGB, $systemDriveLetter) -Category 'Storage')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameDisk' -Fallback 'Disk space') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightDiskError' -Fallback 'Could not verify disk space: {0}') -f $_.Exception.Message) -Category 'Storage')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightVSS.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightVSS
{
    try
    {
        $vssSvc = Get-Service -Name VSS -ErrorAction Stop
        if ($vssSvc.Status -eq 'Running')
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameVSS' -Fallback 'Volume Shadow Copy') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightServiceRunning' -Fallback 'Service is running') -Category 'Services')
        }
        if ($vssSvc.StartType -eq 'Disabled')
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameVSS' -Fallback 'Volume Shadow Copy') -Status 'Warning' -Message (Get-UxLocalizedString -Key 'GuiPreflightVSSDisabled' -Fallback 'Service is disabled (will be enabled and started)') -Category 'Services')
        }
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameVSS' -Fallback 'Volume Shadow Copy') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightVSSNotRunning' -Fallback 'Service not running (status: {0}, will be started)') -f $vssSvc.Status) -Category 'Services')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameVSS' -Fallback 'Volume Shadow Copy') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightVSSError' -Fallback 'VSS service not found: {0}') -f $_.Exception.Message) -Category 'Services')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightEventLog.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightEventLog
{
    try
    {
        $eventLogSvc = Get-Service -Name EventLog -ErrorAction Stop
        if ($eventLogSvc.Status -eq 'Running')
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameEventLog' -Fallback 'EventLog service') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightServiceRunning' -Fallback 'Service is running') -Category 'Services')
        }
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameEventLog' -Fallback 'EventLog service') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightEventLogStatus' -Fallback 'Service is {0}') -f $eventLogSvc.Status) -Category 'Services')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameEventLog' -Fallback 'EventLog service') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightEventLogError' -Fallback 'Could not query EventLog service: {0}') -f $_.Exception.Message) -Category 'Services')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightWMI.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightWMI
{
    try
    {
        $null = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWMI' -Fallback 'WMI health') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightWMIPassed' -Fallback 'CIM/WMI responding') -Category 'System')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWMI' -Fallback 'WMI health') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightWMIFailed' -Fallback 'CIM/WMI query failed: {0}') -f $_.Exception.Message) -Category 'System')
    }
}

<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Test-PreflightSystemRestore
{
    try
    {
        $systemDriveLetter = $env:SystemDrive[0]
        $systemDriveUniqueID = (Get-Volume | Where-Object { $_.DriveLetter -eq $systemDriveLetter }).UniqueID
        $systemProtection = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients" -ErrorAction Ignore)."{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}") | Where-Object { $_ -match [regex]::Escape($systemDriveUniqueID) }

        if ($null -ne $systemProtection)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestore' -Fallback 'System Restore') -Status 'Passed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightRestoreEnabled' -Fallback 'Enabled for {0}') -f $env:SystemDrive) -Category 'System')
        }

        # CIM fallback: the SPP\Clients registry check can return null on newer Windows 11 builds
        # even when System Protection is already on.
        $srpEnabled = $false
        try
        {
            $srpStatus = Get-CimInstance -ClassName SystemRestoreConfig -Namespace 'root\default' -ErrorAction Stop
            if ($srpStatus -and $srpStatus.RPSessionInterval -eq 1) { $srpEnabled = $true }
        }
        catch { $srpEnabled = $false }

        if ($srpEnabled)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestore' -Fallback 'System Restore') -Status 'Passed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightRestoreEnabled' -Fallback 'Enabled for {0}') -f $env:SystemDrive) -Category 'System')
        }

        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestore' -Fallback 'System Restore') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightRestoreNotEnabled' -Fallback 'Not enabled for {0}') -f $env:SystemDrive) -Category 'System')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestore' -Fallback 'System Restore') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightRestoreError' -Fallback 'Could not verify System Protection: {0}') -f $_.Exception.Message) -Category 'System')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightManagedPolicyEnvironment.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightManagedPolicyEnvironment
{
    try
    {
        $domainJoined = $false
        try
        {
            $domainJoined = [bool](Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).PartOfDomain
        }
        catch
        {
            $domainJoined = $false
        }

        $policyPaths = @(
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
            'HKLM:\SOFTWARE\Policies\Microsoft\Edge',
            'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer',
            'HKCU:\SOFTWARE\Policies\Microsoft\Windows\System',
            'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
        )

        $activePolicies = [System.Collections.Generic.List[string]]::new()
        foreach ($path in $policyPaths)
        {
            try
            {
                if (Test-Path -LiteralPath $path)
                {
                    [void]$activePolicies.Add($path)
                }
            }
            catch { }
        }

        if (-not $domainJoined -and $activePolicies.Count -eq 0)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePolicies' -Fallback 'Managed endpoint policy') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightPoliciesPassed' -Fallback 'No domain join or active policy hives detected') -Category 'Security')
        }

        $details = [System.Collections.Generic.List[string]]::new()
        $remediation = [System.Collections.Generic.List[string]]::new()
        $structuredRemediation = [System.Collections.Generic.List[string]]::new()
        if ($domainJoined)
        {
            [void]$details.Add('Domain joined')
            [void]$remediation.Add('Review the connected target with the remote console and confirm the GPO scope before applying changes.')
            [void]$structuredRemediation.Add('Confirm the target is in the expected OU and policy scope.')
            [void]$structuredRemediation.Add('Capture a gpresult report or equivalent policy summary for the endpoint.')
        }
        if ($activePolicies.Count -gt 0)
        {
            [void]$details.Add(('Active policy hives: {0}' -f ($activePolicies -join ', ')))
            [void]$remediation.Add('Export the relevant policy hives or document the enforced settings before a high-risk run.')
            [void]$structuredRemediation.Add('Export the listed policy hives and attach them to the support bundle.')
        }
        [void]$remediation.Add('Use the Troubleshooting Guide and support bundle if the result needs escalation.')
        [void]$structuredRemediation.Add('Generate an incident reproduction pack from the support bundle after any failed remediation attempt.')

        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePolicies' -Fallback 'Managed endpoint policy') -Status 'Warning' -Message (($details -join '; ') + '. ' + ($remediation -join ' ')) -Category 'Security' -RemediationActions @($structuredRemediation))
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePolicies' -Fallback 'Managed endpoint policy') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightPoliciesError' -Fallback 'Could not evaluate policy environment: {0}') -f $_.Exception.Message) -Category 'Security')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightPendingReboot.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightPendingReboot
{
    try
    {
        $reasons = [System.Collections.Generic.List[string]]::new()

        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
        {
            [void]$reasons.Add('Component Based Servicing')
        }
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\WindowsUpdate\Auto Update\RebootRequired')
        {
            [void]$reasons.Add('Windows Update')
        }
        try
        {
            $pfro = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Stop
            if ($pfro -and $pfro.PendingFileRenameOperations) { [void]$reasons.Add('Pending file rename operations') }
        }
        catch { }
        try
        {
            $crv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update' -Name 'PostRebootReporting' -ErrorAction Stop
            if ($crv) { [void]$reasons.Add('Windows Update post-reboot reporting') }
        }
        catch { }

        if ($reasons.Count -eq 0)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePendingReboot' -Fallback 'Pending reboot') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightPendingRebootClear' -Fallback 'No pending reboot detected') -Category 'System')
        }

        $msg = ((Get-UxLocalizedString -Key 'GuiPreflightPendingRebootDetected' -Fallback 'Pending reboot: {0}. Restart before applying tweaks to avoid mid-run failures.') -f ($reasons -join '; '))
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePendingReboot' -Fallback 'Pending reboot') -Status 'Warning' -Message $msg -Category 'System' -RemediationActions @('Restart Windows before retrying.', 'Re-run preflight after reboot to confirm.'))
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNamePendingReboot' -Fallback 'Pending reboot') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightPendingRebootError' -Fallback 'Could not evaluate reboot state: {0}') -f $_.Exception.Message) -Category 'System')
    }
}

<#
    .SYNOPSIS
    Internal function Test-PreflightWinRMReachability.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightWinRMReachability
{
    [CmdletBinding()]
    param (
        [string[]]$Targets = @()
    )

    if (-not $Targets -or $Targets.Count -eq 0)
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWinRM' -Fallback 'WinRM reachability') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightWinRMNoTargets' -Fallback 'No remote targets configured') -Category 'Services')
    }

    try
    {
        $svc = Get-Service -Name 'WinRM' -ErrorAction Stop
        if ($svc.Status -ne 'Running')
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWinRM' -Fallback 'WinRM reachability') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightWinRMServiceStopped' -Fallback 'WinRM service is {0}; remote operations require it to be running.') -f $svc.Status) -Category 'Services' -RemediationActions @('Run: Start-Service WinRM', 'Run: Enable-PSRemoting -SkipNetworkProfileCheck -Force on each target.'))
        }
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWinRM' -Fallback 'WinRM reachability') -Status 'Failed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightWinRMQueryError' -Fallback 'Could not query WinRM service: {0}') -f $_.Exception.Message) -Category 'Services')
    }

    $unreachable = [System.Collections.Generic.List[string]]::new()
    foreach ($target in $Targets)
    {
        if ([string]::IsNullOrWhiteSpace([string]$target)) { continue }
        try
        {
            Test-WSMan -ComputerName $target -ErrorAction Stop | Out-Null
        }
        catch
        {
            [void]$unreachable.Add(('{0}: {1}' -f $target, $_.Exception.Message))
        }
    }

    if ($unreachable.Count -eq 0)
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWinRM' -Fallback 'WinRM reachability') -Status 'Passed' -Message ((Get-UxLocalizedString -Key 'GuiPreflightWinRMReachable' -Fallback '{0} target(s) reachable via WinRM') -f $Targets.Count) -Category 'Services')
    }

    $msg = ((Get-UxLocalizedString -Key 'GuiPreflightWinRMUnreachable' -Fallback 'Unreachable target(s): {0}') -f ($unreachable -join ' | '))
    return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameWinRM' -Fallback 'WinRM reachability') -Status 'Failed' -Message $msg -Category 'Services' -RemediationActions @('Verify network reachability and DNS resolution.', 'Confirm WinRM listeners (winrm e winrm/config/listener) on each target.', 'Check firewall: Enable-NetFirewallRule -DisplayGroup ''Windows Remote Management''.'))
}

<#
    .SYNOPSIS
    Internal function Test-PreflightRestorePointCreation.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-PreflightRestorePointCreation
{
    try
    {
        $createCommand = Get-Command -Name 'CreateRestorePoint' -CommandType Function -ErrorAction SilentlyContinue
        if (-not $createCommand)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestorePoint' -Fallback 'Restore Point') -Status 'Warning' -Message (Get-UxLocalizedString -Key 'GuiPreflightRestorePointNotAvailable' -Fallback 'CreateRestorePoint function not available') -Category 'Recovery')
        }

        $created = [bool](& $createCommand)
        if ($created)
        {
            return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestorePoint' -Fallback 'Restore Point') -Status 'Passed' -Message (Get-UxLocalizedString -Key 'GuiPreflightRestorePointCreated' -Fallback 'Restore point created successfully') -Category 'Recovery')
        }
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestorePoint' -Fallback 'Restore Point') -Status 'Warning' -Message (Get-UxLocalizedString -Key 'GuiPreflightRestorePointFalse' -Fallback 'Restore point creation returned false (System Protection may be disabled or insufficient disk space)') -Category 'Recovery')
    }
    catch
    {
        return (New-PreflightCheckResult -Name (Get-UxLocalizedString -Key 'GuiPreflightNameRestorePoint' -Fallback 'Restore Point') -Status 'Warning' -Message ((Get-UxLocalizedString -Key 'GuiPreflightRestorePointError' -Fallback 'Restore point creation failed: {0}') -f $_.Exception.Message) -Category 'Recovery')
    }
}

<#
    .SYNOPSIS
    Internal function Invoke-PreflightChecks.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Invoke-PreflightChecks
{
    <#
    .SYNOPSIS
        Runs all pre-flight validation checks before execution begins.
    .DESCRIPTION
        Returns an object with Passed (bool), CriticalFailures (array),
        Warnings (array), and AllResults (array of check results).
        Also attempts to create a restore point as part of pre-flight.
    #>
    [CmdletBinding()]
    param (
        [string[]]$RemoteTargets = @()
    )

    $allResults = @(
        Test-PreflightAdminElevation
        Test-PreflightDiskSpace
        Test-PreflightVSS
        Test-PreflightEventLog
        Test-PreflightWMI
        Test-PreflightSystemRestore
        Test-PreflightManagedPolicyEnvironment
        Test-PreflightPendingReboot
        Test-PreflightWinRMReachability -Targets $RemoteTargets
    )

    $criticalFailures = @($allResults | Where-Object { $_.Status -eq 'Failed' })
    $warnings = @($allResults | Where-Object { $_.Status -eq 'Warning' })
    $passed = ($criticalFailures.Count -eq 0) -and ($warnings.Count -eq 0)

    [pscustomobject]@{
        Passed           = $passed
        CriticalFailures = $criticalFailures
        Warnings         = $warnings
        AllResults       = $allResults
    }
}

<#
    .SYNOPSIS
    Internal function Show-PreflightResultsDialog.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-PreflightResultsDialog
{
    <#
    .SYNOPSIS
        Displays pre-flight check results and returns the user's choice.
    .DESCRIPTION
        If all passed, returns 'Continue'. If critical failures exist, shows dialog
        with only 'Cancel'. If warnings only, shows 'Cancel' and 'Continue Anyway'.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$Results
    )

    if ($Results.Passed)
    {
        return 'Continue'
    }

    # Build the formatted message
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add((Get-UxLocalizedString -Key 'GuiPreflightResultsHeading' -Fallback 'Pre-flight check results:'))
    $lines.Add('')

    $passedLabel = Get-UxLocalizedString -Key 'GuiPreflightStatusPassed' -Fallback 'Passed'
    $adminPassedMsg = Get-UxLocalizedString -Key 'GuiPreflightAdminPassed' -Fallback 'Running as administrator'
    $wmiPassedMsg = Get-UxLocalizedString -Key 'GuiPreflightWMIPassed' -Fallback 'CIM/WMI responding'
    $serviceRunningMsg = Get-UxLocalizedString -Key 'GuiPreflightServiceRunning' -Fallback 'Service is running'

    foreach ($check in $Results.AllResults)
    {
        switch ($check.Status)
        {
            'Passed'
            {
                $detailSuffix = ''
                # Include detail for disk space even on pass
                if ($check.Message -and $check.Message -ne $adminPassedMsg -and
                    $check.Message -ne $wmiPassedMsg -and $check.Message -ne $serviceRunningMsg)
                {
                    $detailSuffix = " ($($check.Message))"
                }
                $lines.Add([char]0x2713 + " $($check.Name): $passedLabel$detailSuffix")
            }
            'Failed'
            {
                $lines.Add([char]0x2717 + " $($check.Name): $($check.Message)")
            }
            'Warning'
            {
                $lines.Add([char]0x26A0 + " $($check.Name): $($check.Message)")
            }
        }
    }

    $issueCount = $Results.CriticalFailures.Count + $Results.Warnings.Count
    $lines.Add('')

    if ($Results.CriticalFailures.Count -gt 0)
    {
        $lines.Add((Get-UxLocalizedString -Key 'GuiPreflightMustResolve' -Fallback '{0} issue(s) must be resolved before continuing.') -f $issueCount)
    }
    else
    {
        $lines.Add((Get-UxLocalizedString -Key 'GuiPreflightRequiresAttention' -Fallback '{0} issue(s) requires attention before continuing.') -f $issueCount)
    }

    $message = $lines -join "`n"
    $dialogTitle = Get-UxLocalizedString -Key 'GuiPreflightDialogTitle' -Fallback 'Pre-flight Checks'
    $cancelLabel = Get-UxLocalizedString -Key 'GuiBtnCancel' -Fallback 'Cancel'
    $continueAnywayLabel = Get-UxLocalizedString -Key 'GuiPreflightContinueAnyway' -Fallback 'Continue Anyway'

    if ($Results.CriticalFailures.Count -gt 0)
    {
        Show-ThemedDialog -Title $dialogTitle -Message $message -Buttons @($cancelLabel)
        return 'Cancel'
    }

    # Warnings only - allow the user to continue
    $choice = Show-ThemedDialog -Title $dialogTitle -Message $message -Buttons @($cancelLabel, $continueAnywayLabel) -AccentButton $continueAnywayLabel
    return $choice
}
