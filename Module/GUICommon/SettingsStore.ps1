<#
    .SYNOPSIS
    Internal function Get-GuiSettingsProfileDirectory.
#>
function Get-GuiSettingsProfileDirectory
{
	param (
		[string]$AppName = 'Baseline'
	)

	$stateRoot = [System.Environment]::GetEnvironmentVariable('BASELINE_STATE_ROOT')
	if (-not [string]::IsNullOrWhiteSpace([string]$stateRoot))
	{
		$baseDir = Join-Path $stateRoot 'Profiles'
	}
	elseif ($env:LOCALAPPDATA)
	{
		$baseDir = Join-Path $env:LOCALAPPDATA "$AppName\UserState\Profiles"
	}
	else
	{
		$baseDir = Join-Path $env:TEMP "$AppName\Profiles"
	}

	try
	{
		if (-not (Test-Path -LiteralPath $baseDir))
		{
			[void](New-Item -ItemType Directory -Path $baseDir -Force -ErrorAction Stop)
		}

		if ([string]::IsNullOrWhiteSpace([string]$stateRoot) -and $env:LOCALAPPDATA)
		{
			$legacyDir = Join-Path $env:LOCALAPPDATA "$AppName\Profiles"
			if ((Test-Path -LiteralPath $legacyDir) -and -not [string]::Equals([System.IO.Path]::GetFullPath($legacyDir), [System.IO.Path]::GetFullPath($baseDir), [System.StringComparison]::OrdinalIgnoreCase))
			{
				foreach ($legacyFile in @(Get-ChildItem -LiteralPath $legacyDir -File -Filter '*.json' -ErrorAction SilentlyContinue))
				{
					$targetPath = Join-Path $baseDir $legacyFile.Name
					if (-not (Test-Path -LiteralPath $targetPath))
					{
						Copy-Item -LiteralPath $legacyFile.FullName -Destination $targetPath -Force -ErrorAction Stop
					}
				}
			}
		}
	}
	catch
	{
		$null = $_
	}

	return $baseDir
}

<#
    .SYNOPSIS
    Internal function Get-GuiLastRunFilePath.
#>
function Get-GuiLastRunFilePath
{
	return (Join-Path (Get-GuiSettingsProfileDirectory) 'Baseline-last-run.json')
}

<#
    .SYNOPSIS
    Internal function Get-GuiInterruptedRunFilePath.
#>
function Get-GuiInterruptedRunFilePath
{
	return (Join-Path (Get-GuiSettingsProfileDirectory) 'Baseline-interrupted-run.json')
}

<#
    .SYNOPSIS
    Internal function Get-GuiSessionStatePath.
#>
function Get-GuiSessionStatePath
{
	param (
		[string]$AppName = 'Baseline'
	)

	return (Join-Path (Get-GuiSettingsProfileDirectory -AppName $AppName) "$AppName-last-session.json")
}

<#
    .SYNOPSIS
    Internal function Save-GuiSessionStateDocument.
