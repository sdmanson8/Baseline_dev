# P5 rollback checkpoint: extracted from Show-TweakGUI in Module\Regions\GUI.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
foreach ($prim in $PrimaryCategories.Keys)
	{
		$subs = $PrimaryCategories[$prim]
		if ($subs.Count -eq 0)
		{
			$CategoryToPrimary[$prim] = $prim
		}
		else
		{
			foreach ($s in $subs) { $CategoryToPrimary[$s] = $prim }
		}
	}
