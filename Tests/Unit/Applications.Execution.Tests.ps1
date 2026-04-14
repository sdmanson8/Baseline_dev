Set-StrictMode -Version Latest

BeforeAll {
    $applicationsPath = Join-Path $PSScriptRoot '../../Module/Regions/Applications.psm1'
    $applicationsAst = [System.Management.Automation.Language.Parser]::ParseFile($applicationsPath, [ref]$null, [ref]$null)
    $applicationsFunctions = $applicationsAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $applicationsFunctions)
    {
        Invoke-Expression $fn.Extent.Text
    }

    $guiPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $guiAst = [System.Management.Automation.Language.Parser]::ParseFile($guiPath, [ref]$null, [ref]$null)
    $guiFunctions = $guiAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $guiFunctions)
    {
            if ($fn.Name -in @('Initialize-AppsSelectionState', 'Update-AppsSelectionSummary', 'Start-AppsModuleActionAsync', 'Start-AppsModuleBatchActionAsync'))
            {
                Invoke-Expression $fn.Extent.Text
            }
            elseif ($fn.Name -eq 'Initialize-AppsQueuedActionState')
            {
                Invoke-Expression $fn.Extent.Text
            }
    }

    $appsViewPath = Join-Path $PSScriptRoot '../../Module/GUI/ApplicationsView.ps1'
    $appsViewAst = [System.Management.Automation.Language.Parser]::ParseFile($appsViewPath, [ref]$null, [ref]$null)
    $appsViewFunctions = $appsViewAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $appsViewFunctions)
    {
        Invoke-Expression $fn.Extent.Text
    }

    <#
        .SYNOPSIS
        Internal function Get-BaselineLocalizedString.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Get-BaselineLocalizedString {
        param (
            [string]$Key,
            [string]$Fallback,
            [object[]]$FormatArgs = @()
        )

        if ($FormatArgs.Count -gt 0)
        {
            return ($Fallback -f $FormatArgs)
        }

        return $Fallback
    }

    <#
        .SYNOPSIS
        Internal function Get-UxLocalizedString.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Get-UxLocalizedString {
        param (
            [string]$Key,
            [string]$Fallback,
            [object[]]$FormatArgs = @()
        )

        if ($FormatArgs.Count -gt 0)
        {
            return ($Fallback -f $FormatArgs)
        }

        return $Fallback
    }

    <#
        .SYNOPSIS
        Internal function Get-GuiCurrentTheme.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Get-GuiCurrentTheme {
        return $script:TestTheme
    }

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function New-SafeBrushConverter {
        param (
            [string]$Context
        )

        $converter = [pscustomobject]@{}
        $null = $converter | Add-Member -MemberType ScriptMethod -Name ConvertFromString -Value {
            param([string]$Value)
            return $Value
        } -Force
        return $converter
    }

    <#
        .SYNOPSIS
        Internal function Get-SelectedAppsCatalogItems.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Get-SelectedAppsCatalogItems {
        return @($script:SelectedAppsForSummary)
    }

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function Resolve-WinGetExecutable {
        return 'winget.exe'
    }

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function Resolve-ChocolateyExecutable {
        return 'choco.exe'
    }

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function Resolve-ApplicationPackageId {
        param([string]$PackageId)
        return $PackageId
    }

    <#
        .SYNOPSIS
        Internal function Test-WinGetAvailable.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Test-WinGetAvailable {
        param (
            [switch]$Refresh
        )

        $null = $Refresh
        return [bool]$script:TestWinGetAvailable
    }

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function Test-ChocolateyAvailable {
        param (
            [switch]$Refresh
        )

        $null = $Refresh
        return [bool]$script:TestChocolateyAvailable
    }

    <#
        .SYNOPSIS
        Internal function Write-ConsoleStatus.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Write-ConsoleStatus { param([object]$Action) }
    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function LogInfo { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function LogWarning { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function LogError { param([object]$Message) }

    $script:GuiModuleBasePath = $TestDrive
    $script:GuiLocalizationDirectoryPath = $TestDrive
    $script:SelectedLanguage = 'en'
    $Global:LogFilePath = Join-Path $TestDrive 'baseline.log'
    $env:TEMP = $TestDrive
    $env:TMP = $TestDrive

    <#
        .SYNOPSIS
        Internal function .

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>
    function Start-GuiAppExecutionRun {
        param (
            [string]$Action,
            [string]$LoaderPath,
            [string]$LocalizationDirectory,
            [string]$UICulture,
            [string]$LogFilePath,
            [string]$LogMode,
            [string]$WinGetId,
            [string]$ChocoId,
            [string]$DisplayName,
            [object]$Application,
            [object[]]$SelectedApps = @(),
            [string]$PreferredSource = $null,
            [object]$PackageManagerAvailabilityState = $null
        )

        $script:CapturedExecutionArgs = $PSBoundParameters
    }

    $script:TestTheme = [pscustomobject]@{
        AccentBlue = '#2d8cff'
        TextPrimary = '#ffffff'
        TextSecondary = '#d0d0d0'
        TextMuted = '#909090'
    }

    $script:TestWinGetAvailable = $true
    $script:TestChocolateyAvailable = $true
    $script:AppsPackageSourcePreference = 'winget'
    $script:AppsSourceUiUpdating = $false
    $script:AppsPackageManagerAvailabilityState = $null
    $script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
    $script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
    $script:AppsSelectionUiUpdating = $false
}

Describe 'Resolve-ApplicationExecutionRoute' {
    It 'prefers EntityType over Type for routing' {
        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Mozilla Firefox'
            Type       = 'choco'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        }

        $route.EntityType | Should -Be 'winget'
        $route.Route | Should -Be 'winget'
        $route.PackageId | Should -Be 'Mozilla.Firefox'
        $route.IdentityKey | Should -Be 'winget:mozilla.firefox'
    }

    It 'falls back to Type when EntityType is missing' {
        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name    = 'Krita'
            Type    = 'choco'
            ChocoId = 'krita'
        }

        $route.Route | Should -Be 'choco'
        $route.PackageId | Should -Be 'krita'
    }

    It 'prefers the requested source when both package ids are available' {
        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Mozilla Firefox'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        } -PreferredSource 'choco'

        $route.Route | Should -Be 'choco'
        $route.SelectedSource | Should -Be 'choco'
        $route.PackageId | Should -Be 'firefox'
        $route.PreferredSource | Should -Be 'choco'
    }

    It 'uses supplied package-manager availability state without probing' {
        Mock Test-WinGetAvailable { throw 'WinGet availability should not be probed when state is supplied.' }
        Mock Test-ChocolateyAvailable { throw 'Chocolatey availability should not be probed when state is supplied.' }

        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $false
        }

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Mozilla Firefox'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        } -PackageManagerAvailabilityState $availabilityState

        $route.Route | Should -Be 'winget'
        Should -Invoke Test-WinGetAvailable -Times 0
        Should -Invoke Test-ChocolateyAvailable -Times 0
    }

    It 'marks placeholder entries as unsupported' {
        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Placeholder App'
            EntityType = 'placeholder'
        }

        $route.Route | Should -Be 'unsupported'
        $route.Reason | Should -BeLike '*No install method available*'
    }

    It 'rejects winget entries that do not define a WinGetId' {
        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Broken App'
            EntityType = 'winget'
        }

        $route.Route | Should -Be 'unsupported'
        $route.Reason | Should -BeLike '*does not define a WinGetId*'
    }
}

