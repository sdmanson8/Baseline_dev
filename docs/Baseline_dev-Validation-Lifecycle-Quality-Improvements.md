# Baseline_dev — Validation, Lifecycle, and Quality Code Improvements

**Purpose:** Focus on post-signoff code improvements outside the remote execution core.

## 1. Server validation outside CI

### Current limitation
Server support is not fully validated outside CI.

### Recommended code work
- Add a dedicated server validation matrix
- Add feature guards for server-incompatible actions
- Emit server-specific warnings in preview and execution summaries

---

## 2. Validation evidence capture

### Current state
Testing and validation are present, but the enterprise assessment still distinguishes between implemented, CI-validated, and production-validated surfaces. Release Status currently shows build, signer, and artifact posture, but durable maturity tagging is still future work.

### Recommended code work
- Stamp test evidence into support bundles
- Record build/test provenance with release status
- Capture validation channel in diagnostics:
  - unit-tested
  - desktop-session CI validated
  - manually validated
  - server CI only

---

## 3. Lifecycle verification enforcement

### Current strength
The installer signing policy is strong, specific, and enforceable.

### Recommended code work
- Enforce timestamp presence in verification code
- Persist artifact hash + signer + timestamp to rollout records
- Block promotion/execution when verification is missing or ambiguous
- Add explicit failure UX for unverifiable artifacts

---

## 4. Audit and retention enforcement

### Current state
Audit retention and export flows exist.

### Recommended code work
- Add active warnings when retention is set below policy threshold
- Add immutable export mode for signoff bundles
- Add verification that retention policy tasks are actually executing

---

## 5. Risk-aware UI surfacing

### Current state
Enterprise controls exist, but some risk areas are still generic.

### Recommended code work
- Surface policy conflict categories directly in UI
- Add contextual warnings for:
  - managed endpoints
  - WinRM variability
  - partial-success rollout risk
- Link these warnings to remediation steps and logs

---

## 6. Feature maturity tagging

### Current need
The codebase would benefit from distinguishing implemented features from validated features in a durable way.

### Recommended code work
- Add internal maturity metadata to enterprise features
- Include maturity metadata in diagnostics, support bundles, and release status
- Use the maturity tags to drive hidden/preview/operator-only UI

---

## 7. Documentation-to-code consistency checks

### Current risk
Enterprise documentation can drift ahead of proven code behavior.

### Recommended code work
- Add validation scripts that compare documented enterprise surfaces against feature registration / test evidence
- Fail documentation signoff when required feature evidence is missing
- Add a release checklist verifier for enterprise claims

---

## Suggested implementation order

1. Lifecycle verification enforcement
2. Server validation
3. Validation evidence capture
4. Audit/retention enforcement
5. Risk-aware UI surfacing
6. Feature maturity tagging
7. Documentation-to-code consistency checks
