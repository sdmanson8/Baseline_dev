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
