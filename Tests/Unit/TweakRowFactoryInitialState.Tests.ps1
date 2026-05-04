Set-StrictMode -Version Latest

BeforeAll {
    <#
        .SYNOPSIS
        Internal function Test-GuiObjectField.
    #>

    function Test-GuiObjectField { param([object]$Object, [string]$FieldName) if ($null -eq $Object) { return $false }; if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($FieldName) }; return [bool]($Object.PSObject -and $Object.PSObject.Properties[$FieldName]) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function Get-GuiObjectField { param([object]$Object, [string]$FieldName) if ($null -eq $Object) { return $null }; if ($Object -is [System.Collections.IDictionary]) { return $Object[$FieldName] }; if ($Object.PSObject -and $Object.PSObject.Properties[$FieldName]) { return $Object.PSObject.Properties[$FieldName].Value }; return $null }
    $filePath = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory.ps1'
    $splitRoot = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory'
    $filePaths = @(
        $filePath
        (Join-Path $splitRoot 'RowStateDefaults.ps1')
        (Join-Path $splitRoot 'MetadataDetails.ps1')
        (Join-Path $splitRoot 'ControlFactories.ps1')
    )
    $script:FileContent = @($filePaths | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding UTF8 }) -join "`n"
    $script:FunctionTextByName = @{}
    foreach ($path in $filePaths) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $functions) {
            $script:FunctionTextByName[$fn.Name] = $fn.Extent.Text
            if ($fn.Name -in @('Get-GameModePlanEntryForTweak', 'Get-ToggleInitialCheckedState', 'Get-ActionInitialCheckedState', 'Get-ChoiceInitialSelectedIndex', 'ConvertTo-GuiDateTimeValue', 'Get-DateInitialRunState', 'Get-DateInitialSelectedDate')) {
                Invoke-Expression $fn.Extent.Text
            }
        }
    }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Get-GameModePlan {
        return @($script:TestGameModePlan)
    }

    <#
        .SYNOPSIS
        Internal function Get-GuiExplicitSelectionDefinition.
    #>

    function Get-GuiExplicitSelectionDefinition {
        param([string]$FunctionName)

        if ($script:ExplicitSelectionDefinitions.ContainsKey($FunctionName)) {
            return $script:ExplicitSelectionDefinitions[$FunctionName]
        }

        return $null
    }
}

