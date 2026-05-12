Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    Add-Type -AssemblyName PresentationFramework

    $script:controlFactoriesPath = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory/ControlFactories.ps1'
    $script:uwpAppsPath = Join-Path $PSScriptRoot '../../Module/Regions/UWPApps.psm1'
    $script:ControlFactoriesContent = Get-BaselineTestSourceText -Path $script:controlFactoriesPath
    $script:UwpAppsContent = Get-BaselineTestSourceText -Path $script:uwpAppsPath

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:controlFactoriesPath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    function script:Test-GuiObjectField {
        param([object]$Object, [string]$FieldName)
        if ($null -eq $Object) { return $false }
        if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($FieldName) }
        return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName])
    }

    foreach ($fn in $functions) {
        if ($fn.Name -in @(
            'Register-GuiChoiceSelectionHandler',
            'Register-GuiActionSelectionHandlers',
            'Register-GuiToggleExplicitSelectionHandlers'
        )) {
            Invoke-Expression $fn.Extent.Text
        }
    }

    Set-Item -Path Function:\global:Test-GuiObjectField -Value ${function:script:Test-GuiObjectField}

    function Register-GuiEventHandler {
        param(
            [object]$Source,
            [string]$EventName,
            [scriptblock]$Handler
        )

        if (-not $Source.PSObject.Properties['CapturedHandlers']) {
            Add-Member -InputObject $Source -NotePropertyName 'CapturedHandlers' -NotePropertyValue @{} -Force
        }

        $Source.CapturedHandlers[$EventName] = $Handler
        return $null
    }

    function script:NewRowContext {
        $selectionStore = @{}

        return [pscustomobject]@{
            SelectionStore = $selectionStore
            GetExplicitSelectionDefinition = {
                param([string]$FunctionName)
                if ($selectionStore.ContainsKey($FunctionName)) {
                    return $selectionStore[$FunctionName]
                }
                return $null
            }.GetNewClosure()
            SetExplicitSelectionDefinition = {
                param([string]$FunctionName, [object]$Definition)
                $selectionStore[$FunctionName] = $Definition
            }.GetNewClosure()
            RemoveExplicitSelectionDefinition = {
                param([string]$FunctionName)
                if ($selectionStore.ContainsKey($FunctionName)) {
                    [void]$selectionStore.Remove($FunctionName)
                }
            }.GetNewClosure()
            SyncGameModePlanFromControlsScript = $null
        }
    }
}

Describe 'Manual explicit selection persistence' {
    It 'creates a manual explicit choice selection outside a preset' {
        $combo = [System.Windows.Controls.ComboBox]::new()
        [void]$combo.Items.Add('Install')
        [void]$combo.Items.Add('Uninstall')
        $combo.SelectedIndex = 1
        $rowContext = NewRowContext
        $stateControl = [pscustomobject]@{ IsRestoring = $false }

        Register-GuiChoiceSelectionHandler -ComboBox $combo -FunctionName 'WindowsCapabilities' -ChoiceOptions @('Install', 'Uninstall') -RowContext $rowContext -StateControl $stateControl
        & $combo.CapturedHandlers['SelectionChanged']

        $rowContext.SelectionStore['WindowsCapabilities'].Type | Should -Be 'Choice'
        $rowContext.SelectionStore['WindowsCapabilities'].Value | Should -Be 'Uninstall'
        $rowContext.SelectionStore['WindowsCapabilities'].Source | Should -Be 'Manual'
    }

    It 'creates a manual explicit action selection outside a preset' {
        $checkBox = [System.Windows.Controls.CheckBox]::new()
        $checkBox.IsChecked = $true
        $rowContext = NewRowContext
        $stateControl = [pscustomobject]@{ IsRestoring = $false }

        Register-GuiActionSelectionHandlers -CheckBox $checkBox -FunctionName 'CreateRestorePoint' -RowContext $rowContext -StateControl $stateControl
        & $checkBox.CapturedHandlers['Checked']

        $rowContext.SelectionStore['CreateRestorePoint'].Type | Should -Be 'Action'
        $rowContext.SelectionStore['CreateRestorePoint'].Run | Should -BeTrue
        $rowContext.SelectionStore['CreateRestorePoint'].Source | Should -Be 'Manual'
    }

    It 'does not require module-scoped field helper when a toggle event fires' {
        $checkBox = [System.Windows.Controls.CheckBox]::new()
        $rowContext = NewRowContext
        $stateControl = [pscustomobject]@{ IsRestoring = $false }
        $rowContext.SelectionStore['DemoToggle'] = [pscustomobject]@{
            Function = 'DemoToggle'
            Type = 'Toggle'
            State = 'On'
            Source = 'Preset'
        }

        $savedFunction = Get-Item -Path Function:\global:Test-GuiObjectField -ErrorAction SilentlyContinue
        Remove-Item -Path Function:\global:Test-GuiObjectField -ErrorAction SilentlyContinue
        try {
            Register-GuiToggleExplicitSelectionHandlers -CheckBox $checkBox -FunctionName 'DemoToggle' -RowContext $rowContext -StateControl $stateControl
            { & $checkBox.CapturedHandlers['Unchecked'] } | Should -Not -Throw
        }
        finally {
            if ($savedFunction) {
                Set-Item -Path Function:\global:Test-GuiObjectField -Value $savedFunction.ScriptBlock
            }
        }

        $rowContext.SelectionStore['DemoToggle'].Type | Should -Be 'Toggle'
        $rowContext.SelectionStore['DemoToggle'].State | Should -Be 'Off'
        $rowContext.SelectionStore['DemoToggle'].Source | Should -Be 'Preset'
    }
}

Describe 'UWPApps selection dialogs' {
    It 'guards uninstall picker repopulation against empty package lists' {
        $script:UwpAppsContent | Should -Match '\$AppXPackages = @\(Get-AppxBundle -Exclude \$ExcludedAppxPackages -AllUsers:\$CheckBoxForAllUsers\.IsChecked \| Where-Object \{ \$null -ne \$_ \}\)'
        $script:UwpAppsContent | Should -Match 'if \(\$AppXPackages\.Count -gt 0\)\s*\{\s*Add-UWPAppsUninstallPickerControl -Packages \$AppXPackages'
    }

    It 'guards install picker repopulation against empty package lists' {
        $script:UwpAppsContent | Should -Match '\$MissingPackages = @\(Get-MissingAppxPackages -AllUsers:\$CheckBoxForAllUsers\.IsChecked \| Where-Object \{ \$null -ne \$_ \}\)'
    }
}