Describe 'WinGet availability' {
    BeforeEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
    }

    AfterEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
    }

    It 'marks winget-only routes unsupported when WinGet is unavailable' {
        $script:TestWinGetAvailable = $false

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Arc Browser'
            EntityType = 'winget'
            WinGetId   = 'TheBrowserCompany.Arc'
        }

        $route.Route | Should -Be 'unsupported'
        $route.Reason | Should -BeLike '*WinGet is not available*'
    }

    It 'falls back to Chocolatey when WinGet is unavailable and Chocolatey is available' {
        $script:TestWinGetAvailable = $false
        $script:TestChocolateyAvailable = $true

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Krita'
            EntityType = 'winget'
            WinGetId   = 'KDE.Krita'
            ChocoId    = 'krita'
        }

        $route.Route | Should -Be 'choco'
        $route.SelectedSource | Should -Be 'choco'
        $route.PackageId | Should -Be 'krita'
    }

    It 'falls back to WinGet when Chocolatey is unavailable and WinGet is available' {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $false

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Notepad++'
            EntityType = 'choco'
            WinGetId   = 'Notepad++.Notepad++'
            ChocoId    = 'notepadplusplus'
        }

        $route.Route | Should -Be 'winget'
        $route.SelectedSource | Should -Be 'winget'
        $route.PackageId | Should -Be 'Notepad++.Notepad++'
    }

    It 'marks winget entries unsupported when both WinGet and Chocolatey are unavailable' {
        $script:TestWinGetAvailable = $false
        $script:TestChocolateyAvailable = $false

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Krita'
            EntityType = 'winget'
            WinGetId   = 'KDE.Krita'
            ChocoId    = 'krita'
        }

        $route.Route | Should -Be 'unsupported'
        $route.Reason | Should -BeLike '*Neither WinGet nor Chocolatey is available*'
    }

    It 'marks choco entries unsupported when both Chocolatey and WinGet are unavailable' {
        $script:TestWinGetAvailable = $false
        $script:TestChocolateyAvailable = $false

        $route = Resolve-ApplicationExecutionRoute -Application @{
            Name       = 'Notepad++'
            EntityType = 'choco'
            WinGetId   = 'Notepad++.Notepad++'
            ChocoId    = 'notepadplusplus'
        } -PreferredSource 'choco'

        $route.Route | Should -Be 'unsupported'
        $route.Reason | Should -BeLike '*Neither Chocolatey nor WinGet is available*'
    }

    It 'returns an empty installed-app cache when WinGet is unavailable' {
        $script:TestWinGetAvailable = $false
        Mock Start-Process { throw 'Start-Process should not be called when WinGet is unavailable.' }

        $cache = Get-InstalledAppCache

        $cache.Count | Should -Be 0
        Should -Invoke Start-Process -Times 0
    }

    It 'returns an empty update cache when WinGet is unavailable' {
        $script:TestWinGetAvailable = $false
        Mock Start-Process { throw 'Start-Process should not be called when WinGet is unavailable.' }

        $cache = Get-AvailableAppUpdateCache

        $cache.Count | Should -Be 0
        Should -Invoke Start-Process -Times 0
    }

    It 'launches winget installs with non-interactive flags' {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

        Invoke-WingetInstall -WinGetId 'Google.Chrome' -DisplayName 'Google Chrome'

        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'winget.exe' -and
            -not $WindowStyle -and
            @($ArgumentList) -contains '--disable-interactivity'
        }
    }

    It 'launches winget cache scans in a hidden window with non-interactive flags' {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

        $cache = Get-InstalledAppCache

        $cache.Count | Should -Be 0
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'winget.exe' -and
            $WindowStyle -eq 'Hidden' -and
            @($ArgumentList) -contains '--disable-interactivity'
        }
    }

    It 'launches winget update scans in a hidden window with non-interactive flags' {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

        $cache = Get-AvailableAppUpdateCache

        $cache.Count | Should -Be 0
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'winget.exe' -and
            $WindowStyle -eq 'Hidden' -and
            @($ArgumentList) -contains '--disable-interactivity'
        }
    }
}

