Set-StrictMode -Version Latest

BeforeAll {
    $script:UpdateOverlayContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/UpdateOverlayModule.ps1') -Raw -Encoding UTF8
    $script:GuiRegionContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1') -Raw -Encoding UTF8
}

Describe 'Update overlay swallowed-exception routing' {
    It 'routes version lookup, click-handler cleanup, process launch, and dispose failures through Write-DebugSwallowedException' {
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
        $script:UpdateOverlayContent | Should -Not -Match '\$startBaselineDownloadCommand = Get-GuiRuntimeCommand'
    }

    It 'captures update overlay click dependencies before WPF delegates run' {
        $script:GuiRegionContent | Should -Match "\$startBaselineDownloadScript = Get-GuiFunctionCapture -Name 'Start-BaselineDownload'"
        $script:GuiRegionContent | Should -Match "\$hideBaselineUpdateOverlayScript = Get-GuiFunctionCapture -Name 'Hide-BaselineUpdateOverlay'"
        $script:GuiRegionContent | Should -Match '& \$startBaselineDownloadScript -Uri \$uri -DestinationPath \$tempPath'
        $script:GuiRegionContent | Should -Match '& \$hideBaselineUpdateOverlayScript'
        $script:GuiRegionContent | Should -Not -Match '\$downloadCommand = Get-GuiFunctionCapture'
        $script:GuiRegionContent | Should -Not -Match '\$hideBaselineUpdateOverlayCommand'
    }
}
