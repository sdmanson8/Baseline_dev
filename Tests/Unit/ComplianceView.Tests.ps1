Set-StrictMode -Version Latest

BeforeAll {
    $compliancePath = Join-Path $PSScriptRoot '../../Module/GUI/ComplianceView.ps1'
    $complianceHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/Compliance.Helpers.ps1'
    $script:ComplianceContent = Get-Content -LiteralPath $compliancePath -Raw -Encoding UTF8
    $script:ComplianceHelpersContent = Get-Content -LiteralPath $complianceHelpersPath -Raw -Encoding UTF8
}

Describe 'Compliance view remote targeting' {
    It 'checks the connected remote target before running compliance locally' {
        $script:ComplianceContent | Should -Match 'Get-GuiRemoteTargetContext'
        $script:ComplianceContent | Should -Match 'Invoke-BaselineRemoteCompliance'
        $script:ComplianceContent | Should -Match 'Remote compliance: Compliant targets'
    }

    It 'routes compliance dialog setup and remote-context lookup failures through Write-DebugSwallowedException' {
        $script:ComplianceContent | Should -Match "ComplianceView\.ShowComplianceDialog\.SetOwner"
        $script:ComplianceContent | Should -Match "ComplianceView\.ShowComplianceDialog\.DispatcherYield"
        $script:ComplianceContent | Should -Match "ComplianceView\.ShowComplianceDialog\.GetRemoteTargetContext"
    }

    It 'routes compliance dispatcher yields through Write-DebugSwallowedException' {
        $script:ComplianceHelpersContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''ComplianceHelpers\.Test-SystemCompliance\.DispatcherYield'''
    }
}
