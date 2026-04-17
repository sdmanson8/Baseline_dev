Set-StrictMode -Version Latest

BeforeAll {
    $guiCommonPath = Join-Path $PSScriptRoot '../../Module/GUICommon.psm1'
    $guiCommonLayoutPath = Join-Path $PSScriptRoot '../../Module/GUICommon/Layout.ps1'
    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $guiCommonContent = (Get-Content -LiteralPath $guiCommonPath -Raw -Encoding UTF8) + "`n" + (Get-Content -LiteralPath $guiCommonLayoutPath -Raw -Encoding UTF8)
    $guiContent = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
}

Describe 'GUI layout sharing' {
    It 'defines a guarded GUI font-size resolver before extracted GUI scripts load' {
        $guiContent | Should -Match 'function Get-GuiSafeFontSize'
        $guiContent | Should -Match '\$Script:GuiFontSizeWarnings\s*='
    }

    It 'exports the shared GUI font-size resolver from GUICommon' {
        $guiCommonContent | Should -Match 'function Get-GuiSafeFontSize'
        $guiCommonContent | Should -Match "'Get-GuiSafeFontSize'"
    }

    It 'exposes a shared layout accessor from GUICommon' {
        $guiCommonContent | Should -Match 'function Get-GuiLayout'
        $guiCommonContent | Should -Match '\$Script:GuiLayout\.Clone\(\)'
        $guiCommonContent | Should -Match "'Get-GuiLayout'"
    }

    It 'initializes GuiLayout before dot-sourcing extracted GUI scripts' {
        $layoutAssignment = [regex]::Match($guiContent, '\$Script:GuiLayout\s*=\s*GUICommon\\Get-GuiLayout')
        $firstExtractedScriptLoad = [regex]::Match($guiContent, '\.\s+\(Join-Path\s+\$Script:GuiExtractedRoot\s+''[^'']+\.ps1''\)')

        $layoutAssignment.Success | Should -BeTrue
        $firstExtractedScriptLoad.Success | Should -BeTrue
        $layoutAssignment.Index | Should -BeLessThan $firstExtractedScriptLoad.Index
    }
}
