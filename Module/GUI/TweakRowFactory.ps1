	# Pre-computed shared resources for card hover effects.
	# Frozen DropShadowEffect instances are reused across all cards in the same
	# theme, avoiding per-card object allocation and WPF effect re-composition.
	$Script:CardHoverResources = $null

	<#
	    .SYNOPSIS
	    Internal function Get-CardHoverResources.
	#>

	function Get-CardHoverResources
	{
		$themeName = if ($Script:CurrentThemeName) { $Script:CurrentThemeName } else { 'Dark' }
		if ($Script:CardHoverResources -and $Script:CardHoverResources.ThemeName -eq $themeName)
		{
			return $Script:CardHoverResources
		}
		$bc = New-SafeBrushConverter -Context 'Get-CardHoverResources'
		$isLight = ($Script:CurrentTheme -eq $Script:LightTheme)
		$shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
		$shadow.Color = [System.Windows.Media.Colors]::Black
		$shadow.Direction = 270
		$shadow.ShadowDepth = if ($isLight) { 2 } else { 1 }
		$shadow.Opacity = if ($isLight) { 0.09 } else { 0.18 }
		$shadow.BlurRadius = if ($isLight) { 8 } else { 10 }
		if ($shadow.CanFreeze) { $shadow.Freeze() }
		$Script:CardHoverResources = @{
			ThemeName      = $themeName
			Shadow         = $shadow
			DefaultBg      = $bc.ConvertFromString($Script:CurrentTheme.CardBg)
			HoverBg        = $bc.ConvertFromString($Script:CurrentTheme.CardHoverBg)
			PressBg        = $bc.ConvertFromString($Script:CurrentTheme.TabActiveBg)
			DefaultBorder  = $bc.ConvertFromString($Script:CurrentTheme.CardBorder)
			HoverBorder    = $bc.ConvertFromString($Script:CurrentTheme.AccentHover)
			FocusBorder    = $bc.ConvertFromString($Script:CurrentTheme.FocusRing)
			Thickness1     = [System.Windows.Thickness]::new(1)
			Thickness2     = [System.Windows.Thickness]::new(2)
		}
		return $Script:CardHoverResources
	}

	<#
	    .SYNOPSIS
	    Internal function Add-CardHoverEffects.
	#>

	function Add-CardHoverEffects
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[System.Windows.Controls.Border]$Card,
			[object[]]$FocusSources = @()
		)
		if (-not $Card) { return }
		$setGuiControlPropertyCapture = ${function:Set-GuiControlProperty}
		$invokeGuiSafeActionCapture = ${function:Invoke-GuiSafeAction}
		$res = Get-CardHoverResources
		$defaultBg = $res.DefaultBg
		$hoverBg = $res.HoverBg
		$defaultBorder = $res.DefaultBorder
		$hoverBorder = $res.HoverBorder
		$focusBorder = $res.FocusBorder
		$thickness1 = $res.Thickness1
		$thickness2 = $res.Thickness2

		# Check for left accent border info stored on the card Tag by New-TweakRowCard
		$accentInfo = if ($Card.Tag -is [hashtable] -and $Card.Tag.ContainsKey('AccentBrush')) { $Card.Tag } else { $null }
		if ($accentInfo)
		{
			$defaultBorder = $accentInfo.AccentBrush
			$thickness1 = $accentInfo.AccentThickness
			$thickness2 = $accentInfo.AccentThicknessFocus
		}

		$updateChrome = {
			$hasFocus = $false
			foreach ($focusSource in $FocusSources)
			{
				if ($focusSource -and $focusSource.IsKeyboardFocusWithin)
				{
					$hasFocus = $true
					break
				}
			}
			# Direct property assignment avoids Set-GuiControlProperty overhead on
			# hot-path hover/focus events.  Border always has these properties.
			$Card.Background = if ($Card.IsMouseOver) { $hoverBg } else { $defaultBg }
			if ($hasFocus)
			{
				$Card.BorderBrush = $focusBorder
				$Card.BorderThickness = $thickness2
			}
			elseif ($Card.IsMouseOver)
			{
				$Card.BorderBrush = $hoverBorder
				$Card.BorderThickness = $thickness1
			}
			else
			{
				$Card.BorderBrush = $defaultBorder
				$Card.BorderThickness = $thickness1
			}
		}.GetNewClosure()
		$Card.BorderBrush = $defaultBorder
		$Card.BorderThickness = $thickness1
		$Card.Effect = $res.Shadow
		$Card.Cursor = [System.Windows.Input.Cursors]::Hand
		# Attach hover/focus handlers directly to avoid Invoke-GuiSafeAction
		# overhead on these high-frequency visual-only events.
		$Card.Add_MouseEnter({ try { & $updateChrome } catch {} }.GetNewClosure())
		$Card.Add_MouseLeave({ try { & $updateChrome } catch {} }.GetNewClosure())
		$pressBg = $res.PressBg
		$pressHandler = {
			$Card.Background = $pressBg
		}.GetNewClosure()
		$Card.Add_PreviewMouseLeftButtonDown({ try { & $pressHandler } catch {} }.GetNewClosure())
		$Card.Add_PreviewMouseLeftButtonUp({ try { & $updateChrome } catch {} }.GetNewClosure())
		foreach ($focusSource in $FocusSources)
		{
			if (-not $focusSource) { continue }
			$focusSource.Add_GotKeyboardFocus({ try { & $updateChrome } catch {} }.GetNewClosure())
			$focusSource.Add_LostKeyboardFocus({ try { & $updateChrome } catch {} }.GetNewClosure())
		}
		try { & $updateChrome } catch {}
	}

	<#
	    .SYNOPSIS
	    Internal function Ensure-PendingLinkedStateCollections.
	#>

	function Ensure-PendingLinkedStateCollections
	{
		if (-not ($Script:PendingLinkedChecks -is [System.Collections.Generic.HashSet[string]]))
		{
			$Script:PendingLinkedChecks = [System.Collections.Generic.HashSet[string]]::new()
		}
		if (-not ($Script:PendingLinkedUnchecks -is [System.Collections.Generic.HashSet[string]]))
		{
			$Script:PendingLinkedUnchecks = [System.Collections.Generic.HashSet[string]]::new()
		}
	}

	$syncLinkedState = {
		param (
			[string]$TargetFunction,
			[bool]$IsChecked
		)

		if ([string]::IsNullOrWhiteSpace($TargetFunction)) { return }
		if ($Script:ApplyingGuiPreset) { return }
		Ensure-PendingLinkedStateCollections

		$fidx = $Script:FunctionToIndex[$TargetFunction]
		if ($null -eq $fidx) { return }

		$tctl = $Script:Controls[$fidx]
		if ($null -ne $tctl -and $tctl.PSObject.Properties["IsChecked"])
		{
			$tctl.IsChecked = $IsChecked
		}

		if ($IsChecked)
		{
			if ($Script:PendingLinkedUnchecks) { [void]$Script:PendingLinkedUnchecks.Remove($TargetFunction) }
			if ($Script:PendingLinkedChecks) { [void]$Script:PendingLinkedChecks.Add($TargetFunction) }
		}
		else
		{
			if ($Script:PendingLinkedChecks) { [void]$Script:PendingLinkedChecks.Remove($TargetFunction) }
			if ($Script:PendingLinkedUnchecks) { [void]$Script:PendingLinkedUnchecks.Add($TargetFunction) }
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Test-TweakRowVisible.
	#>

	function Test-TweakRowVisible
	{
		param ([object]$Tweak)

		if (-not $Tweak.VisibleIf)
		{
			return $true
		}

		try
		{
			return [bool](& $Tweak.VisibleIf)
		}
		catch
		{
			return $false
		}
	}

	# Pre-computed CornerRadius shared across all tweak row cards.
	$Script:CardCornerRadius6 = [System.Windows.CornerRadius]::new(6)
	# Pre-computed Thickness values reused across all tweak row cards to avoid
	# per-row allocations.  Thickness is immutable in WPF so sharing is safe.
	$Script:T = @{
		Zero           = [System.Windows.Thickness]::new(0)
		CheckBoxRight  = [System.Windows.Thickness]::new(0, 0, 10, 0)
		ComboLeft      = [System.Windows.Thickness]::new(14, 0, 0, 0)
		StatusRow      = [System.Windows.Thickness]::new(28, 0, 0, 0)
		BadgePad       = [System.Windows.Thickness]::new(5, 1, 5, 1)
		AccentBorder   = [System.Windows.Thickness]::new(3, 1, 1, 1)
		AccentFocus    = [System.Windows.Thickness]::new(3, 2, 2, 2)
		DescIndent     = [System.Windows.Thickness]::new(28, 1, 6, 0)
		MetaIndent     = [System.Windows.Thickness]::new(28, 6, 0, 0)
		BlastIndent    = [System.Windows.Thickness]::new(28, 4, 6, 0)
		WhyIndent      = [System.Windows.Thickness]::new(28, 2, 0, 0)
		DescFlush      = [System.Windows.Thickness]::new(0, 1, 0, 0)
		MetaFlush      = [System.Windows.Thickness]::new(0, 6, 0, 0)
		BlastFlush     = [System.Windows.Thickness]::new(0, 4, 0, 0)
		WhyFlush       = [System.Windows.Thickness]::new(0, 2, 0, 0)
	}

	<#
	    .SYNOPSIS
	    Internal function New-TweakRowCard.
	#>

	function New-TweakRowCard
	{
		param (
			[object]$BrushConverter,
			[System.Windows.Thickness]$Margin,
			[System.Windows.Thickness]$Padding,
			[object]$Tweak = $null
		)

		$card = New-Object System.Windows.Controls.Border
		$res = Get-CardHoverResources
		$card.Background = $res.DefaultBg
		$card.CornerRadius = $Script:CardCornerRadius6
		$card.Margin = $Margin
		$card.Padding = $Padding

		# Apply left accent border for high-risk or caution tweaks
		$isHighRisk = $Tweak -and (Test-GuiObjectField -Object $Tweak -FieldName 'Risk') -and ([string]$Tweak.Risk -eq 'High')
		$isCaution = $Tweak -and (Test-GuiObjectField -Object $Tweak -FieldName 'Caution') -and ($Tweak.Caution -eq $true)
		$isMediumRisk = $Tweak -and (Test-GuiObjectField -Object $Tweak -FieldName 'Risk') -and ([string]$Tweak.Risk -eq 'Medium')
		if ($isHighRisk -or $isCaution)
		{
			$accentBrush = $BrushConverter.ConvertFromString($Script:CurrentTheme.CautionBorder)
			$card.Tag = @{ AccentBrush = $accentBrush; AccentThickness = $Script:T.AccentBorder; AccentThicknessFocus = $Script:T.AccentFocus }
		}
		elseif ($isMediumRisk)
		{
			$accentBrush = $BrushConverter.ConvertFromString($Script:CurrentTheme.RiskMediumBadge)
			$card.Tag = @{ AccentBrush = $accentBrush; AccentThickness = $Script:T.AccentBorder; AccentThicknessFocus = $Script:T.AccentFocus }
		}

		return $card
	}

	<#
	    .SYNOPSIS
	    Internal function New-TweakNamePanel.
	#>

	function New-TweakNamePanel
	{
		param (
			[object]$Tweak,
			[object]$BrushConverter,
			[switch]$UseWrapPanel
		)

		$namePanel = if ($UseWrapPanel)
		{
			New-Object System.Windows.Controls.WrapPanel
		}
		else
		{
			New-Object System.Windows.Controls.StackPanel
		}
		$namePanel.Orientation = 'Horizontal'
		$namePanel.VerticalAlignment = 'Center'

		$nameText = New-Object System.Windows.Controls.TextBlock
		$nameText.Text = if ($Tweak.NameKey) { Get-UxString -Key $Tweak.NameKey -Fallback $Tweak.Name } else { $Tweak.Name }
		$nameText.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSubheading' -Default 12
		$nameText.FontWeight = [System.Windows.FontWeights]::SemiBold
		$nameText.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextPrimary)
		$nameText.VerticalAlignment = 'Center'
		$nameText.Margin = $Script:T.Zero

		# Build a quick-glance dependency tooltip for the tweak name
		$nameTipParts = [System.Collections.Generic.List[string]]::new()
		$impactField = if ((Test-GuiObjectField -Object $Tweak -FieldName 'Impact') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.Impact)) { [string]$Tweak.Impact } else { $null }
		if ($impactField) { [void]$nameTipParts.Add("Impact: $impactField") }
		$whyField = if ((Test-GuiObjectField -Object $Tweak -FieldName 'WhyThisMatters') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.WhyThisMatters)) { [string]$Tweak.WhyThisMatters } else { $null }
		if ($whyField) { [void]$nameTipParts.Add($whyField) }
		$recoveryField = if ((Test-GuiObjectField -Object $Tweak -FieldName 'RecoveryLevel') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.RecoveryLevel)) { [string]$Tweak.RecoveryLevel } else { $null }
		if ($recoveryField)
		{
			$recoveryLabel = switch ($recoveryField)
			{
				'Direct'       { Get-UxString -Key 'GuiRecoveryDirect'       -Fallback 'Directly reversible' }
				'RestorePoint' { Get-UxString -Key 'GuiRecoveryRestorePoint' -Fallback 'Restore point recovery' }
				'Manual'       { Get-UxString -Key 'GuiRecoveryManual'       -Fallback 'Manual recovery' }
				'DefaultsOnly' { Get-UxString -Key 'GuiRecoveryDefaultsOnly' -Fallback 'Defaults-only recovery' }
				default        { $recoveryField }
			}
			[void]$nameTipParts.Add("Recovery: $recoveryLabel")
		}
		if ((Test-GuiObjectField -Object $Tweak -FieldName 'RequiresRestart') -and [bool]$Tweak.RequiresRestart)
		{
			[void]$nameTipParts.Add(([char]0x21BB).ToString() + ' Restart required')
		}
		if ($nameTipParts.Count -gt 0)
		{
			$nameText.ToolTip = $nameTipParts -join "`n"
		}

		# Attach visualization state to tweak for tooltip display
		if ($RowContext -and $RowContext.Metadata)
		{
			$Tweak | Add-Member -MemberType NoteProperty -Name '_StateLabel' -Value ([string]$RowContext.Metadata.StateLabel) -Force
			$Tweak | Add-Member -MemberType NoteProperty -Name '_MatchesDesired' -Value ([bool]$RowContext.Metadata.MatchesDesired) -Force
		}
		[void]($namePanel.Children.Add($nameText))
		[void]($namePanel.Children.Add((New-InfoIcon -TooltipText $(if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback $Tweak.Description } else { $Tweak.Description }) -Tweak $Tweak)))
		if ($Tweak.Caution)
		{
			[void]($namePanel.Children.Add((New-ImpactBadge)))
		}

		return $namePanel
	}

	<#
	    .SYNOPSIS
	    Internal function New-TweakHeaderBadgesPanel.
	#>

	function New-TweakHeaderBadgesPanel
	{
		param (
			[object]$Tweak,
			[object]$Metadata,
			[object]$BrushConverter,
			[System.Windows.Thickness]$BadgeSpacing,
			[object]$ActionButton = $null
		)

		$badgesPanel = New-Object System.Windows.Controls.StackPanel
		$badgesPanel.Orientation = 'Horizontal'
		$badgesPanel.VerticalAlignment = 'Center'
		$badgesPanel.HorizontalAlignment = 'Right'

		$typeBadgeLabel = [string]$Metadata.TypeLabel
		if ([string]::IsNullOrWhiteSpace($typeBadgeLabel))
		{
			$typeBadgeLabel = if (-not [string]::IsNullOrWhiteSpace([string]$Metadata.TypeBadgeLabel))
			{
				[string]$Metadata.TypeBadgeLabel
			}
			elseif (-not [string]::IsNullOrWhiteSpace([string]$Metadata.TypeKind))
			{
				[string]$Metadata.TypeKind
			}
			else
			{
				'Numeric range'
			}
		}
		$typeBadge = GUICommon\New-DialogMetadataPill -Theme $Script:CurrentTheme -Label $typeBadgeLabel -Tone $Metadata.TypeTone -ToolTip 'Type of tweak'
		if ($typeBadge)
		{
			$typeBadge.Margin = $BadgeSpacing
			[void]($badgesPanel.Children.Add($typeBadge))
		}
		$defaultBadgeLabel = if ((Test-GuiObjectField -Object $Metadata -FieldName 'DefaultValueText') -and -not [string]::IsNullOrWhiteSpace([string]$Metadata.DefaultValueText))
		{
			'Default: {0}' -f [string]$Metadata.DefaultValueText
		}
		else
		{
			$null
		}
		if (-not [string]::IsNullOrWhiteSpace($defaultBadgeLabel))
		{
			$defaultBadge = GUICommon\New-DialogMetadataPill -Theme $Script:CurrentTheme -Label $defaultBadgeLabel -Tone 'Primary' -ToolTip (Get-UxString -Key 'GuiTweakChipTooltipDefault' -Fallback 'Default value for this tweak')
			if ($defaultBadge)
			{
				$defaultBadge.Margin = $BadgeSpacing
				[void]($badgesPanel.Children.Add($defaultBadge))
			}
		}
		if ($ActionButton)
		{
			$ActionButton.Margin = $BadgeSpacing
			[void]($badgesPanel.Children.Add($ActionButton))
		}
		if ([bool]$Tweak.RequiresRestart)
		{
			$restartBadge = New-Object System.Windows.Controls.TextBlock
			$restartBadge.Text = [char]0x21BB + ' Restart'
			$restartBadge.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
			$restartBadge.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.RiskMediumBadge)
			$restartBadge.Background = $BrushConverter.ConvertFromString($Script:CurrentTheme.TabActiveBg)
			$restartBadge.Padding = $Script:T.BadgePad
			$restartBadge.Margin = $BadgeSpacing
			$restartBadge.VerticalAlignment = 'Center'
			[void]($badgesPanel.Children.Add($restartBadge))
		}
		$riskBadge = New-RiskBadge -Level $Tweak.Risk
		if ($riskBadge)
		{
			$riskBadge.Margin = $BadgeSpacing
			[void]($badgesPanel.Children.Add($riskBadge))
		}
		if ($Metadata.TroubleshootingOnly)
		{
			$troubleshootingBadge = New-TroubleshootingOnlyBadge
			if ($troubleshootingBadge)
			{
				$troubleshootingBadge.Margin = $BadgeSpacing
				[void]($badgesPanel.Children.Add($troubleshootingBadge))
			}
		}
		if ((Test-GuiObjectField -Object $Tweak -FieldName 'Restorable') -and $null -ne $Tweak.Restorable -and -not [bool]$Tweak.Restorable)
		{
			$restorableBadge = GUICommon\New-DialogMetadataPill -Theme $Script:CurrentTheme -Label (Get-UxString -Key 'GuiBadgeManualRecovery' -Fallback 'Manual recovery') -Tone 'Danger' -ToolTip (Get-UxString -Key 'GuiBadgeManualRecoveryTooltip' -Fallback 'This change cannot be fully rolled back automatically.')
			if ($restorableBadge)
			{
				$restorableBadge.Margin = $BadgeSpacing
				[void]($badgesPanel.Children.Add($restorableBadge))
			}
		}
		if ((Test-IsSafeModeUX) -and (Test-GuiObjectField -Object $Tweak -FieldName 'PresetTier') -and [string]$Tweak.PresetTier -eq 'Minimal')
		{
			$recommendedBadge = GUICommon\New-DialogMetadataPill -Theme $Script:CurrentTheme -Label (Get-UxString -Key 'GuiBadgeRecommended' -Fallback 'Recommended') -Tone 'Success' -ToolTip (Get-UxString -Key 'GuiBadgeRecommendedTooltip' -Fallback 'Included in the recommended Quick Start preset')
			if ($recommendedBadge)
			{
				$recommendedBadge.Margin = $BadgeSpacing
				[void]($badgesPanel.Children.Add($recommendedBadge))
			}
		}

		return $badgesPanel
	}

	<#
	    .SYNOPSIS
	    Internal function Get-TweakDefaultToggleState.
	#>

	function Get-TweakDefaultToggleState
	{
		param ([object]$Tweak)

		if (Test-GuiObjectField -Object $Tweak -FieldName 'Default')
		{
			return [bool](Get-GuiObjectField -Object $Tweak -FieldName 'Default')
		}
		if (Test-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		{
			return [bool](Get-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		}
		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Get-TweakDefaultChoiceSelectedIndex.
	#>

	function Get-TweakDefaultChoiceSelectedIndex
	{
		param ([object]$Tweak)

		$choiceOptions = if ($Tweak.Options) { [object[]]@($Tweak.Options) } else { [object[]]@() }
		$defaultValue = $null
		if (Test-GuiObjectField -Object $Tweak -FieldName 'Default')
		{
			$defaultValue = [string](Get-GuiObjectField -Object $Tweak -FieldName 'Default')
		}
		elseif (Test-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		{
			$defaultValue = [string](Get-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		}

		if ([string]::IsNullOrWhiteSpace([string]$defaultValue) -or $choiceOptions.Count -eq 0)
		{
			return -1
		}

		$defaultIndex = [array]::IndexOf($choiceOptions, [string]$defaultValue)
		if ($defaultIndex -ge 0)
		{
			return $defaultIndex
		}

		return -1
	}

	<#
	    .SYNOPSIS
	    Internal function Get-TweakDefaultNumericRangeValues.
	#>

	function Get-TweakDefaultNumericRangeValues
	{
		param (
			[object]$Tweak,
			[object]$NumericRange
		)

		$defaultSource = $null
		if (Test-GuiObjectField -Object $Tweak -FieldName 'Default')
		{
			$defaultSource = Get-GuiObjectField -Object $Tweak -FieldName 'Default'
		}
		elseif (Test-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		{
			$defaultSource = Get-GuiObjectField -Object $Tweak -FieldName 'WinDefault'
		}

		$defaultAC = $null
		$defaultDC = $null
		if ($null -ne $defaultSource)
		{
			$defaultAC = Get-GuiNumericRangeChannelValue -Value $defaultSource -Channel 'AC' -NumericRange $NumericRange
			$defaultDC = Get-GuiNumericRangeChannelValue -Value $defaultSource -Channel 'DC' -NumericRange $NumericRange
		}

		return [pscustomobject]@{
			ACValue = $defaultAC
			DCValue = $defaultDC
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-TweakDefaultDateSelection.
	#>

	function Get-TweakDefaultDateSelection
	{
		param ([object]$Tweak)

		$defaultRun = if (Test-GuiObjectField -Object $Tweak -FieldName 'Default') { [bool](Get-GuiObjectField -Object $Tweak -FieldName 'Default') } elseif (Test-GuiObjectField -Object $Tweak -FieldName 'WinDefault') { [bool](Get-GuiObjectField -Object $Tweak -FieldName 'WinDefault') } else { $false }
		$defaultDate = $null
		foreach ($candidateField in @('DefaultDate', 'DefaultValue', 'Value'))
		{
			if (Test-GuiObjectField -Object $Tweak -FieldName $candidateField)
			{
				$candidateValue = [string](Get-GuiObjectField -Object $Tweak -FieldName $candidateField)
				if (-not [string]::IsNullOrWhiteSpace($candidateValue))
				{
					$defaultDate = $candidateValue
					break
				}
			}
		}

		return [pscustomobject]@{
			Run = [bool]$defaultRun
			Value = $defaultDate
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Get-TweakDefaultActionState.
	#>

	function Get-TweakDefaultActionState
	{
		param ([object]$Tweak)

		if (Test-GuiObjectField -Object $Tweak -FieldName 'Default')
		{
			return [bool](Get-GuiObjectField -Object $Tweak -FieldName 'Default')
		}
		if (Test-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		{
			return [bool](Get-GuiObjectField -Object $Tweak -FieldName 'WinDefault')
		}
		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Invoke-TweakRowResetToDefaults.
	#>

	function Invoke-TweakRowResetToDefaults
	{
		param (
			[object]$Tweak,
			[object]$RowContext,
			[object]$StateControl
		)

		if (-not $Tweak -or -not $RowContext)
		{
			return
		}

		$stateType = if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'Type')) { [string]$StateControl.Type } elseif (Test-GuiObjectField -Object $Tweak -FieldName 'Type') { [string]$Tweak.Type } else { 'Toggle' }
		try
		{
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring'))
			{
				$StateControl.IsRestoring = $true
			}

			switch ($stateType)
			{
				'Toggle'
				{
					$defaultChecked = Get-TweakDefaultToggleState -Tweak $Tweak
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'CheckBox') -and $StateControl.CheckBox)
					{
						$StateControl.CheckBox.IsChecked = [bool]$defaultChecked
					}
					if ($StateControl)
					{
						$StateControl.IsChecked = [bool]$defaultChecked
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'StatusContext') -and $StateControl.StatusContext -and $StateControl.StatusContext.StatusLabel)
					{
						$statusLabel = $StateControl.StatusContext.StatusLabel
						$statusLabel.Text = if ($defaultChecked) { Get-UxToggleStateLabel -Enabled $true } else { Get-UxToggleStateLabel -Enabled $false }
						$statusLabel.Foreground = & $RowContext.ConvertBrushCapture -Color (if ($defaultChecked) { $StateControl.StatusContext.OnColor } else { $StateControl.StatusContext.OffColor }) -Context 'Build-TweakRow/ResetToggleStatus'
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'Card') -and $StateControl.Card)
					{
						try { $StateControl.Card.Opacity = if ($defaultChecked) { 1.0 } else { 0.7 } } catch { $null = $_ }
					}
					& $RowContext.RemoveExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				}
				'Choice'
				{
					$defaultIndex = Get-TweakDefaultChoiceSelectedIndex -Tweak $Tweak
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'ComboBox') -and $StateControl.ComboBox)
					{
						$StateControl.ComboBox.SelectedIndex = [int]$defaultIndex
					}
					if ($StateControl)
					{
						$StateControl.SelectedIndex = [int]$defaultIndex
						if (Test-GuiObjectField -Object $StateControl -FieldName 'ComboBox') {
							$StateControl.Value = if ($defaultIndex -ge 0 -and $defaultIndex -lt $StateControl.ComboBox.Items.Count) { [string]$StateControl.ComboBox.Items[$defaultIndex] } else { $null }
						}
					}
					& $RowContext.RemoveExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				}
				'NumericRange'
				{
					$numericRange = if (Test-GuiObjectField -Object $Tweak -FieldName 'NumericRange') { Get-GuiObjectField -Object $Tweak -FieldName 'NumericRange' } else { $null }
					$defaultValues = Get-TweakDefaultNumericRangeValues -Tweak $Tweak -NumericRange $numericRange
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'CheckBox') -and $StateControl.CheckBox)
					{
						$StateControl.CheckBox.IsChecked = $false
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'ACSlider') -and $StateControl.ACSlider)
					{
						$StateControl.ACSlider.IsEnabled = $false
						if ($null -ne $defaultValues.ACValue) { $StateControl.ACSlider.Value = [double]$defaultValues.ACValue }
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'DCSlider') -and $StateControl.DCSlider)
					{
						$StateControl.DCSlider.IsEnabled = $false
						if ($null -ne $defaultValues.DCValue) { $StateControl.DCSlider.Value = [double]$defaultValues.DCValue }
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'ACValueText') -and $StateControl.ACValueText)
					{
						$StateControl.ACValueText.Text = Format-GuiNumericRangeValueText -Value $StateControl.ACSlider.Value -NumericRange $numericRange -Units $StateControl.Units
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'DCValueText') -and $StateControl.DCValueText)
					{
						$StateControl.DCValueText.Text = Format-GuiNumericRangeValueText -Value $StateControl.DCSlider.Value -NumericRange $numericRange -Units $StateControl.Units
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'SummaryText') -and $StateControl.SummaryText)
					{
						$StateControl.SummaryText.Text = (Get-UxLocalizedString -Key 'GuiNumericRangeSelectedValue' -Fallback 'Selected values: {0}' -FormatArgs @((Format-GuiPowerSchemeValueText -Value ([pscustomobject]@{ ACValue = $StateControl.ACSlider.Value; DCValue = $StateControl.DCSlider.Value }) -NumericRange $numericRange -Units $StateControl.Units)))
					}
					if ($StateControl)
					{
						$StateControl.IsChecked = $false
						$StateControl.ACValue = $StateControl.ACSlider.Value
						$StateControl.DCValue = $StateControl.DCSlider.Value
						$StateControl.Value = [pscustomobject]@{
							ACValue = $StateControl.ACSlider.Value
							DCValue = $StateControl.DCSlider.Value
						}
					}
					& $RowContext.RemoveExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				}
				'Date'
				{
					$defaultDateSelection = Get-TweakDefaultDateSelection -Tweak $Tweak
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'CheckBox') -and $StateControl.CheckBox)
					{
						$StateControl.CheckBox.IsChecked = [bool]$defaultDateSelection.Run
					}
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'DatePicker') -and $StateControl.DatePicker)
					{
						if ($defaultDateSelection.Value)
						{
							try { $StateControl.DatePicker.SelectedDate = [datetime]$defaultDateSelection.Value } catch { $StateControl.DatePicker.SelectedDate = $null }
						}
						else
						{
							$StateControl.DatePicker.SelectedDate = $null
						}
						$StateControl.DatePicker.IsEnabled = [bool]$defaultDateSelection.Run
					}
					if ($StateControl)
					{
						$StateControl.IsChecked = [bool]$defaultDateSelection.Run
						$resolvedDefaultDate = $null
						if (-not [string]::IsNullOrWhiteSpace([string]$defaultDateSelection.Value))
						{
							try
							{
								$resolvedDefaultDate = [datetime]$defaultDateSelection.Value
							}
							catch
							{
								$resolvedDefaultDate = $null
							}
						}
						$StateControl.SelectedDate = $resolvedDefaultDate
					}
					& $RowContext.RemoveExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				}
				'Action'
				{
					$defaultChecked = Get-TweakDefaultActionState -Tweak $Tweak
					if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'CheckBox') -and $StateControl.CheckBox)
					{
						$StateControl.CheckBox.IsChecked = [bool]$defaultChecked
					}
					if ($StateControl)
					{
						$StateControl.IsChecked = [bool]$defaultChecked
					}
					& $RowContext.RemoveExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
				}
			}
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}
		finally
		{
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring'))
			{
				$StateControl.IsRestoring = $false
			}
		}
	}

	<#
	    .SYNOPSIS
	    Internal function New-TweakResetButton.
	#>

	function New-TweakResetButton
	{
		param (
			[object]$Tweak,
			[object]$RowContext,
			[object]$StateControl
		)

		if (-not $Tweak -or -not $RowContext)
		{
			return $null
		}

		$button = New-PresetButton -Label (Get-UxString -Key 'GuiResetButton' -Fallback 'Reset') -Variant 'Subtle' -Compact
		$button.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
		$button.VerticalAlignment = 'Center'
		$button.ToolTip = (Get-UxString -Key 'GuiTweakResetTooltip' -Fallback 'Restore this option to its default state.')
		$null = Register-GuiEventHandler -Source $button -EventName 'Click' -Handler ({
			Invoke-TweakRowResetToDefaults -Tweak $Tweak -RowContext $RowContext -StateControl $StateControl
		}.GetNewClosure())
		return $button
	}

	<#
	    .SYNOPSIS
	    Internal function Add-TweakMetadataDetails.
	#>

	function Add-TweakMetadataDetails
	{
		param (
			[System.Windows.Controls.Panel]$Container,
			[object]$Tweak,
			[object]$RowContext,
			[string]$DescriptionText,
			[string]$DescriptionColor,
			[System.Windows.Thickness]$DescriptionMargin,
			[System.Windows.Thickness]$MetadataMargin,
			[System.Windows.Thickness]$BlastMargin
		)

		$descriptionTextBlock = New-Object System.Windows.Controls.TextBlock
		$descriptionTextBlock.Text = $DescriptionText
		$descriptionTextBlock.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
		$descriptionTextBlock.Foreground = $RowContext.BrushConverter.ConvertFromString($DescriptionColor)
		$descriptionTextBlock.Margin = $DescriptionMargin
		$descriptionTextBlock.TextWrapping = 'Wrap'
		[void]($Container.Children.Add($descriptionTextBlock))

		# Show CautionReason inline on the tweak row for High-risk items so the
		# consequence text is visible by default without expanding the caution section.
		if ([string]$Tweak.Risk -eq 'High' -and [bool]$Tweak.Caution -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.CautionReason))
		{
			$cautionColor = if ($Script:CurrentTheme -and $Script:CurrentTheme.CautionText) { $Script:CurrentTheme.CautionText } else { '#E5A84B' }
			$cautionInline = New-Object System.Windows.Controls.TextBlock
			$cautionInline.TextWrapping = 'Wrap'
			$cautionInline.Margin = $DescriptionMargin
			$cautionInline.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
			$cautionInline.FontWeight = [System.Windows.FontWeights]::Medium
			$cautionInline.Foreground = $RowContext.BrushConverter.ConvertFromString($cautionColor)

			$cautionIcon = New-Object System.Windows.Documents.Run
			$cautionIcon.Text = ([char]0x26A0).ToString() + ' '
			[void]($cautionInline.Inlines.Add($cautionIcon))

			$cautionText = New-Object System.Windows.Documents.Run
			$cautionText.Text = [string]$Tweak.CautionReason
			[void]($cautionInline.Inlines.Add($cautionText))

			[void]($Container.Children.Add($cautionInline))
		}

		try
		{
			$detailMetaPanel = New-TweakMetadataChipPanel -Metadata $RowContext.Metadata -IncludeType:$false -IncludeState:$true -IncludeRestart:$false -IncludeRestorable:$false -IncludeRecoveryLevel:$true -UseCompactRecoveryLevelLabel:$RowContext.UseCompactRecoveryLevelLabel -IncludeScenarioTags:$true
		}
		catch
		{
			throw "Add-TweakMetadataDetails/MetadataChips failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		if ($detailMetaPanel)
		{
			$detailMetaPanel.Margin = $MetadataMargin
			[void]($Container.Children.Add($detailMetaPanel))
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$RowContext.Metadata.BlastRadius))
		{
			$blastText = New-Object System.Windows.Controls.TextBlock
			$blastText.Text = [string]$RowContext.Metadata.BlastRadius
			$blastText.TextWrapping = 'Wrap'
			$blastText.Margin = $BlastMargin
			$blastText.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
			$blastText.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
			[void]($Container.Children.Add($blastText))
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Add-TweakWhyBlockDetails.
	#>

	function Add-TweakWhyBlockDetails
	{
		param (
			[System.Windows.Controls.Panel]$Container,
			[object]$Tweak,
			[int]$LeftIndent = 0,
			[System.Windows.Thickness]$RowMargin = [System.Windows.Thickness]::new(0, 2, 0, 0)
		)

		$whyBlock = New-WhyThisMattersButton -Tweak $Tweak -LeftIndent $LeftIndent
		if (-not $whyBlock)
		{
			return $null
		}

		$whyRow = New-Object System.Windows.Controls.Grid
		[void]($whyRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($whyRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))
		$whyRow.Margin = $RowMargin
		[System.Windows.Controls.Grid]::SetColumn($whyBlock, 1)
		[void]($whyRow.Children.Add($whyBlock))
		[void]($Container.Children.Add($whyRow))
		if ($whyBlock.Tag)
		{
			[void]($Container.Children.Add($whyBlock.Tag))
		}

		return $whyBlock
	}

	<#
	    .SYNOPSIS
	    Internal function Get-GameModePlanEntryForTweak.
	#>

	function Get-GameModePlanEntryForTweak
	{
		param ([object]$Tweak)

		$currentPlan = Get-GameModePlan
		if (-not [bool]$Script:GameMode -or -not $currentPlan -or @($currentPlan).Count -eq 0)
		{
			return $null
		}

		foreach ($planEntry in @($currentPlan))
		{
			if ($planEntry -and (Test-GuiObjectField -Object $planEntry -FieldName 'Function') -and [string]$planEntry.Function -eq [string]$Tweak.Function)
			{
				return $planEntry
			}
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ToggleInitialCheckedState.
	#>

	function Get-ToggleInitialCheckedState
	{
		param (
			[int]$Index,
			[object]$Tweak
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			$planToggle = if ((Test-GuiObjectField -Object $planMatch -FieldName 'ToggleParam')) { [string]$planMatch.ToggleParam } elseif ((Test-GuiObjectField -Object $planMatch -FieldName 'Selection')) { [string]$planMatch.Selection } else { $null }
			return (-not [string]::IsNullOrWhiteSpace($planToggle) -and [string]$planToggle -eq [string]$Tweak.OnParam)
		}

		# Explicit preset selections must survive tab rebuilds even when the target
		# tab has not been materialized into live controls yet.
		$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Toggle')
		{
			return ([string]$explicitSelection.State -eq 'On')
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder -and (Test-GuiObjectField -Object $placeholder -FieldName 'IsChecked'))
		{
			return [bool]$placeholder.IsChecked
		}

		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ActionInitialCheckedState.
	#>

	function Get-ActionInitialCheckedState
	{
		param (
			[int]$Index,
			[object]$Tweak
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			return $true
		}

		$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Action')
		{
			return [bool]$explicitSelection.Run
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder -and (Test-GuiObjectField -Object $placeholder -FieldName 'IsChecked'))
		{
			return [bool]$placeholder.IsChecked
		}

		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Get-ChoiceInitialSelectedIndex.
	#>

	function Get-ChoiceInitialSelectedIndex
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object[]]$ChoiceOptions = @(),
			[object]$RowContext = $null
		)

		if ($RowContext -and (Test-GuiObjectField -Object $RowContext -FieldName 'GetExplicitSelectionDefinition') -and $RowContext.GetExplicitSelectionDefinition)
		{
			$explicitSelection = & $RowContext.GetExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
			if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Choice' -and -not [string]::IsNullOrWhiteSpace([string]$explicitSelection.Value))
			{
				$explicitIndex = [array]::IndexOf($ChoiceOptions, [string]$explicitSelection.Value)
				if ($explicitIndex -ge 0)
				{
					return $explicitIndex
				}
			}
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder -and (Test-GuiObjectField -Object $placeholder -FieldName 'SelectedIndex'))
		{
			return [int]$placeholder.SelectedIndex
		}

		return -1
	}

	<#
	    .SYNOPSIS
	    Internal function Get-NumericRangeInitialCheckedState.
	#>

	function Get-NumericRangeInitialCheckedState
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext = $null
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			return $true
		}

		$explicitSelection = if ($RowContext -and (Test-GuiObjectField -Object $RowContext -FieldName 'GetExplicitSelectionDefinition') -and $RowContext.GetExplicitSelectionDefinition)
		{
			& $RowContext.GetExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		}
		else
		{
			Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		}
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'NumericRange')
		{
			return $true
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder -and (Test-GuiObjectField -Object $placeholder -FieldName 'IsChecked'))
		{
			return [bool]$placeholder.IsChecked
		}

		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Get-NumericRangeInitialValue.
	#>

	function Get-NumericRangeInitialValue
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[string]$Channel = 'AC',
			[object]$NumericRange = $null,
			[object]$RowContext = $null
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			$planValue = Get-GuiNumericRangeChannelValue -Value $planMatch -Channel $Channel -NumericRange $NumericRange
			if ($null -ne $planValue)
			{
				return $planValue
			}
		}

		$explicitSelection = if ($RowContext -and (Test-GuiObjectField -Object $RowContext -FieldName 'GetExplicitSelectionDefinition') -and $RowContext.GetExplicitSelectionDefinition)
		{
			& $RowContext.GetExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		}
		else
		{
			Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		}
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'NumericRange')
		{
			$explicitValue = Get-GuiNumericRangeChannelValue -Value $explicitSelection -Channel $Channel -NumericRange $NumericRange
			if ($null -ne $explicitValue)
			{
				return $explicitValue
			}
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder)
		{
			$placeholderValue = Get-GuiNumericRangeChannelValue -Value $placeholder -Channel $Channel -NumericRange $NumericRange
			if ($null -ne $placeholderValue)
			{
				return $placeholderValue
			}
		}

		foreach ($candidateField in @('Default', 'WinDefault'))
		{
			if (Test-GuiObjectField -Object $Tweak -FieldName $candidateField)
			{
				$initialValue = Get-GuiNumericRangeChannelValue -Value (Get-GuiObjectField -Object $Tweak -FieldName $candidateField) -Channel $Channel -NumericRange $NumericRange
				if ($null -ne $initialValue)
				{
					return $initialValue
				}
			}
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function ConvertTo-GuiDateTimeValue.
	#>

	function ConvertTo-GuiDateTimeValue
	{
		param ([object]$Value)

		if ($null -eq $Value)
		{
			return $null
		}

		if ($Value -is [datetime])
		{
			return [datetime]$Value
		}

		$rawValue = [string]$Value
		if ([string]::IsNullOrWhiteSpace($rawValue))
		{
			return $null
		}

		$parsedDate = [datetime]::MinValue
		if ([datetime]::TryParseExact($rawValue, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate))
		{
			return $parsedDate
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Get-DateInitialRunState.
	#>

	function Get-DateInitialRunState
	{
		param (
			[int]$Index,
			[object]$Tweak
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			if (Test-GuiObjectField -Object $planMatch -FieldName 'Run')
			{
				return [bool]$planMatch.Run
			}
			if ((Test-GuiObjectField -Object $planMatch -FieldName 'Value') -and -not [string]::IsNullOrWhiteSpace([string]$planMatch.Value))
			{
				return $true
			}
			if ((Test-GuiObjectField -Object $planMatch -FieldName 'DateValue') -and -not [string]::IsNullOrWhiteSpace([string]$planMatch.DateValue))
			{
				return $true
			}
		}

		$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Date')
		{
			if (Test-GuiObjectField -Object $explicitSelection -FieldName 'Run')
			{
				return [bool]$explicitSelection.Run
			}
			if ((Test-GuiObjectField -Object $explicitSelection -FieldName 'Value') -and -not [string]::IsNullOrWhiteSpace([string]$explicitSelection.Value))
			{
				return $true
			}
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder -and (Test-GuiObjectField -Object $placeholder -FieldName 'IsChecked'))
		{
			return [bool]$placeholder.IsChecked
		}

		if (Test-GuiObjectField -Object $Tweak -FieldName 'Default')
		{
			return [bool]$Tweak.Default
		}

		return $false
	}

	<#
	    .SYNOPSIS
	    Internal function Get-DateInitialSelectedDate.
	#>

	function Get-DateInitialSelectedDate
	{
		param (
			[int]$Index,
			[object]$Tweak
		)

		$planMatch = Get-GameModePlanEntryForTweak -Tweak $Tweak
		if ($planMatch)
		{
			foreach ($fieldName in @('DateValue', 'Value', 'SelectedDate'))
			{
				if (Test-GuiObjectField -Object $planMatch -FieldName $fieldName)
				{
					$dateValue = ConvertTo-GuiDateTimeValue -Value (Get-GuiObjectField -Object $planMatch -FieldName $fieldName)
					if ($dateValue)
					{
						return $dateValue
					}
				}
			}
		}

		$explicitSelection = Get-GuiExplicitSelectionDefinition -FunctionName ([string]$Tweak.Function)
		if ($explicitSelection -and [string]$explicitSelection.Type -eq 'Date')
		{
			foreach ($fieldName in @('DateValue', 'Value', 'SelectedDate'))
			{
				if (Test-GuiObjectField -Object $explicitSelection -FieldName $fieldName)
				{
					$dateValue = ConvertTo-GuiDateTimeValue -Value (Get-GuiObjectField -Object $explicitSelection -FieldName $fieldName)
					if ($dateValue)
					{
						return $dateValue
					}
				}
			}
		}

		$placeholder = $Script:Controls[$Index]
		if ($placeholder)
		{
			if ((Test-GuiObjectField -Object $placeholder -FieldName 'SelectedDate') -and $placeholder.SelectedDate)
			{
				$dateValue = ConvertTo-GuiDateTimeValue -Value $placeholder.SelectedDate
				if ($dateValue)
				{
					return $dateValue
				}
			}
			if ((Test-GuiObjectField -Object $placeholder -FieldName 'DatePicker') -and $placeholder.DatePicker -and (Test-GuiObjectField -Object $placeholder.DatePicker -FieldName 'SelectedDate') -and $placeholder.DatePicker.SelectedDate)
			{
				$dateValue = ConvertTo-GuiDateTimeValue -Value $placeholder.DatePicker.SelectedDate
				if ($dateValue)
				{
					return $dateValue
				}
			}
		}

		foreach ($candidateField in @('DefaultDate', 'DefaultValue', 'Value'))
		{
			if (Test-GuiObjectField -Object $Tweak -FieldName $candidateField)
			{
				$dateValue = ConvertTo-GuiDateTimeValue -Value (Get-GuiObjectField -Object $Tweak -FieldName $candidateField)
				if ($dateValue)
				{
					return $dateValue
				}
			}
		}

		return $null
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiDateSelectionHandlers.
	#>

	function Register-GuiDateSelectionHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[System.Windows.Controls.DatePicker]$DatePicker,
			[string]$FunctionName,
			[string]$DateParam,
			[object]$RowContext,
			[object]$StateControl
		)

		if (-not $CheckBox -or -not $DatePicker)
		{
			return
		}

		$dateParamName = if ([string]::IsNullOrWhiteSpace([string]$DateParam)) { 'StartDate' } else { [string]$DateParam }
		$syncSelectionState = {
			param([bool]$IsChecked)

			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			$selectedDateValue = $null
			if ($DatePicker.SelectedDate)
			{
				$selectedDateValue = ([datetime]$DatePicker.SelectedDate).ToString('yyyy-MM-dd')
			}

			if ($StateControl)
			{
				$StateControl.IsChecked = [bool]$IsChecked
				$StateControl.SelectedDate = $DatePicker.SelectedDate
			}

			if ([string]::IsNullOrWhiteSpace($selectedDateValue))
			{
				& $RowContext.RemoveExplicitSelectionDefinition -FunctionName $FunctionName
				if ($RowContext.SyncGameModePlanFromControlsScript)
				{
					& $RowContext.SyncGameModePlanFromControlsScript
				}
				return
			}

			$definition = [ordered]@{
				Function = $FunctionName
				Type = 'Date'
				Run = [bool]$IsChecked
				DateParam = $dateParamName
				Value = $selectedDateValue
				Source = if ($currentExplicitDefinition -and (Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
			}
			& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]$definition)

			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure()

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$DatePicker.IsEnabled = $true
			if (-not $DatePicker.SelectedDate)
			{
				$DatePicker.SelectedDate = [datetime]::Today
				return
			}

			& $syncSelectionState $true
		}.GetNewClosure())

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$DatePicker.IsEnabled = $false
			& $syncSelectionState $false
		}.GetNewClosure())

		$null = Register-GuiEventHandler -Source $DatePicker -EventName 'SelectedDateChanged' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			if ($DatePicker.SelectedDate)
			{
				$DatePicker.IsEnabled = $true
				if (-not [bool]$CheckBox.IsChecked)
				{
					$CheckBox.IsChecked = $true
					return
				}

				& $syncSelectionState $true
			}
			elseif ([bool]$CheckBox.IsChecked)
			{
				$CheckBox.IsChecked = $false
				return
			}
			else
			{
				$DatePicker.IsEnabled = $false
				& $syncSelectionState $false
			}
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Finalize-DateRow.
	#>

	function Finalize-DateRow
	{
		param (
			[System.Windows.Controls.Border]$Card,
			[object]$ChildContent,
			[System.Windows.Controls.CheckBox]$CheckBox,
			[System.Windows.Controls.DatePicker]$DatePicker,
			[object]$StateControl,
			[object]$Tweak,
			[int]$Index,
			[object]$RowContext
		)

		try { $Card.Child = $ChildContent } catch { throw "Finalize/SetChild: $($_.Exception.Message)" }
		try { Add-CardHoverEffects -Card $Card -FocusSources @($CheckBox, $DatePicker) } catch { throw "Finalize/HoverEffects: $($_.Exception.Message)" }
		try { $Card.Opacity = if ($CheckBox.IsChecked) { 1.0 } else { 0.7 } } catch { throw "Finalize/Opacity: $($_.Exception.Message)" }
		$cardRef = $Card
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({ $cardRef.Opacity = 1.0 }.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({ $cardRef.Opacity = 0.7 }.GetNewClosure())
		$Script:Controls[$Index] = $StateControl
		return $Card
	}

	<#
	    .SYNOPSIS
	    Internal function New-DateTweakRow.
	#>

	function New-DateTweakRow
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext
		)

		$card = New-TweakRowCard -BrushConverter $RowContext.BrushConverter -Margin $RowContext.RowCardMargin -Padding $RowContext.RowCardPadding -Tweak $Tweak
		$leftStack = New-Object System.Windows.Controls.StackPanel
		$leftStack.Orientation = 'Vertical'
		$leftStack.VerticalAlignment = 'Center'

		$checkBox = New-ToggleLikeCheckBox -Index $Index -InitialChecked (Get-DateInitialRunState -Index $Index -Tweak $Tweak) -BrushConverter $RowContext.BrushConverter
		Apply-PendingLinkedToggleState -CheckBox $checkBox -FunctionName ([string]$Tweak.Function)
		$stateControl = [pscustomobject]@{
			Type = 'Date'
			IsChecked = [bool]$checkBox.IsChecked
			CheckBox = $checkBox
			DatePicker = $null
			SelectedDate = $null
			Card = $card
			IsRestoring = $false
		}
		$resetButton = New-TweakResetButton -Tweak $Tweak -RowContext $RowContext -StateControl $stateControl
		[void]($leftStack.Children.Add((New-ToggleLikeHeaderGrid -CheckBox $checkBox -Tweak $Tweak -RowContext $RowContext -ResetButton $resetButton)))

		$datePicker = New-Object System.Windows.Controls.DatePicker
		$datePicker.MinWidth = $Script:GuiLayout.ComboBoxMinWidth
		$datePicker.VerticalAlignment = 'Center'
		$datePicker.Margin = $Script:T.ComboLeft
		$datePicker.SelectedDateFormat = 'Short'
		$datePicker.IsTodayHighlighted = $true
		$datePicker.DisplayDate = Get-Date
		$datePicker.IsEnabled = [bool]$checkBox.IsChecked

		$initialSelectedDate = Get-DateInitialSelectedDate -Index $Index -Tweak $Tweak
		if (-not $initialSelectedDate -and [bool]$checkBox.IsChecked)
		{
			$initialSelectedDate = [datetime]::Today
		}
		if ($initialSelectedDate)
		{
			$datePicker.SelectedDate = $initialSelectedDate
		}
		$stateControl.DatePicker = $datePicker
		$stateControl.SelectedDate = $datePicker.SelectedDate
		$stateControl.IsChecked = [bool]$checkBox.IsChecked

		$dateRow = New-Object System.Windows.Controls.StackPanel
		$dateRow.Orientation = 'Horizontal'
		$dateRow.VerticalAlignment = 'Center'
		$dateRow.Margin = [System.Windows.Thickness]::new(28, 5, 0, 0)

		$dateLabel = New-Object System.Windows.Controls.TextBlock
		$dateLabel.Text = Get-UxString -Key 'GuiPauseStartDateLabel' -Fallback 'Pause start date:'
		$dateLabel.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
		$dateLabel.VerticalAlignment = 'Center'
		$dateLabel.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
		$dateLabel.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
		[void]($dateRow.Children.Add($dateLabel))
		[void]($dateRow.Children.Add($datePicker))
		[void]($leftStack.Children.Add($dateRow))

		Add-TweakMetadataDetails -Container $leftStack -Tweak $Tweak -RowContext $RowContext -DescriptionText $(if ($Tweak.Description) { if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback $Tweak.Description } else { $Tweak.Description } } else { Get-UxString -Key 'GuiPauseStartDateDescription' -Fallback 'Pauses updates starting on the selected date.' }) -DescriptionColor $Script:CurrentTheme.TextSecondary -DescriptionMargin $Script:T.DescIndent -MetadataMargin $Script:T.MetaIndent -BlastMargin $Script:T.BlastIndent
		[void](Add-TweakWhyBlockDetails -Container $leftStack -Tweak $Tweak -LeftIndent 28 -RowMargin $Script:T.WhyIndent)

		$stateControl.DatePicker = $datePicker
		$stateControl.SelectedDate = $datePicker.SelectedDate
		$stateControl.IsChecked = [bool]$checkBox.IsChecked

		Register-GuiDateSelectionHandlers -CheckBox $checkBox -DatePicker $datePicker -FunctionName ([string]$Tweak.Function) -DateParam $(if ((Test-GuiObjectField -Object $Tweak -FieldName 'DateParam')) { [string]$Tweak.DateParam } else { 'StartDate' }) -RowContext $RowContext -StateControl $stateControl
		return Finalize-DateRow -Card $card -ChildContent $leftStack -CheckBox $checkBox -DatePicker $datePicker -StateControl $stateControl -Tweak $Tweak -Index $Index -RowContext $RowContext
	}

	<#
	    .SYNOPSIS
	    Internal function Apply-PendingLinkedToggleState.
	#>

	function Apply-PendingLinkedToggleState
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[string]$FunctionName
		)

		Ensure-PendingLinkedStateCollections

		if ($Script:PendingLinkedChecks -and $Script:PendingLinkedChecks.Contains($FunctionName))
		{
			$CheckBox.IsChecked = $true
			[void]($Script:PendingLinkedChecks.Remove($FunctionName))
		}
		elseif ($Script:PendingLinkedUnchecks -and $Script:PendingLinkedUnchecks.Contains($FunctionName))
		{
			$CheckBox.IsChecked = $false
			[void]($Script:PendingLinkedUnchecks.Remove($FunctionName))
		}
	}

	<#
	    .SYNOPSIS
	    Internal function New-ToggleLikeCheckBox.
	#>

	function New-ToggleLikeCheckBox
	{
		param (
			[int]$Index,
			[bool]$InitialChecked,
			[object]$BrushConverter
		)

		$checkBox = New-Object System.Windows.Controls.CheckBox
		$checkBox.VerticalAlignment = 'Center'
		$checkBox.Margin = $Script:T.CheckBoxRight
		$checkBox.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
		$checkBox.IsChecked = $InitialChecked
		$checkBox.Tag = $Index
		$checkBox.Foreground = $BrushConverter.ConvertFromString($Script:CurrentTheme.TextPrimary)
		return $checkBox
	}

	<#
	    .SYNOPSIS
	    Internal function New-ToggleLikeHeaderGrid.
	#>

	function New-ToggleLikeHeaderGrid
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[object]$Tweak,
			[object]$RowContext,
			[object]$ResetButton = $null
		)

		$headerGrid = New-Object System.Windows.Controls.Grid
		[void]($headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))
		[void]($headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($headerGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))

		[System.Windows.Controls.Grid]::SetColumn($CheckBox, 0)
		[void]($headerGrid.Children.Add($CheckBox))

		try
		{
			$nameRow = New-TweakNamePanel -Tweak $Tweak -BrushConverter $RowContext.BrushConverter -UseWrapPanel
		}
		catch
		{
			throw "New-ToggleLikeHeaderGrid/NamePanel failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		[System.Windows.Controls.Grid]::SetColumn($nameRow, 1)
		[void]($headerGrid.Children.Add($nameRow))

		try
		{
			$badgesPanel = New-TweakHeaderBadgesPanel -Tweak $Tweak -Metadata $RowContext.Metadata -BrushConverter $RowContext.BrushConverter -BadgeSpacing $RowContext.BadgeSpacing -ActionButton $ResetButton
		}
		catch
		{
			throw "New-ToggleLikeHeaderGrid/Badges failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		[System.Windows.Controls.Grid]::SetColumn($badgesPanel, 2)
		[void]($headerGrid.Children.Add($badgesPanel))

		return $headerGrid
	}

	<#
	    .SYNOPSIS
	    Internal function New-ChoiceHeaderGrid.
	#>

	function New-ChoiceHeaderGrid
	{
		param (
			[object]$Tweak,
			[object]$RowContext,
			[object]$ResetButton = $null
		)

		$nameRow = New-Object System.Windows.Controls.Grid
		[void]($nameRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($nameRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))

		$nameInner = New-TweakNamePanel -Tweak $Tweak -BrushConverter $RowContext.BrushConverter
		[System.Windows.Controls.Grid]::SetColumn($nameInner, 0)
		[void]($nameRow.Children.Add($nameInner))

		$choiceBadgesPanel = New-TweakHeaderBadgesPanel -Tweak $Tweak -Metadata $RowContext.Metadata -BrushConverter $RowContext.BrushConverter -BadgeSpacing $RowContext.BadgeSpacing -ActionButton $ResetButton
		[System.Windows.Controls.Grid]::SetColumn($choiceBadgesPanel, 1)
		[void]($nameRow.Children.Add($choiceBadgesPanel))

		return $nameRow
	}

	<#
	    .SYNOPSIS
	    Internal function New-ToggleStatusRow.
	#>

	function New-ToggleStatusRow
	{
		param (
			[object]$Tweak,
			[System.Windows.Controls.CheckBox]$CheckBox,
			[object]$RowContext
		)

		$statusRow = New-Object System.Windows.Controls.Grid
		[void]($statusRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($statusRow.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))
		$statusRow.Margin = $Script:T.StatusRow

		$statusLabel = New-Object System.Windows.Controls.TextBlock
		$statusLabel.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
		$statusLabel.FontWeight = [System.Windows.FontWeights]::Medium
		$statusLabel.VerticalAlignment = 'Center'
		[System.Windows.Controls.Grid]::SetColumn($statusLabel, 0)

		$onColor = if ($Script:CurrentTheme -and $Script:CurrentTheme.StateEnabled) { $Script:CurrentTheme.StateEnabled } else { '#9FD6AA' }
		$offColor = if ($Script:CurrentTheme -and $Script:CurrentTheme.StateDisabled) { $Script:CurrentTheme.StateDisabled } else { '#98A0B7' }
		if ($CheckBox.IsChecked)
		{
			$statusLabel.Text = Get-UxToggleStateLabel -Enabled $true
			$statusLabel.Foreground = $RowContext.BrushConverter.ConvertFromString($onColor)
		}
		else
		{
			$statusLabel.Text = Get-UxToggleStateLabel -Enabled $false
			$statusLabel.Foreground = $RowContext.BrushConverter.ConvertFromString($offColor)
		}

		if ($Script:ScanEnabled -and $Tweak.Detect)
		{
			try
			{
				$detectedOn = [bool](& $Tweak.Detect)
				$onLabel = if ($Tweak.OnParam) { Get-UxString -Key "GuiToggleFallback$($Tweak.OnParam)" -Fallback $Tweak.OnParam } else { Get-UxToggleStateLabel -Enabled $true }
				$offLabel = if ($Tweak.OffParam) { Get-UxString -Key "GuiToggleFallback$($Tweak.OffParam)" -Fallback $Tweak.OffParam } else { Get-UxToggleStateLabel -Enabled $false }
				if ($detectedOn -eq [bool]$Tweak.Default)
				{
					$stateWord = if ($detectedOn) { (Get-UxString -Key 'GuiAlreadyPrefix' -Fallback 'Already') + " $onLabel" } else { (Get-UxString -Key 'GuiAlreadyPrefix' -Fallback 'Already') + " $offLabel" }
					$statusLabel.Text = $stateWord
					$statusLabel.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextMuted)
				}
				else
				{
					$stateWord = if ($detectedOn) { $onLabel } else { $offLabel }
					$statusLabel.Text = $stateWord
				}
			}
			catch
			{
				$statusLabel.Text = Get-UxString -Key 'GuiDetectionFailed' -Fallback 'Detection failed'
				$statusLabel.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.CautionText)
				Write-GuiRuntimeWarning -Context 'Build-TweakRow/Detect' -Message ("Detect failed for tweak '{0}' ({1}): {2}" -f [string]$Tweak.Name, [string]$Tweak.Function, $_.Exception.Message)
			}
		}

		[void]($statusRow.Children.Add($statusLabel))
		$whyBlock = New-WhyThisMattersButton -Tweak $Tweak
		if ($whyBlock)
		{
			[System.Windows.Controls.Grid]::SetColumn($whyBlock, 1)
			[void]($statusRow.Children.Add($whyBlock))
		}

		return [pscustomobject]@{
			Row         = $statusRow
			StatusLabel = $statusLabel
			WhyBlock    = $whyBlock
			OnColor     = $onColor
			OffColor    = $offColor
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Register-ToggleStatusHandlers.
	#>

	function Register-ToggleStatusHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[object]$StatusContext,
			[object]$RowContext
		)

		$statusLabelCapture = $StatusContext.StatusLabel
		$onColorCapture = $StatusContext.OnColor
		$offColorCapture = $StatusContext.OffColor
		$convertBrushCapture = $RowContext.ConvertBrushCapture
		$labelEnabled  = Get-UxToggleStateLabel -Enabled $true
		$labelDisabled = Get-UxToggleStateLabel -Enabled $false
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			if ($statusLabelCapture)
			{
				$statusLabelCapture.Text = $labelEnabled
				$statusLabelCapture.Foreground = & $convertBrushCapture -Color $onColorCapture -Context 'Build-TweakRow/StatusEnabled'
			}
		}.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			if ($statusLabelCapture)
			{
				$statusLabelCapture.Text = $labelDisabled
				$statusLabelCapture.Foreground = & $convertBrushCapture -Color $offColorCapture -Context 'Build-TweakRow/StatusDisabled'
			}
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiLinkedToggleHandlers.
	#>

	function Register-GuiLinkedToggleHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[string]$LinkedFunction,
			[scriptblock]$SyncLinkedStateCapture
		)

		if ([string]::IsNullOrWhiteSpace($LinkedFunction))
		{
			return
		}

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			& $SyncLinkedStateCapture $LinkedFunction $true
		}.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			& $SyncLinkedStateCapture $LinkedFunction $false
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiToggleExplicitSelectionHandlers.
	#>

	function Register-GuiToggleExplicitSelectionHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[string]$FunctionName,
			[object]$RowContext,
			[object]$StateControl = $null
		)

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}
			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			if ($currentExplicitDefinition -and [string]$currentExplicitDefinition.Type -eq 'Toggle')
			{
				& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]@{
					Function = $FunctionName
					Type = 'Toggle'
					State = 'On'
					Source = if ((Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
				})
			}
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}
			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			if ($currentExplicitDefinition -and [string]$currentExplicitDefinition.Type -eq 'Toggle')
			{
				& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]@{
					Function = $FunctionName
					Type = 'Toggle'
					State = 'Off'
					Source = if ((Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
				})
			}
			else
			{
				& $RowContext.RemoveExplicitSelectionDefinition -FunctionName $FunctionName
			}
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiActionSelectionHandlers.
	#>

	function Register-GuiActionSelectionHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[string]$FunctionName,
			[object]$RowContext,
			[object]$StateControl = $null
		)

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}
			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			if ($currentExplicitDefinition -and [string]$currentExplicitDefinition.Type -eq 'Action')
			{
				& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]@{
					Function = $FunctionName
					Type = 'Action'
					Run = $true
					Source = if ((Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
				})
			}
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}
			& $RowContext.RemoveExplicitSelectionDefinition -FunctionName $FunctionName
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiChoiceSelectionHandler.
	#>

	function Register-GuiChoiceSelectionHandler
	{
		param (
			[System.Windows.Controls.ComboBox]$ComboBox,
			[string]$FunctionName,
			[object[]]$ChoiceOptions,
			[object]$RowContext,
			[object]$StateControl = $null
		)

		$comboRef = $ComboBox
		$null = Register-GuiEventHandler -Source $ComboBox -EventName 'SelectionChanged' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}
			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			if ($comboRef.SelectedIndex -ge 0)
			{
				if ($currentExplicitDefinition -and [string]$currentExplicitDefinition.Type -eq 'Choice' -and $comboRef.SelectedIndex -lt $ChoiceOptions.Count)
				{
					& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]@{
						Function = $FunctionName
						Type = 'Choice'
						Value = [string]$ChoiceOptions[$comboRef.SelectedIndex]
						Source = if ((Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
					})
				}
			}
			elseif ($currentExplicitDefinition)
			{
				& $RowContext.RemoveExplicitSelectionDefinition -FunctionName $FunctionName
			}
			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Register-GuiNumericRangeSelectionHandlers.
	#>

	function Register-GuiNumericRangeSelectionHandlers
	{
		param (
			[System.Windows.Controls.CheckBox]$CheckBox,
			[System.Windows.Controls.Slider]$AcSlider,
			[System.Windows.Controls.Slider]$DcSlider,
			[System.Windows.Controls.TextBlock]$AcValueText,
			[System.Windows.Controls.TextBlock]$DcValueText,
			[System.Windows.Controls.TextBlock]$SummaryText,
			[string]$FunctionName,
			[object]$NumericRange,
			[string]$Units,
			[object]$RowContext,
			[object]$StateControl
		)

		if (-not $CheckBox -or -not $AcSlider -or -not $DcSlider)
		{
			return
		}

		$resolveValueText = {
			param([object]$Value)

			$resolvedText = Format-GuiPowerSchemeValueText -Value $Value -NumericRange $NumericRange -Units $Units
			if ([string]::IsNullOrWhiteSpace([string]$resolvedText))
			{
				return 'Unknown'
			}

			return [string]$resolvedText
		}.GetNewClosure()

		$syncSelectionState = {
			param([bool]$IsChecked)

			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$acValue = Get-GuiNumericRangeChannelValue -Value $AcSlider.Value -Channel 'AC' -NumericRange $NumericRange
			$dcValue = Get-GuiNumericRangeChannelValue -Value $DcSlider.Value -Channel 'DC' -NumericRange $NumericRange
			$valueObject = [ordered]@{
				ACValue = $acValue
				DCValue = $dcValue
			}

			if ($StateControl)
			{
				$StateControl.IsChecked = [bool]$IsChecked
				$StateControl.ACValue = $acValue
				$StateControl.DCValue = $dcValue
				$StateControl.Value = [pscustomobject]$valueObject
			}

			if ($AcValueText)
			{
				$AcValueText.Text = & $resolveValueText $acValue
			}
			if ($DcValueText)
			{
				$DcValueText.Text = & $resolveValueText $dcValue
			}
			if ($SummaryText)
			{
				$SummaryText.Text = (Get-UxLocalizedString -Key 'GuiNumericRangeSelectedValue' -Fallback 'Selected values: {0}' -FormatArgs @((Format-GuiPowerSchemeValueText -Value ([pscustomobject]$valueObject) -NumericRange $NumericRange -Units $Units)))
			}

			if (-not [bool]$IsChecked)
			{
				& $RowContext.RemoveExplicitSelectionDefinition -FunctionName $FunctionName
				if ($RowContext.SyncGameModePlanFromControlsScript)
				{
					& $RowContext.SyncGameModePlanFromControlsScript
				}
				return
			}

			$currentExplicitDefinition = & $RowContext.GetExplicitSelectionDefinition -FunctionName $FunctionName
			$definition = [ordered]@{
				Function = $FunctionName
				Type = 'NumericRange'
				Value = [pscustomobject]$valueObject
				NumericValue = if ($null -ne $acValue) { $acValue } else { $dcValue }
				ACValue = $acValue
				DCValue = $dcValue
				Units = $Units
				Source = if ($currentExplicitDefinition -and (Test-GuiObjectField -Object $currentExplicitDefinition -FieldName 'Source')) { [string]$currentExplicitDefinition.Source } else { 'Preset' }
			}
			& $RowContext.SetExplicitSelectionDefinition -FunctionName $FunctionName -Definition ([pscustomobject]$definition)

			if ($RowContext.SyncGameModePlanFromControlsScript)
			{
				& $RowContext.SyncGameModePlanFromControlsScript
			}
		}.GetNewClosure()

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$AcSlider.IsEnabled = $true
			$DcSlider.IsEnabled = $true
			& $syncSelectionState $true
		}.GetNewClosure())

		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			$AcSlider.IsEnabled = $false
			$DcSlider.IsEnabled = $false
			& $syncSelectionState $false
		}.GetNewClosure())

		$null = Register-GuiEventHandler -Source $AcSlider -EventName 'ValueChanged' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			if (-not [bool]$CheckBox.IsChecked)
			{
				return
			}

			& $syncSelectionState $true
		}.GetNewClosure())

		$null = Register-GuiEventHandler -Source $DcSlider -EventName 'ValueChanged' -Handler ({
			if ($StateControl -and (Test-GuiObjectField -Object $StateControl -FieldName 'IsRestoring') -and [bool]$StateControl.IsRestoring)
			{
				return
			}

			if (-not [bool]$CheckBox.IsChecked)
			{
				return
			}

			& $syncSelectionState $true
		}.GetNewClosure())
	}

	<#
	    .SYNOPSIS
	    Internal function Finalize-ToggleLikeRow.
	#>

	function Finalize-ToggleLikeRow
	{
		param (
			[System.Windows.Controls.Border]$Card,
			[object]$ChildContent,
			[System.Windows.Controls.CheckBox]$CheckBox,
			[object]$Tweak,
			[int]$Index,
			[object]$RowContext
		)

		try { $Card.Child = $ChildContent } catch { throw "Finalize/SetChild: $($_.Exception.Message)" }
		try { Add-CardHoverEffects -Card $Card -FocusSources @($CheckBox) } catch { throw "Finalize/HoverEffects: $($_.Exception.Message)" }
		if ($Tweak.LinkedWith)
		{
			try { & $RowContext.SyncLinkedState $Tweak.LinkedWith ([bool]$CheckBox.IsChecked) } catch { throw "Finalize/SyncLinked: $($_.Exception.Message)" }
		}
		try { $Card.Opacity = if ($CheckBox.IsChecked) { 1.0 } else { 0.7 } } catch { throw "Finalize/Opacity: $($_.Exception.Message)" }
		$cardRef = $Card
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({ $cardRef.Opacity = 1.0 }.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({ $cardRef.Opacity = 0.7 }.GetNewClosure())
		$Script:Controls[$Index] = $CheckBox
		return $Card
	}

	<#
	    .SYNOPSIS
	    Internal function Finalize-NumericRangeRow.
	#>

	function Finalize-NumericRangeRow
	{
		param (
			[System.Windows.Controls.Border]$Card,
			[object]$ChildContent,
			[System.Windows.Controls.CheckBox]$CheckBox,
			[System.Windows.Controls.Slider]$AcSlider,
			[System.Windows.Controls.Slider]$DcSlider,
			[object]$StateControl,
			[object]$Tweak,
			[int]$Index,
			[object]$RowContext
		)

		try { $Card.Child = $ChildContent } catch { throw "Finalize/SetChild: $($_.Exception.Message)" }
		try { Add-CardHoverEffects -Card $Card -FocusSources @($CheckBox, $AcSlider, $DcSlider) } catch { throw "Finalize/HoverEffects: $($_.Exception.Message)" }
		try { $Card.Opacity = if ($CheckBox.IsChecked) { 1.0 } else { 0.7 } } catch { throw "Finalize/Opacity: $($_.Exception.Message)" }
		$cardRef = $Card
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Checked' -Handler ({ $cardRef.Opacity = 1.0 }.GetNewClosure())
		$null = Register-GuiEventHandler -Source $CheckBox -EventName 'Unchecked' -Handler ({ $cardRef.Opacity = 0.7 }.GetNewClosure())
		$Script:Controls[$Index] = $StateControl
		return $Card
	}

	<#
	    .SYNOPSIS
	    Internal function New-ToggleTweakRow.
	#>

	function New-ToggleTweakRow
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext
		)

		$card = New-TweakRowCard -BrushConverter $RowContext.BrushConverter -Margin $RowContext.RowCardMargin -Padding $RowContext.RowCardPadding -Tweak $Tweak
		$leftStack = New-Object System.Windows.Controls.StackPanel
		$leftStack.Orientation = 'Vertical'
		$leftStack.VerticalAlignment = 'Center'

		$checkBox = New-ToggleLikeCheckBox -Index $Index -InitialChecked (Get-ToggleInitialCheckedState -Index $Index -Tweak $Tweak) -BrushConverter $RowContext.BrushConverter
		Apply-PendingLinkedToggleState -CheckBox $checkBox -FunctionName ([string]$Tweak.Function)

		$statusContext = New-ToggleStatusRow -Tweak $Tweak -CheckBox $checkBox -RowContext $RowContext
		$stateControl = [pscustomobject]@{
			Type = 'Toggle'
			IsChecked = [bool]$checkBox.IsChecked
			IsEnabled = [bool]$checkBox.IsEnabled
			CheckBox = $checkBox
			StatusContext = $statusContext
			Card = $card
			IsRestoring = $false
		}
		$resetButton = New-TweakResetButton -Tweak $Tweak -RowContext $RowContext -StateControl $stateControl
		[void]($leftStack.Children.Add((New-ToggleLikeHeaderGrid -CheckBox $checkBox -Tweak $Tweak -RowContext $RowContext -ResetButton $resetButton)))
		[void]($leftStack.Children.Add($statusContext.Row))
		Add-TweakMetadataDetails -Container $leftStack -Tweak $Tweak -RowContext $RowContext -DescriptionText $(if ($Tweak.Description) { if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback $Tweak.Description } else { $Tweak.Description } } else { Get-UxString -Key 'GuiToggleDefaultDescription' -Fallback 'Turns this feature on when checked and off when unchecked.' }) -DescriptionColor $Script:CurrentTheme.TextSecondary -DescriptionMargin $Script:T.DescIndent -MetadataMargin $Script:T.MetaIndent -BlastMargin $Script:T.BlastIndent
		if ($statusContext.WhyBlock -and $statusContext.WhyBlock.Tag)
		{
			[void]($leftStack.Children.Add($statusContext.WhyBlock.Tag))
		}

		Register-ToggleStatusHandlers -CheckBox $checkBox -StatusContext $statusContext -RowContext $RowContext
		Register-GuiToggleExplicitSelectionHandlers -CheckBox $checkBox -FunctionName ([string]$Tweak.Function) -RowContext $RowContext -StateControl $stateControl
		Register-GuiLinkedToggleHandlers -CheckBox $checkBox -LinkedFunction ([string]$Tweak.LinkedWith) -SyncLinkedStateCapture $RowContext.SyncLinkedState
		return Finalize-ToggleLikeRow -Card $card -ChildContent $leftStack -CheckBox $checkBox -Tweak $Tweak -Index $Index -RowContext $RowContext
	}

	<#
	    .SYNOPSIS
	    Internal function New-ChoiceTweakRow.
	#>

	function New-ChoiceTweakRow
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext
		)

		$card = New-TweakRowCard -BrushConverter $RowContext.BrushConverter -Margin $RowContext.RowCardMargin -Padding $RowContext.RowCardPadding -Tweak $Tweak
		$grid = New-Object System.Windows.Controls.Grid
		[void]($grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))

		$leftStack = New-Object System.Windows.Controls.StackPanel
		$leftStack.Orientation = 'Vertical'
		$leftStack.VerticalAlignment = 'Center'
		[System.Windows.Controls.Grid]::SetColumn($leftStack, 0)

		$combo = New-Object System.Windows.Controls.ComboBox
		$combo.MinWidth = $Script:GuiLayout.ComboBoxMinWidth
		$combo.VerticalAlignment = 'Center'
		$combo.Margin = $Script:T.ComboLeft
		$combo.Tag = $Index
		Set-ChoiceComboStyle -Combo $combo

		$displayOptions = if ($Tweak.DisplayOptions) { $Tweak.DisplayOptions } elseif ($Tweak.Options) { $Tweak.Options } else { @() }
		$choiceOptions = if ($Tweak.Options) { [object[]]@($Tweak.Options) } else { [object[]]@() }
		for ($optionIndex = 0; $optionIndex -lt $choiceOptions.Count; $optionIndex++)
		{
			$rawOption = [string]$displayOptions[$optionIndex]
			$locKey = "GuiChoice$rawOption"
			$localizedOption = Get-UxString -Key $locKey -Fallback $rawOption
			[void]($combo.Items.Add($localizedOption))
		}

		$initialSelectedIndex = Get-ChoiceInitialSelectedIndex -Index $Index -Tweak $Tweak -ChoiceOptions $choiceOptions -RowContext $RowContext
		[int]$selectedIndex = $initialSelectedIndex
		if ($selectedIndex -lt -1) { $selectedIndex = -1 }
		if ($selectedIndex -ge $combo.Items.Count) { $selectedIndex = -1 }
		$combo.SelectedIndex = [int]$selectedIndex

		$stateControl = [pscustomobject]@{
			Type = 'Choice'
			ComboBox = $combo
			SelectedIndex = [int]$combo.SelectedIndex
			Value = if ($combo.SelectedIndex -ge 0 -and $combo.SelectedIndex -lt $choiceOptions.Count) { [string]$choiceOptions[$combo.SelectedIndex] } else { $null }
			IsRestoring = $false
		}
		$resetButton = New-TweakResetButton -Tweak $Tweak -RowContext $RowContext -StateControl $stateControl
		[void]($leftStack.Children.Add((New-ChoiceHeaderGrid -Tweak $Tweak -RowContext $RowContext -ResetButton $resetButton)))
		Add-TweakMetadataDetails -Container $leftStack -Tweak $Tweak -RowContext $RowContext -DescriptionText $(if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback ([string]$Tweak.Description) } else { [string]$Tweak.Description }) -DescriptionColor $Script:CurrentTheme.TextMuted -DescriptionMargin $Script:T.DescFlush -MetadataMargin $Script:T.MetaFlush -BlastMargin $Script:T.BlastFlush
		[void](Add-TweakWhyBlockDetails -Container $leftStack -Tweak $Tweak -LeftIndent 0 -RowMargin $Script:T.WhyFlush)
		[void]($grid.Children.Add($leftStack))

		Register-GuiChoiceSelectionHandler -ComboBox $combo -FunctionName ([string]$Tweak.Function) -ChoiceOptions $choiceOptions -RowContext $RowContext -StateControl $stateControl
		[System.Windows.Controls.Grid]::SetColumn($combo, 1)
		[void]($grid.Children.Add($combo))

		$card.Child = $grid
		Add-CardHoverEffects -Card $card -FocusSources @($combo)
		$Script:Controls[$Index] = $combo
		return $card
	}

	<#
	    .SYNOPSIS
	    Internal function New-NumericRangeTweakRow.
	#>

	function New-NumericRangeTweakRow
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext
		)

		$card = New-TweakRowCard -BrushConverter $RowContext.BrushConverter -Margin $RowContext.RowCardMargin -Padding $RowContext.RowCardPadding -Tweak $Tweak
		$leftStack = New-Object System.Windows.Controls.StackPanel
		$leftStack.Orientation = 'Vertical'
		$leftStack.VerticalAlignment = 'Center'

		$numericRange = if ((Test-GuiObjectField -Object $Tweak -FieldName 'NumericRange')) { $Tweak.NumericRange } else { $null }
		$units = if ($numericRange -and (Test-GuiObjectField -Object $numericRange -FieldName 'Units')) { [string]$numericRange.Units } else { $null }

		$checkBox = New-ToggleLikeCheckBox -Index $Index -InitialChecked (Get-NumericRangeInitialCheckedState -Index $Index -Tweak $Tweak -RowContext $RowContext) -BrushConverter $RowContext.BrushConverter
		Apply-PendingLinkedToggleState -CheckBox $checkBox -FunctionName ([string]$Tweak.Function)

		$summaryText = New-Object System.Windows.Controls.TextBlock
		$summaryText.TextWrapping = [System.Windows.TextWrapping]::Wrap
		$summaryText.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
		$summaryText.Margin = [System.Windows.Thickness]::new(28, 4, 0, 0)
		$summaryText.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
		[void]($leftStack.Children.Add($summaryText))

		$channelGrid = New-Object System.Windows.Controls.Grid
		$channelGrid.Margin = [System.Windows.Thickness]::new(28, 8, 0, 0)
		[void]($channelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))
		[void]($channelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($channelGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto })))
		[void]($channelGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::Auto })))
		[void]($channelGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = [System.Windows.GridLength]::Auto })))

		$buildChannelRow = {
			param(
				[string]$LabelText,
				[int]$RowIndex,
				[double]$InitialValue
			)

			$label = New-Object System.Windows.Controls.TextBlock
			$label.Text = $LabelText
			$label.VerticalAlignment = 'Center'
			$label.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
			$label.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
			$label.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextMuted)
			[System.Windows.Controls.Grid]::SetRow($label, $RowIndex)
			[System.Windows.Controls.Grid]::SetColumn($label, 0)

			$slider = New-Object System.Windows.Controls.Slider
			$slider.Minimum = if ($numericRange -and (Test-GuiObjectField -Object $numericRange -FieldName 'MinValue')) { [double](Get-GuiObjectField -Object $numericRange -FieldName 'MinValue') } else { 0 }
			$slider.Maximum = if ($numericRange -and (Test-GuiObjectField -Object $numericRange -FieldName 'MaxValue')) { [double](Get-GuiObjectField -Object $numericRange -FieldName 'MaxValue') } else { 100 }
			$slider.Value = [double]$InitialValue
			$slider.TickFrequency = if ($numericRange -and (Test-GuiObjectField -Object $numericRange -FieldName 'Increment')) { [double](Get-GuiObjectField -Object $numericRange -FieldName 'Increment') } else { 1 }
			$slider.IsSnapToTickEnabled = $true
			$slider.IsMoveToPointEnabled = $true
			$slider.VerticalAlignment = 'Center'
			$slider.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
			$slider.IsEnabled = [bool]$checkBox.IsChecked
			$slider.MinWidth = $Script:GuiLayout.ComboBoxMinWidth
			$slider.ToolTip = (Format-GuiNumericRangeValueText -Value $InitialValue -NumericRange $numericRange -Units $units)
			[System.Windows.Controls.Grid]::SetRow($slider, $RowIndex)
			[System.Windows.Controls.Grid]::SetColumn($slider, 1)

			$valueText = New-Object System.Windows.Controls.TextBlock
			$valueText.Text = (Format-GuiNumericRangeValueText -Value $InitialValue -NumericRange $numericRange -Units $units)
			$valueText.VerticalAlignment = 'Center'
			$valueText.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeLabel' -Default 11
			$valueText.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
			[System.Windows.Controls.Grid]::SetRow($valueText, $RowIndex)
			[System.Windows.Controls.Grid]::SetColumn($valueText, 2)

			[void]($channelGrid.Children.Add($label))
			[void]($channelGrid.Children.Add($slider))
			[void]($channelGrid.Children.Add($valueText))

			return [pscustomobject]@{
				Slider = $slider
				ValueText = $valueText
			}
		}.GetNewClosure()

		$acInitialValue = Get-NumericRangeInitialValue -Index $Index -Tweak $Tweak -Channel 'AC' -NumericRange $numericRange -RowContext $RowContext
		$dcInitialValue = Get-NumericRangeInitialValue -Index $Index -Tweak $Tweak -Channel 'DC' -NumericRange $numericRange -RowContext $RowContext
		if ($null -eq $acInitialValue -and $null -eq $dcInitialValue)
		{
			throw "NumericRange tweak '$([string]$Tweak.Name)' does not define an initial value."
		}
		if ($null -eq $dcInitialValue)
		{
			$dcInitialValue = $acInitialValue
		}

		$acChannel = & $buildChannelRow 'AC' 0 ([double]$acInitialValue)
		$dcChannel = & $buildChannelRow 'DC' 1 ([double]$dcInitialValue)

		$stateControl = [pscustomobject]@{
			Type = 'NumericRange'
			IsChecked = [bool]$checkBox.IsChecked
			IsEnabled = [bool]$checkBox.IsEnabled
			CheckBox = $checkBox
			ACSlider = $acChannel.Slider
			DCSlider = $dcChannel.Slider
			ACValueText = $acChannel.ValueText
			DCValueText = $dcChannel.ValueText
			SummaryText = $summaryText
			ACValue = $acChannel.Slider.Value
			DCValue = $dcChannel.Slider.Value
			Value = [pscustomobject]@{
				ACValue = $acChannel.Slider.Value
				DCValue = $dcChannel.Slider.Value
			}
			NumericRange = $numericRange
			Units = $units
			Card = $card
			IsRestoring = $false
		}
		$resetButton = New-TweakResetButton -Tweak $Tweak -RowContext $RowContext -StateControl $stateControl
		[void]($leftStack.Children.Add((New-ToggleLikeHeaderGrid -CheckBox $checkBox -Tweak $Tweak -RowContext $RowContext -ResetButton $resetButton)))
		[void]($leftStack.Children.Add($channelGrid))
		Add-TweakMetadataDetails -Container $leftStack -Tweak $Tweak -RowContext $RowContext -DescriptionText $(if ($Tweak.Description) { if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback $Tweak.Description } else { $Tweak.Description } } else { Get-UxString -Key 'GuiNumericRangeDefaultDescription' -Fallback 'Adjusts a numeric power value for the selected power scheme.' }) -DescriptionColor $Script:CurrentTheme.TextSecondary -DescriptionMargin $Script:T.DescIndent -MetadataMargin $Script:T.MetaIndent -BlastMargin $Script:T.BlastIndent
		[void](Add-TweakWhyBlockDetails -Container $leftStack -Tweak $Tweak -LeftIndent 28 -RowMargin $Script:T.WhyIndent)

		Register-GuiNumericRangeSelectionHandlers -CheckBox $checkBox -AcSlider $acChannel.Slider -DcSlider $dcChannel.Slider -AcValueText $acChannel.ValueText -DcValueText $dcChannel.ValueText -SummaryText $summaryText -FunctionName ([string]$Tweak.Function) -NumericRange $numericRange -Units $units -RowContext $RowContext -StateControl $stateControl
		$stateControl.ACValueText.Text = (Format-GuiNumericRangeValueText -Value $acChannel.Slider.Value -NumericRange $numericRange -Units $units)
		$stateControl.DCValueText.Text = (Format-GuiNumericRangeValueText -Value $dcChannel.Slider.Value -NumericRange $numericRange -Units $units)
		$summaryText.Text = (Get-UxLocalizedString -Key 'GuiNumericRangeSelectedValue' -Fallback 'Selected values: {0}' -FormatArgs @((Format-GuiPowerSchemeValueText -Value ([pscustomobject]@{ ACValue = $acChannel.Slider.Value; DCValue = $dcChannel.Slider.Value }) -NumericRange $numericRange -Units $units)))

		return Finalize-NumericRangeRow -Card $card -ChildContent $leftStack -CheckBox $checkBox -AcSlider $acChannel.Slider -DcSlider $dcChannel.Slider -StateControl $stateControl -Tweak $Tweak -Index $Index -RowContext $RowContext
	}

	<#
	    .SYNOPSIS
	    Internal function New-ActionTweakRow.
	#>

	function New-ActionTweakRow
	{
		param (
			[int]$Index,
			[object]$Tweak,
			[object]$RowContext
		)

		$card = New-TweakRowCard -BrushConverter $RowContext.BrushConverter -Margin $RowContext.RowCardMargin -Padding $RowContext.RowCardPadding -Tweak $Tweak
		$checkBox = New-ToggleLikeCheckBox -Index $Index -InitialChecked (Get-ActionInitialCheckedState -Index $Index -Tweak $Tweak) -BrushConverter $RowContext.BrushConverter
		Apply-PendingLinkedToggleState -CheckBox $checkBox -FunctionName ([string]$Tweak.Function)

		$nameRowWithDescription = New-Object System.Windows.Controls.StackPanel
		$nameRowWithDescription.Orientation = 'Vertical'
		$stateControl = [pscustomobject]@{
			Type = 'Action'
			IsChecked = [bool]$checkBox.IsChecked
			IsEnabled = [bool]$checkBox.IsEnabled
			CheckBox = $checkBox
			Card = $card
			IsRestoring = $false
		}
		$resetButton = New-TweakResetButton -Tweak $Tweak -RowContext $RowContext -StateControl $stateControl
		try
		{
			[void]($nameRowWithDescription.Children.Add((New-ToggleLikeHeaderGrid -CheckBox $checkBox -Tweak $Tweak -RowContext $RowContext -ResetButton $resetButton)))
		}
		catch
		{
			throw "New-ActionTweakRow/Header failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		try
		{
			$restorePointHint = if ([string]$Tweak.Function -eq 'CreateRestorePoint') { Get-UxString -Key 'GuiCreateRestorePointHint' -Fallback 'Recommended before applying changes' } else { $null }
			$descriptionText = if ($restorePointHint) { $restorePointHint } elseif ($Tweak.Description) { if ($Tweak.DescriptionKey) { Get-UxString -Key $Tweak.DescriptionKey -Fallback $Tweak.Description } else { $Tweak.Description } } else { Get-UxString -Key 'GuiActionDefaultDescription' -Fallback 'Runs this action one time when selected.' }
			Add-TweakMetadataDetails -Container $nameRowWithDescription -Tweak $Tweak -RowContext $RowContext -DescriptionText $descriptionText -DescriptionColor $(if ($restorePointHint) { $Script:CurrentTheme.AccentBlue } else { $Script:CurrentTheme.TextSecondary }) -DescriptionMargin $Script:T.DescIndent -MetadataMargin $Script:T.MetaIndent -BlastMargin $Script:T.BlastIndent
		}
		catch
		{
			throw "New-ActionTweakRow/Metadata failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		try
		{
			[void](Add-TweakWhyBlockDetails -Container $nameRowWithDescription -Tweak $Tweak -LeftIndent 28 -RowMargin $Script:T.WhyIndent)
		}
		catch
		{
			throw "New-ActionTweakRow/WhyBlock failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}

		try
		{
			Register-GuiLinkedToggleHandlers -CheckBox $checkBox -LinkedFunction ([string]$Tweak.LinkedWith) -SyncLinkedStateCapture $RowContext.SyncLinkedState
			Register-GuiActionSelectionHandlers -CheckBox $checkBox -FunctionName ([string]$Tweak.Function) -RowContext $RowContext -StateControl $stateControl
		}
		catch
		{
			throw "New-ActionTweakRow/RegisterHandlers failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		try
		{
			return Finalize-ToggleLikeRow -Card $card -ChildContent $nameRowWithDescription -CheckBox $checkBox -Tweak $Tweak -Index $Index -RowContext $RowContext
		}
		catch
		{
			throw "New-ActionTweakRow/Finalize failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Build-TweakRow.
	#>

	function Build-TweakRow
	{
		param ([int]$Index, [object]$Tweak, [object]$BrushConverter = $null)

		if (-not (Test-TweakRowVisible -Tweak $Tweak))
		{
			return $null
		}

		# Cache shared row context parts that are identical for every row.
		if (-not $Script:RowContextShared -or $Script:RowContextSharedTheme -ne $Script:CurrentThemeName)
		{
			$Script:RowContextShared = @{
				ConvertBrushCapture               = Get-GuiRuntimeCommand -Name 'ConvertTo-GuiBrush' -CommandType 'Function'
				GetExplicitSelectionDefinition    = ${function:Get-GuiExplicitSelectionDefinition}
				SetExplicitSelectionDefinition    = ${function:Set-GuiExplicitSelectionDefinition}
				RemoveExplicitSelectionDefinition = ${function:Remove-GuiExplicitSelectionDefinition}
				SyncGameModePlanFromControlsScript = ${function:Sync-GameModePlanFromGamingControls}
				RowCardMargin                     = [System.Windows.Thickness]::new(8, 2, 8, 2)
				RowCardPadding                    = [System.Windows.Thickness]::new(10, 6, 10, 6)
				BadgeSpacing                      = [System.Windows.Thickness]::new(2, 0, 0, 0)
				SyncLinkedState                   = $syncLinkedState
				FallbackBrushConverter            = New-SafeBrushConverter -Context 'Build-TweakRow'
			}
			$Script:RowContextSharedTheme = $Script:CurrentThemeName
		}
		$shared = $Script:RowContextShared
		$rowContext = [pscustomobject]@{
			BrushConverter                    = if ($BrushConverter) { $BrushConverter } else { $shared.FallbackBrushConverter }
			ConvertBrushCapture               = $shared.ConvertBrushCapture
			GetExplicitSelectionDefinition    = $shared.GetExplicitSelectionDefinition
			SetExplicitSelectionDefinition    = $shared.SetExplicitSelectionDefinition
			RemoveExplicitSelectionDefinition = $shared.RemoveExplicitSelectionDefinition
			SyncGameModePlanFromControlsScript = $shared.SyncGameModePlanFromControlsScript
			Metadata                          = Get-TweakVisualMetadata -Tweak $Tweak -StateSource $Script:Controls[$Index]
			UseCompactRecoveryLevelLabel      = ([string]$Tweak.Category -eq 'Initial Setup')
			RowCardMargin                     = $shared.RowCardMargin
			RowCardPadding                    = $shared.RowCardPadding
			BadgeSpacing                      = $shared.BadgeSpacing
			SyncLinkedState                   = $shared.SyncLinkedState
		}

		switch ($Tweak.Type)
		{
			'Toggle' { return New-ToggleTweakRow -Index $Index -Tweak $Tweak -RowContext $rowContext }
			'Choice' { return New-ChoiceTweakRow -Index $Index -Tweak $Tweak -RowContext $rowContext }
			'NumericRange' { return New-NumericRangeTweakRow -Index $Index -Tweak $Tweak -RowContext $rowContext }
			'Date' { return New-DateTweakRow -Index $Index -Tweak $Tweak -RowContext $rowContext }
			'Action' { return New-ActionTweakRow -Index $Index -Tweak $Tweak -RowContext $rowContext }
		}

		return $null
	}
	#endregion
