# Roadmap Framing

This note captures product-planning language that should live in docs instead of being
trapped in `TODO.md`.

---

## Tier-3 Readiness Reframe

Tier 3 is a readiness and validation bucket, not a statement that the product is missing
core capability.

When a module or feature sits in Tier 3, the remaining work is usually one of:

- validation coverage
- documentation alignment
- polish
- maintainability

That means the code path can already be functionally complete while still remaining in Tier 3
until the surrounding evidence catches up.

The important rule is to avoid reclassifying Tier 3 items as "missing features" just because
they still appear in a backlog. In this project, Tier 3 means the implementation exists and
the remaining work is about proving it, explaining it, or tightening it.

## How To Read The Tracker

`Tests/phase3-progress.md` is a coverage tracker, not a feature request list.

- checked items indicate a module has test coverage in place
- skipped items indicate a deliberate testing boundary
- Tier placement reflects validation cost and risk, not quality of the code in isolation

If this framing changes, update this doc first and then adjust the tracker and TODO wording
to match.
