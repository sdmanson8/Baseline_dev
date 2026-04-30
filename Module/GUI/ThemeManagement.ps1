# Theme palette definitions, fallback/repair, and brush conversion utilities

	$Script:DarkTheme = @{
		WindowBg      = "#0E111A"
		HeaderBg      = "#121624"
		PanelBg       = "#161A26"
		CardBg        = "#1E2433"
		TabBg         = "#00FFFFFF"
		TabActiveBg   = "#262D40"
		TabHoverBg    = "#202638"
		BorderColor   = "#2430445A"
		TextPrimary   = "#F4F7FF"
		TextSecondary = "#B8C1D9"
		TextMuted     = "#8F99B2"
		TextDisabled  = "#586178"
		AccentBlue    = "#7CB7FF"
		AccentHover   = "#9ACAFF"
		AccentPress   = "#4D9CFF"
		FocusRing     = "#9ACAFF"
		CautionBg     = "#14D6A84A"
		CautionBorder = "#4DD6A84A"
		CautionText   = "#D6A84A"
		ImpactBadge   = "#D6A84A"
		ImpactBadgeBg = "#1FD6A84A"
		LowRiskBadge     = "#35D07F"
		LowRiskBadgeBg   = "#1F35D07F"
		RiskMediumBadge   = "#D6A84A"
		RiskMediumBadgeBg = "#1FD6A84A"
		RiskHighBadge     = "#FF6B8A"
		RiskHighBadgeBg   = "#1FFF6B8A"
		DestructiveSubtleBorder = "#33FF6B8A"
		DestructiveSubtleHoverBg = "#10FF6B8A"
		DestructiveSubtlePressBg = "#18FF6B8A"
		DestructiveBg = "#B93D5B"
		DestructiveHover = "#D64B6D"
		SectionLabel  = "#7CB7FF"
		ScrollBg          = "#121624"
		ScrollThumb       = "#3A4561"
		ScrollThumbHover  = "#4D5875"
		ScrollThumbActive = "#5E6C8E"
		ToggleOn      = "#7CB7FF"
		ToggleOff     = "#586178"
		StateEnabled  = "#35D07F"
		StateDisabled = "#586178"
		SearchBg      = "#262D40"
		SearchBorder  = "#2430445A"
		SearchPlaceholder = "#8F99B2"
		InputBg       = "#262D40"
		InputHoverBg  = "#30384E"
		CardBorder    = "#293044"
		CardHoverBg   = "#202638"
		SecondaryButtonBg = "#00FFFFFF"
		SecondaryButtonHoverBg = "#1E2433"
		SecondaryButtonPressBg = "#262D40"
		SecondaryButtonBorder = "#1FFFFFFF"
		SecondaryButtonFg = "#B8C1D9"
		PresetPanelBg = "#1E2433"
		PresetPanelBorder = "#293044"
		StatusPillBg = "#202638"
		StatusPillBorder = "#293044"
		StatusPillText = "#B8C1D9"
		ActiveTabBorder = "#7CB7FF"
		ActiveTabIndicator = "#7CB7FF"
		StateAccent = "#B34FD1A5"
		StateAccentStrong = "#4FD1A5"
		ProgressGreen      = "#35D07F"
		ProgressGreenTrack = "#2A3146"
	}
	$Script:LightTheme = @{
		WindowBg      = "#F0F2F6"
		HeaderBg      = "#E9EDF3"
		PanelBg       = "#F0F2F6"
		CardBg        = "#FBFCFE"
		TabBg         = "#E8EDF5"
		TabActiveBg   = "#1550AA"
		TabHoverBg    = "#1A60C4"
		BorderColor   = "#E6EAF0"
		TextPrimary   = "#1F2937"
		TextSecondary = "#6B7280"
		TextMuted     = "#7A8494"
		AccentBlue    = "#1550AA"
		AccentHover   = "#1A60C4"
		AccentPress   = "#104090"
		FocusRing     = "#0D63E0"
		CautionBg     = "#F5D0D0"
		CautionBorder = "#A02040"
		CautionText   = "#A02040"
		ImpactBadge   = "#A02040"
		ImpactBadgeBg = "#F5D0D0"
		LowRiskBadge     = "#2F8F6F"
		LowRiskBadgeBg   = "#DFF3EC"
		RiskMediumBadge   = "#7A5A00"
		RiskMediumBadgeBg = "#FFF3D0"
		RiskHighBadge     = "#A02040"
		RiskHighBadgeBg   = "#F5D0D0"
		DestructiveSubtleBorder = "#33A02040"
		DestructiveSubtleHoverBg = "#10A02040"
		DestructiveSubtlePressBg = "#18A02040"
		DestructiveBg = "#C0304E"
		DestructiveHover = "#A02840"
		SectionLabel  = "#1550AA"
		ScrollBg          = "#E9EDF3"
		ScrollThumb       = "#B4B6C2"
		ScrollThumbHover  = "#8D8FA0"
		ScrollThumbActive = "#6C6E80"
		ToggleOn      = "#B34FD1A5"
		ToggleOff     = "#B02040"
		StateEnabled  = "#B34FD1A5"
		StateDisabled = "#8B95A6"
		SearchBg      = "#FBFCFE"
		SearchBorder  = "#D6DDE8"
		SearchPlaceholder = "#7A8494"
		InputBg       = "#FBFCFE"
		InputHoverBg  = "#F6F8FB"
		CardBorder    = "#E6EAF0"
		CardHoverBg   = "#F6F8FB"
		SecondaryButtonBg = "#FBFCFE"
		SecondaryButtonHoverBg = "#F6F8FB"
		SecondaryButtonPressBg = "#E9EEF6"
		SecondaryButtonBorder = "#D6DDE8"
		SecondaryButtonFg = "#263248"
		PresetPanelBg = "#FBFCFE"
		PresetPanelBorder = "#E6EAF0"
		StatusPillBg = "#EEF4FF"
		StatusPillBorder = "#D7E5FF"
		StatusPillText = "#0F4EA8"
		ActiveTabBorder = "#1550AA"
		ActiveTabIndicator = "#1550AA"
		StateAccent = "#B34FD1A5"
		StateAccentStrong = "#4FD1A5"
		ProgressGreen      = "#6BBFA4"
		ProgressGreenTrack = "#E1EEE9"
	}

	$Script:GuiThemeFallbackWarnings = [System.Collections.Generic.HashSet[string]]::new()
	$Script:GuiRuntimeWarnings = [System.Collections.Generic.HashSet[string]]::new()

	<#
	    .SYNOPSIS
	    Internal function Write-GuiThemeFallbackWarning.
	#>

	function Write-GuiThemeFallbackWarning
	{
		param (
			[string]$Context,
			[string]$Message
		)

		if ([string]::IsNullOrWhiteSpace($Message)) { return }
		if ($Message -match 'Encountered an empty color value')
		{
			return
		}

		$warningKey = '{0}|{1}' -f $Context, $Message
		$shouldLog = $true
		if ($Script:GuiThemeFallbackWarnings)
		{
			try { $shouldLog = $Script:GuiThemeFallbackWarnings.Add($warningKey) } catch { $shouldLog = $true }
		}
		if (-not $shouldLog) { return }

		$warningText = "GUI theme fallback [{0}]: {1}" -f $(if ($Context) { $Context } else { 'GUI' }), $Message
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
	    Internal function Get-GuiFallbackColor.
	#>

	function Get-GuiFallbackColor
	{
		param ([string]$FallbackColor)

		if (-not [string]::IsNullOrWhiteSpace($FallbackColor))
		{
			return [string]$FallbackColor
		}

		if ($Script:DarkTheme -and -not [string]::IsNullOrWhiteSpace([string]$Script:DarkTheme.AccentBlue))
		{
			return [string]$Script:DarkTheme.AccentBlue
		}

		return '#7CB7FF'
	}

	<#
	    .SYNOPSIS
	    Internal function Repair-GuiThemePalette.
	#>

	function Repair-GuiThemePalette
	{
		param (
			[hashtable]$Theme,
			[string]$ThemeName = 'Dark'
		)

		$repairedTheme = @{}
		if ($Theme)
		{
			foreach ($key in $Theme.Keys)
			{
				$repairedTheme[$key] = $Theme[$key]
			}
		}

		# Ensure core interactive colors always exist before downstream theme repair runs.
		$defaultColors = @{
			'TabHoverBg' = '#343C55'
			'TextPrimary' = '#F4F7FF'
			'FocusRing' = '#9ACAFF'
			'AccentBlue' = '#7CB7FF'
			'AccentHover' = '#9ACAFF'
			'AccentPress' = '#4D9CFF'
			'HeaderBg' = '#151824'
			'TextSecondary' = '#B8C1D9'
		}
		foreach ($key in $defaultColors.Keys)
		{
			if (-not $repairedTheme.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$repairedTheme[$key]))
			{
				$repairedTheme[$key] = $defaultColors[$key]
				Write-GuiThemeFallbackWarning -Context "Repair-GuiThemePalette/$ThemeName" -Message "Added missing color '$key' with $($defaultColors[$key])."
			}
		}

		$primaryTheme = if ($ThemeName -eq 'Light') { $Script:LightTheme } else { $Script:DarkTheme }
		$secondaryTheme = if ($ThemeName -eq 'Light') { $Script:DarkTheme } else { $Script:LightTheme }
		$requiredKeys = [System.Collections.Generic.HashSet[string]]::new()
		foreach ($sourceTheme in @($primaryTheme, $secondaryTheme))
		{
			if (-not $sourceTheme) { continue }
			foreach ($key in $sourceTheme.Keys)
			{
				[void]$requiredKeys.Add([string]$key)
			}
		}

		foreach ($key in $requiredKeys)
		{
			$currentValue = if ($repairedTheme.ContainsKey($key)) { [string]$repairedTheme[$key] } else { $null }
			if (-not [string]::IsNullOrWhiteSpace($currentValue))
			{
				continue
			}

			$fallbackValue = $null
			if ($primaryTheme -and $primaryTheme.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$primaryTheme[$key]))
			{
				$fallbackValue = [string]$primaryTheme[$key]
			}
			elseif ($secondaryTheme -and $secondaryTheme.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$secondaryTheme[$key]))
			{
				$fallbackValue = [string]$secondaryTheme[$key]
			}
			else
			{
				$fallbackValue = '#7CB7FF'
			}

			$repairedTheme[$key] = $fallbackValue
			Write-GuiThemeFallbackWarning -Context "Repair-GuiThemePalette/$ThemeName" -Message "Filled missing color '$key' with $fallbackValue."
		}

		return $repairedTheme
	}

	<#
	    .SYNOPSIS
	    Internal function Resolve-GuiThemeResourcePath.
	#>

	function Resolve-GuiThemeResourcePath
	{
		param (
			[ValidateSet('Dark', 'Light')]
			[string]$ThemeName
		)

		$themeRoot = if (-not [string]::IsNullOrWhiteSpace([string]$Script:GuiExtractedRoot))
		{
			[string]$Script:GuiExtractedRoot
		}
		else
		{
			$PSScriptRoot
		}

		return (Join-Path -Path $themeRoot -ChildPath ('Themes\{0}.xaml' -f $ThemeName))
	}

	<#
	    .SYNOPSIS
	    Internal function Import-GuiThemeResourceDictionary.
	#>

	function Import-GuiThemeResourceDictionary
	{
		param (
			[ValidateSet('Dark', 'Light')]
			[string]$ThemeName
		)

		$themePath = Resolve-GuiThemeResourcePath -ThemeName $ThemeName
		if (-not (Test-Path -LiteralPath $themePath -PathType Leaf))
		{
			throw "Theme resource dictionary not found: $themePath"
		}

		$reader = $null
		try
		{
			$reader = [System.Xml.XmlReader]::Create($themePath)
			$dictionary = [System.Windows.Markup.XamlReader]::Load($reader)
			if (-not ($dictionary -is [System.Windows.ResourceDictionary]))
			{
				throw "Theme resource file did not load as a ResourceDictionary: $themePath"
			}
			$dictionary['Baseline.ThemeDictionaryMarker'] = $ThemeName
			return $dictionary
		}
		finally
		{
			if ($reader) { $reader.Close() }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Set-GuiThemeResources.
	#>

	function Set-GuiThemeResources
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[object]$Target,
			[ValidateSet('Dark', 'Light')]
			[string]$ThemeName
		)

		if (-not $Target) { throw 'Cannot apply theme resources because the target is null.' }
		if (-not ($Target.PSObject.Properties['Resources'] -or $Target.GetType().GetProperty('Resources'))) { throw 'Cannot apply theme resources because the target has no Resources property.' }

		$resources = $Target.Resources
		if (-not $resources) { throw 'Cannot apply theme resources because the target Resources property is null.' }

		$oldThemeDictionaries = @(
			$resources.MergedDictionaries |
				Where-Object { $_ -is [System.Windows.ResourceDictionary] -and $_.Contains('Baseline.ThemeDictionaryMarker') }
		)
		foreach ($dict in $oldThemeDictionaries)
		{
			[void]$resources.MergedDictionaries.Remove($dict)
		}

		$newDictionary = Import-GuiThemeResourceDictionary -ThemeName $ThemeName
		[void]$resources.MergedDictionaries.Add($newDictionary)
		return $true
	}

	<#
	    .SYNOPSIS
	    Internal function ConvertTo-GuiBrush.
	#>

	function ConvertTo-GuiBrush
	{
		param (
			[object]$Color,
			[string]$Context = 'GUI',
			[string]$FallbackColor = $null
		)

		if (-not $Script:BrushCache) { $Script:BrushCache = @{} }

		$resolvedColor = [string]$Color
		if (-not [string]::IsNullOrWhiteSpace($resolvedColor))
		{
			$cached = $Script:BrushCache[$resolvedColor]
			if ($cached) { return $cached }
		}

		$resolvedFallback = Get-GuiFallbackColor -FallbackColor $FallbackColor

		if ([string]::IsNullOrWhiteSpace($resolvedColor))
		{
			Write-GuiThemeFallbackWarning -Context $Context -Message "Encountered an empty color value. Using $resolvedFallback."
			$resolvedColor = $resolvedFallback
			$cached = $Script:BrushCache[$resolvedColor]
			if ($cached) { return $cached }
		}

		$converter = $Script:SharedBrushConverter
		if (-not $converter) { $converter = [System.Windows.Media.BrushConverter]::new() }
		try
		{
			$brush = [System.Windows.Media.Brush]$converter.ConvertFromString($resolvedColor)
		}
		catch
		{
			Write-GuiThemeFallbackWarning -Context $Context -Message "Failed to convert '$resolvedColor' ($($_.Exception.Message)). Using $resolvedFallback."
			$resolvedColor = $resolvedFallback
			$cached = $Script:BrushCache[$resolvedColor]
			if ($cached) { return $cached }
			$brush = [System.Windows.Media.Brush]$converter.ConvertFromString($resolvedFallback)
		}

		if ($brush -and $brush.CanFreeze) { $brush.Freeze() }
		$Script:BrushCache[$resolvedColor] = $brush
		return $brush
	}

	<#
	    .SYNOPSIS
	    Internal function New-SafeBrushConverter.
	#>

	function New-SafeBrushConverter
	{
		param (
			[string]$Context = 'GUI',
			[string]$FallbackColor = $null
		)

		# Return a lightweight converter that hits $Script:BrushCache directly,
		# bypassing the ScriptMethod dispatch overhead of the previous Add-Member approach.
		$fallbackCapture = Get-GuiFallbackColor -FallbackColor $FallbackColor
		$cacheRef = $Script:BrushCache
		$rawConverter = [System.Windows.Media.BrushConverter]::new()
		$converter = [pscustomobject]@{}
		$converter | Add-Member -MemberType ScriptMethod -Name ConvertFromString -Value {
			param ($Color)
			$key = [string]$Color
			if (-not [string]::IsNullOrWhiteSpace($key))
			{
				$hit = $cacheRef[$key]
				if ($hit) { return [System.Windows.Media.Brush]$hit }
			}
			else
			{
				$key = $fallbackCapture
			}
			try
			{
				$brush = [System.Windows.Media.Brush]$rawConverter.ConvertFromString($key)
				if ($brush -and $brush.CanFreeze) { $brush.Freeze() }
				if ($brush) { $cacheRef[$key] = $brush }
				return [System.Windows.Media.Brush]$brush
			}
			catch
			{
				if ($fallbackCapture -and $fallbackCapture -ne $key)
				{
					$fb = $cacheRef[$fallbackCapture]
					if ($fb) { return [System.Windows.Media.Brush]$fb }
					try
					{
						$fb = [System.Windows.Media.Brush]$rawConverter.ConvertFromString($fallbackCapture)
						if ($fb -and $fb.CanFreeze) { $fb.Freeze() }
						if ($fb) { $cacheRef[$fallbackCapture] = $fb }
						return [System.Windows.Media.Brush]$fb
					}
					catch { return $null }
				}
				return $null
			}
		}.GetNewClosure()
		return $converter
	}
