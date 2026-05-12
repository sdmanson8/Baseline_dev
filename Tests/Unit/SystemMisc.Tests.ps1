Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $script:SystemMiscPath = Join-Path $PSScriptRoot '../../Module/Regions/System/System.SystemMisc.psm1'
    $script:SystemMiscContent = Get-BaselineTestSourceText -Path $script:SystemMiscPath
}

Describe 'System miscellaneous cleanup' {
    It 'routes reserved storage cleanup failures through LogWarning' {
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(disable\) PowerShell dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(disable\) runspace dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(enable\) PowerShell dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(enable\) runspace dispose failed:'
    }
}
