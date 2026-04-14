Set-StrictMode -Version Latest

BeforeAll {
    $script:SessionStatePath = Join-Path $PSScriptRoot '../../Module/GUI/SessionState.ps1'
    $script:AuditViewPath = Join-Path $PSScriptRoot '../../Module/GUI/AuditView.ps1'
    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:GuiRegionPath = Join-Path $PSScriptRoot '../../Module/Regions/GUI.psm1'
    $script:GuiContent = Get-Content -LiteralPath $script:SessionStatePath -Raw -Encoding UTF8
    $script:AuditViewContent = Get-Content -LiteralPath $script:AuditViewPath -Raw -Encoding UTF8
    $script:DialogHelpersContent = Get-Content -LiteralPath $script:DialogHelpersPath -Raw -Encoding UTF8
    $script:GuiRegionContent = Get-Content -LiteralPath $script:GuiRegionPath -Raw -Encoding UTF8
}

Describe 'Audit retention settings' {
    It 'persists the retention window in GUI settings snapshots' {
        $script:GuiContent | Should -Match 'SchemaVersion = 15'
        $script:GuiContent | Should -Match 'AuditRetentionDays'
        $script:GuiContent | Should -Match '\$Script:AuditRetentionDays = \[int\]\$desiredAuditRetentionDays'
        $script:GuiContent | Should -Match '\$Script:Ctx.UI.AuditRetentionDays = \[int\]\$desiredAuditRetentionDays'
    }

    It 'initializes the audit dialog from the saved retention preference and keeps it live' {
        $script:AuditViewContent | Should -Match '\$initialRetentionDays = if \(\$Script:AuditRetentionDays\)'
        $script:AuditViewContent | Should -Match '\$retentionCombo.Add_SelectionChanged'
        $script:AuditViewContent | Should -Match '\$Script:AuditRetentionDays = & \$getSelectedRetentionDays'
        $script:AuditViewContent | Should -Match '\$Script:Ctx.UI.AuditRetentionDays = \[int\]\$Script:AuditRetentionDays'
    }

    It 'exposes audit retention as a first-class settings dialog and menu entry' {
        $script:DialogHelpersContent | Should -Match 'function Show-GuiAuditSettingsDialog'
        $script:DialogHelpersContent | Should -Match 'GuiAuditSettings'
        $script:DialogHelpersContent | Should -Match 'CmbAuditRetention'
        $script:GuiRegionContent | Should -Match 'MenuFileAuditSettings'
        $script:GuiRegionContent | Should -Match 'Audit Settings\.\.\.'
    }
}
