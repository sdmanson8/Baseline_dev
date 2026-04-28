Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Bootstrap/Bootstrap.ps1'
    $script:bootstrapContent = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functionsToLoad = @(
        'Get-BootstrapFileSha256',
        'Get-BootstrapReleaseIntegrityManifest',
        'Get-BootstrapReleaseAssetSha256',
        'Assert-BootstrapReleaseAssetHash'
    )

    $functions = $ast.FindAll({
            param($node)
            ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and
            ($functionsToLoad -contains $node.Name)
        }, $true)

    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Bootstrap release integrity helpers' {
    BeforeEach {
        $script:fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('baseline-bootstrap-integrity-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null

        $script:archiveName = 'Baseline-4.0.0.zip'
        $script:setupName = 'Baseline-setup-4.0.0.exe'
        $script:archivePath = Join-Path $script:fixtureRoot $script:archiveName
        $script:setupPath = Join-Path $script:fixtureRoot $script:setupName
        $script:manifestPath = Join-Path $script:fixtureRoot ($script:archiveName + '.sha256.json')

        Set-Content -LiteralPath $script:archivePath -Value 'archive payload' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath $script:setupPath -Value 'setup payload' -Encoding UTF8 -NoNewline

        $script:archiveHash = (Get-BootstrapFileSha256 -Path $script:archivePath)
        $script:setupHash = (Get-BootstrapFileSha256 -Path $script:setupPath)

        [ordered]@{
            schemaVersion = 1
            algorithm     = 'sha256'
            files         = [ordered]@{
                $script:archiveName = $script:archiveHash
                $script:setupName   = $script:setupHash
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:manifestPath -Encoding UTF8
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force
        }
    }

    It 'enforces a single matching archive and manifest asset per release' {
        $script:bootstrapContent | Should -Match 'Where-Object \{ \[string\]\$_\.name -match \$expectedZipPattern \}'
        $script:bootstrapContent | Should -Match 'Where-Object \{ \[string\]\$_\.name -match \$expectedManifestPattern \}'
        $script:bootstrapContent | Should -Match '\$releaseZip\.Count -ne 1 -or \$releaseManifest\.Count -ne 1'
        $script:bootstrapContent | Should -Match 'Release contract violation for'
        $script:bootstrapContent | Should -Match 'expected exactly one zip matching'
        $script:bootstrapContent | Should -Match 'one SHA-256 manifest matching'
    }

    It 'routes published-at parse failures through Write-DebugSwallowedException' {
        $script:bootstrapContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Bootstrap\.Get-BootstrapLatestRelease\.ParsePublishedAt'''
    }

    It 'routes TLS setup failures through Write-DebugSwallowedException' {
        $script:bootstrapContent | Should -Match 'Write-DebugSwallowedException -ErrorRecord \$_ -Source ''Bootstrap\.Enable-Tls12'''
    }

    It 'returns the expected SHA-256 for an asset in the manifest' {
        $result = Get-BootstrapReleaseAssetSha256 -ManifestPath $script:manifestPath -AssetName $script:archiveName

        $result | Should -Be $script:archiveHash
    }

    It 'verifies the release archive hash against the manifest' {
        $result = Assert-BootstrapReleaseAssetHash -ManifestPath $script:manifestPath -AssetName $script:archiveName -FilePath $script:archivePath -Label 'Release archive'

        $result | Should -Be $script:archiveHash
    }

    It 'throws when the manifest does not contain the requested asset hash' {
        { Get-BootstrapReleaseAssetSha256 -ManifestPath $script:manifestPath -AssetName 'missing.zip' } | Should -Throw '*does not contain a SHA-256 entry*'
    }

    It 'throws when the manifest algorithm is unsupported' {
        [ordered]@{
            schemaVersion = 1
            algorithm     = 'sha512'
            files         = [ordered]@{
                $script:archiveName = $script:archiveHash
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:manifestPath -Encoding UTF8

        { Get-BootstrapReleaseIntegrityManifest -ManifestPath $script:manifestPath } | Should -Throw '*Unsupported release integrity manifest algorithm*'
    }
}
