# P5 rollback checkpoint: extracted from InitialActions in Module\Regions\InitialActions.psm1.
# Contract: dot-sourced in the caller scope; preserves local variables and throws with the original inline behavior.
$Signature = @{
		Namespace          = "WinAPI"
		Name               = "ForegroundWindow"
		Language           = "CSharp"
		CompilerParameters = $CompilerParameters
		MemberDefinition   = @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll")]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
"@
	}
