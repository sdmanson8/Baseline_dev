Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/SystemTweaks/SystemTweaks.Cleanup.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'DiskCleanup' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:startProcessCalls = [System.Collections.Generic.List[object]]::new()
        $Global:LogFilePath = 'C:\temp\Baseline.log'

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function Start-Process {
            param([string]$FilePath, [string]$ArgumentList, [string]$WindowStyle)
            [void]$script:startProcessCalls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = $ArgumentList })
        }
        # $PSScriptRoot is empty when the function is re-evaluated via
        # Invoke-Expression, so Join-Path's Path becomes an empty string.
        # Shim Join-Path to tolerate empty Path.
        function Join-Path {
            param([string]$Path, [string]$ChildPath)
            if ([string]::IsNullOrEmpty($Path)) { return $ChildPath }
            return [System.IO.Path]::Combine($Path, $ChildPath)
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','Start-Process','Join-Path')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name LogFilePath -Scope Global -ErrorAction SilentlyContinue
    }

    It 'launches the diskcleanup helper script with powershell.exe' {
        DiskCleanup

        $script:startProcessCalls.Count | Should -Be 1
        $script:startProcessCalls[0].FilePath | Should -Be 'powershell.exe'
        $script:startProcessCalls[0].ArgumentList | Should -Match 'diskcleanup\.ps1'
        $script:startProcessCalls[0].ArgumentList | Should -Match '-ExecutionPolicy Bypass'
    }
}

Describe 'Invoke-AdditionalServiceOptimizations' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:warningMessages = [System.Collections.Generic.List[string]]::new()
        $script:setServiceCalls = [System.Collections.Generic.List[object]]::new()
        $script:stopServiceCalls = [System.Collections.Generic.List[string]]::new()
        $script:disableMMAgentCalled = $false
        $script:mmAgentCompressionEnabled = $true
        $script:serviceLookup = @{}

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogWarning { param([string]$Message) [void]$script:warningMessages.Add($Message) }
        function Get-MMAgent {
            param([object]$ErrorAction)
            return [pscustomobject]@{ MemoryCompression = $script:mmAgentCompressionEnabled }
        }
        function Disable-MMAgent {
            param([switch]$mc, [object]$ErrorAction)
            $script:disableMMAgentCalled = $true
            $script:mmAgentCompressionEnabled = $false
        }
        function Get-Service {
            param([string]$Name, [object]$ErrorAction)
            return $script:serviceLookup[$Name]
        }
        function Set-Service {
            param([string]$Name, [string]$StartupType, [object]$ErrorAction)
            [void]$script:setServiceCalls.Add([pscustomobject]@{ Name = $Name; StartupType = $StartupType })
        }
        function Stop-Service {
            param([string]$Name, [switch]$Force, [object]$ErrorAction)
            [void]$script:stopServiceCalls.Add($Name)
        }
        function Test-Path { param([string]$Path) return $false }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value, [switch]$Force, [object]$ErrorAction)
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogWarning','Get-MMAgent','Disable-MMAgent','Get-Service','Set-Service','Stop-Service','Test-Path','Set-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'calls Disable-MMAgent when memory compression is enabled' {
        Invoke-AdditionalServiceOptimizations

        $script:disableMMAgentCalled | Should -BeTrue
    }

    It 'disables the extra services when they exist' {
        $script:serviceLookup = @{
            'PeerDistSvc' = [pscustomobject]@{ Name = 'PeerDistSvc' }
            'RemoteRegistry' = [pscustomobject]@{ Name = 'RemoteRegistry' }
        }

        Invoke-AdditionalServiceOptimizations

        ($script:setServiceCalls | Where-Object { $_.Name -eq 'PeerDistSvc' }).StartupType | Should -Be 'Disabled'
        ($script:setServiceCalls | Where-Object { $_.Name -eq 'RemoteRegistry' }).StartupType | Should -Be 'Disabled'
    }

    It 'logs a warning when a service is missing and its registry key does not exist' {
        $script:serviceLookup = @{}

        Invoke-AdditionalServiceOptimizations

        ($script:warningMessages | Where-Object { $_ -match 'PeerDistSvc' }).Count | Should -Be 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'reports success (not warning) when no issues occurred' {
        $script:serviceLookup = @{
            'PeerDistSvc' = [pscustomobject]@{ Name = 'PeerDistSvc' }
            'diagnosticshub.standardcollector.service' = [pscustomobject]@{ Name = 'diagnosticshub.standardcollector.service' }
            'RemoteRegistry' = [pscustomobject]@{ Name = 'RemoteRegistry' }
        }

        Invoke-AdditionalServiceOptimizations

        # warnings from missing-service branch should not fire here
        $script:consoleStatuses[-1] | Should -Be 'success'
    }
}

Describe 'Invoke-CleanupOperation' {
    BeforeEach {
        $script:consoleActions = [System.Collections.Generic.List[string]]::new()
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:removedPaths = [System.Collections.Generic.List[string]]::new()
        $script:clearRecycleCalled = $false
        $script:clearRecycleThrows = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Action)) { [void]$script:consoleActions.Add($Action) }
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogWarning { param([string]$Message) }
        function Test-Path { param([string]$Path) return $true }
        function Remove-Item {
            param([string]$Path, [switch]$Force, [switch]$Recurse, [object]$ErrorAction)
            [void]$script:removedPaths.Add($Path)
        }
        function Clear-RecycleBin {
            param([switch]$Force, [object]$ErrorAction)
            $script:clearRecycleCalled = $true
            if ($script:clearRecycleThrows) { throw 'recycle bin locked' }
        }
        function New-Object {
            param([string]$ComObject)
            throw 'no Shell.Application in tests'
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogWarning','Test-Path','Remove-Item','Clear-RecycleBin','New-Object')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires one of All/Temp/Cache/Recycle' {
        { Invoke-CleanupOperation } | Should -Throw
    }

    It 'cleans TEMP paths on -Temp' {
        Invoke-CleanupOperation -Temp

        $script:removedPaths.Count | Should -BeGreaterOrEqual 1
        ($script:removedPaths | Where-Object { $_ -match 'TEMP' }).Count | Should -BeGreaterOrEqual 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'cleans cache paths on -Cache' {
        Invoke-CleanupOperation -Cache

        ($script:removedPaths | Where-Object { $_ -match 'INetCache' }).Count | Should -BeGreaterOrEqual 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'calls Clear-RecycleBin on -Recycle and reports success' {
        Invoke-CleanupOperation -Recycle

        $script:clearRecycleCalled | Should -BeTrue
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'reports failed when -Recycle throws' {
        $script:clearRecycleThrows = $true

        Invoke-CleanupOperation -Recycle

        $script:consoleStatuses[-1] | Should -Be 'failed'
    }
}