Describe 'Chocolatey availability' {
    BeforeEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
    }

    AfterEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
    }

    It 'returns an empty installed Chocolatey cache when Chocolatey is unavailable' {
        $script:TestChocolateyAvailable = $false

        $cache = Get-InstalledChocolateyAppCache

        $cache.Count | Should -Be 0
    }

    It 'returns an empty Chocolatey update cache when Chocolatey is unavailable' {
        $script:TestChocolateyAvailable = $false

        $cache = Get-AvailableChocolateyUpdateCache

        $cache.Count | Should -Be 0
    }

    It 'launches Chocolatey installs without forcing a hidden window' {
        Mock Resolve-ChocolateyExecutable { 'choco.exe' }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }

        Invoke-ChocoInstall -ChocoId 'googlechrome' -DisplayName 'Google Chrome'

        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'choco.exe' -and
            -not $WindowStyle
        }
    }
}

Describe 'Apps package manager availability' {
    BeforeEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
        $script:AppsPackageManagerBanner = [pscustomobject]@{
            Visibility = $null
        }
        $script:TxtAppsPackageManagerBanner = [pscustomobject]@{
            Text = $null
        }
    }

    AfterEach {
        $script:TestWinGetAvailable = $true
        $script:TestChocolateyAvailable = $true
        $script:AppsPackageManagerBanner = $null
        $script:TxtAppsPackageManagerBanner = $null
    }

    It 'returns a banner state that stays hidden when at least one package manager is available' {
        $state = Get-AppsPackageManagerAvailabilityState

        $state.BothUnavailable | Should -BeFalse
        $state.BannerText | Should -BeNullOrEmpty

        Update-AppsPackageManagerBanner -AvailabilityState $state

        $script:AppsPackageManagerBanner.Visibility.ToString() | Should -Be 'Collapsed'
        $script:TxtAppsPackageManagerBanner.Text | Should -BeNullOrEmpty
    }

    It 'shows a banner when both package managers are unavailable' {
        $script:TestWinGetAvailable = $false
        $script:TestChocolateyAvailable = $false

        $state = Get-AppsPackageManagerAvailabilityState
        $state.BothUnavailable | Should -BeTrue
        $state.BannerText | Should -BeLike '*WinGet and Chocolatey are unavailable*'

        Update-AppsPackageManagerBanner -AvailabilityState $state

        $script:AppsPackageManagerBanner.Visibility.ToString() | Should -Be 'Visible'
        $script:TxtAppsPackageManagerBanner.Text | Should -BeLike '*WinGet and Chocolatey are unavailable*'
    }

    It 'includes package manager availability in the apps render signature' {
        $script:TestWinGetAvailable = $false
        $script:TestChocolateyAvailable = $false

        $state = Get-AppsPackageManagerAvailabilityState
        $signature = Get-AppsViewRenderSignature -PackageManagerAvailabilityState $state

        $signature | Should -Match 'PackageManagers=WinGet=False\|Chocolatey=False'
    }
}

