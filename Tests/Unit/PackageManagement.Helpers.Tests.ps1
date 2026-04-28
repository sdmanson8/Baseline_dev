Set-StrictMode -Version Latest

BeforeAll {
    $filePath = Join-Path $PSScriptRoot '../../Module/SharedHelpers/PackageManagement.Helpers.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$null)
    $functions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($fn in $functions) {
        Invoke-Expression $fn.Extent.Text
    }
}

Describe 'Assert-FileHash' {
    It 'returns the computed SHA-256 when the file matches the expected value' {
        $filePath = Join-Path $TestDrive 'sample.txt'
        Set-Content -LiteralPath $filePath -Value 'baseline' -Encoding ASCII
        $expectedHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToUpperInvariant()

        $result = Assert-FileHash -Path $filePath -ExpectedSha256 $expectedHash -Label 'Sample file'

        $result | Should -Be $expectedHash
    }

    It 'throws when the hash does not match' {
        $filePath = Join-Path $TestDrive 'sample.txt'
        Set-Content -LiteralPath $filePath -Value 'baseline' -Encoding ASCII

        { Assert-FileHash -Path $filePath -ExpectedSha256 ('0' * 64) -Label 'Sample file' } | Should -Throw '*SHA-256 verification*'
    }
}

Describe 'Resolve-PowerShellInstallerUri' {
    BeforeEach {
        Mock Set-DownloadSecurityProtocol {}
        Mock Get-PowerShellInstallerArchitecture { 'win-x64' }
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                assets = @(
                    [pscustomobject]@{ name = 'PowerShell-7.5.0-win-arm64.msi'; browser_download_url = 'https://example.test/arm64.msi' }
                    [pscustomobject]@{ name = 'PowerShell-7.5.0-win-x64.msi'; browser_download_url = 'https://example.test/x64.msi' }
                )
            }
        }
    }

    It 'selects the MSI that matches the resolved architecture' {
        $result = Resolve-PowerShellInstallerUri -ReleaseApiUri 'https://example.test/latest'

        $result | Should -Be 'https://example.test/x64.msi'
    }

    It 'throws when no matching MSI asset exists' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                assets = @(
                    [pscustomobject]@{ name = 'PowerShell-7.5.0-linux-x64.tar.gz'; browser_download_url = 'https://example.test/linux.tar.gz' }
                )
            }
        }

        { Resolve-PowerShellInstallerUri -ReleaseApiUri 'https://example.test/latest' } | Should -Throw '*Could not find a PowerShell MSI installer*'
    }
}

Describe 'Resolve-ChocolateyExecutable' {
    It 'returns the known Chocolatey install path when PATH resolution is stale' {
        $previousProgramData = $env:ProgramData
        $previousChocolateyInstall = $env:ChocolateyInstall
        try {
            $env:ProgramData = Join-Path $TestDrive 'ProgramData'
            $env:ChocolateyInstall = $null
            $expectedPath = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
            $null = New-Item -ItemType Directory -Path (Split-Path -Path $expectedPath -Parent) -Force
            Set-Content -LiteralPath $expectedPath -Value '' -Encoding ASCII

            Mock Update-ProcessPathFromRegistry {}
            Mock Get-Command { $null } -ParameterFilter {
                @($Name) -contains 'choco' -or @($Name) -contains 'choco.exe'
            }

            $result = Resolve-ChocolateyExecutable

            $result | Should -Be $expectedPath
        }
        finally {
            $env:ProgramData = $previousProgramData
            $env:ChocolateyInstall = $previousChocolateyInstall
        }
    }
}

Describe 'Get-WinGetBootstrapInstallerMetadata' {
    It 'returns the reviewed 5.3.6 winget-install release metadata' {
        $metadata = Get-WinGetBootstrapInstallerMetadata

        $metadata.Version | Should -Be '5.3.6'
        $metadata.Sha256 | Should -Be '6016097051EBD3385F4E315FE33B17CEDA6912B9E71CD0C60C1D0DF1823D3262'
        $metadata.Uri | Should -Be 'https://github.com/asheroto/winget-install/releases/download/5.3.6/winget-install.ps1'
        $metadata.Label | Should -Be 'winget-install.ps1 v5.3.6'
    }
}

Describe 'Get-WinGetBootstrapInstallerArguments' {
    It 'keeps the installer in charge of Server-specific method selection' {
        $arguments = @(Get-WinGetBootstrapInstallerArguments)

        $arguments | Should -Be @('-Force')
    }
}

