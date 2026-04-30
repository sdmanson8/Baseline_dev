# Shared helpers for Baseline.

<#
    .SYNOPSIS
    Internal function Initialize-ForegroundWindowInterop.
#>

function Initialize-ForegroundWindowInterop
{
	<# .SYNOPSIS Loads the WinAPI.ForegroundWindow P/Invoke type definition. #>
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
	}
}
"@ -ErrorAction Stop | Out-Null
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-ConsoleWindowInterop.
#>

function Initialize-ConsoleWindowInterop
{
	<# .SYNOPSIS Loads the WinAPI.ConsoleWindow P/Invoke type definition. #>
	if (-not ("WinAPI.ConsoleWindow" -as [type]))
	{
		Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinAPI
{
	public static class ConsoleWindow
	{
		[DllImport("kernel32.dll")]
		public static extern IntPtr GetConsoleWindow();

		[DllImport("user32.dll")]
		public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
	}
}
"@ -ErrorAction Stop | Out-Null
	}
}

<#
    .SYNOPSIS
    Internal function Get-ConsoleHandle.
#>

function Get-ConsoleHandle
{
	<# .SYNOPSIS Returns the console window handle via kernel32 P/Invoke. #>
	Initialize-ConsoleWindowInterop
	return [WinAPI.ConsoleWindow]::GetConsoleWindow()
}

<#
    .SYNOPSIS
    Internal function .
#>
function Hide-ConsoleWindow
{
	<# .SYNOPSIS Hides the console window using ShowWindow(SW_HIDE). #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param ()

	$hwnd = Get-ConsoleHandle
	if ($hwnd -ne [System.IntPtr]::Zero)
	{
		[WinAPI.ConsoleWindow]::ShowWindow($hwnd, 0 <# SW_HIDE #>) | Out-Null
	}
}

<#
    .SYNOPSIS
    Internal function Show-ConsoleWindow.
#>

function Show-ConsoleWindow
{
	<# .SYNOPSIS Shows and restores the console window using ShowWindow(SW_RESTORE). #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param ()

	$hwnd = Get-ConsoleHandle
	if ($hwnd -ne [System.IntPtr]::Zero)
	{
		[WinAPI.ConsoleWindow]::ShowWindow($hwnd, 9 <# SW_RESTORE #>) | Out-Null
	}
}

<#
    .SYNOPSIS
    Internal function .
#>
function Test-InteractiveHost
{
	<# .SYNOPSIS Tests whether the current PowerShell host supports interactive UI. #>
	try
	{
		if ($null -eq $Host -or $null -eq $Host.UI)
		{
			return $false
		}

		$null = $Host.UI.RawUI
		return $true
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Write-EnvironmentLaunchTrace.
#>

function Write-EnvironmentLaunchTrace
{
	<# .SYNOPSIS Writes environment-helper startup diagnostics to the launcher trace. #>
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]
		$Message
	)

	try
	{
		if ([string]::IsNullOrWhiteSpace([string]$Message)) { return }
		$tracePath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline-launch-trace.txt'
		[System.IO.File]::AppendAllText(
			$tracePath,
			("{0:o} {1}`r`n" -f [DateTime]::UtcNow, [string]$Message),
			[System.Text.Encoding]::UTF8
		)
	}
	catch
	{
		$null = $_
	}
}

<#
    .SYNOPSIS
    Internal function Write-EnvironmentSwallowedException.
#>

function Write-EnvironmentSwallowedException
{
	<# .SYNOPSIS Routes swallowed environment-helper exceptions without requiring the logging module to be in scope. #>
	param(
		[Parameter(Mandatory = $false)]
		[object]
		$ErrorRecord,

		[Parameter(Mandatory = $true)]
		[string]
		$Source
	)

	try
	{
		$debugWriter = Get-Command -Name 'Write-DebugSwallowedException' -CommandType Function -ErrorAction SilentlyContinue
		if ($debugWriter)
		{
			& $debugWriter -ErrorRecord $ErrorRecord -Source $Source
			return
		}

		$message = if ($ErrorRecord -and $ErrorRecord.Exception) { [string]$ErrorRecord.Exception.Message } else { [string]$ErrorRecord }
		if (-not [string]::IsNullOrWhiteSpace($message))
		{
			Write-EnvironmentLaunchTrace ("{0}: {1}" -f $Source, $message)
		}
	}
	catch
	{
		$null = $_
	}
}

<#
    .SYNOPSIS
    Internal function ConvertFrom-EnvironmentPowerShellDataFileAst.
#>

function ConvertFrom-EnvironmentPowerShellDataFileAst
{
	<# .SYNOPSIS Converts supported constant PowerShell data-file AST nodes to .NET values. #>
	param(
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.Language.Ast]
		$Ast
	)

	if ($Ast -is [System.Management.Automation.Language.HashtableAst])
	{
		$result = @{}
		foreach ($pair in $Ast.KeyValuePairs)
		{
			$key = ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $pair.Item1
			if ([string]::IsNullOrWhiteSpace([string]$key))
			{
				throw 'PowerShell data file contains an empty hashtable key.'
			}

			$result[[string]$key] = ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $pair.Item2
		}

		return $result
	}

	if ($Ast -is [System.Management.Automation.Language.CommandExpressionAst])
	{
		return ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $Ast.Expression
	}

	if ($Ast -is [System.Management.Automation.Language.PipelineAst])
	{
		if (@($Ast.PipelineElements).Count -ne 1)
		{
			throw 'PowerShell data file pipelines must contain exactly one constant expression.'
		}

		return ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $Ast.PipelineElements[0]
	}

	if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst])
	{
		return $Ast.Value
	}

	if ($Ast -is [System.Management.Automation.Language.ConstantExpressionAst])
	{
		return $Ast.Value
	}

	if ($Ast -is [System.Management.Automation.Language.VariableExpressionAst])
	{
		switch -Exact ($Ast.VariablePath.UserPath)
		{
			'true'  { return $true }
			'false' { return $false }
			'null'  { return $null }
			default { throw ("PowerShell data file contains unsupported variable expression: {0}" -f $Ast.Extent.Text) }
		}
	}

	if ($Ast -is [System.Management.Automation.Language.ArrayLiteralAst])
	{
		$values = foreach ($element in $Ast.Elements)
		{
			ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $element
		}

		return @($values)
	}

	if ($Ast -is [System.Management.Automation.Language.ArrayExpressionAst])
	{
		$values = foreach ($statement in $Ast.SubExpression.Statements)
		{
			ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $statement
		}

		return @($values)
	}

	if ($Ast -is [System.Management.Automation.Language.ParenExpressionAst])
	{
		return ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $Ast.Pipeline
	}

	throw ("PowerShell data file contains unsupported expression: {0}" -f $Ast.Extent.Text)
}

<#
    .SYNOPSIS
    Internal function Import-EnvironmentPowerShellDataFile.
#>

function Import-EnvironmentPowerShellDataFile
{
	<# .SYNOPSIS Imports a constant PowerShell data file on Windows PowerShell 5.1. #>
	param(
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)

	$tokens = $null
	$errors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
	if ($errors -and @($errors).Count -gt 0)
	{
		throw ("PowerShell data file parse failed: {0}" -f [string]$errors[0].Message)
	}

	if (-not $ast.EndBlock -or @($ast.EndBlock.Statements).Count -ne 1)
	{
		throw 'PowerShell data file must contain exactly one hashtable.'
	}

	$data = ConvertFrom-EnvironmentPowerShellDataFileAst -Ast $ast.EndBlock.Statements[0]
	if ($data -isnot [hashtable])
	{
		throw 'PowerShell data file root must be a hashtable.'
	}

	return $data
}

<#
    .SYNOPSIS
    Internal function Initialize-WpfWindowForeground.
#>

