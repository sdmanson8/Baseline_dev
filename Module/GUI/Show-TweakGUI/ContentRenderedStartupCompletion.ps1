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
				if (-not $splashHandle.ContainsKey('GuiReady')) { $splashHandle['GuiReady'] = $false }
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
					$trace = {
						param([string]$Message)
						try
						{
							if (-not [System.IO.Directory]::Exists($traceDirectory)) { [void][System.IO.Directory]::CreateDirectory($traceDirectory) }
							$line = ("{0:o} {1}`r`n" -f [DateTime]::UtcNow, $Message)
							$bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
							$stream = [System.IO.FileStream]::new($tracePath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
							try { $stream.Write($bytes, 0, $bytes.Length) }
							finally { $stream.Dispose() }
						}
						catch { $null = $_ }
					}
					& $trace 'SplashClose runspace: started polling GuiReady'
					try
					{
					# Wait for the GUI-ready signal from Build-TabContent.
					# Cap at 180 s as a safety net so the splash is never
					# stuck if the signal is missed.
						$deadline = [datetime]::UtcNow.AddSeconds(180)
						while ($splash -is [hashtable] -and (-not ($splash.ContainsKey('GuiReady') -and [bool]$splash['GuiReady'])) -and [datetime]::UtcNow -lt $deadline)
						{
							if ($splash.ContainsKey('IsAlive') -and (-not [bool]$splash['IsAlive'])) { break }
							Start-Sleep -Milliseconds 200
						}

						$abortRequested = $false
						if ($splash -is [hashtable])
						{
							if ($splash.ContainsKey('AbortRequested') -and [bool]$splash['AbortRequested']) { $abortRequested = $true }
							elseif ($splash.ContainsKey('UserClosed') -and [bool]$splash['UserClosed']) { $abortRequested = $true }
							elseif ($splash.ContainsKey('ProgrammaticClose') -and [bool]$splash['ProgrammaticClose']) { $abortRequested = $false }
							elseif ($splash.ContainsKey('GuiReady') -and [bool]$splash['GuiReady']) { $abortRequested = $false }
							elseif ($splash.ContainsKey('IsAlive') -and (-not [bool]$splash['IsAlive'])) { $abortRequested = $true }
						}
						if ($abortRequested)
						{
							& $trace 'SplashClose runspace: startup splash closed before GuiReady; aborting process'
							[System.Environment]::Exit(0)
							try { [System.Diagnostics.Process]::GetCurrentProcess().Kill() } catch { $null = $_ }
							return
						}

						& $trace 'SplashClose runspace: GuiReady signaled, revealing GUI before splash close'

						$setMainWindowPresentation = {
							param([bool]$Activate)

							if (-not $mainWindow -or -not $mainWindow.Dispatcher -or $mainWindow.Dispatcher.HasShutdownStarted)
							{
								return
							}

							$mainWindow.Dispatcher.Invoke([System.Action]{
								try { $mainWindow.ShowInTaskbar = $true } catch { $null = $_ }
								try { $mainWindow.Opacity = 1 } catch { $null = $_ }
								try
								{
									if ($mainWindow.WindowState -eq [System.Windows.WindowState]::Minimized)
									{
										$mainWindow.WindowState = [System.Windows.WindowState]::Normal
									}
								}
								catch { $null = $_ }
								try
								{
									if ($mainWindow.Visibility -ne [System.Windows.Visibility]::Visible)
									{
										$mainWindow.Visibility = [System.Windows.Visibility]::Visible
									}
								}
								catch { $null = $_ }
								try { $mainWindow.ShowActivated = $true } catch { $null = $_ }
								if ($Activate)
								{
									$mainWindowHandle = [IntPtr]::Zero
									try
									{
										if (-not ("WinAPI.ForegroundWindow" -as [type]))
										{
											Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinAPI
{
	public static class ForegroundWindow
	{
		[DllImport("user32.dll")]
		public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool SetForegroundWindow(IntPtr hWnd);

		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
	}
}
"@ -ErrorAction Stop | Out-Null
										}
										$mainWindowInterop = New-Object System.Windows.Interop.WindowInteropHelper($mainWindow)
										$mainWindowHandle = $mainWindowInterop.Handle
										if ($mainWindowHandle -eq [IntPtr]::Zero -and $mainWindowInterop.PSObject.Methods['EnsureHandle'])
										{
											$mainWindowHandle = $mainWindowInterop.EnsureHandle()
										}
										if ($mainWindowHandle -ne [IntPtr]::Zero)
										{
											$hwndTopMost = [IntPtr]::new(-1)
											[WinAPI.ForegroundWindow]::ShowWindowAsync($mainWindowHandle, 5) | Out-Null
											[WinAPI.ForegroundWindow]::ShowWindowAsync($mainWindowHandle, 9) | Out-Null
											[WinAPI.ForegroundWindow]::SetWindowPos($mainWindowHandle, $hwndTopMost, 0, 0, 0, 0, 0x43) | Out-Null
											[WinAPI.ForegroundWindow]::SetForegroundWindow($mainWindowHandle) | Out-Null
										}
									}
									catch { $null = $_ }
									try { $mainWindow.Topmost = $true } catch { $null = $_ }
									try { $null = $mainWindow.Activate() } catch { $null = $_ }
									try { $null = $mainWindow.Focus() } catch { $null = $_ }
									try { Start-Sleep -Milliseconds 900 } catch { $null = $_ }
									try { $mainWindow.Topmost = $false } catch { $null = $_ }
									try
									{
										if ($mainWindowHandle -ne [IntPtr]::Zero -and ("WinAPI.ForegroundWindow" -as [type]))
										{
											$hwndNoTopMost = [IntPtr]::new(-2)
											[WinAPI.ForegroundWindow]::SetWindowPos($mainWindowHandle, $hwndNoTopMost, 0, 0, 0, 0, 0x43) | Out-Null
										}
									}
									catch { $null = $_ }
								}
							})
						}.GetNewClosure()

						try
						{
							if ($splash -is [hashtable] -and $splash.ContainsKey('CompletionAnimationDeadlineUtc') -and $splash['CompletionAnimationDeadlineUtc'] -is [datetime])
							{
								while (($splash.ContainsKey('IsAlive') -and [bool]$splash['IsAlive']) -and [datetime]::UtcNow -lt $splash['CompletionAnimationDeadlineUtc'])
								{
									Start-Sleep -Milliseconds 50
								}
							}
						}
						catch { & $trace ("SplashClose runspace: completion animation wait failed: {0}" -f $_.Exception.Message); $null = $_ }

						# Reveal the GUI BEFORE closing the splash so the
						# transition is instant: the GUI is already painted
						# before the splash disappears, so the main window is
						# ready the moment the splash is hidden. If we close
						# the splash first, there's a gap where neither window
						# is visible (desktop flashes).
						try
						{
							& $setMainWindowPresentation $false
						}
						catch { & $trace ("SplashClose runspace: mainWindow presentation transition failed: {0}" -f $_.Exception.Message); $null = $_ }

						$splashDispatcher = if ($splash -is [hashtable] -and $splash.ContainsKey('Dispatcher')) { $splash['Dispatcher'] } else { $null }
						if ($splashDispatcher -and -not $splashDispatcher.HasShutdownStarted)
						{
							$splashDispatcher.Invoke([System.Action]{
								if ($splash -is [hashtable] -and $splash.ContainsKey('ProgrammaticClose')) { $splash['ProgrammaticClose'] = $true }
								$splashWindow = if ($splash -is [hashtable] -and $splash.ContainsKey('Window')) { $splash['Window'] } else { $null }
								if ($splashWindow)
								{
									try { $splashWindow.Hide() } catch { $null = $_ }
									try { $splashWindow.Close() } catch { $null = $_ }
								}
								if ($splash -is [hashtable] -and $splash.ContainsKey('IsAlive')) { $splash['IsAlive'] = $false }
							})
						}

						& $trace 'SplashClose runspace: splash window closed'

						try
						{
							& $setMainWindowPresentation $true
							& $trace 'SplashClose runspace: mainWindow activated after splash close'
						}
						catch { & $trace ("SplashClose runspace: mainWindow activation transition failed: {0}" -f $_.Exception.Message); $null = $_ }

						# Brief wait for window close to propagate, then shut
						# down the splash's runspace so it doesn't leak.
						Start-Sleep -Milliseconds 250
						try
						{
							$splashDispatcher = if ($splash -is [hashtable] -and $splash.ContainsKey('Dispatcher')) { $splash['Dispatcher'] } else { $null }
							if ($splashDispatcher -and -not $splashDispatcher.HasShutdownStarted)
							{
								$splashDispatcher.InvokeShutdown()
							}
						}
						catch { & $trace ("SplashClose runspace: dispatcher InvokeShutdown failed: {0}" -f $_.Exception.Message); $null = $_ }
						try
						{
							$splashPowerShell = if ($splash -is [hashtable] -and $splash.ContainsKey('_PowerShell')) { $splash['_PowerShell'] } else { $null }
							$splashAsyncResult = if ($splash -is [hashtable] -and $splash.ContainsKey('_AsyncResult')) { $splash['_AsyncResult'] } else { $null }
							if ($splashPowerShell -and $splashAsyncResult)
							{
								$splashPowerShell.EndInvoke($splashAsyncResult)
							}
						}
						catch { & $trace ("SplashClose runspace: PowerShell.EndInvoke failed: {0}" -f $_.Exception.Message); $null = $_ }
						try
						{
							$splashPowerShell = if ($splash -is [hashtable] -and $splash.ContainsKey('_PowerShell')) { $splash['_PowerShell'] } else { $null }
							if ($splashPowerShell) { $splashPowerShell.Dispose() }
						}
						catch { & $trace ("SplashClose runspace: PowerShell.Dispose failed: {0}" -f $_.Exception.Message); $null = $_ }
						try
						{
							$splashRunspace = if ($splash -is [hashtable] -and $splash.ContainsKey('_Runspace')) { $splash['_Runspace'] } else { $null }
							if ($splashRunspace) { $splashRunspace.Close(); $splashRunspace.Dispose() }
						}
						catch { & $trace ("SplashClose runspace: Runspace.Dispose failed: {0}" -f $_.Exception.Message); $null = $_ }
					}
					catch
					{
						& $trace ("SplashClose runspace failed: {0}" -f $_.Exception.Message)
						$null = $_
					}
				})
				[void]$closePs.BeginInvoke()
			}
		}
		catch
		{
			try { LogWarning (Format-BaselineErrorForLog -ErrorObject $_ -Prefix 'splash close orchestration failed') } catch { Write-SwallowedException -ErrorRecord $_ -Source 'Regions.GUI.SplashClose.LogWarning.Orchestration' }
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
					Write-SwallowedException -ErrorRecord $_ -Source 'Regions.GUI.AutoScanOnLaunch'
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
