Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $executionPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration.ps1'
    $executionStateSummaryPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration/ExecutionStateSummary.ps1'
    $executionViewPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration/ExecutionView.ps1'
    $executionRunPath = Join-Path $PSScriptRoot '../../Module/GUI/ExecutionOrchestration/ExecutionRunOrchestration.ps1'
    $progressChromePath = Join-Path $PSScriptRoot '../../Module/GUI/AppsModule/ProgressNavChrome.ps1'
    $guiExecutionPath = Join-Path $PSScriptRoot '../../Module/GUIExecution.psm1'
    $sessionStatePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $styledControlsPath = Join-Path $PSScriptRoot '../../Module/GUI/StyledControlsSetup.ps1'
    $script:ExecutionContent = Get-BaselineTestSourceText -Path @(
        $executionPath
        $executionStateSummaryPath
        $executionViewPath
        $executionRunPath
    )
    $script:ExecutionViewContent = Get-BaselineTestSourceText -Path $executionViewPath
    $script:ExecutionRunContent = Get-BaselineTestSourceText -Path $executionRunPath
    $script:ExecutionRunPath = $executionRunPath
    $script:ProgressChromeContent = Get-BaselineTestSourceText -Path $progressChromePath
    $script:GuiExecutionContent = Get-BaselineTestSourceText -Path $guiExecutionPath
    $script:SessionStateContent = Get-BaselineTestSourceText -Path $sessionStatePath
    $script:StyledControlsContent = Get-BaselineTestSourceText -Path $styledControlsPath
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

    It 'uses a native WPF progress bar in the execution header' {
        $script:ExecutionViewContent | Should -Match 'New-Object System\.Windows\.Controls\.ProgressBar'
        $script:ExecutionViewContent | Should -Match 'ExecutionView\.ProgressBar\.Foreground'
        $script:ExecutionViewContent | Should -Match 'New-ExecutionProgressBarTemplate'
        $script:ExecutionViewContent | Should -Match 'return New-GuiExecutionProgressBarTemplate'
        $script:ProgressChromeContent | Should -Match 'function New-GuiExecutionProgressBarTemplate'
        $script:ProgressChromeContent | Should -Match '<Border x:Name="PART_Indicator"'
        $script:ProgressChromeContent | Should -Match '<Border x:Name="PART_BusyIndicator"'
        $script:ProgressChromeContent | Should -Match 'Storyboard\.TargetProperty="Opacity"'
        $script:ProgressChromeContent | Should -Match 'Storyboard\.TargetName="BusyIndicatorTransform"'
        $script:ProgressChromeContent | Should -Match 'Storyboard\.TargetProperty="X"'
        $script:ProgressChromeContent | Should -Match '<Trigger Property="IsIndeterminate" Value="True">'
        $script:ProgressChromeContent | Should -Not -Match 'ExecutionSheenRect'
        $script:ProgressChromeContent | Should -Match 'RepeatBehavior="Forever"'
        $script:ProgressChromeContent | Should -Match 'AutoReverse="True"'
        $script:ExecutionViewContent | Should -Match 'ProgressBar = \$progressBar'
        $script:ExecutionViewContent | Should -Not -Match 'New-SharedProgressBarHost -Maximum 1 -Value 0'
    }

    It 'aligns the execution Abort button with the progress bar row' {
        $script:ExecutionViewContent | Should -Match '\$abortBtnHost\.Margin = \[System\.Windows\.Thickness\]::new\(0, -6, 0, 0\)'
        $script:ExecutionViewContent | Should -Match '\$abortBtn\.Height = \(\[double\]\$Script:GuiLayout\.ProgressBarHeight \+ 12\)'
        $script:ExecutionViewContent | Should -Match '\$abortBtn\.Padding = \[System\.Windows\.Thickness\]::new\(16,4,16,4\)'
    }

    It 'keeps run progress driven by queued start and completion events' {
        $script:ExecutionRunContent | Should -Match "GuiProgressPreparingRun' -Fallback 'Busy - preparing run\.\.\.'"
        $script:ExecutionRunContent | Should -Match '& \$Script:UpdateProgressFn -Completed 0 -Total 0 -CurrentAction \$preparingRunLabel'
        $script:ExecutionRunContent | Should -Match "GuiProgressStarting' -Fallback 'Starting\.\.\.'"
        $script:ExecutionRunContent | Should -Match '\$completedStepIndex = if \(\(Test-GuiObjectField -Object \$entry -FieldName ''StepIndex''\)\)'
        $script:ExecutionRunContent | Should -Match '\$completedProgress = if \(\$null -ne \$completedStepIndex\)'
        $script:ExecutionRunContent | Should -Match '\$Script:ExecutionCurrentStepIndex -gt \[int\]\$Script:RunState\[''CompletedCount''\]'
        $script:ExecutionRunContent | Should -Not -Match '\$currentAction = if \(-not \[string\]::IsNullOrWhiteSpace\(\$Script:RunState\[''CurrentTweak''\]\)\)'
    }

    It 'prevents delayed progress updates from moving the header backwards' {
        $script:ExecutionContent | Should -Match '\$Script:ExecutionLastProgressCompleted = -1'
        $script:StyledControlsContent | Should -Match '\$Completed -lt \[int\]\$Script:ExecutionLastProgressCompleted'
        $script:StyledControlsContent | Should -Match 'return'
        $script:StyledControlsContent | Should -Match '\$Script:ExecutionLastProgressCompleted = \$Completed'
    }

    It 'refreshes the installed-app cache after app actions finish' {
        $script:ExecutionContent | Should -Match '\$(?:Action|runAction|runCatchAction) -in @\(''Install'', ''Uninstall'', ''Update'', ''UpdateAll''\)'
        $script:ExecutionContent | Should -Match 'Start-AppsCacheRefresh'
    }

    It 'wires the execution idle watchdog into both app and tweak run loops' {
        $script:ExecutionContent | Should -Match 'function Update-ExecutionActivityHeartbeat'
        $script:ExecutionContent | Should -Match 'function Test-ExecutionIdleWatchdogExpired'
        $script:ExecutionContent | Should -Match 'function Invoke-ExecutionIdleWatchdogPrompt'
        $script:ExecutionContent | Should -Match 'Baseline has not reported progress for 10 minutes\.'
        $script:ExecutionContent | Should -Match "Buttons @\('Continue Waiting', 'Abort Run'\)"
        $script:ExecutionContent | Should -Match 'Invoke-ExecutionIdleWatchdogPrompt -RunState \$Script:RunState'
        $script:ExecutionContent | Should -Match 'IdleWatchdogSeconds = 600'
        $script:ExecutionContent | Should -Match 'IdleWatchdogPromptOpen = \$false'
        $script:ExecutionContent | Should -Match 'LastActivityAt   = \(Get-Date\)'
    }

    It 'uses structured per-app queue events and keeps the app execution abort button visible' {
        $script:ExecutionContent | Should -Match 'Enter-ExecutionView -Title \$executionTitle -ShowAbortButton:\$true'
        $script:ExecutionContent | Should -Match "'_AppStarted'"
        $script:ExecutionContent | Should -Match "'_AppCompleted'"
        $script:ExecutionContent | Should -Match 'AppUseStructuredProgress = \$false'
        $script:ExecutionContent | Should -Match 'Abort requested - stopping the current app operation now\.'
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
        $script:ExecutionContent | Should -Match "ExecutionOrchestration\.RemoteRunCleanup\.RemoveTempProfilePath"
        $script:ExecutionContent | Should -Match "ExecutionOrchestration\.RemoteRunCleanup\.RemoveTempProfileDir"
    }

    It 'routes run-loop log failures through Write-SwallowedException' {
        $script:ExecutionContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ExecutionOrchestration\.RunLoop\.FatalAppError\.LogError'''
        $script:ExecutionContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ExecutionOrchestration\.RunLoop\.FatalAppDiagnostic\.LogError'''
        $script:ExecutionContent | Should -Match 'Interactive selection request failed: \{0\}'
        $script:ExecutionContent | Should -Match 'ExecutionOrchestration\.InteractiveSelectionRequest\.LogError'
    }

    It 'blocks apply/defaults runs when the host-taint assessment is blocked' {
        $script:ExecutionRunContent | Should -Match '\$Global:BaselineHostTaint'
        $script:ExecutionRunContent | Should -Match '\[string\]\$Global:BaselineHostTaint\.Level -eq ''Blocked'''
        $script:ExecutionRunContent | Should -Match 'GuiHostTaintRunBlocked'
        $script:ExecutionRunContent | Should -Match 'LogError \$hostTaintMessage'
        $script:ExecutionRunContent | Should -Match 'Set-GuiStatusText -Text \$hostTaintMessage -Tone ''caution'''
        $script:ExecutionRunContent | Should -Match "Show-ThemedDialog -Title .*GuiHostTaintRunBlockedTitle"
    }
}

