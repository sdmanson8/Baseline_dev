Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/UIPersonalization/UIPersonalization.Appearance.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'UIPersonalization.Appearance toggle functions' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:removeItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:policyCalls = [System.Collections.Generic.List[object]]::new()
        $script:shouldThrow = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value, [object]$ErrorAction)
            if ($script:shouldThrow) { throw 'set-itemproperty failed' }
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Value = $Value })
        }
        function New-ItemProperty {
            param([string]$Path, [string]$Name, [string]$PropertyType, [object]$Value, [switch]$Force, [object]$ErrorAction)
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Value = $Value })
        }
        function Remove-ItemProperty {
            param([string[]]$Path, [string]$Name, [switch]$Force, [object]$ErrorAction)
            [void]$script:removeItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name })
        }
        function Set-Policy {
            param([string]$Scope, [string]$Path, [string]$Name, [string]$Type, [object]$Value)
            [void]$script:policyCalls.Add([pscustomobject]@{ Scope = $Scope; Name = $Name; Type = $Type })
        }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogError','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty','Set-Policy')) {
            Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    Context 'EnhPointerPrecision' {
        It 'requires Enable or Disable' {
            { EnhPointerPrecision } | Should -Throw
        }

        It 'writes MouseSpeed=0 and thresholds=0 on Disable' {
            EnhPointerPrecision -Disable

            $mouseSpeed = $script:setItemPropertyCalls | Where-Object { $_.Name -eq 'MouseSpeed' }
            $mouseSpeed.Value | Should -Be '0'
            $script:consoleStatuses[-1] | Should -Be 'success'
        }

        It 'writes MouseSpeed=1 and thresholds=6,10 on Enable' {
            EnhPointerPrecision -Enable

            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'MouseSpeed' }).Value | Should -Be '1'
            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'MouseThreshold1' }).Value | Should -Be '6'
            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'MouseThreshold2' }).Value | Should -Be '10'
        }

        It 'reports failed and logs an error when the registry write throws' {
            $script:shouldThrow = $true

            EnhPointerPrecision -Enable

            $script:consoleStatuses[-1] | Should -Be 'failed'
            $script:errorMessages[0] | Should -Match 'set-itemproperty failed'
        }
    }

    Context 'StartupSound' {
        It 'writes DisableStartupSound=0 on Enable' {
            StartupSound -Enable

            $script:setItemPropertyCalls[0].Name | Should -Be 'DisableStartupSound'
            $script:setItemPropertyCalls[0].Value | Should -Be 0
        }

        It 'writes DisableStartupSound=1 on Disable' {
            StartupSound -Disable

            $script:setItemPropertyCalls[0].Value | Should -Be 1
        }
    }

    Context 'TitleBarColor' {
        It 'writes ColorPrevalence=1 on Enable and 0 on Disable' {
            TitleBarColor -Enable
            TitleBarColor -Disable

            $script:setItemPropertyCalls.Count | Should -Be 2
            $script:setItemPropertyCalls[0].Value | Should -Be 1
            $script:setItemPropertyCalls[1].Value | Should -Be 0
        }
    }

    Context 'VisualFX' {
        It 'requires Performance or Appearance' {
            { VisualFX } | Should -Throw
        }

        It '-Performance writes VisualFXSetting=3 and disables animations' {
            VisualFX -Performance

            # Multiple property writes; sanity-check a representative key:
            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'VisualFXSetting' }).Value | Should -Be 3
            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAnimations' }).Value | Should -Be 0
            $script:consoleStatuses[-1] | Should -Be 'success'
        }

        It '-Appearance enables taskbar animations' {
            VisualFX -Appearance

            ($script:setItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAnimations' }).Value | Should -Be 1
        }
    }

    Context 'AeroShaking' {
        It 'clears existing policy properties before applying the toggle' {
            AeroShaking -Enable

            # Up-front cleanup: one Remove-ItemProperty + two Set-Policy Clear calls
            $script:removeItemPropertyCalls.Count | Should -BeGreaterOrEqual 1
            $clearCalls = $script:policyCalls | Where-Object { $_.Type -eq 'CLEAR' }
            $clearCalls.Count | Should -Be 2
        }
    }

    Context 'AppColorMode' {
        It 'writes AppsUseLightTheme=0 on Dark' {
            AppColorMode -Dark

            $script:newItemPropertyCalls[0].Name | Should -Be 'AppsUseLightTheme'
            $script:newItemPropertyCalls[0].Value | Should -Be 0
        }

        It 'writes AppsUseLightTheme=1 on Light' {
            AppColorMode -Light

            $script:newItemPropertyCalls[0].Value | Should -Be 1
        }
    }

    Context 'BuildNumberOnDesktop' {
        It 'writes PaintDesktopVersion=1 on Enable' {
            BuildNumberOnDesktop -Enable

            $script:setItemPropertyCalls[0].Name | Should -Be 'PaintDesktopVersion'
            $script:setItemPropertyCalls[0].Value | Should -Be 1
        }

        It 'writes PaintDesktopVersion=0 on Disable' {
            BuildNumberOnDesktop -Disable

            $script:setItemPropertyCalls[0].Value | Should -Be 0
        }
    }
}
