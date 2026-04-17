<#
    .SYNOPSIS
    Internal function Test-GuiObjectField.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Test-GuiObjectField
{
	param([object]$Object, [string]$FieldName)
	if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($FieldName)) { return $false }
	if ($Object -is [System.Collections.IDictionary]) { return [bool]$Object.Contains($FieldName) }
	return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName])
}

<#
    .SYNOPSIS
    Internal function Get-GuiObjectField.

    .DESCRIPTION
    Internal implementation helper used by Baseline.
#>
function Get-GuiObjectField
{
	param([object]$Object, [string]$FieldName)
	if (-not (Test-GuiObjectField -Object $Object -FieldName $FieldName)) { return $null }
	if ($Object -is [System.Collections.IDictionary]) { return $Object[$FieldName] }
	return $Object.$FieldName
}
