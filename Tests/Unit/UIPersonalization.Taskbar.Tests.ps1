Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/UIPersonalization/UIPersonalization.Taskbar.psm1'
    $source = Get-Content -Raw $filePath
    $source = [regex]::Replace($source, '^using module[^\r\n]*[\r\n]+', '', 'Multiline')
    $sb = [scriptblock]::Create($source)
    $ast = $sb.Ast
    # Only load the outer functions (avoid redefining nested helpers of UnpinTaskbarShortcuts etc.)
    $functions = $ast.FindAll({
            param($node)
            ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and
            ($node.Parent -is [System.Management.Automation.Language.NamedBlockAst])
        }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'UIPersonalization.Taskbar toggle functions' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:newItemCalls = [System.Collections.Generic.List[string]]::new()
        $script:setRegistrySafeCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeRegistrySafeCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:policyCalls = [System.Collections.Generic.List[object]]::new()
        $script:pathExists = $false
        $script:hasExistingProperty = $false
        $script:shouldThrow = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function Test-Path { param([string]$Path) return $script:pathExists }
        function New-Item {
            [CmdletBinding()]
            param([string]$Path, [switch]$Force)
            [void]$script:newItemCalls.Add($Path)
        }
        function New-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name, [string]$PropertyType, [object]$Value, [switch]$Force)
            if ($script:shouldThrow) { throw 'new-itemproperty failed' }
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value })
        }
        function Remove-ItemProperty {
            [CmdletBinding()]
            param([string[]]$Path, [string[]]$Name, [switch]$Force)
            [void]$script:removeItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name })
        }
        function Get-ItemProperty {
            [CmdletBinding()]
            param([string]$Path, [string]$Name)
            if ($script:hasExistingProperty) { return [pscustomobject]@{ $Name = 1 } }
            return $null
        }
        function Set-RegistryValueSafe {
            param([string]$Path, [string]$Name, [object]$Value, [string]$Type)
            [void]$script:setRegistrySafeCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value; Type = $Type })
        }
        function Remove-RegistryValueSafe {
            param([string]$Path, [string]$Name)
            [void]$script:removeRegistrySafeCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name })
        }
        function Set-Policy {
            param([string]$Scope, [string]$Path, [string]$Name, [string]$Type, [object]$Value)
            [void]$script:policyCalls.Add([pscustomobject]@{ Scope = $Scope; Name = $Name; Type = $Type })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','Test-Path','New-Item','New-ItemProperty','Remove-ItemProperty','Get-ItemProperty','Set-RegistryValueSafe','Remove-RegistryValueSafe','Set-Policy')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    Context 'TaskbarAlignment' {
        It 'requires Left or Center' {
            { TaskbarAlignment } | Should -Throw
        }

        It 'writes TaskbarAl=0 on Left' {
            TaskbarAlignment -Left

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAl' }).Value | Should -Be 0
            $script:consoleStatuses[-1] | Should -Be 'success'
        }

        It 'writes TaskbarAl=1 on Center' {
            TaskbarAlignment -Center

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAl' }).Value | Should -Be 1
        }

        It 'reports failed when the registry write throws' {
            $script:shouldThrow = $true

            TaskbarAlignment -Center

            $script:consoleStatuses[-1] | Should -Be 'failed'
        }
    }

    Context 'TaskbarSearch' {
        BeforeEach {
            # TaskbarSearch writes an unconditional "clear-policy" New-ItemProperty in HKLM
            # which we just tolerate in the mock.
        }

        It 'writes SearchboxTaskbarMode=0 on -Hide' {
            TaskbarSearch -Hide

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'SearchboxTaskbarMode' }).Value | Should -Be 0
        }

        It 'writes SearchboxTaskbarMode=1 on -SearchIcon' {
            TaskbarSearch -SearchIcon

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'SearchboxTaskbarMode' }).Value | Should -Be 1
        }

        It 'writes SearchboxTaskbarMode=2 on -SearchBox' {
            TaskbarSearch -SearchBox

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'SearchboxTaskbarMode' }).Value | Should -Be 2
        }

        It 'writes SearchboxTaskbarMode=3 on -SearchIconLabel' {
            TaskbarSearch -SearchIconLabel

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'SearchboxTaskbarMode' }).Value | Should -Be 3
        }

        It 'clears the DisableSearch policy up-front' {
            TaskbarSearch -SearchBox

            @($script:policyCalls | Where-Object { $_.Name -eq 'DisableSearch' -and $_.Type -eq 'CLEAR' }).Count | Should -BeGreaterOrEqual 1
        }
    }

    Context 'TaskViewButton' {
        It 'writes ShowTaskViewButton=0 on -Hide' {
            TaskViewButton -Hide

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'ShowTaskViewButton' }).Value | Should -Be 0
        }

        It 'writes ShowTaskViewButton=1 on -Show' {
            TaskViewButton -Show

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'ShowTaskViewButton' }).Value | Should -Be 1
        }
    }

    Context 'TaskbarCombine' {
        It 'writes TaskbarGlomLevel=0 on -Always' {
            TaskbarCombine -Always

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarGlomLevel' }).Value | Should -Be 0
        }

        It 'writes TaskbarGlomLevel=1 on -Full' {
            TaskbarCombine -Full

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarGlomLevel' }).Value | Should -Be 1
        }

        It 'writes TaskbarGlomLevel=2 on -Never' {
            TaskbarCombine -Never

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarGlomLevel' }).Value | Should -Be 2
        }
    }

    Context 'TaskbarEndTask' {
        It 'creates the TaskbarDeveloperSettings key when missing before writing the value' {
            $script:pathExists = $false

            TaskbarEndTask -Enable

            $script:newItemCalls.Count | Should -Be 1
            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarEndTask' }).Value | Should -Be 1
        }

        It 'removes TaskbarEndTask on Disable when the property exists' {
            $script:pathExists = $true
            $script:hasExistingProperty = $true

            TaskbarEndTask -Disable

            $script:removeRegistrySafeCalls[0].Name | Should -Be 'TaskbarEndTask'
        }
    }

    Context 'Set-TaskbarAcrylicOpacity' {
        It 'rejects an opacity above 100' {
            { Set-TaskbarAcrylicOpacity -Opacity 150 } | Should -Throw
        }

        It 'rejects a negative opacity' {
            { Set-TaskbarAcrylicOpacity -Opacity -1 } | Should -Throw
        }

        It 'writes TaskbarAcrylicOpacity with the provided value via Set-RegistryValueSafe' {
            Set-TaskbarAcrylicOpacity -Opacity 45

            $script:setRegistrySafeCalls[0].Name | Should -Be 'TaskbarAcrylicOpacity'
            $script:setRegistrySafeCalls[0].Value | Should -Be 45
        }
    }

    Context 'Set-SmallTaskbarIcons' {
        It 'writes TaskbarSmallIcons=1 via Set-RegistryValueSafe on Enable' {
            Set-SmallTaskbarIcons -Enable

            $script:setRegistrySafeCalls[0].Name | Should -Be 'TaskbarSmallIcons'
            $script:setRegistrySafeCalls[0].Value | Should -Be 1
        }

        It 'removes TaskbarSmallIcons via Remove-RegistryValueSafe on Disable' {
            Set-SmallTaskbarIcons -Disable

            $script:removeRegistrySafeCalls[0].Name | Should -Be 'TaskbarSmallIcons'
        }
    }

    Context 'Set-AltTabEdgeTabFilter' {
        It 'writes MultiTaskingAltTabFilter=1 on Enable' {
            Set-AltTabEdgeTabFilter -Enable

            $script:setRegistrySafeCalls[0].Name | Should -Be 'MultiTaskingAltTabFilter'
            $script:setRegistrySafeCalls[0].Value | Should -Be 1
        }

        It 'removes MultiTaskingAltTabFilter on Disable' {
            Set-AltTabEdgeTabFilter -Disable

            $script:removeRegistrySafeCalls[0].Name | Should -Be 'MultiTaskingAltTabFilter'
        }
    }

    Context 'UnpinTaskbarShortcuts parameter validation' {
        It 'requires the -Shortcuts parameter' {
            { UnpinTaskbarShortcuts } | Should -Throw
        }

        It 'rejects an invalid shortcut name' {
            { UnpinTaskbarShortcuts -Shortcuts 'NonExistent' } | Should -Throw
        }
    }
}
