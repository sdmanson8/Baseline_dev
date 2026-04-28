Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:DialogPath = Join-Path $script:RepoRoot 'Module/GUI/StartupManagerDialog.ps1'
    $script:XamlPath = Join-Path $script:RepoRoot 'Module/GUI/MainWindow.xaml'
    $script:WindowSetupPath = Join-Path $script:RepoRoot 'Module/GUI/WindowSetup.ps1'
    $script:ActionHandlersPath = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers'
    $script:GuiRegionPath = Join-Path $script:RepoRoot 'Module/Regions/GUI.psm1'

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
}

Describe 'Startup Manager dialog: menu wiring' {
    It 'declares MenuToolsStartupManager in the Tools menu' {
        $script:XamlContent | Should -Match 'Name="MenuToolsStartupManager"'
        $idxItem = $script:XamlContent.IndexOf('Name="MenuToolsStartupManager"')
        $idxToolsMenu = $script:XamlContent.IndexOf('Name="MenuTools"')
        $idxItem | Should -BeGreaterThan $idxToolsMenu
    }

    It 'wires FindName + $Script: assignment in WindowSetup.ps1' {
        $script:WindowSetupContent | Should -Match '\$MenuToolsStartupManager = \$Form\.FindName\("MenuToolsStartupManager"\)'
        $script:WindowSetupContent | Should -Match '\$Script:MenuToolsStartupManager = \$MenuToolsStartupManager'
    }

    It 'dot-sources StartupManagerDialog.ps1 from Module/Regions/GUI.psm1' {
        $script:GuiRegionContent | Should -Match "Join-Path \`$Script:GuiExtractedRoot 'StartupManagerDialog\.ps1'"
    }
}

Describe 'Startup Manager dialog: function definitions' {
    It 'defines Show-GuiStartupManagerDialog' {
        $script:DialogContent | Should -Match 'function Show-GuiStartupManagerDialog'
    }

    It 'defines Get-GuiStartupManagerEntries for the shared flat renderer' {
        $script:DialogContent | Should -Match 'function Get-GuiStartupManagerEntries'
    }

    It 'defines New-GuiStartupManagerEntryRow for the shared flat renderer' {
        $script:DialogContent | Should -Match 'function New-GuiStartupManagerEntryRow'
    }

    It 'defines Add-GuiStartupManagerRowsToPanel for the shared flat renderer' {
        $script:DialogContent | Should -Match 'function Add-GuiStartupManagerRowsToPanel'
    }

    It 'defines New-GuiStartupManagerTabContent for the Customizations tab' {
        $script:DialogContent | Should -Match 'function New-GuiStartupManagerTabContent'
    }

    It 'short-circuits in headless harness when $Script:CurrentTheme is unset' {
        $script:DialogContent | Should -Match 'if \(-not \$Script:CurrentTheme\)'
        $script:DialogContent | Should -Match 'return @\{ Cancelled = \$true; Changes = @\(\) \}'
    }

    It 'enumerates entries via the shared helper' {
        $script:DialogContent | Should -Match '\$entries = @\(Get-GuiStartupManagerEntries\)'
    }

    It 'wraps the enumerator in try/catch routed through Write-DebugSwallowedException' {
        $script:DialogContent | Should -Match "Source 'StartupManagerDialog\.Enumerate'"
    }

    It 'binds per-row checkbox Click to Set-BaselineStartupEntryEnabled with Enable / Disable parameter sets' {
        $script:DialogContent | Should -Match 'Set-BaselineStartupEntryEnabled -EntryId .*-Enable'
        $script:DialogContent | Should -Match 'Set-BaselineStartupEntryEnabled -EntryId .*-Disable'
    }

    It 'snaps the checkbox back when Set-BaselineStartupEntryEnabled returns false (UI must not lie about state)' {
        $script:DialogContent | Should -Match 'if \(-not \$ok\)'
        $script:DialogContent | Should -Match '\$cbRef\.IsChecked = -not \$desired'
    }

    It 'disables RunOnce / no-ApprovedKey rows so Task Manager-style toggle never silently fails' {
        $script:DialogContent | Should -Match '\$isToggleable = \(-not \[bool\]\$entry\.IsRunOnce\) -and \(-not \[string\]::IsNullOrWhiteSpace\(\[string\]\$entry\.ApprovedKey\)\)'
        $script:DialogContent | Should -Match '\$cb\.IsEnabled = \$false'
    }

    It 'records each successful toggle in the Changes list so callers can summarize the session' {
        $script:DialogContent | Should -Match '\$changeListRef\.Add\(\[pscustomobject\]@\{'
        $script:DialogContent | Should -Match 'EntryId = \[string\]\$entryRef\.EntryId'
        $script:DialogContent | Should -Match 'Enabled = \$desired'
    }

    It 'renders a flat list instead of grouping rows by Source' {
        $script:DialogContent | Should -Not -Match 'Group-Object -Property Source'
    }
}

Describe 'Startup Manager dialog: click handler integration' {
    It 'registers a Click handler on MenuToolsStartupManager in ActionHandlers.ps1' {
        $script:ActionHandlersContent | Should -Match 'if \(\$MenuToolsStartupManager\)'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsStartupManager -EventName ''Click'''
    }

    It 'invokes Show-GuiStartupManagerDialog from the Click handler' {
        $script:ActionHandlersContent | Should -Match 'Show-GuiStartupManagerDialog'
    }

    It 'guards on Get-Command so a missing helper module never breaks the menu' {
        $idxIf = $script:ActionHandlersContent.IndexOf('if ($MenuToolsStartupManager)')
        $tail = $script:ActionHandlersContent.Substring($idxIf)
        $tail | Should -Match "Get-Command -Name 'Show-GuiStartupManagerDialog' -CommandType Function -ErrorAction SilentlyContinue"
    }

    It 'uses the run-in-progress gate so Startup Manager cannot be opened mid-apply' {
        $idxIf = $script:ActionHandlersContent.IndexOf('if ($MenuToolsStartupManager)')
        $tail = $script:ActionHandlersContent.Substring($idxIf)
        $tail | Should -Match 'if \(& \$testGuiRunInProgressCapture\) \{ return \}'
    }
}
