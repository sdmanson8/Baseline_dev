
<#
    .SYNOPSIS
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
#>

function New-GuiExecutionProgressBarTemplate
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
	param ()

	$templateXaml = @'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                 TargetType="{x:Type ProgressBar}">
	<Grid ClipToBounds="True" SnapsToDevicePixels="True">
		<Border x:Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="3" Opacity="0.82"/>
		<Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="3" Opacity="0.92">
			<Border.Effect>
				<DropShadowEffect Color="{DynamicResource Color.Progress}" BlurRadius="10" ShadowDepth="0" Opacity="0.35"/>
			</Border.Effect>
			<Border.Triggers>
				<EventTrigger RoutedEvent="FrameworkElement.Loaded">
					<BeginStoryboard>
						<Storyboard RepeatBehavior="Forever" AutoReverse="True">
							<DoubleAnimation Storyboard.TargetProperty="Opacity" From="0.82" To="1" Duration="0:0:0.85"/>
						</Storyboard>
					</BeginStoryboard>
				</EventTrigger>
			</Border.Triggers>
		</Border>
		<Border x:Name="PART_BusyIndicator" Width="180" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="3" Opacity="0">
			<Border.RenderTransform>
				<TranslateTransform x:Name="BusyIndicatorTransform" X="-180"/>
			</Border.RenderTransform>
			<Border.Effect>
				<DropShadowEffect Color="{DynamicResource Color.Progress}" BlurRadius="12" ShadowDepth="0" Opacity="0.42"/>
			</Border.Effect>
		</Border>
	</Grid>
	<ControlTemplate.Triggers>
		<Trigger Property="IsIndeterminate" Value="True">
			<Setter TargetName="PART_Indicator" Property="Opacity" Value="0"/>
			<Setter TargetName="PART_BusyIndicator" Property="Opacity" Value="0.96"/>
			<Trigger.EnterActions>
				<BeginStoryboard x:Name="BusyIndicatorStoryboard">
					<Storyboard RepeatBehavior="Forever">
						<DoubleAnimation Storyboard.TargetName="BusyIndicatorTransform" Storyboard.TargetProperty="X" From="-180" To="900" Duration="0:0:1.05"/>
					</Storyboard>
				</BeginStoryboard>
			</Trigger.EnterActions>
			<Trigger.ExitActions>
				<StopStoryboard BeginStoryboardName="BusyIndicatorStoryboard"/>
			</Trigger.ExitActions>
		</Trigger>
	</ControlTemplate.Triggers>
</ControlTemplate>
'@
	return [System.Windows.Markup.XamlReader]::Parse($templateXaml)
}

<#
    .SYNOPSIS
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

	$progressBar = New-Object System.Windows.Controls.ProgressBar
	$progressBar.Minimum = 0
	$progressBar.Maximum = [Math]::Max(1, $Maximum)
	$progressBar.Value = [Math]::Min([Math]::Max(0, $Value), $progressBar.Maximum)
	$progressBar.IsIndeterminate = [bool]$Indeterminate
	$progressBar.Height = $Height
	$progressBar.MinHeight = $Height
	$progressBar.MinWidth = $MinWidth
	$progressBar.HorizontalAlignment = 'Stretch'
	$progressBar.VerticalAlignment = 'Center'
	$progressBar.BorderThickness = [System.Windows.Thickness]::new(0)
	$progressBar.Template = New-GuiExecutionProgressBarTemplate
	Set-SheenProgressBarTheme -ProgressBar $progressBar

	return @{
		Host        = $progressBar
		ProgressBar = $progressBar
	}
}

