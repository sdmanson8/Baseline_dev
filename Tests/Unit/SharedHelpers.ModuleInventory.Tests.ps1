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

        $helperModules.Count | Should -Be 43
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.Manifest'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.GameMode'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.SingleInstance'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.RemoteTarget'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.RemovalPersistence'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.UserApps'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.NetworkHardening'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.BrowserPolicies'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.Json'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.Process'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.CliMode'
        $helperModules.Name | Should -Contain 'Baseline.SharedHelpers.WindowsUpdate'
    }

    It 'surfaces helper exports through Get-Module inventory' {
        Import-Module $script:ModulePath -Force

        $manifestModule = Get-Module 'Baseline.SharedHelpers.Manifest'
        $gameModeModule = Get-Module 'Baseline.SharedHelpers.GameMode'
        $singleInstanceModule = Get-Module 'Baseline.SharedHelpers.SingleInstance'
        $remoteTargetModule = Get-Module 'Baseline.SharedHelpers.RemoteTarget'
        $initialActionsModule = Get-Module 'Baseline.SharedHelpers.InitialActions'
        $windowsUpdateModule = Get-Module 'Baseline.SharedHelpers.WindowsUpdate'
        $schedulerModule = Get-Module 'Baseline.SharedHelpers.Scheduler'
        $cliModeModule = Get-Module 'Baseline.SharedHelpers.CliMode'

        $manifestModule.ExportedCommands.Keys | Should -Contain 'Get-TweakManifestEntryValue'
        $manifestModule.ExportedCommands.Keys | Should -Contain 'Import-TweakManifestFromData'
        $gameModeModule.ExportedCommands.Keys | Should -Contain 'Get-GameModeProfileDefinitions'
        $gameModeModule.ExportedCommands.Keys | Should -Contain 'Test-GameModeManifestDefaultEnabled'
        $singleInstanceModule.ExportedCommands.Keys | Should -Contain 'Get-BaselineSingleInstanceMutexName'
        $singleInstanceModule.ExportedCommands.Keys | Should -Contain 'Test-BaselineSingleInstanceLockAvailable'
        $singleInstanceModule.ExportedCommands.Keys | Should -Contain 'Resolve-BaselineSingleInstanceDecision'
        (Get-Module 'Baseline.SharedHelpers.PlatformSupport').ExportedCommands.Keys | Should -Contain 'Get-BaselinePlatformFilterOverride'
        $remoteTargetModule.ExportedCommands.Keys | Should -Contain 'Resume-BaselineRemoteOrchestration'
        $initialActionsModule.ExportedCommands.Keys | Should -Contain 'Resolve-BaselineSettingsAppsFeaturesHealthAssessment'
        $initialActionsModule.ExportedCommands.Keys | Should -Contain 'Resolve-BaselineScreenSnippingHealthAssessment'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Get-WindowsUpdateList'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Install-WindowsSecurityUpdates'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Download-WindowsUpdates'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Install-WindowsUpdates'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Get-WindowsUpdateStatus'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Get-WindowsUpdateCompliance'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Invoke-BaselineWindowsUpdateScheduledRun'
        $windowsUpdateModule.ExportedCommands.Keys | Should -Contain 'Get-WindowsUpdateHistory'
        $schedulerModule.ExportedCommands.Keys | Should -Contain 'Register-BaselineWindowsUpdateScheduledRun'
        $cliModeModule.ExportedCommands.Keys | Should -Contain 'Get-BaselinePresetCatalog'
        $cliModeModule.ExportedCommands.Keys | Should -Contain 'Format-BaselinePresetCatalog'
    }

    It 'removes helper slice modules when SharedHelpers is unloaded' {
        Import-Module $script:ModulePath -Force
        @(Get-Module 'Baseline.SharedHelpers.*').Count | Should -Be 43

        Remove-Module SharedHelpers -Force

        @(Get-Module 'Baseline.SharedHelpers.*').Count | Should -Be 0
    }
}
