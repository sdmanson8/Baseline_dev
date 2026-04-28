Set-StrictMode -Version Latest

BeforeAll {
    $loggingPath = Join-Path $PSScriptRoot '../../Module/Logging.psm1'
    $script:loggingModuleName = (Import-Module $loggingPath -Force -DisableNameChecking -PassThru).Name
}

AfterAll {
    if ($script:loggingModuleName) {
        Remove-Module -Name $script:loggingModuleName -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Set-/Get-BaselineDebugLogging' {
    AfterEach {
        Set-BaselineDebugLogging -Enabled $false
    }

    It 'defaults to off' {
        Get-BaselineDebugLogging | Should -BeFalse
    }

    It 'turns on and off' {
        Set-BaselineDebugLogging -Enabled $true
        Get-BaselineDebugLogging | Should -BeTrue
        Set-BaselineDebugLogging -Enabled $false
        Get-BaselineDebugLogging | Should -BeFalse
    }
}

Describe 'Write-BaselineDebug' {
    BeforeEach {
        $tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-debug-test-{0}.log" -f ([guid]::NewGuid().ToString('N')))
        $script:tempLog = $tempLog
        $global:LogFilePath = $tempLog
        Reset-LogStatistics
    }

    AfterEach {
        Set-BaselineDebugLogging -Enabled $false
        if ($script:tempLog -and (Test-Path -LiteralPath $script:tempLog)) {
            Remove-Item -LiteralPath $script:tempLog -Force -ErrorAction SilentlyContinue
        }
        $global:LogFilePath = $null
    }

    It 'is a no-op when Debug Mode is off' {
        Set-BaselineDebugLogging -Enabled $false
        Set-LogFile -Path $script:tempLog -Clear
        Write-BaselineDebug -Message 'should not appear'
        Start-Sleep -Milliseconds 100
        $content = if (Test-Path -LiteralPath $script:tempLog) { [System.IO.File]::ReadAllText($script:tempLog) } else { '' }
        $content | Should -Not -Match 'should not appear'
        (Get-LogStatistics).DebugCount | Should -Be 0
    }

    It 'writes a DEBUG entry when Debug Mode is on' {
        Set-BaselineDebugLogging -Enabled $true
        Set-LogFile -Path $script:tempLog -Clear
        Write-BaselineDebug -Message 'visible debug line'
        Start-Sleep -Milliseconds 200
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match 'DEBUG'
        $content | Should -Match 'visible debug line'
        (Get-LogStatistics).DebugCount | Should -Be 1
    }

    It 'records DebugMode=ON in the header when enabled' {
        Set-BaselineDebugLogging -Enabled $true
        Set-LogFile -Path $script:tempLog -Clear
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match 'DebugMode=ON'
    }

    It 'omits DebugMode tag from header when off' {
        Set-BaselineDebugLogging -Enabled $false
        Set-LogFile -Path $script:tempLog -Clear
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Not -Match 'DebugMode=ON'
    }
}

Describe 'Write-DebugSwallowedException' {
    BeforeEach {
        $tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-swallow-test-{0}.log" -f ([guid]::NewGuid().ToString('N')))
        $script:tempLog = $tempLog
        $global:LogFilePath = $tempLog
        Reset-LogStatistics
    }
    AfterEach {
        Set-BaselineDebugLogging -Enabled $false
        if ($script:tempLog -and (Test-Path -LiteralPath $script:tempLog)) {
            Remove-Item -LiteralPath $script:tempLog -Force -ErrorAction SilentlyContinue
        }
        $global:LogFilePath = $null
    }

    It 'is a no-op when Debug Mode is off' {
        Set-BaselineDebugLogging -Enabled $false
        Set-LogFile -Path $script:tempLog -Clear
        try { throw 'boom' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Test.Site' }
        $content = if (Test-Path -LiteralPath $script:tempLog) { [System.IO.File]::ReadAllText($script:tempLog) } else { '' }
        $content | Should -Not -Match 'boom'
        (Get-LogStatistics).DebugCount | Should -Be 0
    }

    It 'records [swallow] entry with source label when Debug Mode is on' {
        Set-BaselineDebugLogging -Enabled $true
        Set-LogFile -Path $script:tempLog -Clear
        try { throw 'specific failure 42' } catch { Write-DebugSwallowedException -ErrorRecord $_ -Source 'Test.SiteX' }
        Start-Sleep -Milliseconds 200
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match '\[swallow\] Test.SiteX'
        $content | Should -Match 'specific failure 42'
        (Get-LogStatistics).DebugCount | Should -Be 1
    }

    It 'never throws even on weird inputs' {
        Set-BaselineDebugLogging -Enabled $true
        Set-LogFile -Path $script:tempLog -Clear
        { Write-DebugSwallowedException -ErrorRecord 'plain string not an ErrorRecord' -Source 'Test.SiteY' } | Should -Not -Throw
    }
}

Describe 'Write-SessionSummaryToLog RunId prefix' {
    BeforeEach {
        $tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-session-summary-{0}.log" -f ([guid]::NewGuid().ToString('N')))
        $script:tempLog = $tempLog
        $global:LogFilePath = $tempLog
        Reset-LogStatistics
        Set-BaselineRunId -RunId 'aaaaaaaa-1111-2222-3333-444444444444'
        Initialize-SessionStatistics
        Update-SessionStatistics -Values @{
            SessionStartTime = (Get-Date).AddMinutes(-2)
            PresetName = 'Balanced'
            TweaksSelected = 3
            PreviewRunCount = 1
            ApplyRunCount = 1
            SucceededCount = 2
            FailedCount = 1
            SkippedCount = 0
            IsGUI = $true
            GameModeActive = $false
            GameModeProfile = $null
        }
    }

    AfterEach {
        if ($script:tempLog -and (Test-Path -LiteralPath $script:tempLog)) {
            Remove-Item -LiteralPath $script:tempLog -Force -ErrorAction SilentlyContinue
        }
        $global:LogFilePath = $null
    }

    It 'prefixes the session summary block with the active RunId' {
        Set-LogFile -Path $script:tempLog -Clear
        Write-SessionSummaryToLog
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match '\[RunId=aaaaaaaa\] --- Session Summary ---'
        $content | Should -Match '\[RunId=aaaaaaaa\] Preset: Balanced \| Tweaks selected: 3'
    }
}

Describe 'Set-/Get-BaselineRunId' {
    AfterEach {
        # No reset API; re-pin a fresh GUID so tests don't leak state.
        Set-BaselineRunId -RunId ([guid]::NewGuid().ToString())
    }

    It 'auto-generates a GUID on first read' {
        $first = Get-BaselineRunId
        $first | Should -Not -BeNullOrEmpty
        [guid]::Parse($first) | Should -Not -BeNullOrEmpty
    }

    It 'returns a stable value across reads' {
        $a = Get-BaselineRunId
        $b = Get-BaselineRunId
        $a | Should -Be $b
    }

    It 'short form is 8 lowercase hex chars' {
        Set-BaselineRunId -RunId 'ABCDEF12-3456-7890-ABCD-EF1234567890'
        Get-BaselineRunIdShort | Should -Be 'abcdef12'
    }

    It 'Set-BaselineRunId pins the value' {
        Set-BaselineRunId -RunId '11111111-2222-3333-4444-555555555555'
        Get-BaselineRunId | Should -Be '11111111-2222-3333-4444-555555555555'
    }
}

Describe 'Write-LogMessage RunId prefix' {
    BeforeEach {
        $tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-runid-{0}.log" -f ([guid]::NewGuid().ToString('N')))
        $script:tempLog = $tempLog
        $global:LogFilePath = $tempLog
        Reset-LogStatistics
        Set-BaselineRunId -RunId 'aaaaaaaa-1111-2222-3333-444444444444'
    }
    AfterEach {
        if ($script:tempLog -and (Test-Path -LiteralPath $script:tempLog)) {
            Remove-Item -LiteralPath $script:tempLog -Force -ErrorAction SilentlyContinue
        }
        $global:LogFilePath = $null
    }

    It 'stamps every log line with [RunId=xxxxxxxx]' {
        Set-LogFile -Path $script:tempLog -Clear
        Write-LogMessage -Message 'sample line' -Level 'INFO'
        Start-Sleep -Milliseconds 200
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match '\[RunId=aaaaaaaa\]'
        $content | Should -Match 'sample line'
    }

    It 'stamps the header line with the active RunId' {
        Set-LogFile -Path $script:tempLog -Clear
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match 'RunId=aaaaaaaa-1111-2222-3333-444444444444'
    }
}

Describe 'Add-/Get-/Reset-BaselineActionTrail' {
    AfterEach {
        Reset-BaselineActionTrail
    }

    It 'starts empty' {
        Reset-BaselineActionTrail
        @(Get-BaselineActionTrail).Count | Should -Be 0
    }

    It 'records entries in order with timestamp and detail' {
        Reset-BaselineActionTrail
        Add-BaselineActionTrail -Action 'OpenSettings'
        Add-BaselineActionTrail -Action 'Run' -Detail 'Tweaks=5'
        $trail = @(Get-BaselineActionTrail)
        $trail.Count | Should -Be 2
        $trail[0].Action | Should -Be 'OpenSettings'
        $trail[0].Detail | Should -BeNullOrEmpty
        $trail[1].Action | Should -Be 'Run'
        $trail[1].Detail | Should -Be 'Tweaks=5'
        $trail[0].Timestamp | Should -Not -BeNullOrEmpty
    }

    It 'never throws on weird inputs' {
        { Add-BaselineActionTrail -Action 'X' -Detail $null } | Should -Not -Throw
        { Add-BaselineActionTrail -Action ' ' -Detail '' } | Should -Not -Throw
    }

    It 'caps the buffer at the documented max' {
        Reset-BaselineActionTrail
        for ($i = 0; $i -lt 220; $i++) { Add-BaselineActionTrail -Action ('A{0}' -f $i) }
        @(Get-BaselineActionTrail).Count | Should -BeLessOrEqual 200
    }
}

Describe 'Write-LogMessage DEBUG level gating' {
    BeforeEach {
        $tempLog = Join-Path ([System.IO.Path]::GetTempPath()) ("baseline-debug-level-{0}.log" -f ([guid]::NewGuid().ToString('N')))
        $script:tempLog = $tempLog
        $global:LogFilePath = $tempLog
        Reset-LogStatistics
    }
    AfterEach {
        Set-BaselineDebugLogging -Enabled $false
        if ($script:tempLog -and (Test-Path -LiteralPath $script:tempLog)) {
            Remove-Item -LiteralPath $script:tempLog -Force -ErrorAction SilentlyContinue
        }
        $global:LogFilePath = $null
    }

    It 'drops Level=DEBUG when Debug Mode is off' {
        Set-BaselineDebugLogging -Enabled $false
        Set-LogFile -Path $script:tempLog -Clear
        Write-LogMessage -Message 'low signal' -Level 'DEBUG'
        Start-Sleep -Milliseconds 100
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Not -Match 'low signal'
    }

    It 'still emits INFO/WARNING/ERROR regardless of Debug Mode' {
        Set-BaselineDebugLogging -Enabled $false
        Set-LogFile -Path $script:tempLog -Clear
        Write-LogMessage -Message 'info-wins' -Level 'INFO'
        Write-LogMessage -Message 'warn-wins' -Level 'WARNING'
        Write-LogMessage -Message 'err-wins' -Level 'ERROR'
        Start-Sleep -Milliseconds 200
        $content = [System.IO.File]::ReadAllText($script:tempLog)
        $content | Should -Match 'info-wins'
        $content | Should -Match 'warn-wins'
        $content | Should -Match 'err-wins'
    }
}