#>
function Save-GuiSessionStateDocument
{
	param (
		[Parameter(Mandatory = $true)]
		[object]$Snapshot,

		[string]$AppName = 'Baseline'
	)

	try
	{
		$sessionState = [ordered]@{
			Schema = "$AppName.GuiSession"
			SchemaVersion = 1
			SavedAt = (Get-Date).ToString('o')
			State = $Snapshot
		}
		($sessionState | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath (Get-GuiSessionStatePath -AppName $AppName) -Encoding UTF8 -Force
		LogInfo (Get-BaselineBilingualString -Key 'GuiLogGuiSessionStateSaved' -Fallback 'Saved GUI session state.')
		return $true
	}
	catch
	{
		LogWarning (Get-BaselineBilingualString -Key 'GuiLogGuiSessionStateSaveFailed' -Fallback 'Failed to save GUI session state: {0}' -FormatArgs @($_.Exception.Message))
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Read-GuiSessionStateDocument.
#>
function Read-GuiSessionStateDocument
{
	param (
		[string]$AppName = 'Baseline',
		[string]$ExpectedSchema = 'Baseline.GuiSettings'
	)

	$sessionPath = Get-GuiSessionStatePath -AppName $AppName
	if (-not (Test-Path -LiteralPath $sessionPath))
	{
		return $null
	}

	try
	{
		$raw = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 -ErrorAction Stop
		$sessionPayload = $raw | ConvertFrom-BaselineJson -Depth 12 -ErrorAction Stop
	}
	catch
	{
		LogWarning (Get-BaselineBilingualString -Key 'GuiLogGuiSessionStateReadFailed' -Fallback 'Failed to read GUI session state: {0}' -FormatArgs @($_.Exception.Message))
		return $null
	}

	$snapshot = if ((Test-GuiObjectField -Object $sessionPayload -FieldName 'State')) { $sessionPayload.State } else { $sessionPayload }
	if (
		-not $snapshot -or
		((Test-GuiObjectField -Object $snapshot -FieldName 'Schema') -and [string]$snapshot.Schema -ne $ExpectedSchema)
	)
	{
		LogWarning 'The saved GUI session state is invalid and was ignored.'
		return $null
	}

	return $snapshot
}

<#
    .SYNOPSIS
    Internal function Show-GuiSettingsSaveDialog.
#>
function Show-GuiSettingsSaveDialog
{
	param (
		[string]$AppName = 'Baseline'
	)

	$saveDialog = New-Object Microsoft.Win32.SaveFileDialog
	$saveDialog.Filter = "$AppName Settings (*.json)|*.json|All Files (*.*)|*.*"
	$saveDialog.InitialDirectory = Get-GuiSettingsProfileDirectory -AppName $AppName
	$saveDialog.FileName = "$AppName-settings-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss')

	if ($saveDialog.ShowDialog() -eq $true)
	{
		return $saveDialog.FileName
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Show-GuiFileOpenDialog.
#>
function Show-GuiFileOpenDialog
{
	param (
		[string]$Title = 'Open File',
		[string]$Filter = 'All Files (*.*)|*.*',
		[string]$InitialDirectory = $null,
		[bool]$Multiselect = $false
	)

	$openDialog = New-Object Microsoft.Win32.OpenFileDialog
	$openDialog.Title = $Title
	$openDialog.Filter = $Filter
	if (-not [string]::IsNullOrWhiteSpace($InitialDirectory))
	{
		$openDialog.InitialDirectory = $InitialDirectory
	}
	$openDialog.Multiselect = [bool]$Multiselect

	if ($openDialog.ShowDialog() -eq $true)
	{
		if ($Multiselect)
		{
			return @($openDialog.FileNames)
		}

		return $openDialog.FileName
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Show-GuiSettingsOpenDialog.
#>
function Show-GuiSettingsOpenDialog
{
	param (
		[string]$AppName = 'Baseline'
	)

	return (Show-GuiFileOpenDialog `
		-Title (Get-UxLocalizedString -Key 'GuiImportSettings' -Fallback 'Import Settings') `
		-Filter "$AppName Settings (*.json)|*.json|All Files (*.*)|*.*" `
		-InitialDirectory (Get-GuiSettingsProfileDirectory -AppName $AppName))
}

<#
    .SYNOPSIS
    Internal function Write-GuiSettingsProfileDocument.
#>
function Write-GuiSettingsProfileDocument
{
	param (
		[Parameter(Mandatory = $true)]
		[object]$Snapshot,

		[Parameter(Mandatory = $true)]
		[string]$FilePath
	)

	($Snapshot | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $FilePath -Encoding UTF8 -Force
	return $true
}

<#
    .SYNOPSIS
    Internal function Read-GuiSettingsProfileDocument.
#>
function Read-GuiSettingsProfileDocument
{
	param (
		[Parameter(Mandatory = $true)]
		[string]$FilePath,

		[string]$ExpectedSchema = 'Baseline.GuiSettings'
	)

	$raw = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 -ErrorAction Stop
	$parsedProfile = $raw | ConvertFrom-BaselineJson -Depth 12 -ErrorAction Stop
	$snapshot = if ((Test-GuiObjectField -Object $parsedProfile -FieldName 'State')) { $parsedProfile.State } else { $parsedProfile }

	if (
		-not $snapshot -or
		((Test-GuiObjectField -Object $snapshot -FieldName 'Schema') -and [string]$snapshot.Schema -ne $ExpectedSchema) -or
		-not (Test-GuiObjectField -Object $snapshot -FieldName 'Controls')
	)
	{
		throw 'The selected file does not contain a valid Baseline settings profile.'
	}

	return $snapshot
}
