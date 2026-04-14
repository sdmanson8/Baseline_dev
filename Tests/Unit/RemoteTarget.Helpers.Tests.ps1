Set-StrictMode -Version Latest

BeforeAll {
    $script:RemoteTargetHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/RemoteTarget.Helpers.ps1'
    $script:SharedHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers.psm1'
    $script:RemoteTargetHelpersContent = Get-Content -LiteralPath $script:RemoteTargetHelpersPath -Raw -Encoding UTF8
    $script:SharedHelpersContent = Get-Content -LiteralPath $script:SharedHelpersPath -Raw -Encoding UTF8
}

Describe 'Remote session caching' {
    It 'declares a reusable remote session cache and reuses it across remote operations' {
        $script:RemoteTargetHelpersContent | Should -Match 'RemoteSessionCache'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteSessionKey'
        $script:RemoteTargetHelpersContent | Should -Match 'function Clear-BaselineRemoteSessionCache'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteSession'
        $script:RemoteTargetHelpersContent | Should -Match 'Get-BaselineRemoteSession -ComputerName \$computer -Credential \$Credential'
    }

    It 'declares remote orchestration history helpers and writes structured records' {
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteOrchestrationHistoryPath'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteFailureProfile'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteOrchestrationHistory'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteOrchestrationDetails'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteOrchestrationSummary'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteTargetLifecycleState'
        $script:RemoteTargetHelpersContent | Should -Match 'function Get-BaselineRemoteOrchestrationReconciliation'
        $script:RemoteTargetHelpersContent | Should -Match 'function Invoke-BaselineRemoteEntryWithRetry'
        $script:RemoteTargetHelpersContent | Should -Match 'function Invoke-BaselineRemoteRetryDelay'
        $script:RemoteTargetHelpersContent | Should -Match 'function Test-BaselineRemoteOrchestrationAllowed'
        $script:RemoteTargetHelpersContent | Should -Match 'function Write-BaselineRemoteOrchestrationRecord'
        $script:RemoteTargetHelpersContent | Should -Match 'remote-orchestration\.jsonl'
        $script:RemoteTargetHelpersContent | Should -Match 'FailureCategory'
        $script:RemoteTargetHelpersContent | Should -Match 'RetryReason'
        $script:RemoteTargetHelpersContent | Should -Match 'LifecycleState'
        $script:RemoteTargetHelpersContent | Should -Match 'AttemptCount'
        $script:RemoteTargetHelpersContent | Should -Match 'RetryCount'
    }

    It 'exports the session cache helpers from the shared helpers module' {
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteSession'"
        $script:SharedHelpersContent | Should -Match "'Clear-BaselineRemoteSessionCache'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteOrchestrationHistoryPath'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteFailureProfile'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteOrchestrationHistory'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteOrchestrationDetails'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteOrchestrationSummary'"
        $script:SharedHelpersContent | Should -Match "'Get-BaselineRemoteOrchestrationReconciliation'"
        $script:SharedHelpersContent | Should -Match "'Write-BaselineRemoteOrchestrationRecord'"
    }

    It 'clears cached sessions when the GUI disconnects a remote target' {
        $actionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
        $actionHandlersContent = Get-Content -LiteralPath $actionHandlersPath -Raw -Encoding UTF8

        $actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Clear-BaselineRemoteSessionCache'"
        $actionHandlersContent | Should -Match '\$clearRemoteSessionCacheCommand -ComputerName @\(\$context.TargetComputers\)'
    }
}