Describe 'Invoke-ApplicationAction' {
    BeforeEach {
        Mock Invoke-WingetInstall {}
        Mock Invoke-WingetUninstall {}
        Mock Invoke-WingetUpdate {}
        Mock Invoke-ChocoInstall {}
        Mock Invoke-ChocoUninstall {}
        Mock Invoke-ChocoUpdate {}
        Mock LogError {}
    }

    It 'routes winget installs to the winget adapter' {
        $application = [pscustomobject]@{
            Name       = 'Mozilla Firefox'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        }
        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $false
        }

        Invoke-ApplicationAction -Action Install -Application $application -PackageManagerAvailabilityState $availabilityState

        Should -Invoke Invoke-WingetInstall -Times 1 -ParameterFilter {
            $WinGetId -eq 'Mozilla.Firefox' -and
            $DisplayName -eq 'Mozilla Firefox' -and
            $PackageManagerAvailabilityState.WinGetAvailable -eq $true -and
            $PackageManagerAvailabilityState.ChocolateyAvailable -eq $false
        }
        Should -Invoke Invoke-ChocoInstall -Times 0
    }

    It 'routes choco updates to the chocolatey adapter' {
        $application = [pscustomobject]@{
            Name       = '7-Zip'
            EntityType = 'choco'
            ChocoId    = '7zip'
        }
        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $false
            ChocolateyAvailable = $true
        }

        Invoke-ApplicationAction -Action Update -Application $application -PackageManagerAvailabilityState $availabilityState

        Should -Invoke Invoke-ChocoUpdate -Times 1 -ParameterFilter {
            $ChocoId -eq '7zip' -and
            $DisplayName -eq '7-Zip' -and
            $PackageManagerAvailabilityState.WinGetAvailable -eq $false -and
            $PackageManagerAvailabilityState.ChocolateyAvailable -eq $true
        }
        Should -Invoke Invoke-WingetUpdate -Times 0
    }

    It 'throws for unsupported routes' {
        {
            Invoke-ApplicationAction -Action Install -Application @{
                Name       = 'Placeholder'
                EntityType = 'placeholder'
            }
        } | Should -Throw '*No install method available*'
    }
}

