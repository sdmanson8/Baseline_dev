# WindowPosition helpers for Baseline.
# Persists the GUI window placement (Left/Top/Width/Height/Maximized) across
# sessions and validates that the saved rectangle still falls on a connected
# display before reusing it. Window placement contract:
# the saved rectangle is only restored when at least
# $Script:BaselineWindowMinVisibleWidth x $Script:BaselineWindowMinVisibleHeight
# of it overlaps the working area of any display, otherwise the caller falls
# back to the default centred placement.

$Script:BaselineWindowMinVisibleWidth  = 120
$Script:BaselineWindowMinVisibleHeight = 40
$Script:BaselineWindowPrefKeys = @{
	Left       = 'WindowLeft'
	Top        = 'WindowTop'
	Width      = 'WindowWidth'
	Height     = 'WindowHeight'
	Maximized  = 'WindowMaximized'
	Remember   = 'RememberWindowPosition'
}

function Get-BaselineDisplayWorkAreas
{
	<#
		.SYNOPSIS
		Returns the work-area rectangles for every connected display.

		.DESCRIPTION
		Prefers System.Windows.Forms.Screen so multi-monitor setups are
		enumerated. Falls back to System.Windows.SystemParameters.WorkArea
		(primary display only) when WinForms is unavailable. Each returned
		object exposes Left/Top/Width/Height in device-independent pixels.
	#>
	[CmdletBinding()]
	param ()

	$result = New-Object System.Collections.Generic.List[object]
	try
	{
		Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
		$screens = [System.Windows.Forms.Screen]::AllScreens
		foreach ($screen in $screens)
		{
			$wa = $screen.WorkingArea
			$result.Add([pscustomobject]@{
				Left   = [double]$wa.X
				Top    = [double]$wa.Y
				Width  = [double]$wa.Width
				Height = [double]$wa.Height
			})
		}
	}
	catch
	{
		try
		{
			$wa = [System.Windows.SystemParameters]::WorkArea
			$result.Add([pscustomobject]@{
				Left   = [double]$wa.Left
				Top    = [double]$wa.Top
				Width  = [double]$wa.Width
				Height = [double]$wa.Height
			})
		}
		catch
		{
			$result.Add([pscustomobject]@{
				Left   = 0.0
				Top    = 0.0
				Width  = 1024.0
				Height = 768.0
			})
		}
	}
	return ,$result.ToArray()
}

function Test-BaselineWindowRectVisible
{
	<#
		.SYNOPSIS
		Returns $true when at least MinVisibleWidth x MinVisibleHeight of the
		given window rectangle overlaps the work area of any display.

		.PARAMETER Rect
		Hashtable / pscustomobject with Left, Top, Width, Height (doubles).

		.PARAMETER WorkAreas
		Array of display work-area rectangles produced by
		Get-BaselineDisplayWorkAreas.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object]$Rect,

		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[AllowNull()]
		[object[]]$WorkAreas,

		[double]$MinVisibleWidth  = $Script:BaselineWindowMinVisibleWidth,
		[double]$MinVisibleHeight = $Script:BaselineWindowMinVisibleHeight
	)

	if (-not $Rect) { return $false }
	if ($null -eq $WorkAreas -or $WorkAreas.Count -eq 0) { return $false }

	$rLeft   = [double]$Rect.Left
	$rTop    = [double]$Rect.Top
	$rWidth  = [double]$Rect.Width
	$rHeight = [double]$Rect.Height
	if ($rWidth -le 0 -or $rHeight -le 0) { return $false }
	$rRight  = $rLeft + $rWidth
	$rBottom = $rTop  + $rHeight

	foreach ($wa in $WorkAreas)
	{
		if (-not $wa) { continue }
		$wLeft   = [double]$wa.Left
		$wTop    = [double]$wa.Top
		$wRight  = $wLeft + [double]$wa.Width
		$wBottom = $wTop  + [double]$wa.Height

		$ovLeft   = [Math]::Max($rLeft,   $wLeft)
		$ovTop    = [Math]::Max($rTop,    $wTop)
		$ovRight  = [Math]::Min($rRight,  $wRight)
		$ovBottom = [Math]::Min($rBottom, $wBottom)

		$ovWidth  = $ovRight  - $ovLeft
		$ovHeight = $ovBottom - $ovTop
		if ($ovWidth -ge $MinVisibleWidth -and $ovHeight -ge $MinVisibleHeight)
		{
			return $true
		}
	}
	return $false
}

