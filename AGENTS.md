Avoid degradation handling, fallback, hacks, heuristics, local stabilizations, or post-processing bandages that are not faithful general algorithms. Avoid using degradation handling, fallback solutions, temporary patches, heuristic methods, local stabilization measures, and post-processing remedies that aren't faithful general algorithms.

## Naming conventions

Region module functions follow two naming patterns:
- **Verb-Noun** (e.g., `Disable-RemoteCommands`, `Update-Protocols`) — standard PowerShell convention for functions that perform a clear action.
- **Bare nouns** (e.g., `UWPApps`, `ScheduledTasks`, `ContextMenu`) — used for top-level "entry point" functions that serve as the public API for an entire category. These are referenced by name in the manifest JSON and invoked dynamically.

New functions should use Verb-Noun. Bare noun entry points are a legacy pattern retained for manifest compatibility.