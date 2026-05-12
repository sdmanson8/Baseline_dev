Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $script:RiskDialogContent = Get-BaselineTestSourceText -Path (Join-Path $repoRoot 'Module/GUICommon/RiskDecisionDialog.ps1')
    $script:CommonDialogContent = Get-BaselineTestSourceText -Path (Join-Path $repoRoot 'Module/GUICommon/Dialogs.ps1')
    $script:PreviewBuildersContent = Get-BaselineTestSourceText -Path (Join-Path $repoRoot 'Module/GUI/PreviewBuilders.ps1')
    $script:ButtonHandlersContent = Get-BaselineTestSourceText -Path (Join-Path $repoRoot 'Module/GUI/ActionHandlers/ButtonHandlers.ps1')
    $script:PreflightContent = Get-BaselineTestSourceText -Path (Join-Path $repoRoot 'Module/GUI/PreflightChecks.ps1')
}

Describe 'Run warning dialog action hierarchy' {
    It 'uses Cancel, Preview Run, and Run Anyway as the default risk decision buttons' {
        $script:RiskDialogContent | Should -Match '\[string\[\]\]\$Buttons = @\(''Cancel'', ''Preview Run'', ''Run Anyway''\)'
        $script:RiskDialogContent | Should -Match "'Run Anyway' \{ return 'Warning' \}"
        $script:CommonDialogContent | Should -Match "'Run Anyway' \{ return 'Warning' \}"
    }

    It 'makes Run Anyway the destructive action in high-risk and preflight dialogs' {
        $script:PreviewBuildersContent | Should -Match '-Buttons @\(''Cancel'', \$previewActionLabel, ''Run Anyway''\)'
        $script:PreviewBuildersContent | Should -Match "-DestructiveButton 'Run Anyway'"
        $script:PreviewBuildersContent | Should -Not -Match 'Continue Anyway'
        $script:ButtonHandlersContent | Should -Match "'Run Anyway'"
        $script:ButtonHandlersContent | Should -Not -Match 'Continue Anyway'
        $script:PreflightContent | Should -Match "GuiPreflightContinueAnyway' -Fallback 'Run Anyway'"
        $script:PreflightContent | Should -Match '-DestructiveButton \$continueAnywayLabel'
    }

    It 'gates the plan summary behind RequireRunConfirmation' {
        $script:ButtonHandlersContent | Should -Match "Get-Variable -Scope Script -Name 'RequireRunConfirmation'"
        $script:ButtonHandlersContent | Should -Match 'if \(\$requireRunConfirmation\)'
        $script:ButtonHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-PlanSummaryDialog'"
        $script:ButtonHandlersContent | Should -Match '& \$showPlanSummaryDialogCommand -SelectedTweaks \$tweakList -PreflightResults \$planPreflightResults'
    }
}
