Set-StrictMode -Version Latest

BeforeAll {
    . (Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1')

    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $actionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $actionHandlersSplitRoot = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers'
    $errorHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/ErrorHandling.Helpers.ps1'
    $environmentHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/Environment.Helpers.ps1'
    $initialActionsPath = Join-Path $PSScriptRoot '../../Module/Regions/InitialActions.psm1'
    $initialSetupPath = Join-Path $PSScriptRoot '../../Module/Regions/InitialSetup.psm1'
    $initialSetupManifestPath = Join-Path $PSScriptRoot '../../Module/Data/InitialSetup.json'
    $detectScriptblocksPath = Join-Path $PSScriptRoot '../../Module/GUI/DetectScriptblocks.ps1'

    $guiContent = Get-Content -LiteralPath $guiPath -Raw -Encoding UTF8
    $actionHandlersContent = Get-BaselineTestSourceText -Path @(
        $actionHandlersPath
        (Join-Path $actionHandlersSplitRoot 'ThemeNavigationHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'ButtonHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'SystemScanFooterHandlers.ps1')
        (Join-Path $actionHandlersSplitRoot 'MenuHandlers.ps1')
    )
    $errorHelpersContent = Get-Content -LiteralPath $errorHelpersPath -Raw -Encoding UTF8
    $environmentHelpersContent = Get-Content -LiteralPath $environmentHelpersPath -Raw -Encoding UTF8
    $initialActionsContent = Get-Content -LiteralPath $initialActionsPath -Raw -Encoding UTF8
    $initialSetupContent = Get-Content -LiteralPath $initialSetupPath -Raw -Encoding UTF8
    $detectScriptblocksContent = Get-Content -LiteralPath $detectScriptblocksPath -Raw -Encoding UTF8
    $initialSetupManifest = Get-Content -LiteralPath $initialSetupManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $initialSetupAst = [System.Management.Automation.Language.Parser]::ParseFile($initialSetupPath, [ref]$null, [ref]$null)
    $initialSetupBootstrapFunction = $initialSetupAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Initialize-PackageManagersBootstrap'
    }, $true) | Select-Object -First 1
    $initialSetupCheckWinGetFunction = $initialSetupAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'CheckWinGet'
    }, $true) | Select-Object -First 1
}

