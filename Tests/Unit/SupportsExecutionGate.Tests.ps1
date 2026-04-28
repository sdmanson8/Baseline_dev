Set-StrictMode -Version Latest

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../Module/GUIExecution.psm1'
    Import-Module $modulePath -Force

    $sharedPath = Join-Path $PSScriptRoot '../../Module/SharedHelpers.psm1'
    Import-Module $sharedPath -Force

    $script:ExecutionContent = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
}

# These four cases mirror the spec wording in todo.md (OS Support Matrix →
# AppsCategory SupportsExecution): execution is gated by SupportsExecution
# in addition to (and independently from) Availability/PlatformSupport.
Describe 'Resolve-GuiExecutionSupportsExecutionGate' {
    It 'returns Allow when the field is missing (default executable, back-compat)' {
        $entry = [pscustomobject]@{ Name = 'NoField'; Function = 'NoField' }
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $entry
        $r.Decision | Should -Be 'Allow'
        $r.Reason | Should -Be ''
    }

    It 'returns Allow when SupportsExecution is explicitly $true' {
        $entry = [pscustomobject]@{ Name = 'Yes'; Function = 'Yes'; SupportsExecution = $true }
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $entry
        $r.Decision | Should -Be 'Allow'
    }

    It 'returns Block when SupportsExecution is $false and ForceUnsupported is not set' {
        $entry = [pscustomobject]@{ Name = 'No'; Function = 'No'; SupportsExecution = $false }
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $entry
        $r.Decision | Should -Be 'Block'
        $r.Reason | Should -Match 'Execution not supported'
    }

    It 'returns Force when SupportsExecution is $false and ForceUnsupported is set' {
        $entry = [pscustomobject]@{ Name = 'No'; Function = 'No'; SupportsExecution = $false }
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $entry -ForceUnsupported
        $r.Decision | Should -Be 'Force'
        $r.Reason | Should -Match 'Execution not supported'
    }

    It 'accepts a hashtable-style entry (loader IDictionary path)' {
        $entry = @{ Name = 'H'; Function = 'H'; SupportsExecution = $false }
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $entry
        $r.Decision | Should -Be 'Block'
    }

    It 'returns Allow on a $null entry (defensive default)' {
        $r = Resolve-GuiExecutionSupportsExecutionGate -Entry $null
        $r.Decision | Should -Be 'Allow'
    }

    # The four spec cases (matrix of SupportsExecution x Availability):
    Context 'spec matrix: SupportsExecution and Availability are independent' {
        It 'SupportsExecution=true + Available=true => executes (Allow on both gates)' {
            $entry = [pscustomobject]@{
                Name = 'AvailExec'; Function = 'AvailExec'
                SupportsExecution = $true
                Availability = [pscustomobject]@{ Available = $true; Reason = '' }
            }
            (Resolve-GuiExecutionAvailabilityGate -Entry $entry).Decision    | Should -Be 'Allow'
            (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Allow'
        }

        It 'SupportsExecution=true + Available=false => skipped by availability gate' {
            $entry = [pscustomobject]@{
                Name = 'NotAvailExec'; Function = 'NotAvailExec'
                SupportsExecution = $true
                Availability = [pscustomobject]@{ Available = $false; Reason = 'Not available on Windows 10.' }
            }
            (Resolve-GuiExecutionAvailabilityGate -Entry $entry).Decision    | Should -Be 'Block'
            (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Allow'
        }

        It 'SupportsExecution=false + Available=true => skipped by execution gate' {
            $entry = [pscustomobject]@{
                Name = 'AvailNotExec'; Function = 'AvailNotExec'
                SupportsExecution = $false
                Availability = [pscustomobject]@{ Available = $true; Reason = '' }
            }
            (Resolve-GuiExecutionAvailabilityGate -Entry $entry).Decision    | Should -Be 'Allow'
            (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Block'
        }

        It 'SupportsExecution missing + Available=true => executes (default executable)' {
            $entry = [pscustomobject]@{
                Name = 'DefaultExec'; Function = 'DefaultExec'
                Availability = [pscustomobject]@{ Available = $true; Reason = '' }
            }
            (Resolve-GuiExecutionAvailabilityGate -Entry $entry).Decision    | Should -Be 'Allow'
            (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Allow'
        }
    }

    It 'ForceUnsupported overrides BOTH gates simultaneously' {
        $entry = [pscustomobject]@{
            Name = 'Both'; Function = 'Both'
            SupportsExecution = $false
            Availability = [pscustomobject]@{ Available = $false; Reason = 'Not available on Windows Server.' }
        }
        (Resolve-GuiExecutionAvailabilityGate -Entry $entry -ForceUnsupported).Decision    | Should -Be 'Force'
        (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry -ForceUnsupported).Decision | Should -Be 'Force'
    }
}

Describe 'Test-BaselineEntrySupportsExecution (shared helper) parity with the gate' {
    It 'agrees with the gate decision on present-true entries' {
        $entry = [pscustomobject]@{ SupportsExecution = $true }
        Test-BaselineEntrySupportsExecution -Entry $entry | Should -BeTrue
        (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Allow'
    }

    It 'agrees with the gate decision on present-false entries' {
        $entry = [pscustomobject]@{ SupportsExecution = $false }
        Test-BaselineEntrySupportsExecution -Entry $entry | Should -BeFalse
        (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Block'
    }

    It 'agrees with the gate decision on missing-field entries (both default to allow)' {
        $entry = [pscustomobject]@{ Name = 'Missing' }
        Test-BaselineEntrySupportsExecution -Entry $entry | Should -BeTrue
        (Resolve-GuiExecutionSupportsExecutionGate -Entry $entry).Decision | Should -Be 'Allow'
    }
}

Describe 'Worker execution gate (Start-GuiExecutionWorker source-pattern checks)' {
    It 'invokes the SupportsExecution gate after the availability gate' {
        $script:ExecutionContent | Should -Match 'Resolve-GuiExecutionSupportsExecutionGate -Entry \$tweak -ForceUnsupported:\$bgForceUnsupported'
    }

    It 'logs a localized execution-not-supported line when the gate blocks' {
        $script:ExecutionContent | Should -Match 'GuiLogExecutionSkippedNotExecutable'
        $script:ExecutionContent | Should -Match 'Skipped . execution not supported on this system: \{0\}'
    }

    It 'logs a warning when the gate forces a non-executable entry' {
        $script:ExecutionContent | Should -Match 'Forcing execution of non-executable entry: \{0\} . \{1\}'
    }

    It 'increments a separate NotExecutableCount counter so the run report can distinguish skip reasons' {
        $script:ExecutionContent | Should -Match "NotExecutableCount"
    }

    It 'exports Resolve-GuiExecutionSupportsExecutionGate from the GUIExecution module' {
        $script:ExecutionContent | Should -Match "'Resolve-GuiExecutionSupportsExecutionGate'"
    }
}
