using module ..\Logging.psm1
using module ..\SharedHelpers.psm1

#region UWP apps

<#
.SYNOPSIS
Enable or disable Background Apps



.DESCRIPTION

Enables or disables Background Apps in GUI and headless runs.
.PARAMETER Enable
Enable Background Apps (default value)

.PARAMETER Disable
Disable Background Apps

.EXAMPLE
BackgroundApps -Enable

.EXAMPLE
BackgroundApps -Disable

.NOTES
Current user
#>
function BackgroundApps
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Enable")]
		[switch]$Enable,

		[Parameter(Mandatory = $true, ParameterSetName = "Disable")]
		[switch]$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Background Apps"
			LogInfo "Enabling Background Apps"
			try
			{
				Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 0 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable Background Apps: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Background Apps"
			LogInfo "Disabling Background Apps"
			try
			{
				Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Type DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable Background Apps: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Install or uninstall Microsoft Copilot and related Windows AI components.

	.DESCRIPTION
	Calls the AIRemoval helper script to either restore or remove the
	Windows AI components associated with Copilot, then installs or removes the
	store Copilot app itself.

	.PARAMETER Install
	Install Microsoft Copilot and restore the AI components used by it.

	.PARAMETER Uninstall
	Uninstall Microsoft Copilot and remove the AI components used by it.

	.EXAMPLE
	Copilot -Install

	.EXAMPLE
	Copilot -Uninstall

	.NOTES
	Current user

	.NOTES
	Machine-wide
#>

function Copilot
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Install"
		)]
		[switch]
		$Install,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Uninstall"
		)]
		[switch]
		$Uninstall
	)

	$osInfo = Get-OSInfo
	switch ($PSCmdlet.ParameterSetName)
	{
		"Install"
		{
			Write-ConsoleStatus -Action "Installing Microsoft Copilot app"
			LogInfo "Installing Microsoft Copilot app and restoring related Windows AI components"
			if ($osInfo.IsWindowsServer)
			{
				LogWarning "Skipping Microsoft Copilot install because this Windows AI package flow is not applicable on Windows Server."
				Write-ConsoleStatus -Status warning
				return
			}

			try
			{
				# Store the log path in the environment for the helper process.
				[Environment]::SetEnvironmentVariable("AIREMOVAL_LOG", $global:LogFilePath, "Process")
				$global:LASTEXITCODE = 0
				& "$PSScriptRoot\UWPApps\AIRemoval.ps1" -nonInteractive -revertMode -AllOptions
				if (-not $?)
				{
					throw "AIRemoval restore mode did not complete successfully."
				}
				if ($LASTEXITCODE -ne 0)
				{
					throw "AIRemoval restore mode returned exit code $LASTEXITCODE."
				}

				Start-Sleep -Seconds 2
				$WingetCommand = Get-Command winget -ErrorAction SilentlyContinue
				if (-not $WingetCommand)
				{
					throw "winget is required to install the Copilot Store app, but it is not available on this system."
				}

				$WingetProcess = Start-Process -FilePath $WingetCommand.Source -ArgumentList "install -s msstore -e --silent --accept-source-agreements --accept-package-agreements --id 9NHT9RB2F4HD" -Wait -PassThru -ErrorAction Stop
				if ($WingetProcess.ExitCode -ne 0)
				{
					throw "winget failed to install Microsoft Copilot with exit code $($WingetProcess.ExitCode)."
				}

				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to install Microsoft Copilot and related Windows AI components: $($_.Exception.Message)"
				throw
			}
		}
		"Uninstall"
		{
			Write-ConsoleStatus -Action "Uninstalling Microsoft Copilot app"
			LogInfo "Uninstalling Microsoft Copilot app and related Windows AI components"
			if ($osInfo.IsWindowsServer)
			{
				LogWarning "Skipping Microsoft Copilot uninstall because this Windows AI package flow is not applicable on Windows Server."
				Write-ConsoleStatus -Status warning
				return
			}

			try
			{
				# Store the log path in the environment for the helper process.
				[Environment]::SetEnvironmentVariable("AIREMOVAL_LOG", $global:LogFilePath, "Process")
				$global:LASTEXITCODE = 0
				& "$PSScriptRoot\UWPApps\AIRemoval.ps1" -nonInteractive -AllOptions
				if (-not $?)
				{
					throw "AIRemoval removal mode did not complete successfully."
				}
				if ($LASTEXITCODE -ne 0)
				{
					throw "AIRemoval removal mode returned exit code $LASTEXITCODE."
				}

				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to uninstall Microsoft Copilot and related Windows AI components: $($_.Exception.Message)"
				throw
			}
		}
	}
}

<#
	.SYNOPSIS
	Cortana autostarting


	
.DESCRIPTION
	
Applies the Baseline behavior for cortana autostarting.
	.PARAMETER Disable
	Disable Cortana autostarting

	.PARAMETER Enable
	Enable Cortana autostarting

	.EXAMPLE
	CortanaAutostart -Disable

	.EXAMPLE
	CortanaAutostart -Enable

	.NOTES
	Current user
#>
function CortanaAutostart
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable
	)

	if (-not (Get-AppxPackage -Name Microsoft.549981C3F5F10 -WarningAction SilentlyContinue))
	{
		LogWarning ($Localization.Skipped -f (Get-TweakSkipLabel $MyInvocation))
		return
	}

	try
	{
		if (-not (Test-Path -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId"))
		{
			New-Item -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Force -ErrorAction Stop | Out-Null
		}
	}
	catch
	{
		$actionText = if ($PSCmdlet.ParameterSetName -eq "Disable") { "Disabling Cortana autostarting" } else { "Enabling Cortana autostarting" }
		Write-ConsoleStatus -Action $actionText
		Write-ConsoleStatus -Status failed
		LogError "Failed to create Cortana startup registry key: $($_.Exception.Message)"
		return
	}

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Cortana autostarting"
			LogInfo "Disabling Cortana autostarting"
			try
			{
				New-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Name State -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable Cortana autostarting: $($_.Exception.Message)"
			}
		}
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Cortana autostarting"
			LogInfo "Enabling Cortana autostarting"
			try
			{
				New-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -Name State -PropertyType DWord -Value 2 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable Cortana autostarting: $($_.Exception.Message)"
			}
		}
	}
}

<#
    .SYNOPSIS
    Enable or disable the Baseline Edge debloat policy set.

    .DESCRIPTION
    Applies or removes the Edge and EdgeUpdate policy values Baseline uses to suppress consumer features, first-run prompts, and bundled extras.

    .PARAMETER Enable
    Apply the Baseline Edge debloat policy set.

    .PARAMETER Disable
    Remove the Baseline Edge debloat policy set.

    .EXAMPLE
    EdgeDebloat -Enable
#>
function EdgeDebloat
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Enable")]
		[switch]$Enable,

		[Parameter(Mandatory = $true, ParameterSetName = "Disable")]
		[switch]$Disable
	)

	$EdgePath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
	$EdgeUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
	$EdgeBlocklistPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist"

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Edge Debloat"
			LogInfo "Enabling Edge Debloat"
			
			# Create paths if they don't exist
			if (-not (Test-Path $EdgeUpdatePath))
			{
				New-Item -Path $EdgeUpdatePath -Force -ErrorAction SilentlyContinue | Out-Null
			}
			if (-not (Test-Path $EdgePath))
			{
				New-Item -Path $EdgePath -Force -ErrorAction SilentlyContinue | Out-Null
			}
			if (-not (Test-Path $EdgeBlocklistPath))
			{
				New-Item -Path $EdgeBlocklistPath -Force -ErrorAction SilentlyContinue | Out-Null
			}
			
			Set-ItemProperty -LiteralPath $EdgeUpdatePath -Name "CreateDesktopShortcutDefault" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "PersonalizationReportingEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgeBlocklistPath -Name "1" -Type String -Value "ofefcgjbeghpigppfmkologfjadafddi" -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "ShowRecommendationsEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "HideFirstRunExperience" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "DefaultBrowserSettingsCampaignEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "UserFeedbackAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "ConfigureDoNotTrack" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "AlternateErrorPagesEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "EdgeCollectionsEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "EdgeShoppingAssistantEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "MicrosoftEdgeInsiderPromotionEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "ShowMicrosoftRewards" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "WebWidgetAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "DiagnosticData" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "EdgeAssetDeliveryServiceEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath $EdgePath -Name "WalletDonationEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			
			LogInfo "Edge debloat policies applied"
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Edge Debloat"
			LogInfo "Disabling Edge Debloat"
			
			Remove-ItemProperty -Path $EdgeUpdatePath -Name "CreateDesktopShortcutDefault" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "PersonalizationReportingEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgeBlocklistPath -Name "1" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "ShowRecommendationsEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "HideFirstRunExperience" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "DefaultBrowserSettingsCampaignEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "UserFeedbackAllowed" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "ConfigureDoNotTrack" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "AlternateErrorPagesEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "EdgeCollectionsEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "EdgeShoppingAssistantEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "MicrosoftEdgeInsiderPromotionEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "ShowMicrosoftRewards" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "WebWidgetAllowed" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "DiagnosticData" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "EdgeAssetDeliveryServiceEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-ItemProperty -Path $EdgePath -Name "WalletDonationEnabled" -Force -ErrorAction SilentlyContinue | Out-Null
			
			LogInfo "Edge debloat policies removed"
			Write-ConsoleStatus -Status success
		}
	}
}

<#
.SYNOPSIS
Remove Microsoft Edge (Legacy and Chromium) while preserving EdgeWebView2.

.DESCRIPTION
Detects and removes Microsoft Edge installations including Legacy UWP Edge,
Chromium-based Edge, and EdgeUpdate components. EdgeWebView2 is intentionally
preserved (required by other apps).

Action-type entry â€” one-way destructive operation. Backs up HKCU UserChoice
ProgId/Hash for .html/.htm/.xml/.pdf so a non-Edge default browser preference
survives the removal. Installs an OpenWebSearch protocol redirect (via
ie_to_edge_stub.exe) and a logon-triggered repair scheduled task so links that
still resolve through MSEdgeHTM are forwarded to the user's actual default
browser.

.PARAMETER Remove
Trigger the one-way Edge removal flow.

