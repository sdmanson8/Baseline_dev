# Group Policy conflict-detection helper slice for Baseline.
#
# Compares each tweak's intended registry write against the policy hives
# (HKLM/HKCU \SOFTWARE\Policies\...) so we can warn the user that an enforced
# GPO will revert their change and produce remediation guidance.
#
# Dependencies (loaded earlier in SharedHelpers.psm1):
#   Test-TweakManifestEntryField, Get-TweakManifestEntryValue (Manifest.Helpers.ps1)

$Script:CachedBaselineGpoPolicyHiveRoots = @(
    'HKLM:\SOFTWARE\Policies'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies'
    'HKCU:\SOFTWARE\Policies'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies'
)

<#
    .SYNOPSIS
    Internal function Test-BaselineGpoPolicyPath.
#>

function Test-BaselineGpoPolicyPath
{
    <#
        .SYNOPSIS
        Returns $true when a registry path lives under one of the recognised
        Group Policy hive roots (HKLM/HKCU \SOFTWARE\Policies\...).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $normalized = $Path.TrimEnd('\').Replace('/', '\')
    foreach ($root in $Script:CachedBaselineGpoPolicyHiveRoots)
    {
        if ($normalized.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase))
        {
            return $true
        }
    }
    return $false
}

<#
    .SYNOPSIS
    Internal function Get-BaselineGpoPolicyValueState.
#>

function Get-BaselineGpoPolicyValueState
{
    <#
        .SYNOPSIS
        Reads the current state of a policy value, returning a structured object:
        Path, Name, Exists, Value, Type, IsPolicyHive.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $result = [pscustomobject]@{
        Path         = $Path
        Name         = $Name
        Exists       = $false
        Value        = $null
        Type         = $null
        IsPolicyHive = (Test-BaselineGpoPolicyPath -Path $Path)
    }

    try
    {
        if (-not (Test-Path -LiteralPath $Path)) { return $result }
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        if ($null -ne $item -and ($item | Get-Member -Name $Name -ErrorAction SilentlyContinue))
        {
            $result.Exists = $true
            $result.Value  = $item.$Name
        }
        try
        {
            $key = Get-Item -LiteralPath $Path -ErrorAction Stop
            $kind = $key.GetValueKind($Name)
            $result.Type = [string]$kind
        }
        catch { }
    }
    catch
    {
        $result.Exists = $false
    }

    return $result
}

<#
    .SYNOPSIS
    Internal function Get-BaselineGpoEnvironmentSummary.
#>

function Get-BaselineGpoEnvironmentSummary
{
    <#
        .SYNOPSIS
        Returns a summary of the local policy environment: domain join, MDM
        enrolment, and the populated policy hive roots.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param ()

    $domainJoined = $false
    $domainName = $null
    try
    {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $domainJoined = [bool]$cs.PartOfDomain
        if ($domainJoined) { $domainName = [string]$cs.Domain }
    }
    catch { }

    $mdmEnrolled = $false
    try
    {
        $enrollments = Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction Stop
        foreach ($e in $enrollments)
        {
            $props = Get-ItemProperty -LiteralPath $e.PSPath -ErrorAction SilentlyContinue
            if ($props -and $props.PSObject.Properties['EnrollmentState'] -and [int]$props.EnrollmentState -eq 1)
            {
                $mdmEnrolled = $true
                break
            }
        }
    }
    catch { }

    $populated = [System.Collections.Generic.List[string]]::new()
    foreach ($root in $Script:CachedBaselineGpoPolicyHiveRoots)
    {
        try
        {
            if (Test-Path -LiteralPath $root)
            {
                $children = @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)
                if ($children.Count -gt 0) { [void]$populated.Add($root) }
            }
        }
        catch { }
    }

    return [pscustomobject]@{
        DomainJoined      = $domainJoined
        DomainName        = $domainName
        MdmEnrolled       = $mdmEnrolled
        PopulatedHives    = $populated.ToArray()
        IsManagedEndpoint = ($domainJoined -or $mdmEnrolled -or $populated.Count -gt 0)
    }
}

<#
    .SYNOPSIS
    Internal function Get-BaselineGpoConflictForEntry.
#>

