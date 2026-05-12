# P5 rollback checkpoint: extracted from WindowsCapabilities in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
try
	{
		$Capabilities = Get-WindowsCapability -Online -ErrorAction Stop |
			Where-Object -FilterScript {
				$CapabilityName = $_.Name
				($_.State -eq $State) -and
				(
					(Test-CapabilityPatternMatch -CapabilityName $CapabilityName -Patterns $UncheckedCapabilities) -or
					(Test-CapabilityPatternMatch -CapabilityName $CapabilityName -Patterns $CheckedCapabilities)
				) -and
				-not (Test-CapabilityPatternMatch -CapabilityName $CapabilityName -Patterns $ExcludedCapabilities)
			} |
			Sort-Object -Property DisplayName, Name
	}
	catch
	{
		Remove-HandledErrorRecord -ErrorRecord $_
		$Capabilities = $null
	}