Describe 'AppInstall' {
    BeforeEach {
        Mock Invoke-ApplicationAction {}
    }

    It 'delegates install actions to the unified router' {
        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $true
        }

        AppInstall -Install -WinGetId 'Mozilla.Firefox' -ChocoId 'firefox' -DisplayName 'Mozilla Firefox' -PreferredSource 'choco' -PackageManagerAvailabilityState $availabilityState

        Should -Invoke Invoke-ApplicationAction -Times 1 -ParameterFilter {
            $Action -eq 'Install' -and $WinGetId -eq 'Mozilla.Firefox' -and $ChocoId -eq 'firefox' -and $DisplayName -eq 'Mozilla Firefox' -and $PreferredSource -eq 'choco' -and $PackageManagerAvailabilityState -eq $availabilityState
        }
    }
}

Describe 'AppUpdate' {
    BeforeEach {
        Mock Resolve-WinGetExecutable { 'winget.exe' }
        Mock Get-Command { [pscustomobject]@{ Name = 'choco' } }
        <#
            .SYNOPSIS
            Internal function Resolve-ApplicationPackageId.

            .DESCRIPTION
            Internal implementation helper used by Baseline.
        #>

        function Resolve-ApplicationPackageId
        {
            param([string]$PackageId)
            return $PackageId
        }
        Mock Invoke-ApplicationAction {}
        Mock Invoke-WingetUpdateAll {}
        Mock Invoke-ChocoUpdateAll {}
    }

    It 'delegates update-all actions to the bulk adapters' {
        AppUpdate -All

        Should -Invoke Invoke-WingetUpdateAll -Times 1
        Should -Invoke Invoke-ChocoUpdateAll -Times 1
    }

    It 'forwards preferred source for single app updates' {
        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $true
        }

        AppUpdate -WinGetId 'Mozilla.Firefox' -ChocoId 'firefox' -DisplayName 'Mozilla Firefox' -PreferredSource 'choco' -PackageManagerAvailabilityState $availabilityState

        Should -Invoke Invoke-ApplicationAction -Times 1 -ParameterFilter {
            $Action -eq 'Update' -and $WinGetId -eq 'Mozilla.Firefox' -and $ChocoId -eq 'firefox' -and $DisplayName -eq 'Mozilla Firefox' -and $PreferredSource -eq 'choco' -and $PackageManagerAvailabilityState -eq $availabilityState
        }
    }

    It 'forwards availability state to the bulk update adapters' {
        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $true
        }

        Mock Test-WinGetAvailable { throw 'WinGet availability should not be probed when cached state is supplied.' }
        Mock Test-ChocolateyAvailable { throw 'Chocolatey availability should not be probed when cached state is supplied.' }

        AppUpdate -All -PackageManagerAvailabilityState $availabilityState

        Should -Invoke Invoke-WingetUpdateAll -Times 1 -ParameterFilter {
            $PackageManagerAvailabilityState.WinGetAvailable -eq $true -and
            $PackageManagerAvailabilityState.ChocolateyAvailable -eq $true
        }
        Should -Invoke Invoke-ChocoUpdateAll -Times 1 -ParameterFilter {
            $PackageManagerAvailabilityState.WinGetAvailable -eq $true -and
            $PackageManagerAvailabilityState.ChocolateyAvailable -eq $true
        }
        Should -Invoke Test-WinGetAvailable -Times 0
        Should -Invoke Test-ChocolateyAvailable -Times 0
    }
}