.NOTES
Logs at %ProgramData%\Baseline\Logs\EdgeRemovalLog.txt; stub + redirect at
%ProgramData%\Baseline\OpenWebSearch.
#>
function EdgeRemoval
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Remove")]
		[switch]$Remove
	)

	Write-ConsoleStatus -Action "Removing Microsoft Edge"
	LogInfo "Starting Microsoft Edge removal (preserves EdgeWebView2)"

	$logFolder = Join-Path $env:ProgramData 'Baseline\Logs'
	$logFile   = Join-Path $logFolder 'EdgeRemovalLog.txt'
	$scriptsDir = Join-Path $env:ProgramData 'Baseline\OpenWebSearch'

	if (-not (Test-Path $logFolder))
	{
		New-Item -ItemType Directory -Path $logFolder -Force -ErrorAction SilentlyContinue | Out-Null
	}
	<#
	    .SYNOPSIS
	    Write a line to the Edge removal log.

	    .DESCRIPTION
	    Appends a timestamped message to the Edge removal log file and mirrors the same text into the main Baseline log.

	    .PARAMETER Message
	    Text to append to the Edge removal log.

	    .EXAMPLE
	    Write-EdgeRemovalLog -Message 'Stopping Edge-related processes'
	#>
	function Write-EdgeRemovalLog
	{
		param([string]$Message)
		try
		{
			if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 512000)
			{
				Remove-Item $logFile -Force -ErrorAction SilentlyContinue
				$ts0 = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
				"$ts0 - Log rotated - previous log exceeded 500KB" | Out-File -FilePath $logFile
			}
			$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
			"$ts - $Message" | Out-File -FilePath $logFile -Append
		}
		catch
		{
			# Logging must never break removal flow
		}
		LogInfo $Message
	}
	<#
	    .SYNOPSIS
	    Return the CBS package names for legacy Edge.

	    .DESCRIPTION
	    Reads the Component Based Servicing package list and returns the package names that identify the legacy UWP Edge payload.

	    .EXAMPLE
	    Get-LegacyEdgePackages
	#>
	function Get-LegacyEdgePackages
	{
		$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
		return Get-ChildItem -Path $regPath -Name -ErrorAction SilentlyContinue |
			Where-Object { $_ -match 'Microsoft-Windows-Internet-Browser-Package' -and $_ -match '~~' }
	}
	<#
	    .SYNOPSIS
	    Return whether the legacy Edge package is installed.

	    .DESCRIPTION
	    Queries the legacy Edge CBS packages and uses DISM package info to determine whether any package is still installed.

	    .EXAMPLE
	    Test-LegacyEdgeInstalled
	#>
	function Test-LegacyEdgeInstalled
	{
		$packages = Get-LegacyEdgePackages
		if ($packages)
		{
			foreach ($pkg in $packages)
			{
				$info = & dism /online /Get-PackageInfo /PackageName:$pkg 2>$null
				if ($info -match 'State.*Installed') { return $true }
			}
		}
		return $false
	}
	<#
	    .SYNOPSIS
	    Return whether Chromium-based Edge is installed.

	    .DESCRIPTION
	    Checks the standard Edge folders and a store-program probe to decide whether the Chromium Edge build is still present.

	    .EXAMPLE
	    Test-ChromiumEdgeInstalled
	#>
	function Test-ChromiumEdgeInstalled
	{
		$folders = @('Edge', 'EdgeCore', 'EdgeUpdate')
		$programFiles = @($env:ProgramFiles, ${env:ProgramFiles(x86)})
		foreach ($pf in $programFiles)
		{
			foreach ($f in $folders)
			{
				if (Test-Path "$pf\Microsoft\$f") { return $true }
			}
		}
		try
		{
			$app = Get-WmiObject -Class Win32_InstalledStoreProgram -Filter "Name like '%Microsoft.MicrosoftEdge.Stable%'" -ErrorAction SilentlyContinue
			return $app -ne $null
		}
		catch
		{
			return $false
		}
	}
	<#
	    .SYNOPSIS
	    Back up selected UserChoice file associations before Edge removal.

	    .DESCRIPTION
	    Captures ProgId and Hash values for the HTML, HTM, XML, and PDF UserChoice associations so non-Edge defaults can be restored later.

	    .EXAMPLE
	    Backup-UserChoiceAssociations
	#>
	function Backup-UserChoiceAssociations
	{
		Write-EdgeRemovalLog 'Backing up HKCU UserChoice ProgId/Hash for .html/.htm/.xml/.pdf'
		$backup = @{}
		$exts = @('.html', '.htm', '.xml', '.pdf')
		foreach ($ext in $exts)
		{
			$keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
			if (Test-Path $keyPath)
			{
				try
				{
					$props = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
					if ($props -and $props.ProgId)
					{
						$backup[$ext] = @{ ProgId = $props.ProgId; Hash = $props.Hash }
					}
				}
				catch
				{
					# Best-effort backup
				}
			}
		}
		Write-EdgeRemovalLog "Captured UserChoice for $($backup.Count) extension(s)"
		return $backup
	}
	<#
	    .SYNOPSIS
	    Restore saved UserChoice file associations after Edge removal.

	    .DESCRIPTION
	    Replays the saved non-Edge ProgId values for the backed-up UserChoice extensions when a backup payload is available.

	    .PARAMETER Backup
	    Hashtable returned by Backup-UserChoiceAssociations.

	    .EXAMPLE
	    Restore-UserChoiceAssociations -Backup $backup
	#>
	function Restore-UserChoiceAssociations
	{
		param($Backup)
		if (-not $Backup -or $Backup.Count -eq 0) { return }
		foreach ($ext in $Backup.Keys)
		{
			$entry = $Backup[$ext]
			if (-not $entry.ProgId -or $entry.ProgId -eq 'MSEdgeHTM') { continue }
			$keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
			if (Test-Path $keyPath)
			{
				try
				{
					Set-ItemProperty -Path $keyPath -Name ProgId -Value $entry.ProgId -Force -ErrorAction SilentlyContinue
					Write-EdgeRemovalLog "Restored UserChoice for $ext -> $($entry.ProgId)"
				}
				catch
				{
					Write-EdgeRemovalLog "Failed to restore UserChoice for $ext"
				}
			}
		}
	}
	<#
	    .SYNOPSIS
	    Stop running Edge-related processes.

	    .DESCRIPTION
	    Stops the updater, browser, widgets, resume, and related Edge processes so uninstall and cleanup operations can proceed.

	    .EXAMPLE
	    Stop-EdgeProcesses
	#>
	function Stop-EdgeProcesses
	{
		Write-EdgeRemovalLog 'Stopping Edge-related processes'
		$names = @('MicrosoftEdgeUpdate', 'OneDrive', 'WidgetService', 'Widgets', 'msedge', 'Resume', 'CrossDeviceResume', 'msedgewebview2')
		foreach ($n in $names)
		{
			$count = (Get-Process -Name $n -ErrorAction SilentlyContinue).Count
			if ($count -gt 0)
			{
				Stop-Process -Name $n -Force -ErrorAction SilentlyContinue
				Write-EdgeRemovalLog "Stopped $count instance(s) of $n"
			}
		}
	}
	<#
	    .SYNOPSIS
	    Remove the legacy UWP Edge package.

	    .DESCRIPTION
	    Makes the legacy Edge package visible in CBS, removes ownership blockers, and calls DISM to uninstall the package.

	    .EXAMPLE
	    Remove-LegacyEdge
	#>
	function Remove-LegacyEdge
	{
		Write-EdgeRemovalLog 'Starting Legacy Edge/UWP Edge removal'
		$packages = Get-LegacyEdgePackages
		$first = $packages | Select-Object -First 1
		if (-not $first)
		{
			Write-EdgeRemovalLog 'No Legacy Edge packages found in CBS registry'
			return
		}
		$pkgPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\$first"
		Set-ItemProperty -Path $pkgPath -Name 'Visibility' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
		$ownersPath = "$pkgPath\Owners"
		if (Test-Path $ownersPath)
		{
			Remove-Item -Path $ownersPath -Recurse -Force -ErrorAction SilentlyContinue
		}
		Write-EdgeRemovalLog 'Removing Legacy Edge package via DISM (30s timeout)'
		$dismProc = Start-Process -FilePath 'dism.exe' -ArgumentList '/online', '/Remove-Package', "/PackageName:$first" -NoNewWindow -PassThru
		if ($dismProc -and $dismProc.WaitForExit(30000))
		{
			Write-EdgeRemovalLog 'DISM completed successfully'
		}
		elseif ($dismProc)
		{
			Write-EdgeRemovalLog 'DISM timed out after 30s; killing and retrying once'
			$dismProc.Kill()
			Start-Sleep -Seconds 2
			$retry = Start-Process -FilePath 'dism.exe' -ArgumentList '/online', '/Remove-Package', "/PackageName:$first" -NoNewWindow -PassThru
			if ($retry -and $retry.WaitForExit(30000))
			{
				Write-EdgeRemovalLog 'DISM retry completed successfully'
			}
			elseif ($retry)
			{
				Write-EdgeRemovalLog 'DISM retry also timed out; continuing'
				$retry.Kill()
			}
			else
			{
				Write-EdgeRemovalLog 'DISM retry failed to start; continuing'
			}
		}
		else
		{
			Write-EdgeRemovalLog 'DISM failed to start; continuing'
		}
		Write-EdgeRemovalLog 'Removing Legacy UWP Edge AppxPackage'
		Get-AppxPackage -AllUsers Microsoft.MicrosoftEdge | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
		Write-EdgeRemovalLog 'Legacy Edge/UWP Edge removal completed'
	}
	<#
	    .SYNOPSIS
	    Remove Edge shortcuts from user and common locations.

	    .DESCRIPTION
	    Deletes known Microsoft Edge shortcut files from user profiles, Quick Launch, taskbar pins, and shared Start Menu locations.

	    .EXAMPLE
	    Remove-EdgeShortcuts
	#>
	function Remove-EdgeShortcuts
	{
		Write-EdgeRemovalLog 'Starting Edge shortcut cleanup'
		$userProfiles = Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
			Where-Object { Test-Path "$($_.FullName)\NTUSER.DAT" }
		$paths = @()
		foreach ($p in $userProfiles)
		{
			$paths += @(
				"$($p.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
				"$($p.FullName)\Desktop\Microsoft Edge.lnk",
				"$($p.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
				"$($p.FullName)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
				"$($p.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
			)
		}
		$paths += 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk'
		$count = 0
		foreach ($shortcut in $paths)
		{
			if (Test-Path -Path $shortcut -PathType Leaf)
			{
				Remove-Item -Path $shortcut -Force -ErrorAction SilentlyContinue
				$count++
			}
		}
		Write-EdgeRemovalLog "Removed $count Edge shortcut(s)"
	}
	<#
	    .SYNOPSIS
	    Install the Edge protocol redirect helper.

	    .DESCRIPTION
	    Creates the OpenWebSearch redirect assets Baseline uses to intercept Edge-targeted URL launches after browser removal.

	    .EXAMPLE
	    Install-EdgeProtocolRedirect
	#>
	function Install-EdgeProtocolRedirect
	{
		Write-EdgeRemovalLog 'Installing Edge protocol redirect via OpenWebSearch'
		New-Item -ItemType Directory -Path $scriptsDir -Force -ErrorAction SilentlyContinue | Out-Null

		$stubTarget = Join-Path $scriptsDir 'ie_to_edge_stub.exe'
		if (-not (Test-Path $stubTarget))
		{
			Write-EdgeRemovalLog "Warning: ie_to_edge_stub.exe not found at $stubTarget; skipping redirect install"
			return
		}

		$openWebSearchPath = Join-Path $scriptsDir 'OpenWebSearch.cmd'
		$openWebSearchContent = @'
@title OpenWebSearch 2023 & echo off
for /f %%E in ('"prompt $E$S& for %%e in (1) do rem"') do echo;%%E[2t 2>nul

call :reg_var "HKCU\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoiceLatest\ProgId" ProgID ProgID
if not defined ProgID call :reg_var "HKCU\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" ProgID ProgID
if /i "%ProgID%" neq "MSEdgeHTM" if defined ProgID goto :browser_found
for %%P in ("%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe") do if exist %%P (set "Choice=%%~P"& goto :skip_browser)
set "Choice="
for %%R in (HKCU HKLM) do (
    for /f "delims=" %%K in ('reg query "%%R\SOFTWARE\Clients\StartMenuInternet" 2^>nul') do (
        for /f "skip=1 tokens=2*" %%A in ('reg query "%%K\shell\open\command" /ve 2^>nul') do (
            echo "%%B" | findstr /i "msedge ie_to_edge_stub iexplore" >nul || (set "Choice=%%~B" & goto :skip_browser)
        )
    )
)
if not defined Choice exit /b
:browser_found
call :reg_var "HKCR\%ProgID%\shell\open\command" "" Browser
set Choice=& for %%. in (%Browser%) do if not defined Choice set "Choice=%%~."
:skip_browser

set "URI=" & set "URL=" & set "NOOP="

set "CLI=%CMDCMDLINE:"=``%"
if defined CLI set "CLI=%CLI:*ie_to_edge_stub.exe`` =%"
if defined CLI set "CLI=%CLI:*ie_to_edge_stub.exe =%"
if defined CLI set "CLI=%CLI:*msedge.exe`` =%"
if defined CLI set "CLI=%CLI:*msedge.exe =%"
set "FIX=%CLI:~-1%"
if defined CLI if "%FIX%"==" " set "CLI=%CLI:~0,-1%"
if defined CLI set "RED=%CLI:microsoft-edge=%"
if defined CLI set "URL=%CLI:http=%"
if "%CLI%" equ "%RED%" (set NOOP=1) else if "%CLI%" equ "%URL%" (set NOOP=1)
if defined NOOP exit /b

set "URL=%CLI:*microsoft-edge=%"
set "URL=http%URL:*http=%"
set "FIX=%URL:~-2%"
if defined URL if "%FIX%"=="``" set "URL=%URL:~0,-2%"
call :dec_url
start "" "%Choice%" "%URL%"
exit

:reg_var
set {var}=& set {reg}=reg query "%~1" /v %2 /z /se "," /f /e& if %2=="" set {reg}=reg query "%~1" /ve /z /se "," /f /e
for /f "skip=2 tokens=* delims=" %%V in ('%{reg}% %4 %5 %6 %7 %8 %9 2^>nul') do if not defined {var} set "{var}=%%V"
if not defined {var} (set {reg}=& set "%~3="& exit /b) else if %2=="" set "{var}=%{var}:*)    =%"
if not defined {var} (set {reg}=& set "%~3="& exit /b) else set {reg}=& set "%~3=%{var}:*)    =%"& set {var}=& exit /b

:dec_url
set ".=%URL:!=}%" & setlocal enabledelayedexpansion
set ".=!.:%%={!" &set ".=!.:{3A=:!" &set ".=!.:{2F=/!" &set ".=!.:{3F=?!" &set ".=!.:{23=#!" &set ".=!.:{5B=[!" &set ".=!.:{5D=]!"
set ".=!.:{40=@!"&set ".=!.:{21=}!" &set ".=!.:{24=$!" &set ".=!.:{26=&!" &set ".=!.:{27='!" &set ".=!.:{28=(!" &set ".=!.:{29=)!"
set ".=!.:{2A=*!"&set ".=!.:{2B=+!" &set ".=!.:{2C=,!" &set ".=!.:{3B=;!" &set ".=!.:{3D==!" &set ".=!.:{25=%%!"&set ".=!.:{20= !"
set ".=!.:{=%%!" & endlocal& set "URL=%.:}=!%" & exit /b
'@

		$openWebSearchContent | Out-File -FilePath $openWebSearchPath -Encoding ASCII -Force
		Write-EdgeRemovalLog "Created OpenWebSearch.cmd at $openWebSearchPath"

		$buildNumber = [Environment]::OSVersion.Version.Build
		$conhostFlags = if ($buildNumber -gt 25179) { '--width 1 --height 1' } else { '--headless' }
		$conhostDebugger = "$env:SystemRoot\system32\conhost.exe $conhostFlags $openWebSearchPath"

		Write-EdgeRemovalLog 'Configuring registry entries for Edge protocol redirect'
		reg.exe add 'HKCR\microsoft-edge' /f /ve /d 'URL:microsoft-edge' 2>&1 | Out-Null
		reg.exe add 'HKCR\microsoft-edge' /f /v 'URL Protocol' /d '' 2>&1 | Out-Null
		reg.exe add 'HKCR\microsoft-edge' /f /v 'NoOpenWith' /d '' 2>&1 | Out-Null
		reg.exe add 'HKCR\microsoft-edge\shell\open\command' /f /ve /d "$stubTarget %1" 2>&1 | Out-Null
		reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie_to_edge_stub.exe' /f /v UseFilter /d 1 /t reg_dword 2>&1 | Out-Null
		reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie_to_edge_stub.exe\0' /f /v FilterFullPath /d "$stubTarget" 2>&1 | Out-Null
		reg.exe add 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\ie_to_edge_stub.exe\0' /f /v Debugger /d "$conhostDebugger" 2>&1 | Out-Null
		reg.exe delete 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\msedge.exe' /f 2>&1 | Out-Null
		Write-EdgeRemovalLog 'Registry configuration completed'

		$repairTemplate = @'
# OpenWebSearch Repair - re-sets protocol handler and MSEdgeHTM registry if Edge overwrites them
$stubPath = "{0}"
$owsPath = "{1}"
if (-not (Test-Path $stubPath)) {{ exit }}
if (-not (Test-Path $owsPath)) {{ exit }}
$cmd = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\microsoft-edge\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
if ($cmd -and $cmd -notlike "*ie_to_edge_stub*") {{
    reg.exe add "HKCR\microsoft-edge\shell\open\command" /f /ve /d "$stubPath %1" 2>&1 | Out-Null
}}
$htm = (Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\MSEdgeHTM\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
if ($htm -and $htm -notlike "*ie_to_edge_stub*") {{
    reg.exe add "HKCR\MSEdgeHTM\shell\open\command" /f /ve /d "`"$stubPath`" %1" 2>&1 | Out-Null
}}
'@
		$repairContent = $repairTemplate -f $stubTarget, $openWebSearchPath
		$repairScriptPath = Join-Path $scriptsDir 'OpenWebSearchRepair.ps1'
		$repairContent | Out-File -FilePath $repairScriptPath -Encoding UTF8 -Force
		Write-EdgeRemovalLog "Created OpenWebSearchRepair.ps1 at $repairScriptPath"

		try
		{
			$repairAction    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoProfile -Command `"iex([IO.File]::ReadAllText('$repairScriptPath'))`""
			$repairTrigger   = New-ScheduledTaskTrigger -AtLogon
			$repairSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
			$repairPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
			Register-ScheduledTask -TaskName 'OpenWebSearchRepair' -TaskPath '\Baseline\' -Action $repairAction -Trigger $repairTrigger -Settings $repairSettings -Principal $repairPrincipal -Force | Out-Null
			Write-EdgeRemovalLog 'Registered OpenWebSearchRepair scheduled task (runs at logon)'
		}
		catch
		{
			Write-EdgeRemovalLog "Failed to register OpenWebSearchRepair task: $($_.Exception.Message)"
		}
	}
	<#
	    .SYNOPSIS
	    Uninstall Chromium-based Edge and EdgeUpdate.

	    .DESCRIPTION
	    Runs the available Edge uninstall commands, stops related processes, and removes EdgeUpdate to finish the Chromium Edge cleanup.

	    .EXAMPLE
	    Remove-ChromiumEdge
	#>
	function Remove-ChromiumEdge
	{
		Write-EdgeRemovalLog 'Starting Edge Chromium uninstall'
		$edgePath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
		New-Item -Path $edgePath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
		New-Item -Path $edgePath -ItemType File -Name 'MicrosoftEdge.exe' -ErrorAction SilentlyContinue | Out-Null

		Write-EdgeRemovalLog 'Searching registry for Edge uninstall strings'
		$uninstallKeys = Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue
		$edgeUninstallCount = 0
		foreach ($key in $uninstallKeys)
		{
			$displayName = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).DisplayName
			if ($displayName -like '*Microsoft Edge*')
			{
				$uninstallString = (Get-ItemProperty $key.PSPath).UninstallString
				if ($uninstallString)
				{
					$edgeUninstallCount++
					Stop-EdgeProcesses
					if ($uninstallString -like '*msiexec*')
					{
						Write-EdgeRemovalLog 'Executing MSI uninstaller for Edge'
						Start-Process cmd.exe "/c $uninstallString /quiet" -WindowStyle Hidden -Wait | Out-Null
					}
					else
					{
						Write-EdgeRemovalLog 'Executing standard uninstaller for Edge'
						Start-Process cmd.exe "/c $uninstallString --force-uninstall --silent" -WindowStyle Hidden -Wait | Out-Null
					}
				}
			}
		}
		if ($edgeUninstallCount -eq 0)
		{
			Write-EdgeRemovalLog 'No Edge uninstall entries found in registry'
		}
		else
		{
			Write-EdgeRemovalLog "Executed $edgeUninstallCount Edge uninstaller(s)"
		}

		Write-EdgeRemovalLog 'Removing UWP Edge Chromium AppxPackage'
		Get-AppxPackage -AllUsers Microsoft.MicrosoftEdge.Stable | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null

		Write-EdgeRemovalLog 'Cleaning up temporary Edge directory'
		Remove-Item -Recurse -Force $edgePath -ErrorAction SilentlyContinue | Out-Null
		Write-EdgeRemovalLog 'Edge Chromium uninstall completed'

		Write-EdgeRemovalLog 'Starting EdgeUpdate removal'
		$edgeupdate = @()
		$searchPaths = @('LocalApplicationData', 'ProgramFilesX86', 'ProgramFiles')
		foreach ($pathType in $searchPaths)
		{
			$folder = [Environment]::GetFolderPath($pathType)
			$pattern = "$folder\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe"
			$found = Get-ChildItem $pattern -Recurse -ErrorAction SilentlyContinue
			if ($found) { $edgeupdate += $found.FullName }
		}
		if ($edgeupdate.Count -gt 0)
		{
			Write-EdgeRemovalLog "Found $($edgeupdate.Count) EdgeUpdate executable(s)"
		}
		else
		{
			Write-EdgeRemovalLog 'No EdgeUpdate executables found'
		}

		# Backup ClientState â€” required for EdgeWebView2 to keep working post-removal
		$backupRegFile = Join-Path $env:TEMP ("EdgeUpdate_ClientState_Backup_{0}.reg" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
		$clientStatePath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState'
		if (Test-Path $clientStatePath)
		{
			Write-EdgeRemovalLog 'Backing up EdgeUpdate ClientState (preserves EdgeWebView2)'
			cmd /c "reg export `"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState`" `"$backupRegFile`" /y" 2>$null
			if (Test-Path $backupRegFile)
			{
				Write-EdgeRemovalLog "Created registry backup at $backupRegFile"
			}
			else
			{
				Write-EdgeRemovalLog 'Warning: failed to create ClientState registry backup'
			}
		}
		else
		{
			Write-EdgeRemovalLog 'No EdgeUpdate ClientState registry found to backup'
		}

		foreach ($exePath in $edgeupdate)
		{
			if (Test-Path $exePath)
			{
				Write-EdgeRemovalLog "Unregistering EdgeUpdate service from $exePath"
				Start-Process -FilePath $exePath -ArgumentList '/unregsvc' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
				$waitCount = 0
				do
				{
					Start-Sleep -Seconds 3
					$running = Get-Process -Name 'setup', 'MicrosoftEdge*' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\Microsoft\Edge*' }
				}
				while ($running -and $waitCount++ -lt 20)
				if (Test-Path $exePath)
				{
					Write-EdgeRemovalLog "Running EdgeUpdate uninstaller from $exePath"
					Start-Process -FilePath $exePath -ArgumentList '/uninstall' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
				}
			}
		}

		if (Test-Path $backupRegFile)
		{
			Write-EdgeRemovalLog 'Restoring EdgeUpdate ClientState (re-arms EdgeWebView2)'
			cmd /c "reg import `"$backupRegFile`"" 2>$null
			Remove-Item $backupRegFile -ErrorAction SilentlyContinue
		}
		else
		{
			Write-EdgeRemovalLog 'No registry backup file found to restore'
		}
		Write-EdgeRemovalLog 'EdgeUpdate removal completed'
	}
	<#
	    .SYNOPSIS
	    Remove Edge registry keys and registration leftovers.

	    .DESCRIPTION
	    Deletes direct Edge registry keys and selected registration values that remain after Edge removal.

	    .EXAMPLE
	    Remove-EdgeRegistryKeys
	#>
	function Remove-EdgeRegistryKeys
	{
		Write-EdgeRemovalLog 'Starting Edge registry cleanup'
		$directPaths = @(
			'HKLM:\SOFTWARE\Microsoft\Edge',
			'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Edge',
			'HKCU:\Software\Microsoft\Edge',
			'HKCU:\Software\Microsoft\EdgeUpdate',
			'HKLM:\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge',
			'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe',
			'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MicrosoftEdge',
			'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge',
			'HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application\Edge',
			'HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application\edgeupdate',
			'HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application\edgeupdatem'
		)
		$removed = 0
		foreach ($p in $directPaths)
		{
			if (Test-Path $p)
			{
				Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
				$removed++
			}
		}
		Write-EdgeRemovalLog "Removed $removed direct registry key(s)"

		$valuesToRemove = @(
			@{ Path = 'HKLM:\SOFTWARE\RegisteredApplications'; Name = 'Microsoft Edge' },
			@{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppLaunch'; Name = 'MSEdge' },
			@{ Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store'; Name = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' }
		)
		$removedValues = 0
		foreach ($item in $valuesToRemove)
		{
			if ((Test-Path $item.Path) -and (Get-ItemProperty -Path $item.Path -Name $item.Name -ErrorAction SilentlyContinue))
			{
				Remove-ItemProperty -Path $item.Path -Name $item.Name -Force -ErrorAction SilentlyContinue
				$removedValues++
			}
		}
		Write-EdgeRemovalLog "Removed $removedValues registry value(s)"

		$patterns = @(
			@{ Root = 'HKLM:\SOFTWARE\Classes'; Pattern = 'MicrosoftEdgeUpdate*' },
			@{ Root = 'HKLM:\SOFTWARE\Classes'; Pattern = 'MSEdge*' },
			@{ Root = 'HKLM:\SOFTWARE\Classes\WOW6432Node'; Pattern = 'MicrosoftEdgeUpdate*' },
			@{ Root = 'HKLM:\SOFTWARE\WOW6432Node\Classes'; Pattern = 'MicrosoftEdgeUpdate*' }
		)
		$removedPattern = 0
		foreach ($pi in $patterns)
		{
			if (Test-Path $pi.Root)
			{
				$matched = Get-ChildItem -Path $pi.Root -ErrorAction SilentlyContinue |
					Where-Object { $_.PSChildName -like $pi.Pattern }
				foreach ($key in $matched)
				{
					Remove-Item $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
					$removedPattern++
				}
			}
		}
		Write-EdgeRemovalLog "Removed $removedPattern pattern-matched key(s)"

		$muiCachePath = 'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'
		if (Test-Path $muiCachePath)
		{
			$properties = Get-ItemProperty -Path $muiCachePath -ErrorAction SilentlyContinue
			$removedMui = 0
			if ($properties)
			{
				foreach ($prop in $properties.PSObject.Properties)
				{
					if ($prop.Name -like '*Edge*' -or $prop.Name -like '*EdgeUpdate*')
					{
						Remove-ItemProperty -Path $muiCachePath -Name $prop.Name -Force -ErrorAction SilentlyContinue
						$removedMui++
					}
				}
			}
			Write-EdgeRemovalLog "Removed $removedMui MuiCache entry(ies)"
		}
	}
	<#
	    .SYNOPSIS
	    Remove leftover Edge folders while preserving WebView2.

	    .DESCRIPTION
	    Deletes the extra system and per-user Edge folders Baseline cleans after browser removal without touching EdgeWebView2.

	    .EXAMPLE
	    Remove-AdditionalEdgeFolders
	#>
	function Remove-AdditionalEdgeFolders
	{
		Write-EdgeRemovalLog 'Starting additional Edge folder cleanup (preserves EdgeWebView2)'
		$systemPaths = @(
			'C:\ProgramData\Microsoft\EdgeUpdate',
			'C:\Windows\Temp\MsEdgeCrashpad'
		)
		$removed = 0
		foreach ($p in $systemPaths)
		{
			if (Test-Path $p)
			{
				Write-EdgeRemovalLog "Removing $p"
				Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
				$removed++
			}
		}
		$userProfiles = Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue |
			Where-Object { Test-Path "$($_.FullName)\NTUSER.DAT" }
		foreach ($p in $userProfiles)
		{
			$edgeLocal = "$($p.FullName)\AppData\Local\Microsoft\Edge"
			if (Test-Path $edgeLocal)
			{
				Write-EdgeRemovalLog "Removing $edgeLocal"
				Remove-Item $edgeLocal -Recurse -Force -ErrorAction SilentlyContinue
				$removed++
			}
		}
		Write-EdgeRemovalLog "Removed $removed additional Edge folder(s)"
	}

	# --- Main flow ---
	try
	{
		$userChoiceBackup = Backup-UserChoiceAssociations

		Write-EdgeRemovalLog 'Checking for Edge installations'
		$legacyInstalled = Test-LegacyEdgeInstalled
		$chromiumInstalled = Test-ChromiumEdgeInstalled

		if (-not $legacyInstalled -and -not $chromiumInstalled)
		{
			Write-EdgeRemovalLog 'No Edge installations detected; skipping removal'
		}

		# Stash ie_to_edge_stub.exe BEFORE removal so we can install the redirect afterward
		if ($chromiumInstalled)
		{
			Write-EdgeRemovalLog 'Locating ie_to_edge_stub.exe before Edge removal'
			$stubPath = $null
			$stubLocations = @("$env:ProgramData\ie_to_edge_stub.exe", "$env:Public\ie_to_edge_stub.exe")
			foreach ($loc in $stubLocations)
			{
				if (Test-Path $loc) { $stubPath = $loc; Write-EdgeRemovalLog "Found stub at $loc"; break }
			}
			if (-not $stubPath)
			{
				$found = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Edge" -Filter 'ie_to_edge_stub.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
				if ($found) { $stubPath = $found.FullName; Write-EdgeRemovalLog "Found stub at $stubPath" }
				else { Write-EdgeRemovalLog 'ie_to_edge_stub.exe not found in any location' }
			}
			if ($stubPath)
			{
				New-Item -ItemType Directory -Path $scriptsDir -Force -ErrorAction SilentlyContinue | Out-Null
				Copy-Item $stubPath (Join-Path $scriptsDir 'ie_to_edge_stub.exe') -Force -ErrorAction SilentlyContinue
				Write-EdgeRemovalLog "Cached ie_to_edge_stub.exe to $scriptsDir"
			}
		}

		$removedSomething = $false
		if ($legacyInstalled)
		{
			Write-EdgeRemovalLog 'Legacy Edge detected; proceeding with removal'
			Stop-EdgeProcesses
			Remove-LegacyEdge
			$removedSomething = $true
		}
		if ($chromiumInstalled)
		{
			Write-EdgeRemovalLog 'Chromium Edge detected; proceeding with removal'
			Stop-EdgeProcesses
			Remove-ChromiumEdge
			$removedSomething = $true
		}

		if ($removedSomething)
		{
			Write-EdgeRemovalLog 'Cleaning up Microsoft Edge folders (preserves EdgeWebView)'
			$edgeFolders = Get-ChildItem -Path "$env:SystemDrive\Program Files (x86)\Microsoft" -Directory -ErrorAction SilentlyContinue |
				Where-Object { ($_.Name -like '*Edge*' -or $_.Name -like '*Temp*') -and $_.Name -notlike '*EdgeWebView*' }
			if ($edgeFolders)
			{
				Write-EdgeRemovalLog "Found $($edgeFolders.Count) Edge-related folder(s) to remove"
				$edgeFolders | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
			}
			Remove-EdgeShortcuts
			Remove-EdgeRegistryKeys
			Remove-AdditionalEdgeFolders
		}

		# Redirect MSEdgeHTM via stub so existing UserChoice associations still resolve
		$cachedStub = Join-Path $scriptsDir 'ie_to_edge_stub.exe'
		if (Test-Path $cachedStub)
		{
			reg.exe add 'HKCR\MSEdgeHTM\shell\open\command' /f /ve /d "`"$cachedStub`" %1" 2>&1 | Out-Null
			Write-EdgeRemovalLog 'Redirected MSEdgeHTM to ie_to_edge_stub.exe'
		}
		else
		{
			reg.exe delete 'HKCR\MSEdgeHTM' /f 2>&1 | Out-Null
			Write-EdgeRemovalLog 'Removed MSEdgeHTM (stub not available)'
		}

		Install-EdgeProtocolRedirect

		Write-EdgeRemovalLog 'Removing Edge scheduled tasks'
		try
		{
			$edgeTasks = Get-ScheduledTask -TaskName '*Edge*' -ErrorAction SilentlyContinue
			if ($edgeTasks)
			{
				foreach ($task in $edgeTasks)
				{
					if ($task.TaskName -eq 'EdgeRemoval' -or $task.TaskName -eq 'OpenWebSearchRepair') { continue }
					Write-EdgeRemovalLog "Found Edge scheduled task: $($task.TaskName)"
					try
					{
						Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
						Write-EdgeRemovalLog "Deleted scheduled task $($task.TaskName)"
					}
					catch
					{
						Write-EdgeRemovalLog "Failed to delete $($task.TaskName): $($_.Exception.Message)"
					}
				}
			}
			else
			{
				Write-EdgeRemovalLog 'No Edge scheduled tasks found'
			}
		}
		catch
		{
			Write-EdgeRemovalLog "Failed to enumerate scheduled tasks: $($_.Exception.Message)"
		}

		Restore-UserChoiceAssociations -Backup $userChoiceBackup

		Write-EdgeRemovalLog 'Edge removal completed'
		Write-ConsoleStatus -Status success
	}
	catch
	{
		Write-EdgeRemovalLog "Edge removal failed: $($_.Exception.Message)"
		Write-ConsoleStatus -Status failed
		LogError "Edge removal failed: $($_.Exception.Message)"
	}
}

<#
.SYNOPSIS
Enable or disable New Outlook



.DESCRIPTION

Enables or disables New Outlook in GUI and headless runs.
.PARAMETER Enable
Enable New Outlook

.PARAMETER Disable
Disable New Outlook

.EXAMPLE
NewOutlook -Enable

.EXAMPLE
NewOutlook -Disable

.NOTES
Current user
#>
function NewOutlook
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling New Outlook"
			LogInfo "Enabling New Outlook"
			Set-ItemProperty -LiteralPath "HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences" -Name "UseNewOutlook" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General" -Name "HideNewOutlookToggle" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General" -Name "DoNewOutlookAutoMigration" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences" -Name "NewOutlookMigrationUserSetting" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling New Outlook"
			LogInfo "Disabling New Outlook"
			Set-ItemProperty -LiteralPath "HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences" -Name "UseNewOutlook" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General" -Name "HideNewOutlookToggle" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General" -Name "DoNewOutlookAutoMigration" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Remove-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences" -Name "NewOutlookMigrationUserSetting" | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
    .SYNOPSIS
    Enable or disable the notification tray and calendar flyout.

    .DESCRIPTION
    Toggles the Explorer policy and toast notification setting Baseline uses to control Notification Center availability.

    .PARAMETER Enable
    Turn the notification tray and calendar flyout on.

    .PARAMETER Disable
    Turn the notification tray and calendar flyout off.

    .EXAMPLE
    Notifications -Disable
#>
function Notifications
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Enable")]
		[switch]$Enable,

		[Parameter(Mandatory = $true, ParameterSetName = "Disable")]
		[switch]$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Notification Tray/Calendar"
			LogInfo "Enabling Notification Tray/Calendar"
			Remove-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Notification Tray/Calendar"
			LogInfo "Disabling Notification Tray/Calendar"
			if (-not (Test-Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer"))
			{
				New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force -ErrorAction SilentlyContinue | Out-Null
			}
			Set-ItemProperty -LiteralPath "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
    .SYNOPSIS
    Enable or disable the reverted Windows 11 Start Menu layout.

    .DESCRIPTION
    Uses ViVeTool to toggle the supported Start Menu feature ID on eligible Windows 11 builds and keeps the temporary tool under the Baseline temp folder.

    .PARAMETER Enable
    Apply the reverted Start Menu feature toggle.

    .PARAMETER Disable
    Remove the reverted Start Menu feature toggle.

    .EXAMPLE
    RevertStartMenu -Enable
#>
function RevertStartMenu
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Enable")]
		[switch]$Enable,

		[Parameter(Mandatory = $true, ParameterSetName = "Disable")]
		[switch]$Disable
	)

	$viveToolUrl = "https://github.com/thebookisclosed/ViVe/releases/download/v0.3.4/ViVeTool-v0.3.4-IntelAmd.zip"
	$featureId = "47205210"
	$tempDir = "$env:TEMP\ViVeTool"
	$SupportedMessage = "Revert Start Menu is only supported on Windows 11 24H2 build 26100.7019+ or 26H1 build 28000.1575+ and newer. Skipping."
	$DownloadFailedMessage = "Unable to download ViVeTool from GitHub. Skipping Revert Start Menu."
	$IsRevertStartMenuSupported = Test-Windows11FeatureBranchSupport -Thresholds @(
		@{ DisplayVersion = "24H2"; Build = 26100; UBR = 7019 },
		@{ DisplayVersion = "26H1"; Build = 28000; UBR = 1575 }
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling Revert Start Menu"
			LogInfo "Enabling Revert Start Menu"

			if (-not $IsRevertStartMenuSupported)
			{
				Write-ConsoleStatus -Status success
				LogWarning $SupportedMessage
				return
			}

			try
			{
				# Create temp directory
				if (Test-Path $tempDir)
				{
					Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
				}
				New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
				
				# Download ViVeTool
				$zipPath = "$tempDir\ViVeTool.zip"
				Invoke-WebRequest $viveToolUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop | Out-Null
				LogInfo "Downloaded ViVeTool"
				
				# Extract
				Expand-Archive $zipPath -DestinationPath $tempDir -Force -ErrorAction Stop | Out-Null
				LogInfo "Extracted ViVeTool"
				
				# Run ViVeTool
				$viveExe = "$tempDir\ViVeTool.exe"
				if (-not (Test-Path $viveExe))
				{
					throw "ViVeTool.exe was not found after extraction"
				}
				$ViVeProcess = Start-Process $viveExe -ArgumentList "/disable /id:$featureId" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
				if ($ViVeProcess.ExitCode -ne 0)
				{
					throw "ViVeTool returned exit code $($ViVeProcess.ExitCode)"
				}
				LogInfo "Applied ViVeTool setting to disable feature $featureId"
				
				# Cleanup
				Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
				LogInfo "Cleaned up temporary files"
				LogInfo $Localization.RestartWarning
				Write-ConsoleStatus -Status success
			}
			catch
			{
				if ($_.Exception.Message -match 'github\.com|remote name could not be resolved|The remote server returned an error|Unable to connect|connection could not be established')
				{
					LogWarning "$DownloadFailedMessage Error: $($_.Exception.Message)"
					# Write-Host: intentional â€” user-visible progress indicator
					Write-Host "skipped!" -ForegroundColor Yellow
				}
				else
				{
					LogError "Failed to enable Revert Start Menu: $($_.Exception.Message)"
					Write-ConsoleStatus -Status failed
				}
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling Revert Start Menu"
			LogInfo "Disabling Revert Start Menu"

			if (-not $IsRevertStartMenuSupported)
			{
				Write-ConsoleStatus -Status success
				LogWarning $SupportedMessage
				return
			}

			try
			{
				# Create temp directory
				if (Test-Path $tempDir)
				{
					Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
				}
				New-Item -Path $tempDir -ItemType Directory -Force -ErrorAction Stop | Out-Null

				# Download ViVeTool
				$zipPath = "$tempDir\ViVeTool.zip"
				Invoke-WebRequest $viveToolUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop | Out-Null
				LogInfo "Downloaded ViVeTool"

				# Extract
				Expand-Archive $zipPath -DestinationPath $tempDir -Force -ErrorAction Stop | Out-Null
				LogInfo "Extracted ViVeTool"

				# Run ViVeTool
				$viveExe = "$tempDir\ViVeTool.exe"
				if (-not (Test-Path $viveExe))
				{
					throw "ViVeTool.exe was not found after extraction"
				}
				$ViVeProcess = Start-Process $viveExe -ArgumentList "/enable /id:$featureId" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
				if ($ViVeProcess.ExitCode -ne 0)
				{
					throw "ViVeTool returned exit code $($ViVeProcess.ExitCode)"
				}
				LogInfo "Applied ViVeTool setting to enable feature $featureId"

				# Cleanup
				Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
				LogInfo "Cleaned up temporary files"
				LogInfo $Localization.RestartWarning
				Write-ConsoleStatus -Status success
			}
			catch
			{
					$revertDisableError = $_.Exception.Message
					if ($revertDisableError -match 'github\.com|remote name could not be resolved|The remote server returned an error|Unable to connect|connection could not be established')
					{
						LogWarning ("{0} Error: {1}" -f $DownloadFailedMessage, $revertDisableError)
						# Write-Host: intentional â€” user-visible progress indicator
						Write-Host "skipped!" -ForegroundColor Yellow
					}
					else
					{
						LogError ("Failed to disable Revert Start Menu: {0}" -f $revertDisableError)
						Write-ConsoleStatus -Status failed
					}
			}
		}
	}
}

<#
	.SYNOPSIS
	Install or uninstall UWP apps by using the graphical app picker.

	.DESCRIPTION
	Opens a graphical app picker that lists installable or removable Microsoft
	Store and inbox UWP packages, then applies the selected action.

	.PARAMETER Install
	Open the app picker and install the selected UWP apps.

	.PARAMETER Uninstall
	Open the app picker and uninstall the selected UWP apps.

	.PARAMETER ForAllUsers
	Apply the selected install or uninstall action for all users where supported.

	.EXAMPLE
	UWPApps -Install

	.EXAMPLE
	UWPApps -Uninstall

	.NOTES
	Current user

	.NOTES
	Use `-ForAllUsers` for machine-wide package provisioning changes where supported
#>

function UWPApps
{
	[CmdletBinding(DefaultParameterSetName = "None")]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = "Install")]
		[switch]
		$Install,

		[Parameter(Mandatory = $true, ParameterSetName = "Uninstall")]
		[switch]
		$Uninstall,

		[Parameter(Mandatory = $false)]
		[switch]
		$ForAllUsers,

		[Parameter(Mandatory = $false)]
		[string[]]
		$SelectedPackages,

		[Parameter(Mandatory = $false)]
		[switch]
		$CollectSelectionOnly,

		[Parameter(Mandatory = $false)]
		[switch]
		$NonInteractive
	)

	$script:UWPAppsSelectionResult = $null
	$script:UWPAppsSelectionSeed = if ($null -ne $SelectedPackages) { @($SelectedPackages) } else { @() }
	$script:UWPAppsExecutionResult = $null
	$SelectedPackagesProvided = $PSBoundParameters.ContainsKey('SelectedPackages')
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
	$guiCommonPath = if ($modulePath)
	{
		Join-Path -Path (Split-Path -Path (Split-Path -Path $modulePath -Parent) -Parent) -ChildPath 'GUICommon.psm1'
	}
	else
	{
		$null
	}

	<#
	    .SYNOPSIS
	    Request GUI UWP apps selection.

	    
