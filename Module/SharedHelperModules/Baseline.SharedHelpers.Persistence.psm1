<#
    .SYNOPSIS
    Named module boundary for Persistence.Helpers.ps1 — exposes its functions through the module system.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'Persistence.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Get-BaselineDataDirectory'
    'Write-BaselineDocument'
    'Read-BaselineDocument'
    'Add-BaselineAuditRecord'
    'Read-BaselineAuditLog'
    'Test-BaselineDocumentSchema'
)

Export-ModuleMember -Function $ExportedFunctions
