# Baseline_dev — Code Improvement Priorities

**Purpose:** Convert the readiness assessment into concrete post-signoff engineering follow-up work.

## Priority 1 — Remote execution resilience

The current remote transport is implemented, and the code now includes session reuse, bounded retry, structured history, and interrupted-run resume. The remaining work is richer dashboards and longer-horizon operator workflows.

These are the highest-value follow-up improvements because they directly affect multi-machine reliability and operator trust.

### Recommended work
- Add a session cache keyed by target + credential scope
- Extend bounded retry across payload execution paths where idempotency is safe
- Add per-target terminal states: `Succeeded`, `Failed`, `Skipped`, `Retrying`, `Cancelled`
- Persist per-run and per-target summaries to a machine-readable history store

### Why this matters
Today the transport works, and the GUI already exposes remote console and approval-policy flows, but richer analytics and recovery workflows still need hardening. The assessment treats the remaining gaps as accepted limitations, not signoff blockers.

---

## Priority 2 — Multi-target execution safety

The orchestration surface exists, but multi-machine operations still carry risk around partial success and operator visibility.

### Recommended work
- Add a clear execution state model for every target
- Add a kill-switch / cancel path that stops future target dispatches cleanly
- Add partial-success reconciliation logic so the operator can see exactly which targets changed and which did not

### Why this matters
Enterprise rollout quality is defined by what happens when only some targets succeed. That is where support burden and trust problems usually appear first.

---

## Priority 3 — Historical aggregation and audit views

The code now persists structured orchestration history, reconciliation, and detail artifacts per run. The next improvement is richer query and dashboard surfaces over that history.

### Recommended work
- Expose normalized run summaries through a query surface
- Add a query layer for:
  - target history
  - rollout history
  - repeated failures by class
  - compliance drift over time
- Add exportable incident-focused history bundles and dashboard views
- Add bundle deep links from the query surface to the relevant artifact

### Why this matters
Current supportability is good, but historical fleet-level analysis is still weak.

---

## Priority 4 — Server validation beyond CI

Server support is still not fully validated outside CI.

### Recommended work
- Add a server-focused smoke/integration test lane
- Introduce environment capability probes that detect unsupported server behaviors before execution
- Separate desktop-only vs server-safe tweak/application surfaces in code, not just docs

### Why this matters
This is one of the few remaining stated platform limitations in the readiness assessment.

---

## Priority 5 — Remote preflight hardening

Preflight checks exist, but they can be pushed further.

### Recommended work
- Distinguish transport failure from policy failure from credential failure
- Add a structured preflight result contract
- Promote remediation guidance into machine-readable codes
- Add explicit detection for common Group Policy override patterns

### Why this matters
This reduces operator guesswork and makes remote failure handling more deterministic.

---

## Priority 6 — Operator-console maturity

The remote console exists, but the next code step is maturity, not feature count.

### Recommended work
- Add target grouping / filtering
- Add severity-based rollup states
- Add direct links from failed targets to logs, support bundle generation, and incident reproduction actions
- Add queue visibility for pending / in-progress / completed targets

### Why this matters
Without concise rollup views, multi-target orchestration gets noisy fast.

---

## Priority 7 — Deployment and lifecycle verification integration

The signing policy is strong. The code should reflect that strength more directly in the operator flow.

### Recommended work
- Fail closed on missing or invalid timestamp/signature verification
- Surface signer subject and verification result in release status UI and lifecycle logs
- Store verification metadata alongside rollout records
- Require explicit operator acknowledgement when verification state changes between download and execution

### Why this matters
The signing policy already defines the enterprise trust model. The code should enforce it consistently.

---

## Priority 8 — Clearer boundary between “implemented” and “validated”

Some surfaces are implemented, but not equally validated. That distinction should remain visible in diagnostics and support material.

### Recommended work
- Tag features internally by maturity:
  - Implemented
  - Tested
  - CI-validated
  - Production-validated
- Surface that status in diagnostics / support bundles
- Use feature maturity gates to control enterprise-only actions

### Why this matters
This helps prevent the codebase from overstating readiness as features accumulate.

---

## Suggested order of execution

1. Remote execution resilience
2. Multi-target execution safety
3. Historical aggregation
4. Server validation
5. Preflight hardening
6. Operator-console maturity
7. Lifecycle verification integration
8. Feature maturity tagging
