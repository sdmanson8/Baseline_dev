Set-StrictMode -Version Latest

BeforeAll {
    $iconFactoryPath = Join-Path $PSScriptRoot '../../Module/GUI/IconFactory.ps1'
    $script:IconFactoryContent = Get-Content -LiteralPath $iconFactoryPath -Raw -Encoding UTF8
}

Describe 'Icon factory font sizing' {
    It 'guards shared icon text helpers against non-positive font sizes' {
        $script:IconFactoryContent | Should -Match 'function Test-GuiPositiveFontSize'
        $script:IconFactoryContent | Should -Match 'if \(Test-GuiPositiveFontSize -Value \$Size\)'
        $script:IconFactoryContent | Should -Match 'if \(Test-GuiPositiveFontSize -Value \$TextFontSize\)'
        $script:IconFactoryContent | Should -Match '\$resolvedTextFontSize = if \(Test-GuiPositiveFontSize -Value \$TextFontSize\)'
        $script:IconFactoryContent | Should -Match 'elseif \(Test-GuiPositiveFontSize -Value \$Button\.FontSize\)'
    }
}