function Initialize-WpfWindowForeground
{
	<# .SYNOPSIS Configures a WPF window to activate and bring itself to foreground. #>
	param
	(
		[Parameter(Mandatory = $true)]
		$Window
	)

	try
	{
		$Window.ShowActivated = $true
	}
	catch
	{
		# Ignore if the supplied object is not a WPF Window.
	}

	$activationPending = [ref]$true
	$bringWindowToFront = {
		if (-not $activationPending.Value)
		{
			return
		}

		$activationPending.Value = $false

		try
		{
			$activateWindowAction = [System.Action]{
				try
				{
					Initialize-ForegroundWindowInterop

					if ($Window.WindowState -eq [System.Windows.WindowState]::Minimized)
					{
						$Window.WindowState = [System.Windows.WindowState]::Normal
					}

					$interopHelper = New-Object -TypeName System.Windows.Interop.WindowInteropHelper -ArgumentList $Window
					if ($interopHelper.Handle -ne [IntPtr]::Zero)
					{
						[WinAPI.ForegroundWindow]::ShowWindowAsync($interopHelper.Handle, 9 <# SW_RESTORE #>) | Out-Null
						[WinAPI.ForegroundWindow]::SetForegroundWindow($interopHelper.Handle) | Out-Null
					}

					$originalTopmost = $Window.Topmost
					$Window.Topmost = $true
					$Window.Activate() | Out-Null
					$Window.Focus() | Out-Null

					$resetTopmostAction = [System.Action]{
						$Window.Topmost = $originalTopmost
					}
					$Window.Dispatcher.BeginInvoke($resetTopmostAction, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) | Out-Null
				}
				catch
				{
					try
					{
						$Window.WindowState = [System.Windows.WindowState]::Normal
						$Window.Activate() | Out-Null
						$Window.Focus() | Out-Null
					}
					catch
					{
						# Ignore foreground activation failures and allow the dialog to continue opening normally.
					}
				}
			}

			$Window.Dispatcher.BeginInvoke($activateWindowAction, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) | Out-Null
		}
		catch
		{
			try
			{
				$Window.WindowState = [System.Windows.WindowState]::Normal
				$Window.Activate() | Out-Null
				$Window.Focus() | Out-Null
			}
			catch
			{
				# Ignore foreground activation failures and allow the dialog to continue opening normally.
			}
		}
	}

	$Window.Add_Loaded($bringWindowToFront)
	$Window.Add_SourceInitialized($bringWindowToFront)
	$Window.Add_ContentRendered($bringWindowToFront)
	$Window.Add_StateChanged({
		if ($activationPending -and ($Window.WindowState -eq [System.Windows.WindowState]::Minimized))
		{
			$bringWindowToFront.Invoke()
		}
	})
}

<#
    .SYNOPSIS
    Internal function Get-WindowsVersionData.
#>

function Get-WindowsVersionData
{
	<# .SYNOPSIS Retrieves Windows version details from the registry (build, UBR, display version). #>
	$CurrentVersion = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
	$CurrentBuild = [string]$CurrentVersion.CurrentBuild
	$DisplayVersion = [string]$CurrentVersion.DisplayVersion
	$ProductName = [string]$CurrentVersion.ProductName
	$InstallationType = [string]$CurrentVersion.InstallationType
	$UBR = 0
	$IsWindowsServer = $false

	if ([string]::IsNullOrWhiteSpace($CurrentBuild))
	{
		$CurrentBuild = [string]$CurrentVersion.CurrentBuildNumber
	}

	if ([string]::IsNullOrWhiteSpace($DisplayVersion))
	{
		$DisplayVersion = [string]$CurrentVersion.ReleaseId
	}

	if ($null -ne $CurrentVersion.UBR)
	{
		$UBR = [int]$CurrentVersion.UBR
	}

	if (-not [string]::IsNullOrWhiteSpace($InstallationType))
	{
		$IsWindowsServer = $InstallationType -match "Server"
	}
	elseif (-not [string]::IsNullOrWhiteSpace($ProductName))
	{
		$IsWindowsServer = $ProductName -match "Server"
	}

	$buildNumber = 0
	if (-not [int]::TryParse([string]$CurrentBuild, [ref]$buildNumber)) { $buildNumber = 0 }

	[pscustomobject]@{
		IsWindows11      = ($buildNumber -ge 22000)
		IsWindowsServer  = $IsWindowsServer
		CurrentBuild     = $buildNumber
		UBR              = $UBR
		DisplayVersion   = $DisplayVersion
		ProductName      = $ProductName
		InstallationType = $InstallationType
	}
}

<#
    .SYNOPSIS
    Internal function Get-OSInfo.
#>

function Get-OSInfo
{
	<# .SYNOPSIS Returns a summary object with OS name, build, UBR, and version data. #>
	$VersionData = Get-WindowsVersionData
	$OSName = if ($VersionData.IsWindowsServer)
	{
		if ([string]::IsNullOrWhiteSpace($VersionData.ProductName))
		{
			"Windows Server"
		}
		else
		{
			$VersionData.ProductName
		}
	}
	elseif ($VersionData.IsWindows11)
	{
		"Windows 11"
	}
	else
	{
		"Windows 10"
	}

	[pscustomobject]@{
		IsWindows11      = $VersionData.IsWindows11
		IsWindowsServer  = $VersionData.IsWindowsServer
		OSName           = $OSName
		CurrentBuild     = $VersionData.CurrentBuild
		UBR              = $VersionData.UBR
		DisplayVersion   = $VersionData.DisplayVersion
		ProductName      = $VersionData.ProductName
		InstallationType = $VersionData.InstallationType
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineValidationMatrixSummary.
#>

function Get-BaselineValidationMatrixSummary
{
	[CmdletBinding()]
	param (
		[string]$RepoRoot = $null
	)

	$resolvedRepoRoot = $RepoRoot
	if ([string]::IsNullOrWhiteSpace($resolvedRepoRoot))
	{
		if ($Script:SharedHelpersRepoRoot)
		{
			$resolvedRepoRoot = [string]$Script:SharedHelpersRepoRoot
		}
		elseif ($PSScriptRoot)
		{
			$resolvedRepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
		}
	}

	$matrixPath = if (-not [string]::IsNullOrWhiteSpace($resolvedRepoRoot)) { Join-Path $resolvedRepoRoot 'Tests/Integration/DesktopMatrixResults.json' } else { $null }
	$summary = [ordered]@{
		SourcePath                 = $matrixPath
		ValidatedDesktopEditions    = @()
		PendingDesktopEditions      = @()
		ServerEditions              = @()
		Summary                    = 'Unavailable'
		ServerValidationSummary    = 'Unavailable'
		ServerCoverageStatus       = 'Unavailable'
		HasServerCoverage          = $false
		ServerCIOnly               = $false
	}

	if ($matrixPath -and (Test-Path -LiteralPath $matrixPath))
	{
		try
		{
			$matrixJson = Get-Content -LiteralPath $matrixPath -Raw -Encoding UTF8 | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
			$validated = @($matrixJson.summary.testedDesktopEditions)
			$pending = @($matrixJson.summary.pendingDesktopEditions)
			$server = @($matrixJson.summary.serverEditions)
			$serverCount = @($server).Count
			$serverCIOnly = $serverCount -gt 0 -and (@($server | Where-Object { [string]$_ -match '(?i)\bCI only\b' }).Count -eq $serverCount)

			$summary.ValidatedDesktopEditions = @($validated)
			$summary.PendingDesktopEditions = @($pending)
			$summary.ServerEditions = @($server)
			$summary.HasServerCoverage = ($serverCount -gt 0)
			$summary.ServerCIOnly = $serverCIOnly
			$summary.ServerCoverageStatus = if ($serverCount -gt 0) { if ($serverCIOnly) { 'CIOnly' } else { 'Validated' } } else { 'Unavailable' }
			$summary.ServerValidationSummary = if ($serverCount -gt 0) {
				$serverText = if ($server.Count -gt 0) { $server -join ', ' } else { 'none' }
				if ($serverCIOnly)
				{
					('CI only: {0}' -f $serverText)
				}
				else
				{
					('Validated outside CI: {0}' -f $serverText)
				}
			}
			else
			{
				'No server editions recorded'
			}
			$summary.Summary = @(
				('Validated: {0}' -f ($(if ($validated.Count -gt 0) { $validated -join ', ' } else { 'none' }))),
				('Pending: {0}' -f ($(if ($pending.Count -gt 0) { $pending -join ', ' } else { 'none' }))),
				('Server: {0}' -f ($(if ($server.Count -gt 0) { $server -join ', ' } else { 'none' })))
			) -join ' | '
		}
		catch
		{
			$summary.Summary = 'Unavailable'
			$summary.ServerValidationSummary = 'Unavailable'
			$summary.ServerCoverageStatus = 'Unavailable'
			$summary.HasServerCoverage = $false
			$summary.ServerCIOnly = $false
		}
	}

	[pscustomobject]$summary
}

<#
    .SYNOPSIS
    Internal function Get-BaselineValidationEvidenceReport.
#>

function Get-BaselineValidationEvidenceReport
{
	[CmdletBinding()]
	param (
		[string]$RepoRoot = $null
	)

	$resolvedRepoRoot = $RepoRoot
	if ([string]::IsNullOrWhiteSpace($resolvedRepoRoot))
	{
		if ($Script:SharedHelpersRepoRoot)
		{
			$resolvedRepoRoot = [string]$Script:SharedHelpersRepoRoot
		}
		elseif ($PSScriptRoot)
		{
			$resolvedRepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
		}
	}

	$testReportPath = if (-not [string]::IsNullOrWhiteSpace($resolvedRepoRoot)) { Join-Path $resolvedRepoRoot 'Tests/TestReport.json' } else { $null }
	$matrixPath = if (-not [string]::IsNullOrWhiteSpace($resolvedRepoRoot)) { Join-Path $resolvedRepoRoot 'Tests/Integration/DesktopMatrixResults.json' } else { $null }
	$report = [ordered]@{
		Schema = 'Baseline.ValidationEvidence'
		SchemaVersion = 1
		GeneratedAt = [System.DateTime]::UtcNow.ToString('o')
		SourcePath = [ordered]@{
			RepoRoot = $resolvedRepoRoot
			TestReport = $testReportPath
			ValidationMatrix = $matrixPath
		}
		Build = [ordered]@{
			BaselineVersion = $null
			TestReportGeneratedAt = $null
			TestPlatform = $null
			TestPowerShell = $null
		}
		ValidationChannels = @()
		Summary = 'Unavailable'
	}

	$channelRows = [System.Collections.Generic.List[pscustomobject]]::new()
	$summaryParts = [System.Collections.Generic.List[string]]::new()

	$baselineVersion = $null
	if (Get-Command -Name 'Get-BaselineDisplayVersion' -ErrorAction SilentlyContinue)
	{
		try { $baselineVersion = Get-BaselineDisplayVersion } catch { $baselineVersion = $null }
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$baselineVersion))
	{
		$report.Build.BaselineVersion = [string]$baselineVersion
	}

	if ($testReportPath -and (Test-Path -LiteralPath $testReportPath))
	{
		try
		{
			$testReport = Get-Content -LiteralPath $testReportPath -Raw -Encoding UTF8 | ConvertFrom-BaselineJson -Depth 16 -ErrorAction Stop
			if ($testReport.PSObject.Properties['generated'])
			{
				$report.Build.TestReportGeneratedAt = [string]$testReport.generated
			}
			if ($testReport.PSObject.Properties['platform'])
			{
				$platform = $testReport.platform
				if ($platform.PSObject.Properties['os'])
				{
					$report.Build.TestPlatform = [string]$platform.os
				}
				if ($platform.PSObject.Properties['psVersion'])
				{
					$report.Build.TestPowerShell = [string]$platform.psVersion
				}
			}

			$unitLayer = $null
			$compositionLayer = $null
			if ($testReport.PSObject.Properties['layers'])
			{
				$layers = $testReport.layers
				if ($layers.PSObject.Properties['unit']) { $unitLayer = $layers.unit }
				if ($layers.PSObject.Properties['composition']) { $compositionLayer = $layers.composition }
			}

			if ($unitLayer)
			{
				$unitResult = if ($unitLayer.PSObject.Properties['result']) { [string]$unitLayer.result } else { 'Unknown' }
				$unitPassed = if ($unitLayer.PSObject.Properties['passed']) { [int]$unitLayer.passed } else { 0 }
				$unitFailed = if ($unitLayer.PSObject.Properties['failed']) { [int]$unitLayer.failed } else { 0 }
				$unitSkipped = if ($unitLayer.PSObject.Properties['skipped']) { [int]$unitLayer.skipped } else { 0 }
				$channelRows.Add([pscustomobject]@{
					Channel = 'unit-tested'
					Status = $unitResult
					Source = $testReportPath
					Detail = ('Unit layer result: {0} (passed {1}, failed {2}, skipped {3})' -f $unitResult, $unitPassed, $unitFailed, $unitSkipped)
				})
				if ($unitResult -eq 'Passed')
				{
					[void]$summaryParts.Add('unit-tested')
				}
			}

			if ($compositionLayer)
			{
				$compositionResult = if ($compositionLayer.PSObject.Properties['result']) { [string]$compositionLayer.result } else { 'Unknown' }
				$compositionPassed = if ($compositionLayer.PSObject.Properties['passed']) { [int]$compositionLayer.passed } else { 0 }
				$compositionFailed = if ($compositionLayer.PSObject.Properties['failed']) { [int]$compositionLayer.failed } else { 0 }
				$channelRows.Add([pscustomobject]@{
					Channel = 'desktop-session CI validated'
					Status = $compositionResult
					Source = $testReportPath
					Detail = ('Desktop-session layer result: {0} (passed {1}, failed {2})' -f $compositionResult, $compositionPassed, $compositionFailed)
				})
				if ($compositionResult -eq 'Passed')
				{
					[void]$summaryParts.Add('desktop-session CI validated')
				}
			}

			$manualChannel = $null
			if ($testReport.PSObject.Properties['validationChannel'] -and -not [string]::IsNullOrWhiteSpace([string]$testReport.validationChannel))
			{
				$manualChannel = [string]$testReport.validationChannel
			}
			elseif ($testReport.PSObject.Properties['manualValidation'])
			{
				$manualValidationValue = $testReport.manualValidation
				if (($manualValidationValue -is [bool] -and $manualValidationValue) -or ($manualValidationValue -isnot [bool] -and -not [string]::IsNullOrWhiteSpace([string]$manualValidationValue)))
				{
					$manualChannel = 'manually validated'
				}
			}
			elseif ($testReport.PSObject.Properties['summary'] -and $testReport.summary.PSObject.Properties['validationChannel'] -and -not [string]::IsNullOrWhiteSpace([string]$testReport.summary.validationChannel))
			{
				$manualChannel = [string]$testReport.summary.validationChannel
			}

			if (-not [string]::IsNullOrWhiteSpace($manualChannel))
			{
				$normalizedManualChannel = [string]$manualChannel.Trim()
				$channelRows.Add([pscustomobject]@{
					Channel = 'manually validated'
					Status = 'Passed'
					Source = $testReportPath
					Detail = ('Explicit validation channel recorded: {0}' -f $normalizedManualChannel)
				})
				[void]$summaryParts.Add('manually validated')
			}
		}
		catch
		{
			# Keep the report deterministic when the test report cannot be parsed.
		}
	}

	$matrix = $null
	if (Get-Command -Name 'Get-BaselineValidationMatrixSummary' -ErrorAction SilentlyContinue)
	{
		try { $matrix = Get-BaselineValidationMatrixSummary -RepoRoot $resolvedRepoRoot } catch { $matrix = $null }
	}
	if ($matrix)
	{
		$channelRows.Add([pscustomobject]@{
			Channel = 'server CI only'
			Status = if ($matrix.HasServerCoverage) { if ($matrix.ServerCIOnly) { 'CI only' } else { 'Outside CI' } } else { 'Unavailable' }
			Source = $matrix.SourcePath
			Detail = [string]$matrix.ServerValidationSummary
		})
		if ($matrix.HasServerCoverage -and $matrix.ServerCIOnly)
		{
			[void]$summaryParts.Add('server CI only')
		}
	}

	$report.ValidationChannels = @($channelRows)
	if ($summaryParts.Count -gt 0)
	{
		$report.Summary = ($summaryParts -join '; ')
	}

	[pscustomobject]$report
}

<#
    .SYNOPSIS
    Internal function ConvertTo-WindowsDisplayVersionComparable.
#>

function ConvertTo-WindowsDisplayVersionComparable
{
	<# .SYNOPSIS Converts a display version string (e.g. 23H2) to a sortable integer. #>
	param
	(
		[string]
		$DisplayVersion
	)

	if ([string]::IsNullOrWhiteSpace($DisplayVersion))
	{
		return $null
	}

	if ($DisplayVersion -match '^(?<Year>\d{2})H(?<Half>\d)$')
	{
		return ([int]$Matches.Year * 10) + [int]$Matches.Half
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Test-Windows11FeatureBranchSupport.
#>

function Test-Windows11FeatureBranchSupport
{
	<# .SYNOPSIS Tests whether Windows 11 meets the feature branch threshold. #>
	param
	(
		[Parameter(Mandatory = $true)]
		[hashtable[]]
		$Thresholds
	)

	$VersionData = Get-WindowsVersionData
	if (-not $VersionData.IsWindows11)
	{
		return $false
	}

	$ParsedThresholds = $Thresholds | ForEach-Object {
		[pscustomobject]@{
			DisplayVersion = [string]$_.DisplayVersion
			Build          = [int]$_.Build
			UBR            = if ($null -ne $_.UBR) { [int]$_.UBR } else { 0 }
		}
	} | Sort-Object Build, UBR

	if (-not $ParsedThresholds)
	{
		return $false
	}

	$ApplicableThreshold = $ParsedThresholds | Where-Object -FilterScript {
		$VersionData.CurrentBuild -ge $_.Build
	} | Select-Object -Last 1

	if (-not $ApplicableThreshold)
	{
		return $false
	}

	if ($VersionData.CurrentBuild -gt $ApplicableThreshold.Build)
	{
		return $true
	}

	return ($VersionData.UBR -ge $ApplicableThreshold.UBR)
}

<#
    .SYNOPSIS
    Internal function Get-BaselineWindowsThemePreference.
#>

function Get-BaselineWindowsThemePreference
{
	param ()

	$personalizePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
	try
	{
		$themeSettings = Get-ItemProperty -LiteralPath $personalizePath -ErrorAction Stop
		foreach ($propertyName in @('AppsUseLightTheme', 'SystemUsesLightTheme'))
		{
			if ($themeSettings.PSObject.Properties[$propertyName])
			{
				if ([int]$themeSettings.$propertyName -eq 1)
				{
					return 'Light'
				}

				return 'Dark'
			}
		}
	}
	catch
	{
		Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.GetBaselineWindowsThemePreference.LoadTheme'
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Get-BaselineStartupThemeName.
#>

function Get-BaselineStartupThemeName
{
	param ()

	$sessionPath = $null
	try
	{
		$stateRoot = [System.Environment]::GetEnvironmentVariable('BASELINE_STATE_ROOT')
		if (-not [string]::IsNullOrWhiteSpace([string]$stateRoot))
		{
			$sessionBaseDir = Join-Path $stateRoot 'Profiles'
		}
		elseif ($env:LOCALAPPDATA)
		{
			$sessionBaseDir = Join-Path $env:LOCALAPPDATA 'Baseline\Profiles'
		}
		else
		{
			$sessionBaseDir = Join-Path $env:TEMP 'Baseline\Profiles'
		}

		$sessionPath = Join-Path $sessionBaseDir 'Baseline-last-session.json'
		if (Test-Path -LiteralPath $sessionPath -PathType Leaf)
		{
			$sessionJson = Get-Content -LiteralPath $sessionPath -Raw -ErrorAction Stop | ConvertFrom-BaselineJson -Depth 16
			$sessionTheme = $null
			if ($sessionJson -and $sessionJson.State -and $sessionJson.State.Theme)
			{
				$sessionTheme = [string]$sessionJson.State.Theme
			}
			elseif ($sessionJson -and $sessionJson.Theme)
			{
				$sessionTheme = [string]$sessionJson.Theme
			}

			if ($sessionTheme -in @('Light', 'Dark'))
			{
				return $sessionTheme
			}
		}
	}
	catch
	{
		Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.GetBaselineStartupThemeName.LoadSession'
	}

	$windowsTheme = Get-BaselineWindowsThemePreference
	if ($windowsTheme -in @('Light', 'Dark'))
	{
		return $windowsTheme
	}

	return 'Dark'
}

<#
    .SYNOPSIS
    Internal function Show-BootstrapLoadingSplash.
#>

function Show-BootstrapLoadingSplash
{
	<# .SYNOPSIS Displays a loading splash window in a background runspace. #>
	[CmdletBinding()]
	[OutputType([System.Object])]
	param (
		[switch]$StartUpdatesPulse
	)

	try
	{
		Write-EnvironmentLaunchTrace ('Bootstrap splash helper entered: embedded={0} startUpdatesPulse={1}' -f [System.Environment]::GetEnvironmentVariable('BASELINE_EMBEDDED_HOST'), [bool]$StartUpdatesPulse)
		Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase -ErrorAction Stop

		# Match the main GUI's startup sizing logic so the splash and the
		# eventual main window hand off at the same physical footprint.
		$guiMinW = 940
		$guiMinH = 660
		try
		{
			$workArea = [System.Windows.SystemParameters]::WorkArea
			$widthRatio = if ($workArea.Width -ge 2560) { 0.55 } elseif ($workArea.Width -ge 1920) { 0.65 } else { 0.85 }
			$targetW = [Math]::Round($workArea.Width * $widthRatio)
			$targetH = [Math]::Round($workArea.Height * 0.85)
			$maxW = [Math]::Min(1400, $workArea.Width)
			$effectiveMinW = [Math]::Min($guiMinW, $workArea.Width)
			$effectiveMinH = [Math]::Min($guiMinH, $workArea.Height)
			$splashWindowWidth  = [int][Math]::Min([Math]::Max($targetW, $effectiveMinW), $maxW)
			$splashWindowHeight = [int][Math]::Min([Math]::Max($targetH, $effectiveMinH), $workArea.Height)
		}
		catch
		{
			$splashWindowWidth  = $guiMinW
			$splashWindowHeight = $guiMinH
		}

		# Match the last saved session first, then fall back to the current Windows theme.
		$useLightTheme = ((Get-BaselineStartupThemeName) -eq 'Light')

			$syncHash = [hashtable]::Synchronized(@{
				Window     = $null
				Dispatcher = $null
				StatusText = $null
				SubActionPanel = $null
				ProgressBar = $null
				StepGlyphs = $null
				StepIdleDots = $null
				StepPulseDots = $null
				StepChecks = $null
				StepLabels = $null
				StepStates = $null
				StepOrder  = @('updates', 'system', 'winget', 'chocolatey', 'finalize')
				SplashTheme = $null
				GuiReady   = $false
				IsReady    = $false
				IsAlive    = $true
				WasLoaded  = $false
				WasShown   = $false
				WasRendered = $false
				StartUpdatesPulseApplied = $false
				ChecklistProgressActive = $false
				WindowHandle = [IntPtr]::Zero
				ErrorType  = $null
				ErrorMessage = $null
			})

		# Theme colors
		if ($useLightTheme)
		{
			$splashBg = '#F0F2F6'; $splashBorder = '#E6EAF0'; $splashFg = '#1F2937'
			$splashSub = '#6B7280'; $splashAccent = '#1550AA'; $splashFooterBg = '#E9EDF3'
			$splashMuted = '#7A8494'; $splashBtnFg = '#6B7280'; $splashStepActive = '#1F2937'; $splashDarkMode = $false
		}
		else
		{
			$splashBg = '#10131C'; $splashBorder = '#293044'; $splashFg = '#F4F7FF'
			$splashSub = '#AEB7D1'; $splashAccent = '#7CB7FF'; $splashFooterBg = '#151824'
			$splashMuted = '#7E89A8'; $splashBtnFg = '#B8C1D9'; $splashStepActive = '#E6EBFF'; $splashDarkMode = $true
		}
		$CurrentTheme = [ordered]@{
			WindowBg    = $splashBg
			BorderColor = $splashBorder
			TextPrimary = $splashFg
			TextSecondary = $splashSub
			Accent      = $splashAccent
			CardBg      = $splashFooterBg
			TextMuted   = $splashMuted
		}
		$SplashTheme = [ordered]@{
			Muted   = $splashMuted
			Sub     = $splashSub
			Primary = $splashStepActive
			Accent  = $splashAccent
		}

		$runspace = [runspacefactory]::CreateRunspace()
		$runspace.ApartmentState = 'STA'
		$runspace.ThreadOptions  = 'ReuseThread'
		$runspace.Open()
		$splashIconPath = $null
		$splashThemePath = $null
		try
		{
			$repoBasePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
			$candidateSplashIcon = Join-Path -Path $repoBasePath -ChildPath 'Assets\baseline.ico'
			if (Test-Path -LiteralPath $candidateSplashIcon -PathType Leaf)
			{
				$splashIconPath = [System.IO.Path]::GetFullPath($candidateSplashIcon)
			}
			$splashThemeFileName = if ($useLightTheme) { 'Light.xaml' } else { 'Dark.xaml' }
			$candidateSplashTheme = Join-Path -Path $repoBasePath -ChildPath ('Module\GUI\Themes\{0}' -f $splashThemeFileName)
			if (Test-Path -LiteralPath $candidateSplashTheme -PathType Leaf)
			{
				$splashThemePath = [System.IO.Path]::GetFullPath($candidateSplashTheme)
			}
		}
		catch
		{
			$splashIconPath = $null
			$splashThemePath = $null
		}
		$runspace.SessionStateProxy.SetVariable('syncHash', $syncHash)
		$runspace.SessionStateProxy.SetVariable('splashIconPath', $splashIconPath)
		$runspace.SessionStateProxy.SetVariable('splashThemePath', $splashThemePath)
		$runspace.SessionStateProxy.SetVariable('splashBg', $splashBg)
		$runspace.SessionStateProxy.SetVariable('splashBorder', $splashBorder)
		$runspace.SessionStateProxy.SetVariable('splashFg', $splashFg)
		$runspace.SessionStateProxy.SetVariable('splashSub', $splashSub)
		$runspace.SessionStateProxy.SetVariable('splashAccent', $splashAccent)
		$runspace.SessionStateProxy.SetVariable('splashFooterBg', $splashFooterBg)
		$runspace.SessionStateProxy.SetVariable('splashMuted', $splashMuted)
		$runspace.SessionStateProxy.SetVariable('splashBtnFg', $splashBtnFg)
		$runspace.SessionStateProxy.SetVariable('splashDarkMode', $splashDarkMode)
		$runspace.SessionStateProxy.SetVariable('splashWindowWidth', $splashWindowWidth)
		$runspace.SessionStateProxy.SetVariable('splashWindowHeight', $splashWindowHeight)
		$runspace.SessionStateProxy.SetVariable('CurrentTheme', $CurrentTheme)
		$runspace.SessionStateProxy.SetVariable('SplashTheme', $SplashTheme)
		# Pass localization strings for splash screen
		$splashLocSubtitle = Get-BaselineLocalizedString -Key 'GuiSplashSubtitle' -Fallback 'Windows Optimization & Hardening'
		$splashLocLoading = Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait...'
		$splashLocStepUpdates    = Get-BaselineLocalizedString -Key 'Bootstrap_StepCheckingForUpdates' -Fallback 'Checking for Updates'
		$splashLocStepSystem     = Get-BaselineLocalizedString -Key 'Bootstrap_StepRunningSystemChecks' -Fallback 'Running System Checks'
		$splashLocStepWinget     = Get-BaselineLocalizedString -Key 'Bootstrap_StepCheckingWinget' -Fallback 'Checking WinGet'
		$splashLocStepChocolatey = Get-BaselineLocalizedString -Key 'Bootstrap_StepCheckingChocolatey' -Fallback 'Checking Chocolatey'
		$splashLocStepFinalize   = Get-BaselineLocalizedString -Key 'Bootstrap_StepFinalizing' -Fallback 'Finalizing Baseline Configuration'
		$runspace.SessionStateProxy.SetVariable('splashLocSubtitle', $splashLocSubtitle)
		$runspace.SessionStateProxy.SetVariable('splashLocLoading', $splashLocLoading)
		$runspace.SessionStateProxy.SetVariable('splashLocCheckingForUpdates', (Get-BaselineLocalizedString -Key 'Bootstrap_CheckingForUpdates' -Fallback 'Checking for updates...'))
		$runspace.SessionStateProxy.SetVariable('splashLocStepUpdates', $splashLocStepUpdates)
		$runspace.SessionStateProxy.SetVariable('splashLocStepSystem', $splashLocStepSystem)
		$runspace.SessionStateProxy.SetVariable('splashLocStepWinget', $splashLocStepWinget)
		$runspace.SessionStateProxy.SetVariable('splashLocStepChocolatey', $splashLocStepChocolatey)
		$runspace.SessionStateProxy.SetVariable('splashLocStepFinalize', $splashLocStepFinalize)
		$runspace.SessionStateProxy.SetVariable('startUpdatesPulse', [bool]$StartUpdatesPulse)
		$runspace.SessionStateProxy.SetVariable('bootstrapSplashProgressWidthDefinition', (Get-Command -Name 'Get-BaselineSplashProgressWidth' -CommandType Function -ErrorAction Stop).ScriptBlock.ToString())
		$runspace.SessionStateProxy.SetVariable('bootstrapLoadingSplashStateDefinition', (Get-Command -Name 'Set-BootstrapLoadingSplashState' -CommandType Function -ErrorAction Stop).ScriptBlock.ToString())
		$runspace.SessionStateProxy.SetVariable('bootstrapLoadingSplashStepDefinition', (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction Stop).ScriptBlock.ToString())

		$ps = [powershell]::Create()
		$ps.Runspace = $runspace
		[void]$ps.AddScript({
			try
			{
				Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

				$installSplashFunction = {
					param(
						[string]$Name,
						[string]$Definition
					)

					if ([string]::IsNullOrWhiteSpace($Definition))
					{
						throw "Bootstrap splash function definition is empty: $Name"
					}

					Set-Item -Path ('Function:\global:{0}' -f $Name) -Value ([scriptblock]::Create($Definition)) -ErrorAction Stop
				}

				& $installSplashFunction 'Get-BaselineSplashProgressWidth' $bootstrapSplashProgressWidthDefinition
				& $installSplashFunction 'Set-BootstrapLoadingSplashState' $bootstrapLoadingSplashStateDefinition
				& $installSplashFunction 'Set-BootstrapLoadingSplashStep' $bootstrapLoadingSplashStepDefinition
				$bootstrapLoadingSplashStateCommand = (Get-Command -Name 'Set-BootstrapLoadingSplashState' -CommandType Function -ErrorAction Stop).ScriptBlock
				$bootstrapLoadingSplashStepCommand = (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction Stop).ScriptBlock

				$subtitleEsc = [System.Security.SecurityElement]::Escape($splashLocSubtitle)
				$loadingEsc = [System.Security.SecurityElement]::Escape($splashLocLoading)
				$stepUpdatesEsc = [System.Security.SecurityElement]::Escape($splashLocStepUpdates)
				$stepSystemEsc = [System.Security.SecurityElement]::Escape($splashLocStepSystem)
				$stepWingetEsc = [System.Security.SecurityElement]::Escape($splashLocStepWinget)
				$stepChocolateyEsc = [System.Security.SecurityElement]::Escape($splashLocStepChocolatey)
				$stepFinalizeEsc = [System.Security.SecurityElement]::Escape($splashLocStepFinalize)

				[xml]$xaml = @"
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Title="Baseline | Windows Utility"
	Width="$splashWindowWidth"
	Height="$splashWindowHeight"
	MinWidth="940"
	MinHeight="660"
	ResizeMode="NoResize"
	WindowStartupLocation="CenterScreen"
	Background="Transparent"
	BorderBrush="Transparent"
	BorderThickness="0"
	Foreground="{DynamicResource Brush.TextPrimary}"
	FontFamily="Segoe UI"
	ShowInTaskbar="True"
	ShowActivated="False"
	Topmost="False"
	WindowStyle="None"
	AllowsTransparency="True"
	SnapsToDevicePixels="True"
	UseLayoutRounding="True">
	<Window.Resources>
		<Storyboard x:Key="SpinnerRotation" RepeatBehavior="Forever">
			<DoubleAnimation Storyboard.TargetName="SubActionSpinnerRotate" Storyboard.TargetProperty="Angle" From="0" To="360" Duration="0:0:1.2"/>
		</Storyboard>
		<Style x:Key="SplashCaptionButtonStyle" TargetType="Button">
			<Setter Property="Background" Value="Transparent"/>
			<Setter Property="Foreground" Value="{DynamicResource Brush.TextSecondary}"/>
			<Setter Property="BorderBrush" Value="Transparent"/>
			<Setter Property="BorderThickness" Value="0"/>
			<Setter Property="Padding" Value="0"/>
			<Setter Property="FocusVisualStyle" Value="{x:Null}"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Button">
						<Border x:Name="CaptionBd"
							Background="{TemplateBinding Background}"
							BorderBrush="{TemplateBinding BorderBrush}"
							BorderThickness="{TemplateBinding BorderThickness}"
							CornerRadius="6"
							SnapsToDevicePixels="True">
							<ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
						</Border>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
			<Style.Triggers>
				<Trigger Property="IsMouseOver" Value="True">
					<Setter Property="Background" Value="{DynamicResource Brush.SurfaceHover}"/>
					<Setter Property="Foreground" Value="{DynamicResource Brush.TextPrimary}"/>
				</Trigger>
				<Trigger Property="IsPressed" Value="True">
					<Setter Property="Background" Value="{DynamicResource Brush.ButtonPressBg}"/>
					<Setter Property="Foreground" Value="{DynamicResource Brush.TextPrimary}"/>
				</Trigger>
			</Style.Triggers>
		</Style>
		<Style x:Key="SplashCloseButtonStyle" TargetType="Button" BasedOn="{StaticResource SplashCaptionButtonStyle}">
			<Style.Triggers>
				<Trigger Property="IsMouseOver" Value="True">
					<Setter Property="Background" Value="{DynamicResource Brush.Danger}"/>
					<Setter Property="Foreground" Value="White"/>
				</Trigger>
				<Trigger Property="IsPressed" Value="True">
					<Setter Property="Background" Value="{DynamicResource Brush.Danger}"/>
					<Setter Property="Foreground" Value="White"/>
				</Trigger>
			</Style.Triggers>
		</Style>
	</Window.Resources>
	<Window.Triggers>
		<EventTrigger RoutedEvent="FrameworkElement.Loaded">
			<BeginStoryboard Storyboard="{StaticResource SpinnerRotation}"/>
		</EventTrigger>
	</Window.Triggers>
	<Border Name="RootBorder" CornerRadius="8" Background="{DynamicResource Brush.SplashBackdrop}" BorderBrush="{DynamicResource Brush.Border}" BorderThickness="1" Margin="0" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" SnapsToDevicePixels="True" ClipToBounds="True">
			<Grid Background="Transparent" Margin="0" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" SnapsToDevicePixels="True">
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="*"/>
				</Grid.RowDefinitions>
			<Grid Grid.Row="0" Background="{DynamicResource Brush.HeaderBg}" Margin="10,6,6,0">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<DockPanel Grid.Column="0" LastChildFill="True" VerticalAlignment="Center" Margin="0,0,10,0">
					<Image Name="SplashTopLeftIcon" Width="20" Height="20" Stretch="Uniform" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="2,0,8,0"/>
					<TextBlock Name="TitleText"
						Text="{Binding RelativeSource={RelativeSource AncestorType=Window}, Path=Title}"
						FontSize="12"
						FontWeight="SemiBold"
						Foreground="{DynamicResource Brush.TextPrimary}"
						VerticalAlignment="Center"
						TextTrimming="CharacterEllipsis"/>
				</DockPanel>
				<StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
					<Button Name="BtnMinimize" Content="&#x2015;" Width="28" Height="24" FontSize="11"
						Cursor="Hand" ToolTip="Minimize" Margin="0,0,2,0" Style="{StaticResource SplashCaptionButtonStyle}"/>
					<Button Name="BtnClose" Content="&#x2715;" Width="28" Height="24" FontSize="11"
						Cursor="Hand" ToolTip="Close" Style="{StaticResource SplashCloseButtonStyle}"/>
				</StackPanel>
			</Grid>
			<Border Name="SplashContentCard" Grid.Row="1" Background="{DynamicResource Brush.SplashCard}" BorderThickness="0" CornerRadius="18" Padding="52,44" VerticalAlignment="Center" HorizontalAlignment="Center" SnapsToDevicePixels="True">
				<Border.Effect>
					<DropShadowEffect Color="#000000" BlurRadius="34" ShadowDepth="0" Opacity="0.18"/>
				</Border.Effect>
				<StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Margin="0">
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,16">
					<Image Name="SplashCenterIcon" Width="58" Height="58" Stretch="Uniform" VerticalAlignment="Center" Margin="0,0,16,0"
						RenderOptions.BitmapScalingMode="HighQuality" UseLayoutRounding="True" SnapsToDevicePixels="True"/>
					<TextBlock Text="Baseline"
						FontWeight="SemiBold"
						FontSize="56"
						Foreground="{DynamicResource Brush.TextPrimary}"
						VerticalAlignment="Center"/>
				</StackPanel>
				<TextBlock Name="SubtitleText" Text="$subtitleEsc"
					FontSize="14" Foreground="{DynamicResource Brush.SplashSubtitle}"
					HorizontalAlignment="Center" Margin="0,0,0,32"/>
				<StackPanel Name="StepListPanel" HorizontalAlignment="Center" MinWidth="360" Margin="0,0,0,24">
					<Grid Margin="0,0,0,7">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="22"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid Name="StepGlyph_updates" Grid.Column="0" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Center">
							<Ellipse Name="StepIdle_updates" Width="8" Height="8" Stroke="{DynamicResource Brush.TextMuted}" StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center" HorizontalAlignment="Center"/>
							<Ellipse Name="StepPulse_updates" Width="8" Height="8" Fill="{DynamicResource Brush.Accent}" Opacity="0.6" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center" RenderTransformOrigin="0.5,0.5">
								<Ellipse.RenderTransform>
									<ScaleTransform/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<TextBlock Name="StepCheck_updates" Text="&#x2714;" FontFamily="Segoe UI Symbol" FontSize="12" Foreground="{DynamicResource Brush.Accent}" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
						</Grid>
						<TextBlock Name="StepLabel_updates" Grid.Column="1" Text="$stepUpdatesEsc" FontSize="13" Foreground="{DynamicResource Brush.TextMuted}" VerticalAlignment="Center" Margin="8,0,0,0"/>
					</Grid>
					<Grid Margin="0,0,0,7">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="22"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid Name="StepGlyph_system" Grid.Column="0" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Center">
							<Ellipse Name="StepIdle_system" Width="8" Height="8" Stroke="{DynamicResource Brush.TextMuted}" StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center" HorizontalAlignment="Center"/>
							<Ellipse Name="StepPulse_system" Width="8" Height="8" Fill="{DynamicResource Brush.Accent}" Opacity="0.6" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center" RenderTransformOrigin="0.5,0.5">
								<Ellipse.RenderTransform>
									<ScaleTransform/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<TextBlock Name="StepCheck_system" Text="&#x2714;" FontFamily="Segoe UI Symbol" FontSize="12" Foreground="{DynamicResource Brush.Accent}" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
						</Grid>
						<TextBlock Name="StepLabel_system" Grid.Column="1" Text="$stepSystemEsc" FontSize="13" Foreground="{DynamicResource Brush.TextMuted}" VerticalAlignment="Center" Margin="8,0,0,0"/>
					</Grid>
					<Grid Margin="0,0,0,7">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="22"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid Name="StepGlyph_winget" Grid.Column="0" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Center">
							<Ellipse Name="StepIdle_winget" Width="8" Height="8" Stroke="{DynamicResource Brush.TextMuted}" StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center" HorizontalAlignment="Center"/>
							<Ellipse Name="StepPulse_winget" Width="8" Height="8" Fill="{DynamicResource Brush.Accent}" Opacity="0.6" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center" RenderTransformOrigin="0.5,0.5">
								<Ellipse.RenderTransform>
									<ScaleTransform/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<TextBlock Name="StepCheck_winget" Text="&#x2714;" FontFamily="Segoe UI Symbol" FontSize="12" Foreground="{DynamicResource Brush.Accent}" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
						</Grid>
						<TextBlock Name="StepLabel_winget" Grid.Column="1" Text="$stepWingetEsc" FontSize="13" Foreground="{DynamicResource Brush.TextMuted}" VerticalAlignment="Center" Margin="8,0,0,0"/>
					</Grid>
					<Grid Margin="0,0,0,7">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="22"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid Name="StepGlyph_chocolatey" Grid.Column="0" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Center">
							<Ellipse Name="StepIdle_chocolatey" Width="8" Height="8" Stroke="{DynamicResource Brush.TextMuted}" StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center" HorizontalAlignment="Center"/>
							<Ellipse Name="StepPulse_chocolatey" Width="8" Height="8" Fill="{DynamicResource Brush.Accent}" Opacity="0.6" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center" RenderTransformOrigin="0.5,0.5">
								<Ellipse.RenderTransform>
									<ScaleTransform/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<TextBlock Name="StepCheck_chocolatey" Text="&#x2714;" FontFamily="Segoe UI Symbol" FontSize="12" Foreground="{DynamicResource Brush.Accent}" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
						</Grid>
						<TextBlock Name="StepLabel_chocolatey" Grid.Column="1" Text="$stepChocolateyEsc" FontSize="13" Foreground="{DynamicResource Brush.TextMuted}" VerticalAlignment="Center" Margin="8,0,0,0"/>
					</Grid>
					<Grid Margin="0,0,0,0">
						<Grid.ColumnDefinitions>
							<ColumnDefinition Width="22"/>
							<ColumnDefinition Width="*"/>
						</Grid.ColumnDefinitions>
						<Grid Name="StepGlyph_finalize" Grid.Column="0" Width="16" Height="16" VerticalAlignment="Center" HorizontalAlignment="Center">
							<Ellipse Name="StepIdle_finalize" Width="8" Height="8" Stroke="{DynamicResource Brush.TextMuted}" StrokeThickness="1" Fill="Transparent" VerticalAlignment="Center" HorizontalAlignment="Center"/>
							<Ellipse Name="StepPulse_finalize" Width="8" Height="8" Fill="{DynamicResource Brush.Accent}" Opacity="0.6" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Center" RenderTransformOrigin="0.5,0.5">
								<Ellipse.RenderTransform>
									<ScaleTransform/>
								</Ellipse.RenderTransform>
							</Ellipse>
							<TextBlock Name="StepCheck_finalize" Text="&#x2714;" FontFamily="Segoe UI Symbol" FontSize="12" Foreground="{DynamicResource Brush.Accent}" VerticalAlignment="Center" HorizontalAlignment="Center" Visibility="Collapsed"/>
						</Grid>
						<TextBlock Name="StepLabel_finalize" Grid.Column="1" Text="$stepFinalizeEsc" FontSize="13" Foreground="{DynamicResource Brush.TextMuted}" VerticalAlignment="Center" Margin="8,0,0,0"/>
					</Grid>
				</StackPanel>
				<StackPanel Name="SubActionPanel" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,14" Visibility="Collapsed">
					<TextBlock Name="SubActionSpinner" Text="&#x27F3;" FontFamily="Segoe UI Symbol" FontSize="11"
						Foreground="{DynamicResource Brush.TextSecondary}" VerticalAlignment="Center" Margin="0,0,6,0" RenderTransformOrigin="0.5,0.5">
						<TextBlock.RenderTransform>
							<RotateTransform x:Name="SubActionSpinnerRotate" Angle="0"/>
						</TextBlock.RenderTransform>
					</TextBlock>
					<TextBlock Name="StatusText" Text="$loadingEsc" FontSize="11" Foreground="{DynamicResource Brush.TextMuted}"
						VerticalAlignment="Center"/>
				</StackPanel>
				<ProgressBar Name="ProgressBar"
					Width="360" Height="6"
					Visibility="Visible"
					Minimum="0" Maximum="330" Value="0"
					IsIndeterminate="False"
					Foreground="{DynamicResource Brush.Progress}"
					Background="{DynamicResource Brush.ProgressTrack}"
					BorderThickness="0">
					<ProgressBar.Template>
						<ControlTemplate TargetType="ProgressBar">
							<Grid SnapsToDevicePixels="True">
								<Border x:Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="3" Opacity="0.82"/>
								<Border x:Name="PART_Indicator" Width="{TemplateBinding Value}" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="3">
									<Border.Effect>
										<DropShadowEffect Color="{DynamicResource Color.Progress}" BlurRadius="10" ShadowDepth="0" Opacity="0.35"/>
									</Border.Effect>
									<Grid ClipToBounds="True">
										<Rectangle x:Name="PART_GlowRect" Width="84" HorizontalAlignment="Left" RenderTransformOrigin="0,0">
											<Rectangle.Fill>
												<LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
													<GradientStop Color="#00FFFFFF" Offset="0"/>
													<GradientStop Color="#7FFFFFFF" Offset="0.5"/>
													<GradientStop Color="#00FFFFFF" Offset="1"/>
												</LinearGradientBrush>
											</Rectangle.Fill>
											<Rectangle.RenderTransform>
												<TranslateTransform x:Name="SplashSheenT" X="-100"/>
											</Rectangle.RenderTransform>
										</Rectangle>
									</Grid>
								</Border>
							</Grid>
							<ControlTemplate.Triggers>
								<EventTrigger RoutedEvent="FrameworkElement.Loaded">
									<BeginStoryboard>
										<Storyboard RepeatBehavior="Forever">
											<DoubleAnimation Storyboard.TargetName="SplashSheenT" Storyboard.TargetProperty="X" From="-100" To="400" Duration="0:0:1.4"/>
										</Storyboard>
									</BeginStoryboard>
								</EventTrigger>
							</ControlTemplate.Triggers>
						</ControlTemplate>
					</ProgressBar.Template>
				</ProgressBar>
				</StackPanel>
			</Border>
		</Grid>
	</Border>
</Window>
"@
				$splash = [System.Windows.Markup.XamlReader]::Load(
					(New-Object System.Xml.XmlNodeReader $xaml)
				)
				if ([string]::IsNullOrWhiteSpace([string]$splashThemePath))
				{
					throw 'Bootstrap splash theme resource dictionary was not found.'
				}

				$themeReader = [System.Xml.XmlReader]::Create($splashThemePath)
				try
				{
					$themeDictionary = [System.Windows.Markup.XamlReader]::Load($themeReader)
					if (-not ($themeDictionary -is [System.Windows.ResourceDictionary]))
					{
						throw "Bootstrap splash theme resource did not load as a ResourceDictionary: $splashThemePath"
					}
					[void]$splash.Resources.MergedDictionaries.Add($themeDictionary)
				}
				finally
				{
					if ($themeReader) { $themeReader.Close() }
				}

				$tracePath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline-launch-trace.txt'
				$writeSplashTrace = {
					param([string]$Message)
					try { [System.IO.File]::AppendAllText($tracePath, ("{0:o} {1}`r`n" -f [DateTime]::UtcNow, $Message), [System.Text.Encoding]::UTF8) } catch { }
				}

				if (-not [string]::IsNullOrWhiteSpace([string]$splashIconPath) -and (Test-Path -LiteralPath $splashIconPath -PathType Leaf))
				{
					try
					{
						$selectSplashIconFrame = {
							param(
								[Parameter(Mandatory = $true)]
								[System.Collections.IEnumerable]
								$Frames,
								[Parameter(Mandatory = $true)]
								[int]$TargetPixelWidth
							)

							$closest = $Frames |
								Sort-Object -Property @{ Expression = { [Math]::Abs($_.PixelWidth - $TargetPixelWidth) } } |
								Select-Object -First 1
							return $closest
						}

						$iconUri = [System.Uri]::new($splashIconPath, [System.UriKind]::Absolute)
						$iconDecoder = [System.Windows.Media.Imaging.IconBitmapDecoder]::new(
							$iconUri,
							[System.Windows.Media.Imaging.BitmapCreateOptions]::None,
							[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
						)
						$iconForWindow = if ($iconDecoder.Frames -and $iconDecoder.Frames.Count -gt 0)
						{
							& $selectSplashIconFrame -Frames $iconDecoder.Frames -TargetPixelWidth 32
						}
						else
						{
							$null
						}
						$iconForTitleBar = if ($iconDecoder.Frames -and $iconDecoder.Frames.Count -gt 0)
						{
							& $selectSplashIconFrame -Frames $iconDecoder.Frames -TargetPixelWidth 20
						}
						else
						{
							$null
						}
						$iconForCenterLogo = if ($iconDecoder.Frames -and $iconDecoder.Frames.Count -gt 0)
						{
							& $selectSplashIconFrame -Frames $iconDecoder.Frames -TargetPixelWidth 58
						}
						else
						{
							$null
						}
						if (-not $iconForWindow) { $iconForWindow = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri) }
						if (-not $iconForTitleBar) { $iconForTitleBar = $iconForWindow }
						if (-not $iconForCenterLogo) { $iconForCenterLogo = $iconForWindow }
						if ($iconForWindow -and $iconForWindow.CanFreeze) { $iconForWindow.Freeze() }
						if ($iconForTitleBar -and $iconForTitleBar.CanFreeze) { $iconForTitleBar.Freeze() }
						if ($iconForCenterLogo -and $iconForCenterLogo.CanFreeze) { $iconForCenterLogo.Freeze() }
						$splash.Icon = $iconForWindow
						$splashTopLeftIcon = $splash.FindName('SplashTopLeftIcon')
						if ($splashTopLeftIcon)
						{
							$splashTopLeftIcon.Source = $iconForTitleBar
							[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($splashTopLeftIcon, [System.Windows.Media.BitmapScalingMode]::HighQuality)
							$splashTopLeftIcon.SnapsToDevicePixels = $true
							$splashTopLeftIcon.UseLayoutRounding = $true
						}
						$splashCenterIcon = $splash.FindName('SplashCenterIcon')
						if ($splashCenterIcon)
						{
							$splashCenterIcon.Source = $iconForCenterLogo
							[System.Windows.Media.RenderOptions]::SetBitmapScalingMode($splashCenterIcon, [System.Windows.Media.BitmapScalingMode]::HighQuality)
							$splashCenterIcon.SnapsToDevicePixels = $true
							$splashCenterIcon.UseLayoutRounding = $true
						}
					}
					catch { & $writeSplashTrace ('Environment.ShowBootstrapLoadingSplash.LoadSplashIcon: {0}' -f $_.Exception.Message) }
				}

				# Apply Windows 11 rounded corners and dark title bar
				$splash.Add_SourceInitialized({
					try
					{
						if (-not ('WinAPI.SplashChrome' -as [type]))
						{
							Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace WinAPI {
	public static class SplashChrome {
		[DllImport("dwmapi.dll")]
		public static extern int DwmSetWindowAttribute(IntPtr hwnd, int dwAttribute, ref int pvAttribute, int cbAttribute);
		[DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")] private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
		[DllImport("user32.dll", EntryPoint = "GetWindowLong")] private static extern IntPtr GetWindowLong32(IntPtr hWnd, int nIndex);
		[DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")] private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
		[DllImport("user32.dll", EntryPoint = "SetWindowLong")] private static extern IntPtr SetWindowLong32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
		[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
		public static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex) { return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLong32(hWnd, nIndex); }
		public static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong) { return IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, nIndex, dwNewLong) : SetWindowLong32(hWnd, nIndex, dwNewLong); }
		public const int GWL_STYLE = -16;
		public const int WS_SYSMENU = 0x00080000;
		public const int WS_MINIMIZEBOX = 0x00020000;
	}
}
"@ -ErrorAction Stop | Out-Null
						}
						$hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($splash)).Handle
						if ($hwnd -ne [IntPtr]::Zero)
						{
							$syncHash.WindowHandle = $hwnd
							$darkMode = if ($splashDarkMode) { 1 } else { 0 }
							$immAttr = if ([Environment]::OSVersion.Version.Build -ge 18362) { 20 } else { 19 }
							[void]([WinAPI.SplashChrome]::DwmSetWindowAttribute($hwnd, $immAttr, [ref]$darkMode, 4))
							if ([Environment]::OSVersion.Version.Build -ge 22000)
							{
								$cornerPref = 2
								[void]([WinAPI.SplashChrome]::DwmSetWindowAttribute($hwnd, 33, [ref]$cornerPref, 4))
							}
							# Restore system menu (right-click title bar: Restore/Move/Size/Minimize/Maximize/Close)
							$style = [WinAPI.SplashChrome]::GetWindowLongPtr($hwnd, [WinAPI.SplashChrome]::GWL_STYLE)
							$styleInt = $style.ToInt64()
							$styleInt = $styleInt -bor [WinAPI.SplashChrome]::WS_SYSMENU
							$styleInt = $styleInt -bor [WinAPI.SplashChrome]::WS_MINIMIZEBOX
							[void]([WinAPI.SplashChrome]::SetWindowLongPtr($hwnd, [WinAPI.SplashChrome]::GWL_STYLE, [IntPtr]::new($styleInt)))
							[void]([WinAPI.SplashChrome]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x27))
							& $writeSplashTrace ('Bootstrap splash source initialized: hwnd={0}' -f $hwnd)
						}
					}
					catch
					{
						$syncHash.ErrorType = $_.Exception.GetType().FullName
						$syncHash.ErrorMessage = $_.Exception.Message
						& $writeSplashTrace ('Bootstrap splash chrome setup failed: {0}' -f $_.Exception.Message)
					}
				})

				# Wire up minimize/close buttons and drag-to-move
				$btnMin = $splash.FindName('BtnMinimize')
				$btnCls = $splash.FindName('BtnClose')
				if ($btnMin)
				{
					$btnMin.Add_Click({ $splash.WindowState = [System.Windows.WindowState]::Minimized })
				}
				if ($btnCls)
				{
					$btnCls.Add_Click({
						$syncHash.UserClosed = $true
						$splash.Close()
						# Terminate the entire process when user explicitly closes the splash
						[System.Environment]::Exit(0)
					})
				}
				$splash.Add_MouseLeftButtonDown({ param($s,$e) $splash.DragMove() })

				# System-style right-click context menu for splash title area
				$splashMenu = New-Object System.Windows.Controls.ContextMenu
				$miMin = New-Object System.Windows.Controls.MenuItem
				$miMin.Header = 'Minimize'
				$miMin.Add_Click({ $splash.WindowState = [System.Windows.WindowState]::Minimized })
				$miCloseCtx = New-Object System.Windows.Controls.MenuItem
				$miCloseCtx.Header = 'Close'
				$miCloseCtx.InputGestureText = 'Alt+F4'
				$miCloseCtx.FontWeight = [System.Windows.FontWeights]::Bold
				$miCloseCtx.Add_Click({ $syncHash.UserClosed = $true; $splash.Close(); [System.Environment]::Exit(0) })
				$splashSep = New-Object System.Windows.Controls.Separator
				[void]$splashMenu.Items.Add($miMin)
				[void]$splashMenu.Items.Add($splashSep)
				[void]$splashMenu.Items.Add($miCloseCtx)
				$splash.ContextMenu = $splashMenu

					$syncHash.Window     = $splash
					$syncHash.Dispatcher = $splash.Dispatcher
					$syncHash.StatusText = $splash.FindName('StatusText')
					$syncHash.SubActionPanel = $splash.FindName('SubActionPanel')
					$syncHash.ProgressBar = $splash.FindName('ProgressBar')
					$syncHash.StepGlyphs = @{
						'updates'    = $splash.FindName('StepGlyph_updates')
						'system'     = $splash.FindName('StepGlyph_system')
						'winget'     = $splash.FindName('StepGlyph_winget')
						'chocolatey' = $splash.FindName('StepGlyph_chocolatey')
						'finalize'   = $splash.FindName('StepGlyph_finalize')
					}
					$syncHash.StepIdleDots = @{
						'updates'    = $splash.FindName('StepIdle_updates')
						'system'     = $splash.FindName('StepIdle_system')
						'winget'     = $splash.FindName('StepIdle_winget')
						'chocolatey' = $splash.FindName('StepIdle_chocolatey')
						'finalize'   = $splash.FindName('StepIdle_finalize')
					}
					$syncHash.StepPulseDots = @{
						'updates'    = $splash.FindName('StepPulse_updates')
						'system'     = $splash.FindName('StepPulse_system')
						'winget'     = $splash.FindName('StepPulse_winget')
						'chocolatey' = $splash.FindName('StepPulse_chocolatey')
						'finalize'   = $splash.FindName('StepPulse_finalize')
					}
					$syncHash.StepChecks = @{
						'updates'    = $splash.FindName('StepCheck_updates')
						'system'     = $splash.FindName('StepCheck_system')
						'winget'     = $splash.FindName('StepCheck_winget')
						'chocolatey' = $splash.FindName('StepCheck_chocolatey')
						'finalize'   = $splash.FindName('StepCheck_finalize')
					}
					$syncHash.StepLabels = @{
						'updates'    = $splash.FindName('StepLabel_updates')
						'system'     = $splash.FindName('StepLabel_system')
						'winget'     = $splash.FindName('StepLabel_winget')
						'chocolatey' = $splash.FindName('StepLabel_chocolatey')
						'finalize'   = $splash.FindName('StepLabel_finalize')
					}
					$syncHash.StepStates = @{
						'updates'    = 'pending'
						'system'     = 'pending'
						'winget'     = 'pending'
						'chocolatey' = 'pending'
						'finalize'   = 'pending'
					}
					$syncHash.SplashTheme = $SplashTheme
					$startUpdatesPulseAction = {
						param([string]$Source = 'unknown')
						if (-not $startUpdatesPulse) { return }
						if ([bool]$syncHash.StartUpdatesPulseApplied) { return }
						try
						{
							$stateApplied = $true
							$stepApplied = $false
							if ($bootstrapLoadingSplashStateCommand)
							{
								$stateApplied = [bool](& $bootstrapLoadingSplashStateCommand -Splash $syncHash -StatusText $splashLocCheckingForUpdates -Completed 0 -Total 5)
							}
							if ($bootstrapLoadingSplashStepCommand)
							{
								$stepApplied = [bool](& $bootstrapLoadingSplashStepCommand -Splash $syncHash -StepId 'updates' -Status 'in_progress' -SubAction '')
							}
							$syncHash.StartUpdatesPulseApplied = $stepApplied
							& $writeSplashTrace ('Bootstrap splash update pulse {0}: state={1} step={2}' -f $Source, $stateApplied, $stepApplied)
						}
						catch
						{
							$syncHash.ErrorType = $_.Exception.GetType().FullName
							$syncHash.ErrorMessage = $_.Exception.Message
							& $writeSplashTrace ('Bootstrap splash update pulse failed: {0}' -f $_.Exception.Message)
						}
					}.GetNewClosure()

					$splash.Add_Loaded({
						try
						{
							if ($splash.WindowState -eq [System.Windows.WindowState]::Minimized)
							{
								$splash.WindowState = [System.Windows.WindowState]::Normal
							}
							& $startUpdatesPulseAction 'Loaded'
							$syncHash.WasLoaded = $true
							& $writeSplashTrace 'Bootstrap splash loaded'
						}
						catch
						{
							$syncHash.ErrorType = $_.Exception.GetType().FullName
							$syncHash.ErrorMessage = $_.Exception.Message
							$syncHash.IsReady = $true
							$syncHash.IsAlive = $false
							& $writeSplashTrace ('Bootstrap splash load failed: {0}' -f $_.Exception.Message)
							try { $splash.Close() } catch { }
						}
					})

					$splash.Add_ContentRendered({
						try
						{
							$syncHash.WasShown = $true
							$syncHash.WasRendered = $true
							& $startUpdatesPulseAction 'ContentRendered'
							$syncHash.IsReady = $true
							& $writeSplashTrace 'Bootstrap splash content rendered'
						}
						catch
						{
							$syncHash.ErrorType = $_.Exception.GetType().FullName
							$syncHash.ErrorMessage = $_.Exception.Message
							$syncHash.IsReady = $true
							$syncHash.IsAlive = $false
							& $writeSplashTrace ('Bootstrap splash content render failed: {0}' -f $_.Exception.Message)
							try { $splash.Close() } catch { }
						}
					})

					$splash.Add_Activated({
						try { & $writeSplashTrace 'Bootstrap splash activated' } catch { }
					})

				$splash.Add_Closed({
					$syncHash.IsAlive = $false
					& $writeSplashTrace 'Bootstrap splash closed'
					$splash.Dispatcher.InvokeShutdown()
				})

				& $writeSplashTrace 'Bootstrap splash ShowDialog starting'
				$splash.ShowDialog() | Out-Null
			}
			catch
			{
				$syncHash.ErrorType = $_.Exception.GetType().FullName
				$syncHash.ErrorMessage = $_.Exception.Message
				$syncHash.IsReady = $true
				$syncHash.IsAlive = $false
				try
				{
					$tracePath = Join-Path ([System.IO.Path]::GetTempPath()) 'Baseline-launch-trace.txt'
					[System.IO.File]::AppendAllText($tracePath, ("{0:o} Bootstrap splash runspace failed: {1}`r`n" -f [DateTime]::UtcNow, $_.Exception.Message), [System.Text.Encoding]::UTF8)
				}
				catch { }
			}
		})

		Write-EnvironmentLaunchTrace 'Bootstrap splash helper BeginInvoke starting'
		$asyncResult = $ps.BeginInvoke()
		$deadline = [datetime]::Now.AddSeconds(10)
		while (-not $syncHash.IsReady -and [datetime]::Now -lt $deadline)
		{
			Start-Sleep -Milliseconds 50
		}
		Write-EnvironmentLaunchTrace ('Bootstrap splash helper wait complete: IsReady={0} IsAlive={1} WasLoaded={2} WasRendered={3} Error={4}' -f [bool]$syncHash.IsReady, [bool]$syncHash.IsAlive, [bool]$syncHash.WasLoaded, [bool]$syncHash.WasRendered, [string]$syncHash.ErrorMessage)

		if ((-not $syncHash.IsAlive) -or (-not $syncHash.WasRendered))
		{
			# Splash never became ready - clean up the background runspace.
			try
			{
				if (-not [string]::IsNullOrWhiteSpace([string]$syncHash.ErrorMessage))
				{
					Write-EnvironmentLaunchTrace ('Bootstrap splash failed before it became visible: {0}' -f [string]$syncHash.ErrorMessage)
				}
				else
				{
					Write-EnvironmentLaunchTrace 'Bootstrap splash failed before it became visible.'
				}
			}
			catch { }
			try { $ps.Stop(); $ps.Dispose() } catch { Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.ShowBootstrapLoadingSplash.CleanupPowerShell' }
			try { $runspace.Close(); $runspace.Dispose() } catch { Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.ShowBootstrapLoadingSplash.CleanupRunspace' }
			return $null
		}

		$syncHash._PowerShell  = $ps
		$syncHash._AsyncResult = $asyncResult
		$syncHash._Runspace    = $runspace

		Write-EnvironmentLaunchTrace ('Bootstrap splash helper returning live splash: IsAlive={0} WasRendered={1} WindowHandle={2}' -f [bool]$syncHash.IsAlive, [bool]$syncHash.WasRendered, [string]$syncHash.WindowHandle)
		return $syncHash
	}
	catch
	{
		Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.ShowBootstrapLoadingSplash'
		Write-EnvironmentLaunchTrace ('Bootstrap splash helper failed: {0}' -f $_.Exception.Message)
		try { if ($ps) { $ps.Stop(); $ps.Dispose() } } catch { Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.ShowBootstrapLoadingSplash.StopPowerShell' }
		try { if ($runspace) { $runspace.Close(); $runspace.Dispose() } } catch { Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.ShowBootstrapLoadingSplash.StopRunspace' }
		return $null
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineSplashProgressWidth.
#>

function Get-BaselineSplashProgressWidth
{
	<# .SYNOPSIS Returns the splash progress bar width in device-independent pixels. #>
	param(
		[Parameter(Mandatory = $true)]
		[object]
		$ProgressBar
	)

	$width = 0.0
	try
	{
		$width = [double]$ProgressBar.ActualWidth
	}
	catch
	{
		$width = 0.0
	}

	if ([double]::IsNaN($width) -or $width -le 0)
	{
		try
		{
			$width = [double]$ProgressBar.Width
		}
		catch
		{
			$width = 0.0
		}
	}

	if ([double]::IsNaN($width) -or $width -le 0)
	{
		$width = 330.0
	}

	return $width
}

<#
    .SYNOPSIS
    Internal function Initialize-BaselineProcessIdentity.
#>

function Initialize-BaselineProcessIdentity
{
	<# .SYNOPSIS Applies a Baseline app identity to the current process for shell chrome. #>
	[CmdletBinding()]
	param(
		[string]$AppUserModelId = 'sdmanson8.Baseline'
	)

	if ([string]::IsNullOrWhiteSpace($AppUserModelId))
	{
		return $false
	}

	try
	{
		if (-not ('WinAPI.BaselineShellIdentity' -as [type]))
		{
			Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinAPI
{
	public static class BaselineShellIdentity
	{
		[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
		public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
	}
}
"@ -ErrorAction Stop | Out-Null
		}

		$result = [WinAPI.BaselineShellIdentity]::SetCurrentProcessExplicitAppUserModelID($AppUserModelId)
		return ($result -ge 0)
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Format-BaselineDownloadStatus.
#>

function Format-BaselineDownloadStatus
{
	<# .SYNOPSIS Formats the update download status with percent, size, and transfer rate. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$VersionTag,

		[Parameter(Mandatory = $true)]
		[long]$BytesReceived,

		[long]$TotalBytes = 0,

		[double]$ElapsedSeconds = 0
	)

	$receivedMB = [Math]::Round(($BytesReceived / 1MB), 1)
	$speedMBps = if ($ElapsedSeconds -gt 0)
	{
		[Math]::Round((($BytesReceived / $ElapsedSeconds) / 1MB), 2)
	}
	else
	{
		0
	}

	if ($TotalBytes -gt 0)
	{
		$totalMB = [Math]::Round(($TotalBytes / 1MB), 1)
		$pct = [int]([Math]::Min(99, ($BytesReceived * 100 / $TotalBytes)))
		return (Get-BaselineLocalizedString -Key 'Bootstrap_DownloadingUpdate' -Fallback 'Downloading update {0}... {1}% ({2} / {3} MB at {4} MB/s)' -FormatArgs @($VersionTag, $pct, $receivedMB, $totalMB, $speedMBps))
	}

	return (Get-BaselineLocalizedString -Key 'Bootstrap_DownloadingUpdateNoTotal' -Fallback 'Downloading update {0}... {1} MB at {2} MB/s' -FormatArgs @($VersionTag, $receivedMB, $speedMBps))
}

<#
    .SYNOPSIS
    Internal function Set-BootstrapLoadingSplashState.
#>

function Set-BootstrapLoadingSplashState
{
	<# .SYNOPSIS Updates the bootstrap loading splash text and progress bar. #>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[object]
		$Splash = $Global:LoadingSplash,

		[Parameter(Mandatory = $false)]
		[string]
		$StatusText = $null,

		[Parameter(Mandatory = $false)]
		[int]
		$Completed = 0,

		[Parameter(Mandatory = $false)]
		[int]
		$Total = 0,

		[Parameter(Mandatory = $false)]
		[switch]
		$Indeterminate,

		[Parameter(Mandatory = $false)]
		[switch]
		$HideProgressBar
	)

	if (-not $Splash)
	{
		return $false
	}

	$window = $null
	$dispatcher = $null
	$statusControl = $null
	$subActionPanel = $null
	$progressBar = $null
	$checklistProgressActive = $false

	if ($Splash -is [hashtable])
	{
		if ($Splash.ContainsKey('Window')) { $window = $Splash.Window }
		if ($Splash.ContainsKey('Dispatcher')) { $dispatcher = $Splash.Dispatcher }
		if ($Splash.ContainsKey('StatusText')) { $statusControl = $Splash.StatusText }
		if ($Splash.ContainsKey('SubActionPanel')) { $subActionPanel = $Splash.SubActionPanel }
		if ($Splash.ContainsKey('ProgressBar')) { $progressBar = $Splash.ProgressBar }
		if ($Splash.ContainsKey('ChecklistProgressActive')) { $checklistProgressActive = [bool]$Splash.ChecklistProgressActive }
	}
	else
	{
		$window = $Splash
		if ($window -and $window.PSObject.Properties['Dispatcher'])
		{
			$dispatcher = $window.Dispatcher
		}
	}

	if (-not $window -or -not $dispatcher -or $dispatcher.HasShutdownStarted)
	{
		return $false
	}

	try
	{
		$dispatcher.Invoke([System.Action]{
			try
			{
				if (-not $statusControl -and $window)
				{
					$statusControl = $window.FindName('StatusText')
				}
				if (-not $subActionPanel -and $window)
				{
					$subActionPanel = $window.FindName('SubActionPanel')
				}
				if (-not $progressBar -and $window)
				{
					$progressBar = $window.FindName('ProgressBar')
				}

				$hasStatusText = -not [string]::IsNullOrWhiteSpace([string]$StatusText)
				$showStatusLine = $hasStatusText -or [bool]$Indeterminate

				if ($statusControl -and $hasStatusText)
				{
					$statusControl.Text = [string]$StatusText
				}

				if ($showStatusLine)
				{
					if ($subActionPanel)
					{
						$subActionPanel.Visibility = [System.Windows.Visibility]::Visible
					}
					elseif ($statusControl)
					{
						$statusControl.Visibility = [System.Windows.Visibility]::Visible
					}
				}

				if ($progressBar)
				{
					if ($HideProgressBar)
					{
						$progressBar.Visibility = [System.Windows.Visibility]::Collapsed
						if ($progressBar.PSObject.Properties['IsIndeterminate']) { $progressBar.IsIndeterminate = $false }
						if ($progressBar.PSObject.Properties['Value']) { $progressBar.Value = 0 }
						if ($progressBar.PSObject.Properties['Maximum']) { $progressBar.Maximum = 1 }
					}
					else
					{
						$showProgress = [bool]$Indeterminate -or ($Total -gt 0)
						$progressBar.Visibility = if ($showProgress) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

						if (-not $showProgress)
						{
							if ($progressBar.PSObject.Properties['IsIndeterminate']) { $progressBar.IsIndeterminate = $false }
						}
						elseif ($Indeterminate -or $Total -le 0)
						{
							if ($progressBar.PSObject.Properties['IsIndeterminate']) { $progressBar.IsIndeterminate = -not $checklistProgressActive }
						}
						else
						{
							$safeTotal = [Math]::Max(1, $Total)
							$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
							$barWidth = Get-BaselineSplashProgressWidth -ProgressBar $progressBar
							if ($progressBar.PSObject.Properties['IsIndeterminate']) { $progressBar.IsIndeterminate = $false }
							if ($progressBar.PSObject.Properties['Maximum']) { $progressBar.Maximum = $barWidth }
							if ($progressBar.PSObject.Properties['Value']) { $progressBar.Value = [Math]::Round((($safeCompleted / $safeTotal) * $barWidth), 3) }
						}
					}
				}
			}
			catch
			{
				Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.SetBootstrapLoadingSplashState.DispatcherUpdate'
			}
		})

		return $true
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Set-BootstrapLoadingSplashStep.
#>

function Set-BootstrapLoadingSplashStep
{
	<# .SYNOPSIS Advances a step in the bootstrap splash checklist (pending/in_progress/completed) and optionally sets its sub-action text. #>
	[CmdletBinding()]
	[OutputType([bool])]
	param(
		[Parameter(Mandatory = $false)]
		[object]
		$Splash = $Global:LoadingSplash,

		[Parameter(Mandatory = $true)]
		[ValidateSet('updates','system','winget','chocolatey','finalize')]
		[string]
		$StepId,

		[Parameter(Mandatory = $true)]
		[ValidateSet('pending','in_progress','completed')]
		[string]
		$Status,

		[Parameter(Mandatory = $false)]
		[AllowEmptyString()]
		[AllowNull()]
		[string]
		$SubAction
	)

	if (-not $Splash) { return $false }

	$window = $null
	$dispatcher = $null
	$stepGlyphs = $null
	$stepIdleDots = $null
	$stepPulseDots = $null
	$stepChecks = $null
	$stepLabels = $null
	$stepStates = $null
	$statusControl = $null
	$subActionPanel = $null
	$progressBar = $null
	$theme = $null
	$stepOrder = @('updates','system','winget','chocolatey','finalize')

	if ($Splash -is [hashtable])
	{
		if ($Splash.ContainsKey('Window'))            { $window         = $Splash.Window }
		if ($Splash.ContainsKey('Dispatcher'))        { $dispatcher     = $Splash.Dispatcher }
		if ($Splash.ContainsKey('StepGlyphs'))        { $stepGlyphs     = $Splash.StepGlyphs }
		if ($Splash.ContainsKey('StepIdleDots'))      { $stepIdleDots   = $Splash.StepIdleDots }
		if ($Splash.ContainsKey('StepPulseDots'))     { $stepPulseDots  = $Splash.StepPulseDots }
		if ($Splash.ContainsKey('StepChecks'))        { $stepChecks     = $Splash.StepChecks }
		if ($Splash.ContainsKey('StepLabels'))        { $stepLabels     = $Splash.StepLabels }
		if ($Splash.ContainsKey('StepStates'))        { $stepStates     = $Splash.StepStates }
		if ($Splash.ContainsKey('StatusText'))        { $statusControl  = $Splash.StatusText }
		if ($Splash.ContainsKey('SubActionPanel'))    { $subActionPanel = $Splash.SubActionPanel }
		if ($Splash.ContainsKey('ProgressBar'))       { $progressBar    = $Splash.ProgressBar }
		if ($Splash.ContainsKey('SplashTheme'))       { $theme          = $Splash.SplashTheme }
		if ($Splash.ContainsKey('StepOrder') -and $Splash.StepOrder) { $stepOrder = @($Splash.StepOrder) }
	}

	if (-not $window -or -not $dispatcher -or $dispatcher.HasShutdownStarted) { return $false }
	if (-not $stepGlyphs -or -not $stepLabels -or -not $stepStates) { return $false }

	$hasSubActionArg = $PSBoundParameters.ContainsKey('SubAction')
	if ($Splash -is [hashtable])
	{
		if ($Status -eq 'in_progress')
		{
			$Splash.ChecklistProgressActive = $true
		}
		elseif ($StepId -eq 'finalize' -and $Status -eq 'completed')
		{
			$Splash.ChecklistProgressActive = $false
			$Splash.CompletionAnimationDeadlineUtc = [datetime]::UtcNow.AddMilliseconds(360)
		}
	}

	try
	{
		$dispatcher.Invoke([System.Action]{
			try
			{
				$mutedBrush   = $null
				$subBrush     = $null
				$primaryBrush = $null
				$accentBrush  = $null
				if ($theme)
				{
					try { $mutedBrush   = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Muted))   } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.BrushConvert.Muted' }
					try { $subBrush     = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Sub))     } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.BrushConvert.Sub' }
					try { $primaryBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Primary)) } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.BrushConvert.Primary' }
					try { $accentBrush  = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($theme.Accent))  } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.BrushConvert.Accent' }
				}

				$opacityProp   = [System.Windows.UIElement]::OpacityProperty
				$snapAndKeep   = [System.Windows.Media.Animation.HandoffBehavior]::SnapshotAndReplace
				$holdEnd       = [System.Windows.Media.Animation.FillBehavior]::HoldEnd

				$animateOpacity = {
					param($element, $to, $durationMs)
					if (-not $element) { return }
					try
					{
						$a = New-Object System.Windows.Media.Animation.DoubleAnimation
						$a.To       = [double]$to
						$a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds([int]$durationMs))
						$e          = New-Object System.Windows.Media.Animation.QuadraticEase
						$e.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
						$a.EasingFunction = $e
						$a.FillBehavior   = $holdEnd
						$element.BeginAnimation($opacityProp, $a, $snapAndKeep)
					}
					catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.OpacityAnimation.Begin' }
				}

				$scaleXProp = [System.Windows.Media.ScaleTransform]::ScaleXProperty
				$scaleYProp = [System.Windows.Media.ScaleTransform]::ScaleYProperty
				$visVisible = [System.Windows.Visibility]::Visible
				$visCollapsed = [System.Windows.Visibility]::Collapsed

				$startPulseDot = {
					param($pulseEllipse)
					if (-not $pulseEllipse) { return }
					try
					{
						& $stopPulseDot $pulseEllipse
						$rt = $pulseEllipse.RenderTransform
						if ($rt -is [System.Windows.Media.ScaleTransform])
						{
							$sxa = New-Object System.Windows.Media.Animation.DoubleAnimation
							$sxa.From = 1.0; $sxa.To = 1.4
							$sxa.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(360))
							$sxa.AutoReverse = $true
							$sxa.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
							$rt.BeginAnimation($scaleXProp, $sxa, $snapAndKeep)

							$sya = New-Object System.Windows.Media.Animation.DoubleAnimation
							$sya.From = 1.0; $sya.To = 1.4
							$sya.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(360))
							$sya.AutoReverse = $true
							$sya.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
							$rt.BeginAnimation($scaleYProp, $sya, $snapAndKeep)
						}
						$oa = New-Object System.Windows.Media.Animation.DoubleAnimation
						$oa.From = 0.6; $oa.To = 1.0
						$oa.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(360))
						$oa.AutoReverse = $true
						$oa.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
						$pulseEllipse.BeginAnimation($opacityProp, $oa, $snapAndKeep)
					}
					catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.PulseDot.Start' }
				}

				$stopPulseDot = {
					param($pulseEllipse)
					if (-not $pulseEllipse) { return }
					try
					{
						$rt = $pulseEllipse.RenderTransform
						if ($rt -is [System.Windows.Media.ScaleTransform])
						{
							$rt.BeginAnimation($scaleXProp, $null)
							$rt.BeginAnimation($scaleYProp, $null)
							$rt.ScaleX = 1.0
							$rt.ScaleY = 1.0
						}
						$pulseEllipse.BeginAnimation($opacityProp, $null)
						$pulseEllipse.Opacity = 0.6
					}
					catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.PulseDot.Stop' }
				}

				$stopInactivePulseDots = {
					param($activeStepId)
					if (-not $stepPulseDots) { return }
					foreach ($pulseId in @($stepPulseDots.Keys))
					{
						if ($pulseId -eq $activeStepId) { continue }
						$pulseDot = $stepPulseDots[$pulseId]
						if (-not $pulseDot) { continue }
						& $stopPulseDot $pulseDot
						$pulseDot.Visibility = $visCollapsed
					}
				}

				$applyRowState = {
					param($id, $state)
					$g     = $stepGlyphs[$id]
					$idle  = if ($stepIdleDots)  { $stepIdleDots[$id] }  else { $null }
					$pulse = if ($stepPulseDots) { $stepPulseDots[$id] } else { $null }
					$check = if ($stepChecks)    { $stepChecks[$id] }    else { $null }
					$l     = $stepLabels[$id]

					switch ($state)
					{
						'pending'
						{
							if ($pulse)
							{
								& $stopPulseDot $pulse
								$pulse.Visibility = $visCollapsed
							}
							if ($check) { $check.Visibility = $visCollapsed }
							if ($idle)
							{
								if ($mutedBrush) { $idle.Stroke = $mutedBrush }
								$idle.Visibility = $visVisible
							}
							if ($g) { & $animateOpacity $g 1.0 220 }
						}
						'in_progress'
						{
							if ($idle)  { $idle.Visibility  = $visCollapsed }
							if ($check) { $check.Visibility = $visCollapsed }
							if ($pulse)
							{
								if ($accentBrush) { $pulse.Fill = $accentBrush }
								$pulse.Visibility = $visVisible
								& $startPulseDot $pulse
							}
							if ($g) { & $animateOpacity $g 1.0 220 }
						}
						'completed'
						{
							if ($pulse)
							{
								& $stopPulseDot $pulse
								$pulse.Visibility = $visCollapsed
							}
							if ($idle) { $idle.Visibility = $visCollapsed }
							if ($check)
							{
								if ($accentBrush) { $check.Foreground = $accentBrush }
								$check.Visibility = $visVisible
							}
							if ($g) { & $animateOpacity $g 0.85 280 }
						}
					}

					if ($l)
					{
						switch ($state)
						{
							'pending'
							{
								if ($mutedBrush) { $l.Foreground = $mutedBrush }
								& $animateOpacity $l 1.0 200
							}
							'in_progress'
							{
								if ($primaryBrush) { $l.Foreground = $primaryBrush }
								& $animateOpacity $l 1.0 200
							}
							'completed'
							{
								if ($subBrush) { $l.Foreground = $subBrush }
								& $animateOpacity $l 0.85 280
							}
						}
					}
				}

				# Cascade earlier steps to completed when a later step starts. This
				# keeps the checklist coherent even if a caller skips a transition.
				if ($Status -in @('in_progress','completed'))
				{
					$foundIdx = [Array]::IndexOf($stepOrder, $StepId)
					if ($foundIdx -gt 0)
					{
						for ($i = 0; $i -lt $foundIdx; $i++)
						{
							$earlierId = $stepOrder[$i]
							if ($stepStates[$earlierId] -ne 'completed')
							{
								$stepStates[$earlierId] = 'completed'
								& $applyRowState $earlierId 'completed'
							}
						}
					}
				}

				$activePulseStepId = if ($Status -eq 'in_progress') { $StepId } else { $null }
				& $stopInactivePulseDots $activePulseStepId

				$stepStates[$StepId] = $Status
				& $applyRowState $StepId $Status

				$completedCount = 0
				foreach ($id in $stepOrder)
				{
					if ($stepStates[$id] -eq 'completed') { $completedCount++ }
				}

				# Snap on step completion; while the final handoff is active, keep
				# the bar moving slowly toward a reserved near-complete ceiling
				# until the foreground GUI tab signals readiness.
				if ($progressBar)
				{
					try
					{
						if ($progressBar.PSObject.Properties['IsIndeterminate']) { $progressBar.IsIndeterminate = $false }
						$barWidth = Get-BaselineSplashProgressWidth -ProgressBar $progressBar
						$stepCount = [Math]::Max(1, [double]$stepOrder.Count)
						$current = [double]$progressBar.Value
						if ($progressBar.PSObject.Properties['Maximum']) { $progressBar.Maximum = $barWidth }
						if ($Status -eq 'in_progress')
						{
							$activeIdx = [Array]::IndexOf($stepOrder, $StepId)
							if ($activeIdx -lt 0) { $activeIdx = $completedCount }
							$lastStepIndex = [Math]::Max(0, ([int]$stepOrder.Count) - 1)
							$isFinalHandoffStep = ([string]$StepId -eq [string]$stepOrder[$lastStepIndex])
							$snapTo = ([double]$activeIdx / $stepCount) * $barWidth
							$fillFrom = $snapTo
							$fillTo = (([double]$activeIdx + 0.35) / $stepCount) * $barWidth
							$fillDurationMs = 2200
							$fillEase = New-Object System.Windows.Media.Animation.CubicEase
							$fillEase.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
							if ($isFinalHandoffStep)
							{
								$handoffCeiling = $barWidth * 0.97
								if ($current -gt $snapTo -and $current -lt $handoffCeiling)
								{
									$fillFrom = $current
								}
								$fillTo = $handoffCeiling
								$fillDurationMs = 24000
								$fillEase = $null
							}

							$fill = New-Object System.Windows.Media.Animation.DoubleAnimation
							$fill.From = $fillFrom
							$fill.To   = $fillTo
							$fill.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($fillDurationMs))
							if ($fillEase) { $fill.EasingFunction = $fillEase }
							$fill.FillBehavior = $holdEnd
							# Clear any prior animation on Value before starting the step-owned fill.
							$progressBar.BeginAnimation([System.Windows.Controls.ProgressBar]::ValueProperty, $null)
							if ($progressBar.PSObject.Properties['Value']) { $progressBar.Value = $fillFrom }
							$progressBar.BeginAnimation([System.Windows.Controls.ProgressBar]::ValueProperty, $fill, $snapAndKeep)
						}
						else
						{
							$anim = New-Object System.Windows.Media.Animation.DoubleAnimation
							$anim.From = $current
							$anim.To   = ([double]$completedCount / $stepCount) * $barWidth
							$anim.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(320))
							$ease = New-Object System.Windows.Media.Animation.QuadraticEase
							$ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
							$anim.EasingFunction = $ease
							$anim.FillBehavior = $holdEnd
							$progressBar.BeginAnimation([System.Windows.Controls.ProgressBar]::ValueProperty, $anim, $snapAndKeep)
						}
					}
					catch
					{
						try
						{
							$barWidth = Get-BaselineSplashProgressWidth -ProgressBar $progressBar
							$stepCount = [Math]::Max(1, [double]$stepOrder.Count)
							$progressBar.Value = ([double]$completedCount / $stepCount) * $barWidth
						}
						catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.Splash.ProgressBar.SetValueFallback' }
					}
				}

				# Sub-action visibility: panel toggles, not just the inner StatusText.
				if ($hasSubActionArg)
				{
					if ([string]::IsNullOrWhiteSpace([string]$SubAction))
					{
						if ($statusControl) { $statusControl.Text = '' }
						if ($subActionPanel)
						{
							$subActionPanel.Visibility = [System.Windows.Visibility]::Collapsed
						}
						elseif ($statusControl)
						{
							$statusControl.Visibility = [System.Windows.Visibility]::Collapsed
						}
					}
					else
					{
						if ($statusControl) { $statusControl.Text = [string]$SubAction }
						if ($subActionPanel)
						{
							$subActionPanel.Visibility = [System.Windows.Visibility]::Visible
						}
						elseif ($statusControl)
						{
							$statusControl.Visibility = [System.Windows.Visibility]::Visible
						}
					}
				}
				elseif ($Status -eq 'completed')
				{
					if ($statusControl) { $statusControl.Text = '' }
					if ($subActionPanel)
					{
						$subActionPanel.Visibility = [System.Windows.Visibility]::Collapsed
					}
					elseif ($statusControl)
					{
						$statusControl.Visibility = [System.Windows.Visibility]::Collapsed
					}
				}

				# Finish moment: when the last step lands as completed, brighten the
				# whole list back to full opacity for a beat of visual closure before
				# the splash window is dismissed.
				if ($StepId -eq 'finalize' -and $Status -eq 'completed')
				{
					foreach ($id in $stepOrder)
					{
						$gFin = $stepGlyphs[$id]
						$lFin = $stepLabels[$id]
						if ($gFin) { & $animateOpacity $gFin 1.0 350 }
						if ($lFin) { & $animateOpacity $lFin 1.0 350 }
					}
				}
			}
			catch
			{
				if ($Splash -is [hashtable])
				{
					$Splash.ErrorType = $_.Exception.GetType().FullName
					$Splash.ErrorMessage = $_.Exception.Message
				}
				try { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.SetBootstrapLoadingSplashStep.DispatcherUpdate' } catch { }
				throw
			}
		})

		return $true
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Close-LoadingSplashWindow.
#>

function Close-LoadingSplashWindow
{
	<# .SYNOPSIS Closes a splash window and optionally disposes background resources. #>
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $false)]
		[object]
		$Splash,

		[Parameter(Mandatory = $false)]
		[switch]
		$DisposeResources,

		[Parameter(Mandatory = $false)]
		[int]
		$CloseTimeoutMilliseconds = 2000
	)

	if (-not $Splash) { return $false }

	$closeRequested = $false

	try
	{
		if ($Splash -is [hashtable])
		{
			if ($Splash.IsAlive -and $Splash.Dispatcher -and (-not $Splash.Dispatcher.HasShutdownStarted))
			{
				$Splash.Dispatcher.Invoke([System.Action]{
					if ($Splash.Window)
					{
						try { $Splash.Window.Hide() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.WindowHide' }
						try { $Splash.Window.Close() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.WindowClose' }
					}
					$Splash.IsAlive = $false
				})
				$closeRequested = $true
			}
		}
		elseif ($Splash.Dispatcher -and (-not $Splash.Dispatcher.HasShutdownStarted))
		{
			$Splash.Dispatcher.Invoke([System.Action]{
				try { $Splash.Hide() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.Hide' }
				try { $Splash.Close() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.Close' }
			})
			$closeRequested = $true
		}
	}
	catch
	{
		Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.DispatcherInvoke'
	}

	if ($DisposeResources -and $Splash -is [hashtable])
	{
		$closeDeadline = [datetime]::UtcNow.AddMilliseconds([Math]::Max($CloseTimeoutMilliseconds, 0))
		while ($Splash.IsAlive -and [datetime]::UtcNow -lt $closeDeadline)
		{
			Start-Sleep -Milliseconds 50
		}

		if ($Splash.IsAlive -and $Splash.Dispatcher -and (-not $Splash.Dispatcher.HasShutdownStarted))
		{
			try { $Splash.Dispatcher.InvokeShutdown() } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.DispatcherInvokeShutdown' }
		}

		try
		{
			if ($Splash._PowerShell -and $Splash._AsyncResult)
			{
				$Splash._PowerShell.EndInvoke($Splash._AsyncResult)
			}
		}
		catch
		{
			Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.EndInvoke'
		}

		try { if ($Splash._PowerShell) { $Splash._PowerShell.Dispose() } } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.PowerShellDispose' }
		try { if ($Splash._Runspace) { $Splash._Runspace.Close(); $Splash._Runspace.Dispose() } } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.CloseLoadingSplashWindow.RunspaceDispose' }
	}

	return $closeRequested
}

<#
    .SYNOPSIS
    Internal function Compare-BaselineReleaseVersions.
#>

function Compare-BaselineReleaseVersions
{
	<# .SYNOPSIS Compares two Baseline release tags using semantic-version precedence. #>
	param(
		[AllowNull()]
		[string]$LeftVersion,

		[AllowNull()]
		[string]$RightVersion
	)

	$parseVersionInfo = {
		param([AllowNull()][string]$VersionText)

		if ([string]::IsNullOrWhiteSpace([string]$VersionText))
		{
			return $null
		}

		$originalText = [string]$VersionText
		$trimmedText = $originalText.Trim()
		$coreText = $trimmedText.Split('+')[0].Trim()
		$match = [regex]::Match($coreText, '\d+(?:\.\d+){1,3}')
		if (-not $match.Success)
		{
			return [pscustomobject]@{
				OriginalText      = $trimmedText
				ComparableText    = $coreText
				Parsed            = $false
				CoreVersion       = $null
				PrereleaseLabel   = $null
				PrereleaseTokens  = @()
				IsPrerelease      = $false
			}
		}

		$parts = $match.Value.Split('.')
		while ($parts.Count -lt 4)
		{
			$parts += '0'
		}
		if ($parts.Count -gt 4)
		{
			$parts = $parts[0..3]
		}

		$coreVersion = $null
		try
		{
			$coreVersion = [System.Version]($parts -join '.')
		}
		catch
		{
			return [pscustomobject]@{
				OriginalText      = $trimmedText
				ComparableText    = $coreText
				Parsed            = $false
				CoreVersion       = $null
				PrereleaseLabel   = $null
				PrereleaseTokens  = @()
				IsPrerelease      = $false
			}
		}

		$prereleaseLabel = $coreText.Substring($match.Index + $match.Length).Trim()
		if ($prereleaseLabel -match '^\((.+)\)$')
		{
			$prereleaseLabel = [string]$Matches[1]
		}
		$prereleaseLabel = [regex]::Replace($prereleaseLabel, '^[\s\-\._\(\[\{]+', '')
		$prereleaseLabel = [regex]::Replace($prereleaseLabel, '[\s\)\]\}]+$', '')
		if ([string]::IsNullOrWhiteSpace([string]$prereleaseLabel))
		{
			$prereleaseLabel = $null
		}

		$prereleaseTokens = @()
		if ($prereleaseLabel)
		{
			$tokenMatches = [regex]::Matches($prereleaseLabel.ToLowerInvariant(), '[0-9]+|[A-Za-z]+')
			if ($tokenMatches.Count -gt 0)
			{
				$prereleaseTokens = @($tokenMatches | ForEach-Object { [string]$_.Value })
			}
			else
			{
				$prereleaseTokens = @([string]$prereleaseLabel.ToLowerInvariant())
			}
		}

		return [pscustomobject]@{
			OriginalText      = $trimmedText
			ComparableText    = $coreText
			Parsed            = $true
			CoreVersion       = $coreVersion
			PrereleaseLabel   = $prereleaseLabel
			PrereleaseTokens  = $prereleaseTokens
			IsPrerelease      = (-not [string]::IsNullOrWhiteSpace([string]$prereleaseLabel))
		}
	}

	$leftInfo = & $parseVersionInfo $LeftVersion
	$rightInfo = & $parseVersionInfo $RightVersion

	if ($null -eq $leftInfo -and $null -eq $rightInfo)
	{
		return 0
	}
	if ($null -eq $leftInfo)
	{
		return -1
	}
	if ($null -eq $rightInfo)
	{
		return 1
	}

	if (-not $leftInfo.Parsed -and -not $rightInfo.Parsed)
	{
		return [Math]::Sign([string]::Compare($leftInfo.OriginalText, $rightInfo.OriginalText, [System.StringComparison]::OrdinalIgnoreCase))
	}
	if (-not $leftInfo.Parsed)
	{
		return -1
	}
	if (-not $rightInfo.Parsed)
	{
		return 1
	}

	$coreComparison = $leftInfo.CoreVersion.CompareTo($rightInfo.CoreVersion)
	if ($coreComparison -ne 0)
	{
		return [Math]::Sign($coreComparison)
	}

	if ($leftInfo.IsPrerelease -and -not $rightInfo.IsPrerelease)
	{
		return -1
	}
	if (-not $leftInfo.IsPrerelease -and $rightInfo.IsPrerelease)
	{
		return 1
	}
	if (-not $leftInfo.IsPrerelease -and -not $rightInfo.IsPrerelease)
	{
		return 0
	}

	$maxTokenCount = [Math]::Max($leftInfo.PrereleaseTokens.Count, $rightInfo.PrereleaseTokens.Count)
	for ($index = 0; $index -lt $maxTokenCount; $index++)
	{
		if ($index -ge $leftInfo.PrereleaseTokens.Count)
		{
			return -1
		}
		if ($index -ge $rightInfo.PrereleaseTokens.Count)
		{
			return 1
		}

		$leftToken = [string]$leftInfo.PrereleaseTokens[$index]
		$rightToken = [string]$rightInfo.PrereleaseTokens[$index]
		$leftTokenIsNumber = ($leftToken -match '^\d+$')
		$rightTokenIsNumber = ($rightToken -match '^\d+$')

		if ($leftTokenIsNumber -and $rightTokenIsNumber)
		{
			$leftNumber = [int64]$leftToken
			$rightNumber = [int64]$rightToken
			if ($leftNumber -ne $rightNumber)
			{
				return [Math]::Sign($leftNumber.CompareTo($rightNumber))
			}
			continue
		}
		if ($leftTokenIsNumber -and -not $rightTokenIsNumber)
		{
			return -1
		}
		if (-not $leftTokenIsNumber -and $rightTokenIsNumber)
		{
			return 1
		}

		$tokenComparison = [string]::Compare($leftToken, $rightToken, [System.StringComparison]::OrdinalIgnoreCase)
		if ($tokenComparison -ne 0)
		{
			return [Math]::Sign($tokenComparison)
		}
	}

	return 0
}

<#
    .SYNOPSIS
    Internal function Get-BaselineLatestReleaseEntry.
#>

function Get-BaselineLatestReleaseEntry
{
	<# .SYNOPSIS Selects the highest Baseline GitHub release from a release list. #>
	param(
		[AllowNull()]
		[object[]]$Releases
	)

	$bestRelease = $null
	$bestPublishedAt = [DateTimeOffset]::MinValue

	foreach ($release in @($Releases))
	{
		if ($null -eq $release)
		{
			continue
		}

		$isDraft = $false
		try
		{
			$isDraft = [bool]$release.draft
		}
		catch
		{
			$isDraft = $false
		}
		if ($isDraft)
		{
			continue
		}

		$candidateTag = [string]$release.tag_name
		if ([string]::IsNullOrWhiteSpace([string]$candidateTag))
		{
			continue
		}

		$candidatePublishedAt = [DateTimeOffset]::MinValue
		foreach ($propertyName in @('published_at', 'created_at'))
		{
			$rawPublishedAt = $null
			try
			{
				if ($release.PSObject.Properties[$propertyName])
				{
					$rawPublishedAt = [string]$release.$propertyName
				}
			}
			catch
			{
				$rawPublishedAt = $null
			}

			if ([string]::IsNullOrWhiteSpace([string]$rawPublishedAt))
			{
				continue
			}

			try
			{
				$candidatePublishedAt = [DateTimeOffset]::Parse($rawPublishedAt, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
				break
			}
			catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.GetBaselineLatestReleaseEntry.ParsePublishedAt' }
		}

		if ($null -eq $bestRelease)
		{
			$bestRelease = $release
			$bestPublishedAt = $candidatePublishedAt
			continue
		}

		$comparison = Compare-BaselineReleaseVersions -LeftVersion $candidateTag -RightVersion ([string]$bestRelease.tag_name)
		if ($comparison -gt 0 -or ($comparison -eq 0 -and $candidatePublishedAt -gt $bestPublishedAt))
		{
			$bestRelease = $release
			$bestPublishedAt = $candidatePublishedAt
		}
	}

	return $bestRelease
}

<#
    .SYNOPSIS
    Internal function Invoke-BaselineAutoUpdate.
#>

function Get-BaselineAutoUpdateThrottlePath
{
	<#
	.SYNOPSIS
	Returns the per-user state file used to throttle automatic startup
	update checks.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[string]$LocalAppData = ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData))
	)

	if ([string]::IsNullOrWhiteSpace($LocalAppData))
	{
		throw 'LocalApplicationData is not available; cannot persist the Baseline auto-update throttle state.'
	}

	return (Join-Path (Join-Path (Join-Path $LocalAppData 'Baseline') 'UserState') 'auto-update-check.json')
}

function Get-BaselineAutoUpdateThrottleDecision
{
	<#
	.SYNOPSIS
	Determines whether the startup auto-update check is eligible to run.
	#>
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[datetime]$NowUtc = [DateTime]::UtcNow,

		[int]$MinimumIntervalHours = 4
	)

	$minimumInterval = [TimeSpan]::FromHours([Math]::Max(1, [int]$MinimumIntervalHours))
	if (-not (Test-Path -LiteralPath $Path))
	{
		return [pscustomobject]@{
			ShouldCheck = $true
			LastCheckedUtc = $null
			NextEligibleUtc = $NowUtc
			Reason = 'No previous auto-update check was recorded.'
		}
	}

	try
	{
		$raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
		$state = ConvertFrom-BaselineJson -InputObject $raw
		$lastCheckedRaw = if ($state -and $state.PSObject.Properties['LastCheckedUtc']) { [string]$state.LastCheckedUtc } else { '' }
		$lastCheckedUtc = [datetime]::MinValue
		if ([string]::IsNullOrWhiteSpace($lastCheckedRaw) -or -not [datetime]::TryParse($lastCheckedRaw, [ref]$lastCheckedUtc))
		{
			throw 'LastCheckedUtc is missing or invalid.'
		}

		$lastCheckedUtc = $lastCheckedUtc.ToUniversalTime()
		$nextEligibleUtc = $lastCheckedUtc.Add($minimumInterval)
		return [pscustomobject]@{
			ShouldCheck = ($NowUtc.ToUniversalTime() -ge $nextEligibleUtc)
			LastCheckedUtc = $lastCheckedUtc
			NextEligibleUtc = $nextEligibleUtc
			Reason = if ($NowUtc.ToUniversalTime() -ge $nextEligibleUtc) { 'Auto-update throttle interval elapsed.' } else { 'Auto-update check was already performed inside the throttle interval.' }
		}
	}
	catch
	{
		return [pscustomobject]@{
			ShouldCheck = $true
			LastCheckedUtc = $null
			NextEligibleUtc = $NowUtc
			Reason = 'Auto-update throttle state could not be read.'
		}
	}
}

function Set-BaselineAutoUpdateThrottleTimestamp
{
	<#
	.SYNOPSIS
	Records that the startup auto-update check was attempted.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[datetime]$NowUtc = [DateTime]::UtcNow
	)

	$directory = Split-Path -Path $Path -Parent
	if (-not (Test-Path -LiteralPath $directory))
	{
		$null = New-Item -Path $directory -ItemType Directory -Force
	}

	$payload = [pscustomobject]@{
		Schema = 'Baseline.AutoUpdateCheck'
		SchemaVersion = 1
		LastCheckedUtc = $NowUtc.ToUniversalTime().ToString('o')
		MinimumIntervalHours = 4
	}
	[System.IO.File]::WriteAllText($Path, ($payload | ConvertTo-Json -Depth 4), [System.Text.Encoding]::UTF8)
}

function Invoke-BaselineAutoUpdate
{
	<#
	.SYNOPSIS
	Checks GitHub for a newer Baseline release zip and, if found, downloads it
	using the existing splash progress bar then relaunches the updated exe.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[object]$Splash = $Global:LoadingSplash,

		[Parameter(Mandatory = $false)]
		[string]$CurrentVersion = '0.0.0'
	)

	# Skip if launched by the installer or already updated this session
	if ($env:BASELINE_INSTALLER_MODE -eq '1') { return }
	if ($env:BASELINE_SKIP_UPDATE    -eq '1') { return }
	if ($env:BASELINE_EMBEDDED_HOST -ne '1') { return }
	$exePath = [string]$env:BASELINE_LAUNCHER_PATH
	if ([string]::IsNullOrWhiteSpace($exePath) -or -not [System.IO.Path]::IsPathRooted($exePath))
	{
		return
	}

	# If we couldn't determine our own version, refuse to auto-update. Without a
	# trustworthy current version every published release looks "newer" and we
	# would silently downgrade the user.
	if ([string]::IsNullOrWhiteSpace([string]$CurrentVersion) -or $CurrentVersion -eq '0.0.0')
	{
		LogWarning ('Skipping auto-update check: current Baseline version could not be determined (reported: "{0}"). Refusing to compare against GitHub releases to avoid downgrading.' -f $CurrentVersion)
		return
	}

	try
	{
		$throttlePath = Get-BaselineAutoUpdateThrottlePath
		$throttleDecision = Get-BaselineAutoUpdateThrottleDecision -Path $throttlePath -MinimumIntervalHours 4
		if (-not [bool]$throttleDecision.ShouldCheck)
		{
			LogInfo ('Skipping auto-update check: checked within the last 4 hours. Next eligible UTC: {0:o}.' -f $throttleDecision.NextEligibleUtc)
			return
		}
		Set-BaselineAutoUpdateThrottleTimestamp -Path $throttlePath

		Set-DownloadSecurityProtocol
		[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText (Get-BaselineLocalizedString -Key 'Bootstrap_CheckingForUpdates' -Fallback 'Checking for updates...') -Indeterminate)
		if (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction SilentlyContinue)
		{
			[void](Set-BootstrapLoadingSplashStep -Splash $Splash -StepId 'updates' -Status 'in_progress' -SubAction '')
		}
		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_CheckingForUpdatesVerbose' -Fallback 'Checking for updates (current version: {0})...' -FormatArgs @($CurrentVersion))

		$apiUrl  = 'https://api.github.com/repos/sdmanson8/Baseline/releases'
		$headers = @{ 'User-Agent' = "Baseline/$CurrentVersion" }

		$releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -TimeoutSec 8 -ErrorAction Stop
		$release = Get-BaselineLatestReleaseEntry -Releases $releases
		if (-not $release) { LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_NoReleasesFound' -Fallback 'No releases found on GitHub; skipping update.'); return }

		$latestTag = [string]$release.tag_name
		$isNewer = ((Compare-BaselineReleaseVersions -LeftVersion $latestTag -RightVersion $CurrentVersion) -gt 0)

		if (-not $isNewer)
		{
			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_AlreadyUpToDate' -Fallback 'Already up to date (latest: {0}).' -FormatArgs @($latestTag))
			[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText (Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait...') -Indeterminate)
			return
		}

		$downloadUrl = $null
		$releaseAsset = $release.assets | Where-Object { $_.name -like 'Baseline-*.zip' } | Select-Object -First 1
		if ($releaseAsset)
		{
			$downloadUrl = [string]$releaseAsset.browser_download_url
		}
		if ([string]::IsNullOrWhiteSpace($downloadUrl)) { LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_NoMatchingUpdateAsset' -Fallback 'Update {0} found but no matching zip asset; skipping.' -FormatArgs @($latestTag)); return }

		LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_UpdateAvailable' -Fallback 'Update available: {0}. Downloading...' -FormatArgs @($latestTag))
		# Download with progress bar
		[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText (Format-BaselineDownloadStatus -VersionTag $latestTag -BytesReceived 0 -TotalBytes 0 -ElapsedSeconds 0) -Completed 0 -Total 100)

		$tmpDir  = Join-Path ([System.IO.Path]::GetTempPath()) ("BaselineUpdate_" + [System.Guid]::NewGuid().ToString('N'))
		$zipPath = Join-Path $tmpDir 'Baseline-update.zip'
		$newExePath = Join-Path $tmpDir 'Baseline.exe'
		[void](New-Item -ItemType Directory -Path $tmpDir -Force)

		try
		{
			$request  = [System.Net.HttpWebRequest]::Create($downloadUrl)
			$request.UserAgent = "Baseline/$CurrentVersion"
			$request.Timeout   = 300000
			$response = $request.GetResponse()
			$total    = $response.ContentLength
			if ($total -le 0 -and $releaseAsset.SizeBytes -gt 0)
			{
				$total = [long]$releaseAsset.SizeBytes
			}

			$srcStream  = $response.GetResponseStream()
			$destStream = [System.IO.File]::Create($zipPath)
			$buffer     = New-Object byte[] 81920
			$received   = 0L
			$downloadTimer = [System.Diagnostics.Stopwatch]::StartNew()
			$lastUiUpdateMs = -1.0
			$lastPercent = -1

			try
			{
				$read = $srcStream.Read($buffer, 0, $buffer.Length)
				while ($read -gt 0)
				{
					$destStream.Write($buffer, 0, $read)
					$received += $read
					if ($total -gt 0)
					{
						$pct = [int]([Math]::Min(99, ($received * 100 / $total)))
						if (($pct -ne $lastPercent) -or (($downloadTimer.Elapsed.TotalMilliseconds - $lastUiUpdateMs) -ge 250))
						{
							$statusText = Format-BaselineDownloadStatus -VersionTag $latestTag -BytesReceived $received -TotalBytes $total -ElapsedSeconds $downloadTimer.Elapsed.TotalSeconds
							[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText $statusText -Completed $pct -Total 100)
							$lastPercent = $pct
							$lastUiUpdateMs = $downloadTimer.Elapsed.TotalMilliseconds
						}
					}
					elseif (($downloadTimer.Elapsed.TotalMilliseconds - $lastUiUpdateMs) -ge 250)
					{
						$statusText = Format-BaselineDownloadStatus -VersionTag $latestTag -BytesReceived $received -TotalBytes 0 -ElapsedSeconds $downloadTimer.Elapsed.TotalSeconds
						[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText $statusText -Indeterminate)
						$lastUiUpdateMs = $downloadTimer.Elapsed.TotalMilliseconds
					}
					$read = $srcStream.Read($buffer, 0, $buffer.Length)
				}
			}
			finally
			{
				$destStream.Close()
				$srcStream.Close()
				$response.Close()
			}

			[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText (Get-BaselineLocalizedString -Key 'Bootstrap_InstallingUpdate' -Fallback '' -FormatArgs @($latestTag)) -Completed 100 -Total 100)

			# Extract Baseline.exe from zip
			Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
			$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
			try
			{
				$entry = $zip.Entries | Where-Object { $_.Name -eq 'Baseline.exe' } | Select-Object -First 1
				if (-not $entry) { return }
				[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $newExePath, $true)
			}
			finally
			{
				$zip.Dispose()
			}

			# Write self-deleting updater script and relaunch
			$cmdPath = Join-Path $tmpDir 'apply-update.cmd'
			$cmdContent = @"
@echo off
timeout /t 2 /nobreak >nul
move /y "$newExePath" "$exePath"
set BASELINE_SKIP_UPDATE=1
start "" "$exePath"
del /f /q "$zipPath"
del /f /q "%~f0"
"@
			[System.IO.File]::WriteAllText($cmdPath, $cmdContent)

			$cmdExe = [System.Environment]::GetEnvironmentVariable('ComSpec')
			if ([string]::IsNullOrWhiteSpace($cmdExe))
			{
				$cmdExe = Join-Path $env:SystemRoot 'System32\cmd.exe'
			}

			$psi = [System.Diagnostics.ProcessStartInfo]::new()
			$psi.FileName = $cmdExe
			$psi.CreateNoWindow  = $true
			$psi.UseShellExecute = $false
			$psi.ArgumentList.Add('/c')
			$psi.ArgumentList.Add($cmdPath)
			[void]([System.Diagnostics.Process]::Start($psi))

			LogInfo (Get-BaselineBilingualString -Key 'Bootstrap_UpdateDownloadedRelaunching' -Fallback 'Update {0} downloaded. Relaunching to apply...' -FormatArgs @($latestTag))
			[void](Close-LoadingSplashWindow -Splash $Splash -DisposeResources)
			[System.Environment]::Exit(0)
		}
		catch
		{
			LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_UpdateDownloadOrApplyFailed' -Fallback 'Failed to download or apply update {0}: {1}' -FormatArgs @($latestTag, $_.Exception.Message))
			try { if (Test-Path $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue } } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.InvokeBaselineAutoUpdate.CleanupTempDir' }
		}
	}
	catch
	{
		# Never block startup — silently fall through on any update failure
		LogWarning (Get-BaselineBilingualString -Key 'Bootstrap_AutoUpdateCheckFailed' -Fallback 'Auto-update check failed: {0}' -FormatArgs @($_.Exception.Message))
	}
	finally
	{
		# Restore the checklist row to a completed state if the process stayed alive.
		try
		{
			if (Get-Command -Name 'Set-BootstrapLoadingSplashStep' -CommandType Function -ErrorAction SilentlyContinue)
			{
				[void](Set-BootstrapLoadingSplashStep -Splash $Splash -StepId 'updates' -Status 'completed' -SubAction '')
			}
			else
			{
				[void](Set-BootstrapLoadingSplashState -Splash $Splash -StatusText (Get-BaselineLocalizedString -Key 'GuiSplashLoading' -Fallback 'Please Wait...') -Indeterminate)
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.InvokeBaselineAutoUpdate.RestoreSplashState' }
	}
}

<#
    .SYNOPSIS
    Internal function Show-Menu.
#>

function Show-Menu
{
	<# .SYNOPSIS Displays an interactive console menu with arrow key navigation. #>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[array]
		$Menu,

		[Parameter(Mandatory = $true)]
		[int]
		$Default,

		[Parameter(Mandatory = $false)]
		[switch]
		$AddSkip
	)

	$Menu = @($Menu)

	if ($Localization -and $Localization.KeyboardArrows)
	{
		$Menu += ($Localization.KeyboardArrows -f [System.Char]::ConvertFromUtf32(0x2191), [System.Char]::ConvertFromUtf32(0x2193))
	}
	else
	{
		$Menu += ("Please use the arrow keys {0} and {1} on your keyboard to select your answer" -f [System.Char]::ConvertFromUtf32(0x2191), [System.Char]::ConvertFromUtf32(0x2193))
	}

	if ($AddSkip)
	{
		$Menu += Get-LocalizedShellString -ResourceId 16956 -Fallback 'Skip'
	}

	if ($env:WT_SESSION)
	{
		[System.Console]::BufferHeight += $Menu.Count
	}

	$minY = [Console]::CursorTop
	$y = [Math]::Max([Math]::Min(($Default - 1), ($Menu.Count - 1)), 0)

	# Returns selected menu item on Enter, or $null on Escape (callers must handle $null).
	do
	{
		[Console]::CursorTop = $minY
		[Console]::CursorLeft = 0
		$i = 0

		foreach ($item in $Menu)
		{
			if ($i -ne $y)
			{
				Write-Host ('  {0}  ' -f $item)
			}
			else
			{
				Write-Host ('[ {0} ]' -f $item)
			}

			$i++
		}

		$k = [Console]::ReadKey($true)
		switch ($k.Key)
		{
			'UpArrow'
			{
				if ($y -gt 0)
				{
					$y--
				}
			}
			'DownArrow'
			{
				if ($y -lt ($Menu.Count - 1))
				{
					$y++
				}
			}
			'Enter'
			{
				return $Menu[$y]
			}
		}
	}
	while ($k.Key -notin ([ConsoleKey]::Escape, [ConsoleKey]::Enter))
}

<#
    .SYNOPSIS
    Internal function Get-LocalizedShellString.
#>

function Get-LocalizedShellString
{
	<# .SYNOPSIS Retrieves a localized Windows shell string by resource ID. #>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[uint32]
		$ResourceId,

		[Parameter(Mandatory = $true)]
		[string]
		$Fallback,

		[Parameter(Mandatory = $false)]
		[switch]
		$StripAccelerators
	)

	$value = $null

	try
	{
		if ("WinAPI.GetStrings" -as [type])
		{
			$value = [WinAPI.GetStrings]::GetString($ResourceId)
		}
	}
	catch
	{
		$value = $null
	}

	if ([string]::IsNullOrWhiteSpace($value))
	{
		$value = $Fallback
	}

	if ($StripAccelerators -and -not [string]::IsNullOrEmpty($value))
	{
		$value = $value.Replace("&", "")
	}

	return $value
}

<#
    .SYNOPSIS
    Internal function Restart-Script.
#>

function Restart-Script
{
	<# .SYNOPSIS Restarts the script under Windows PowerShell 5.1 unless it is already running there. #>
	param
	(
		[Parameter(Mandatory = $true)]
		[string]
		$ScriptPath,

		[string]
		$Preset,

		[string]
		$GameModeProfile,

		[string]
		$ScenarioProfile,

		[string[]]
		$Functions,

		[string[]]
		$Include,

		[switch]
		$DryRun
	)
	if ([System.Environment]::GetEnvironmentVariable('BASELINE_EMBEDDED_HOST') -eq '1')
	{
		return
	}

	$runningWindowsPowerShell51 = (
		$PSVersionTable.PSEdition -eq 'Desktop' -and
		$PSVersionTable.PSVersion.Major -eq 5 -and
		$PSVersionTable.PSVersion.Minor -eq 1
	)

	if (-not $runningWindowsPowerShell51)
	{
		$powershell51 = (Get-Command -Name powershell.exe -ErrorAction SilentlyContinue).Source

		if (-not $powershell51)
		{
			LogError "PowerShell 5.1 not found."
			[Environment]::Exit(1)
		}

		if (-not (Test-Path -LiteralPath $ScriptPath))
		{
			LogError "Script not found: $ScriptPath"
			[Environment]::Exit(1)
		}

		LogInfo "Restarting script in Windows PowerShell 5.1 from host $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))."

		$currentPolicy = (Get-ExecutionPolicy).ToString()
		$argList = @(
			'-ExecutionPolicy', $currentPolicy,
			'-NoProfile',
			'-File', $ScriptPath
		)

		if ($Preset)
		{
			$argList += '-Preset'
			$argList += $Preset
		}
		elseif ($GameModeProfile)
		{
			$argList += '-GameModeProfile'
			$argList += $GameModeProfile
		}
		elseif ($ScenarioProfile)
		{
			$argList += '-ScenarioProfile'
			$argList += $ScenarioProfile
		}
		elseif ($Functions)
		{
			$argList += '-Functions'
			$argList += $Functions
		}

		if ($Include)
		{
			$argList += '-Include'
			$argList += $Include
		}

		if ($DryRun)
		{
			$argList += '-DryRun'
		}

		Start-Process -FilePath $powershell51 -ArgumentList $argList -WindowStyle Hidden
		[Environment]::Exit(0)
	}
}

<#
    .SYNOPSIS
    Internal function Get-BaselineDisplayVersion.
#>

function Get-BaselineDisplayVersion
{
	<# .SYNOPSIS Reads the module version string from Baseline.psd1. #>
	param ([string]$ModuleRoot)

	$resolvedRoot = if ($ModuleRoot) { $ModuleRoot } else { $Script:SharedHelpersModuleRoot }
	$moduleManifestPath = Join-Path $resolvedRoot 'Baseline.psd1'
	if (-not (Test-Path -LiteralPath $moduleManifestPath))
	{
		return $null
	}

	try
	{
		$moduleManifest = Import-EnvironmentPowerShellDataFile -Path $moduleManifestPath
		if ($moduleManifest.ContainsKey('ModuleVersion') -and -not [string]::IsNullOrWhiteSpace([string]$moduleManifest.ModuleVersion))
		{
			$version = "v{0}" -f [string]$moduleManifest.ModuleVersion
			if ($moduleManifest.ContainsKey('PrivateData') -and $moduleManifest.PrivateData -is [hashtable] -and $moduleManifest.PrivateData.ContainsKey('Prerelease') -and -not [string]::IsNullOrWhiteSpace([string]$moduleManifest.PrivateData.Prerelease))
			{
				$version = "{0} ({1})" -f $version, [string]$moduleManifest.PrivateData.Prerelease
			}
			return $version
		}
	}
	catch { Write-EnvironmentSwallowedException -ErrorRecord $_ -Source 'Environment.GetBaselineDisplayVersion.LoadManifest' }

	return $null
}

<#
    .SYNOPSIS
    Internal function Get-TweakSkipLabel.
#>

function Get-TweakSkipLabel
{
	<# .SYNOPSIS Returns the current tweak or caller name for skip log labels. #>
	param (
		[System.Management.Automation.InvocationInfo]$CallerInvocation
	)

	if ($Global:CurrentTweakName) { return $Global:CurrentTweakName }
	if ($CallerInvocation -and $CallerInvocation.MyCommand) { return $CallerInvocation.MyCommand.Name }
	return "this item"
}

<#
.SYNOPSIS
Kill all explorer.exe processes to apply shell/taskbar changes.

.DESCRIPTION
Terminates explorer.exe (taskbar, desktop shell, all File Explorer windows).
The shell restarts automatically. Used during tweak execution to force
registry changes to take immediate effect.
#>
function Stop-Foreground
{
	LogInfo "Stopping explorer.exe to apply shell changes"
	Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue | Out-Null
}

<#
.SYNOPSIS
Execute a scriptblock via a UCPD-bypassed PowerShell copy with guaranteed cleanup.

.DESCRIPTION
Copies powershell.exe to a temporary name to bypass the Windows UCPD driver
which blocks certain registry writes. The temporary file is removed in a
finally block to guarantee cleanup even if the command fails.

.PARAMETER ScriptBlock
The scriptblock to execute in the temporary PowerShell process.
#>
function Invoke-UCPDBypassed
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[scriptblock]$ScriptBlock
	)

	$sourcePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
	$tempPath = Get-UCPDTemporaryPowerShellPath -SourcePath $sourcePath

	Copy-Item -Path $sourcePath -Destination $tempPath -Force -ErrorAction Stop | Out-Null
	try
	{
		# ExecutionPolicy Bypass: required for elevated child process
	& $tempPath -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $ScriptBlock | Out-Null
		if ($LASTEXITCODE -ne 0)
		{
			throw "Temporary PowerShell copy returned exit code $LASTEXITCODE"
		}
	}
	finally
	{
		Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue | Out-Null
	}
}

<#
    .SYNOPSIS
    Internal function Get-UCPDTemporaryPowerShellPath.
#>

function Get-UCPDTemporaryPowerShellPath
{
	<# .SYNOPSIS Generates a unique temporary PowerShell executable path for UCPD bypass. #>
	param (
		[string]$SourcePath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
	)

	$sourceDirectory = Split-Path -Path $SourcePath -Parent
	$sourceLeaf = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
	$uniqueName = '{0}_{1}.exe' -f $sourceLeaf, ([guid]::NewGuid().ToString('N'))
	return (Join-Path -Path $sourceDirectory -ChildPath $uniqueName)
}

<#
    .SYNOPSIS
    Internal function .
#>
function Set-BaselineOperationMode
{
	<#
		.SYNOPSIS
		Sets the global operation mode. Valid: 'ReadWrite' (default) or 'ReadOnly'.
		ReadOnly mode causes Persistence/Audit/Registry write helpers to throw.
	#>
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('ReadWrite', 'ReadOnly')]
		[string]$Mode
	)

	$Global:BaselineOperationMode = $Mode
	[System.Environment]::SetEnvironmentVariable('BASELINE_OPERATION_MODE', $Mode, [System.EnvironmentVariableTarget]::Process)
}