.DESCRIPTION
	    
Supports GUI UWP apps selection handling inside Baseline.
	#>

	function Request-GuiUWPAppsSelection
	{
		param
		(
			[Parameter(Mandatory = $true)]
			[ValidateSet('Install', 'Uninstall')]
			[string]
			$Mode,

			[Parameter(Mandatory = $false)]
			[bool]
			$ForAllUsersSelection = $false,

			[Parameter(Mandatory = $false)]
			[string[]]
			$SeedPackages = @()
		)

		$queue = Get-Variable -Name 'GUIRunState' -ValueOnly -ErrorAction Ignore
		if (-not $queue)
		{
			throw 'GUI execution could not open the UWP app picker because the GUI request queue is unavailable.'
		}

		$responseState = [hashtable]::Synchronized(@{
			Done = $false
			Result = $null
			Error = $null
		})

		$queue.Enqueue([PSCustomObject]@{
			Kind = '_InteractiveSelectionRequest'
			RequestType = 'UWPApps'
			Mode = $Mode
			ForAllUsers = [bool]$ForAllUsersSelection
			SelectedPackages = @($SeedPackages)
			ResponseState = $responseState
		})

		while (-not [bool]$responseState['Done'])
		{
			$runState = Get-Variable -Name 'runState' -ValueOnly -ErrorAction Ignore
			if ($runState -and $runState.ContainsKey('AbortRequested') -and [bool]$runState['AbortRequested'])
			{
				return $null
			}

			Start-Sleep -Milliseconds 200
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$responseState['Error']))
		{
			throw [System.InvalidOperationException]::new([string]$responseState['Error'])
		}

		return $responseState['Result']
	}

		<#
		    .SYNOPSIS
		    Sets UWP apps execution result.

		    
