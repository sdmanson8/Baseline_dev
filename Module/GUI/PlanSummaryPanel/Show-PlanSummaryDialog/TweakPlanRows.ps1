# P5 rollback checkpoint: extracted from Show-PlanSummaryDialog in Module\GUI\PlanSummaryPanel.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
foreach ($tweak in $sortedTweaks)
	{
		$rowBorder = New-Object System.Windows.Controls.Border
		$rowBorder.Background = $brushCardBg
		$rowBorder.BorderBrush = $brushCardBorder
		$rowBorder.BorderThickness = $thickness1
		$rowBorder.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.BorderRadiusSmall)
		$rowBorder.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)
		$rowBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)

		$rowGrid = New-Object System.Windows.Controls.Grid
		[void]($rowGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) })))
		[void]($rowGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Auto) })))

		# Tweak name
		$nameBlock = New-Object System.Windows.Controls.TextBlock
		$nameBlock.Text = [string]$tweak.Name
		$nameBlock.Foreground = $brushTextPrimary
		$nameBlock.FontWeight = [System.Windows.FontWeights]::Normal
		$nameBlock.TextWrapping = 'NoWrap'
		$nameBlock.TextTrimming = 'CharacterEllipsis'
		$nameBlock.VerticalAlignment = 'Center'
		[System.Windows.Controls.Grid]::SetColumn($nameBlock, 0)
		[void]($rowGrid.Children.Add($nameBlock))

		# Badge panel (type + risk + restart)
		$badgePanel = New-Object System.Windows.Controls.StackPanel
		$badgePanel.Orientation = 'Horizontal'
		$badgePanel.VerticalAlignment = 'Center'

		# Type badge
		$tweakType = if (Test-GuiObjectField -Object $tweak -FieldName 'Type') { [string](Get-GuiObjectField -Object $tweak -FieldName 'Type') } else { '' }
		if (-not [string]::IsNullOrWhiteSpace($tweakType))
		{
			$typeBadge = New-Object System.Windows.Controls.Border
			$typeBadge.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.PillCornerRadius)
			$typeBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
			$typeBadge.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
			$typeBadge.Background = $bc.ConvertFromString($theme.StatusPillBg)
			$typeBadge.BorderBrush = $bc.ConvertFromString($theme.StatusPillBorder)
			$typeBadge.BorderThickness = $thickness1

			$typeText = New-Object System.Windows.Controls.TextBlock
			$typeText.Text = $tweakType
			$typeText.FontSize = $Script:GuiLayout.FontSizeTiny
			$typeText.FontWeight = [System.Windows.FontWeights]::SemiBold
			$typeText.Foreground = $bc.ConvertFromString($theme.StatusPillText)
			$typeBadge.Child = $typeText
			[void]($badgePanel.Children.Add($typeBadge))
		}

		# High risk badge
		$tweakRisk = if (Test-GuiObjectField -Object $tweak -FieldName 'Risk') { [string](Get-GuiObjectField -Object $tweak -FieldName 'Risk') } else { $null }
		if ($tweakRisk -eq 'High')
		{
			$riskBadge = New-Object System.Windows.Controls.Border
			$riskBadge.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.PillCornerRadius)
			$riskBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
			$riskBadge.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
			$riskBadge.Background = $bc.ConvertFromString($theme.RiskHighBadgeBg)
			$riskBadge.BorderBrush = $bc.ConvertFromString($theme.RiskHighBadge)
			$riskBadge.BorderThickness = $thickness1

			$riskText = New-Object System.Windows.Controls.TextBlock
			$riskText.Text = (Get-UxLocalizedString -Key 'GuiPlanHighRisk' -Fallback 'High Risk')
			$riskText.FontSize = $Script:GuiLayout.FontSizeTiny
			$riskText.FontWeight = [System.Windows.FontWeights]::SemiBold
			$riskText.Foreground = $bc.ConvertFromString($theme.RiskHighBadge)
			$riskBadge.Child = $riskText
			[void]($badgePanel.Children.Add($riskBadge))
		}

		# Restart indicator
		$needsRestart = (Test-GuiObjectField -Object $tweak -FieldName 'RequiresRestart') -and [bool](Get-GuiObjectField -Object $tweak -FieldName 'RequiresRestart')
		if ($needsRestart)
		{
			$restartBadge = New-Object System.Windows.Controls.Border
			$restartBadge.CornerRadius = [System.Windows.CornerRadius]::new($Script:GuiLayout.PillCornerRadius)
			$restartBadge.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
			$restartBadge.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
			$restartBadge.Background = $bc.ConvertFromString($theme.RiskMediumBadgeBg)
			$restartBadge.BorderBrush = $bc.ConvertFromString($theme.RiskMediumBadge)
			$restartBadge.BorderThickness = $thickness1

			$restartText = New-Object System.Windows.Controls.TextBlock
			$restartText.Text = "$([char]0x21BB) $(Get-UxLocalizedString -Key 'GuiPlanRestart' -Fallback 'Restart')"
			$restartText.FontSize = $Script:GuiLayout.FontSizeTiny
			$restartText.FontWeight = [System.Windows.FontWeights]::SemiBold
			$restartText.Foreground = $bc.ConvertFromString($theme.RiskMediumBadge)
			$restartBadge.Child = $restartText
			[void]($badgePanel.Children.Add($restartBadge))
		}

		[System.Windows.Controls.Grid]::SetColumn($badgePanel, 1)
		[void]($rowGrid.Children.Add($badgePanel))

		$rowBorder.Child = $rowGrid
		[void]($bodyStack.Children.Add($rowBorder))
	}
