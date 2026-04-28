Set-StrictMode -Version Latest

BeforeAll {
    $script:DiffViewPath = Join-Path $PSScriptRoot '../../Module/GUI/DiffView.ps1'
    $script:DiffViewContent = Get-Content -LiteralPath $script:DiffViewPath -Raw -Encoding UTF8
}

Describe 'Diff view' {
    It 'routes dialog setup and list initialization fallbacks through Write-DebugSwallowedException' {
        $script:DiffViewContent | Should -Match 'function Show-DiffViewDialog'
        $script:DiffViewContent | Should -Match 'function Show-DiffViewFromSelection'
        $script:DiffViewContent | Should -Match 'DiffView\.Show-DiffViewDialog\.SetOwner'
        $script:DiffViewContent | Should -Match 'DiffView\.Show-DiffViewFromSelection\.BeginInit'
        $script:DiffViewContent | Should -Match 'DiffView\.Show-DiffViewFromSelection\.EndInit'
    }
}
