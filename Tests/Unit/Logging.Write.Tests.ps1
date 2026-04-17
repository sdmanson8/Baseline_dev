Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Logging.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    foreach ($fn in $functions) {
        if ($fn.Name -in @('Add-PendingLogMessage', 'Restore-PendingLogMessages', 'Write-PendingLogMessagesToFile', 'Write-LogMessage')) {
            Invoke-Expression $fn.Extent.Text
        }
    }

    function Send-UILogEntry {
        param([psobject]$Entry)
        return $true
    }

    function New-TestLogMutex {
        param(
            [bool[]]$WaitResults
        )

        $state = [pscustomobject]@{
            WaitResults   = [System.Collections.Generic.Queue[bool]]::new()
            WaitArguments = [System.Collections.Generic.List[int]]::new()
            ReleaseCount  = 0
        }

        foreach ($result in @($WaitResults)) {
            $state.WaitResults.Enqueue([bool]$result)
        }

        $mutex = [pscustomobject]@{
            State = $state
        }

        $null = $mutex | Add-Member -MemberType ScriptMethod -Name WaitOne -Value {
            param([int]$MillisecondsTimeout)
            [void]$this.State.WaitArguments.Add([int]$MillisecondsTimeout)
            if ($this.State.WaitResults.Count -eq 0) {
                return $false
            }

            return $this.State.WaitResults.Dequeue()
        } -Force

        $null = $mutex | Add-Member -MemberType ScriptMethod -Name ReleaseMutex -Value {
            $this.State.ReleaseCount++
        } -Force

        return $mutex
    }
}

Describe 'Write-LogMessage backlog handling' {
    BeforeEach {
        $script:LogFilePath = Join-Path $TestDrive 'baseline.log'
        $script:LogMode = $null
        $script:DefaultLogMutexTimeoutMs = 5000
        $script:LogMutexRetryBackoffMs = @(100, 250, 500)
        $script:LogStatistics = @{
            Info = 0
            Warning = 0
            Error = 0
        }
        $script:PendingLogMessages = [System.Collections.Generic.List[string]]::new()
        $script:PendingLogMessagesSyncRoot = [object]::new()
        $script:CapturedAppends = [System.Collections.Generic.List[object]]::new()
        $script:CapturedHostMessages = [System.Collections.Generic.List[string]]::new()
        $script:CapturedWarnings = [System.Collections.Generic.List[string]]::new()
        $script:CapturedSleeps = [System.Collections.Generic.List[int]]::new()

        function Add-Content {
            param(
                [string]$Path,
                [object]$Value,
                [object]$Encoding,
                [object]$ErrorAction
            )

            [void]$script:CapturedAppends.Add(@($Value))
        }

        function Write-Host {
            param(
                [string]$Object,
                [string]$ForegroundColor,
                [switch]$NoNewline
            )

            [void]$script:CapturedHostMessages.Add([string]$Object)
        }

        function Write-Warning {
            param([string]$Message)
            [void]$script:CapturedWarnings.Add([string]$Message)
        }

        function Start-Sleep {
            param([int]$Milliseconds)
            [void]$script:CapturedSleeps.Add([int]$Milliseconds)
        }
    }

    AfterEach {
        foreach ($functionName in @('Add-Content', 'Write-Host', 'Write-Warning', 'Start-Sleep')) {
            Remove-Item -Path ("Function:\{0}" -f $functionName) -ErrorAction SilentlyContinue
        }
    }

    It 'flushes queued messages before the current write when the mutex is available' {
        [void]$script:PendingLogMessages.Add('queued log line')
        $script:LogLock = New-TestLogMutex -WaitResults @($true)

        Write-LogMessage -Message 'current write'

        $script:CapturedAppends.Count | Should -Be 1
        @($script:CapturedAppends[0]).Count | Should -Be 2
        $script:CapturedAppends[0][0] | Should -Be 'queued log line'
        $script:CapturedAppends[0][1] | Should -Match 'INFO: current write'
        $script:PendingLogMessages.Count | Should -Be 0
        $script:LogLock.State.ReleaseCount | Should -Be 1
    }

    It 'queues timed-out messages and flushes them on the next successful write' {
        $script:LogLock = New-TestLogMutex -WaitResults @($false, $false, $false, $false)

        Write-LogMessage -Message 'first write'

        $script:CapturedAppends.Count | Should -Be 0
        $script:PendingLogMessages.Count | Should -Be 1
        $script:PendingLogMessages[0] | Should -Match 'INFO: first write'
        $script:CapturedSleeps.ToArray() | Should -Be @(100, 250, 500)
        $script:CapturedHostMessages[0] | Should -Match 'queued for retry'

        $script:LogLock = New-TestLogMutex -WaitResults @($true)

        Write-LogMessage -Message 'second write'

        $script:CapturedAppends.Count | Should -Be 1
        @($script:CapturedAppends[0]).Count | Should -Be 2
        $script:CapturedAppends[0][0] | Should -Match 'INFO: first write'
        $script:CapturedAppends[0][1] | Should -Match 'INFO: second write'
        $script:PendingLogMessages.Count | Should -Be 0
    }

    It 'retries timed-out writes with the configured backoff sequence' {
        $script:LogLock = New-TestLogMutex -WaitResults @($false, $false, $false, $false)

        Write-LogMessage -Message 'retry target'

        $script:LogLock.State.WaitArguments.ToArray() | Should -Be @(5000, 0, 0, 0)
        $script:CapturedSleeps.ToArray() | Should -Be @(100, 250, 500)
        $script:PendingLogMessages.Count | Should -Be 1
    }
}
