Set-StrictMode -Version Latest

BeforeAll {
    $guiRegionPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $script:GuiRegionContent = Get-Content -LiteralPath $guiRegionPath -Raw -Encoding UTF8
}

Describe 'GUI bootstrap PlatformSupport stamp (P2 #18)' {
    # The TweakRowFactory hide-unavailable gate and the ExecutionOrchestration
    # Not-applicable partition both read $entry.Availability. Without a stamp
    # call after manifest load, the block never gets populated and both gates
    # silently no-op. This test pins the wiring so a refactor cannot drop it.

    It 'calls Update-BaselineManifestAvailability after Test-TweakManifestIntegrity' {
        $integrityIndex = $script:GuiRegionContent.IndexOf('Test-TweakManifestIntegrity -Manifest $Script:TweakManifest')
        $stampIndex = $script:GuiRegionContent.IndexOf('Update-BaselineManifestAvailability `')
        $integrityIndex | Should -BeGreaterThan 0
        $stampIndex | Should -BeGreaterThan $integrityIndex
    }

    It 'feeds Get-BaselineSystemPlatformInfo with no override (real host) into the stamp' {
        $script:GuiRegionContent | Should -Match '\$Script:BaselineSystemPlatformInfo = Get-BaselineSystemPlatformInfo'
        $script:GuiRegionContent | Should -Match '-SystemInfo \$Script:BaselineSystemPlatformInfo'
    }

    It 'wraps the stamp in a try/catch routed through Write-DebugSwallowedException' {
        $script:GuiRegionContent | Should -Match "Source 'GUI\.ManifestLoad\.AvailabilityStamp'"
    }

    It 'sets ManifestLoadedFromData only after the stamp has run' {
        $stampIndex = $script:GuiRegionContent.IndexOf('Update-BaselineManifestAvailability `')
        $loadedFlagIndex = $script:GuiRegionContent.IndexOf('$Script:ManifestLoadedFromData = $true')
        $stampIndex | Should -BeGreaterThan 0
        $loadedFlagIndex | Should -BeGreaterThan $stampIndex
    }
}
