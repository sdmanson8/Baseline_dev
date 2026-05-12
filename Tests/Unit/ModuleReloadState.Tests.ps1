Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $script:LoaderPath = Join-Path $PSScriptRoot '../../Module/Baseline.psm1'
    $script:StateDocPath = Join-Path $PSScriptRoot '../../dev_docs/STATE.md'
    $script:LoaderContent = Get-BaselineTestSourceText -Path $script:LoaderPath
    $script:StateDocContent = Get-BaselineTestSourceText -Path $script:StateDocPath
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
