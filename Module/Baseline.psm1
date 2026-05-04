<#
    .SYNOPSIS
    Internal loader module for Baseline.
 
    .VERSION
    4.0.0 (beta)

    .DATE
    17.03.2026 - initial beta version
    21.03.2026 - Added GUI
	06.04.2026 - Major changes to the GUI, and added more features
    26.04.2026 - Minor Fixes
    unreleased - unreleased

	.AUTHOR
	sdmanson8 - Copyright (c) 2026

    .DESCRIPTION
    Imports shared modules and region modules, then exports their functions.
    This module exists for the internal Baseline runtime and should be treated
    as implementation detail, not end-user documentation.
#>

# Logging and helper functions are shared across all region modules, so we import them first to ensure they are available for use in the region modules.
# Import shared modules used by all region modules
Import-Module -Name "$PSScriptRoot\Logging.psm1" -Force -Global
Import-Module -Name "$PSScriptRoot\SharedHelpers.psm1" -Force -Global
Import-Module -Name "$PSScriptRoot\GUIExecution.psm1" -Force -Global

# Optional supply-chain hardening. When BASELINE_INTEGRITY_MODE is set to
# Strict or Audit, every script file under Module/ is hashed and compared
# against Module/integrity.manifest.json before any region modules load.
# Default mode is Off (no overhead, no behaviour change).
if (Get-Command -Name 'Invoke-BaselineModuleIntegrityGate' -ErrorAction SilentlyContinue)
{
    Invoke-BaselineModuleIntegrityGate -ModuleRoot $PSScriptRoot
}

# Detect the OS version once through the shared helper so every module uses the same logic.
$osName = (Get-OSInfo).OSName

# Initialize logging in the disposable temp storage root. BASELINE_STATE_ROOT is
# reserved for persistent user state such as profiles and saved sessions.
$logDirectory = Get-BaselineLogDirectory -FallbackRoot $env:TEMP
$logDirectory = Get-BaselineConfiguredLogDirectory -DefaultDirectory $logDirectory -FallbackRoot $env:TEMP

$resolvedLogPath = [string]$global:LogFilePath
if ([string]::IsNullOrWhiteSpace($resolvedLogPath))
{
    $resolvedLogPath = New-BaselineSessionLogPath -LogDirectory $logDirectory -OsName $osName
}
$previousLogPath = [string]$global:LogFilePath
$hadPreviousLogPath = -not [string]::IsNullOrWhiteSpace([string]$previousLogPath)
$alreadyInitialized = $hadPreviousLogPath -and $previousLogPath -eq $resolvedLogPath
$global:LogFilePath = $resolvedLogPath
Set-LogFile -Path $global:LogFilePath
if (-not $alreadyInitialized)
{
    Initialize-SessionStatistics
    if ($hadPreviousLogPath)
    {
        LogWarning ("Baseline loader reset session statistics after module reload because the log path changed from '{0}' to '{1}'." -f $previousLogPath, $resolvedLogPath)
    }
}

<#
    .SYNOPSIS
    Load the region modules that provide the script's functions.

    .DESCRIPTION
    Imports Errors.psm1 and InitialActions.psm1 first because other region modules may depend on them.
    Then imports the remaining region modules from the Regions folder in name order and exports their functions through this loader module.
#>
$RegionDir = Join-Path $PSScriptRoot 'Regions'

$coreFiles = @('Errors.psm1', 'InitialActions.psm1')
$excludedRegionFiles = @(
    'GUI.psm1'
)

foreach ($core in $coreFiles) {
    $corePath = Join-Path $RegionDir $core
    if (Test-Path -LiteralPath $corePath) {
        try {
            Import-Module -Name $corePath -Force -Global -ErrorAction Stop
        }
        catch {
            LogError "Failed to import region module '$core': $($_.Exception.Message)"
            throw
        }
    }
}

Get-ChildItem -Path $RegionDir -Filter '*.psm1' -File |
    Where-Object { $_.Name -notin $coreFiles -and $_.Name -notin $excludedRegionFiles } |
    Sort-Object Name |
    ForEach-Object {
        try {
            Import-Module -Name $_.FullName -Force -Global -ErrorAction Stop
        }
        catch {
            LogError "Failed to import region module '$($_.Name)': $($_.Exception.Message)"
            throw
        }
    }

# Region modules are imported with -Global so their functions are available
# directly. Do not export with wildcard to avoid leaking internal helpers.
Export-ModuleMember -Function @()
