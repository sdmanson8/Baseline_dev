# P5 rollback checkpoint: extracted from Set-BootstrapLoadingSplashStep in Module\SharedHelpers\Environment.Helpers.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($Splash -is [hashtable])
	{
		if ($Status -eq 'in_progress')
		{
			$Splash['ChecklistProgressActive'] = $true
		}
		elseif ($StepId -eq 'finalize' -and $Status -eq 'completed')
		{
			$Splash['ChecklistProgressActive'] = $false
			$Splash['CompletionAnimationDeadlineUtc'] = [datetime]::UtcNow.AddMilliseconds(360)
		}
	}
