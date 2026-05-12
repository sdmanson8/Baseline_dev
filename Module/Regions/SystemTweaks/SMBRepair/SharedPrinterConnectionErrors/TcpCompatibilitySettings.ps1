# P5 rollback checkpoint: extracted from SharedPrinterConnectionErrors in Module\Regions\SystemTweaks\SystemTweaks.SMBRepair.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
try
	{
		& netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "netsh returned exit code $LASTEXITCODE while setting autotuninglevel"
		}
		LogInfo "TCP autotuninglevel = normal"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "netsh tcp autotuninglevel failed: $($_.Exception.Message)"
	}

	try
	{
		& netsh int tcp set global rss=enabled 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "netsh returned exit code $LASTEXITCODE while setting RSS"
		}
		LogInfo "TCP RSS = enabled"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "netsh tcp rss failed: $($_.Exception.Message)"
	}

	try
	{
		& netsh int tcp set global chimney=enabled 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "netsh returned exit code $LASTEXITCODE while setting chimney"
		}
		LogInfo "TCP chimney = enabled"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "netsh tcp chimney failed (not supported on all hardware): $($_.Exception.Message)"
	}
