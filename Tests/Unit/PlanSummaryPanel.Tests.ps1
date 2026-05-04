Set-StrictMode -Version Latest

BeforeAll {
    $planSummaryPath = Join-Path $PSScriptRoot '../../Module/GUI/PlanSummaryPanel.ps1'
    $script:PlanSummaryContent = Get-Content -LiteralPath $planSummaryPath -Raw -Encoding UTF8
}

Describe 'Plan summary panel' {
    It 'routes owner assignment failures through Write-DebugSwallowedException' {
        $script:PlanSummaryContent | Should -Match "PlanSummaryPanel\.ShowPlanSummaryPanel\.SetOwner"
    }

    It 'captures the run label before wiring WPF click delegates' {
        $script:PlanSummaryContent | Should -Match '\$continueLabel = Get-UxRunActionLabel'
        $script:PlanSummaryContent | Should -Match '\$btnContinue\.Content = \$continueLabel'
        $script:PlanSummaryContent | Should -Match '\$continueLabelRef = \$continueLabel'
        $script:PlanSummaryContent | Should -Match '\$resRefContinue\.Value = \$continueLabelRef'
        $script:PlanSummaryContent | Should -Not -Match '\$resRefContinue\.Value = \(Get-UxRunActionLabel\)'
    }
}
