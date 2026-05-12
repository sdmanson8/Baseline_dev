# P5 rollback checkpoint: extracted from SharedPrinterConnectionErrors in Module\Regions\SystemTweaks\SystemTweaks.SMBRepair.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
try
	{
		& ipconfig /flushdns | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "ipconfig returned exit code $LASTEXITCODE while flushing DNS"
		}
		LogInfo "DNS cache flushed"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "ipconfig /flushdns failed: $($_.Exception.Message)"
	}

	try
	{
		& nbtstat -R | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "nbtstat returned exit code $LASTEXITCODE while purging the NetBIOS cache"
		}
		LogInfo "NetBIOS cache purged (nbtstat -R)"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "nbtstat -R failed: $($_.Exception.Message)"
	}

	try
	{
		& nbtstat -RR | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "nbtstat returned exit code $LASTEXITCODE while re-registering NetBIOS names"
		}
		LogInfo "NetBIOS names re-registered (nbtstat -RR)"
	}
	catch
	{
		$hadIssue = $true
		LogWarning "nbtstat -RR failed: $($_.Exception.Message)"
	}

	try
	{
		$nicConfigs = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue
		if ($nicConfigs)
		{
			foreach ($nic in $nicConfigs)
			{
				$result = Invoke-CimMethod -InputObject $nic -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 1 } -ErrorAction SilentlyContinue
				if ($result.ReturnValue -eq 0)
				{
					LogInfo "NetBIOS enabled on adapter: $($nic.Description)"
				}
				else
				{
					$hadIssue = $true
					LogWarning "NetBIOS set returned $($result.ReturnValue) on: $($nic.Description)"
				}
			}
		}
		elseif (Get-Command wmic -ErrorAction SilentlyContinue)
		{
			& wmic nicconfig where "(IPEnabled=TRUE)" call SetTcpipNetbios 1 | Out-Null
			if ($LASTEXITCODE -ne 0)
			{
				throw "wmic returned exit code $LASTEXITCODE while enabling NetBIOS"
			}
			LogInfo "NetBIOS over TCP/IP enabled via wmic"
		}
		else
		{
			LogInfo "NetBIOS enable skipped because the WMI and wmic paths were unavailable"
		}
	}
	catch
	{
		$hadIssue = $true
		LogWarning "NetBIOS enable failed: $($_.Exception.Message)"
	}
