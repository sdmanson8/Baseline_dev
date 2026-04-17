Avoid degradation handling, fallback, hacks, heuristics, local stabilizations, or post-processing bandages that are not faithful general algorithms. Avoid using degradation handling, fallback solutions, temporary patches, heuristic methods, local stabilization measures, and post-processing remedies that aren't faithful general algorithms.

## Tooling exception

`Tools/Add-MissingMetadata.ps1` is the explicit exception to the heuristics ban.

It is a maintainer-side metadata backfill tool, not runtime product logic. Its use stays constrained:

- conservative allowlists and reviewed maps only
- fill missing metadata only; do not broadly overwrite explicit manifest values
- deterministic and idempotent on unchanged input
- human-reviewed and audited before commit

## Naming conventions

Region entry-point functions — those referenced by name in the `Module/Data/*.json` manifests and invoked dynamically by the runner — must use **bare nouns** (e.g., `UWPApps`, `ScheduledTasks`, `ContextMenu`, `ActivityHistory`, `AdvertisingID`, `IPv6`, `DnsProvider`).

Toggle behaviour is expressed via the function's `-Enable`/`-Disable` (or equivalent) parameters, not the function name.

Internal helpers that are not manifest-referenced (private utilities, GUI builders, nested local functions) follow standard PowerShell **Verb-Noun** convention.
