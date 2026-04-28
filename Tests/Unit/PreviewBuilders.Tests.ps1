Set-StrictMode -Version Latest

BeforeAll {
    $script:PreviewBuildersPath = Join-Path $PSScriptRoot '../../Module/GUI/PreviewBuilders.ps1'
    $script:PreviewBuildersContent = Get-Content -LiteralPath $script:PreviewBuildersPath -Raw -Encoding UTF8
}

Describe 'Preview builders' {
    It 'routes preview cursor fallbacks through Write-DebugSwallowedException' {
        $script:PreviewBuildersContent | Should -Match 'function Show-SelectedTweakPreview'
        $script:PreviewBuildersContent | Should -Match 'PreviewBuilders\.Show-SelectedTweakPreview\.SetWaitCursor'
        $script:PreviewBuildersContent | Should -Match 'PreviewBuilders\.Show-SelectedTweakPreview\.RestoreCursor'
    }
}
