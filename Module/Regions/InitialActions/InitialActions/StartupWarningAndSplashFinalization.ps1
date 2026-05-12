# P5 rollback checkpoint: extracted from InitialActions in Module\Regions\InitialActions.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($Warning)
	{
		# Get the name of a preset (e.g Bootstrap/Baseline.ps1) regardless if it was named
		# $_.File has no EndsWith() method
		[string]$PresetName = ((Get-PSCallStack).Position | Where-Object -FilterScript {$_.File}).File | Where-Object -FilterScript {$_.EndsWith(".ps1")}
		LogWarning (Get-BaselineBilingualString -Key 'CustomizationWarning' -Fallback 'Have you customized every function in the {0} preset file before running Baseline | Windows Utility?' -FormatArgs @("`"$PresetName`""))
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ShowingMainMenuWaitingForInput' -Fallback 'Showing Main Menu, waiting for input')

		do
		{
			$Choice = Show-Menu -Menu @($Script:Yes, $Script:No) -Default 2

			switch ($Choice)
			{
				$Script:Yes
				{
					continue
				}
				$Script:No
				{
					Invoke-Item -Path $PresetName
					Start-Sleep -Seconds 5
				}
				$Script:KeyboardArrows {}
			}
		}
		until ($Choice -ne $Script:KeyboardArrows)
	}

	if ($Global:GUIMode -and $Global:LoadingSplash -and $Global:LoadingSplash.IsAlive)
	{
		try
		{
			if (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Set-BootstrapLoadingSplashStep -Splash $Global:LoadingSplash -StepId 'system' -Status 'in_progress' -SubAction ''
			}
			if (Get-Command -Name 'Initialize-PackageManagersBootstrap' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Initialize-PackageManagersBootstrap -LoadingSplash $Global:LoadingSplash
			}
		}
		catch
		{
			LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_PackageManagerStartupBootstrapFailedUnexpectedly' -Fallback 'Package manager startup bootstrap failed unexpectedly: {0}' -FormatArgs @($_.Exception.Message))
		}
	}

	if ($Global:LoadingSplash -and $Global:LoadingSplash.IsAlive)
	{
		try
		{
			if (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Set-BootstrapLoadingSplashStep -Splash $Global:LoadingSplash -StepId 'finalize' -Status 'in_progress' -SubAction ''
			}
			# The launcher closes the splash immediately after InitialActions
			# returns, once startup checks are done and before the GUI builds.
		}
		catch { Write-SwallowedException -ErrorRecord $_ -Source 'InitialActions.SplashFinalize.SetStep' }
	}