.DESCRIPTION
		    
Supports UWP apps execution result handling inside Baseline.
		#>

		function Set-UWPAppsExecutionResult
		{
			param
			(
			[Parameter(Mandatory = $true)]
			[ValidateSet('Success', 'Partial', 'Failed')]
			[string]
			$Outcome,

			[Parameter(Mandatory = $true)]
			[string]
			$Message
		)

			$script:UWPAppsExecutionResult = [PSCustomObject]@{
				Outcome = $Outcome
				Message = $Message
			}
		}

		<#
		    .SYNOPSIS
		    Sets UWP apps picker surface.

		    
.DESCRIPTION
		    
Supports UWP apps picker surface handling inside Baseline.
		#>

		function Set-UWPAppsPickerSurface
		{
			param
			(
				[Parameter(Mandatory = $true)]
				[object]
				$Window,

				[Parameter(Mandatory = $true)]
				[System.Windows.Controls.Border]
				$RootBorder,

				[Parameter(Mandatory = $true)]
				[System.Windows.Controls.Panel]
				$PanelContainer,

				[Parameter(Mandatory = $true)]
				[hashtable]
				$Theme,

				[Parameter(Mandatory = $true)]
				[System.Windows.Media.BrushConverter]
				$BrushConverter,

				[Parameter(Mandatory = $true)]
				[object]
				$UseDarkMode
			)

			$resolvedUseDarkMode = GUICommon\Get-GuiBooleanValue -Value $UseDarkMode -Default $(if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }) -Context 'Set-UWPAppsPickerSurface'

			$surfaceTheme = $Theme
			if (-not $surfaceTheme -or $surfaceTheme.Count -le 0)
			{
				$surfaceTheme = if ($resolvedUseDarkMode) { $Script:DarkTheme } else { $Script:LightTheme }
			}
			elseif (Get-Command -Name 'Repair-GuiThemePalette' -CommandType Function -ErrorAction SilentlyContinue)
			{
				$surfaceTheme = Repair-GuiThemePalette -Theme $surfaceTheme -ThemeName $(if ($resolvedUseDarkMode) { 'Dark' } else { 'Light' })
			}

			$getThemeColor = {
				param(
					[string]$ColorName,
					[string]$DefaultColor
				)

				try
				{
					if ($surfaceTheme -and ($surfaceTheme -is [System.Collections.IDictionary]) -and $surfaceTheme.Contains($ColorName))
					{
						$value = [string]$surfaceTheme[$ColorName]
						if (-not [string]::IsNullOrWhiteSpace($value))
						{
							return $value
						}
					}
				}
				catch
				{
					if (Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue)
					{
						Write-DebugSwallowedException -ErrorRecord $_ -Source 'UWPApps.ApplyRemovalResults.ThemeColor'
					}
					else
					{
						Write-Verbose ("UWPApps.ApplyRemovalResults.ThemeColor: {0}" -f $_.Exception.Message)
					}
				}

				return $DefaultColor
			}.GetNewClosure()

			$windowBg = & $getThemeColor -ColorName 'WindowBg' -DefaultColor $(if ($resolvedUseDarkMode) { [string]$Script:DarkTheme.WindowBg } else { [string]$Script:LightTheme.WindowBg })
			$panelBg = & $getThemeColor -ColorName 'PanelBg' -DefaultColor $windowBg

			if ($Window)
			{
				$Window.Background = $BrushConverter.ConvertFromString($windowBg)
			}
			if ($RootBorder)
			{
				$RootBorder.Background = $BrushConverter.ConvertFromString($windowBg)
			}
			if ($PanelContainer)
			{
				$PanelContainer.Background = $BrushConverter.ConvertFromString($panelBg)
			}
		}

		switch ($PSCmdlet.ParameterSetName)
		{
		"Install"
		{
            if ($Global:GUIMode -and -not $CollectSelectionOnly -and -not $SelectedPackagesProvided)
            {
                $selectionResult = Request-GuiUWPAppsSelection -Mode 'Install' -ForAllUsersSelection ([bool]$ForAllUsers) -SeedPackages @($SelectedPackages)
                if ($null -ne $selectionResult)
                {
                    $ForAllUsers = [bool]$selectionResult.ForAllUsers
                    $SelectedPackages = @($selectionResult.SelectedPackages)
                    $script:UWPAppsSelectionSeed = @($SelectedPackages)
                    $SelectedPackagesProvided = $true
                }
            }

            if ($NonInteractive -and -not $SelectedPackagesProvided)
            {
                Write-ConsoleStatus -Action "Installing UWP apps"
                LogWarning "Skipping UWP app install because no preselected packages were provided for noninteractive execution."
                Write-ConsoleStatus -Status warning
                return
            }

            # Show the app picker and install the packages the user selects.
            Add-Type -AssemblyName PresentationCore, PresentationFramework
            if (-not $CollectSelectionOnly)
            {
                Write-ConsoleStatus -Action "Installing UWP apps"
                LogInfo "Installing UWP apps:"
            }

            # Check for admin rights when "All Users" is selected
            if ($ForAllUsers)
            {
                $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (-not $IsAdmin)
                {
                    LogWarning "Skipping UWP app install for all users because administrator privileges are required."
                    if (-not $CollectSelectionOnly)
                    {
                        Write-ConsoleStatus -Status warning
                    }
                    if (-not $NonInteractive)
                    {
                        $wshell = New-Object -ComObject Wscript.Shell
                        $wshell.Popup("Installing for all users requires administrator privileges.`nPlease run PowerShell as Administrator.", 0, "Admin Required", 0)
                    }
                    return
                }
            }

            # The following UWP apps will be excluded from the display
            $ExcludedAppxPackages = @(
                # Microsoft Edge
                "Microsoft.MicrosoftEdge.Stable",
                # Microsoft Visual C++ runtime framework
                "Microsoft.VCLibs.140.00",
                # AMD Radeon Software
                "AdvancedMicroDevicesInc-2.AMDRadeonSoftware",
                # Intel Graphics Control Center
                "AppUp.IntelGraphicsControlPanel",
                "AppUp.IntelGraphicsExperience",
                # ELAN Touchpad
                "ELANMicroelectronicsCorpo.ELANTouchpadforThinkpad",
                "ELANMicroelectronicsCorpo.ELANTrackPointforThinkpa",
                # Microsoft Application Compatibility Enhancements
                "Microsoft.ApplicationCompatibilityEnhancements",
                # AVC Encoder Video Extension
                "Microsoft.AVCEncoderVideoExtension",
                # Microsoft Desktop App Installer
                "Microsoft.DesktopAppInstaller",
                # Store Experience Host
                "Microsoft.StorePurchaseApp",
                # Cross Device Experience Host
                "MicrosoftWindows.CrossDevice",
                # Notepad
                "Microsoft.WindowsNotepad",
                # Microsoft Store
                "Microsoft.WindowsStore",
                # Windows Terminal
                "Microsoft.WindowsTerminal",
                "Microsoft.WindowsTerminalPreview",
                # Web Media Extensions
                "Microsoft.WebMediaExtensions",
                # AV1 Video Extension
                "Microsoft.AV1VideoExtension",
                # Windows Subsystem for Linux
                "MicrosoftCorporationII.WindowsSubsystemForLinux",
                # HEVC Video Extensions from Device Manufacturer
                "Microsoft.HEVCVideoExtension",
                "Microsoft.HEVCVideoExtensions",
                # Raw Image Extension
                "Microsoft.RawImageExtension",
                # HEIF Image Extensions
                "Microsoft.HEIFImageExtension",
                # MPEG-2 Video Extension
                "Microsoft.MPEG2VideoExtension",
                # VP9 Video Extensions
                "Microsoft.VP9VideoExtensions",
                # Webp Image Extensions
                "Microsoft.WebpImageExtension",
                # PowerShell
                "Microsoft.PowerShell",
                # NVIDIA Control Panel
                "NVIDIACorp.NVIDIAControlPanel",
                # Realtek Audio Console
                "RealtekSemiconductorCorp.RealtekAudioControl",
                # Synaptics
                "SynapticsIncorporated.SynapticsControlPanel",
                "SynapticsIncorporated.24916F58D6E7"
            )


            #region XAML Markup
            [xml]$XAML = @"
            <Window
                xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                Name="Window"
                MinHeight="400" MinWidth="415"
                SizeToContent="Width" WindowStartupLocation="CenterScreen"
                TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
                FontFamily="FluentSystemIcons" FontSize="12" ShowInTaskbar="True"
                Background="Transparent" AllowsTransparency="True" WindowStyle="None">
                <Window.Resources>
                        <Style TargetType="StackPanel">
                                <Setter Property="Orientation" Value="Horizontal"/>
                                <Setter Property="VerticalAlignment" Value="Top"/>
                        </Style>
                        <Style TargetType="CheckBox">
                                <Setter Property="Margin" Value="10, 13, 10, 10"/>
                                <Setter Property="IsChecked" Value="True"/>
                        </Style>
                        <Style TargetType="TextBlock">
                                <Setter Property="Margin" Value="0, 10, 10, 10"/>
                        </Style>
                        <Style TargetType="Button">
                                <Setter Property="Margin" Value="20"/>
                                <Setter Property="Padding" Value="10"/>
                                <Setter Property="IsEnabled" Value="False"/>
                        </Style>
                        <Style TargetType="Border">
                                <Setter Property="Grid.Row" Value="1"/>
                                <Setter Property="CornerRadius" Value="0"/>
                                <Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
                        </Style>
                        <Style TargetType="ScrollViewer">
                                <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
                                <Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
                        </Style>
                </Window.Resources>
                <Border Name="RootBorder" CornerRadius="8" Padding="0">
                <Grid>
                        <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid Grid.Row="0">
                                <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Name="PanelSelectAll" Grid.Column="0" HorizontalAlignment="Left">
                                        <CheckBox Name="CheckBoxSelectAll" IsChecked="False"/>
                                        <TextBlock Name="TextBlockSelectAll" Margin="10,10, 0, 10"/>
                                </StackPanel>
                                <StackPanel Name="PanelInstallForAll" Grid.Column="1" HorizontalAlignment="Right">
                                        <TextBlock Name="TextBlockInstallForAll" Margin="10,10, 0, 10"/>
                                        <CheckBox Name="CheckBoxForAllUsers" IsChecked="False"/>
                                </StackPanel>
                        </Grid>
                        <Border>
                                <ScrollViewer>
                                        <StackPanel Name="PanelContainer" Orientation="Vertical" Margin="5"/>
                                </ScrollViewer>
                        </Border>
                        <Button Name="ButtonInstall" Grid.Row="2" Content="" Margin="20" Padding="10" IsEnabled="False"/>
                </Grid>
                </Border>
            </Window>
"@
            #endregion XAML Markup

            $Form = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML))

			if ($null -eq $Form)
            {
                # TODO: Consider replacing with Write-Log
                Write-Host "Failed to load XAML" -ForegroundColor Red
                return
            }

            $XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
                Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
            }

			# Apply shared window chrome theming
			$bc = New-Object System.Windows.Media.BrushConverter
			$currentTheme = if (Test-Path -Path Variable:\Script:CurrentTheme) { $Script:CurrentTheme } else { @{} }
			$isDarkMode = if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }

			# Apply window chrome theme
				if (Test-Path -Path Function:\Set-GuiWindowChromeTheme)
				{
					[void](GUICommon\Set-GuiWindowChromeTheme -Window $Form -UseDarkMode:$isDarkMode)
				}

				$PanelContainer = $Form.FindName("PanelContainer")
				if ($null -eq $PanelContainer)
	            {
	                # TODO: Consider replacing with Write-Log
	                Write-Host "PanelContainer not found!" -ForegroundColor Red
	                return
	            }
				$RootBorder = $Form.FindName("RootBorder")
				Set-UWPAppsPickerSurface -Window $Form -RootBorder $RootBorder -PanelContainer $PanelContainer -Theme $currentTheme -BrushConverter $bc -UseDarkMode $isDarkMode
	            $Window.Title               = $Localization.UWPAppsTitle
				if (Test-Path -Path Function:\Add-GuiPopupWindowChrome)
				{
					[void](GUICommon\Add-GuiPopupWindowChrome -Window $Form -RootBorder $RootBorder -PanelContainer $PanelContainer -Theme $currentTheme -UseDarkMode $isDarkMode)
				}
	            $ButtonInstall.Content      = $Localization.Install
	            $TextBlockInstallForAll.Text = $Localization.UninstallUWPForAll
            $TextBlockSelectAll.Text     = $Localization.GuiSelectAll

            $ButtonInstall.Add_Click({ButtonInstallClick})
            $CheckBoxForAllUsers.Add_Click({CheckBoxForAllUsersClick})
            $CheckBoxSelectAll.Add_Click({CheckBoxSelectAllClick})

            #region Functions
            function Get-MissingAppxPackages
            {
            	            <#
            	                .SYNOPSIS
            	                Return the supported Appx packages that are currently missing.

            	                .DESCRIPTION
            	                Builds the Baseline package list for the current OS and returns the packages that are not installed for the current user or all users.

            	                .PARAMETER AllUsers
            	                Check package presence across all users when running with administrative rights.

            	                .EXAMPLE
            	                Get-MissingAppxPackages -AllUsers
            	            #>
           	[CmdletBinding()]
           	param
           	(
          		[switch]
          		$AllUsers
           	)

           	# Check if running as admin for AllUsers queries
           	$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

			$CommonPackages = @(
				@{ Name = "Microsoft.OutlookForWindows"; DisplayName = "Microsoft Outlook" }
				@{ Name = "Microsoft.WindowsCalculator"; DisplayName = "Calculator" }
				@{ Name = "Microsoft.WindowsCamera"; DisplayName = "Camera" }
				@{ Name = "Microsoft.Windows.Photos"; DisplayName = "Photos" }
				@{ Name = "Microsoft.GamingServices"; DisplayName = "Gaming Services" }
				@{ Name = "Microsoft.YourPhone"; DisplayName = "Phone Link" }
				@{ Name = "DolbyLaboratories.DolbyAccess"; DisplayName = "Dolby Access" }
			)

			# Add Voice Recorder only for Windows 10
			$os = Get-OSInfo
			if (-not $os.IsWindows11) {
				$CommonPackages += @{ Name = "Microsoft.WindowsSoundRecorder"; DisplayName = "Voice Recorder" }
			}

           	$MissingPackages = @()
           	$InstalledCount = 0
           	$ExcludedCount = 0

           	foreach ($Package in $CommonPackages)
           	{
          		if ($Package.Name -in $ExcludedAppxPackages)
          		{
         			$ExcludedCount++
         			continue
          		}

          		# Check if package is installed
          		$Installed = $null

          		if ($AllUsers)
          		{
         			if ($IsAdmin)
         			{
            				# Admin: Check all users
            				$Installed = Get-AppxPackage -Name $Package.Name -AllUsers -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
         			}
         			else
         			{
            				# Non-admin: Can only check current user
            				$Installed = Get-AppxPackage -Name $Package.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            				if (-not $script:AllUsersWarningShown)
            				{
           					LogWarning "Running without admin rights - 'All Users' mode will only check current user"
           					$script:AllUsersWarningShown = $true
            				}
         			}
          		}
          		else
          		{
         			# Current user only
         			$Installed = Get-AppxPackage -Name $Package.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
          		}

          		if ($null -eq $Installed)
          		{
         			$MissingPackages += [PSCustomObject]@{
            				Name = $Package.Name
            				PackageFullName = $Package.Name
            				DisplayName = $Package.DisplayName
         			}
          		}
          		else
          		{
         			$InstalledCount++
         			#LogInfo "Already installed: $($Package.DisplayName)"
          		}
           	}

           	#LogInfo "Package scan complete: $($MissingPackages.Count) missing, $InstalledCount installed, $ExcludedCount excluded"
           	return $MissingPackages | Sort-Object -Property DisplayName
            }

            <#
                .SYNOPSIS
                Runs check box for all users click.

                
