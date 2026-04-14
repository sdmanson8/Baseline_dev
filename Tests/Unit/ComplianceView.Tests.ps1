Set-StrictMode -Version Latest

BeforeAll {
    $compliancePath = Join-Path $PSScriptRoot '../../Module/GUI/ComplianceView.ps1'
    $script:ComplianceContent = Get-Content -LiteralPath $compliancePath -Raw -Encoding UTF8
}

Describe 'Compliance view remote targeting' {
    It 'checks the connected remote target before running compliance locally' {
        $script:ComplianceContent | Should -Match 'Get-GuiRemoteTargetContext'
        $script:ComplianceContent | Should -Match 'Invoke-BaselineRemoteCompliance'
        $script:ComplianceContent | Should -Match 'Remote compliance: Compliant targets'
    }
}