function Get-BaselineGpoConflictForEntry
{
    <#
        .SYNOPSIS
        Inspects a single manifest entry and returns a conflict descriptor when
        an active policy would override the intended write. Returns $null when
        no conflict is detected.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    $function = if (Test-TweakManifestEntryField -Entry $Entry -FieldName 'Function') { [string](Get-TweakManifestEntryValue -Entry $Entry -FieldName 'Function') } else { $null }
    if ([string]::IsNullOrWhiteSpace($function)) { return $null }

    # The manifest stores the candidate registry target on a few common fields
    # depending on tweak type. We probe each one to keep this generic.
    $pathFields = @('RegistryPath', 'Path', 'PolicyPath', 'TargetPath')
    $nameFields = @('RegistryName', 'Name', 'ValueName', 'PolicyName')

    $path = $null
    foreach ($f in $pathFields)
    {
        if ((Test-TweakManifestEntryField -Entry $Entry -FieldName $f) -and -not [string]::IsNullOrWhiteSpace([string](Get-TweakManifestEntryValue -Entry $Entry -FieldName $f)))
        {
            $path = [string](Get-TweakManifestEntryValue -Entry $Entry -FieldName $f)
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }

    $name = $null
    foreach ($f in $nameFields)
    {
        if ((Test-TweakManifestEntryField -Entry $Entry -FieldName $f) -and -not [string]::IsNullOrWhiteSpace([string](Get-TweakManifestEntryValue -Entry $Entry -FieldName $f)))
        {
            $name = [string](Get-TweakManifestEntryValue -Entry $Entry -FieldName $f)
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    if (-not (Test-BaselineGpoPolicyPath -Path $path)) { return $null }

    $state = Get-BaselineGpoPolicyValueState -Path $path -Name $name
    if (-not $state.Exists) { return $null }

    return [pscustomobject]@{
        Function     = $function
        PolicyPath   = $path
        PolicyName   = $name
        CurrentValue = $state.Value
        ValueKind    = $state.Type
        Severity     = 'Warning'
        Remediation  = @(
            'Identify the GPO/Intune policy enforcing this value (gpresult /h gp.html or Get-GPRegistryValue).',
            'Either lift the policy in scope for this endpoint or accept that Baseline''s change will be reverted.',
            'For audit, capture the policy export with the support bundle.'
        )
    }
}

<#
    .SYNOPSIS
    Internal function Get-BaselineGpoConflictReport.
#>

function Get-BaselineGpoConflictReport
{
    <#
        .SYNOPSIS
        Produces a structured GPO conflict report for a manifest set.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [array]$Manifest = @(),

        [string[]]$FunctionFilter = @()
    )

    $env = Get-BaselineGpoEnvironmentSummary
    $conflicts = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($entry in $Manifest)
    {
        if (-not $entry) { continue }
        if ($FunctionFilter -and $FunctionFilter.Count -gt 0)
        {
            $fn = if (Test-TweakManifestEntryField -Entry $entry -FieldName 'Function') { [string](Get-TweakManifestEntryValue -Entry $entry -FieldName 'Function') } else { $null }
            if (-not $fn -or -not ($FunctionFilter -contains $fn)) { continue }
        }

        $conflict = Get-BaselineGpoConflictForEntry -Entry $entry
        if ($conflict) { [void]$conflicts.Add($conflict) }
    }

    return [pscustomobject]@{
        GeneratedAt    = [DateTimeOffset]::UtcNow
        Environment    = $env
        ConflictCount  = $conflicts.Count
        Conflicts      = $conflicts.ToArray()
        HasConflicts   = ($conflicts.Count -gt 0)
    }
}

<#
    .SYNOPSIS
    Internal function Format-BaselineGpoConflictReport.
#>

function Format-BaselineGpoConflictReport
{
    <#
        .SYNOPSIS
        Returns a multi-line string suitable for log/dialog rendering.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine(('GPO conflict report - generated {0:o}' -f $Report.GeneratedAt))
    [void]$sb.AppendLine(('Domain joined: {0} | MDM enrolled: {1} | Hives populated: {2}' -f $Report.Environment.DomainJoined, $Report.Environment.MdmEnrolled, ($Report.Environment.PopulatedHives -join ', ')))
    [void]$sb.AppendLine(('Conflicts detected: {0}' -f $Report.ConflictCount))

    foreach ($c in $Report.Conflicts)
    {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine(('  * {0}' -f $c.Function))
        [void]$sb.AppendLine(('    Policy : {0}\{1} = {2} ({3})' -f $c.PolicyPath, $c.PolicyName, $c.CurrentValue, $c.ValueKind))
        foreach ($r in $c.Remediation) { [void]$sb.AppendLine(('    -> {0}' -f $r)) }
    }

    return $sb.ToString()
}
