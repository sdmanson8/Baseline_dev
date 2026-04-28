Set-StrictMode -Version Latest

BeforeAll {
    $script:UpdateOverlayContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/GUI/UpdateOverlayModule.ps1') -Raw -Encoding UTF8
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
}