.DESCRIPTION
                
Supports check box for all users click handling inside Baseline.
            #>

            function CheckBoxForAllUsersClick
            {
                $PanelContainer.Children.Clear()
                $PackagesToInstall.Clear()
                $MissingPackages = Get-MissingAppxPackages -AllUsers:$CheckBoxForAllUsers.IsChecked
                Add-Control -Packages $MissingPackages -Panel $PanelContainer
                ButtonInstallSetIsEnabled
            }

            <#
                .SYNOPSIS
                Runs button install click.

                
.DESCRIPTION
                
Supports button install click handling inside Baseline.
            #>
            function ButtonInstallClick
            {
           	if ($CollectSelectionOnly)
                {
                    $script:UWPAppsSelectionResult = [PSCustomObject]@{
                        Mode = 'Install'
                        ForAllUsers = [bool]$CheckBoxForAllUsers.IsChecked
                        SelectedPackages = @($PackagesToInstall)
                    }
                    $Window.Close()
                    return
                }

                if (-not $SelectedPackagesProvided)
                {
                    foreach ($popupControl in @($ButtonInstall, $CheckBoxSelectAll, $CheckBoxForAllUsers, $PanelContainer))
                    {
                        if ($null -ne $popupControl)
                        {
                            $popupControl.IsEnabled = $false
                        }
                    }

                    $commandParameters = @{
                        Install = $true
                        ForAllUsers = [bool]$CheckBoxForAllUsers.IsChecked
                        SelectedPackages = @($PackagesToInstall)
                    }

                    if ($modulePath -and (Get-Command -Name 'Start-GuiPopupCommandAsync' -ErrorAction SilentlyContinue))
                    {
                        [void](GUICommon\Start-GuiPopupCommandAsync -Window $Form -ModulePath $modulePath -AdditionalModulePaths @($guiCommonPath) -CommandName 'UWPApps' -CommandParameters $commandParameters)
                        return
                    }
                }

           	$Window.Close()

           	$SuccessfulPackages = [System.Collections.Generic.List[string]]::new()
           	$ManualPackages = [System.Collections.Generic.List[string]]::new()
                $scope = if ($CheckBoxForAllUsers.IsChecked) { "all users" } else { "current user" }

           	# Store URLs for apps that need Store installation
           	$StoreUrls = @{
          		"Microsoft.WindowsCalculator" = "ms-windows-store://pdp/?productid=9WZDNCRFHVN5"
          		"Microsoft.WindowsCamera" = "ms-windows-store://pdp/?productid=9WZDNCRFJBBG"
          		"Microsoft.Windows.Photos" = "ms-windows-store://pdp/?productid=9WZDNCRFJBH4"
          		"DolbyLaboratories.DolbyAccess" = "ms-windows-store://pdp/?productid=9N0866FS04W8"
          		"Microsoft.GamingServices" = "ms-windows-store://pdp/?productid=9MWPM2CQNLHN"
          		"Microsoft.OutlookForWindows" = "ms-windows-store://pdp/?productid=9NRX63209R7B"
          		"MSTeams" = "ms-windows-store://pdp/?productid=XP8BT8DW290MPM"
          		"Microsoft.YourPhone" = "ms-windows-store://pdp/?productid=9NMPJ99VJBWV"
           	}

           	# Winget package mappings
           	$WingetMap = @{
          		"Microsoft.WindowsCalculator" = "Microsoft.WindowsCalculator"
          		"Microsoft.WindowsCamera" = "Microsoft.WindowsCamera"
          		"Microsoft.Windows.Photos" = "Microsoft.Windows.Photos"
          		"Microsoft.OutlookForWindows" = "Microsoft.OutlookForWindows"
          		"MSTeams" = "Microsoft.Teams"
          		"Microsoft.GamingServices" = "Microsoft.GamingServices"
          		"Microsoft.YourPhone" = "Microsoft.YourPhone"
          		"DolbyLaboratories.DolbyAccess" = "DolbyLaboratories.DolbyAccess"
           	}

           	foreach ($PackageName in $PackagesToInstall)
           	{
          		try {
         			# METHOD 1: Check if package files exist and register them
         			$WindowsAppsPath = "$env:ProgramFiles\WindowsApps"
         			$PackageFolders = Get-ChildItem -Path $WindowsAppsPath -Directory -ErrorAction SilentlyContinue |
            				Where-Object {$_.Name -like "*$PackageName*"} |
            				Sort-Object LastWriteTime -Descending

         			$Installed = $false
         			foreach ($Folder in $PackageFolders)
         			{
            				$ManifestPath = Join-Path $Folder.FullName "AppXManifest.xml"
            				if (Test-Path $ManifestPath)
            				{
           					#LogInfo "Found existing package files for $PackageName. Registering..."
           					try {
          						Add-AppxPackage -DisableDevelopmentMode -Register $ManifestPath -ErrorAction Stop
          						Start-Sleep -Seconds 2

          						$VerifyInstall = Get-AppxPackage -Name $PackageName -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
          						if ($VerifyInstall)
          						{
         							$SuccessfulPackages.Add($PackageName)
         							#LogInfo "Successfully registered $PackageName for $scope"
         							$Installed = $true
         							break
          						}
           					}
           					catch {
          						if ($_.Exception.Message -like "*0x80073D02*")
          						{
         							#LogInfo "$PackageName registration failed - system components in use"
         							$ManualPackages.Add($PackageName)
         							$Installed = $true
         							break
          						}
           					}
                    	}
         			}

         			if ($Installed) { continue }

         			# METHOD 2: Try provisioned packages
         			#LogInfo "Checking provisioned packages for $PackageName..."
         			$Provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            				Where-Object {$_.DisplayName -eq $PackageName -or $_.PackageName -like "*$PackageName*"}

         			if ($Provisioned)
         			{
           				try {
           					Add-AppxProvisionedPackage -Online -PackageName $Provisioned.PackageName -SkipLicense -ErrorAction Stop | Out-Null
           					Start-Sleep -Seconds 3

           					$VerifyInstall = Get-AppxPackage -Name $PackageName -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
           					if ($VerifyInstall)
           					    {
              						$SuccessfulPackages.Add($PackageName)
              						#LogInfo "Successfully installed $PackageName for $scope"
              						continue
           					    }
                            }
            				catch {
           					LogWarning "Provisioned package installation did not complete for $PackageName. Trying other recovery methods."
            				}
         			}

         			# METHOD 3: Try winget
         			#LogInfo "Trying winget for $PackageName..."
         			$WingetPath = Get-Command winget -ErrorAction SilentlyContinue
         			if ($WingetPath)
         			{
            				$WingetID = $WingetMap[$PackageName]
           				if ($WingetID)
            				{
           					if ($CheckBoxForAllUsers.IsChecked)
           					{
          						$WingetProcess = Start-Process -FilePath "winget" -ArgumentList "install --exact --id $WingetID --scope machine --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -ErrorAction Stop
           					}
           					else
           					{
          						$WingetProcess = Start-Process -FilePath "winget" -ArgumentList "install --exact --id $WingetID --scope user --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -ErrorAction Stop
           					}

								if ($WingetProcess.ExitCode -ne 0)
								{
									LogWarning "winget failed to install $PackageName with exit code $($WingetProcess.ExitCode). Trying other recovery methods."
								}

           					Start-Sleep -Seconds 5
           					$AfterWinget = Get-AppxPackage -Name $PackageName -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

           					if ($AfterWinget)
           					{
          						$SuccessfulPackages.Add($PackageName)
          						#LogInfo "Successfully installed $PackageName for $scope"
          						continue
           					}
                        }
         			}

         			# METHOD 4: Try Microsoft Store as last resort
         			$StoreUrl = $StoreUrls[$PackageName]
         			if ($StoreUrl)
         			{
                            if ($NonInteractive)
                            {
                                LogWarning "$PackageName requires Microsoft Store or manual follow-up in noninteractive mode."
                                $ManualPackages.Add($PackageName)
                                continue
                            }

            				#LogInfo "Opening Microsoft Store for $PackageName. Please install manually..."
            				Start-Process $StoreUrl

            				# Show themed dialog that blocks until user clicks OK
            				$messageText = "Microsoft Store has been opened for $PackageName.`n`nPlease install the app manually, then click OK to continue with the next app."
            				$dialogParams = @{
            					Title = if ($Localization.PSObject.Properties['ManualInstallRequired']) { $Localization.ManualInstallRequired } else { 'Manual Installation Required' }
            					Message = $messageText
            					Buttons = @('OK')
            				}

            				# Pass theme if available
            				if (Test-Path -Path Variable:\Script:CurrentTheme)
            				{
            					$dialogParams['Theme'] = $Script:CurrentTheme
            				}
            				if (Test-Path -Path Function:\Set-ButtonChrome)
            				{
            					$dialogParams['ApplyButtonChrome'] = ${function:Set-ButtonChrome}
            				}
            				if (Test-Path -Path Variable:\Script:CurrentThemeName)
            				{
            					$dialogParams['UseDarkMode'] = ($Script:CurrentThemeName -eq 'Dark')
            				}

            				GUICommon\Show-ThemedDialog @dialogParams

            				Start-Sleep -Seconds 2
            				$AfterStore = Get-AppxPackage -Name $PackageName -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            				if ($AfterStore)
            				{
               					$SuccessfulPackages.Add($PackageName)
               					#LogInfo "Successfully installed $PackageName for $scope"
            				}
            				else
            				{
               					$ManualPackages.Add($PackageName)
               					LogWarning "$PackageName requires manual installation from the Microsoft Store."
            				}
         			}
         			else
         			{
                        LogWarning "$PackageName could not be installed automatically and needs manual follow-up."
            			$ManualPackages.Add($PackageName)
         			}
          		}
          		catch {
         			LogWarning "$PackageName - Installation needs manual follow-up: $($_.Exception.Message)"
         			$ManualPackages.Add($PackageName)
          		}
           	}

            # Log results
            if ($SuccessfulPackages.Count -gt 0)
            {
                foreach ($Package in $SuccessfulPackages)
                {
                    LogInfo "Successfully installed $Package for $scope"
                }
            }

            if ($ManualPackages.Count -gt 0)
            {
                $manualPackageList = $ManualPackages -join ', '
                if ($SuccessfulPackages.Count -gt 0)
                {
                    $message = "Partial success: Installed $($SuccessfulPackages.Count) selected UWP app(s) for $scope, but $($ManualPackages.Count) still need Microsoft Store or manual follow-up: $manualPackageList."
                    LogWarning $message
                    Set-UWPAppsExecutionResult -Outcome Partial -Message $message
                    return
                }

                $message = "Failed to install selected UWP apps for $scope. Microsoft Store or manual follow-up is still needed for: $manualPackageList."
                LogError $message
                Set-UWPAppsExecutionResult -Outcome Failed -Message $message
                return
            }

            $message = "Installed $($SuccessfulPackages.Count) selected UWP app(s) for $scope."
            LogInfo $message
            Set-UWPAppsExecutionResult -Outcome Success -Message $message
        }

            <#
                .SYNOPSIS
                Adds control.

                
