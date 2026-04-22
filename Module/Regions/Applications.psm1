using module ..\Logging.psm1
using module ..\SharedHelpers.psm1

#region Applications

<#
    .SYNOPSIS
    Internal function Test-ApplicationCatalogField.
#>

function Test-ApplicationCatalogField
{
	param (
		[object]$Object,
		[string]$FieldName
	)

	if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($FieldName))
	{
		return $false
	}

	if ($Object -is [System.Collections.IDictionary])
	{
		return $Object.Contains($FieldName)
	}

	return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName])
}

<#
    .SYNOPSIS
    Internal function Get-ApplicationCatalogFieldValue.
#>

function Get-ApplicationCatalogFieldValue
{
	param (
		[object]$Object,
		[string]$FieldName
	)

	if (-not (Test-ApplicationCatalogField -Object $Object -FieldName $FieldName))
	{
		return $null
	}

	if ($Object -is [System.Collections.IDictionary])
	{
		return $Object[$FieldName]
	}

	return $Object.$FieldName
}

<#
    .SYNOPSIS
    Internal function Get-PackageManagerAvailabilityStateValue.
#>

function Get-PackageManagerAvailabilityStateValue
{
	param (
		[object]$AvailabilityState,
		[string]$PropertyName
	)

	if (-not $AvailabilityState -or [string]::IsNullOrWhiteSpace($PropertyName))
	{
		return $null
	}

	if ($AvailabilityState -is [System.Collections.IDictionary])
	{
		if ($AvailabilityState.Contains($PropertyName))
		{
			return $AvailabilityState[$PropertyName]
		}

		return $null
	}

	if ($AvailabilityState.PSObject.Properties[$PropertyName])
	{
		return $AvailabilityState.$PropertyName
	}

	return $null
}

<#
    .SYNOPSIS
    Internal function Resolve-ApplicationExecutionRoute.
#>