Describe 'GUI apply pipeline busy-state cleanup (winutil #4376 / PR #4404)' {
    # Background: winutil's `Invoke-WinUtilAutoRun` had multiple early-return
    # branches that forgot to clear `$sync.ProcessRunning = $false`, leaving
    # the GUI permanently spinning on "Applying tweaks". Baseline's equivalent
    # is the `RunInProgress` flag on `$Script:GuiState` plus the disabled
    # `PrimaryTabs` / `BtnRun` / `BtnPreviewRun` / `BtnDefaults` /
    # `Set-GuiActionButtonsEnabled` / `ChkScan` / `ChkTheme` / search controls.
    # These tests pin that EVERY exit path out of the apply pipeline restores
    # all of them, so a thrown pump-tick body or a failed timer construction
    # never traps the GUI in busy state.

    It 'pump-tick outer catch clears RunInProgress and re-enables every disabled control' {
        # Locate the outer catch on the tweaks pump-tick (the one that follows
        # the second `finally { Clear-LogMode }` block, which is unique to the
        # tweaks-execution pump-tick body — the apps pump-tick does not have it).
        $clearLogModeIndex = $script:ExecutionContent.IndexOf('Clear-LogMode')
        $clearLogModeIndex | Should -BeGreaterThan 0
        $outerCatchSlice = $script:ExecutionContent.Substring($clearLogModeIndex)
        # The next `catch` after Clear-LogMode is the outer pump-tick catch.
        $outerCatchSlice | Should -Match 'GuiLogExecutionOuterCatch'
        # Cleanup contract — every line below must be present in the catch slice
        # before the next `function` keyword (i.e. before we leave Start-GuiExecutionRun).
        $functionBoundary = $outerCatchSlice.IndexOf("`tfunction Get-ActiveTweakRunList")
        if ($functionBoundary -lt 0) { $functionBoundary = $outerCatchSlice.Length }
        $catchBody = $outerCatchSlice.Substring(0, $functionBoundary)
        $catchBody | Should -Match "& \`$Script:GuiState\.Set 'RunInProgress' \`$false"
        $catchBody | Should -Match "\`$PrimaryTabs\.IsEnabled = \`$true"
        $catchBody | Should -Match "\`$BtnRun\.IsEnabled = \`$true"
        $catchBody | Should -Match "\`$BtnPreviewRun\.IsEnabled = \`$true"
        $catchBody | Should -Match "\`$BtnDefaults\.IsEnabled = \`$true"
        $catchBody | Should -Match 'Set-GuiActionButtonsEnabled -Enabled \$true'
        $catchBody | Should -Match "\`$ChkScan\.IsEnabled = \`$true"
        $catchBody | Should -Match "\`$ChkTheme\.IsEnabled = \`$true"
        $catchBody | Should -Match 'Set-SearchControlsEnabled -Enabled \$true'
    }

    It 'synchronous timer-start is wrapped so a throw before first tick still clears RunInProgress' {
        # The Tweaks apply pipeline's `& $executionPumpTickFn` is the synchronous
        # first invocation. It MUST be inside a try/catch that matches the cleanup
        # contract — otherwise a throw in `New-Object DispatcherTimer` or the
        # first pump-tick invocation traps the GUI in busy state with no recovery.
        $script:ExecutionContent | Should -Match 'GuiLogExecutionTimerStartFailed'
        # The localization key only exists on the Tweaks-side timer wrapper, so
        # this assertion both confirms presence and uniqueness.
        ([regex]::Matches($script:ExecutionContent, 'GuiLogExecutionTimerStartFailed')).Count | Should -Be 1
    }

    It 'forbids leading Start-Sleep on any wait loop (winutil #4404 5-second hang)' {
        # winutil's busy-wait loop slept BEFORE checking ProcessRunning, so the
        # "nothing to do" case took 5+ seconds to no-op. Apply pipeline must not
        # introduce any Start-Sleep — DispatcherTimer is the cooperative pump.
        $script:ExecutionContent | Should -Not -Match 'Start-Sleep'
    }

    It 'forbids modal MessageBox dialogs on the apply path (winutil #4404 unattended trap)' {
        # winutil's Invoke-WPFInstall popped a MessageBox.Show on empty selection
        # which permanently hung unattended runs. Apply path must use Show-ThemedDialog
        # (which the headless host can stub) or LogWarning, never MessageBox::Show.
        $script:ExecutionContent | Should -Not -Match '\[System\.Windows\.MessageBox\]::Show'
        $script:ExecutionContent | Should -Not -Match '\[System\.Windows\.Forms\.MessageBox\]::Show'
    }
}

