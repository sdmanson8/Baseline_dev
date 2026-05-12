# P5 rollback checkpoint: extracted from WindowsCapabilities in Module\Regions\System\System.WindowsFeatures.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
# Foreground activation is intentionally omitted. The dialog must not reclaim
# focus after the user moves to another window.
