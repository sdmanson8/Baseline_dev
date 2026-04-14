Set-StrictMode -Version Latest

$script:InstallerTemplates = @(
    @{
        ScriptName = 'Baseline-Setup.iss'
        ScriptPath = Join-Path $PSScriptRoot '../../dist/Baseline-Setup.iss'
    }
    @{
        ScriptName = 'Baseline-Setup-dev.iss'
        ScriptPath = Join-Path $PSScriptRoot '../../dist/Baseline-Setup-dev.iss'
    }
)

Describe 'Portable installer registration' {
    It '<ScriptName> disables uninstall registration for portable mode' -ForEach $script:InstallerTemplates {
        $content = Get-Content -LiteralPath $ScriptPath -Raw -Encoding UTF8

        $content | Should -Match '(?m)^Uninstallable=IsInstallMode$' -Because "portable mode in $ScriptName must not create an uninstallable entry"
        $content | Should -Match '(?m)^CreateUninstallRegKey=IsInstallMode$' -Because "portable mode in $ScriptName must not register in Apps & Features"
    }
}
