Set-StrictMode -Version Latest

BeforeAll {
    $script:LauncherProgramPath = Join-Path $PSScriptRoot '../../Launcher/Program.cs'
    $script:LauncherProjectPath = Join-Path $PSScriptRoot '../../Launcher/RunLauncher.csproj'
    $script:BootstrapPath = Join-Path $PSScriptRoot '../../Bootstrap/Baseline.ps1'
    $script:InitialActionsPath = Join-Path $PSScriptRoot '../../Module/Regions/InitialActions.psm1'
    $script:UwpAppsPath = Join-Path $PSScriptRoot '../../Module/Regions/UWPApps.psm1'
    $script:SystemWindowsFeaturesPath = Join-Path $PSScriptRoot '../../Module/Regions/System/System.WindowsFeatures.psm1'
    $script:TelemetryServicesPath = Join-Path $PSScriptRoot '../../Module/Regions/PrivacyTelemetry/PrivacyTelemetry.TelemetryServices.psm1'
    $script:BuildLauncherPath = Join-Path $PSScriptRoot '../../Tools/Build-Launcher.ps1'

    $script:LauncherProgramContent = Get-Content -LiteralPath $script:LauncherProgramPath -Raw -Encoding UTF8
    $script:LauncherProjectContent = Get-Content -LiteralPath $script:LauncherProjectPath -Raw -Encoding UTF8
    $script:BootstrapContent = Get-Content -LiteralPath $script:BootstrapPath -Raw -Encoding UTF8
    $script:InitialActionsContent = Get-Content -LiteralPath $script:InitialActionsPath -Raw -Encoding UTF8
    $script:UwpAppsContent = Get-Content -LiteralPath $script:UwpAppsPath -Raw -Encoding UTF8
    $script:SystemWindowsFeaturesContent = Get-Content -LiteralPath $script:SystemWindowsFeaturesPath -Raw -Encoding UTF8
    $script:TelemetryServicesContent = Get-Content -LiteralPath $script:TelemetryServicesPath -Raw -Encoding UTF8
    $script:BuildLauncherContent = Get-Content -LiteralPath $script:BuildLauncherPath -Raw -Encoding UTF8
}

Describe 'Launcher identity host' {
    It 'hosts Windows PowerShell in-process instead of shelling out to powershell.exe' {
        $script:LauncherProgramContent | Should -Match 'RunspaceFactory\.CreateRunspace\(host\)'
        $script:LauncherProgramContent | Should -Match 'PowerShell\.Create\(\)'
        $script:LauncherProgramContent | Should -Match 'BaselinePowerShellHost'
        $script:LauncherProgramContent | Should -Not -Match 'ProcessStartInfo'
        $script:LauncherProgramContent | Should -Not -Match 'powershell\.exe'
    }

    It 'keys the hydrated runtime cache by build identity as well as version' {
        $script:LauncherProgramContent | Should -Match 'ManifestModule\.ModuleVersionId\.ToString\("N"\)'
        $script:LauncherProgramContent | Should -Not -Match 'Substring\(0,\s*12\)'
        $script:LauncherProgramContent | Should -Match 'RuntimeCacheSchema\s*=\s*"4"'
        $script:LauncherProgramContent | Should -Match 'Path\.Combine\(cacheRoot, version, RuntimeCacheSchema, buildId\)'
    }

    It 'restores UTF-8 BOMs only for non-ASCII PowerShell payload files during hydration' {
        $script:LauncherProgramContent | Should -Match 'Utf8Bom'
        $script:LauncherProgramContent | Should -Match 'ShouldPrependUtf8Bom\(target, resourceStream\)'
        $script:LauncherProgramContent | Should -Match 'ResourceStartsWithUtf8Bom'
        $script:LauncherProgramContent | Should -Match 'RequiresPowerShellUtf8Bom'
        $script:LauncherProgramContent | Should -Match 'extension\.Equals\("\.ps1"'
        $script:LauncherProgramContent | Should -Match 'extension\.Equals\("\.psm1"'
        $script:LauncherProgramContent | Should -Match 'extension\.Equals\("\.psd1"'
        $script:LauncherProgramContent | Should -Match 'hasNonAsciiByte'
    }

    It 'keeps the embedded host on the STA launcher thread' {
        $script:LauncherProgramContent | Should -Match 'runspace\.ApartmentState = ApartmentState\.STA;'
        $script:LauncherProgramContent | Should -Match 'runspace\.ThreadOptions = PSThreadOptions\.ReuseThread;'
        $script:LauncherProgramContent | Should -Match 'Environment\.SetEnvironmentVariable\(EmbeddedHostVar, "1", EnvironmentVariableTarget\.Process\);'
    }

    It 'targets net48 and references the Windows PowerShell automation assembly' {
        $script:LauncherProjectContent | Should -Match '<TargetFramework>net48</TargetFramework>'
        $script:LauncherProjectContent | Should -Match '<Reference Include="System\.Management\.Automation">'
        $script:LauncherProjectContent | Should -Match 'System\.Management\.Automation\.dll'
        $script:LauncherProjectContent | Should -Match '<PlatformTarget>AnyCPU</PlatformTarget>'
        $script:LauncherProjectContent | Should -Match '<Prefer32Bit>false</Prefer32Bit>'
        $script:LauncherProjectContent | Should -Not -Match 'Microsoft\.PowerShell\.SDK'
    }

    It 'builds the launcher with dotnet build for net48' {
        $script:BuildLauncherContent | Should -Match '''build'''
        $script:BuildLauncherContent | Should -Match '''-f'', ''net48'''
        $script:BuildLauncherContent | Should -Not -Match 'PlatformTarget=x64'
        $script:BuildLauncherContent | Should -Not -Match '0x8664'
        $script:BuildLauncherContent | Should -Match '0x014C'
        $script:BuildLauncherContent | Should -Not -Match 'PublishSingleFile'
        $script:BuildLauncherContent | Should -Not -Match 'SelfContained'
    }
}

