# TweakRowFactory split file loaded by Module\GUI\TweakRowFactory.ps1.

	<#
	    .SYNOPSIS
	    Internal function Set-TweakSearchHighlightedTextBlock.
	#>
	function Set-TweakSearchHighlightedTextBlock
	{
		param (
			[System.Windows.Controls.TextBlock]$TextBlock,
			[string]$Text,
			[object]$BrushConverter
		)

		if (-not $TextBlock) { return }
		$query = if ($null -ne $Script:SearchText) { [string]$Script:SearchText.Trim() } else { '' }
		if ([string]::IsNullOrWhiteSpace($query) -or [string]::IsNullOrWhiteSpace($Text))
		{
			$TextBlock.Text = [string]$Text
			return
		}

		$comparison = [System.StringComparison]::OrdinalIgnoreCase
		$startIndex = 0
		$matchIndex = ([string]$Text).IndexOf($query, $startIndex, $comparison)
		if ($matchIndex -lt 0)
		{
			$TextBlock.Text = [string]$Text
			return
		}

		$TextBlock.Inlines.Clear()
		$highlightBg = if ($Script:CurrentTheme -and $Script:CurrentTheme.SearchHighlightBg) { [string]$Script:CurrentTheme.SearchHighlightBg } else { '#FDE68A' }
		$highlightFg = if ($Script:CurrentTheme -and $Script:CurrentTheme.SearchHighlightText) { [string]$Script:CurrentTheme.SearchHighlightText } else { '#111827' }
		$highlightBgBrush = $BrushConverter.ConvertFromString($highlightBg)
		$highlightFgBrush = $BrushConverter.ConvertFromString($highlightFg)
		while ($matchIndex -ge 0)
		{
			if ($matchIndex -gt $startIndex)
			{
				$prefix = New-Object System.Windows.Documents.Run
				$prefix.Text = ([string]$Text).Substring($startIndex, $matchIndex - $startIndex)
				[void]($TextBlock.Inlines.Add($prefix))
			}

			$matchRun = New-Object System.Windows.Documents.Run
			$matchRun.Text = ([string]$Text).Substring($matchIndex, $query.Length)
			$matchRun.Background = $highlightBgBrush
			$matchRun.Foreground = $highlightFgBrush
			$matchRun.FontWeight = [System.Windows.FontWeights]::SemiBold
			[void]($TextBlock.Inlines.Add($matchRun))

			$startIndex = $matchIndex + $query.Length
			if ($startIndex -ge ([string]$Text).Length) { break }
			$matchIndex = ([string]$Text).IndexOf($query, $startIndex, $comparison)
		}

		if ($startIndex -lt ([string]$Text).Length)
		{
			$suffix = New-Object System.Windows.Documents.Run
			$suffix.Text = ([string]$Text).Substring($startIndex)
			[void]($TextBlock.Inlines.Add($suffix))
		}
	}

	<#
	    .SYNOPSIS
	    Internal function Add-TweakDetailLine.
	#>
	function Add-TweakDetailLine
	{
		param (
			[System.Windows.Controls.Panel]$Container,
			[object]$RowContext,
			[string]$Label,
			[string]$Text,
			[System.Windows.Thickness]$Margin
		)

		if (-not $Container -or [string]::IsNullOrWhiteSpace($Text)) { return }

		$line = New-Object System.Windows.Controls.TextBlock
		$line.TextWrapping = 'Wrap'
		$line.Margin = $Margin
		$line.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
		$line.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)

		if (-not [string]::IsNullOrWhiteSpace($Label))
		{
			$labelRun = New-Object System.Windows.Documents.Run
			$labelRun.Text = ('{0}: ' -f $Label)
			$labelRun.FontWeight = [System.Windows.FontWeights]::SemiBold
			$labelRun.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextPrimary)
			[void]($line.Inlines.Add($labelRun))
		}

		$textRun = New-Object System.Windows.Documents.Run
		$textRun.Text = [string]$Text
		[void]($line.Inlines.Add($textRun))
		if ($Label -eq (Get-UxString -Key 'GuiSectionTags' -Fallback 'Tags'))
		{
			Set-TweakSearchHighlightedTextBlock -TextBlock $line -Text ('{0}: {1}' -f $Label, $Text) -BrushConverter $RowContext.BrushConverter
		}
		[void]($Container.Children.Add($line))
	}

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
		$shadow.ShadowDepth = 0
		$shadow.Opacity = if ($isLight) { 0.04 } else { 0.18 }
		$shadow.BlurRadius = if ($isLight) { 8 } else { 18 }
		if ($shadow.CanFreeze) { $shadow.Freeze() }
		$Script:CardHoverResources = @{
			ThemeName      = $themeName
			Shadow         = $shadow
			DefaultBg      = $bc.ConvertFromString($Script:CurrentTheme.CardBg)
			HoverBg        = $bc.ConvertFromString($Script:CurrentTheme.CardHoverBg)
			PressBg        = $bc.ConvertFromString($Script:CurrentTheme.TabActiveBg)
			DefaultBorder  = $bc.ConvertFromString($Script:CurrentTheme.CardBorder)
			HoverBorder    = $bc.ConvertFromString($Script:CurrentTheme.CardBorder)
			FocusBorder    = $bc.ConvertFromString($Script:CurrentTheme.FocusRing)
			Thickness1     = if ($isLight) { $Script:T.CardBorder } else { $Script:T.RowDivider }
			Thickness2     = if ($isLight) { $Script:T.CardBorderFocus } else { $Script:T.RowDividerFocus }
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

		$toggleButton = New-Object System.Windows.Controls.Button
		$toggleButton.Content = Get-UxString -Key 'GuiShowDetails' -Fallback 'Show details'
		$toggleButton.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
		$toggleButton.FontWeight = [System.Windows.FontWeights]::SemiBold
		$toggleButton.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
		$toggleButton.Margin = $DescriptionMargin
		$toggleButton.HorizontalAlignment = 'Left'
		$toggleButton.Cursor = [System.Windows.Input.Cursors]::Hand
		if (Get-Command -Name 'Set-ButtonChrome' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Set-ButtonChrome -Button $toggleButton -Variant 'Subtle' -Compact -Muted
		}
		[void]($Container.Children.Add($toggleButton))

		$detailsPanel = New-Object System.Windows.Controls.StackPanel
		$detailsPanel.Orientation = 'Vertical'
		$detailsPanel.Visibility = [System.Windows.Visibility]::Collapsed
		try { $Tweak | Add-Member -MemberType NoteProperty -Name '_RowDetailsPanel' -Value $detailsPanel -Force } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'TweakRowFactory.AddMetadataDetails.AttachDetailsPanel' }

		$descriptionTextBlock = New-Object System.Windows.Controls.TextBlock
		Set-TweakSearchHighlightedTextBlock -TextBlock $descriptionTextBlock -Text $DescriptionText -BrushConverter $RowContext.BrushConverter
		$descriptionTextBlock.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
		$descriptionTextBlock.Foreground = $RowContext.BrushConverter.ConvertFromString($DescriptionColor)
		$descriptionTextBlock.Margin = $DescriptionMargin
		$descriptionTextBlock.TextWrapping = 'Wrap'
		[void]($detailsPanel.Children.Add($descriptionTextBlock))

		# Keep high-risk consequence text with the rest of the expanded details.
		if ([string]$Tweak.Risk -eq 'High' -and [bool]$Tweak.Caution -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.CautionReason))
		{
			$cautionColor = if ($Script:CurrentTheme -and $Script:CurrentTheme.CautionText) { $Script:CurrentTheme.CautionText } else { '#D6A84A' }
			$neutralTextColor = if ($Script:CurrentTheme -and $Script:CurrentTheme.TextSecondary) { $Script:CurrentTheme.TextSecondary } else { '#CDD6EA' }
			$cautionInline = New-Object System.Windows.Controls.TextBlock
			$cautionInline.TextWrapping = 'Wrap'
			$cautionInline.Margin = $DescriptionMargin
			$cautionInline.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
			$cautionInline.FontWeight = [System.Windows.FontWeights]::Medium
			$cautionInline.Foreground = $RowContext.BrushConverter.ConvertFromString($neutralTextColor)

			$cautionIcon = New-Object System.Windows.Documents.Run
			$cautionIcon.Text = ([char]0x26A0).ToString() + ' '
			$cautionIcon.Foreground = $RowContext.BrushConverter.ConvertFromString($cautionColor)
			[void]($cautionInline.Inlines.Add($cautionIcon))

			$cautionText = New-Object System.Windows.Documents.Run
			$cautionText.Text = [string]$Tweak.CautionReason
			[void]($cautionInline.Inlines.Add($cautionText))

			[void]($detailsPanel.Children.Add($cautionInline))
		}

		$impactText = if ((Test-GuiObjectField -Object $Tweak -FieldName 'Impact') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.Impact)) { [string]$Tweak.Impact } else { $null }
		Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionImpact' -Fallback 'Impact') -Text $impactText -Margin $DescriptionMargin
		$behaviorText = if ((Test-GuiObjectField -Object $Tweak -FieldName 'Detail') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.Detail)) { [string]$Tweak.Detail } else { $null }
		Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionBehavior' -Fallback 'Behavior') -Text $behaviorText -Margin $DescriptionMargin
		$whyText = if ((Test-GuiObjectField -Object $Tweak -FieldName 'WhyThisMatters') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.WhyThisMatters)) { [string]$Tweak.WhyThisMatters } else { $null }
		Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionWhyThisMatters' -Fallback 'Why This Matters') -Text $whyText -Margin $DescriptionMargin
		$recoveryText = if ((Test-GuiObjectField -Object $Tweak -FieldName 'RecoveryLevel') -and -not [string]::IsNullOrWhiteSpace([string]$Tweak.RecoveryLevel)) { [string]$Tweak.RecoveryLevel } else { $null }
		Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionRecovery' -Fallback 'Recovery') -Text $recoveryText -Margin $DescriptionMargin
		$restartText = if ([bool]$Tweak.RequiresRestart) { Get-UxString -Key 'GuiTweakChipRestartRequired' -Fallback 'Restart required' } else { Get-UxString -Key 'GuiTweakChipRestartNotRequired' -Fallback 'No restart required' }
		Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionRestart' -Fallback 'Restart') -Text $restartText -Margin $DescriptionMargin
		if ($RowContext.Metadata -and (Test-GuiObjectField -Object $RowContext.Metadata -FieldName 'ScenarioTags') -and $RowContext.Metadata.ScenarioTags)
		{
			$tagsText = (@($RowContext.Metadata.ScenarioTags) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ', '
			Add-TweakDetailLine -Container $detailsPanel -RowContext $RowContext -Label (Get-UxString -Key 'GuiSectionTags' -Fallback 'Tags') -Text $tagsText -Margin $DescriptionMargin
		}

		try
		{
			$detailMetaPanel = New-TweakMetadataChipPanel -Metadata $RowContext.Metadata -IncludeType:$true -IncludeState:$true -IncludeRestart:$true -IncludeRestorable:$true -IncludeRecoveryLevel:$true -UseCompactRecoveryLevelLabel:$RowContext.UseCompactRecoveryLevelLabel -IncludeScenarioTags:$true
		}
		catch
		{
			throw "Add-TweakMetadataDetails/MetadataChips failed for tweak '$([string]$Tweak.Name)': $($_.Exception.Message)"
		}
		if ($detailMetaPanel)
		{
			$detailMetaPanel.Margin = $MetadataMargin
			[void]($detailsPanel.Children.Add($detailMetaPanel))
		}

		if (-not [string]::IsNullOrWhiteSpace([string]$RowContext.Metadata.BlastRadius))
		{
			$blastText = New-Object System.Windows.Controls.TextBlock
			$blastText.Text = [string]$RowContext.Metadata.BlastRadius
			$blastText.TextWrapping = 'Wrap'
			$blastText.Margin = $BlastMargin
			$blastText.FontSize = GUICommon\Get-GuiSafeFontSize -Key 'FontSizeSmall' -Default 10
			$blastText.Foreground = $RowContext.BrushConverter.ConvertFromString($Script:CurrentTheme.TextSecondary)
			[void]($detailsPanel.Children.Add($blastText))
		}

		$showDetailsLabel = Get-UxString -Key 'GuiShowDetails' -Fallback 'Show details'
		$hideDetailsLabel = Get-UxString -Key 'GuiHideDetails' -Fallback 'Hide details'
		Register-GuiEventHandler -Source $toggleButton -EventName 'Click' -Handler ({
			$showDetails = ($detailsPanel.Visibility -ne [System.Windows.Visibility]::Visible)
			$detailsPanel.Visibility = if ($showDetails) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
			$toggleButton.Content = if ($showDetails) {
				$hideDetailsLabel
			}
			else {
				$showDetailsLabel
			}
		}.GetNewClosure()) | Out-Null
		[void]($Container.Children.Add($detailsPanel))
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

		if ((Test-GuiObjectField -Object $Tweak -FieldName '_RowDetailsPanel') -and $Tweak._RowDetailsPanel)
		{
			return $null
		}

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

