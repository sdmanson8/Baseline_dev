# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
try
	{
		if ($hasLiveStartupSplash)
		{
			$Form.ShowInTaskbar = $false
			$Form.Opacity = 0
		}
		else
		{
			$Form.ShowInTaskbar = $true
			$Form.Opacity = 1
		}
	}
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'Regions.GUI.StartupVisibility.Apply'
	}
