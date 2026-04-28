Set-StrictMode -Version Latest

BeforeAll {
    $script:GroupPolicyHelpersContent = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Module/SharedHelpers/GroupPolicy.Helpers.ps1') -Raw -Encoding UTF8
}

Describe 'GroupPolicy helper swallowed-exception routing' {
    It 'routes environment and policy lookup failures through Write-DebugSwallowedException' {
        $script:GroupPolicyHelpersContent | Should -Match "Source 'GroupPolicy\.GetBaselineGpoPolicyValueState\.GetValueKind'"
        $script:GroupPolicyHelpersContent | Should -Match "Source 'GroupPolicy\.GetBaselineGpoPolicyValueState\.LoadValue'"
        $script:GroupPolicyHelpersContent | Should -Match "Source 'GroupPolicy\.GetBaselineGpoEnvironmentSummary\.LoadComputerSystem'"
        $script:GroupPolicyHelpersContent | Should -Match "Source 'GroupPolicy\.GetBaselineGpoEnvironmentSummary\.LoadEnrollments'"
        $script:GroupPolicyHelpersContent | Should -Match "Source 'GroupPolicy\.GetBaselineGpoEnvironmentSummary\.ScanPolicyRoot'"
    }
}
