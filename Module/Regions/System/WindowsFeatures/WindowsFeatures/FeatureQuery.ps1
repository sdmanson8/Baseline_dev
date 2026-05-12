# P5 rollback checkpoint: extracted from WindowsFeatures in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
try
	{
		$Features = Get-WindowsOptionalFeature -Online -ErrorAction Stop |
			Where-Object -FilterScript {
				($_.State -in $State) -and
				(
					(Test-FeaturePatternMatch -FeatureName $_.FeatureName -Patterns $UncheckedFeatures) -or
					(Test-FeaturePatternMatch -FeatureName $_.FeatureName -Patterns $CheckedFeatures)
				)
			} |
			Sort-Object -Property DisplayName, FeatureName
	}
	catch
	{
		Remove-HandledErrorRecord -ErrorRecord $_
		$Features = $null
	}
