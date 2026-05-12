# Pure logic functions for tweak analysis: removal detection, scenario signals, selection state

	<#
	    .SYNOPSIS
	#>

	function Test-TweakRemovalOperation
	{
		param ([object]$Tweak)

		if (-not $Tweak) { return $false }

		$searchParts = @(
			[string]$Tweak.Name,
			[string]$Tweak.Description,
			[string]$Tweak.Detail,
			[string]$Tweak.WhyThisMatters,
			([string[]]@($Tweak.Tags | ForEach-Object { [string]$_ }) -join ' ')
		) -join ' '

		if ($Tweak.Type -eq 'Choice')
		{
			$optionValues = @($Tweak.Options | ForEach-Object { [string]$_ })
			if ($optionValues | Where-Object { $_ -match '^(?i)(uninstall|remove|delete)$' })
			{
				return $true
			}
		}

		return ($searchParts -match '(?i)\b(uninstall|remove|delete)\b')
	}

	<#
	    .SYNOPSIS
	#>

	function Test-TweakPackageOperation
	{
		param ([object]$Tweak)

		if (-not $Tweak) { return $false }

		$tagValues = @($Tweak.Tags | ForEach-Object { [string]$_ })
		$optionValues = @($Tweak.Options | ForEach-Object { [string]$_ })
		$haystack = @(
			[string]$Tweak.Name,
			[string]$Tweak.Function,
			[string]$Tweak.Description,
			[string]$Tweak.Detail,
			[string]$Tweak.WhyThisMatters,
			[string]$Tweak.CautionReason,
			[string]$Tweak.SubCategory,
			[string]$Tweak.SourceRegion,
			($tagValues -join ' ')
		) -join ' '

		if ([string]$Tweak.SubCategory -eq 'App Management') { return $true }
		if ([string]$Tweak.SourceRegion -eq 'OneDrive') { return $true }
		if ($tagValues -contains 'package-manager') { return $true }
		if (@($optionValues | Where-Object { $_ -match '^(?i)(install|uninstall|update|restore)$' }).Count -gt 0)
		{
			return $true
		}

		return ($haystack -match '(?i)\b(package manager|winget|microsoft store|store app|appx|msix|powershell 7|onedrive|copilot)\b')
	}

	<#
	    .SYNOPSIS
	#>

	function Get-TweakScenarioSignals
	{
		param ([object]$Tweak)

		if (-not $Tweak) { return @() }

		$signals = New-Object System.Collections.Generic.List[string]
		$addSignal = {
			param ([string]$Label)

			if ([string]::IsNullOrWhiteSpace($Label)) { return }
			if (-not ($signals -contains $Label))
			{
				[void]$signals.Add($Label)
			}
		}.GetNewClosure()

		$tagValues = @($Tweak.Tags | ForEach-Object { [string]$_ })
		$haystack = @(
			[string]$Tweak.Name,
			[string]$Tweak.Description,
			[string]$Tweak.Detail,
			[string]$Tweak.WhyThisMatters,
			[string]$Tweak.CautionReason,
			[string]$Tweak.Category,
			[string]$Tweak.SubCategory,
			[string]$Tweak.SourceRegion,
			($tagValues -join ' ')
		) -join ' '
		$tagText = $tagValues -join ' '

		if ($haystack -match '(?i)\b(gaming|game\s*bar|xbox|fullscreen|anti-?cheat|raw\s+mouse\s+input)\b' -or
			$tagText -match '(?i)\b(gaming|xbox)\b')
		{
			& $addSignal 'Gaming'
		}

		if ($haystack -match '(?i)\b(privacy|telemetry|tracking|advertis|bing search|web search|activity history|location|camera|microphone|tips|suggestions|personalized)\b' -or
			$tagText -match '(?i)\b(privacy|telemetry|tracking|advertising|bing|websearch|activity|location|camera|microphone)\b')
		{
			& $addSignal 'Privacy'
		}

		if ((Test-TweakRemovalOperation -Tweak $Tweak) -or
			$haystack -match '(?i)\b(cleanup|debloat|uninstall|remove|delete|clear recent|recent files|recent shortcuts)\b' -or
			$tagText -match '(?i)\b(cleanup|debloat|uninstall|remove|delete)\b')
		{
			& $addSignal 'Cleanup'
		}

		if ($haystack -match '(?i)\b(compatibility|onedrive|office|adobe|network sharing|sharing wizard|network discovery|printer|remote access|store app|uwp|sync)\b' -or
			$tagText -match '(?i)\b(compatibility|onedrive|office|adobe|networking|sharing|discovery|printer|store|uwp|remote)\b')
		{
			& $addSignal 'Compatibility'
		}

		if ($haystack -match '(?i)\b(performance|latency|speed|power plan|gpu scheduling|multiplane overlay|visual effects|mouse acceleration|raw input|faster)\b' -or
			$tagText -match '(?i)\b(performance|gpu|cpu|latency|power|speed|visualfx)\b')
		{
			& $addSignal 'Performance'
		}

		if ($haystack -match '(?i)\b(security|hardening|defender|firewall|credential|cipher|protocol|winrm|smartscreen|lsa|smb1|netbios|llmnr|bitlocker)\b' -or
			$tagText -match '(?i)\b(security|hardening|defender|firewall|smb|protocol)\b')
		{
			& $addSignal 'Hardening'
		}

		if ($haystack -match '(?i)\b(repair|recover|recovery|troubleshoot|troubleshooting|diagnostic|fix|rollback)\b' -or
			$tagText -match '(?i)\b(repair|recovery|troubleshooting|diagnostic|fix)\b')
		{
			& $addSignal 'Troubleshooting'
		}

		return @($signals)
	}

	<#
	    .SYNOPSIS
	#>

	function Test-TweakIsSelected
	{
		param (
			[object]$Tweak,
			[object]$StateSource
		)

		if (-not $Tweak) { return $false }
		if (Get-Command -Name 'Test-GuiTweakAvailableOnCurrentSystem' -CommandType Function -ErrorAction SilentlyContinue)
		{
			if (-not (Test-GuiTweakAvailableOnCurrentSystem -Tweak $Tweak))
			{
				return $false
			}
		}
		$source = if ($StateSource) { $StateSource } else { $Tweak }
		if (-not $source) { return $false }

		switch ([string]$Tweak.Type)
		{
			'Choice' { return ((Test-GuiObjectField -Object $source -FieldName 'SelectedIndex') -and [int]$source.SelectedIndex -ge 0) }
			'NumericRange'
			{
				$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				if ($explicitSelection -and [string]$explicitSelection.Type -eq 'NumericRange')
				{
					if ((Test-GuiObjectField -Object $explicitSelection -FieldName 'ACValue') -or (Test-GuiObjectField -Object $explicitSelection -FieldName 'DCValue') -or (Test-GuiObjectField -Object $explicitSelection -FieldName 'NumericValue') -or (Test-GuiObjectField -Object $explicitSelection -FieldName 'Value'))
					{
						return $true
					}
				}

				if ((Test-GuiObjectField -Object $source -FieldName 'IsChecked'))
				{
					return [bool]$source.IsChecked
				}

				if ((Test-GuiObjectField -Object $source -FieldName 'ACValue') -or (Test-GuiObjectField -Object $source -FieldName 'DCValue') -or (Test-GuiObjectField -Object $source -FieldName 'NumericValue') -or (Test-GuiObjectField -Object $source -FieldName 'Value'))
				{
					return $true
				}

				return $false
			}
			'Date'
			{
				$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Date')
				{
					if (Test-GuiObjectField -Object $explicitSelection -FieldName 'Run')
					{
						return [bool]$explicitSelection.Run
					}
					if ((Test-GuiObjectField -Object $explicitSelection -FieldName 'SelectedDate') -and $explicitSelection.SelectedDate)
					{
						return $true
					}
					if ((Test-GuiObjectField -Object $explicitSelection -FieldName 'Value') -and -not [string]::IsNullOrWhiteSpace([string]$explicitSelection.Value))
					{
						return $true
					}
				}
				if ((Test-GuiObjectField -Object $source -FieldName 'SelectedDate') -and $source.SelectedDate)
				{
					return $true
				}
				return ((Test-GuiObjectField -Object $source -FieldName 'IsChecked') -and [bool]$source.IsChecked)
			}
			'Toggle'
			{
				$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Toggle')
				{
					return $true
				}
				return ((Test-GuiObjectField -Object $source -FieldName 'IsChecked') -and [bool]$source.IsChecked)
			}
			'Action' { return ((Test-GuiObjectField -Object $source -FieldName 'IsChecked') -and [bool]$source.IsChecked) }
			default
			{
				return (
					((Test-GuiObjectField -Object $source -FieldName 'IsChecked') -and [bool]$source.IsChecked) -or
					((Test-GuiObjectField -Object $source -FieldName 'SelectedIndex') -and [int]$source.SelectedIndex -ge 0)
				)
			}
		}
	}

	<#
	    .SYNOPSIS
	#>

	function Get-GuiToggleGoalState
	{
		param (
			[object]$Tweak
		)

		if ($Tweak -and (Test-GuiObjectField -Object $Tweak -FieldName 'Default'))
		{
			return [bool](Get-GuiObjectField -Object $Tweak -FieldName 'Default')
		}

		return $false
	}

	<#
	    .SYNOPSIS
	#>

	function Get-GuiToggleDetectedState
	{
		param (
			[object]$Tweak
		)

		if (-not [bool]$Script:ScanEnabled -or -not $Tweak -or -not (Test-GuiObjectField -Object $Tweak -FieldName 'Detect') -or -not $Tweak.Detect)
		{
			return [pscustomobject]@{
				Known = $false
				Value = $null
			}
		}

		$goalState = Get-GuiToggleGoalState -Tweak $Tweak
		return [pscustomobject]@{
			Known = $true
			Value = [bool](Invoke-GuiDetectScriptblock -Detect $Tweak.Detect -DefaultValue $goalState)
		}
	}

	<#
	    .SYNOPSIS
	#>

	function Get-GuiToggleDisplayState
	{
		param (
			[object]$Tweak,
			[object]$StateSource = $null
		)

		$goalState = Get-GuiToggleGoalState -Tweak $Tweak
		$detected = Get-GuiToggleDetectedState -Tweak $Tweak
		$isSelected = Test-TweakIsSelected -Tweak $Tweak -StateSource $StateSource
		$matchesDesired = ([bool]$detected.Known -and [bool]$detected.Value -eq [bool]$goalState)

		if ($matchesDesired)
		{
			return [pscustomobject]@{
				StateLabel = Get-UxLocalizedString -Key 'GuiTweakStateAlreadySet' -Fallback 'Already Set'
				StateTone = 'Muted'
				StateDetail = Get-UxLocalizedString -Key 'GuiTweakStateDetailDetectedMatchesGoal' -Fallback 'Detected state matches the configured goal.'
				MatchesDesired = $true
				DetectedState = [bool]$detected.Value
				GoalState = [bool]$goalState
				IsSelected = [bool]$isSelected
			}
		}

		if ($isSelected)
		{
			return [pscustomobject]@{
				StateLabel = Get-UxLocalizedString -Key 'GuiTweakStateWillChange' -Fallback 'Will Change'
				StateTone = 'Primary'
				StateDetail = Get-UxLocalizedString -Key 'GuiTweakStateDetailWillChange' -Fallback 'Selected and will change the system state when run.'
				MatchesDesired = $false
				DetectedState = if ([bool]$detected.Known) { [bool]$detected.Value } else { $null }
				GoalState = [bool]$goalState
				IsSelected = $true
			}
		}

		return [pscustomobject]@{
			StateLabel = Get-UxLocalizedString -Key 'GuiTweakStateNotApplied' -Fallback 'Not Applied'
			StateTone = 'Muted'
			StateDetail = Get-UxLocalizedString -Key 'GuiTweakStateDetailNotApplied' -Fallback 'Not selected for this run.'
			MatchesDesired = $false
			DetectedState = if ([bool]$detected.Known) { [bool]$detected.Value } else { $null }
			GoalState = [bool]$goalState
			IsSelected = $false
		}
	}

	<#
	    .SYNOPSIS
	#>

	function Test-TweakIsRestorable
	{
		param ([object]$Tweak)

		if (-not $Tweak) { return $false }
		return -not (
			(Test-GuiObjectField -Object $Tweak -FieldName 'Restorable') -and
			$null -ne $Tweak.Restorable -and
			-not [bool]$Tweak.Restorable
		)
	}

	function Test-TweakIsGamingRelated
	{
		param ([object]$Tweak)

		if (-not $Tweak) { return $false }
		return (@(Get-TweakScenarioSignals -Tweak $Tweak) -contains 'Gaming')
	}

	<#
	    .SYNOPSIS
	#>

	function Get-TweakFocusGroup
	{
		param (
			[object]$Tweak,
			[string[]]$ScenarioSignals
		)

		if (-not $Tweak) { return 'General' }

		$signals = @($ScenarioSignals)
		if ($signals.Count -eq 0)
		{
			$signals = @(Get-TweakScenarioSignals -Tweak $Tweak)
		}

		foreach ($candidate in @('Troubleshooting', 'Gaming', 'Privacy', 'Cleanup', 'Compatibility', 'Performance', 'Hardening'))
		{
			if ($signals -contains $candidate)
			{
				return $candidate
			}
		}

		if (Test-TweakRemovalOperation -Tweak $Tweak)
		{
			return 'Cleanup'
		}

		return 'General'
	}

	<#
	    .SYNOPSIS
	#>

	function Get-TweakInclusionReason
	{
		param (
			[object]$Tweak,
			[string]$FocusGroup,
			[string[]]$ScenarioSignals
		)

		if (-not $Tweak) { return $null }

		$tier = if ([string]::IsNullOrWhiteSpace([string]$Tweak.PresetTier)) { 'Basic' } else { [string]$Tweak.PresetTier }
		$tierText = switch ($tier)
		{
			'Minimal' { 'Included because it is a very small, low-risk change.'; break }
			'Basic' { 'Included because it is a low-risk change.'; break }
			'Safe' { 'Included because it is a low-risk change.'; break }
			'Balanced' { 'Included because it offers a moderate change with limited tradeoffs.'; break }
			'Advanced' { 'Included because it is an expert-level change intended for the Advanced expert preset.'; break }
			default { 'Included because it matches the preset policy.' }
		}

		$group = if ([string]::IsNullOrWhiteSpace([string]$FocusGroup)) { Get-TweakFocusGroup -Tweak $Tweak -ScenarioSignals $ScenarioSignals } else { [string]$FocusGroup }
		$groupText = switch ($group)
		{
			'Gaming' { 'It is gaming-related and helps keep latency or overlay behavior under control.'; break }
			'Privacy' { 'It supports privacy and telemetry cleanup.'; break }
			'Cleanup' { 'It removes clutter or unwanted components.'; break }
			'Compatibility' { 'It helps keep common workflows, apps, or devices working as expected.'; break }
			'Performance' { 'It targets responsiveness or latency improvements.'; break }
			'Hardening' { 'It tightens security defaults.'; break }
			'Troubleshooting' { 'It is a targeted fix or troubleshooting aid.'; break }
			default { 'It fits the current baseline policy.' }
		}

		return ('{0} {1}' -f $tierText, $groupText).Trim()
	}

	<#
	    .SYNOPSIS
	#>

	function Get-TweakBlastRadiusText
	{
		param (
			[object]$Tweak,
			[string]$TypeLabel,
			[string[]]$ScenarioTags,
			[bool]$MatchesDesired = $false
		)

		if ($MatchesDesired)
		{
			return (Get-UxLocalizedString -Key 'GuiTweakAlreadySetMessage' -Fallback 'Already set. No change is expected from this selection.')
		}

		$isPackageOperation = Test-TweakPackageOperation -Tweak $Tweak
		$isRemovalOperation = Test-TweakRemovalOperation -Tweak $Tweak
		$riskLevel = if ([string]::IsNullOrWhiteSpace([string]$Tweak.Risk)) { 'Low' } else { [string]$Tweak.Risk }
		$impactLevel = if ((Test-GuiObjectField -Object $Tweak -FieldName 'Impact') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.Impact)) { [string]$Tweak.Impact } else { $riskLevel }

		$focusNotes = New-Object System.Collections.Generic.List[string]
		foreach ($tag in @($ScenarioTags))
		{
			switch ([string]$tag)
			{
				'Gaming' { if ($focusNotes -notcontains 'gaming / overlays / input latency') { [void]$focusNotes.Add('gaming / overlays / input latency') } }
				'Networking' { if ($focusNotes -notcontains 'network sharing and SMB workflows') { [void]$focusNotes.Add('network sharing and SMB workflows') } }
				'SMB' { if ($focusNotes -notcontains 'network sharing and SMB workflows') { [void]$focusNotes.Add('network sharing and SMB workflows') } }
				'OneDrive' { if ($focusNotes -notcontains 'OneDrive sync workflows') { [void]$focusNotes.Add('OneDrive sync workflows') } }
				'Adobe' { if ($focusNotes -notcontains 'Adobe licensing and cloud workflows') { [void]$focusNotes.Add('Adobe licensing and cloud workflows') } }
				'Updates' { if ($focusNotes -notcontains 'update and reboot behavior') { [void]$focusNotes.Add('update and reboot behavior') } }
				'Hardening' { if ($focusNotes -notcontains 'security and hardening defaults') { [void]$focusNotes.Add('security and hardening defaults') } }
				'Privacy' { if ($focusNotes -notcontains 'telemetry and tracking behavior') { [void]$focusNotes.Add('telemetry and tracking behavior') } }
				'Security' { if ($focusNotes -notcontains 'security and access-control behavior') { [void]$focusNotes.Add('security and access-control behavior') } }
			}
		}

		$severityText = switch ($riskLevel)
		{
			'High' { 'High blast radius.'; break }
			'Medium' { 'Moderate blast radius.'; break }
			default { 'Low blast radius.' }
		}

		$details = New-Object System.Collections.Generic.List[string]
		[void]$details.Add($severityText)

		if ($isPackageOperation)
		{
			if ($isRemovalOperation)
			{
				[void]$details.Add('This package/app change can remove software components and may need Store, winget, or manual reinstall follow-up.')
			}
			else
			{
				[void]$details.Add('This package/app change can download, register, or update Windows software and may need network, admin, or Store follow-up.')
			}
		}
		elseif ($TypeLabel -eq 'Uninstall / Remove')
		{
			[void]$details.Add('This is a removal-style change and may be harder to reverse.')
		}

		if ($focusNotes.Count -gt 0)
		{
			[void]$details.Add(('May affect {0}.' -f (($focusNotes | Select-Object -Unique) -join ', ')))
		}
		elseif ($impactLevel -eq 'High')
		{
			[void]$details.Add('Review the linked description before running.')
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$Tweak.CautionReason))
		{
			[void]$details.Add([string]$Tweak.CautionReason.Trim().TrimEnd('.') + '.')
		}
		else
		{
			[void]$details.Add('Review the linked description before running.')
		}

		return ('Blast radius: {0}' -f ($details -join ' '))
	}
