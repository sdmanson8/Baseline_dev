<#
    .SYNOPSIS
    Wrapper module for Registry.Helpers.ps1.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'Registry.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Set-Policy'
    'Get-CurrentWindowsUserSid'
    'ConvertTo-NativeRegistryPath'
    'ConvertTo-RegExeValueType'
    'Dismount-RegistryHive'
    'Mount-RegistryHive'
    'Test-RegistryValueEquivalent'
    'Set-RegistryValueSafe'
    'Remove-RegistryValueSafe'
    'ConvertTo-RegistryCompositeStringValue'
    'Set-RegistryCompositeStringValue'
    'Set-SystemTweaksRegistryValue'
    'Remove-SystemTweaksRegistryValue'
)

Export-ModuleMember -Function $ExportedFunctions
