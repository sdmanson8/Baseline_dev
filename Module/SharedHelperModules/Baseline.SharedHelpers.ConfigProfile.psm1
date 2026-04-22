<#
    .SYNOPSIS
    Named module boundary for ConfigProfile.Helpers.ps1 — exposes its functions through the module system.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'ConfigProfile.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'ConvertTo-ConfigurationProfileValueText'
    'New-ConfigurationProfile'
    'Export-ConfigurationProfile'
    'Import-ConfigurationProfile'
    'Test-ConfigurationProfileCompatibility'
    'Compare-ConfigurationProfiles'
    'Get-ProfileEntryComparisonKey'
    'ConvertFrom-PresetToProfile'
)

Export-ModuleMember -Function $ExportedFunctions
