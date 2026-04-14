Set-StrictMode -Version Latest

# Pester resolves -ForEach during discovery, so the locale case list must exist
# before BeforeAll runs. The source data itself is loaded inside BeforeAll.
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$localizationDir = Join-Path $repoRoot 'Localizations'
$sourceFileName = 'en-US.json'
$localeFilePattern = '^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\.json$'

$script:LocaleCases = @(
    Get-ChildItem -LiteralPath $localizationDir -Recurse -Filter '*.json' -File | Where-Object {
        $_.Name -match $localeFilePattern -and $_.Name -notin @($sourceFileName, 'en-GB.json')
    } | Sort-Object Name | ForEach-Object {
        @{
            LocaleName = $_.Name
            LocalePath = $_.FullName
            LocaleCode = $_.BaseName
            LocaleDirectory = $_.Directory.Name
        }
    }
)

Describe 'Localization key-set integrity' {
    BeforeAll {
        $script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
        $script:LocalizationDir = Join-Path $script:RepoRoot 'Localizations'
        $script:SourceFileName = $sourceFileName
        $sourceMatches = @(Get-ChildItem -LiteralPath $script:LocalizationDir -Recurse -File -Filter 'en-US.json' -ErrorAction SilentlyContinue)
        if ($sourceMatches.Count -ne 1) { throw "Localization file 'en-US.json' not found uniquely under '$script:LocalizationDir'." }
        $script:SourcePath = $sourceMatches[0].FullName

        $sourceLikeMatches = @(Get-ChildItem -LiteralPath $script:LocalizationDir -Recurse -File -Filter 'en-GB.json' -ErrorAction SilentlyContinue)
        if ($sourceLikeMatches.Count -ne 1) { throw "Localization file 'en-GB.json' not found uniquely under '$script:LocalizationDir'." }
        $script:SourceLikePath = $sourceLikeMatches[0].FullName

        $script:LocalizationSchemaPath = Join-Path $script:LocalizationDir 'localization_schema.json'
        $script:LocaleMapPath = Join-Path $script:LocalizationDir 'locale-map.json'

        $script:SourceMap = Get-Content -LiteralPath $script:SourcePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $script:SourceKeys = @($script:SourceMap.PSObject.Properties.Name)
        $sortedSourceKeys = [string[]]@($script:SourceKeys | ForEach-Object { [string]$_ })
        [System.Array]::Sort($sortedSourceKeys, [System.StringComparer]::Ordinal)
        $sourcePayload = [System.Text.Encoding]::UTF8.GetBytes(($sortedSourceKeys -join "`n"))
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try
        {
            $sourceHashBytes = $sha256.ComputeHash($sourcePayload)
        }
        finally
        {
            $sha256.Dispose()
        }

        $script:SourceKeyHash = (($sourceHashBytes | ForEach-Object { $_.ToString('x2') }) -join '')

        # PowerShell 5.1 ships ConvertFrom-Json without -AsHashtable, so we
        # parse to PSObject and project to a hashtable manually. Keeps the
        # downstream indexer access (e.g. $LocalizationSchema['key_hash'])
        # identical across PS 5.1 and PS 7+.
        $convertToHashtable = {
            param($Object)
            $h = @{}
            if ($null -eq $Object) { return $h }
            foreach ($prop in $Object.PSObject.Properties)
            {
                $h[[string]$prop.Name] = $prop.Value
            }
            return $h
        }

        $schemaObj = Get-Content -LiteralPath $script:LocalizationSchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $localeMapObj = Get-Content -LiteralPath $script:LocaleMapPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $script:LocalizationSchema = & $convertToHashtable $schemaObj
        $script:LocaleMap = & $convertToHashtable $localeMapObj
    }

    It 'keeps the canonical source schema for en-US.json' {
        [string]$script:LocalizationSchema['source_file'] | Should -Be 'en-US.json'
        [int]$script:LocalizationSchema['key_count'] | Should -Be $script:SourceKeys.Count
        [string]$script:LocalizationSchema['hash_algorithm'] | Should -Be 'sha256'
        [string]$script:LocalizationSchema['key_hash'] | Should -Be $script:SourceKeyHash
    }

    It 'keeps the canonical source schema for en-GB.json' {
        $sourceLikeMap = Get-Content -LiteralPath $script:SourceLikePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $sourceLikeKeys = @($sourceLikeMap.PSObject.Properties.Name)
        $sortedSourceLikeKeys = [string[]]@($sourceLikeKeys | ForEach-Object { [string]$_ })
        [System.Array]::Sort($sortedSourceLikeKeys, [System.StringComparer]::Ordinal)
        $sourceLikePayload = [System.Text.Encoding]::UTF8.GetBytes(($sortedSourceLikeKeys -join "`n"))
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try
        {
            $sourceLikeHashBytes = $sha256.ComputeHash($sourceLikePayload)
        }
        finally
        {
            $sha256.Dispose()
        }
        $sourceLikeHash = (($sourceLikeHashBytes | ForEach-Object { $_.ToString('x2') }) -join '')

        $sourceLikeKeys.Count | Should -Be $script:SourceKeys.Count
        $sourceLikeHash | Should -Be $script:SourceKeyHash
    }

    It '<LocaleName> lives in the mapped directory' -ForEach $script:LocaleCases {
        [string]$script:LocaleMap[$LocaleCode] | Should -Be $LocaleDirectory
    }

    It '<LocaleName> preserves every source key' -ForEach $script:LocaleCases {
        $localeMap = Get-Content -LiteralPath $LocalePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $localeKeys = @($localeMap.PSObject.Properties.Name)
        $missingKeys = @($script:SourceKeys | Where-Object { $_ -notin $localeKeys })
        $extraKeys = @($localeKeys | Where-Object { $_ -notin $script:SourceKeys })

        $missingKeys | Should -BeNullOrEmpty -Because "Locale file '$LocaleName' must never drop canonical keys."
        $extraKeys | Should -BeNullOrEmpty -Because "Locale file '$LocaleName' must not invent keys outside the canonical source set."
    }
}
