Set-StrictMode -Version Latest

BeforeAll {
    $script:PerfTraceContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/PerfTrace.ps1') -Raw -Encoding UTF8
}

Describe 'PerfTrace swallowed-exception routing' {
    It 'routes perf-log initialization and append failures through Write-DebugSwallowedException' {
        $script:PerfTraceContent | Should -Match "Source 'PerfTrace\.InitializeGuiPerfTrace\.WriteSessionHeader'"
        $script:PerfTraceContent | Should -Match "Source 'PerfTrace\.StopGuiPerfScope\.AppendLine'"
    }
}
