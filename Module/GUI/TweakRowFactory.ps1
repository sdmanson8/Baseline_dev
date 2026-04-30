	# Pre-computed shared resources for card hover effects.

# P5 rollback checkpoint: TweakRowFactory helpers are split into Module\GUI\TweakRowFactory\*.ps1.
# Keep this explicit order so defaults and metadata helpers load before row factories and Build-TweakRow.
$tweakRowFactorySplitRoot = Join-Path $PSScriptRoot 'TweakRowFactory'
. (Join-Path $tweakRowFactorySplitRoot 'RowStateDefaults.ps1')
. (Join-Path $tweakRowFactorySplitRoot 'MetadataDetails.ps1')
. (Join-Path $tweakRowFactorySplitRoot 'ControlFactories.ps1')
	# Frozen DropShadowEffect instances are reused across all cards in the same
	# theme, avoiding per-card object allocation and WPF effect re-composition.
	$Script:CardHoverResources = $null

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
		RowDivider     = [System.Windows.Thickness]::new(0, 0, 0, 1)
		RowDividerFocus = [System.Windows.Thickness]::new(0, 0, 0, 2)
		CardBorder     = [System.Windows.Thickness]::new(1)
		CardBorderFocus = [System.Windows.Thickness]::new(2)
		AccentBorder   = [System.Windows.Thickness]::new(3, 0, 0, 1)
		AccentFocus    = [System.Windows.Thickness]::new(3, 0, 0, 2)
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
	    Internal function Build-TweakRow.
	#>

	function Build-TweakRow
	{
		param ([int]$Index, [object]$Tweak, [object]$BrushConverter = $null)

		$__perf = Start-GuiPerfScope -Name 'BuildTweakRow' -Note ("{0}:{1}:{2}" -f $Index, [string]$Tweak.Type, [string]$Tweak.Function)
		try
		{
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
					RowCardMargin                     = [System.Windows.Thickness]::new(8, 3, 8, 5)
					RowCardPadding                    = [System.Windows.Thickness]::new(12, 8, 12, 8)
					BadgeSpacing                      = [System.Windows.Thickness]::new(4, 0, 0, 0)
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
		finally
		{
			Stop-GuiPerfScope -Scope $__perf
		}
	}
	#endregion
