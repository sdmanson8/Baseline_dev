Set-StrictMode -Version Latest

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:GuiRegionPath = Join-Path $script:RepoRoot 'Module/Regions/GUI.psm1'
    $script:BuildPrimaryTabsPath = Join-Path $script:RepoRoot 'Module/GUI/BuildPrimaryTabs.ps1'
    $script:TabManagementPath = Join-Path $script:RepoRoot 'Module/GUI/TabManagement.ps1'
    $script:BuildTabContentPath = Join-Path $script:RepoRoot 'Module/GUI/BuildTabContent.ps1'

    $script:GuiRegionContent = Get-Content -LiteralPath $script:GuiRegionPath -Raw -Encoding UTF8
    $script:BuildPrimaryTabsContent = Get-Content -LiteralPath $script:BuildPrimaryTabsPath -Raw -Encoding UTF8
    $script:TabManagementContent = Get-Content -LiteralPath $script:TabManagementPath -Raw -Encoding UTF8
    $script:BuildTabContentContent = Get-Content -LiteralPath $script:BuildTabContentPath -Raw -Encoding UTF8
}

Describe 'Customizations tab wiring' {
    It 'declares Customizations as a primary category' {
        $script:GuiRegionContent | Should -Match '"Customizations"\s*=\s*@\(\)'
    }

    It 'forces the Customizations tab to exist even when no manifest tweaks map to it' {
        $script:BuildPrimaryTabsContent | Should -Match 'if \(\$pKey -eq ''Customizations''\)'
        $script:BuildPrimaryTabsContent | Should -Match 'Get-BaselineStartupEntries'
    }

    It 'counts startup entries for the Customizations tab header' {
        $script:TabManagementContent | Should -Match 'if \(\$pKey -eq ''Customizations''\)'
        $script:TabManagementContent | Should -Match 'Get-BaselineStartupEntries'
    }

    It 'special-cases Build-TabContent for Customizations' {
        $script:BuildTabContentContent | Should -Match 'if \(\$PrimaryTab -eq ''Customizations''\)'
        $script:BuildTabContentContent | Should -Match 'New-GuiStartupManagerTabContent'
    }

    It 'routes adaptive tab layout bring-into-view failures through Write-DebugSwallowedException' {
        $script:BuildPrimaryTabsContent | Should -Match "BuildPrimaryTabs\.AdaptiveTabLayout\.BringIntoView"
    }

    It 'routes Customizations startup-entry counting failures through Write-DebugSwallowedException' {
        $script:TabManagementContent | Should -Match "TabManagement\.Get-PrimaryTabItemHeaderText\.CustomizationsStartupEntries"
    }
}
