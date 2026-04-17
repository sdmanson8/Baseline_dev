Set-StrictMode -Version Latest

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../Module/SharedHelpers.psm1'
}

AfterAll {
    Remove-Module SharedHelpers -Force -ErrorAction SilentlyContinue
    foreach ($helperModule in @(Get-Module 'Baseline.SharedHelpers.*'))
    {
        Remove-Module -ModuleInfo $helperModule -Force -ErrorAction SilentlyContinue
    }
}

Describe 'SharedHelpers helper module inventory' {
    BeforeEach {
        Remove-Module SharedHelpers -Force -ErrorAction SilentlyContinue
        foreach ($helperModule in @(Get-Module 'Baseline.SharedHelpers.*'))
        {
            Remove-Module -ModuleInfo $helperModule -Force -ErrorAction SilentlyContinue
        }
    }

    It 'imports helper slices as explicit named modules' {
        Import-Module $script:ModulePath -Force

        $helperModules = @(Get-Module 'Baseline.SharedHelpers.*')

        $helperModules.Count | Should -Be 30
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.Manifest'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.GameMode'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.RemoteTarget'
    }

    It 'surfaces helper exports through Get-Module inventory' {
        Import-Module $script:ModulePath -Force

        $manifestModule = Get-Module 'Baseline.SharedHelpers.Manifest'
        $gameModeModule = Get-Module 'Baseline.SharedHelpers.GameMode'
        $remoteTargetModule = Get-Module 'Baseline.SharedHelpers.RemoteTarget'

        $manifestModule.ExportedCommands.Keys | Should -Contain 'Get-TweakManifestEntryValue'
        $manifestModule.ExportedCommands.Keys | Should -Contain 'Import-TweakManifestFromData'
        $gameModeModule.ExportedCommands.Keys | Should -Contain 'Get-GameModeProfileDefinitions'
        $gameModeModule.ExportedCommands.Keys | Should -Contain 'Test-GameModeManifestDefaultEnabled'
        $remoteTargetModule.ExportedCommands.Keys | Should -Contain 'Resume-BaselineRemoteOrchestration'
    }

    It 'removes helper slice modules when SharedHelpers is unloaded' {
        Import-Module $script:ModulePath -Force
        @(Get-Module 'Baseline.SharedHelpers.*').Count | Should -Be 30

        Remove-Module SharedHelpers -Force

        @(Get-Module 'Baseline.SharedHelpers.*').Count | Should -Be 0
    }
}
