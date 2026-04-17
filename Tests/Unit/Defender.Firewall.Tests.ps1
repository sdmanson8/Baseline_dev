Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/Regions/Defender/Defender.Firewall.psm1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Firewall' {
    BeforeEach {
        $script:consoleActions    = [System.Collections.Generic.List[string]]::new()
        $script:consoleStatuses   = [System.Collections.Generic.List[string]]::new()
        $script:infoMessages      = [System.Collections.Generic.List[string]]::new()
        $script:warningMessages   = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages     = [System.Collections.Generic.List[string]]::new()
        $script:removeRegCalls    = [System.Collections.Generic.List[object]]::new()
        $script:newItemCalls      = [System.Collections.Generic.List[string]]::new()
        $script:setItemPropertyCalls = [System.Collections.Generic.List[object]]::new()
        $script:testPathReturnValue = $false

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Action)) { [void]$script:consoleActions.Add($Action) }
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) [void]$script:infoMessages.Add($Message) }
        function LogWarning { param([string]$Message) [void]$script:warningMessages.Add($Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function Remove-RegistryValueSafe {
            param([string]$Path, [string]$Name)
            [void]$script:removeRegCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name })
        }
        function Test-Path {
            param([string]$Path)
            return $script:testPathReturnValue
        }
        function New-Item {
            param([string]$Path, [switch]$Force, [object]$ErrorAction)
            [void]$script:newItemCalls.Add($Path)
        }
        function Set-ItemProperty {
            param([string]$Path, [string]$LiteralPath, [string]$Name, [string]$Type, [object]$Value, [object]$ErrorAction)
            [void]$script:setItemPropertyCalls.Add([pscustomobject]@{ Path = $(if ([string]::IsNullOrEmpty($Path)) { $LiteralPath } else { $Path }); Name = $Name; Type = $Type; Value = $Value })
        }
    }

    AfterEach {
        Remove-Item Function:\Write-ConsoleStatus -ErrorAction SilentlyContinue
        Remove-Item Function:\LogInfo -ErrorAction SilentlyContinue
        Remove-Item Function:\LogWarning -ErrorAction SilentlyContinue
        Remove-Item Function:\LogError -ErrorAction SilentlyContinue
        Remove-Item Function:\Remove-RegistryValueSafe -ErrorAction SilentlyContinue
        Remove-Item Function:\Test-Path -ErrorAction SilentlyContinue
        Remove-Item Function:\New-Item -ErrorAction SilentlyContinue
        Remove-Item Function:\Set-ItemProperty -ErrorAction SilentlyContinue
    }

    It 'requires either Enable or Disable (parameter set validation)' {
        { Firewall } | Should -Throw
    }

    It 'removes the EnableFirewall policy when enabling' {
        Firewall -Enable

        $script:consoleActions[0] | Should -Be 'Enabling Windows Firewall'
        $script:consoleStatuses[-1] | Should -Be 'success'
        $script:removeRegCalls.Count | Should -Be 1
        $script:removeRegCalls[0].Path | Should -Be 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile'
        $script:removeRegCalls[0].Name | Should -Be 'EnableFirewall'
        $script:errorMessages.Count | Should -Be 0
    }

    It 'writes the policy value when disabling and the policy key already exists' {
        $script:testPathReturnValue = $true

        Firewall -Disable

        $script:consoleActions[0] | Should -Be 'Disabling Windows Firewall'
        $script:consoleStatuses[-1] | Should -Be 'success'
        $script:newItemCalls.Count | Should -Be 0
        $script:setItemPropertyCalls.Count | Should -Be 1
        $script:setItemPropertyCalls[0].Name | Should -Be 'EnableFirewall'
        $script:setItemPropertyCalls[0].Value | Should -Be 0
        $script:setItemPropertyCalls[0].Type | Should -Be 'DWord'
    }

    It 'creates the policy key when disabling on a system that lacks it' {
        $script:testPathReturnValue = $false

        Firewall -Disable

        $script:newItemCalls.Count | Should -Be 1
        $script:newItemCalls[0] | Should -Be 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile'
        $script:setItemPropertyCalls.Count | Should -Be 1
    }

    It 'reports failure when enabling throws' {
        function Remove-RegistryValueSafe {
            param([string]$Path, [string]$Name)
            throw 'simulated failure'
        }

        Firewall -Enable

        $script:consoleStatuses[-1] | Should -Be 'failed'
        $script:errorMessages.Count | Should -Be 1
        $script:errorMessages[0] | Should -Match 'simulated failure'
    }
}

