Set-StrictMode -Version Latest

BeforeAll {
    $modeStatePath = Join-Path $PSScriptRoot '../../Module/GUI/ModeState.ps1'
    $script:ModeStateContent = Get-Content -LiteralPath $modeStatePath -Raw -Encoding UTF8
}

Describe 'Mode state' {
    It 'routes design-mode preference writes through Write-DebugSwallowedException' {
        $script:ModeStateContent | Should -Match "ModeState\.Set-DesignModeState\.SavePreference"
    }
}