.DESCRIPTION
                
Supports control handling inside Baseline.
            #>

            function Add-Control
            {
           	param($Packages, $Panel)

            $selectionSeed = @($script:UWPAppsSelectionSeed)
            $useSelectionSeed = ($selectionSeed.Count -gt 0)

           	foreach ($Package in $Packages)
           	{
          		$CheckBox = New-Object System.Windows.Controls.CheckBox
          		$CheckBox.Tag = $Package.PackageFullName
          		$CheckBox.IsChecked = $(if ($useSelectionSeed) { $Package.PackageFullName -in $selectionSeed } else { $true })
          		$CheckBox.Margin = "5,5,5,5"
          		$CheckBox.VerticalAlignment = "Center"

          		$LabelPanel = New-Object System.Windows.Controls.StackPanel
          		$LabelPanel.Orientation = "Horizontal"
          		$LabelPanel.VerticalAlignment = "Center"

          		$IconBlock = New-Object System.Windows.Controls.TextBlock
          		$IconBlock.Text = [char]0xF4A5
          		$IconBlock.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
          		$IconBlock.FontSize = 14
          		$IconBlock.VerticalAlignment = "Center"
          		$IconBlock.Margin = "0,0,6,0"
          		[void]$LabelPanel.Children.Add($IconBlock)

          		$TextBlock = New-Object System.Windows.Controls.TextBlock
          		$TextBlock.Text = $Package.DisplayName
          		$TextBlock.Margin = "5,5,5,5"
          		$TextBlock.VerticalAlignment = "Center"
          		[void]$LabelPanel.Children.Add($TextBlock)

          		$StackPanel = New-Object System.Windows.Controls.StackPanel
          		$StackPanel.Orientation = "Horizontal"
          		$StackPanel.Margin = "2,2,2,2"
          		$StackPanel.Children.Add($CheckBox) | Out-Null
          		$StackPanel.Children.Add($LabelPanel) | Out-Null

          		$Panel.Children.Add($StackPanel) | Out-Null
                if ($CheckBox.IsChecked)
                {
          		    $PackagesToInstall.Add($Package.PackageFullName) | Out-Null
                }

          		$CheckBox.Add_Click({CheckBoxClick})
           	}
        }

            <#
                .SYNOPSIS
                Runs check box click.

                
.DESCRIPTION
                
Supports check box click handling inside Baseline.
            #>

            function CheckBoxClick
            {
           	$CheckBox = $_.Source
           	if ($CheckBox.IsChecked)
           	{
          		$PackagesToInstall.Add($CheckBox.Tag) | Out-Null
           	}
           	else
           	{
          		$PackagesToInstall.Remove($CheckBox.Tag)
           	}
           	ButtonInstallSetIsEnabled
            }

            <#
                .SYNOPSIS
                Runs check box select all click.

                
.DESCRIPTION
                
Supports check box select all click handling inside Baseline.
            #>

            function CheckBoxSelectAllClick
            {
           	$CheckBox = $_.Source

           	if ($CheckBox.IsChecked)
           	{
          		$PackagesToInstall.Clear()
          		foreach ($Item in $PanelContainer.Children)
          		{
         			$ChildCheckBox = $Item.Children[0]
         			$ChildCheckBox.IsChecked = $true
         			$PackagesToInstall.Add($ChildCheckBox.Tag) | Out-Null
          		}
           	}
           	else
           	{
          		$PackagesToInstall.Clear()
          		foreach ($Item in $PanelContainer.Children)
          		{
         			$Item.Children[0].IsChecked = $false
          		}
           	}
           	ButtonInstallSetIsEnabled
            }

            <#
                .SYNOPSIS
                Runs button install set is enabled.

                
.DESCRIPTION
                
