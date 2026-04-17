<#
    .SYNOPSIS
    Internal function Test-GuiCommonUniqueAdd.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Test-GuiCommonUniqueAdd
{
	param(
		[Parameter(Mandatory = $true)]
		[object]$HashSet,

		[Parameter(Mandatory = $true)]
		[object]$SyncRoot,

		[Parameter(Mandatory = $true)]
		[string]$Value
	)

	if ([string]::IsNullOrWhiteSpace($Value))
	{
		return $false
	}

	if ($null -eq $HashSet)
	{
		return $false
	}

	$lockTaken = $false
	try
	{
		[System.Threading.Monitor]::Enter($SyncRoot, [ref]$lockTaken)
		return $HashSet.Add($Value)
	}
	finally
	{
		if ($lockTaken)
		{
			[System.Threading.Monitor]::Exit($SyncRoot)
		}
	}
}

<#
    .SYNOPSIS
    Internal function Get-GuiBooleanValue.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-GuiBooleanValue
{
	param(
		[Parameter(Mandatory = $false)]
		[object]$Value,

		[bool]$Default = $false,

		[string]$Context = 'GUI'
	)

	if ($null -eq $Value)
	{
		return $Default
	}

	if ($Value -is [bool])
	{
		return [bool]$Value
	}

	if ($Value -is [System.Management.Automation.SwitchParameter])
	{
		return [bool]$Value
	}

	$text = [string]$Value
	if ([string]::IsNullOrWhiteSpace($text))
	{
		return $Default
	}

	$trimmed = $text.Trim()
	$parsedBool = $false
	if ([bool]::TryParse($trimmed, [ref]$parsedBool))
	{
		return $parsedBool
	}

	$parsedNumber = 0.0
	if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedNumber))
	{
		return ($parsedNumber -ne 0)
	}

	switch ($trimmed.ToLowerInvariant())
	{
		'yes' { return $true }
		'on' { return $true }
		'enabled' { return $true }
		'no' { return $false }
		'off' { return $false }
		'disabled' { return $false }
	}

	Write-GuiCommonWarning ("Invalid boolean value '{0}'{1}. Using fallback {2}." -f $trimmed, $(if ([string]::IsNullOrWhiteSpace($Context)) { '' } else { " for $Context" }), $Default)
	return $Default
}

<#
    .SYNOPSIS
    Internal function Write-GuiCommonWarning.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Write-GuiCommonWarning
{
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	if ([string]::IsNullOrWhiteSpace($Message))
	{
		return
	}

	$shouldLog = $true
	if ($Script:GuiCommonWarnings)
	{
		try
		{
			$shouldLog = Test-GuiCommonUniqueAdd -HashSet $Script:GuiCommonWarnings -SyncRoot $Script:GuiCommonWarningsSyncRoot -Value $Message
		}
		catch
		{
			$shouldLog = $true
		}
	}

	if ($shouldLog)
	{
		LogWarning $Message
	}
}
