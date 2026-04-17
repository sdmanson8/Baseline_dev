<#
    .SYNOPSIS
    Wrapper module for FeatureMaturity.Helpers.ps1.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'FeatureMaturity.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Get-BaselineFeatureMaturityOrder'
    'Get-BaselineEnterpriseActionMaturityCatalogData'
    'Get-BaselineFeatureMaturityLevels'
    'ConvertTo-BaselineFeatureMaturityLevel'
    'Get-BaselineFeatureMaturityRank'
    'Test-BaselineFeatureMaturityAtLeast'
    'Get-BaselineEnterpriseActionMaturityCatalog'
    'Test-BaselineEnterpriseActionMaturityGate'
    'Get-BaselineFeatureMaturityReport'
)

Export-ModuleMember -Function $ExportedFunctions
