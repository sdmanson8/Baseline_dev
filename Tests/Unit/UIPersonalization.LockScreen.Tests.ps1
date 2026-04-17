Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/UIPersonalization/UIPersonalization.LockScreen.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'LockScreen (OS-gated)' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:newItemCalls = [System.Collections.Generic.List[string]]::new()
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeRegCalls = [System.Collections.Generic.List[object]]::new()
        $script:osCaption = 'Microsoft Windows 11 Pro'
        $script:hasPolicy = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) }
        function Get-CimInstance {
            param([string]$ClassName, [string]$Filter)
            return [pscustomobject]@{ Caption = $script:osCaption }
        }
        function Get-ItemProperty {
            param([string]$Path, [string]$Name, [object]$ErrorAction)
            if ($script:hasPolicy) { return [pscustomobject]@{ NoLockScreen = 1 } }
            return $null
        }
        function Remove-RegistryValueSafe {
            param([string]$Path, [string]$Name)
            [void]$script:removeRegCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name })
        }
        function Test-Path { param([string]$Path) return $true }
        function New-Item {
            param([string]$Path, [switch]$Force, [object]$ErrorAction)
            [void]$script:newItemCalls.Add($Path)
        }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value, [object]$ErrorAction)
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Name = $Name; Value = $Value })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','Get-CimInstance','Get-ItemProperty','Remove-RegistryValueSafe','Test-Path','New-Item','Set-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires one of Enable or Disable' {
        { LockScreen } | Should -Throw
    }

    It 'returns silently on non-Windows 11 editions' {
        $script:osCaption = 'Microsoft Windows 10 Pro'

        LockScreen -Disable

        $script:consoleStatuses.Count | Should -Be 0
        $script:setItemPropertyCalls.Count | Should -Be 0
    }

    It 'sets NoLockScreen=1 on Disable for Windows 11' {
        LockScreen -Disable

        $script:setItemPropertyCalls.Count | Should -Be 1
        $script:setItemPropertyCalls[0].Name | Should -Be 'NoLockScreen'
        $script:setItemPropertyCalls[0].Value | Should -Be 1
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'removes NoLockScreen on Enable when the policy is present' {
        $script:hasPolicy = $true

        LockScreen -Enable

        $script:removeRegCalls.Count | Should -Be 1
        $script:removeRegCalls[0].Name | Should -Be 'NoLockScreen'
    }
}

Describe 'LockScreenBlur' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeItemPropertyCalls = [System.Collections.Generic.List[object]]::new()

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value)
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Name = $Name; Value = $Value })
        }
        function Remove-ItemProperty {
            param([string]$Path, [string]$Name, [object]$ErrorAction)
            [void]$script:removeItemPropertyCalls.Add([pscustomobject]@{ Name = $Name })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','Set-ItemProperty','Remove-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'requires one of Enable or Disable' {
        { LockScreenBlur } | Should -Throw
    }

    It 'removes DisableAcrylicBackgroundOnLogon on Enable' {
        LockScreenBlur -Enable

        $script:removeItemPropertyCalls.Count | Should -Be 1
        $script:removeItemPropertyCalls[0].Name | Should -Be 'DisableAcrylicBackgroundOnLogon'
    }

    It 'sets DisableAcrylicBackgroundOnLogon=1 on Disable' {
        LockScreenBlur -Disable

        $script:setItemPropertyCalls.Count | Should -Be 1
        $script:setItemPropertyCalls[0].Value | Should -Be 1
    }
}

Describe 'NetworkFromLockScreen and ShutdownFromLockScreen' {
    BeforeEach {
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeItemPropertyCalls = [System.Collections.Generic.List[object]]::new()

        function Write-ConsoleStatus { param([string]$Action, [string]$Status) }
        function LogInfo { param([string]$Message) }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value)
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Name = $Name; Value = $Value })
        }
        function Remove-ItemProperty {
            param([string]$Path, [string]$Name, [object]$ErrorAction)
            [void]$script:removeItemPropertyCalls.Add([pscustomobject]@{ Name = $Name })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','Set-ItemProperty','Remove-ItemProperty')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    It 'NetworkFromLockScreen -Disable writes DontDisplayNetworkSelectionUI=1' {
        NetworkFromLockScreen -Disable

        $script:setItemPropertyCalls[0].Name | Should -Be 'DontDisplayNetworkSelectionUI'
        $script:setItemPropertyCalls[0].Value | Should -Be 1
    }

    It 'NetworkFromLockScreen -Enable removes DontDisplayNetworkSelectionUI' {
        NetworkFromLockScreen -Enable

        $script:removeItemPropertyCalls[0].Name | Should -Be 'DontDisplayNetworkSelectionUI'
    }

    It 'ShutdownFromLockScreen -Enable writes ShutdownWithoutLogon=1' {
        ShutdownFromLockScreen -Enable

        $match = $script:setItemPropertyCalls | Where-Object { $_.Name -eq 'ShutdownWithoutLogon' }
        $match.Value | Should -Be 1
    }

    It 'ShutdownFromLockScreen -Disable writes ShutdownWithoutLogon=0' {
        ShutdownFromLockScreen -Disable

        $match = $script:setItemPropertyCalls | Where-Object { $_.Name -eq 'ShutdownWithoutLogon' }
        $match.Value | Should -Be 0
    }
}
