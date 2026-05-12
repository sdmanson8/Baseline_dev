# P5 rollback checkpoint: extracted from InitialActions in Module\Regions\InitialActions.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($osInfo.IsWindowsServer)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_FeatureExperiencePackNotApplicable' -Fallback 'Windows Feature Experience Pack check is not applicable on Windows Server.')
	}
	else
	{
		$featurePackPresent = Test-BaselineAppxPackagePresence -Name 'MicrosoftWindows.Client.CBS'
		if ($featurePackPresent -eq $false)
		{
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Windows Feature Experience Pack'))
		}
	}