Describe 'WindowsFirewallLogging' {
    BeforeEach {
        $script:consoleActions = [System.Collections.Generic.List[string]]::new()
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:infoMessages = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:netshCalls = [System.Collections.Generic.List[string]]::new()

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Action)) { [void]$script:consoleActions.Add($Action) }
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) [void]$script:infoMessages.Add($Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function netsh {
            [void]$script:netshCalls.Add($args -join ' ')
        }
    }

    AfterEach {
        Remove-Item Function:\Write-ConsoleStatus -ErrorAction SilentlyContinue
        Remove-Item Function:\LogInfo -ErrorAction SilentlyContinue
        Remove-Item Function:\LogError -ErrorAction SilentlyContinue
        Remove-Item Function:\netsh -ErrorAction SilentlyContinue
    }

    It 'configures logging with three netsh commands' {
        WindowsFirewallLogging

        $script:consoleActions[0] | Should -Be 'Configuring Windows Firewall logging'
        $script:consoleStatuses[-1] | Should -Be 'success'
        $script:netshCalls.Count | Should -Be 3
        ($script:netshCalls -join "`n") | Should -Match 'pfirewall\.log'
        ($script:netshCalls -join "`n") | Should -Match 'maxfilesize 4096'
        ($script:netshCalls -join "`n") | Should -Match 'droppedconnections enable'
        $script:errorMessages.Count | Should -Be 0
    }
}

Describe 'LOLBinFirewallRules' {
    BeforeEach {
        $script:consoleActions = [System.Collections.Generic.List[string]]::new()
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:infoMessages = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:netshCalls = [System.Collections.Generic.List[string]]::new()

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Action)) { [void]$script:consoleActions.Add($Action) }
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) [void]$script:infoMessages.Add($Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function netsh { [void]$script:netshCalls.Add($args -join ' ') }
    }

    AfterEach {
        Remove-Item Function:\Write-ConsoleStatus -ErrorAction SilentlyContinue
        Remove-Item Function:\LogInfo -ErrorAction SilentlyContinue
        Remove-Item Function:\LogError -ErrorAction SilentlyContinue
        Remove-Item Function:\netsh -ErrorAction SilentlyContinue
    }

    It 'adds outbound block rules for each known LOLBin' {
        LOLBinFirewallRules

        $script:netshCalls.Count | Should -BeGreaterThan 30
        ($script:netshCalls -join "`n") | Should -Match 'Block certutil\.exe netconns'
        ($script:netshCalls -join "`n") | Should -Match 'Block mshta\.exe netconns'
        ($script:netshCalls -join "`n") | Should -Match 'Block regsvr32\.exe netconns'
        ($script:netshCalls -join "`n") | Should -Match 'dir=out'
        ($script:netshCalls -join "`n") | Should -Match 'action=block'
        $script:consoleStatuses[-1] | Should -Be 'success'
        $script:errorMessages.Count | Should -Be 0
    }
}

Describe 'NetworkProtection' {
    BeforeEach {
        $script:consoleActions = [System.Collections.Generic.List[string]]::new()
        $script:consoleStatuses = [System.Collections.Generic.List[string]]::new()
        $script:infoMessages = [System.Collections.Generic.List[string]]::new()
        $script:warningMessages = [System.Collections.Generic.List[string]]::new()
        $script:errorMessages = [System.Collections.Generic.List[string]]::new()
        $script:mpCalls = [System.Collections.Generic.List[object]]::new()
        $Script:DefenderEnabled = $true

        function Write-ConsoleStatus {
            param([string]$Action, [string]$Status)
            if (-not [string]::IsNullOrWhiteSpace($Action)) { [void]$script:consoleActions.Add($Action) }
            if (-not [string]::IsNullOrWhiteSpace($Status)) { [void]$script:consoleStatuses.Add($Status) }
        }
        function LogInfo { param([string]$Message) [void]$script:infoMessages.Add($Message) }
        function LogWarning { param([string]$Message) [void]$script:warningMessages.Add($Message) }
        function LogError { param([string]$Message) [void]$script:errorMessages.Add($Message) }
        function Set-MpPreference {
            param([string]$EnableNetworkProtection, [object]$ErrorAction)
            [void]$script:mpCalls.Add($EnableNetworkProtection)
        }
        function Get-TweakSkipLabel { param($Invocation) return 'NetworkProtection' }
        $Script:Localization = [pscustomobject]@{ Skipped = 'Skipped: {0}' }
    }

    AfterEach {
        Remove-Item Function:\Write-ConsoleStatus -ErrorAction SilentlyContinue
        Remove-Item Function:\LogInfo -ErrorAction SilentlyContinue
        Remove-Item Function:\LogWarning -ErrorAction SilentlyContinue
        Remove-Item Function:\LogError -ErrorAction SilentlyContinue
        Remove-Item Function:\Set-MpPreference -ErrorAction SilentlyContinue
        Remove-Item Function:\Get-TweakSkipLabel -ErrorAction SilentlyContinue
    }

    It 'enables network protection via Set-MpPreference' {
        NetworkProtection -Enable

        $script:mpCalls.Count | Should -Be 1
        $script:mpCalls[0] | Should -Be 'Enabled'
        $script:consoleActions[0] | Should -Match 'Enabling Microsoft Defender Exploit Guard network protection'
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'disables network protection via Set-MpPreference' {
        NetworkProtection -Disable

        $script:mpCalls.Count | Should -Be 1
        $script:mpCalls[0] | Should -Be 'Disabled'
        $script:consoleStatuses[-1] | Should -Be 'success'
    }

    It 'skips entirely when Defender is disabled globally' {
        $Script:DefenderEnabled = $false

        NetworkProtection -Enable

        $script:mpCalls.Count | Should -Be 0
        $script:warningMessages.Count | Should -Be 1
        $script:warningMessages[0] | Should -Match 'Skipped'
    }
}
