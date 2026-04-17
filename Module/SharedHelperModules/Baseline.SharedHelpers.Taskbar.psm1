<#
    .SYNOPSIS
    Wrapper module for Taskbar.Helpers.ps1.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'Taskbar.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Initialize-NewsInterestsTaskbarHashInterop'
    'Get-NewsInterestsTaskbarHashValue'
    'Set-UCPDBypassedRegistryDWordValue'
    'Set-NewsInterestsTaskbarViewMode'
    'Get-TaskbarPinnedItems'
    'Get-TaskbarPinnedMatches'
    'Invoke-TaskbarUnpin'
    'Get-TaskbarUnpinVerbCandidates'
    'Remove-TaskbarPinnedLink'
    'Invoke-TaskbarUnpinWithFallback'
    'Remove-TaskbarPinnedLinksByPattern'
    'Invoke-ARM64ShellUnpin'
)

Export-ModuleMember -Function $ExportedFunctions
