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
