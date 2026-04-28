<#
    .SYNOPSIS
    Module wrapper for PlatformSupport.Helpers.ps1.

    .DESCRIPTION
    Exposes helper functions through this dedicated module boundary so they are loaded via PowerShell's module system.

#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'PlatformSupport.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Test-BaselineEditionInFamily'
    'Get-BaselineServerReleaseFromBuild'
    'Get-BaselineSystemPlatformInfo'
    'Get-BaselinePlatformFilterOverride'
    'ConvertTo-BaselinePlatformLabel'
    'Test-BaselineEntryAvailable'
    'Test-BaselineEntrySupportsExecution'
    'Get-BaselineEntryAvailabilitySummary'
    'Update-BaselineManifestAvailability'
)

Export-ModuleMember -Function $ExportedFunctions





