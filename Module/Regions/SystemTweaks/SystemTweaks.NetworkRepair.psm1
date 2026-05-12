using module ..\..\Logging.psm1
using module ..\..\SharedHelpers.psm1

<#
	.SYNOPSIS
	Reset the Windows network stack on explicit user request.

	.DESCRIPTION
	Runs the standard network stack reset sequence with visible status and
	exit-code enforcement. This is an explicit repair action, not a background
	fallback.

	.EXAMPLE
	NetworkStackReset
#>
function NetworkStackReset
{
	[CmdletBinding()]
	param()

	$netshPath = Join-Path $env:SystemRoot 'System32\netsh.exe'
	$steps = @(
		@{
			Label = 'Resetting Winsock catalog'
			Arguments = @('winsock', 'reset')
		},
		@{
			Label = 'Resetting WinHTTP proxy'
			Arguments = @('winhttp', 'reset', 'proxy')
		},
		@{
			Label = 'Resetting TCP/IP stack'
			Arguments = @('int', 'ip', 'reset')
		}
	)

	Write-ConsoleStatus -Action 'Resetting Windows network stack'
	LogInfo 'Resetting Windows network stack'

	try
	{
		foreach ($step in $steps)
		{
			LogInfo ([string]$step.Label)
			$null = Invoke-BaselineProcess -FilePath $netshPath -ArgumentList @($step.Arguments) -TimeoutSeconds 300 -AllowedExitCodes @(0)
		}

		LogWarning 'Restart required to complete the network stack reset.'
		Write-ConsoleStatus -Status success
	}
	catch
	{
		LogError "Network stack reset failed: $($_.Exception.Message)"
		Write-ConsoleStatus -Status failed
	}
}

$ExportedFunctions = @(
	'NetworkStackReset'
)
Export-ModuleMember -Function $ExportedFunctions