Describe 'GUI run completion exit code' {
    It 'pins $Global:LASTEXITCODE through Get-BaselineHeadlessExitCode at run completion' {
        $script:ExecutionContent | Should -Match "Get-Command -Name 'Get-BaselineHeadlessExitCode'"
        $script:ExecutionContent | Should -Match '\$Global:LASTEXITCODE\s*=\s*\[int\]\$guiExit\.ExitCode'
        $script:ExecutionContent | Should -Match 'GUI run finished: exitCode='
    }

    It 'classifies aborted runs with no failures and unstarted remainder as partial' {
        # When the user aborts mid-run, the completed-count gap must NOT be
        # silently rolled into 0 / clean.
        $script:ExecutionContent | Should -Match 'if \(\$abortedRun -and \$guiFailed -eq 0 -and \$guiSucceeded -lt \$guiTotal\)'
        $script:ExecutionContent | Should -Match '\$guiFailed = \$guiTotal - \$guiSucceeded'
    }

    It 'computes the exit code AFTER the audit record is written' {
        $auditIndex = $script:ExecutionContent.IndexOf('Write-AuditRecord @auditParams')
        $exitCodePinIndex = $script:ExecutionContent.IndexOf('$Global:LASTEXITCODE = [int]$guiExit.ExitCode')
        $completeIndex = $script:ExecutionContent.IndexOf('Complete-GuiExecutionRun -Mode $Script:ExecutionMode')

        $auditIndex | Should -BeGreaterThan 0
        $exitCodePinIndex | Should -BeGreaterThan $auditIndex
        $completeIndex | Should -BeGreaterThan $exitCodePinIndex
    }

    It 'guards the helper lookup so a missing Get-BaselineHeadlessExitCode never breaks the GUI completion path' {
        # ErrorAction SilentlyContinue + outer try/catch routed through
        # Write-SwallowedException — completion must keep going even if
        # the helper module is unloaded mid-session.
        $script:ExecutionContent | Should -Match "Get-Command -Name 'Get-BaselineHeadlessExitCode' -CommandType Function -ErrorAction SilentlyContinue"
        $script:ExecutionContent | Should -Match "Source 'ExecutionOrchestration\.RunCompletion\.ExitCode'"
    }

    It 'routes the Apps & features health check through the run-completion path' {
        $script:ExecutionContent | Should -Match "Get-Command -Name 'Resolve-BaselineSettingsAppsFeaturesHealthAssessment' -CommandType Function -ErrorAction SilentlyContinue"
        $script:ExecutionContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ExecutionOrchestration\.RunCompletion\.SettingsAppsFeaturesHealthAssessment'''
        $script:ExecutionContent | Should -Match 'Selected tweaks have finished running, but the Settings appsfeatures health check needs attention\.'
    }

    It 'routes the ScreenSketch regression probe through the run-completion path' {
        $script:ExecutionContent | Should -Match "Get-Command -Name 'Resolve-BaselineScreenSnippingHealthAssessment' -CommandType Function -ErrorAction SilentlyContinue"
        $script:ExecutionContent | Should -Match 'Write-SwallowedException -ErrorRecord \$_ -Source ''ExecutionOrchestration\.RunCompletion\.ScreenSnippingHealthAssessment'''
        $script:ExecutionContent | Should -Match 'Set-ExecutionSummaryStatus -Key ''PrtScnSnippingTool'' -Status ''Failed'' -Detail \(\[string\]\$screenSnippingHealthAssessment\.Message\)'
    }

    It 'emits run-completion toasts through the shared Baseline toast helper' {
        $script:ExecutionContent | Should -Match "function Invoke-GuiExecutionCompletionToast"
        $script:ExecutionContent | Should -Match 'if \(\$Mode -ne ''Run''\)'
        $script:ExecutionContent | Should -Match 'Get-Command -Name ''Test-BaselineToastRuntimeAvailable'' -CommandType Function -ErrorAction SilentlyContinue'
        $script:ExecutionContent | Should -Match 'Show-BaselineToast -Title \$Title -Body \$Body -AppId ''Baseline'' -Duration ''Short'''
        $script:ExecutionContent | Should -Match 'Invoke-GuiExecutionCompletionToast -Mode \$Mode -Title \$dlgTitle -Body \$summaryCountsText'
        $script:ExecutionContent | Should -Match "ExecutionOrchestration\.RunCompletion\.Toast"
    }

    It 'returns to the restored GUI when the local run summary closes' {
        $script:ExecutionRunContent | Should -Match 'if \(\$nextStep -eq ''Close''\)\s*\{\s*Exit-ExecutionView\s*\}\s*else\s*\{\s*Close-GuiMainWindow -Reason ''Execution summary exit requested\.'''
        $script:ExecutionRunContent | Should -Not -Match 'if \(\$nextStep -eq ''Close''\)\s*\{[\s\S]*?Invoke-GuiSystemScan'
    }
}