Describe 'Invoke-AppBatchAction' {
    BeforeEach {
        Mock Invoke-ApplicationAction {}
    }

    It 'routes each unique application once and records unsupported entries' {
        $wingetApp = [pscustomobject]@{
            Name       = 'Mozilla Firefox'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        }
        $duplicateWingetApp = [pscustomobject]@{
            Name       = 'Mozilla Firefox Duplicate'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        }
        $chocoApp = [pscustomobject]@{
            Name       = '7-Zip'
            EntityType = 'choco'
            ChocoId    = '7zip'
        }
        $placeholderApp = [pscustomobject]@{
            Name       = 'Placeholder App'
            EntityType = 'placeholder'
        }

        $result = Invoke-AppBatchAction -Action Install -Applications @(
            $wingetApp,
            $duplicateWingetApp,
            $chocoApp,
            $placeholderApp
        )

        $result.Outcome | Should -Be 'Partial'
        $result.SuccessCount | Should -Be 2
        $result.FailureCount | Should -Be 1
        $result.TotalCount | Should -Be 3
        $result.FailedApps[0].Error | Should -BeLike '*No install method available*'

        Should -Invoke Invoke-ApplicationAction -Times 2
    }

    It 'honors the preferred source for batch execution' {
        $application = [pscustomobject]@{
            Name       = 'Mozilla Firefox'
            EntityType = 'winget'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
        }

        $availabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $true
        }

        $result = Invoke-AppBatchAction -Action Install -Applications @($application) -PreferredSource 'choco' -PackageManagerAvailabilityState $availabilityState

        $result.Outcome | Should -Be 'Success'
        $result.SuccessfulApps[0].SelectedSource | Should -Be 'choco'
        Should -Invoke Invoke-ApplicationAction -Times 1 -ParameterFilter {
            $Action -eq 'Install' -and $PreferredSource -eq 'choco' -and $PackageManagerAvailabilityState -eq $availabilityState
        }
    }
}

Describe 'Start-AppsModuleActionAsync' {
    BeforeEach {
        $script:CapturedExecutionArgs = $null
    }

    AfterEach {
        $script:AppsPackageManagerAvailabilityState = $null
    }

    It 'forwards the application object and derived identifiers to the execution runner' {
        $application = [pscustomobject]@{
            Name       = 'Mozilla Firefox'
            WinGetId   = 'Mozilla.Firefox'
            ChocoId    = 'firefox'
            EntityType = 'winget'
        }
        $script:AppsPackageManagerAvailabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $true
        }

        Start-AppsModuleActionAsync -Action Install -Application $application -PreferredSource 'choco'

        $script:CapturedExecutionArgs.Action | Should -Be 'Install'
        $script:CapturedExecutionArgs.WinGetId | Should -Be 'Mozilla.Firefox'
        $script:CapturedExecutionArgs.ChocoId | Should -Be 'firefox'
        $script:CapturedExecutionArgs.DisplayName | Should -Be 'Mozilla Firefox'
        $script:CapturedExecutionArgs.Application.Name | Should -Be 'Mozilla Firefox'
        $script:CapturedExecutionArgs.PreferredSource | Should -Be 'choco'
        $script:CapturedExecutionArgs.PackageManagerAvailabilityState.WinGetAvailable | Should -BeTrue
        $script:CapturedExecutionArgs.PackageManagerAvailabilityState.ChocolateyAvailable | Should -BeTrue
    }
}

