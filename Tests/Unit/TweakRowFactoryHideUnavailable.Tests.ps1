Set-StrictMode -Version Latest

BeforeAll {
    # Extract the Test-TweakRowVisible function from TweakRowFactory.ps1 via AST
    # so the test exercises the real source without loading the full GUI module.
    $splitRoot = Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory'
    $sourceFiles = @(
        (Join-Path $PSScriptRoot '../../Module/GUI/TweakRowFactory.ps1')
        (Join-Path $splitRoot 'RowStateDefaults.ps1')
        (Join-Path $splitRoot 'MetadataDetails.ps1')
        (Join-Path $splitRoot 'ControlFactories.ps1')
    )
    $script:FunctionTextByName = @{}
    foreach ($sourceFile in $sourceFiles) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourceFile, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $functions) {
            $script:FunctionTextByName[$fn.Name] = $fn.Extent.Text
        }
    }
    if ($script:FunctionTextByName.ContainsKey('Test-TweakRowVisible')) {
        Invoke-Expression $script:FunctionTextByName['Test-TweakRowVisible']
    } else {
        throw 'Test-TweakRowVisible was not found in TweakRowFactory.ps1'
    }

    # Mock the user-preference accessor that Test-TweakRowVisible delegates to.
    # The script-scoped variable lets each It block flip the pref.
    $script:HideUnavailablePrefValue = $true
    function Get-BaselineUserPreference {
        param([string]$Key, [object]$Default = $null)
        if ($Key -eq 'HideUnavailableItems') { return $script:HideUnavailablePrefValue }
        return $Default
    }

    function script:NewAvailableTweak {
        return [pscustomobject]@{
            Name = 'AvailableEntry'
            Function = 'AvailableEntry'
            Type = 'Toggle'
            Availability = [pscustomobject]@{
                Available = $true
                UnavailableReason = $null
            }
        }
    }

    function script:NewUnavailableTweak {
        param([string]$Reason = 'Requires Windows 11')
        return [pscustomobject]@{
            Name = 'UnavailableEntry'
            Function = 'UnavailableEntry'
            Type = 'Toggle'
            Availability = [pscustomobject]@{
                Available = $false
                UnavailableReason = $Reason
            }
        }
    }
}

Describe 'Test-TweakRowVisible HideUnavailableItems gate' {
    It 'returns $true for an available entry when HideUnavailableItems = $true' {
        $script:HideUnavailablePrefValue = $true
        $tweak = NewAvailableTweak
        Test-TweakRowVisible -Tweak $tweak | Should -BeTrue
    }

    It 'returns $true for an available entry when HideUnavailableItems = $false' {
        $script:HideUnavailablePrefValue = $false
        $tweak = NewAvailableTweak
        Test-TweakRowVisible -Tweak $tweak | Should -BeTrue
    }

    It 'returns $false for an unavailable entry when HideUnavailableItems = $true' {
        $script:HideUnavailablePrefValue = $true
        $tweak = NewUnavailableTweak
        Test-TweakRowVisible -Tweak $tweak | Should -BeFalse
    }

    It 'returns $true for an unavailable entry when HideUnavailableItems = $false (rendered greyed)' {
        $script:HideUnavailablePrefValue = $false
        $tweak = NewUnavailableTweak
        Test-TweakRowVisible -Tweak $tweak | Should -BeTrue
    }

    It 'still hides an entry whose VisibleIf returns $false even when available' {
        $script:HideUnavailablePrefValue = $false
        $tweak = [pscustomobject]@{
            Name = 'GatedEntry'
            Function = 'GatedEntry'
            Type = 'Toggle'
            Availability = [pscustomobject]@{ Available = $true; UnavailableReason = $null }
            VisibleIf = { $false }
        }
        Test-TweakRowVisible -Tweak $tweak | Should -BeFalse
    }

    It 'defaults to hiding unavailable rows when Get-BaselineUserPreference is unavailable' {
        # Simulate the function being absent by removing it for this case.
        Remove-Item Function:Get-BaselineUserPreference -ErrorAction SilentlyContinue
        try {
            $tweak = NewUnavailableTweak
            Test-TweakRowVisible -Tweak $tweak | Should -BeFalse
        }
        finally {
            # Restore for other tests in the file.
            function script:Get-BaselineUserPreference {
                param([string]$Key, [object]$Default = $null)
                if ($Key -eq 'HideUnavailableItems') { return $script:HideUnavailablePrefValue }
                return $Default
            }
        }
    }
}
