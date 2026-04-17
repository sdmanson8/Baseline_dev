Set-StrictMode -Version Latest

BeforeAll {
    $script:LoaderPath = Join-Path $PSScriptRoot '../../Module/Baseline.psm1'
    $script:StateDocPath = Join-Path $PSScriptRoot '../../dev_docs/STATE.md'
    $script:LoaderContent = Get-Content -LiteralPath $script:LoaderPath -Raw -Encoding UTF8
    $script:StateDocContent = Get-Content -LiteralPath $script:StateDocPath -Raw -Encoding UTF8
}

Describe 'Module reload state visibility' {
    It 'logs when module reload resets session statistics because the log path changed' {
        $script:LoaderContent | Should -Match 'Initialize-SessionStatistics'
        $script:LoaderContent | Should -Match 'LogWarning\s+\("Baseline loader reset session statistics after module reload because the log path changed from'
    }

    It 'documents loader reload resets in STATE.md' {
        $script:StateDocContent | Should -Match 'Loader reload behaviour'
        $script:StateDocContent | Should -Match 'session statistics'
        $script:StateDocContent | Should -Match 'log path'
    }
}
