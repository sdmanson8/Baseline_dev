using module ..\Logging.psm1
using module ..\SharedHelpers.psm1

# Appx cmdlets fail with "The type initializer for '<Module>' threw an exception"
# in the minimal embedded runspace the Baseline launcher creates. Fall back to the
# WinRT PackageManager so presence checks still work. Returns $null when neither
# path produces a conclusive answer (caller should treat that as "unknown", not
# "missing", to avoid a false "Windows is broken" warning).
function Test-BaselineAppxPackagePresence
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]
		$Name
	)

	try
	{
		Import-Module Appx -DisableNameChecking -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
		$package = Get-AppxPackage -Name $Name -WarningAction SilentlyContinue -ErrorAction Stop
		return [bool]$package
	}
	catch
	{
		# Fall through to WinRT probe.
	}

	try
	{
		$packageManager = [Windows.Management.Deployment.PackageManager, Windows.Web, ContentType=WindowsRuntime]::new()
		$match = $packageManager.FindPackages() | Where-Object { $_.Id.Name -eq $Name } | Select-Object -First 1
		return [bool]$match
	}
	catch
	{
		return $null
	}
}

#region InitialActions
<#
	.SYNOPSIS
	Run the shared startup checks and runtime setup used before applying tweaks.

	.DESCRIPTION
	Prepares the Baseline session by clearing previous errors, unblocking
	script files, setting network and compiler prerequisites, and initializing
	the runtime helpers used by other region modules.

	.PARAMETER Warning
	Show the warning prompt during startup checks.

	.EXAMPLE
	InitialActions
