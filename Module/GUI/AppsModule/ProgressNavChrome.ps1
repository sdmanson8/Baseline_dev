# AppsModule split file loaded by Module\GUI\AppsModule.ps1.

<#
    .SYNOPSIS
    Internal function Ensure-SheenProgressBarType.
#>

function Ensure-SheenProgressBarType
{
	[CmdletBinding()]
	param ()

	if ('SheenProgressBar' -as [type])
	{
		return
	}

	Add-Type -AssemblyName System.Windows.Forms
	Add-Type -AssemblyName System.Drawing
	Add-Type -AssemblyName WindowsFormsIntegration

	$csharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class SheenProgressBar : Control
{
    private int _minimum = 0;
    private int _maximum = 100;
    private int _value = 0;
    private bool _isIndeterminate = false;
    private float _highlightPhase = 0f;
    private Timer _animTimer;

    public int Minimum
    {
        get { return _minimum; }
        set { _minimum = Math.Max(0, Math.Min(value, _maximum)); Invalidate(); }
    }

    public int Maximum
    {
        get { return _maximum; }
        set
        {
            _maximum = Math.Max(1, value);
            if (_minimum > _maximum) { _minimum = _maximum; }
            if (_value > _maximum) { _value = _maximum; }
            Invalidate();
        }
    }

    public int Value
    {
        get { return _value; }
        set { _value = Math.Max(_minimum, Math.Min(value, _maximum)); Invalidate(); }
    }

    public bool IsIndeterminate
    {
        get { return _isIndeterminate; }
        set { _isIndeterminate = value; Invalidate(); }
    }

	public int SheenWidth { get; set; }
	public int SheenAlphaPeak { get; set; }
	public Color BarColor { get; set; }
	public Color BackgroundColor { get; set; }

    public SheenProgressBar()
    {
        this.DoubleBuffered = true;
        this.MinimumSize = new Size(1, 1);
		this.SheenWidth = 80;
		this.SheenAlphaPeak = 150;
		this.BarColor = Color.FromArgb(0, 120, 215);
		this.BackgroundColor = Color.FromArgb(40, 40, 40);
        _animTimer = new Timer();
        _animTimer.Interval = 30;
        _animTimer.Tick += (s, e) =>
        {
            _highlightPhase += 0.03f;
            if (_highlightPhase > 1.2f) _highlightPhase = -0.2f;
            Invalidate();
        };
        _animTimer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;

        Rectangle bounds = new Rectangle(0, 0, this.Width, this.Height);
        using (SolidBrush bgBrush = new SolidBrush(BackgroundColor))
        {
            g.FillRectangle(bgBrush, bounds);
        }

        if (this.Width <= 0 || this.Height <= 0)
        {
            return;
        }

        if (_isIndeterminate)
        {
            int sweepWidth = Math.Max(SheenWidth * 2, Math.Max(30, this.Width / 3));
            int travelWidth = this.Width + sweepWidth + SheenWidth;
            int sweepX = (int)(((_highlightPhase + 0.2f) / 1.4f) * travelWidth) - sweepWidth;
            Rectangle sweepRect = new Rectangle(sweepX, 0, sweepWidth, this.Height);

            using (SolidBrush barBrush = new SolidBrush(BarColor))
            {
                g.FillRectangle(barBrush, sweepRect);
            }

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sweepRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(bounds);
                g.FillRectangle(sheenBrush, sweepRect);
                g.Clip = prev;
            }

            return;
        }

        int range = Math.Max(1, _maximum - _minimum);
        int fillWidth = (int)(((float)(_value - _minimum) / range) * this.Width);
        fillWidth = Math.Max(0, Math.Min(fillWidth, this.Width));
        if (fillWidth <= 0) return;

        Rectangle fillRect = new Rectangle(0, 0, fillWidth, this.Height);
        using (SolidBrush barBrush = new SolidBrush(BarColor))
        {
            g.FillRectangle(barBrush, fillRect);
        }

        if (fillWidth > 4)
        {
            int sheenX = (int)(_highlightPhase * (fillRect.Width + SheenWidth)) - SheenWidth + fillRect.X;
            Rectangle sheenRect = new Rectangle(sheenX, fillRect.Y, SheenWidth, fillRect.Height);

            using (LinearGradientBrush sheenBrush = new LinearGradientBrush(
                sheenRect, Color.Transparent, Color.Transparent, LinearGradientMode.Horizontal))
            {
                ColorBlend blend = new ColorBlend();
                blend.Positions = new float[] { 0f, 0.35f, 0.5f, 0.65f, 1f };
                blend.Colors = new Color[]
                {
                    Color.FromArgb(0, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak, 255, 255, 255),
                    Color.FromArgb(SheenAlphaPeak / 2, 255, 255, 255),
                    Color.FromArgb(0, 255, 255, 255)
                };
                sheenBrush.InterpolationColors = blend;

                Region prev = g.Clip;
                g.SetClip(fillRect);
                g.FillRectangle(sheenBrush, sheenRect);
                g.Clip = prev;
            }
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing && _animTimer != null)
        {
            _animTimer.Stop();
            _animTimer.Dispose();
        }
        base.Dispose(disposing);
    }
}
"@

	Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"
}

