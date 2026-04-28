Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/GUI/DetectScriptblocks.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $script:DetectScriptblocksContent = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Invoke-GuiDetectScriptblock' {
    BeforeEach {
        $script:DesignMode = $false
    }

    It 'returns the scriptblock result when Design Mode is off' {
        $result = Invoke-GuiDetectScriptblock -Detect { $true } -DefaultValue $false

        $result | Should -Be $true
    }

    It 'returns the manifest default when Design Mode is on' {
        $script:DesignMode = $true

        $result = Invoke-GuiDetectScriptblock -Detect { throw 'should not run' } -DefaultValue $true

        $result | Should -Be $true
    }

    It 'routes detection fallback catches through Write-DebugSwallowedException' {
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.RegistryBackup\.LoadAutoRegBackupTask'
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.NetworkProtection\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.DefenderScanCPULimit\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.DefenderSignatureUpdateInterval\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.BlockStoreSearchResults\.LoadIdentitySid'
    }
}