<#
    .SYNOPSIS
    Internal function .
#>
function Get-BaselineOperationMode
{
	<#
		.SYNOPSIS
		Returns the active operation mode. Defaults to 'ReadWrite'.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	if ($Global:BaselineOperationMode) { return [string]$Global:BaselineOperationMode }
	$envMode = [System.Environment]::GetEnvironmentVariable('BASELINE_OPERATION_MODE')
	if (-not [string]::IsNullOrWhiteSpace([string]$envMode)) { return [string]$envMode }
	return 'ReadWrite'
}

<#
    .SYNOPSIS
    Internal function .
#>
function Test-BaselineReadOnlyMode
{
	<# .SYNOPSIS Returns $true when Baseline is in ReadOnly mode. #>
	return ((Get-BaselineOperationMode) -eq 'ReadOnly')
}

<#
    .SYNOPSIS
    Internal function .
#>
function Assert-BaselineWriteAllowed
{
	<#
		.SYNOPSIS
		Throws when the active mode is ReadOnly. Used by canonical write helpers.
	#>
	[CmdletBinding()]
	param (
		[string]$Operation = 'write'
	)

	if (Test-BaselineReadOnlyMode)
	{
		throw [System.InvalidOperationException]::new(("Baseline is running in ReadOnly mode; '{0}' is not permitted." -f $Operation))
	}
}