Describe 'PlatformSupport availability partition (P2 #18)' {
    # Entries flagged unavailable by Update-BaselineManifestAvailability must
    # be marked "Not applicable" in the run summary and filtered out of the
    # execution list, so the per-preset report surfaces the count of skipped
    # entries instead of silently dropping them.

    It 'partitions the local apply path immediately after Initialize-ExecutionSummary' {
        $initIndex = $script:ExecutionContent.IndexOf('Initialize-ExecutionSummary -SelectedTweaks $tweakList')
        $partitionIndex = $script:ExecutionContent.IndexOf('Resolve-GuiExecutionRunnableTweaks -TweakList $tweakList -ForceUnsupported:$ForceUnsupported')
        $initIndex | Should -BeGreaterThan 0
        $partitionIndex | Should -BeGreaterThan $initIndex
    }

    It 'marks unavailable entries Not applicable via Set-ExecutionSummaryStatus' {
        $script:ExecutionContent | Should -Match "Set-ExecutionSummaryStatus -Key \(\[string\]\`$tweak\.Key\) -Status 'Not applicable' -Detail \`$detailText"
    }

    It 'filters unavailable entries out of the runnable tweak list' {
        $script:ExecutionContent | Should -Match 'return @\(\$availableTweaks\.ToArray\(\)\)'
        $script:ExecutionContent | Should -Match '\$tweakList = @\(Resolve-GuiExecutionRunnableTweaks -TweakList \$tweakList -ForceUnsupported:\$ForceUnsupported\)'
    }

    It 'reads availability metadata via the IDictionary and PSObject paths' {
        $script:GuiExecutionContent | Should -Match '\$availability\.Contains\(''Available''\)'
        $script:GuiExecutionContent | Should -Match '\$availability\.PSObject\.Properties\[''Available''\]'
    }

    It 'keeps Start-GuiExecutionRun inside the staged refactor size budget' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ExecutionRunPath, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0

        $functionAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq 'Start-GuiExecutionRun'
        }, $true) | Select-Object -First 1

        $functionAst | Should -Not -BeNullOrEmpty
        ($functionAst.Extent.EndLineNumber - $functionAst.Extent.StartLineNumber + 1) | Should -BeLessOrEqual 400
    }
}