<#
    .SYNOPSIS
    Internal function New-SharedProgressBarHost.
#>

function New-SharedProgressBarHost
{
	[CmdletBinding()]
	param (
		[int]$Maximum = 100,
		[int]$Value = 0,
		[switch]$Indeterminate,
		[double]$Height = $Script:GuiLayout.ProgressBarHeight,
		[double]$MinWidth = $Script:GuiLayout.ProgressBarMinWidth
	)

	Ensure-SheenProgressBarType

	$windowsFormsHost = [System.Windows.Forms.Integration.WindowsFormsHost]::new()
	$windowsFormsHost.HorizontalAlignment = 'Stretch'
	$windowsFormsHost.VerticalAlignment = 'Center'
	$windowsFormsHost.MinWidth = $MinWidth
	$windowsFormsHost.Height = $Height

	$progressBar = [SheenProgressBar]::new()
	$progressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
	$progressBar.Minimum = 0
	$progressBar.Maximum = [Math]::Max(1, $Maximum)
	$progressBar.Value = [Math]::Min([Math]::Max(0, $Value), $progressBar.Maximum)
	$progressBar.IsIndeterminate = [bool]$Indeterminate
	Set-SheenProgressBarTheme -ProgressBar $progressBar
	$windowsFormsHost.Child = $progressBar

	return @{
		Host        = $windowsFormsHost
		ProgressBar = $progressBar
	}
}

<#
    .SYNOPSIS
    Internal function Set-SheenProgressBarTheme.
#>

function Set-SheenProgressBarTheme
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[hashtable]$Theme = $null
	)

	if (-not $ProgressBar)
	{
		return
	}

	if (-not $Theme)
	{
		$Theme = Get-GuiCurrentTheme
	}

	if (-not $Theme)
	{
		return
	}

	try
	{
		$progressColor = if ($Theme.ContainsKey('ProgressGreen') -and -not [string]::IsNullOrWhiteSpace([string]$Theme.ProgressGreen)) { [string]$Theme.ProgressGreen } else { [string]$Theme.AccentBlue }
		$progressTrack = if ($Theme.ContainsKey('ProgressGreenTrack') -and -not [string]::IsNullOrWhiteSpace([string]$Theme.ProgressGreenTrack)) { [string]$Theme.ProgressGreenTrack } else { [string]$Theme.CardBorder }
		$ProgressBar.BarColor = [System.Drawing.ColorTranslator]::FromHtml($progressColor)
		$ProgressBar.BackgroundColor = [System.Drawing.ColorTranslator]::FromHtml($progressTrack)
	}
	catch
	{
		$null = $_
	}
}

<#
    .SYNOPSIS
    Internal function Set-SharedProgressBarState.
#>