<#
    .SYNOPSIS
    Internal function .
#>
function Initialize-BaselineMarkdownRuntime
{
	<# .SYNOPSIS Loads the embedded Markdig + Markdig.Wpf assemblies into the current runspace. #>
	[CmdletBinding()]
	param (
		[string]$ModuleRoot
	)

	if ($Script:CachedBaselineMarkdownRuntimeLoaded) { return $true }

	if ([string]::IsNullOrWhiteSpace($ModuleRoot))
	{
		$ModuleRoot = $Script:SharedHelpersModuleRoot
	}

	if ([string]::IsNullOrWhiteSpace($ModuleRoot) -or -not (Test-Path -LiteralPath $ModuleRoot -PathType Container))
	{
		return $false
	}

	$librariesRoot = Join-Path $ModuleRoot 'Libraries'
	if (-not (Test-Path -LiteralPath $librariesRoot -PathType Container))
	{
		return $false
	}

	# Load dependencies before Markdig / Markdig.Wpf so their references resolve.
	$loadOrder = @(
		'System.Buffers.dll',
		'System.Runtime.CompilerServices.Unsafe.dll',
		'System.Numerics.Vectors.dll',
		'System.Memory.dll',
		'Markdig.dll',
		'Markdig.Wpf.dll'
	)

	foreach ($dllName in $loadOrder)
	{
		$dllPath = Join-Path $librariesRoot $dllName
		if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) { continue }
		try { Add-Type -Path $dllPath -ErrorAction Stop } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.InitializeBaselineMarkdownRuntime.AddAssembly' }
	}

	$Script:CachedBaselineMarkdownRuntimeLoaded = (Test-BaselineMarkdownRuntimeReady)
	return [bool]$Script:CachedBaselineMarkdownRuntimeLoaded
}

