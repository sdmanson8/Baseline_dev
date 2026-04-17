# Configuration profile helper slice for Baseline.
# Provides portable configuration profile creation, import/export, compatibility
# checking, comparison, and conversion from existing presets.
# Uses Write-BaselineDocument / Read-BaselineDocument patterns for persistence.

$Script:ConfigProfileSchema = 'Baseline.ConfigProfile'
$Script:ConfigProfileSchemaVersion = 2

<#
    .SYNOPSIS
    Internal function ConvertTo-ConfigurationProfileValueText.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function ConvertTo-ConfigurationProfileValueText
{
	[CmdletBinding()]
	param ([object]$Value)

	if ($null -eq $Value)
	{
		return $null
	}

	if ($Value -is [string])
	{
		return [string]$Value
	}

	if ($Value -is [bool] -or $Value -is [ValueType])
	{
		return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
	}

	if ($Value -is [System.Collections.IDictionary])
	{
		if ($Value.Contains('ACValue') -or $Value.Contains('DCValue'))
		{
			$acValue = if ($Value.Contains('ACValue')) { $Value['ACValue'] } else { $null }
			$dcValue = if ($Value.Contains('DCValue')) { $Value['DCValue'] } else { $null }
			$acText = if ($null -ne $acValue) { ConvertTo-ConfigurationProfileValueText -Value $acValue } else { $null }
			$dcText = if ($null -ne $dcValue) { ConvertTo-ConfigurationProfileValueText -Value $dcValue } else { $null }

			if (-not [string]::IsNullOrWhiteSpace([string]$acText) -and -not [string]::IsNullOrWhiteSpace([string]$dcText))
			{
				if ([string]$acText -eq [string]$dcText)
				{
					return [string]$acText
				}

				return ('AC={0};DC={1}' -f [string]$acText, [string]$dcText)
			}

			if (-not [string]::IsNullOrWhiteSpace([string]$acText))
			{
				return ('AC={0}' -f [string]$acText)
			}

			if (-not [string]::IsNullOrWhiteSpace([string]$dcText))
			{
				return ('DC={0}' -f [string]$dcText)
			}
		}

		if ($Value.Contains('Value'))
		{
			return ConvertTo-ConfigurationProfileValueText -Value $Value['Value']
		}
		if ($Value.Contains('SelectedValue'))
		{
			return ConvertTo-ConfigurationProfileValueText -Value $Value['SelectedValue']
		}
		if ($Value.Contains('NumericValue'))
		{
			return ConvertTo-ConfigurationProfileValueText -Value $Value['NumericValue']
		}

		return ([string]($Value | ConvertTo-Json -Depth 8 -Compress))
	}

	if ($Value -is [pscustomobject])
	{
		if ($Value.PSObject.Properties['ACValue'] -or $Value.PSObject.Properties['DCValue'])
		{
			$acValue = if ($Value.PSObject.Properties['ACValue']) { $Value.ACValue } else { $null }
			$dcValue = if ($Value.PSObject.Properties['DCValue']) { $Value.DCValue } else { $null }
			$acText = if ($null -ne $acValue) { ConvertTo-ConfigurationProfileValueText -Value $acValue } else { $null }
			$dcText = if ($null -ne $dcValue) { ConvertTo-ConfigurationProfileValueText -Value $dcValue } else { $null }

			if (-not [string]::IsNullOrWhiteSpace([string]$acText) -and -not [string]::IsNullOrWhiteSpace([string]$dcText))
			{
				if ([string]$acText -eq [string]$dcText)
				{
					return [string]$acText
				}

				return ('AC={0};DC={1}' -f [string]$acText, [string]$dcText)
			}

			if (-not [string]::IsNullOrWhiteSpace([string]$acText))
			{
				return ('AC={0}' -f [string]$acText)
			}

			if (-not [string]::IsNullOrWhiteSpace([string]$dcText))
			{
				return ('DC={0}' -f [string]$dcText)
			}
		}

		foreach ($fieldName in @('Value', 'SelectedValue', 'NumericValue'))
		{
			if ($Value.PSObject.Properties[$fieldName] -and $null -ne $Value.$fieldName)
			{
				return ConvertTo-ConfigurationProfileValueText -Value $Value.$fieldName
			}
		}

		return ([string]($Value | ConvertTo-Json -Depth 8 -Compress))
	}

	return [string]$Value
}

