using module ..\Logging.psm1
using module ..\SharedHelpers.psm1
using module ..\GUICommon.psm1
using module ..\GUIExecution.psm1

# GUI scripts are dot-sourced here so their $Script: state belongs to GUI.psm1.
$Script:GuiLayout = GUICommon\Get-GuiLayout
$Script:GuiFontSizeWarnings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$Script:SetButtonChromeScript = $null

function Set-ButtonChrome
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param (
		[System.Windows.Controls.Primitives.ButtonBase]$Button,
		[ValidateSet('Primary', 'Preview', 'Danger', 'DangerSubtle', 'Secondary', 'Subtle', 'Selection', 'SegmentNeutral')]
		[string]$Variant = 'Secondary',
		[switch]$Compact,
		[switch]$Muted
	)

	if ($Script:SetButtonChromeScript -isnot [scriptblock])
	{
		throw 'Set-ButtonChrome proxy is not initialized.'
	}

	& $Script:SetButtonChromeScript @PSBoundParameters
}

function Test-GuiStartupSplashLive
{
	param (
		[object]$Splash
	)

	if ($Splash -isnot [hashtable]) { return $false }
	if (-not $Splash.ContainsKey('IsAlive')) { return $false }
	if (-not $Splash.ContainsKey('WasRendered')) { return $false }

	return ([bool]$Splash.IsAlive -and [bool]$Splash.WasRendered)
}

# Load GUI subsystem scripts during module import so Show-TweakGUI can call their top-level functions.
. (Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'GUI' | Join-Path -ChildPath 'AppsModule.ps1')
. (Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'GUI' | Join-Path -ChildPath 'UpdateOverlayModule.ps1')
. (Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'GUI' | Join-Path -ChildPath 'LanguageCatalog.ps1')
<#
    .SYNOPSIS
    Return a validated font size for the current GUI layout.

    .DESCRIPTION
    Proxies to GUICommon\Get-GuiSafeFontSize so region GUI code can resolve a layout key to a safe font size with a fallback value.

    .PARAMETER Key
    Layout key to resolve.

    .PARAMETER Default
    Fallback font size used when the key is missing or invalid.

    .PARAMETER Layout
    Layout object to read from. Defaults to the current GUI layout state.

    .EXAMPLE
    Get-GuiSafeFontSize -Key 'Body' -Default 12
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
    Creates safe thickness.

    
.DESCRIPTION
    
Supports safe thickness handling inside Baseline.
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
    Creates WPF setter.

    
.DESCRIPTION
    
Supports WPF setter handling inside Baseline.
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
		$unwrappedValue = $resolvedValue.psobject.BaseObject
		if ($null -ne $unwrappedValue)
		{
			$resolvedValue = $unwrappedValue
		}
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
    Checks GUI object field.

    
.DESCRIPTION
    
Supports GUI object field handling inside Baseline.
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
    Gets GUI object field.

    
.DESCRIPTION
    
Supports GUI object field handling inside Baseline.
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
    Gets GUI runtime failure details.

    
.DESCRIPTION
    
Supports GUI runtime failure details handling inside Baseline.
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
    Show GUI runtime failure.

    
.DESCRIPTION
    
Supports GUI runtime failure handling inside Baseline.
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
    Writes GUI preset debug.

    
.DESCRIPTION
    
Supports GUI preset debug handling inside Baseline.
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
    Writes GUI runtime warning.

    
.DESCRIPTION
    
Supports GUI runtime warning handling inside Baseline.
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
# Defined in Module/GUI/DetectScriptblocks.ps1 and dot-sourced so the hashtables
# land in this module's $Script: scope. Kept as a separate file because the
# block was nearly 400 lines of hashtable literal.
. (Join-Path $PSScriptRoot '..' | Join-Path -ChildPath 'GUI' | Join-Path -ChildPath 'DetectScriptblocks.ps1')
#endregion Detect & Visibility Scriptblocks

$Script:TweakManifest = @()
$Script:ManifestLoadedFromData = $false

