Set-StrictMode -Version Latest

BeforeAll {
    $script:PerfTraceContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/PerfTrace.ps1') -Raw -Encoding UTF8
    $script:DialogHelpersContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1') -Raw -Encoding UTF8
}

Describe 'PerfTrace swallowed-exception routing' {
    It 'routes perf-log initialization and append failures through Write-DebugSwallowedException' {
        $script:PerfTraceContent | Should -Match "Source 'PerfTrace\.TestGuiPerfTraceDebugEnabled\.GetBaselineDebugLogging'"
        $script:PerfTraceContent | Should -Match "Source 'PerfTrace\.InitializeGuiPerfTrace\.WriteSessionHeader'"
        $script:PerfTraceContent | Should -Match "Source 'PerfTrace\.StopGuiPerfScope\.AppendLine'"
    }

    It 'requires Debug Mode before creating perf.log' {
        $script:PerfTraceContent | Should -Match 'function Test-GuiPerfTraceDebugEnabled'
        $script:PerfTraceContent | Should -Match '\$debugEnabled = Test-GuiPerfTraceDebugEnabled'
        $script:PerfTraceContent | Should -Match '\$Script:GuiPerfEnabled = \(\$debugEnabled -and \$perfRequested\)'
        $script:PerfTraceContent | Should -Match 'function Set-GuiPerfTraceState'
        $script:PerfTraceContent | Should -Match 'Remove-Item -Path Env:\\BASELINE_PERF_LOG'
    }

    It 'loads PerfTrace from the module root before dialog helpers that depend on it' {
        $script:DialogHelpersContent | Should -Match 'Join-Path \$Script:DialogHelpersRoot ''PerfTrace\.ps1'''
        $script:DialogHelpersContent | Should -Not -Match 'Join-Path \$dialogHelpersSplitRoot ''PerfTrace\.ps1'''
    }
}
