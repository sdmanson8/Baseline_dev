Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $script:UpdateOverlayContent = Get-BaselineTestSourceText -Path (Join-Path $PSScriptRoot '../../Module/GUI/UpdateOverlayModule.ps1')
    $script:GuiRegionContent = Get-BaselineTestSourceText -Path (Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1')
    $script:MainWindowContent = Get-BaselineTestSourceText -Path (Join-Path $PSScriptRoot '../../Module/GUI/MainWindow.xaml')
    $script:WindowSetupContent = Get-BaselineTestSourceText -Path (Join-Path $PSScriptRoot '../../Module/GUI/WindowSetup.ps1')
}

Describe 'Update overlay swallowed-exception routing' {
    It 'routes version lookup, process launch, and dispose failures through Write-SwallowedException' {
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.LoadCurrentVersion'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.OpenReleasePage'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.DownloadCleanup\.DisposePowerShell'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.DownloadCleanup\.DisposeRunspace'"
    }

    It 'keeps update-check close actions from invoking the download handler' {
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryClickAction'
        $script:UpdateOverlayContent | Should -Match 'function Write-BaselineUpdateOverlayDebug'
        ([regex]::Matches($script:UpdateOverlayContent, 'Write-BaselineUpdateOverlayDebug')).Count | Should -Be 2
        $script:UpdateOverlayContent | Should -Match '\$Script:WriteBaselineUpdateOverlayDebugScript = \$\{function:Write-BaselineUpdateOverlayDebug\}'
        $script:UpdateOverlayContent | Should -Match '\$writeOverlayDebug = if \(\$Script:WriteBaselineUpdateOverlayDebugScript -is \[scriptblock\]\)'
        $script:UpdateOverlayContent | Should -Match 'BASELINE_UPDATE_OVERLAY_DEBUG'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryPreviewMouseDownEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadYes\.Add_PreviewMouseLeftButtonDown\(\$Script:UpdateOverlayPrimaryPreviewMouseDownEvent\)'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryPreviewMouseUpEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadYes\.Add_PreviewMouseLeftButtonUp\(\$Script:UpdateOverlayPrimaryPreviewMouseUpEvent\)'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPreviewMouseDownEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$updateDialogOverlay\.Add_PreviewMouseLeftButtonDown\(\$Script:UpdateOverlayPreviewMouseDownEvent\)'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPreviewMouseUpEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$updateDialogOverlay\.Add_PreviewMouseLeftButtonUp\(\$Script:UpdateOverlayPreviewMouseUpEvent\)'
        $script:UpdateOverlayContent | Should -Match '\$updateDialogOverlay = \$Script:UpdateDialogOverlay'
        $script:UpdateOverlayContent | Should -Match '\$updateDialogOverlay\.Visibility = \[System\.Windows\.Visibility\]::Collapsed'
        $script:UpdateOverlayContent | Should -Match '\$updateDialogOverlay\.IsHitTestVisible = \$false'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateDialogOverlay\.IsHitTestVisible = \$true'
        $script:UpdateOverlayContent | Should -Match '\[bool\]\$PrimaryButtonCloses = \$false'
        $script:UpdateOverlayContent | Should -Match '-PrimaryButtonCloses:\$true'
        $script:UpdateOverlayContent | Should -Match '\$overlayState\.PrimaryCloses'
        $script:UpdateOverlayContent | Should -Match '\$closeOverlayDirect = \{'
        $script:UpdateOverlayContent | Should -Match 'New-Object System\.Windows\.Controls\.ProgressBar'
        $script:UpdateOverlayContent | Should -Match '\$progressBar\.IsHitTestVisible = \$false'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadYes\.IsDefault = \$false'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadYes\.IsCancel = \$false'
        $script:UpdateOverlayContent | Should -Not -Match 'IsCancel = \[bool\]\$PrimaryButtonCloses'
        $script:UpdateOverlayContent | Should -Not -Match 'New-SharedProgressBarHost -Maximum 100 -Value 0'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlaySecondaryClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlaySecondaryClickAction'
        $script:UpdateOverlayContent | Should -Match '\$setUpdateCheckPrimaryClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$setUpdateCheckCloseClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$wireCloseButtons = \{'
        $script:UpdateOverlayContent | Should -Match 'function New-BaselineUpdateOverlayCloseAction'
        $script:UpdateOverlayContent | Should -Match '\$hideBaselineUpdateOverlayAction = New-BaselineUpdateOverlayCloseAction'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryClickAction = \$Script:UpdateCheckPrimaryClickEvent'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlaySecondaryClickAction = \$Script:UpdateCheckSecondaryClickEvent'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayPrimaryClickAction = \$Script:DownloadExtractEvent'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayState\.PrimaryCloses = \$true'
        $script:UpdateOverlayContent | Should -Match '\$Script:UpdateOverlayState\.PrimaryCloses = \$false'
        $script:UpdateOverlayContent | Should -Not -Match '\.Remove_Click\('
        $script:UpdateOverlayContent | Should -Not -Match 'Hide-BaselineUpdateOverlay capture not found'
        $script:UpdateOverlayContent | Should -Not -Match '\$hideBaselineUpdateOverlayScript = Get-GuiFunctionCapture -Name ''Hide-BaselineUpdateOverlay'''
        $script:UpdateOverlayContent | Should -Not -Match '(?m)^\s*Hide-BaselineUpdateOverlay\s*$'
        $script:UpdateOverlayContent | Should -Not -Match '\$hideBaselineUpdateOverlayCommand = Get-GuiRuntimeCommand'
        $script:UpdateOverlayContent | Should -Not -Match '\$startBaselineDownloadCommand = Get-GuiRuntimeCommand'
    }

    It 'covers the full window grid and initializes update-check click state' {
        $script:MainWindowContent | Should -Match 'Name="UpdateDialogOverlay" Grid\.RowSpan="2"'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateCheckPrimaryClickEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateCheckSecondaryClickEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPrimaryClickEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlaySecondaryClickEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPrimaryPreviewMouseDownEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPrimaryPreviewMouseUpEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPreviewMouseDownEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPreviewMouseUpEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayPrimaryClickAction = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlaySecondaryClickAction = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateOverlayState = \[hashtable\]::Synchronized'
    }

    It 'captures update overlay click dependencies before WPF delegates run' {
        $script:GuiRegionContent | Should -Match '\$startBaselineDownloadScript = Get-GuiFunctionCapture -Name ''Start-BaselineDownload'''
        $script:GuiRegionContent | Should -Match '\$hideBaselineUpdateOverlayScript = Get-GuiFunctionCapture -Name ''Hide-BaselineUpdateOverlay'''
        $script:GuiRegionContent | Should -Match '& \$startBaselineDownloadScript -Uri \$uri -DestinationPath \$tempPath'
        $script:GuiRegionContent | Should -Match '& \$hideBaselineUpdateOverlayScript'
        $script:GuiRegionContent | Should -Match '\$Script:UpdateOverlayPrimaryClickAction = \$Script:DownloadStartEvent'
        $script:GuiRegionContent | Should -Match '\$Script:UpdateOverlaySecondaryClickAction = \{'
        $script:GuiRegionContent | Should -Match '\$Script:UpdateOverlayState\.SecondaryCloses = \$true'
        $script:GuiRegionContent | Should -Not -Match '\$BtnDownloadYes\.Add_Click\(\$Script:DownloadStartEvent\)'
        $script:GuiRegionContent | Should -Not -Match '\$downloadCommand = Get-GuiFunctionCapture'
        $script:GuiRegionContent | Should -Not -Match '\$hideBaselineUpdateOverlayCommand'
    }

    It 'selects update assets with channel-qualified zip patterns' {
        $script:UpdateOverlayContent | Should -Match 'Get-BaselineUpdateAssetPattern -Branch \$updateBranch'
        $script:UpdateOverlayContent | Should -Match "'Baseline-\*-beta\.zip'"
        $script:UpdateOverlayContent | Should -Match "'Baseline-\*-stable\.zip'"
        $script:UpdateOverlayContent | Should -Match '\$release\.assets \| Where-Object \{ \$_.name -like \$releaseAssetPattern \}'
        $script:UpdateOverlayContent | Should -Not -Match "'Baseline-\*\.zip'"
    }
}
