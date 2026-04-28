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
}

Describe 'User folders dialog: menu wiring' {
    It 'declares MenuToolsUserFolders in the Tools menu' {
        $script:XamlContent | Should -Match 'Name="MenuToolsUserFolders"'
        $idxItem = $script:XamlContent.IndexOf('Name="MenuToolsUserFolders"')
        $idxToolsMenu = $script:XamlContent.IndexOf('Name="MenuTools"')
        $idxItem | Should -BeGreaterThan $idxToolsMenu
    }

    It 'wires FindName + $Script: assignment in WindowSetup.ps1' {
        $script:WindowSetupContent | Should -Match '\$MenuToolsUserFolders = \$Form\.FindName\("MenuToolsUserFolders"\)'
        $script:WindowSetupContent | Should -Match '\$Script:MenuToolsUserFolders = \$MenuToolsUserFolders'
    }

    It 'dot-sources UserFoldersDialog.ps1 from Module/Regions/GUI.psm1' {
        $script:GuiRegionContent | Should -Match "Join-Path \`$Script:GuiExtractedRoot 'UserFoldersDialog\.ps1'"
    }

    It 'styles the menu item header with an icon' {
        $script:ActionHandlersContent | Should -Match '\$MenuToolsUserFolders\.Header'
        $script:ActionHandlersContent | Should -Match "New-GuiLabeledIconContent -IconName 'Document'"
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

Describe 'User folders dialog: click handler integration' {
    It 'registers a Click handler on MenuToolsUserFolders in ActionHandlers.ps1' {
        $script:ActionHandlersContent | Should -Match 'if \(\$MenuToolsUserFolders\)'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsUserFolders -EventName ''Click'''
    }

    It 'invokes Show-GuiUserFoldersDialog from the Click handler' {
        $script:ActionHandlersContent | Should -Match 'Show-GuiUserFoldersDialog'
    }

    It 'guards on Get-Command so a missing helper module never breaks the menu' {
        $idxIf = $script:ActionHandlersContent.IndexOf('if ($MenuToolsUserFolders)')
        $tail = $script:ActionHandlersContent.Substring($idxIf)
        $tail | Should -Match "Get-Command -Name 'Show-GuiUserFoldersDialog' -CommandType Function -ErrorAction SilentlyContinue"
    }

    It 'uses the run-in-progress gate so the dialog cannot be opened mid-apply' {
        $idxIf = $script:ActionHandlersContent.IndexOf('if ($MenuToolsUserFolders)')
        $tail = $script:ActionHandlersContent.Substring($idxIf)
        $tail | Should -Match 'if \(& \$testGuiRunInProgressCapture\) \{ return \}'
    }
}
