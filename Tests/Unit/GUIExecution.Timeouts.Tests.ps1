Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    function Test-GuiObjectField {
        param([object]$Object, [string]$FieldName)
        if ($null -eq $Object) { return $false }
        if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($FieldName) }
        return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName])
    }

    function Get-BaselineLocalizedString {
        param(
            [string]$Key,
            [string]$Fallback,
            [object[]]$FormatArgs = @()
        )

        if ($FormatArgs.Count -gt 0)
        {
            return ($Fallback -f $FormatArgs)
        }

        return $Fallback
    }

    function LogInfo { param([object]$Message) }
    function LogWarning { param([object]$Message) }
    function LogError { param([object]$Message) }

    $filePath = Join-Path $PSScriptRoot '../../Module/GUIExecution.psm1'
    $script:GuiExecutionContent = Get-BaselineTestSourceText -Path $filePath
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions)
    {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Get-GuiExecutionActionTimeoutSeconds' {
    It 'honors the manifest timeout override when present' {
        $entry = [pscustomobject]@{
            TimeoutSeconds = 42
            Function = 'Anything'
            Type = 'Toggle'
        }

        Get-GuiExecutionActionTimeoutSeconds -Entry $entry -ExecutionClass 'Tweak' | Should -Be 42
    }

    It 'uses the scheduled tasks timeout bucket for task tweaks' {
        $entry = [pscustomobject]@{
            Function = 'ScheduledTasks'
            Type = 'Action'
        }

        Get-GuiExecutionActionTimeoutSeconds -Entry $entry -ExecutionClass 'Tweak' | Should -Be 120
    }

    It 'uses the app default timeout bucket for applications' {
        Get-GuiExecutionActionTimeoutSeconds -Entry ([pscustomobject]@{ Name = 'Firefox' }) -ExecutionClass 'App' | Should -Be 900
    }

    It 'uses the UWPApps manifest timeout override for bulk app operations' {
        $uwpManifestPath = Join-Path $PSScriptRoot '../../Module/Data/UWPApps.json'
        $uwpManifest = Get-BaselineTestSourceText -Path $uwpManifestPath | ConvertFrom-Json
        $uwpEntry = @($uwpManifest.Entries | Where-Object Function -eq 'UWPApps' | Select-Object -First 1)[0]

        $uwpEntry.TimeoutSeconds | Should -Be 1800
        Get-GuiExecutionActionTimeoutSeconds -Entry $uwpEntry -ExecutionClass 'Tweak' | Should -Be 1800
    }

    It 'validates choice values against manifest options before invoking the command' {
        $script:GuiExecutionContent | Should -Match '\$choiceOptions = @\(\)'
        $script:GuiExecutionContent | Should -Match '\$choiceParam -notin \$choiceOptions'
        $script:GuiExecutionContent | Should -Match 'The choice selection for'
        $script:GuiExecutionContent | Should -Match 'is invalid'
        $script:GuiExecutionContent | Should -Match 'Expected one of'
    }
}

Describe 'Test-GuiExecutionInvocationTimedOut' {
    It 'returns true for explicit timeout results' {
        $result = [pscustomobject]@{
            TimedOut = $true
            ErrorTypeName = $null
        }

        Test-GuiExecutionInvocationTimedOut -InvocationResult $result | Should -Be $true
    }

    It 'returns true when the invocation failed with a timeout exception type' {
        $result = [pscustomobject]@{
            TimedOut = $false
            ErrorTypeName = 'System.TimeoutException'
        }

        Test-GuiExecutionInvocationTimedOut -InvocationResult $result | Should -Be $true
    }

    It 'returns false for ordinary failures' {
        $result = [pscustomobject]@{
            TimedOut = $false
            ErrorTypeName = 'System.InvalidOperationException'
        }

        Test-GuiExecutionInvocationTimedOut -InvocationResult $result | Should -Be $false
    }
}

Describe 'New-GuiExecutionAppBatchResult' {
    It 'returns a partial outcome when some apps fail and others succeed' {
        $route = [pscustomobject]@{
            SelectionKey = 'winget:code'
            WinGetId = 'Microsoft.VisualStudioCode'
            ChocoId = $null
            DisplayName = 'Visual Studio Code'
            EntityType = 'winget'
            Route = 'winget'
            SelectedSource = 'winget'
            PackageId = 'Microsoft.VisualStudioCode'
        }

        $result = New-GuiExecutionAppBatchResult -Action 'Install' -SuccessfulApps @(
            New-GuiExecutionAppBatchEntry -Route $route
        ) -FailedApps @(
            New-GuiExecutionAppBatchEntry -Route $route -Error 'Timed out after 900 seconds.'
        )

        $result.Outcome | Should -Be 'Partial'
        $result.SuccessCount | Should -Be 1
        $result.FailureCount | Should -Be 1
    }
}

Describe 'GUI execution action host exports and logging bootstrap' {
    It 'exports the GUI execution helpers used by background execution runspaces' {
        $script:GuiExecutionContent | Should -Match "'Get-GuiExecutionActionTimeoutSeconds'"
        $script:GuiExecutionContent | Should -Match "'Test-GuiExecutionCriticalAction'"
        $script:GuiExecutionContent | Should -Match "'Test-GuiExecutionInvocationTimedOut'"
        $script:GuiExecutionContent | Should -Match "'New-GuiExecutionAppBatchEntry'"
        $script:GuiExecutionContent | Should -Match "'New-GuiExecutionAppBatchResult'"
        $script:GuiExecutionContent | Should -Match "'New-GuiExecutionActionHost'"
        $script:GuiExecutionContent | Should -Match "'Close-GuiExecutionActionHost'"
        $script:GuiExecutionContent | Should -Match "'Invoke-GuiExecutionActionHostCommand'"
    }

    It 'preseeds the requested log path before importing the loader in background runspaces' {
        ([regex]::Matches($script:GuiExecutionContent, '\$Global:LogFilePath = \$bgLogFilePath\s*\r?\n\s*Import-Module \$bgLoaderPath -Force -Global -ErrorAction Stop')).Count | Should -Be 3
    }
}
