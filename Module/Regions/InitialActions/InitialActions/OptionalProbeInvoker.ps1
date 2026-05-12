# P5 rollback checkpoint: extracted from InitialActions in Module\Regions\InitialActions.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$InvokeOptionalProbe = {
			param([scriptblock]$ScriptBlock)

			try
			{
				& $ScriptBlock
			}
			catch
			{
				$null
			}
		}
