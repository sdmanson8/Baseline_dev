# P5 rollback checkpoint: extracted from Complete-GuiExecutionRun in Module\GUI\ExecutionOrchestration\ExecutionRunOrchestration.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($AbortedRun)
		{
			$resumeCandidates = @(Get-ExecutionResumeCandidateList -Results $executionSummary)
			if ($resumeCandidates.Count -gt 0)
			{
				$null = Save-GuiInterruptedRunProfile -ResumeCandidates $resumeCandidates -Mode $Mode -Reason 'Interrupted run'
			}
			else
			{
				$null = Clear-GuiInterruptedRunProfile
			}
		}
		else
		{
			$null = Clear-GuiInterruptedRunProfile
		}
