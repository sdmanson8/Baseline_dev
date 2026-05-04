Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:DialogPath = Join-Path $script:RepoRoot 'Module/GUI/UserFoldersDialog.ps1'
    $script:XamlPath = Join-Path $script:RepoRoot 'Module/GUI/MainWindow.xaml'
    $script:WindowSetupPath = Join-Path $script:RepoRoot 'Module/GUI/WindowSetup.ps1'
    $script:ActionHandlersPath = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers'
    $script:GuiRegionPath = Join-Path $script:RepoRoot 'Module/Regions/GUI.psm1'
    $script:StyleManagementPath = Join-Path $script:RepoRoot 'Module/GUI/StyleManagement.ps1'
    $script:StartupDialogPath = Join-Path $script:RepoRoot 'Module/GUI/StartupManagerDialog.ps1'

    $script:DialogContent = Get-Content -LiteralPath $script:DialogPath -Raw -Encoding UTF8
    $script:XamlContent = Get-Content -LiteralPath $script:XamlPath -Raw -Encoding UTF8
    $script:WindowSetupContent = Get-Content -LiteralPath $script:WindowSetupPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-BaselineTestSourceText -Path @(
        $script:ActionHandlersPath
        (Join-Path $script:ActionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $script:GuiRegionContent = Get-Content -LiteralPath $script:GuiRegionPath -Raw -Encoding UTF8
    $script:StyleManagementContent = Get-Content -LiteralPath $script:StyleManagementPath -Raw -Encoding UTF8
    $script:StartupDialogContent = Get-Content -LiteralPath $script:StartupDialogPath -Raw -Encoding UTF8
}

Describe 'User folders dialog: category placement' {
    It 'does not expose User Folders from the Tools menu' {
        $script:XamlContent | Should -Not -Match 'Name="MenuToolsUserFolders"'
        $script:WindowSetupContent | Should -Not -Match 'MenuToolsUserFolders'
    }

    It 'dot-sources UserFoldersDialog.ps1 from Module/Regions/GUI.psm1' {
        $script:GuiRegionContent | Should -Match "Join-Path \`$Script:GuiExtractedRoot 'UserFoldersDialog\.ps1'"
    }

    It 'exposes User Folders from the Customizations tab action card' {
        $script:StartupDialogContent | Should -Match 'function Invoke-GuiCustomizationsUserFoldersAction'
        $script:StartupDialogContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-GuiUserFoldersDialog'"
        $script:StartupDialogContent | Should -Match "GuiUserFoldersTitle"
    }
}

Describe 'User folders dialog: function definitions' {
    It 'defines Show-GuiUserFoldersDialog' {
        $script:DialogContent | Should -Match 'function Show-GuiUserFoldersDialog'
    }

    It 'defines Get-GuiUserFoldersEntries and New-GuiUserFoldersEntryRow for the shared flat renderer' {
        $script:DialogContent | Should -Match 'function Get-GuiUserFoldersEntries'
        $script:DialogContent | Should -Match 'function New-GuiUserFoldersEntryRow'
    }

    It 'enumerates entries via Get-BaselineUserFolderDefinitions behind a Get-Command guard' {
        $script:DialogContent | Should -Match "Get-Command -Name 'Get-BaselineUserFolderDefinitions'"
        $script:DialogContent | Should -Match '\$definitions = @\(Get-BaselineUserFolderDefinitions\)'
    }

    It 'uses Show-GuiFolderPickerDialog for browse selection' {
        $script:DialogContent | Should -Match 'Show-GuiFolderPickerDialog'
    }

    It 'invokes UserFolders on Apply Selected' {
        $script:DialogContent | Should -Match 'UserFolders -Folder'
    }

    It 'short-circuits in headless harness when $Script:CurrentTheme is unset' {
        $script:DialogContent | Should -Match 'if \(-not \$Script:CurrentTheme\)'
        $script:DialogContent | Should -Match 'return @\{ Cancelled = \$true; Changes = @\(\); Errors = @\(\) \}'
    }
}

Describe 'User folders dialog: Tools menu removal' {
    It 'removes the legacy Tools click handler' {
        $script:ActionHandlersContent | Should -Not -Match 'MenuToolsUserFolders'
    }
}