function Get-BaselineSavedWindowPlacement
{
	<#
		.SYNOPSIS
		Reads the persisted window placement from the user-prefs store.
		Returns $null when nothing has been saved or the saved values are
		not numerically usable.
	#>
	[CmdletBinding()]
	param ()

	$getPref = Get-Command -Name 'Get-BaselineUserPreference' -ErrorAction SilentlyContinue
	if (-not $getPref) { return $null }

	$left      = & $getPref -Key $Script:BaselineWindowPrefKeys.Left
	$top       = & $getPref -Key $Script:BaselineWindowPrefKeys.Top
	$width     = & $getPref -Key $Script:BaselineWindowPrefKeys.Width
	$height    = & $getPref -Key $Script:BaselineWindowPrefKeys.Height
	$maximized = & $getPref -Key $Script:BaselineWindowPrefKeys.Maximized -Default $false

	if ($null -eq $width -or $null -eq $height) { return $null }
	if ($null -eq $left -or $null -eq $top) { return $null }

	$dLeft   = 0.0; $dTop = 0.0; $dWidth = 0.0; $dHeight = 0.0
	if (-not [double]::TryParse([string]$left,   [ref]$dLeft))   { return $null }
	if (-not [double]::TryParse([string]$top,    [ref]$dTop))    { return $null }
	if (-not [double]::TryParse([string]$width,  [ref]$dWidth))  { return $null }
	if (-not [double]::TryParse([string]$height, [ref]$dHeight)) { return $null }

	if ($dWidth -le 0 -or $dHeight -le 0) { return $null }

	return [pscustomobject]@{
		Left      = $dLeft
		Top       = $dTop
		Width     = $dWidth
		Height    = $dHeight
		Maximized = [bool]$maximized
	}
}

function Save-BaselineWindowPlacement
{
	<#
		.SYNOPSIS
		Persists the supplied window placement to the user-prefs store. A
		no-op when the user has opted out via RememberWindowPosition=$false
		or when the user-prefs API is unavailable. Maximized windows save
		their RestoreBounds rather than the screen-filling rect so the
		next launch comes up at a usable size.
	#>
	[CmdletBinding()]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param (
		[Parameter(Mandatory)]
		[double]$Left,
		[Parameter(Mandatory)]
		[double]$Top,
		[Parameter(Mandatory)]
		[double]$Width,
		[Parameter(Mandatory)]
		[double]$Height,
		[bool]$Maximized = $false
	)

	$setPref = Get-Command -Name 'Set-BaselineUserPreference' -ErrorAction SilentlyContinue
	$getPref = Get-Command -Name 'Get-BaselineUserPreference' -ErrorAction SilentlyContinue
	if (-not $setPref -or -not $getPref) { return $false }

	$remember = & $getPref -Key $Script:BaselineWindowPrefKeys.Remember -Default $true
	if (-not [bool]$remember) { return $false }

	if ($Width -le 0 -or $Height -le 0) { return $false }

	& $setPref -Key $Script:BaselineWindowPrefKeys.Left      -Value ([double]$Left)
	& $setPref -Key $Script:BaselineWindowPrefKeys.Top       -Value ([double]$Top)
	& $setPref -Key $Script:BaselineWindowPrefKeys.Width     -Value ([double]$Width)
	& $setPref -Key $Script:BaselineWindowPrefKeys.Height    -Value ([double]$Height)
	& $setPref -Key $Script:BaselineWindowPrefKeys.Maximized -Value ([bool]$Maximized)
	return $true
}

function Resolve-BaselineWindowPlacement
{
	<#
		.SYNOPSIS
		Returns the window placement to apply at startup. Prefers the
		persisted placement when it is still visible on a connected
		display; otherwise returns the supplied default rectangle.

		.PARAMETER DefaultRect
		The fallback rectangle (Left/Top/Width/Height) computed from the
		current display's work area. Used when bounds-validation rejects
		the saved rect or when no rect has been saved.

		.PARAMETER WorkAreas
		Display work areas as produced by Get-BaselineDisplayWorkAreas. If
		omitted, queried at call time.

		.OUTPUTS
		[pscustomobject] with Left/Top/Width/Height/Maximized/Source where
		Source is one of 'saved', 'default-no-saved', 'default-off-screen',
		'default-disabled'.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object]$DefaultRect,

		[object[]]$WorkAreas,

		[double]$MinVisibleWidth  = $Script:BaselineWindowMinVisibleWidth,
		[double]$MinVisibleHeight = $Script:BaselineWindowMinVisibleHeight
	)

	$getPref = Get-Command -Name 'Get-BaselineUserPreference' -ErrorAction SilentlyContinue
	$remember = $true
	if ($getPref)
	{
		$remember = [bool](& $getPref -Key $Script:BaselineWindowPrefKeys.Remember -Default $true)
	}

	$default = [pscustomobject]@{
		Left      = [double]$DefaultRect.Left
		Top       = [double]$DefaultRect.Top
		Width     = [double]$DefaultRect.Width
		Height    = [double]$DefaultRect.Height
		Maximized = $false
		Source    = 'default-disabled'
	}

	if (-not $remember) { return $default }

	$saved = Get-BaselineSavedWindowPlacement
	if (-not $saved)
	{
		$default.Source = 'default-no-saved'
		return $default
	}

	if (-not $WorkAreas) { $WorkAreas = Get-BaselineDisplayWorkAreas }

	$visible = Test-BaselineWindowRectVisible -Rect $saved -WorkAreas $WorkAreas `
		-MinVisibleWidth $MinVisibleWidth -MinVisibleHeight $MinVisibleHeight
	if (-not $visible)
	{
		$default.Source = 'default-off-screen'
		return $default
	}

	return [pscustomobject]@{
		Left      = $saved.Left
		Top       = $saved.Top
		Width     = $saved.Width
		Height    = $saved.Height
		Maximized = $saved.Maximized
		Source    = 'saved'
	}
}