<#
    .SYNOPSIS
    Internal function New-ConfigurationProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function New-ConfigurationProfile
{
	<#
		.SYNOPSIS
		Creates a new configuration profile object from the supplied selections.

		.DESCRIPTION
		Builds a portable profile envelope containing tweak entries, metadata, and
		target requirements for the current machine. The profile can be exported,
		imported on another machine, and compared with other profiles.
	#>
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[array]$Selections,

		[array]$AppActions = @(),

		[Parameter(Mandatory)]
		[string]$BaselineVersion,

		[string]$Description,

		[string]$AppsPackageSourcePreference
	)

	# Determine target requirements from the current machine.
	$minBuild = 22621
	$edition = 'Pro|Home|Enterprise'
	try
	{
		$versionData = Get-WindowsVersionData
		if ($versionData -and $versionData.CurrentBuild)
		{
			$parsedBuild = 0
			if ([int]::TryParse([string]$versionData.CurrentBuild, [ref]$parsedBuild) -and $parsedBuild -gt 0)
			{
				$minBuild = $parsedBuild
			}
		}
	}
	catch { }

	try
	{
		$currentVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
		if ($currentVersion -and $currentVersion.PSObject.Properties['EditionID'] -and -not [string]::IsNullOrWhiteSpace([string]$currentVersion.EditionID))
		{
			$edition = [string]$currentVersion.EditionID
		}
	}
	catch { }

	# Build normalized entry list from selections.
	$entries = [System.Collections.Generic.List[ordered]]::new()
	foreach ($selection in @($Selections))
	{
		if ($null -eq $selection) { continue }

		$functionName = $null
		$entryType = 'Toggle'
		$param = $null
		$category = $null
		$value = $null
		$runFlag = $null

		if ($selection -is [System.Collections.IDictionary])
		{
			$functionName = if ($selection.Contains('Function')) { [string]$selection['Function'] } else { $null }
			$entryType = if ($selection.Contains('Type')) { [string]$selection['Type'] } else { 'Toggle' }
			$param = if ($selection.Contains('ToggleParam')) { [string]$selection['ToggleParam'] }
						elseif ($selection.Contains('Selection')) { [string]$selection['Selection'] }
						else { $null }
			$category = if ($selection.Contains('Category')) { [string]$selection['Category'] } else { $null }
			$value = if ($selection.Contains('Value')) { $selection['Value'] } elseif ($selection.Contains('SelectedValue')) { $selection['SelectedValue'] } else { $null }
			$runFlag = if ($selection.Contains('Run')) { [bool]$selection['Run'] } else { $null }
		}
		elseif ($selection -is [pscustomobject] -or ($null -ne $selection.PSObject))
		{
			$functionName = if ($selection.PSObject.Properties['Function']) { [string]$selection.Function } else { $null }
			$entryType = if ($selection.PSObject.Properties['Type']) { [string]$selection.Type } else { 'Toggle' }
			$param = if ($selection.PSObject.Properties['ToggleParam']) { [string]$selection.ToggleParam }
						elseif ($selection.PSObject.Properties['Selection']) { [string]$selection.Selection }
						else { $null }
			$category = if ($selection.PSObject.Properties['Category']) { [string]$selection.Category } else { $null }
			$value = if ($selection.PSObject.Properties['Value']) { $selection.Value } elseif ($selection.PSObject.Properties['SelectedValue']) { $selection.SelectedValue } else { $null }
			$runFlag = if ($selection.PSObject.Properties['Run']) { [bool]$selection.Run } elseif ($selection.PSObject.Properties['State']) { ([string]$selection.State -match '^(?i:on|true|1)$') } else { $null }
		}

		if ([string]::IsNullOrWhiteSpace($functionName)) { continue }

		$entry = [ordered]@{
			Function = $functionName
			Type     = $entryType
		}

		switch ($entryType)
		{
			'Choice'
			{
				$entry.Value = $value
				$entry.Category = $category
			}
			'NumericRange'
			{
				$entry.Value = $value
				$entry.Category = $category
				if ($selection -is [System.Collections.IDictionary])
				{
					foreach ($fieldName in @('NumericValue', 'ACValue', 'DCValue', 'Units'))
					{
						if ($selection.Contains($fieldName))
						{
							$entry[$fieldName] = $selection[$fieldName]
						}
					}
				}
				elseif ($selection -is [pscustomobject] -or ($null -ne $selection.PSObject))
				{
					foreach ($fieldName in @('NumericValue', 'ACValue', 'DCValue', 'Units'))
					{
						if ($selection.PSObject.Properties[$fieldName])
						{
							$entry[$fieldName] = $selection.$fieldName
						}
					}
				}
			}
			'Date'
			{
				$entry.Run = if ($null -eq $runFlag) { [bool]$value } else { [bool]$runFlag }
				$entry.Value = $value
				$entry.Category = $category
				if ($selection -is [System.Collections.IDictionary] -and $selection.Contains('DateParam'))
				{
					$entry.DateParam = [string]$selection['DateParam']
				}
				elseif ($selection -is [pscustomobject] -and $selection.PSObject.Properties['DateParam'])
				{
					$entry.DateParam = [string]$selection.DateParam
				}
			}
			default
			{
				$entry.Param = if (-not [string]::IsNullOrWhiteSpace($param)) { $param } else { $null }
				$entry.Category = $category
			}
		}

		$entries.Add($entry)
	}

	$appActionEntries = [System.Collections.Generic.List[ordered]]::new()
	foreach ($appAction in @($AppActions))
	{
		if ($null -eq $appAction) { continue }

		$appId = $null
		$action = $null
		$name = $null
		$winGetId = $null
		$chocoId = $null

		if ($appAction -is [System.Collections.IDictionary])
		{
			$appId = if ($appAction.Contains('AppId')) { [string]$appAction['AppId'] } elseif ($appAction.Contains('SelectionKey')) { [string]$appAction['SelectionKey'] } else { $null }
			$action = if ($appAction.Contains('Action')) { [string]$appAction['Action'] } else { $null }
			$name = if ($appAction.Contains('Name')) { [string]$appAction['Name'] } else { $null }
			$winGetId = if ($appAction.Contains('WinGetId')) { [string]$appAction['WinGetId'] } else { $null }
			$chocoId = if ($appAction.Contains('ChocoId')) { [string]$appAction['ChocoId'] } else { $null }
		}
		elseif ($appAction -is [pscustomobject] -or ($null -ne $appAction.PSObject))
		{
			$appId = if ($appAction.PSObject.Properties['AppId']) { [string]$appAction.AppId } elseif ($appAction.PSObject.Properties['SelectionKey']) { [string]$appAction.SelectionKey } else { $null }
			$action = if ($appAction.PSObject.Properties['Action']) { [string]$appAction.Action } else { $null }
			$name = if ($appAction.PSObject.Properties['Name']) { [string]$appAction.Name } else { $null }
			$winGetId = if ($appAction.PSObject.Properties['WinGetId']) { [string]$appAction.WinGetId } else { $null }
			$chocoId = if ($appAction.PSObject.Properties['ChocoId']) { [string]$appAction.ChocoId } else { $null }
		}

		if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($action))
		{
			continue
		}

		$normalizedAction = [string]$action.Trim()
		if ($normalizedAction -notin @('Install', 'Uninstall'))
		{
			continue
		}

		$appActionEntries.Add([ordered]@{
			AppId = [string]$appId
			Action = $normalizedAction
			Name = $name
			WinGetId = $winGetId
			ChocoId = $chocoId
		}) | Out-Null
	}

	$profile = [ordered]@{
		Schema             = $Script:ConfigProfileSchema
		SchemaVersion      = $Script:ConfigProfileSchemaVersion
		Name               = $Name
		Description        = if (-not [string]::IsNullOrWhiteSpace($Description)) { $Description } else { $null }
		CreatedAt          = [System.DateTime]::UtcNow.ToString('o')
		BaselineVersion    = $BaselineVersion
		SourceMachine      = $env:COMPUTERNAME
		AppsPackageSourcePreference = if (-not [string]::IsNullOrWhiteSpace($AppsPackageSourcePreference)) { [string]$AppsPackageSourcePreference } else { $null }
		TargetRequirements = [ordered]@{
			MinBuild = $minBuild
			Edition  = $edition
		}
		Entries            = @($entries)
		AppActions         = @($appActionEntries)
	}

	return [pscustomobject]$profile
}

