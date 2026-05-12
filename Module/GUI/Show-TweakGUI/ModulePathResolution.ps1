# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		Write-Warning "GUI module base path could not be resolved - preset directory will not be available"
	}
	elseif ((Split-Path -Path $Script:GuiModuleBasePath -Leaf) -ieq 'Regions')
	{
		$normalizedGuiModuleBasePath = Split-Path -Path $Script:GuiModuleBasePath -Parent
		if (-not [string]::IsNullOrWhiteSpace([string]$normalizedGuiModuleBasePath))
		{
			$Script:GuiModuleBasePath = $normalizedGuiModuleBasePath
		}
	}