# Defined at module scope so Show-TweakGUI can capture them once for deferred
# WPF event handlers and dispatcher callbacks.
function Test-IsSafeModeUX
{
	<#
	    .SYNOPSIS
	    Return whether the GUI is currently in Safe Mode.

	    .DESCRIPTION
	    Reads the script-scoped Safe Mode flag and returns it as a boolean for other GUI helpers.

	    .EXAMPLE
	    Test-IsSafeModeUX
	#>
	return ([bool]$Script:SafeMode)
}
<#
    .SYNOPSIS
    Checks is expert mode ux.

    
.DESCRIPTION
    
Supports is expert mode ux handling inside Baseline.
#>
function Test-IsExpertModeUX { return ([bool]$Script:AdvancedMode) }
<#
    .SYNOPSIS
    Checks GUI run in progress.

    
.DESCRIPTION
    
Supports GUI run in progress handling inside Baseline.
#>
function Test-GuiRunInProgress { return [bool]$Script:RunInProgress }


#region GUI Builder
function Show-TweakGUI
{
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
	[CmdletBinding()]
	param ()

	# Enable per-monitor DPI awareness before any WPF objects are created
	# so the window renders at native resolution on high-DPI displays.
	try { GUICommon\Initialize-GuiDpiAwareness } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ShowTweakGUI.InitializeGuiDpiAwareness' }

	# --- Extracted function groups (dot-sourced to reduce file size) ---
	$Script:GuiExtractedRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'GUI'
	$traceGuiStartup = {
		param([string]$Message)
		if (-not $env:BASELINE_PERF_LOG) { return }
		try
		{
			$traceDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline'
			if (-not [System.IO.Directory]::Exists($traceDirectory))
			{
				[void][System.IO.Directory]::CreateDirectory($traceDirectory)
			}
			$tracePath = Join-Path $traceDirectory 'Baseline-launch-trace.txt'
			[System.IO.File]::AppendAllText($tracePath, ("{0:o} [GUI] {1}`r`n" -f [DateTime]::UtcNow, $Message), [System.Text.Encoding]::UTF8)
		}
		catch
		{
			$null = $_
		}
	}.GetNewClosure()
	& $traceGuiStartup 'Show-TweakGUI start'

	# Context Object and Observable State must load first - other GUI files reference $Script:Ctx
	. (Join-Path $Script:GuiExtractedRoot 'GuiContext.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'StateTransitions.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ObservableState.ps1')
	$Script:Ctx = New-GuiContext
	$Script:Ctx.Config.ExtractedRoot = $Script:GuiExtractedRoot
	$Script:AuditRetentionDays = [int]$Script:Ctx.UI.AuditRetentionDays
	$Script:DesignMode = [bool]$Global:DesignMode
	$Script:Ctx.UI.DesignMode = [bool]$Script:DesignMode
	if ($Script:Ctx.ContainsKey('Mode')) { $Script:Ctx.Mode.Design = [bool]$Script:DesignMode }
	& $traceGuiStartup 'Core context loaded'

	. (Join-Path $Script:GuiExtractedRoot 'UxPolicy.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'UIDensity.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'SessionState.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PreviewBuilders.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ExecutionSummary.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PresetManagement.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'GameModeUI.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'GameModeState.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PreflightChecks.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'PlanSummaryPanel.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ExecutionOrchestration.ps1')
	& $traceGuiStartup 'Core GUI scripts loaded'


	if (-not $Script:ManifestLoadedFromData)
	{
		try
		{
			$Script:TweakManifest = Import-TweakManifestFromData `
				-DetectScriptblocks $Script:DetectScriptblocks `
				-VisibleIfScriptblocks $Script:VisibleIfScriptblocks
			& $traceGuiStartup 'Manifest import complete'
			# Keep startup limited to runtime-required manifest work. Structural
			# integrity validation is a maintainer/test concern; it only emits
			# warnings and does not change rendered tweak behavior.
			# Stamp Availability onto every entry so the row-factory hide-unavailable
			# gate (TweakRowFactory.ps1) and the apply-path partition
			# (ExecutionOrchestration.ps1) both see a populated block instead of
			# treating absence as "available". No override → real host platform.
			try
			{
				$Script:BaselineSystemPlatformInfo = Get-BaselineSystemPlatformInfo
				$null = Update-BaselineManifestAvailability `
					-Manifest $Script:TweakManifest `
					-SystemInfo $Script:BaselineSystemPlatformInfo
				& $traceGuiStartup 'Manifest availability stamped'
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'GUI.ManifestLoad.AvailabilityStamp'
			}
			$Script:ManifestLoadedFromData = $true
			$Script:Ctx.Data.TweakManifest = $Script:TweakManifest
			$Script:Ctx.Data.ManifestLoaded = $true
		}
		catch
		{
			Write-Warning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'Failed to load tweak metadata from Module/Data')
			return
		}
	}
	& $traceGuiStartup 'Manifest ready'

	Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase
	Add-Type -AssemblyName System.Windows.Forms, System.Drawing, WindowsFormsIntegration

	Ensure-SheenProgressBarType
	& $traceGuiStartup 'WPF assemblies ready'

	if (-not $Script:ExplicitPresetSelections) {
		$Script:ExplicitPresetSelections = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	}
	if (-not $Script:ExplicitPresetSelectionDefinitions) {
		$Script:ExplicitPresetSelectionDefinitions = @{}
	}

	$Script:GuiModuleBasePath = $null
	$Script:GuiPresetDirectoryPath = $null
	$Script:GuiLocalizationDirectoryPath = $null

	try { $Script:GuiModuleBasePath = $MyInvocation.MyCommand.Module.ModuleBase } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveModuleBase.ModuleBase' }
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $PSCommandPath } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveModuleBase.PSCommandPath' }
	}
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $MyInvocation.MyCommand.Path } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveModuleBase.MyInvocationPath' }
	}
	if ([string]::IsNullOrWhiteSpace([string]$Script:GuiModuleBasePath))
	{
		try { $Script:GuiModuleBasePath = Split-Path -Parent $PSScriptRoot } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveModuleBase.PSScriptRoot' }
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
		"Customizations"       = @()
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
			'DownloadUpdatesOverMeteredConnection'
			'FeatureUpdateDeferral'
			'QualityUpdateDeferral'
			'StoreAppAutoDownload'
			'MapUpdates'
			'UpdateMSRT'
			'WindowsUpdateDisableAll'
			'WindowsUpdatePause'
			'WindowsUpdateSecurityOnlyMode'
			'UpdateNotificationLevel'
			'UpdateAutoDownload'
			'UpdateDriver'
			'UpdateMSProducts'
			'UpdateMicrosoftProducts'
			'UpdateRestart'
			'WindowsLatestUpdate'
			'WindowsUpdate'
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
	    Resolves GUI primary tab for tweak.

	    
.DESCRIPTION
	    
Supports GUI primary tab for tweak handling inside Baseline.
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
	# rebuilds them on every keystroke. All fields are static tweak metadata.
	# Also index tweak rows by primary tab so filter population can avoid
	# scanning the full manifest for normal tab-scoped filter updates.
	$Script:TweakSearchHaystacks = @{}
	$Script:TweakIndicesByPrimaryTab = @{}
	for ($__hi = 0; $__hi -lt $Script:TweakManifest.Count; $__hi++)
	{
		$__t = $Script:TweakManifest[$__hi]
		if (-not $__t) { continue }
		$__owning = Resolve-GuiPrimaryTabForTweak -Tweak $__t
		if (-not [string]::IsNullOrWhiteSpace([string]$__owning))
		{
			if (-not $Script:TweakIndicesByPrimaryTab.ContainsKey($__owning))
			{
				$Script:TweakIndicesByPrimaryTab[$__owning] = [System.Collections.Generic.List[int]]::new()
			}
			[void]$Script:TweakIndicesByPrimaryTab[$__owning].Add($__hi)
		}
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
	& $traceGuiStartup 'Search indexes ready'

	# --- Phase 2 extractions (after WPF assemblies are loaded) ---
	. (Join-Path $Script:GuiExtractedRoot 'ThemeManagement.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'IconRegistry.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'IconFactory.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'TweakAnalysis.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ComponentFactory.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'FilteringLogic.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ApplicationsView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'SystemScan.ps1')
	& $traceGuiStartup 'Phase 2 GUI scripts loaded'

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
	& $traceGuiStartup 'Theme and icon systems ready'


	#region Themed Dialog

	. (Join-Path $Script:GuiExtractedRoot 'ExecutionSummaryDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'DiffView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ComplianceView.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'AuditView.ps1')


	# --- Dialog and tab management extractions (after XAML controls are available) ---
	. (Join-Path $Script:GuiExtractedRoot 'DialogHelpers.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'ReviewMode.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'AddCustomAppDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'StartupManagerDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'RemovalPersistenceDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'UserFoldersDialog.ps1')
	. (Join-Path $Script:GuiExtractedRoot 'TabManagement.ps1')

	$guiWindowMinWidth  = $Script:GuiLayout.WindowMinWidth
	$guiWindowMinHeight = $Script:GuiLayout.WindowMinHeight

	#region XAML template
	$xamlPath = Join-Path $Script:GuiExtractedRoot 'MainWindow.xaml'
	if (-not (Test-Path -LiteralPath $xamlPath))
	{
		throw "Main window XAML resource is missing: $xamlPath"
	}
	$xamlText = [System.IO.File]::ReadAllText($xamlPath, [System.Text.Encoding]::UTF8)
	$xamlText = $xamlText.Replace('__GuiWindowMinWidth__', [string]$guiWindowMinWidth).Replace('__GuiWindowMinHeight__', [string]$guiWindowMinHeight)
	[xml]$XAML = $xamlText
	#endregion XAML template

	#region Window setup and control wiring
	. (Join-Path $Script:GuiExtractedRoot 'WindowSetup.ps1')
	#endregion
	& $traceGuiStartup 'Window setup complete'

	#region Helper: Apply theme
	. (Join-Path $Script:GuiExtractedRoot 'ApplyTheme.ps1')
	#endregion


	#region Helper: Create styled controls
	. (Join-Path $Script:GuiExtractedRoot 'StyledControlsSetup.ps1')
	#endregion
	#endregion


	#region Build controls for a set of tweaks
	. (Join-Path $Script:GuiExtractedRoot 'BuildTweakControls.ps1')
	#endregion

	#region Windows Update runtime panel
	. (Join-Path $Script:GuiExtractedRoot 'UpdatesPanel.ps1')
	#endregion

	#region Build tab content for a primary category
	. (Join-Path $Script:GuiExtractedRoot 'BuildTabContent.ps1')
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

		if (-not $Script:ForceCloseCompleted)
		{
			# Persist the current GUI session silently; restore-on-launch is
			# controlled by the GUI settings toggle.
			$null = Save-GuiSessionState
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
				try { $Script:SearchRefreshTimer.Stop() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SearchRefreshTimer.Stop' }
				$Script:SearchRefreshTimer = $null
			}
			if ($Script:FilterRefreshTimer)
			{
				try { $Script:FilterRefreshTimer.Stop() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.FilterRefreshTimer.Stop' }
				$Script:FilterRefreshTimer = $null
			}

			Clear-GuiWindowRuntimeState

			$Script:GuiUnhandledExceptionHooked = $false
			$Script:GuiUnhandledExceptionHandler = $null
			if ($Script:MainForm -eq $closedSender)
			{
				$Script:MainForm = $null
			}
		}) | Out-Null

	$Script:StartupSessionSnapshot = $null
	$Script:StartupHydratePrimaryTab = 'Initial Setup'
	$Script:StartupRestoreSessionPending = $false
	$Script:StartupIsFirstRun = $true
	try
	{
		$Script:StartupIsFirstRun = [bool](Test-GuiFirstRunWelcomePending)
	}
	catch
	{
		Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveStartupSession.FirstRunState'
		$Script:StartupIsFirstRun = $true
	}

	$startupRestoreLastSession = if ($null -ne $Script:RestoreLastSession) { [bool]$Script:RestoreLastSession } else { $true }
	if ($startupRestoreLastSession -and -not $Script:StartupIsFirstRun)
	{
		try
		{
			$startupSessionSnapshot = GUICommon\Read-GuiSessionStateDocument -AppName 'Baseline' -ExpectedSchema 'Baseline.GuiSettings'
			if ($startupSessionSnapshot)
			{
				$Script:StartupSessionSnapshot = $startupSessionSnapshot
				$Script:StartupRestoreSessionPending = $true
				$desiredTab = if (Test-GuiObjectField -Object $startupSessionSnapshot -FieldName 'CurrentPrimaryTab') { [string]$startupSessionSnapshot.CurrentPrimaryTab } else { $null }
				$desiredLast = if (Test-GuiObjectField -Object $startupSessionSnapshot -FieldName 'LastStandardPrimaryTab') { [string]$startupSessionSnapshot.LastStandardPrimaryTab } else { $null }
				if (Test-GuiObjectField -Object $startupSessionSnapshot -FieldName 'UIDensity' -and -not [string]::IsNullOrWhiteSpace([string]$startupSessionSnapshot.UIDensity))
				{
					$Script:UIDensity = if (Get-Command -Name 'Normalize-BaselineUiDensity' -CommandType Function -ErrorAction SilentlyContinue) { Normalize-BaselineUiDensity -Density ([string]$startupSessionSnapshot.UIDensity) } else { [string]$startupSessionSnapshot.UIDensity }
				}
				if (-not [string]::IsNullOrWhiteSpace($desiredTab) -and $desiredTab -ne $Script:SearchResultsTabTag)
				{
					$Script:StartupHydratePrimaryTab = $desiredTab
				}
				elseif (-not [string]::IsNullOrWhiteSpace($desiredLast))
				{
					$Script:StartupHydratePrimaryTab = $desiredLast
				}
			}
		}
		catch
		{
			Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.ResolveStartupSession.ReadAppDataSession'
			$Script:StartupSessionSnapshot = $null
			$Script:StartupRestoreSessionPending = $false
			$Script:StartupHydratePrimaryTab = 'Initial Setup'
		}
	}
	& $traceGuiStartup ("Startup session resolved: firstRun={0}; restorePending={1}; tab={2}" -f $Script:StartupIsFirstRun, $Script:StartupRestoreSessionPending, $Script:StartupHydratePrimaryTab)

	#region Build primary tabs
	. (Join-Path $Script:GuiExtractedRoot 'BuildPrimaryTabs.ps1')
	#endregion
	& $traceGuiStartup 'Primary tabs built'

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
		$Script:LastCategoryFilterSignature = $null
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
	$Script:SetButtonChromeScript = ${function:Set-ButtonChrome}
	$Script:ShowThemedDialogScript = ${function:Show-ThemedDialog}
	$Script:ShowSelectedTweakPreviewScript = ${function:Show-SelectedTweakPreview}
	$Script:GetUxRunActionLabelScript = ${function:Get-UxRunActionLabel}
	$Script:UpdateRunPathContextLabelScript = ${function:Update-RunPathContextLabel}
	$Script:InvokeGuiStateTransitionScript = ${function:Invoke-GuiStateTransition}
	$Script:SyncUxActionButtonTextScript = ${function:Sync-UxActionButtonText}
	$Script:ClearInvisibleSelectionStateScript = ${function:Clear-InvisibleSelectionState}
	$Script:UpdateHeaderModeStateTextScript = ${function:Update-HeaderModeStateText}
	$invokeGuiSystemScanOnLaunchScript = ${function:Invoke-GuiSystemScan}

	# Apply initial theme based on the saved session, then Windows theme when no session exists.
	$initialThemeName = 'Dark'
	try
	{
		$initialThemeName = Get-BaselineStartupThemeName
	}
	catch
	{
		$null = $_
	}
	Set-GUITheme -Theme $(if ($initialThemeName -eq 'Light') { $Script:LightTheme } else { $Script:DarkTheme }) -SkipContentRebuild
	Set-StaticButtonStyle
	& $traceGuiStartup 'Initial theme applied'

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
	if ($Script:BtnClearQueuedActions) { Set-GuiButtonIconContent -Button $Script:BtnClearQueuedActions -IconName 'Clear' -Text (Get-UxLocalizedString -Key 'GuiAppsReset' -Fallback 'Reset') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsResetTip' -Fallback 'Clear all queued changes and checked applications.') -IconSize 14 -Gap 6 -TextFontSize 11 }
	if ($Script:BtnScanInstalledApps) { Set-GuiButtonIconContent -Button $Script:BtnScanInstalledApps -IconName 'Search' -Text (Get-UxLocalizedString -Key 'GuiAppsScanInstalledApps' -Fallback 'Scan Installed Apps') -ToolTip (Get-UxLocalizedString -Key 'GuiAppsScanInstalledAppsTip' -Fallback 'Scan installed apps to update install status.') -IconSize 14 -Gap 6 -TextFontSize 11 }
	& $traceGuiStartup 'Primary action icons wired'

	Set-StaticControlTabOrder
	Set-GuiActionButtonsEnabled -Enabled $true
	& $traceGuiStartup 'Static controls initialized'

	$shouldRestoreLastSession = if ($null -ne $Script:RestoreLastSession) { [bool]$Script:RestoreLastSession } else { $true }
	$restoredSessionStatusText = Get-UxLocalizedString -Key 'GuiLogSessionRestoredPreviousState' -Fallback ''
	if ($shouldRestoreLastSession -and $Script:StartupSessionSnapshot)
	{
		$restoreGuiSessionStateScript = Get-GuiFunctionCapture -Name 'Restore-GuiSessionState'
		$setGuiStatusTextScript = Get-GuiFunctionCapture -Name 'Set-GuiStatusText'
		$restoredSessionAction = {
			try
			{
				$restoredGuiSession = & $restoreGuiSessionStateScript -Snapshot $Script:StartupSessionSnapshot
				if ($restoredGuiSession)
				{
					if ($setGuiStatusTextScript) { & $setGuiStatusTextScript -Text $restoredSessionStatusText -Tone 'accent' }
				}
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.RestoreStartupSession'
			}
		}.GetNewClosure()
		& $restoredSessionAction
	}
	Update-GuiLocalizationStrings
	Update-PrimaryTabHeaders
	Sync-UxActionButtonText
	& $traceGuiStartup 'Initial localization and headers synced'

	$startBaselineDownloadScript = Get-GuiFunctionCapture -Name 'Start-BaselineDownload'
	$hideBaselineUpdateOverlayScript = Get-GuiFunctionCapture -Name 'Hide-BaselineUpdateOverlay'
	$Script:DownloadStartEvent = {
		$uri = 'https://github.com/sdmanson8/Baseline/archive/refs/heads/main.zip'
		$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline_Update.zip'
		if ($startBaselineDownloadScript)
		{
			& $startBaselineDownloadScript -Uri $uri -DestinationPath $tempPath
		}
		else
		{
			LogWarning 'Start-BaselineDownload not available; update download action was skipped.'
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
			if ($hideBaselineUpdateOverlayScript)
			{
				& $hideBaselineUpdateOverlayScript
			}
		}.GetNewClosure())
	}

	# Resolve all first-run dependencies ONCE, here, while module scope is valid.
	$firstRunDialogDispatcher = if ($Form -and $Form.Dispatcher) { $Form.Dispatcher } else { $null }
	$closeLoadingSplashBlock = (Get-Item function:Close-LoadingSplashWindow -ErrorAction Stop).ScriptBlock
	$testGuiStartupSplashLiveBlock = (Get-Item function:Test-GuiStartupSplashLive -ErrorAction Stop).ScriptBlock
	$hideConsoleWindowBlock  = (Get-Item function:Hide-ConsoleWindow -ErrorAction Stop).ScriptBlock
	$showThemedDialogBlock   = (Get-Item function:Show-ThemedDialog -ErrorAction Stop).ScriptBlock
	$showWelcomeDialogBlock  = (Get-Item function:Show-FirstRunWelcomeDialog -ErrorAction Stop).ScriptBlock
	$completeWelcomeBlock    = (Get-Item function:Complete-GuiFirstRunWelcome -ErrorAction Stop).ScriptBlock
	$firstRunTheme           = $Script:CurrentTheme
	$firstRunApplyButtonChrome = ${function:Set-ButtonChrome}
	$firstRunOwnerWindow     = $Form
	$firstRunUseDarkMode     = ($Script:CurrentThemeName -eq 'Dark')

	if ($closeLoadingSplashBlock -isnot [scriptblock]) { throw "Close-LoadingSplashWindow did not resolve to a scriptblock." }
	if ($testGuiStartupSplashLiveBlock -isnot [scriptblock]) { throw "Test-GuiStartupSplashLive did not resolve to a scriptblock." }
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
	& $traceGuiStartup 'First-run command dependencies resolved'

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
	& $traceGuiStartup 'First-run welcome state resolved'

	$startupSplashHandle = $Global:LoadingSplash
	$hasLiveStartupSplash = & $testGuiStartupSplashLiveBlock -Splash $startupSplashHandle
	try
	{
		$Form.ShowInTaskbar = $true
		$Form.Opacity = 1
	}
	catch
	{
		Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.StartupVisibility.Apply'
	}
	& $traceGuiStartup 'Startup visibility applied'

	$startupPresentationCompleted = $false
	Register-GuiEventHandler -Source $Form -EventName 'ContentRendered' -Handler ({
		if ($startupPresentationCompleted) { return }
		$startupPresentationCompleted = $true

		# Run initial adaptive tab layout check now that the window has its actual size
		if ($Script:AdaptiveTabLayoutScript) { & $Script:AdaptiveTabLayoutScript }

		# Schedule splash close via a dedicated background runspace.
		#
		# Why not a dispatcher: the GUI dispatcher is busy for ~50 s after
		# ContentRendered with deferred ApplicationIdle Build-TabContent work,
		# so anything queued at Background/ApplicationIdle on the GUI is
		# starved until that backlog drains.
		#
		# Why not Register-ObjectEvent: PowerShell event subscribers run on
		# the main runspace thread, which is blocked inside Form.ShowDialog()
		# until the user closes the GUI - the action never fires.
		#
		# A fresh runspace gives us a completely independent thread that can
		# poll the splash's GuiReady flag (flipped by Build-TabContent once the
		# foreground tab is interactive) and then close the splash via its OWN
		# dispatcher (separate STA, idle, uncontended). This keeps the splash
		# visible until the GUI is actually usable, while background work keeps
		# draining on the main dispatcher.
		try
		{
			$splashHandle = $Global:LoadingSplash
			if (& $testGuiStartupSplashLiveBlock -Splash $splashHandle)
			{
				if (-not $splashHandle.ContainsKey('GuiReady')) { $splashHandle.GuiReady = $false }
				$closeRunspace = [runspacefactory]::CreateRunspace()
				$closeRunspace.ApartmentState = 'MTA'
				$closeRunspace.Open()
				$closeRunspace.SessionStateProxy.SetVariable('splash', $splashHandle)
				$closeRunspace.SessionStateProxy.SetVariable('mainWindow', $Form)
				$closePs = [powershell]::Create()
				$closePs.Runspace = $closeRunspace
				[void]$closePs.AddScript({
					$traceDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline'
					$tracePath = Join-Path $traceDirectory 'Baseline-launch-trace.txt'
					$trace = { param($m) try { if (-not [System.IO.Directory]::Exists($traceDirectory)) { [void][System.IO.Directory]::CreateDirectory($traceDirectory) }; [System.IO.File]::AppendAllText($tracePath, ("{0:o} {1}`r`n" -f [DateTime]::UtcNow, $m), [System.Text.Encoding]::UTF8) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.Trace.AppendAllText' } }
					& $trace 'SplashClose runspace: started polling GuiReady'
					try
					{
					# Wait for the GUI-ready signal from Build-TabContent.
					# Cap at 180 s as a safety net so the splash is never
					# stuck if the signal is missed.
						$deadline = [datetime]::UtcNow.AddSeconds(180)
						while (-not $splash.GuiReady -and [datetime]::UtcNow -lt $deadline)
						{
							if (-not $splash.IsAlive) { break }
							Start-Sleep -Milliseconds 200
						}

						& $trace 'SplashClose runspace: GuiReady signaled, revealing GUI before splash close'

						try
						{
							if ($splash -is [hashtable] -and $splash.ContainsKey('CompletionAnimationDeadlineUtc') -and $splash.CompletionAnimationDeadlineUtc -is [datetime])
							{
								while ($splash.IsAlive -and [datetime]::UtcNow -lt $splash.CompletionAnimationDeadlineUtc)
								{
									Start-Sleep -Milliseconds 50
								}
							}
						}
						catch { try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close: completion animation wait failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.CompletionAnimationWait' }; $null = $_ }

						# Reveal the GUI BEFORE closing the splash so the
						# transition is instant: the GUI is already painted
						# before the splash disappears, so the main window is
						# ready the moment the splash is hidden. If we close
						# the splash first, there's a gap where neither window
						# is visible (desktop flashes).
						try
						{
							if ($mainWindow -and $mainWindow.Dispatcher -and -not $mainWindow.Dispatcher.HasShutdownStarted)
							{
								$mainWindow.Dispatcher.Invoke([System.Action]{
									try { $mainWindow.ShowInTaskbar = $true } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.MainWindow.ShowInTaskbar' }
									try { $mainWindow.Opacity = 1 } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.MainWindow.Opacity' }
								})
							}
						}
						catch { try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close: mainWindow taskbar/opacity transition failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.MainWindowTaskbarOpacity' }; $null = $_ }

						if ($splash -and $splash.Dispatcher -and -not $splash.Dispatcher.HasShutdownStarted)
						{
							$splash.Dispatcher.Invoke([System.Action]{
								if ($splash.Window)
								{
									try { $splash.Window.Hide() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.Window.Hide' }
									try { $splash.Window.Close() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.Window.Close' }
								}
								$splash.IsAlive = $false
							})
						}

						& $trace 'SplashClose runspace: splash window closed'

						# Splash is gone - Activate the GUI now so it has
						# focus and is the topmost window. Done after splash
						# close because Activate while the splash exists can
						# fight the splash's own focus claim.
						try
						{
							if ($mainWindow -and $mainWindow.Dispatcher -and -not $mainWindow.Dispatcher.HasShutdownStarted)
							{
								$mainWindow.Dispatcher.Invoke([System.Action]{
									try { $mainWindow.Activate() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.MainWindow.Activate' }
								})
							}
						}
						catch { try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close: mainWindow.Activate failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.MainWindowActivate' }; $null = $_ }

						# Brief wait for window close to propagate, then shut
						# down the splash's runspace so it doesn't leak.
						Start-Sleep -Milliseconds 250
						try
						{
							if ($splash -and $splash.Dispatcher -and -not $splash.Dispatcher.HasShutdownStarted)
							{
								$splash.Dispatcher.InvokeShutdown()
							}
						}
						catch { try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close: dispatcher InvokeShutdown failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.DispatcherInvokeShutdown' }; $null = $_ }
						try
						{
							if ($splash._PowerShell -and $splash._AsyncResult)
							{
								$splash._PowerShell.EndInvoke($splash._AsyncResult)
							}
						}
						catch { try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close: PowerShell.EndInvoke failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.PowerShellEndInvoke' }; $null = $_ }
						try { if ($splash._PowerShell) { $splash._PowerShell.Dispose() } } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.PowerShell.Dispose' }
						try { if ($splash._Runspace) { $splash._Runspace.Close(); $splash._Runspace.Dispose() } } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.Runspace.Dispose' }
					}
					catch
					{
						try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close runspace failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.RunspaceDispose' }
						$null = $_
					}
				})
				[void]$closePs.BeginInvoke()
			}
		}
		catch
		{
			try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close orchestration failed') } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.Orchestration' }
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

		if ([bool]$Script:AutoScanOnLaunch -and $invokeGuiSystemScanOnLaunchScript)
		{
			$autoScanAction = {
				try
				{
					& $invokeGuiSystemScanOnLaunchScript
				}
				catch
				{
					Write-DebugSwallowedException -ErrorRecord $_ -Source 'Regions.GUI.AutoScanOnLaunch'
				}
			}.GetNewClosure()
			$null = $Form.Dispatcher.BeginInvoke(
				[System.Action]$autoScanAction,
				[System.Windows.Threading.DispatcherPriority]::ApplicationIdle
			)
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
	& $traceGuiStartup 'ContentRendered startup handler registered'

	# Activate immediately only when the GUI is visible at ShowDialog time.
	$Form.ShowActivated = -not $hasLiveStartupSplash
	Initialize-WpfWindowForeground -Window $Form
	& $traceGuiStartup 'Foreground initialization complete'

	# Set Preview Run as the default-focused action so it feels like the natural next step.
	if ($BtnPreviewRun) { $BtnPreviewRun.Focusable = $true }
	& $traceGuiStartup 'Pre-show initialization complete'

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

function Write-TweakProgress
{
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