<#
    .SYNOPSIS
    Internal function Export-ConfigurationProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Export-ConfigurationProfile
{
	<#
		.SYNOPSIS
		Writes a configuration profile object to a JSON file using UTF-8 no BOM.
	#>
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param (
		[Parameter(Mandatory)]
		[object]$Profile,

		[Parameter(Mandatory)]
		[string]$FilePath
	)

	$parentDir = Split-Path -Path $FilePath -Parent
	if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir))
	{
		[void](New-Item -Path $parentDir -ItemType Directory -Force)
	}

	$json = ConvertTo-Json -InputObject $Profile -Depth 16
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($FilePath, $json, $utf8NoBom)
}

<#
    .SYNOPSIS
    Internal function Import-ConfigurationProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Import-ConfigurationProfile
{
	<#
		.SYNOPSIS
		Reads a configuration profile from a JSON file and validates the schema.

		.DESCRIPTION
		Parses the JSON file, checks that the Schema field matches
		'Baseline.ConfigProfile' and that SchemaVersion is at least 1, and
		returns the profile object. Throws on missing file or invalid schema.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$FilePath
	)

	if (-not (Test-Path -LiteralPath $FilePath))
	{
		throw "Configuration profile not found: $FilePath"
	}

	try
	{
		$content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
		$document = $content | ConvertFrom-BaselineJson -Depth 16
	}
	catch
	{
		throw "Failed to read or parse configuration profile '$FilePath': $_"
	}

	# Validate schema field.
	$actualSchema = if ($document.PSObject.Properties['Schema']) { [string]$document.Schema } else { $null }
	if ($actualSchema -ne $Script:ConfigProfileSchema)
	{
		throw "Schema mismatch in '$FilePath': expected '$($Script:ConfigProfileSchema)', found '$actualSchema'."
	}

	# Validate minimum schema version.
	$actualVersion = if ($document.PSObject.Properties['SchemaVersion']) { [int]$document.SchemaVersion } else { 0 }
	if ($actualVersion -lt 1)
	{
		throw "Unsupported schema version $actualVersion in '$FilePath'. Minimum supported version is 1."
	}

	# Validate required fields.
	if (-not $document.PSObject.Properties['Entries'] -and -not $document.PSObject.Properties['AppActions'])
	{
		throw "Configuration profile '$FilePath' is missing the required 'Entries' or 'AppActions' field."
	}

	return $document
}

