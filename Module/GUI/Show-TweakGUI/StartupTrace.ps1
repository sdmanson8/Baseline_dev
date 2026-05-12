# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$traceGuiStartup = {
		param([string]$Message)
		try
		{
			$traceDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline'
			if (-not [System.IO.Directory]::Exists($traceDirectory))
			{
				[void][System.IO.Directory]::CreateDirectory($traceDirectory)
			}
			$tracePath = Join-Path $traceDirectory 'Baseline-launch-trace.txt'
			[System.IO.File]::AppendAllText($tracePath, ("{0:o} [GUI] {1}`r`n" -f [DateTime]::UtcNow, $Message), [System.Text.Encoding]::UTF8)
		}
		catch
		{
			$null = $_
		}
	}.GetNewClosure()
