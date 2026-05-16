try
	{
		$Form.ShowInTaskbar = $true
		$Form.Opacity = 1
		if ($Form.WindowState -eq [System.Windows.WindowState]::Minimized)
		{
			$Form.WindowState = [System.Windows.WindowState]::Normal
		}
	}
	catch
	{
		Write-SwallowedException -ErrorRecord $_ -Source 'Regions.GUI.StartupVisibility.Apply'
	}