Supports button install set is enabled handling inside Baseline.
            #>

            function ButtonInstallSetIsEnabled
            {
           	$ButtonInstall.IsEnabled = ($PackagesToInstall.Count -gt 0)
            }
            #endregion Functions

            # Check "For all users" checkbox if specified
            if ($ForAllUsers)
            {
           	$CheckBoxForAllUsers.IsChecked = $true
            }

            $PackagesToInstall = [System.Collections.Generic.List[string]]::new()
            $MissingPackages = Get-MissingAppxPackages -AllUsers:$ForAllUsers

            if ($MissingPackages.Count -eq 0)
            {
           	LogWarning "Skipping UWP app install because no apps were missing for the chosen scope."
                if (-not $CollectSelectionOnly)
                {
                    Write-ConsoleStatus -Status warning
                }
                if ($CollectSelectionOnly)
                {
                    return [PSCustomObject]@{
                        Mode = 'Install'
                        ForAllUsers = [bool]$ForAllUsers
                        SelectedPackages = @()
                    }
                }
                return
            }
            else
            {
           	Add-Control -Packages $MissingPackages -Panel $PanelContainer

           	if ($PackagesToInstall.Count -gt 0)
	{
		$ButtonInstall.IsEnabled = $true
	}

    if ($SelectedPackagesProvided -and -not $CollectSelectionOnly)
    {
        $Window = New-Object psobject
        $Window | Add-Member -MemberType ScriptMethod -Name Close -Value { return $null } -Force
        $CheckBoxForAllUsers = [pscustomobject]@{ IsChecked = [bool]$ForAllUsers }
        $PackagesToInstall.Clear()
        foreach ($selectedPackage in @($SelectedPackages))
        {
            if (-not [string]::IsNullOrWhiteSpace([string]$selectedPackage))
            {
                $PackagesToInstall.Add([string]$selectedPackage) | Out-Null
            }
        }
        if ($PackagesToInstall.Count -gt 0)
        {
            ButtonInstallClick
        }
    }
    elseif ($Global:GUIMode -and -not $CollectSelectionOnly)
    {
        # GUI-mode runs collect the package selection on the main UI thread when this tweak starts.
    }
    else
    {
	    try
	    {
		    Initialize-WpfWindowForeground -Window $Form
		    $Form.ShowDialog() | Out-Null
	    }
	    catch
	    {
		    LogError "Install UWP Apps dialog failed to open: $($_.Exception.Message)"
            if (-not $CollectSelectionOnly)
            {
		        Write-ConsoleStatus -Status failed
            }
		    return
	    }
    }
    }
    if ($Form.PSObject.Properties['GuiPopupOperationError'] -and $Form.GuiPopupOperationError)
    {
        $operationError = $Form.GuiPopupOperationError
        Remove-HandledErrorRecord -ErrorRecord $operationError
        LogError "Failed to install UWP apps: $($operationError.Exception.Message)"
        Write-ConsoleStatus -Status failed
        throw $operationError
    }
    if ($Form.PSObject.Properties['GuiPopupOperationResult'] -and $Form.GuiPopupOperationResult)
    {
        $script:UWPAppsExecutionResult = $Form.GuiPopupOperationResult
    }
    if ($CollectSelectionOnly)
    {
        return $script:UWPAppsSelectionResult
    }
    if ($null -eq $script:UWPAppsExecutionResult)
    {
        LogWarning "Skipping UWP app install because no packages were confirmed."
        Write-ConsoleStatus -Status warning
        return
    }
    if ($script:UWPAppsExecutionResult.Outcome -eq 'Success')
    {
        Write-ConsoleStatus -Status success
        return
    }
    Write-ConsoleStatus -Status failed
    throw $script:UWPAppsExecutionResult.Message
}
		"Uninstall"
		{
            if ($Global:GUIMode -and -not $CollectSelectionOnly -and -not $SelectedPackagesProvided)
            {
                $selectionResult = Request-GuiUWPAppsSelection -Mode 'Uninstall' -ForAllUsersSelection ([bool]$ForAllUsers) -SeedPackages @($SelectedPackages)
                if ($null -ne $selectionResult)
                {
                    $ForAllUsers = [bool]$selectionResult.ForAllUsers
                    $SelectedPackages = @($selectionResult.SelectedPackages)
                    $script:UWPAppsSelectionSeed = @($SelectedPackages)
                    $SelectedPackagesProvided = $true
                }
            }

            if ($NonInteractive -and -not $SelectedPackagesProvided)
            {
                Write-ConsoleStatus -Action "Uninstalling UWP apps"
                LogWarning "Skipping UWP app uninstall because no preselected packages were provided for noninteractive execution."
                Write-ConsoleStatus -Status warning
                return
            }

			# Show the app picker and remove the packages the user selects.
			Add-Type -AssemblyName PresentationCore, PresentationFramework
            if (-not $CollectSelectionOnly)
            {
			    Write-ConsoleStatus -Action "Uninstalling UWP apps"
			    LogInfo "Uninstalling UWP apps:"
            }
			#region Variables
			# The following UWP apps will have their checkboxes unchecked
			$UncheckedAppxPackages = @(
				# Dolby Access
				"DolbyLaboratories.DolbyAccess",

				# Windows Media Player
				"Microsoft.ZuneMusic",

				# Screen Sketch
				"Microsoft.ScreenSketch",

				# Photos (and Video Editor)
				"Microsoft.Windows.Photos",
				"Microsoft.Photos.MediaEngineDLC",

				# Calculator
				"Microsoft.WindowsCalculator",

				# Windows Camera
				"Microsoft.WindowsCamera",

				# Microsoft Teams
				"MSTeams",

				# Xbox Identity Provider
				"Microsoft.XboxIdentityProvider",

				# Xbox Console Companion
				"Microsoft.XboxApp",

				# Xbox
				"Microsoft.GamingApp",
				"Microsoft.GamingServices",

				# Paint
				"Microsoft.Paint",

				# Xbox TCUI
				"Microsoft.Xbox.TCUI",

				# Xbox Speech To Text Overlay
				"Microsoft.XboxSpeechToTextOverlay",

				# Game Bar
				"Microsoft.XboxGamingOverlay",

				# Game Bar Plugin
				"Microsoft.XboxGameOverlay"
			)

			# The following UWP apps will be excluded from the display
			$ExcludedAppxPackages = @(
				# AMD Radeon Software
				"AdvancedMicroDevicesInc-2.AMDRadeonSoftware",

				# Intel Graphics Control Center
				"AppUp.IntelGraphicsControlPanel",
				"AppUp.IntelGraphicsExperience",

				# ELAN Touchpad
				"ELANMicroelectronicsCorpo.ELANTouchpadforThinkpad",
				"ELANMicroelectronicsCorpo.ELANTrackPointforThinkpa",

				# Microsoft Application Compatibility Enhancements
				"Microsoft.ApplicationCompatibilityEnhancements",

				# AVC Encoder Video Extension
				"Microsoft.AVCEncoderVideoExtension",

				# Microsoft Desktop App Installer
				"Microsoft.DesktopAppInstaller",

				# Store Experience Host
				"Microsoft.StorePurchaseApp",

				# Cross Device Experience Host
				"MicrosoftWindows.CrossDevice",

				# Notepad
				"Microsoft.WindowsNotepad",

				# Microsoft Store
				"Microsoft.WindowsStore",

				# Windows Terminal
				"Microsoft.WindowsTerminal",
				"Microsoft.WindowsTerminalPreview",

				# Web Media Extensions
				"Microsoft.WebMediaExtensions",

				# AV1 Video Extension
				"Microsoft.AV1VideoExtension",

				# Windows Subsystem for Linux
				"MicrosoftCorporationII.WindowsSubsystemForLinux",

				# HEVC Video Extensions from Device Manufacturer
				"Microsoft.HEVCVideoExtension",
				"Microsoft.HEVCVideoExtensions",

				# Raw Image Extension
				"Microsoft.RawImageExtension",

				# HEIF Image Extensions
				"Microsoft.HEIFImageExtension",

				# MPEG-2 Video Extension
				"Microsoft.MPEG2VideoExtension",

				# VP9 Video Extensions
				"Microsoft.VP9VideoExtensions",

				# Webp Image Extensions
				"Microsoft.WebpImageExtension",

				# PowerShell
				"Microsoft.PowerShell",

				# NVIDIA Control Panel
				"NVIDIACorp.NVIDIAControlPanel",

				# Realtek Audio Console
				"RealtekSemiconductorCorp.RealtekAudioControl",

				# Synaptics
				"SynapticsIncorporated.SynapticsControlPanel",
				"SynapticsIncorporated.24916F58D6E7"
			)

			#region XAML Markup
			# This block defines the dialog XAML used at runtime.
			[xml]$XAML = @"
			<Window
				xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
				xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
				Name="Window"
				MinHeight="400" MinWidth="415" MaxHeight="700"
				SizeToContent="Width" WindowStartupLocation="CenterScreen"
				TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
				FontFamily="FluentSystemIcons" FontSize="12" ShowInTaskbar="True"
				Background="Transparent" AllowsTransparency="True" WindowStyle="None">
				<Window.Resources>
					<Style TargetType="CheckBox">
						<Setter Property="IsChecked" Value="True"/>
					</Style>
					<Style TargetType="Button">
						<Setter Property="Margin" Value="20"/>
						<Setter Property="Padding" Value="10"/>
						<Setter Property="IsEnabled" Value="False"/>
					</Style>
					<Style TargetType="Border">
						<Setter Property="Grid.Row" Value="1"/>
						<Setter Property="CornerRadius" Value="0"/>
						<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
					</Style>
					<Style TargetType="ScrollViewer">
						<Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
						<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
					</Style>
				</Window.Resources>
				<Border Name="RootBorder" CornerRadius="8" Padding="0">
				<Grid>
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
						<RowDefinition Height="Auto"/>
					</Grid.RowDefinitions>
					<Grid Grid.Row="0" Margin="10,8,10,8">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="*"/>
							<ColumnDefinition Width="Auto"/>
						</Grid.ColumnDefinitions>
						<StackPanel Name="PanelSelectAll" Grid.Column="0" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
							<CheckBox Name="CheckBoxSelectAll" IsChecked="False" VerticalAlignment="Center" Margin="0,0,6,0"/>
							<TextBlock Name="TextBlockSelectAll" VerticalAlignment="Center"/>
						</StackPanel>
						<StackPanel Name="PanelRemoveForAll" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
							<TextBlock Name="TextBlockRemoveForAll" VerticalAlignment="Center" Margin="0,0,6,0"/>
							<CheckBox Name="CheckBoxForAllUsers" IsChecked="False" VerticalAlignment="Center"/>
						</StackPanel>
					</Grid>
					<Border>
						<ScrollViewer>
							<StackPanel Name="PanelContainer" Orientation="Vertical" Margin="10,6,10,6"/>
						</ScrollViewer>
					</Border>
					<Button Name="ButtonUninstall" Grid.Row="2"/>
				</Grid>
				</Border>
			</Window>
"@
			#endregion XAML Markup

			$Form = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAML))
			$XAML.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
				Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
			}

			# Apply shared window chrome theming
			$bc = New-Object System.Windows.Media.BrushConverter
			$currentTheme = if (Test-Path -Path Variable:\Script:CurrentTheme) { $Script:CurrentTheme } else { @{} }
			$isDarkMode = if (Test-Path -Path Variable:\Script:CurrentThemeName) { $Script:CurrentThemeName -eq 'Dark' } else { $false }

			# Apply window chrome theme
				if (Test-Path -Path Function:\Set-GuiWindowChromeTheme)
				{
					[void](GUICommon\Set-GuiWindowChromeTheme -Window $Form -UseDarkMode:$isDarkMode)
				}

				$RootBorder = $Form.FindName("RootBorder")
				Set-UWPAppsPickerSurface -Window $Form -RootBorder $RootBorder -PanelContainer $PanelContainer -Theme $currentTheme -BrushConverter $bc -UseDarkMode $isDarkMode

				$Window.Title               = $Localization.UWPAppsTitle
				if (Test-Path -Path Function:\Add-GuiPopupWindowChrome)
				{
					[void](GUICommon\Add-GuiPopupWindowChrome -Window $Form -RootBorder $RootBorder -PanelContainer $PanelContainer -Theme $currentTheme -UseDarkMode $isDarkMode)
				}
				$ButtonUninstall.Content    = $Localization.Uninstall
			$TextBlockRemoveForAll.Text = $Localization.UninstallUWPForAll
			$TextBlockSelectAll.Text    = $Localization.GuiSelectAll

			$ButtonUninstall.Add_Click({ButtonUninstallClick})
			$CheckBoxForAllUsers.Add_Click({CheckBoxForAllUsersClick})
			$CheckBoxSelectAll.Add_Click({CheckBoxSelectAllClick})
			#endregion Variables

			#region Functions
			function Get-AppxBundle
			{
							<#
							    .SYNOPSIS
							    Return installed Appx bundle packages for the current scope.

							    .DESCRIPTION
							    Collects installed bundle packages, adds the manual package checks Baseline needs, and filters out excluded names.

							    .PARAMETER Exclude
							    Package names to exclude from the returned list.

							    .PARAMETER AllUsers
							    Query packages across all users.

							    .EXAMPLE
							    Get-AppxBundle -AllUsers -Exclude 'Microsoft.XboxApp'
							#>
				[CmdletBinding()]
				param
				(
					[string[]]
					$Exclude,

					[switch]
					$AllUsers
				)

				$AppxPackages = @(Get-AppxPackage -PackageTypeFilter Bundle -AllUsers:$AllUsers -WarningAction SilentlyContinue | Where-Object -FilterScript {$_.Name -notin $ExcludedAppxPackages})

				# The -PackageTypeFilter Bundle doesn't contain these packages, and we need to add manually
				$Packages = @(
					# Outlook
					"Microsoft.OutlookForWindows",

					# Microsoft Teams
					"MSTeams"
				)
				foreach ($Package in $Packages)
				{
					if (Get-AppxPackage -Name $Package -AllUsers:$AllUsers -WarningAction SilentlyContinue)
					{
						$AppxPackages += Get-AppxPackage -Name $Package -AllUsers:$AllUsers -WarningAction SilentlyContinue
					}
				}

				$PackagesIds = [Windows.Management.Deployment.PackageManager, Windows.Web, ContentType = WindowsRuntime]::new().FindPackages() | Select-Object -Property DisplayName -ExpandProperty Id | Select-Object -Property Name, DisplayName
				foreach ($AppxPackage in $AppxPackages)
				{
					$PackageId = $PackagesIds | Where-Object -FilterScript {$_.Name -eq $AppxPackage.Name}
					if (-not $PackageId)
					{
						continue
					}

					[PSCustomObject]@{
						Name            = $AppxPackage.Name
						PackageFullName = $AppxPackage.PackageFullName
						# Sometimes there's more than one package presented in Windows with the same package name like {Microsoft Teams, Microsoft Teams} and we need to display the first one
						DisplayName     = $PackageId.DisplayName | Select-Object -First 1
					}
				}
			}

			# Package names that can be reinstalled via the Install UWP Apps dialog.
			# Apps NOT in this list get a warning label in the Uninstall picker.
			$ReinstallablePackageNames = @(
				'Microsoft.OutlookForWindows'
				'Microsoft.WindowsCalculator'
				'Microsoft.WindowsCamera'
				'Microsoft.Windows.Photos'
				'Microsoft.GamingServices'
				'Microsoft.YourPhone'
				'DolbyLaboratories.DolbyAccess'
				'Microsoft.WindowsSoundRecorder'
			)

			<#
			    .SYNOPSIS
			    Creates UWP apps info icon.

			    
.DESCRIPTION
			    
Supports UWP apps info icon handling inside Baseline.
			#>

			function New-UwpAppsInfoIcon
			{
				param (
					[string]$TooltipText
				)

				$icon = New-Object -TypeName System.Windows.Controls.TextBlock
				$icon.Text = [char]0x24D8  # info icon
				$icon.FontFamily = [System.Windows.Media.FontFamily]::new('Segoe UI Symbol')
				$icon.FontSize = 14
				$icon.Foreground = [System.Windows.Media.Brushes]::DodgerBlue
				$icon.VerticalAlignment = 'Center'
				$icon.Margin = [System.Windows.Thickness]::new(0, 0, 4, 0)
				$icon.Cursor = [System.Windows.Input.Cursors]::Arrow
				$icon.ToolTip = $(if ([string]::IsNullOrWhiteSpace($TooltipText)) { 'This item has extra information.' } else { $TooltipText })
				[System.Windows.Controls.ToolTipService]::SetPlacement($icon, [System.Windows.Controls.Primitives.PlacementMode]::Right)
				[System.Windows.Controls.ToolTipService]::SetShowDuration($icon, 20000)
				[System.Windows.Controls.ToolTipService]::SetInitialShowDelay($icon, 150)
				return $icon
			}

			<#
			    .SYNOPSIS
			    Adds control.

			    
.DESCRIPTION
			    
Supports control handling inside Baseline.
			#>

			function Add-Control
			{
				[CmdletBinding()]
				param
				(
					[Parameter(
						Mandatory = $true,
						ValueFromPipeline = $true
					)]
					[ValidateNotNull()]
					[PSCustomObject[]]
					$Packages
				)

				process
				{
                    $selectionSeed = @($script:UWPAppsSelectionSeed)
                    $useSelectionSeed = ($selectionSeed.Count -gt 0)
					foreach ($Package in $Packages)
					{
						$CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
						$CheckBox.Tag = $Package.PackageFullName
						$CheckBox.VerticalAlignment = 'Center'
						$CheckBox.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

						$LabelPanel = New-Object -TypeName System.Windows.Controls.StackPanel
						$LabelPanel.Orientation = 'Horizontal'
						$LabelPanel.VerticalAlignment = 'Center'
						$LabelPanel.HorizontalAlignment = 'Stretch'

						$IconBlock = New-Object -TypeName System.Windows.Controls.TextBlock
						$IconBlock.Text = [char]0xF4A5
						$IconBlock.FontFamily = [System.Windows.Media.FontFamily]::new('FluentSystemIcons')
						$IconBlock.FontSize = 14
						$IconBlock.VerticalAlignment = 'Center'
						$IconBlock.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
						[void]$LabelPanel.Children.Add($IconBlock)

						$TextBlock = New-Object -TypeName System.Windows.Controls.TextBlock
						$TextBlock.VerticalAlignment = 'Center'
						$TextBlock.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)

						if ($Package.DisplayName)
						{
							$TextBlock.Text = $Package.DisplayName
						}
						else
						{
							$TextBlock.Text = $Package.Name
						}

						[void]$LabelPanel.Children.Add($TextBlock)

						$rowPanel = New-Object -TypeName System.Windows.Controls.DockPanel
						$rowPanel.LastChildFill = $true
						$rowPanel.HorizontalAlignment = 'Stretch'
						$rowPanel.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)

						[System.Windows.Controls.DockPanel]::SetDock($CheckBox, [System.Windows.Controls.Dock]::Left)
						[void]$rowPanel.Children.Add($CheckBox)

						# Warn if the app cannot be reinstalled via the Install dialog
						if ($Package.Name -notin $ReinstallablePackageNames)
						{
							$warningPanel = New-Object -TypeName System.Windows.Controls.StackPanel
							$warningPanel.Orientation = 'Horizontal'
							$warningPanel.VerticalAlignment = 'Center'
							$warningPanel.HorizontalAlignment = 'Right'
						$warningPanel.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)

							$infoIcon = New-UwpAppsInfoIcon -TooltipText 'This app cannot be reinstalled from the Microsoft Store.'
							if ($infoIcon)
							{
								$warningPanel.Children.Add($infoIcon) | Out-Null
							}

							$warnTb = New-Object -TypeName System.Windows.Controls.TextBlock
							$warnTb.Text = if ($Localization.PSObject.Properties['Warning']) { $Localization.Warning } else { 'Warning' }
							$warnTb.Foreground = [System.Windows.Media.Brushes]::IndianRed
							$warnTb.FontSize = 12
							$warnTb.FontWeight = [System.Windows.FontWeights]::SemiBold
							$warnTb.VerticalAlignment = 'Center'
							$warnTb.ToolTip = if ($Localization.PSObject.Properties['UWPNoReinstallWarning']) { $Localization.UWPNoReinstallWarning } else { 'This app cannot be reinstalled from the Microsoft Store.' }
							$warningPanel.Children.Add($warnTb) | Out-Null

							[System.Windows.Controls.DockPanel]::SetDock($warningPanel, [System.Windows.Controls.Dock]::Right)
							[void]$rowPanel.Children.Add($warningPanel)
						}

						[void]$rowPanel.Children.Add($LabelPanel)
						$PanelContainer.Children.Add($rowPanel) | Out-Null

						if ($useSelectionSeed)
                        {
                            $CheckBox.IsChecked = ($Package.PackageFullName -in $selectionSeed)
                            if ($CheckBox.IsChecked)
                            {
                                $PackagesToRemove.Add($Package.PackageFullName)
                            }
                        }
                        elseif ($UncheckedAppxPackages.Contains($Package.Name))
						{
							$CheckBox.IsChecked = $false
						}
						else
						{
							$CheckBox.IsChecked = $true
							$PackagesToRemove.Add($Package.PackageFullName)
						}

						$CheckBox.Add_Click({CheckBoxClick})
					}
				}
			}

			<#
			    .SYNOPSIS
			    Runs check box for all users click.

			    
