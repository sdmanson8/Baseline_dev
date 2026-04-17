<#
    .SYNOPSIS
    Pure-logic helpers extracted from Module/Regions/InitialActions.psm1.

    .DESCRIPTION
    InitialActions bundles P/Invoke loading, CIM queries, registry probes, and
    network I/O into one 800-line procedure. This file isolates the decision
    logic so unit tests can AST-load it without the side-effecting shell.
#>

<#
    .SYNOPSIS
    Formats the startup label that InitialActions logs on entry.
#>
function Get-BaselineStartupLabel
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$OSName,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$DisplayVersion = $null
    )

    $label = "Baseline | Utility for $OSName"
    if (-not [string]::IsNullOrWhiteSpace([string]$DisplayVersion))
    {
        $label = "$label $DisplayVersion"
    }

    return $label
}

<#
    .SYNOPSIS
    Indicates whether the current PowerShell host is unsupported by InitialActions.

    .DESCRIPTION
    InitialActions warns about PowerShell ISE and VS Code hosts because the
    interactive shell affordances they use conflict with Baseline's custom host
    and progress rendering.
#>
function Test-BaselineUnsupportedHost
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$HostName,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$TermProgram
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$HostName) -and ([string]$HostName -match 'ISE'))
    {
        return $true
    }

    if ([string]$TermProgram -eq 'vscode')
    {
        return $true
    }

    return $false
}

<#
    .SYNOPSIS
    Tests whether a hosts-file entry matches the expected IP-plus-name pattern.

    .DESCRIPTION
    Downloaded hosts-file entries are validated before Baseline rewrites the
    system hosts file. Entries that do not match the pattern are skipped so a
    corrupted download cannot inject arbitrary text.
#>
function Test-BaselineHostsEntry
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Line
    )

    if ($null -eq $Line)
    {
        return $false
    }

    return ([string]$Line -match '^\s*[\d.:a-fA-F]+\s+\S+')
}

<#
    .SYNOPSIS
    Splits hosts-file content into comment-stripped candidate entries.
#>
function Get-BaselineHostsCandidateEntries
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [AllowNull()]
        [string[]]$Content
    )

    if ($null -eq $Content -or $Content.Count -eq 0)
    {
        return @()
    }

    $result = @($Content | Where-Object { $_ -and ($_ -notmatch '^\s*#') })
    return $result
}

<#
    .SYNOPSIS
    Indicates whether the proportion of invalid hosts entries crosses the trust
    threshold, in which case the caller should skip the WindowsSpyBlocker
    cleanup entirely.
#>
function Test-BaselineHostsDownloadSuspect
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int]$InvalidCount,

        [Parameter(Mandatory)]
        [int]$TotalCount,

        [double]$Threshold = 0.5
    )

    if ($TotalCount -le 0)
    {
        return $false
    }

    return (([double]$InvalidCount / [double]$TotalCount) -gt $Threshold)
}

<#
    .SYNOPSIS
    Parses a SecurityCenter2 AntiVirusProduct product state integer into the
    middle-byte substring that InitialActions uses to classify Defender.

    .DESCRIPTION
    Windows encodes the running/up-to-date state of a registered AV product in
    the second byte of the productState DWORD. A value whose second byte is
    "00" or "01" means Defender is not the active scanner.
#>
function Get-BaselineDefenderProductStateCode
{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$ProductState
    )

    if ($null -eq $ProductState)
    {
        return $null
    }

    try
    {
        $hex = '0x{0:x}' -f ([int]$ProductState)
    }
    catch
    {
        return $null
    }

    if ($hex.Length -lt 5)
    {
        return $null
    }

    return $hex.Substring(3, 2)
}

<#
    .SYNOPSIS
    Indicates whether the parsed Defender product-state code represents an
    active scanner.
#>
function Test-BaselineDefenderActiveByProductState
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$StateCode
    )

    if ([string]::IsNullOrWhiteSpace([string]$StateCode))
    {
        return $false
    }

    return ([string]$StateCode -notmatch '00|01')
}

<#
    .SYNOPSIS
    Aggregates the five Defender-status booleans into a single enabled flag.

    .DESCRIPTION
    InitialActions treats Defender as enabled only when the services are
    running, SecurityCenter2 reports an active product state, and each GPO
    override is absent. A single false flag flips the overall state to false.
#>
function Test-BaselineDefenderFullyEnabled
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [bool]$ServicesRunning,

        [Parameter(Mandatory)]
        [bool]$ProductStateActive,

        [Parameter(Mandatory)]
        [bool]$AntiSpywareEnabled,

        [Parameter(Mandatory)]
        [bool]$RealtimeMonitoringEnabled,

        [Parameter(Mandatory)]
        [bool]$BehaviorMonitoringEnabled
    )

    return ($ServicesRunning -and $ProductStateActive -and $AntiSpywareEnabled -and $RealtimeMonitoringEnabled -and $BehaviorMonitoringEnabled)
}

<#
    .SYNOPSIS
    Indicates whether at least one Defender service is running.

    .DESCRIPTION
    InitialActions considers Defender's service layer healthy if any of the
    sampled services is running — a full-shutdown of every service is the
    broken state that harmful tweakers produce.
#>
function Test-BaselineDefenderServicesHealthy
{
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object[]]$Services
    )

    if ($null -eq $Services -or $Services.Count -eq 0)
    {
        return $false
    }

    $stopped = @($Services | Where-Object { $_.Status -ne 'Running' }).Count
    return ($stopped -lt $Services.Count)
}
