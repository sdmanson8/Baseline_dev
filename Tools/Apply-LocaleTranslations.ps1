[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LocaleName,

    [Parameter(Mandatory)]
    [string]$TranslationsJsonPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$localizationDir = Join-Path $repoRoot 'Localizations'

$file = Get-ChildItem -LiteralPath $localizationDir -Recurse -Filter "$LocaleName.json" -File | Select-Object -First 1
if (-not $file) { throw "Locale file not found: $LocaleName.json" }

$translations = Get-Content -LiteralPath $TranslationsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

$doc = [System.Text.Json.JsonDocument]::Parse((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8))
$orderedLocale = [ordered]@{}
foreach ($prop in $doc.RootElement.EnumerateObject()) {
    $orderedLocale[$prop.Name] = [string]$prop.Value.GetString()
}
$doc.Dispose()

$applied = 0
$skipped = 0
foreach ($k in $translations.Keys) {
    if (-not $orderedLocale.Contains($k)) { $skipped++; continue }
    $orderedLocale[$k] = [string]$translations[$k]
    $applied++
}

$json = $orderedLocale | ConvertTo-Json -Depth 4
$json = $json -replace "`r`n", "`n"
$json = $json + "`n"
[System.IO.File]::WriteAllText($file.FullName, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ("Applied {0} translations to {1} (skipped {2})" -f $applied, $file.FullName, $skipped)
