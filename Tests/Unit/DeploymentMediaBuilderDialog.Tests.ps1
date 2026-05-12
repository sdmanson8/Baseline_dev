Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $script:DialogPath = Join-Path $script:RepoRoot 'Module/GUI/DeploymentMediaBuilderDialog.ps1'
    $script:ViewPath = Join-Path $script:RepoRoot 'Module/GUI/DeploymentMediaBuilderView.ps1'
    $script:XamlPath = Join-Path $script:RepoRoot 'Module/GUI/MainWindow.xaml'
    $script:WindowSetupPath = Join-Path $script:RepoRoot 'Module/GUI/WindowSetup.ps1'
    $script:StyleManagementPath = Join-Path $script:RepoRoot 'Module/GUI/StyleManagement.ps1'
    $script:ModeStatePath = Join-Path $script:RepoRoot 'Module/GUI/ModeState.ps1'
    $script:SessionRestorePartPath = Join-Path $script:RepoRoot 'Module/GUI/SessionState/Restore-GuiSettingsSnapshot/RestorePreferenceSettings.ps1'
    $script:ActionHandlersPath = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers.ps1'
    $script:ActionHandlersSplitRoot = Join-Path $script:RepoRoot 'Module/GUI/ActionHandlers'
    $script:GuiRegionPath = Join-Path $script:RepoRoot 'Module/Regions/GUI.psm1'

    $script:DialogContent = Get-BaselineTestSourceText -Path $script:DialogPath
    $script:ViewContent = Get-BaselineTestSourceText -Path $script:ViewPath
    $script:XamlContent = Get-BaselineTestSourceText -Path $script:XamlPath
    $script:WindowSetupContent = Get-BaselineTestSourceText -Path $script:WindowSetupPath
    $script:StyleContent = Get-BaselineTestSourceText -Path $script:StyleManagementPath
    $script:ModeContent = Get-BaselineTestSourceText -Path $script:ModeStatePath
    $script:SessionRestoreContent = Get-BaselineTestSourceText -Path $script:SessionRestorePartPath
    $script:ActionHandlersContent = Get-BaselineTestSourceText -Path @(
        $script:ActionHandlersPath
        (Join-Path $script:ActionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $script:ActionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $script:GuiRegionContent = Get-BaselineTestSourceText -Path $script:GuiRegionPath
}

Describe 'Deployment Media Builder menu wiring' {
    It 'declares Advanced Tools > Deployment Media Builder in the Tools menu' {
        $script:XamlContent | Should -Match 'Name="MenuToolsAdvanced"'
        $script:XamlContent | Should -Match 'Name="MenuToolsDeploymentMediaBuilder"'
        $idxAdvanced = $script:XamlContent.IndexOf('Name="MenuToolsAdvanced"')
        $idxItem = $script:XamlContent.IndexOf('Name="MenuToolsDeploymentMediaBuilder"')
        $idxItem | Should -BeGreaterThan $idxAdvanced
    }

    It 'wires FindName + script assignments in WindowSetup.ps1' {
        $script:WindowSetupContent | Should -Match '\$MenuToolsAdvanced = \$Form\.FindName\("MenuToolsAdvanced"\)'
        $script:WindowSetupContent | Should -Match '\$MenuToolsDeploymentMediaBuilder = \$Form\.FindName\("MenuToolsDeploymentMediaBuilder"\)'
        $script:WindowSetupContent | Should -Match '\$Script:MenuToolsAdvanced = \$MenuToolsAdvanced'
        $script:WindowSetupContent | Should -Match '\$Script:MenuToolsDeploymentMediaBuilder = \$MenuToolsDeploymentMediaBuilder'
    }

    It 'localizes and enables the menu item through the normal menu surfaces' {
        $script:StyleContent | Should -Match 'GuiMenuToolsAdvanced'
        $script:StyleContent | Should -Match 'GuiMenuToolsDeploymentMediaBuilder'
        $script:StyleContent | Should -Match 'MenuToolsDeploymentMediaBuilder\.IsEnabled = \$Enabled'
        $script:ActionHandlersContent | Should -Match 'GuiMenuToolsDeploymentMediaBuilder'
    }

    It 'hides advanced deployment media tools in Safe Mode and restores them in Expert Mode' {
        $script:ModeContent | Should -Match 'MenuToolsAdvanced.*\$safeModeHidden'
        $script:ModeContent | Should -Match 'MenuToolsDeploymentMediaBuilder.*\$safeModeHidden'
        $script:ModeContent | Should -Match 'MenuToolsDeploymentMediaBuilder.*''Visible'''
        $script:SessionRestoreContent | Should -Match 'MenuToolsDeploymentMediaBuilder.*\$modeHidden'
    }

    It 'dot-sources DeploymentMediaBuilderDialog.ps1 from Module/Regions/GUI.psm1' {
        $script:GuiRegionContent | Should -Match "Join-Path \`$Script:GuiExtractedRoot 'DeploymentMediaBuilderDialog\.ps1'"
    }

    It 'dot-sources DeploymentMediaBuilderView.ps1 from Module/Regions/GUI.psm1' {
        $script:GuiRegionContent | Should -Match "Join-Path \`$Script:GuiExtractedRoot 'DeploymentMediaBuilderView\.ps1'"
    }
}

Describe 'Deployment Media Builder top navigation view' {
    It 'declares the builder navigation mode and inline view controls' {
        $script:XamlContent | Should -Match 'Name="NavModeDeploymentMedia"'
        $script:XamlContent | Should -Match '(?s)Name="NavModeUpdates".*Name="NavModeDeploymentMedia".*Name="NavModeApps"'
        $script:XamlContent | Should -Match 'Name="DeploymentMediaView"'
        $script:XamlContent | Should -Match 'Name="BtnDeploymentMediaDetectIso"'
        $script:XamlContent | Should -Match 'Name="BtnDeploymentMediaPreviewPlan"'
        $script:XamlContent | Should -Match 'Name="BtnDeploymentMediaStartBuild"'
        $script:XamlContent | Should -Match 'Setup checklist'
    }

    It 'keeps DeploymentMediaView free of filter and search surfaces' {
        $idxStart = $script:XamlContent.IndexOf('<Grid Name="DeploymentMediaView"')
        $idxStart | Should -BeGreaterThan -1
        $idxEnd = $script:XamlContent.IndexOf('<Grid Name="AppsView"', $idxStart)
        $idxEnd | Should -BeGreaterThan $idxStart
        $deploymentViewXaml = $script:XamlContent.Substring($idxStart, $idxEnd - $idxStart)
        $deploymentViewXaml | Should -Not -Match 'Search'
        $deploymentViewXaml | Should -Not -Match 'Filter'
    }

    It 'wires the navigation view through normal mode state and plan helpers' {
        $script:WindowSetupContent | Should -Match '\$NavModeDeploymentMedia = \$Form\.FindName\("NavModeDeploymentMedia"\)'
        $script:WindowSetupContent | Should -Match '\$DeploymentMediaView = \$Form\.FindName\("DeploymentMediaView"\)'
        $script:WindowSetupContent | Should -Match '\$Script:NavModeDeploymentMedia = \$NavModeDeploymentMedia'
        $script:WindowSetupContent | Should -Match '\$Script:DeploymentMediaView = \$DeploymentMediaView'
        $script:StyleContent | Should -Match 'Nav_DeploymentMedia'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$NavModeDeploymentMedia -EventName ''Checked'''
        $script:ViewContent | Should -Match 'function Initialize-GuiDeploymentMediaBuilderView'
        $script:ViewContent | Should -Match 'function Get-GuiDeploymentMediaBuilderPlan'
        $script:ViewContent | Should -Match 'New-GuiDeploymentMediaBuildPlan'
        $script:ViewContent | Should -Match 'Invoke-GuiDeploymentMediaBuild -Plan \$plan'
    }
}

Describe 'Deployment Media Builder dialog contract' {
    It 'defines the dialog and plan/report helpers' {
        $script:DialogContent | Should -Match 'function Show-GuiDeploymentMediaBuilderDialog'
        $script:DialogContent | Should -Match 'function New-GuiDeploymentMediaBuildPlan'
        $script:DialogContent | Should -Match 'function Get-GuiDeploymentMediaIsoImageInfo'
        $script:DialogContent | Should -Match 'function Invoke-GuiDeploymentMediaBuild'
        $script:DialogContent | Should -Match 'function Resolve-GuiDeploymentMediaOscdimgPath'
        $script:DialogContent | Should -Match 'function Invoke-GuiDeploymentMediaDriverInjection'
        $script:DialogContent | Should -Match 'function Save-GuiDeploymentMediaBuildReport'
    }

    It 'short-circuits in headless harness when $Script:CurrentTheme is unset' {
        $script:DialogContent | Should -Match 'if \(-not \$Script:CurrentTheme\)'
        $script:DialogContent | Should -Match 'return @\{ Cancelled = \$true; Previewed = \$false; Started = \$false; ReportPath = \$null; OutputPath = \$null; BuildRoot = \$null \}'
    }

    It 'keeps the workflow explicit, previewable, and auditable' {
        $script:DialogContent | Should -Match 'Preview Build Plan'
        $script:DialogContent | Should -Match 'Start ISO Build'
        $script:DialogContent | Should -Match 'Detect Editions'
        $script:DialogContent | Should -Match 'IsEnabled="False"'
        $script:DialogContent | Should -Match 'Show-ThemedDialog -Title \$titleText'
        $script:DialogContent | Should -Match 'Invoke-GuiDeploymentMediaBuild -Plan \$currentPlan'
        $script:DialogContent | Should -Match 'Build report saved'
    }

    It 'preserves the safety contract from todo1.md' {
        foreach ($expected in @(
            'Official Microsoft ISO only',
            'Never modify the original ISO',
            'Always use a temp/working directory',
            'Always verify WIM/ESD presence and selected image index',
            'Always show the selected edition before build',
            'Always produce a build log/report',
            'Always cleanup mounts',
            'Support safe cancellation',
            'Never silently ignore DISM or oscdimg failures',
            'Use Preview Build Plan before exposing Start ISO Build'
        )) {
            $script:DialogContent | Should -Match ([regex]::Escape($expected))
        }
    }

    It 'validates source ISO, edition index, answer file, and driver directory before start is enabled' {
        $script:DialogContent | Should -Match 'Source ISO is required'
        $script:DialogContent | Should -Match 'Source ISO must be an \.iso file'
        $script:DialogContent | Should -Match 'Selected edition index must be 1 or higher'
        $script:DialogContent | Should -Match 'Run Detect Editions before starting a build'
        $script:DialogContent | Should -Match 'Autounattend file must be an \.xml file'
        $script:DialogContent | Should -Match 'Driver source directory does not exist'
        $script:DialogContent | Should -Match '\$btnStartBuild\.IsEnabled = \[bool\]\$currentPlan\.IsValid'
    }

    It 'inspects the selected ISO with Windows image APIs and cleans up the mount' {
        $script:DialogContent | Should -Match 'Mount-DiskImage -ImagePath \$SourceIso'
        $script:DialogContent | Should -Match 'Get-WindowsImage -ImagePath \$imagePath'
        $script:DialogContent | Should -Match 'sources\\install\.wim'
        $script:DialogContent | Should -Match 'sources\\install\.esd'
        $script:DialogContent | Should -Match 'Dismount-DiskImage -ImagePath \$SourceIso'
        $script:DialogContent | Should -Match 'Failed to cleanup mounted ISO'
    }

    It 'performs real media build actions instead of only writing a report' {
        $script:DialogContent | Should -Match 'Invoke-GuiDeploymentMediaRobocopy -Source \$isoRoot -Destination \$mediaRoot'
        $script:DialogContent | Should -Match 'Copy-Item -LiteralPath \(\[string\]\$Plan\.AutounattendPath\) -Destination \$answerDestination'
        $script:DialogContent | Should -Match 'Get-SelectedTweakRunList -TweakManifest \$Script:TweakManifest -Controls \$Script:Controls'
        $script:DialogContent | Should -Match 'Mount-WindowsImage -ImagePath \$installImagePath'
        $script:DialogContent | Should -Match 'Add-WindowsDriver -Path \$installMountPath'
        $script:DialogContent | Should -Match 'Dismount-WindowsImage -Path \$installMountPath -Save'
        $script:DialogContent | Should -Match 'oscdimg\.exe is required to create an ISO'
        $script:DialogContent | Should -Match 'Invoke-GuiDeploymentMediaProcess -FilePath \$oscdimgPath'
        $script:DialogContent | Should -Match 'Invoke-GuiDeploymentMediaRobocopy -Source \$mediaRoot -Destination \$targetRoot'
        $script:DialogContent | Should -Match 'Invoke-GuiDeploymentMediaProcess -FilePath \$bootsectPath'
        $script:DialogContent | Should -Match '\$validatedPlan = New-GuiDeploymentMediaBuildPlan'
        $script:DialogContent | Should -Match 'Deployment media build plan failed final validation'
    }

    It 'keeps Create USB explicit and conservative' {
        $script:DialogContent | Should -Match 'TxtUsbTargetRoot'
        $script:DialogContent | Should -Match 'USB target root is required when output mode is Create USB'
        $script:DialogContent | Should -Match 'USB target must be the root of a removable drive'
        $script:DialogContent | Should -Match 'USB target must be a removable drive'
        $script:DialogContent | Should -Match 'USB target root must be empty before Baseline copies media to it'
        $script:DialogContent | Should -Match 'Get-CimInstance -ClassName Win32_LogicalDisk'
    }
}

Describe 'Deployment Media Builder click handler integration' {
    It 'captures the dialog command from the GUI runtime command surface' {
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-GuiDeploymentMediaBuilderDialog' -CommandType 'Function'"
        $script:ActionHandlersContent | Should -Match 'Show-GuiDeploymentMediaBuilderDialog not found'
    }

    It 'registers a guarded click handler on MenuToolsDeploymentMediaBuilder' {
        $script:ActionHandlersContent | Should -Match 'if \(\$MenuToolsDeploymentMediaBuilder\)'
        $script:ActionHandlersContent | Should -Match 'Register-GuiEventHandler -Source \$MenuToolsDeploymentMediaBuilder -EventName ''Click'''
        $idxIf = $script:ActionHandlersContent.IndexOf('if ($MenuToolsDeploymentMediaBuilder)')
        $tail = $script:ActionHandlersContent.Substring($idxIf)
        $tail | Should -Match 'if \(& \$testGuiRunInProgressCapture\) \{ return \}'
        $tail | Should -Match 'Deployment Media Builder dialog command is not available\.'
    }
}
