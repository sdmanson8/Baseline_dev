Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Tools/New-InstallerPackage.ps1'
    $script:RepoRoot = Split-Path -Path (Split-Path -Path $filePath -Parent) -Parent
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Resolve-IsccPath' {
    BeforeEach {
        $script:OriginalProgramFiles = [System.Environment]::GetEnvironmentVariable('ProgramFiles', 'Process')
        $script:OriginalProgramFilesX86 = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)', 'Process')
    }

    AfterEach {
        [System.Environment]::SetEnvironmentVariable('ProgramFiles', $script:OriginalProgramFiles, 'Process')
        [System.Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $script:OriginalProgramFilesX86, 'Process')
    }

    It 'returns the requested path when it exists' {
        $requestedPath = Join-Path $TestDrive 'ISCC.exe'
        Set-Content -LiteralPath $requestedPath -Value '' -Encoding ASCII

        Resolve-IsccPath -RequestedPath $requestedPath | Should -Be $requestedPath
    }

    It 'returns null without throwing when no installation roots are defined' {
        [System.Environment]::SetEnvironmentVariable('ProgramFiles', $null, 'Process')
        [System.Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $null, 'Process')

        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'iscc.exe' }

        { Resolve-IsccPath } | Should -Not -Throw
        Resolve-IsccPath | Should -Be $null
    }
}

Describe 'Get-InstallerBuildLayout' {
    It 'uses short staging directory names for the installer payload' {
        $layout = Get-InstallerBuildLayout `
            -BaseTempPath 'C:\Users\runneradmin\AppData\Local\Temp' `
            -RootName 'BaselineInstaller_1234567890abcdef1234567890abcdef'

        $layout.TempExtract | Should -Be 'C:\Users\runneradmin\AppData\Local\Temp\BaselineInstaller_1234567890abcdef1234567890abcdef\x'
        $layout.SourceRoot | Should -Be 'C:\Users\runneradmin\AppData\Local\Temp\BaselineInstaller_1234567890abcdef1234567890abcdef\x\B'
        $layout.StageDir | Should -Be 'C:\Users\runneradmin\AppData\Local\Temp\BaselineInstaller_1234567890abcdef1234567890abcdef\s\B'
    }
}

Describe 'Get-InstallerPayloadPathBudgetReport' {
    It 'keeps the staged payload under the classic MAX_PATH limit for release packaging' {
        $report = Get-InstallerPayloadPathBudgetReport `
            -RepoRoot $script:RepoRoot `
            -BaseTempPath 'C:\Users\runneradmin\AppData\Local\Temp' `
            -RootName 'BaselineInstaller_1234567890abcdef1234567890abcdef'

        $report.MaxLength | Should -BeLessOrEqual 259
        $report.MaxRelativePath | Should -Match 'Assets\\AIRemovalPackage\\'
    }
}