Describe 'First-run startup command wiring' {
        It 'resolves first-run GUI commands before startup handlers run' {
                $guiContent | Should -Match "Get-Item function:Show-ThemedDialog"
                $guiContent | Should -Match "Get-Item function:Show-FirstRunWelcomeDialog"
                $guiContent | Should -Match "Get-UxFirstRunWelcomeMessage"
                $guiContent | Should -Match "Get-Command 'Show-HelpDialog'"
                $guiContent | Should -Match "Get-Command 'Set-GuiPresetSelection'"
                $guiContent | Should -Match "Get-Command 'Set-GuiStatusText'"
                $guiContent | Should -Match "Get-Command 'Get-UxRecommendedPresetName'"
                $guiContent | Should -Match "Get-Command 'Get-GuiFirstRunWelcomeMarkerPath'"
    }

    It 'uses the same runtime-command pattern for the New Start Here action' {
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-ThemedDialog'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-HelpDialog'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Set-GuiPresetSelection'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Get-UxRecommendedPresetName'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Get-UxPresetLoadedStatusText'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Get-UxFirstRunPrimaryActionLabel'"
		$actionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Get-UxFirstRunWelcomeMessage'"
        $actionHandlersContent | Should -Not -Match '\$welcomeMessage\s*=\s*Get-UxFirstRunWelcomeMessage'
        $actionHandlersContent | Should -Not -Match '\$choice\s*=\s*Show-ThemedDialog\s+-Title\s+''Welcome to Baseline'''
        $actionHandlersContent | Should -Match "Show-HelpDialog not found\."
    }

    It 'persists restore-last-session through the GUI preference store' {
        $actionHandlersContent | Should -Match 'Get-BaselineUserPreference -Key ''RestoreLastSession'' -Default \$true'
        $actionHandlersContent | Should -Match 'Set-BaselineUserPreference -Key ''RestoreLastSession'' -Value \$restoreLastSessionWanted'
    }

    It 'maps a missing help dialog function to the startup-command error code' {
        $errorHelpersContent | Should -Match "'\*Show-HelpDialog not found\*' \{ return 'GUI-STARTUP-004' \}"
    }

    It 'boots the package managers from InitialActions during GUI startup' {
        $initialActionsContent | Should -Match 'Initialize-PackageManagersBootstrap\s+-LoadingSplash\s+\$Global:LoadingSplash'
        $initialActionsContent | Should -Not -Match 'CheckWinGet\s+-LoadingSplash\s+\$Global:LoadingSplash'
    }

    It 'restores the neutral splash loading text after startup bootstrap' {
        $environmentHelpersContent | Should -Match "GuiSplashLoading' -Fallback 'Please Wait\.\.\.'"
        $environmentHelpersContent | Should -Not -Match "GuiSplashLoading' -Fallback 'Please wait - opening GUI\.\.\.'"
    }

    It 'keeps the advisory tweaker probes non-fatal during startup' {
        $initialActionsContent | Should -Match '\$InvokeOptionalProbe\s*=\s*\{\s*param\(\[scriptblock\]\$ScriptBlock\)'
        $initialActionsContent | Should -Match '\$AutoSettingsPS\s*=\s*&\s*\$InvokeOptionalProbe'
        $initialActionsContent | Should -Match '\$Flibustier\s*=\s*&\s*\$InvokeOptionalProbe'
    }

    It 'keeps WinGet active in the startup bootstrap helper' {
        $wingetCommands = @($initialSetupBootstrapFunction.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and $node.Extent.Text -match 'WinGetBootstrap'
        }, $true))
        $wingetCommands | Should -Not -BeNullOrEmpty

        $chocolateyCommands = @($initialSetupBootstrapFunction.Body.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and $node.Extent.Text -match 'ChocolateyBootstrap'
        }, $true))
        $chocolateyCommands | Should -Not -BeNullOrEmpty
    }

    It 'queues the Chocolatey startup bootstrap job unconditionally (no approval gate)' {
        $initialSetupContent | Should -Not -Match "Test-BaselineEnvironmentFlagEnabled\s+-Name\s+'BASELINE_ALLOW_CHOCOLATEY_BOOTSTRAP'"
        $initialSetupContent | Should -Match "Start-Job\s+-Name\s+'ChocolateyBootstrap'"
    }

        It 'uses the shared reviewed winget-install metadata instead of duplicating the release pin' {
        $initialSetupContent | Should -Match 'Get-WinGetBootstrapInstallerMetadata'
        $initialSetupContent | Should -Not -Match '\$installerVersion\s*=\s*''5\.3\.1'''
        $initialSetupContent | Should -Not -Match '\$installerSha256\s*=\s*''029094EFD9D26A83AEA184B16D15C772D35D64E1288010741F50FD33A1E1F40F'''
    }

    It 'uses the shared generic winget-install arguments so Server 2019 stays on the repo-defined path' {
        $initialSetupContent | Should -Match 'Get-WinGetBootstrapInstallerArguments'
        $initialSetupContent | Should -Not -Match "'-AlternateInstallMethod'"
    }

    It 'keeps CheckWinGet hidden while preserving the preset and headless hook' {
        $initialSetupCheckWinGetFunction | Should -Not -BeNullOrEmpty
        $detectScriptblocksContent | Should -Match '''CheckWinGet''\s*=\s*\{\s*\$false\s*\}'

        $checkWinGetEntry = @($initialSetupManifest.Entries | Where-Object { [string]$_.Function -eq 'CheckWinGet' })
        $checkWinGetEntry | Should -Not -BeNullOrEmpty
        [string]$checkWinGetEntry[0].Name | Should -Be 'Check WinGet'
        [string]$checkWinGetEntry[0].Description | Should -Not -BeNullOrEmpty

        $packageManagerEntries = @(
            $initialSetupManifest.Entries | Where-Object {
                [string]$_.Name -eq 'Check and Install Package Managers' -or
                [string]$_.Function -eq 'Initialize-PackageManagers'
            }
        )
        $packageManagerEntries | Should -BeNullOrEmpty
    }
}
