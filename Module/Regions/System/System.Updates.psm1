using module ..\..\Logging.psm1
using module ..\..\SharedHelpers.psm1

<#
	.SYNOPSIS
	Internal admin utility for Windows Update and active-hours settings.

	.PARAMETER Automatically
	Automatically adjust active hours for me based on daily usage

	.PARAMETER Manually
	Manually adjust active hours for me based on daily usage (default value)

	.EXAMPLE
	ActiveHours -Automatically

	.EXAMPLE
	ActiveHours -Manually

	.NOTES
	Machine-wide
#>
function ActiveHours
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Automatically"
		)]
		[switch]
		$Automatically,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Manually"
		)]
		[switch]
		$Manually
	)

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoRebootWithLoggedOnUsers, AlwaysAutoRebootAtScheduledTime -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoRebootWithLoggedOnUsers -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AlwaysAutoRebootAtScheduledTime -Type CLEAR | Out-Null

	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursEnd, ActiveHoursStart, SetActiveHours -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursEnd -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursStart -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name SetActiveHours -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Automatically"
		{
			Write-ConsoleStatus -Action "Automatically adjusting active hours for me based on daily usage"
			LogInfo "Automatically adjusting active hours for me based on daily usage"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name SmartActiveHoursState -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Manually"
		{
			Write-ConsoleStatus -Action "Manually adjusting active hours for me based on daily usage"
			LogInfo "Manually adjusting active hours for me based on daily usage"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name SmartActiveHoursState -PropertyType DWord -Value 0 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Windows latest updates

	.PARAMETER Disable
	Do not get the latest updates as soon as they're available (default value)

	.PARAMETER Enable
	Get the latest updates as soon as they're available

	.EXAMPLE
	WindowsLatestUpdate -Disable

	.EXAMPLE
	WindowsLatestUpdate -Enable

	.NOTES
	Machine-wide
#>
function WindowsLatestUpdate
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

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AllowOptionalContent, SetAllowOptionalContent -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AllowOptionalContent -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name SetAllowOptionalContent -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling getting the latest updates as soon as they're available"
			LogInfo "Disabling getting the latest updates as soon as they're available"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsContinuousInnovationOptedIn -PropertyType DWord -Value 0 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling getting the latest updates as soon as they're available"
			LogInfo "Enabling getting the latest updates as soon as they're available"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsContinuousInnovationOptedIn -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Allow updates to be downloaded automatically over metered connections

	.PARAMETER Enable
	Allow updates to be downloaded automatically over metered connections

	.PARAMETER Disable
	Do not download updates automatically over metered connections (default value)

	.EXAMPLE
	DownloadUpdatesOverMeteredConnection -Enable

	.EXAMPLE
	DownloadUpdatesOverMeteredConnection -Disable

	.NOTES
	Machine-wide
#>
function DownloadUpdatesOverMeteredConnection
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

	$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Allowing updates to be downloaded automatically over metered connections"
			LogInfo "Allowing updates to be downloaded automatically over metered connections"
			try
			{
				if (-not (Test-Path -Path $WindowsUpdatePolicyPath))
				{
					New-Item -Path $WindowsUpdatePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsUpdatePolicyPath -Name AllowAutoWindowsUpdateDownloadOverMeteredNetwork -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to allow updates to be downloaded automatically over metered connections: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Blocking updates from downloading automatically over metered connections"
			LogInfo "Blocking updates from downloading automatically over metered connections"
			try
			{
				if (-not (Test-Path -Path $WindowsUpdatePolicyPath))
				{
					New-Item -Path $WindowsUpdatePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsUpdatePolicyPath -Name AllowAutoWindowsUpdateDownloadOverMeteredNetwork -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to block updates from downloading automatically over metered connections: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Allow Microsoft Store apps to automatically download and install updates

	.PARAMETER Enable
	Allow Microsoft Store apps to automatically download and install updates

	.PARAMETER Disable
	Do not allow Microsoft Store apps to automatically download and install updates (default value)

	.EXAMPLE
	StoreAppAutoDownload -Enable

	.EXAMPLE
	StoreAppAutoDownload -Disable

	.NOTES
	Machine-wide
#>
function StoreAppAutoDownload
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

	$WindowsStorePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Allowing Microsoft Store apps to automatically download and install updates"
			LogInfo "Allowing Microsoft Store apps to automatically download and install updates"
			try
			{
				if (-not (Test-Path -Path $WindowsStorePolicyPath))
				{
					New-Item -Path $WindowsStorePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsStorePolicyPath -Name AutoDownload -PropertyType DWord -Value 4 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to allow Microsoft Store apps to automatically download and install updates: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Blocking Microsoft Store apps from automatically downloading and installing updates"
			LogInfo "Blocking Microsoft Store apps from automatically downloading and installing updates"
			try
			{
				if (-not (Test-Path -Path $WindowsStorePolicyPath))
				{
					New-Item -Path $WindowsStorePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsStorePolicyPath -Name AutoDownload -PropertyType DWord -Value 2 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to block Microsoft Store apps from automatically downloading and installing updates: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Feature update deferral period

	.PARAMETER Enable
	Defer feature updates by 365 days

	.PARAMETER Disable
	Restore Windows default feature update behavior (default value)

	.EXAMPLE
	FeatureUpdateDeferral -Enable

	.EXAMPLE
	FeatureUpdateDeferral -Disable

	.NOTES
	Machine-wide
#>
function FeatureUpdateDeferral
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

	$UpdateUxSettingsPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Deferring feature updates by 365 days"
			LogInfo "Deferring feature updates by 365 days"
			try
			{
				if (-not (Test-Path -Path $UpdateUxSettingsPath))
				{
					New-Item -Path $UpdateUxSettingsPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $UpdateUxSettingsPath -Name BranchReadinessLevel -PropertyType DWord -Value 20 -Force -ErrorAction Stop | Out-Null
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferFeatureUpdates -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferFeatureUpdatesPeriodInDays -PropertyType DWord -Value 365 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to defer feature updates by 365 days: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Restoring Windows default feature update behavior"
			LogInfo "Restoring Windows default feature update behavior"
			try
			{
				Remove-ItemProperty -Path $UpdateUxSettingsPath -Name BranchReadinessLevel, DeferFeatureUpdates, DeferFeatureUpdatesPeriodInDays -Force -ErrorAction SilentlyContinue | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to restore Windows default feature update behavior: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Quality update deferral period

	.PARAMETER Default
	Restore Windows default quality update behavior (default value)

	.PARAMETER FourDays
	Defer quality updates by 4 days

	.PARAMETER SevenDays
	Defer quality updates by 7 days

	.EXAMPLE
	QualityUpdateDeferral -FourDays

	.EXAMPLE
	QualityUpdateDeferral -SevenDays

	.NOTES
	Machine-wide
#>

function QualityUpdateDeferral
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default"
		)]
		[switch]
		$Default,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "FourDays"
		)]
		[switch]
		$FourDays,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "SevenDays"
		)]
		[switch]
		$SevenDays
	)

	$UpdateUxSettingsPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

	switch ($PSCmdlet.ParameterSetName)
	{
		"Default"
		{
			Write-ConsoleStatus -Action "Restoring Windows default quality update behavior"
			LogInfo "Restoring Windows default quality update behavior"
			try
			{
				Remove-ItemProperty -Path $UpdateUxSettingsPath -Name DeferQualityUpdates, DeferQualityUpdatesPeriodInDays -Force -ErrorAction SilentlyContinue | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to restore Windows default quality update behavior: $($_.Exception.Message)"
			}
		}
		"FourDays"
		{
			Write-ConsoleStatus -Action "Deferring quality updates by 4 days"
			LogInfo "Deferring quality updates by 4 days"
			try
			{
				if (-not (Test-Path -Path $UpdateUxSettingsPath))
				{
					New-Item -Path $UpdateUxSettingsPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferQualityUpdates -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferQualityUpdatesPeriodInDays -PropertyType DWord -Value 4 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to defer quality updates by 4 days: $($_.Exception.Message)"
			}
		}
		"SevenDays"
		{
			Write-ConsoleStatus -Action "Deferring quality updates by 7 days"
			LogInfo "Deferring quality updates by 7 days"
			try
			{
				if (-not (Test-Path -Path $UpdateUxSettingsPath))
				{
					New-Item -Path $UpdateUxSettingsPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferQualityUpdates -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				New-ItemProperty -Path $UpdateUxSettingsPath -Name DeferQualityUpdatesPeriodInDays -PropertyType DWord -Value 7 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to defer quality updates by 7 days: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Security updates only mode

	.PARAMETER Enable
	Enable a security-first update posture by keeping automatic downloads, driver offers, and restart behavior under control while preserving feature and quality deferral policy

	.PARAMETER Disable
	Restore the normal Windows update posture

	.EXAMPLE
	WindowsUpdateSecurityOnlyMode -Enable

	.EXAMPLE
	WindowsUpdateSecurityOnlyMode -Disable

	.NOTES
	Machine-wide
#>
function WindowsUpdateSecurityOnlyMode
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
			Write-ConsoleStatus -Action "Enabling security updates only mode"
			LogInfo "Enabling security updates only mode"
			try
			{
				UpdateAutoDownload -Disable
				UpdateDriver -Disable
				UpdateRestart -Disable
				FeatureUpdateDeferral -Enable
				QualityUpdateDeferral -SevenDays
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable security updates only mode: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Restoring normal Windows update behavior"
			LogInfo "Restoring normal Windows update behavior"
			try
			{
				UpdateAutoDownload -Enable
				UpdateDriver -Enable
				UpdateRestart -Enable
				FeatureUpdateDeferral -Disable
				QualityUpdateDeferral -Default
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to restore normal Windows update behavior: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Pause Windows updates starting on a selected date

	.PARAMETER Enable
	Pause Windows updates starting on the selected date

	.PARAMETER Disable
	Clear the Windows update pause state

	.PARAMETER StartDate
	The date that should be written to the documented Windows Update pause keys in yyyy-MM-dd format

	.EXAMPLE
	WindowsUpdatePause -Enable -StartDate 2025-04-08

	.EXAMPLE
	WindowsUpdatePause -Disable

	.NOTES
	Machine-wide
#>

function WindowsUpdatePause
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
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[string]
		$StartDate
	)

	$UpdateUxSettingsPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
	$pauseValueNames = @(
		'PauseFeatureUpdatesStartTime'
		'PauseQualityUpdatesStartTime'
		'PauseUpdatesStartTime'
		'PausedFeatureDate'
		'PausedQualityDate'
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Pausing Windows updates starting on $StartDate"
			LogInfo "Pausing Windows updates starting on $StartDate"
			try
			{
				$parsedStartDate = [datetime]::MinValue
				if (-not [datetime]::TryParseExact($StartDate, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedStartDate))
				{
					throw "Invalid start date '$StartDate'. Expected yyyy-MM-dd."
				}

				$pauseValue = $parsedStartDate.ToString('yyyy-MM-ddT00:00:00Z')
				if (-not (Test-Path -Path $UpdateUxSettingsPath))
				{
					New-Item -Path $UpdateUxSettingsPath -Force -ErrorAction Stop | Out-Null
				}

				foreach ($valueName in $pauseValueNames)
				{
					New-ItemProperty -Path $UpdateUxSettingsPath -Name $valueName -PropertyType String -Value $pauseValue -Force -ErrorAction Stop | Out-Null
				}
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError ("Failed to pause Windows updates starting on {0}: {1}" -f $StartDate, $_.Exception.Message)
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Clearing paused Windows update state"
			LogInfo "Clearing paused Windows update state"
			try
			{
				Remove-ItemProperty -Path $UpdateUxSettingsPath -Name $pauseValueNames -Force -ErrorAction SilentlyContinue | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to clear paused Windows update state: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Restart as soon as possible to finish updating

	.PARAMETER Enable
	Restart as soon as possible to finish updating

	.PARAMETER Disable
	Don't restart as soon as possible to finish updating (default value)

	.EXAMPLE
	DeviceRestartAfterUpdate -Enable

	.EXAMPLE
	DeviceRestartAfterUpdate -Disable

	.NOTES
	Machine-wide
#>
function RestartDeviceAfterUpdate
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

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursEnd, ActiveHoursStart, SetActiveHours -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursEnd -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name ActiveHoursStart -Type CLEAR | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name SetActiveHours -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling restart as soon as possible to finish updating"
			LogInfo "Enabling restart as soon as possible to finish updating"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsExpedited -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling restart as soon as possible to finish updating"
			LogInfo "Disabling restart as soon as possible to finish updating"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsExpedited -PropertyType DWord -Value 0 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Notification when your PC requires a restart to finish updating

	.PARAMETER Show
	Notify me when a restart is required to finish updating

	.PARAMETER Hide
	Do not notify me when a restart is required to finish updating (default value)

	.EXAMPLE
	RestartNotification -Show

	.EXAMPLE
	RestartNotification -Hide

	.NOTES
	Machine-wide
#>
function RestartNotification
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide
	)

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name SetAutoRestartNotificationDisable -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name SetAutoRestartNotificationDisable -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Show"
		{
			Write-ConsoleStatus -Action "Showing notification when your PC requires a restart to finish updating"
			LogInfo "Showing notification when your PC requires a restart to finish updating"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Hide"
		{
			Write-ConsoleStatus -Action "Hiding notification when your PC requires a restart to finish updating"
			LogInfo "Hiding notification when your PC requires a restart to finish updating"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType DWord -Value 0 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Windows Update notification level

	.PARAMETER Default
	Restore Windows default update notification behavior (default value)

	.PARAMETER All
	Show all Windows Update notifications

	.PARAMETER RestartOnly
	Show restart warnings only for Windows Update

	.PARAMETER Off
	Hide all Windows Update notifications, including restart warnings

	.EXAMPLE
	UpdateNotificationLevel -All

	.EXAMPLE
	UpdateNotificationLevel -RestartOnly

	.EXAMPLE
	UpdateNotificationLevel -Off

	.NOTES
	Machine-wide
#>

function UpdateNotificationLevel
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default"
		)]
		[switch]
		$Default,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "All"
		)]
		[switch]
		$All,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "RestartOnly"
		)]
		[switch]
		$RestartOnly,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Off"
		)]
		[switch]
		$Off
	)

	$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

	switch ($PSCmdlet.ParameterSetName)
	{
		"Default"
		{
			Write-ConsoleStatus -Action "Restoring Windows default update notification behavior"
			LogInfo "Restoring Windows default update notification behavior"
			try
			{
				Remove-ItemProperty -Path $WindowsUpdatePolicyPath -Name SetUpdateNotificationLevel -Force -ErrorAction SilentlyContinue | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to restore Windows default update notification behavior: $($_.Exception.Message)"
			}
		}
		"All"
		{
			Write-ConsoleStatus -Action "Showing all Windows Update notifications"
			LogInfo "Showing all Windows Update notifications"
			try
			{
				if (-not (Test-Path -Path $WindowsUpdatePolicyPath))
				{
					New-Item -Path $WindowsUpdatePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsUpdatePolicyPath -Name SetUpdateNotificationLevel -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to show all Windows Update notifications: $($_.Exception.Message)"
			}
		}
		"RestartOnly"
		{
			Write-ConsoleStatus -Action "Showing restart warnings only for Windows Update"
			LogInfo "Showing restart warnings only for Windows Update"
			try
			{
				if (-not (Test-Path -Path $WindowsUpdatePolicyPath))
				{
					New-Item -Path $WindowsUpdatePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsUpdatePolicyPath -Name SetUpdateNotificationLevel -PropertyType DWord -Value 1 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to show restart warnings only for Windows Update: $($_.Exception.Message)"
			}
		}
		"Off"
		{
			Write-ConsoleStatus -Action "Hiding all Windows Update notifications"
			LogInfo "Hiding all Windows Update notifications"
			try
			{
				if (-not (Test-Path -Path $WindowsUpdatePolicyPath))
				{
					New-Item -Path $WindowsUpdatePolicyPath -Force -ErrorAction Stop | Out-Null
				}
				New-ItemProperty -Path $WindowsUpdatePolicyPath -Name SetUpdateNotificationLevel -PropertyType DWord -Value 2 -Force -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to hide all Windows Update notifications: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Restart apps after signing in

	.PARAMETER Enable
	Automatically saving my restartable apps and restart them when I sign back in

	.PARAMETER Disable
	Turn off automatically saving my restartable apps and restart them when I sign back in (default value)

	.EXAMPLE
	SaveRestartableApps -Enable

	.EXAMPLE
	SaveRestartableApps -Disable

	.NOTES
	Current user
#>
function SaveRestartableApps
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
			Write-ConsoleStatus -Action "Enabling saving restartable apps and restarting them after signing in"
			LogInfo "Enabling saving restartable apps and restarting them after signing in"
			New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name RestartApps -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling saving restartable apps and restarting them after signing in"
			LogInfo "Disabling saving restartable apps and restarting them after signing in"
			New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name RestartApps -PropertyType DWord -Value 0 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Recommended troubleshooter preferences

	.PARAMETER Automatically
	Run troubleshooter automatically, then notify me

	.PARAMETER Default
	Ask me before running troubleshooter (default value)

	.EXAMPLE
	RecommendedTroubleshooting -Automatically

	.EXAMPLE
	RecommendedTroubleshooting -Default

	.NOTES
	In order this feature to work Windows level of diagnostic data gathering will be set to "Optional diagnostic data" and the error reporting feature will be turned on

	.NOTES
	Machine-wide
#>

function RecommendedTroubleshooting
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Automatically"
		)]
		[switch]
		$Automatically,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Default"
		)]
		[switch]
		$Default
	)

	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Force -ErrorAction SilentlyContinue | Out-Null
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection -Name MaxTelemetryAllowed -Force -ErrorAction SilentlyContinue | Out-Null
	Remove-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack -Name ShowedToastAtLevel -Force -ErrorAction SilentlyContinue | Out-Null

	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Type CLEAR | Out-Null

	# Turn on Windows Error Reporting
	Get-ScheduledTask -TaskName QueueReporting -ErrorAction SilentlyContinue | Enable-ScheduledTask | Out-Null
	Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" -Name Disabled -Force -ErrorAction SilentlyContinue | Out-Null

	Get-Service -Name WerSvc | Set-Service -StartupType Manual | Out-Null
	Get-Service -Name WerSvc | Start-Service | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Automatically"
		{
			Write-ConsoleStatus -Action "Setting troubleshooter preferences to automatically run"
			LogInfo "Setting troubleshooter preferences to automatically run"
			if (-not (Test-Path -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation))
			{
				New-Item -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Force | Out-Null
			}
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Name UserPreference -PropertyType DWord -Value 3 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Default"
		{
			Write-ConsoleStatus -Action "Setting troubleshooter preferences to ask before running"
			LogInfo "Setting troubleshooter preferences to ask before running"
			if (-not (Test-Path -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation))
			{
				New-Item -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Force | Out-Null
			}
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsMitigation -Name UserPreference -PropertyType DWord -Value 2 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

<#
	.SYNOPSIS
	Search for apps in Microsoft Store from Open with dialog

	.PARAMETER Enable
	Allow searching for apps in Microsoft Store from Open with dialog

	.PARAMETER Disable
	Prevent searching for apps in Microsoft Store from Open with dialog

	.EXAMPLE
	SearchAppInStore -Enable

	.EXAMPLE
	SearchAppInStore -Disable

	.NOTES
	Current user
#>
function SearchAppInStore
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
			Write-ConsoleStatus -Action "Enabling searching for apps in Microsoft Store from Open with dialog"
			LogInfo "Enabling searching for apps in Microsoft Store from Open with dialog"
			try
			{
				Remove-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to enable searching for apps in Microsoft Store from Open with dialog: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling searching for apps in Microsoft Store from Open with dialog"
			LogInfo "Disabling searching for apps in Microsoft Store from Open with dialog"
			try
			{
				If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer")) {
					New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -ErrorAction Stop | Out-Null
				}
				Set-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Type DWord -Value 1 -ErrorAction Stop | Out-Null
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to disable searching for apps in Microsoft Store from Open with dialog: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Block Microsoft Store search results

	.PARAMETER Enable
	Block recommended Microsoft Store apps when searching for apps in the Start menu

	.PARAMETER Disable
	Allow recommended Microsoft Store apps when searching for apps in the Start menu

	.EXAMPLE
	StoreSearchResults -Enable

	.EXAMPLE
	StoreSearchResults -Disable

	.NOTES
	Current user
#>
function StoreSearchResults
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

	$storeDbPath = Join-Path $env:LocalAppData 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db'

	if (-not (Test-Path -LiteralPath $storeDbPath))
	{
		LogWarning ($Localization.Skipped -f (Get-TweakSkipLabel $MyInvocation))
		return
	}

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Blocking Microsoft Store search results"
			LogInfo "Blocking Microsoft Store search results"
			try
			{
				icacls $storeDbPath /deny Everyone:F 2>$null | Out-Null
				if ($LASTEXITCODE -ne 0)
				{
					throw "icacls returned exit code $LASTEXITCODE while blocking Microsoft Store search results"
				}
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to block Microsoft Store search results: $($_.Exception.Message)"
			}
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Unblocking Microsoft Store search results"
			LogInfo "Unblocking Microsoft Store search results"
			try
			{
				icacls $storeDbPath /remove:d Everyone 2>$null | Out-Null
				if ($LASTEXITCODE -ne 0)
				{
					throw "icacls returned exit code $LASTEXITCODE while unblocking Microsoft Store search results"
				}
				Write-ConsoleStatus -Status success
			}
			catch
			{
				Write-ConsoleStatus -Status failed
				LogError "Failed to unblock Microsoft Store search results: $($_.Exception.Message)"
			}
		}
	}
}

<#
	.SYNOPSIS
	Repair Windows Update

	.PARAMETER Standard
	Run the standard Windows Update repair sequence.

	.PARAMETER Aggressive
	Run the standard repair sequence plus OS integrity checks and deeper Windows Update cache resets.

	.EXAMPLE
	WindowsUpdate -Standard

	.EXAMPLE
	WindowsUpdate -Aggressive

	.NOTES
	Machine-wide
	Requires an elevated PowerShell session.
	High risk.
	Restart required.
#>

function WindowsUpdate
{
	[CmdletBinding(DefaultParameterSetName = 'Standard')]
	param
	(
		[Parameter(Mandatory = $true, ParameterSetName = 'Standard')]
		[switch]
		$Standard,

		[Parameter(Mandatory = $true, ParameterSetName = 'Aggressive')]
		[switch]
		$Aggressive
	)

	$isAggressive = $PSCmdlet.ParameterSetName -eq 'Aggressive'
	$actionText = if ($isAggressive)
	{
		'Repairing Windows Update (Aggressive)'
	}
	else
	{
		'Repairing Windows Update'
	}

	Write-ConsoleStatus -Action $actionText
	LogInfo $actionText

	try
	{
		if ($isAggressive)
		{
			LogInfo 'Running aggressive Windows Update repair checks'
			Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', 'chkdsk /scan /perf' -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
			Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', 'sfc /scannow' -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
			Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', 'dism /online /cleanup-image /restorehealth' -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
		}

		foreach ($serviceName in @('BITS', 'wuauserv', 'appidsvc', 'cryptsvc'))
		{
			Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue | Out-Null
		}

		Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue | Out-Null

		if ($isAggressive)
		{
			Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\DataStore" -NewName 'DataStore.bak' -ErrorAction SilentlyContinue | Out-Null
			Rename-Item -Path "$env:SystemRoot\System32\Catroot2" -NewName 'catroot2.bak' -ErrorAction SilentlyContinue | Out-Null
		}

		Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\Download" -NewName 'Download.bak' -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path "$env:SystemRoot\WindowsUpdate.log" -ErrorAction SilentlyContinue | Out-Null

		if ($isAggressive)
		{
			Start-Process -FilePath "$env:SystemRoot\System32\sc.exe" -ArgumentList 'sdset', 'bits', 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)' -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
			Start-Process -FilePath "$env:SystemRoot\System32\sc.exe" -ArgumentList 'sdset', 'wuauserv', 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)' -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		}

		$dlls = @(
			'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll',
			'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll',
			'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll', 'dssenh.dll',
			'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll', 'slbcsp.dll', 'cryptdlg.dll',
			'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll', 'wuapi.dll',
			'wuaueng.dll', 'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll',
			'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll'
		)

		foreach ($dll in $dlls)
		{
			Start-Process -FilePath "$env:SystemRoot\System32\regsvr32.exe" -ArgumentList '/s', $dll -NoNewWindow -Wait -ErrorAction SilentlyContinue | Out-Null
		}

		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name 'AccountDomainSid' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name 'PingID' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name 'SusClientId' -Force -ErrorAction SilentlyContinue | Out-Null

		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'ExcludeWUDriversInQualityUpdate' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata' -Name 'PreventDeviceMetadataFromNetwork' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' -Name 'DontPromptForWindowsUpdate' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' -Name 'DontSearchWindowsUpdate' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' -Name 'DriverUpdateWizardWuSearchEnabled' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoRebootWithLoggedOnUsers' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AUPowerManagement' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'BranchReadinessLevel' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'DeferFeatureUpdatesPeriodInDays' -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -Name 'DeferQualityUpdatesPeriodInDays' -Force -ErrorAction SilentlyContinue | Out-Null

		Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKCU:\Software\Microsoft\WindowsSelfHost' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKCU:\Software\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\Microsoft\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\Microsoft\WindowsSelfHost' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\WOW6432Node\Microsoft\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
		Remove-Item -Path 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate' -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

		Start-Process -FilePath "$env:SystemRoot\System32\secedit.exe" -ArgumentList '/configure', '/cfg', "$env:windir\inf\defltbase.inf", '/db', 'defltbase.sdb', '/verbose' -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', "RD /S /Q $env:WinDir\System32\GroupPolicyUsers" -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c', "RD /S /Q $env:WinDir\System32\GroupPolicy" -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		Start-Process -FilePath "$env:SystemRoot\System32\gpupdate.exe" -ArgumentList '/force' -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null

		Start-Process -FilePath "$env:SystemRoot\System32\netsh.exe" -ArgumentList 'winsock', 'reset' -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		Start-Process -FilePath "$env:SystemRoot\System32\netsh.exe" -ArgumentList 'winhttp', 'reset', 'proxy' -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
		Start-Process -FilePath "$env:SystemRoot\System32\netsh.exe" -ArgumentList 'int', 'ip', 'reset' -NoNewWindow -ErrorAction SilentlyContinue | Out-Null

		Get-BitsTransfer -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue

		foreach ($serviceName in @('BITS', 'wuauserv', 'CryptSvc'))
		{
			Set-Service -Name $serviceName -StartupType Manual -ErrorAction SilentlyContinue | Out-Null
			Start-Service -Name $serviceName -ErrorAction SilentlyContinue | Out-Null
		}

		Set-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc' -Name 'Start' -Value 3 -ErrorAction SilentlyContinue | Out-Null
		Start-Service -Name 'AppIDSvc' -ErrorAction SilentlyContinue | Out-Null

		try
		{
			(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
		}
		catch
		{
			LogWarning "Failed to trigger Microsoft.Update.AutoUpdate.DetectNow(): $($_.Exception.Message)"
		}

		Start-Process -FilePath "$env:SystemRoot\System32\wuauclt.exe" -ArgumentList '/resetauthorization', '/detectnow' -NoNewWindow -ErrorAction SilentlyContinue | Out-Null

		LogInfo 'Windows Update repair completed. Restart recommended.'
		Write-ConsoleStatus -Status success
	}
	catch
	{
		Write-ConsoleStatus -Status failed
		LogError ("Failed to repair Windows Update{0}: {1}" -f $(if ($isAggressive) { ' (Aggressive)' } else { '' }), $_.Exception.Message)
	}
}

<#
	.SYNOPSIS
	Receive updates for other Microsoft products

	.PARAMETER Enable
	Receive updates for other Microsoft products

	.PARAMETER Disable
	Do not receive updates for other Microsoft products (default value)

	.EXAMPLE
	UpdateMicrosoftProducts -Enable

	.EXAMPLE
	UpdateMicrosoftProducts -Disable

	.NOTES
	Current user
#>
function UpdateMicrosoftProducts
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

	# Remove all policies in order to make changes visible in UI only if it's possible
	Remove-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AllowMUUpdateService -Force -ErrorAction SilentlyContinue | Out-Null
	Set-Policy -Scope Computer -Path SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name AllowMUUpdateService -Type CLEAR | Out-Null

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
			Write-ConsoleStatus -Action "Enabling receiving updates for other Microsoft products"
			LogInfo "Enabling receiving updates for other Microsoft products"
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name AllowMUUpdateService -PropertyType DWord -Value 1 -Force | Out-Null
			Write-ConsoleStatus -Status success
		}
		"Disable"
		{
			Write-ConsoleStatus -Action "Disabling receiving updates for other Microsoft products"
			LogInfo "Disabling receiving updates for other Microsoft products"
			Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name AllowMUUpdateService -Force -ErrorAction SilentlyContinue | Out-Null
			Write-ConsoleStatus -Status success
		}
	}
}

Export-ModuleMember -Function '*'