<#
    .SYNOPSIS
    Internal function Test-ConfigurationProfileCompatibility.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Test-ConfigurationProfileCompatibility
{
	<#
		.SYNOPSIS
		Checks whether the current system meets the target requirements of a profile.

		.DESCRIPTION
		Compares the profile's TargetRequirements (MinBuild, Edition) against the
		running system and returns an object with a Compatible flag and any warnings.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object]$Profile
	)

	$warnings = [System.Collections.Generic.List[string]]::new()
	$compatible = $true

	$requirements = if ($Profile.PSObject.Properties['TargetRequirements']) { $Profile.TargetRequirements } else { $null }
	if ($null -eq $requirements)
	{
		return [pscustomobject]@{
			Compatible = $true
			Warnings   = @()
		}
	}

	# Check Windows build number.
	$requiredBuild = 0
	if ($requirements.PSObject.Properties['MinBuild'])
	{
		[void][int]::TryParse([string]$requirements.MinBuild, [ref]$requiredBuild)
	}

	$currentBuild = 0
	try
	{
		$versionData = Get-WindowsVersionData
		if ($versionData -and $versionData.CurrentBuild)
		{
			[void][int]::TryParse([string]$versionData.CurrentBuild, [ref]$currentBuild)
		}
	}
	catch { }

	if ($requiredBuild -gt 0 -and $currentBuild -gt 0 -and $currentBuild -lt $requiredBuild)
	{
		$compatible = $false
		$warnings.Add("Profile requires Windows build $requiredBuild or later, current build is $currentBuild.")
	}
	elseif ($requiredBuild -gt 0 -and $currentBuild -gt 0 -and $currentBuild -ne $requiredBuild)
	{
		$warnings.Add("Profile created for build $requiredBuild, current is $currentBuild.")
	}

	# Check Windows edition.
	if ($requirements.PSObject.Properties['Edition'] -and -not [string]::IsNullOrWhiteSpace([string]$requirements.Edition))
	{
		$allowedEditions = [string]$requirements.Edition
		$currentEdition = $null
		try
		{
			$currentVersion = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
			if ($currentVersion -and $currentVersion.PSObject.Properties['EditionID'])
			{
				$currentEdition = [string]$currentVersion.EditionID
			}
		}
		catch { }

		if (-not [string]::IsNullOrWhiteSpace($currentEdition))
		{
			$editionList = $allowedEditions -split '\|' | ForEach-Object { $_.Trim() }
			$editionMatch = $false
			foreach ($allowed in $editionList)
			{
				if ($currentEdition -eq $allowed)
				{
					$editionMatch = $true
					break
				}
			}

			if (-not $editionMatch)
			{
				$warnings.Add("Profile targets edition(s) '$allowedEditions', current edition is '$currentEdition'.")
			}
		}
	}

	return [pscustomobject]@{
		Compatible = $compatible
		Warnings   = @($warnings)
	}
}

