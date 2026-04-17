<#
    .SYNOPSIS
    Wrapper module for Manifest.Helpers.ps1.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'Manifest.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Convert-JsonManifestValue'
    'ConvertTo-NormalizedParameterName'
    'ConvertTo-TweakRiskLevel'
    'ConvertTo-TweakPresetTier'
    'ConvertTo-TweakWorkflowSensitivity'
    'Convert-ToWhyThisMattersText'
    'Write-ManifestValidationWarning'
    'Import-TweakManifestFromData'
    'Test-TweakManifestEntryField'
    'Get-TweakManifestEntryValue'
    'Get-TweakManifestDefaultCommand'
    'Get-ManifestEntryByFunction'
    'Get-ValidScenarioTagCatalog'
    'Get-ValidGamingPreviewGroups'
    'Get-ValidGameModeProfileNames'
    'Test-TweakManifestIntegrity'
    'Get-TweakRestartGroups'
    'Get-TweakDependencyInfo'
)

Export-ModuleMember -Function $ExportedFunctions
