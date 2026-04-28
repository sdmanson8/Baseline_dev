# Dialog helper functions for Baseline UI modals.

# P5 rollback checkpoint: dialog helpers are split into Module\GUI\DialogHelpers\*.ps1.
# Keep this explicit order; later files may depend on functions loaded by earlier files.
$Script:DialogHelpersRoot = $PSScriptRoot
$dialogHelpersSplitRoot = Join-Path $Script:DialogHelpersRoot 'DialogHelpers'
. (Join-Path $dialogHelpersSplitRoot 'DialogThemeHelpers.ps1')
. (Join-Path $dialogHelpersSplitRoot 'ContentDialogs.ps1')
. (Join-Path $Script:DialogHelpersRoot 'PerfTrace.ps1')
. (Join-Path $dialogHelpersSplitRoot 'SettingsDialogs.ps1')
. (Join-Path $dialogHelpersSplitRoot 'AuditOperatorDialogs.ps1')
. (Join-Path $dialogHelpersSplitRoot 'RemoteDialogs.ps1')