<#
    .SYNOPSIS
    Internal function Compare-ConfigurationProfiles.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Compare-ConfigurationProfiles
{
	<#
		.SYNOPSIS
		Compares two configuration profiles and returns differences.

		.DESCRIPTION
		Examines the Entries arrays of both profiles and categorises each entry as
		OnlyInA, OnlyInB, Different (present in both but with different parameters),
		or Same.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object]$ProfileA,

		[Parameter(Mandatory)]
		[object]$ProfileB
	)

	$entriesA = @()
	if ($ProfileA.PSObject.Properties['Entries'] -and $null -ne $ProfileA.Entries)
	{
		$entriesA = @($ProfileA.Entries)
	}

	$entriesB = @()
	if ($ProfileB.PSObject.Properties['Entries'] -and $null -ne $ProfileB.Entries)
	{
		$entriesB = @($ProfileB.Entries)
	}

	# Index entries by Function name for O(n) comparison.
	$indexA = [ordered]@{}
	foreach ($entry in $entriesA)
	{
		if ($null -eq $entry) { continue }
		$fn = if ($entry.PSObject.Properties['Function']) { [string]$entry.Function } else { $null }
		if (-not [string]::IsNullOrWhiteSpace($fn))
		{
			$indexA[$fn] = $entry
		}
	}

	$indexB = [ordered]@{}
	foreach ($entry in $entriesB)
	{
		if ($null -eq $entry) { continue }
		$fn = if ($entry.PSObject.Properties['Function']) { [string]$entry.Function } else { $null }
		if (-not [string]::IsNullOrWhiteSpace($fn))
		{
			$indexB[$fn] = $entry
		}
	}

	$onlyInA = [System.Collections.Generic.List[object]]::new()
	$onlyInB = [System.Collections.Generic.List[object]]::new()
	$different = [System.Collections.Generic.List[object]]::new()
	$same = [System.Collections.Generic.List[object]]::new()

	foreach ($fn in $indexA.Keys)
	{
		$entryA = $indexA[$fn]
		if ($indexB.Contains($fn))
		{
			$entryB = $indexB[$fn]
			if ((Get-ProfileEntryComparisonKey $entryA) -eq (Get-ProfileEntryComparisonKey $entryB))
			{
				$same.Add($entryA)
			}
			else
			{
				$different.Add([pscustomobject]@{
					Function = $fn
					InA      = $entryA
					InB      = $entryB
				})
			}
		}
		else
		{
			$onlyInA.Add($entryA)
		}
	}

	foreach ($fn in $indexB.Keys)
	{
		if (-not $indexA.Contains($fn))
		{
			$onlyInB.Add($indexB[$fn])
		}
	}

	return [pscustomobject]@{
		OnlyInA   = @($onlyInA)
		OnlyInB   = @($onlyInB)
		Different = @($different)
		Same      = @($same)
	}
}

