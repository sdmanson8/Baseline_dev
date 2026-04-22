<#
    .SYNOPSIS
    Named module boundary for AuditTrail.Helpers.ps1 — exposes its functions through the module system.

    .DESCRIPTION
    Loads the shared helper slice into an explicitly named module so the helper
    inventory is visible through Get-Module.
#>

$Script:SharedHelpersModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$Script:SharedHelpersRepoRoot = Split-Path -Path $Script:SharedHelpersModuleRoot -Parent

$helperPath = Join-Path -Path (Join-Path $Script:SharedHelpersModuleRoot 'SharedHelpers') -ChildPath 'AuditTrail.Helpers.ps1'
if (-not (Test-Path -LiteralPath $helperPath))
{
    throw "Required shared helper file is missing: $helperPath"
}

. $helperPath

$ExportedFunctions = @(
    'Get-AuditLogPath'
    'Get-BaselineAuditRetentionDays'
    'Get-BaselineAuditRetentionCutoff'
    'Invoke-BaselineAuditRetentionPolicy'
    'Write-AuditRecord'
    'Get-AuditLog'
    'Export-AuditReport'
    'Clear-AuditLog'
    'Get-BaselineAuditRetentionPolicyThreshold'
    'Test-BaselineAuditRetentionBelowPolicy'
    'Get-BaselineAuditRetentionPolicyWarning'
    'Test-BaselineAuditRetentionTaskExecution'
    'Get-BaselineAuditRetentionReport'
)

Export-ModuleMember -Function $ExportedFunctions
