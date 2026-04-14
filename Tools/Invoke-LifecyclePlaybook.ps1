<#
    .SYNOPSIS
    Generates or executes a Baseline upgrade, downgrade, or rollback playbook.

    .DESCRIPTION
    Uses the shared lifecycle helpers to build a structured playbook from the
    current Baseline version, installer artifact, or rollback profile. When
    -Execute is supplied, the script runs the requested installer or rollback
    command set.

    .EXAMPLE
    pwsh -File .\Tools\Invoke-LifecyclePlaybook.ps1 -Operation Upgrade -InstallerPath .\dist\Baseline-setup-4.0.0.exe

    .EXAMPLE
    pwsh -File .\Tools\Invoke-LifecyclePlaybook.ps1 -Operation Rollback -RollbackProfilePath .\bundle\rollback.json -Execute
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Upgrade', 'Downgrade', 'Rollback')]
    [string]$Operation,

    [string]$CurrentVersion,
    [string]$TargetVersion,
    [string]$InstallerPath,
    [string]$RollbackProfilePath,
    [string]$OutputPath,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$modulePath = Join-Path $repoRoot 'Module\Baseline.psd1'
Import-Module -LiteralPath $modulePath -Force -ErrorAction Stop

$playbook = New-BaselineLifecyclePlaybook `
    -Operation $Operation `
    -CurrentVersion $CurrentVersion `
    -TargetVersion $TargetVersion `
    -InstallerPath $InstallerPath `
    -RollbackProfilePath $RollbackProfilePath

if ($WhatIfPreference)
{
    $Execute = $false
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath))
{
    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir))
    {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    $exportPath = if ($OutputPath.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) { $OutputPath } else { '{0}.json' -f $OutputPath }
    $playbook | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $exportPath -Encoding UTF8
}

$result = Invoke-BaselineLifecyclePlaybook -Playbook $playbook -Execute:$Execute
$result | Add-Member -NotePropertyName Playbook -NotePropertyValue $playbook -Force
$result
