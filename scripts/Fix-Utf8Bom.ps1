$ErrorActionPreference = 'Stop'
$bom = [byte[]](0xEF, 0xBB, 0xBF)
$fixed = New-Object System.Collections.Generic.List[string]
$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -Path $root -Recurse -Include *.ps1, *.psm1, *.psd1 -File |
    Where-Object {
        $p = $_.FullName
        ($p -notlike '*\.git\*') -and ($p -notlike '*\node_modules\*') -and ($p -notlike '*\__pycache__\*')
    }
foreach ($f in $files)
{
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -lt 3) { continue }
    $hasBom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) { continue }
    $hasNonAscii = $false
    foreach ($b in $bytes) { if ($b -gt 127) { $hasNonAscii = $true; break } }
    if (-not $hasNonAscii) { continue }
    $new = New-Object byte[] ($bytes.Length + 3)
    [Array]::Copy($bom, 0, $new, 0, 3)
    [Array]::Copy($bytes, 0, $new, 3, $bytes.Length)
    [System.IO.File]::WriteAllBytes($f.FullName, $new)
    $fixed.Add($f.FullName) | Out-Null
}
Write-Output ("Fixed {0} file(s)." -f $fixed.Count)
$fixed | ForEach-Object { Write-Output "  $_" }
