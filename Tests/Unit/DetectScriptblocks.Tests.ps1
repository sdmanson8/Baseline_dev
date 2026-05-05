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

    It 'routes expected detection catches through Write-DebugSwallowedException and keeps Defender probes quiet' {
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.RegistryBackup\.LoadAutoRegBackupTask'
        $script:DetectScriptblocksContent | Should -Match 'function Get-GuiDetectMpPreference'
        $script:DetectScriptblocksContent | Should -Not -Match 'DetectScriptblocks\.NetworkProtection\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Not -Match 'DetectScriptblocks\.DefenderScanCPULimit\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Not -Match 'DetectScriptblocks\.DefenderSignatureUpdateInterval\.LoadMpPreference'
        $script:DetectScriptblocksContent | Should -Match 'DetectScriptblocks\.BlockStoreSearchResults\.LoadIdentitySid'
    }
}
