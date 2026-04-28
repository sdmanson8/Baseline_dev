# TweakRowFactory split file loaded by Module\GUI\TweakRowFactory.ps1.

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
		$Card.Add_MouseEnter({ try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_MouseEnter' } }.GetNewClosure())
		$Card.Add_MouseLeave({ try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_MouseLeave' } }.GetNewClosure())
		$pressBg = $res.PressBg
		$pressHandler = {
			$Card.Background = $pressBg
		}.GetNewClosure()
		$Card.Add_PreviewMouseLeftButtonDown({ try { & $pressHandler } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_PreviewMouseLeftButtonDown' } }.GetNewClosure())
		$Card.Add_PreviewMouseLeftButtonUp({ try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_PreviewMouseLeftButtonUp' } }.GetNewClosure())
		foreach ($focusSource in $FocusSources)
		{
			if (-not $focusSource) { continue }
			$focusSource.Add_GotKeyboardFocus({ try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_GotKeyboardFocus' } }.GetNewClosure())
			$focusSource.Add_LostKeyboardFocus({ try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.Add_LostKeyboardFocus' } }.GetNewClosure())
		}
		try { & $updateChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.Build-TweakRowCard.UpdateChrome' }
	}

	<#
	    .SYNOPSIS
	    Internal function Get-CompatibilityBadgeInfo.
	#>

	function Get-CompatibilityBadgeInfo
	{
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
		param (
			[AllowNull()]
			[string]$Label
		)

		if ([string]::IsNullOrWhiteSpace($Label))
		{
			return $null
		}

		switch ([string]$Label.Trim())
		{
			'Windows10Only'
			{
				return [pscustomobject]@{
					Label = Get-UxString -Key 'GuiCompatibilityBadgeWindows10Only' -Fallback 'Windows 10 only'
					Tone = 'Primary'
					ToolTip = Get-UxString -Key 'GuiCompatibilityBadgeTooltipWindows10Only' -Fallback 'This item targets Windows 10 only.'
				}
			}
			'Windows11Only'
			{
				return [pscustomobject]@{
					Label = Get-UxString -Key 'GuiCompatibilityBadgeWindows11Only' -Fallback 'Windows 11 only'
					Tone = 'Primary'
					ToolTip = Get-UxString -Key 'GuiCompatibilityBadgeTooltipWindows11Only' -Fallback 'This item targets Windows 11 only.'
				}
			}
			'ServerOnly'
			{
				return [pscustomobject]@{
					Label = Get-UxString -Key 'GuiCompatibilityBadgeServerOnly' -Fallback 'Server only'
					Tone = 'Primary'
					ToolTip = Get-UxString -Key 'GuiCompatibilityBadgeTooltipServerOnly' -Fallback 'This item targets Server only.'
				}
			}
			'ClientOnly'
			{
				return [pscustomobject]@{
					Label = Get-UxString -Key 'GuiCompatibilityBadgeClientOnly' -Fallback 'Client only'
					Tone = 'Primary'
					ToolTip = Get-UxString -Key 'GuiCompatibilityBadgeTooltipClientOnly' -Fallback 'This item targets Client only.'
				}
			}
			default
			{
				return $null
			}
		}
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