<#
    .SYNOPSIS
    Internal function Test-BaselineMarkdownRuntimeReady.
#>

function Test-BaselineMarkdownRuntimeReady
{
	<# .SYNOPSIS Returns $true once Markdig + Markdig.Wpf have been loaded into the runspace. #>
	$markdigAssembly = $null
	$markdigWpfAssembly = $null

	foreach ($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies())
	{
		$assemblyName = $null
		try { $assemblyName = $assembly.GetName().Name } catch { $assemblyName = $null }
		if ([string]::IsNullOrWhiteSpace([string]$assemblyName)) { continue }

		if ($assemblyName -eq 'Markdig')
		{
			$markdigAssembly = $assembly
		}
		elseif ($assemblyName -eq 'Markdig.Wpf')
		{
			$markdigWpfAssembly = $assembly
		}

		if ($markdigAssembly -and $markdigWpfAssembly) { break }
	}

	if (-not $markdigAssembly -or -not $markdigWpfAssembly)
	{
		return $false
	}

	return (($null -ne $markdigAssembly.GetType('Markdig.Markdown', $false, $false)) -and
		($null -ne $markdigWpfAssembly.GetType('Markdig.Wpf.Markdown', $false, $false)))
}

<#
    .SYNOPSIS
    Internal function Get-BaselineMarkdownPipeline.
