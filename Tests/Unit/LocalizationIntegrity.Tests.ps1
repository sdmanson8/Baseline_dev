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
        # identical across supported Windows PowerShell 5.1 runs.
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

Describe 'Localization value integrity' {
    BeforeAll {
        $script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
        $script:LocalizationDir = Join-Path $script:RepoRoot 'Localizations'
        $script:ExemptKeysPath = Join-Path $script:LocalizationDir 'english_exempt_keys.json'

        $script:ExemptKeys = @()
        if (Test-Path -LiteralPath $script:ExemptKeysPath -PathType Leaf)
        {
            $exemptData = Get-Content -LiteralPath $script:ExemptKeysPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if ($exemptData -is [System.Collections.IDictionary])
            {
                $script:ExemptKeys = @($exemptData.Keys)
            }
            elseif ($exemptData -is [pscustomobject])
            {
                $script:ExemptKeys = @($exemptData.PSObject.Properties | ForEach-Object { $_.Name })
            }
            else
            {
                $script:ExemptKeys = @($exemptData)
            }
        }

        $script:ExemptKeys = @(
            $script:ExemptKeys |
                Where-Object { $_ } |
                Sort-Object -Unique
        )
    }

    It '<LocaleName> does not contain empty translations outside the exemption list' -ForEach $script:LocaleCases {
        $localeMap = Get-Content -LiteralPath $LocalePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $emptyKeys = @(
            $localeMap.PSObject.Properties |
                Where-Object {
                    [string]::IsNullOrWhiteSpace([string]$_.Value) -and
                    ($_.Name -notin $script:ExemptKeys)
                } |
                ForEach-Object { $_.Name }
        )

        $emptyKeys | Should -BeNullOrEmpty -Because "Locale file '$LocaleName' must not contain empty translations for non-exempt keys."
    }
}

Describe 'Localization string-overflow guard' {
    BeforeAll {
        $script:RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
        $script:LocalizationDir = Join-Path $script:RepoRoot 'Localizations'
        $script:StringLengthLimitsPath = Join-Path $script:LocalizationDir 'string_length_limits.json'

        $script:StringLengthLimits = @{}
        if (Test-Path -LiteralPath $script:StringLengthLimitsPath -PathType Leaf)
        {
            $limitData = Get-Content -LiteralPath $script:StringLengthLimitsPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            foreach ($prop in $limitData.PSObject.Properties)
            {
                if ($prop.Name.StartsWith('_')) { continue }
                $script:StringLengthLimits[[string]$prop.Name] = [int]$prop.Value
            }
        }
    }

    It 'has a non-empty length-limit configuration' {
        $script:StringLengthLimits.Count | Should -BeGreaterThan 0 -Because 'string_length_limits.json must define at least one tight UI slot to guard against overflow.'
    }

    It '<LocaleName> respects every declared UI slot length limit' -ForEach $script:LocaleCases {
        $localeMap = Get-Content -LiteralPath $LocalePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $overflows = foreach ($key in $script:StringLengthLimits.Keys)
        {
            $prop = $localeMap.PSObject.Properties[$key]
            if ($null -eq $prop) { continue }
            $value = [string]$prop.Value
            if ([string]::IsNullOrWhiteSpace($value)) { continue }
            $limit = [int]$script:StringLengthLimits[$key]
            if ($value.Length -gt $limit)
            {
                "{0} = '{1}' ({2} chars, limit {3})" -f $key, $value, $value.Length, $limit
            }
        }

        $overflows = @($overflows)
        $overflows | Should -BeNullOrEmpty -Because "Locale file '$LocaleName' has translations that exceed declared UI slot widths and will overflow the control: $($overflows -join '; ')"
    }
}