Describe 'Invoke-WinGetBootstrap' {
    BeforeEach {
        $script:wingetBootstrapInfoMessages = [System.Collections.Generic.List[string]]::new()
        $script:wingetBootstrapWarningMessages = [System.Collections.Generic.List[string]]::new()
        $script:wingetBootstrapErrorMessages = [System.Collections.Generic.List[string]]::new()
        $script:wingetVersionCallCount = 0
        $script:capturedWinGetInstallerArgumentList = $null
        $script:previousTemp = $env:TEMP
        $env:TEMP = $TestDrive

        function Get-BaselineBilingualString {
            param(
                [string]$Key,
                [string]$Fallback,
                [object[]]$FormatArgs = @()
            )

            if ($FormatArgs.Count -gt 0) {
                return ($Fallback -f $FormatArgs)
            }

            return $Fallback
        }

        function LogInfo {
            param([string]$Message)
            [void]$script:wingetBootstrapInfoMessages.Add($Message)
        }

        function LogWarning {
            param([string]$Message)
            [void]$script:wingetBootstrapWarningMessages.Add($Message)
        }

        function LogError {
            param([string]$Message)
            [void]$script:wingetBootstrapErrorMessages.Add($Message)
        }

        function Repair-WinGetPackageManager { }
    }

    AfterEach {
        $env:TEMP = $script:previousTemp
        Remove-Item Function:\Get-BaselineBilingualString -ErrorAction SilentlyContinue
        Remove-Item Function:\LogInfo -ErrorAction SilentlyContinue
        Remove-Item Function:\LogWarning -ErrorAction SilentlyContinue
        Remove-Item Function:\LogError -ErrorAction SilentlyContinue
        Remove-Item Function:\Repair-WinGetPackageManager -ErrorAction SilentlyContinue
    }

    It 'does not accept a zero exit code as success when stderr reported errors and winget is still unavailable' {
        Mock Invoke-DownloadFile {
            param($Uri, $OutFile)
            Set-Content -LiteralPath $OutFile -Value 'installer' -Encoding ASCII
        }
        Mock Assert-FileHash { 'OK' }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Mock Get-PackageManagerBootstrapLogLines {
            param($Path)
            if ([string]$Path -like '*stderr*') {
                return @('Add-AppxPackage : Deployment failed with HRESULT: 0x80073CF1')
            }

            return @('winget-install completed')
        }
        Mock Get-WinGetVersion {
            $script:wingetVersionCallCount++
            return $null
        }
        Mock Start-Sleep {}
        Mock Set-PSRepository { throw 'repair path hit' }
        Mock Install-PackageProvider {}
        Mock Install-Module {}
        Mock Import-Module {}
        Mock Repair-WinGetPackageManager {}
        Mock Reset-WinGetAvailabilityState {}

        $result = Invoke-WinGetBootstrap

        $result.Success | Should -BeFalse
        ($script:wingetBootstrapWarningMessages -join "`n") | Should -Match 'reported errors despite a zero exit code'
        ($script:wingetBootstrapErrorMessages -join "`n") | Should -Match 'winget\.exe is still unavailable\. First error: Add-AppxPackage'
    }

    It 'treats a clean installer with no stderr as success even if winget needs a new session' {
        Mock Invoke-DownloadFile {
            param($Uri, $OutFile)
            Set-Content -LiteralPath $OutFile -Value 'installer' -Encoding ASCII
        }
        Mock Assert-FileHash { 'OK' }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Mock Get-PackageManagerBootstrapLogLines {
            param($Path)
            if ([string]$Path -like '*stderr*') {
                return @()
            }

            return @('winget-install completed')
        }
        Mock Get-WinGetVersion {
            $script:wingetVersionCallCount++
            return $null
        }
        Mock Start-Sleep {}
        Mock Reset-WinGetAvailabilityState {}

        $result = Invoke-WinGetBootstrap

        $result.Success | Should -BeTrue
        $result.Installed | Should -BeTrue
        $result.Available | Should -BeFalse
        ($script:wingetBootstrapWarningMessages -join "`n") | Should -Match 'installation completed, but winget\.exe is not available in the current session yet'
    }

    It 'passes only the generic installer switch so Server 2019 and 2022 stay on the repo-defined paths' {
        Mock Invoke-DownloadFile {
            param($Uri, $OutFile)
            Set-Content -LiteralPath $OutFile -Value 'installer' -Encoding ASCII
        }
        Mock Assert-FileHash { 'OK' }
        Mock Start-Process {
            param(
                [string]$FilePath,
                [object[]]$ArgumentList
            )

            $script:capturedWinGetInstallerArgumentList = @($ArgumentList)
            [pscustomobject]@{ ExitCode = 0 }
        }
        Mock Get-PackageManagerBootstrapLogLines { @() }
        Mock Get-WinGetVersion {
            $script:wingetVersionCallCount++
            if ($script:wingetVersionCallCount -eq 1) {
                return $null
            }

            return '1.0.0'
        }
        Mock Start-Sleep {}
        Mock Reset-WinGetAvailabilityState {}

        $null = Invoke-WinGetBootstrap

        ($script:capturedWinGetInstallerArgumentList -join ' ') | Should -Match '-Force'
        ($script:capturedWinGetInstallerArgumentList -join ' ') | Should -Not -Match 'AlternateInstallMethod'
    }
}
