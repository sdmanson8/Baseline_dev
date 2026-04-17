Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/InitialActions.Helpers.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Get-BaselineStartupLabel' {
    It 'concatenates the OS name and version when a version is supplied' {
        Get-BaselineStartupLabel -OSName 'Windows 11 Pro' -DisplayVersion 'v4.0.0' |
            Should -Be 'Baseline | Utility for Windows 11 Pro v4.0.0'
    }

    It 'omits the trailing space when the version is empty' {
        Get-BaselineStartupLabel -OSName 'Windows 11 Pro' -DisplayVersion '' |
            Should -Be 'Baseline | Utility for Windows 11 Pro'
    }

    It 'omits the trailing space when the version is whitespace' {
        Get-BaselineStartupLabel -OSName 'Windows 11 Pro' -DisplayVersion '   ' |
            Should -Be 'Baseline | Utility for Windows 11 Pro'
    }

    It 'omits the trailing space when no version is supplied' {
        Get-BaselineStartupLabel -OSName 'Windows 11 Pro' |
            Should -Be 'Baseline | Utility for Windows 11 Pro'
    }
}

Describe 'Test-BaselineUnsupportedHost' {
    It 'flags PowerShell ISE host names' {
        Test-BaselineUnsupportedHost -HostName 'Windows PowerShell ISE Host' -TermProgram '' | Should -BeTrue
    }

    It 'flags VS Code regardless of the PowerShell host name' {
        Test-BaselineUnsupportedHost -HostName 'ConsoleHost' -TermProgram 'vscode' | Should -BeTrue
    }

    It 'permits the standard ConsoleHost outside VS Code' {
        Test-BaselineUnsupportedHost -HostName 'ConsoleHost' -TermProgram '' | Should -BeFalse
    }

    It 'permits an empty host name when the terminal is not VS Code' {
        Test-BaselineUnsupportedHost -HostName '' -TermProgram '' | Should -BeFalse
    }
}

Describe 'Test-BaselineHostsEntry' {
    It 'accepts an IPv4 entry with a hostname' {
        Test-BaselineHostsEntry -Line '127.0.0.1 telemetry.example.com' | Should -BeTrue
    }

    It 'accepts a leading-whitespace IPv4 entry' {
        Test-BaselineHostsEntry -Line '  10.0.0.1 host' | Should -BeTrue
    }

    It 'accepts an IPv6 entry' {
        Test-BaselineHostsEntry -Line '::1 ipv6.example.com' | Should -BeTrue
    }

    It 'rejects a comment line' {
        Test-BaselineHostsEntry -Line '# this is a comment' | Should -BeFalse
    }

    It 'rejects an empty line' {
        Test-BaselineHostsEntry -Line '' | Should -BeFalse
    }

    It 'rejects a line with only whitespace' {
        Test-BaselineHostsEntry -Line '   ' | Should -BeFalse
    }

    It 'rejects garbage text without an IP-shaped prefix' {
        Test-BaselineHostsEntry -Line 'oops not a hosts entry' | Should -BeFalse
    }

    It 'rejects $null without throwing' {
        Test-BaselineHostsEntry -Line $null | Should -BeFalse
    }
}

Describe 'Get-BaselineHostsCandidateEntries' {
    It 'strips comment lines and empty entries' {
        $input = @(
            '127.0.0.1 a.example',
            '# comment',
            '',
            '10.0.0.1 b.example'
        )

        $result = @(Get-BaselineHostsCandidateEntries -Content $input)

        $result.Count | Should -Be 2
        $result[0] | Should -Be '127.0.0.1 a.example'
        $result[1] | Should -Be '10.0.0.1 b.example'
    }

    It 'returns an empty array when content is null' {
        $result = @(Get-BaselineHostsCandidateEntries -Content $null)
        $result.Count | Should -Be 0
    }

    It 'returns an empty array when content is empty' {
        $result = @(Get-BaselineHostsCandidateEntries -Content @())
        $result.Count | Should -Be 0
    }
}

