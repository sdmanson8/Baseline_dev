# P5 rollback checkpoint: extracted from Show-GuiSettingsDialog in Module\GUI\DialogHelpers\SettingsDialogs.ps1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
if ($btnSave)
		{
			$btnSave.Content = $saveLabel
			Set-ButtonChrome -Button $btnSave -Variant 'Primary'
			$btnSave.IsDefault = $true
			$btnSave.Add_Click({
				$getTag = {
					param ($combo, $default)
					if ($combo -and $combo.SelectedItem -and $null -ne $combo.SelectedItem.Tag)
					{
						return $combo.SelectedItem.Tag
					}
					return $default
				}

				$selectedLanguage = if ($settingsLanguageState -and $settingsLanguageState.Code) { [string]$settingsLanguageState.Code } else { 'en' }
				$defaultUpdateBranch = if (Get-Command -Name 'Get-BaselineDefaultUpdateBranch' -CommandType Function -ErrorAction SilentlyContinue) { Get-BaselineDefaultUpdateBranch } else { 'Stable' }
				$resultRef.Value = @{
					Language = $selectedLanguage
					DefaultStartupMode = [string](& $getTag $cmbDefaultStartupMode 'Safe')
					RestoreLastSession = [bool]$chkRestoreLastSession.IsChecked
					AutoScanOnLaunch = [bool]$chkAutoScanOnLaunch.IsChecked
					HideUnavailableItems = if ($chkHideUnavailableItems) { [bool]$chkHideUnavailableItems.IsChecked } else { $true }
					AutoCheckUpdates = if ($chkAutoCheckUpdates) { [bool]$chkAutoCheckUpdates.IsChecked } else { $true }
					UpdateCheckFrequency = [string](& $getTag $cmbUpdateFrequency 'Startup')
					UpdateBranch = [string](& $getTag $cmbUpdateBranch $defaultUpdateBranch)
					IncludePrereleaseUpdates = if ($chkIncludePrereleaseUpdates) { [bool]$chkIncludePrereleaseUpdates.IsChecked } else { $false }
					Theme = [string](& $getTag $cmbTheme 'System')
					UIDensity = [string](& $getTag $cmbUIDensity 'Comfort')
					SafeMode = [bool]$chkSafeModeDefault.IsChecked
					RequireRunConfirmation = [bool]$chkRequireRunConfirmation.IsChecked
					PreviewBeforeRunDefault = [bool]$chkPreviewBeforeRunDefault.IsChecked
					AuditRetentionDays = [int](& $getTag $cmbAuditRetention 90)
					AppsPackageSourcePreference = [string](& $getTag $cmbPackageSource 'auto')
					AppsSilentInstall = [bool]$chkAppsSilentInstall.IsChecked
					AppsAutoUpdate = [bool]$chkAppsAutoUpdate.IsChecked
					LoggingEnabled = [bool]$chkLoggingEnabled.IsChecked
					DebugLoggingEnabled = [bool]$chkDebugLogging.IsChecked
					LogLevel = [string](& $getTag $cmbLogLevel 'All')
					LogFileDirectory = if ($chkAdvancedMode -and [bool]$chkAdvancedMode.IsChecked -and -not [string]::IsNullOrWhiteSpace([string]$settingsLogState.CustomDirectory)) { [string]$settingsLogState.CustomDirectory } else { '' }
					AdvancedMode = [bool]$chkAdvancedMode.IsChecked
					ExperimentalFeatures = [bool]$chkExperimentalFeatures.IsChecked
					DesignMode = [bool]$chkDesignMode.IsChecked
				}
				$dlg.Close()
			}.GetNewClosure())
		}
