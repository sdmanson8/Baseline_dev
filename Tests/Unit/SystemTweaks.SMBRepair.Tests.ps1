Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/SystemTweaks/SystemTweaks.SMBRepair.psm1'
    $source = Get-Content -Raw $filePath
    # Strip `using module` lines so Invoke-Expression does not try to resolve the real Logging/SharedHelpers
    $source = [regex]::Replace($source, '^using module[^\r\n]*[\r\n]+', '', 'Multiline')
    $sb = [scriptblock]::Create($source)
    $ast = $sb.Ast
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'LanmanWorkstationGuestAuthPolicy' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:policyCalls = [System.Collections.Generic.List[object]]::new()
        $script:shouldThrow = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function Set-Policy {
            param([string]$Scope, [string]$Path, [string]$Name, [string]$Type, [object]$Value)
            if ($script:shouldThrow) { throw 'policy failed' }
            [void]$script:policyCalls.Add([pscustomobject]@{ Scope = $Scope; Name = $Name; Value = $Value })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','Set-Policy')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires Enable or Disable' {
        { LanmanWorkstationGuestAuthPolicy } | Should -Throw
    }

    It 'writes AllowInsecureGuestAuth=1 on Enable' {
        LanmanWorkstationGuestAuthPolicy -Enable

        $script:policyCalls[0].Name | Should -Be 'AllowInsecureGuestAuth'
        $script:policyCalls[0].Value | Should -Be 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'writes AllowInsecureGuestAuth=0 on Disable' {
        LanmanWorkstationGuestAuthPolicy -Disable

        $script:policyCalls[0].Value | Should -Be 0
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'reports failed when Set-Policy throws' {
        $script:shouldThrow = $true

        LanmanWorkstationGuestAuthPolicy -Enable

        $script:consoleStatuses[-1] | Should -Be 'failed'
        $script:errorMessages[0] | Should -Match 'policy failed'
    }
}

Describe 'Set-SystemTweaksRegistryValue' {
    BeforeEach {
        $script:newItemCalls = [System.Collections.Generic.List[string]]::new()
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:pathExists = $true
        $script:propertyExists = $true

        function Test-Path { param([string]$Path) return $script:pathExists }
        function New-Item {
            [CmdletBinding()]
            param([string]$Path, [switch]$Force)
            [void]$script:newItemCalls.Add($Path)
        }
        function Get-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name)
            if ($script:propertyExists) { return [pscustomobject]@{ $Name = 0 } }
            return $null
        }
        function Set-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value, [switch]$Force)
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Value = $Value; Type = $Type })
        }
        function New-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name, [string]$PropertyType, [object]$Value, [switch]$Force)
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Value = $Value; PropertyType = $PropertyType })
        }
    }

    AfterEach {
        foreach ($n in @('Test-Path','New-Item','Get-ItemProperty','Set-ItemProperty','New-ItemProperty')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'creates the key when the path does not exist' {
        $script:pathExists = $false

        Set-SystemTweaksRegistryValue -Path 'HKLM:\FAKE' -Name 'Val' -Value 1 -Type DWord

        $script:newItemCalls.Count | Should -Be 1
    }

    It 'updates an existing property via Set-ItemProperty when the value is present' {
        $script:pathExists = $true
        $script:propertyExists = $true

        Set-SystemTweaksRegistryValue -Path 'HKLM:\FAKE' -Name 'Val' -Value 5 -Type DWord

        $script:setItemPropertyCalls.Count | Should -Be 1
        $script:setItemPropertyCalls[0].Value | Should -Be 5
        $script:newItemPropertyCalls.Count | Should -Be 0
    }

    It 'creates a new property via New-ItemProperty when the value is absent' {
        $script:pathExists = $true
        $script:propertyExists = $false

        Set-SystemTweaksRegistryValue -Path 'HKLM:\FAKE' -Name 'Val' -Value 7 -Type DWord

        $script:newItemPropertyCalls.Count | Should -Be 1
        $script:newItemPropertyCalls[0].Value | Should -Be 7
        $script:setItemPropertyCalls.Count | Should -Be 0
    }

    It 'rejects an invalid Type' {
        { Set-SystemTweaksRegistryValue -Path 'HKLM:\FAKE' -Name 'Val' -Value 1 -Type 'Nonsense' } | Should -Throw
    }
}

Describe 'Remove-SystemTweaksRegistryValue' {
    BeforeEach {
        $script:removeSafeCalls = [System.Collections.Generic.List[object]]::new()

        function Remove-RegistryValueSafe {
            param([string]$Path, [string]$Name)
            [void]$script:removeSafeCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name })
            return $true
        }
    }

    AfterEach {
        Microsoft.PowerShell.Management\Remove-Item Function:\Remove-RegistryValueSafe -ErrorAction SilentlyContinue
    }

    It 'delegates to Remove-RegistryValueSafe' {
        Remove-SystemTweaksRegistryValue -Path 'HKLM:\FAKE' -Name 'Val' | Out-Null

        $script:removeSafeCalls.Count | Should -Be 1
        $script:removeSafeCalls[0].Path | Should -Be 'HKLM:\FAKE'
        $script:removeSafeCalls[0].Name | Should -Be 'Val'
    }
}