#>
function Get-BaselineMarkdownPipeline
{
	<# .SYNOPSIS Returns a cached MarkdownPipeline configured with GitHub-style heading identifiers. #>
	if ($Script:CachedBaselineMarkdownPipeline) { return $Script:CachedBaselineMarkdownPipeline }

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		[void](Initialize-BaselineMarkdownRuntime)
	}

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		throw 'Markdig runtime is not available.'
	}

	$builder = New-Object Markdig.MarkdownPipelineBuilder
	$builder = [Markdig.MarkdownExtensions]::UseAutoIdentifiers($builder, [Markdig.Extensions.AutoIdentifiers.AutoIdentifierOptions]::GitHub)
	$Script:CachedBaselineMarkdownPipeline = $builder.Build()
	return $Script:CachedBaselineMarkdownPipeline
}

<#
    .SYNOPSIS
    Internal function .
#>
function ConvertFrom-BaselineMarkdownToFlowDocument
{
	<# .SYNOPSIS Renders a Markdown string into a WPF FlowDocument using Markdig.Wpf. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$Markdown
	)

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		[void](Initialize-BaselineMarkdownRuntime)
	}

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		throw 'Markdig runtime is not available.'
	}

	return [Markdig.Wpf.Markdown]::ToFlowDocument([string]$Markdown)
}

