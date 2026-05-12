# P5 rollback checkpoint: extracted from InitialActions in Module\Regions\InitialActions.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$Files = if ($osInfo.IsWindowsServer)
	{
		@(
			"$env:SystemRoot\System32\smartscreen.exe",
			"$env:SystemRoot\System32\CompatTelRunner.exe"
		)
	}
	else
	{
		@(
			"$env:SystemRoot\System32\smartscreen.exe",
			"$env:SystemRoot\System32\SecurityHealthSystray.exe",
			"$env:SystemRoot\System32\CompatTelRunner.exe"
		)
	}