function Resolve-ApplicationExecutionRoute
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$Application,

		[string]$PreferredSource = $null,

		[object]$PackageManagerAvailabilityState = $null,

		[ValidateSet('Install', 'Uninstall', 'Update')]
		[string]$Action = 'Install'
	)

	$validRouteTypes = @('winget', 'choco', 'uwp', 'feature', 'system', 'placeholder')
	$normalizedPreferredSource = if ([string]::IsNullOrWhiteSpace([string]$PreferredSource))
	{
		'winget'
	}
	else
	{
		switch ([string]$PreferredSource.Trim().ToLowerInvariant())
		{
			'winget' { 'winget' }
			'choco' { 'choco' }
			'chocolatey' { 'choco' }
			default { 'winget' }
		}
	}
	$normalizedAction = if ([string]::IsNullOrWhiteSpace([string]$Action)) { 'Install' } else { [string]$Action }

	$entityType = [string](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'EntityType')
	if ([string]::IsNullOrWhiteSpace($entityType))
	{
		$entityType = [string](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'Type')
	}
	$entityType = if ([string]::IsNullOrWhiteSpace($entityType)) { $null } else { [string]$entityType.Trim().ToLowerInvariant() }
	if ($entityType -and ($validRouteTypes -notcontains $entityType))
	{
		$entityType = $null
	}

	$displayName = [string](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'Name')
	if ([string]::IsNullOrWhiteSpace($displayName))
	{
		$displayName = 'Unknown application'
	}

	$extraArgs = Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'ExtraArgs'
	$winGetId = [string](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'WinGetId')
	if ([string]::IsNullOrWhiteSpace($winGetId))
	{
		$winGetId = [string](Get-ApplicationCatalogFieldValue -Object $extraArgs -FieldName 'WinGetId')
	}

	$chocoId = [string](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'ChocoId')
	if ([string]::IsNullOrWhiteSpace($chocoId))
	{
		$chocoId = [string](Get-ApplicationCatalogFieldValue -Object $extraArgs -FieldName 'ChocoId')
	}

	$storeUri = [string](Get-ApplicationCatalogFieldValue -Object $extraArgs -FieldName 'StoreUri')
	$directUrl = [string](Get-ApplicationCatalogFieldValue -Object $extraArgs -FieldName 'DirectUrl')
	$command = [string](Get-ApplicationCatalogFieldValue -Object $extraArgs -FieldName 'Command')

	$selectionKey = $null
	if (Get-Command -Name 'Get-ApplicationCatalogIdentityKey' -CommandType Function -ErrorAction SilentlyContinue)
	{
		try
		{
			$selectionKey = [string](Get-ApplicationCatalogIdentityKey -Entry $Application)
		}
		catch
		{
			$selectionKey = $null
		}
	}
	if ([string]::IsNullOrWhiteSpace($selectionKey))
	{
		if (-not [string]::IsNullOrWhiteSpace($winGetId))
		{
			$selectionKey = "winget:{0}" -f [string]$winGetId.Trim().ToLowerInvariant()
		}
		elseif (-not [string]::IsNullOrWhiteSpace($chocoId))
		{
			$selectionKey = "choco:{0}" -f [string]$chocoId.Trim().ToLowerInvariant()
		}
		elseif (-not [string]::IsNullOrWhiteSpace([string]$displayName))
		{
			$selectionKey = [string]$displayName.Trim().ToLowerInvariant()
		}
		else
			{
				$selectionKey = 'application'
			}
	}

	$supportsExecution = if (Test-ApplicationCatalogField -Object $Application -FieldName 'SupportsExecution')
	{
		[bool](Get-ApplicationCatalogFieldValue -Object $Application -FieldName 'SupportsExecution')
	}
	else
	{
		$true
	}

	$availableSources = [System.Collections.Generic.List[string]]::new()
	if (-not [string]::IsNullOrWhiteSpace($winGetId)) { [void]$availableSources.Add('winget') }
	if (-not [string]::IsNullOrWhiteSpace($chocoId)) { [void]$availableSources.Add('choco') }
	if (-not [string]::IsNullOrWhiteSpace($storeUri)) { [void]$availableSources.Add('store') }
	if (-not [string]::IsNullOrWhiteSpace($directUrl)) { [void]$availableSources.Add('direct') }
	if (-not [string]::IsNullOrWhiteSpace($command)) { [void]$availableSources.Add('command') }

	$wingetAvailable = $true
	$hasWingetAvailabilityState = $false
	if ($PackageManagerAvailabilityState -is [System.Collections.IDictionary])
	{
		$hasWingetAvailabilityState = $PackageManagerAvailabilityState.Contains('WinGetAvailable')
	}
	elseif ($PackageManagerAvailabilityState -and $PackageManagerAvailabilityState.PSObject.Properties['WinGetAvailable'])
	{
		$hasWingetAvailabilityState = $true
	}
	if ($hasWingetAvailabilityState)
	{
		$wingetAvailable = [bool]$PackageManagerAvailabilityState.WinGetAvailable
	}
	elseif (-not [string]::IsNullOrWhiteSpace($winGetId) -and (Get-Command -Name 'Test-WinGetAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$wingetAvailable = [bool](Test-WinGetAvailable)
		}
		catch
		{
			$wingetAvailable = $false
		}
	}

	$chocolateyAvailable = $true
	$hasChocolateyAvailabilityState = $false
	if ($PackageManagerAvailabilityState -is [System.Collections.IDictionary])
	{
		$hasChocolateyAvailabilityState = $PackageManagerAvailabilityState.Contains('ChocolateyAvailable')
	}
	elseif ($PackageManagerAvailabilityState -and $PackageManagerAvailabilityState.PSObject.Properties['ChocolateyAvailable'])
	{
		$hasChocolateyAvailabilityState = $true
	}
	if ($hasChocolateyAvailabilityState)
	{
		$chocolateyAvailable = [bool]$PackageManagerAvailabilityState.ChocolateyAvailable
	}
	elseif (-not [string]::IsNullOrWhiteSpace($chocoId) -and (Get-Command -Name 'Test-ChocolateyAvailable' -CommandType Function -ErrorAction SilentlyContinue))
	{
		try
		{
			$chocolateyAvailable = [bool](Test-ChocolateyAvailable)
		}
		catch
		{
			$chocolateyAvailable = $false
		}
	}

	$route = 'unsupported'
	$selectedSource = $null
	$packageId = $null
	$reason = $null

	switch ($entityType)
	{
		'uwp'
		{
			$reason = "Application '$displayName' is tagged as UWP, but no UWP execution adapter is registered yet."
		}
		'feature'
		{
			$reason = "Application '$displayName' is tagged as a Windows feature, but no feature execution adapter is registered yet."
		}
		'system'
		{
			$reason = "Application '$displayName' is tagged as a system component, but no system execution adapter is registered yet."
		}
		'placeholder'
		{
			$reason = "No install method available for $displayName."
		}
		default
		{
			$reason = $null
		}
	}

	if (-not $reason)
	{
		if ($normalizedPreferredSource -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
		{
			$route = 'winget'
			$selectedSource = 'winget'
			$packageId = [string]$winGetId
		}
		elseif ($normalizedPreferredSource -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
		{
			$route = 'choco'
			$selectedSource = 'choco'
			$packageId = [string]$chocoId
		}
		elseif ($entityType -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($winGetId))
		{
			$route = 'winget'
			$selectedSource = 'winget'
			$packageId = [string]$winGetId
		}
		elseif ($entityType -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($chocoId))
		{
			$route = 'choco'
			$selectedSource = 'choco'
			$packageId = [string]$chocoId
		}
		elseif (-not [string]::IsNullOrWhiteSpace($winGetId))
		{
			$route = 'winget'
			$selectedSource = 'winget'
			$packageId = [string]$winGetId
		}
		elseif (-not [string]::IsNullOrWhiteSpace($chocoId))
		{
			$route = 'choco'
			$selectedSource = 'choco'
			$packageId = [string]$chocoId
		}
		elseif ($normalizedAction -eq 'Install')
		{
			if (-not [string]::IsNullOrWhiteSpace($storeUri))
			{
				$route = 'store'
				$selectedSource = 'store'
				$packageId = [string]$storeUri
			}
			elseif (-not [string]::IsNullOrWhiteSpace($directUrl))
			{
				$route = 'direct'
				$selectedSource = 'direct'
				$packageId = [string]$directUrl
			}
			elseif (-not [string]::IsNullOrWhiteSpace($command))
			{
				$route = 'command'
				$selectedSource = 'command'
				$packageId = [string]$command
			}
			else
			{
				if ($entityType -eq 'winget' -and [string]::IsNullOrWhiteSpace($winGetId))
				{
					$reason = "Application '$displayName' is tagged as WinGet, but does not define a WinGetId."
				}
				elseif ($entityType -eq 'choco' -and [string]::IsNullOrWhiteSpace($chocoId))
				{
					$reason = "Application '$displayName' is tagged as Chocolatey, but does not define a ChocoId."
				}
				else
				{
					$reason = "Application '$displayName' does not define an execution route."
				}
			}
		}
		else
		{
			if ($entityType -eq 'winget' -and [string]::IsNullOrWhiteSpace($winGetId))
			{
				$reason = "Application '$displayName' is tagged as WinGet, but does not define a WinGetId."
			}
			elseif ($entityType -eq 'choco' -and [string]::IsNullOrWhiteSpace($chocoId))
			{
				$reason = "Application '$displayName' is tagged as Chocolatey, but does not define a ChocoId."
			}
			else
			{
				$reason = "Application '$displayName' does not define an execution route."
			}
		}
	}

	if ($route -eq 'winget')
	{
		if (-not $wingetAvailable)
		{
			if (-not [string]::IsNullOrWhiteSpace($chocoId) -and $chocolateyAvailable)
			{
				$route = 'choco'
				$selectedSource = 'choco'
				$packageId = [string]$chocoId
				$reason = $null
			}
			else
			{
				$route = 'unsupported'
				$selectedSource = $null
				$packageId = $null
				if (-not [string]::IsNullOrWhiteSpace($chocoId) -and -not $chocolateyAvailable)
				{
					$reason = Get-BaselineLocalizedString -Key 'Progress_PackageManagerUnavailable' -Fallback 'Neither WinGet nor Chocolatey is available on this system.'
				}
				else
				{
					$reason = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
				}
				$supportsExecution = $false
			}
		}
	}
	elseif ($route -eq 'choco' -and -not $chocolateyAvailable)
	{
		if (-not [string]::IsNullOrWhiteSpace($winGetId) -and $wingetAvailable)
		{
			$route = 'winget'
			$selectedSource = 'winget'
			$packageId = [string]$winGetId
			$reason = $null
		}
		else
		{
			$route = 'unsupported'
			$selectedSource = $null
			$packageId = $null
			if (-not [string]::IsNullOrWhiteSpace($winGetId) -and -not $wingetAvailable)
			{
				$reason = Get-BaselineLocalizedString -Key 'Progress_PackageManagerUnavailable' -Fallback 'Neither Chocolatey nor WinGet is available on this system.'
			}
			else
			{
				$reason = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			}
			$supportsExecution = $false
		}
	}

	if (-not $supportsExecution -and $route -ne 'unsupported')
	{
		$route = 'unsupported'
		$selectedSource = $null
		$packageId = $null
		$reason = "Application '$displayName' is marked as not supporting execution."
	}

	if ($route -eq 'unsupported' -and [string]::IsNullOrWhiteSpace($reason))
	{
		if ($entityType -eq 'winget' -and [string]::IsNullOrWhiteSpace($winGetId))
		{
			$reason = "Application '$displayName' is tagged as WinGet, but does not define a WinGetId."
		}
		elseif ($entityType -eq 'choco' -and [string]::IsNullOrWhiteSpace($chocoId))
		{
			$reason = "Application '$displayName' is tagged as Chocolatey, but does not define a ChocoId."
		}
		else
		{
			$reason = "Application '$displayName' is not executable."
		}
	}

	$identityKey = if (-not [string]::IsNullOrWhiteSpace($selectionKey))
	{
		[string]$selectionKey.Trim().ToLowerInvariant()
	}
	elseif ($route -eq 'winget' -and -not [string]::IsNullOrWhiteSpace($packageId))
	{
		"winget:{0}" -f [string]$packageId.Trim().ToLowerInvariant()
	}
	elseif ($route -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($packageId))
	{
		"choco:{0}" -f [string]$packageId.Trim().ToLowerInvariant()
	}
	else
	{
		"name:{0}" -f [string]$displayName.Trim().ToLowerInvariant()
	}

	return [pscustomobject]@{
		EntityType = $entityType
		Route = $route
		SelectedSource = $selectedSource
		PreferredSource = $normalizedPreferredSource
		AvailableSources = @($availableSources)
		PackageId = $packageId
		DisplayName = $displayName
		SupportsExecution = [bool]$supportsExecution
		IdentityKey = $identityKey
		SelectionKey = $selectionKey
		Reason = $reason
		WinGetId = $winGetId
		ChocoId = $chocoId
		StoreUri = $storeUri
		DirectUrl = $directUrl
		Command = $command
	}
}

<#
    .SYNOPSIS
    Internal function Save-ChocolateyBootstrapScript.
#>

function Save-ChocolateyBootstrapScript
{
	[CmdletBinding()]
	param()

	$bootstrapScriptUrl = 'https://community.chocolatey.org/install.ps1'
	$bootstrapScriptPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("baseline-choco-bootstrap-{0}.ps1" -f [System.Guid]::NewGuid().ToString('N'))
	$webClient = New-Object System.Net.WebClient

	try
	{
		$webClient.DownloadFile($bootstrapScriptUrl, $bootstrapScriptPath)
		return $bootstrapScriptPath
	}
	finally
	{
		$webClient.Dispose()
	}
}

<#
    .SYNOPSIS
    Internal function Test-BaselineEnvironmentFlagEnabled.
#>

function Test-BaselineEnvironmentFlagEnabled
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name
	)

	$rawValue = [System.Environment]::GetEnvironmentVariable($Name)
	if ([string]::IsNullOrWhiteSpace($rawValue))
	{
		return $false
	}

	switch ($rawValue.Trim().ToLowerInvariant())
	{
		'1' { return $true }
		'true' { return $true }
		'yes' { return $true }
		'on' { return $true }
		default { return $false }
	}
}

<#
    .SYNOPSIS
    Internal function Test-ChocolateyBootstrapInteractiveHost.
#>

