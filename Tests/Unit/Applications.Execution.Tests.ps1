Set-StrictMode -Version Latest

BeforeAll {
    $applicationsPath = Join-Path $PSScriptRoot '../../Module/Regions/Applications.psm1'
    $applicationsAst = [System.Management.Automation.Language.Parser]::ParseFile($applicationsPath, [ref]$null, [ref]$null)
    $applicationsFunctions = $applicationsAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $applicationsFunctions)
    {
        Invoke-Expression $fn.Extent.Text
    }

    # Apps functions were extracted from GUI.psm1 into Module/GUI/AppsModule.ps1
    # during Phase 2 decomposition. Parse both so tests find the definitions
    # regardless of which file they currently live in.
    $guiSourceFiles = @(
        (Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'),
        (Join-Path $PSScriptRoot '../../Module/GUI/AppsModule.ps1')
    )
    $targetAppsFunctions = @('Initialize-AppsSelectionState', 'Update-AppsSelectionSummary', 'Start-AppsModuleActionAsync', 'Start-AppsModuleBatchActionAsync', 'Initialize-AppsQueuedActionState')
    foreach ($srcFile in $guiSourceFiles)
    {
        if (-not (Test-Path -LiteralPath $srcFile)) { continue }
        $srcAst = [System.Management.Automation.Language.Parser]::ParseFile($srcFile, [ref]$null, [ref]$null)
        $srcFunctions = $srcAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $srcFunctions)
        {
            if ($fn.Name -in $targetAppsFunctions)
            {
                Invoke-Expression $fn.Extent.Text
            }
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
    #>

    function Get-GuiCurrentTheme {
        return $script:TestTheme
    }

    <#
        .SYNOPSIS
        Internal function .
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
    #>

    function Get-SelectedAppsCatalogItems {
        return @($script:SelectedAppsForSummary)
    }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Resolve-WinGetExecutable {
        return 'winget.exe'
    }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Resolve-ChocolateyExecutable {
        return 'choco.exe'
    }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Resolve-ApplicationPackageId {
        param([string]$PackageId)
        return $PackageId
    }

    <#
        .SYNOPSIS
        Internal function Test-WinGetAvailable.
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
    #>

    function Write-ConsoleStatus { param([object]$Action) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function LogInfo { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function LogWarning { param([object]$Message) }
    <#
        .SYNOPSIS
        Internal function .
    #>
    function LogError { param([object]$Message) }

    <#
        .SYNOPSIS
        Internal function .
    #>
    function Reset-ChocolateyAvailabilityState { }

    $script:GuiModuleBasePath = $TestDrive
    $script:GuiLocalizationDirectoryPath = $TestDrive
    $script:SelectedLanguage = 'en'
    $Global:LogFilePath = Join-Path $TestDrive 'baseline.log'
    $env:TEMP = $TestDrive
    $env:TMP = $TestDrive

    <#
        .SYNOPSIS
        Internal function .
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

Describe 'Chocolatey bootstrap' {
    BeforeEach {
        Mock Get-ExecutionPolicy { 'RemoteSigned' }
        Mock Set-ExecutionPolicy {}
        Mock Reset-ChocolateyAvailabilityState {}
        Mock Confirm-ChocolateyBootstrapExecution {}
        Remove-Variable -Name ChocolateyBootstrapExecuted -Scope Global -ErrorAction SilentlyContinue
        $Global:ChocolateyBootstrapExecuted = $false
    }

    AfterEach {
        Remove-Variable -Name ChocolateyBootstrapExecuted -Scope Global -ErrorAction SilentlyContinue
    }

    It 'downloads the Chocolatey bootstrap to disk and executes it' {
        $script:BootstrapScriptPath = Join-Path $TestDrive 'choco-install.ps1'
        Set-Content -LiteralPath $script:BootstrapScriptPath -Value '$Global:ChocolateyBootstrapExecuted = $true'
        Mock Save-ChocolateyBootstrapScript { $script:BootstrapScriptPath }

        Invoke-ChocolateyBootstrapInstall

        $Global:ChocolateyBootstrapExecuted | Should -BeTrue
        Should -Invoke Confirm-ChocolateyBootstrapExecution -Times 1
        Should -Invoke Save-ChocolateyBootstrapScript -Times 1
        Should -Invoke Reset-ChocolateyAvailabilityState -Times 1
        Test-Path -LiteralPath $script:BootstrapScriptPath | Should -BeFalse
    }

    It 'restores the previous execution policy when bootstrap download fails' {
        Mock Save-ChocolateyBootstrapScript { throw 'bootstrap download failed' }

        { Invoke-ChocolateyBootstrapInstall } | Should -Throw '*bootstrap download failed*'

        Should -Invoke Set-ExecutionPolicy -Times 1 -ParameterFilter {
            $ExecutionPolicy -eq 'Bypass' -and $Scope -eq 'Process' -and $Force
        }
        Should -Invoke Set-ExecutionPolicy -Times 1 -ParameterFilter {
            $ExecutionPolicy -eq 'RemoteSigned' -and $Scope -eq 'Process' -and $Force
        }
    }
}

Describe 'Chocolatey bootstrap approval' {
    It 'runs without throwing (approval gate removed)' {
        { Confirm-ChocolateyBootstrapExecution } | Should -Not -Throw
    }
}

Describe 'Test-ChocolateyBootstrapInteractiveHost' {
    BeforeAll {
        # The 'Chocolatey bootstrap approval' Describe above removes this function
        # via AfterEach; re-parse it from source so this Describe has its own copy.
        $applicationsPath = Join-Path $PSScriptRoot '../../Module/Regions/Applications.psm1'
        $applicationsAst = [System.Management.Automation.Language.Parser]::ParseFile($applicationsPath, [ref]$null, [ref]$null)
        $targetFn = $applicationsAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-ChocolateyBootstrapInteractiveHost' }, $true) | Select-Object -First 1
        if ($targetFn) { Invoke-Expression $targetFn.Extent.Text }
    }

    BeforeEach {
        $script:rawUi = [pscustomobject]@{}
        $script:baselineHost = [pscustomobject]@{
            Name = 'BaselineHost'
            UI = [pscustomobject]@{ RawUI = $script:rawUi }
        }
        $script:remoteHost = [pscustomobject]@{
            Name = 'ServerRemoteHost'
            UI = [pscustomobject]@{ RawUI = $script:rawUi }
        }
        $script:defaultHost = [pscustomobject]@{
            Name = 'Default Host'
            UI = [pscustomobject]@{ RawUI = $script:rawUi }
        }
        $script:consoleHost = [pscustomobject]@{
            Name = 'ConsoleHost'
            UI = [pscustomobject]@{ RawUI = $script:rawUi }
        }
    }

    It 'rejects the BaselineHost launcher even though RawUI is present' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $script:baselineHost -UserInteractive $true | Should -BeFalse
    }

    It 'rejects PSRemoting ServerRemoteHost' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $script:remoteHost -UserInteractive $true | Should -BeFalse
    }

    It 'rejects Default Host automation contexts' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $script:defaultHost -UserInteractive $true | Should -BeFalse
    }

    It 'rejects when UserInteractive is false' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $script:consoleHost -UserInteractive $false | Should -BeFalse
    }

    It 'accepts a ConsoleHost when UserInteractive is true' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $script:consoleHost -UserInteractive $true | Should -BeTrue
    }

    It 'rejects a null host' {
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $null -UserInteractive $true | Should -BeFalse
    }

    It 'rejects a host with no UI' {
        $hostNoUi = [pscustomobject]@{ Name = 'ConsoleHost'; UI = $null }
        Test-ChocolateyBootstrapInteractiveHost -HostInstance $hostNoUi -UserInteractive $true | Should -BeFalse
    }
}