<#
    .SYNOPSIS
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
		if ($ProgressBar -is [System.Windows.Controls.ProgressBar])
		{
			$ProgressBar.Foreground = ConvertTo-GuiBrush -Color $progressColor -Context 'SharedProgress.ProgressBar.Foreground'
			$ProgressBar.Background = ConvertTo-GuiBrush -Color $progressTrack -Context 'SharedProgress.ProgressBar.Background'
			return
		}
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
	$deploymentMediaActive = [bool]$Script:DeploymentMediaModeActive
	if ($Script:NavModeTweaks) { Set-GuiNavButtonChrome -Button $Script:NavModeTweaks -IsActive (-not $appsActive -and -not $updatesActive -and -not $deploymentMediaActive) }
	if ($Script:NavModeApps) { Set-GuiNavButtonChrome -Button $Script:NavModeApps -IsActive $appsActive }
	if ($Script:NavModeUpdates) { Set-GuiNavButtonChrome -Button $Script:NavModeUpdates -IsActive $updatesActive }
	if ($Script:NavModeDeploymentMedia) { Set-GuiNavButtonChrome -Button $Script:NavModeDeploymentMedia -IsActive $deploymentMediaActive }
}

<#
    .SYNOPSIS
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
		if ([bool]$Script:DeploymentMediaModeActive -and (Get-Command -Name 'Set-GuiDeploymentMediaMode' -CommandType Function -ErrorAction SilentlyContinue))
		{
			Set-GuiDeploymentMediaMode -Enable:$false
		}
	}

	$Script:UpdatesModeActive = $Enable
	if ($Enable)
	{
		$Script:AppsModeActive = $false
		$Script:DeploymentMediaModeActive = $false
	}

	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = (-not $Enable -and -not [bool]$Script:AppsModeActive -and -not [bool]$Script:DeploymentMediaModeActive) }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = [bool]$Script:AppsModeActive }
	if ($Script:NavModeUpdates) { $Script:NavModeUpdates.IsChecked = $Enable }
	if ($Script:NavModeDeploymentMedia) { $Script:NavModeDeploymentMedia.IsChecked = [bool]$Script:DeploymentMediaModeActive }
	try { Update-GuiNavModeChrome } catch { Write-SwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiUpdatesMode.UpdateGuiNavModeChrome' }

	if ($Script:ModeSubtitle)
	{
		$subtitleKey = if ($Enable) { 'Nav_WindowsUpdatesSubtitle' } else { 'Nav_OptimizeSubtitle' }
		$subtitleFallback = if ($Enable) { 'Manage Windows Update' } else { 'Configure system behavior' }
		$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $subtitleKey -Fallback $subtitleFallback)
		$Script:ModeSubtitle.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
	}

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = $visible }
	if ($Script:AppsView) { $Script:AppsView.Visibility = $collapsed }
	if ($Script:DeploymentMediaView) { $Script:DeploymentMediaView.Visibility = $collapsed }
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
	elseif (-not [bool]$Script:DeploymentMediaModeActive)
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
#>