function Test-ChocolateyBootstrapInteractiveHost
{
	[CmdletBinding()]
	param(
		[Parameter()]
		[object]$HostInstance = $Host,

		[Parameter()]
		[Nullable[bool]]$UserInteractive = $null
	)

	try
	{
		if ($null -eq $HostInstance -or $null -eq $HostInstance.UI)
		{
			return $false
		}

		# Known non-interactive hosts whose PromptForChoice implementation throws
		# NotSupportedException: BaselineHost (launcher), ServerRemoteHost (PSRemoting),
		# Default Host (various automation contexts). RawUI presence is not enough —
		# BaselineHost exposes RawUI but rejects PromptForChoice.
		$nonInteractiveHostNames = @('BaselineHost', 'ServerRemoteHost', 'Default Host')
		if ($HostInstance.Name -and ($nonInteractiveHostNames -contains [string]$HostInstance.Name))
		{
			return $false
		}

		$isUserInteractive = if ($null -ne $UserInteractive) { [bool]$UserInteractive } else { [Environment]::UserInteractive }
		if (-not $isUserInteractive)
		{
			return $false
		}

		$null = $HostInstance.UI.RawUI
		return $true
	}
	catch
	{
		return $false
	}
}

<#
    .SYNOPSIS
    Internal function Confirm-ChocolateyBootstrapExecution.
#>

