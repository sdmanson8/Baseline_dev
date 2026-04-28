Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $functions) {
            if ($fn.Name -in @(
            'Resolve-GuiModePreference',
            'Get-GuiFirstRunWelcomeMarkerPath',
            'Test-GuiFirstRunWelcomePending',
            'Complete-GuiFirstRunWelcome',
            'Get-GuiSettingsSnapshot'
        )) {
            Invoke-Expression $fn.Extent.Text
        }
    }

    function Test-GuiObjectField {
        param(
            [object]$Object,
            [string]$FieldName
        )

        return ($null -ne $Object -and $Object.PSObject.Properties[$FieldName])
    }

    function Convert-JsonManifestValue {
        param([object]$Value)
        return $Value
    }

    function Copy-GuiExplicitSelectionDefinition {
        param(
            [object]$Definition,
            [string]$FunctionName
        )

        return $Definition
    }
}

Describe 'Resolve-GuiModePreference' {
    It 'keeps Safe Mode active when Safe Mode is requested' {
        $result = Resolve-GuiModePreference -SafeMode $true -AdvancedMode $false

        $result.SafeMode | Should -Be $true
        $result.AdvancedMode | Should -Be $false
    }

    It 'keeps Expert Mode active when Expert Mode is requested' {
        $result = Resolve-GuiModePreference -SafeMode $false -AdvancedMode $true

        $result.SafeMode | Should -Be $false
        $result.AdvancedMode | Should -Be $true
    }

    It 'prefers Safe Mode when an old snapshot tries to restore both modes off' {
        $result = Resolve-GuiModePreference -SafeMode $false -AdvancedMode $false

        $result.SafeMode | Should -Be $true
        $result.AdvancedMode | Should -Be $false
    }

    It 'lets Safe Mode win if both flags are somehow true' {
        $result = Resolve-GuiModePreference -SafeMode $true -AdvancedMode $true

        $result.SafeMode | Should -Be $true
        $result.AdvancedMode | Should -Be $false
    }
}

Describe 'First-run welcome state' {
    BeforeEach {
        $script:TestGuiSettingsProfileDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-welcome-tests-{0}" -f ([guid]::NewGuid().ToString('N')))

        <#
            .SYNOPSIS
            Internal function Get-GuiSettingsProfileDirectory.
        #>

        function Get-GuiSettingsProfileDirectory {
            param ([string]$AppName = 'Baseline')
            return $script:TestGuiSettingsProfileDirectory
        }

        <#
            .SYNOPSIS
            Internal function .
        #>
        function LogWarning {
            param ([string]$Message)
        }
    }

    AfterEach {
        Remove-Item -LiteralPath $script:TestGuiSettingsProfileDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Function:\Get-GuiSettingsProfileDirectory -ErrorAction SilentlyContinue
        Remove-Item Function:\LogWarning -ErrorAction SilentlyContinue
    }

    It 'treats a missing welcome marker as pending' {
        Test-GuiFirstRunWelcomePending | Should -Be $true
    }

    It 'marks the welcome as completed after the first successful display' {
        $markerPath = Get-GuiFirstRunWelcomeMarkerPath

        Complete-GuiFirstRunWelcome | Should -Be $true
        (Test-Path -LiteralPath $markerPath) | Should -Be $true
        Test-GuiFirstRunWelcomePending | Should -Be $false
    }
}

Describe 'GUI session snapshots' {
    BeforeEach {
        $script:CurrentThemeName = 'Dark'
        $script:SearchText = ''
        $script:AppsSearchText = ''
        $script:AuditRetentionDays = 90
        $script:AppsPackageSourcePreference = 'auto'
        $script:AppsSourceFilter = 'All'
        $script:PinnedBaselineVersion = $null
        $script:AppsQueuedActions = [System.Collections.Generic.Dictionary[string,string]]::new()
        $script:ExplicitPresetSelections = @()
        $script:ExplicitPresetSelectionDefinitions = [ordered]@{}
        $script:TweakManifest = @()
        $script:Controls = @()
        $script:AdvancedMode = $false
        $script:SafeMode = $false
        $script:GameMode = $false
        $script:DesignMode = $true
        $script:RiskFilter = 'All'
        $script:CategoryFilter = 'All'
        $script:PlatformFilter = 'ThisDevice'
        $script:AppsCategoryFilter = 'All'
        $script:AppsStatusFilter = 'All'
        $script:SelectedOnlyFilter = $false
        $script:HideUnavailableItems = $true
        $script:HighRiskOnlyFilter = $false
        $script:RestorableOnlyFilter = $false
        $script:GamingOnlyFilter = $false
        $script:LastStandardPrimaryTab = $null
        $script:GameModePreviousPrimaryTab = $null
    }

    It 'captures Design Mode in the GUI snapshot' {
        $snapshot = Get-GuiSettingsSnapshot

        $snapshot.DesignMode | Should -Be $true
        $snapshot.HideUnavailableItems | Should -Be $true
    }
}