function Set-GuiDeploymentMediaMode
{
	[CmdletBinding()]
	param (
		[bool]$Enable = $false
	)

	if ($Script:DeploymentMediaModeActive -eq $Enable)
	{
		return
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Enable)
	{
		$selectedPrimaryTab = if ($Script:PrimaryTabs -and $Script:PrimaryTabs.SelectedItem -and $Script:PrimaryTabs.SelectedItem.Tag) { [string]$Script:PrimaryTabs.SelectedItem.Tag } else { $null }
		$Script:DeploymentMediaReturnPrimaryTab = if (-not [string]::IsNullOrWhiteSpace($selectedPrimaryTab) -and $selectedPrimaryTab -ne $Script:SearchResultsTabTag) { $selectedPrimaryTab } elseif (-not [string]::IsNullOrWhiteSpace([string]$Script:LastStandardPrimaryTab)) { [string]$Script:LastStandardPrimaryTab } else { 'Initial Setup' }
		$Script:DeploymentMediaModeActive = $true
		if ([bool]$Script:AppsModeActive)
		{
			Set-GuiAppsMode -Enable:$false
		}
		if ([bool]$Script:UpdatesModeActive)
		{
			Set-GuiUpdatesMode -Enable:$false
		}
	}

	$Script:DeploymentMediaModeActive = $Enable
	if ($Enable)
	{
		$Script:AppsModeActive = $false
		$Script:UpdatesModeActive = $false
	}

	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = (-not $Enable -and -not [bool]$Script:AppsModeActive -and -not [bool]$Script:UpdatesModeActive) }
	if ($Script:NavModeUpdates) { $Script:NavModeUpdates.IsChecked = [bool]$Script:UpdatesModeActive }
	if ($Script:NavModeDeploymentMedia) { $Script:NavModeDeploymentMedia.IsChecked = $Enable }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = [bool]$Script:AppsModeActive }
	try { Update-GuiNavModeChrome } catch { Write-SwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiDeploymentMediaMode.UpdateGuiNavModeChrome' }

	if ($Script:ModeSubtitle)
	{
		$subtitleKey = if ($Enable) { 'Nav_DeploymentMediaSubtitle' } else { 'Nav_OptimizeSubtitle' }
		$subtitleFallback = if ($Enable) { 'Build Windows setup media' } else { 'Configure system behavior' }
		$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $subtitleKey -Fallback $subtitleFallback)
		$Script:ModeSubtitle.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
	}

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:AppsView) { $Script:AppsView.Visibility = $collapsed }
	if ($Script:DeploymentMediaView) { $Script:DeploymentMediaView.Visibility = if ($Enable) { $visible } else { $collapsed } }
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

	if ($Script:SafeModeGroup) { $Script:SafeModeGroup.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:ThemeToggleGroup) { $Script:ThemeToggleGroup.Visibility = $collapsed }

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
		$Script:MenuToolsRemoteSessionStatus
	)
	foreach ($item in $tweaksOnlyMenu)
	{
		if ($item) { $item.Visibility = if ($Enable) { $collapsed } else { $visible } }
	}

	$appsOnlyMenu = @(
		$Script:MenuToolsAppsManager,
		$Script:MenuToolsUpdateAllApps,
		$Script:MenuToolsSepApps
	)
	foreach ($item in $appsOnlyMenu)
	{
		if ($item) { $item.Visibility = $collapsed }
	}

	foreach ($control in @($Script:BtnFilterToggle, $Script:FilterOptionsPanel))
	{
		if ($control) { $control.Visibility = if ($Enable) { $collapsed } else { $visible } }
	}

	foreach ($control in @($Script:TxtSearch, $Script:TxtSearchPlaceholder, $Script:BtnClearSearch))
	{
		if ($control) { $control.Visibility = if ($Enable) { $collapsed } else { $visible } }
	}
	if (-not $Enable -and (Get-Command -Name 'Sync-GuiSearchInputChrome' -CommandType Function -ErrorAction SilentlyContinue))
	{
		Sync-GuiSearchInputChrome
	}

	if ($Script:BtnPreviewRun) { $Script:BtnPreviewRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnDefaults) { $Script:BtnDefaults.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnRun) { $Script:BtnRun.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:BtnApplyQueuedActions) { $Script:BtnApplyQueuedActions.Visibility = $collapsed }

	if ($Enable)
	{
		if (Get-Command -Name 'Initialize-GuiDeploymentMediaBuilderView' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Initialize-GuiDeploymentMediaBuilderView
		}
		if (Get-Command -Name 'Sync-GuiDeploymentMediaBuilderViewText' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Sync-GuiDeploymentMediaBuilderViewText
		}
	}
	else
	{
		$restoreTab = if (-not [string]::IsNullOrWhiteSpace([string]$Script:DeploymentMediaReturnPrimaryTab)) { [string]$Script:DeploymentMediaReturnPrimaryTab } else { 'Initial Setup' }
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

	if ($Enable -and [bool]$Script:DeploymentMediaModeActive -and (Get-Command -Name 'Set-GuiDeploymentMediaMode' -CommandType Function -ErrorAction SilentlyContinue))
	{
		Set-GuiDeploymentMediaMode -Enable:$false
	}

	$Script:AppsModeActive = $Enable
	if ($Enable)
	{
		$Script:UpdatesModeActive = $false
		$Script:DeploymentMediaModeActive = $false
	}
	if ($Script:NavModeTweaks) { $Script:NavModeTweaks.IsChecked = (-not $Enable -and -not [bool]$Script:UpdatesModeActive -and -not [bool]$Script:DeploymentMediaModeActive) }
	if ($Script:NavModeApps) { $Script:NavModeApps.IsChecked = $Enable }
	if ($Script:NavModeUpdates) { $Script:NavModeUpdates.IsChecked = $false }
	if ($Script:NavModeDeploymentMedia) { $Script:NavModeDeploymentMedia.IsChecked = [bool]$Script:DeploymentMediaModeActive }
	try { Update-GuiNavModeChrome } catch { Write-SwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiAppsMode.UpdateGuiNavModeChrome' }
	if ($Script:ModeSubtitle)
	{
		$subtitleKey = if ($Enable) { 'Nav_SoftwareAndAppsSubtitle' } else { 'Nav_OptimizeSubtitle' }
		$subtitleFallback = if ($Enable) { 'Manage installed applications' } else { 'Configure system behavior' }
		$Script:ModeSubtitle.Text = (Get-UxLocalizedString -Key $subtitleKey -Fallback $subtitleFallback)
		$Script:ModeSubtitle.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
	}
	if ($Enable -and -not $Script:AppsOperationInProgress -and -not $Script:AppsCacheRefreshInProgress)
	{
		$appsViewAlreadyRendered = [bool]($Script:AppsWrapPanel -and $Script:AppsWrapPanel.Children -and $Script:AppsWrapPanel.Children.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Script:AppsViewBuildSignature))
		if (-not $appsViewAlreadyRendered)
		{
			if (Get-Command -Name 'Update-AppsPackageManagerBanner' -CommandType Function -ErrorAction SilentlyContinue)
			{
				try { Update-AppsPackageManagerBanner } catch { Write-SwallowedException -ErrorRecord $_ -Source 'AppsModule.Set-GuiAppsMode.UpdateAppsPackageManagerBanner' }
			}
		}
	}

	$collapsed = [System.Windows.Visibility]::Collapsed
	$visible = [System.Windows.Visibility]::Visible

	if ($Script:TweaksView) { $Script:TweaksView.Visibility = if ($Enable) { $collapsed } else { $visible } }
	if ($Script:AppsView) { $Script:AppsView.Visibility = if ($Enable) { $visible } else { $collapsed } }
	if ($Script:DeploymentMediaView) { $Script:DeploymentMediaView.Visibility = $collapsed }
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
		$Script:MenuToolsRemoteSessionStatus
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
		if (Get-Command -Name 'Sync-GuiSearchInputChrome' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Sync-GuiSearchInputChrome
		}
	}

	if ($Enable)
	{
		if (Get-Command -Name 'Resolve-AppsCatalogCategory' -CommandType Function -ErrorAction SilentlyContinue)
		{
			$Script:AppsCategoryFilter = Resolve-AppsCatalogCategory -Category $Script:AppsCategoryFilter
		}
		elseif ([string]::IsNullOrWhiteSpace([string]$Script:AppsCategoryFilter) -or [string]$Script:AppsCategoryFilter -eq 'All')
		{
			$Script:AppsCategoryFilter = 'Browsers'
		}
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
	elseif (-not [bool]$Script:UpdatesModeActive -and -not [bool]$Script:DeploymentMediaModeActive)
	{
		if (Get-Command -Name 'Update-CurrentTabContent' -CommandType Function -ErrorAction SilentlyContinue)
		{
			Update-CurrentTabContent -SkipIdlePrebuild
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
