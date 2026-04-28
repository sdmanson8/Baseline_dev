Set-StrictMode -Version Latest

BeforeAll {
    $systemScanPath = Join-Path $PSScriptRoot '../../Module/GUI/SystemScan.ps1'
    $script:SystemScanContent = Get-Content -LiteralPath $systemScanPath -Raw -Encoding UTF8
}

Describe 'System scan' {
    It 'routes non-fatal scan fallbacks through Write-DebugSwallowedException' {
        $script:SystemScanContent | Should -Match 'SystemScan\.Test-GuiManifestToggleNeedsAttention\.LoadCurrentState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadGameBarState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadTerminalState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadOfficeState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadMappedNetworkDrives'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadDomainJoined'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadWinReState'
    }
}
