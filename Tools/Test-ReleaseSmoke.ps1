<#
    .SYNOPSIS
    Release smoke-test entry point for Baseline artifact validation.

    .DESCRIPTION
    Runs the standard smoke suite with built-launcher checks enabled. Use this
    after building the launcher or before packaging a release.

    .EXAMPLE
    powershell -File .\Tools\Test-ReleaseSmoke.ps1

    .EXAMPLE
    powershell -File .\Tools\Test-ReleaseSmoke.ps1 -IncludeGUI
#>

[CmdletBinding()]
param (
    [switch]$IncludeGUI
)

$ErrorActionPreference = 'Stop'

$smokeTestPath = Join-Path $PSScriptRoot 'Test-SmokeTest.ps1'
if (-not (Test-Path -LiteralPath $smokeTestPath -PathType Leaf))
{
    throw "Smoke-test script not found: $smokeTestPath"
}

& $smokeTestPath -RequireReleaseArtifacts -IncludeGUI:$IncludeGUI
exit $LASTEXITCODE
