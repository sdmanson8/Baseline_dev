# P5 rollback checkpoint: extracted from WindowsCapabilities in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
function Get-CapabilityFriendlyName
	{
		param ([string]$Name, [string]$DisplayName)

		if (-not [string]::IsNullOrWhiteSpace($DisplayName))
		{
			return $DisplayName
		}

		# Strip version suffix (e.g. ~~~~0.0.1.0) and match against friendly names
		$baseName = ($Name -replace '~.*$', '').TrimEnd('~')
		foreach ($pattern in $CapabilityFriendlyNames.Keys)
		{
			if ($baseName -like "$pattern*")
			{
				return $CapabilityFriendlyNames[$pattern]
			}
		}

		# Last resort: strip the version suffix and return as-is
		return $baseName
	}