<#
    .SYNOPSIS
    Internal function ConvertFrom-BaselineMarkdownToAnchoredFlowDocument.
#>
function ConvertFrom-BaselineMarkdownToAnchoredFlowDocument
{
	<#
		.SYNOPSIS
		Renders Markdown into a FlowDocument with anchor map and repaired hyperlinks.
		.DESCRIPTION
		Markdig.Wpf can drop fragment-only URLs from anchor links. This helper
		parses the Markdown AST with the same pipeline, pairs AST links/headings
		with the rendered FlowDocument, and returns enough metadata for callers to
		handle in-document navigation without replacing the README body.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$Markdown
	)

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		[void](Initialize-BaselineMarkdownRuntime)
	}

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		throw 'Markdig runtime is not available.'
	}

	$pipeline = Get-BaselineMarkdownPipeline
	$ast = [Markdig.Markdown]::Parse([string]$Markdown, $pipeline)

	$allNodes = @([Markdig.Syntax.MarkdownObjectExtensions]::Descendants($ast))
	$astHeadings = @($allNodes | Where-Object { $_ -is [Markdig.Syntax.HeadingBlock] })
	$astLinks = @($allNodes | Where-Object { $_ -is [Markdig.Syntax.Inlines.LinkInline] })

	$astHeadingIds = New-Object System.Collections.Generic.List[string]
	foreach ($heading in $astHeadings)
	{
		$attributes = [Markdig.Renderers.Html.HtmlAttributesExtensions]::GetAttributes($heading)
		$id = if ($attributes -and $attributes.Id) { [string]$attributes.Id } else { $null }
		[void]$astHeadingIds.Add($id)
	}

	$astLinkUrls = New-Object System.Collections.Generic.List[string]
	foreach ($link in $astLinks)
	{
		[void]$astLinkUrls.Add([string]$link.Url)
	}

	$document = [Markdig.Wpf.Markdown]::ToFlowDocument([string]$Markdown)
	$docHeadings = New-Object System.Collections.Generic.List[System.Windows.Documents.Paragraph]
	$docHyperlinks = New-Object System.Collections.Generic.List[System.Windows.Documents.Hyperlink]
	$defaultFontSize = [double]$document.FontSize
	if ($defaultFontSize -le 0) { $defaultFontSize = 14.0 }

	$blockStack = New-Object System.Collections.Generic.Stack[object]
	foreach ($block in ($document.Blocks | ForEach-Object { $_ })) { $blockStack.Push($block) }
	$orderedBlocks = New-Object System.Collections.Generic.List[object]
	while ($blockStack.Count -gt 0)
	{
		$block = $blockStack.Pop()
		[void]$orderedBlocks.Insert(0, $block)
		if ($block -is [System.Windows.Documents.Section])
		{
			foreach ($subBlock in ($block.Blocks | ForEach-Object { $_ })) { $blockStack.Push($subBlock) }
		}
		elseif ($block -is [System.Windows.Documents.List])
		{
			foreach ($listItem in ($block.ListItems | ForEach-Object { $_ }))
			{
				foreach ($subBlock in ($listItem.Blocks | ForEach-Object { $_ })) { $blockStack.Push($subBlock) }
			}
		}
		elseif ($block -is [System.Windows.Documents.Table])
		{
			foreach ($rowGroup in ($block.RowGroups | ForEach-Object { $_ }))
			{
				foreach ($row in ($rowGroup.Rows | ForEach-Object { $_ }))
				{
					foreach ($cell in ($row.Cells | ForEach-Object { $_ }))
					{
						foreach ($subBlock in ($cell.Blocks | ForEach-Object { $_ })) { $blockStack.Push($subBlock) }
					}
				}
			}
		}
	}

	foreach ($block in $orderedBlocks)
	{
		if (-not ($block -is [System.Windows.Documents.Paragraph])) { continue }
		$paragraph = [System.Windows.Documents.Paragraph]$block
		try { $paragraphFontSize = [double]$paragraph.FontSize } catch { $paragraphFontSize = 0.0 }
		if ($paragraphFontSize -gt ($defaultFontSize + 0.5))
		{
			[void]$docHeadings.Add($paragraph)
		}

		$inlineStack = New-Object System.Collections.Generic.Stack[object]
		foreach ($inline in ($paragraph.Inlines | ForEach-Object { $_ })) { $inlineStack.Push($inline) }
		$inlineOrdered = New-Object System.Collections.Generic.List[object]
		while ($inlineStack.Count -gt 0)
		{
			$inline = $inlineStack.Pop()
			[void]$inlineOrdered.Insert(0, $inline)
			if ($inline -is [System.Windows.Documents.Span])
			{
				foreach ($child in ($inline.Inlines | ForEach-Object { $_ })) { $inlineStack.Push($child) }
			}
		}
		foreach ($inline in $inlineOrdered)
		{
			if ($inline -is [System.Windows.Documents.Hyperlink]) { [void]$docHyperlinks.Add($inline) }
		}
	}

	$anchorMap = New-Object "System.Collections.Generic.Dictionary[string, System.Windows.Documents.Paragraph]"
	$headingPairs = [Math]::Min($astHeadingIds.Count, $docHeadings.Count)
	for ($i = 0; $i -lt $headingPairs; $i++)
	{
		$id = $astHeadingIds[$i]
		if ([string]::IsNullOrWhiteSpace([string]$id)) { continue }
		$docHeadings[$i].Tag = $id
		if (-not $anchorMap.ContainsKey($id)) { $anchorMap[$id] = $docHeadings[$i] }
	}

	$linkPairs = [Math]::Min($astLinkUrls.Count, $docHyperlinks.Count)
	for ($i = 0; $i -lt $linkPairs; $i++)
	{
		$url = $astLinkUrls[$i]
		if ([string]::IsNullOrWhiteSpace([string]$url)) { continue }
		$docHyperlinks[$i].Tag = $url
		try
		{
			$docHyperlinks[$i].NavigateUri = [System.Uri]::new([string]$url, [System.UriKind]::RelativeOrAbsolute)
		}
		catch { }
	}

	return [PSCustomObject]@{
		Document = $document
		AnchorMap = $anchorMap
		Hyperlinks = $docHyperlinks
	}
}

