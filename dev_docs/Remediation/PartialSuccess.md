# Partial-success rollout risk — remediation guide

This guide is linked from the preflight **Risk categories** surface when the rollout history from the last 7 days contains one or more rollouts that ended in `PartialSuccess` (some targets succeeded, others failed).

## Why Baseline flags this

A partial-success rollout leaves the fleet in a mixed state. If the same operation is re-run without reconciling the previous run, the operator can:

- Re-apply changes that already succeeded (usually a no-op, but noisy in audit).
- Skip the targets that failed last time, which hides the root cause.
- Overwrite a manual fix that another operator applied in the meantime.

## What to do before continuing

1. Open the **Rollout history** panel (Remote Console → History) and locate the RunId referenced in the warning.
2. Review the per-target failures from that run. Confirm each failed target has either been:
   - Remediated manually, or
   - Excluded from this run's target list.
3. If the partial-success outcome is expected (for example, package cleanup where some targets never had the package installed), annotate the RunId in the audit bundle so the next operator does not re-open the investigation.
4. If the new run is intended to retry the failed targets, ensure the operation is idempotent — check `Get-BaselineRemoteRolloutOutcomes -RunId <runId>` for the failure categories.

## Logs

- Orchestration history file: `Get-BaselineRemoteRolloutOutcomes` surfaces the JSON records.
- Support bundle → `RolloutOutcomes` section.
- Execution summary card: **Partial Success** (shown when any result is tagged `FailureCode = 'partial_success'`).
