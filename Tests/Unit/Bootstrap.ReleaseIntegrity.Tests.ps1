Set-StrictMode -Version Latest

BeforeAll {
    $sourceContentHelperPath = Join-Path $PSScriptRoot 'Support/SourceContent.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $sourceContentHelperPath)) { $sourceContentHelperPath = Join-Path $PSScriptRoot '../Support/SourceContent.Helpers.ps1' }
    . $sourceContentHelperPath


    $filePath = Join-Path $PSScriptRoot '../../Bootstrap/Bootstrap.ps1'
    $script:bootstrapContent = Get-BaselineTestSourceText -Path $filePath
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functionsToLoad = @(
        'Get-RawBootstrapFileSha256',
        'Get-RawBootstrapReleaseIntegrityManifest',
        'Get-RawBootstrapReleaseAssetSha256',
        'Assert-RawBootstrapReleaseAssetHash',
        'Compare-BootstrapReleaseVersions'
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

        $script:archiveName = 'Baseline-4.0.0-stable.zip'
        $script:setupName = 'Baseline-4.0.0-beta-setup.exe'
        $script:archivePath = Join-Path $script:fixtureRoot $script:archiveName
        $script:setupPath = Join-Path $script:fixtureRoot $script:setupName
        $script:manifestPath = Join-Path $script:fixtureRoot ($script:archiveName + '.sha256.json')

        Set-Content -LiteralPath $script:archivePath -Value 'archive payload' -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath $script:setupPath -Value 'setup payload' -Encoding UTF8 -NoNewline

        $script:archiveHash = (Get-RawBootstrapFileSha256 -Path $script:archivePath)
        $script:setupHash = (Get-RawBootstrapFileSha256 -Path $script:setupPath)

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

    It 'allows callers to select the bootstrap release channel explicitly' {
        $script:bootstrapContent | Should -Match '\[ValidateSet\(''stable'', ''beta''\)\]'
        $script:bootstrapContent | Should -Match '\[string\]\$ReleaseChannel'
        $script:bootstrapContent | Should -Match 'IsNullOrWhiteSpace\(\$ReleaseChannel\)'
    }

    It 'parses channel-stamped prerelease tags during version comparison' {
        Compare-BootstrapReleaseVersions -LeftVersion 'v4.0.0-beta.1' -RightVersion 'v4.0.0-beta' | Should -BeGreaterThan 0
        Compare-BootstrapReleaseVersions -LeftVersion 'v4.0.0-beta-rc1' -RightVersion 'v4.0.0-beta' | Should -BeGreaterThan 0
        Compare-BootstrapReleaseVersions -LeftVersion 'v4.0.0-beta' -RightVersion 'v4.0.0' | Should -BeLessThan 0
    }

    It 'routes published-at parse failures through severity-aware swallowed-exception logging' {
        $script:bootstrapContent | Should -Match 'Write-BootstrapSwallowedException -ErrorRecord \$_ -Source ''Bootstrap\.Get-BootstrapLatestRelease\.ParsePublishedAt'' -Severity Debug'
    }

    It 'routes TLS setup failures through warning-severity swallowed-exception logging' {
        $script:bootstrapContent | Should -Match 'Write-BootstrapSwallowedException -ErrorRecord \$_ -Source ''Bootstrap\.Enable-Tls12'' -Severity Warning'
    }

    It 'fails visibly when execution-critical bootstrap cache cleanup fails' {
        $script:bootstrapContent | Should -Match 'Remove-Item -LiteralPath \$CacheRoot -Recurse -Force -ErrorAction Stop'
        $script:bootstrapContent | Should -Match 'Failed to clean bootstrap cache'
        $script:bootstrapContent | Should -Not -Match 'Remove-Item -LiteralPath \$CacheRoot -Recurse -Force -ErrorAction SilentlyContinue'
    }

    It 'returns the expected SHA-256 for an asset in the manifest' {
        $result = Get-RawBootstrapReleaseAssetSha256 -ManifestPath $script:manifestPath -AssetName $script:archiveName

        $result | Should -Be $script:archiveHash
    }

    It 'verifies the release archive hash against the manifest' {
        $result = Assert-RawBootstrapReleaseAssetHash -ManifestPath $script:manifestPath -AssetName $script:archiveName -FilePath $script:archivePath -Label 'Release archive'

        $result | Should -Be $script:archiveHash
    }

    It 'throws when the manifest does not contain the requested asset hash' {
        { Get-RawBootstrapReleaseAssetSha256 -ManifestPath $script:manifestPath -AssetName 'missing.zip' } | Should -Throw '*does not contain a SHA-256 entry*'
    }

    It 'throws when the manifest algorithm is unsupported' {
        [ordered]@{
            schemaVersion = 1
            algorithm     = 'sha512'
            files         = [ordered]@{
                $script:archiveName = $script:archiveHash
            }
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:manifestPath -Encoding UTF8

        { Get-RawBootstrapReleaseIntegrityManifest -ManifestPath $script:manifestPath } | Should -Throw '*Unsupported release integrity manifest algorithm*'
    }
}