#>
function InitialActions
{
	param
	(
		[Parameter(Mandatory = $false)]
		[switch]
		$Warning
	)

	$osInfo = Get-OSInfo
	$osName = $osInfo.OSName
	$displayVersion = Get-BaselineDisplayVersion

	$startupLabel = Get-BaselineStartupLabel -OSName $osName -DisplayVersion $displayVersion

	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_Starting' -Fallback 'Starting {0}' -FormatArgs @($startupLabel)) -addGap

	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_BeginningInitialChecks' -Fallback 'Beginning Initial Checks:')

	# Clear the $Error variable
	$Global:Error.Clear()

	# Unblock all files in the script folder by removing the Zone.Identifier alternate data stream with a value of "3"
	Get-ChildItem -Path $PSScriptRoot\..\ -File -Recurse -Force | Unblock-File

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

	# Progress bar can significantly impact cmdlet performance
	# https://github.com/PowerShell/PowerShell/issues/2138
	$Script:ProgressPreference = "SilentlyContinue"

	# https://github.com/PowerShell/PowerShell/issues/21070
	$Script:CompilerParameters = [System.CodeDom.Compiler.CompilerParameters]::new("System.dll")
	$Script:CompilerParameters.TempFiles = [System.CodeDom.Compiler.TempFileCollection]::new($env:TEMP, $false)
	$Script:CompilerParameters.GenerateInMemory = $true
	$Signature = @{
		Namespace          = "WinAPI"
		Name               = "GetStrings"
		Language           = "CSharp"
		UsingNamespace     = "System.Text"
		CompilerParameters = $CompilerParameters
		MemberDefinition   = @"
[DllImport("kernel32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr GetModuleHandle(string lpModuleName);

[DllImport("user32.dll", CharSet = CharSet.Auto)]
internal static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);

public static string GetString(uint strId)
{
	IntPtr intPtr = GetModuleHandle("shell32.dll");
	StringBuilder sb = new StringBuilder(255);
	LoadString(intPtr, strId, sb, sb.Capacity);
	return sb.ToString();
}

// Get string from other DLLs
[DllImport("shlwapi.dll", CharSet=CharSet.Unicode)]
private static extern int SHLoadIndirectString(string pszSource, StringBuilder pszOutBuf, int cchOutBuf, string ppvReserved);

public static string GetIndirectString(string indirectString)
{
	try
	{
		int returnValue;
		StringBuilder lptStr = new StringBuilder(1024);
		returnValue = SHLoadIndirectString(indirectString, lptStr, 1024, null);

		if (returnValue == 0)
		{
			return lptStr.ToString();
		}
		else
		{
			return null;
			// return "SHLoadIndirectString Failure: " + returnValue;
		}
	}
	catch // (Exception ex)
	{
		return null;
		// return "Exception Message: " + ex.Message;
	}
}
"@
	}
	if (-not ("WinAPI.GetStrings" -as [type]))
	{
		Add-Type @Signature
	}

	$Signature = @{
		Namespace          = "WinAPI"
		Name               = "ForegroundWindow"
		Language           = "CSharp"
		CompilerParameters = $CompilerParameters
		MemberDefinition   = @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
"@
	}

	if (-not ("WinAPI.ForegroundWindow" -as [type]))
	{
		Add-Type @Signature | Out-Null
	}

	# Checking whether the logged-in user is an admin
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingAdmin' -Fallback 'Checking whether the logged-in user is an admin')
	$CurrentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name | Split-Path -Leaf
	$LoginUserName = $null
	try
	{
		$LoginUserName = (Get-CimInstance -ClassName Win32_Process -Filter "name='explorer.exe'" | Invoke-CimMethod -MethodName GetOwner | Select-Object -First 1).User
	}
	catch
	{
		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_UnableToDetermineLoggedInUserFromExplorer' -Fallback 'Unable to determine the logged-in user from explorer.exe: {0}' -FormatArgs @($_.Exception.Message))
	}

	if ($CurrentUserName -ne $LoginUserName)
	{
		LogWarning (Get-BaselineBilingualString -Key 'LoggedInUserNotAdmin' -Fallback "The logged-on user doesn't have admin rights.")
	}

	$IsAdmin = ([System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

	# Checking whether the script was run in PowerShell ISE or VS Code
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingHostEnvironment' -Fallback 'Checking whether the script was run in PowerShell ISE or VS Code')
	if (Test-BaselineUnsupportedHost -HostName $Host.Name -TermProgram $env:TERM_PROGRAM)
	{
		LogWarning (Get-BaselineBilingualString -Key 'UnsupportedHost' -Fallback "The script doesn't support running via {0}." -FormatArgs @($Host.Name.Replace('Host', '')))
	}

	# Checking whether Windows was broken by 3rd party harmful tweakers, trojans, or custom Windows images
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingWindowsIntegrity' -Fallback 'Checking whether Windows was broken by 3rd party harmful tweakers, trojans, or custom Windows images')
	$Tweakers = @{
		# https://github.com/Sycnex/Windows10Debloater
		Windows10Debloater  = "$env:SystemDrive\Temp\Windows10Debloater"
		# https://github.com/Fs00/Win10BloatRemover
		Win10BloatRemover   = "$env:TEMP\.net\Win10BloatRemover"
		# https://github.com/arcadesdude/BRU
		"Bloatware Removal" = "$env:SystemDrive\BRU\Bloatware-Removal*.log"
		# https://www.youtube.com/GHOSTSPECTRE
		"Ghost Toolbox"     = "$env:SystemRoot\System32\migwiz\dlmanifests\run.ghost.cmd"
		# https://win10tweaker.ru
		"Win 10 Tweaker"    = "HKCU:\Software\Win 10 Tweaker"
		# https://boosterx.ru
		BoosterX            = "$env:ProgramFiles\GameModeX\GameModeX.exe"
		# https://forum.ru-board.com/topic.cgi?forum=5&topic=14285&start=400#11
		"Defender Control"  = "$env:APPDATA\Defender Control"
		# https://forum.ru-board.com/topic.cgi?forum=5&topic=14285&start=260#12
		"Defender Switch"   = "$env:ProgramData\DSW"
		# https://revi.cc/revios/download
		"Revision Tool"     = "${env:ProgramFiles(x86)}\Revision Tool"
		# https://www.youtube.com/watch?v=L0cj_I6OF2o
		"WinterOS Tweaker"  = "$env:SystemRoot\WinterOS*"
		# https://github.com/ThePCDuke/WinCry
		WinCry              = "$env:SystemRoot\TempCleaner.exe"
		# https://www.youtube.com/watch?v=5NBqbUUB1Pk
		WinClean             = "$env:ProgramFiles\WinClean Plus Apps"
		# https://github.com/Atlas-OS/Atlas
		AtlasOS              = "$env:SystemRoot\AtlasModules"
		# https://x.com/NPKirbyy
		KirbyOS              = "$env:ProgramData\KirbyOS"
		# https://pc-np.com
		PCNP                 = "HKCU:\Software\PCNP"
	}
	foreach ($Tweaker in $Tweakers.Keys)
	{
		if (Test-Path -Path $Tweakers[$Tweaker])
		{
			if ($Tweakers[$Tweaker] -eq "HKCU:\Software\Win 10 Tweaker")
			{
				LogWarning (Get-BaselineBilingualString -Key 'Win10TweakerWarning' -Fallback 'Windows has been infected with a trojan via a Win 10 Tweaker backdoor. Reinstall Windows using only a genuine ISO image.')

			}
			LogWarning (Get-BaselineBilingualString -Key 'TweakerWarning' -Fallback 'The Windows stability may have been compromised by using {0}. Reinstall Windows using only a genuine ISO image.' -FormatArgs @($Tweaker))
		}
	}

		# Checking whether Windows was broken by 3rd party harmful tweakers, trojans, or custom Windows images
		# These probes are advisory only and must never block startup on restricted or unsupported systems.
		$MuiCacheProperties = @()
		if (Test-Path -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache")
		{
			try
			{
				$MuiCacheProperties = (Get-ItemProperty -Path "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -ErrorAction SilentlyContinue).PSObject.Properties
			}
			catch
			{
				$MuiCacheProperties = @()
			}
		}

		$InvokeOptionalProbe = {
			param([scriptblock]$ScriptBlock)

			try
			{
				& $ScriptBlock
			}
			catch
			{
				$null
			}
		}

		$AutoSettingsPS = & $InvokeOptionalProbe {
			Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" | Where-Object -FilterScript {$_.Property -match "AutoSettingsPS"}
		}
		$Flibustier = & $InvokeOptionalProbe {
			Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\.NETFramework\Performance" -Name *flibustier
		}
		$Winpilot = & $InvokeOptionalProbe {
			$MuiCacheProperties | Where-Object -FilterScript {$_.Value -eq "Winpilot"}
		}
		$Bloatynosy = & $InvokeOptionalProbe {
			$MuiCacheProperties | Where-Object -FilterScript {$_.Value -eq "BloatynosyNue"}
		}
		$XdAntiSpy = & $InvokeOptionalProbe {
			$MuiCacheProperties | Where-Object -FilterScript {$_.Value -eq "xd-AntiSpy"}
		}
		$ModernTweaker = & $InvokeOptionalProbe {
			$MuiCacheProperties | Where-Object -FilterScript {$_.Value -eq "Modern Tweaker"}
		}
		$KernelOS = & $InvokeOptionalProbe {
			Get-CimInstance -Namespace root/CIMV2/power -ClassName Win32_PowerPlan | Where-Object -FilterScript {$_.ElementName -match "KernelOS"}
		}
		$ChlorideOS = & $InvokeOptionalProbe {
			Get-Volume | Where-Object -FilterScript {$_.FileSystemLabel -eq "ChlorideOS"}
		}

		$Tweakers = @{
			# https://forum.ru-board.com/topic.cgi?forum=62&topic=30617&start=1600#14
			AutoSettingsPS   = "$AutoSettingsPS"
			# Flibustier custom Windows image
			Flibustier       = "$Flibustier"
			# https://github.com/builtbybel/Winpilot
			Winpilot         = "$Winpilot"
			# https://github.com/builtbybel/Winpilot
			Bloatynosy       = "$Bloatynosy"
			# https://github.com/builtbybel/xd-AntiSpy
			"xd-AntiSpy"     = "$XdAntiSpy"
			# https://forum.ru-board.com/topic.cgi?forum=5&topic=50519
			"Modern Tweaker" = "$ModernTweaker"
			# https://discord.com/invite/kernelos
			KernelOS         = "$KernelOS"
			# https://discord.com/invite/9ZCgxhaYV6
			ChlorideOS       = "$ChlorideOS"
		}
	foreach ($Tweaker in $Tweakers.Keys)
	{
		if ($Tweakers[$Tweaker])
		{
			LogWarning (Get-BaselineBilingualString -Key 'TweakerWarning' -Fallback 'The Windows stability may have been compromised by using {0}. Reinstall Windows using only a genuine ISO image.' -FormatArgs @($Tweaker))
		}
	}

	if ($IsAdmin)
	{
		# Remove harmful blocked DNS domains list from https://github.com/schrebra/Windows.10.DNS.Block.List
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_RemovingBlockedDnsDomainsList' -Fallback 'Remove harmful blocked DNS domains list from {0}' -FormatArgs @('https://github.com/schrebra/Windows.10.DNS.Block.List'))
		Get-NetFirewallRule -DisplayName Block.MSFT* -ErrorAction Ignore | Remove-NetFirewallRule | Out-Null

		# Remove firewalled IP addresses that block Microsoft recourses added by harmful tweakers
		# https://wpd.app
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_RemovingBlockedMicrosoftIpAddresses' -Fallback 'Remove firewalled IP addresses that block Microsoft recourses added by harmful tweakers')
		Get-NetFirewallRule -DisplayName "Blocker MicrosoftTelemetry*", "Blocker MicrosoftExtra*", "windowsSpyBlocker*" -ErrorAction Ignore | Remove-NetFirewallRule | Out-Null

		# Remove IP addresses from hosts file that block Microsoft resources added by WindowsSpyBlocker
		# https://github.com/crazy-max/WindowsSpyBlocker
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_RemovingHostsEntries' -Fallback 'Remove IP addresses from hosts file that block Microsoft resources added by WindowsSpyBlocker')
		try
		{
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingGitHubAlive' -Fallback 'Checking whether {0} is alive' -FormatArgs @('https://github.com'))
			$Parameters = @{
				Uri              = "https://github.com"
				Method           = "Head"
				DisableKeepAlive = $true
				UseBasicParsing  = $true
				TimeoutSec       = 15
			}
			(Invoke-WebRequest @Parameters).StatusDescription | Out-Null

			Clear-Variable -Name IPArray -ErrorAction Ignore

			# https://github.com/crazy-max/WindowsSpyBlocker/tree/master/data/hosts
			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$extra = (Invoke-WebRequest @Parameters).Content

			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra_v6.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$extra_v6 = (Invoke-WebRequest @Parameters).Content

			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$spy = (Invoke-WebRequest @Parameters).Content

			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy_v6.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$spy_v6 = (Invoke-WebRequest @Parameters).Content

			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/update.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$update = (Invoke-WebRequest @Parameters).Content

			$Parameters = @{
				Uri             = "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/update_v6.txt"
				UseBasicParsing = $true
				TimeoutSec      = 15
			}
			$update_v6 = (Invoke-WebRequest @Parameters).Content

			$IPArray = Get-BaselineHostsCandidateEntries -Content (@($extra, $extra_v6, $spy, $spy_v6, $update, $update_v6) -split "`r?`n")

			# Validate downloaded hosts entries for integrity
			$TotalLines = @($IPArray).Count
			$InvalidLines = @($IPArray | Where-Object { -not (Test-BaselineHostsEntry -Line $_) })
			$ValidLines = @($IPArray | Where-Object { Test-BaselineHostsEntry -Line $_ })

			if ($InvalidLines.Count -gt 0)
			{
				foreach ($BadLine in $InvalidLines)
				{
					LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_InvalidHostsEntrySkipped' -Fallback 'Invalid hosts entry skipped: {0}' -FormatArgs @($BadLine))
				}
			}

			if (Test-BaselineHostsDownloadSuspect -InvalidCount $InvalidLines.Count -TotalCount $TotalLines)
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_MoreThanHalfHostsEntriesFailedValidation' -Fallback 'More than 50% of downloaded hosts entries failed validation ({0}/{1}). Downloaded data may be corrupted or tampered. Skipping WindowsSpyBlocker hosts cleanup.' -FormatArgs @($InvalidLines.Count, $TotalLines))
				return
			}

			$IPArray = $ValidLines

			$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
			$HostsContent = Get-Content -Path $HostsPath -Encoding Default -Force

			$MatchedHostsEntries = $HostsContent | Where-Object {
				$Line = $_.Trim()
				$Line -and
				(-not $Line.StartsWith("#")) -and
				($IPArray | Select-String -SimpleMatch -Pattern $Line -Quiet)
			}

			if ($MatchedHostsEntries)
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_WindowsSpyBlockerEntriesDetectedInHostsFile' -Fallback 'WindowsSpyBlocker entries detected in hosts file')

				$FilteredHosts = $HostsContent | Where-Object {
					$Line = $_.Trim()

					if (-not $Line -or $Line.StartsWith("#"))
					{
						return $true
					}

					-not ($IPArray | Select-String -SimpleMatch -Pattern $Line -Quiet)
				}

				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CleaningHostsFile' -Fallback 'Cleaning hosts file')
				$FilteredHosts | Set-Content -Path $HostsPath -Encoding Default -Force

				Start-Process -FilePath notepad.exe -ArgumentList $HostsPath | Out-Null
			}
		}
		catch [System.Net.WebException]
		{
			LogWarning (((Get-BaselineBilingualString -Key 'NoResponse' -Fallback 'A connection could not be established with {0}.') -f 'https://github.com') + ' ' + (Get-BaselineBilingualString -Key 'Bootstrap_SkippingWindowsSpyBlockerHostsCleanup' -Fallback 'Skipping WindowsSpyBlocker hosts cleanup.'))
		}
	}
	else
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingFirewallHostsRemediationNotElevated' -Fallback 'Skipping firewall and hosts remediation because Baseline is not running elevated.')
	}

	# Checking whether Windows Feature Experience Pack was removed by harmful tweakers
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingFeatureExperiencePack' -Fallback 'Checking whether Windows Feature Experience Pack was removed by harmful tweakers')
	if ($osInfo.IsWindowsServer)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_FeatureExperiencePackNotApplicable' -Fallback 'Windows Feature Experience Pack check is not applicable on Windows Server.')
	}
	else
	{
		$featurePackPresent = Test-BaselineAppxPackagePresence -Name 'MicrosoftWindows.Client.CBS'
		if ($featurePackPresent -eq $false)
		{
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Windows Feature Experience Pack'))
		}
	}

	# Checking whether EventLog service is running
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingEventLogService' -Fallback 'Checking whether EventLog service is running')
	if ((Get-Service -Name EventLog).Status -eq "Stopped")
	{
		LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @([WinAPI.GetStrings]::GetString(22029)))
	}

	# Checking whether the Microsoft Store being an important system component was removed
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingMicrosoftStore' -Fallback 'Checking whether the Microsoft Store being an important system component was removed')
	if ($osInfo.IsWindowsServer)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_MicrosoftStoreNotApplicable' -Fallback 'Microsoft Store presence check is not applicable on Windows Server.')
	}
	else
	{
		$storePresent = Test-BaselineAppxPackagePresence -Name 'Microsoft.WindowsStore'
		if ($storePresent -eq $false)
		{
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Store'))
		}
	}

	#region Defender checks
	# Checking whether necessary Microsoft Defender components exists
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingDefenderComponents' -Fallback 'Checking whether necessary Microsoft Defender components exists')
	$Files = if ($osInfo.IsWindowsServer)
	{
		@(
			"$env:SystemRoot\System32\smartscreen.exe",
			"$env:SystemRoot\System32\CompatTelRunner.exe"
		)
	}
	else
	{
		@(
			"$env:SystemRoot\System32\smartscreen.exe",
			"$env:SystemRoot\System32\SecurityHealthSystray.exe",
			"$env:SystemRoot\System32\CompatTelRunner.exe"
		)
	}
	foreach ($File in $Files)
	{
		if (-not (Test-Path -Path $File))
		{
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @($File))
		}
	}

	# Checking whether Windows Security Settings page was hidden from UI
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingSecurityPageVisibility' -Fallback 'Checking whether Windows Security Settings page was hidden from UI')
	if ([Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", "SettingsPageVisibility", $null) -match "hide:windowsdefender")
	{
		LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
	}

	# Checking whether WMI is corrupted
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingWmi' -Fallback 'Checking whether WMI is corrupted')
	if ($osInfo.IsWindowsServer)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingDefenderWmiHealthCheckOnWindowsServer' -Fallback 'Skipping Microsoft Defender WMI health check on Windows Server.')
	}
	else
	{
		try
		{
			Get-CimInstance -ClassName MSFT_MpComputerStatus -Namespace root/Microsoft/Windows/Defender -ErrorAction Stop | Out-Null
		}
		catch [Microsoft.Management.Infrastructure.CimException]
		{
			Remove-HandledErrorRecord -ErrorRecord $_
			LogWarning (Get-BaselineBilingualString -Key 'GuiPreflightWMIFailed' -Fallback 'CIM/WMI query failed: {0}' -FormatArgs @($_.Exception.Message))
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
		}
	}

	# Check Microsoft Defender state
	$SecurityCenterProducts = @()
	$SecurityCenterAvailable = $false
	$Script:DefenderServices = $false
	$Script:DefenderProductState = $false
	$Script:AntiSpywareEnabled = $false
	$Script:RealtimeMonitoringEnabled = $false
	$Script:BehaviorMonitoringEnabled = $false

	if ($osInfo.IsWindowsServer)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingSecurityCenterChecksOnWindowsServer' -Fallback 'Skipping SecurityCenter2 antivirus checks on Windows Server.')
	}
	else
	{
		try
		{
			$SecurityCenterProducts = @(Get-CimInstance -ClassName AntiVirusProduct -Namespace root/SecurityCenter2 -ErrorAction Stop)
			$SecurityCenterAvailable = $true
			if (-not $SecurityCenterProducts)
			{
				LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
			}
		}
		catch [Microsoft.Management.Infrastructure.CimException]
		{
			LogWarning (Get-BaselineBilingualString -Key 'GuiPreflightWMIFailed' -Fallback 'CIM/WMI query failed: {0}' -FormatArgs @($_.Exception.Message))
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
		}
	}

	# Checking services
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingServices' -Fallback 'Checking services')
		try
		{
			$DefenderServiceNames = if ($osInfo.IsWindowsServer)
			{
				@("WinDefend", "wscsvc")
		}
		else
		{
			@("WinDefend", "SecurityHealthService", "wscsvc")
		}

			$Services = Get-Service -Name $DefenderServiceNames -ErrorAction Stop
			if ($IsAdmin -and (-not $osInfo.IsWindowsServer) -and ($Services.Name -contains "SecurityHealthService"))
			{
				Get-Service -Name SecurityHealthService -ErrorAction Stop | Start-Service | Out-Null
			}
		}
	catch [Microsoft.PowerShell.Commands.ServiceCommandException]
	{
		Remove-HandledErrorRecord -ErrorRecord $_
		$Services = @()
		LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
	}

	$Script:DefenderServices = Test-BaselineDefenderServicesHealthy -Services $Services

	# Checking Get-MpPreference cmdlet
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingGetMpPreference' -Fallback 'Checking Get-MpPreference cmdlet')
	if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)
	{
		try
		{
			(Get-MpPreference -ErrorAction Stop).EnableControlledFolderAccess | Out-Null
		}
		catch [Microsoft.Management.Infrastructure.CimException]
		{
			LogWarning (Get-BaselineBilingualString -Key 'WindowsComponentBroken' -Fallback '{0} is broken or removed from Windows. Reinstall Windows using only a genuine ISO image.' -FormatArgs @('Microsoft Defender'))
		}
	}
	else
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_MicrosoftDefenderPreferenceCmdletsUnavailable' -Fallback 'Microsoft Defender preference cmdlets are not available on this OS.')
	}

	# Check Microsoft Defender state
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingMicrosoftDefenderState' -Fallback 'Checking Microsoft Defender state')
	$DefenderState = $null
	if ($SecurityCenterAvailable)
	{
		$DefenderProduct = $SecurityCenterProducts | Where-Object { $_.instanceGuid -eq "{D68DDC3A-831F-4fae-9E44-DA132C1ACF46}" } | Select-Object -First 1
		if ($DefenderProduct -and ($null -ne $DefenderProduct.productState))
		{
			try
			{
				$DefenderState = Get-BaselineDefenderProductStateCode -ProductState $DefenderProduct.productState
			}
			catch
			{
				LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_UnableToParseDefenderProductState' -Fallback 'Unable to parse Microsoft Defender product state: {0}' -FormatArgs @($_.Exception.Message))
			}
		}
	}
	else
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_MicrosoftDefenderSecurityCenterStateUnavailable' -Fallback 'Microsoft Defender Security Center product state is not available on this OS.')
	}

	if (Test-BaselineDefenderActiveByProductState -StateCode $DefenderState)
	{
		# Defender is a currently used AV. Continue...
		$Script:DefenderProductState = $true

		# Checking whether Microsoft Defender was turned off via GPO
		if ([Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender", "DisableAntiSpyware", $null) -eq 1)
		{
			$Script:AntiSpywareEnabled = $false
		}
		else
		{
			$Script:AntiSpywareEnabled = $true
		}

		# Checking whether Microsoft Defender was turned off via GPO
		if ([Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableRealtimeMonitoring", $null) -eq 1)
		{
			$Script:RealtimeMonitoringEnabled = $false
		}
		else
		{
			$Script:RealtimeMonitoringEnabled = $true
		}

		# Checking whether Microsoft Defender was turned off via GPO
		if ([Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection", "DisableBehaviorMonitoring", $null) -eq 1)
		{
			$Script:BehaviorMonitoringEnabled = $false
		}
		else
		{
			$Script:BehaviorMonitoringEnabled = $true
		}
	}
	else
	{
		$Script:DefenderProductState = $false
		$Script:AntiSpywareEnabled = $false
		$Script:RealtimeMonitoringEnabled = $false
		$Script:BehaviorMonitoringEnabled = $false
	}

	if (Test-BaselineDefenderFullyEnabled -ServicesRunning $Script:DefenderServices -ProductStateActive $Script:DefenderProductState -AntiSpywareEnabled $Script:AntiSpywareEnabled -RealtimeMonitoringEnabled $Script:RealtimeMonitoringEnabled -BehaviorMonitoringEnabled $Script:BehaviorMonitoringEnabled)
	{
		# Defender is enabled
		$Script:DefenderEnabled = $true

		switch ((Get-MpPreference).EnableControlledFolderAccess)
		{
			"1"
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_DisablingControlledFolderAccess' -Fallback 'Disabling Controlled folder access')
				$Script:ControlledFolderAccess = $true
				if ($IsAdmin)
				{
					Set-MpPreference -EnableControlledFolderAccess Disabled | Out-Null
				}
				else
				{
					LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingControlledFolderAccessRemediationNotElevated' -Fallback 'Skipping Controlled folder access remediation because Baseline is not running elevated.')
				}

				Start-Process -FilePath "windowsdefender://RansomwareProtection" | Out-Null
			}
			"0"
			{
				LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_ControlledFolderAccessAlreadyDisabled' -Fallback 'Controlled folder access has already been disabled')
				$Script:ControlledFolderAccess = $false
			}
			default
			{
				$Script:ControlledFolderAccess = $false
			}
		}
	}
	else
	{
		$Script:DefenderEnabled = $false
		$Script:ControlledFolderAccess = $false
	}
	#endregion Defender checks

	# Checking whether LGPO.exe exists in the Assets folder
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingLgpoExists' -Fallback 'Checking whether LGPO.exe exists in the Assets folder')
	if (-not (Test-Path -Path "$PSScriptRoot\..\..\Assets\LGPO.exe"))
	{
		LogWarning (Get-BaselineBilingualString -Key 'Bin' -Fallback 'There are no files in "{0}" folder. Please, re-download the archive.' -FormatArgs @([IO.Path]::GetFullPath("$PSScriptRoot\..\..\Assets")))
	}

	# Enable back the SysMain service if it was disabled by harmful tweakers
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingSysMain' -Fallback 'Enable back the SysMain service if it was disabled by harmful tweakers')
	if ($IsAdmin -and ((Get-Service -Name SysMain).Status -eq "Stopped"))
	{
		Get-Service -Name SysMain | Set-Service -StartupType Automatic | Out-Null
		Get-Service -Name SysMain | Start-Service | Out-Null
	}
	elseif ((Get-Service -Name SysMain).Status -eq "Stopped")
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingSysMainRecoveryNotElevated' -Fallback 'Skipping SysMain recovery because Baseline is not running elevated.')
	}

	# Automatically manage paging file size for all drives
	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingPagingFile' -Fallback 'Automatically manage paging file size for all drives')
	if ($IsAdmin -and (-not (Get-CimInstance -ClassName CIM_ComputerSystem).AutomaticManagedPageFile))
	{
		Get-CimInstance -ClassName CIM_ComputerSystem | Set-CimInstance -Property @{AutomaticManagedPageFile = $true} | Out-Null
	}
	elseif (-not (Get-CimInstance -ClassName CIM_ComputerSystem).AutomaticManagedPageFile)
	{
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_SkippingPagingFileRemediationNotElevated' -Fallback 'Skipping automatic paging file remediation because Baseline is not running elevated.')
	}

	# PowerShell 5.1 (7.5 too) interprets 8.3 file name literally, if an environment variable contains a non-Latin word
	# https://github.com/PowerShell/PowerShell/issues/21070
	Get-ChildItem -Path "$env:TEMP\Computer.txt", "$env:TEMP\User.txt" -Force -ErrorAction Ignore |
		Remove-Item -Force -ErrorAction Ignore | Out-Null

	$Global:BaselinePostActionRequirements = @{
		EnsurePrintManagementConsole = $false
		EnsureSmbGuestAuth = $false
	}

	# Save all opened folders in order to restore them after File Explorer restart
	try
	{
		$Script:OpenedFolders = {
			(New-Object -ComObject Shell.Application).Windows() |
				ForEach-Object { $_.Document.Folder.Self.Path }
		}.Invoke()
	}
	catch [System.Management.Automation.PropertyNotFoundException]
	{
		$Script:OpenedFolders = @()
	}
	if ($env:BASELINE_EMBEDDED_HOST -ne '1' -and (Test-InteractiveHost))
	{
		Clear-Host
	}

	# Extract the localized "Browse" string from shell32.dll
	$Script:Browse = Get-LocalizedShellString -ResourceId 9015 -Fallback 'Browse'
	# Extract the localized "&No" string from shell32.dll
	$Script:No = Get-LocalizedShellString -ResourceId 33232 -Fallback 'No' -StripAccelerators
	# Extract the localized "&Yes" string from shell32.dll
	$Script:Yes = Get-LocalizedShellString -ResourceId 33224 -Fallback 'Yes' -StripAccelerators
	$Script:KeyboardArrows = Get-BaselineBilingualString -Key 'KeyboardArrows' -Fallback 'Please use the arrow keys {0} and {1} on your keyboard to select your answer' -FormatArgs @([System.Char]::ConvertFromUtf32(0x2191), [System.Char]::ConvertFromUtf32(0x2193))
	# Extract the localized "Skip" string from shell32.dll
	$Script:Skip = Get-LocalizedShellString -ResourceId 16956 -Fallback 'Skip'

	Write-Information -MessageData "┏┓   *     ┏      ┓ ┏*   ┓ 		" -InformationAction Continue
	Write-Information -MessageData "┗┓┏┏┓┓┏┓╋  ╋┏┓┏┓  ┃┃┃┓┏┓┏┫┏┓┓┏┏┏" -InformationAction Continue
	Write-Information -MessageData "┗┛┗┛ ┗┣┛┗  ┛┗┛┛   ┗┻┛┗┛┗┗┻┗┛┗┻┛┛" -InformationAction Continue
	Write-Information -MessageData "      ┛                   		" -InformationAction Continue

	# Display a warning message about whether a user has customized the preset file
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
			$splashLoadingText = Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait...'
			if ($null -ne $Global:Localization)
			{
				$candidate = $null
				if ($Global:Localization -is [System.Collections.IDictionary] -and $Global:Localization.Contains('GuiSplashLoading')) { $candidate = [string]$Global:Localization['GuiSplashLoading'] }
				elseif ($Global:Localization.PSObject -and $Global:Localization.PSObject.Properties['GuiSplashLoading']) { $candidate = [string]$Global:Localization.GuiSplashLoading }
				if (-not [string]::IsNullOrWhiteSpace($candidate)) { $splashLoadingText = $candidate }
			}

			if (Get-Command -Name 'Set-BootstrapLoadingSplashState' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Set-BootstrapLoadingSplashState -Splash $Global:LoadingSplash -StatusText $splashLoadingText -Indeterminate
			}
			else
			{
				$Global:LoadingSplash.Dispatcher.Invoke([System.Action]{
					try
					{
						$statusText = $Global:LoadingSplash.Window.FindName('StatusText')
						if ($statusText)
						{
							$statusText.Text = $splashLoadingText
						}
					}
					catch { $null = $_ }
				})
			}
			# The launcher closes the splash immediately after InitialActions
			# returns, once startup checks are done and before the GUI builds.
		}
		catch { $null = $_ }
	}

	LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_InitialChecksFinished' -Fallback 'Initial Checks finished, continuing with Main Script') -addGap
	if ($env:BASELINE_EMBEDDED_HOST -ne '1' -and (Test-InteractiveHost))
	{
		Clear-Host
	}
}
#endregion InitialActions

Export-ModuleMember -Function '*'