<#
    .SYNOPSIS
    Internal function Get-ProfileEntryComparisonKey.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function Get-ProfileEntryComparisonKey
{
	<# .SYNOPSIS Builds a normalised comparison string for a profile entry. #>
	param ([object]$Entry)

	if ($null -eq $Entry) { return '' }

	$type = if ($Entry.PSObject.Properties['Type']) { [string]$Entry.Type } else { 'Toggle' }
	$fn = if ($Entry.PSObject.Properties['Function']) { [string]$Entry.Function } else { '' }

		switch ($type)
		{
			'Choice'
			{
				$val = if ($Entry.PSObject.Properties['Value']) { ConvertTo-ConfigurationProfileValueText -Value $Entry.Value } else { '' }
				return "$fn|Choice|$val"
			}
			'NumericRange'
			{
				$val = if ($Entry.PSObject.Properties['Value']) { ConvertTo-ConfigurationProfileValueText -Value $Entry.Value }
					elseif ($Entry.PSObject.Properties['NumericValue']) { ConvertTo-ConfigurationProfileValueText -Value $Entry.NumericValue }
					elseif ($Entry.PSObject.Properties['ACValue'] -or $Entry.PSObject.Properties['DCValue']) { ConvertTo-ConfigurationProfileValueText -Value $Entry }
					else { '' }
				return "$fn|NumericRange|$val"
			}
			'Date'
			{
				$run = if ($Entry.PSObject.Properties['Run']) { [bool]$Entry.Run } else { $false }
				$val = if ($Entry.PSObject.Properties['Value']) { ConvertTo-ConfigurationProfileValueText -Value $Entry.Value } else { '' }
				return "$fn|Date|$run|$val"
			}
			default
			{
			$param = if ($Entry.PSObject.Properties['Param']) { [string]$Entry.Param } else { '' }
			return "$fn|Toggle|$param"
		}
	}
}

<#
    .SYNOPSIS
    Internal function ConvertFrom-PresetToProfile.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>

