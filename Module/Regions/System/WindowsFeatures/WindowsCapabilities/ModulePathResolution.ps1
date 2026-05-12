# P5 rollback checkpoint: extracted from WindowsCapabilities in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$modulePath = if (-not [string]::IsNullOrWhiteSpace([string]$PSCommandPath))
	{
		[string]$PSCommandPath
	}
	elseif ($MyInvocation.MyCommand.Module -and -not [string]::IsNullOrWhiteSpace([string]$MyInvocation.MyCommand.Module.Path))
	{
		[string]$MyInvocation.MyCommand.Module.Path
	}
	else
	{
		$null
	}