.DESCRIPTION
			    
Supports check box for all users click handling inside Baseline.
			#>

			function CheckBoxForAllUsersClick
			{
				$PanelContainer.Children.RemoveRange(0, $PanelContainer.Children.Count)
				$PackagesToRemove.Clear()
				$AppXPackages = Get-AppxBundle -Exclude $ExcludedAppxPackages -AllUsers:$CheckBoxForAllUsers.IsChecked
				$AppXPackages | Add-Control

				ButtonUninstallSetIsEnabled
			}

			<#
			    .SYNOPSIS
			    Runs button uninstall click.

			    
.DESCRIPTION
			    
Supports button uninstall click handling inside Baseline.
			#>
			function ButtonUninstallClick
			{
                if ($CollectSelectionOnly)
                {
                    $script:UWPAppsSelectionResult = [PSCustomObject]@{
                        Mode = 'Uninstall'
                        ForAllUsers = [bool]$CheckBoxForAllUsers.IsChecked
                        SelectedPackages = @($PackagesToRemove)
                    }
                    $Window.Close() | Out-Null
                    return
                }

                if (-not $SelectedPackagesProvided)
                {
                    foreach ($popupControl in @($ButtonUninstall, $CheckBoxSelectAll, $CheckBoxForAllUsers, $PanelContainer))
                    {
                        if ($null -ne $popupControl)
                        {
                            $popupControl.IsEnabled = $false
                        }
                    }

                    $commandParameters = @{
                        Uninstall = $true
                        ForAllUsers = [bool]$CheckBoxForAllUsers.IsChecked
                        SelectedPackages = @($PackagesToRemove)
                    }

                    if ($modulePath -and (Get-Command -Name 'Start-GuiPopupCommandAsync' -ErrorAction SilentlyContinue))
                    {
                        [void](GUICommon\Start-GuiPopupCommandAsync -Window $Form -ModulePath $modulePath -AdditionalModulePaths @($guiCommonPath) -CommandName 'UWPApps' -CommandParameters $commandParameters)
                        return
                    }
                }

				$Window.Close() | Out-Null
                $RemovedPackages = [System.Collections.Generic.List[string]]::new()
                $FailedPackages = [System.Collections.Generic.List[string]]::new()
                $AncillaryIssues = [System.Collections.Generic.List[string]]::new()
                $scope = if ($CheckBoxForAllUsers.IsChecked) { 'all users' } else { 'current user' }

				# If MSTeams is selected to uninstall, delete quietly "Microsoft Teams Meeting Add-in for Microsoft Office" too
				# & "$env:SystemRoot\System32\msiexec.exe" --% /x {A7AB73A3-CB10-4AA5-9D38-6AEFFBDE4C91} /qn
				if ($PackagesToRemove -match "MSTeams")
				{
                    try
                    {
					    $MSIProcess = Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x {A7AB73A3-CB10-4AA5-9D38-6AEFFBDE4C91} /qn" -PassThru -WindowStyle Hidden -ErrorAction Stop
						$teamsRemovalFinished = $MSIProcess.WaitForExit(60000)
						if (-not $teamsRemovalFinished)
						{
							LogWarning "Teams Meeting Add-in removal timed out and needs manual follow-up."
                            $AncillaryIssues.Add('Teams Meeting Add-in')
							$MSIProcess.Kill()
						}
					    elseif ($MSIProcess.ExitCode -ne 0)
					    {
						    LogWarning "Teams Meeting Add-in removal returned exit code $($MSIProcess.ExitCode) and needs manual follow-up."
                            $AncillaryIssues.Add('Teams Meeting Add-in')
					    }
                    }
                    catch
                    {
                        LogWarning "Teams Meeting Add-in removal needs manual follow-up: $($_.Exception.Message)"
                        $AncillaryIssues.Add('Teams Meeting Add-in')
                    }
				}

                foreach ($Package in $PackagesToRemove)
				{
                    $PackageDisplayName = ([string]$Package).Split('_')[0]
                    try
                    {
				        Invoke-SilencedProgress {
						    Remove-AppxPackage -Package $Package -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction Stop
				        }

                        Start-Sleep -Milliseconds 500
                        $RemainingPackage = Get-AppxPackage -AllUsers:$CheckBoxForAllUsers.IsChecked -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |
                            Where-Object -FilterScript { $_.PackageFullName -eq $Package }
                        if ($RemainingPackage)
                        {
                            throw "Package still appears to be installed after the removal attempt."
                        }

                        $RemovedPackages.Add($PackageDisplayName)
                        LogInfo "Successfully removed $PackageDisplayName for $scope"
                    }
                    catch
                    {
                        $FailedPackages.Add($PackageDisplayName)
                        LogError "$PackageDisplayName - Removal failed: $($_.Exception.Message)"
                    }
				}

                if ($FailedPackages.Count -gt 0 -or $AncillaryIssues.Count -gt 0)
                {
                    $issueParts = @()
                    if ($FailedPackages.Count -gt 0)
                    {
                        $issueParts += "failed to remove: $($FailedPackages -join ', ')"
                    }
                    if ($AncillaryIssues.Count -gt 0)
                    {
                        $issueParts += "manual cleanup is still needed for: $($AncillaryIssues -join ', ')"
                    }

                    if ($RemovedPackages.Count -gt 0)
                    {
                        $message = "Partial success: Removed $($RemovedPackages.Count) selected UWP app(s) for $scope, but $($issueParts -join '; ')."
                        LogWarning $message
                        Set-UWPAppsExecutionResult -Outcome Partial -Message $message
                        return
                    }

                    $message = "Failed to remove selected UWP apps for $scope. $($issueParts -join '; ')."
                    LogError $message
                    Set-UWPAppsExecutionResult -Outcome Failed -Message $message
                    return
                }

                $message = "Removed $($RemovedPackages.Count) selected UWP app(s) for $scope."
                LogInfo $message
                Set-UWPAppsExecutionResult -Outcome Success -Message $message
			}

			<#
			    .SYNOPSIS
			    Runs check box click.

			    
.DESCRIPTION
			    
Supports check box click handling inside Baseline.
			#>

			function CheckBoxClick
			{
				$CheckBox = $_.Source

				if ($CheckBox.IsChecked)
				{
					$PackagesToRemove.Add($CheckBox.Tag) | Out-Null
				}
				else
				{
					$PackagesToRemove.Remove($CheckBox.Tag)
				}

				ButtonUninstallSetIsEnabled
			}

			<#
			    .SYNOPSIS
			    Runs check box select all click.

			    
.DESCRIPTION
			    
Supports check box select all click handling inside Baseline.
			#>

			function CheckBoxSelectAllClick
			{
				$CheckBox = $_.Source

				if ($CheckBox.IsChecked)
				{
					$PackagesToRemove.Clear()

					foreach ($Item in $PanelContainer.Children)
					{
						foreach ($Child in $Item.Children)
						{
							if ($Child -is [System.Windows.Controls.CheckBox])
							{
								$Child.IsChecked = $true
								$PackagesToRemove.Add($Child.Tag)
							}
						}
					}
				}
				else
				{
					$PackagesToRemove.Clear()

					foreach ($Item in $PanelContainer.Children)
					{
						foreach ($Child in $Item.Children)
						{
							if ($Child -is [System.Windows.Controls.CheckBox])
							{
								$Child.IsChecked = $false
							}
						}
					}
				}

				ButtonUninstallSetIsEnabled
			}

			<#
			    .SYNOPSIS
			    Runs button uninstall set is enabled.

			    
.DESCRIPTION
			    
Supports button uninstall set is enabled handling inside Baseline.
			#>

			function ButtonUninstallSetIsEnabled
			{
				if ($PackagesToRemove.Count -gt 0)
				{
					$ButtonUninstall.IsEnabled = $true
				}
				else
				{
					$ButtonUninstall.IsEnabled = $false
				}
			}
			#endregion Functions

			# Check "For all users" checkbox to uninstall packages from all accounts
			if ($ForAllUsers)
			{
				$CheckBoxForAllUsers.IsChecked = $true
			}

			$PackagesToRemove = [Collections.Generic.List[string]]::new()
			$AppXPackages = Get-AppxBundle -Exclude $ExcludedAppxPackages -AllUsers:$ForAllUsers
			$AppXPackages | Add-Control

			if ($AppXPackages.Count -eq 0)
			{
				LogWarning "Skipping UWP app uninstall because no apps were available for the chosen scope."
                if (-not $CollectSelectionOnly)
                {
                    Write-ConsoleStatus -Status warning
                }
                if ($CollectSelectionOnly)
                {
                    return [PSCustomObject]@{
                        Mode = 'Uninstall'
                        ForAllUsers = [bool]$ForAllUsers
                        SelectedPackages = @()
                    }
                }
                return
			}
			else
			{
				#region Sendkey function
				# Emulate the Backspace key sending to prevent the console window to freeze
				Start-Sleep -Milliseconds 500

				Add-Type -AssemblyName System.Windows.Forms

				$canUseForegroundInterop = $false
				try
				{
					Initialize-ForegroundWindowInterop
					$canUseForegroundInterop = [bool]("WinAPI.ForegroundWindow" -as [type])
				}
				catch
				{
					$canUseForegroundInterop = $false
				}

				# We cannot use Get-Process -Id $PID as script might be invoked via Terminal with different $PID
				Get-Process -Name Baseline, powershell, WindowsTerminal -ErrorAction Ignore | Where-Object -FilterScript {$_.MainWindowTitle -match "Baseline \| Utility for Windows"} | ForEach-Object -Process {
					if ($canUseForegroundInterop -and $_.MainWindowHandle -ne [System.IntPtr]::Zero)
					{
						try
						{
							# Show window, if minimized
							[WinAPI.ForegroundWindow]::ShowWindowAsync($_.MainWindowHandle, 10) | Out-Null
						}
						catch
						{
							# Allow the dialog to continue even if the foreground helper is unavailable.
						}
					}

					Start-Sleep -Seconds 1

					if ($canUseForegroundInterop -and $_.MainWindowHandle -ne [System.IntPtr]::Zero)
					{
						try
						{
							# Force move the console window to the foreground
							[WinAPI.ForegroundWindow]::SetForegroundWindow($_.MainWindowHandle) | Out-Null
						}
						catch
						{
							# Allow the dialog to continue even if the foreground helper is unavailable.
						}
					}

					Start-Sleep -Seconds 1

					# Emulate the Backspace key sending to prevent the console window to freeze
					[System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE 1}")
				}
				#endregion Sendkey function

				if ($PackagesToRemove.Count -gt 0)
				{
					$ButtonUninstall.IsEnabled = $true
				}

				# Restore minimized dialogs and bring them to the foreground once when shown.
                if ($SelectedPackagesProvided -and -not $CollectSelectionOnly)
                {
                    $Window = New-Object psobject
                    $Window | Add-Member -MemberType ScriptMethod -Name Close -Value { return $null } -Force
                    $CheckBoxForAllUsers = [pscustomobject]@{ IsChecked = [bool]$ForAllUsers }
                    $PackagesToRemove.Clear()
                    foreach ($selectedPackage in @($SelectedPackages))
                    {
                        if (-not [string]::IsNullOrWhiteSpace([string]$selectedPackage))
                        {
                            $PackagesToRemove.Add([string]$selectedPackage) | Out-Null
                        }
                    }
                    if ($PackagesToRemove.Count -gt 0)
                    {
                        ButtonUninstallClick
                    }
                }
                elseif ($Global:GUIMode -and -not $CollectSelectionOnly)
                {
                    # GUI-mode runs collect the package selection on the main UI thread when this tweak starts.
                }
                else
                {
				    try
				    {
					    Initialize-WpfWindowForeground -Window $Form
					    $Form.ShowDialog() | Out-Null
				    }
				    catch
				    {
					    LogError "Uninstall UWP Apps dialog failed to open: $($_.Exception.Message)"
                        if (-not $CollectSelectionOnly)
                        {
					        Write-ConsoleStatus -Status failed
                        }
					    return
				    }
                }
			}
            if ($Form.PSObject.Properties['GuiPopupOperationError'] -and $Form.GuiPopupOperationError)
            {
                $operationError = $Form.GuiPopupOperationError
                Remove-HandledErrorRecord -ErrorRecord $operationError
                LogError "Failed to uninstall UWP apps: $($operationError.Exception.Message)"
                Write-ConsoleStatus -Status failed
                throw $operationError
            }
            if ($Form.PSObject.Properties['GuiPopupOperationResult'] -and $Form.GuiPopupOperationResult)
            {
                $script:UWPAppsExecutionResult = $Form.GuiPopupOperationResult
            }
            if ($CollectSelectionOnly)
            {
                return $script:UWPAppsSelectionResult
            }
            if ($null -eq $script:UWPAppsExecutionResult)
            {
                LogWarning "Skipping UWP app uninstall because no packages were confirmed."
                Write-ConsoleStatus -Status warning
                return
            }
            if ($script:UWPAppsExecutionResult.Outcome -eq 'Success')
            {
			    Write-ConsoleStatus -Status success
                return
            }
            Write-ConsoleStatus -Status failed
            throw $script:UWPAppsExecutionResult.Message
		}
	}
}

#endregion UWP apps

Export-ModuleMember -Function '*'
