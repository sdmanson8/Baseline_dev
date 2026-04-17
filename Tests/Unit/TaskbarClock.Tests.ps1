Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/TaskbarClock.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'ClockInNotificationCenter' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:throwOnWrite = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function New-ItemProperty {
            param([string]$Path, [string]$Name, [string]$PropertyType, [object]$Value, [switch]$Force, [object]$ErrorAction)
            if ($script:throwOnWrite) { throw 'registry write denied' }
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','New-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires one of Show or Hide' {
        { ClockInNotificationCenter } | Should -Throw
    }

    It 'writes ShowClockInNotificationCenter=1 on Show' {
        ClockInNotificationCenter -Show

        $script:newItemPropertyCalls.Count | Should -Be 1
        $script:newItemPropertyCalls[0].Name | Should -Be 'ShowClockInNotificationCenter'
        $script:newItemPropertyCalls[0].Value | Should -Be 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'writes ShowClockInNotificationCenter=0 on Hide' {
        ClockInNotificationCenter -Hide

        $script:newItemPropertyCalls.Count | Should -Be 1
        $script:newItemPropertyCalls[0].Value | Should -Be 0
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'logs an error and marks failed when the registry write throws' {
        $script:throwOnWrite = $true

        ClockInNotificationCenter -Show

        $script:consoleStatuses[-1] | Should -Be 'failed'
        $script:errorMessages.Count | Should -Be 1
        $script:errorMessages[0] | Should -Match 'registry write denied'
    }
}

Describe 'SecondsInSystemClock' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:throwOnWrite = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function New-ItemProperty {
            param([string]$Path, [string]$Name, [string]$PropertyType, [object]$Value, [switch]$Force, [object]$ErrorAction)
            if ($script:throwOnWrite) { throw 'boom' }
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','New-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires one of Show or Hide' {
        { SecondsInSystemClock } | Should -Throw
    }

    It 'writes ShowSecondsInSystemClock=1 on Show' {
        SecondsInSystemClock -Show

        $script:newItemPropertyCalls.Count | Should -Be 1
        $script:newItemPropertyCalls[0].Name | Should -Be 'ShowSecondsInSystemClock'
        $script:newItemPropertyCalls[0].Value | Should -Be 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'writes ShowSecondsInSystemClock=0 on Hide' {
        SecondsInSystemClock -Hide

        $script:newItemPropertyCalls.Count | Should -Be 1
        $script:newItemPropertyCalls[0].Value | Should -Be 0
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'logs an error and marks failed when the registry write throws' {
        $script:throwOnWrite = $true

        SecondsInSystemClock -Hide

        $script:consoleStatuses[-1] | Should -Be 'failed'
        $script:errorMessages[0] | Should -Match 'boom'
    }
}