<#
    .SYNOPSIS
    Internal function ConvertFrom-BaselineMarkdownToHtml.
#>
function ConvertFrom-BaselineMarkdownToHtml
{
	<# .SYNOPSIS Renders Markdown to a complete HTML document using Markdig. #>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$Markdown,

		[string]$BackgroundColor = '#1e1e2e',
		[string]$ForegroundColor = '#e6e6e6',
		[string]$MutedForegroundColor = '#a0a0a0',
		[string]$LinkColor = '#4da3ff',
		[string]$CodeBackgroundColor = '#2a2a3d'
	)

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		[void](Initialize-BaselineMarkdownRuntime)
	}

	if (-not (Test-BaselineMarkdownRuntimeReady))
	{
		throw 'Markdig runtime is not available.'
	}

	$bodyHtml = [Markdig.Markdown]::ToHtml([string]$Markdown, (Get-BaselineMarkdownPipeline))
	return @"
<!doctype html>
<html>
<head>
	<meta charset="utf-8" />
	<meta name="viewport" content="width=device-width, initial-scale=1" />
	<style>
		:root {
			color-scheme: dark;
		}
		html, body {
			margin: 0;
			padding: 0;
			background: $BackgroundColor;
			color: $ForegroundColor;
			font-family: "Segoe UI", Arial, sans-serif;
			font-size: 14px;
			line-height: 1.6;
		}
		body {
			padding: 20px 24px;
		}
		main {
			max-width: 1100px;
			margin: 0 auto;
		}
		a {
			color: $LinkColor;
		}
		h1, h2, h3, h4, h5, h6 {
			color: $ForegroundColor;
			line-height: 1.2;
			margin-top: 1.4em;
			margin-bottom: 0.5em;
		}
		p, ul, ol, blockquote, table, pre {
			margin-top: 0;
			margin-bottom: 1em;
		}
		blockquote {
			margin-left: 0;
			padding: 0.75em 1em;
			border-left: 4px solid $LinkColor;
			background: rgba(255,255,255,0.04);
		}
		code {
			background: $CodeBackgroundColor;
			border-radius: 4px;
			padding: 0.15em 0.35em;
			color: $ForegroundColor;
			font-family: Consolas, "Courier New", monospace;
		}
		pre {
			background: $CodeBackgroundColor;
			border-radius: 8px;
			padding: 16px;
			overflow: auto;
		}
		pre code {
			background: transparent;
			padding: 0;
		}
		table {
			border-collapse: collapse;
			width: 100%;
		}
		th, td {
			border: 1px solid rgba(255,255,255,0.12);
			padding: 8px 10px;
			vertical-align: top;
		}
		th {
			background: rgba(255,255,255,0.06);
		}
		img {
			max-width: 100%;
			height: auto;
		}
		hr {
			border: 0;
			border-top: 1px solid rgba(255,255,255,0.12);
			margin: 1.5em 0;
		}
		.muted {
			color: $MutedForegroundColor;
		}
	</style>
</head>
<body>
	<main>
$bodyHtml
	</main>
</body>
</html>
"@
}

<#
    .SYNOPSIS
    Internal function Initialize-BaselineWebView2Runtime.
#>
function Initialize-BaselineWebView2Runtime
{
	<# .SYNOPSIS Loads the WebView2 assemblies from the hydrated runtime. #>
	[CmdletBinding()]
	param (
		[string]$ModuleRoot
	)

	if ($Script:CachedBaselineWebView2RuntimeLoaded) { return $true }

	if ([string]::IsNullOrWhiteSpace($ModuleRoot))
	{
		$ModuleRoot = $Script:SharedHelpersModuleRoot
	}

	if ([string]::IsNullOrWhiteSpace($ModuleRoot) -or -not (Test-Path -LiteralPath $ModuleRoot -PathType Container))
	{
		return $false
	}

	$librariesRoot = Join-Path $ModuleRoot 'Libraries'
	if (-not (Test-Path -LiteralPath $librariesRoot -PathType Container))
	{
		$librariesRoot = $null
	}

	$searchRoots = [System.Collections.Generic.List[string]]::new()
	if (-not [string]::IsNullOrWhiteSpace($librariesRoot))
	{
		[void]$searchRoots.Add($librariesRoot)
	}

	$commonRoots = @(
		'%ProgramFiles%\Microsoft Office\root\Office16\ADDINS\Microsoft Power Query for Excel Integrated\bin',
		'%ProgramFiles(x86)%\Microsoft Office\root\Office16\ADDINS\Microsoft Power Query for Excel Integrated\bin',
		'%WINDIR%\SystemApps\Shared\WebView2SDK',
		'%WINDIR%\WinSxS'
	)

	foreach ($rootTemplate in $commonRoots)
	{
		try
		{
			$rootPath = [Environment]::ExpandEnvironmentVariables($rootTemplate)
			if (-not [string]::IsNullOrWhiteSpace($rootPath) -and (Test-Path -LiteralPath $rootPath -PathType Container))
			{
				[void]$searchRoots.Add($rootPath)
			}
		}
		catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.InitializeBaselineWebView2Runtime.ExpandSearchRoot' }
	}

	$loadOrder = @(
		'Microsoft.Web.WebView2.Core.dll',
		'Microsoft.Web.WebView2.WinForms.dll'
	)

	foreach ($dllName in $loadOrder)
	{
		$dllPath = $null
		foreach ($searchRoot in @($searchRoots))
		{
			$candidate = Join-Path $searchRoot $dllName
			if (Test-Path -LiteralPath $candidate -PathType Leaf)
			{
				$dllPath = $candidate
				break
			}
		}

		if (-not $dllPath) { continue }
		try { Add-Type -Path $dllPath -ErrorAction Stop } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Environment.InitializeBaselineWebView2Runtime.AddAssembly' }
	}

	$Script:CachedBaselineWebView2RuntimeLoaded = ([System.Type]::GetType('Microsoft.Web.WebView2.WinForms.WebView2, Microsoft.Web.WebView2.WinForms') -ne $null)
	return [bool]$Script:CachedBaselineWebView2RuntimeLoaded
}

<#
    .SYNOPSIS
    Internal function Test-BaselineWebView2RuntimeReady.
#>
function Test-BaselineWebView2RuntimeReady
{
	<# .SYNOPSIS Returns $true once WebView2 has been loaded into the runspace. #>
	return ([System.Type]::GetType('Microsoft.Web.WebView2.WinForms.WebView2, Microsoft.Web.WebView2.WinForms') -ne $null)
}

<#
    .SYNOPSIS
    Detect whether the current host is a virtual machine.

    .DESCRIPTION
    Returns $true when the Win32_ComputerSystem Model reports a known
    hypervisor signature. Used by guardrails that must not run on VMs (e.g.
    hardware-accelerated GPU scheduling). Production code and tests share this
    single helper so detection behavior stays aligned.
#>
function Test-IsVirtualMachine
{
	[CmdletBinding()]
	param()

	try
	{
		$model = [string](Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).Model
	}
	catch
	{
		return $false
	}

	return ($model -match 'Virtual|VMware|VBOX|KVM|QEMU|Xen|Hyper-V')
}

