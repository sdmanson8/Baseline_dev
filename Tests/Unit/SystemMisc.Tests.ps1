Set-StrictMode -Version Latest

BeforeAll {
    $script:SystemMiscPath = Join-Path $PSScriptRoot '../../Module/Regions/System/System.SystemMisc.psm1'
    $script:SystemMiscContent = Get-Content -LiteralPath $script:SystemMiscPath -Raw -Encoding UTF8
}

Describe 'System miscellaneous cleanup' {
    It 'routes reserved storage cleanup failures through LogWarning' {
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(disable\) PowerShell dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(disable\) runspace dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(enable\) PowerShell dispose failed:'
        $script:SystemMiscContent | Should -Match 'Reserved storage cleanup \(enable\) runspace dispose failed:'
    }
}