Describe 'Start-AppsModuleBatchActionAsync' {
    BeforeEach {
        $script:CapturedExecutionArgs = $null
    }

    AfterEach {
        $script:AppsPackageManagerAvailabilityState = $null
    }

    It 'forwards the selected apps and preferred source to the execution runner' {
        $selectedApps = @(
            [pscustomobject]@{
                Name       = 'Mozilla Firefox'
                WinGetId   = 'Mozilla.Firefox'
                ChocoId    = 'firefox'
                EntityType = 'winget'
            }
        )
        $script:AppsPackageManagerAvailabilityState = [pscustomobject]@{
            WinGetAvailable = $true
            ChocolateyAvailable = $false
        }

        Start-AppsModuleBatchActionAsync -Action Install -SelectedApps $selectedApps -PreferredSource 'choco'

        $script:CapturedExecutionArgs.Action | Should -Be 'Install'
        $script:CapturedExecutionArgs.SelectedApps.Count | Should -Be 1
        $script:CapturedExecutionArgs.SelectedApps[0].Name | Should -Be 'Mozilla Firefox'
        $script:CapturedExecutionArgs.PreferredSource | Should -Be 'choco'
        $script:CapturedExecutionArgs.PackageManagerAvailabilityState.WinGetAvailable | Should -BeTrue
        $script:CapturedExecutionArgs.PackageManagerAvailabilityState.ChocolateyAvailable | Should -BeFalse
    }
}

Describe 'Update-AppsSelectionSummary' {
    BeforeEach {
        $script:SelectedAppsForSummary = @(
            [pscustomobject]@{
                Name = 'Mozilla Firefox'
            }
        )

        $script:AppsViewLoaded = $false
        $script:AppsViewDirty = $false
        $script:AppsOperationInProgress = $false
        $script:AppsCacheRefreshInProgress = $false
        $script:SelectedAppIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $script:AppsSelectionControls = [System.Collections.Generic.List[object]]::new()
        $script:AppsBulkActionButtons = [System.Collections.Generic.List[object]]::new()
        $script:TxtAppSelectionStatus = [pscustomobject]@{
            Text = $null
            Foreground = $null
        }
        $script:BtnInstallSelectedApps = [pscustomobject]@{
            IsEnabled = $false
            ToolTip = $null
        }
        $script:BtnUninstallSelectedApps = [pscustomobject]@{
            IsEnabled = $false
            ToolTip = $null
        }
        $script:BtnUpdateSelectedApps = [pscustomobject]@{
            IsEnabled = $false
            ToolTip = $null
        }
        $script:BtnClearAppSelection = [pscustomobject]@{
            IsEnabled = $false
            ToolTip = $null
        }
        $script:BtnScanInstalledApps = [pscustomobject]@{
            IsEnabled = $false
            ToolTip = $null
        }
        $script:AppsSelectionUiUpdating = $false
    }

    It 'allows installation without a scanned installed-app cache' {
        Update-AppsSelectionSummary

        $script:BtnInstallSelectedApps.IsEnabled | Should -BeTrue
        $script:BtnUninstallSelectedApps.IsEnabled | Should -BeFalse
        $script:BtnUpdateSelectedApps.IsEnabled | Should -BeFalse
        $script:BtnClearAppSelection.IsEnabled | Should -BeTrue
        $script:BtnScanInstalledApps.IsEnabled | Should -BeTrue
        $script:BtnInstallSelectedApps.ToolTip | Should -Be 'Install every checked application.'
        $script:BtnUninstallSelectedApps.ToolTip | Should -Match 'Scan installed apps before uninstalling or updating\.'
        $script:BtnUpdateSelectedApps.ToolTip | Should -Match 'Scan installed apps before uninstalling or updating\.'
        $script:BtnScanInstalledApps.ToolTip | Should -Be 'Scan installed apps to update install status.'
    }

    It 'enables update and uninstall actions once the installed-app cache is ready' {
        $script:AppsViewLoaded = $true
        Update-AppsSelectionSummary

        $script:BtnInstallSelectedApps.IsEnabled | Should -BeTrue
        $script:BtnUninstallSelectedApps.IsEnabled | Should -BeTrue
        $script:BtnUpdateSelectedApps.IsEnabled | Should -BeTrue
        $script:BtnClearAppSelection.IsEnabled | Should -BeTrue
        $script:BtnScanInstalledApps.IsEnabled | Should -BeTrue
    }
}
