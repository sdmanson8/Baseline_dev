using module ..\Logging.psm1
using module ..\SharedHelpers.psm1
using module ..\GUICommon.psm1
using module ..\GUIExecution.psm1

# Extracted GUI scripts are dot-sourced into this module, so they resolve
# $Script: variables against GUI.psm1 rather than GUICommon.psm1.
$Script:GuiLayout = GUICommon\Get-GuiLayout
$Script:GuiFontSizeWarnings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

<#
    .SYNOPSIS
    Internal function Get-GuiSafeFontSize.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-GuiSafeFontSize
{
	param(
		[Parameter(Mandatory = $true)]
		[string]$Key,
		[double]$Default = 12,
		[object]$Layout = $Script:GuiLayout
	)

	return GUICommon\Get-GuiSafeFontSize -Key $Key -Default $Default -Layout $Layout
}

<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function New-SafeThickness
{
	param(
		[double]$Left = 0,
		[double]$Top = 0,
		[double]$Right = 0,
		[double]$Bottom = 0,
		[Nullable[double]]$Uniform = $null
	)

	if ($null -ne $Uniform)
	{
		return [System.Windows.Thickness]::new([double]$Uniform)
	}

	return [System.Windows.Thickness]::new($Left, $Top, $Right, $Bottom)
}

<#
    .SYNOPSIS
    Internal function New-WpfSetter.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-WpfSetter
{
	param(
		[Parameter(Mandatory = $true)][System.Windows.DependencyProperty]$Property,
		[Parameter(Mandatory = $true)][object]$Value,
		[string]$TargetName
	)

	$setter = New-Object System.Windows.Setter
	$setter.Property = $Property
	$resolvedValue = $Value
	if ($null -ne $resolvedValue -and $resolvedValue -is [psobject])
	{
		$resolvedValue = $resolvedValue.BaseObject
	}

	if (
		$null -ne $resolvedValue -and
		$Property.PropertyType -eq [System.Windows.Media.Brush] -and
		$resolvedValue -isnot [System.Windows.Media.Brush]
	)
	{
		try
		{
			if ($resolvedValue -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$resolvedValue))
			{
				if (Get-Command -Name 'ConvertTo-GuiBrush' -CommandType Function -ErrorAction SilentlyContinue)
				{
					$resolvedValue = ConvertTo-GuiBrush -Color ([string]$resolvedValue) -Context 'New-WpfSetter'
				}
				else
				{
					$resolvedValue = [System.Windows.Media.Brush]([System.Windows.Media.BrushConverter]::new().ConvertFromString([string]$resolvedValue))
				}
			}
			else
			{
				$resolvedValue = [System.Windows.Media.Brush]$resolvedValue
			}
		}
		catch
		{
			$resolvedValue = $Value
		}
	}

	$setter.Value = $resolvedValue
	if (-not [string]::IsNullOrWhiteSpace($TargetName))
	{
		$setter.TargetName = $TargetName
	}

	return $setter
}

<#
    .SYNOPSIS
    Internal function Test-GuiObjectField.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-GuiObjectField
{
	param(
		[object]$Object,
		[string]$FieldName
	)

	if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($FieldName))
	{
		return $false
	}

	if ($Object -is [System.Collections.IDictionary])
	{
		return [bool]$Object.Contains($FieldName)
	}

	return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName])
}

<#
    .SYNOPSIS
    Internal function Get-GuiObjectField.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-GuiObjectField
{
	param(
		[object]$Object,
		[string]$FieldName
	)

	if (-not (Test-GuiObjectField -Object $Object -FieldName $FieldName))
	{
		return $null
	}

	if ($Object -is [System.Collections.IDictionary])
	{
		return $Object[$FieldName]
	}

	return $Object.$FieldName
}

<#
    .SYNOPSIS
    Internal function Get-GuiRuntimeFailureDetails.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-GuiRuntimeFailureDetails
{
	param (
		[string]$Context = 'GUI',
		[System.Exception]$Exception,
		[string[]]$DebugTrail
	)

	$errorLines = New-Object System.Collections.Generic.List[string]
	[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureEventFailed' -Fallback 'GUI event failed [{0}]: {1}' -FormatArgs @($(if ($Context) { $Context } else { 'GUI' }), $Exception.Message)))
	[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureExceptionType' -Fallback 'Exception type: {0}' -FormatArgs @($Exception.GetType().FullName)))
	$errorRecord = $null
	try
	{
		if ($Exception.PSObject.Properties['ErrorRecord'])
		{
			$errorRecord = $Exception.ErrorRecord
		}
	}
	catch
	{
		$errorRecord = $null
	}
	if ($Exception.InnerException)
	{
		[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureInnerException' -Fallback 'Inner exception: {0}' -FormatArgs @($Exception.InnerException.Message)))
	}
	if ($errorRecord)
	{
		if ($errorRecord.InvocationInfo -and -not [string]::IsNullOrWhiteSpace([string]$errorRecord.InvocationInfo.PositionMessage))
		{
			[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureInvocation' -Fallback 'Invocation:'))
			[void]$errorLines.Add($errorRecord.InvocationInfo.PositionMessage.Trim())
		}
		if (-not [string]::IsNullOrWhiteSpace([string]$errorRecord.ScriptStackTrace))
		{
			[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureScriptStackTrace' -Fallback 'Script stack trace:'))
			[void]$errorLines.Add($errorRecord.ScriptStackTrace.Trim())
		}
		if ($null -ne $errorRecord.TargetObject)
		{
			$targetType = try { $errorRecord.TargetObject.GetType().FullName } catch { 'unknown' }
			[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureTargetObjectType' -Fallback 'Target object type: {0}' -FormatArgs @($targetType)))
		}
	}
	if ($Exception.StackTrace)
	{
		[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailureStackTrace' -Fallback 'Stack trace:'))
		[void]$errorLines.Add($Exception.StackTrace.Trim())
	}

	if ($DebugTrail -and $DebugTrail.Count -gt 0)
	{
		[void]$errorLines.Add('')
		[void]$errorLines.Add((Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeFailurePresetDebugTrail' -Fallback 'Preset debug trail (most recent entries):'))
		$startIndex = [Math]::Max(0, $DebugTrail.Count - 15)
		for ($i = $startIndex; $i -lt $DebugTrail.Count; $i++)
		{
			[void]$errorLines.Add($DebugTrail[$i])
		}
	}

	return ($errorLines -join [Environment]::NewLine)
}

<#
    .SYNOPSIS
    Internal function Show-GuiRuntimeFailure.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-GuiRuntimeFailure
{
	param (
		[string]$Context = 'GUI',
		[System.Exception]$Exception,
		[switch]$ShowDialog,
		[string[]]$DebugTrail
	)

	if (-not $Exception) { return $null }

	$errorText = Get-GuiRuntimeFailureDetails -Context $Context -Exception $Exception -DebugTrail $DebugTrail
	if (Get-Command -Name 'LogError' -CommandType Function -ErrorAction SilentlyContinue)
	{
		LogError $errorText
	}
	else
	{
		Write-Warning $errorText
	}

	if ($ShowDialog -and $Script:MainForm -and $Script:CurrentTheme)
	{
		try
		{
			$friendlyError = Get-BaselineErrorInfo -Exception $Exception -Context $Context
			$friendlyTitle = if ($friendlyError -and $friendlyError.PSObject.Properties['Title']) { [string]$friendlyError.Title } else { 'GUI Error' }
			$friendlyMessage = Format-BaselineErrorDialogMessage -ErrorInfo $friendlyError -LogPath $Global:LogFilePath -IncludeLogPath
			$noopButtonChrome = [scriptblock]::Create('param($Button, $Variant)')
			GUICommon\Show-ThemedDialog `
				-Theme $Script:CurrentTheme `
				-ApplyButtonChrome $noopButtonChrome `
				-OwnerWindow $Script:MainForm `
				-Title $friendlyTitle `
				-Message $friendlyMessage `
				-Buttons @('OK') `
				-UseDarkMode ($Script:CurrentThemeName -eq 'Dark') `
				-AccentButton 'OK'
		}
		catch
		{
			$null = $_
		}
	}

	return $errorText
}

<#
    .SYNOPSIS
    Internal function Write-GuiPresetDebug.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Write-GuiPresetDebug
{
	param (
		[string]$Context = 'GUI',
		[string]$Message
	)

	if ([string]::IsNullOrWhiteSpace($Message)) { return }

	$debugText = "GUI preset debug [{0}]: {1}" -f $(if ($Context) { $Context } else { 'GUI' }), $Message
	try
	{
		if (-not $Script:GuiPresetDebugTrail)
		{
			$Script:GuiPresetDebugTrail = [System.Collections.Generic.List[string]]::new()
		}
		$trailEntry = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $debugText
		[void]$Script:GuiPresetDebugTrail.Add($trailEntry)
		while ($Script:GuiPresetDebugTrail.Count -gt 100)
		{
			$Script:GuiPresetDebugTrail.RemoveAt(0)
		}

		# Debug trail is kept in memory for diagnostics only — not written to the log file.
	}
	catch
	{
		try
		{
			Write-Warning $debugText
		}
		catch
		{
			$null = $_
		}
	}
}

$Script:GuiPresetDebugScript = ${function:Write-GuiPresetDebug}

<#
    .SYNOPSIS
    Internal function Write-GuiRuntimeWarning.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Write-GuiRuntimeWarning
{
	param (
		[string]$Context,
		[string]$Message
	)

	if ([string]::IsNullOrWhiteSpace($Message)) { return }

	$warningKey = '{0}|{1}' -f $Context, $Message
	$shouldLog = $true
	if ($Script:GuiRuntimeWarnings)
	{
		try { $shouldLog = $Script:GuiRuntimeWarnings.Add($warningKey) } catch { $shouldLog = $true }
	}
	if (-not $shouldLog) { return }

	$warningText = Get-UxBilingualLocalizedString -Key 'GuiLogRuntimeWarning' -Fallback 'GUI runtime safeguard [{0}]: {1}' -FormatArgs @($(if ($Context) { $Context } else { 'GUI' }), $Message)
	if (Get-Command -Name 'LogWarning' -CommandType Function -ErrorAction SilentlyContinue)
	{
		LogWarning $warningText
	}
	else
	{
		Write-Warning $warningText
	}
}


<#
	.SYNOPSIS
	WPF-based GUI that replaces the preset file (Bootstrap/Baseline.ps1).

	.DESCRIPTION
	Builds a modern two-tier tabbed WPF window from a tweak manifest.
	Each tweak is presented with clear Enable/Disable visual state,
	info icons for descriptions, and grouped caution warnings per tab.
	The GUI stays open for multiple runs and supports light/dark themes.

	.NOTES
	Tweak types
	  Toggle  - Enable/Disable or Show/Hide parameter pair
	  Choice  - Multiple named parameter sets (combo box)
	  Action  - No parameters; checkbox means "run this"

	Manifest field reference
	  Name            Display text
	  Category        Primary tab name
	  SubCategory     Secondary tab name (optional)
	  Function        PowerShell function to invoke
	  Type            Toggle | Choice | Action
	  OnParam         Parameter name for the "on" / positive state   (Toggle only)
	  OffParam        Parameter name for the "off" / negative state  (Toggle only)
	  Options         [string[]] of available parameter names        (Choice only)
	  DisplayOptions  [string[]] of friendly display names           (Choice only)
	  Default         $true/$false (Toggle/Action) or string (Choice)
	  WinDefault      The Windows-default value ($true/$false or string)
	  Description     Info tooltip text
	  Caution         $true if the tweak carries a CAUTION warning
	  CautionReason   Explanation of why this tweak is cautioned
	  ExtraArgs       Hashtable of additional arguments
	  Scannable       $true (default) if system-scan can detect state; $false to always allow re-run

	App catalog field reference
	  Name            Display text
	  SubCategory     Secondary grouping name
	  WinGetId        WinGet package identifier
	  ChocoId         Chocolatey package identifier
	  EntityType      winget | choco | uwp | feature | system | placeholder
	  SupportsExecution  $true when the backend can execute the item
#>

#region Detect & Visibility Scriptblocks
# Detect scriptblocks keyed by Function name (cannot be stored in JSON).
# Used by system-scan to determine current on/off state of a tweak.
$Script:DetectScriptblocks = @{
	'DiagTrackService' = { (Get-Service DiagTrack -EA SilentlyContinue).StartType -ne "Disabled" }
	'MaintenanceWakeUp' = {
		$maintenancePowerManagement = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name AUPowerManagement -EA SilentlyContinue).AUPowerManagement
		$wakeUp = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name WakeUp -EA SilentlyContinue).WakeUp
		(($maintenancePowerManagement -ne 0) -or ($wakeUp -ne 0))
	}
	'SharedExperiences' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" -Name RomeSdkChannelUserAuthzPolicy -EA SilentlyContinue).RomeSdkChannelUserAuthzPolicy -eq 1 }
	'ClipboardHistory' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Clipboard" -Name EnableClipboardHistory -EA SilentlyContinue).EnableClipboardHistory -eq 1 }
	'Superfetch' = { (Get-Service SysMain -EA SilentlyContinue).StartType -ne "Disabled" }
	'NTFSLongPaths' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -EA SilentlyContinue).LongPathsEnabled -eq 1 }
	'SleepButton' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name ShowSleepOption -EA SilentlyContinue).ShowSleepOption -eq 1 }
	'FastStartup' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled -EA SilentlyContinue).HiberbootEnabled -eq 1 }
	'AutoRebootOnCrash' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name AutoReboot -EA SilentlyContinue).AutoReboot -eq 1 }
	'SigninInfo' = { $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value; (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\UserARSO\$sid" -Name OptOut -EA SilentlyContinue).OptOut -ne 1 }
	'LanguageListAccess' = { (Get-ItemProperty "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -EA SilentlyContinue).HttpAcceptLanguageOptOut -ne 1 }
	'OnlineSpeechRecognition' = {
		$setting = Get-ItemProperty "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" -Name HasAccepted -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['HasAccepted'])
		{
			return $true
		}

		$setting.HasAccepted -ne 0
	}
	'NarratorOnlineServices' = {
		$setting = Get-ItemProperty "HKCU:\Software\Microsoft\Narrator\NoRoam" -Name OnlineServicesEnabled -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['OnlineServicesEnabled'])
		{
			return $true
		}

		$setting.OnlineServicesEnabled -ne 0
	}
	'NarratorScriptingSupport' = {
		$setting = Get-ItemProperty "HKCU:\Software\Microsoft\Narrator\NoRoam" -Name ScriptingEnabled -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['ScriptingEnabled'])
		{
			return $true
		}

		$setting.ScriptingEnabled -ne 0
	}
	'InkingAndTypingPersonalization' = {
		$setting = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization" -Name Value -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['Value'])
		{
			return $true
		}

		$setting.Value -ne 0
	}
	'DeviceSearchHistory' = {
		$setting = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -Name IsDeviceSearchHistoryEnabled -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['IsDeviceSearchHistoryEnabled'])
		{
			return $true
		}

		$setting.IsDeviceSearchHistoryEnabled -ne 0
	}
	'CloudContentSearch' = {
		$settings = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -EA SilentlyContinue
		if (-not $settings)
		{
			return $true
		}

		$msaEnabled = -not $settings.PSObject.Properties['IsMSACloudSearchEnabled'] -or $settings.IsMSACloudSearchEnabled -ne 0
		$aadEnabled = -not $settings.PSObject.Properties['IsAADCloudSearchEnabled'] -or $settings.IsAADCloudSearchEnabled -ne 0
		$msaEnabled -and $aadEnabled
	}
	'Block-WorkplaceJoinMessages' = {
		$machineSetting = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" -Name BlockAADWorkplaceJoin -EA SilentlyContinue
		$userSetting = Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin" -Name BlockAADWorkplaceJoin -EA SilentlyContinue

		if (-not $machineSetting -or -not $userSetting)
		{
			return $false
		}
		if (-not $machineSetting.PSObject.Properties['BlockAADWorkplaceJoin'] -or -not $userSetting.PSObject.Properties['BlockAADWorkplaceJoin'])
		{
			return $false
		}

		($machineSetting.BlockAADWorkplaceJoin -eq 1) -and ($userSetting.BlockAADWorkplaceJoin -eq 1)
	}
	'Prevent-BitLockerAutoEncryption' = {
		$setting = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker" -Name PreventDeviceEncryption -EA SilentlyContinue
		if (-not $setting -or -not $setting.PSObject.Properties['PreventDeviceEncryption'])
		{
			return $false
		}

		$setting.PreventDeviceEncryption -eq 1
	}
	'AdvertisingID' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -EA SilentlyContinue).Enabled -eq 1 }
	'LockWidgets' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -EA SilentlyContinue).TaskbarDa -ne 0 }
	'WindowsTips' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SoftLandingEnabled -EA SilentlyContinue).SoftLandingEnabled -ne 0 }
	'AppsSilentInstalling' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SilentInstalledAppsEnabled -EA SilentlyContinue).SilentInstalledAppsEnabled -ne 0 }
	'TailoredExperiences' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name TailoredExperiencesWithDiagnosticDataEnabled -EA SilentlyContinue).TailoredExperiencesWithDiagnosticDataEnabled -ne 0 }
	'BingSearch' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name BingSearchEnabled -EA SilentlyContinue).BingSearchEnabled -ne 0 }
	'WiFiSense' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name Value -EA SilentlyContinue).Value -ne 0 }
	'WebSearch' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name CortanaConsent -EA SilentlyContinue).CortanaConsent -ne 0 }
	'ActivityHistory' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name EnableActivityFeed -EA SilentlyContinue).EnableActivityFeed -ne 0 }
	'MapUpdates' = { (Get-ItemProperty "HKLM:\SYSTEM\Maps" -Name AutoUpdateEnabled -EA SilentlyContinue).AutoUpdateEnabled -eq 1 }
	'WAPPush' = { (Get-Service dmwappushservice -EA SilentlyContinue).StartType -ne "Disabled" }
	'ClearRecentFiles' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name ClearRecentDocsOnExit -EA SilentlyContinue).ClearRecentDocsOnExit -eq 1 }
	'RecentFiles' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name NoRecentDocsHistory -EA SilentlyContinue).NoRecentDocsHistory -ne 1 }
	'CrossDeviceResume' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" -Name IsResumeAllowed -EA SilentlyContinue).IsResumeAllowed -eq 1 }
	'MultiplaneOverlay' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name OverlayTestMode -EA SilentlyContinue).OverlayTestMode -ne 5 }
	'S3Sleep' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name PlatformAoAcOverride -EA SilentlyContinue).PlatformAoAcOverride -eq 0 }
	'ExplorerAutoDiscovery' = { (Get-ItemProperty "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell" -Name FolderType -EA SilentlyContinue).FolderType -ne "NotSpecified" }
	'WPBT' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name DisableWpbtExecution -EA SilentlyContinue).DisableWpbtExecution -ne 1 }
	'FullscreenOptimizations' = { (Get-ItemProperty "HKCU:\System\GameConfigStore" -Name GameDVR_DXGIHonorFSEWindowsCompatible -EA SilentlyContinue).GameDVR_DXGIHonorFSEWindowsCompatible -ne 1 }
	'Teredo' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name DisabledComponents -EA SilentlyContinue).DisabledComponents -ne 255 }
	'ExplorerTitleFullPath' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name FullPath -EA SilentlyContinue).FullPath -eq 1 }
	'NavPaneAllFolders' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name NavPaneShowAllFolders -EA SilentlyContinue).NavPaneShowAllFolders -eq 1 }
	'NavPaneLibraries' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name NavPaneShowLibraries -EA SilentlyContinue).NavPaneShowLibraries -eq 1 }
	'FldrSeparateProcess' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name SeparateProcess -EA SilentlyContinue).SeparateProcess -eq 1 }
	'RestoreFldrWindows' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name PersistBrowsers -EA SilentlyContinue).PersistBrowsers -eq 1 }
	'EncCompFilesColor' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowEncryptCompressedColor -EA SilentlyContinue).ShowEncryptCompressedColor -eq 1 }
	'SharingWizard' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name SharingWizardOn -EA SilentlyContinue).SharingWizardOn -ne 0 }
	'SelectCheckboxes' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name AutoCheckSelect -EA SilentlyContinue).AutoCheckSelect -eq 1 }
	'SyncNotifications' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowSyncProviderNotifications -EA SilentlyContinue).ShowSyncProviderNotifications -eq 1 }
	'BuildNumberOnDesktop' = { (Get-ItemProperty "HKCU:\Control Panel\Desktop" -Name PaintDesktopVersion -EA SilentlyContinue).PaintDesktopVersion -eq 1 }
	'Thumbnails' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name IconsOnly -EA SilentlyContinue).IconsOnly -ne 1 }
	'ThumbnailCache' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name DisableThumbnailCache -EA SilentlyContinue).DisableThumbnailCache -ne 1 }
	'ThumbsDBOnNetwork' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name DisableThumbsDBOnNetworkFolders -EA SilentlyContinue).DisableThumbsDBOnNetworkFolders -ne 1 }
	'CheckBoxes' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name AutoCheckSelect -EA SilentlyContinue).AutoCheckSelect -eq 1 }
	'HiddenItems' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name Hidden -EA SilentlyContinue).Hidden -eq 1 }
	'SuperHiddenFiles' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowSuperHidden -EA SilentlyContinue).ShowSuperHidden -eq 1 }
	'FileExtensions' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -EA SilentlyContinue).HideFileExt -ne 1 }
	'MergeConflicts' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideMergeConflicts -EA SilentlyContinue).HideMergeConflicts -ne 1 }
	'SnapAssist' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name SnapAssist -EA SilentlyContinue).SnapAssist -ne 0 }
	'RecycleBinDeleteConfirmation' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name ConfirmFileDelete -EA SilentlyContinue).ConfirmFileDelete -eq 1 }
	'MeetNow' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name HideSCAMeetNow -EA SilentlyContinue).HideSCAMeetNow -ne 1 }
	'NewsInterests' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name ShellFeedsTaskbarViewMode -EA SilentlyContinue).ShellFeedsTaskbarViewMode -ne 2 }
	'TaskbarAlignment' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarAl -EA SilentlyContinue).TaskbarAl -ne 1 }
	'TaskbarWidgets' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarDa -EA SilentlyContinue).TaskbarDa -ne 0 }
	'TaskViewButton' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -EA SilentlyContinue).ShowTaskViewButton -ne 0 }
	'TaskbarEndTask' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" -Name TaskbarEndTask -EA SilentlyContinue).TaskbarEndTask -eq 1 }
	'FirstLogonAnimation' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name EnableFirstLogonAnimation -EA SilentlyContinue).EnableFirstLogonAnimation -ne 0 }
	'JPEGWallpapersQuality' = { (Get-ItemProperty "HKCU:\Control Panel\Desktop" -Name JPEGImportQuality -EA SilentlyContinue).JPEGImportQuality -eq 100 }
	'PrtScnSnippingTool' = { (Get-ItemProperty "HKCU:\Control Panel\Keyboard" -Name PrintScreenKeyForSnippingEnabled -EA SilentlyContinue).PrintScreenKeyForSnippingEnabled -eq 1 }
	'AeroShaking' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name DisallowShaking -EA SilentlyContinue).DisallowShaking -ne 1 }
	'NavigationPaneExpand' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name NavPaneExpandToCurrentFolder -EA SilentlyContinue).NavPaneExpandToCurrentFolder -eq 1 }
	'LockScreen' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name NoLockScreen -EA SilentlyContinue).NoLockScreen -ne 1 }
	'LockScreenRS1' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name DisableLockScreen -EA SilentlyContinue).DisableLockScreen -ne 1 }
	'NetworkFromLockScreen' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name DontDisplayNetworkSelectionUI -EA SilentlyContinue).DontDisplayNetworkSelectionUI -ne 1 }
	'ShutdownFromLockScreen' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name ShutdownWithoutLogon -EA SilentlyContinue).ShutdownWithoutLogon -eq 1 }
	'AdminApprovalMode' = {
		$systemPolicy = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -EA SilentlyContinue
		$consentPromptBehaviorAdmin = if ($systemPolicy -and $systemPolicy.PSObject.Properties['ConsentPromptBehaviorAdmin']) { [int]$systemPolicy.ConsentPromptBehaviorAdmin } else { 5 }
		$promptOnSecureDesktop = if ($systemPolicy -and $systemPolicy.PSObject.Properties['PromptOnSecureDesktop']) { [int]$systemPolicy.PromptOnSecureDesktop } else { 1 }

		switch ("$consentPromptBehaviorAdmin|$promptOnSecureDesktop")
		{
			'1|1' { return 'PromptForCredentials' }
			'2|1' { return 'AlwaysNotify' }
			'5|1' { return 'Default' }
			'5|0' { return 'NoDim' }
			'0|0' { return 'Never' }
			default { return $null }
		}
	}
	'LockScreenBlur' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name DisableAcrylicBackgroundOnLogon -EA SilentlyContinue).DisableAcrylicBackgroundOnLogon -ne 1 }
	'TaskManagerDetails' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskManager" -Name Preferences -EA SilentlyContinue) -ne $null }
	'FileOperationsDetails' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name EnthusiastMode -EA SilentlyContinue).EnthusiastMode -eq 1 }
	'FileDeleteConfirm' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name ConfirmFileDelete -EA SilentlyContinue).ConfirmFileDelete -eq 1 }
	'TrayIcons' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name NoAutoTrayNotify -EA SilentlyContinue).NoAutoTrayNotify -ne 1 }
	'SearchAppInStore' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name NoUseStoreOpenWith -EA SilentlyContinue).NoUseStoreOpenWith -ne 1 }
	'BlockStoreSearchResults' = {
		$storeDbPath = Join-Path $env:LocalAppData 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db'
		if (-not (Test-Path -LiteralPath $storeDbPath))
		{
			return $false
		}

		$acl = Get-Acl -LiteralPath $storeDbPath -EA SilentlyContinue
		if (-not $acl)
		{
			return $false
		}

		foreach ($rule in @($acl.Access))
		{
			try
			{
				$identitySid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
			}
			catch
			{
				$identitySid = $rule.IdentityReference.Value
			}

			if (
				$identitySid -eq 'S-1-1-0' -and
				$rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
				(($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -ne 0)
			)
			{
				return $true
			}
		}

		return $false
	}
	'NewAppPrompt' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name NoNewAppAlert -EA SilentlyContinue).NoNewAppAlert -ne 1 }
	'RecentlyAddedApps' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name HideRecentlyAddedApps -EA SilentlyContinue).HideRecentlyAddedApps -ne 1 }
	'TitleBarColor' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name ColorPrevalence -EA SilentlyContinue).ColorPrevalence -eq 1 }
	'EnhPointerPrecision' = { (Get-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -EA SilentlyContinue).MouseSpeed -eq 1 }
	'StartupSound' = {
		$bootAnimationSound = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation" -Name DisableStartupSound -EA SilentlyContinue).DisableStartupSound
		$editionOverrideSound = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides" -Name UserSetting_DisableStartupSound -EA SilentlyContinue).UserSetting_DisableStartupSound
		($bootAnimationSound -ne 1 -and $editionOverrideSound -ne 1)
	}
	'ChangingSoundScheme' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name NoChangingSoundScheme -EA SilentlyContinue).NoChangingSoundScheme -ne 1 }
	'SoundDuckingPreference' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Multimedia\Audio" -Name UserDuckingPreference -EA SilentlyContinue).UserDuckingPreference -eq 3 }
	'NarratorAudioDucking' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Narrator\NoRoam" -Name DuckAudio -EA SilentlyContinue).DuckAudio -eq 1 }
	'SpeechOneCoreVoiceActivation' = { (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\SpeechOneCore\Settings" -Name AgentActivationEnabled -EA SilentlyContinue).AgentActivationEnabled -eq 1 }
	'AccessibilityActivationSounds' = { (Get-ItemProperty "HKCU:\Control Panel\Accessibility" -Name 'Sound on Activation' -EA SilentlyContinue).'Sound on Activation' -eq 1 }
	'AccessibilityWarningSounds' = { (Get-ItemProperty "HKCU:\Control Panel\Accessibility" -Name 'Warning Sounds' -EA SilentlyContinue).'Warning Sounds' -eq 1 }
	'VerboseStatus' = { (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name VerboseStatus -EA SilentlyContinue).VerboseStatus -eq 1 }
	'StorageSense' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -EA SilentlyContinue)."01" -eq 1 }
	'Hibernation' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name HibernateEnabled -EA SilentlyContinue).HibernateEnabled -eq 1 }
	'BSoDStopError' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name DisplayParameters -EA SilentlyContinue).DisplayParameters -eq 1 }
	'ActiveHours' = {
		$settings = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -EA SilentlyContinue
		($settings -and ($settings.SmartActiveHoursState -eq 0))
	}
	'DeliveryOptimization' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name DODownloadMode -EA SilentlyContinue).DODownloadMode -ne 99 }
	'DownloadUpdatesOverMeteredConnection' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name AllowAutoWindowsUpdateDownloadOverMeteredNetwork -EA SilentlyContinue).AllowAutoWindowsUpdateDownloadOverMeteredNetwork -eq 1 }
	'RestartDeviceAfterUpdate' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name IsExpedited -EA SilentlyContinue).IsExpedited -eq 1 }
	'RestartNotification' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name RestartNotificationsAllowed2 -EA SilentlyContinue).RestartNotificationsAllowed2 -eq 1 }
	'Set-UpdateNotificationLevel' = {
		$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
		$policy = Get-ItemProperty $policyPath -Name SetUpdateNotificationLevel -EA SilentlyContinue
		if (-not $policy -or -not $policy.PSObject.Properties['SetUpdateNotificationLevel'])
		{
			return 'Default'
		}

		switch ([int]$policy.SetUpdateNotificationLevel)
		{
			0 { return 'All' }
			1 { return 'RestartOnly' }
			2 { return 'Off' }
			default { return 'Default' }
		}
	}
	'StoreAppAutoDownload' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name AutoDownload -EA SilentlyContinue).AutoDownload -ne 2 }
	'Set-FeatureUpdateDeferral' = {
		$settings = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -EA SilentlyContinue
		($settings -and $settings.DeferFeatureUpdates -eq 1 -and $settings.DeferFeatureUpdatesPeriodInDays -eq 365)
	}
	'Set-QualityUpdateDeferral' = {
		$settings = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -EA SilentlyContinue
		($settings -and $settings.DeferQualityUpdates -eq 1 -and $settings.DeferQualityUpdatesPeriodInDays -in @(4, 7))
	}
	'Set-StoreAppAutoDownload' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name AutoDownload -EA SilentlyContinue).AutoDownload -eq 4 }
	'Set-WindowsUpdatePause' = {
		$settings = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -EA SilentlyContinue
		$pauseFeature = if ($settings -and $settings.PauseFeatureUpdatesStartTime) { [string]$settings.PauseFeatureUpdatesStartTime } else { $null }
		$pauseQuality = if ($settings -and $settings.PauseQualityUpdatesStartTime) { [string]$settings.PauseQualityUpdatesStartTime } else { $null }
		$pauseGeneral = if ($settings -and $settings.PauseUpdatesStartTime) { [string]$settings.PauseUpdatesStartTime } else { $null }
		$pausedFeature = if ($settings -and $settings.PausedFeatureDate) { [string]$settings.PausedFeatureDate } else { $null }
		$pausedQuality = if ($settings -and $settings.PausedQualityDate) { [string]$settings.PausedQualityDate } else { $null }
		-not [string]::IsNullOrWhiteSpace($pauseFeature) -or
		-not [string]::IsNullOrWhiteSpace($pauseQuality) -or
		-not [string]::IsNullOrWhiteSpace($pauseGeneral) -or
		-not [string]::IsNullOrWhiteSpace($pausedFeature) -or
		-not [string]::IsNullOrWhiteSpace($pausedQuality)
	}
	'Set-WindowsUpdateSecurityOnlyMode' = {
		$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
		$windowsUpdatePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
		$deviceMetadataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
		$driverSearchingPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
		$policyAuOptions = (Get-ItemProperty $policyPath -Name AUOptions -EA SilentlyContinue).AUOptions
		$branchReadiness = (Get-ItemProperty $windowsUpdatePath -Name BranchReadinessLevel -EA SilentlyContinue).BranchReadinessLevel
		$deferFeature = (Get-ItemProperty $windowsUpdatePath -Name DeferFeatureUpdates -EA SilentlyContinue).DeferFeatureUpdates
		$deferFeatureDays = (Get-ItemProperty $windowsUpdatePath -Name DeferFeatureUpdatesPeriodInDays -EA SilentlyContinue).DeferFeatureUpdatesPeriodInDays
		$deferQuality = (Get-ItemProperty $windowsUpdatePath -Name DeferQualityUpdates -EA SilentlyContinue).DeferQualityUpdates
		$deferQualityDays = (Get-ItemProperty $windowsUpdatePath -Name DeferQualityUpdatesPeriodInDays -EA SilentlyContinue).DeferQualityUpdatesPeriodInDays
		$preventMetadata = (Get-ItemProperty $deviceMetadataPath -Name PreventDeviceMetadataFromNetwork -EA SilentlyContinue).PreventDeviceMetadataFromNetwork
		$searchOrder = (Get-ItemProperty $driverSearchingPath -Name SearchOrderConfig -EA SilentlyContinue).SearchOrderConfig
		$excludeDrivers = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name ExcludeWUDriversInQualityUpdate -EA SilentlyContinue).ExcludeWUDriversInQualityUpdate
		$restartDebugger = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\MusNotification.exe" -Name Debugger -EA SilentlyContinue).Debugger
		($policyAuOptions -eq 2 -and
		$branchReadiness -eq 20 -and
		$deferFeature -eq 1 -and
		$deferFeatureDays -eq 365 -and
		$deferQuality -eq 1 -and
		$deferQualityDays -eq 4 -and
		$preventMetadata -eq 1 -and
		$searchOrder -eq 0 -and
		$excludeDrivers -eq 1 -and
		[string]$restartDebugger -eq 'cmd.exe')
	}
	'WindowsManageDefaultPrinter' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -EA SilentlyContinue).LegacyDefaultPrinterMode -ne 1 }
	'SMBServer' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name SMB2 -EA SilentlyContinue).SMB2 -ne 0 }
	'NetBIOS' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" -ErrorAction SilentlyContinue) -ne $null }
	'LLMNR' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name EnableMulticast -EA SilentlyContinue).EnableMulticast -ne 0 }
	'ConnectionSharing' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections" -Name NC_ShowSharedAccessUI -EA SilentlyContinue).NC_ShowSharedAccessUI -ne 0 }
	'ReservedStorage' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager" -Name ShippedWithReserves -EA SilentlyContinue).ShippedWithReserves -eq 1 }
	'NumLock' = { (Get-ItemProperty "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -EA SilentlyContinue).InitialKeyboardIndicators -match "2" }
	'CapsLock' = { -not ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -EA SilentlyContinue)."Scancode Map") }
	'StickyShift' = { (Get-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" -Name Flags -EA SilentlyContinue).Flags -ne 506 }
	'Autoplay' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name DisableAutoplay -EA SilentlyContinue).DisableAutoplay -ne 1 }
	'SaveRestartableApps' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name RestartApps -EA SilentlyContinue).RestartApps -eq 1 }
	'NetworkDiscovery' = { (Get-NetFirewallRule -DisplayGroup "Network Discovery" -EA SilentlyContinue | Where-Object Enabled -eq True | Select-Object -First 1) -ne $null }
	'RegistryBackup' = {
		$periodicBackupEnabled = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager" -Name EnablePeriodicBackup -EA SilentlyContinue).EnablePeriodicBackup -eq 1
		$autoRegBackupTask = $false
		try
		{
			$autoRegBackupTask = [bool](Get-ScheduledTask -TaskName 'AutoRegBackup' -ErrorAction SilentlyContinue)
		}
		catch
		{
			$autoRegBackupTask = $false
		}
		($periodicBackupEnabled -and $autoRegBackupTask)
	}
	'XboxGameBar' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name AppCaptureEnabled -EA SilentlyContinue).AppCaptureEnabled -ne 0 }
	'XboxGameTips' = { (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name ShowStartupPanel -EA SilentlyContinue).ShowStartupPanel -ne 0 }
	'GPUScheduling' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name HwSchMode -EA SilentlyContinue).HwSchMode -eq 2 }
	'GameDVR' = { (Get-ItemProperty "HKCU:\System\GameConfigStore" -Name GameDVR_Enabled -EA SilentlyContinue).GameDVR_Enabled -ne 0 }
	'WindowsGameMode' = { (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name AutoGameModeEnabled -EA SilentlyContinue).AutoGameModeEnabled -ne 0 }
	'MouseAcceleration' = { (Get-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -EA SilentlyContinue).MouseSpeed -ne "0" }
	'NaglesAlgorithm' = { -not ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\*" -Name TCPNoDelay -EA SilentlyContinue).TCPNoDelay -contains 1) }
	'NetworkProtection' = { try { (Get-MpPreference -EA Stop).EnableNetworkProtection -eq 1 } catch { $false } }
	'DefenderSandbox' = { [System.Environment]::GetEnvironmentVariable("MP_FORCE_USE_SANDBOX","Machine") -eq "1" }
	'PowerShellModulesLogging' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name EnableModuleLogging -EA SilentlyContinue).EnableModuleLogging -eq 1 }
	'PowerShellScriptsLogging' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -EA SilentlyContinue).EnableScriptBlockLogging -eq 1 }
	'AppsSmartScreen' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name EnableSmartScreen -EA SilentlyContinue).EnableSmartScreen -ne 0 }
	'SaveZoneInformation' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name SaveZoneInformation -EA SilentlyContinue).SaveZoneInformation -ne 2 }
	'WindowsScriptHost' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows Script Host\Settings" -Name Enabled -EA SilentlyContinue).Enabled -ne 0 }
	'WindowsSandbox' = { (Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -EA SilentlyContinue).State -eq "Enabled" }
	'LocalSecurityAuthority' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RunAsPPL -EA SilentlyContinue).RunAsPPL -ge 1 }
	'SharingMappedDrives' = { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLinkedConnections -EA SilentlyContinue).EnableLinkedConnections -eq 1 }
	'Firewall' = { (Get-NetFirewallProfile -EA SilentlyContinue | Where-Object Enabled -eq True | Select-Object -First 1) -ne $null }
	'DefenderTrayIcon' = { (Get-ItemProperty "HKCU:\Software\Policies\Microsoft\Windows Defender Security Center\Systray" -Name HideSystray -EA SilentlyContinue).HideSystray -ne 1 }
	'DefenderCloud' = { (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name SpynetReporting -EA SilentlyContinue).SpynetReporting -ne 0 }
	'CIMemoryIntegrity' = { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name Enabled -EA SilentlyContinue).Enabled -eq 1 }
	'AccountProtectionWarn' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows Security Health\State" -Name AccountProtection_MicrosoftAccount_Disconnected -EA SilentlyContinue).AccountProtectionWarn -ne 1 }
	'DownloadBlocking' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" -Name SaveZoneInformation -EA SilentlyContinue).SaveZoneInformation -ne 2 }
	'F8BootMenu' = { (bcdedit /enum "{current}" 2>$null) -match "bootmenupolicy.*legacy" }
	'BootRecovery' = { (bcdedit /enum "{current}" 2>$null) -match "recoveryenabled.*Yes" }
	'MSIExtractContext' = { Test-Path "Registry::HKEY_CLASSES_ROOT\Msi.Package\shell\Extract" }
	'CABInstallContext' = { Test-Path "Registry::HKEY_CLASSES_ROOT\CABFolder\Shell\runas" }
	'MultipleInvokeContext' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name MultipleInvokePromptMinimum -EA SilentlyContinue).MultipleInvokePromptMinimum -ge 15 }
	'OpenWindowsTerminalContext' = { Test-Path "Registry::HKEY_CLASSES_ROOT\Directory\shell\OpenWTHere" }
	'SecondsInSystemClock' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowSecondsInSystemClock -EA SilentlyContinue).ShowSecondsInSystemClock -eq 1 }
	'ClockInNotificationCenter' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowClock -EA SilentlyContinue).ShowClock -ne 0 }
	'NetworkThrottling' = { (Get-ItemProperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name NetworkThrottlingIndex -EA SilentlyContinue).NetworkThrottlingIndex -ne -1 }
	'GameBarController' = { (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name UseNexusForGameBarEnabled -EA SilentlyContinue).UseNexusForGameBarEnabled -ne 0 }
	'DesktopComposition' = { (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\DWM" -Name CompositionPolicy -EA SilentlyContinue).CompositionPolicy -ne 0 }
	'XboxAuthManager' = { (Get-Service XblAuthManager -EA SilentlyContinue).StartType -ne "Disabled" }
	'XboxGameSave' = { (Get-Service XblGameSave -EA SilentlyContinue).StartType -ne "Disabled" }
	'XboxNetworking' = { (Get-Service XboxNetApiSvc -EA SilentlyContinue).StartType -ne "Disabled" }
}

# VisibleIf scriptblocks keyed by Function name.
# Controls OS-specific tweak visibility (e.g. Win10 vs Win11).
$Script:VisibleIfScriptblocks = @{
	# Hidden in the GUI; preset and headless paths still resolve the manifest entry.
	'CheckWinGet' = { $false }
	'LockScreen' = { ((Get-OSInfo).OSName -like "*Windows 11*") }
	'LockScreenRS1' = { ((Get-OSInfo).OSName -like "*Windows 10*") }
}
#endregion Detect & Visibility Scriptblocks

$Script:TweakManifest = @()
$Script:ManifestLoadedFromData = $false

# Defined at module scope so Show-TweakGUI can capture them once for deferred
# WPF event handlers and dispatcher callbacks.
<#
    .SYNOPSIS
    Internal function Test-IsSafeModeUX.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-IsSafeModeUX { return ([bool]$Script:SafeMode) }
<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Test-IsExpertModeUX { return ([bool]$Script:AdvancedMode) }
<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Test-GuiRunInProgress { return [bool]$Script:RunInProgress }

<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-ApplicationEntityType
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	$validEntityTypes = @('winget', 'choco', 'uwp', 'feature', 'system', 'placeholder')

	if ($Entry -and $Entry.PSObject.Properties['EntityType'])
	{
		$explicitType = [string]$Entry.EntityType
		if (-not [string]::IsNullOrWhiteSpace($explicitType))
		{
			$normalizedType = $explicitType.Trim().ToLowerInvariant()
			if ($validEntityTypes -contains $normalizedType)
			{
				return $normalizedType
			}
		}
	}

	if ($Entry -and $Entry.PSObject.Properties['Type'])
	{
		$explicitType = [string]$Entry.Type
		if (-not [string]::IsNullOrWhiteSpace($explicitType))
		{
			$normalizedType = $explicitType.Trim().ToLowerInvariant()
			if ($validEntityTypes -contains $normalizedType)
			{
				return $normalizedType
			}
		}
	}

	$topLevelWinGetId = $null
	$topLevelChocoId = $null
	try
	{
		if ($Entry.PSObject.Properties['WinGetId'])
		{
			$topLevelWinGetId = [string]$Entry.WinGetId
		}
		if ($Entry.PSObject.Properties['ChocoId'])
		{
			$topLevelChocoId = [string]$Entry.ChocoId
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelWinGetId))
	{
		return 'winget'
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelChocoId))
	{
		return 'choco'
	}

	$winGetId = $null
	$chocoId = $null
	try
	{
		if ($Entry.ExtraArgs)
		{
			if ($Entry.ExtraArgs.PSObject.Properties['WinGetId'])
			{
				$winGetId = [string]$Entry.ExtraArgs.WinGetId
			}
			if ($Entry.ExtraArgs.PSObject.Properties['ChocoId'])
			{
				$chocoId = [string]$Entry.ExtraArgs.ChocoId
			}
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($winGetId))
	{
		return 'winget'
	}

	if (-not [string]::IsNullOrWhiteSpace($chocoId))
	{
		return 'choco'
	}

	return 'placeholder'
}

<#
    .SYNOPSIS
    Internal function Test-ApplicationExecutionSupport.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-ApplicationExecutionSupport
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	if ($Entry -and $Entry.PSObject.Properties['SupportsExecution'] -and -not [bool]$Entry.SupportsExecution)
	{
		return $false
	}

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$winGetId = $null
	$chocoId = $null
	$storeUri = $null
	$directUrl = $null
	$command = $null

	try
	{
		if ($Entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.WinGetId))
		{
			$winGetId = [string]$Entry.WinGetId
		}
		elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.WinGetId))
		{
			$winGetId = [string]$Entry.ExtraArgs.WinGetId
		}

		if ($Entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ChocoId))
		{
			$chocoId = [string]$Entry.ChocoId
		}
		elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.ChocoId))
		{
			$chocoId = [string]$Entry.ExtraArgs.ChocoId
		}

		if ($Entry.ExtraArgs)
		{
			if ($Entry.ExtraArgs.PSObject.Properties['StoreUri'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.StoreUri))
			{
				$storeUri = [string]$Entry.ExtraArgs.StoreUri
			}
			if ($Entry.ExtraArgs.PSObject.Properties['DirectUrl'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.DirectUrl))
			{
				$directUrl = [string]$Entry.ExtraArgs.DirectUrl
			}
			if ($Entry.ExtraArgs.PSObject.Properties['Command'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.Command))
			{
				$command = [string]$Entry.ExtraArgs.Command
			}
		}
	}
	catch
	{
		$null = $_
	}

	switch ($entityType)
	{
		'uwp' { return $false }
		'feature' { return $false }
		'system' { return $false }
		'placeholder' { return $false }
		default
		{
			if (-not [string]::IsNullOrWhiteSpace($storeUri) -or -not [string]::IsNullOrWhiteSpace($directUrl) -or -not [string]::IsNullOrWhiteSpace($command))
			{
				return $true
			}

			if (-not [string]::IsNullOrWhiteSpace($chocoId))
			{
				return $true
			}

			if (-not [string]::IsNullOrWhiteSpace($winGetId))
			{
				if (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue)
				{
					try
					{
						return [bool](Test-WinGetAvailable)
					}
					catch
					{
						return $false
					}
				}

				return $true
			}

			return $false
		}
	}
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationCatalogIdentityKey.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-ApplicationCatalogIdentityKey
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry
	)

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$topLevelWinGetId = $null
	$topLevelChocoId = $null
	try
	{
		if ($Entry.PSObject.Properties['WinGetId'])
		{
			$topLevelWinGetId = [string]$Entry.WinGetId
		}
		if ($Entry.PSObject.Properties['ChocoId'])
		{
			$topLevelChocoId = [string]$Entry.ChocoId
		}
	}
	catch
	{
		$null = $_
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelWinGetId))
	{
		return ("winget:{0}" -f [string]$topLevelWinGetId.Trim().ToLowerInvariant())
	}

	if (-not [string]::IsNullOrWhiteSpace($topLevelChocoId))
	{
		return ("choco:{0}" -f [string]$topLevelChocoId.Trim().ToLowerInvariant())
	}

	if ($Entry.ExtraArgs)
	{
		try
		{
			if ($Entry.ExtraArgs.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.WinGetId))
			{
				return ("winget:{0}" -f [string]$Entry.ExtraArgs.WinGetId.Trim().ToLowerInvariant())
			}
			if ($Entry.ExtraArgs.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.ChocoId))
			{
				return ("choco:{0}" -f [string]$Entry.ExtraArgs.ChocoId.Trim().ToLowerInvariant())
			}
		}
		catch
		{
			$null = $_
		}
	}

	$name = if (-not [string]::IsNullOrWhiteSpace([string]$Entry.Name)) { [string]$Entry.Name.Trim().ToLowerInvariant() } else { '<unknown>' }
	$subCategory = if (-not [string]::IsNullOrWhiteSpace([string]$Entry.SubCategory)) { [string]$Entry.SubCategory.Trim().ToLowerInvariant() } else { '<none>' }
	return ("{0}:{1}:{2}" -f $entityType, $subCategory, $name)
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationExecutionState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-ApplicationExecutionState
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Entry,

		[hashtable]$WinGetInstalledCache = @{},

		[hashtable]$ChocolateyInstalledCache = @{},

		[hashtable]$WinGetUpdateCache = @{},

		[hashtable]$ChocolateyUpdateCache = @{},

		[string]$PreferredSource = $null
	)

	$entityType = Get-ApplicationEntityType -Entry $Entry
	$selectionKey = Get-ApplicationCatalogIdentityKey -Entry $Entry
	$supportsExecution = Test-ApplicationExecutionSupport -Entry $Entry
	$normalizedPreferredSource = if ([string]::IsNullOrWhiteSpace([string]$PreferredSource))
	{
		$null
	}
	else
	{
		switch ([string]$PreferredSource.Trim().ToLowerInvariant())
		{
			'winget' { 'winget' }
			'choco' { 'choco' }
			'chocolatey' { 'choco' }
			default { $null }
		}
	}
	$sourceForState = $null
	$winGetId = $null
	$chocoId = $null
	$storeUri = $null
	$directUrl = $null
	$command = $null
	$packageId = $null
	$updateKey = $null
	$isInstalled = $false
	$hasUpdateAvailable = $false

	if ($Entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.WinGetId))
	{
		$winGetId = [string]$Entry.WinGetId
	}
	elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['WinGetId'])
	{
		$winGetId = [string]$Entry.ExtraArgs.WinGetId
	}

	if ($Entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ChocoId))
	{
		$chocoId = [string]$Entry.ChocoId
	}
	elseif ($Entry.ExtraArgs -and $Entry.ExtraArgs.PSObject.Properties['ChocoId'])
	{
		$chocoId = [string]$Entry.ExtraArgs.ChocoId
	}

	if ($Entry.ExtraArgs)
	{
		if ($Entry.ExtraArgs.PSObject.Properties['StoreUri'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.StoreUri))
		{
			$storeUri = [string]$Entry.ExtraArgs.StoreUri
		}
		if ($Entry.ExtraArgs.PSObject.Properties['DirectUrl'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.DirectUrl))
		{
			$directUrl = [string]$Entry.ExtraArgs.DirectUrl
		}
		if ($Entry.ExtraArgs.PSObject.Properties['Command'] -and -not [string]::IsNullOrWhiteSpace([string]$Entry.ExtraArgs.Command))
		{
			$command = [string]$Entry.ExtraArgs.Command
		}
	}

	$wingetAvailable = $true
	if (-not [string]::IsNullOrWhiteSpace($winGetId) -and (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$wingetAvailable = [bool](Test-WinGetAvailable)
		}
		catch
		{
			$wingetAvailable = $false
		}
	}
	$chocolateyAvailable = $true
	if (-not [string]::IsNullOrWhiteSpace($chocoId) -and (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$chocolateyAvailable = [bool](Test-ChocolateyAvailable)
		}
		catch
		{
			$chocolateyAvailable = $false
		}
	}

	if ($normalizedPreferredSource -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif ($normalizedPreferredSource -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	elseif ($entityType -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif ($entityType -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	elseif (-not [string]::IsNullOrWhiteSpace($winGetId))
	{
		$sourceForState = 'winget'
	}
	elseif (-not [string]::IsNullOrWhiteSpace($chocoId))
	{
		$sourceForState = 'choco'
	}
	else
	{
		$sourceForState = $entityType
	}

	switch ($sourceForState)
	{
		'winget'
		{
			$packageId = $winGetId
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				if (-not $wingetAvailable)
				{
					if (-not [string]::IsNullOrWhiteSpace($chocoId) -and $chocolateyAvailable)
					{
						$sourceForState = 'choco'
						$packageId = $chocoId
						$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $ChocolateyInstalledCache)
						$updateKey = [string]$packageId
						$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $ChocolateyUpdateCache)
					}
					else
					{
						$sourceForState = 'unsupported'
						$packageId = $null
						$supportsExecution = $false
					}
				}
				else
				{
					$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $WinGetInstalledCache)
					$updateKey = [string]$packageId
					$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $WinGetUpdateCache)
				}
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'choco'
		{
			$packageId = $chocoId
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $ChocolateyInstalledCache)
				$updateKey = [string]$packageId
				$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $ChocolateyUpdateCache)
				if (-not $chocolateyAvailable)
				{
					if (-not [string]::IsNullOrWhiteSpace($winGetId) -and $wingetAvailable)
					{
						$sourceForState = 'winget'
						$packageId = $winGetId
						$isInstalled = [bool](Test-ApplicationPackageIdInCache -PackageId $packageId -Cache $WinGetInstalledCache)
						$updateKey = [string]$packageId
						$hasUpdateAvailable = $isInstalled -and [bool](Test-ApplicationPackageIdInCache -PackageId $updateKey -Cache $WinGetUpdateCache)
					}
					else
					{
						$sourceForState = 'unsupported'
						$packageId = $null
						$isInstalled = $false
						$hasUpdateAvailable = $false
						$supportsExecution = $false
					}
				}
			}
			else
			{
				$sourceForState = 'unsupported'
				$packageId = $null
				$supportsExecution = $false
			}
		}
		'store'
		{
			$packageId = $storeUri
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'direct'
		{
			$packageId = $directUrl
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		'command'
		{
			$packageId = $command
			if (-not [string]::IsNullOrWhiteSpace($packageId))
			{
				$supportsExecution = [bool]$supportsExecution
			}
			else
			{
				$supportsExecution = $false
			}
		}
		default
		{
			$supportsExecution = $false
			$isInstalled = $false
			$hasUpdateAvailable = $false
		}
	}

	$state = if (-not $supportsExecution)
	{
		'Unsupported'
	}
	elseif ($hasUpdateAvailable)
	{
		'Update available'
	}
	elseif ($isInstalled)
	{
		'Installed'
	}
	else
	{
		'Not installed'
	}

	$primaryAction = if (-not $supportsExecution)
	{
		$null
	}
	elseif ($hasUpdateAvailable)
	{
		'Update'
	}
	elseif ($isInstalled)
	{
		'Uninstall'
	}
	else
	{
		'Install'
	}

	$route = $null
	if ($supportsExecution -and (Get-Command -Name 'Resolve-ApplicationExecutionRoute' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$route = Resolve-ApplicationExecutionRoute -Application $Entry -PreferredSource $PreferredSource -Action $(if ([string]::IsNullOrWhiteSpace($primaryAction)) { 'Install' } else { $primaryAction })
		}
		catch
		{
			$route = $null
		}
	}

	return [pscustomobject]@{
		SelectionKey = $selectionKey
		EntityType = $entityType
		SupportsExecution = [bool]$supportsExecution
		State = $state
		IsInstalled = [bool]$isInstalled
		UpdateAvailable = [bool]$hasUpdateAvailable
		PackageId = $packageId
		PreferredSource = if ($route -and $route.PSObject.Properties['PreferredSource']) { [string]$route.PreferredSource } else { $normalizedPreferredSource }
		SelectedSource = if ($route -and $route.PSObject.Properties['SelectedSource']) { [string]$route.SelectedSource } else { $sourceForState }
		AvailableSources = if ($route -and $route.PSObject.Properties['AvailableSources']) { @($route.AvailableSources) } else { @() }
		Route = if ($route -and $route.PSObject.Properties['Route']) { [string]$route.Route } else { $sourceForState }
		Action = $primaryAction
	}
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationCacheSnapshot.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-ApplicationCacheSnapshot
{
	[CmdletBinding()]
	param (
		[object]$CacheState
	)

	$snapshot = [pscustomobject]@{
		WinGet = @{}
		Chocolatey = @{}
		WinGetUpdates = @{}
		ChocolateyUpdates = @{}
	}

	if ($CacheState -is [hashtable])
	{
		$snapshot.WinGet = $CacheState
		return $snapshot
	}

	if ($CacheState -and $CacheState.PSObject.Properties['WinGet'])
	{
		if ($CacheState.WinGet -is [hashtable])
		{
			$snapshot.WinGet = $CacheState.WinGet
		}
		if ($CacheState.PSObject.Properties['Chocolatey'] -and ($CacheState.Chocolatey -is [hashtable]))
		{
			$snapshot.Chocolatey = $CacheState.Chocolatey
		}
		if ($CacheState.PSObject.Properties['WinGetUpdates'] -and ($CacheState.WinGetUpdates -is [hashtable]))
		{
			$snapshot.WinGetUpdates = $CacheState.WinGetUpdates
		}
		if ($CacheState.PSObject.Properties['ChocolateyUpdates'] -and ($CacheState.ChocolateyUpdates -is [hashtable]))
		{
			$snapshot.ChocolateyUpdates = $CacheState.ChocolateyUpdates
		}
	}

	return $snapshot
}

<#
    .SYNOPSIS
    Internal function Get-BaselineApplicationsCatalog.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-BaselineApplicationsCatalog
{
	[CmdletBinding()]
	param (
		[switch]$Force
	)

	if (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { $null = Test-WinGetAvailable -Refresh } catch { $null = $_ }
	}
	if (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { $null = Test-ChocolateyAvailable -Refresh } catch { $null = $_ }
	}

	if (-not $Force -and ($Script:BaselineApplicationsCatalog -is [System.Array]) -and $Script:BaselineApplicationsCatalog.Count -gt 0)
	{
		return $Script:BaselineApplicationsCatalog
	}

	$catalogDirectory = $null
	$candidateCatalogDirectories = [System.Collections.Generic.List[string]]::new()
	foreach ($basePath in @($Script:GuiModuleBasePath))
	{
		if ([string]::IsNullOrWhiteSpace([string]$basePath))
		{
			continue
		}

		try
		{
			[void]$candidateCatalogDirectories.Add((Join-Path -Path $basePath -ChildPath 'Data\AppsCategory'))
			if ((Split-Path -Path $basePath -Leaf) -ieq 'Regions')
			{
				$moduleRoot = Split-Path -Path $basePath -Parent
				if (-not [string]::IsNullOrWhiteSpace([string]$moduleRoot))
				{
					[void]$candidateCatalogDirectories.Add((Join-Path -Path $moduleRoot -ChildPath 'Data\AppsCategory'))
				}
			}
		}
		catch
		{
			$null = $_
		}
	}

	$catalogFiles = @()
	foreach ($candidateDirectory in @($candidateCatalogDirectories | Select-Object -Unique))
	{
		if (-not [string]::IsNullOrWhiteSpace([string]$candidateDirectory) -and (Test-Path -LiteralPath $candidateDirectory -PathType Container))
		{
			$catalogDirectory = $candidateDirectory
			$catalogFiles = @(Get-ChildItem -LiteralPath $catalogDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
			if ($catalogFiles.Count -gt 0)
			{
				break
			}
		}
	}

	if (-not $catalogFiles -or $catalogFiles.Count -eq 0)
	{
		LogError (Get-UxBilingualLocalizedString -Key 'GuiLogApplicationsCatalogNotFound' -Fallback 'Applications catalog not found: {0}' -FormatArgs @($catalogDirectory))
		$Script:BaselineApplicationsCatalog = @()
		return $Script:BaselineApplicationsCatalog
	}

	try
	{
		$catalogFilesJson = foreach ($catalogFile in $catalogFiles)
		{
			[pscustomobject]@{
				Path = [string]$catalogFile.FullName
				Json = (Get-Content -LiteralPath $catalogFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
			}
		}
	}
	catch
	{
		LogError (Get-UxBilingualLocalizedString -Key 'GuiLogApplicationsCatalogLoadFailed' -Fallback 'Failed to load applications catalog: {0}' -FormatArgs @($_.Exception.Message))
		$Script:BaselineApplicationsCatalog = @()
		return $Script:BaselineApplicationsCatalog
	}

	$dedupe = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$catalog = [System.Collections.Generic.List[object]]::new()

	foreach ($catalogFile in @($catalogFilesJson))
	{
		foreach ($entry in @($catalogFile.Json.Entries))
		{
			if (-not $entry) { continue }

			$winGetId = $null
			$chocoId = $null
			try
			{
				if ($entry.PSObject.Properties['WinGetId'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.WinGetId))
				{
					$winGetId = [string]$entry.WinGetId
				}
				if ($entry.PSObject.Properties['ChocoId'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.ChocoId))
				{
					$chocoId = [string]$entry.ChocoId
				}
				if ($entry.ExtraArgs)
				{
					if ($entry.ExtraArgs.PSObject.Properties['WinGetId'])
					{
						$winGetId = [string]$entry.ExtraArgs.WinGetId
					}
					if ($entry.ExtraArgs.PSObject.Properties['ChocoId'])
					{
						$chocoId = [string]$entry.ExtraArgs.ChocoId
					}
				}
			}
			catch
			{
				$null = $_
			}

			$identityKey = Get-ApplicationCatalogIdentityKey -Entry $entry
			if (-not $dedupe.Add($identityKey)) { continue }

			$displayName = if (-not [string]::IsNullOrWhiteSpace([string]$entry.Name)) { [string]$entry.Name } else { $(if (-not [string]::IsNullOrWhiteSpace($winGetId)) { $winGetId } elseif (-not [string]::IsNullOrWhiteSpace($chocoId)) { $chocoId } else { 'Unknown application' }) }
			$entityType = Get-ApplicationEntityType -Entry $entry
			$supportsExecution = Test-ApplicationExecutionSupport -Entry $entry
			$descriptionKey = $null
			if ($entry.PSObject.Properties['DescriptionKey'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.DescriptionKey))
			{
				$descriptionKey = [string]$entry.DescriptionKey
			}
			else
			{
				$identitySlug = (($identityKey -replace '[^A-Za-z0-9]+', '_').Trim('_'))
				if (-not [string]::IsNullOrWhiteSpace([string]$identitySlug))
				{
					$descriptionKey = 'GuiAppDescription_{0}' -f $identitySlug
				}
			}
			$resolvedDescription = if (-not [string]::IsNullOrWhiteSpace([string]$descriptionKey))
			{
				Get-UxLocalizedString -Key $descriptionKey -Fallback ([string]$entry.Description)
			}
			else
			{
				[string]$entry.Description
			}
			$searchIndex = @(
				$displayName
				$winGetId
				$chocoId
				$entityType
				$resolvedDescription
				$entry.Detail
				$entry.SubCategory
				($entry.Tags -join ' ')
				$entry.Risk
				$entry.Impact
				$entry.WhyThisMatters
				$entry.SourceRegion
			)
			if ($entry.ExtraArgs)
			{
				$searchIndex += @(
					$entry.ExtraArgs.WinGetId
					$entry.ExtraArgs.ChocoId
					$entry.ExtraArgs.StoreUri
					$entry.ExtraArgs.DirectUrl
					$entry.ExtraArgs.Command
				)
			}
			$searchIndex = @($searchIndex | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ }) -join ' '

			[void]$catalog.Add([pscustomobject]@{
				Name = $displayName
				WinGetId = $winGetId
				ChocoId = $chocoId
				Type = $entityType
				EntityType = $entityType
				SupportsExecution = [bool]$supportsExecution
				Description = [string]$resolvedDescription
				DescriptionKey = [string]$descriptionKey
				Detail = [string]$entry.Detail
				SubCategory = [string]$entry.SubCategory
				Tags = @($entry.Tags)
				Risk = [string]$entry.Risk
				Safe = [bool]$entry.Safe
				Impact = [string]$entry.Impact
				RequiresRestart = [bool]$entry.RequiresRestart
				Caution = [bool]$entry.Caution
				WhyThisMatters = [string]$entry.WhyThisMatters
				SourceRegion = [string]$entry.SourceRegion
				ExtraArgs = $entry.ExtraArgs
				SearchIndex = [string]$searchIndex.ToLowerInvariant()
			})
		}
	}

	$Script:BaselineApplicationsCatalog = @($catalog)
	return $Script:BaselineApplicationsCatalog
}

<#
    .SYNOPSIS
    Internal function Set-AppsActionControlsEnabled.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-AppsActionControlsEnabled
{
	[CmdletBinding()]
	param (
		[bool]$Enabled = $true
	)

	if ($Script:BtnUpdateAllApps) { $Script:BtnUpdateAllApps.IsEnabled = $Enabled }
	if ($Script:BtnRun -and $Script:AppsModeActive) { $Script:BtnRun.IsEnabled = $Enabled }
	if ($Script:AppsBulkActionButtons -is [System.Collections.IEnumerable])
	{
		foreach ($bulkButton in @($Script:AppsBulkActionButtons))
		{
			if ($bulkButton)
			{
				try { $bulkButton.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if ($Script:CmbAppsCategoryFilter)
	{
		try { $Script:CmbAppsCategoryFilter.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnAppsSourceWinGet)
	{
		try { $Script:BtnAppsSourceWinGet.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnAppsSourceChocolatey)
	{
		try { $Script:BtnAppsSourceChocolatey.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnApplyQueuedActions)
	{
		try { $Script:BtnApplyQueuedActions.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:BtnClearQueuedActions)
	{
		try { $Script:BtnClearQueuedActions.IsEnabled = $Enabled } catch { $null = $_ }
	}
	if ($Script:AppsActionButtons -is [System.Collections.IEnumerable])
	{
		foreach ($actionButton in @($Script:AppsActionButtons))
		{
			if ($actionButton)
			{
				try { $actionButton.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if ($Script:AppsQueuedActionControls -is [System.Collections.IEnumerable])
	{
		foreach ($queuedControl in @($Script:AppsQueuedActionControls))
		{
			if (-not $queuedControl) { continue }
			foreach ($controlName in @('Install', 'Uninstall', 'DoNothing'))
			{
				if ($queuedControl.PSObject.Properties[$controlName] -and $queuedControl.$controlName)
				{
					try { $queuedControl.$controlName.IsEnabled = $Enabled } catch { $null = $_ }
				}
			}
		}
	}
	if ($Script:AppsSelectionControls -is [System.Collections.IEnumerable])
	{
		foreach ($selectionControl in @($Script:AppsSelectionControls))
		{
			if ($selectionControl)
			{
				try { $selectionControl.IsEnabled = $Enabled } catch { $null = $_ }
			}
		}
	}
	if (Get-Command -Name 'Update-AppsSelectionSummary' -CommandType Function -ErrorAction SilentlyContinue)
	{
		Update-AppsSelectionSummary
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsSelectionState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Initialize-AppsSelectionState
{
	[CmdletBinding()]
	param ()

	if (-not ($Script:SelectedAppIds -is [System.Collections.Generic.HashSet[string]]))
	{
		$Script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not ($Script:AppsSelectionControls -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	}
	if (-not ($Script:AppsBulkActionButtons -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
	}
	if ($null -eq $Script:AppsSelectionUiUpdating)
	{
		$Script:AppsSelectionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsQueuedActionState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Initialize-AppsQueuedActionState
{
	<#
		.SYNOPSIS
		Lazily initialises the per-app queued-action dictionary.
		Keys are app IDs (case-insensitive); values are 'Install', 'Uninstall', or 'DoNothing'.
	#>
	[CmdletBinding()]
	param ()

	if (-not ($Script:AppsQueuedActions -is [System.Collections.Generic.Dictionary[string, string]]))
	{
		$Script:AppsQueuedActions = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not ($Script:AppsQueuedActionControls -is [System.Collections.Generic.List[object]]))
	{
		$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	}
	if (-not ($Script:AppsQueuedActionControlMap -is [System.Collections.Generic.Dictionary[string, object]]))
	{
		$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if ($null -eq $Script:AppsQueuedActionUiUpdating)
	{
		$Script:AppsQueuedActionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Sync-AppsQueuedActionControls.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Sync-AppsQueuedActionControls
{
	<#
		.SYNOPSIS
		Updates the queued-action radio buttons so they match the pending queue state.
	#>
	[CmdletBinding()]
	param (
		[string]$AppId
	)

	Initialize-AppsQueuedActionState
	if ($Script:AppsQueuedActionUiUpdating) { return }

	$controlPairs = @()
	if (-not [string]::IsNullOrWhiteSpace($AppId))
	{
		$controlSet = $null
		if ($Script:AppsQueuedActionControlMap.TryGetValue([string]$AppId, [ref]$controlSet))
		{
			$controlPairs = @([pscustomobject]@{
				AppId = [string]$AppId
				Controls = $controlSet
			})
		}
	}
	else
	{
		foreach ($pair in @($Script:AppsQueuedActionControlMap.GetEnumerator()))
		{
			if (-not $pair.Value) { continue }
			$controlPairs += [pscustomobject]@{
				AppId = [string]$pair.Key
				Controls = $pair.Value
			}
		}
	}

	if ($controlPairs.Count -eq 0) { return }

	$Script:AppsQueuedActionUiUpdating = $true
	try
	{
		foreach ($pair in @($controlPairs))
		{
			$action = Get-AppQueuedAction -AppId $pair.AppId
			$controls = $pair.Controls
			if (-not $controls) { continue }

			try
			{
				if ($controls.PSObject.Properties['Install'] -and $controls.Install)
				{
					$controls.Install.IsChecked = ([string]$action -eq 'Install')
				}
				if ($controls.PSObject.Properties['Uninstall'] -and $controls.Uninstall)
				{
					$controls.Uninstall.IsChecked = ([string]$action -eq 'Uninstall')
				}
				if ($controls.PSObject.Properties['DoNothing'] -and $controls.DoNothing)
				{
					$controls.DoNothing.IsChecked = ([string]$action -eq 'DoNothing')
				}
			}
			catch
			{
				$null = $_
			}
		}
	}
	finally
	{
		$Script:AppsQueuedActionUiUpdating = $false
	}
}

<#
    .SYNOPSIS
    Internal function Get-QueuedAppsProfileActions.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-QueuedAppsProfileActions
{
	<#
		.SYNOPSIS
		Builds a portable list of queued app actions for configuration profiles.
	#>
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState

	$catalog = @(Get-BaselineApplicationsCatalog)
	if ($catalog.Count -eq 0 -or $Script:AppsQueuedActions.Count -eq 0)
	{
		return @()
	}

	$profileActions = [System.Collections.Generic.List[object]]::new()
	foreach ($app in @($catalog))
	{
		if (-not $app) { continue }

		$appId = Get-ApplicationCatalogIdentityKey -Entry $app
		$action = Get-AppQueuedAction -AppId $appId
		if ([string]::IsNullOrWhiteSpace([string]$action) -or $action -eq 'DoNothing')
		{
			continue
		}

		$profileActions.Add([ordered]@{
			AppId = [string]$appId
			Action = [string]$action
			Name = if ($app.PSObject.Properties['Name']) { [string]$app.Name } else { $null }
			WinGetId = if ($app.PSObject.Properties['WinGetId']) { [string]$app.WinGetId } else { $null }
			ChocoId = if ($app.PSObject.Properties['ChocoId']) { [string]$app.ChocoId } else { $null }
		}) | Out-Null
	}

	return @($profileActions)
}

<#
    .SYNOPSIS
    Internal function Set-AppQueuedAction.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-AppQueuedAction
{
	<#
		.SYNOPSIS
		Records the desired action for a single app in the pending queue.

		.DESCRIPTION
		Sets the per-app queued action to Install, Uninstall, or DoNothing.
		Setting DoNothing (the default) removes the entry so the queue stays
		clean and only explicitly requested changes are applied.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$AppId,

		[Parameter(Mandatory)]
		[ValidateSet('Install', 'Uninstall', 'DoNothing')]
		[string]$Action
	)

	Initialize-AppsQueuedActionState
	$normalizedId = [string]$AppId.Trim()
	if ([string]::IsNullOrWhiteSpace($normalizedId)) { return }

	if ($Action -eq 'DoNothing')
	{
		[void]$Script:AppsQueuedActions.Remove($normalizedId)
	}
	else
	{
		$Script:AppsQueuedActions[$normalizedId] = $Action
	}

	Sync-AppsQueuedActionControls -AppId $normalizedId
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Get-AppQueuedAction.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-AppQueuedAction
{
	<#
		.SYNOPSIS
		Returns the queued action for an app (Install, Uninstall, or DoNothing).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$AppId
	)

	Initialize-AppsQueuedActionState
	$normalizedId = [string]$AppId.Trim()
	if ([string]::IsNullOrWhiteSpace($normalizedId))
	{
		return 'DoNothing'
	}
	$value = $null
	if ($Script:AppsQueuedActions.TryGetValue($normalizedId, [ref]$value))
	{
		return $value
	}
	return 'DoNothing'
}

<#
    .SYNOPSIS
    Internal function Clear-AppsQueuedActions.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Clear-AppsQueuedActions
{
	<#
		.SYNOPSIS
		Clears all pending queued app actions without touching the selection state.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState
	$Script:AppsQueuedActions.Clear()
	Sync-AppsQueuedActionControls
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Start-AppsModuleQueuedActionAsync
{
	<#
		.SYNOPSIS
		Applies the per-app queued actions (Install / Uninstall) in a single pass.

		.DESCRIPTION
		Reads $Script:AppsQueuedActions, groups apps by requested action, and
		dispatches one Start-AppsModuleBatchActionAsync call per action type.
		Install and uninstall batches are sequenced so the app action runspace has
		time to finish, refresh caches, and return to an idle state before the next
		group begins. The queue is cleared after the last group finishes.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	[CmdletBinding()]
	param ()

	Initialize-AppsQueuedActionState

	if ($Script:AppsQueuedActions.Count -eq 0) { return }
	if ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress) { return }

	$catalog = $Script:BaselineApplicationsCatalog
	if (-not $catalog) { return }

	$installApps   = [System.Collections.Generic.List[object]]::new()
	$uninstallApps = [System.Collections.Generic.List[object]]::new()
	foreach ($app in @($catalog))
	{
		if (-not $app) { continue }
		$appId = Get-ApplicationCatalogIdentityKey -Entry $app
		switch ((Get-AppQueuedAction -AppId $appId))
		{
			'Install'   { [void]$installApps.Add($app) }
			'Uninstall' { [void]$uninstallApps.Add($app) }
		}
	}

	$taskQueue = [System.Collections.Generic.List[object]]::new()
	if ($installApps.Count -gt 0)
	{
		[void]$taskQueue.Add([pscustomobject]@{ Action = 'Install'; Apps = @($installApps) })
	}
	if ($uninstallApps.Count -gt 0)
	{
		[void]$taskQueue.Add([pscustomobject]@{ Action = 'Uninstall'; Apps = @($uninstallApps) })
	}

	if ($taskQueue.Count -eq 0)
	{
		Clear-AppsQueuedActions
		return
	}

	$applyState = [pscustomobject]@{
		Tasks = @($taskQueue)
		Index = 0
		Active = $false
		Timer = $null
	}

	$applyTick = {
		try
		{
			if ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				return
			}

			if ($applyState.Active)
			{
				$applyState.Active = $false
				$applyState.Index++
			}

			if ($applyState.Index -ge $applyState.Tasks.Count)
			{
				try { $applyState.Timer.Stop() } catch { $null = $_ }
				try { $applyState.Timer.Dispose() } catch { $null = $_ }
				$applyState.Timer = $null
				Clear-AppsQueuedActions
				return
			}

			$currentTask = $applyState.Tasks[$applyState.Index]
			if (-not $currentTask) { return }

			$action = [string]$currentTask.Action
			$apps = @($currentTask.Apps)
			if ($apps.Count -eq 0)
			{
				$applyState.Index++
				return
			}

			$applyState.Active = $true
			Start-AppsModuleBatchActionAsync -Action $action -SelectedApps $apps
		}
		catch
		{
			LogError (Get-UxBilingualLocalizedString -Key 'GuiLogExecutionAppQueueStateFailed' -Fallback 'Failed to apply queued app actions: {0}' -FormatArgs @($_.Exception.Message))
			try { $applyState.Timer.Stop() } catch { $null = $_ }
			try { $applyState.Timer.Dispose() } catch { $null = $_ }
			$applyState.Timer = $null
			Clear-AppsQueuedActions
		}
	}.GetNewClosure()

	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(250)
	$timer.Add_Tick($applyTick)
	$applyState.Timer = $timer
	$timer.Start()
	& $applyTick
}

<#
    .SYNOPSIS
    Internal function Get-SelectedAppsCatalogItems.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-SelectedAppsCatalogItems
{
	[CmdletBinding()]
	param ()

	Initialize-AppsSelectionState

	if (-not $Script:SelectedAppIds -or $Script:SelectedAppIds.Count -eq 0)
	{
		return @()
	}

	$catalog = @(Get-BaselineApplicationsCatalog)
	if ($catalog.Count -eq 0)
	{
		return @()
	}

	return @(
		$catalog |
			Where-Object {
				if (-not $_)
				{
					$false
				}
				else
				{
					$selectionKey = Get-ApplicationCatalogIdentityKey -Entry $_
					-not [string]::IsNullOrWhiteSpace($selectionKey) -and $Script:SelectedAppIds.Contains([string]$selectionKey)
				}
			}
	)
}

<#
    .SYNOPSIS
    Internal function Update-AppsSelectionSummary.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Update-AppsSelectionSummary
{
	[CmdletBinding()]
	param ()

	if (-not $Script:TxtAppSelectionStatus -and -not $Script:BtnInstallSelectedApps -and -not $Script:BtnUninstallSelectedApps -and -not $Script:BtnUpdateSelectedApps -and -not $Script:BtnClearAppSelection -and -not $Script:BtnScanInstalledApps -and -not $Script:BtnApplyQueuedActions -and -not $Script:BtnClearQueuedActions)
	{
		return
	}

	Initialize-AppsSelectionState

	$selectedApps = @(Get-SelectedAppsCatalogItems)
	$selectedCount = $selectedApps.Count
	Initialize-AppsQueuedActionState
	$queuedCount = if ($Script:AppsQueuedActions) { $Script:AppsQueuedActions.Count } else { 0 }
	$theme = Get-GuiCurrentTheme
	if (-not $theme)
	{
		$theme = $Script:CurrentTheme
	}
	$bc = New-SafeBrushConverter -Context 'Update-AppsSelectionSummary'

	if ($Script:TxtAppSelectionStatus)
	{
		$selectionLabel = switch ($selectedCount)
		{
			0 { (Get-UxLocalizedString -Key 'GuiAppsNoSelection' -Fallback 'No apps selected') }
			1 { (Get-UxLocalizedString -Key 'GuiAppsSingleSelected' -Fallback '1 app selected') }
			default { (Get-UxLocalizedString -Key 'GuiAppsMultipleSelected' -Fallback '{0} apps selected' -FormatArgs @($selectedCount)) }
		}
		if ($queuedCount -gt 0)
		{
			$queuedLabel = if ($queuedCount -eq 1)
			{
				(Get-UxLocalizedString -Key 'GuiAppsQueuedSingle' -Fallback '1 queued change')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsQueuedMultiple' -Fallback '{0} queued changes' -FormatArgs @($queuedCount))
			}
			$selectionLabel = '{0} | {1}' -f $selectionLabel, $queuedLabel
		}
		$Script:TxtAppSelectionStatus.Text = $selectionLabel
		if ($Script:TxtAppSelectionStatus.PSObject.Properties['FontWeight'])
		{
			$Script:TxtAppSelectionStatus.FontWeight = $(if ($selectedCount -gt 0) { [System.Windows.FontWeights]::SemiBold } else { [System.Windows.FontWeights]::Normal })
		}
		if ($theme)
		{
			$Script:TxtAppSelectionStatus.Foreground = $bc.ConvertFromString($(if ($selectedCount -gt 0) { $theme.AccentBlue } else { $theme.TextSecondary }))
		}
	}

		$cacheReady = [bool]($Script:AppsViewLoaded -and -not $Script:AppsViewDirty)
		$installDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		elseif ($selectedCount -eq 0)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionSelectTooltip' -Fallback 'Select at least one app to enable this action.')
		}
		else
		{
			$null
		}
		$catalogActionDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		elseif ($selectedCount -eq 0)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionSelectTooltip' -Fallback 'Select at least one app to enable this action.')
		}
		elseif (-not $cacheReady)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionCatalogRequiredTooltip' -Fallback 'Scan installed apps before uninstalling or updating.')
		}
		else
		{
			$null
		}
		$scanDisabledTooltip = if ($Script:AppsOperationInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
		}
		elseif ($Script:AppsCacheRefreshInProgress)
		{
			(Get-UxLocalizedString -Key 'GuiAppsActionRefreshTooltip' -Fallback 'Wait for the app catalog to finish scanning before selecting actions.')
		}
		else
		{
			$null
		}

		if ($Script:BtnInstallSelectedApps)
		{
			$Script:BtnInstallSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($selectedCount -gt 0)
			$Script:BtnInstallSelectedApps.ToolTip = if ($installDisabledTooltip) { $installDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsInstallSelectedTip' -Fallback 'Install every checked application.') }
		}
		if ($Script:BtnUninstallSelectedApps)
		{
			$Script:BtnUninstallSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and $cacheReady -and ($selectedCount -gt 0)
			$Script:BtnUninstallSelectedApps.ToolTip = if ($catalogActionDisabledTooltip) { $catalogActionDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsUninstallSelectedTip' -Fallback 'Uninstall every checked application.') }
		}
		if ($Script:BtnUpdateSelectedApps)
		{
			$Script:BtnUpdateSelectedApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and $cacheReady -and ($selectedCount -gt 0)
			$Script:BtnUpdateSelectedApps.ToolTip = if ($catalogActionDisabledTooltip) { $catalogActionDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsUpdateSelectedTip' -Fallback 'Update every checked application.') }
		}
		if ($Script:BtnClearAppSelection)
		{
			$Script:BtnClearAppSelection.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($selectedCount -gt 0)
			$Script:BtnClearAppSelection.ToolTip = if ($selectedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionEmptyTip' -Fallback 'No apps are selected.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionBusyTip' -Fallback 'Wait for the current app action to finish before clearing the selection.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearSelectionTip' -Fallback 'Clear all checked applications.')
			}
		}
		if ($Script:BtnScanInstalledApps)
		{
			$Script:BtnScanInstalledApps.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress)
			$Script:BtnScanInstalledApps.ToolTip = if ($scanDisabledTooltip) { $scanDisabledTooltip } else { (Get-UxLocalizedString -Key 'GuiAppsScanInstalledAppsTip' -Fallback 'Scan installed apps to update install status.') }
		}
		if ($Script:BtnApplyQueuedActions)
		{
			$Script:BtnApplyQueuedActions.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($queuedCount -gt 0)
			$Script:BtnApplyQueuedActions.ToolTip = if ($queuedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsApplyQueuedEmptyTip' -Fallback 'Queue an install or uninstall action first.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsApplyQueuedTip' -Fallback 'Apply queued install and uninstall changes.')
			}
		}
		if ($Script:BtnClearQueuedActions)
		{
			$Script:BtnClearQueuedActions.IsEnabled = (-not $Script:AppsOperationInProgress) -and (-not $Script:AppsCacheRefreshInProgress) -and ($queuedCount -gt 0)
			$Script:BtnClearQueuedActions.ToolTip = if ($queuedCount -eq 0)
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearQueuedEmptyTip' -Fallback 'No queued app changes to clear.')
			}
			elseif ($Script:AppsOperationInProgress -or $Script:AppsCacheRefreshInProgress)
			{
				(Get-UxLocalizedString -Key 'GuiAppsActionBusyTooltip' -Fallback 'Wait for the current app action to finish before starting another one.')
			}
			else
			{
				(Get-UxLocalizedString -Key 'GuiAppsClearQueuedTip' -Fallback 'Clear all queued app changes without applying them.')
			}
		}
	}

<#
    .SYNOPSIS
    Internal function Set-AppSelectionState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-AppSelectionState
{
	[CmdletBinding()]
	param (
		[Alias('WinGetId', 'AppKey', 'ApplicationId')]
		[string]$SelectionKey,

		[bool]$Selected = $false
	)

	if ([string]::IsNullOrWhiteSpace($SelectionKey))
	{
		return
	}

	Initialize-AppsSelectionState
	$normalizedId = [string]$SelectionKey.Trim()
	if ($Selected)
	{
		[void]$Script:SelectedAppIds.Add($normalizedId)
	}
	else
	{
		[void]$Script:SelectedAppIds.Remove($normalizedId)
	}

	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Clear-AppSelectionState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Clear-AppSelectionState
{
	[CmdletBinding()]
	param ()

	Initialize-AppsSelectionState

	if ($Script:AppsSelectionUiUpdating)
	{
		return
	}

	$Script:AppsSelectionUiUpdating = $true
	try
	{
		$Script:SelectedAppIds.Clear()
		foreach ($selectionControl in @($Script:AppsSelectionControls))
		{
			if ($selectionControl)
			{
				try { $selectionControl.IsChecked = $false } catch { $null = $_ }
			}
		}
	}
	finally
	{
		$Script:AppsSelectionUiUpdating = $false
	}

	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Ensure-SheenProgressBarType.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Ensure-SheenProgressBarType
{
	[CmdletBinding()]
	param ()

	if ('SheenProgressBar' -as [type])
	{
		return
	}

	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
	Add-Type -AssemblyName WindowsFormsIntegration

	$csharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class SheenProgressBar : Control
{
    private int _minimum = 0;
    private int _maximum = 100;
    private int _value = 0;
    private bool _isIndeterminate = false;
    private float _highlightPhase = 0f;
    private Timer _animTimer;

    public int Minimum
    {
        get { return _minimum; }
        set { _minimum = Math.Max(0, Math.Min(value, _maximum)); Invalidate(); }
    }

    public int Maximum
    {
        get { return _maximum; }
        set
        {
            _maximum = Math.Max(1, value);
            if (_minimum > _maximum) { _minimum = _maximum; }
            if (_value > _maximum) { _value = _maximum; }
            Invalidate();
        }
    }

    public int Value
    {
        get { return _value; }
        set { _value = Math.Max(_minimum, Math.Min(value, _maximum)); Invalidate(); }
    }

    public bool IsIndeterminate
    {
        get { return _isIndeterminate; }
        set { _isIndeterminate = value; Invalidate(); }
    }

	public int SheenWidth { get; set; }
	public int SheenAlphaPeak { get; set; }
	public Color BarColor { get; set; }
	public Color BackgroundColor { get; set; }

    public SheenProgressBar()
    {
        this.DoubleBuffered = true;
        this.MinimumSize = new Size(1, 1);
		this.SheenWidth = 80;
		this.SheenAlphaPeak = 150;
		this.BarColor = Color.FromArgb(0, 120, 215);
		this.BackgroundColor = Color.FromArgb(40, 40, 40);
        _animTimer = new Timer();
        _animTimer.Interval = 30;
        _animTimer.Tick += (s, e) =>
        {
            _highlightPhase += 0.03f;
            if (_highlightPhase > 1.2f) _highlightPhase = -0.2f;
            Invalidate();
        };
        _animTimer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Rectangle bounds = new Rectangle(0, 0, this.Width, this.Height);
        using (SolidBrush bgBrush = new SolidBrush(BackgroundColor))
        {
            g.FillRectangle(bgBrush, bounds);
        }

        if (this.Width <= 0 || this.Height <= 0)
        {
            return;
        }

        if (_isIndeterminate)
        {
            int sweepWidth = Math.Max(SheenWidth * 2, Math.Max(30, this.Width / 3));
            int travelWidth = this.Width + sweepWidth + SheenWidth;
            int sweepX = (int)(((_highlightPhase + 0.2f) / 1.4f) * travelWidth) - sweepWidth;
            Rectangle sweepRect = new Rectangle(sweepX, 0, sweepWidth, this.Height);

            using (SolidBrush barBrush = new SolidBrush(BarColor))
            {
                g.FillRectangle(barBrush, sweepRect);
            }

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sweepRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(bounds);
                g.FillRectangle(sheenBrush, sweepRect);
                g.Clip = prev;
            }

            return;
        }

        int range = Math.Max(1, _maximum - _minimum);
        int fillWidth = (int)(((float)(_value - _minimum) / range) * this.Width);
        fillWidth = Math.Max(0, Math.Min(fillWidth, this.Width));
        if (fillWidth <= 0) return;

        Rectangle fillRect = new Rectangle(0, 0, fillWidth, this.Height);
        using (SolidBrush barBrush = new SolidBrush(BarColor))
        {
            g.FillRectangle(barBrush, fillRect);
        }

        if (fillWidth > 4)
        {
            int sheenX = (int)(_highlightPhase * (fillRect.Width + SheenWidth)) - SheenWidth + fillRect.X;
            Rectangle sheenRect = new Rectangle(sheenX, fillRect.Y, SheenWidth, fillRect.Height);

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sheenRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(fillRect);
                g.FillRectangle(sheenBrush, sheenRect);
                g.Clip = prev;
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing && _animTimer != null)
        {
            _animTimer.Stop();
            _animTimer.Dispose();
        }
        base.Dispose(disposing);
    }
}
"@

	Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"
}

<#
    .SYNOPSIS
    Internal function New-SharedProgressBarHost.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-SharedProgressBarHost
{
	[CmdletBinding()]
	param (
		[int]$Maximum = 100,
		[int]$Value = 0,
		[switch]$Indeterminate,
		[double]$Height = $Script:GuiLayout.ProgressBarHeight,
		[double]$MinWidth = $Script:GuiLayout.ProgressBarMinWidth
	)

	Ensure-SheenProgressBarType

	$windowsFormsHost = [System.Windows.Forms.Integration.WindowsFormsHost]::new()
	$windowsFormsHost.HorizontalAlignment = 'Stretch'
	$windowsFormsHost.VerticalAlignment = 'Center'
	$windowsFormsHost.MinWidth = $MinWidth
	$windowsFormsHost.Height = $Height

	$progressBar = [SheenProgressBar]::new()
	$progressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
	$progressBar.Minimum = 0
	$progressBar.Maximum = [Math]::Max(1, $Maximum)
	$progressBar.Value = [Math]::Min([Math]::Max(0, $Value), $progressBar.Maximum)
	$progressBar.IsIndeterminate = [bool]$Indeterminate
	Set-SheenProgressBarTheme -ProgressBar $progressBar
	$windowsFormsHost.Child = $progressBar

	return @{
		Host        = $windowsFormsHost
		ProgressBar = $progressBar
	}
}

<#
    .SYNOPSIS
    Internal function Set-SheenProgressBarTheme.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-SheenProgressBarTheme
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[hashtable]$Theme = $null
	)

	if (-not $ProgressBar)
	{
		return
	}

	if (-not $Theme)
	{
		$Theme = Get-GuiCurrentTheme
	}

	if (-not $Theme)
	{
		return
	}

	try
	{
		$ProgressBar.BarColor = [System.Drawing.ColorTranslator]::FromHtml([string]$Theme.AccentBlue)
		$ProgressBar.BackgroundColor = [System.Drawing.ColorTranslator]::FromHtml([string]$Theme.CardBorder)
	}
	catch
	{
		$null = $_
	}
}

<#
    .SYNOPSIS
    Internal function Set-SharedProgressBarState.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-SharedProgressBarState
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[object]$ProgressText,
		[int]$Completed = 0,
		[int]$Total = 0,
		[string]$CurrentAction = $null,
		[switch]$Indeterminate,
		[switch]$PassThruText
	)

	$displayText = $null
	if ($ProgressBar)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $true
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = 1
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = 0
			}
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $false
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = $safeTotal
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = $safeCompleted
			}
		}
	}

	if ($ProgressText)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			$displayText = if ([string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				Get-UxExecutionPlaceholderText -Kind 'Working'
			}
			else
			{
				[string]$CurrentAction
			}
			$ProgressText.Text = $displayText
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
			$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
			$ProgressText.Text = $displayText
			if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				$ProgressText.Text += " - $CurrentAction"
			}
			$displayText = $ProgressText.Text
		}
	}
	elseif (-not $Indeterminate -and $Total -gt 0)
	{
		$safeTotal = [Math]::Max(1, $Total)
		$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
		$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
		$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
		if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
		{
			$displayText += " - $CurrentAction"
		}
	}

	if ($PassThruText)
	{
		return $displayText
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsProgressSection.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Initialize-AppsProgressSection
{
	[CmdletBinding()]
	param ()

	if (-not $Script:AppsProgressContainer)
	{
		return
	}

	if (-not $Script:AppsProgressHost -or -not $Script:AppsProgressBar)
	{
		$sharedProgress = New-SharedProgressBarHost -Maximum 1 -Value 0
		$Script:AppsProgressHost = $sharedProgress.Host
		$Script:AppsProgressBar = $sharedProgress.ProgressBar
		$Script:AppsProgressContainer.Child = $Script:AppsProgressHost
	}

	$theme = Get-GuiCurrentTheme
	if ($theme)
	{
		$bc = New-SafeBrushConverter -Context 'Initialize-AppsProgressSection'
		$Script:AppsProgressContainer.Background = $bc.ConvertFromString($theme.CardBorder)
	}

	Set-SheenProgressBarTheme -ProgressBar $Script:AppsProgressBar

	if ($Script:AppsProgressBar)
	{
		$Script:AppsProgressBar.IsIndeterminate = $false
		$Script:AppsProgressBar.Maximum = 1
		$Script:AppsProgressBar.Value = 0
	}
	if ($Script:TxtAppsProgressText)
	{
		$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
	}
	if ($Script:TxtAppCacheStatus)
	{
		$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
	}
}

<#
    .SYNOPSIS
    Internal function Build-AppsViewCards.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Build-AppsViewCards
{
	[CmdletBinding()]
	param ()

	if (-not $Script:AppsWrapPanel) { return }

	$bc = New-SafeBrushConverter -Context 'Build-AppsViewCards'
	$theme = Get-GuiCurrentTheme
	Initialize-AppsSelectionState
	$packageManagerAvailabilityState = $null
	if (Get-Command -Name 'Get-AppsPackageManagerAvailabilityState' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try
		{
			$packageManagerAvailabilityState = Get-AppsPackageManagerAvailabilityState
		}
		catch
		{
			$packageManagerAvailabilityState = $null
		}
	}
	if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try { Update-AppsPackageManagerBanner -AvailabilityState $packageManagerAvailabilityState } catch { $null = $_ }
	}
	$renderSignature = $null
	if (Get-Command -Name 'Get-AppsViewRenderSignature' -CommandType Function -ErrorAction SilentlyContinue)
	{
		$renderSignature = Get-AppsViewRenderSignature -PackageManagerAvailabilityState $packageManagerAvailabilityState
		if ($Script:AppsWrapPanel.Children.Count -gt 0 -and $Script:AppsViewBuildSignature -eq $renderSignature)
		{
			Sync-AppsQueuedActionControls
			Update-AppsSelectionSummary
			return
		}
	}
	$Script:AppsWrapPanel.Children.Clear()
	if ($Script:AppsActionButtons -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsActionButtons.Clear()
	}
	else
	{
		$Script:AppsActionButtons = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsSelectionControls -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsSelectionControls.Clear()
	}
	else
	{
		$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsQueuedActionControls -is [System.Collections.Generic.List[object]])
	{
		$Script:AppsQueuedActionControls.Clear()
	}
	else
	{
		$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	}
	if ($Script:AppsQueuedActionControlMap -is [System.Collections.Generic.Dictionary[string, object]])
	{
		$Script:AppsQueuedActionControlMap.Clear()
	}
	else
	{
		$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}

	Update-AppCategoryFilterList
	$allCatalog = @(Get-BaselineApplicationsCatalog)
	$activeSearchQuery = if ($Script:AppsModeActive) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
	$catalog = @(Get-FilteredApplicationsCatalogItems -SearchQuery $activeSearchQuery)
	$installedCacheSnapshot = Get-ApplicationCacheSnapshot -CacheState $Script:InstalledAppsCache
	$installedWingetCache = $installedCacheSnapshot.WinGet
	$installedChocolateyCache = $installedCacheSnapshot.Chocolatey
	$wingetUpdateCache = $installedCacheSnapshot.WinGetUpdates
	$chocolateyUpdateCache = $installedCacheSnapshot.ChocolateyUpdates
	$cacheReady = [bool]($Script:AppsViewLoaded -and -not $Script:AppsViewDirty)
	$cacheRefreshPrompt = if (Get-Command -Name 'Get-AppsCacheRefreshPromptText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		Get-AppsCacheRefreshPromptText
	}
	else
	{
		(Get-UxLocalizedString -Key 'GuiAppsCacheRefreshRequired' -Fallback 'Installed status not scanned')
	}
	$setAppSelectionStateCommand = Get-GuiRuntimeCommand -Name 'Set-AppSelectionState' -CommandType 'Function'
	$setAppQueuedActionCommand = Get-GuiRuntimeCommand -Name 'Set-AppQueuedAction' -CommandType 'Function'
	$startAppsModuleActionAsyncCommand = Get-GuiRuntimeCommand -Name 'Start-AppsModuleActionAsync' -CommandType 'Function'
	if (-not $setAppSelectionStateCommand) { throw 'Set-AppSelectionState not found.' }
	if (-not $setAppQueuedActionCommand) { throw 'Set-AppQueuedAction not found.' }
	if (-not $startAppsModuleActionAsyncCommand) { throw 'Start-AppsModuleActionAsync not found.' }

	if ($allCatalog.Count -eq 0)
	{
		$emptyState = [System.Windows.Controls.Border]::new()
		$emptyState.Margin = [System.Windows.Thickness]::new(12)
		$emptyState.Padding = [System.Windows.Thickness]::new(18)
		$emptyState.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$emptyState.Background = $bc.ConvertFromString($theme.CardBg)
		$emptyState.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$emptyState.BorderThickness = [System.Windows.Thickness]::new(1)
		$emptyState.Child = [System.Windows.Controls.TextBlock]::new()
		$emptyState.Child.Text = (Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		$emptyState.Child.TextWrapping = 'Wrap'
		$emptyState.Child.Foreground = $bc.ConvertFromString($theme.TextSecondary)
		[void]$Script:AppsWrapPanel.Children.Add($emptyState)
		$emptySummaryText = (Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		if ($Script:TxtAppCacheStatus) { $Script:TxtAppCacheStatus.Text = $emptySummaryText }
		if ($Script:TxtAppsProgressText) { $Script:TxtAppsProgressText.Text = $emptySummaryText }
		$Script:AppsViewBuildSignature = $renderSignature
		Update-AppsSelectionSummary
		return
	}

	if ($catalog.Count -eq 0)
	{
		$emptyMessage = if (-not [string]::IsNullOrWhiteSpace([string]$activeSearchQuery) -and ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All'))
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateSearchAndCategory' -Fallback 'No apps match your search in the selected category.')
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$activeSearchQuery))
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateSearch' -Fallback 'No apps match your search.')
		}
		elseif ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All')
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoCategoryMatches' -Fallback 'No applications match the selected category.')
		}
		else
		{
			(Get-UxLocalizedString -Key 'GuiAppsEmptyStateNoPackageBackedApplications' -Fallback 'No package-backed applications were found.')
		}
		$emptyState = [System.Windows.Controls.Border]::new()
		$emptyState.Margin = [System.Windows.Thickness]::new(12)
		$emptyState.Padding = [System.Windows.Thickness]::new(18)
		$emptyState.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$emptyState.Background = $bc.ConvertFromString($theme.CardBg)
		$emptyState.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$emptyState.BorderThickness = [System.Windows.Thickness]::new(1)
		$emptyState.Child = [System.Windows.Controls.TextBlock]::new()
		$emptyState.Child.Text = $emptyMessage
		$emptyState.Child.TextWrapping = 'Wrap'
		$emptyState.Child.Foreground = $bc.ConvertFromString($theme.TextSecondary)
		[void]$Script:AppsWrapPanel.Children.Add($emptyState)
		if ($Script:TxtAppCacheStatus)
		{
			$installedCount = 0
			$updateAvailableCount = 0
			foreach ($entry in @($allCatalog))
			{
				if (-not $entry) { continue }
				$appState = Get-ApplicationExecutionState -Entry $entry -WinGetInstalledCache $installedWingetCache -ChocolateyInstalledCache $installedChocolateyCache -WinGetUpdateCache $wingetUpdateCache -ChocolateyUpdateCache $chocolateyUpdateCache -PreferredSource $Script:AppsPackageSourcePreference
				if ($appState.IsInstalled)
				{
					$installedCount++
				}
				if ($appState.UpdateAvailable)
				{
					$updateAvailableCount++
				}
			}
			$summaryText = if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2} | Showing: 0/{1}'), $installedCount, $allCatalog.Count, $updateAvailableCount)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummary' -Fallback 'Installed: {0}/{1} | Showing: 0/{1}'), $installedCount, $allCatalog.Count)
			}
			$Script:TxtAppCacheStatus.Text = $summaryText
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = $summaryText
			}
		}
		$Script:AppsViewBuildSignature = $renderSignature
		Update-AppsSelectionSummary
		return
	}

	$sortedCatalog = @($catalog | Sort-Object SubCategory, Name)
	$buildProgressLabel = [string]::Format(
		(Get-UxLocalizedString -Key 'GuiAppsLoadingCatalog' -Fallback 'Loading {0}...'),
		(Get-UxLocalizedString -Key 'Category_SoftwareApps_Title' -Fallback 'Software & Apps')
	)
	$installedCount = 0
	$updateAvailableCount = 0
	if ($Script:TxtAppCacheStatus -and $Script:AppsProgressBar)
	{
		$Script:TxtAppCacheStatus.Text = $buildProgressLabel
	}
	if ($Script:TxtAppsProgressText -and $buildProgressLabel)
	{
		$Script:TxtAppsProgressText.Text = $buildProgressLabel
	}
	if ($Script:AppsProgressBar)
	{
		try { $Script:AppsProgressBar.IsIndeterminate = $true } catch { $null = $_ }
	}

	foreach ($app in @($sortedCatalog))
	{
		if (-not $app)
		{
			continue
		}

		$selectionCheckBox = $null
		$primaryButton = $null
		$updateButton = $null
		$appCapture = $null
		$isInstalledCapture = $false

		$appState = Get-ApplicationExecutionState -Entry $app -WinGetInstalledCache $installedWingetCache -ChocolateyInstalledCache $installedChocolateyCache -WinGetUpdateCache $wingetUpdateCache -ChocolateyUpdateCache $chocolateyUpdateCache -PreferredSource $Script:AppsPackageSourcePreference
		$entityType = [string]$appState.EntityType
		$supportsExecution = [bool]$appState.SupportsExecution
		$isInstalled = [bool]$appState.IsInstalled
		$hasUpdateAvailable = [bool]$appState.UpdateAvailable
		if ($isInstalled) { $installedCount++ }
		if ($hasUpdateAvailable) { $updateAvailableCount++ }
		$selectionKeyCapture = [string]$appState.SelectionKey
		$appActionState = if (-not [string]::IsNullOrWhiteSpace($selectionKeyCapture)) { Get-AppActionState -Application $app -SelectionKey $selectionKeyCapture } else { $null }

		$statusLabel = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { (Get-UxLocalizedString -Key 'GuiAppsQueued' -Fallback 'Queued') }
				'Installing' { (Get-UxLocalizedString -Key 'GuiAppsInstalling' -Fallback 'Installing') }
				'Failed' { (Get-UxLocalizedString -Key 'GuiAppsFailed' -Fallback 'Failed') }
				default
				{
					switch ($appState.State)
					{
						'Installed' { (Get-UxLocalizedString -Key 'Status_Installed' -Fallback 'Installed') }
						'Update available' { (Get-UxLocalizedString -Key 'GuiAppsUpdateAvailable' -Fallback 'Update available') }
						'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported') }
						default { (Get-UxLocalizedString -Key 'Status_NotInstalled' -Fallback 'Not Installed') }
					}
				}
			}
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { (Get-UxLocalizedString -Key 'Status_Installed' -Fallback 'Installed') }
				'Update available' { (Get-UxLocalizedString -Key 'GuiAppsUpdateAvailable' -Fallback 'Update available') }
				'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported') }
				default { (Get-UxLocalizedString -Key 'Status_NotInstalled' -Fallback 'Not Installed') }
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusLabel = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshRequired' -Fallback 'Installed status not scanned')
		}
		$statusForeground = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { $theme.AccentBlue }
				'Installing' { $theme.AccentBlue }
				'Failed' { $theme.CautionBorder }
				default
				{
					switch ($appState.State)
					{
						'Installed' { $theme.ToggleOn }
						'Update available' { $theme.AccentBlue }
						'Unsupported' { $theme.TextMuted }
						default { $theme.TextMuted }
					}
				}
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusForeground = $theme.TextMuted
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { $theme.ToggleOn }
				'Update available' { $theme.AccentBlue }
				'Unsupported' { $theme.TextMuted }
				default { $theme.TextMuted }
			}
		}

		$primaryAction = if ($supportsExecution)
		{
			if ($isInstalled)
			{
				(Get-UxLocalizedString -Key 'Uninstall' -Fallback 'Uninstall')
			}
			else
			{
				(Get-UxLocalizedString -Key 'Install' -Fallback 'Install')
			}
		}
		else
		{
			(Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'Unsupported')
		}
		$selectedSource = if ($appState -and $appState.PSObject.Properties['SelectedSource']) { [string]$appState.SelectedSource } else { $null }
		$selectedSourceLabel = switch ($selectedSource)
		{
			'winget' { (Get-UxLocalizedString -Key 'GuiAppsSourceWinGet' -Fallback 'WinGet') }
			'choco' { (Get-UxLocalizedString -Key 'GuiAppsSourceChocolatey' -Fallback 'Chocolatey') }
			'store' { (Get-UxLocalizedString -Key 'GuiAppsSourceStore' -Fallback 'Store') }
			'direct' { (Get-UxLocalizedString -Key 'GuiAppsSourceDirect' -Fallback 'Direct Download') }
			'command' { (Get-UxLocalizedString -Key 'GuiAppsSourceCommand' -Fallback 'Custom Command') }
			default { $null }
		}
		$selectedSourceTooltip = switch ($selectedSource)
		{
			'winget' { (Get-UxLocalizedString -Key 'GuiAppsSourceWinGetTip' -Fallback 'This app will use WinGet for the selected action.') }
			'choco' { (Get-UxLocalizedString -Key 'GuiAppsSourceChocolateyTip' -Fallback 'This app will use Chocolatey for the selected action.') }
			'store' { (Get-UxLocalizedString -Key 'GuiAppsSourceStoreTip' -Fallback 'This app opens the Microsoft Store for the selected action.') }
			'direct' { (Get-UxLocalizedString -Key 'GuiAppsSourceDirectTip' -Fallback 'This app uses a direct download route for the selected action.') }
			'command' { (Get-UxLocalizedString -Key 'GuiAppsSourceCommandTip' -Fallback 'This app uses a custom command route for the selected action.') }
			default { $null }
		}
		$statusTone = if ($appActionState)
		{
			switch ([string]$appActionState.State)
			{
				'Queued' { 'Primary' }
				'Installing' { 'Caution' }
				'Failed' { 'Danger' }
				default
				{
					switch ($appState.State)
					{
						'Installed' { 'Success' }
						'Update available' { 'Primary' }
						'Unsupported' { 'Muted' }
						default { 'Muted' }
					}
				}
			}
		}
		else
		{
			switch ($appState.State)
			{
				'Installed' { 'Success' }
				'Update available' { 'Primary' }
				'Unsupported' { 'Muted' }
				default { 'Muted' }
			}
		}
		$statusTooltip = if ($appActionState -and -not [string]::IsNullOrWhiteSpace([string]$appActionState.Message))
		{
			[string]$appActionState.Message
		}
		else
		{
			switch ([string]$appState.State)
			{
				'Installed' { (Get-UxLocalizedString -Key 'GuiAppsStatusInstalledTip' -Fallback 'This app is currently installed.') }
				'Update available' { (Get-UxLocalizedString -Key 'GuiAppsStatusUpdateAvailableTip' -Fallback 'An update is available for this app.') }
				'Unsupported' { (Get-UxLocalizedString -Key 'GuiAppsStatusUnsupportedTip' -Fallback 'This catalog entry does not support direct execution.') }
				default { (Get-UxLocalizedString -Key 'GuiAppsStatusNotInstalledTip' -Fallback 'This app is not currently installed.') }
			}
		}
		if (-not $cacheReady -and $supportsExecution)
		{
			$statusTooltip = $cacheRefreshPrompt
		}
		$isAppActionBusy = $appActionState -and @('Queued', 'Installing') -contains [string]$appActionState.State
		$appIconName = if (Get-Command -Name 'Get-GuiApplicationIconName' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Get-GuiApplicationIconName -Name $app.Name -SubCategory $app.SubCategory -Tags $app.Tags -SourceRegion $app.SourceRegion
		}
		else
		{
			'AppGeneric'
		}
		$card = [System.Windows.Controls.Border]::new()
		$card.Width = 340
		$card.Margin = [System.Windows.Thickness]::new(8)
		$card.Padding = [System.Windows.Thickness]::new(16)
		$card.CornerRadius = [System.Windows.CornerRadius]::new(8)
		$card.Background = $bc.ConvertFromString($theme.CardBg)
		$card.BorderBrush = $bc.ConvertFromString($theme.CardBorder)
		$card.BorderThickness = [System.Windows.Thickness]::new(1)

		$stack = [System.Windows.Controls.StackPanel]::new()
		$stack.Orientation = 'Vertical'

		$headerGrid = [System.Windows.Controls.Grid]::new()
		$headerGrid.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
		$headerGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
		$headerGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new())
		$headerGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
		$headerGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)

		if ($appIconName)
		{
			$appIcon = New-GuiIconTextBlock -IconName $appIconName -Size 18 -Foreground $bc.ConvertFromString($theme.AccentBlue) -VerticalAlignment 'Center'
			if ($appIcon)
			{
				$appIcon.Margin = [System.Windows.Thickness]::new(0, 1, 12, 0)
				[System.Windows.Controls.Grid]::SetColumn($appIcon, 0)
				[void]$headerGrid.Children.Add($appIcon)
			}
		}

		$title = [System.Windows.Controls.TextBlock]::new()
		$title.Text = [string]$app.Name
		$title.FontSize = 14
		$title.FontWeight = [System.Windows.FontWeights]::Bold
		$title.TextWrapping = 'Wrap'
		$title.Foreground = $bc.ConvertFromString($theme.TextPrimary)
		[System.Windows.Controls.Grid]::SetColumn($title, 1)
		[void]$headerGrid.Children.Add($title)
		[void]$stack.Children.Add($headerGrid)

		if (-not [string]::IsNullOrWhiteSpace([string]$app.SubCategory))
		{
			$subTitle = [System.Windows.Controls.TextBlock]::new()
			$subTitle.Text = [string]$app.SubCategory
			$subTitle.FontSize = 10
			$subTitle.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)
			$subTitle.Foreground = $bc.ConvertFromString($theme.SectionLabel)
			[void]$stack.Children.Add($subTitle)
		}

		if (-not [string]::IsNullOrWhiteSpace($entityType) -and $entityType -ne 'winget')
		{
			$typeBadge = [System.Windows.Controls.TextBlock]::new()
			$typeBadge.Text = switch ($entityType)
			{
				'choco' { (Get-UxLocalizedString -Key 'AppTypeBadgeChoco' -Fallback 'Chocolatey package') }
				'uwp' { (Get-UxLocalizedString -Key 'AppTypeBadgeUWP' -Fallback 'UWP app') }
				'feature' { (Get-UxLocalizedString -Key 'AppTypeBadgeFeature' -Fallback 'Windows feature') }
				'system' { (Get-UxLocalizedString -Key 'AppTypeBadgeSystem' -Fallback 'System component') }
				'placeholder' { (Get-UxLocalizedString -Key 'AppTypeBadgePlaceholder' -Fallback 'No install method') }
				default { [string]$entityType }
			}
			$typeBadge.FontSize = 9
			$typeBadge.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)
			$typeBadge.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($typeBadge)
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$app.Description))
		{
			$description = [System.Windows.Controls.TextBlock]::new()
			$description.Text = [string]$app.Description
			$description.TextWrapping = 'Wrap'
			$description.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
			$description.Foreground = $bc.ConvertFromString($theme.TextSecondary)
			[void]$stack.Children.Add($description)
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$app.Detail))
		{
			$detail = [System.Windows.Controls.TextBlock]::new()
			$detail.Text = [string]$app.Detail
			$detail.TextWrapping = 'Wrap'
			$detail.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
			$detail.FontSize = 10
			$detail.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($detail)
		}

		$metadataItems = [System.Collections.Generic.List[object]]::new()
		if (-not [string]::IsNullOrWhiteSpace($statusLabel))
		{
			[void]$metadataItems.Add([pscustomobject]@{
				Label = $statusLabel
				Tone = $statusTone
				ToolTip = $statusTooltip
			})
		}
		if (-not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
		{
			[void]$metadataItems.Add([pscustomobject]@{
				Label = $selectedSourceLabel
				Tone = 'Primary'
				ToolTip = $selectedSourceTooltip
			})
		}
		if ($metadataItems.Count -gt 0)
		{
			$metadataPanel = GUICommon\New-DialogMetadataPillPanel -Theme $theme -Items $metadataItems
			if ($metadataPanel)
			{
				$metadataPanel.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
				[void]$stack.Children.Add($metadataPanel)
			}
		}

			if ($supportsExecution)
			{
				if (-not $cacheReady)
				{
					$refreshNotice = [System.Windows.Controls.TextBlock]::new()
					$refreshNotice.Text = $cacheRefreshPrompt
					$refreshNotice.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
					$refreshNotice.TextWrapping = [System.Windows.TextWrapping]::Wrap
					$refreshNotice.FontSize = 10
					$refreshNotice.Foreground = $bc.ConvertFromString($theme.TextMuted)
					$refreshNotice.ToolTip = $cacheRefreshPrompt
					[void]$stack.Children.Add($refreshNotice)
				}

				$selectionRow = [System.Windows.Controls.DockPanel]::new()
				$selectionRow.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
				$selectionRow.LastChildFill = $true

				$selectionCheckBox = [System.Windows.Controls.CheckBox]::new()
				$selectionCheckBox.Content = (Get-UxLocalizedString -Key 'GuiAppsSelectLabel' -Fallback 'Select')
				$selectionCheckBox.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
				$selectionCheckBox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
				$selectionCheckBox.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
				$selectionCheckBox.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsSelectTooltip' -Fallback 'Include this app in bulk actions.')
				$selectionCheckBox.Foreground = $bc.ConvertFromString($theme.TextPrimary)
				$selectionCheckBox.Tag = $selectionKeyCapture
				$selectionCheckBox.IsChecked = [bool]($Script:SelectedAppIds -and $Script:SelectedAppIds.Contains($selectionKeyCapture))
				$selectionCheckBox.Add_Checked({
					if ($Script:AppsSelectionUiUpdating) { return }
					& $setAppSelectionStateCommand -SelectionKey $selectionKeyCapture -Selected $true
				}.GetNewClosure())
				$selectionCheckBox.Add_Unchecked({
					if ($Script:AppsSelectionUiUpdating) { return }
					& $setAppSelectionStateCommand -SelectionKey $selectionKeyCapture -Selected $false
				}.GetNewClosure())
				[System.Windows.Controls.DockPanel]::SetDock($selectionCheckBox, [System.Windows.Controls.Dock]::Right)
				[void]$selectionRow.Children.Add($selectionCheckBox)
				[void]$Script:AppsSelectionControls.Add($selectionCheckBox)

				$statusRow = [System.Windows.Controls.TextBlock]::new()
				$statusRow.Text = $statusLabel
				$statusRow.Margin = [System.Windows.Thickness]::new(0)
				$statusRow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
				$statusRow.TextWrapping = [System.Windows.TextWrapping]::Wrap
				$statusRow.FontSize = 10
				$statusRow.Foreground = $bc.ConvertFromString($statusForeground)
				if (-not [string]::IsNullOrWhiteSpace($statusTooltip))
				{
					$statusRow.ToolTip = $statusTooltip
				}
				[void]$selectionRow.Children.Add($statusRow)
				[void]$stack.Children.Add($selectionRow)

			$buttonRow = [System.Windows.Controls.WrapPanel]::new()
			$buttonRow.Orientation = 'Horizontal'
			$buttonRow.Margin = [System.Windows.Thickness]::new(0, 12, 0, 0)

			$appCapture = $app
			$queueSelectionKey = [string]$selectionKeyCapture
			$queueAction = Get-AppQueuedAction -AppId $queueSelectionKey
			$queueGroupName = 'AppQueue_{0}' -f (($queueSelectionKey -replace '[^A-Za-z0-9]+', '_').Trim('_'))
			$queuedActionControls = [pscustomobject]@{
				Install = $null
				Uninstall = $null
				DoNothing = $null
			}
			[void]$Script:AppsQueuedActionControlMap.Remove($queueSelectionKey)
			[void]$Script:AppsQueuedActionControlMap.Add($queueSelectionKey, $queuedActionControls)

			$installRadio = [System.Windows.Controls.RadioButton]::new()
			$installRadio.Content = (Get-UxLocalizedString -Key 'Install' -Fallback 'Install')
			$installRadio.GroupName = $queueGroupName
			$installRadio.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$installRadio.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
			$installRadio.Cursor = [System.Windows.Input.Cursors]::Hand
			$installRadio.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
			$installRadio.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$installRadio.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsQueueInstallTip' -Fallback 'Queue this app for installation.')
			$installRadio.IsChecked = ([string]$queueAction -eq 'Install')
			$installRadio.Add_Checked({
				if ($Script:AppsQueuedActionUiUpdating) { return }
				& $setAppQueuedActionCommand -AppId $queueSelectionKey -Action 'Install'
			}.GetNewClosure())
			$queuedActionControls.Install = $installRadio
			[void]$buttonRow.Children.Add($installRadio)

			$uninstallRadio = [System.Windows.Controls.RadioButton]::new()
			$uninstallRadio.Content = (Get-UxLocalizedString -Key 'Uninstall' -Fallback 'Uninstall')
			$uninstallRadio.GroupName = $queueGroupName
			$uninstallRadio.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$uninstallRadio.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
			$uninstallRadio.Cursor = [System.Windows.Input.Cursors]::Hand
			$uninstallRadio.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
			$uninstallRadio.Foreground = $bc.ConvertFromString($theme.TextPrimary)
			$uninstallRadio.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsQueueUninstallTip' -Fallback 'Queue this app for uninstallation.')
			$uninstallRadio.IsChecked = ([string]$queueAction -eq 'Uninstall')
			$uninstallRadio.Add_Checked({
				if ($Script:AppsQueuedActionUiUpdating) { return }
				& $setAppQueuedActionCommand -AppId $queueSelectionKey -Action 'Uninstall'
			}.GetNewClosure())
			$queuedActionControls.Uninstall = $uninstallRadio
			[void]$buttonRow.Children.Add($uninstallRadio)

			$doNothingRadio = [System.Windows.Controls.RadioButton]::new()
			$doNothingRadio.Content = (Get-UxLocalizedString -Key 'GuiAppsDoNothing' -Fallback 'Do nothing')
			$doNothingRadio.GroupName = $queueGroupName
			$doNothingRadio.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
			$doNothingRadio.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
			$doNothingRadio.Cursor = [System.Windows.Input.Cursors]::Hand
			$doNothingRadio.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
			$doNothingRadio.Foreground = $bc.ConvertFromString($theme.TextMuted)
			$doNothingRadio.ToolTip = (Get-UxLocalizedString -Key 'GuiAppsQueueDoNothingTip' -Fallback 'Leave this app unchanged for now.')
			$doNothingRadio.IsChecked = (-not [string]::IsNullOrWhiteSpace([string]$queueAction) -and [string]$queueAction -eq 'DoNothing') -or [string]::IsNullOrWhiteSpace([string]$queueAction)
			$doNothingRadio.Add_Checked({
				if ($Script:AppsQueuedActionUiUpdating) { return }
				& $setAppQueuedActionCommand -AppId $queueSelectionKey -Action 'DoNothing'
			}.GetNewClosure())
			$queuedActionControls.DoNothing = $doNothingRadio
			[void]$buttonRow.Children.Add($doNothingRadio)

			[void]$Script:AppsQueuedActionControls.Add($queuedActionControls)

			if ($isInstalled -or $hasUpdateAvailable)
			{
				$updateButton = [System.Windows.Controls.Button]::new()
				$updateButton.Content = (Get-UxLocalizedString -Key 'Update' -Fallback 'Update')
				$updateButton.MinWidth = 88
				$updateButton.Cursor = [System.Windows.Input.Cursors]::Hand
				$updateButton.IsEnabled = -not $isAppActionBusy
				$updateButton.ToolTip = if (-not [string]::IsNullOrWhiteSpace($selectedSourceLabel))
				{
					(Get-UxLocalizedString -Key 'GuiAppsUpdateSelectedViaSourceTip' -Fallback ('Update using {0}.' -f $selectedSourceLabel))
				}
				else
				{
					(Get-UxLocalizedString -Key 'Tooltip_UpdateApplication' -Fallback 'Update this application.')
				}
				Set-ButtonChrome -Button $updateButton -Variant 'Secondary' -Compact
				Set-GuiButtonIconContent -Button $updateButton -IconName 'ArrowSync' -Text (Get-UxLocalizedString -Key 'Update' -Fallback 'Update') -IconSize 14 -Gap 6 -TextFontSize 11 -ToolTip $updateButton.ToolTip
				[void]$Script:AppsActionButtons.Add($updateButton)
					$updateButton.Add_Click({
						param($buttonSender, $buttonEventArgs)
						$null = $buttonEventArgs
						& $startAppsModuleActionAsyncCommand -Action 'Update' -Application $appCapture
					}.GetNewClosure())
				[void]$buttonRow.Children.Add($updateButton)
			}

			[void]$stack.Children.Add($buttonRow)
		}
		else
		{
			$unsupportedText = [System.Windows.Controls.TextBlock]::new()
			$unsupportedText.Text = (Get-UxLocalizedString -Key 'GuiAppsUnsupportedAction' -Fallback 'No install method available.')
			$unsupportedText.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
			$unsupportedText.TextWrapping = [System.Windows.TextWrapping]::Wrap
			$unsupportedText.FontSize = 10
			$unsupportedText.Foreground = $bc.ConvertFromString($theme.TextMuted)
			[void]$stack.Children.Add($unsupportedText)
		}

		$card.Child = $stack

		if (Get-Command -Name 'Add-CardHoverEffects' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$focusSources = @()
			if ($selectionCheckBox) { $focusSources += $selectionCheckBox }
			if ($primaryButton) { $focusSources += $primaryButton }
			if ($updateButton) { $focusSources += $updateButton }
			if ($focusSources.Count -gt 0)
			{
				try { Add-CardHoverEffects -Card $card -FocusSources $focusSources } catch { $null = $_ }
			}
		}

		[void]$Script:AppsWrapPanel.Children.Add($card)
		if (($Script:AppsWrapPanel.Children.Count % 10) -eq 0)
		{
			try { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch { $null = $_ }
		}
	}

	if ($Script:TxtAppCacheStatus)
	{
		if (-not $cacheReady)
		{
			$Script:TxtAppCacheStatus.Text = $cacheRefreshPrompt
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = $cacheRefreshPrompt
			}
			Update-AppsSelectionSummary
			return
		}
		$summaryText = if ($Script:AppsCategoryFilter -and $Script:AppsCategoryFilter -ne 'All')
		{
			if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryFilteredWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2} | Showing: {3}/{1}'), $installedCount, $allCatalog.Count, $updateAvailableCount, $catalog.Count)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryFiltered' -Fallback 'Installed: {0}/{1} | Showing: {2}/{1}'), $installedCount, $allCatalog.Count, $catalog.Count)
			}
		}
		else
		{
			if ($updateAvailableCount -gt 0)
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryAllWithUpdates' -Fallback 'Installed: {0}/{1} | Updates available: {2}'), $installedCount, $allCatalog.Count, $updateAvailableCount)
			}
			else
			{
				[string]::Format((Get-UxLocalizedString -Key 'AppStatusSummaryAll' -Fallback 'Installed: {0}/{1}'), $installedCount, $allCatalog.Count)
			}
		}
		$Script:TxtAppCacheStatus.Text = $summaryText
		if ($Script:TxtAppsProgressText)
		{
			$Script:TxtAppsProgressText.Text = $summaryText
		}
	}
	if ($Script:AppsProgressBar)
	{
		try
		{
			$Script:AppsProgressBar.IsIndeterminate = $false
			$Script:AppsProgressBar.Maximum = 1
			$Script:AppsProgressBar.Value = 0
		}
		catch
		{
			$null = $_
		}
	}
	$Script:AppsViewBuildSignature = $renderSignature
	Update-AppsSelectionSummary
}

<#
    .SYNOPSIS
    Internal function Start-AppsCacheRefresh.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Start-AppsCacheRefresh
{
	[CmdletBinding()]
	param ()

	if ($Script:AppsCacheRefreshInProgress)
	{
		return
	}

	$Script:AppsCacheRefreshInProgress = $true
	Set-AppsActionControlsEnabled -Enabled $false
	Initialize-AppsProgressSection
	if ($Script:AppsProgressContainer)
	{
		$Script:AppsProgressContainer.Visibility = [System.Windows.Visibility]::Visible
	}
	$syncHash = [hashtable]::Synchronized(@{
		Completed    = 0
		Total        = 4
		CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
		IsComplete   = $false
		Error        = $null
	})
	if ($Script:TxtAppCacheStatus)
	{
		$initialProgressText = Set-SharedProgressBarState -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
		$Script:TxtAppCacheStatus.Text = $initialProgressText
	}

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace
	$appsGetApplicationCacheSnapshotCommand = Get-Command 'Get-ApplicationCacheSnapshot' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsSetSharedProgressBarStateCommand = Get-Command 'Set-SharedProgressBarState' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsGetUxLocalizedStringCommand = Get-Command 'Get-UxLocalizedString' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsBuildAppsViewCardsCommand = Get-Command 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsLogErrorCommand = Get-Command 'LogError' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$appsSetActionControlsEnabledCommand = Get-Command 'Set-AppsActionControlsEnabled' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1

	if (-not $appsGetApplicationCacheSnapshotCommand) { throw 'Get-ApplicationCacheSnapshot not found.' }
	if (-not $appsSetSharedProgressBarStateCommand) { throw 'Set-SharedProgressBarState not found.' }
	if (-not $appsGetUxLocalizedStringCommand) { throw 'Get-UxLocalizedString not found.' }
	if (-not $appsBuildAppsViewCardsCommand) { throw 'Build-AppsViewCards not found.' }
	if (-not $appsLogErrorCommand) { throw 'LogError not found.' }
	if (-not $appsSetActionControlsEnabledCommand) { throw 'Set-AppsActionControlsEnabled not found.' }

	$null = $ps.AddScript({
		param ($ModulePath, $Sync)
		Import-Module -Force -Name $ModulePath
		$wingetCache = @{}
		$chocolateyCache = @{}
		$wingetUpdateCache = @{}
		$chocolateyUpdateCache = @{}
		$Sync.Total = 4
		$Sync.Completed = 0
		$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
			$wingetCache = Get-InstalledAppCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogWinGetInstalledCacheRefreshFailed' -Fallback 'WinGet installed-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 1
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyInstalled' -Fallback 'Checking Chocolatey installation status...')
			$chocolateyCache = Get-InstalledChocolateyAppCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogChocolateyInstalledCacheRefreshFailed' -Fallback 'Chocolatey installed-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 2
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...')
			$wingetUpdateCache = Get-AvailableAppUpdateCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogWinGetUpdateCacheRefreshFailed' -Fallback 'WinGet update-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 3
		}
		try
		{
			$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshScanningChocolateyUpdates' -Fallback 'Checking Chocolatey update availability...')
			$chocolateyUpdateCache = Get-AvailableChocolateyUpdateCache
		}
		catch
		{
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogChocolateyUpdateCacheRefreshFailed' -Fallback 'Chocolatey update-cache scan failed: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Sync.Completed = 4
		}
		$Sync.CurrentAction = (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshComplete' -Fallback 'Installed apps scanned.')
		[pscustomobject]@{
			WinGet = $wingetCache
			Chocolatey = $chocolateyCache
			WinGetUpdates = $wingetUpdateCache
			ChocolateyUpdates = $chocolateyUpdateCache
		}
	}).AddArgument($appModulePath).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()
	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(100)
	$timer.Add_Tick({
		if ($syncHash.Error)
		{
			$timer.Stop()
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = (Set-SharedProgressBarState -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed 0 -Total 1 -CurrentAction (Get-UxLocalizedString -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText)
			}
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @([string]$syncHash.Error))
			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
			return
		}

		if ($Script:AppsProgressBar -or $Script:TxtAppsProgressText)
		{
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Completed -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction -PassThruText
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = $progressText
			}
		}

		if (-not $asyncResult.IsCompleted)
		{
			return
		}

		$timer.Stop()
		try
		{
			$cacheResult = @($ps.EndInvoke($asyncResult))
			$cachePayload = if ($cacheResult.Count -gt 0) { $cacheResult[0] } else { $null }
			if ($cachePayload -is [psobject])
			{
				$Script:InstalledAppsCache = & $appsGetApplicationCacheSnapshotCommand -CacheState $cachePayload
			}
			elseif ($cachePayload -is [hashtable])
			{
				$Script:InstalledAppsCache = [pscustomobject]@{
					WinGet = $cachePayload
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			else
			{
				$Script:InstalledAppsCache = [pscustomobject]@{
					WinGet = @{}
					Chocolatey = @{}
					WinGetUpdates = @{}
					ChocolateyUpdates = @{}
				}
			}
			$Script:AppsViewLoaded = $true
			$Script:AppsViewDirty = $false
			& $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed $syncHash.Total -Total $syncHash.Total -CurrentAction $syncHash.CurrentAction | Out-Null
			& $appsBuildAppsViewCardsCommand
		}
		catch
		{
			$Script:InstalledAppsCache = [pscustomobject]@{
				WinGet = @{}
				Chocolatey = @{}
				WinGetUpdates = @{}
				ChocolateyUpdates = @{}
			}
			$Script:AppsViewLoaded = $false
			$Script:AppsViewDirty = $true
			$progressText = & $appsSetSharedProgressBarStateCommand -ProgressBar $Script:AppsProgressBar -ProgressText $Script:TxtAppsProgressText -Completed 0 -Total 1 -CurrentAction (& $appsGetUxLocalizedStringCommand -Key 'GuiAppsCacheRefreshFailed' -Fallback 'Failed to scan installed applications.') -PassThruText
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = $progressText
			}
			& $appsLogErrorCommand (& $appsGetUxLocalizedStringCommand -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message))
		}
		finally
		{
			$Script:AppsCacheRefreshInProgress = $false
			& $appsSetActionControlsEnabledCommand -Enabled $true
			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
		}
	}.GetNewClosure())
	$timer.Start()
}

<#
    .SYNOPSIS
    Internal function Start-AppsModuleActionAsync.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Start-AppsModuleActionAsync
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update', 'UpdateAll')]
		[string]$Action,

		[string]$WinGetId,

		[string]$ChocoId,

		[string]$DisplayName,

		[object]$Application,

		[string]$PreferredSource = $null
	)

	$resolvedWinGetId = $WinGetId
	$resolvedChocoId = $ChocoId
	$resolvedDisplayName = $DisplayName
	if ($Application)
	{
		if ([string]::IsNullOrWhiteSpace([string]$resolvedDisplayName) -and $Application.PSObject.Properties['Name'])
		{
			$resolvedDisplayName = [string]$Application.Name
		}
		if ([string]::IsNullOrWhiteSpace([string]$resolvedWinGetId) -and $Application.PSObject.Properties['WinGetId'])
		{
			$resolvedWinGetId = [string]$Application.WinGetId
		}
		if ([string]::IsNullOrWhiteSpace([string]$resolvedChocoId) -and $Application.PSObject.Properties['ChocoId'])
		{
			$resolvedChocoId = [string]$Application.ChocoId
		}
	}
	Initialize-AppPackageSourcePreferenceState
	$resolvedPreferredSource = ConvertTo-AppPackageSourcePreference -Source $(if ([string]::IsNullOrWhiteSpace([string]$PreferredSource)) { $Script:AppsPackageSourcePreference } else { $PreferredSource })

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$bgUICulture = if ([string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage)) { 'en' } else { [string]$Script:SelectedLanguage }
	Start-GuiAppExecutionRun `
		-Action $Action `
		-LoaderPath $appModulePath `
		-LocalizationDirectory $Script:GuiLocalizationDirectoryPath `
		-UICulture $bgUICulture `
		-LogFilePath $Global:LogFilePath `
		-WinGetId $resolvedWinGetId `
		-ChocoId $resolvedChocoId `
		-DisplayName $resolvedDisplayName `
		-Application $Application `
		-PreferredSource $resolvedPreferredSource `
		-PackageManagerAvailabilityState $Script:AppsPackageManagerAvailabilityState
}

<#
    .SYNOPSIS
    Internal function Start-AppsModuleBatchActionAsync.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Start-AppsModuleBatchActionAsync
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update')]
		[string]$Action,

		[object[]]$SelectedApps = @(),

		[string]$PreferredSource = $null
	)

	Initialize-AppsSelectionState
	if (-not $SelectedApps -or $SelectedApps.Count -eq 0)
	{
		$SelectedApps = @(Get-SelectedAppsCatalogItems)
	}
	else
	{
		$SelectedApps = @($SelectedApps | Where-Object { $_ })
	}

	Initialize-AppPackageSourcePreferenceState
	$resolvedPreferredSource = ConvertTo-AppPackageSourcePreference -Source $(if ([string]::IsNullOrWhiteSpace([string]$PreferredSource)) { $Script:AppsPackageSourcePreference } else { $PreferredSource })

	if ($SelectedApps.Count -eq 0)
	{
		return
	}

	$appModulePath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Regions\Applications.psm1'
	$bgUICulture = if ([string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage)) { 'en' } else { [string]$Script:SelectedLanguage }
	Start-GuiAppExecutionRun `
		-Action $Action `
		-LoaderPath $appModulePath `
		-LocalizationDirectory $Script:GuiLocalizationDirectoryPath `
		-UICulture $bgUICulture `
		-LogFilePath $Global:LogFilePath `
		-SelectedApps @($SelectedApps) `
		-PreferredSource $resolvedPreferredSource `
		-PackageManagerAvailabilityState $Script:AppsPackageManagerAvailabilityState
}

<#
    .SYNOPSIS
    Internal function Set-GuiAppsMode.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Set-GuiAppsMode
{
	[CmdletBinding()]
	param (
		[bool]$Enable = $false
	)

	if ($Script:AppsModeActive -eq $Enable)
	{
		return
	}

	$Script:AppsModeActive = $Enable
	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = -not $Enable }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = $Enable }
	if ($Enable -and (-not $Script:AppsProgressBar -or -not $Script:AppsProgressHost))
	{
		Initialize-AppsProgressSection
	}
	if ($Enable -and $Script:AppsProgressBar -and -not $Script:AppsOperationInProgress -and -not $Script:AppsCacheRefreshInProgress)
	{
		$appsViewAlreadyRendered = [bool]($Script:AppsWrapPanel -and $Script:AppsWrapPanel.Children -and $Script:AppsWrapPanel.Children.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Script:AppsViewBuildSignature))
		if (-not $appsViewAlreadyRendered)
		{
			$Script:AppsProgressBar.IsIndeterminate = $false
			$Script:AppsProgressBar.Maximum = 1
			$Script:AppsProgressBar.Value = 0
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
			}
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
			}
			if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Update-AppsPackageManagerBanner } catch { $null = $_ }
			}
		}
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:AppsView) { $Script:AppsView.Visibility = if ($Enable) { $visible } else { $collapsed } }
	if ($Script:PrimaryTabHost) { $Script:PrimaryTabHost.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:ExpertModeBanner) { $Script:ExpertModeBanner.Visibility = if ($Enable) { $collapsed } else { $visible } }

	if ($Script:TxtSearch)
	{
		$desiredSearchText = if ($Enable) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
		if ($Script:TxtSearch.Text -ne $desiredSearchText)
		{
			$Script:SearchUiUpdating = $true
			try
			{
				$Script:TxtSearch.Text = $desiredSearchText
			}
			finally
			{
				$Script:SearchUiUpdating = $false
			}
		}
	}

	if ($Enable)
	{
		Initialize-AppPackageSourcePreferenceState
		Update-AppPackageSourcePreferenceControls
	}

	foreach ($control in @($Script:BtnFilterToggle, $Script:FilterOptionsPanel))
	{
		if ($control)
		{
			$control.Visibility = if ($Enable) { $collapsed } else { $visible }
		}
	}

	if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnRun) { $Script:BtnRun.Visibility = if ($Enable) { $collapsed } else { $visible } }

	if ($Enable)
	{
		Build-AppsViewCards
	}
	else
	{
		if ($Script:CurrentPrimaryTab)
		{
			$Script:FilterGeneration++
			if ($Script:UpdateCurrentTabContentScript)
			{
				& $Script:UpdateCurrentTabContentScript
			}
			elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Update-CurrentTabContent
			}
		}
	}

	if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		if ($Script:SyncUxActionButtonTextScript)
		{
			& $Script:SyncUxActionButtonTextScript
		}
		else
		{
			Sync-UxActionButtonText
		}
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-BaselineUpdateOverlay.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Initialize-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param ()

	if (-not $Script:CustomPBarContainer -or -not $Script:UpdateDialogOverlay) { return }

	Ensure-SheenProgressBarType

	$sharedProgress = New-SharedProgressBarHost -Maximum 100 -Value 0
	$windowsFormsHost = $sharedProgress.Host
	$progressBar = $sharedProgress.ProgressBar
	$Script:CustomProgressBar = $progressBar
	$Script:CustomProgressHost = $windowsFormsHost
	$Script:CustomPBarContainer.Child = $windowsFormsHost
}

<#
    .SYNOPSIS
    Internal function Show-BaselineUpdateOverlay.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param (
		[string]$Title = (Get-UxLocalizedString -Key 'GuiUpdateDialogTitle' -Fallback 'Update Baseline'),
		[string]$Description = (Get-UxLocalizedString -Key 'GuiUpdateDialogDescription' -Fallback 'A new version of Baseline is available from GitHub. Do you want to download and extract it now?'),
		[string]$StatusText = (Get-UxLocalizedString -Key 'GuiUpdateDialogReady' -Fallback 'Ready to download.'),
		[string]$ProgressPct = '0%',
		[string]$PrimaryButtonText = (Get-UxLocalizedString -Key 'GuiUpdateDialogDownload' -Fallback 'Download Update'),
		[string]$SecondaryButtonText = (Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Cancel'),
		[bool]$ShowButtons = $true,
		[bool]$ShowProgressPct = $true,
		[switch]$Indeterminate
	)

	if ($Script:UpdateDialogOverlay)
	{
		$Script:UpdateDialogOverlay.Visibility = [System.Windows.Visibility]::Visible
	}
	if ($Script:CustomProgressBar)
	{
		$Script:CustomProgressBar.IsIndeterminate = [bool]$Indeterminate
		$Script:CustomProgressBar.Value = 0
	}
	if ($Script:TxtOverlayTitle) { $Script:TxtOverlayTitle.Text = [string]$Title }
	if ($Script:TxtUpdateDescription) { $Script:TxtUpdateDescription.Text = [string]$Description }
	if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = [string]$StatusText }
	if ($Script:TxtDownloadProgressPct)
	{
		$Script:TxtDownloadProgressPct.Text = [string]$ProgressPct
		$Script:TxtDownloadProgressPct.Visibility = if ($ShowProgressPct) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
	}
	if ($Script:BtnDownloadYes)
	{
		$Script:BtnDownloadYes.Content = [string]$PrimaryButtonText
		$Script:BtnDownloadYes.Visibility = if ($ShowButtons) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		$Script:BtnDownloadYes.IsEnabled = [bool]$ShowButtons
	}
	if ($Script:BtnDownloadNo)
	{
		$Script:BtnDownloadNo.Content = [string]$SecondaryButtonText
		$Script:BtnDownloadNo.Visibility = if ($ShowButtons) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
		$Script:BtnDownloadNo.IsEnabled = [bool]$ShowButtons
	}
}

<#
    .SYNOPSIS
    Internal function Show-BaselineUpdateCheckDialog.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-BaselineUpdateCheckDialog
{
	[CmdletBinding()]
	param ()

	$title = (Get-UxLocalizedString -Key 'GuiUpdateDialogTitle' -Fallback 'Update Baseline')
	$checkingDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckDescription' -Fallback 'Checking GitHub releases for a newer Baseline version.')
	$checkingStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckStatus' -Fallback 'Checking for updates...')
	$openReleaseLabel = (Get-UxLocalizedString -Key 'GuiUpdateCheckOpenRelease' -Fallback 'Open Release Page')
	$closeLabel = (Get-UxLocalizedString -Key 'GuiCloseButton' -Fallback 'Close')
	$upToDateDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckUpToDateDescription' -Fallback 'Baseline is already up to date.')
	$upToDateStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckUpToDateStatus' -Fallback 'Already up to date.')
	$availableDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableDescription' -Fallback 'A newer version of Baseline is available on GitHub Releases.')
	$availableStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableStatus' -Fallback 'Update available.')
	$errorDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckFailedDescription' -Fallback 'Unable to check for updates right now.')
	$releasePageUrl = 'https://github.com/sdmanson8/Baseline/releases/latest'
	$currentVersion = '0.0.0'
	$hideBaselineUpdateOverlayCommand = Get-GuiRuntimeCommand -Name 'Hide-BaselineUpdateOverlay' -CommandType 'Function'
	$startBaselineDownloadCommand = Get-GuiRuntimeCommand -Name 'Start-BaselineDownload' -CommandType 'Function'
	$showSingleCloseButton = {
		if ($Script:BtnDownloadNo)
		{
			$Script:BtnDownloadNo.Visibility = [System.Windows.Visibility]::Collapsed
			$Script:BtnDownloadNo.IsEnabled = $false
		}
	}

	try
	{
		$currentVersion = [string](Get-BaselineDisplayVersion)
	}
	catch { }

	Show-BaselineUpdateOverlay -Title $title -Description $checkingDescription -StatusText $checkingStatus -ShowButtons:$false -ShowProgressPct:$false -Indeterminate

	try
	{
		Set-DownloadSecurityProtocol
		$headers = @{ 'User-Agent' = "Baseline/$currentVersion" }
		$releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/sdmanson8/Baseline/releases' -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction Stop
		$release = $releases | Where-Object { -not $_.draft } | Select-Object -First 1
		if (-not $release)
		{
			Show-BaselineUpdateOverlay -Title $title -Description $upToDateDescription -StatusText $checkingStatus -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $showSingleCloseButton
			if ($Script:BtnDownloadYes)
			{
				if ($Script:UpdateCheckPrimaryClickEvent) { try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { } }
				$Script:UpdateCheckPrimaryClickEvent = {
					& $hideBaselineUpdateOverlayCommand
				}.GetNewClosure()
				$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
			}
			return
		}

		$latestTag = [string]$release.tag_name
		$latestClean = $latestTag.TrimStart('v').Split('+')[0].Split('-')[0].Trim()
		$currentClean = $currentVersion.TrimStart('v').Split('+')[0].Split('-')[0].Trim()

		$isNewer = $false
		if ([System.Version]::TryParse($latestClean, [ref]$null) -and [System.Version]::TryParse($currentClean, [ref]$null))
		{
			$isNewer = ([System.Version]$latestClean) -gt ([System.Version]$currentClean)
		}
		else
		{
			$isNewer = [string]::Compare($latestClean, $currentClean, [System.StringComparison]::OrdinalIgnoreCase) -gt 0
		}

		if (-not $isNewer)
		{
			Show-BaselineUpdateOverlay -Title $title -Description $upToDateDescription -StatusText ($upToDateStatus -f $latestTag) -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			& $showSingleCloseButton
			if ($Script:BtnDownloadYes)
			{
				if ($Script:UpdateCheckPrimaryClickEvent) { try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { } }
				$Script:UpdateCheckPrimaryClickEvent = {
					& $hideBaselineUpdateOverlayCommand
				}.GetNewClosure()
				$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
			}
			return
		}

		$releaseAsset = $release.assets | Where-Object { $_.name -like 'Baseline-*.zip' } | Select-Object -First 1
		if ($releaseAsset)
		{
			$availableDescription = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableDescription' -Fallback 'A newer version of Baseline is available on GitHub Releases.') -f $latestTag
			$availableStatus = (Get-UxLocalizedString -Key 'GuiUpdateCheckAvailableStatus' -Fallback 'Update available: {0}.') -f $latestTag
			Show-BaselineUpdateOverlay -Title $title -Description $availableDescription -StatusText $availableStatus -PrimaryButtonText $openReleaseLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
			if ($Script:BtnDownloadYes)
			{
				if ($Script:UpdateCheckPrimaryClickEvent) { try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { } }
				$Script:UpdateCheckPrimaryClickEvent = {
					try { Start-Process -FilePath $releasePageUrl -ErrorAction SilentlyContinue } catch { }
					& $hideBaselineUpdateOverlayCommand
				}.GetNewClosure()
				$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
			}
			return
		}

		Show-BaselineUpdateOverlay -Title $title -Description $errorDescription -StatusText ($availableStatus -f $latestTag) -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
		& $showSingleCloseButton
		if ($Script:BtnDownloadYes)
		{
			if ($Script:UpdateCheckPrimaryClickEvent) { try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { } }
			$Script:UpdateCheckPrimaryClickEvent = {
				& $hideBaselineUpdateOverlayCommand
			}.GetNewClosure()
			$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
		}
	}
	catch
	{
		Show-BaselineUpdateOverlay -Title $title -Description $errorDescription -StatusText $_.Exception.Message -PrimaryButtonText $closeLabel -SecondaryButtonText $closeLabel -ShowButtons:$true -ShowProgressPct:$false
		& $showSingleCloseButton
		if ($Script:BtnDownloadYes)
		{
			if ($Script:UpdateCheckPrimaryClickEvent) { try { $Script:BtnDownloadYes.Remove_Click($Script:UpdateCheckPrimaryClickEvent) } catch { } }
			$Script:UpdateCheckPrimaryClickEvent = {
				& $hideBaselineUpdateOverlayCommand
			}.GetNewClosure()
			$Script:BtnDownloadYes.Add_Click($Script:UpdateCheckPrimaryClickEvent)
		}
	}
}

<#
    .SYNOPSIS
    Internal function Show-BaselineImportOverlay.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Show-BaselineImportOverlay
{
	[CmdletBinding()]
	param (
		[string]$Title = (Get-UxLocalizedString -Key 'GuiImportSettings' -Fallback 'Import Settings'),
		[string]$Description = (Get-UxLocalizedString -Key 'GuiImportSettingsOverlayDescription' -Fallback 'Loading the selected settings profile.'),
		[string]$StatusText = (Get-UxLocalizedString -Key 'GuiImportSettingsPreparing' -Fallback 'Preparing import...')
	)

	Show-BaselineUpdateOverlay -Title $Title -Description $Description -StatusText $StatusText -ShowButtons:$false -ShowProgressPct:$false -Indeterminate
}

<#
    .SYNOPSIS
    Internal function .

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Hide-BaselineUpdateOverlay
{
	[CmdletBinding()]
	param ()

	if ($Script:UpdateDialogOverlay)
	{
		$Script:UpdateDialogOverlay.Visibility = [System.Windows.Visibility]::Collapsed
	}
}

<#
    .SYNOPSIS
    Internal function Start-BaselineDownload.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Start-BaselineDownload
{
	param (
		[string]$Uri,
		[string]$DestinationPath
	)

	LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogStartBackgroundDownload' -Fallback 'Starting background download from {0}' -FormatArgs @($Uri))

	if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $false }
	if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $false }
	if ($Script:CustomProgressBar)
	{
		$Script:CustomProgressBar.IsIndeterminate = $false
		$Script:CustomProgressBar.Value = 0
	}
	if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "0%" }
	if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusDownloadConnecting' -Fallback 'Connecting to GitHub...') }

		$syncHash = [hashtable]::Synchronized(@{
			ProgressPct = 0
			Status      = (Get-UxLocalizedString -Key 'GuiStatusDownloadInitializing' -Fallback 'Initializing...')
			IsComplete  = $false
			Error       = $null
		})

	$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
	$runspace.Open()
	$ps = [System.Management.Automation.PowerShell]::Create()
	$ps.Runspace = $runspace

	[void]$ps.AddScript({
		param($DownloadUri, $Path, $Sync)
		$response = $null
		$responseStream = $null
		$targetStream = $null
		try
		{
			$webRequest = [System.Net.WebRequest]::Create($DownloadUri)
			$response = $webRequest.GetResponse()
			$totalBytes = $response.ContentLength

			$responseStream = $response.GetResponseStream()
			$targetStream = [System.IO.File]::Create($Path)

			$buffer = New-Object byte[] 65536
			$totalRead = 0

			do
			{
				$read = $responseStream.Read($buffer, 0, $buffer.Length)
				if ($read -gt 0)
				{
					$targetStream.Write($buffer, 0, $read)
					$totalRead += $read
					if ($totalBytes -gt 0)
					{
						$Sync.ProgressPct = [math]::Round(($totalRead / $totalBytes) * 100)
						$mbRead = [math]::Round($totalRead / 1MB, 2)
						$mbTotal = [math]::Round($totalBytes / 1MB, 2)
							$Sync.Status = (Get-UxLocalizedString -Key 'GuiStatusDownloadProgressFormat' -Fallback 'Downloading... {0} MB / {1} MB' -FormatArgs @($mbRead, $mbTotal))
					}
				}
			}
			while ($read -gt 0)

			$Sync.IsComplete = $true
			$Sync.Status = (Get-UxLocalizedString -Key 'GuiStatusDownloadComplete' -Fallback 'Download complete.')
		}
		catch
		{
			$Sync.Error = $_.Exception.Message
			$Sync.IsComplete = $true
		}
		finally
		{
			if ($targetStream) { $targetStream.Dispose() }
			if ($responseStream) { $responseStream.Dispose() }
			if ($response) { $response.Dispose() }
		}
	}).AddArgument($Uri).AddArgument($DestinationPath).AddArgument($syncHash)

	$asyncResult = $ps.BeginInvoke()

	$timer = [System.Windows.Threading.DispatcherTimer]::new()
	$timer.Interval = [TimeSpan]::FromMilliseconds(50)

	$timer.Add_Tick({
		if ($syncHash.Error)
		{
			$timer.Stop()
			if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusDownloadFailedFormat' -Fallback 'Download failed: {0}' -FormatArgs @($syncHash.Error)) }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.Content = (Get-UxLocalizedString -Key 'GuiStatusDownloadRetry' -Fallback 'Retry') }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $true }
			if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $true }
			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
			return
		}

		if ($Script:CustomProgressBar) { $Script:CustomProgressBar.Value = $syncHash.ProgressPct }
		if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "$($syncHash.ProgressPct)%" }
		if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Text = $syncHash.Status }

		if ($syncHash.IsComplete -and -not $syncHash.Error)
		{
			$timer.Stop()
			if ($Script:CustomProgressBar) { $Script:CustomProgressBar.Value = 100 }
			if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Text = "100%" }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.Content = (Get-UxLocalizedString -Key 'GuiStatusDownloadExtractRestart' -Fallback 'Extract & Restart') }
			if ($Script:BtnDownloadYes) { $Script:BtnDownloadYes.IsEnabled = $true }
			if ($Script:BtnDownloadNo) { $Script:BtnDownloadNo.IsEnabled = $true }

			if ($Script:BtnDownloadYes -and $Script:DownloadStartEvent)
			{
				try { $Script:BtnDownloadYes.Remove_Click($Script:DownloadStartEvent) } catch { $null = $_ }
			}
			if ($Script:BtnDownloadYes -and $Script:DownloadExtractEvent)
			{
				$Script:BtnDownloadYes.Add_Click($Script:DownloadExtractEvent)
			}

			try { $ps.Dispose() } catch { $null = $_ }
			try { $runspace.Dispose() } catch { $null = $_ }
		}
	}.GetNewClosure())

	$timer.Start()
}

#region GUI Builder
<#
	.SYNOPSIS
	Show the WPF tweak-selection GUI and execute selected tweaks.

	.DESCRIPTION
	Builds a modern two-tier tabbed WPF window from $Script:TweakManifest.
	The GUI stays open after each run so further changes can be made.
	Supports dark/light themes, system-scan to skip already-applied tweaks,
	info icons, caution sections, and linked toggles (PS7 <-> telemetry).

	.EXAMPLE
	Show-TweakGUI
#>
function Show-TweakGUI
{
	[CmdletBinding()]
	param ()

	# Enable per-monitor DPI awareness before any WPF objects are created
	# so the window renders at native resolution on high-DPI displays.
	try { GUICommon\Initialize-GuiDpiAwareness } catch { <# non-fatal #> }

	# --- Extracted function groups (dot-sourced to reduce file size) ---
	$Script:GuiExtractedRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'GUI'

	# Context Object and Observable State must load first - other GUI files reference $Script:Ctx
	. (Join-Path $Script:GuiExtractedRoot 'GuiContext.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'StateTransitions.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ObservableState.ps1')
	$Script:Ctx = New-GuiContext
	$Script:Ctx.Config.ExtractedRoot = $Script:GuiExtractedRoot
	$Script:AuditRetentionDays = [int]$Script:Ctx.UI.AuditRetentionDays

	. (Join-Path $Script:GuiExtractedRoot 'UxPolicy.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'SessionState.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PreviewBuilders.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ExecutionSummary.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PresetManagement.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'GameModeUI.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'GameModeState.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PreflightChecks.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PlanSummaryPanel.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ExecutionOrchestration.ps1')


	if (-not $Script:ManifestLoadedFromData)
	{
		try
		{
			$Script:TweakManifest = Import-TweakManifestFromData `
				-DetectScriptblocks $Script:DetectScriptblocks `
				-VisibleIfScriptblocks $Script:VisibleIfScriptblocks
			Test-TweakManifestIntegrity -Manifest $Script:TweakManifest
			$Script:ManifestLoadedFromData = $true
			$Script:Ctx.Data.TweakManifest = $Script:TweakManifest
			$Script:Ctx.Data.ManifestLoaded = $true
		}
		catch
		{
			Write-Warning ("Failed to load tweak metadata from Module/Data: {0}" -f $_.Exception.Message)
			return
		}
	}

	Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
	Add-Type -AssemblyName System.Windows.Forms, System.Drawing, WindowsFormsIntegration

	Ensure-SheenProgressBarType

	if (-not $Script:ExplicitPresetSelections) {
		$Script:ExplicitPresetSelections = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not $Script:ExplicitPresetSelectionDefinitions) {
		$Script:ExplicitPresetSelectionDefinitions = @{}
	}

	$Script:GuiModuleBasePath = $null
	$Script:GuiPresetDirectoryPath = $null
	$Script:GuiLocalizationDirectoryPath = $null

	try { $Script:GuiModuleBasePath = $MyInvocation.MyCommand.Module.ModuleBase } catch {}
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $PSCommandPath } catch {}
	}
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {}
	}
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $PSScriptRoot } catch {}
	}
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

	if (-not [string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		$Script:GuiPresetDirectoryPath = Join-Path -Path $Script:GuiModuleBasePath -ChildPath 'Data\Presets'
		$Script:GuiLocalizationDirectoryPath = Resolve-BaselineLocalizationDirectory -BasePath $Script:GuiModuleBasePath
	}

	# Primary category tabs (top tier)
	$PrimaryCategories = [ordered]@{
		"Initial Setup"        = @()
		"Privacy & Telemetry"  = @()
		"Security"             = @("Security", "OS Hardening")
		"System"               = @("System", "System Tweaks", "Start Menu", "Start Menu Apps")
		"Updates"              = @()
		"UI & Personalization" = @("UI & Personalization", "Taskbar", "Taskbar Clock", "Cursors")
		"UWP Apps"             = @("UWP Apps", "OneDrive")
		"Gaming"               = @()
		"Context Menu"         = @()
	}

	# Map manifest categories to primary tabs
	$CategoryToPrimary = @{}
	foreach ($prim in $PrimaryCategories.Keys)
	{
		$subs = $PrimaryCategories[$prim]
		if ($subs.Count -eq 0)
		{
			$CategoryToPrimary[$prim] = $prim
		}
		else
		{
			foreach ($s in $subs) { $CategoryToPrimary[$s] = $prim }
		}
	}
	$Script:UpdatesPrimaryTabFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach (
		$functionName in @(
			'ActiveHours'
			'DeliveryOptimization'
			'MaintenanceWakeUp'
			'RestartDeviceAfterUpdate'
			'RestartNotification'
			'SearchAppInStore'
			'BlockStoreSearchResults'
			'Set-DownloadUpdatesOverMeteredConnection'
			'Set-FeatureUpdateDeferral'
			'Set-QualityUpdateDeferral'
			'Set-StoreAppAutoDownload'
			'Set-WindowsUpdatePause'
			'Set-WindowsUpdateSecurityOnlyMode'
			'UpdateAutoDownload'
			'UpdateDriver'
			'UpdateMSProducts'
			'UpdateMicrosoftProducts'
			'UpdateRestart'
			'WindowsLatestUpdate'
		)
	)
	{
		if (-not [string]::IsNullOrWhiteSpace([string]$functionName))
		{
			[void]$Script:UpdatesPrimaryTabFunctions.Add([string]$functionName)
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Resolve-GuiPrimaryTabForTweak.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Resolve-GuiPrimaryTabForTweak
	{
		param ([object]$Tweak)

		if (-not $Tweak)
		{
			return $null
		}

		$functionName = if ($Tweak -is [System.Collections.IDictionary])
		{
			if ($Tweak.Contains('Function')) { [string]$Tweak['Function'] } else { $null }
		}
		elseif ($Tweak.PSObject.Properties['Function']) { [string]$Tweak.Function }
		else { $null }

		if (-not [string]::IsNullOrWhiteSpace($functionName) -and $Script:UpdatesPrimaryTabFunctions -and $Script:UpdatesPrimaryTabFunctions.Contains($functionName))
		{
			return 'Updates'
		}

		$categoryName = if ($Tweak -is [System.Collections.IDictionary])
		{
			if ($Tweak.Contains('Category')) { [string]$Tweak['Category'] } else { $null }
		}
		elseif ($Tweak.PSObject.Properties['Category']) { [string]$Tweak.Category }
		else { $null }

		if ([string]::IsNullOrWhiteSpace($categoryName))
		{
			return $null
		}

		if ($CategoryToPrimary.ContainsKey($categoryName))
		{
			return [string]$CategoryToPrimary[$categoryName]
		}

		return $categoryName
	}

	# Ensure all manifest categories map somewhere
	foreach ($t in $Script:TweakManifest)
	{
		if (-not $CategoryToPrimary.ContainsKey($t.Category))
		{
			$CategoryToPrimary[$t.Category] = $t.Category
		}
	}

	# Pre-compute search haystacks once so Test-TweakMatchesCurrentFilters never
	# rebuilds them on every keystroke.  All fields are static tweak metadata.
	$Script:TweakSearchHaystacks = @{}
	for ($__hi = 0; $__hi -lt $Script:TweakManifest.Count; $__hi++)
	{
		$__t = $Script:TweakManifest[$__hi]
		if (-not $__t) { continue }
		$__owning = Resolve-GuiPrimaryTabForTweak -Tweak $__t
		$__sb = [System.Text.StringBuilder]::new(256)
		foreach ($__p in @([string]$__t.Name, [string]$__t.Description, [string]$__t.Detail, [string]$__t.WhyThisMatters,
		                    [string]$__t.Category, [string]$__t.SubCategory, [string]$__t.Function, $__owning,
		                    [string]$__t.Risk, [string]$__t.PresetTier))
		{
			if (-not [string]::IsNullOrWhiteSpace($__p)) { [void]$__sb.Append($__p); [void]$__sb.Append(' ') }
		}
		if ($__t.Tags) { $__tags = $__t.Tags -join ' '; if ($__tags) { [void]$__sb.Append($__tags); [void]$__sb.Append(' ') } }
		[void]$__sb.Append($(if ($__t.Safe) { 'safe' } else { 'not-safe' }))
		[void]$__sb.Append(' ')
		[void]$__sb.Append($(if ($__t.Impact) { 'impact' } else { 'standard' }))
		[void]$__sb.Append(' ')
		[void]$__sb.Append($(if ($__t.RequiresRestart) { 'restart reboot requires-restart' } else { 'no-restart' }))
		$Script:TweakSearchHaystacks[$__hi] = $__sb.ToString()
	}
	Remove-Variable -Name __hi, __t, __owning, __sb, __p, __tags -ErrorAction SilentlyContinue

	# --- Phase 2 extractions (after WPF assemblies are loaded) ---
	. (Join-Path $Script:GuiExtractedRoot 'ThemeManagement.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'IconRegistry.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'IconFactory.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'TweakAnalysis.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ComponentFactory.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'FilteringLogic.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ApplicationsView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'SystemScan.ps1')

	# Write-GuiRuntimeWarning is defined at module scope (before Show-TweakGUI) so it is visible from Dispatcher.BeginInvoke closures and .GetNewClosure() scriptblocks.

	. (Join-Path $Script:GuiExtractedRoot 'EventInfrastructure.ps1')


	$Script:GuiEventHandlerStore = [System.Collections.Generic.List[object]]::new()
	$Script:GuiRuntimeCommandCache = @{}
	$Script:GuiFunctionCaptureCache = @{}
	$Script:ShowGuiRuntimeFailureScript = ${function:Show-ScopedGuiRuntimeFailure}
	$Script:TestGuiRunInProgressScript = ${function:Test-GuiRunInProgress}
	$Script:NewSafeBrushConverterScript = ${function:New-SafeBrushConverter}
	if ($Script:ShowGuiRuntimeFailureScript -isnot [scriptblock]) { throw "Show-ScopedGuiRuntimeFailure capture did not resolve to a scriptblock." }
	if ($Script:TestGuiRunInProgressScript -isnot [scriptblock]) { throw "Test-GuiRunInProgress capture did not resolve to a scriptblock." }
	if ($Script:NewSafeBrushConverterScript -isnot [scriptblock]) { throw "New-SafeBrushConverter capture did not resolve to a scriptblock." }

	$Script:DarkTheme = Repair-GuiThemePalette -Theme $Script:DarkTheme -ThemeName 'Dark'
	$Script:LightTheme = Repair-GuiThemePalette -Theme $Script:LightTheme -ThemeName 'Light'
	$Script:CurrentTheme = $Script:DarkTheme
	$Script:BrushCache = @{}
	$Script:SharedBrushConverter = [System.Windows.Media.BrushConverter]::new()
	$Script:SharedCardShadow = $null

	# Sync context - theme (read-only after init)
	$Script:Ctx.Theme.Dark = $Script:DarkTheme
	$Script:Ctx.Theme.Light = $Script:LightTheme
	$Script:Ctx.Theme.Current = $Script:CurrentTheme
	$Script:Ctx.Theme.CurrentName = 'Dark'
	$Script:Ctx.Theme.BrushConverter = $Script:SharedBrushConverter
	$Script:Ctx.Theme.BrushCache = $Script:BrushCache
	#endregion Theme colors

	Initialize-GuiIconSystem -ModuleRoot $Script:GuiModuleBasePath

	. (Join-Path $Script:GuiExtractedRoot 'StyleManagement.ps1')


	#region Themed Dialog

	. (Join-Path $Script:GuiExtractedRoot 'ExecutionSummaryDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'DiffView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ComplianceView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'AuditView.ps1')


	# --- Dialog and tab management extractions (after XAML controls are available) ---
	. (Join-Path $Script:GuiExtractedRoot 'DialogHelpers.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'TabManagement.ps1')

	$guiWindowMinWidth  = $Script:GuiLayout.WindowMinWidth
	$guiWindowMinHeight = $Script:GuiLayout.WindowMinHeight

	#region XAML template
	[xml]$XAML = @"
	<Window
		xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
		xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
		Name="MainWindow"
		Title="Baseline | Utility for Windows"
	MinWidth="$guiWindowMinWidth" MinHeight="$guiWindowMinHeight"
	WindowStartupLocation="CenterScreen"
	FontFamily="FluentSystemIcons" FontSize="13"
	ShowInTaskbar="True"
	WindowStyle="None"
	AllowsTransparency="True"
	Background="Transparent"
	ResizeMode="CanResizeWithGrip">
	<Border Name="RootBorder" CornerRadius="8" Background="#1E1E2E" BorderBrush="#333346" BorderThickness="1" Margin="0">
	<Border.Resources>
		<!-- Themed scrollbar brushes; replaced at runtime by Set-GUITheme -->
		<SolidColorBrush x:Key="ScrollBarTrackBrush"       Color="#1E1E2E"/>
		<SolidColorBrush x:Key="ScrollBarThumbBrush"       Color="#4A4D5E"/>
		<SolidColorBrush x:Key="ScrollBarThumbHoverBrush"  Color="#6C7086"/>
		<SolidColorBrush x:Key="ScrollBarThumbActiveBrush" Color="#7F849C"/>

		<Style x:Key="BaselineScrollBarThumbStyle" TargetType="Thumb">
			<Setter Property="OverridesDefaultStyle" Value="True"/>
			<Setter Property="IsTabStop" Value="False"/>
			<Setter Property="Focusable" Value="False"/>
			<Setter Property="Background" Value="{DynamicResource ScrollBarThumbBrush}"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Thumb">
						<Border x:Name="ThumbBorder" Background="{TemplateBinding Background}" CornerRadius="4" Margin="2" Opacity="0.55"/>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="ThumbBorder" Property="Background" Value="{DynamicResource ScrollBarThumbHoverBrush}"/>
								<Setter TargetName="ThumbBorder" Property="Opacity" Value="0.85"/>
							</Trigger>
							<Trigger Property="IsDragging" Value="True">
								<Setter TargetName="ThumbBorder" Property="Background" Value="{DynamicResource ScrollBarThumbActiveBrush}"/>
								<Setter TargetName="ThumbBorder" Property="Opacity" Value="1.0"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<Style x:Key="BaselineScrollBarRepeatButtonStyle" TargetType="RepeatButton">
			<Setter Property="OverridesDefaultStyle" Value="True"/>
			<Setter Property="Background" Value="Transparent"/>
			<Setter Property="IsTabStop" Value="False"/>
			<Setter Property="Focusable" Value="False"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="RepeatButton">
						<Border Background="Transparent"/>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<Style TargetType="ScrollBar">
			<Setter Property="Background" Value="{DynamicResource ScrollBarTrackBrush}"/>
			<Setter Property="Foreground" Value="{DynamicResource ScrollBarThumbBrush}"/>
			<Setter Property="BorderThickness" Value="0"/>
			<Setter Property="SnapsToDevicePixels" Value="True"/>
			<Style.Triggers>
				<Trigger Property="Orientation" Value="Vertical">
					<Setter Property="Width" Value="8"/>
					<Setter Property="MinWidth" Value="8"/>
					<Setter Property="Template">
						<Setter.Value>
							<ControlTemplate TargetType="ScrollBar">
								<Grid Background="Transparent">
									<Border Background="{TemplateBinding Background}" Opacity="0.30" CornerRadius="4"/>
									<Track Name="PART_Track" IsDirectionReversed="True">
										<Track.DecreaseRepeatButton>
											<RepeatButton Style="{StaticResource BaselineScrollBarRepeatButtonStyle}" Command="ScrollBar.PageUpCommand"/>
										</Track.DecreaseRepeatButton>
										<Track.Thumb>
											<Thumb Style="{StaticResource BaselineScrollBarThumbStyle}" MinHeight="30"/>
										</Track.Thumb>
										<Track.IncreaseRepeatButton>
											<RepeatButton Style="{StaticResource BaselineScrollBarRepeatButtonStyle}" Command="ScrollBar.PageDownCommand"/>
										</Track.IncreaseRepeatButton>
									</Track>
								</Grid>
							</ControlTemplate>
						</Setter.Value>
					</Setter>
				</Trigger>
				<Trigger Property="Orientation" Value="Horizontal">
					<Setter Property="Height" Value="8"/>
					<Setter Property="MinHeight" Value="8"/>
					<Setter Property="Template">
						<Setter.Value>
							<ControlTemplate TargetType="ScrollBar">
								<Grid Background="Transparent">
									<Border Background="{TemplateBinding Background}" Opacity="0.30" CornerRadius="4"/>
									<Track Name="PART_Track" IsDirectionReversed="False">
										<Track.DecreaseRepeatButton>
											<RepeatButton Style="{StaticResource BaselineScrollBarRepeatButtonStyle}" Command="ScrollBar.PageLeftCommand"/>
										</Track.DecreaseRepeatButton>
										<Track.Thumb>
											<Thumb Style="{StaticResource BaselineScrollBarThumbStyle}" MinWidth="30"/>
										</Track.Thumb>
										<Track.IncreaseRepeatButton>
											<RepeatButton Style="{StaticResource BaselineScrollBarRepeatButtonStyle}" Command="ScrollBar.PageRightCommand"/>
										</Track.IncreaseRepeatButton>
									</Track>
								</Grid>
							</ControlTemplate>
						</Setter.Value>
					</Setter>
				</Trigger>
			</Style.Triggers>
		</Style>
	</Border.Resources>
	<Grid>
		<!-- Custom title bar -->
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
		</Grid.RowDefinitions>
		<Border Name="TitleBar" Grid.Row="0" Background="#181825" CornerRadius="8,8,0,0" Padding="12,8,8,8" Cursor="Arrow">
			<Grid>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="Auto"/>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<Image Name="TitleBarLogo" Grid.Column="0" Width="18" Height="18" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,8,0"/>
				<TextBlock Name="TitleBarText" Grid.Column="1" Text="" VerticalAlignment="Center" FontSize="12" Foreground="#CDD6F4"/>
				<StackPanel Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
					<Button Name="BtnMinimize" Content="&#x2212;" FontFamily="Arial" FontSize="12" Width="36" Height="28" Background="Transparent" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
					<Button Name="BtnMaximize" Content="&#x25A1;" FontFamily="Arial" FontSize="10" Width="36" Height="28" Background="Transparent" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
					<Button Name="BtnClose" Content="×" FontFamily="Arial" FontSize="12" Width="36" Height="28" Background="Transparent" Foreground="#CDD6F4" BorderThickness="0" Cursor="Hand" VerticalContentAlignment="Center" HorizontalContentAlignment="Center"/>
				</StackPanel>
			</Grid>
		</Border>
	<Grid Grid.Row="1">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>
		<!-- Top Menu Bar -->
		<Border Name="MenuBarBorder" Grid.Row="0" Background="{DynamicResource MenuBarBackground}" BorderBrush="{DynamicResource MenuBarBorder}" BorderThickness="0,0,0,1" Padding="8,0">
			<Menu Name="MainMenuBar" Background="Transparent" Foreground="{DynamicResource MenuBarForeground}" FontFamily="Segoe UI" FontSize="12" Padding="0">
				<Menu.Resources>
					<!-- Themed fallback brushes; replaced at runtime by Set-GUITheme -->
					<SolidColorBrush x:Key="MenuBarBackground" Color="#181825"/>
					<SolidColorBrush x:Key="MenuBarBorder" Color="#4C556D"/>
					<SolidColorBrush x:Key="MenuBarForeground" Color="#CDD6F4"/>
					<SolidColorBrush x:Key="MenuBarHoverBg" Color="#3670B8"/>
					<SolidColorBrush x:Key="MenuBarHoverFg" Color="#FFFFFF"/>
					<SolidColorBrush x:Key="MenuSubmenuBg" Color="#272B3A"/>
					<SolidColorBrush x:Key="MenuSubmenuBorder" Color="#4C556D"/>
					<SolidColorBrush x:Key="MenuSeparatorBrush" Color="#4C556D"/>

					<!-- Top-level MenuItem (header in the menu bar) -->
					<ControlTemplate x:Key="BaselineTopMenuItemTemplate" TargetType="MenuItem">
						<Border Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
							<ContentPresenter ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsHighlighted" Value="True">
								<Setter TargetName="Bd" Property="Background" Value="{DynamicResource MenuBarHoverBg}"/>
								<Setter Property="Foreground" Value="{DynamicResource MenuBarHoverFg}"/>
							</Trigger>
							<Trigger Property="IsSubmenuOpen" Value="True">
								<Setter TargetName="Bd" Property="Background" Value="{DynamicResource MenuBarHoverBg}"/>
								<Setter Property="Foreground" Value="{DynamicResource MenuBarHoverFg}"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>

					<!-- Submenu MenuItem (items inside a dropdown) -->
					<ControlTemplate x:Key="BaselineSubMenuItemTemplate" TargetType="MenuItem">
						<Border Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
							<Grid>
								<Grid.ColumnDefinitions>
									<ColumnDefinition Width="18"/>
									<ColumnDefinition Width="*"/>
									<ColumnDefinition Width="Auto"/>
								</Grid.ColumnDefinitions>
								<TextBlock Name="CheckGlyph" Grid.Column="0" Text="&#x2713;" FontSize="12" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
								<ContentPresenter Grid.Column="1" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center" Margin="4,0,0,0"/>
								<TextBlock Grid.Column="2" Text="{TemplateBinding InputGestureText}" Opacity="0.6" Margin="16,0,0,0" VerticalAlignment="Center"/>
							</Grid>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsChecked" Value="True">
								<Setter TargetName="CheckGlyph" Property="Visibility" Value="Visible"/>
							</Trigger>
							<Trigger Property="IsHighlighted" Value="True">
								<Setter TargetName="Bd" Property="Background" Value="{DynamicResource MenuBarHoverBg}"/>
								<Setter Property="Foreground" Value="{DynamicResource MenuBarHoverFg}"/>
							</Trigger>
							<Trigger Property="IsEnabled" Value="False">
								<Setter Property="Opacity" Value="0.5"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>

					<!-- TopLevelHeader with themed submenu popup chrome -->
					<ControlTemplate x:Key="BaselineTopMenuHeaderTemplate" TargetType="MenuItem">
						<Grid>
							<Border Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
								<ContentPresenter ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
							</Border>
							<Popup Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsSubmenuOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
								<Border Name="SubmenuBorder" Background="{DynamicResource MenuSubmenuBg}" BorderBrush="{DynamicResource MenuSubmenuBorder}" BorderThickness="1" Padding="2" SnapsToDevicePixels="True">
									<StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
								</Border>
							</Popup>
						</Grid>
						<ControlTemplate.Triggers>
							<Trigger Property="IsHighlighted" Value="True">
								<Setter TargetName="Bd" Property="Background" Value="{DynamicResource MenuBarHoverBg}"/>
								<Setter Property="Foreground" Value="{DynamicResource MenuBarHoverFg}"/>
							</Trigger>
							<Trigger Property="IsSubmenuOpen" Value="True">
								<Setter TargetName="Bd" Property="Background" Value="{DynamicResource MenuBarHoverBg}"/>
								<Setter Property="Foreground" Value="{DynamicResource MenuBarHoverFg}"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>

					<Style TargetType="MenuItem">
						<Setter Property="Foreground" Value="{DynamicResource MenuBarForeground}"/>
						<Setter Property="Background" Value="Transparent"/>
						<Setter Property="Padding" Value="10,6"/>
						<Setter Property="FontFamily" Value="Segoe UI"/>
						<Setter Property="FontSize" Value="12"/>
						<Style.Triggers>
							<Trigger Property="Role" Value="TopLevelHeader">
								<Setter Property="Template" Value="{StaticResource BaselineTopMenuHeaderTemplate}"/>
							</Trigger>
							<Trigger Property="Role" Value="TopLevelItem">
								<Setter Property="Template" Value="{StaticResource BaselineTopMenuItemTemplate}"/>
							</Trigger>
							<Trigger Property="Role" Value="SubmenuHeader">
								<Setter Property="Template" Value="{StaticResource BaselineSubMenuItemTemplate}"/>
							</Trigger>
							<Trigger Property="Role" Value="SubmenuItem">
								<Setter Property="Template" Value="{StaticResource BaselineSubMenuItemTemplate}"/>
							</Trigger>
						</Style.Triggers>
					</Style>

					<Style TargetType="Separator">
						<Setter Property="Background" Value="{DynamicResource MenuSeparatorBrush}"/>
						<Setter Property="Height" Value="1"/>
						<Setter Property="Margin" Value="4,4"/>
					</Style>
				</Menu.Resources>
				<MenuItem Name="MenuFile" Header="_File">
					<MenuItem Name="MenuFileImportSettings" Header="Import Settings..."/>
					<MenuItem Name="MenuFileExportSettings" Header="Export Settings..."/>
					<MenuItem Name="MenuFileAuditSettings" Header="Audit Settings..."/>
					<Separator/>
					<MenuItem Name="MenuFileExportConfigProfile" Header="Export Config Profile..."/>
					<MenuItem Name="MenuFileExportSystemState" Header="Export System State..."/>
					<Separator/>
					<MenuItem Name="MenuFileExit" Header="E_xit" InputGestureText="Alt+F4"/>
				</MenuItem>
				<MenuItem Name="MenuActions" Header="_Actions">
					<MenuItem Name="MenuActionsConnectToComputer" Header="Connect to Computer..."/>
					<MenuItem Name="MenuActionsDisconnect" Header="Disconnect"/>
					<Separator/>
					<MenuItem Name="MenuActionsPreviewRun" Header="Preview Run"/>
					<MenuItem Name="MenuActionsRunTweaks" Header="Run Tweaks"/>
					<Separator/>
					<MenuItem Name="MenuActionsUndoLastRun" Header="Undo Last Run"/>
					<MenuItem Name="MenuActionsRestoreDefaults" Header="Restore Defaults"/>
					<Separator/>
					<MenuItem Name="MenuActionsCheckCompliance" Header="Check Compliance..."/>
					<MenuItem Name="MenuActionsScanSystem" Header="Scan System" IsCheckable="True"/>
					<MenuItem Name="MenuActionsAuditLog" Header="Audit Log..."/>
				</MenuItem>
				<MenuItem Name="MenuView" Header="_View">
					<MenuItem Name="MenuViewSafeMode" Header="Safe Mode" IsCheckable="True"/>
					<Separator/>
					<MenuItem Name="MenuViewFilters" Header="Show Filters Panel" IsCheckable="True"/>
					<MenuItem Name="MenuViewLogsPanel" Header="Open Logs"/>
					<MenuItem Name="MenuViewTheme" Header="Switch to Light Mode" IsCheckable="True"/>
				</MenuItem>
				<MenuItem Name="MenuTools" Header="_Tools">
					<MenuItem Name="MenuToolsAppsManager" Header="Apps Manager"/>
					<MenuItem Name="MenuToolsUpdateAllApps" Header="Update All Applications"/>
					<Separator/>
					<MenuItem Name="MenuToolsExportSupportBundle" Header="Export Support Bundle..."/>
					<MenuItem Name="MenuToolsApproveRemoteTargets" Header="Approve Target List..."/>
					<MenuItem Name="MenuToolsSaveRemoteApprovalPolicy" Header="Save Remote Approval Policy..."/>
					<MenuItem Name="MenuToolsLoadRemoteApprovalPolicy" Header="Load Remote Approval Policy..."/>
					<MenuItem Name="MenuToolsRemoteConsole" Header="Remote Console..."/>
					<MenuItem Name="MenuToolsOperatorConsole" Header="Operator Console..."/>
					<MenuItem Name="MenuToolsRemoteSessionStatus" Header="Remote Session Status..."/>
				</MenuItem>
				<MenuItem Name="MenuHelp" Header="_Help">
					<MenuItem Name="MenuHelpStartGuide" Header="Getting Started"/>
					<MenuItem Name="MenuHelpReadme" Header="Readme"/>
					<MenuItem Name="MenuHelpFAQ" Header="FAQ"/>
					<MenuItem Name="MenuHelpChangelog" Header="Changelog"/>
					<Separator/>
					<MenuItem Name="MenuHelpCheckForUpdate" Header="Check for Updates..."/>
					<Separator/>
					<MenuItem Name="MenuHelpReleaseStatus" Header="Release Status..."/>
					<MenuItem Name="MenuHelpTroubleshooting" Header="Troubleshooting Guide..."/>
					<MenuItem Name="MenuHelpAbout" Header="About Baseline"/>
				</MenuItem>
			</Menu>
		</Border>
		<!-- Header -->
		<Border Name="HeaderBorder" Grid.Row="1" Padding="16,10">
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>
				<Grid Grid.Row="0">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="*" MinWidth="120"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<TextBlock Name="TitleText" Grid.Column="0"
						FontSize="18" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,12,0"
						TextTrimming="CharacterEllipsis"/>
					<Button Name="BtnStartHere" Grid.Column="2" Content=""
						FontSize="11" Margin="0,0,8,0" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
					<Button Name="BtnHelp" Grid.Column="3" Content=""
						FontSize="11" Margin="0,0,8,0" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
					<Button Name="BtnLog" Grid.Column="4" Content=""
						FontSize="11" Margin="0,0,8,0" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
					<StackPanel Grid.Column="5" Orientation="Horizontal" Margin="0,0,8,0" VerticalAlignment="Center" Visibility="Collapsed">
						<TextBlock Text="" VerticalAlignment="Center" Margin="0,0,6,0"
							Name="ScanLabel" FontSize="11"/>
						<CheckBox Name="ChkScan" VerticalAlignment="Center"/>
					</StackPanel>
					<!-- Separator between actions and state toggles -->
					<Border Name="HeaderSeparator" Grid.Column="6" Width="1" Height="28"
						Margin="4,0,10,0" VerticalAlignment="Center" Opacity="0.4"/>
					<StackPanel Grid.Column="7" Orientation="Vertical" Margin="0,0,12,0" VerticalAlignment="Center">
						<StackPanel Orientation="Horizontal">
							<CheckBox Name="ChkSafeMode" VerticalAlignment="Center" Content="" Margin="0,0,10,0"/>
							<CheckBox Name="ChkGameMode" Visibility="Collapsed"/>
						</StackPanel>
						<TextBlock Name="TxtAdvancedModeState" Margin="2,4,0,0" FontSize="10" Text="" ToolTip=""/>
					</StackPanel>
					<StackPanel Grid.Column="8" Orientation="Vertical" VerticalAlignment="Center" Margin="0,0,12,0">
						<CheckBox Name="ChkTheme" VerticalAlignment="Center" Content=""/>
						<TextBlock Name="TxtThemeState" Margin="2,4,0,0" FontSize="10" Text="" ToolTip=""/>
					</StackPanel>
					<StackPanel Grid.Column="9" Orientation="Vertical" VerticalAlignment="Center" Margin="0,0,4,0">
						<ToggleButton Name="BtnLanguage" Padding="8,4" Cursor="Hand" VerticalAlignment="Center" ToolTip="" Content=""/>
						<Popup Name="LanguagePopup" StaysOpen="False" Placement="Bottom" PlacementTarget="{Binding ElementName=BtnLanguage}" AllowsTransparency="True" IsOpen="{Binding IsChecked, ElementName=BtnLanguage, Mode=TwoWay}">
							<Border Name="LanguagePopupBorder" BorderThickness="1" CornerRadius="6" Padding="6">
								<StackPanel Width="208">
									<Grid Margin="0,0,0,6">
										<TextBox Name="TxtLanguageSearch" Height="28" Padding="10,4" VerticalContentAlignment="Center" ToolTip=""/>
										<TextBlock Name="TxtLanguageSearchPlaceholder" Text=""
											Margin="12,0,28,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
									</Grid>
									<ScrollViewer VerticalScrollBarVisibility="Auto" MaxHeight="320">
										<StackPanel Name="LanguageListPanel"/>
									</ScrollViewer>
								</StackPanel>
							</Border>
						</Popup>
						<TextBlock Name="TxtLanguageState" Margin="2,4,0,0" FontSize="10" Text="" ToolTip=""/>
					</StackPanel>
				</Grid>
				<Grid Grid.Row="1" Margin="0,10,0,0">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="Auto"/>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<TextBlock Name="SearchLabel" Grid.Column="0" Text="" Margin="0,0,10,0" VerticalAlignment="Center" FontSize="11"/>
					<Grid Grid.Column="1" Margin="0,0,8,0">
						<TextBox Name="TxtSearch" Height="30" Padding="10,4" VerticalContentAlignment="Center"/>
						<TextBlock Name="TxtSearchPlaceholder" Text=""
							Margin="12,0,36,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
					</Grid>
					<Button Name="BtnClearSearch" Grid.Column="2" Content="" FontSize="11" Padding="12,4" Cursor="Hand" Height="30"/>
				</Grid>
				<StackPanel Grid.Row="2" Margin="0,8,0,0" Orientation="Vertical">
					<StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,8">
						<RadioButton Name="NavModeTweaks" Content="" IsChecked="True" FontSize="11" Margin="0,0,10,0" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
						<RadioButton Name="NavModeApps" Content="" FontSize="11" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
					</StackPanel>
					<Button Name="BtnFilterToggle" Content="" HorizontalAlignment="Left"
						FontSize="11" Padding="8,3" Cursor="Hand" Background="Transparent" BorderThickness="0"/>
					<WrapPanel Name="FilterOptionsPanel" Margin="0,6,0,0" Orientation="Horizontal" VerticalAlignment="Center" Visibility="Collapsed">
						<TextBlock Name="RiskFilterLabel" Text="" Margin="0,0,10,0" VerticalAlignment="Center" FontSize="11"/>
						<ComboBox Name="CmbRiskFilter" Width="138" Height="30" Margin="0,0,16,0" VerticalContentAlignment="Center"/>
						<TextBlock Name="CategoryFilterLabel" Text="" Margin="0,0,10,0" VerticalAlignment="Center" FontSize="11"/>
						<ComboBox Name="CmbCategoryFilter" Width="220" Height="30" Margin="0,0,16,0" VerticalContentAlignment="Center"/>
						<TextBlock Name="ViewFilterLabel" Text="" Margin="0,0,10,0" VerticalAlignment="Center" FontSize="11"/>
						<CheckBox Name="ChkSelectedOnly" Content="" Margin="0,0,14,0" VerticalAlignment="Center" FontSize="11" ToolTip=""/>
						<CheckBox Name="ChkHighRiskOnly" Content="" Margin="0,0,14,0" VerticalAlignment="Center" FontSize="11" ToolTip=""/>
						<CheckBox Name="ChkRestorableOnly" Content="" Margin="0,0,14,0" VerticalAlignment="Center" FontSize="11" ToolTip=""/>
						<CheckBox Name="ChkGamingOnly" Content="" VerticalAlignment="Center" FontSize="11" ToolTip=""/>
					</WrapPanel>
				</StackPanel>
			</Grid>
		</Border>
		<!-- Primary tab bar -->
			<Grid Name="PrimaryTabHost" Grid.Row="2" Margin="8,4,8,0">
				<!-- Primary tab row -->
				<TabControl Name="PrimaryTabs" Padding="0">
					<TabControl.Template>
						<ControlTemplate TargetType="TabControl">
							<ScrollViewer Name="PrimaryTabHeaderScroll"
								HorizontalScrollBarVisibility="Auto"
								VerticalScrollBarVisibility="Disabled"
								CanContentScroll="False"
								Focusable="False">
								<StackPanel Name="HeaderPanel"
									Orientation="Horizontal"
									IsItemsHost="True"/>
							</ScrollViewer>
						</ControlTemplate>
					</TabControl.Template>
					<TabControl.Resources>
						<Style TargetType="TabItem">
						<Setter Property="Template">
							<Setter.Value>
								<ControlTemplate TargetType="TabItem">
									<Border Background="{TemplateBinding Background}"
											BorderBrush="{TemplateBinding BorderBrush}"
											BorderThickness="{TemplateBinding BorderThickness}"
											Padding="{TemplateBinding Padding}"
											Margin="1,0"
											SnapsToDevicePixels="True"
											Cursor="Hand">
										<ContentPresenter
											ContentSource="Header"
											HorizontalAlignment="Center"
											VerticalAlignment="Center"
											TextBlock.Foreground="{TemplateBinding Foreground}"
											TextBlock.FontWeight="{TemplateBinding FontWeight}"/>
									</Border>
								</ControlTemplate>
							</Setter.Value>
						</Setter>
						</Style>
					</TabControl.Resources>
				</TabControl>
				<!-- Legacy narrow-mode picker kept hidden; the desktop UI stays on a fixed tab row. -->
				<ComboBox Name="PrimaryTabDropdown" Visibility="Collapsed"
					HorizontalAlignment="Left" Width="280" Height="32" MaxDropDownHeight="300"
					VerticalContentAlignment="Center" FontSize="13"/>
			</Grid>
		<!-- Expert Mode banner (visible only in Expert Mode) -->
		<Border Name="ExpertModeBanner" Grid.Row="3" Visibility="Collapsed" Padding="6,4" Margin="8,0,8,0">
			<TextBlock Text=""
				FontSize="10" FontWeight="SemiBold" HorizontalAlignment="Center"
				Padding="12,2"/>
		</Border>
		<!-- Content area (filled by tab selection) -->
		<Border Name="ContentBorder" Grid.Row="4" Margin="8,0,8,4">
			<Grid>
				<Grid Name="TweaksView" Visibility="Visible">
					<ScrollViewer Name="ContentScroll" VerticalScrollBarVisibility="Auto"
						HorizontalScrollBarVisibility="Disabled"/>
				</Grid>
				<Grid Name="AppsView" Visibility="Collapsed">
					<Grid.RowDefinitions>
						<RowDefinition Height="Auto"/>
						<RowDefinition Height="*"/>
					</Grid.RowDefinitions>
					<StackPanel Grid.Row="0" Orientation="Vertical" Margin="10">
						<StackPanel Orientation="Horizontal" Margin="0,0,0,8">
							<Button Name="BtnUpdateAllApps" Content="" Padding="10,5" Margin="0,0,12,0" Cursor="Hand"/>
							<TextBlock Name="TxtAppCacheStatus" VerticalAlignment="Center" Opacity="0.7" Text=""/>
							<TextBlock Name="AppsCategoryLabel" VerticalAlignment="Center" Margin="16,0,8,0" FontSize="11" Text=""/>
							<ComboBox Name="CmbAppsCategoryFilter" Width="220" Height="30" VerticalContentAlignment="Center"/>
							<StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
								<TextBlock Name="AppsSourceLabel" VerticalAlignment="Center" Margin="0,0,8,0" FontSize="11" Text=""/>
								<RadioButton Name="BtnAppsSourceWinGet" GroupName="AppsPackageSource" Content="" Margin="0,0,8,0" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
								<RadioButton Name="BtnAppsSourceChocolatey" GroupName="AppsPackageSource" Content="" Padding="10,4" Cursor="Hand" VerticalAlignment="Center"/>
							</StackPanel>
						</StackPanel>
						<Border Name="AppsPackageManagerBanner" Visibility="Collapsed" Margin="0,0,0,8" Padding="10,6" CornerRadius="6" BorderThickness="1">
							<TextBlock Name="TxtAppsPackageManagerBanner" VerticalAlignment="Center" TextWrapping="Wrap"/>
						</Border>
						<WrapPanel Orientation="Horizontal" Margin="0,0,0,8" VerticalAlignment="Center">
							<TextBlock Name="TxtAppSelectionStatus" VerticalAlignment="Center" Opacity="0.7" Margin="0,0,12,0" Text=""/>
							<Button Name="BtnInstallSelectedApps" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnUninstallSelectedApps" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnUpdateSelectedApps" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnApplyQueuedActions" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnClearQueuedActions" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnClearAppSelection" Content="" Padding="10,5" Margin="0,0,8,0" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
							<Button Name="BtnScanInstalledApps" Content="" Padding="10,5" Cursor="Hand" IsEnabled="False" ToolTipService.ShowOnDisabled="True"/>
						</WrapPanel>
						<Border Name="AppsProgressContainer" Height="10" Margin="0,0,0,6" CornerRadius="2" ClipToBounds="True"/>
						<TextBlock Name="TxtAppsProgressText" VerticalAlignment="Center" Opacity="0.7" Text=""/>
					</StackPanel>
					<ScrollViewer Name="AppsScroll" Grid.Row="1" VerticalScrollBarVisibility="Auto"
						HorizontalScrollBarVisibility="Disabled">
						<WrapPanel Name="AppsWrapPanel" Orientation="Horizontal" HorizontalAlignment="Left" Margin="10"/>
					</ScrollViewer>
				</Grid>
			</Grid>
		</Border>
		<!-- Bottom bar -->
		<Border Name="BottomBorder" Grid.Row="5" Padding="10,14,10,8" BorderThickness="0,1,0,0">
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>
				<Grid Grid.Row="0">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="*"/>
						<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<StackPanel Name="ActionButtonBar" Grid.Column="0"
						Orientation="Vertical" VerticalAlignment="Top" HorizontalAlignment="Left">
						<Button Name="BtnDefaults" Content=""
							FontSize="11" Margin="4,0,4,0" Padding="12,6" Cursor="Hand"/>
					</StackPanel>
					<WrapPanel Name="BottomActionBar" Grid.Column="1"
						Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top">
						<Button Name="BtnPreviewRun" Content=""
							FontFamily="FluentSystemIcons" FontSize="13" Margin="4" Padding="18,10" Cursor="Hand" FontWeight="SemiBold" MinWidth="160"/>
						<Button Name="BtnRun" Content=""
							FontFamily="FluentSystemIcons" FontSize="15" Margin="4" Padding="28,12" Cursor="Hand" FontWeight="Bold" MinWidth="170"/>
					</WrapPanel>
				</Grid>
		<Grid Grid.Row="1" Margin="0,10,0,0">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="Auto"/>
					</Grid.ColumnDefinitions>
					<TextBlock Name="StatusText" Grid.Column="0" VerticalAlignment="Center"
						FontSize="12" Margin="4,0,16,0" TextWrapping="Wrap" Visibility="Collapsed"/>
					<TextBlock Name="RunPathContextLabel" Grid.Column="1" HorizontalAlignment="Right"
						VerticalAlignment="Center" FontSize="11" Margin="4,0,8,0" Visibility="Collapsed"/>
				</Grid>
			</Grid>
		</Border>
		<Grid Name="UpdateDialogOverlay" Grid.RowSpan="6" Visibility="Collapsed" Background="#D8000000" Panel.ZIndex="1000">
			<Border Name="UpdateDialogCard" Background="#1E1E2E" BorderBrush="#44888888" BorderThickness="1" CornerRadius="8" Padding="24" Width="450" HorizontalAlignment="Center" VerticalAlignment="Center">
				<StackPanel>
					<TextBlock Name="TxtOverlayTitle" Text="" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"/>
					<TextBlock Name="TxtUpdateDescription" Text="" TextWrapping="Wrap" Opacity="0.8" Margin="0,0,0,20"/>
					<Border Name="CustomPBarContainer" Height="10" Margin="0,0,0,10" CornerRadius="2" ClipToBounds="True"/>
					<Grid Margin="0,0,0,25">
						<TextBlock Name="TxtDownloadProgressLabel" Text="" Opacity="0.6" HorizontalAlignment="Left" FontSize="11"/>
						<TextBlock Name="TxtDownloadProgressPct" Text="0%" Opacity="0.6" HorizontalAlignment="Right" FontSize="11"/>
					</Grid>
					<StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
						<Button Name="BtnDownloadNo" Content="" Width="90" Margin="0,0,10,0" Cursor="Hand"/>
						<Button Name="BtnDownloadYes" Content="" Width="130" Cursor="Hand"/>
					</StackPanel>
				</StackPanel>
			</Border>
		</Grid>
	</Grid>
</Grid>
</Border>
</Window>
"@
	#endregion XAML template

	$loadedForm = [System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XAML))

	if (-not ($loadedForm -is [System.Windows.Window]))
	{
		throw "XAML root did not load as System.Windows.Window. Actual type: $($loadedForm.GetType().FullName)"
	}

	[System.Windows.Window]$Form = $loadedForm
	$Script:MainForm = $Form

	try
	{
		$repoBasePath = Split-Path -Path $Script:GuiModuleBasePath -Parent
		$windowIconPath = Join-Path -Path $repoBasePath -ChildPath 'Assets\baseline.ico'
		if (-not [string]::IsNullOrWhiteSpace([string]$windowIconPath) -and (Test-Path -LiteralPath $windowIconPath -PathType Leaf))
		{
			$windowIconUri = [System.Uri]::new([System.IO.Path]::GetFullPath($windowIconPath), [System.UriKind]::Absolute)
			$windowIconSource = [System.Windows.Media.Imaging.BitmapFrame]::Create($windowIconUri)
			$Form.Icon = $windowIconSource
			$titleBarLogo = $Form.FindName('TitleBarLogo')
			if ($titleBarLogo)
			{
				$titleBarLogo.Source = $windowIconSource
			}
		}
	}
	catch
	{
		Write-GuiRuntimeWarning -Context 'WindowIcon' -Message $_.Exception.Message
	}

	# Size the window to 85% of the screen working area so it fits any resolution
	# without being full-screen. Falls back to safe defaults if the call fails.
	try
	{
		$workArea = [System.Windows.SystemParameters]::WorkArea
		$widthRatio = if ($workArea.Width -ge 2560) { 0.55 } elseif ($workArea.Width -ge 1920) { 0.65 } else { 0.85 }
		$targetW  = [Math]::Round($workArea.Width  * $widthRatio)
		$targetH  = [Math]::Round($workArea.Height * 0.85)
		$maxW = [Math]::Min(1400, $workArea.Width)

		# On small screens, clamp MinWidth to the available work area
		$effectiveMinW = [Math]::Min($guiWindowMinWidth, $workArea.Width)
		$effectiveMinH = [Math]::Min($guiWindowMinHeight, $workArea.Height)

		$Form.MinWidth  = $effectiveMinW
		$Form.MinHeight = $effectiveMinH
		$Form.Width  = [Math]::Min([Math]::Max($targetW, $effectiveMinW), $maxW)
		$Form.Height = [Math]::Min([Math]::Max($targetH, $effectiveMinH), $workArea.Height)
	}
	catch
	{
		$Form.MinWidth = $guiWindowMinWidth
		$Form.MinHeight = $guiWindowMinHeight
		$Form.Width  = [Math]::Max(940, $guiWindowMinWidth)
		$Form.Height = [Math]::Max(720, $guiWindowMinHeight)
	}
	$HeaderBorder    = $Form.FindName("HeaderBorder")
	$HeaderSeparator = $Form.FindName("HeaderSeparator")
	$TitleText       = $Form.FindName("TitleText")
	$WindowBorder  = $Form.FindName("RootBorder")
	$TitleBar      = $Form.FindName("TitleBar")
	$TitleBarText  = $Form.FindName("TitleBarText")
	$BtnMinimize   = $Form.FindName("BtnMinimize")
	$BtnMaximize   = $Form.FindName("BtnMaximize")
	$BtnClose      = $Form.FindName("BtnClose")

	# Wire custom title bar: drag, minimize, maximize, close
	if ($TitleBar)
	{
		$TitleBar.Add_MouseLeftButtonDown({
			if ($_.ClickCount -eq 2)
			{
				if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
				{
					$Form.WindowState = [System.Windows.WindowState]::Normal
				}
				else
				{
					$Form.WindowState = [System.Windows.WindowState]::Maximized
				}
			}
			else
			{
				$Form.DragMove()
			}
		})
	}
	# System-style right-click context menu for the custom title bar
	if ($TitleBar)
	{
		$sysMenu = New-Object System.Windows.Controls.ContextMenu
		$miRestore = New-Object System.Windows.Controls.MenuItem
		$miRestore.Header = 'Restore'
		$miRestore.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Normal })
		$miMove = New-Object System.Windows.Controls.MenuItem
		$miMove.Header = 'Move'
		$miMove.IsEnabled = $false
		$miSize = New-Object System.Windows.Controls.MenuItem
		$miSize.Header = 'Size'
		$miSize.IsEnabled = $false
		$miMinimize = New-Object System.Windows.Controls.MenuItem
		$miMinimize.Header = 'Minimize'
		$miMinimize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Minimized })
		$miMaximize = New-Object System.Windows.Controls.MenuItem
		$miMaximize.Header = 'Maximize'
		$miMaximize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Maximized })
		$sep = New-Object System.Windows.Controls.Separator
		$miClose = New-Object System.Windows.Controls.MenuItem
		$miClose.Header = 'Close'
		$miClose.InputGestureText = 'Alt+F4'
		$miClose.FontWeight = [System.Windows.FontWeights]::Bold
		$miClose.Add_Click({ $Form.Close() })
		[void]$sysMenu.Items.Add($miRestore)
		[void]$sysMenu.Items.Add($miMove)
		[void]$sysMenu.Items.Add($miSize)
		[void]$sysMenu.Items.Add($miMinimize)
		[void]$sysMenu.Items.Add($miMaximize)
		[void]$sysMenu.Items.Add($sep)
		[void]$sysMenu.Items.Add($miClose)
		$Script:TitleBarSystemMenu = $sysMenu
		$Script:TitleBarSystemMenuItems = @{ Restore = $miRestore; Minimize = $miMinimize; Maximize = $miMaximize; Move = $miMove; Size = $miSize }
		$sysMenu.Add_Opened({
			$isMax = $Form.WindowState -eq [System.Windows.WindowState]::Maximized
			$Script:TitleBarSystemMenuItems.Restore.IsEnabled = $isMax
			$Script:TitleBarSystemMenuItems.Maximize.IsEnabled = -not $isMax
			$Script:TitleBarSystemMenuItems.Move.IsEnabled = -not $isMax
			$Script:TitleBarSystemMenuItems.Size.IsEnabled = -not $isMax
		})
		$TitleBar.ContextMenu = $sysMenu
	}
	if ($BtnMinimize) { $BtnMinimize.Add_Click({ $Form.WindowState = [System.Windows.WindowState]::Minimized }) }
	if ($BtnMaximize)
	{
		$BtnMaximize.Add_Click({
			if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
			{
				$Form.WindowState = [System.Windows.WindowState]::Normal
			}
			else
			{
				$Form.WindowState = [System.Windows.WindowState]::Maximized
			}
		})
	}
	if ($BtnClose) { $BtnClose.Add_Click({ $Form.Close() }) }

	# Adjust border radius when maximized (no rounding needed when filling screen)
	$Form.Add_StateChanged({
		if ($Form.WindowState -eq [System.Windows.WindowState]::Maximized)
		{
			$WindowBorder.CornerRadius = [System.Windows.CornerRadius]::new(0)
			$WindowBorder.Margin = [System.Windows.Thickness]::new(7)
			if ($TitleBar) { $TitleBar.CornerRadius = [System.Windows.CornerRadius]::new(0) }
		}
		else
		{
			$WindowBorder.CornerRadius = [System.Windows.CornerRadius]::new(8)
			$WindowBorder.Margin = [System.Windows.Thickness]::new(0)
			if ($TitleBar) { $TitleBar.CornerRadius = [System.Windows.CornerRadius]::new(8, 8, 0, 0) }
		}
	})
	$PrimaryTabs   = $Form.FindName("PrimaryTabs")
	$PrimaryTabDropdown = $Form.FindName("PrimaryTabDropdown")
	$PrimaryTabHost = $Form.FindName("PrimaryTabHost")
	$ContentBorder = $Form.FindName("ContentBorder")
	$ContentScroll = $Form.FindName("ContentScroll")
	$ExpertModeBanner = $Form.FindName("ExpertModeBanner")
	$BottomBorder  = $Form.FindName("BottomBorder")
	$StatusText    = $Form.FindName("StatusText")
	$Script:StatusTextControl = $StatusText
	$ActionButtonBar = $Form.FindName("ActionButtonBar")
	$BtnPreviewRun = $Form.FindName("BtnPreviewRun")
	$BtnRun        = $Form.FindName("BtnRun")
	$Script:RunPathContextLabel = $Form.FindName("RunPathContextLabel")
	$BtnDefaults   = $Form.FindName("BtnDefaults")
	$BtnExportSettings = $null
	$BtnImportSettings = $null
	$BtnRestoreSnapshot = $null
	$ChkTheme      = $Form.FindName("ChkTheme")
	$BtnLanguage   = $Form.FindName("BtnLanguage")
	$LanguagePopup = $Form.FindName("LanguagePopup")
	$LanguagePopupBorder = $Form.FindName("LanguagePopupBorder")
	$TxtLanguageSearch = $Form.FindName("TxtLanguageSearch")
	$TxtLanguageSearchPlaceholder = $Form.FindName("TxtLanguageSearchPlaceholder")
	$LanguageListPanel = $Form.FindName("LanguageListPanel")
	$TxtLanguageState = $Form.FindName("TxtLanguageState")
	$ChkSafeMode   = $Form.FindName("ChkSafeMode")
	$ChkGameMode   = $Form.FindName("ChkGameMode")
	$TxtAdvancedModeState = $Form.FindName("TxtAdvancedModeState")
	$TxtThemeState = $Form.FindName("TxtThemeState")
	$BtnStartHere  = $Form.FindName("BtnStartHere")
	$BtnHelp       = $Form.FindName("BtnHelp")
	$BtnLog        = $Form.FindName("BtnLog")
	$ChkScan       = $Form.FindName("ChkScan")
	$ScanLabel     = $Form.FindName("ScanLabel")
	$SearchLabel   = $Form.FindName("SearchLabel")
	$TxtSearch     = $Form.FindName("TxtSearch")
	$TxtSearchPlaceholder = $Form.FindName("TxtSearchPlaceholder")
	$BtnClearSearch = $Form.FindName("BtnClearSearch")
	$RiskFilterLabel = $Form.FindName("RiskFilterLabel")
	$CategoryFilterLabel = $Form.FindName("CategoryFilterLabel")
	$ViewFilterLabel = $Form.FindName("ViewFilterLabel")
	$CmbRiskFilter = $Form.FindName("CmbRiskFilter")
	$CmbCategoryFilter = $Form.FindName("CmbCategoryFilter")
	$ChkSelectedOnly = $Form.FindName("ChkSelectedOnly")
	$ChkHighRiskOnly = $Form.FindName("ChkHighRiskOnly")
	$ChkRestorableOnly = $Form.FindName("ChkRestorableOnly")
	$ChkGamingOnly = $Form.FindName("ChkGamingOnly")
	$BtnFilterToggle = $Form.FindName("BtnFilterToggle")
	$FilterOptionsPanel = $Form.FindName("FilterOptionsPanel")
	$NavModeTweaks = $Form.FindName("NavModeTweaks")
	$NavModeApps = $Form.FindName("NavModeApps")
	$TweaksView = $Form.FindName("TweaksView")
	$AppsView = $Form.FindName("AppsView")
	$AppsScroll = $Form.FindName("AppsScroll")
	$AppsWrapPanel = $Form.FindName("AppsWrapPanel")
	$BtnUpdateAllApps = $Form.FindName("BtnUpdateAllApps")
	$TxtAppCacheStatus = $Form.FindName("TxtAppCacheStatus")
	$AppsPackageManagerBanner = $Form.FindName("AppsPackageManagerBanner")
	$TxtAppsPackageManagerBanner = $Form.FindName("TxtAppsPackageManagerBanner")
	$AppsCategoryLabel = $Form.FindName("AppsCategoryLabel")
	$AppsSourceLabel = $Form.FindName("AppsSourceLabel")
	$CmbAppsCategoryFilter = $Form.FindName("CmbAppsCategoryFilter")
	$TxtAppSelectionStatus = $Form.FindName("TxtAppSelectionStatus")
	$BtnInstallSelectedApps = $Form.FindName("BtnInstallSelectedApps")
	$BtnUninstallSelectedApps = $Form.FindName("BtnUninstallSelectedApps")
	$BtnUpdateSelectedApps = $Form.FindName("BtnUpdateSelectedApps")
	$BtnApplyQueuedActions = $Form.FindName("BtnApplyQueuedActions")
	$BtnClearQueuedActions = $Form.FindName("BtnClearQueuedActions")
	$BtnClearAppSelection = $Form.FindName("BtnClearAppSelection")
	$BtnScanInstalledApps = $Form.FindName("BtnScanInstalledApps")
	$BtnAppsSourceWinGet = $Form.FindName("BtnAppsSourceWinGet")
	$BtnAppsSourceChocolatey = $Form.FindName("BtnAppsSourceChocolatey")
	$AppsProgressContainer = $Form.FindName("AppsProgressContainer")
	$TxtAppsProgressText = $Form.FindName("TxtAppsProgressText")
	$UpdateDialogOverlay = $Form.FindName("UpdateDialogOverlay")
	$UpdateDialogCard = $Form.FindName("UpdateDialogCard")
	$TxtOverlayTitle = $Form.FindName("TxtOverlayTitle")
	$TxtUpdateDescription = $Form.FindName("TxtUpdateDescription")
	$CustomPBarContainer = $Form.FindName("CustomPBarContainer")
	$TxtDownloadProgressLabel = $Form.FindName("TxtDownloadProgressLabel")
	$TxtDownloadProgressPct = $Form.FindName("TxtDownloadProgressPct")
	$BtnDownloadNo = $Form.FindName("BtnDownloadNo")
	$BtnDownloadYes = $Form.FindName("BtnDownloadYes")

	# --- Top Menu Bar controls ---
	$MenuBarBorder              = $Form.FindName("MenuBarBorder")
	$MainMenuBar                = $Form.FindName("MainMenuBar")
	$MenuFile                   = $Form.FindName("MenuFile")
	$MenuFileImportSettings     = $Form.FindName("MenuFileImportSettings")
	$MenuFileExportSettings     = $Form.FindName("MenuFileExportSettings")
	$MenuFileAuditSettings      = $Form.FindName("MenuFileAuditSettings")
	$MenuFileExportConfigProfile = $Form.FindName("MenuFileExportConfigProfile")
	$MenuFileExportSystemState  = $Form.FindName("MenuFileExportSystemState")
	$MenuFileExit               = $Form.FindName("MenuFileExit")
	$MenuActions                = $Form.FindName("MenuActions")
	$MenuActionsConnectToComputer = $Form.FindName("MenuActionsConnectToComputer")
	$MenuActionsDisconnect      = $Form.FindName("MenuActionsDisconnect")
	$MenuActionsPreviewRun      = $Form.FindName("MenuActionsPreviewRun")
	$MenuActionsRunTweaks       = $Form.FindName("MenuActionsRunTweaks")
	$MenuActionsUndoLastRun     = $Form.FindName("MenuActionsUndoLastRun")
	$MenuActionsRestoreDefaults = $Form.FindName("MenuActionsRestoreDefaults")
	$MenuActionsCheckCompliance = $Form.FindName("MenuActionsCheckCompliance")
	$MenuActionsScanSystem      = $Form.FindName("MenuActionsScanSystem")
	$MenuActionsAuditLog        = $Form.FindName("MenuActionsAuditLog")
	$MenuView                   = $Form.FindName("MenuView")
	$MenuViewSafeMode           = $Form.FindName("MenuViewSafeMode")
	$MenuViewFilters            = $Form.FindName("MenuViewFilters")
	$MenuViewLogsPanel          = $Form.FindName("MenuViewLogsPanel")
	$MenuViewTheme              = $Form.FindName("MenuViewTheme")
	$MenuTools                  = $Form.FindName("MenuTools")
	$MenuToolsAppsManager       = $Form.FindName("MenuToolsAppsManager")
	$MenuToolsUpdateAllApps     = $Form.FindName("MenuToolsUpdateAllApps")
	$MenuToolsExportSupportBundle = $Form.FindName("MenuToolsExportSupportBundle")
	$MenuToolsApproveRemoteTargets = $Form.FindName("MenuToolsApproveRemoteTargets")
	$MenuToolsSaveRemoteApprovalPolicy = $Form.FindName("MenuToolsSaveRemoteApprovalPolicy")
	$MenuToolsLoadRemoteApprovalPolicy = $Form.FindName("MenuToolsLoadRemoteApprovalPolicy")
	$MenuToolsRemoteConsole = $Form.FindName("MenuToolsRemoteConsole")
	$MenuToolsOperatorConsole = $Form.FindName("MenuToolsOperatorConsole")
	$MenuToolsRemoteSessionStatus = $Form.FindName("MenuToolsRemoteSessionStatus")
	$MenuHelp                   = $Form.FindName("MenuHelp")
	$MenuHelpStartGuide         = $Form.FindName("MenuHelpStartGuide")
	$MenuHelpReadme             = $Form.FindName("MenuHelpReadme")
	$MenuHelpFAQ                = $Form.FindName("MenuHelpFAQ")
	$MenuHelpChangelog          = $Form.FindName("MenuHelpChangelog")
	$MenuHelpCheckForUpdate     = $Form.FindName("MenuHelpCheckForUpdate")
	$MenuHelpReleaseStatus      = $Form.FindName("MenuHelpReleaseStatus")
	$MenuHelpTroubleshooting    = $Form.FindName("MenuHelpTroubleshooting")
	$MenuHelpAbout              = $Form.FindName("MenuHelpAbout")

	$Script:WindowBorder                 = $WindowBorder
	$Script:MenuBarBorder                = $MenuBarBorder
	$Script:MainMenuBar                  = $MainMenuBar
	$Script:MenuFile                     = $MenuFile
	$Script:MenuActions                  = $MenuActions
	$Script:MenuActionsConnectToComputer = $MenuActionsConnectToComputer
	$Script:MenuActionsDisconnect        = $MenuActionsDisconnect
	$Script:MenuView                     = $MenuView
	$Script:MenuTools                    = $MenuTools
	$Script:MenuHelp                     = $MenuHelp
	$Script:MenuViewSafeMode             = $MenuViewSafeMode
	$Script:MenuViewFilters              = $MenuViewFilters
	$Script:MenuViewTheme                = $MenuViewTheme
	$Script:MenuActionsCheckCompliance   = $MenuActionsCheckCompliance
	$Script:MenuActionsScanSystem        = $MenuActionsScanSystem
	$Script:MenuActionsAuditLog          = $MenuActionsAuditLog
	$Script:MenuViewLogsPanel            = $MenuViewLogsPanel
	$Script:MenuHelpChangelog            = $MenuHelpChangelog
	$Script:MenuHelpCheckForUpdate       = $MenuHelpCheckForUpdate
	$Script:MenuActionsUndoLastRun       = $MenuActionsUndoLastRun
	$Script:MenuActionsRestoreDefaults   = $MenuActionsRestoreDefaults
	$Script:MenuActionsPreviewRun        = $MenuActionsPreviewRun
	$Script:MenuActionsRunTweaks         = $MenuActionsRunTweaks
	$Script:MenuFileExportSettings       = $MenuFileExportSettings
	$Script:MenuFileImportSettings       = $MenuFileImportSettings
	$Script:MenuFileAuditSettings        = $MenuFileAuditSettings
	$Script:MenuFileExportConfigProfile  = $MenuFileExportConfigProfile
	$Script:MenuFileExportSystemState    = $MenuFileExportSystemState
	$Script:MenuToolsAppsManager         = $MenuToolsAppsManager
	$Script:MenuToolsUpdateAllApps       = $MenuToolsUpdateAllApps
	$Script:MenuToolsExportSupportBundle = $MenuToolsExportSupportBundle
	$Script:MenuToolsApproveRemoteTargets = $MenuToolsApproveRemoteTargets
	$Script:MenuToolsSaveRemoteApprovalPolicy = $MenuToolsSaveRemoteApprovalPolicy
	$Script:MenuToolsLoadRemoteApprovalPolicy = $MenuToolsLoadRemoteApprovalPolicy
	$Script:MenuToolsRemoteConsole = $MenuToolsRemoteConsole
	$Script:MenuToolsOperatorConsole = $MenuToolsOperatorConsole
	$Script:MenuToolsRemoteSessionStatus = $MenuToolsRemoteSessionStatus
	$Script:MenuHelpStartGuide           = $MenuHelpStartGuide
	$Script:MenuHelpReadme               = $MenuHelpReadme
	$Script:MenuHelpFAQ                  = $MenuHelpFAQ
	$Script:MenuHelpReleaseStatus        = $MenuHelpReleaseStatus
	$Script:MenuHelpTroubleshooting      = $MenuHelpTroubleshooting
	$Script:MenuHelpAbout                = $MenuHelpAbout

	$Script:PrimaryTabHost = $PrimaryTabHost
	$Script:ExpertModeBanner = $ExpertModeBanner
	$Script:SearchLabel = $SearchLabel
	$Script:TxtSearch = $TxtSearch
	$Script:TxtSearchPlaceholder = $TxtSearchPlaceholder
	$Script:BtnClearSearch = $BtnClearSearch
	$Script:BtnFilterToggle = $BtnFilterToggle
	$Script:FilterOptionsPanel = $FilterOptionsPanel
	$Script:RiskFilterLabel = $RiskFilterLabel
	$Script:CategoryFilterLabel = $CategoryFilterLabel
	$Script:ViewFilterLabel = $ViewFilterLabel
	$Script:ChkSelectedOnly = $ChkSelectedOnly
	$Script:ChkHighRiskOnly = $ChkHighRiskOnly
	$Script:ChkRestorableOnly = $ChkRestorableOnly
	$Script:ChkGamingOnly = $ChkGamingOnly
	$Script:BtnPreviewRun = $BtnPreviewRun
	$Script:BtnRun = $BtnRun
	$Script:BtnDefaults = $BtnDefaults
	$Script:BtnStartHere = $BtnStartHere
	$Script:BtnHelp = $BtnHelp
	$Script:NavModeTweaks = $NavModeTweaks
	$Script:NavModeApps = $NavModeApps
	$Script:TweaksView = $TweaksView
	$Script:AppsView = $AppsView
	$Script:AppsScroll = $AppsScroll
	$Script:AppsWrapPanel = $AppsWrapPanel
	$Script:BtnUpdateAllApps = $BtnUpdateAllApps
	$Script:TxtAppCacheStatus = $TxtAppCacheStatus
	$Script:AppsPackageManagerBanner = $AppsPackageManagerBanner
	$Script:TxtAppsPackageManagerBanner = $TxtAppsPackageManagerBanner
	$Script:AppsCategoryLabel = $AppsCategoryLabel
	$Script:AppsSourceLabel = $AppsSourceLabel
	$Script:CmbAppsCategoryFilter = $CmbAppsCategoryFilter
	$Script:TxtAppSelectionStatus = $TxtAppSelectionStatus
	$Script:BtnInstallSelectedApps = $BtnInstallSelectedApps
	$Script:BtnUninstallSelectedApps = $BtnUninstallSelectedApps
	$Script:BtnUpdateSelectedApps = $BtnUpdateSelectedApps
	$Script:BtnApplyQueuedActions = $BtnApplyQueuedActions
	$Script:BtnClearQueuedActions = $BtnClearQueuedActions
	$Script:BtnClearAppSelection = $BtnClearAppSelection
	$Script:BtnScanInstalledApps = $BtnScanInstalledApps
	$Script:BtnAppsSourceWinGet = $BtnAppsSourceWinGet
	$Script:BtnAppsSourceChocolatey = $BtnAppsSourceChocolatey
	$Script:AppsProgressContainer = $AppsProgressContainer
	$Script:TxtAppsProgressText = $TxtAppsProgressText
	$Script:UpdateDialogOverlay = $UpdateDialogOverlay
	$Script:UpdateDialogCard = $UpdateDialogCard
	$Script:TxtOverlayTitle = $TxtOverlayTitle
	$Script:TxtUpdateDescription = $TxtUpdateDescription
	$Script:CustomPBarContainer = $CustomPBarContainer
	$Script:TxtDownloadProgressLabel = $TxtDownloadProgressLabel
	$Script:TxtDownloadProgressPct = $TxtDownloadProgressPct
	$Script:BtnDownloadNo = $BtnDownloadNo
	$Script:BtnDownloadYes = $BtnDownloadYes
	$Script:ExecutionLogBox = $null
	$Script:ExecutionPreviousContent = $null
	$Script:ExecutionLastConsoleAction = $null
	$Script:ExecutionProgressHost = $null
	$Script:ExecutionProgressBar = $null
	$Script:ExecutionProgressText = $null
	$Script:ExecutionProgressIndeterminate = $false
	$Script:ExecutionSubProgressBar = $null
	$Script:ExecutionSubProgressText = $null
	$Script:AbortRunButton = $null
	$Script:AbortRequested = $false
	$Script:ExecutionWorker = $null
	$Script:ExecutionRunspace = $null
	$Script:ExecutionRunPowerShell = $null
		$Script:ExecutionRunTimer = $null
		$Script:RunAbortDisposition = $null
		$Script:ExecutionMode = $null
		$Script:SuppressRunClosePrompt = $false
		$Script:ForceCloseCompleted = $false
		$Script:ExecutionTimerErrorShown = $false
	$Script:AbortDialogShowing = $false
	$Script:BgPS = $null
	$Script:BgAsync = $null
	$Script:BaselineApplicationsCatalog = $null
	$Script:InstalledAppsCache = [pscustomobject]@{
		WinGet = @{}
		Chocolatey = @{}
		WinGetUpdates = @{}
		ChocolateyUpdates = @{}
	}
	$Script:AppsModeActive = $false
	$Script:AppsViewLoaded = $false
	$Script:AppsViewDirty = $false
	$Script:AppsViewBuildSignature = $null
	$Script:AppsCacheRefreshInProgress = $false
	$Script:AppsOperationInProgress = $false
	$Script:AppsCategoryFilter = 'All'
	$Script:AppsFilterUiUpdating = $false
	$Script:AppsProgressHost = $null
	$Script:AppsProgressBar = $null
	$Script:AppsActionButtons = [System.Collections.Generic.List[object]]::new()
	$Script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
	$Script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
	$Script:AppsQueuedActionControls = [System.Collections.Generic.List[object]]::new()
	$Script:AppsQueuedActionControlMap = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$Script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$Script:AppsSelectionUiUpdating = $false
	$Script:AppsQueuedActionUiUpdating = $false
	$Script:AppActionStates = @{}
	foreach ($bulkButton in @($BtnInstallSelectedApps, $BtnUninstallSelectedApps, $BtnUpdateSelectedApps, $BtnApplyQueuedActions, $BtnClearQueuedActions, $BtnClearAppSelection, $BtnScanInstalledApps))
	{
		if ($bulkButton)
		{
			[void]$Script:AppsBulkActionButtons.Add($bulkButton)
		}
	}
	$Script:DownloadStartEvent = $null
	$Script:DownloadExtractEvent = $null
	Initialize-AppsProgressSection
	Initialize-BaselineUpdateOverlay
	$Script:SearchText = ''
	$Script:AppsSearchText = ''
	$Script:AppsPackageSourcePreference = 'winget'
	$Script:SearchResultsTabTag = '__SEARCH_RESULTS__'
	$Script:LastStandardPrimaryTab = $null
	$Script:TabScrollOffsets = @{}
	$Script:TabContentCache = @{}
	$Script:CategoryFilterListCache = @{}
	$Script:LastCategoryFilterPopulateKey = $null
	$Script:FilterGeneration = 0
	$Script:SearchRefreshTimer = $null
	$Script:SearchUiUpdating = $false
	$Script:AppsSourceUiUpdating = $false
	$Script:SearchRefreshDelayMs = $Script:GuiLayout.SearchRefreshDelayMs
	$Script:CurrentThemeName = 'Dark'
	$Script:UiSnapshotUndo = $null
	$Script:PresetStatusMessage = $null
	$Script:PresetStatusTone = 'info'
	$Script:PresetStatusBadge = $null
	$Script:PresetProgressHost = $null
	$Script:PresetProgressBar = $null
	$Script:EnvironmentRecommendationData = $null
	$Script:EnvironmentSummaryText = $null
	$Script:SecondaryActionGroupBorder = $null
	$previousGuiUnhandledExceptionHooked = [bool]$Script:GuiUnhandledExceptionHooked
	$previousGuiUnhandledExceptionHandler = $Script:GuiUnhandledExceptionHandler
	$previousGuiDispatcher = if ($Script:MainForm -and $Script:MainForm.Dispatcher)
	{
		$Script:MainForm.Dispatcher
	}
	elseif ($Form -and $Form.Dispatcher)
	{
		$Form.Dispatcher
	}
	else
	{
		$null
	}

	if ($previousGuiUnhandledExceptionHooked -and $previousGuiUnhandledExceptionHandler -and $previousGuiDispatcher)
	{
		try
		{
			$previousGuiDispatcher.remove_UnhandledException($previousGuiUnhandledExceptionHandler)
		}
		catch
		{
			$null = $_
		}
	}

	$Script:GuiUnhandledExceptionHooked = $false
	$Script:GuiUnhandledExceptionHandler = $null
	$Script:ExplicitPresetSelections = [System.Collections.Generic.HashSet[string]]::new(
		[System.StringComparer]::OrdinalIgnoreCase
	)
	$Script:ExplicitPresetSelectionDefinitions = @{}

	$Script:GuiDispatcherHandlingError = $false
	if (-not $Script:GuiUnhandledExceptionHooked -and $Form -and $Form.Dispatcher)
	{
		$Script:GuiUnhandledExceptionHandler = [System.Windows.Threading.DispatcherUnhandledExceptionEventHandler]{
			param($unusedSender, $e)

			if ($Script:GuiDispatcherHandlingError)
			{
				$e.Handled = $true
				return
			}
			$Script:GuiDispatcherHandlingError = $true

			$isFatal = $false
			try
			{
				$showGuiRuntimeFailureScript = $Script:ShowGuiRuntimeFailureScript
				if ($showGuiRuntimeFailureScript)
				{
					$null = & $showGuiRuntimeFailureScript -Context 'WPF Dispatcher' -Exception $e.Exception -ShowDialog
				}
				else
				{
					Write-Warning ("GUI event failed [WPF Dispatcher]: {0}" -f $e.Exception.Message)
				}

				# Treat critical .NET exceptions as fatal - do not suppress them
				$ex = $e.Exception
				$isFatal = $ex -is [System.StackOverflowException] -or
					$ex -is [System.OutOfMemoryException] -or
					$ex -is [System.AccessViolationException] -or
					$ex -is [System.InvalidProgramException]
			}
			catch
			{
				# If our own handler fails, the original exception must not be swallowed
				$isFatal = $true
			}
			finally
			{
				$Script:GuiDispatcherHandlingError = $false
			}

			$e.Handled = -not $isFatal
		}

		try
		{
			$Form.Dispatcher.add_UnhandledException($Script:GuiUnhandledExceptionHandler)
			$Script:GuiUnhandledExceptionHooked = $true
		}
		catch
		{
			$null = $_
		}
	}
	$Script:RiskFilter = 'All'
	$Script:CategoryFilter = 'All'
	$Script:CategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:AppsCategoryFilterInternalValues = [System.Collections.Generic.List[string]]::new()
	$Script:SelectedOnlyFilter = $false
	$Script:HighRiskOnlyFilter = $false
	$Script:RestorableOnlyFilter = $false
	$Script:GamingOnlyFilter = $false
	$Script:SafeMode = $true
	$Script:AdvancedMode = $false

	# Auto-detect language from system UI culture. Session restore may override this.
	$Script:SelectedLanguage = $null
	$cultureToFileMap = @{ 'zh-cn' = 'zh-Hans'; 'zh-sg' = 'zh-Hans'; 'zh-tw' = 'zh-Hant'; 'zh-hk' = 'zh-Hant'; 'zh-mo' = 'zh-Hant' }
	$uiCultureLower = $PSUICulture.ToLower()
	$autoLangCandidates = @()
	if ($cultureToFileMap.ContainsKey($uiCultureLower)) { $autoLangCandidates += $cultureToFileMap[$uiCultureLower] }
	$autoLangCandidates += @($uiCultureLower, ($PSUICulture -split '-')[0].ToLower())
	$locDirInit = $Script:GuiLocalizationDirectoryPath
	foreach ($candidate in $autoLangCandidates)
	{
		if (-not [string]::IsNullOrWhiteSpace([string]$locDirInit))
		{
			try
			{
				$null = Resolve-BaselineLocalizationFile -BaseDirectory $locDirInit -FileName "$candidate.json"
				$Script:SelectedLanguage = $candidate
				break
			}
			catch { $null = $_ }
		}
	}
	if (-not $Script:SelectedLanguage) { $Script:SelectedLanguage = 'en' }
	Initialize-GameModeState
	$Script:FilterUiUpdating = $false
	$Script:ExecutionSummaryRecords = @()
	$Script:ExecutionSummaryLookup = @{}
	$Script:ExecutionCurrentSummaryKey = $null
	$Script:GuiDisplayVersion = Get-BaselineDisplayVersion

		# Keep the native window title concise; version details live in Help.
		$headerTitle = $Form.Title
		try
		{
			$windowTitle = (Get-UxLocalizedString -Key 'GuiMainWindowTitleFormat' -Fallback 'Baseline | Utility for {0}' -FormatArgs @((Get-OSInfo).OSName))
			$Form.Title = $windowTitle
			if ($TitleBarText) { $TitleBarText.Text = $windowTitle }
			$headerTitle = $windowTitle
		}
		catch { Write-GuiRuntimeWarning -Context 'WindowTitle' -Message $_.Exception.Message }
		$TitleText.Text = $headerTitle


	#region Helper: Apply theme
		<#
		    .SYNOPSIS
		    Internal function Set-GUITheme.

		    .DESCRIPTION
		    Internal implementation helper used by Baseline.
		#>

		function Set-GUITheme
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
			param ([hashtable]$Theme)
			$themeRepairName = 'Dark'
			if ($Theme -eq $Script:LightTheme)
			{
				$Script:CurrentThemeName = 'Light'
				$themeRepairName = 'Light'
			}
			elseif ($Theme -eq $Script:DarkTheme)
			{
				$Script:CurrentThemeName = 'Dark'
				$themeRepairName = 'Dark'
			}
			else
			{
				$Script:CurrentThemeName = 'Custom'
			}
			$Theme = Repair-GuiThemePalette -Theme $Theme -ThemeName $themeRepairName
			$Script:CurrentTheme = $Theme
			$Script:BrushCache = @{}
			$Script:SharedCardShadow = $null
			$Script:CardHoverResources = $null
			$bc = New-SafeBrushConverter -Context 'Set-GUITheme'

		$Form.Foreground  = $bc.ConvertFromString($Theme.TextPrimary)
		[void](GUICommon\Set-GuiWindowChromeTheme -Window $Form -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))
		[void](GUICommon\Update-GuiPopupWindowThemes -Theme $Theme -UseDarkMode ($Script:CurrentThemeName -eq 'Dark'))
		if ($WindowBorder) { $WindowBorder.Background = $bc.ConvertFromString($Theme.WindowBg); $WindowBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor) }
		if ($TitleBar) { $TitleBar.Background = $bc.ConvertFromString($Theme.HeaderBg) }
		if ($TitleBarText) { $TitleBarText.Foreground = $bc.ConvertFromString($Theme.TextPrimary) }
		if ($BtnMinimize) { Set-WindowCaptionButtonStyle -Button $BtnMinimize }
		if ($BtnMaximize) { Set-WindowCaptionButtonStyle -Button $BtnMaximize }
		if ($BtnClose) { Set-WindowCaptionButtonStyle -Button $BtnClose -Variant 'Close' }
		if ($Script:NavModeTweaks) { Set-ButtonChrome -Button $Script:NavModeTweaks -Variant 'Subtle' -Compact -Muted }
		if ($Script:NavModeApps) { Set-ButtonChrome -Button $Script:NavModeApps -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnUpdateAllApps) { Set-ButtonChrome -Button $Script:BtnUpdateAllApps -Variant 'Primary' -Compact }
		if ($Script:BtnDownloadYes) { Set-ButtonChrome -Button $Script:BtnDownloadYes -Variant 'Primary' }
		if ($Script:BtnDownloadNo) { Set-ButtonChrome -Button $Script:BtnDownloadNo -Variant 'Secondary' }
		$HeaderBorder.Background = $bc.ConvertFromString($Theme.HeaderBg)
		if ($HeaderSeparator) { $HeaderSeparator.Background = $bc.ConvertFromString($Theme.BorderColor) }
		$ContentBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		if ($Script:ExpertModeBanner)
		{
			$Script:ExpertModeBanner.Background = $bc.ConvertFromString($Theme.CautionBg)
			$bannerText = $Script:ExpertModeBanner.Child
			if ($bannerText) { $bannerText.Foreground = $bc.ConvertFromString($Theme.CautionText) }
		}
		$BottomBorder.Background = $bc.ConvertFromString($Theme.PanelBg)
		$BottomBorder.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		$TitleText.Foreground = $bc.ConvertFromString($Theme.TextPrimary)
		$ScanLabel.Foreground = $bc.ConvertFromString($Theme.TextSecondary)
		$currentStatusText = ''
		if ($Script:GuiState)
		{
			try { $currentStatusText = [string](& $Script:GuiState.Get 'StatusText') } catch { $currentStatusText = '' }
		}
		elseif ($StatusText)
		{
			$currentStatusText = [string]$StatusText.Text
		}
		Set-GuiStatusText -Text $currentStatusText -Tone $(if ($Script:CurrentStatusTone) { [string]$Script:CurrentStatusTone } else { 'muted' })
		Set-HeaderToggleControlsStyle
		if ($Script:UpdateDialogCard)
		{
			$Script:UpdateDialogCard.Background = $bc.ConvertFromString($Theme.CardBg)
			$Script:UpdateDialogCard.BorderBrush = $bc.ConvertFromString($Theme.BorderColor)
		}
		if ($Script:CustomPBarContainer) { $Script:CustomPBarContainer.Background = $bc.ConvertFromString($Theme.CardBorder) }
		if ($Script:AppsProgressContainer) { $Script:AppsProgressContainer.Background = $bc.ConvertFromString($Theme.CardBorder) }
		foreach ($progressBar in @($Script:CustomProgressBar, $Script:ExecutionProgressBar, $Script:AppsProgressBar, $Script:PresetProgressBar))
		{
			if ($progressBar)
			{
				Set-SheenProgressBarTheme -ProgressBar $progressBar -Theme $Theme
			}
		}
		if ($Script:TxtAppCacheStatus) { $Script:TxtAppCacheStatus.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:AppsPackageManagerBanner)
		{
			$Script:AppsPackageManagerBanner.Background = $bc.ConvertFromString($Theme.CautionBg)
			$Script:AppsPackageManagerBanner.BorderBrush = $bc.ConvertFromString($Theme.CautionBorder)
		}
		if ($Script:TxtAppsPackageManagerBanner) { $Script:TxtAppsPackageManagerBanner.Foreground = $bc.ConvertFromString($Theme.CautionText) }
		if ($Script:TxtAppSelectionStatus) { $Script:TxtAppSelectionStatus.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtAppsProgressText) { $Script:TxtAppsProgressText.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtOverlayTitle) { $Script:TxtOverlayTitle.Foreground = $bc.ConvertFromString($Theme.TextPrimary) }
		if ($Script:TxtUpdateDescription) { $Script:TxtUpdateDescription.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtDownloadProgressLabel) { $Script:TxtDownloadProgressLabel.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		if ($Script:TxtDownloadProgressPct) { $Script:TxtDownloadProgressPct.Foreground = $bc.ConvertFromString($Theme.TextSecondary) }
		Set-SearchInputStyle
		Set-FilterControlStyle
		Set-StaticButtonStyle
		Update-PrimaryTabVisuals
		if (Get-Command -Name 'Update-GuiMenuBarTheme' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiMenuBarTheme
		}
		if (Get-Command -Name 'Update-GuiScrollBarTheme' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-GuiScrollBarTheme
		}

		# Rebuild content for current tab to pick up new theme colors.
		$Script:FilterGeneration++
		Clear-TabContentCache
		$Script:AppsViewBuildSignature = $null
		if ($Script:AppsModeActive)
		{
			if (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Build-AppsViewCards
			}
		}
		elseif ($null -ne $Script:CurrentPrimaryTab)
		{
			Build-TabContent -PrimaryTab $Script:CurrentPrimaryTab -SkipIdlePrebuild
		}
		Update-HeaderModeStateText
		if (Get-Command -Name 'Update-RunPathContextLabel' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-RunPathContextLabel
		}
	}
	#endregion


	#region Helper: Create styled controls

	. (Join-Path $Script:GuiExtractedRoot 'TweakVisualization.ps1')

		    # Scriptblock stored in Script: scope so all closures and timer ticks can access it directly.
    # Simple: takes completed count, total count, and what's currently running.
    $Script:UpdateProgressFn = {
        param (
            [int]$Completed,
            [int]$Total,
            [string]$CurrentAction,
            [int]$SubCompleted = -1,
            [int]$SubTotal = 0,
            [string]$SubAction = $null,
            [switch]$ClearSub
        )

        if ($Script:ExecutionProgressBar -or $Script:ExecutionProgressText)
        {
            $Script:ExecutionProgressIndeterminate = ($Total -le 0 -or ($Completed -le 0 -and $CurrentAction -notin @('Done', 'Aborted')))
            Set-SharedProgressBarState -ProgressBar $Script:ExecutionProgressBar -ProgressText $Script:ExecutionProgressText -Completed $Completed -Total $Total -CurrentAction $CurrentAction -Indeterminate:($Script:ExecutionProgressIndeterminate)
        }

		# Sub-progress bar (downloads, installs, etc. reported by tweak functions)
		if ($Script:ExecutionSubProgressBar)
		{
			if ($ClearSub)
			{
				$Script:ExecutionSubProgressBar.Visibility = [System.Windows.Visibility]::Collapsed
				if ($Script:ExecutionSubProgressText) { $Script:ExecutionSubProgressText.Visibility = [System.Windows.Visibility]::Collapsed }
			}
			elseif ($SubTotal -gt 0)
			{
				$Script:ExecutionSubProgressBar.Visibility  = [System.Windows.Visibility]::Visible
				$Script:ExecutionSubProgressBar.Maximum     = $SubTotal
				$Script:ExecutionSubProgressBar.Value       = [Math]::Min($SubCompleted, $SubTotal)
				$Script:ExecutionSubProgressBar.IsIndeterminate = $false
				if ($Script:ExecutionSubProgressText)
				{
					$Script:ExecutionSubProgressText.Visibility = [System.Windows.Visibility]::Visible
					$pct = [Math]::Round(($SubCompleted / $SubTotal) * 100)
					$Script:ExecutionSubProgressText.Text = if ($SubAction) { "$SubAction  ($pct%)" } else { "$pct%" }
				}
			}
			elseif ($SubCompleted -ge 0 -and $SubTotal -le 0)
			{
				# Unknown total - show indeterminate sub-bar
				$Script:ExecutionSubProgressBar.Visibility = [System.Windows.Visibility]::Visible
				$Script:ExecutionSubProgressBar.IsIndeterminate = $true
				if ($Script:ExecutionSubProgressText)
				{
					$Script:ExecutionSubProgressText.Visibility = [System.Windows.Visibility]::Visible
					$Script:ExecutionSubProgressText.Text = if ($SubAction) { $SubAction } else { Get-UxExecutionPlaceholderText -Kind 'Working' }
				}
			}
		}

		# Sync observable state for progress subscribers
		if ($Script:GuiState -and $Total -gt 0)
		{
			& $Script:GuiState.SetBatch @{
				ProgressCompleted = $Completed
				ProgressTotal     = $Total
				ProgressAction    = $CurrentAction
			}
		}
	}

		<#
		    .SYNOPSIS
		    Internal function Invoke-GuiEvents.

		    .DESCRIPTION
		    Internal implementation helper used by Baseline.
		#>

		function Invoke-GuiEvents
		{
			$frame = New-Object System.Windows.Threading.DispatcherFrame
			$scheduled = Invoke-GuiDispatcherAction -Dispatcher $Form.Dispatcher -PriorityUsage 'Pump' -Action {
				$frame.Continue = $false
			}
			if ($scheduled)
			{
				[System.Windows.Threading.Dispatcher]::PushFrame($frame)
			}
		}

		<#
		    .SYNOPSIS
		    Internal function .

		    .DESCRIPTION
		    Internal implementation helper used by Baseline.
		#>
		function Close-GuiMainWindow
		{
			param (
				[string]$Reason = 'GUI close requested.'
			)

			Write-Host ("[Close-GuiMainWindow] {0}" -f $Reason)
			if ($Script:MainForm)
			{
				try { $Script:MainForm.Close() } catch { Write-GuiRuntimeWarning -Context 'Close-GuiMainWindow' -Message ("Failed to close main form: {0}" -f $_.Exception.Message) }
			}
		}

		$Script:ForceCloseExecutionFn = {
			Set-RunAbortDisposition -Disposition 'Exit'
			$timerToStop = $Script:ExecutionRunTimer
			$workerToStop = $Script:ExecutionWorker

			Clear-UILogHandler
			Remove-Variable -Name 'GUIRunState' -Scope Global -ErrorAction SilentlyContinue

			if ($Script:RunState)
			{
				$Script:RunState['AbortRequested'] = $true
				$Script:RunState['AbortRequestedAt'] = Get-Date
				$Script:RunState['AbortedRun'] = $true
				$Script:RunState['Done'] = $true
			}

			if ($timerToStop)
			{
				try { $timerToStop.Stop() } catch { $null = $_ }
				try { $timerToStop.Dispose() } catch { $null = $_ }
			}

			$Script:SuppressRunClosePrompt = $true

			if ($workerToStop)
			{
				GUIExecution\Stop-GuiExecutionWorkerAsync -Worker $workerToStop
			}

			$Script:ExecutionRunTimer = $null
			$Script:ExecutionWorker = $null
			$Script:ExecutionRunPowerShell = $null
			$Script:ExecutionRunspace = $null
			$Script:BgPS = $null
			$Script:BgAsync = $null
			$Script:RunInProgress = $false

			if ($Script:MainForm)
			{
				try
				{
					$null = Invoke-GuiDispatcherAction -Dispatcher $Script:MainForm.Dispatcher -PriorityUsage 'Immediate' -Action {
	                try { Close-GuiMainWindow -Reason 'ForceCloseExecutionFn requested immediate exit.' } catch { $null = $_ }
	                try
	                {
	                        if ([System.Windows.Application]::Current)
                        {
                                [System.Windows.Application]::Current.Shutdown()
                        }
                }
                catch { $null = $_ }
	        }
				}
				catch
				{
					try { Close-GuiMainWindow -Reason 'ForceCloseExecutionFn fallback close.' } catch { $null = $_ }
				}
			}

		$Script:ForceCloseCompleted = $true
	}

		$Script:RequestRunAbortFn = {
			param(
				[switch]$ExitNow
			)

			if (-not $Script:RunInProgress -or $Script:AbortRequested) { return }

			if ($ExitNow)
			{
				Set-RunAbortDisposition -Disposition 'Exit'
			}
			elseif ([string]::IsNullOrWhiteSpace([string]$Script:RunAbortDisposition))
			{
				Set-RunAbortDisposition -Disposition 'Return'
			}

			$Script:AbortRequested = $true
			if ($Script:AbortRunButton)
			{
				$Script:AbortRunButton.Content = (Get-UxLocalizedString -Key 'GuiStatusAborting' -Fallback 'Aborting...')
				$Script:AbortRunButton.IsEnabled = $false
			}
			if ($BtnRun)
			{
				$BtnRun.Content = if ($ExitNow) { (Get-UxLocalizedString -Key 'GuiStatusExiting' -Fallback 'Exiting...') } else { (Get-UxLocalizedString -Key 'GuiStatusStopping' -Fallback 'Stopping...') }
				$BtnRun.IsEnabled = $false
			}
			Set-GuiStatusText -Text $(if ($ExitNow) { (Get-UxLocalizedString -Key 'GuiStatusExitRequested' -Fallback '') } else { (Get-UxLocalizedString -Key 'GuiStatusAbortRequested' -Fallback '') }) -Tone 'caution'
			LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogAbortRequestedByUser' -Fallback 'Abort requested by user - waiting for the current step to stop.')

		if ($Script:RunState)
		{
			$Script:RunState['AbortRequested'] = $true
			$Script:RunState['AbortRequestedAt'] = Get-Date
			$Script:RunState['AbortedRun'] = $true
		}

			if ($ExitNow)
			{
				LogWarning (Get-UxBilingualLocalizedString -Key 'GuiLogExitRequestedByUser' -Fallback 'Exit requested by user - closing Baseline now.')
				& $Script:ForceCloseExecutionFn
				return
			}
	}

	$Script:PromptRunAbortFn = {
		if (-not $Script:RunInProgress -or $Script:AbortRequested) { return }

		$Script:AbortDialogShowing = $true
		try
		{
			$abortTitle = Get-UxLocalizedString -Key 'GuiAbortRunTitle' -Fallback 'Abort Run'
			$abortQuestion = Get-UxLocalizedString -Key 'GuiAbortRunQuestion' -Fallback 'Stop the current run now?'
			$abortDetail = Get-UxLocalizedString -Key 'GuiAbortRunDetail' -Fallback 'Return to Tweaks aborts the run and keeps the app open. Exit Now force-stops the run and closes Baseline immediately.'
			$abortBtnReturn = Get-UxLocalizedString -Key 'GuiAbortReturnToTweaks' -Fallback 'Return to Tweaks'
			$abortBtnExit = Get-UxLocalizedString -Key 'GuiAbortExitNow' -Fallback 'Exit Now'
			$abortBtnCancel = Get-UxLocalizedString -Key 'GuiBtnCancel' -Fallback 'Cancel'
			$choice = Show-ThemedDialog -Title $abortTitle `
			-Message "$abortQuestion`n`n$abortDetail" `
			-Buttons @($abortBtnReturn, $abortBtnExit, $abortBtnCancel) `
			-AccentButton $abortBtnReturn `
			-DestructiveButton $abortBtnExit
			Write-Host ("Abort dialog choice: '{0}'" -f $(if ($null -eq $choice) { '<null>' } else { [string]$choice }))
		}
		finally
		{
			$Script:AbortDialogShowing = $false
		}

		if (-not $Script:RunInProgress)
		{
			# Run completed while the dialog was open - nothing to abort
			return
		}

			switch ($choice)
			{
				{ $_ -eq $abortBtnReturn }
				{
					Set-RunAbortDisposition -Disposition 'Return'
					& $Script:RequestRunAbortFn
				}
				{ $_ -eq $abortBtnExit }
				{
					Set-RunAbortDisposition -Disposition 'Exit'
					& $Script:RequestRunAbortFn -ExitNow
				}
				default
				{
					Set-RunAbortDisposition -Disposition $null
				}
			}
		}


	#endregion


	#region Build controls for a set of tweaks
	$Script:Controls = @{}
	# Function-name -> manifest-index map for linked-toggle lookups in closures
	$Script:FunctionToIndex = @{}
	$Script:Ctx.Data.Controls = $Script:Controls
	$Script:Ctx.Data.FunctionToIndex = $Script:FunctionToIndex
	for ($fti = 0; $fti -lt $Script:TweakManifest.Count; $fti++)
	{
		$Script:FunctionToIndex[$Script:TweakManifest[$fti].Function] = $fti
	}

	# Pre-seed every manifest entry with a value holder so the run loop works
	# even for tabs the user never visits. Build-TweakRow replaces these with
	# real WPF controls when a tab is first rendered, carrying the state forward.
	for ($si = 0; $si -lt $Script:TweakManifest.Count; $si++)
	{
		$st = $Script:TweakManifest[$si]
		$isVisible = $true
		if ($st.VisibleIf)
		{
			try { $isVisible = [bool](& $st.VisibleIf) } catch { $isVisible = $false }
		}
			switch ($st.Type)
			{
				'Toggle' {
					$Script:Controls[$si] = [pscustomobject]@{ IsChecked = $false; IsEnabled = $isVisible }
				}
				'Action' {
					$Script:Controls[$si] = [pscustomobject]@{ IsChecked = $false; IsEnabled = $isVisible }
				}
				'Choice' {
					$Script:Controls[$si] = [pscustomobject]@{ SelectedIndex = [int]-1; IsEnabled = $isVisible }
				}
				'NumericRange' {
					$Script:Controls[$si] = [pscustomobject]@{ IsChecked = $false; IsEnabled = $isVisible }
				}
			}
		}

	# Pending linked states for tweaks whose target tab is not yet built
	$Script:PendingLinkedChecks   = [System.Collections.Generic.HashSet[string]]::new()
	$Script:PendingLinkedUnchecks = [System.Collections.Generic.HashSet[string]]::new()
	$Script:ApplyingGuiPreset     = $false  # suppress linked sync while applying an explicit preset
	# Applied-this-session tracking for system scan
	$Script:AppliedTweaks = [System.Collections.Generic.HashSet[string]]::new()

		<#
		    .SYNOPSIS
		    Internal function Update-CurrentTabContent.

		    .DESCRIPTION
		    Internal implementation helper used by Baseline.
		#>

		function Update-CurrentTabContent
		{
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
			param (
				[switch]$SkipIdlePrebuild
			)

			if ($Script:AppsModeActive) { return }

			if ($PrimaryTabs -and ($null -eq $PrimaryTabs.SelectedItem -or -not $PrimaryTabs.SelectedItem.Tag))
			{
				$resolvedSelection = $null
				$preferredTag = if (-not [string]::IsNullOrWhiteSpace([string]$Script:CurrentPrimaryTab))
				{
					[string]$Script:CurrentPrimaryTab
				}
				elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:LastStandardPrimaryTab))
				{
					[string]$Script:LastStandardPrimaryTab
				}
				else
				{
					$null
				}

				if ($preferredTag)
				{
					foreach ($tabItem in $PrimaryTabs.Items)
					{
						if (($tabItem -is [System.Windows.Controls.TabItem]) -and $tabItem.Tag -and ([string]$tabItem.Tag -eq $preferredTag))
						{
							$resolvedSelection = $tabItem
							break
						}
					}
				}

				if (-not $resolvedSelection)
				{
					foreach ($tabItem in $PrimaryTabs.Items)
					{
						if (($tabItem -is [System.Windows.Controls.TabItem]) -and $tabItem.Tag -and ([string]$tabItem.Tag -ne $Script:SearchResultsTabTag))
						{
							$resolvedSelection = $tabItem
							break
						}
					}
				}

				if ($resolvedSelection -and $PrimaryTabs.SelectedItem -ne $resolvedSelection)
				{
					$PrimaryTabs.SelectedItem = $resolvedSelection
				}
			}

		$targetTab = if ($PrimaryTabs -and $PrimaryTabs.SelectedItem -and $PrimaryTabs.SelectedItem.Tag)
		{
			[string]$PrimaryTabs.SelectedItem.Tag
		}
		elseif ($Script:CurrentPrimaryTab)
		{
			[string]$Script:CurrentPrimaryTab
		}
		else
		{
			$null
		}

			if ([string]::IsNullOrWhiteSpace($targetTab)) { return }
			$updateRiskFilterListScript = if ($Script:UpdateRiskFilterListScript) { $Script:UpdateRiskFilterListScript } else { ${function:Update-RiskFilterList} }
			$updateCategoryFilterListScript = if ($Script:UpdateCategoryFilterListScript) { $Script:UpdateCategoryFilterListScript } else { ${function:Update-CategoryFilterList} }
			$updatePrimaryTabVisualsScript = if ($Script:UpdatePrimaryTabVisualsScript) { $Script:UpdatePrimaryTabVisualsScript } else { ${function:Update-PrimaryTabVisuals} }
			$buildTabContentScript = if ($Script:BuildTabContentScript) { $Script:BuildTabContentScript } else { ${function:Build-TabContent} }
			if ($updateRiskFilterListScript)
			{
				try
				{
					& $updateRiskFilterListScript
				}
				catch
				{
					throw "Update-CurrentTabContent/UpdateRiskFilterList for tab '$targetTab' failed: $($_.Exception.Message)"
				}
			}
			if ($updateCategoryFilterListScript)
			{
				try
				{
					& $updateCategoryFilterListScript -PrimaryTab $targetTab
				}
				catch
				{
					throw "Update-CurrentTabContent/UpdateCategoryFilterList for tab '$targetTab' failed: $($_.Exception.Message)"
				}
			}
			try
			{
				& $updatePrimaryTabVisualsScript
			}
			catch
			{
				throw "Update-CurrentTabContent/UpdatePrimaryTabVisuals for tab '$targetTab' failed: $($_.Exception.Message)"
			}
			try
			{
				& $buildTabContentScript -PrimaryTab $targetTab -SkipIdlePrebuild:$SkipIdlePrebuild
			}
			catch
			{
				throw "Update-CurrentTabContent/BuildTabContent for tab '$targetTab' failed: $($_.Exception.Message)"
			}
		}

	. (Join-Path $Script:GuiExtractedRoot 'ModeState.ps1')


	. (Join-Path $Script:GuiExtractedRoot 'PresetApplication.ps1')


	<#
	    .SYNOPSIS
	    Internal function Set-SecondaryActionGroupStyle.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-SecondaryActionGroupStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		if (-not $Script:SecondaryActionGroupBorder) { return }
		$bc = New-SafeBrushConverter -Context 'Set-SecondaryActionGroupStyle'
		$Script:SecondaryActionGroupBorder.Background = $bc.ConvertFromString($Script:CurrentTheme.CardBg)
		$Script:SecondaryActionGroupBorder.BorderBrush = $bc.ConvertFromString($Script:CurrentTheme.BorderColor)
		$Script:SecondaryActionGroupBorder.Opacity = 0.7
	}

	<#
	    .SYNOPSIS
	    Internal function .

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>
	function Set-StaticButtonStyle
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()
		Set-ButtonChrome -Button $Script:BtnRun -Variant 'Primary'
		if ($Script:BtnPreviewRun) { Set-ButtonChrome -Button $Script:BtnPreviewRun -Variant 'Preview' }
		Set-ButtonChrome -Button $Script:BtnDefaults -Variant 'DangerSubtle'
		if ($Script:BtnUpdateAllApps) { Set-ButtonChrome -Button $Script:BtnUpdateAllApps -Variant 'Primary' -Compact }
		if ($Script:BtnAppsSourceWinGet) { Set-ButtonChrome -Button $Script:BtnAppsSourceWinGet -Variant 'Subtle' -Compact }
		if ($Script:BtnAppsSourceChocolatey) { Set-ButtonChrome -Button $Script:BtnAppsSourceChocolatey -Variant 'Subtle' -Compact }
		if ($Script:BtnInstallSelectedApps) { Set-ButtonChrome -Button $Script:BtnInstallSelectedApps -Variant 'Primary' -Compact }
		if ($Script:BtnUninstallSelectedApps) { Set-ButtonChrome -Button $Script:BtnUninstallSelectedApps -Variant 'DangerSubtle' -Compact }
		if ($Script:BtnUpdateSelectedApps) { Set-ButtonChrome -Button $Script:BtnUpdateSelectedApps -Variant 'Secondary' -Compact }
		if ($Script:BtnApplyQueuedActions) { Set-ButtonChrome -Button $Script:BtnApplyQueuedActions -Variant 'Primary' -Compact }
		if ($Script:BtnClearQueuedActions) { Set-ButtonChrome -Button $Script:BtnClearQueuedActions -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnClearAppSelection) { Set-ButtonChrome -Button $Script:BtnClearAppSelection -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnScanInstalledApps) { Set-ButtonChrome -Button $Script:BtnScanInstalledApps -Variant 'Secondary' -Compact }
		if ($Script:BtnStartHere) { Set-ButtonChrome -Button $Script:BtnStartHere -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnHelp) { Set-ButtonChrome -Button $Script:BtnHelp -Variant 'Subtle' -Compact -Muted }
		if ($BtnLanguage) { Set-ButtonChrome -Button $BtnLanguage -Variant 'Subtle' -Compact -Muted }
		Set-ButtonChrome -Button $BtnLog -Variant 'Subtle' -Compact -Muted
		if ($BtnExportSettings) { Set-ButtonChrome -Button $BtnExportSettings -Variant 'Subtle' -Compact -Muted }
		if ($BtnImportSettings) { Set-ButtonChrome -Button $BtnImportSettings -Variant 'Subtle' -Compact -Muted }
		if ($Script:BtnRestoreSnapshot) { Set-ButtonChrome -Button $Script:BtnRestoreSnapshot -Variant 'Subtle' -Compact -Muted }
		Set-SecondaryActionGroupStyle
	}

	<#
	    .SYNOPSIS
	    Internal function Set-StaticControlTabOrder.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Set-StaticControlTabOrder
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param ()

		$tabIndex = 0
		foreach ($control in @(
			$Script:BtnHelp,
			$BtnLog,
			$ChkScan,
			$ChkSafeMode,
			$ChkTheme,
			$BtnLanguage,
			$Script:TxtSearch,
			$Script:BtnClearSearch,
			$CmbRiskFilter,
			$CmbCategoryFilter,
			$ChkSelectedOnly,
			$ChkHighRiskOnly,
			$ChkRestorableOnly,
			$ChkGamingOnly,
			$Script:BtnDefaults,
			$BtnExportSettings,
			$BtnImportSettings,
			$Script:BtnRestoreSnapshot,
			$Script:BtnPreviewRun,
			$Script:BtnRun,
			$Script:BtnUpdateAllApps,
			$CmbAppsCategoryFilter,
			$Script:BtnAppsSourceWinGet,
			$Script:BtnAppsSourceChocolatey,
			$Script:BtnInstallSelectedApps,
			$Script:BtnUninstallSelectedApps,
			$Script:BtnUpdateSelectedApps,
			$Script:BtnApplyQueuedActions,
			$Script:BtnClearQueuedActions,
			$Script:BtnClearAppSelection,
			$Script:BtnScanInstalledApps
		))
		{
			if (-not $control) { continue }
			if ($control.PSObject.Properties['IsTabStop']) { $control.IsTabStop = $true }
			if ($control.PSObject.Properties['TabIndex'])
			{
				$control.TabIndex = $tabIndex
				$tabIndex++
			}
		}
	}

	. (Join-Path $Script:GuiExtractedRoot 'ContentManagement.ps1')


	. (Join-Path $Script:GuiExtractedRoot 'TweakRowFactory.ps1')


	#region Build tab content for a primary category
	$Script:CurrentPrimaryTab = $null
	$Script:SubTabControls = @{}


	. (Join-Path $Script:GuiExtractedRoot 'PresetUI.ps1')


	<#
	    .SYNOPSIS
	    Internal function Add-TabSectionsToPanel.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Add-TabSectionsToPanel
	{
		param ([object]$BuildContext)

		foreach ($subKey in $BuildContext.CategoryTweaks.Keys)
		{
			try
			{
				$indexes = $BuildContext.CategoryTweaks[$subKey]
			}
			catch
			{
				throw "Build-TabContent/ResolveSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			$showSectionHeader = $BuildContext.IsSearchResultsTab -or ($BuildContext.CategoryTweaks.Count -gt 1) -or ([string]$subKey -ne 'General')
			if ($showSectionHeader)
			{
				try
				{
					[void]($BuildContext.MainPanel.Children.Add((New-SectionHeader -Text $subKey)))
				}
				catch
				{
					throw "Build-TabContent/SectionHeader for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
				}
			}

			try
			{
				$cautionTweaksList = [System.Collections.Generic.List[object]]::new()
				foreach ($index in $indexes)
				{
					if ($Script:TweakManifest[$index].Caution)
					{
						$cautionTweaksList.Add($Script:TweakManifest[$index])
					}
				}
				$cautionTweaks = $cautionTweaksList
			}
			catch
			{
				throw "Build-TabContent/CollectCautionTweaks for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			foreach ($index in $indexes)
			{
				try
				{
					$tweak = $Script:TweakManifest[$index]
				}
				catch
				{
					throw "Build-TabContent/ResolveTweak for tab '$($BuildContext.PrimaryTab)' at index $index failed: $($_.Exception.Message)"
				}

				try
				{
					$row = Build-TweakRow -Index $index -Tweak $tweak -BrushConverter $BuildContext.BrushConverter
				}
				catch
				{
					throw "Build-TabContent/Row for tab '$($BuildContext.PrimaryTab)' failed at index $index ($([string]$tweak.Type) / $([string]$tweak.Function) / $([string]$tweak.Name)): $($_.Exception.Message)"
				}

				if ($row)
				{
					try
					{
						[void]($BuildContext.MainPanel.Children.Add($row))
					}
					catch
					{
						throw "Build-TabContent/AddRow for tab '$($BuildContext.PrimaryTab)' failed at index $index ($([string]$tweak.Type) / $([string]$tweak.Function) / $([string]$tweak.Name)): $($_.Exception.Message)"
					}
				}
			}

			try
			{
				$cautionSection = New-CautionSection -CautionTweaks $cautionTweaks
			}
			catch
			{
				throw "Build-TabContent/CautionSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
			}

			if ($cautionSection)
			{
				try
				{
					[void]($BuildContext.MainPanel.Children.Add($cautionSection))
				}
				catch
				{
					throw "Build-TabContent/AddCautionSection for tab '$($BuildContext.PrimaryTab)' section '$([string]$subKey)' failed: $($_.Exception.Message)"
				}
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Save-TabContentCacheEntry.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Save-TabContentCacheEntry
	{
		param (
			[object]$BuildContext,
			[int[]]$AllTabIndexes,
			[switch]$CacheOnly
		)

		if (-not $CacheOnly)
		{
			$ContentScroll.Content = $BuildContext.MainPanel
		}
		$controlRefs = @{}
		foreach ($index in @($AllTabIndexes))
		{
			if ($Script:Controls.ContainsKey($index) -and $Script:Controls[$index])
			{
				$controlRefs[[int]$index] = $Script:Controls[$index]
			}
		}
		$Script:TabContentCache[$BuildContext.PrimaryTab] = @{
			Panel = $BuildContext.MainPanel
			ControlRefs = $controlRefs
			PresetStatusBadge = $Script:PresetStatusBadge
			FilterGeneration = $Script:FilterGeneration
		}
	}

	# Helper for Dispatcher.BeginInvoke tab pre-builds. Uses [scriptblock]::Create()
	# to embed $Tag as a string literal — PowerShell scriptblocks use dynamic scoping
	# so function parameters do not survive past the function return. The block is then
	# re-bound to this module so $Script: variables and sibling functions
	# (Build-TabContent, Test-GuiRunInProgress, etc.) remain resolvable.
	<#
	    .SYNOPSIS
	    Internal function New-TabPreBuildAction.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function New-TabPreBuildAction
	{
		param ([string]$Tag)
		$safe = $Tag -replace "'", "''"
		$sb = [scriptblock]::Create(@"
try
{
	if (-not (Test-GuiRunInProgress) -and -not (`$Script:TabContentCache -and `$Script:TabContentCache.ContainsKey('$safe')))
	{
		Build-TabContent -PrimaryTab '$safe' -BackgroundBuild
	}
}
catch { Write-GuiRuntimeWarning -Context 'TabPreBuild:$safe' -Message `$_.Exception.Message }
"@)
		$mod = $ExecutionContext.SessionState.Module
		if ($mod) { $sb = $mod.NewBoundScriptBlock($sb) }
		return $sb
	}

	<#
	    .SYNOPSIS
	    Internal function Build-TabContent.

	    .DESCRIPTION
	    Internal implementation helper used by Baseline.
	#>

	function Build-TabContent
	{
		param (
			[string]$PrimaryTab,
			[switch]$BackgroundBuild,
			[switch]$SkipIdlePrebuild
		)

		if (-not $BackgroundBuild)
		{
			$Script:CurrentPrimaryTab = $PrimaryTab
			$Script:PresetStatusBadge = $null
			if (Restore-CachedTabContent -PrimaryTab $PrimaryTab)
			{
				return
			}
		}
		elseif ($Script:TabContentCache.ContainsKey($PrimaryTab))
		{
			return
		}

		try
		{
			$buildContext = New-TabContentBuildContext -PrimaryTab $PrimaryTab
		}
		catch
		{
			throw "Build-TabContent/Preamble for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		Add-TabContentLeadPanel -BuildContext $buildContext

		$activeFilterItems = Get-ActiveTabFilterItems -BuildContext $buildContext
		if ($activeFilterItems.Count -gt 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-ActiveFiltersBanner -BuildContext $buildContext -ActiveFilterItems $activeFilterItems)))
			}
			catch
			{
				Write-GuiRuntimeWarning -Context 'Build-TabContent/ActiveFiltersBanner' -Message ("Active filters banner failed for tab '{0}': {1}" -f $PrimaryTab, $_.Exception.Message)
			}
		}

		if ($buildContext.CategoryTweaks.Count -eq 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-EmptyTabStateCard -BuildContext $buildContext -HasActiveFilters:($activeFilterItems.Count -gt 0))))
			}
			catch
			{
				throw "Build-TabContent/EmptyState for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
		}

		try
		{
			$allTabIndexes = Get-TabContentIndexArray -CategoryTweaks $buildContext.CategoryTweaks
		}
		catch
		{
			throw "Build-TabContent/CollectTabIndexes for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		if ($allTabIndexes.Count -gt 0)
		{
			try
			{
				[void]($buildContext.MainPanel.Children.Add((New-TabSelectionBar -AllTabIndexes $allTabIndexes)))
			}
			catch
			{
				throw "Build-TabContent/SelectionBar for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
		}

		# Suspend WPF layout passes while adding tweak rows to avoid
		# expensive per-child Measure/Arrange cycles.
		$panelSuspended = $false
		try
		{
			if ($buildContext.MainPanel -is [System.Windows.FrameworkElement])
			{
				$buildContext.MainPanel.BeginInit()
				$panelSuspended = $true
			}
		}
		catch { <# BeginInit not critical — continue without suspension #> }

		Add-TabSectionsToPanel -BuildContext $buildContext

		if ($panelSuspended)
		{
			try { $buildContext.MainPanel.EndInit() } catch { <# non-fatal #> }
		}

		try
		{
			Save-TabContentCacheEntry -BuildContext $buildContext -AllTabIndexes $allTabIndexes -CacheOnly:$BackgroundBuild
		}
		catch
		{
			throw "Build-TabContent/AssignContent for tab '$PrimaryTab' failed: $($_.Exception.Message)"
		}

		if (-not $BackgroundBuild)
		{
			try
			{
				Update-MainContentPanelWidth -Panel $buildContext.MainPanel
			}
			catch
			{
				throw "Build-TabContent/UpdatePanelWidth for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}
			try
			{
				Restore-CurrentTabScrollOffset -TabKey $PrimaryTab
			}
			catch
			{
				throw "Build-TabContent/RestoreScrollOffset for tab '$PrimaryTab' failed: $($_.Exception.Message)"
			}

			# Schedule pre-builds for uncached tabs at idle priority so first-visit
			# switches are instant instead of waiting for on-demand construction.
			if (-not $SkipIdlePrebuild -and $PrimaryTabs -and $PrimaryTabs.Dispatcher)
			{
				$searchTag = $Script:SearchResultsTabTag
				foreach ($tabItem in $PrimaryTabs.Items)
				{
					if (-not ($tabItem -is [System.Windows.Controls.TabItem]) -or -not $tabItem.Tag) { continue }
					$tabTag = [string]$tabItem.Tag
					if ($tabTag -eq $PrimaryTab -or $tabTag -eq $searchTag) { continue }
					if ($Script:TabContentCache -and $Script:TabContentCache.ContainsKey($tabTag)) { continue }
					# Use a helper function (instead of .GetNewClosure()) to capture $tabTag
					# per-iteration while preserving the scope chain so that Build-TabContent
					# and its dependencies (New-TabContentBuildContext, etc.) remain resolvable.
					$preBuildAction = New-TabPreBuildAction -Tag $tabTag
					$null = $PrimaryTabs.Dispatcher.BeginInvoke(
						[System.Action]$preBuildAction,
						[System.Windows.Threading.DispatcherPriority]::ApplicationIdle
					)
				}
			}
		}
	}
	#endregion

	$Script:RunInProgress = $false

	# --- Observable State: reactive UI bindings ---
	$Script:GuiState = New-ObservableState -Dispatcher $Form.Dispatcher -InitialValues @{
		StatusText       = ''
		StatusForeground = (Get-GuiCurrentTheme).TextSecondary
		RunInProgress    = $false
		ProgressCompleted = 0
		ProgressTotal    = 0
		ProgressAction   = ''
		RiskFilter           = $Script:RiskFilter
		CategoryFilter       = $Script:CategoryFilter
		SelectedOnlyFilter   = $Script:SelectedOnlyFilter
		HighRiskOnlyFilter   = $Script:HighRiskOnlyFilter
		RestorableOnlyFilter = $Script:RestorableOnlyFilter
		GamingOnlyFilter     = $Script:GamingOnlyFilter
	}

	# Subscriber: StatusText -> $StatusText.Text
	& $Script:GuiState.Subscribe 'StatusText' {
		param ($newValue)
		if ($StatusText)
		{
			$StatusText.Text = [string]$newValue
			$StatusText.Visibility = if ([string]::IsNullOrWhiteSpace([string]$newValue)) { 'Collapsed' } else { 'Visible' }
		}
	}

	# Subscriber: StatusForeground -> $StatusText.Foreground (color string -> WPF brush)
	& $Script:GuiState.Subscribe 'StatusForeground' {
		param ($newValue)
		if ($StatusText -and $newValue -and $Script:SharedBrushConverter)
		{
			try { $StatusText.Foreground = $Script:SharedBrushConverter.ConvertFromString([string]$newValue) }
			catch { Write-GuiRuntimeWarning -Context 'GuiState/StatusForeground' -Message $_.Exception.Message }
		}
	}

	# Subscriber: RunInProgress -> sync to $Script: and context
	& $Script:GuiState.Subscribe 'RunInProgress' {
		param ($newValue)
		$Script:RunInProgress = [bool]$newValue
		if ($Script:Ctx) { $Script:Ctx.Run.InProgress = [bool]$newValue }
	}

	# Sync context - UI references
	$Script:Ctx.UI.MainForm = $Form
	$Script:Ctx.UI.StatusText = $StatusText
	$Script:Ctx.Run.InProgress = $false

		Register-GuiEventHandler -Source $Form -EventName 'Closing' -Handler ({
			param($windowSource, $e)
			if ($Script:SuppressRunClosePrompt) { return }
			if ($Script:AbortRequested -and (Get-RunAbortDisposition) -eq 'Return')
			{
				$e.Cancel = $true
				return
			}
			if (& $Script:TestGuiRunInProgressScript)
			{
				$e.Cancel = $true
			# Trigger the abort prompt if user attempts to close while running
			& $Script:PromptRunAbortFn
			return
		}

		# Show Save Session dialog while the main window is still alive to avoid
		# the long delay caused by WPF teardown / GC when spawning a new window
		# after ShowDialog() has returned.
		if (-not $Script:ForceCloseCompleted)
		{
			$saveTitle = Get-UxLocalizedString -Key 'GuiSaveSessionTitle' -Fallback 'Save Session'
			$saveMessage = Get-UxLocalizedString -Key 'GuiSaveSessionMessage' -Fallback 'Do you want to save your current selections for next launch?'
			$saveBtnSave = Get-UxLocalizedString -Key 'GuiSaveSessionSave' -Fallback 'Save'
			$saveBtnDiscard = Get-UxLocalizedString -Key 'GuiSaveSessionDiscard' -Fallback 'Discard'
			$saveChoice = GUICommon\Show-ThemedDialog `
				-Theme $Script:CurrentTheme `
				-ApplyButtonChrome ${function:Set-ButtonChrome} `
				-OwnerWindow $windowSource `
				-Title $saveTitle `
				-Message $saveMessage `
				-Buttons @($saveBtnSave, $saveBtnDiscard) `
				-UseDarkMode ($Script:CurrentThemeName -eq 'Dark') `
				-AccentButton $saveBtnSave
			if ($saveChoice -eq $saveBtnSave)
			{
				$null = Save-GuiSessionState
			}
		}
	}) | Out-Null

		Register-GuiEventHandler -Source $Form -EventName 'Closed' -Handler ({
			param($closedSender, $e)

			$dispatcher = if ($closedSender -and $closedSender.Dispatcher)
			{
				$closedSender.Dispatcher
			}
			elseif ($Script:MainForm -and $Script:MainForm.Dispatcher)
			{
				$Script:MainForm.Dispatcher
			}
			else
			{
				$null
			}

			if ($Script:GuiUnhandledExceptionHooked -and $Script:GuiUnhandledExceptionHandler -and $dispatcher)
			{
				try
				{
					$dispatcher.remove_UnhandledException($Script:GuiUnhandledExceptionHandler)
				}
				catch
				{
					$null = $_
				}
			}

			if ($Script:SearchRefreshTimer)
			{
				try { $Script:SearchRefreshTimer.Stop() } catch { $null = $_ }
				$Script:SearchRefreshTimer = $null
			}

			Clear-GuiWindowRuntimeState

			$Script:GuiUnhandledExceptionHooked = $false
			$Script:GuiUnhandledExceptionHandler = $null
			if ($Script:MainForm -eq $closedSender)
			{
				$Script:MainForm = $null
			}
		}) | Out-Null

	#region Build primary tabs
	foreach ($pKey in $PrimaryCategories.Keys)
	{
		# Check if any tweaks exist for this primary tab
		$hasTweaks = $false
		$tweakCount = 0
		for ($i = 0; $i -lt $Script:TweakManifest.Count; $i++)
		{
			if ((Resolve-GuiPrimaryTabForTweak -Tweak $Script:TweakManifest[$i]) -eq $pKey)
			{
				$hasTweaks = $true
				$tweakCount++
			}
		}
		if (-not $hasTweaks) { continue }

		$tabItem = New-Object System.Windows.Controls.TabItem
		$tabIconName = Get-GuiPrimaryTabIconName -PrimaryTab $pKey
		$tabDisplayName = Get-LocalizedTabHeader -PrimaryTab $pKey
		if ($tabIconName)
		{
			$tabItem.Header = New-GuiLabeledIconContent -IconName $tabIconName -Text "$tabDisplayName ($tweakCount)" -IconSize 16 -Gap 6 -AllowTextOnlyFallback
		}
		else
		{
			$tabItem.Header = "$tabDisplayName ($tweakCount)"
		}
		$tabItem.Tag = $pKey
		$tabItem.Foreground = ConvertTo-GuiBrush -Color $Script:CurrentTheme.TextPrimary -Context 'BuildPrimaryTabs/Foreground'
		$tabItem.Background = ConvertTo-GuiBrush -Color $Script:CurrentTheme.TabBg -Context 'BuildPrimaryTabs/Background'
		$tabItem.Padding = [System.Windows.Thickness]::new(16, 6, 16, 6)
		[void]($PrimaryTabs.Items.Add($tabItem))
		Add-PrimaryTabHoverEffects -Tab $tabItem
	}
	Update-PrimaryTabVisuals

	$Script:FilterUiUpdating = $true
	try
	{
		# Risk Filter - ONLY use SelectedIndex (integer)
		if ($CmbRiskFilter)
		{
			$CmbRiskFilter.Items.Clear()
			$riskDisplayAll = Get-UxLocalizedString -Key 'GuiRiskAll' -Fallback 'All'
			$riskDisplayLow = Get-UxLocalizedString -Key 'GuiRiskLowShort' -Fallback 'Low'
			$riskDisplayMedium = Get-UxLocalizedString -Key 'GuiRiskMediumShort' -Fallback 'Medium'
			$riskDisplayHigh = Get-UxLocalizedString -Key 'GuiRiskHighShort' -Fallback 'High'
			$Script:RiskFilterInternalValues = @('All', 'Low', 'Medium', 'High')
			foreach ($riskOption in @($riskDisplayAll, $riskDisplayLow, $riskDisplayMedium, $riskDisplayHigh))
			{
				[void]$CmbRiskFilter.Items.Add($riskOption)
			}

			$idx = 0
				if ($Script:RiskFilter -and $Script:RiskFilterInternalValues)
				{
					$found = $Script:RiskFilterInternalValues.IndexOf([string]$Script:RiskFilter)
					if ($found -ge 0) { $idx = $found }
				}
			try {
				$CmbRiskFilter.SelectedIndex = [int]$idx
			} catch {
				$CmbRiskFilter.SelectedIndex = 0
			}
		}

		# Category Filter (safe)
		if ($CmbCategoryFilter)
		{
			$idx = 0
			if ($Script:CategoryFilter -and $Script:CategoryFilterInternalValues)
			{
				$found = $Script:CategoryFilterInternalValues.IndexOf($Script:CategoryFilter)
				if ($found -ge 0) { $idx = $found }
			}
			try {
				$CmbCategoryFilter.SelectedIndex = [int]$idx
			} catch {
				$CmbCategoryFilter.SelectedIndex = 0
			}
		}

		# Checkboxes
		if ($ChkSafeMode)      { try { $ChkSafeMode.IsChecked      = [bool]$Script:SafeMode } catch { Write-GuiRuntimeWarning -Context 'FilterSync:SafeMode' -Message $_.Exception.Message } }
		if ($ChkGameMode)      { try { $ChkGameMode.IsChecked      = [bool]$Script:GameMode } catch { Write-GuiRuntimeWarning -Context 'FilterSync:GameMode' -Message $_.Exception.Message } }
		if ($ChkScan)          { try { $ChkScan.IsChecked          = [bool]$Script:ScanEnabled } catch { Write-GuiRuntimeWarning -Context 'FilterSync:ScanEnabled' -Message $_.Exception.Message } }

		# Language selector button + popup
		if ($BtnLanguage -and $LanguagePopup -and $LanguageListPanel)
		{
			# Build display-name-to-code mapping from available JSON files.
			$Script:LanguageMap = [ordered]@{}
			$locDir = $Script:GuiLocalizationDirectoryPath
			# Language display: NativeName|EnglishName pairs for dual-line display
			$langDisplayData = @{
				'af'      = @{ Native = 'Afrikaans';           English = 'Afrikaans' }
				'am'      = @{ Native = 'አማርኛ';               English = 'Amharic' }
				'ar'      = @{ Native = 'العربية';              English = 'Arabic' }
				'az'      = @{ Native = 'Azərbaycan';          English = 'Azerbaijani' }
				'be'      = @{ Native = 'Беларуская';          English = 'Belarusian' }
				'bg'      = @{ Native = 'Български';           English = 'Bulgarian' }
				'bn'      = @{ Native = 'বাংলা';                English = 'Bengali' }
				'bs'      = @{ Native = 'Bosanski';            English = 'Bosnian' }
				'ca'      = @{ Native = 'Català';              English = 'Catalan' }
				'cs'      = @{ Native = 'Čeština';             English = 'Czech' }
				'da'      = @{ Native = 'Dansk';               English = 'Danish' }
				'de'      = @{ Native = 'Deutsch';             English = 'German' }
				'el'      = @{ Native = 'Ελληνικά';            English = 'Greek' }
				'en'      = @{ Native = 'English';             English = 'English' }
				'en-029'  = @{ Native = 'English (Caribbean)'; English = 'English (Caribbean)' }
				'en-AE'   = @{ Native = 'English (United Arab Emirates)'; English = 'English (United Arab Emirates)' }
				'en-AU'   = @{ Native = 'English (Australia)'; English = 'English (Australia)' }
				'en-BZ'   = @{ Native = 'English (Belize)';    English = 'English (Belize)' }
				'en-CA'   = @{ Native = 'English (Canada)';    English = 'English (Canada)' }
				'en-GB'   = @{ Native = 'English (United Kingdom)'; English = 'English (United Kingdom)' }
				'en-IE'   = @{ Native = 'English (Ireland)';   English = 'English (Ireland)' }
				'en-IN'   = @{ Native = 'English (India)';      English = 'English (India)' }
				'en-JM'   = @{ Native = 'English (Jamaica)';    English = 'English (Jamaica)' }
				'en-MV'   = @{ Native = 'English (Maldives)';   English = 'English (Maldives)' }
				'en-MY'   = @{ Native = 'English (Malaysia)';   English = 'English (Malaysia)' }
				'en-NZ'   = @{ Native = 'English (New Zealand)'; English = 'English (New Zealand)' }
				'en-PH'   = @{ Native = 'English (Philippines)'; English = 'English (Philippines)' }
				'en-SG'   = @{ Native = 'English (Singapore)';  English = 'English (Singapore)' }
				'en-TT'   = @{ Native = 'English (Trinidad & Tobago)'; English = 'English (Trinidad & Tobago)' }
				'en-US'   = @{ Native = 'English (United States)'; English = 'English (United States)' }
				'en-ZA'   = @{ Native = 'English (South Africa)'; English = 'English (South Africa)' }
				'en-ZW'   = @{ Native = 'English (Zimbabwe)';    English = 'English (Zimbabwe)' }
				'es'      = @{ Native = 'Español';             English = 'Spanish' }
				'es-MX'   = @{ Native = 'Español (México)';    English = 'Spanish (Mexico)' }
				'et'      = @{ Native = 'Eesti';               English = 'Estonian' }
				'eu'      = @{ Native = 'Euskara';             English = 'Basque' }
				'fa'      = @{ Native = 'فارسی';               English = 'Persian' }
				'fi'      = @{ Native = 'Suomi';               English = 'Finnish' }
				'fil'     = @{ Native = 'Filipino';            English = 'Filipino' }
				'fr'      = @{ Native = 'Français';            English = 'French' }
				'fr-CA'   = @{ Native = 'Français (Canada)';   English = 'French (Canada)' }
				'ga'      = @{ Native = 'Gaeilge';             English = 'Irish' }
				'gd'      = @{ Native = 'Gàidhlig';            English = 'Scottish Gaelic' }
				'gl'      = @{ Native = 'Galego';              English = 'Galician' }
				'gu'      = @{ Native = 'ગુજરાતી';              English = 'Gujarati' }
				'he'      = @{ Native = 'עברית';               English = 'Hebrew' }
				'hi'      = @{ Native = 'हिन्दी';                English = 'Hindi' }
				'hr'      = @{ Native = 'Hrvatski';            English = 'Croatian' }
				'hu'      = @{ Native = 'Magyar';              English = 'Hungarian' }
				'hy'      = @{ Native = 'Հայերեն';             English = 'Armenian' }
				'id'      = @{ Native = 'Bahasa Indonesia';    English = 'Indonesian' }
				'is'      = @{ Native = 'Íslenska';            English = 'Icelandic' }
				'it'      = @{ Native = 'Italiano';            English = 'Italian' }
				'ja'      = @{ Native = '日本語';               English = 'Japanese' }
				'ka'      = @{ Native = 'ქართული';             English = 'Georgian' }
				'kk'      = @{ Native = 'Қазақ';               English = 'Kazakh' }
				'km'      = @{ Native = 'ខ្មែរ';                 English = 'Khmer' }
				'kn'      = @{ Native = 'ಕನ್ನಡ';                English = 'Kannada' }
				'ko'      = @{ Native = '한국어';               English = 'Korean' }
				'lo'      = @{ Native = 'ລາວ';                 English = 'Lao' }
				'lt'      = @{ Native = 'Lietuvių';            English = 'Lithuanian' }
				'lv'      = @{ Native = 'Latviešu';            English = 'Latvian' }
				'mk'      = @{ Native = 'Македонски';          English = 'Macedonian' }
				'ml'      = @{ Native = 'മലയാളം';              English = 'Malayalam' }
				'mr'      = @{ Native = 'मराठी';                English = 'Marathi' }
				'ms'      = @{ Native = 'Bahasa Melayu';       English = 'Malay' }
				'mt'      = @{ Native = 'Malti';               English = 'Maltese' }
				'nb'      = @{ Native = 'Norsk Bokmål';        English = 'Norwegian' }
				'ne'      = @{ Native = 'नेपाली';               English = 'Nepali' }
				'nl'      = @{ Native = 'Nederlands';          English = 'Dutch' }
				'nl-BE'   = @{ Native = 'Nederlands (België)'; English = 'Dutch (Belgium)' }
				'nn'      = @{ Native = 'Norsk Nynorsk';       English = 'Norwegian Nynorsk' }
				'pa'      = @{ Native = 'ਪੰਜਾਬੀ';               English = 'Punjabi' }
				'pl'      = @{ Native = 'Polski';              English = 'Polish' }
				'pt'      = @{ Native = 'Português';           English = 'Portuguese' }
				'pt-BR'   = @{ Native = 'Português (Brasil)';  English = 'Portuguese (Brazil)' }
				'ro'      = @{ Native = 'Română';              English = 'Romanian' }
				'ru'      = @{ Native = 'Русский';             English = 'Russian' }
				'sk'      = @{ Native = 'Slovenčina';          English = 'Slovak' }
				'sl'      = @{ Native = 'Slovenščina';         English = 'Slovenian' }
				'sq'      = @{ Native = 'Shqip';               English = 'Albanian' }
				'sr'      = @{ Native = 'Srpski';              English = 'Serbian' }
				'sv'      = @{ Native = 'Svenska';             English = 'Swedish' }
				'sw'      = @{ Native = 'Kiswahili';           English = 'Swahili' }
				'ta'      = @{ Native = 'தமிழ்';                English = 'Tamil' }
				'te'      = @{ Native = 'తెలుగు';               English = 'Telugu' }
				'th'      = @{ Native = 'ไทย';                  English = 'Thai' }
				'tr'      = @{ Native = 'Türkçe';              English = 'Turkish' }
				'uk'      = @{ Native = 'Українська';          English = 'Ukrainian' }
				'ur'      = @{ Native = 'اردو';                 English = 'Urdu' }
				'uz'      = @{ Native = "O'zbek";              English = 'Uzbek' }
				'vi'      = @{ Native = 'Tiếng Việt';          English = 'Vietnamese' }
				'zh-Hans' = @{ Native = '简体中文';              English = 'Chinese (Simplified)' }
				'zh-Hant' = @{ Native = '繁體中文';              English = 'Chinese (Traditional)' }
				'as'      = @{ Native = 'অসমীয়া';              English = 'Assamese' }
				'bn-BD'   = @{ Native = 'বাংলা (বাংলাদেশ)';     English = 'Bengali (Bangladesh)' }
				'chr'     = @{ Native = 'ᏣᎳᎩ';                English = 'Cherokee' }
				'ckb'     = @{ Native = 'کوردیی ناوەندی';       English = 'Central Kurdish' }
				'cy'      = @{ Native = 'Cymraeg';             English = 'Welsh' }
				'ha'      = @{ Native = 'Hausa';               English = 'Hausa' }
				'ig'      = @{ Native = 'Igbo';                English = 'Igbo' }
				'kok'     = @{ Native = 'कोंकणी';               English = 'Konkani' }
				'ky'      = @{ Native = 'Кыргызча';            English = 'Kyrgyz' }
				'lb'      = @{ Native = 'Lëtzebuergesch';      English = 'Luxembourgish' }
				'mi'      = @{ Native = 'Te Reo Māori';        English = 'Māori' }
				'mn'      = @{ Native = 'Монгол';              English = 'Mongolian' }
				'nso'     = @{ Native = 'Sesotho sa Leboa';    English = 'Northern Sotho' }
				'or'      = @{ Native = 'ଓଡ଼ିଆ';                English = 'Odia' }
				'pa-Arab' = @{ Native = 'پنجابی';               English = 'Punjabi (Arabic)' }
				'prs'     = @{ Native = 'دری';                  English = 'Dari' }
				'ps'      = @{ Native = 'پښتو';                 English = 'Pashto' }
				'qu'      = @{ Native = 'Runasimi';            English = 'Quechua' }
				'quc'     = @{ Native = "K'iche'";             English = "K'iche'" }
				'rw'      = @{ Native = 'Ikinyarwanda';        English = 'Kinyarwanda' }
				'sd'      = @{ Native = 'سنڌي';                 English = 'Sindhi' }
				'si'      = @{ Native = 'සිංහල';                English = 'Sinhala' }
				'sr-Cyrl' = @{ Native = 'Српски';              English = 'Serbian (Cyrillic)' }
				'ti'      = @{ Native = 'ትግርኛ';                English = 'Tigrinya' }
				'tk'      = @{ Native = 'Türkmen';             English = 'Turkmen' }
				'tn'      = @{ Native = 'Setswana';            English = 'Setswana' }
				'tt'      = @{ Native = 'Татар';               English = 'Tatar' }
				'ug'      = @{ Native = 'ئۇيغۇرچە';             English = 'Uyghur' }
				'wo'      = @{ Native = 'Wolof';               English = 'Wolof' }
				'xh'      = @{ Native = 'isiXhosa';            English = 'isiXhosa' }
				'yo'      = @{ Native = 'Yorùbá';              English = 'Yoruba' }
				'zu'      = @{ Native = 'isiZulu';             English = 'isiZulu' }
			}
			# Build compat map for legacy code
			$langDisplayNames = @{}
			foreach ($ldKey in $langDisplayData.Keys) { $langDisplayNames[$ldKey] = $langDisplayData[$ldKey].English }

			$languageFiles = @()
			$languageEntries = New-Object System.Collections.ArrayList
			if (-not [string]::IsNullOrWhiteSpace([string]$locDir))
			{
				# Locale JSON files live in per-language folders; the root JSON files are
				# metadata (locale-map, schema, exempt-keys) and must not appear in the picker.
				$languageFiles = @(
					Get-ChildItem -LiteralPath $locDir -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue |
						Where-Object { $langDisplayData.ContainsKey($_.BaseName) } |
						Sort-Object @{ Expression = { if ($langDisplayData.ContainsKey($_.BaseName)) { $langDisplayData[$_.BaseName].English } else { $_.BaseName } } }, BaseName
				)
			}

			foreach ($jsonFile in $languageFiles)
			{
				$code = $jsonFile.BaseName
				$nativeName = if ($langDisplayData.ContainsKey($code)) { $langDisplayData[$code].Native } else { $code }
				$englishName = if ($langDisplayData.ContainsKey($code)) { $langDisplayData[$code].English } else { $code }
				$displayName = $englishName
				$Script:LanguageMap[$displayName] = $code
				[void]$languageEntries.Add([pscustomobject]@{
					Code = $code
					DisplayName = $displayName
					NativeName = $nativeName
					EnglishName = $englishName
					SearchIndex = ("{0} {1} {2} {3}" -f $nativeName, $englishName, $code, ($code -replace '-', ' ')).ToLowerInvariant()
				})
			}

			$setLanguageSearchInputStyle = ${function:Set-LanguageSearchInputStyle}
			$getUxLocalizedStringCapture = Get-GuiFunctionCapture -Name 'Get-UxLocalizedString'
			$getUxBilingualLocalizedStringCapture = Get-GuiFunctionCapture -Name 'Get-UxBilingualLocalizedString'
			$setFilterControlStyleCapture = ${function:Set-FilterControlStyle}

			if (-not $getUxLocalizedStringCapture) { throw 'Get-UxLocalizedString not found.' }
			if (-not $getUxBilingualLocalizedStringCapture) { throw 'Get-UxBilingualLocalizedString not found.' }
			Set-Item -Path function:Get-UxBilingualLocalizedString -Value $getUxBilingualLocalizedStringCapture

			# Language change logic stays in Show-TweakGUI scope so the live WPF
			# controls remain available, but the click handlers invoke a concrete
			# command handle instead of a raw local variable.
			<#
			    .SYNOPSIS
			    Internal function Set-SelectedGuiLanguage.

			    .DESCRIPTION
			    Internal implementation helper used by Baseline.
			#>

			function Set-SelectedGuiLanguage
			{
				param([string]$langCode)
				$Script:SelectedLanguage = $langCode

				# 1. Load new localization strings
				$locDir = $Script:GuiLocalizationDirectoryPath
				if (-not [string]::IsNullOrWhiteSpace([string]$locDir))
				{
					$Global:Localization = Import-BaselineLocalization -BaseDirectory $locDir -UICulture $langCode
					[void](Set-BaselineThreadCulture -UICulture $langCode)
					$env:BASELINE_LANGUAGE = $langCode
				}

				# 2. Clear the inline language search and update indicator
				if ($TxtLanguageSearch) { $TxtLanguageSearch.Text = '' }
				if ($TxtLanguageState) { $TxtLanguageState.Text = $langCode.ToUpperInvariant() }
				Set-LanguageSearchInputStyle
				$LanguagePopup.IsOpen = $false
				if ($BtnLanguage) { $BtnLanguage.IsChecked = $false }

				# 3. Refresh all header/toolbar localized strings
				Update-GuiLocalizationStrings

				# 4. Refresh tab headers with localized names
				Update-PrimaryTabHeaders

				# 5. Rebuild tab content (mirrors theme change pattern)
				$Script:FilterGeneration++
				Clear-TabContentCache
				if ($null -ne $Script:CurrentPrimaryTab)
				{
					Update-CurrentTabContent -SkipIdlePrebuild
				}

				# 6. Sync action buttons (respects execution-mode guard)
				Sync-UxActionButtonText

				# 7. Update run-path context label if available
				if (Get-Command -Name 'Update-RunPathContextLabel' -CommandType Function -ErrorAction SilentlyContinue)
				{
					Update-RunPathContextLabel
				}

				LogInfo (& $getUxBilingualLocalizedStringCapture -Key 'GuiLogLanguageChanged' -Fallback 'Language changed to: {0}' -FormatArgs @($langCode))
			}

			$setSelectedGuiLanguageCommand = ${function:Set-SelectedGuiLanguage}
			$renderLanguageList = {
				param ([string]$FilterText = '')

				$currentCode = if ($Script:SelectedLanguage) { [string]$Script:SelectedLanguage } else { 'en' }
				if ($currentCode -eq 'en') { $currentCode = 'en-US' }
				$normalizedFilter = if ([string]::IsNullOrWhiteSpace([string]$FilterText)) { '' } else { ([string]$FilterText).Trim().ToLowerInvariant() }
				$LanguageListPanel.Children.Clear()

				$matchingEntries = if ([string]::IsNullOrWhiteSpace($normalizedFilter))
				{
					@($languageEntries)
				}
				else
				{
					@($languageEntries | Where-Object { [string]$_.SearchIndex -like "*$normalizedFilter*" })
				}

				if ($matchingEntries.Count -eq 0)
				{
					$emptyState = [System.Windows.Controls.TextBlock]::new()
					$emptyState.Text = (& $getUxLocalizedStringCapture -Key 'GuiLanguageSearchNoResults' -Fallback 'No languages found.')
					$emptyState.TextWrapping = 'Wrap'
					$emptyState.Margin = [System.Windows.Thickness]::new(10, 8, 10, 6)
					$emptyState.FontSize = 11
					$emptyState.HorizontalAlignment = 'Left'
					[void]$LanguageListPanel.Children.Add($emptyState)
					if ($setFilterControlStyleCapture) { & $setFilterControlStyleCapture }
					return
				}

				foreach ($entry in $matchingEntries)
				{
					$langBtn = [System.Windows.Controls.Button]::new()
					$langBtn.Tag = [string]$entry.Code
					$langBtn.Cursor = [System.Windows.Input.Cursors]::Hand
					$langBtn.HorizontalContentAlignment = 'Left'
					$langBtn.Padding = [System.Windows.Thickness]::new(12, 5, 12, 5)
					$langBtn.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
					$langBtn.Width = 240
					$langBtn.ClickMode = [System.Windows.Controls.ClickMode]::Press
					$langBtn.BorderThickness = [System.Windows.Thickness]::new(0)
					$langBtn.Background = [System.Windows.Media.Brushes]::Transparent

					# Dual-line content: Native name (bold) + English name (muted)
					$isActive = [string]$entry.Code -eq $currentCode
					$langStack = [System.Windows.Controls.StackPanel]::new()
					$langStack.Orientation = 'Vertical'
					$nativeBlock = [System.Windows.Controls.TextBlock]::new()
					$nativeBlock.Text = [string]$entry.NativeName
					$nativeBlock.FontSize = 12
					$nativeBlock.FontWeight = if ($isActive) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::Normal }
					[void]$langStack.Children.Add($nativeBlock)
					if ([string]$entry.NativeName -ne [string]$entry.EnglishName)
					{
						$engBlock = [System.Windows.Controls.TextBlock]::new()
						$engBlock.Text = [string]$entry.EnglishName
						$engBlock.FontSize = 10
						$engBlock.Opacity = 0.6
						[void]$langStack.Children.Add($engBlock)
					}
					$langBtn.Content = $langStack

					$langBtn.Add_Click({
						param($buttonSender, $buttonEventArgs)
						$null = $buttonEventArgs
						& $setSelectedGuiLanguageCommand ([string]$buttonSender.Tag)
					})

					[void]$LanguageListPanel.Children.Add($langBtn)
				}

				if ($setFilterControlStyleCapture) { & $setFilterControlStyleCapture }
			}.GetNewClosure()

			if ($TxtLanguageSearch)
			{
				if ($setLanguageSearchInputStyle) { & $setLanguageSearchInputStyle }
				$null = Register-GuiEventHandler -Source $TxtLanguageSearch -EventName 'GotKeyboardFocus' -Handler ({
					if ($setLanguageSearchInputStyle) { & $setLanguageSearchInputStyle }
				}.GetNewClosure())
				$null = Register-GuiEventHandler -Source $TxtLanguageSearch -EventName 'LostKeyboardFocus' -Handler ({
					if ($setLanguageSearchInputStyle) { & $setLanguageSearchInputStyle }
				}.GetNewClosure())
				$null = Register-GuiEventHandler -Source $TxtLanguageSearch -EventName 'TextChanged' -Handler ({
					& $renderLanguageList -FilterText $TxtLanguageSearch.Text
					if ($setLanguageSearchInputStyle) { & $setLanguageSearchInputStyle }
				}.GetNewClosure())
			}

			& $renderLanguageList -FilterText $(if ($TxtLanguageSearch) { $TxtLanguageSearch.Text } else { '' })
			if ($TxtLanguageState)
			{
				$currentLanguageCode = if ($Script:SelectedLanguage) { [string]$Script:SelectedLanguage } else { 'en' }
				$TxtLanguageState.Text = $currentLanguageCode.ToUpperInvariant()
			}

			$null = Register-GuiEventHandler -Source $LanguagePopup -EventName 'Opened' -Handler ({
				if ($TxtLanguageSearch)
				{
					if (-not [string]::IsNullOrWhiteSpace([string]$TxtLanguageSearch.Text))
					{
						$TxtLanguageSearch.Text = ''
					}
					else
					{
						& $renderLanguageList -FilterText ''
					}
					if ($setLanguageSearchInputStyle) { & $setLanguageSearchInputStyle }
					$null = $TxtLanguageSearch.Focus()
				}
				else
				{
					& $renderLanguageList -FilterText ''
				}
			}.GetNewClosure())
		}
	}
	finally
	{
		$Script:FilterUiUpdating = $false
	}
	Set-FilterControlStyle

	$Script:SuppressPrimaryTabSelectionChanged = $true
	$updateCurrentTabContentScript = ${function:Update-CurrentTabContent}
	$saveTabScrollOffsetScript = ${function:Save-CurrentTabScrollOffset}
		Register-GuiEventHandler -Source $PrimaryTabs -EventName 'SelectionChanged' -Handler ({
			param($tabEventSender, $e)
			if (-not $e) { return }
		if ($e.Source -ne $PrimaryTabs) { return }
		if ($Script:SuppressPrimaryTabSelectionChanged) { return }
		$skipIdlePrebuild = [bool]$Script:SkipIdlePrebuildOnNextPrimaryTabSelection
		$Script:SkipIdlePrebuildOnNextPrimaryTabSelection = $false
		& $saveTabScrollOffsetScript
		$selected = $PrimaryTabs.SelectedItem
		if ($selected -and $selected.Tag)
		{
			if ([string]$selected.Tag -ne $Script:SearchResultsTabTag)
			{
				$Script:LastStandardPrimaryTab = [string]$selected.Tag
				}
				# Defer content build so the tab header switches immediately
				$null = Invoke-GuiDispatcherAction -Dispatcher $PrimaryTabs.Dispatcher -PriorityUsage 'DeferredContentBuild' -Action {
						try { & $updateCurrentTabContentScript -SkipIdlePrebuild:$skipIdlePrebuild }
						catch {
							$showFn = $Script:ShowGuiRuntimeFailureScript
							if ($showFn) { $null = & $showFn -Context 'PrimaryTabs/SelectionChanged' -Exception $_.Exception -ShowDialog }
							else { Write-Warning ("GUI event failed [PrimaryTabs/SelectionChanged]: {0}" -f $_.Exception.Message) }
						}
				}
		}
	}) | Out-Null

	# Keep the desktop UI on a stable single-row tab strip so the primary
	# navigation does not reshuffle when Safe/Expert/Game Mode state changes.
	$Script:AdaptiveTabMode = 'tabs'
	$Script:SuppressDropdownSync = $false

	$adaptiveTabLayoutScript = {
		$availableTabWidth = if ($PrimaryTabHost -and $PrimaryTabHost.ActualWidth -gt 0)
		{
			[double]$PrimaryTabHost.ActualWidth
		}
		elseif ($Form.ActualWidth -gt 0)
		{
			[Math]::Max(0, [double]$Form.ActualWidth - 16)
		}
		else
		{
			0
		}
		if ($availableTabWidth -le 0) { return }

		$padding = if ($availableTabWidth -ge 1400)
		{
			[System.Windows.Thickness]::new(16, 6, 16, 6)
		}
		else
		{
			[System.Windows.Thickness]::new(8, 6, 8, 6)
		}

		foreach ($tabItem in $PrimaryTabs.Items)
		{
			if (-not ($tabItem -is [System.Windows.Controls.TabItem]))
			{
				continue
			}

			$tabItem.Padding = $padding
		}

		$Script:AdaptiveTabMode = 'tabs'
		if ($PrimaryTabDropdown)
		{
			$PrimaryTabDropdown.Visibility = [System.Windows.Visibility]::Collapsed
		}
		$PrimaryTabs.Visibility = [System.Windows.Visibility]::Visible

		# Keep the fixed one-row header strip visible and refresh the selected
		# tab's visual state after any width change.
		$selectedTab = $PrimaryTabs.SelectedItem
		if ($selectedTab -is [System.Windows.Controls.TabItem])
		{
			try { $selectedTab.BringIntoView() } catch { }
		}
	}
	$Script:AdaptiveTabLayoutScript = $adaptiveTabLayoutScript

	Register-GuiEventHandler -Source $Form -EventName 'SizeChanged' -Handler ({
		& $Script:AdaptiveTabLayoutScript
	}) | Out-Null

	# Build the initial tab while the startup splash is still visible so the main
	# window only appears once real content is ready.
	if (-not ($PrimaryTabs -is [System.Windows.Controls.TabControl]))
	{
		throw "PrimaryTabs is not a TabControl. Actual type: $($PrimaryTabs.GetType().FullName)"
	}

	if ($PrimaryTabs.Items.Count -gt 0)
	{
		$showGuiRuntimeFailureCapture = $Script:ShowGuiRuntimeFailureScript
		try
		{
			$null = Invoke-GuiDispatcherAction -Dispatcher $PrimaryTabs.Dispatcher -PriorityUsage 'IdleFinalize' -Action {
					try
					{
						$firstTab = if ($PrimaryTabs.Items.Count -gt 0) { $PrimaryTabs.Items[0] } else { $null }
						$selectedTab = if ($PrimaryTabs.SelectedItem) { $PrimaryTabs.SelectedItem } else { $null }
						$targetTab = if ($selectedTab) { $selectedTab } else { $firstTab }
						if ($null -eq $targetTab)
						{
							return
						}

						if ($null -eq $selectedTab -and $PrimaryTabs.SelectedItem -ne $targetTab)
						{
							$PrimaryTabs.SelectedItem = $targetTab
						}

						if ($targetTab.Tag -and [string]$targetTab.Tag -ne $Script:SearchResultsTabTag)
						{
							$Script:LastStandardPrimaryTab = [string]$targetTab.Tag
						}

						Update-CurrentTabContent
					}
					catch
					{
						if ($showGuiRuntimeFailureCapture) { $null = & $showGuiRuntimeFailureCapture -Context 'InitialTabBuild' -Exception $_.Exception -ShowDialog }
						else { Write-Warning ("GUI event failed [InitialTabBuild]: {0}" -f $_.Exception.Message) }
					}
					finally
					{
						$Script:SuppressPrimaryTabSelectionChanged = $false
					}
				}
		}
		catch
		{
			$Script:SuppressPrimaryTabSelectionChanged = $false
			throw
		}
	}
	else
	{
		$Script:SuppressPrimaryTabSelectionChanged = $false
	}
	#endregion

	# Linked-toggle wiring is handled inline in Build-TweakRow (supports lazy tab building).

	$Script:ClearTabContentCacheScript = ${function:Clear-TabContentCache}
	$Script:UpdateCategoryFilterListScript = ${function:Update-CategoryFilterList}
	$Script:UpdateSearchResultsTabStateScript = ${function:Update-SearchResultsTabState}

	$refreshVisibleContent = {
		if ((& $Script:TestGuiRunInProgressScript) -or $Script:FilterUiUpdating) { return }
		# Bump the filter generation so stale tab caches are evicted on next visit
		# without the cost of clearing and rebuilding all tabs up front.
		$Script:FilterGeneration++
		# When search text is active, use the search sentinel tag so category
		# filters reflect cross-tab results.  Fall back to the selected real tab.
		$hasSearchText = -not [string]::IsNullOrWhiteSpace([string]$Script:SearchText)
		$targetTab = if ($hasSearchText) {
			$Script:SearchResultsTabTag
		}
		elseif ($PrimaryTabs -and $PrimaryTabs.SelectedItem -and $PrimaryTabs.SelectedItem.Tag) {
			[string]$PrimaryTabs.SelectedItem.Tag
		}
		elseif ($Script:CurrentPrimaryTab) {
			[string]$Script:CurrentPrimaryTab
		}
		else {
			$null
		}
		# Only invalidate the current tab and search results for immediate rebuild.
		# Other tabs carry a stale FilterGeneration and will be evicted lazily.
		if ($targetTab) { & $Script:ClearTabContentCacheScript $targetTab }
		if ($Script:SearchResultsTabTag -and $targetTab -ne $Script:SearchResultsTabTag)
		{
			& $Script:ClearTabContentCacheScript $Script:SearchResultsTabTag
		}
		& $Script:UpdateCategoryFilterListScript -PrimaryTab $targetTab
		& $Script:UpdateSearchResultsTabStateScript
	}

	# Search-only refresh: keeps regular tab caches so returning from search is instant.
	# Only the search-results tab entry is cleared; regular tabs were built without a
	# search filter and remain correct once search is cleared.
	$refreshSearchContent = {
		if ((& $Script:TestGuiRunInProgressScript) -or $Script:FilterUiUpdating) { return }
		if ($Script:AppsModeActive)
		{
			if (Get-Command -Name 'Build-AppsViewCards' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Build-AppsViewCards
			}
			return
		}
		# Only evict search-related category filter cache entries; regular tab
		# entries remain valid since the search query doesn't affect their content.
		if ($Script:CategoryFilterListCache -and $Script:SearchResultsTabTag)
		{
			$staleKeys = @($Script:CategoryFilterListCache.Keys | Where-Object { [string]$_ -and ([string]$_).StartsWith("$($Script:SearchResultsTabTag)|") })
			foreach ($sk in $staleKeys) { [void]$Script:CategoryFilterListCache.Remove($sk) }
		}
		if ($Script:LastCategoryFilterPopulateKey -and $Script:SearchResultsTabTag -and $Script:LastCategoryFilterPopulateKey.StartsWith("$($Script:SearchResultsTabTag)|"))
		{
			$Script:LastCategoryFilterPopulateKey = $null
		}
		if ($Script:TabContentCache -and $Script:SearchResultsTabTag -and $Script:TabContentCache.ContainsKey($Script:SearchResultsTabTag))
		{
			[void]$Script:TabContentCache.Remove($Script:SearchResultsTabTag)
		}
		# When search text is active, use the search sentinel tag so category
		# filters reflect cross-tab results (inline banner replaces the old
		# Search Results tab).  Fall back to the selected real tab otherwise.
		$hasSearchText = -not [string]::IsNullOrWhiteSpace([string]$Script:SearchText)
		$targetTab = if ($hasSearchText) {
			$Script:SearchResultsTabTag
		}
		elseif ($PrimaryTabs -and $PrimaryTabs.SelectedItem -and $PrimaryTabs.SelectedItem.Tag) {
			[string]$PrimaryTabs.SelectedItem.Tag
		}
		elseif ($Script:CurrentPrimaryTab) {
			[string]$Script:CurrentPrimaryTab
		}
		else {
			$null
		}
		& $Script:UpdateCategoryFilterListScript -PrimaryTab $targetTab
		& $Script:UpdateSearchResultsTabStateScript
	}

	# Subscribers: filter state -> sync $Script: variables and refresh UI
	$refreshVisibleContentCapture = $refreshVisibleContent
	foreach ($filterProp in @('RiskFilter', 'CategoryFilter', 'SelectedOnlyFilter', 'HighRiskOnlyFilter', 'RestorableOnlyFilter', 'GamingOnlyFilter'))
	{
		$propCapture = $filterProp
		& $Script:GuiState.Subscribe $filterProp {
			param ($newValue)
			Set-Variable -Name $propCapture -Value $newValue -Scope Script
			& $refreshVisibleContentCapture
		}.GetNewClosure()
	}

	. (Join-Path $Script:GuiExtractedRoot 'SearchFilterHandlers.ps1')

	. (Join-Path $Script:GuiExtractedRoot 'ActionHandlers.ps1')


	# Late-bind function captures for handlers that run from WPF event contexts
	# where Show-TweakGUI's local scope isn't on the call chain.
	$Script:ClearTabContentCacheScript = ${function:Clear-TabContentCache}
	$Script:BuildTabContentScript = ${function:Build-TabContent}
	$Script:UpdateCurrentTabContentScript = ${function:Update-CurrentTabContent}
	$Script:UpdatePrimaryTabVisualsScript = ${function:Update-PrimaryTabVisuals}
	$Script:SaveGuiUndoSnapshotScript = ${function:Save-GuiUndoSnapshot}
	$Script:GetPrimaryTabItemScript = ${function:Get-PrimaryTabItem}
	$Script:ClearGameModePlanScript = ${function:Clear-GameModePlan}
	$Script:SetGameModeProfileScript = ${function:Set-GameModeProfile}
	$Script:ResetGameModeStateScript = ${function:Reset-GameModeState}
	$Script:BuildGameModePlanScript = ${function:Build-GameModePlan}
	$Script:BuildGameModeAdvancedPlanEntriesScript = ${function:Build-GameModeAdvancedPlanEntries}
	$Script:GetGameModeProfileDefaultSelectionScript = (Get-Item function:Get-GameModeProfileDefaultSelection -ErrorAction Stop).ScriptBlock
	$Script:GetGamingPreviewGroupSortOrderScript = (Get-Item function:Get-GamingPreviewGroupSortOrder -ErrorAction Stop).ScriptBlock
	$Script:NewGameModeComparisonPanelScript = ${function:New-GameModeComparisonPanel}
	$Script:SyncGameModeContextStateScript = ${function:Sync-GameModeContextState}
	$Script:SyncGameModePlanToGamingControlsScript = ${function:Sync-GameModePlanToGamingControls}
	$Script:UpdateGameModeStatusTextScript = ${function:Update-GameModeStatusText}
	$Script:ShowThemedDialogScript = ${function:Show-ThemedDialog}
	$Script:ShowSelectedTweakPreviewScript = ${function:Show-SelectedTweakPreview}
	$Script:GetUxRunActionLabelScript = ${function:Get-UxRunActionLabel}
	$Script:UpdateRunPathContextLabelScript = ${function:Update-RunPathContextLabel}
	$Script:InvokeGuiStateTransitionScript = ${function:Invoke-GuiStateTransition}
	$Script:SyncUxActionButtonTextScript = ${function:Sync-UxActionButtonText}
	$Script:ClearInvisibleSelectionStateScript = ${function:Clear-InvisibleSelectionState}
	$Script:UpdateHeaderModeStateTextScript = ${function:Update-HeaderModeStateText}

	# Apply initial theme
	Set-GUITheme -Theme $Script:DarkTheme
	Set-StaticButtonStyle

	# Wire icon content for primary action buttons
	if ($Script:BtnPreviewRun) { Set-GuiButtonIconContent -Button $Script:BtnPreviewRun -IconName 'PreviewRun'      -Text (Get-UxPreviewButtonLabel) -ToolTip (Get-UxPreviewButtonToolTip) }
	if ($Script:BtnRun)        { Set-GuiButtonIconContent -Button $Script:BtnRun        -IconName 'RunTweaks'       -Text (Get-UxRunActionLabel) -ToolTip (Get-UxRunActionToolTip) }
if ($Script:BtnDefaults)   { Set-GuiButtonIconContent -Button $Script:BtnDefaults   -IconName 'RestoreDefaults' -Text (Get-UxLocalizedString -Key 'GuiBtnRestoreAllTweaks' -Fallback 'Restore all tweaks to Windows Defaults') -ToolTip (Get-UxLocalizedString -Key 'GuiActionRestoreDefaultsTooltip' -Fallback 'Restore supported settings to Windows defaults.') }
	if ($BtnLog)        { Set-GuiButtonIconContent -Button $BtnLog        -IconName 'OpenLog'         -Text (Get-UxLocalizedString -Key 'GuiBtnLog' -Fallback 'Open Log') -ToolTip (Get-UxLocalizedString -Key 'GuiActionLogTooltip' -Fallback 'Open the detailed execution log.') }
	if ($Script:BtnStartHere)  { Set-GuiButtonIconContent -Button $Script:BtnStartHere  -IconName 'QuickStart'     -Text (Get-UxStartGuideButtonLabel) -ToolTip (Get-UxLocalizedString -Key 'GuiActionStartGuideTooltip' -Fallback 'Open the getting started guide.') }
	if ($Script:BtnHelp)       { Set-GuiButtonIconContent -Button $Script:BtnHelp       -IconName 'Help'           -Text (Get-UxHelpButtonLabel) -ToolTip (Get-UxLocalizedString -Key 'GuiActionOpenHelpTooltip' -Fallback 'Open help and usage guidance.') }
	if ($BtnLanguage)   { Set-GuiButtonIconContent -Button $BtnLanguage   -IconName 'Language'       -Text (Get-UxLocalizedString -Key 'GuiBtnLanguage' -Fallback 'Language') -ToolTip (Get-UxLocalizedString -Key 'GuiBtnLanguageTooltip' -Fallback 'Change language') -IconSize 14 -Gap 6 -TextFontSize 11 }
	if ($Script:BtnClearSearch) { Set-GuiButtonIconContent -Button $Script:BtnClearSearch -IconName 'Clear'         -Text (Get-UxLocalizedString -Key 'GuiBtnClearSearch' -Fallback 'Clear') -ToolTip (Get-UxLocalizedString -Key 'GuiActionClearSearchTooltip' -Fallback 'Clear search text and active filters.') -IconSize 14 -Gap 6 -TextFontSize 11 }
	if ($Script:BtnApplyQueuedActions) { Set-GuiButtonIconContent -Button $Script:BtnApplyQueuedActions -IconName 'RunTweaks' -Text (Get-UxLocalizedString -Key 'GuiAppsApplyQueued' -Fallback 'Apply Changes') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsApplyQueuedTip' -Fallback 'Apply queued install and uninstall changes.') -IconSize 14 -Gap 6 -TextFontSize 11 }
	if ($Script:BtnClearQueuedActions) { Set-GuiButtonIconContent -Button $Script:BtnClearQueuedActions -IconName 'Clear' -Text (Get-UxLocalizedString -Key 'GuiAppsClearQueued' -Fallback 'Clear Changes') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsClearQueuedTip' -Fallback 'Clear all queued app changes without applying them.') -IconSize 14 -Gap 6 -TextFontSize 11 }
	if ($Script:BtnScanInstalledApps) { Set-GuiButtonIconContent -Button $Script:BtnScanInstalledApps -IconName 'Search' -Text (Get-UxLocalizedString -Key 'GuiAppsScanInstalledApps' -Fallback 'Scan Installed Apps') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsScanInstalledAppsTip' -Fallback 'Scan installed apps to update install status.') -IconSize 14 -Gap 6 -TextFontSize 11 }

	Set-StaticControlTabOrder
	Set-GuiActionButtonsEnabled -Enabled $true

	$restoredGuiSession = Restore-GuiSessionState
	Update-GuiLocalizationStrings
	Update-PrimaryTabHeaders
	if ($TxtLanguageState -and -not [string]::IsNullOrWhiteSpace([string]$Script:SelectedLanguage))
	{
		$TxtLanguageState.Text = ([string]$Script:SelectedLanguage).ToUpperInvariant()
	}
	Sync-UxActionButtonText
	if ($restoredGuiSession)
	{
		Set-GuiStatusText -Text (Get-UxLocalizedString -Key 'GuiLogSessionRestoredPreviousState' -Fallback '') -Tone 'accent'
	}

	$Script:DownloadStartEvent = {
		$uri = 'https://github.com/sdmanson8/Baseline/archive/refs/heads/main.zip'
		$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_Update.zip'
		$downloadCommand = Get-GuiFunctionCapture -Name 'Start-BaselineDownload'
		if ($downloadCommand)
		{
			& $downloadCommand -Uri $uri -DestinationPath $tempPath
		}
		else
		{
			LogWarn 'Start-BaselineDownload not available; update download action was skipped.'
		}
	}.GetNewClosure()

	$Script:DownloadExtractEvent = {
		if ($TxtDownloadProgressLabel) { $TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusExtractingArchive' -Fallback 'Extracting archive...') }
		if ($BtnDownloadYes) { $BtnDownloadYes.IsEnabled = $false }
		if ($BtnDownloadNo) { $BtnDownloadNo.IsEnabled = $false }

		$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_Update.zip'
		$extractPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_New'

		Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

		if ($TxtDownloadProgressLabel) { $TxtDownloadProgressLabel.Text = (Get-UxLocalizedString -Key 'GuiStatusReadyToRestart' -Fallback 'Ready to restart!') }

		# Add your custom bootstrap/overwrite logic here to finalize the update
	}.GetNewClosure()

	if ($BtnDownloadYes)
	{
		$BtnDownloadYes.Add_Click($Script:DownloadStartEvent)
	}
	if ($BtnDownloadNo)
	{
		$BtnDownloadNo.Add_Click({
			& $hideBaselineUpdateOverlayCommand
		}.GetNewClosure())
	}

	# Resolve all first-run dependencies ONCE, here, while module scope is valid.
	$firstRunDialogDispatcher = if ($Form -and $Form.Dispatcher) { $Form.Dispatcher } else { $null }
	$closeLoadingSplashBlock = (Get-Item function:Close-LoadingSplashWindow -ErrorAction Stop).ScriptBlock
	$hideConsoleWindowBlock  = (Get-Item function:Hide-ConsoleWindow -ErrorAction Stop).ScriptBlock
	$showThemedDialogBlock   = (Get-Item function:Show-ThemedDialog -ErrorAction Stop).ScriptBlock
	$showWelcomeDialogBlock  = (Get-Item function:Show-FirstRunWelcomeDialog -ErrorAction Stop).ScriptBlock
	$completeWelcomeBlock    = (Get-Item function:Complete-GuiFirstRunWelcome -ErrorAction Stop).ScriptBlock
	$firstRunTheme           = $Script:CurrentTheme
	$firstRunApplyButtonChrome = ${function:Set-ButtonChrome}
	$firstRunOwnerWindow     = $Form
	$firstRunUseDarkMode     = ($Script:CurrentThemeName -eq 'Dark')

	if ($closeLoadingSplashBlock -isnot [scriptblock]) { throw "Close-LoadingSplashWindow did not resolve to a scriptblock." }
	if ($hideConsoleWindowBlock  -isnot [scriptblock]) { throw "Hide-ConsoleWindow did not resolve to a scriptblock." }
	if ($showThemedDialogBlock   -isnot [scriptblock]) { throw "Show-ThemedDialog did not resolve to a scriptblock." }
	if ($showWelcomeDialogBlock  -isnot [scriptblock]) { throw "Show-FirstRunWelcomeDialog did not resolve to a scriptblock." }
	if ($completeWelcomeBlock    -isnot [scriptblock]) { throw "Complete-GuiFirstRunWelcome did not resolve to a scriptblock." }

	$firstRunShowHelpDialogCommand = Get-Command 'Show-HelpDialog' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$firstRunSetGuiPresetSelectionCommand = Get-Command 'Set-GuiPresetSelection' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$firstRunSetGuiStatusTextCommand = Get-Command 'Set-GuiStatusText' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$getRecommendedPresetNameCommand = Get-Command 'Get-UxRecommendedPresetName' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1
	$getFirstRunMarkerPathCommand = Get-Command 'Get-GuiFirstRunWelcomeMarkerPath' -CommandType Function -ErrorAction SilentlyContinue | Select-Object -First 1

	if (-not $firstRunSetGuiPresetSelectionCommand)   { throw "Set-GuiPresetSelection not found." }
	if (-not $firstRunSetGuiStatusTextCommand)        { throw "Set-GuiStatusText not found." }
	if (-not $getRecommendedPresetNameCommand){ throw "Get-UxRecommendedPresetName not found." }
	if (-not $getFirstRunMarkerPathCommand)   { throw "Get-GuiFirstRunWelcomeMarkerPath not found." }

	$firstRunMarkerPath = & $getFirstRunMarkerPathCommand
	if ([string]::IsNullOrWhiteSpace($firstRunMarkerPath))
	{
		throw "Get-GuiFirstRunWelcomeMarkerPath returned an empty path."
	}

	$firstRunMarkerDirectory = Split-Path -Path $firstRunMarkerPath -Parent
	if ([string]::IsNullOrWhiteSpace($firstRunMarkerDirectory))
	{
		throw "First-run marker directory could not be derived from path: $firstRunMarkerPath"
	}

	if (-not (Test-Path -LiteralPath $firstRunMarkerDirectory))
	{
		$null = New-Item -ItemType Directory -Path $firstRunMarkerDirectory -Force -ErrorAction Stop
	}

	$shouldShowFirstRunWelcome = -not (Test-Path -LiteralPath $firstRunMarkerPath)
	$firstRunRecommendedPreset = & $getRecommendedPresetNameCommand
	$firstRunPrimaryActionLabel = Get-UxFirstRunPrimaryActionLabel
	$firstRunWelcomeMessage = Get-UxFirstRunWelcomeMessage
	$firstRunDialogTitle = Get-UxFirstRunDialogTitle
	$firstRunPresetLoadedStatusText = Get-UxPresetLoadedStatusText -PresetName $firstRunRecommendedPreset

	$startupPresentationCompleted = $false
	Register-GuiEventHandler -Source $Form -EventName 'ContentRendered' -Handler ({
		if ($startupPresentationCompleted) { return }
		$startupPresentationCompleted = $true

		# Run initial adaptive tab layout check now that the window has its actual size
		if ($Script:AdaptiveTabLayoutScript) { & $Script:AdaptiveTabLayoutScript }

		try
		{
			$loadingSplash = Get-Variable -Name 'LoadingSplash' -Scope Global -ValueOnly -ErrorAction SilentlyContinue
			if ($loadingSplash)
			{
				$null = & $closeLoadingSplashBlock -Splash $loadingSplash -DisposeResources
				$Global:LoadingSplash = $null
			}
		}
		catch
		{
			$null = $_
		}

		try
		{
			& $hideConsoleWindowBlock
		}
		catch
		{
			$null = $_
		}

		if (Get-Command -Name 'Update-WindowMinWidthFromHeader' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-WindowMinWidthFromHeader
		}

		if (-not $shouldShowFirstRunWelcome)
		{
			return
		}

		# Recheck concrete marker path in case another path created it during startup.
		if (Test-Path -LiteralPath $firstRunMarkerPath)
		{
			return
		}

		try
		{
			$openHelpAction = {
				if ($firstRunShowHelpDialogCommand)
				{
					if ($firstRunDialogDispatcher -and $firstRunDialogDispatcher.PSObject.Methods['BeginInvoke'])
					{
						$showHelpDialogAction = {
							& $firstRunShowHelpDialogCommand
						}.GetNewClosure()
						$null = $firstRunDialogDispatcher.BeginInvoke(
							[System.Action]$showHelpDialogAction,
							[System.Windows.Threading.DispatcherPriority]::ApplicationIdle
						)
					}
					else
					{
						& $firstRunShowHelpDialogCommand
					}
				}
			}.GetNewClosure()

			$chooseRecommendedPresetAction = {
				$presetToApply = $firstRunRecommendedPreset
				& $firstRunSetGuiPresetSelectionCommand -PresetName $presetToApply
				& $firstRunSetGuiStatusTextCommand -Text $firstRunPresetLoadedStatusText -Tone 'accent'
			}.GetNewClosure()

			$guidedSetupWizardItem = Get-Item function:Show-GuidedSetupWizard -ErrorAction SilentlyContinue
			$guidedSetupWizardBlock = if ($guidedSetupWizardItem) { $guidedSetupWizardItem.ScriptBlock } else { $null }
			$guidedSetupAction = if ($guidedSetupWizardBlock)
			{
				{
					& $guidedSetupWizardBlock `
						-ShowThemedDialogCapture $showThemedDialogBlock `
						-SetGuiPresetSelectionAction { param($PresetName) & $firstRunSetGuiPresetSelectionCommand -PresetName $PresetName } `
						-SetGuiStatusTextAction { param($Text, $Tone) & $firstRunSetGuiStatusTextCommand -Text $Text -Tone $Tone } `
						-Theme $firstRunTheme `
						-ApplyButtonChrome $firstRunApplyButtonChrome `
						-OwnerWindow $firstRunOwnerWindow `
						-UseDarkMode $firstRunUseDarkMode
				}.GetNewClosure()
			}
			else { $null }

			$dialogResult = & $showWelcomeDialogBlock `
				-RecommendedPreset $firstRunRecommendedPreset `
				-PrimaryActionLabel $firstRunPrimaryActionLabel `
				-WelcomeMessage $firstRunWelcomeMessage `
				-DialogTitle $firstRunDialogTitle `
				-ShowThemedDialogCapture $showThemedDialogBlock `
				-OpenHelpAction $openHelpAction `
				-ChooseRecommendedPresetAction $chooseRecommendedPresetAction `
				-GuidedSetupAction $guidedSetupAction `
				-Theme $firstRunTheme `
				-ApplyButtonChrome $firstRunApplyButtonChrome `
				-OwnerWindow $firstRunOwnerWindow `
				-UseDarkMode $firstRunUseDarkMode

			if ($dialogResult)
			{
				# Do NOT call Complete-GuiFirstRunWelcome here.
				# Write the marker directly using the already-validated concrete path.
				if (-not (Test-Path -LiteralPath $firstRunMarkerDirectory))
				{
					$null = New-Item -ItemType Directory -Path $firstRunMarkerDirectory -Force -ErrorAction Stop
				}

				Set-Content -LiteralPath $firstRunMarkerPath -Value ([DateTime]::UtcNow.ToString('o')) -Encoding UTF8 -Force
			}
		}
		catch
		{
			throw "First-run welcome failed: $($_.Exception.Message)"
		}
	}.GetNewClosure()) | Out-Null

	# Activate the main window only when it is about to be shown.
	$Form.ShowActivated = $true
	Initialize-WpfWindowForeground -Window $Form

	# Set Preview Run as the default-focused action so it feels like the natural next step.
	if ($BtnPreviewRun) { $BtnPreviewRun.Focusable = $true }

	# Show the GUI
	try
	{
		[void]([System.Windows.Window]$Form).ShowDialog()
	}
	catch
	{
		$errorLines = New-Object System.Collections.Generic.List[string]
		[void]$errorLines.Add("Failed to open WPF window. Form type: $($Form.GetType().FullName)")
		[void]$errorLines.Add("Apartment state: $([System.Threading.Thread]::CurrentThread.GetApartmentState())")
		[void]$errorLines.Add("Error: $($_.Exception.GetType().FullName): $($_.Exception.Message)")

		$innerException = $_.Exception.InnerException
		if ($innerException)
		{
			[void]$errorLines.Add("Inner exception: $($innerException.GetType().FullName): $($innerException.Message)")
			if (-not [string]::IsNullOrWhiteSpace([string]$innerException.StackTrace))
			{
				[void]$errorLines.Add("Inner stack trace:`n$($innerException.StackTrace.Trim())")
			}
		}

		throw ($errorLines -join [Environment]::NewLine)
	}

	LogInfo (Get-UxBilingualLocalizedString -Key 'GuiLogGuiClosed' -Fallback 'GUI closed')

	# Write local-only session summary to the log file at end of GUI session
	Write-SessionSummaryToLog
}
#endregion GUI Builder

#region Report-TweakProgress
<#
	.SYNOPSIS
	Reports sub-task progress from inside a tweak function back to the GUI progress bar.

	.DESCRIPTION
	Intended to be called from tweak functions that run in the background runspace during a
	GUI-mode execution.  The function enqueues a '_SubProgress' message into $Global:GUIRunState
	(set automatically by the GUI run loop).  The DispatcherTimer on the UI thread picks it up
	and updates the secondary progress bar below the main tweak progress bar.

	If the script is not running in GUI mode or $Global:GUIRunState is not set the call is a
	no-op, so it is safe to leave in tweak functions even when they are run headlessly.

	.PARAMETER Action
	Short label shown next to the percentage, e.g. "Downloading WinGet installer".

	.PARAMETER Completed
	Number of units completed.  Used together with -Total.

	.PARAMETER Total
	Total number of units.  When provided with -Completed the bar fills proportionally.

	.PARAMETER Percent
	0-100 percentage.  Use this instead of -Completed/-Total when only a percentage is available.

	.EXAMPLE
	# Inside a tweak function that downloads a file in chunks:
	for ($i = 0; $i -lt $chunks.Count; $i++)
	{
	    Write-TweakProgress -Action "Downloading installer" -Completed $i -Total $chunks.Count
	    # ... download chunk ...
	}
#>
<#
    .SYNOPSIS
    Internal function Write-TweakProgress.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Write-TweakProgress
{
	[CmdletBinding()]
	param (
		[string]$Action    = $null,
		[int]   $Completed = 0,
		[int]   $Total     = 0,
		[int]   $Percent   = -1
	)

	if (-not $Global:GUIMode) { return }
	# $GUIRunState is the ConcurrentQueue injected directly by the GUI run loop via
	# SessionStateProxy.SetVariable - it is not a global, just a session variable.
	$queue = Get-Variable -Name 'GUIRunState' -ValueOnly -ErrorAction Ignore
	if (-not $queue) { return }

	$queue.Enqueue([PSCustomObject]@{
		Kind      = '_SubProgress'
		Action    = $Action
		Completed = $Completed
		Total     = $Total
		Percent   = $Percent
	})
}
#endregion Report-TweakProgress

Set-Alias -Name Report-TweakProgress -Value Write-TweakProgress -Scope Script
Export-ModuleMember -Function 'Show-TweakGUI', 'Write-TweakProgress' -Alias 'Report-TweakProgress'
