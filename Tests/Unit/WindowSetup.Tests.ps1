Set-StrictMode -Version Latest

BeforeAll {
    $script:WindowSetupContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1') -Raw -Encoding UTF8
}

Describe 'WindowSetup swallowed-exception routing' {
    It 'routes placement, dispatcher-hook, preference, and localization failures through Write-DebugSwallowedException' {
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.ResolvePlacement'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.ApplyDefaultWindowBounds'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.LoadRememberWindowPosition'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.RemoveUnhandledExceptionHook'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.AddUnhandledExceptionHook'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.LoadGuiPreferences'"
        $script:WindowSetupContent | Should -Match "Source 'WindowSetup\.ResolveLocalizationCandidate'"
    }
}
