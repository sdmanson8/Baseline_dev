Set-StrictMode -Version Latest

function Get-BaselineTestSourceText
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Path
    )

    $chunks = [System.Collections.Generic.List[string]]::new()
    foreach ($sourcePath in $Path)
    {
        $resolvedPath = (Resolve-Path -LiteralPath $sourcePath -ErrorAction Stop).ProviderPath
        [void]$chunks.Add((Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8))
    }

    return ($chunks -join "`n")
}
