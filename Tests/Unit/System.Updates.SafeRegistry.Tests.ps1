Set-StrictMode -Version Latest

BeforeAll {
    $script:filePath = Join-Path $PSScriptRoot '../../Module/Regions/System/System.Updates.psm1'
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($script:filePath, [ref]$null, [ref]$null)
    $script:recommendedTroubleshooting = $script:ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'RecommendedTroubleshooting'
        }, $true)
}

Describe 'RecommendedTroubleshooting safe-registry cleanup' {
    It 'clears HKCU telemetry and error-reporting values through Remove-RegistryValueSafe' {
        $safeRemovals = @($script:recommendedTroubleshooting.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Remove-RegistryValueSafe'
                }, $true))

        foreach ($target in @(
                @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack'; Name = 'ShowedToastAtLevel' },
                @{ Path = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled' }
            )) {
            @($safeRemovals | Where-Object {
                    $_.Extent.Text -like "*$($target.Path)*" -and
                    $_.Extent.Text -like "*$($target.Name)*"
                }).Count | Should -Be 1
        }
    }

    It 'does not directly clear the migrated HKCU values' {
        $directRemovals = @($script:recommendedTroubleshooting.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Remove-ItemProperty' -and
                    ($node.Extent.Text -like '*HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack*' -or
                        $node.Extent.Text -like '*HKCU:\Software\Microsoft\Windows\Windows Error Reporting*')
                }, $true))

        $directRemovals.Count | Should -Be 0
    }
}
