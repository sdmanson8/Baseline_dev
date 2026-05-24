# Managed endpoint policy — remediation guide

This guide is linked from the Baseline preflight **Risk categories** surface when the operator's endpoint appears to be managed (domain-joined or has active policy hives under `HKLM\SOFTWARE\Policies` / `HKCU\SOFTWARE\Policies`).

## Why Baseline flags this

Managed endpoints frequently enforce settings that:

- Silently revert tweaks after they are applied.
- Block specific registry writes or service state changes mid-run.
- Re-apply at the next group policy refresh and cause the target to drift back to its previous state.

Baseline does not block the run — it warns so the operator can decide whether to continue.

## What to do before continuing

1. Confirm the target is in the expected OU and policy scope. If a domain controller is reachable, capture `gpresult /h policy.html` (or equivalent) and attach it to the support bundle.
2. Export the active policy hives listed in the preflight detail so the enforced values are documented alongside the run.
3. If any selected tweak overlaps an enforced policy, scope it out of the run or stage it in a narrower maintenance window with the appropriate operator sign-off.
4. If a policy prevented the run in a previous attempt, generate an incident reproduction pack from the support bundle (`Create Support Bundle → Incident Pack`) before re-running.

## Where to look in the logs

- **Support bundle**: `PolicyConflictSignals` detail under the preflight section lists the hives detected.
- **Audit trail**: entries with `RecordKind = 'PolicyConflict'` capture the operator's decision to continue.

## Related surfaces

- Preflight dialog → Risk categories
- Preview dialog → "Risk-aware checks flagged before this run"
- Remote Console → Preflight panel