function Confirm-ChocolateyBootstrapExecution
{
	[CmdletBinding()]
	param()

	$bootstrapScriptUrl = 'https://community.chocolatey.org/install.ps1'
	$approvalVariableName = 'BASELINE_ALLOW_CHOCOLATEY_BOOTSTRAP'
	if (Test-BaselineEnvironmentFlagEnabled -Name $approvalVariableName)
	{
		return
	}

	$approvalTitle = Get-BaselineLocalizedString -Key 'Progress_Choco_BootstrapApprovalTitle' -Fallback 'Approve Chocolatey bootstrap'
	$approvalMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_BootstrapApprovalMessage' -Fallback ("Baseline can install Chocolatey by downloading and running Chocolatey's official bootstrap script.`n`nURL: {0}`n`nThis script is not bundled with Baseline or integrity-pinned by this repository. Review and approve it before continuing.`n`nFor reviewed headless automation, set {1}=1 for this process before launching Baseline." -f $bootstrapScriptUrl, $approvalVariableName)
	$approvalFailureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_BootstrapApprovalRequired' -Fallback ("Chocolatey bootstrap requires explicit operator approval before Baseline runs {0}. Review the script and approve it in an interactive session, or set {1}=1 for this process after review." -f $bootstrapScriptUrl, $approvalVariableName)

	$showThemedDialog = Get-Command -Name 'GUICommon\Show-ThemedDialog' -ErrorAction SilentlyContinue
	$approveLabel = 'Approve and Continue'
	if ($showThemedDialog -and (Test-Path -Path Variable:\Script:CurrentTheme) -and (Test-Path -Path Function:\Set-ButtonChrome))
	{
		$useDarkMode = $true
		if (Test-Path -Path Variable:\Script:CurrentThemeName)
		{
			$useDarkMode = ($Script:CurrentThemeName -eq 'Dark')
		}

		$dialogResult = GUICommon\Show-ThemedDialog `
			-Theme $Script:CurrentTheme `
			-ApplyButtonChrome ${function:Set-ButtonChrome} `
			-Title $approvalTitle `
			-Message $approvalMessage `
			-Buttons @('Cancel', $approveLabel) `
			-AccentButton $approveLabel `
			-UseDarkMode $useDarkMode

		if ($dialogResult -eq $approveLabel)
		{
			return
		}

		throw $approvalFailureMessage
	}

	if (Test-ChocolateyBootstrapInteractiveHost)
	{
		$approveChoice = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Approve and Continue', 'Download and run the Chocolatey bootstrap script now.'
		$cancelChoice = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Cancel', 'Stop before downloading and executing the Chocolatey bootstrap script.'
		$selectedIndex = $Host.UI.PromptForChoice($approvalTitle, $approvalMessage, @($approveChoice, $cancelChoice), 1)
		if ($selectedIndex -eq 0)
		{
			return
		}
	}

	throw $approvalFailureMessage
}

<#
    .SYNOPSIS
    Internal function ConvertTo-ApplicationCommandLiteral.
#>

function ConvertTo-ApplicationCommandLiteral
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		$Ast,

		[Parameter(Mandatory = $true)]
		[string]$Command,

		[Parameter(Mandatory = $false)]
		[switch]$CommandName
	)

	if ($Ast -is [System.Management.Automation.Language.StringConstantExpressionAst])
	{
		$literalValue = [string]$Ast.Value
		if ($CommandName -and [string]::IsNullOrWhiteSpace($literalValue))
		{
			throw "Command '$Command' must start with a literal command name."
		}

		return $literalValue
	}

	if (-not $CommandName -and $Ast -is [System.Management.Automation.Language.ConstantExpressionAst])
	{
		return [string]$Ast.Value
	}

	if ($CommandName)
	{
		throw "Command '$Command' must start with a literal command name."
	}

	throw "Command '$Command' contains unsupported syntax."
}

<#
    .SYNOPSIS
    Internal function Assert-ApplicationCommandAstIsSafe.
#>

function Assert-ApplicationCommandAstIsSafe
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		$Ast,

		[Parameter(Mandatory = $true)]
		[string]$Command
	)

	if ($Ast.ParamBlock -or $Ast.BeginBlock -or $Ast.ProcessBlock -or $Ast.DynamicParamBlock -or $Ast.CleanBlock)
	{
		throw "Command '$Command' contains unsupported syntax."
	}

	if (-not $Ast.EndBlock)
	{
		throw "Command '$Command' must resolve to one or more command invocations."
	}

	$statements = @($Ast.EndBlock.Statements)
	if ($statements.Count -eq 0)
	{
		throw "Command '$Command' must resolve to one or more command invocations."
	}

	foreach ($statement in $statements)
	{
		$pipelineAst = $statement -as [System.Management.Automation.Language.PipelineAst]
		if (-not $pipelineAst)
		{
			throw "Command '$Command' must contain only command invocations."
		}

		if ($pipelineAst.Background)
		{
			throw "Command '$Command' contains unsupported syntax."
		}

		foreach ($pipelineElement in @($pipelineAst.PipelineElements))
		{
			$commandAst = $pipelineElement -as [System.Management.Automation.Language.CommandAst]
			if (-not $commandAst -or $commandAst.CommandElements.Count -lt 1)
			{
				throw "Command '$Command' must resolve to a command name plus arguments."
			}

			if (@($commandAst.Redirections).Count -gt 0)
			{
				throw "Command '$Command' contains unsupported syntax."
			}

			if ($commandAst.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Unknown)
			{
				throw "Command '$Command' contains unsupported syntax."
			}

			$null = ConvertTo-ApplicationCommandLiteral -Ast $commandAst.CommandElements[0] -Command $Command -CommandName
			foreach ($element in ($commandAst.CommandElements | Select-Object -Skip 1))
			{
				if ($element -is [System.Management.Automation.Language.CommandParameterAst])
				{
					if ($null -ne $element.Argument)
					{
						$null = ConvertTo-ApplicationCommandLiteral -Ast $element.Argument -Command $Command
					}

					continue
				}

				$null = ConvertTo-ApplicationCommandLiteral -Ast $element -Command $Command
			}
		}
	}
}

<#
    .SYNOPSIS
    Internal function ConvertTo-ApplicationCommandInvocation.
#>

function ConvertTo-ApplicationCommandInvocation
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Command
	)

	$tokens = $null
	$parseErrors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseInput($Command, [ref]$tokens, [ref]$parseErrors)
	if ($parseErrors -and $parseErrors.Count -gt 0)
	{
		throw "Command '$Command' could not be parsed safely."
	}

	Assert-ApplicationCommandAstIsSafe -Ast $ast -Command $Command

	$statements = @($ast.EndBlock.Statements)
	$commandNames = [System.Collections.Generic.List[string]]::new()
	$isSingleCommandInvocation = ($statements.Count -eq 1)
	$commandAst = $null
	if ($isSingleCommandInvocation)
	{
		$pipelineAst = $statements[0] -as [System.Management.Automation.Language.PipelineAst]
		$isSingleCommandInvocation = ($pipelineAst -and $pipelineAst.PipelineElements.Count -eq 1)
		if ($isSingleCommandInvocation)
		{
			$commandAst = $pipelineAst.PipelineElements[0] -as [System.Management.Automation.Language.CommandAst]
		}
	}

	$commandArguments = [System.Collections.Generic.List[string]]::new()
	foreach ($statement in $statements)
	{
		$pipelineAst = $statement -as [System.Management.Automation.Language.PipelineAst]
		foreach ($pipelineElement in @($pipelineAst.PipelineElements))
		{
			$pipelineCommandAst = $pipelineElement -as [System.Management.Automation.Language.CommandAst]
			[void]$commandNames.Add((ConvertTo-ApplicationCommandLiteral -Ast $pipelineCommandAst.CommandElements[0] -Command $Command -CommandName))
		}
	}

	if ($commandAst)
	{
		foreach ($element in ($commandAst.CommandElements | Select-Object -Skip 1))
		{
			if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $element -is [System.Management.Automation.Language.ConstantExpressionAst])
			{
				[void]$commandArguments.Add([string]$element.Value)
				continue
			}

			if ($element -is [System.Management.Automation.Language.CommandParameterAst])
			{
				[void]$commandArguments.Add("-$($element.ParameterName)")
				if ($null -ne $element.Argument)
				{
					[void]$commandArguments.Add((ConvertTo-ApplicationCommandLiteral -Ast $element.Argument -Command $Command))
				}

				continue
			}
		}
	}

	return [pscustomobject]@{
		CommandName = if ($commandAst) { [string]$commandNames[0] } else { $null }
		CommandArguments = @($commandArguments)
		CommandNames = @($commandNames)
		HasSingleCommandInvocation = [bool]$commandAst
		ScriptBlock = [scriptblock]::Create($Command)
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-WingetInstall.
#>

function Invoke-WingetInstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$WinGetId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$wingetAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'WinGetAvailable'
	if ($null -eq $wingetAvailableState)
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}
	}
	elseif (-not [bool]$wingetAvailableState)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	$wingetPath = Resolve-WinGetExecutable
	if (-not $wingetPath)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_WinGet_StartingInstallation' -Fallback 'Starting installation of {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Installing' -Fallback 'Installing {0}...' -FormatArgs @($DisplayName))

	try
	{
		$result = Start-Process -FilePath $wingetPath -ArgumentList @(
			'install', '--id', $WinGetId, '--exact', '--silent',
			'--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_InstalledSuccess' -Fallback 'Successfully installed {0}' -FormatArgs @($DisplayName))
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_FailedInstall' -Fallback 'Failed to install {0}' -FormatArgs @($DisplayName)
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-WingetUninstall.
#>

function Invoke-WingetUninstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$WinGetId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$wingetAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'WinGetAvailable'
	if ($null -eq $wingetAvailableState)
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}
	}
	elseif (-not [bool]$wingetAvailableState)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	$wingetPath = Resolve-WinGetExecutable
	if (-not $wingetPath)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_WinGet_StartingUninstallation' -Fallback 'Starting uninstallation of {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Uninstalling' -Fallback 'Uninstalling {0}...' -FormatArgs @($DisplayName))

	try
	{
		$result = Start-Process -FilePath $wingetPath -ArgumentList @(
			'uninstall', '--id', $WinGetId, '--exact', '--silent', '--disable-interactivity'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstalledSuccess' -Fallback 'Successfully uninstalled {0}' -FormatArgs @($DisplayName))
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstallationError' -Fallback 'Error uninstalling {0}: {1}' -FormatArgs @($DisplayName, "exit code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstallationError' -Fallback 'Error uninstalling {0}: {1}' -FormatArgs @($DisplayName, $_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-WingetUpdate.
#>

function Invoke-WingetUpdate
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$WinGetId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$wingetAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'WinGetAvailable'
	if ($null -eq $wingetAvailableState)
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}
	}
	elseif (-not [bool]$wingetAvailableState)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	$wingetPath = Resolve-WinGetExecutable
	if (-not $wingetPath)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Processing' -Fallback 'Processing {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Processing' -Fallback 'Processing {0}...' -FormatArgs @($DisplayName))

	try
	{
		$result = Start-Process -FilePath $wingetPath -ArgumentList @(
			'upgrade', '--id', $WinGetId, '--exact', '--include-unknown', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready')
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("winget upgrade $DisplayName exited with code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocolateyBootstrapInstall.
#>

function Invoke-ChocolateyBootstrapInstall
{
	[CmdletBinding()]
	param()

	Confirm-ChocolateyBootstrapExecution

	$previousExecutionPolicy = [string](Get-ExecutionPolicy -Scope Process)
	$previousSecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol
	$bootstrapScriptPath = $null
	if ([string]::IsNullOrWhiteSpace($previousExecutionPolicy))
	{
		$previousExecutionPolicy = 'Undefined'
	}

	try
	{
		Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
		$bootstrapScriptPath = Save-ChocolateyBootstrapScript
		& $bootstrapScriptPath
		Reset-ChocolateyAvailabilityState
	}
	finally
	{
		[System.Net.ServicePointManager]::SecurityProtocol = $previousSecurityProtocol
		if ($bootstrapScriptPath -and (Test-Path -LiteralPath $bootstrapScriptPath))
		{
			Remove-Item -LiteralPath $bootstrapScriptPath -Force -ErrorAction SilentlyContinue
		}

		Set-ExecutionPolicy -ExecutionPolicy $previousExecutionPolicy -Scope Process -Force
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocoInstall.
#>

function Invoke-ChocoInstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ChocoId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$resolvedChocoId = Resolve-ApplicationPackageId -PackageId $ChocoId
	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Choco_InstallingPackage' -Fallback "Installing '{0}' via Chocolatey..." -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_InstallingPackage' -Fallback "Installing '{0}' via Chocolatey..." -FormatArgs @($DisplayName))

	try
	{
		$chocoPath = Resolve-ChocolateyExecutable
		if (-not $chocoPath)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_Installing' -Fallback 'Installing Chocolatey package manager...')
			Invoke-ChocolateyBootstrapInstall
			$chocoPath = Resolve-ChocolateyExecutable
		}

		if (-not $chocoPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}

		$result = Start-Process -FilePath $chocoPath -ArgumentList @(
			'install', $resolvedChocoId, '-y', '--no-progress', '--accept-license'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_InstalledSuccess' -Fallback 'Successfully installed {0}' -FormatArgs @($DisplayName))
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_FailedInstall' -Fallback 'Failed to install {0}' -FormatArgs @($DisplayName)
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocoUninstall.
#>

function Invoke-ChocoUninstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ChocoId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$resolvedChocoId = Resolve-ApplicationPackageId -PackageId $ChocoId
	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Choco_UninstallingPackage' -Fallback "Uninstalling '{0}' via Chocolatey..." -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_UninstallingPackage' -Fallback "Uninstalling '{0}' via Chocolatey..." -FormatArgs @($DisplayName))

	try
	{
		$chocoPath = Resolve-ChocolateyExecutable
		if (-not $chocoPath)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_Installing' -Fallback 'Installing Chocolatey package manager...')
			Invoke-ChocolateyBootstrapInstall
			$chocoPath = Resolve-ChocolateyExecutable
		}

		if (-not $chocoPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}

		$result = Start-Process -FilePath $chocoPath -ArgumentList @(
			'uninstall', $resolvedChocoId, '-y', '--no-progress'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstalledSuccess' -Fallback 'Successfully uninstalled {0}' -FormatArgs @($DisplayName))
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstallationError' -Fallback 'Error uninstalling {0}: {1}' -FormatArgs @($DisplayName, "exit code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_UninstallationError' -Fallback 'Error uninstalling {0}: {1}' -FormatArgs @($DisplayName, $_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocoUpdate.
#>

function Invoke-ChocoUpdate
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ChocoId,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$resolvedChocoId = Resolve-ApplicationPackageId -PackageId $ChocoId
	Write-ConsoleStatus -Action ("Updating '{0}' via Chocolatey..." -f $DisplayName)
	LogInfo ("Updating '{0}' via Chocolatey..." -f $DisplayName)

	try
	{
		$chocoPath = Resolve-ChocolateyExecutable
		if (-not $chocoPath)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_Installing' -Fallback 'Installing Chocolatey package manager...')
			Invoke-ChocolateyBootstrapInstall
			$chocoPath = Resolve-ChocolateyExecutable
		}

		if (-not $chocoPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}

		$result = Start-Process -FilePath $chocoPath -ArgumentList @(
			'upgrade', $resolvedChocoId, '-y', '--no-progress'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo ("Successfully updated {0}" -f $DisplayName)
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("choco upgrade $DisplayName exited with code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-WingetUpdateAll.
#>

function Invoke-WingetUpdateAll
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$wingetAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'WinGetAvailable'
	if ($null -eq $wingetAvailableState)
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}
	}
	elseif (-not [bool]$wingetAvailableState)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	$wingetPath = Resolve-WinGetExecutable
	if (-not $wingetPath)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_WinGet_CheckingUpdates' -Fallback 'Checking for WinGet updates...')
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_Updating' -Fallback 'Updating WinGet...')

	try
	{
		$result = Start-Process -FilePath $wingetPath -ArgumentList @(
			'upgrade', '--all', '--include-unknown', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_Ready' -Fallback 'WinGet is ready')
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("winget upgrade --all exited with code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ChocoUpdateAll.
#>

function Invoke-ChocoUpdateAll
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	$chocoAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'ChocolateyAvailable'
	if ($null -eq $chocoAvailableState)
	{
		if (-not (Test-ChocolateyAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}
	}
	elseif (-not [bool]$chocoAvailableState)
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
		LogError $failureMessage
		throw $failureMessage
	}

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Choco_CheckingUpdates' -Fallback 'Checking Chocolatey updates...')
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Choco_Updating' -Fallback 'Updating Chocolatey...')

	try
	{
		$chocoPath = Resolve-ChocolateyExecutable
		if (-not $chocoPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Choco_NotAvailable' -Fallback 'Chocolatey is not available on this system.'
			LogError $failureMessage
			throw $failureMessage
		}

		$result = Start-Process -FilePath $chocoPath -ArgumentList @(
			'upgrade', 'all', '-y', '--no-progress'
		) -Wait -PassThru -ErrorAction Stop

		if ($result.ExitCode -eq 0)
		{
			LogInfo 'Chocolatey update-all completed successfully.'
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("choco upgrade all exited with code $($result.ExitCode)")
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-StoreInstall.
#>

function Invoke-StoreInstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$StoreUri,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[hashtable]$Theme = $null,

		[Parameter(Mandatory = $false)]
		[scriptblock]$ApplyButtonChrome = $null,

		[Parameter(Mandatory = $false)]
		[object]$OwnerWindow = $null,

		[Parameter(Mandatory = $false)]
		[object]$UseDarkMode = $true
	)

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Store_StartingInstallation' -Fallback 'Opening Microsoft Store for {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Store_Opening' -Fallback 'Opening Microsoft Store for {0}...' -FormatArgs @($DisplayName))

	try
	{
		# Resolve theme if not provided (will be available in main module scope)
		if ($null -eq $Theme)
		{
			$Theme = if (Test-Path -Path Variable:\Script:CurrentTheme) { $Script:CurrentTheme } else { @{} }
		}

		# Resolve ApplyButtonChrome function if not provided
		if ($null -eq $ApplyButtonChrome)
		{
			$ApplyButtonChrome = if (Test-Path -Path Function:\Set-ButtonChrome) { ${function:Set-ButtonChrome} } else { { } }
		}

		# Resolve UseDarkMode from current theme if available
		if (Test-Path -Path Variable:\Script:CurrentThemeName)
		{
			$UseDarkMode = ($Script:CurrentThemeName -eq 'Dark')
		}

		# Open Store
		Start-Process -FilePath $StoreUri

		# Show themed dialog that blocks until user clicks OK
		$messageText = Get-BaselineLocalizedString -Key 'Progress_Store_InstallPrompt' -Fallback "Microsoft Store has been opened for $DisplayName.`n`nPlease install the app manually, then click OK to continue with the next app."

		$dialogResult = GUICommon\Show-ThemedDialog `
			-Theme $Theme `
			-ApplyButtonChrome $ApplyButtonChrome `
			-OwnerWindow $OwnerWindow `
			-Title (Get-BaselineLocalizedString -Key 'Progress_Store_DialogTitle' -Fallback 'Manual Installation Required') `
			-Message $messageText `
			-Buttons @('OK') `
			-UseDarkMode $UseDarkMode

		Start-Sleep -Seconds 2

		# Verify installation (for future enhancement - currently just logs)
		LogInfo (Get-BaselineLocalizedString -Key 'Progress_Store_OpenedSuccess' -Fallback 'Microsoft Store interaction completed for {0}. Proceeding to next app.' -FormatArgs @($DisplayName))
		return
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-DirectUrlInstall.
#>

function Invoke-DirectUrlInstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$DirectUrl,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[hashtable]$Theme = $null,

		[Parameter(Mandatory = $false)]
		[scriptblock]$ApplyButtonChrome = $null,

		[Parameter(Mandatory = $false)]
		[object]$OwnerWindow = $null,

		[Parameter(Mandatory = $false)]
		[object]$UseDarkMode = $true
	)

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_DirectUrl_StartingDownload' -Fallback 'Downloading {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_DirectUrl_Downloading' -Fallback 'Downloading {0} from {1}...' -FormatArgs @($DisplayName, $DirectUrl))

	try
	{
		# Resolve theme if not provided
		if ($null -eq $Theme)
		{
			$Theme = if (Test-Path -Path Variable:\Script:CurrentTheme) { $Script:CurrentTheme } else { @{} }
		}

		if ($null -eq $ApplyButtonChrome)
		{
			$ApplyButtonChrome = if (Test-Path -Path Function:\Set-ButtonChrome) { ${function:Set-ButtonChrome} } else { { } }
		}

		if (Test-Path -Path Variable:\Script:CurrentThemeName)
		{
			$UseDarkMode = ($Script:CurrentThemeName -eq 'Dark')
		}

		$tempDir = [System.IO.Path]::GetTempPath()
		$fileName = Split-Path -Leaf $DirectUrl
		$filePath = Join-Path -Path $tempDir -ChildPath $fileName

		$webClient = New-Object System.Net.WebClient
		$webClient.DownloadFile($DirectUrl, $filePath)

		LogInfo (Get-BaselineLocalizedString -Key 'Progress_DirectUrl_Downloaded' -Fallback 'Downloaded {0} to {1}. Attempting to execute...' -FormatArgs @($DisplayName, $filePath))

		if ($filePath.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase))
		{
			$result = Start-Process -FilePath $filePath -Wait -PassThru -ErrorAction Stop
			if ($result.ExitCode -eq 0 -or $result.ExitCode -eq 3010)
			{
				LogInfo (Get-BaselineLocalizedString -Key 'Progress_DirectUrl_InstalledSuccess' -Fallback 'Successfully installed {0}' -FormatArgs @($DisplayName))
				return
			}
		}
		else
		{
			$result = Start-Process -FilePath $filePath -PassThru -ErrorAction Stop
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_DirectUrl_OpenedSuccess' -Fallback 'Opened {0}' -FormatArgs @($DisplayName))
			return
		}

		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_FailedInstall' -Fallback 'Failed to install {0}' -FormatArgs @($DisplayName)
		LogError $failureMessage
		throw $failureMessage
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-CommandInstall.
#>

function Invoke-CommandInstall
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Command,

		[Parameter(Mandatory = $true)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[hashtable]$Theme = $null,

		[Parameter(Mandatory = $false)]
		[scriptblock]$ApplyButtonChrome = $null,

		[Parameter(Mandatory = $false)]
		[object]$OwnerWindow = $null,

		[Parameter(Mandatory = $false)]
		[object]$UseDarkMode = $true
	)

	Write-ConsoleStatus -Action (Get-BaselineLocalizedString -Key 'Progress_Command_Executing' -Fallback 'Executing installation command for {0}...' -FormatArgs @($DisplayName))
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_Command_Executing' -Fallback 'Executing installation command for {0}...' -FormatArgs @($DisplayName))

	try
	{
		# Resolve theme if not provided
		if ($null -eq $Theme)
		{
			$Theme = if (Test-Path -Path Variable:\Script:CurrentTheme) { $Script:CurrentTheme } else { @{} }
		}

		if ($null -eq $ApplyButtonChrome)
		{
			$ApplyButtonChrome = if (Test-Path -Path Function:\Set-ButtonChrome) { ${function:Set-ButtonChrome} } else { { } }
		}

		if (Test-Path -Path Variable:\Script:CurrentThemeName)
		{
			$UseDarkMode = ($Script:CurrentThemeName -eq 'Dark')
		}

		$commandInvocation = ConvertTo-ApplicationCommandInvocation -Command $Command
		$previousErrorActionPreference = $ErrorActionPreference
		try
		{
			$ErrorActionPreference = 'Stop'
			$null = & $commandInvocation.ScriptBlock
			if ($commandInvocation.HasSingleCommandInvocation -and -not [string]::IsNullOrWhiteSpace([string]$commandInvocation.CommandName))
			{
				$resolvedCommand = Get-Command -Name $commandInvocation.CommandName -ErrorAction Stop | Select-Object -First 1
				if ($resolvedCommand.CommandType -in @([System.Management.Automation.CommandTypes]::Application, [System.Management.Automation.CommandTypes]::ExternalScript))
				{
					$exitCode = $global:LASTEXITCODE
					if ($exitCode -ne 0)
					{
						throw "Command '$Command' exited with code $exitCode."
					}
				}
			}
		}
		finally
		{
			$ErrorActionPreference = $previousErrorActionPreference
		}

		LogInfo (Get-BaselineLocalizedString -Key 'Progress_Command_Success' -Fallback 'Successfully executed installation command for {0}' -FormatArgs @($DisplayName))
		return
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
}

<#
    .SYNOPSIS
    Internal function Invoke-ApplicationAction.
#>

function Invoke-ApplicationAction
{
	[CmdletBinding(DefaultParameterSetName = 'Legacy')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update')]
		[string]$Action,

		[Parameter(Mandatory = $true, ParameterSetName = 'Application')]
		[object]$Application,

		[Parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
		[string]$WinGetId,

		[Parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
		[string]$ChocoId,

		[Parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
		[string]$DisplayName,

		[Parameter(Mandatory = $false, ParameterSetName = 'Application')]
		[Parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
		[string]$PreferredSource,

		[Parameter(Mandatory = $false, ParameterSetName = 'Application')]
		[Parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
		[object]$PackageManagerAvailabilityState = $null
	)

	if ($PSCmdlet.ParameterSetName -eq 'Application')
	{
		$route = Resolve-ApplicationExecutionRoute -Application $Application -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState -Action $Action
		if ($route.Route -eq 'unsupported')
		{
			LogError $route.Reason
			throw $route.Reason
		}

		switch ($route.Route)
		{
			'winget'
			{
				switch ($Action)
				{
					'Install' { Invoke-WingetInstall -WinGetId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
					'Uninstall' { Invoke-WingetUninstall -WinGetId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
					'Update' { Invoke-WingetUpdate -WinGetId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
				}
			}
			'choco'
			{
				switch ($Action)
				{
					'Install' { Invoke-ChocoInstall -ChocoId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
					'Uninstall' { Invoke-ChocoUninstall -ChocoId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
					'Update' { Invoke-ChocoUpdate -ChocoId $route.PackageId -DisplayName $route.DisplayName -PackageManagerAvailabilityState $PackageManagerAvailabilityState; return }
				}
			}
			'store'
			{
				$storeParams = @{
					StoreUri = $route.PackageId
					DisplayName = $route.DisplayName
				}

				if (Test-Path -Path Variable:\Script:CurrentTheme)
				{
					$storeParams['Theme'] = $Script:CurrentTheme
				}
				if (Test-Path -Path Function:\Set-ButtonChrome)
				{
					$storeParams['ApplyButtonChrome'] = ${function:Set-ButtonChrome}
				}
				if (Test-Path -Path Variable:\Script:CurrentThemeName)
				{
					$storeParams['UseDarkMode'] = ($Script:CurrentThemeName -eq 'Dark')
				}

				Invoke-StoreInstall @storeParams
				return
			}
			'direct'
			{
				$directParams = @{
					DirectUrl = $route.PackageId
					DisplayName = $route.DisplayName
				}

				if (Test-Path -Path Variable:\Script:CurrentTheme)
				{
					$directParams['Theme'] = $Script:CurrentTheme
				}
				if (Test-Path -Path Function:\Set-ButtonChrome)
				{
					$directParams['ApplyButtonChrome'] = ${function:Set-ButtonChrome}
				}
				if (Test-Path -Path Variable:\Script:CurrentThemeName)
				{
					$directParams['UseDarkMode'] = ($Script:CurrentThemeName -eq 'Dark')
				}

				Invoke-DirectUrlInstall @directParams
				return
			}
			'command'
			{
				$commandParams = @{
					Command = $route.PackageId
					DisplayName = $route.DisplayName
				}

				if (Test-Path -Path Variable:\Script:CurrentTheme)
				{
					$commandParams['Theme'] = $Script:CurrentTheme
				}
				if (Test-Path -Path Function:\Set-ButtonChrome)
				{
					$commandParams['ApplyButtonChrome'] = ${function:Set-ButtonChrome}
				}
				if (Test-Path -Path Variable:\Script:CurrentThemeName)
				{
					$commandParams['UseDarkMode'] = ($Script:CurrentThemeName -eq 'Dark')
				}

				Invoke-CommandInstall @commandParams
				return
			}
		}

		throw $route.Reason
	}

	$hasWinGetId = -not [string]::IsNullOrWhiteSpace([string]$WinGetId)
	$hasChocoId = -not [string]::IsNullOrWhiteSpace([string]$ChocoId)
	$targetName = if (-not [string]::IsNullOrWhiteSpace([string]$DisplayName)) { [string]$DisplayName } elseif ($hasWinGetId) { [string]$WinGetId } elseif ($hasChocoId) { [string]$ChocoId } else { 'application' }
	$legacyRoute = Resolve-ApplicationExecutionRoute -Application @{
		Name = $targetName
		WinGetId = $WinGetId
		ChocoId = $ChocoId
		SupportsExecution = $true
	} -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState -Action $Action

	if ($legacyRoute.Route -eq 'unsupported')
	{
		LogError $legacyRoute.Reason
		throw $legacyRoute.Reason
	}

	switch ($Action)
	{
		'Install'
		{
			if ($legacyRoute.Route -eq 'winget')
			{
				Invoke-WingetInstall -WinGetId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			if ($legacyRoute.Route -eq 'choco')
			{
				Invoke-ChocoInstall -ChocoId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			throw $legacyRoute.Reason
		}
		'Uninstall'
		{
			if ($legacyRoute.Route -eq 'winget')
			{
				Invoke-WingetUninstall -WinGetId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			if ($legacyRoute.Route -eq 'choco')
			{
				Invoke-ChocoUninstall -ChocoId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			throw $legacyRoute.Reason
		}
		'Update'
		{
			if ($legacyRoute.Route -eq 'winget')
			{
				Invoke-WingetUpdate -WinGetId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			if ($legacyRoute.Route -eq 'choco')
			{
				Invoke-ChocoUpdate -ChocoId $legacyRoute.PackageId -DisplayName $targetName -PackageManagerAvailabilityState $PackageManagerAvailabilityState
				return
			}

			throw $legacyRoute.Reason
		}
	}
}

<#
	.SYNOPSIS
	Compatibility wrapper for install and uninstall actions.

	.PARAMETER Install
	Install the specified application.

	.PARAMETER Uninstall
	Uninstall the specified application.

	.PARAMETER WinGetId
	Optional WinGet package identifier (e.g. Mozilla.Firefox).

	.PARAMETER ChocoId
	Optional Chocolatey package identifier used as fallback.

	.PARAMETER DisplayName
	Friendly application name used for progress and log messages.

	.EXAMPLE
	AppInstall -Install -WinGetId "Mozilla.Firefox" -ChocoId "firefox"

	.EXAMPLE
	AppInstall -Uninstall -WinGetId "Mozilla.Firefox"

	.NOTES
	Machine-wide
#>

function AppInstall
{
	param
	(
		[Parameter(Mandatory = $false)]
		[switch]$Install,

		[Parameter(Mandatory = $false)]
		[switch]$Uninstall,

		[Parameter(Mandatory = $false)]
		[string]$WinGetId,

		[Parameter(Mandatory = $false)]
		[string]$ChocoId,

		[Parameter(Mandatory = $false)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[string]$PreferredSource,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null
	)

	if ($Install)
	{
		Invoke-ApplicationAction -Action 'Install' -WinGetId $WinGetId -ChocoId $ChocoId -DisplayName $DisplayName -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState
		return
	}

	if ($Uninstall)
	{
		Invoke-ApplicationAction -Action 'Uninstall' -WinGetId $WinGetId -ChocoId $ChocoId -DisplayName $DisplayName -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState
		return
	}
}

<#
	.SYNOPSIS
	Retrieves a cached list of installed applications via WinGet to prevent UI freezing.
#>
function Get-InstalledAppCache
{
	LogInfo (Get-BaselineLocalizedString -Key 'Progress_CheckingInstallStatus' -Fallback 'Checking installation status...')
	$installedCache = @{}
	$wingetPath = Resolve-WinGetExecutable

	try
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogWarning $failureMessage
			return $installedCache
		}

		if (-not $wingetPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.'
			LogWarning $failureMessage
			return $installedCache
		}

		# We only want the IDs of installed packages to build a quick lookup table.
		$wingetListPath = Join-Path -Path $env:TEMP -ChildPath 'winget_list.txt'
		$process = Start-Process -FilePath $wingetPath -ArgumentList @("list", "--accept-source-agreements", "--disable-interactivity") -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $wingetListPath -ErrorAction Stop
		if ($process.ExitCode -ne 0)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("winget list exited with code $($process.ExitCode)")
			LogError $failureMessage
			throw $failureMessage
		}

		if (Test-Path -LiteralPath $wingetListPath)
		{
			$output = Get-Content -LiteralPath $wingetListPath
			$inTable = $false
			foreach ($line in $output)
			{
				$trimmedLine = [string]$line
				if ([string]::IsNullOrWhiteSpace($trimmedLine))
				{
					continue
				}

				$trimmedLine = $trimmedLine.Trim()
				if (-not $inTable)
				{
					if ($trimmedLine -match '^-+$')
					{
						$inTable = $true
					}
					continue
				}

				$columns = @($trimmedLine -split '\s{2,}')
				if ($columns.Count -lt 2)
				{
					continue
				}

				$packageId = [string]$columns[1].Trim()
				if ([string]::IsNullOrWhiteSpace($packageId))
				{
					continue
				}

				if ($packageId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$')
				{
					continue
				}

				$installedCache[$packageId] = $true
			}
		}

		LogInfo (Get-BaselineLocalizedString -Key 'Progress_AppsCacheGenerated' -Fallback 'App cache generated with {0} detected packages.' -FormatArgs @($installedCache.Count))
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
	finally
	{
		if ($wingetListPath -and (Test-Path -LiteralPath $wingetListPath))
		{
			Remove-Item -LiteralPath $wingetListPath -Force -ErrorAction SilentlyContinue
		}
	}

	return $installedCache
}

<#
    .SYNOPSIS
    Internal function Get-InstalledChocolateyAppCache.
#>

function Get-InstalledChocolateyAppCache
{
	LogInfo 'Checking Chocolatey installation status...'
	$installedCache = @{}
	if (-not (Test-ChocolateyAvailable -Refresh))
	{
		LogInfo 'Chocolatey is not available on this system.'
		return $installedCache
	}

	$chocoPath = Resolve-ChocolateyExecutable
	if (-not $chocoPath)
	{
		LogInfo 'Chocolatey is not available on this system.'
		return $installedCache
	}

	try
	{
		$output = & $chocoPath list --local-only --limit-output --no-progress 2>$null
		foreach ($line in @($output))
		{
			$trimmedLine = [string]$line
			if ([string]::IsNullOrWhiteSpace($trimmedLine))
			{
				continue
			}

			$packageId = ([string]$trimmedLine -split '\|', 2)[0].Trim()
			if ([string]::IsNullOrWhiteSpace($packageId))
			{
				continue
			}

			$installedCache[$packageId] = $true
		}

		LogInfo ("Chocolatey cache generated with {0} detected packages." -f $installedCache.Count)
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}

	return $installedCache
}

<#
    .SYNOPSIS
    Internal function Get-AvailableAppUpdateCache.
#>

function Get-AvailableAppUpdateCache
{
	LogInfo 'Checking WinGet update availability...'
	$updateCache = @{}
	$wingetPath = Resolve-WinGetExecutable
	$wingetListPath = $null

	try
	{
		if (-not (Test-WinGetAvailable -Refresh))
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.')
			return $updateCache
		}

		if (-not $wingetPath)
		{
			LogInfo (Get-BaselineLocalizedString -Key 'Progress_WinGet_NotAvailable' -Fallback 'WinGet is not available on this system.')
			return $updateCache
		}

		$wingetListPath = Join-Path -Path $env:TEMP -ChildPath 'winget_upgrade_available.txt'
		$process = Start-Process -FilePath $wingetPath -ArgumentList @(
			"list", "--upgrade-available", "--include-unknown", "--accept-source-agreements", "--disable-interactivity"
		) -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $wingetListPath -ErrorAction Stop
		if ($process.ExitCode -ne 0)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @("winget list --upgrade-available --include-unknown exited with code $($process.ExitCode)")
			LogError $failureMessage
			throw $failureMessage
		}

		if (Test-Path -LiteralPath $wingetListPath)
		{
			$output = Get-Content -LiteralPath $wingetListPath
			$inTable = $false
			foreach ($line in $output)
			{
				$trimmedLine = [string]$line
				if ([string]::IsNullOrWhiteSpace($trimmedLine))
				{
					continue
				}

				$trimmedLine = $trimmedLine.Trim()
				if (-not $inTable)
				{
					if ($trimmedLine -match '^-+$')
					{
						$inTable = $true
					}
					continue
				}

				$columns = @($trimmedLine -split '\s{2,}')
				if ($columns.Count -lt 2)
				{
					continue
				}

				$packageId = [string]$columns[1].Trim()
				if ([string]::IsNullOrWhiteSpace($packageId))
				{
					continue
				}

				if ($packageId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$')
				{
					continue
				}

				$updateCache[$packageId] = $true
			}
		}

		LogInfo ("WinGet update cache generated with {0} detected packages." -f $updateCache.Count)
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}
	finally
	{
		if ($wingetListPath -and (Test-Path -LiteralPath $wingetListPath))
		{
			Remove-Item -LiteralPath $wingetListPath -Force -ErrorAction SilentlyContinue
		}
	}

	return $updateCache
}

<#
    .SYNOPSIS
    Internal function Get-AvailableChocolateyUpdateCache.
#>

function Get-AvailableChocolateyUpdateCache
{
	LogInfo 'Checking Chocolatey update availability...'
	$updateCache = @{}
	if (-not (Test-ChocolateyAvailable -Refresh))
	{
		LogInfo 'Chocolatey is not available on this system.'
		return $updateCache
	}

	$chocoPath = Resolve-ChocolateyExecutable
	if (-not $chocoPath)
	{
		LogInfo 'Chocolatey is not available on this system.'
		return $updateCache
	}

	try
	{
		$output = & $chocoPath outdated --limit-output --no-progress 2>$null
		foreach ($line in @($output))
		{
			$trimmedLine = [string]$line
			if ([string]::IsNullOrWhiteSpace($trimmedLine))
			{
				continue
			}

			$packageId = ([string]$trimmedLine -split '\|', 2)[0].Trim()
			if ([string]::IsNullOrWhiteSpace($packageId))
			{
				continue
			}

			$updateCache[$packageId] = $true
		}

		LogInfo ("Chocolatey update cache generated with {0} detected packages." -f $updateCache.Count)
	}
	catch
	{
		$failureMessage = Get-BaselineLocalizedString -Key 'Progress_Error' -Fallback 'Error: {0}' -FormatArgs @($_.Exception.Message)
		LogError $failureMessage
		throw $failureMessage
	}

	return $updateCache
}

<#
	.SYNOPSIS
	Updates a specific application or all available applications.

	.PARAMETER WinGetId
	Optional WinGet package identifier for the application to update.

	.PARAMETER ChocoId
	Optional Chocolatey package identifier used as fallback.

	.PARAMETER DisplayName
	Friendly application name used for progress and log messages.

	.PARAMETER All
	Update all available applications.
#>
function AppUpdate
{
	param
	(
		[Parameter(Mandatory = $false)]
		[string]$WinGetId,

		[Parameter(Mandatory = $false)]
		[string]$ChocoId,

		[Parameter(Mandatory = $false)]
		[string]$DisplayName,

		[Parameter(Mandatory = $false)]
		[string]$PreferredSource,

		[Parameter(Mandatory = $false)]
		[object]$PackageManagerAvailabilityState = $null,

		[Parameter(Mandatory = $false)]
		[switch]$All
	)

	$wingetPath = Resolve-WinGetExecutable
	$hasWinGetId = -not [string]::IsNullOrWhiteSpace([string]$WinGetId)
	$hasChocoId = -not [string]::IsNullOrWhiteSpace([string]$ChocoId)
	$resolvedChocoId = if ($hasChocoId) { Resolve-ApplicationPackageId -PackageId $ChocoId } else { $null }
	$targetName = if (-not [string]::IsNullOrWhiteSpace([string]$DisplayName)) { [string]$DisplayName } elseif ($hasWinGetId) { [string]$WinGetId } elseif ($hasChocoId) { [string]$resolvedChocoId } else { [string]$WinGetId }

	if ($All)
	{
		$wingetAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'WinGetAvailable'
		$chocolateyAvailableState = Get-PackageManagerAvailabilityStateValue -AvailabilityState $PackageManagerAvailabilityState -PropertyName 'ChocolateyAvailable'
		$attemptedAny = $false
		$failureMessages = [System.Collections.Generic.List[string]]::new()

		$shouldAttemptWinget = if ($null -eq $wingetAvailableState)
		{
			Test-WinGetAvailable -Refresh
		}
		else
		{
			[bool]$wingetAvailableState
		}

		if ($shouldAttemptWinget -and $wingetPath)
		{
			$attemptedAny = $true
			try
			{
				Invoke-WingetUpdateAll -PackageManagerAvailabilityState $PackageManagerAvailabilityState
			}
			catch
			{
				[void]$failureMessages.Add([string]$_.Exception.Message)
			}
		}

		$shouldAttemptChocolatey = if ($null -eq $chocolateyAvailableState)
		{
			Test-ChocolateyAvailable -Refresh
		}
		else
		{
			[bool]$chocolateyAvailableState
		}

		if ($shouldAttemptChocolatey)
		{
			$attemptedAny = $true
			try
			{
				Invoke-ChocoUpdateAll -PackageManagerAvailabilityState $PackageManagerAvailabilityState
			}
			catch
			{
				[void]$failureMessages.Add([string]$_.Exception.Message)
			}
		}
		elseif (-not $wingetPath)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_App_NoInstallMethod' -Fallback 'No install method available for {0}.' -FormatArgs @('application updates')
			LogError $failureMessage
			throw $failureMessage
		}

		if (-not $attemptedAny)
		{
			$failureMessage = Get-BaselineLocalizedString -Key 'Progress_App_NoInstallMethod' -Fallback 'No install method available for {0}.' -FormatArgs @('application updates')
			LogError $failureMessage
			throw $failureMessage
		}

		if ($failureMessages.Count -gt 0)
		{
			$failureMessage = ($failureMessages -join ' ')
			throw $failureMessage
		}

		LogInfo (Get-BaselineLocalizedString -Key 'Progress_App_UpdatesReady' -Fallback 'Application updates completed.')
	}
	elseif ($hasWinGetId -or $hasChocoId)
	{
		Invoke-ApplicationAction -Action 'Update' -WinGetId $WinGetId -ChocoId $ChocoId -DisplayName $targetName -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState
		return
	}
}

<#
	.SYNOPSIS
	Applies a single app action across multiple selected applications.
#>
function Invoke-AppBatchAction
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Install', 'Uninstall', 'Update')]
		[string]$Action,

		[Parameter(Mandatory = $true)]
		[object[]]$Applications,

		[string]$PreferredSource = $null,

		[object]$PackageManagerAvailabilityState = $null
	)

	$uniqueIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$successfulApps = [System.Collections.Generic.List[object]]::new()
	$failedApps = [System.Collections.Generic.List[object]]::new()

	foreach ($application in @($Applications))
	{
		if (-not $application)
		{
			continue
		}

		$route = Resolve-ApplicationExecutionRoute -Application $application -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState -Action $Action
		if (-not $uniqueIds.Add($route.IdentityKey))
		{
			continue
		}

		if ($route.Route -eq 'unsupported')
		{
			$failedApps.Add([pscustomobject]@{
				SelectionKey = $route.SelectionKey
				WinGetId   = $route.WinGetId
				ChocoId    = $route.ChocoId
				Name       = $route.DisplayName
				EntityType = if ([string]::IsNullOrWhiteSpace($route.EntityType)) { 'placeholder' } else { $route.EntityType }
				Route      = $route.Route
				SelectedSource = $route.SelectedSource
				PackageId  = $route.PackageId
				Error      = $route.Reason
			}) | Out-Null
			continue
		}

		try
		{
			Invoke-ApplicationAction -Action $Action -Application $application -PreferredSource $PreferredSource -PackageManagerAvailabilityState $PackageManagerAvailabilityState
			$successfulApps.Add([pscustomobject]@{
				SelectionKey = $route.SelectionKey
				WinGetId   = $route.WinGetId
				ChocoId    = $route.ChocoId
				Name       = $route.DisplayName
				EntityType = $route.EntityType
				Route      = $route.Route
				SelectedSource = $route.SelectedSource
				PackageId  = $route.PackageId
			}) | Out-Null
		}
		catch
		{
			$failedApps.Add([pscustomobject]@{
				SelectionKey = $route.SelectionKey
				WinGetId   = $route.WinGetId
				ChocoId    = $route.ChocoId
				Name       = $route.DisplayName
				EntityType = $route.EntityType
				Route      = $route.Route
				SelectedSource = $route.SelectedSource
				PackageId  = $route.PackageId
				Error      = [string]$_.Exception.Message
			}) | Out-Null
		}
	}

	$processedCount = $successfulApps.Count + $failedApps.Count
	if ($processedCount -eq 0)
	{
		$message = Get-BaselineLocalizedString -Key 'Progress_NoSelection' -Fallback 'No applications were selected.'
		LogWarning $message
		return [pscustomobject]@{
			Action         = $Action
			TotalCount      = 0
			SuccessCount    = 0
			FailureCount    = 0
			Outcome         = 'Failed'
			Message         = $message
			SuccessfulApps  = @()
			FailedApps      = @()
		}
	}

	$pastTense = switch ($Action)
	{
		'Install'   { 'installed' }
		'Uninstall' { 'uninstalled' }
		'Update'    { 'updated' }
	}

	if ($failedApps.Count -gt 0 -and $successfulApps.Count -gt 0)
	{
		$message = Get-BaselineLocalizedString -Key 'Progress_BatchPartial' -Fallback 'Partially {0} {1} selected app(s): {2} succeeded, {3} failed.' -FormatArgs @($pastTense, $processedCount, $successfulApps.Count, $failedApps.Count)
		LogWarning $message
		$outcome = 'Partial'
	}
	elseif ($failedApps.Count -gt 0)
	{
		$message = Get-BaselineLocalizedString -Key 'Progress_BatchFailed' -Fallback 'Failed to {0} {1} selected app(s).' -FormatArgs @($pastTense, $processedCount)
		LogError $message
		$outcome = 'Failed'
	}
	else
	{
		$message = Get-BaselineLocalizedString -Key 'Progress_BatchSuccess' -Fallback 'Successfully {0} {1} selected app(s).' -FormatArgs @($pastTense, $successfulApps.Count)
		LogInfo $message
		$outcome = 'Success'
	}

	return [pscustomobject]@{
		Action         = $Action
		TotalCount      = $processedCount
		SuccessCount    = $successfulApps.Count
		FailureCount    = $failedApps.Count
		Outcome         = $outcome
		Message         = $message
		SuccessfulApps  = @($successfulApps)
		FailedApps      = @($failedApps)
	}
}

#endregion
