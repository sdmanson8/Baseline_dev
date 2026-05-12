Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $systemScanPath = Join-Path $PSScriptRoot '../../Module/GUI/SystemScan.ps1'
    $script:SystemScanContent = Get-BaselineTestSourceText -Path $systemScanPath
}

Describe 'System scan' {
    It 'routes non-fatal scan fallbacks through Write-SwallowedException' {
        $script:SystemScanContent | Should -Match 'SystemScan\.Test-GuiManifestToggleNeedsAttention\.LoadCurrentState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadGameBarState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadTerminalState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadOfficeState'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadMappedNetworkDrives'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadDomainJoined'
        $script:SystemScanContent | Should -Match 'SystemScan\.Get-GuiEnvironmentRecommendationData\.LoadWinReState'
    }
}
