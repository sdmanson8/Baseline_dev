Set-StrictMode -Version Latest

BeforeAll {
    <#
        .SYNOPSIS
        Internal function Get-BaselineDisplayVersion.

        .DESCRIPTION
        Internal implementation helper used by Baseline.
    #>

    function Get-BaselineDisplayVersion { return '4.0.0-beta' }

    $auditHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/AuditTrail.Helpers.ps1'
    $bundleHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/SupportBundle.Helpers.ps1'
    $remoteHelpersPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/RemoteTarget.Helpers.ps1'
    $script:BundleHelpersPath = $bundleHelpersPath
    foreach ($filePath in @($auditHelpersPath, $remoteHelpersPath, $bundleHelpersPath)) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
        $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $functions) {
            Invoke-Expression $fn.Extent.Text
        }
    }

    $script:TempRoot = Join-Path $env:TEMP ('BaselineSupportBundleTests_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null
    $script:AuditLogPath = Join-Path $script:TempRoot 'audit.jsonl'
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $oldTimestamp = ([datetime]::UtcNow).AddDays(-120).ToString('o')
    $recentTimestamp = ([datetime]::UtcNow).AddHours(-1).ToString('o')
    @(
        ('{{"Timestamp":"{0}","Action":"Run","Mode":"Run"}}' -f $oldTimestamp)
        ('{{"Timestamp":"{0}","Action":"Compliance","Mode":"Compliance"}}' -f $recentTimestamp)
    ) | Set-Content -LiteralPath $script:AuditLogPath -Encoding UTF8
    $script:BundlePath = Join-Path $script:TempRoot 'support-bundle.zip'
    $script:SharedHelpersRepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

AfterAll {
    if ($null -ne $script:OriginalLocalAppData) {
        $env:LOCALAPPDATA = $script:OriginalLocalAppData
    }
    if (Test-Path -LiteralPath $script:TempRoot) {
        Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Export-BaselineSupportBundle' {
    It 'creates a zip archive with bundle metadata and audit log' {
        $historyRoot = Join-Path $script:TempRoot 'LocalAppData'
        $historyDir = Join-Path $historyRoot 'Baseline'
        New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
        $historyPath = Join-Path $historyDir 'remote-orchestration.jsonl'
        @(
            '{"Timestamp":"2026-04-14T08:00:00.0000000Z","MachineName":"TESTHOST","RunId":"abc123","Operation":"RemoteApply","ComputerName":"server01","Status":"Applied","SessionReused":true,"SessionState":"Opened","AppliedCount":2,"FailedCount":0,"DriftedCount":0,"TotalChecked":0,"FailureCategory":"Success","Retryable":false,"RetryReason":"Completed successfully.","Errors":[],"HistoryPath":"C:\\Temp\\remote-orchestration.jsonl"}'
            '{"Timestamp":"2026-04-14T08:01:00.0000000Z","MachineName":"TESTHOST","RunId":"def456","Operation":"RemoteCompliance","ComputerName":"server02","Status":"Compliant","SessionReused":false,"SessionState":"Opened","AppliedCount":0,"FailedCount":0,"DriftedCount":0,"TotalChecked":4,"FailureCategory":"Success","Retryable":false,"RetryReason":"Completed successfully.","Errors":[],"HistoryPath":"C:\\Temp\\remote-orchestration.jsonl"}'
        ) | Set-Content -LiteralPath $historyPath -Encoding UTF8

        # Place the seeded audit log where Get-AuditLogPath will resolve it
        # once $env:LOCALAPPDATA is redirected below.
        Copy-Item -LiteralPath $script:AuditLogPath -Destination (Join-Path $historyDir 'audit.jsonl') -Force

        $previousLocalAppData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = $historyRoot
        try {
            $result = Export-BaselineSupportBundle -OutputPath $script:BundlePath -IncludeTestReport:$false
        }
        finally {
            $env:LOCALAPPDATA = $previousLocalAppData
        }

        Test-Path -LiteralPath $result.OutputPath | Should -BeTrue

        $extractDir = Join-Path $script:TempRoot 'extract'
        Expand-Archive -LiteralPath $result.OutputPath -DestinationPath $extractDir -Force

        $metadataPath = Join-Path $extractDir 'metadata.json'
        $auditCopyPath = Join-Path $extractDir 'audit.jsonl'
        $contentsPath = Join-Path $extractDir 'contents.json'

        Test-Path -LiteralPath $metadataPath | Should -BeTrue
        Test-Path -LiteralPath $auditCopyPath | Should -BeTrue
        Test-Path -LiteralPath $contentsPath | Should -BeTrue

        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $metadata.Schema | Should -Be 'Baseline.SupportBundle'
        $metadata.BaselineVersion | Should -Be '4.0.0-beta'
        $metadata.AuditRetention.Days | Should -BeGreaterThan 0

        $contents = Get-Content -LiteralPath $contentsPath -Raw | ConvertFrom-Json
        @($contents.Files).Count | Should -BeGreaterThan 0
        ($contents.Files | Where-Object Name -eq 'remote-orchestration.jsonl').Count | Should -Be 1
        ($contents.Files | Where-Object Name -eq 'remote-orchestration-summary.txt').Count | Should -Be 1
        ($contents.Files | Where-Object Name -eq 'remote-orchestration-reconciliation.json').Count | Should -Be 1
        ($contents.Files | Where-Object Name -eq 'remote-orchestration-details.json').Count | Should -Be 1
        ($contents.Files | Where-Object Name -eq 'bundle-index.json').Count | Should -Be 1

        $auditLines = @(Get-Content -LiteralPath $auditCopyPath)
        $auditLines.Count | Should -Be 1
        ($auditLines[0] | ConvertFrom-Json).Action | Should -Be 'Compliance'

        Test-Path -LiteralPath (Join-Path $extractDir 'remote-orchestration.jsonl') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractDir 'remote-orchestration-summary.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractDir 'remote-orchestration-reconciliation.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractDir 'remote-orchestration-details.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $extractDir 'bundle-index.json') | Should -BeTrue
    }

    It 'includes the preflight report when the preflight command is available' {
        $bundleContent = Get-Content -LiteralPath $script:BundleHelpersPath -Raw -Encoding UTF8
        $bundleContent | Should -Match 'Invoke-PreflightChecks'
        $bundleContent | Should -Match 'preflight-report\.json'
        $bundleContent | Should -Match 'remote-orchestration\.jsonl'
        $bundleContent | Should -Match 'remote-orchestration-summary\.txt'
        $bundleContent | Should -Match 'remote-orchestration-reconciliation\.json'
        $bundleContent | Should -Match 'remote-orchestration-details\.json'
        $bundleContent | Should -Match 'bundle-index\.json'
    }
}
