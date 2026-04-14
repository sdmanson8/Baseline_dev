Set-StrictMode -Version Latest

BeforeAll {
    $actionPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:ActionContent = Get-Content -LiteralPath $actionPath -Raw -Encoding UTF8
}

Describe 'Preview run handoff' {
    It 'starts execution when the preview dialog returns the run label' {
        $script:ActionContent | Should -Match 'Register-GuiEventHandler -Source \$BtnPreviewRun -EventName ''Click'''
        $script:ActionContent | Should -Match '\$previewResult = & \$showSelectedTweakPreviewCommand -SelectedTweaks \$tweakList -AllowApply'
        $script:ActionContent | Should -Match 'if \(\$previewResult -and \$previewResult -eq \(& \$getUxRunActionLabelCommand\)\)'
        $script:ActionContent | Should -Match '& \$startGuiExecutionRunCommand -TweakList \$tweakList -Mode ''Run'' -ExecutionTitle'
    }
}
