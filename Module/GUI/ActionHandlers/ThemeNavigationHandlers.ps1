# ActionHandlers split file loaded by Module\GUI\ActionHandlers.ps1.

	#region Theme toggle handler
	Register-GuiEventHandler -Source $ChkTheme -EventName 'Checked' -Handler ({
		Invoke-CapturedFunction -Name 'Set-GUITheme' -Parameters @{ Theme = $Script:LightTheme }
	}) | Out-Null
	Register-GuiEventHandler -Source $ChkTheme -EventName 'Unchecked' -Handler ({
		Invoke-CapturedFunction -Name 'Set-GUITheme' -Parameters @{ Theme = $Script:DarkTheme }
	}) | Out-Null
	if ($NavModeTweaks)
	{
		Register-GuiEventHandler -Source $NavModeTweaks -EventName 'Checked' -Handler ({
			Set-GuiAppsMode -Enable:$false
		}) | Out-Null
	}
	if ($NavModeApps)
	{
		Register-GuiEventHandler -Source $NavModeApps -EventName 'Checked' -Handler ({
			Set-GuiAppsMode -Enable:$true
		}) | Out-Null
	}
	#endregion
