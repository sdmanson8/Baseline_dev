Set-StrictMode -Version Latest

BeforeAll {
    foreach ($assemblyName in @('WindowsBase', 'PresentationCore', 'PresentationFramework'))
    {
        try { Add-Type -AssemblyName $assemblyName -ErrorAction Stop } catch { $null = $_ }
    }

    $script:DialogHelpersPath = Join-Path $PSScriptRoot '../../Module/GUI/DialogHelpers.ps1'
    $script:ActionHandlersPath = Join-Path $PSScriptRoot '../../Module/GUI/ActionHandlers.ps1'
    $script:DialogHelpersContent = Get-Content -LiteralPath $script:DialogHelpersPath -Raw -Encoding UTF8
    $script:ActionHandlersContent = Get-Content -LiteralPath $script:ActionHandlersPath -Raw -Encoding UTF8

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:DialogHelpersPath, [ref]$null, [ref]$null)
    $helperFunctionNames = @(
        'Set-BaselineReadmeInlineTheme',
        'Set-BaselineReadmeBlockTheme',
        'Set-BaselineReadmeFlowDocumentTheme'
    )
    foreach ($functionName in $helperFunctionNames)
    {
        $helperFunction = $ast.Find({
                param($node)
                ($node -is [System.Management.Automation.Language.FunctionDefinitionAst]) -and
                $node.Name -eq $functionName
            }, $true)
        if ($helperFunction)
        {
            Invoke-Expression $helperFunction.Extent.Text
        }
    }
}

