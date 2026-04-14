Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Tools/New-InstallerPackage.ps1'
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
