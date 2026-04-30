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

    It 'loads the restore-last-session user preference during GUI startup' {
        $script:WindowSetupContent | Should -Match 'Get-BaselineUserPreference -Key ''RestoreLastSession'' -Default \$true'
    }

    It 'forces debug logging on while a restored session is rehydrated' {
        $script:WindowSetupContent | Should -Match 'if \(\$Script:RestoreLastSession\)\s*\{\s*# Keep verbose logging on while the restored session rehydrates so perf'
        $script:WindowSetupContent | Should -Match '\$Script:DebugLoggingEnabled = \$true'
        $script:WindowSetupContent | Should -Match 'Set-BaselineDebugLogging -Enabled \(\[bool\]\$Script:DebugLoggingEnabled\)'
    }
}