function Set-SharedProgressBarState
{
	[CmdletBinding()]
	param (
		[object]$ProgressBar,
		[object]$ProgressText,
		[int]$Completed = 0,
		[int]$Total = 0,
		[string]$CurrentAction = $null,
		[switch]$Indeterminate,
		[switch]$PassThruText
	)

	$displayText = $null
	if ($ProgressBar)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $true
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = 1
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = 0
			}
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			if ($ProgressBar.PSObject.Properties['IsIndeterminate'])
			{
				$ProgressBar.IsIndeterminate = $false
			}
			if ($ProgressBar.PSObject.Properties['Maximum'])
			{
				$ProgressBar.Maximum = $safeTotal
			}
			if ($ProgressBar.PSObject.Properties['Value'])
			{
				$ProgressBar.Value = $safeCompleted
			}
		}
	}

	if ($ProgressText)
	{
		if ($Indeterminate -or $Total -le 0)
		{
			$displayText = if ([string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				Get-UxExecutionPlaceholderText -Kind 'Working'
			}
			else
			{
				[string]$CurrentAction
			}
			$ProgressText.Text = $displayText
		}
		else
		{
			$safeTotal = [Math]::Max(1, $Total)
			$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
			$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
			$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
			$ProgressText.Text = $displayText
			if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
			{
				$ProgressText.Text += " - $CurrentAction"
			}
			$displayText = $ProgressText.Text
		}
	}
	elseif (-not $Indeterminate -and $Total -gt 0)
	{
		$safeTotal = [Math]::Max(1, $Total)
		$safeCompleted = [Math]::Min([Math]::Max(0, $Completed), $safeTotal)
		$pct = [Math]::Round(($safeCompleted / [double]$safeTotal) * 100)
		$displayText = '{0}/{1} ({2}%)' -f $safeCompleted, $safeTotal, $pct
		if (-not [string]::IsNullOrWhiteSpace([string]$CurrentAction))
		{
			$displayText += " - $CurrentAction"
		}
	}

	if ($PassThruText)
	{
		return $displayText
	}
}

<#
    .SYNOPSIS
    Internal function Initialize-AppsProgressSection.
#>

function Initialize-AppsProgressSection
{
	[CmdletBinding()]
	param ()

	if (-not $Script:AppsProgressContainer)
	{
		return
	}

	if (-not $Script:AppsProgressHost -or -not $Script:AppsProgressBar)
	{
		$sharedProgress = New-SharedProgressBarHost -Maximum 1 -Value 0
		$Script:AppsProgressHost = $sharedProgress.Host
		$Script:AppsProgressBar = $sharedProgress.ProgressBar
		$Script:AppsProgressContainer.Child = $Script:AppsProgressHost
	}

	$theme = Get-GuiCurrentTheme
	if ($theme)
	{
		$bc = New-SafeBrushConverter -Context 'Initialize-AppsProgressSection'
		$Script:AppsProgressContainer.Background = $bc.ConvertFromString($theme.CardBorder)
	}

	Set-SheenProgressBarTheme -ProgressBar $Script:AppsProgressBar

	if ($Script:AppsProgressBar)
	{
		$Script:AppsProgressBar.IsIndeterminate = $false
		$Script:AppsProgressBar.Maximum = 1
		$Script:AppsProgressBar.Value = 0
	}
	if ($Script:TxtAppsProgressText)
	{
		$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
	}
	if ($Script:TxtAppCacheStatus)
	{
		$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
	}
}

<#
    .SYNOPSIS
    Applies active/inactive chrome to the top-nav mode radio buttons so the
    segmented-control state is visually unambiguous.
#>

