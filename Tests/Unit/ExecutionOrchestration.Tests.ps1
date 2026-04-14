Set-StrictMode -Version Latest

BeforeAll {
    $executionPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration.ps1'
    $sessionStatePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $script:ExecutionContent = Get-Content -LiteralPath $executionPath -Raw -Encoding UTF8
    $script:SessionStateContent = Get-Content -LiteralPath $sessionStatePath -Raw -Encoding UTF8
}

Describe 'Execution orchestration timer wiring' {
    It 'captures the execution pump tick scriptblock before registering DispatcherTimer callbacks' {
        ([regex]::Matches($script:ExecutionContent, '\$executionPumpTickFn = \$Script:ExecutionPumpTickFn')).Count | Should -Be 2
        ([regex]::Matches($script:ExecutionContent, 'Add_Tick\(\{\s*& \$executionPumpTickFn\s*\}\.GetNewClosure\(\)\)')).Count | Should -Be 2
    }

    It 'guards execution-view controls before toggling their enabled state' {
        $script:ExecutionContent | Should -Match 'Test-GuiObjectField -Object \$PrimaryTabs -FieldName ''IsEnabled'''
        $script:ExecutionContent | Should -Match 'Test-GuiObjectField -Object \$BtnRun -FieldName ''Content'''
        $script:ExecutionContent | Should -Match 'Test-GuiObjectField -Object \$Script:BtnUndoLastRun -FieldName ''IsEnabled'''
    }

    It 'refreshes the installed-app cache after app actions finish' {
        $script:ExecutionContent | Should -Match "\$Action -in @\('Install', 'Uninstall', 'Update', 'UpdateAll'\)"
        $script:ExecutionContent | Should -Match 'Start-AppsCacheRefresh'
    }

    It 'routes connected remote runs through the remote apply helper' {
        $script:ExecutionContent | Should -Match 'Get-GuiRemoteTargetContext'
        $script:ExecutionContent | Should -Match 'function Confirm-RemoteMultiTargetApply'
        $script:ExecutionContent | Should -Match 'function Confirm-RemoteTargetApproval'
        $script:ExecutionContent | Should -Match 'function Get-ExecutionResumeCandidateList'
        $script:SessionStateContent | Should -Match 'function Save-GuiInterruptedRunProfile'
        $script:SessionStateContent | Should -Match 'function Clear-GuiInterruptedRunProfile'
        $script:ExecutionContent | Should -Match 'Save-GuiInterruptedRunProfile -ResumeCandidates'
        $script:ExecutionContent | Should -Match 'Clear-GuiInterruptedRunProfile'
        $script:ExecutionContent | Should -Match 'Resume Interrupted Run'
        $script:ExecutionContent | Should -Match 'Show-ThemedDialog -Title ''Confirm Remote Apply'''
        $script:ExecutionContent | Should -Match 'Apply to Targets'
        $script:ExecutionContent | Should -Match 'Approve this exact target list for the current GUI session before applying changes'
        $script:ExecutionContent | Should -Match 'Remote run cancelled before apply'
        $script:ExecutionContent | Should -Match 'Remote run cancelled before target approval'
        $script:ExecutionContent | Should -Match 'Invoke-BaselineRemoteApply'
        $script:ExecutionContent | Should -Match 'New-ConfigurationProfile'
        $script:ExecutionContent | Should -Match 'Complete-GuiExecutionRun -Mode ''Run'' -CompletedCount \$executionSummary.Count -ExecutionSummary \$executionSummary -LogPath \$Global:LogFilePath -RemoteExecution -RemoteTargetLabel \$targetLabel'
    }
}