Describe 'Test-BaselineHostsDownloadSuspect' {
    It 'is suspect when more than half of entries are invalid' {
        Test-BaselineHostsDownloadSuspect -InvalidCount 6 -TotalCount 10 | Should -BeTrue
    }

    It 'is not suspect when exactly half of entries are invalid' {
        Test-BaselineHostsDownloadSuspect -InvalidCount 5 -TotalCount 10 | Should -BeFalse
    }

    It 'is not suspect when fewer than half of entries are invalid' {
        Test-BaselineHostsDownloadSuspect -InvalidCount 4 -TotalCount 10 | Should -BeFalse
    }

    It 'is not suspect when no entries were downloaded' {
        Test-BaselineHostsDownloadSuspect -InvalidCount 0 -TotalCount 0 | Should -BeFalse
    }

    It 'honours a caller-supplied threshold' {
        Test-BaselineHostsDownloadSuspect -InvalidCount 3 -TotalCount 10 -Threshold 0.2 | Should -BeTrue
        Test-BaselineHostsDownloadSuspect -InvalidCount 1 -TotalCount 10 -Threshold 0.2 | Should -BeFalse
    }
}

Describe 'Get-BaselineDefenderProductStateCode' {
    It 'extracts the state byte from a fully-on Defender product state' {
        # 0x41000 -> hex string "0x41000", second byte is "10"
        Get-BaselineDefenderProductStateCode -ProductState 0x41000 | Should -Be '10'
    }

    It 'extracts "00" for a not-running scanner' {
        Get-BaselineDefenderProductStateCode -ProductState 0x40000 | Should -Be '00'
    }

    It 'extracts "01" for a partially-disabled scanner' {
        Get-BaselineDefenderProductStateCode -ProductState 0x41100 | Should -Be '11'
    }

    It 'returns $null when the product state is null' {
        Get-BaselineDefenderProductStateCode -ProductState $null | Should -BeNullOrEmpty
    }

    It 'returns $null when the formatted state has fewer than 5 characters' {
        # 0x10 -> "0x10" length 4 -> not enough digits to read the middle byte
        Get-BaselineDefenderProductStateCode -ProductState 0x10 | Should -BeNullOrEmpty
    }

    It 'returns $null when the input cannot be coerced to an int' {
        Get-BaselineDefenderProductStateCode -ProductState 'not-an-int' | Should -BeNullOrEmpty
    }
}

Describe 'Test-BaselineDefenderActiveByProductState' {
    It 'is active for a non-zero, non-one second byte' {
        Test-BaselineDefenderActiveByProductState -StateCode '10' | Should -BeTrue
    }

    It 'is inactive when the second byte is 00' {
        Test-BaselineDefenderActiveByProductState -StateCode '00' | Should -BeFalse
    }

    It 'is inactive when the second byte is 01' {
        Test-BaselineDefenderActiveByProductState -StateCode '01' | Should -BeFalse
    }

    It 'is inactive when no state code was parsed' {
        Test-BaselineDefenderActiveByProductState -StateCode '' | Should -BeFalse
        Test-BaselineDefenderActiveByProductState -StateCode $null | Should -BeFalse
    }
}

Describe 'Test-BaselineDefenderFullyEnabled' {
    It 'is enabled only when every input flag is true' {
        Test-BaselineDefenderFullyEnabled -ServicesRunning $true -ProductStateActive $true -AntiSpywareEnabled $true -RealtimeMonitoringEnabled $true -BehaviorMonitoringEnabled $true |
            Should -BeTrue
    }

    It 'is disabled when any flag is false' {
        Test-BaselineDefenderFullyEnabled -ServicesRunning $true -ProductStateActive $true -AntiSpywareEnabled $true -RealtimeMonitoringEnabled $true -BehaviorMonitoringEnabled $false |
            Should -BeFalse
        Test-BaselineDefenderFullyEnabled -ServicesRunning $false -ProductStateActive $true -AntiSpywareEnabled $true -RealtimeMonitoringEnabled $true -BehaviorMonitoringEnabled $true |
            Should -BeFalse
    }
}

Describe 'Test-BaselineDefenderServicesHealthy' {
    It 'is healthy when at least one service is Running' {
        $services = @(
            [pscustomobject]@{ Name = 'A'; Status = 'Stopped' },
            [pscustomobject]@{ Name = 'B'; Status = 'Running' }
        )

        Test-BaselineDefenderServicesHealthy -Services $services | Should -BeTrue
    }

    It 'is unhealthy when every service is stopped' {
        $services = @(
            [pscustomobject]@{ Name = 'A'; Status = 'Stopped' },
            [pscustomobject]@{ Name = 'B'; Status = 'Stopped' }
        )

        Test-BaselineDefenderServicesHealthy -Services $services | Should -BeFalse
    }

    It 'is unhealthy when no services were sampled' {
        Test-BaselineDefenderServicesHealthy -Services @() | Should -BeFalse
        Test-BaselineDefenderServicesHealthy -Services $null | Should -BeFalse
    }
}