function Set-GuiNavButtonChrome
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		$Button,
		[Parameter(Mandatory = $true)]
		[bool]$IsActive
	)

	if (-not $Button) { return }

	$theme = $Script:CurrentTheme
	$bc = New-SafeBrushConverter -Context 'Set-GuiNavButtonChrome'

	if ($IsActive)
	{
		$bgColor     = if ($theme -and $theme.ContainsKey('AccentBlue'))         { [string]$theme.AccentBlue }         else { '#3B82F6' }
		$hoverColor  = if ($theme -and $theme.ContainsKey('AccentHover'))        { [string]$theme.AccentHover }        else { '#60A5FA' }
		$borderColor = if ($theme -and $theme.ContainsKey('ActiveTabIndicator')) { [string]$theme.ActiveTabIndicator } else { '#7CB7FF' }
		$fgColor     = '#FFFFFF'
		$thickness   = 2
		$fontWeight  = [System.Windows.FontWeights]::SemiBold
	}
	else
	{
		$bgColor     = 'Transparent'
		$hoverColor  = if ($theme -and $theme.ContainsKey('TabHoverBg'))      { [string]$theme.TabHoverBg }      else { '#3670B8' }
		$borderColor = if ($theme -and $theme.ContainsKey('BorderColor'))     { [string]$theme.BorderColor }     else { '#293044' }
		$fgColor     = if ($theme -and $theme.ContainsKey('TextSecondary'))   { [string]$theme.TextSecondary }   else { '#9CA3AF' }
		$thickness   = 1
		$fontWeight  = [System.Windows.FontWeights]::Normal
	}

	$bgBrush = $bc.ConvertFromString($bgColor)
	$hoverBrush = $bc.ConvertFromString($hoverColor)
	$borderBrush = $bc.ConvertFromString($borderColor)
	$fgBrush = $bc.ConvertFromString($fgColor)

	$Button.Template = $null
	$Button.Background = $bgBrush
	$Button.BorderBrush = $borderBrush
	$Button.BorderThickness = [System.Windows.Thickness]::new($thickness)
	$Button.Foreground = $fgBrush
	$Button.FontWeight = $fontWeight
	$Button.Cursor = [System.Windows.Input.Cursors]::Hand
	$Button.FocusVisualStyle = $null

	$tmpl = New-Object System.Windows.Controls.ControlTemplate($Button.GetType())
	$bd = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.Border])
	$bd.Name = 'Bd'
	$bd.SetValue([System.Windows.Controls.Border]::CornerRadiusProperty, [System.Windows.CornerRadius]::new(5))
	$bd.SetValue([System.Windows.Controls.Border]::PaddingProperty, [System.Windows.Thickness]::new(12, 5, 12, 5))
	$bd.SetValue([System.Windows.Controls.Border]::BackgroundProperty, $bgBrush)
	$bd.SetValue([System.Windows.Controls.Border]::BorderBrushProperty, $borderBrush)
	$bd.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, [System.Windows.Thickness]::new($thickness))
	$cp = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ContentPresenter])
	$cp.SetValue([System.Windows.Controls.ContentPresenter]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
	$cp.SetValue([System.Windows.Controls.ContentPresenter]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
	$bd.AppendChild($cp)
	$tmpl.VisualTree = $bd

	$hoverTrigger = New-Object System.Windows.Trigger
	$hoverTrigger.Property = [System.Windows.UIElement]::IsMouseOverProperty
	$hoverTrigger.Value = $true
	[void]($hoverTrigger.Setters.Add((New-WpfSetter -Property ([System.Windows.Controls.Border]::BackgroundProperty) -Value $hoverBrush -TargetName 'Bd')))
	[void]($tmpl.Triggers.Add($hoverTrigger))

	$Button.Template = $tmpl
}

function Update-GuiNavModeChrome
{
	[CmdletBinding()]
	param ()

	$appsActive = [bool]$Script:AppsModeActive
	$updatesActive = [bool]$Script:UpdatesModeActive
	if ($Script:NavModeTweaks) { Set-GuiNavButtonChrome -Button $Script:NavModeTweaks -IsActive (-not $appsActive -and -not $updatesActive) }
	if ($Script:NavModeApps) { Set-GuiNavButtonChrome -Button $Script:NavModeApps -IsActive $appsActive }
	if ($Script:NavModeUpdates) { Set-GuiNavButtonChrome -Button $Script:NavModeUpdates -IsActive $updatesActive }
}

<#
    .SYNOPSIS
    Internal function Set-GuiUpdatesMode.
#>

function Set-GuiUpdatesMode
{
	[CmdletBinding()]
	param (
		[bool]$Enable = $false
	)

	if ($Script:UpdatesModeActive -eq $Enable)
	{
		return
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Enable)
	{
		$selectedPrimaryTab = if ($Script:PrimaryTabs -and $Script:PrimaryTabs.SelectedItem -and $Script:PrimaryTabs.SelectedItem.Tag) { [string]$Script:PrimaryTabs.SelectedItem.Tag } else { $null }
		$Script:UpdatesReturnPrimaryTab = if (-not [string]::IsNullOrWhiteSpace($selectedPrimaryTab) -and $selectedPrimaryTab -ne $Script:SearchResultsTabTag) { $selectedPrimaryTab } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:LastStandardPrimaryTab)) { [string]$Script:LastStandardPrimaryTab } else { 'Initial Setup' }
		if ([bool]$Script:AppsModeActive)
		{
			Set-GuiAppsMode -Enable:$false
		}
	}

	$Script:UpdatesModeActive = $Enable
	if ($Enable) { $Script:AppsModeActive = $false }

	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = (-not $Enable -and -not [bool]$Script:AppsModeActive) }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = [bool]$Script:AppsModeActive }
	if ($Script:NavModeUpdates) { $Script:NavModeUpdates.IsChecked = $Enable }
	try { Update-GuiNavModeChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiUpdatesMode.UpdateGuiNavModeChrome' }

	if ($Script:ModeSubtitle)
	{
		$subtitleKey = if ($Enable) { 'Nav_WindowsUpdatesSubtitle' } else { 'Nav_OptimizeSubtitle' }
		$subtitleFallback = if ($Enable) { 'Manage Windows Update' } else { 'Configure system behavior' }
		$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $subtitleKey -Fallback $subtitleFallback)
		$Script:ModeSubtitle.HorizontalAlignment = if ($Enable) { [System.Windows.HorizontalAlignment]::Center } else { [System.Windows.HorizontalAlignment]::Left }
	}

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = $visible }
	if ($Script:AppsView) { $Script:AppsView.Visibility = $collapsed }
	if ($Script:PrimaryTabHost) { $Script:PrimaryTabHost.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:ExpertModeBanner)
	{
		$Script:ExpertModeBanner.Visibility = $collapsed
	}
	if ($Script:SafeModeGroup) { $Script:SafeModeGroup.Visibility = $visible }
	foreach ($control in @($Script:BtnFilterToggle, $Script:FilterOptionsPanel))
	{
		if ($control) { $control.Visibility = if ($Enable) { $collapsed } else { $visible } }
	}
	if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnRun) { $Script:BtnRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnApplyQueuedActions) { $Script:BtnApplyQueuedActions.Visibility = $collapsed }

	if ($Enable)
	{
		if (Get-Command -Name 'Build-TabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Build-TabContent -PrimaryTab 'Updates' -SkipIdlePrebuild
		}
	}
	else
	{
		$restoreTab = if (-not [string]::IsNullOrWhiteSpace([string]$Script:UpdatesReturnPrimaryTab)) { [string]$Script:UpdatesReturnPrimaryTab } else { 'Initial Setup' }
		if ($Script:PrimaryTabs)
		{
			foreach ($tab in $Script:PrimaryTabs.Items)
			{
				if (($tab -is [System.Windows.Controls.TabItem]) -and $tab.Tag -and ([string]$tab.Tag -eq $restoreTab))
				{
					$Script:PrimaryTabs.SelectedItem = $tab
					break
				}
			}
		}
		if (Get-Command -Name 'Build-TabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Build-TabContent -PrimaryTab $restoreTab -SkipIdlePrebuild
		}
	}

	if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		if ($Script:SyncUxActionButtonTextScript)
		{
			& $Script:SyncUxActionButtonTextScript
		}
		else
		{
			Sync-UxActionButtonText
		}
	}
}

