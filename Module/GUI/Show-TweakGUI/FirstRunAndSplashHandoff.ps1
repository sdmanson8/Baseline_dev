
# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Purpose: first-run dependency and startup splash resolution.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$firstRunDialogDispatcher = if ($Form -and $Form.Dispatcher) { $Form.Dispatcher } else { $null }
	$closeLoadingSplashBlock = (Get-Item function:Close-LoadingSplashWindow -ErrorAction Stop).ScriptBlock
	$testGuiStartupSplashLiveBlock = (Get-Item function:Test-GuiStartupSplashLive -ErrorAction Stop).ScriptBlock
	$testGuiStartupSplashAbortBlock = (Get-Item function:Test-GuiStartupSplashAbortRequested -ErrorAction Stop).ScriptBlock
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
	if ($testGuiStartupSplashAbortBlock -isnot [scriptblock]) { throw "Test-GuiStartupSplashAbortRequested did not resolve to a scriptblock." }
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
	if (& $testGuiStartupSplashAbortBlock -Splash $startupSplashHandle)
	{
		Stop-GuiStartupSplashAbortProcess -Trace $traceGuiStartup -Message 'Show-TweakGUI aborted before window display because startup splash was closed'
	}
	$hasLiveStartupSplash = & $testGuiStartupSplashLiveBlock -Splash $startupSplashHandle
	$startupSplashAbortWatchdog = $null
	if ($hasLiveStartupSplash)
	{
		$startupSplashAbortWatchdog = Start-GuiStartupSplashAbortWatchdog -Splash $startupSplashHandle
	}
			# P5 rollback checkpoint: Show-TweakGUI part extracted to Module/GUI/Show-TweakGUI/WindowPresentation.ps1; re-inline here if rollback is needed.
		. (Join-Path $PSScriptRoot 'WindowPresentation.ps1')
	& $traceGuiStartup 'Startup visibility applied'