Describe 'Tweak row content pins' {
    It 'routes tweak-row opacity updates through Write-DebugSwallowedException' {
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Update-TweakRowState\.CardOpacity'''
    }

    It 'routes hover and focus chrome updates through Write-DebugSwallowedException' {
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_MouseEnter'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_MouseLeave'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_PreviewMouseLeftButtonDown'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_PreviewMouseLeftButtonUp'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_GotKeyboardFocus'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.Add_LostKeyboardFocus'''
        $script:FileContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''TweakRowFactory\.Build-TweakRowCard\.UpdateChrome'''
    }

    It 'separates tweak cards with soft elevation instead of hard shadow offsets' {
        $script:FileContent | Should -Match '\$shadow\.ShadowDepth = 0'
        $script:FileContent | Should -Match '\$shadow\.Opacity = if \(\$isLight\) \{ 0\.04 \} else \{ 0\.18 \}'
        $script:FileContent | Should -Match '\$shadow\.BlurRadius = if \(\$isLight\) \{ 8 \} else \{ 18 \}'
    }

    It 'uses divider-only row chrome instead of boxed row borders' {
        $script:FileContent | Should -Match 'RowDivider\s+= \[System\.Windows\.Thickness\]::new\(0, 0, 0, 1\)'
        $script:FileContent | Should -Match 'RowDividerFocus\s+= \[System\.Windows\.Thickness\]::new\(0, 0, 0, 2\)'
        $script:FileContent | Should -Match 'Thickness1\s+= if \(\$isLight\) \{ \$Script:T\.CardBorder \} else \{ \$Script:T\.RowDivider \}'
        $script:FileContent | Should -Match 'Thickness2\s+= if \(\$isLight\) \{ \$Script:T\.CardBorderFocus \} else \{ \$Script:T\.RowDividerFocus \}'
        $script:FileContent | Should -Match 'AccentBorder\s+= \[System\.Windows\.Thickness\]::new\(3, 0, 0, 1\)'
        $script:FileContent | Should -Match 'RowCardPadding\s+= \[System\.Windows\.Thickness\]::new\(12, 8, 12, 8\)'
    }

    It 'does not render per-row reset actions in the primary row header' {
        $script:FileContent | Should -Not -Match '-ActionButton \$ResetButton'
        $script:FunctionTextByName['New-ToggleLikeHeaderGrid'] | Should -Not -Match 'ResetButton'
        $script:FunctionTextByName['New-ChoiceHeaderGrid'] | Should -Not -Match 'ResetButton'
        $script:FileContent | Should -Not -Match 'New-ToggleLikeHeaderGrid[^\r\n]+-ResetButton'
        $script:FileContent | Should -Not -Match 'New-ChoiceHeaderGrid[^\r\n]+-ResetButton'
    }

    It 'keeps tweak details collapsed behind row-level Show details controls' {
        $script:FileContent | Should -Match 'Set-TweakSearchHighlightedTextBlock'
        $script:FileContent | Should -Match '\$detailsPanel\.Visibility = \[System\.Windows\.Visibility\]::Collapsed'
        $script:FileContent | Should -Match "Get-UxString -Key 'GuiShowDetails' -Fallback 'Show details'"
        $script:FileContent | Should -Match "Get-UxString -Key 'GuiHideDetails' -Fallback 'Hide details'"
        $script:FileContent | Should -Match 'Add-TweakDetailLine -Container \$detailsPanel .*GuiSectionImpact'
        $script:FileContent | Should -Match 'Add-TweakDetailLine -Container \$detailsPanel .*GuiSectionBehavior'
        $script:FileContent | Should -Match 'Add-TweakDetailLine -Container \$detailsPanel .*GuiSectionRecovery'
        $script:FileContent | Should -Match 'Add-TweakDetailLine -Container \$detailsPanel .*GuiSectionTags'
    }
}

Describe 'Tweak row initial state recovery' {
    BeforeEach {
        $script:GameMode = $false
        $script:TestGameModePlan = @()
        $script:ExplicitSelectionDefinitions = @{}
        $script:Controls = @{}
    }

    Describe 'Get-ToggleInitialCheckedState' {
        It 'uses explicit preset On state when the tab control has not been built yet' {
            $script:ExplicitSelectionDefinitions['DemoToggle'] = [pscustomobject]@{
                Function = 'DemoToggle'
                Type = 'Toggle'
                State = 'On'
                Source = 'Preset'
            }

            $result = Get-ToggleInitialCheckedState -Index 42 -Tweak ([pscustomobject]@{
                Function = 'DemoToggle'
                OnParam = 'Enable'
                OffParam = 'Disable'
            })

            $result | Should -BeTrue
        }

        It 'uses explicit preset Off state when the tab control has not been built yet' {
            $script:ExplicitSelectionDefinitions['DemoToggle'] = [pscustomobject]@{
                Function = 'DemoToggle'
                Type = 'Toggle'
                State = 'Off'
                Source = 'Preset'
            }

            $result = Get-ToggleInitialCheckedState -Index 42 -Tweak ([pscustomobject]@{
                Function = 'DemoToggle'
                OnParam = 'Enable'
                OffParam = 'Disable'
            })

            $result | Should -BeFalse
        }

        It 'keeps game mode plan precedence over explicit preset state' {
            $script:GameMode = $true
            $script:TestGameModePlan = @(
                [pscustomobject]@{
                    Function = 'DemoToggle'
                    ToggleParam = 'Enable'
                }
            )
            $script:ExplicitSelectionDefinitions['DemoToggle'] = [pscustomobject]@{
                Function = 'DemoToggle'
                Type = 'Toggle'
                State = 'Off'
                Source = 'Preset'
            }

            $result = Get-ToggleInitialCheckedState -Index 42 -Tweak ([pscustomobject]@{
                Function = 'DemoToggle'
                OnParam = 'Enable'
                OffParam = 'Disable'
            })

            $result | Should -BeTrue
        }
    }

    Describe 'New-ToggleLikeHeaderGrid accessibility' {
        It 'binds explicit tweak descriptions into AutomationProperties.HelpText' {
            $script:FunctionTextByName['New-ToggleLikeHeaderGrid'] | Should -Match '\[System\.Windows\.Automation\.AutomationProperties\]::SetHelpText\(\$CheckBox, \$helpText\)'
            $script:FunctionTextByName['New-ToggleLikeHeaderGrid'] | Should -Match 'Get-UxString -Key \$Tweak\.DescriptionKey -Fallback \$Tweak\.Description'
            $script:FunctionTextByName['New-ToggleLikeHeaderGrid'] | Should -Match '\[string\]\$Tweak\.Description'
        }
    }

    Describe 'Get-ActionInitialCheckedState' {
        It 'uses explicit preset action selections when the tab control has not been built yet' {
            $script:ExplicitSelectionDefinitions['DemoAction'] = [pscustomobject]@{
                Function = 'DemoAction'
                Type = 'Action'
                Run = $true
                Source = 'Preset'
            }

            $result = Get-ActionInitialCheckedState -Index 7 -Tweak ([pscustomobject]@{
                Function = 'DemoAction'
            })

            $result | Should -BeTrue
        }
    }

    Describe 'Get-ChoiceInitialSelectedIndex' {
        It 'prefers explicit preset choices over stale placeholder state' {
            $script:Controls[3] = [pscustomobject]@{
                SelectedIndex = 0
            }
            $script:ExplicitSelectionDefinitions['DemoChoice'] = [pscustomobject]@{
                Function = 'DemoChoice'
                Type = 'Choice'
                Value = 'Uninstall'
                Source = 'Preset'
            }

            $rowContext = [pscustomobject]@{
                GetExplicitSelectionDefinition = {
                    param([string]$FunctionName)

                    if ($script:ExplicitSelectionDefinitions.ContainsKey($FunctionName)) {
                        return $script:ExplicitSelectionDefinitions[$FunctionName]
                    }

                    return $null
                }
            }

            $result = Get-ChoiceInitialSelectedIndex -Index 3 -Tweak ([pscustomobject]@{
                Function = 'DemoChoice'
            }) -ChoiceOptions @('Install', 'Uninstall') -RowContext $rowContext

            $result | Should -Be 1
        }

        It 'falls back to placeholder choice state when no explicit preset exists' {
            $script:Controls[3] = [pscustomobject]@{
                SelectedIndex = 0
            }

            $rowContext = [pscustomobject]@{
                GetExplicitSelectionDefinition = {
                    param([string]$FunctionName)
                    return $null
                }
            }

            $result = Get-ChoiceInitialSelectedIndex -Index 3 -Tweak ([pscustomobject]@{
                Function = 'DemoChoice'
            }) -ChoiceOptions @('Install', 'Uninstall') -RowContext $rowContext

            $result | Should -Be 0
        }
    }

    Describe 'Get-DateInitialRunState' {
        It 'honours explicit preset date selections when the tab control has not been built yet' {
            $script:ExplicitSelectionDefinitions['DemoDate'] = [pscustomobject]@{
                Function = 'DemoDate'
                Type = 'Date'
                Run = $true
                Value = '2025-04-08'
                DateParam = 'StartDate'
                Source = 'Preset'
            }

            $result = Get-DateInitialRunState -Index 9 -Tweak ([pscustomobject]@{
                Function = 'DemoDate'
                DateParam = 'StartDate'
            })

            $result | Should -BeTrue
        }

        It 'keeps unchecked explicit date selections as unchecked' {
            $script:ExplicitSelectionDefinitions['DemoDate'] = [pscustomobject]@{
                Function = 'DemoDate'
                Type = 'Date'
                Run = $false
                Value = '2025-04-08'
                DateParam = 'StartDate'
                Source = 'Preset'
            }

            $result = Get-DateInitialRunState -Index 9 -Tweak ([pscustomobject]@{
                Function = 'DemoDate'
                DateParam = 'StartDate'
            })

            $result | Should -BeFalse
        }
    }

    Describe 'Get-DateInitialSelectedDate' {
        It 'prefers explicit preset date values over stale placeholder state' {
            $script:Controls[4] = [pscustomobject]@{
                SelectedDate = [datetime]'2024-01-01'
            }
            $script:ExplicitSelectionDefinitions['DemoDate'] = [pscustomobject]@{
                Function = 'DemoDate'
                Type = 'Date'
                Run = $true
                Value = '2025-04-08'
                DateParam = 'StartDate'
                Source = 'Preset'
            }

            $result = Get-DateInitialSelectedDate -Index 4 -Tweak ([pscustomobject]@{
                Function = 'DemoDate'
                DateParam = 'StartDate'
            })

            $result.ToString('yyyy-MM-dd') | Should -Be '2025-04-08'
        }

        It 'falls back to placeholder selected dates when no explicit preset exists' {
            $script:Controls[4] = [pscustomobject]@{
                SelectedDate = [datetime]'2024-01-01'
            }

            $result = Get-DateInitialSelectedDate -Index 4 -Tweak ([pscustomobject]@{
                Function = 'DemoDate'
                DateParam = 'StartDate'
            })

            $result.ToString('yyyy-MM-dd') | Should -Be '2024-01-01'
        }
    }

    Describe 'Numeric range row wiring' {
        It 'resolves the shared label font size through the guarded helper inside the toggle-like checkbox helper' {
            $script:FunctionTextByName['New-ToggleLikeCheckBox'] | Should -Match '(?i)\$checkBox\.FontSize\s*=\s*GUICommon\\Get-GuiSafeFontSize\s*-Key\s*''FontSizeLabel''\s*-Default\s*11'
        }

        It 'does not force FontSize onto the numeric-range checkbox or slider controls' {
            $numericRangeText = $script:FunctionTextByName['New-NumericRangeTweakRow']

            $numericRangeText | Should -Not -Match '(?i)\$checkBox\.FontSize\s*='
            $numericRangeText | Should -Not -Match '(?i)\$slider\.FontSize\s*='
        }
    }
}