Describe 'Documentation viewer wiring' {
    It 'defines dedicated themed changelog and README viewers with installed-path resolvers' {
        $script:DialogHelpersContent | Should -Match 'function Resolve-BaselineChangelogPath'
        $script:DialogHelpersContent | Should -Match 'function Resolve-BaselineReadmePath'
        $script:DialogHelpersContent | Should -Match 'BASELINE_LAUNCHER_PATH'
        $script:DialogHelpersContent | Should -Match '\[System\.AppContext\]::BaseDirectory'
        $script:DialogHelpersContent | Should -Match 'function Show-ChangelogDialog'
        $script:DialogHelpersContent | Should -Match 'function Show-ReadmeDialog'
        $script:DialogHelpersContent | Should -Match 'TxtChangelogContent'
        $script:DialogHelpersContent | Should -Match 'TxtReadmeContent'
        $script:DialogHelpersContent | Should -Match 'ReadAllText'
    }

    It 'routes the Help menu changelog and documentation actions through themed dialogs instead of launching external apps' {
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-ChangelogDialog'"
        $script:ActionHandlersContent | Should -Match "Get-GuiRuntimeCommand -Name 'Show-ReadmeDialog'"
        $script:ActionHandlersContent | Should -Match '& \$showChangelogDialogCommand'
        $script:ActionHandlersContent | Should -Match '& \$showReadmeDialogCommand'
        $script:ActionHandlersContent | Should -Not -Match 'Start-Process -FilePath \$docsUrl'
    }

    It 'reapplies the README viewer theme through the shared popup theme registry' {
        $script:DialogHelpersContent | Should -Match 'Register-GuiPopupThemeWindow -Window \$dlg -ThemeCallback \$readmeThemeCallback'
        $script:DialogHelpersContent | Should -Match '\$readmeThemeCallback = \{'
        $script:DialogHelpersContent | Should -Match '& \$loadReadmeContent -ThemeOverride \$Theme'
        $script:DialogHelpersContent | Should -Match 'ReadmeHeaderBorder'
        $script:DialogHelpersContent | Should -Match 'ReadmeContentBorder'
        $script:DialogHelpersContent | Should -Match 'ReadmeFooterBorder'
    }

    It 'themes rendered README FlowDocuments after markdown conversion so code content stays readable' {
        $script:DialogHelpersContent | Should -Match 'function Set-BaselineReadmeInlineTheme'
        $script:DialogHelpersContent | Should -Match 'function Set-BaselineReadmeBlockTheme'
        $script:DialogHelpersContent | Should -Match 'function Set-BaselineReadmeFlowDocumentTheme'
        $script:DialogHelpersContent | Should -Match 'Markdig\.Wpf resolves its code styles during ToFlowDocument\(\)'
        $script:DialogHelpersContent | Should -Match '\$codeBackgroundBrush = \$BrushConverter\.ConvertFromString\(\$ActiveTheme\.HeaderBg\)'
        $script:DialogHelpersContent | Should -Match '\$Inline\.Background = if \(\$WithinCodeBlock\) \{ \[System\.Windows\.Media\.Brushes\]::Transparent \} else \{ \$CodeBackgroundBrush \}'
        $script:DialogHelpersContent | Should -Match '\$Block\.BorderThickness = \[System\.Windows\.Thickness\]::new\(1\)'
        $script:DialogHelpersContent | Should -Match 'Set-BaselineReadmeFlowDocumentTheme -Document \$Document -ActiveTheme \$activeTheme -BrushConverter \$bc -ReadmeFontSize \$readmeFontSize'

        $brushConverter = [System.Windows.Media.BrushConverter]::new()
        $theme = @{
            TextPrimary = '#EDEDED'
            HeaderBg = '#1F2937'
            BorderColor = '#475569'
        }

        $document = [System.Windows.Documents.FlowDocument]::new()

        $paragraph = [System.Windows.Documents.Paragraph]::new()
        $paragraph.Inlines.Add([System.Windows.Documents.Run]::new('Prefix ')) | Out-Null
        $inlineCode = [System.Windows.Documents.Span]::new()
        $inlineCode.Background = [System.Windows.Media.Brushes]::Khaki
        $inlineRun = [System.Windows.Documents.Run]::new('Get-Process')
        $inlineCode.Inlines.Add($inlineRun) | Out-Null
        $paragraph.Inlines.Add($inlineCode) | Out-Null

        $codeParagraph = [System.Windows.Documents.Paragraph]::new()
        $codeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
        $codeRun = [System.Windows.Documents.Run]::new('winget list')
        $codeParagraph.Inlines.Add($codeRun) | Out-Null

        $list = [System.Windows.Documents.List]::new()
        $listItem = [System.Windows.Documents.ListItem]::new()
        $listCodeParagraph = [System.Windows.Documents.Paragraph]::new()
        $listCodeParagraph.Background = [System.Windows.Media.Brushes]::LightGray
        $listCodeRun = [System.Windows.Documents.Run]::new('Nested code item')
        $listCodeParagraph.Inlines.Add($listCodeRun) | Out-Null
        $listItem.Blocks.Add($listCodeParagraph) | Out-Null
        $list.ListItems.Add($listItem) | Out-Null

        $document.Blocks.Add($paragraph) | Out-Null
        $document.Blocks.Add($codeParagraph) | Out-Null
        $document.Blocks.Add($list) | Out-Null

        { Set-BaselineReadmeFlowDocumentTheme -Document $document -ActiveTheme $theme -BrushConverter $brushConverter -ReadmeFontSize 15 } | Should -Not -Throw

        $expectedCodeBackground = $brushConverter.ConvertFromString($theme.HeaderBg).ToString()
        $expectedCodeForeground = $brushConverter.ConvertFromString($theme.TextPrimary).ToString()
        $expectedBorder = $brushConverter.ConvertFromString($theme.BorderColor).ToString()

        $document.FontFamily.Source | Should -Be 'Segoe UI'
        $document.FontSize | Should -Be 15
        $inlineCode.Background.ToString() | Should -Be $expectedCodeBackground
        $inlineRun.FontFamily.Source | Should -Match 'Consolas'
        $codeParagraph.Background.ToString() | Should -Be $expectedCodeBackground
        $codeParagraph.BorderBrush.ToString() | Should -Be $expectedBorder
        $codeParagraph.BorderThickness.Left | Should -Be 1
        $codeParagraph.Padding.Left | Should -Be 8
        $codeRun.Background.ToString() | Should -Be ([System.Windows.Media.Brushes]::Transparent.ToString())
        $codeRun.Foreground.ToString() | Should -Be $expectedCodeForeground
        $listCodeParagraph.Background.ToString() | Should -Be $expectedCodeBackground
        $listCodeRun.FontFamily.Source | Should -Match 'Consolas'
    }
}