Describe 'Test-Windows11SmbDuplicateSidIssue' {
    BeforeEach {
        $script:eventsToReturn = @()
        $script:getWinEventThrows = $false

        function Get-WinEvent {
            [CmdletBinding()]
            param([hashtable]$FilterHashtable)
            if ($script:getWinEventThrows) { throw 'no logs' }
            return $script:eventsToReturn
        }
        function Remove-HandledErrorRecord { param([object]$ErrorRecord) }
        function LogInfo { param([string]$Message) }
    }

    AfterEach {
        foreach ($n in @('Get-WinEvent','Remove-HandledErrorRecord','LogInfo')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'returns $true when a matching event is present' {
        $script:eventsToReturn = @(
            [pscustomobject]@{ Message = 'LSASS observed a partial mismatch in the machine ID for something' }
        )

        Test-Windows11SmbDuplicateSidIssue | Should -BeTrue
    }

    It 'returns $false when no matching events are present' {
        $script:eventsToReturn = @(
            [pscustomobject]@{ Message = 'Unrelated event text here' }
        )

        Test-Windows11SmbDuplicateSidIssue | Should -BeFalse
    }

    It 'returns $false when the event log query throws' {
        $script:getWinEventThrows = $true

        Test-Windows11SmbDuplicateSidIssue | Should -BeFalse
    }
}

Describe 'Windows11SMBUpdateIssue' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:warningMessages = [System.Collections.Generic.List[string]]::new()
        $script:isWindows11 = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogWarning { param([string]$Message) [void]$script:warningMessages.Add($Message) }
        function LogError { param([string]$Message) }
        function Get-OSInfo { return [pscustomobject]@{ IsWindows11 = $script:isWindows11; OSName = 'Windows 11'; CurrentBuild = 22631 } }
        function Remove-SystemTweaksRegistryValue { param([string]$Path, [string]$Name) return $false }
        function Set-SystemTweaksRegistryValue { param([string]$Path, [string]$Name, [object]$Value, [string]$Type) }
        function Test-Windows11SmbDuplicateSidIssue { return $false }
        function SMBGuestCompatibility { param([switch]$SuppressConsoleStatus) }
        function Get-CimInstance { param([string]$ClassName) return [pscustomobject]@{ PartOfDomain = $true } }
        function Test-Path { param([string]$Path) return $false }
        function Get-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name)
            return $null
        }
        function Set-SmbClientConfiguration {
            [CmdletBinding()]
            param([bool]$RequireSecuritySignature, [bool]$EnableSecuritySignature, [switch]$Force)
        }
        function Set-SmbServerConfiguration {
            [CmdletBinding()]
            param([bool]$RequireSecuritySignature, [bool]$EnableSecuritySignature, [bool]$EnableSMB2Protocol, [switch]$Force)
        }
        function Compare-Object {
            [CmdletBinding()]
            param([object]$ReferenceObject, [object]$DifferenceObject)
            return $null
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogWarning','LogError','Get-OSInfo','Remove-SystemTweaksRegistryValue','Set-SystemTweaksRegistryValue','Test-Windows11SmbDuplicateSidIssue','SMBGuestCompatibility','Get-CimInstance','Test-Path','Get-ItemProperty','Set-SmbClientConfiguration','Set-SmbServerConfiguration','Compare-Object')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'short-circuits to success when not running on Windows 11' {
        $script:isWindows11 = $false

        Windows11SMBUpdateIssue

        $script:consoleStatuses[-1] | Should -Be 'success'
        $script:warningMessages.Count | Should -Be 0
    }

    It 'reports success on Windows 11 when no sub-step signals an issue' {
        $script:isWindows11 = $true

        Windows11SMBUpdateIssue

        $script:consoleStatuses[-1] | Should -Be 'success'
    }
}

Describe 'SMBGuestCompatibility' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:setRegistryCalls = [System.Collections.Generic.List[object]]::new()
        $script:partOfDomain = $false
        $script:Global_BaselinePostActionRequirements = $null
        Remove-Variable -Name BaselinePostActionRequirements -Scope Global -ErrorAction SilentlyContinue

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogWarning { param([string]$Message) }
        function Get-CimInstance { param([string]$ClassName) return [pscustomobject]@{ PartOfDomain = $script:partOfDomain } }
        function Get-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name)
            return $null
        }
        function Set-SystemTweaksRegistryValue {
            param([string]$Path, [string]$Name, [object]$Value, [string]$Type)
            [void]$script:setRegistryCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Value = $Value })
        }
        function Set-SmbClientConfiguration {
            [CmdletBinding()]
            param([bool]$EnableInsecureGuestLogons, [bool]$RequireSecuritySignature, [bool]$EnableSecuritySignature, [switch]$Force)
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogWarning','Get-CimInstance','Get-ItemProperty','Set-SystemTweaksRegistryValue','Set-SmbClientConfiguration')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name BaselinePostActionRequirements -Scope Global -ErrorAction SilentlyContinue
    }

    It 'skips configuration and reports success when the device is domain joined' {
        $script:partOfDomain = $true

        SMBGuestCompatibility

        $script:setRegistryCalls.Count | Should -Be 0
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'applies registry guest-auth settings and marks the post-action flag when not domain joined' {
        $script:partOfDomain = $false

        SMBGuestCompatibility

        # Three guest-auth settings are applied unconditionally on a non-domain machine
        $script:setRegistryCalls.Count | Should -BeGreaterOrEqual 3
        ($script:setRegistryCalls | Where-Object { $_.Name -eq 'AllowInsecureGuestAuth' }).Count | Should -BeGreaterOrEqual 1
        $Global:BaselinePostActionRequirements['EnsureSmbGuestAuth'] | Should -BeTrue
    }

    It 'does not emit a console status when -SuppressConsoleStatus is passed' {
        $script:partOfDomain = $true

        SMBGuestCompatibility -SuppressConsoleStatus

        $script:consoleStatuses.Count | Should -Be 0
    }
}

Describe 'SharedPrinterConnectionErrors non-admin path' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'fails early and logs when not running elevated' -Skip:([bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        SharedPrinterConnectionErrors

        $script:consoleStatuses[-1] | Should -Be 'failed'
        $script:errorMessages[0] | Should -Match 'elevated'
    }
}
