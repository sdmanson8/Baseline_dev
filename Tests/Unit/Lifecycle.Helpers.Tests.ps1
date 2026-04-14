Set-StrictMode -Version Latest

BeforeAll {
    $script:LifecycleHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/Lifecycle.Helpers.ps1'
    $script:LifecycleHelpersContent = Get-Content -LiteralPath $script:LifecycleHelpersPath -Raw -Encoding UTF8
    $script:LifecycleToolPath = Join-Path $PSScriptRoot '../../Tools/Invoke-LifecyclePlaybook.ps1'
    $script:IncidentToolPath = Join-Path $PSScriptRoot '../../Tools/New-IncidentReproductionPack.ps1'
    $script:SigningPolicyPath = Join-Path $PSScriptRoot '../../docs/Installer-Signing-Policy.md'
}

Describe 'Lifecycle helpers' {
    It 'exposes lifecycle playbook and incident reproduction helpers' {
        $script:LifecycleHelpersContent | Should -Match 'function New-BaselineLifecyclePlaybook'
        $script:LifecycleHelpersContent | Should -Match 'function Invoke-BaselineLifecyclePlaybook'
        $script:LifecycleHelpersContent | Should -Match 'function Import-BaselineRollbackProfile'
        $script:LifecycleHelpersContent | Should -Match 'function New-BaselineIncidentReproductionPack'
        $script:LifecycleHelpersContent | Should -Match 'Rollback profile'
        $script:LifecycleHelpersContent | Should -Match 'incident reproduction'
    }

    It 'ships the lifecycle tooling and signing policy documentation' {
        Test-Path -LiteralPath $script:LifecycleToolPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $script:IncidentToolPath -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath $script:SigningPolicyPath -PathType Leaf | Should -BeTrue
    }
}