function ConvertFrom-PresetToProfile
{
	<#
		.SYNOPSIS
		Converts an existing preset file into a configuration profile.

		.DESCRIPTION
		Reads the preset JSON from Module/Data/Presets/{PresetName}.json, resolves
		each command line against the manifest, and returns a full configuration
		profile object. This bridges the legacy preset system with the new profile
		system.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$PresetName,

		[Parameter(Mandatory)]
		[array]$Manifest,

		[string]$ModuleRoot
	)

	# Load the preset command list using the existing helper.
	$commandList = Get-HeadlessPresetCommandList -PresetName $PresetName -ModuleRoot $ModuleRoot

	# Resolve each command line into a selection object.
	$selections = [System.Collections.Generic.List[ordered]]::new()
	foreach ($commandLine in @($commandList))
	{
		if ([string]::IsNullOrWhiteSpace([string]$commandLine)) { continue }

		$parts = ([string]$commandLine).Trim() -split '\s+', 2
		$functionName = $parts[0]
		$paramRaw = if ($parts.Count -gt 1) { $parts[1] } else { $null }
		$paramName = if (-not [string]::IsNullOrWhiteSpace($paramRaw)) { $paramRaw.TrimStart('-') } else { $null }

		if ([string]::IsNullOrWhiteSpace($functionName)) { continue }

		$manifestEntry = Get-ManifestEntryByFunction -Manifest $Manifest -Function $functionName
		$category = if ($manifestEntry -and $manifestEntry.PSObject.Properties['Category']) { [string]$manifestEntry.Category } else { $null }
		$type = if ($manifestEntry -and $manifestEntry.PSObject.Properties['Type']) { [string]$manifestEntry.Type } else { 'Toggle' }

		$selection = [ordered]@{
			Function = $functionName
			Type     = $type
			Category = $category
		}

		switch ($type)
		{
			'Choice'
			{
				$selection.SelectedValue = $paramName
			}
			'NumericRange'
			{
				$acValue = $null
				$dcValue = $null
				$scalarValue = $null

				for ($i = 1; $i -lt $tokens.Count - 1; $i++)
				{
					$token = [string]$tokens[$i]
					if (-not $token.StartsWith('-'))
					{
						continue
					}

					$tokenName = $token.TrimStart('-')
					$tokenValue = [string]$tokens[$i + 1]
					switch ($tokenName)
					{
						'Value' { $scalarValue = $tokenValue }
						'NumericValue' { $scalarValue = $tokenValue }
						'ACValue' { $acValue = $tokenValue }
						'DCValue' { $dcValue = $tokenValue }
					}
				}

				if ($null -ne $acValue -or $null -ne $dcValue)
				{
					if ($null -ne $acValue)
					{
						$selection.ACValue = $acValue
					}
					if ($null -ne $dcValue)
					{
						$selection.DCValue = $dcValue
					}
					$selection.Value = [ordered]@{
						ACValue = $acValue
						DCValue = if ($null -ne $dcValue) { $dcValue } else { $acValue }
					}
				}
				elseif (-not [string]::IsNullOrWhiteSpace($scalarValue))
				{
					$selection.Value = $scalarValue
					$selection.NumericValue = $scalarValue
				}
				elseif (-not [string]::IsNullOrWhiteSpace($paramName))
				{
					$selection.Value = $paramName
				}
			}
			'Date'
			{
				$selection.Run = $true
				if (-not [string]::IsNullOrWhiteSpace($paramName) -and $commandLine -match '(?i)-StartDate\s+(\S+)')
				{
					$selection.DateParam = if ($manifestEntry -and $manifestEntry.PSObject.Properties['DateParam']) { [string]$manifestEntry.DateParam } else { 'StartDate' }
					$selection.Value = [string]$matches[1]
				}
				else
				{
					$selection.Value = $paramName
				}
			}
			default
			{
				$selection.ToggleParam = $paramName
			}
		}

		$selections.Add($selection)
	}

	# Resolve Baseline version.
	$baselineVersion = $null
	if (Get-Command -Name 'Get-BaselineDisplayVersion' -ErrorAction SilentlyContinue)
	{
		try { $baselineVersion = Get-BaselineDisplayVersion } catch { }
	}
	if ([string]::IsNullOrWhiteSpace($baselineVersion))
	{
		$baselineVersion = 'unknown'
	}

	return New-ConfigurationProfile `
		-Name $PresetName `
		-Selections @($selections) `
		-BaselineVersion $baselineVersion `
		-Description "Profile converted from preset '$PresetName'."
}