Describe 'Embedded host bootstrap flow' {
    It 'avoids console-only title and clear-host calls on the embedded host path' {
        $script:BootstrapContent | Should -Match 'if \(-not \$Script:IsEmbeddedHost\)\s*\{\s*Clear-Host'
        $script:BootstrapContent | Should -Match '\$Script:BaselineWindowTitle = "Baseline \| Utility for \$osName"'
        $script:BootstrapContent | Should -Match 'try\s*\{\s*\$Host\.UI\.RawUI\.WindowTitle = \$Script:BaselineWindowTitle'
        $script:BootstrapContent | Should -Match '\$Script:BootstrapSplash\.Window\.Title = \$Script:BaselineWindowTitle'
    }

    It 'skips later Clear-Host calls when the embedded launcher owns the process' {
        ([regex]::Matches($script:InitialActionsContent, '\$env:BASELINE_EMBEDDED_HOST -ne ''1'' -and \(Test-InteractiveHost\)')).Count | Should -Be 2
    }

    It 'treats startup AppX package probes as non-fatal checks' {
        $script:InitialActionsContent | Should -Match 'Get-AppxPackage -Name MicrosoftWindows\.Client\.CBS -WarningAction SilentlyContinue -ErrorAction Stop'
        $script:InitialActionsContent | Should -Match 'Get-AppxPackage -Name Microsoft\.WindowsStore -WarningAction SilentlyContinue -ErrorAction Stop'
        $script:InitialActionsContent | Should -Match 'Windows Feature Experience Pack check could not be completed'
        $script:InitialActionsContent | Should -Match 'Microsoft Store presence check could not be completed'
    }

    It 'keeps the headless apply loop on valid splatting syntax' {
        $script:BootstrapContent | Should -Not -Match '@invocation\.NamedArguments'
        $script:BootstrapContent | Should -Match '\$namedArguments\s*=\s*\$invocation\.NamedArguments'
        $script:BootstrapContent | Should -Match '& \$resolvedCmd @namedArguments'
    }
}

Describe 'Foreground helper process selection' {
    It 'includes the Baseline process name anywhere the GUI window is searched by title' {
        $script:UwpAppsContent | Should -Match 'Get-Process -Name Baseline, powershell, WindowsTerminal'
        ([regex]::Matches($script:SystemWindowsFeaturesContent, 'Get-Process -Name Baseline, powershell, WindowsTerminal')).Count | Should -Be 2
        $script:TelemetryServicesContent | Should -Match 'Get-Process -Name Baseline, powershell, WindowsTerminal'
    }
}
