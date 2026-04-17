# Runtime Cache

Baseline's embedded launcher hydrates its bundled PowerShell payload into a per-user runtime
cache under:

`%LOCALAPPDATA%\Baseline\RC\<version>\4\<buildId>\`

The `4` segment is the current runtime-cache schema version from `Launcher/Program.cs`.

## What It Stores

The cache contains the embedded runtime payload extracted from `Baseline.exe`, including:

- `Bootstrap/Baseline.ps1`
- `Module/*.psm1`
- `Module/Data/**/*.json`
- `Localizations/**/*.json`
- embedded runtime libraries such as `Markdig.dll`

The hydrated root is considered ready only when the launcher finds the sentinel file
`.baseline-runtime-ready` plus the expected bootstrap, module, localization, and library files.

## When The Cache Is Used

On startup, the launcher first checks whether it is already running from a ready runtime root.
If so, it executes in place and does not use `%LOCALAPPDATA%\Baseline\RC`.

Otherwise it:

1. reads the public bundle version from assembly metadata
2. derives a build ID from the assembly module version ID
3. uses `%LOCALAPPDATA%\Baseline\RC\<version>\4\<buildId>\` as the hydration target
4. reuses that directory immediately if it already passes the readiness check

## Hydration Behaviour

Hydration is protected by a single cache-root lock file:

`%LOCALAPPDATA%\Baseline\RC\.hydrate.lock`

The launcher extracts into a sibling staging directory, writes the sentinel last, and then
renames the staging directory into place. If a target directory for the same build already
exists but is not ready, the launcher deletes it and rehydrates the payload from scratch.

The shorter `RC` cache root and `.s` staging suffix keep hydrated payload paths below classic
`MAX_PATH` limits for long bundled CBS manifest filenames on machines that do not enable
Windows long-path policy globally.

This means:

- one build ID gets at most one ready hydrated directory
- incomplete hydration for the same build is replaced, not accumulated
- concurrent launches serialize on the lock instead of racing

## Growth And Bounds

Current behaviour is intentionally simple:

- cache entries are partitioned by public bundle version, schema version, and build ID
- repeated launches of the same build reuse the same hydrated directory
- a new build ID creates a new sibling directory
- Baseline does not currently prune older versions or older build IDs automatically

So the cache is bounded per build, but not globally bounded across all historical builds.
Old cache directories remain until they are removed manually.

## Safe Cleanup

If Baseline is not running, old runtime-cache directories can be deleted safely. The launcher
will recreate the current build's directory on the next start if it is missing.

Do not delete the cache while a Baseline process is actively running from it.
