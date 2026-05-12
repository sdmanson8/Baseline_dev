# Sophia ScanRegistryPolicies Parity Review

## Decision

Baseline does not import arbitrary pre-existing registry policy values into LGPO state at runtime.

The current Baseline policy path is intentionally explicit: manifests select supported functions, `Set-Policy` writes reviewed policy entries, and the generated LGPO import flow materializes Baseline-owned policy text. Sophia's `ScanRegistryPolicies` behavior scans policy registry hives, maps values through ADMX definitions, and emits matching LGPO entries so Group Policy Editor reflects manually-created registry policy values. That is useful as a migration/import feature, but it is not required for Baseline's current apply contract.

## Review Notes

- Active tree search found Baseline's LGPO infrastructure (`LGPO.exe`, `Set-Policy`, and generated LGPO import support) but no existing `ScanRegistryPolicies` implementation.
- Stash review found no related implementation to recover.
- Upstream review at `E:\Github\Baseline` found only audit/reference records for Sophia `ScanRegistryPolicies`, not reusable Baseline code.
- Runtime manifests should not gain a `ScanRegistryPolicies` tweak until Baseline deliberately supports importing unknown pre-existing registry policies into its own policy state.

## Follow-Up Trigger

Re-open this parity item only if Baseline adds a first-class "import existing registry policies into LGPO" feature. That feature should use reviewed ADMX mappings, present a preview of every discovered policy, and require explicit user confirmation before importing anything.
