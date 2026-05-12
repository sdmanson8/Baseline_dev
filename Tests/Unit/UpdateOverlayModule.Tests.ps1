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
    It 'routes version lookup, click-handler cleanup, process launch, and dispose failures through Write-SwallowedException' {
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.LoadCurrentVersion'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.RemoveUpdateCheckPrimaryClickEvent'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.OpenReleasePage'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.DownloadCleanup\.DisposePowerShell'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.DownloadCleanup\.DisposeRunspace'"
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.RemoveDownloadStartEvent'"
    }

    It 'keeps update-check close actions from invoking the download handler' {
        $script:UpdateOverlayContent | Should -Match '\$setUpdateCheckPrimaryClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadYes\.Remove_Click\(\$Script:DownloadStartEvent\)'
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.RemoveDownloadExtractEvent'"
        $script:UpdateOverlayContent | Should -Match '\$setUpdateCheckCloseClickEvent = \{'
        $script:UpdateOverlayContent | Should -Match '\$Script:BtnDownloadNo\.Remove_Click\(\$Script:UpdateCheckSecondaryClickEvent\)'
        $script:UpdateOverlayContent | Should -Match '\$wireCloseButtons = \{'
        $script:UpdateOverlayContent | Should -Match 'Hide-BaselineUpdateOverlay'
        $script:UpdateOverlayContent | Should -Match "Source 'UpdateOverlayModule\.HideUpdateOverlayCommand'"
        $script:UpdateOverlayContent | Should -Not -Match '\$startBaselineDownloadCommand = Get-GuiRuntimeCommand'
    }

    It 'covers the full window grid and initializes update-check click state' {
        $script:MainWindowContent | Should -Match 'Name="UpdateDialogOverlay" Grid\.RowSpan="2"'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateCheckPrimaryClickEvent = \$null'
        $script:WindowSetupContent | Should -Match '\$Script:UpdateCheckSecondaryClickEvent = \$null'
    }

    It 'captures update overlay click dependencies before WPF delegates run' {
        $script:GuiRegionContent | Should -Match '\$startBaselineDownloadScript = Get-GuiFunctionCapture -Name ''Start-BaselineDownload'''
        $script:GuiRegionContent | Should -Match '\$hideBaselineUpdateOverlayScript = Get-GuiFunctionCapture -Name ''Hide-BaselineUpdateOverlay'''
        $script:GuiRegionContent | Should -Match '& \$startBaselineDownloadScript -Uri \$uri -DestinationPath \$tempPath'
        $script:GuiRegionContent | Should -Match '& \$hideBaselineUpdateOverlayScript'
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