<#
    .SYNOPSIS
    Internal function Set-GuiAppsMode.
#>

function Set-GuiAppsMode
{
	[CmdletBinding()]
	param (
		[bool]$Enable = $false
	)

	if ($Script:AppsModeActive -eq $Enable)
	{
		return
	}

	$Script:AppsModeActive = $Enable
	if ($Enable) { $Script:UpdatesModeActive = $false }
	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = -not $Enable }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = $Enable }
	if ($Script:NavModeUpdates) { $Script:NavModeUpdates.IsChecked = $false }
	try { Update-GuiNavModeChrome } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiAppsMode.UpdateGuiNavModeChrome' }
	if ($Script:ModeSubtitle)
	{
		$subtitleKey = if ($Enable) { 'Nav_SoftwareAndAppsSubtitle' } else { 'Nav_OptimizeSubtitle' }
		$subtitleFallback = if ($Enable) { 'Manage installed applications' } else { 'Configure system behavior' }
		$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $subtitleKey -Fallback $subtitleFallback)
		$Script:ModeSubtitle.HorizontalAlignment = if ($Enable) { [System.Windows.HorizontalAlignment]::Right } else { [System.Windows.HorizontalAlignment]::Left }
	}
	if ($Enable -and (-not $Script:AppsProgressBar -or -not $Script:AppsProgressHost))
	{
		Initialize-AppsProgressSection
	}
	if ($Enable -and $Script:AppsProgressBar -and -not $Script:AppsOperationInProgress -and -not $Script:AppsCacheRefreshInProgress)
	{
		$appsViewAlreadyRendered = [bool]($Script:AppsWrapPanel -and $Script:AppsWrapPanel.Children -and $Script:AppsWrapPanel.Children.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Script:AppsViewBuildSignature))
		if (-not $appsViewAlreadyRendered)
		{
			$Script:AppsProgressBar.IsIndeterminate = $false
			$Script:AppsProgressBar.Maximum = 1
			$Script:AppsProgressBar.Value = 0
			if ($Script:TxtAppsProgressText)
			{
				$Script:TxtAppsProgressText.Text = (Get-AppsCacheRefreshPromptText)
			}
			if ($Script:TxtAppCacheStatus)
			{
				$Script:TxtAppCacheStatus.Text = (Get-AppsCacheRefreshPromptText)
			}
			if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Update-AppsPackageManagerBanner } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiAppsMode.UpdateAppsPackageManagerBanner' }
			}
		}
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:AppsView) { $Script:AppsView.Visibility = if ($Enable) { $visible } else { $collapsed } }
	if ($Script:PrimaryTabHost) { $Script:PrimaryTabHost.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:ExpertModeBanner)
	{
		$Script:ExpertModeBanner.Visibility = if ($Enable)
		{
			$collapsed
		}
		elseif ((Get-Command -Name 'Test-IsExpertModeUX' -CommandType Function -ErrorAction SilentlyContinue) -and (Test-IsExpertModeUX))
		{
			$visible
		}
		else
		{
			$collapsed
		}
	}

	if ($Script:SafeModeGroup)
	{
		$Script:SafeModeGroup.Visibility = if ($Enable) { $collapsed } else { $visible }
	}

	if ($Script:ThemeToggleGroup)
	{
		$Script:ThemeToggleGroup.Visibility = $collapsed
	}

	# Tweaks-only menu items: hide while in Apps mode.
	$tweaksOnlyMenu = @(
		$Script:MenuActionsPreviewRun,
		$Script:MenuActionsRunTweaks,
		$Script:MenuActionsUndoLastRun,
		$Script:MenuActionsRestoreDefaults,
		$Script:MenuActionsCheckCompliance,
		$Script:MenuActionsScanSystem,
		$Script:MenuActionsAuditLog,
		$Script:MenuActionsSep1,
		$Script:MenuActionsSep2,
		$Script:MenuActionsSep3,
		$Script:MenuToolsApproveRemoteTargets,
		$Script:MenuToolsSaveRemoteApprovalPolicy,
		$Script:MenuToolsLoadRemoteApprovalPolicy,
		$Script:MenuToolsRemoteConsole,
		$Script:MenuToolsOperatorConsole,
		$Script:MenuToolsRemoteSessionStatus,
		$Script:MenuToolsInstallWsl
	)
	foreach ($item in $tweaksOnlyMenu)
	{
		if ($item) { $item.Visibility = if ($Enable) { $collapsed } else { $visible } }
	}

	# Apps-only menu items: hide while in Tweaks mode.
	$appsOnlyMenu = @(
		$Script:MenuToolsAppsManager,
		$Script:MenuToolsUpdateAllApps,
		$Script:MenuToolsSepApps
	)
	foreach ($item in $appsOnlyMenu)
	{
		if ($item) { $item.Visibility = if ($Enable) { $visible } else { $collapsed } }
	}

	if ($Script:TxtSearch)
	{
		$desiredSearchText = if ($Enable) { [string]$Script:AppsSearchText } else { [string]$Script:SearchText }
		if ($Script:TxtSearch.Text -ne $desiredSearchText)
		{
			$Script:SearchUiUpdating = $true
			try
			{
				$Script:TxtSearch.Text = $desiredSearchText
			}
			finally
			{
				$Script:SearchUiUpdating = $false
			}
		}
	}

	if ($Enable)
	{
		Initialize-AppPackageSourcePreferenceState
		Update-AppPackageSourcePreferenceControls
		if (Get-Command -Name 'Update-AppSourceFilterControls' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-AppSourceFilterControls
		}
	}

	foreach ($control in @($Script:BtnFilterToggle, $Script:FilterOptionsPanel))
	{
		if ($control)
		{
			$control.Visibility = if ($Enable) { $collapsed } else { $visible }
		}
	}

	if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnRun) { $Script:BtnRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnApplyQueuedActions) { $Script:BtnApplyQueuedActions.Visibility = if ($Enable) { $visible } else { $collapsed } }

	if ($Enable)
	{
		Build-AppsViewCards
	}
	else
	{
		if ($Script:CurrentPrimaryTab)
		{
			$Script:FilterGeneration++
			if ($Script:UpdateCurrentTabContentScript)
			{
				& $Script:UpdateCurrentTabContentScript
			}
			elseif (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
			{
				Update-CurrentTabContent
			}
		}
	}

	if (Get-Command -Name 'Sync-UxActionButtonText' -CommandType Function -ErrorAction SilentlyContinue)
	{
		if ($Script:SyncUxActionButtonTextScript)
		{
			& $Script:SyncUxActionButtonTextScript
		}
		else
		{
			Sync-UxActionButtonText
		}
	}
}

