Set-StrictMode -Version Latest

BeforeAll {
    $modeStatePath = Join-Path $PSScriptRoot '../../Module/GUI/ModeState.ps1'
    $script:ModeStateContent = Get-Content -LiteralPath $modeStatePath -Raw -Encoding UTF8
}

Describe 'Mode state' {
    It 'persists Safe and Expert startup-mode changes' {
        $script:ModeStateContent | Should -Match 'function Save-GuiDefaultStartupModePreference'
        $script:ModeStateContent | Should -Match 'Set-BaselineUserPreference -Key ''DefaultStartupMode'' -Value \$Mode'
        $script:ModeStateContent | Should -Match "Save-GuiDefaultStartupModePreference -Mode 'Safe'"
        $script:ModeStateContent | Should -Match 'Save-GuiDefaultStartupModePreference -Mode \$nextStartupMode'
    }

    It 'routes design-mode preference writes through Write-DebugSwallowedException' {
        $script:ModeStateContent | Should -Match "ModeState\.Set-DesignModeState\.SavePreference"
    }

    It 'keeps the unified Safe/Expert checkbox content on the active mode label' {
        $script:ModeStateContent | Should -Match "Get-UxLocalizedString -Key 'GuiHelpSectionSafeMode' -Fallback 'Safe Mode'"
        $script:ModeStateContent | Should -Match "Get-UxLocalizedString -Key 'GuiHelpSectionExpertMode' -Fallback 'Expert Mode'"
        $script:ModeStateContent | Should -Not -Match 'GuiChkSafeMode'
    }
}
