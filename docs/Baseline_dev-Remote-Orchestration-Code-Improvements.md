# Baseline_dev — Remote Orchestration Code Improvements

**Purpose:** Capture the next remote/orchestration code improvements after the current enterprise workflow implementation.

## Scope

These items are follow-up improvements, not signoff blockers. They document the areas where the current implementation is usable but still operationally thin.

## 1. Session reuse

### Current limitation
Remote transport works, cached session reuse exists, and the GUI already exposes remote console and approval-policy save/load flows, but the lifecycle is still thin.

### Code improvement
- Introduce a session manager abstraction
- Cache sessions by:
  - computer name
  - credential context
  - transport settings
- Add idle expiration and invalid-session eviction

### Result
Lower connection overhead, better responsiveness, cleaner repeated operations.

---

## 2. Retry strategy

### Current limitation
Failure classification exists, session setup retries, and payload execution now retries in bounded form, but the long-running operator recovery flows still deserve more work.

### Code improvement
- Classify failures:
  - transient network
  - authentication
  - policy / permission
  - execution / payload
- Retry only transient classes
- Use bounded retry count with jittered backoff
- Record retry attempts in per-target logs and orchestration history

### Result
Fewer false negatives and better operator confidence.

---

## 3. Per-target state machine

### Current limitation
Operators need clearer target progression and richer cancel recovery handling.

### Code improvement
Add explicit states:
- Pending
- Connecting
- Connected
- PreflightFailed
- PreviewReady
- Running
- Succeeded
- Failed
- Cancelled
- RequiresReview

### Result
Clear orchestration behavior and easier UI binding.

---

## 4. Partial-success reconciliation

### Current limitation
Multi-machine runs can succeed only on some targets, and the code now captures reconciliation data for those outcomes.

### Code improvement
- Add a reconciliation summary object
- Separate:
  - targets changed
  - targets unchanged
  - targets blocked
  - targets failed
- Add “retry failed only” and “export failed set” actions

### Result
Operators can recover faster from partial rollout problems.

---

## 5. Preflight contract

### Current limitation
Preflight checks exist, but need stronger structure.

### Code improvement
Return structured preflight results for:
- WinRM reachability
- firewall/access
- credentials
- policy conflict signals
- supported environment classification

### Result
Remote failures become actionable instead of opaque.

---

## 6. Historical orchestration data

### Current limitation
Cross-run aggregation exists in file form, and the code now captures detail artifacts too, but richer query and dashboard surfaces are still limited.

### Code improvement
- Persist orchestration summaries
- Track repeated failure classes by target
- Track approval decisions and rollout outcomes
- Add “last known remote health” per target
- Add searchable dashboard views over the history and detail bundle artifacts

### Result
Support and audit workflows become significantly stronger.

---

## 7. Kill switch and safe cancellation

### Current limitation
Live decisions, kill switch support, and resume-after-abort behavior are implemented, but the cancellation path still deserves hardening.

### Code improvement
- Propagate cancel intent through dispatch pipeline and worker queues
- Stop future dispatches without corrupting already-running target results
- Mark in-progress targets consistently after cancellation
- Preserve a resumable not-run set for the interrupted run

### Result
Safer remote operations and cleaner incident handling.

---

## 8. Support-bundle deep linking

### Current limitation
Supportability exists, but failed orchestration paths should be easier to investigate at a glance.

### Code improvement
- Add one-click support bundle generation from failed target rows
- Include:
  - target state
  - error class
  - recent orchestration history
  - bundle index and detail artifacts
  - signature / rollout context if lifecycle-related

### Result
Faster incident reproduction and less operator friction.
