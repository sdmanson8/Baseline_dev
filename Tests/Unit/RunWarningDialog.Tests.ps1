Set-StrictMode -Version Latest

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $script:RiskDialogContent = Get-Content -LiteralPath (Join-Path $repoRoot 'Module/GUICommon/RiskDecisionDialog.ps1') -Raw -Encoding UTF8
    $script:CommonDialogContent = Get-Content -LiteralPath (Join-Path $repoRoot 'Module/GUICommon/Dialogs.ps1') -Raw -Encoding UTF8
    $script:PreviewBuildersContent = Get-Content -LiteralPath (Join-Path $repoRoot 'Module/GUI/PreviewBuilders.ps1') -Raw -Encoding UTF8
    $script:ButtonHandlersContent = Get-Content -LiteralPath (Join-Path $repoRoot 'Module/GUI/ActionHandlers/ButtonHandlers.ps1') -Raw -Encoding UTF8
    $script:PreflightContent = Get-Content -LiteralPath (Join-Path $repoRoot 'Module/GUI/PreflightChecks.ps1') -Raw -Encoding UTF8
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
}
