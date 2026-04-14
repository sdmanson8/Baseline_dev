Set-StrictMode -Version Latest

BeforeAll {
    $script:PreflightChecksPath = Join-Path $PSScriptRoot '../../Module/GUI/PreflightChecks.ps1'
    $script:PreflightChecksContent = Get-Content -LiteralPath $script:PreflightChecksPath -Raw -Encoding UTF8
}

Describe 'Preflight checks' {
    It 'includes a managed policy environment check in the preflight run' {
        $script:PreflightChecksContent | Should -Match 'function Test-PreflightManagedPolicyEnvironment'
        $script:PreflightChecksContent | Should -Match "GuiPreflightNamePolicies"
        $script:PreflightChecksContent | Should -Match "GuiPreflightPoliciesPassed"
        $script:PreflightChecksContent | Should -Match "GuiPreflightPoliciesError"
        $script:PreflightChecksContent | Should -Match 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer'
        $script:PreflightChecksContent | Should -Match 'Test-PreflightManagedPolicyEnvironment'
        $script:PreflightChecksContent | Should -Match 'Review the connected target with the remote console and confirm the GPO scope before applying changes'
        $script:PreflightChecksContent | Should -Match 'Export the relevant policy hives or document the enforced settings before a high-risk run'
        $script:PreflightChecksContent | Should -Match 'RemediationActions'
        $script:PreflightChecksContent | Should -Match 'Generate an incident reproduction pack from the support bundle after any failed remediation attempt'
    }
}
