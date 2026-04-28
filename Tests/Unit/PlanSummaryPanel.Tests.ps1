Set-StrictMode -Version Latest

BeforeAll {
    $planSummaryPath = Join-Path $PSScriptRoot '../../Module/GUI/PlanSummaryPanel.ps1'
    $script:PlanSummaryContent = Get-Content -LiteralPath $planSummaryPath -Raw -Encoding UTF8
}

Describe 'Plan summary panel' {
    It 'routes owner assignment failures through Write-DebugSwallowedException' {
        $script:PlanSummaryContent | Should -Match "PlanSummaryPanel\.ShowPlanSummaryPanel\.SetOwner"
    }
}
