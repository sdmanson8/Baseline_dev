# Lightweight in-process perf tracer for the Baseline GUI.
# Activation: set env var BASELINE_PERF_LOG=1 before launching. When unset,
# Start/Stop scopes are near-zero-cost no-ops (single env read + early return).
# Output: $env:LOCALAPPDATA\Temp\Baseline\perf.log (one line per scope: ISO8601, ms, name, note).

$Script:GuiPerfEnabled = $null
$Script:GuiPerfLogPath = $null
$Script:GuiPerfSink    = $null

function Initialize-GuiPerfTrace
{
	[CmdletBinding()]
	param()

	$raw = [System.Environment]::GetEnvironmentVariable('BASELINE_PERF_LOG')
	$Script:GuiPerfEnabled = (-not [string]::IsNullOrWhiteSpace($raw)) -and ($raw -ne '0' -and $raw.ToLowerInvariant() -ne 'false' -and $raw.ToLowerInvariant() -ne 'off')

	if (-not $Script:GuiPerfEnabled) { return }

	$base = $env:LOCALAPPDATA
	if ([string]::IsNullOrWhiteSpace($base)) { $base = [System.IO.Path]::GetTempPath() }
	$dir = Join-Path $base 'Temp\Baseline'
	try
	{
		if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
		$Script:GuiPerfLogPath = Join-Path $dir 'perf.log'
		$stamp = (Get-Date).ToString('o')
		[System.IO.File]::AppendAllText($Script:GuiPerfLogPath, "# session $stamp pid=$PID`r`n", [System.Text.Encoding]::UTF8)
	}
	catch
	{
		Write-DebugSwallowedException -ErrorRecord $_ -Source 'PerfTrace.InitializeGuiPerfTrace.WriteSessionHeader'
		$Script:GuiPerfEnabled = $false
	}
}

function Start-GuiPerfScope
{
	[CmdletBinding()]
	[OutputType([object])]
	param(
		[Parameter(Mandatory)][string]$Name,
		[string]$Note = ''
	)

	if (-not $Script:GuiPerfEnabled) { return $null }
	return [pscustomobject]@{
		Name = $Name
		Note = $Note
		Sw   = [System.Diagnostics.Stopwatch]::StartNew()
	}
}

function Stop-GuiPerfScope
{
	[CmdletBinding()]
	param(
		[object]$Scope,
		[string]$ExtraNote = ''
	)

	if (-not $Script:GuiPerfEnabled -or -not $Scope) { return }
	try
	{
		$Scope.Sw.Stop()
		$ms   = [int]$Scope.Sw.Elapsed.TotalMilliseconds
		$note = if ([string]::IsNullOrWhiteSpace($ExtraNote)) { $Scope.Note } else { $ExtraNote }
		$line = "{0} {1,6} ms  {2}  {3}`r`n" -f (Get-Date).ToString('HH:mm:ss.fff'), $ms, $Scope.Name, $note
		[System.IO.File]::AppendAllText($Script:GuiPerfLogPath, $line, [System.Text.Encoding]::UTF8)
	}
	catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'PerfTrace.StopGuiPerfScope.AppendLine' }
}
