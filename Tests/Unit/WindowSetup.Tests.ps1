Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $script:WindowSetupContent = Get-BaselineTestSourceText -Path (Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1')
}

Describe 'WindowSetup swallowed-exception routing' {
    It 'routes placement, dispatcher-hook, preference, and localization failures through Write-SwallowedException' {
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

    It 'applies persisted debug logging without forcing it for restored sessions' {
        $script:WindowSetupContent | Should -Not -Match 'Keep verbose logging on while the restored session rehydrates'
        $script:WindowSetupContent | Should -Match 'Set-BaselineDebugLogging -Enabled \(\[bool\]\$Script:DebugLoggingEnabled\)'
        $script:WindowSetupContent | Should -Match 'Set-GuiPerfTraceState -Enabled \(\[bool\]\$Script:DebugLoggingEnabled\)'
    }
}