Describe 'Command execution routes' {
    BeforeEach {
        $script:CapturedCommandInvocation = $null
    }

    It 'parses literal command strings into a command name and argument list' {
        $invocation = ConvertTo-ApplicationCommandInvocation -Command "winget install -s msstore 'Microsoft Solitaire Collection'"

        $invocation.CommandName | Should -Be 'winget'
        @($invocation.CommandArguments).Count | Should -Be 4
        $invocation.CommandArguments[0] | Should -Be 'install'
        $invocation.CommandArguments[1] | Should -Be '-s'
        $invocation.CommandArguments[2] | Should -Be 'msstore'
        $invocation.CommandArguments[3] | Should -Be 'Microsoft Solitaire Collection'
        $invocation.HasSingleCommandInvocation | Should -BeTrue
    }

    It 'parses safe pipelines and semicolon-separated statements' {
        $invocation = ConvertTo-ApplicationCommandInvocation -Command 'Get-AppxPackage -Name *3DViewer* | Remove-AppxPackage; Get-AppxPackage -AllUsers -Name *3DViewer* | Remove-AppxProvisionedAppxPackage'

        $invocation.HasSingleCommandInvocation | Should -BeFalse
        @($invocation.CommandNames) | Should -Be @(
            'Get-AppxPackage',
            'Remove-AppxPackage',
            'Get-AppxPackage',
            'Remove-AppxProvisionedAppxPackage'
        )
    }

    It 'rejects unsafe subexpressions and scriptblocks' {
        {
            ConvertTo-ApplicationCommandInvocation -Command 'Get-AppxPackage $(Get-Date)'
        } | Should -Throw '*contains unsupported syntax*'
    }

    It 'rejects dot-source invocation against a literal script path' {
        {
            ConvertTo-ApplicationCommandInvocation -Command ". '.\foo.ps1'"
        } | Should -Throw '*contains unsupported syntax*'
    }

    It 'rejects call-operator invocation against a literal script path' {
        {
            ConvertTo-ApplicationCommandInvocation -Command "& '.\foo.ps1'"
        } | Should -Throw '*contains unsupported syntax*'
    }

    It 'rejects dot-source invocation against a bareword path' {
        {
            ConvertTo-ApplicationCommandInvocation -Command '. C:\Temp\foo.ps1'
        } | Should -Throw '*contains unsupported syntax*'
    }

    It 'rejects call-operator invocation of a command name' {
        {
            ConvertTo-ApplicationCommandInvocation -Command '& winget install git'
        } | Should -Throw '*contains unsupported syntax*'
    }

    It 'executes parsed commands without Invoke-Expression' {
        function Invoke-TestApplicationCommand {
            param (
                [string]$Mode,
                [string]$Target
            )

            $script:CapturedCommandInvocation = @($Mode, $Target)
        }

        try {
            Invoke-CommandInstall -Command 'Invoke-TestApplicationCommand install baseline' -DisplayName 'Baseline Test App'

            @($script:CapturedCommandInvocation).Count | Should -Be 2
            $script:CapturedCommandInvocation[0] | Should -Be 'install'
            $script:CapturedCommandInvocation[1] | Should -Be 'baseline'
        }
        finally {
            Remove-Item -Path Function:\Invoke-TestApplicationCommand -ErrorAction SilentlyContinue
        }
    }

    It 'executes safe pipelines without Invoke-Expression' {
        function Get-TestApplicationItem {
            'baseline'
        }

        function Invoke-TestPipelineCommand {
            process {
                $script:CapturedCommandInvocation = $_
            }
        }

        try {
            Invoke-CommandInstall -Command 'Get-TestApplicationItem | Invoke-TestPipelineCommand' -DisplayName 'Baseline Pipeline App'

            $script:CapturedCommandInvocation | Should -Be 'baseline'
        }
        finally {
            Remove-Item -Path Function:\Get-TestApplicationItem -ErrorAction SilentlyContinue
            Remove-Item -Path Function:\Invoke-TestPipelineCommand -ErrorAction SilentlyContinue
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
