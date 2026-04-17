Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/Taskbar.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    # Only load the outer (top-level) functions; skip any nested ones (e.g. UnpinTaskbarShortcuts' internals)
    $functions = $ast.FindAll({
            param($node)
            ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and
            ($node.Parent -is [System.Management.Automation.Language.NamedBlockAst])
        }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Taskbar.psm1 region' {
    BeforeEach {
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:warningMessages = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:newItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:newItemCalls = [System.Collections.Generic.List[string]]::new()
        $script:removeItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:policyCalls = [System.Collections.Generic.List[object]]::new()
        $script:setViewModeCalls = [System.Collections.Generic.List[object]]::new()
        $script:getPackageReturns = $true
        $script:machineIdReturn = 'MACHINE-1234'
        $script:settingsBytes = [byte[]]::new(80)
        $script:stuckRectsAvailable = $true
        $script:setViewModeThrows = $false
        $script:pathExists = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) }
        function LogWarning { param([string]$Message) [void]$script:warningMessages.Add($Message) }
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
            [void]$script:newItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name; Value = $Value; PropertyType = $PropertyType })
        }
        function Remove-ItemProperty {
            [CmdletBinding()]
            param([string[]]$Path, [string[]]$Name, [switch]$Force)
            [void]$script:removeItemPropertyCalls.Add([pscustomobject]@{ Path = $Path; Name = $Name })
        }
        function Get-ItemPropertyValue {
            [CmdletBinding()]
            param([string]$Path, [string]$Name)
            if (-not $script:stuckRectsAvailable) { throw 'no StuckRects3' }
            return $script:settingsBytes
        }
        function Set-Policy {
            param([string]$Scope, [string]$Path, [string]$Name, [string]$Type, [object]$Value)
            [void]$script:policyCalls.Add([pscustomobject]@{ Scope = $Scope; Name = $Name; Type = $Type })
        }
        function Get-Package {
            param([string]$Name, [string]$ProviderName)
            if ($script:getPackageReturns) { return [pscustomobject]@{ Name = 'Microsoft Edge' } }
            return $null
        }
        function Set-NewsInterestsTaskbarViewMode {
            param([string]$MachineId, [int]$ViewMode)
            if ($script:setViewModeThrows) { throw 'view-mode update failed' }
            [void]$script:setViewModeCalls.Add([pscustomobject]@{ MachineId = $MachineId; ViewMode = $ViewMode })
        }
        function Remove-HandledErrorRecord { param([object]$ErrorRecord) }
        function Get-TweakSkipLabel { param([object]$MyInvocation) return 'label' }
    }

    AfterEach {
        foreach ($n in @('Write-ConsoleStatus','LogInfo','LogWarning','LogError','Test-Path','New-Item','New-ItemProperty','Remove-ItemProperty','Get-ItemPropertyValue','Set-Policy','Get-Package','Set-NewsInterestsTaskbarViewMode','Remove-HandledErrorRecord','Get-TweakSkipLabel')) {
            Microsoft.PowerShell.Management\Remove-Item Function:\$n -ErrorAction SilentlyContinue
        }
    }

    Context 'NewsInterests' {
        BeforeEach {
            $Global:Localization = [pscustomobject]@{ Skipped = '{0} skipped' }
        }

        AfterEach {
            Remove-Variable -Name Localization -Scope Global -ErrorAction SilentlyContinue
        }

        It 'requires Enable or Disable' {
            { NewsInterests } | Should -Throw
        }

        It 'skips without calling the helper when Edge is not installed' {
            $script:getPackageReturns = $false

            NewsInterests -Disable

            $script:setViewModeCalls.Count | Should -Be 0
            $script:consoleStatuses.Count | Should -Be 0
        }

        It 'calls Set-NewsInterestsTaskbarViewMode with ViewMode 2 on Disable' {
            $script:getPackageReturns = $true

            # The function reads MachineId via [Microsoft.Win32.Registry]::GetValue. We can't
            # easily mock that static call, so we accept whatever real value the host has.
            # Instead we skip if no MachineId is actually present.
            $hasMachineId = [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SQMClient", "MachineId", $null)
            if (-not $hasMachineId) {
                Set-ItResult -Skipped -Because 'no SQMClient MachineId available on this host'
            }

            NewsInterests -Disable

            $script:setViewModeCalls[0].ViewMode | Should -Be 2
            $script:consoleStatuses[-1] | Should -Be 'success'
        }

        It 'calls Set-NewsInterestsTaskbarViewMode with ViewMode 0 on Enable' {
            $script:getPackageReturns = $true

            $hasMachineId = [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SQMClient", "MachineId", $null)
            if (-not $hasMachineId) {
                Set-ItResult -Skipped -Because 'no SQMClient MachineId available on this host'
            }

            NewsInterests -Enable

            $script:setViewModeCalls[0].ViewMode | Should -Be 0
        }

        It 'records a warning when Set-NewsInterestsTaskbarViewMode throws' {
            $script:setViewModeThrows = $true

            $hasMachineId = [Microsoft.Win32.Registry]::GetValue("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SQMClient", "MachineId", $null)
            if (-not $hasMachineId) {
                Set-ItResult -Skipped -Because 'no SQMClient MachineId available on this host'
            }

            NewsInterests -Enable

            $script:consoleStatuses[-1] | Should -Be 'warning'
            $script:warningMessages[0] | Should -Match 'News and Interests'
        }
    }

    Context 'MeetNow' {
        It 'requires Hide or Show' {
            { MeetNow } | Should -Throw
        }

        It 'sets byte index 9 to 128 and writes the binary blob on Hide' {
            $script:settingsBytes = [byte[]](0..31)

            MeetNow -Hide

            $script:newItemPropertyCalls.Count | Should -Be 1
            $script:newItemPropertyCalls[0].Name | Should -Be 'Settings'
            $script:newItemPropertyCalls[0].PropertyType | Should -Be 'Binary'
            $script:newItemPropertyCalls[0].Value[9] | Should -Be 128
        }

        It 'sets byte index 9 to 0 on Show' {
            $script:settingsBytes = [byte[]](0..31)
            $script:settingsBytes[9] = 128

            MeetNow -Show

            $script:newItemPropertyCalls[0].Value[9] | Should -Be 0
        }

        It 'reports failed when StuckRects3 cannot be read' {
            $script:stuckRectsAvailable = $false

            MeetNow -Hide

            $script:consoleStatuses[-1] | Should -Be 'failed'
        }
    }

    Context 'TaskbarAlignment' {
        It 'writes TaskbarAl=0 on Left' {
            TaskbarAlignment -Left

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAl' }).Value | Should -Be 0
        }

        It 'writes TaskbarAl=1 on Center' {
            TaskbarAlignment -Center

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarAl' }).Value | Should -Be 1
        }
    }

    Context 'TaskViewButton' {
        It 'writes ShowTaskViewButton=0 on Hide' {
            TaskViewButton -Hide

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'ShowTaskViewButton' }).Value | Should -Be 0
        }

        It 'writes ShowTaskViewButton=1 on Show' {
            TaskViewButton -Show

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'ShowTaskViewButton' }).Value | Should -Be 1
        }
    }

    Context 'TaskbarCombine' {
        It 'writes TaskbarGlomLevel=0 on Always' {
            TaskbarCombine -Always

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarGlomLevel' }).Value | Should -Be 0
        }

        It 'writes TaskbarGlomLevel=2 on Never' {
            TaskbarCombine -Never

            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarGlomLevel' }).Value | Should -Be 2
        }
    }

    Context 'TaskbarEndTask' {
        It 'creates the key when missing and writes TaskbarEndTask=1 on Enable' {
            $script:pathExists = $false

            TaskbarEndTask -Enable

            $script:newItemCalls.Count | Should -Be 1
            ($script:newItemPropertyCalls | Where-Object { $_.Name -eq 'TaskbarEndTask' }).Value | Should -Be 1
        }
    }

    Context 'UnpinTaskbarShortcuts parameter validation' {
        It 'requires -Shortcuts' {
            { UnpinTaskbarShortcuts } | Should -Throw
        }
    }
}
