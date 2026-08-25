## Specs and the change loop

- Spec files (`*.spec.md`, `*.convention.md`) are the **source of truth** for
  design in this repo. Search for them before starting work in an area; code is
  verified against the spec, not the other way around.
- The full spec format and the **define → plan → implement → harvest** change
  loop live in `.claude/spec-conventions.md` (synced from `brindlechute/playbook`
  — do not edit it in place).
- Run the loop via the `br-define` / `br-plan` / `br-work` / `br-reaper` skills
  under `.claude/skills/` (also synced — do not edit them in place).

## Build and CI gate

Before considering a `br-work` unit done, run:

```bash
flutter analyze
flutter test
```

The backend lives in this repo but is not checked during builds (user
preference). CI runs on GitHub Actions (`.github/workflows/`): `flutter
analyze` + `flutter test` on push/PR with Flutter pinned to **3.38.9**, and
pushing a `v*` tag automatically builds Windows/Android and uploads a Release.
Flutter dependencies are locked via the committed `pubspec.lock`.

## Commit conventions

No commit-message trailer is required in this repo.

## Change workflow (user preference)

- Every new piece of work starts from `master` on its own branch
  (`codex/<slug>`), and the whole change loop (define → plan → work) happens on
  that single branch.
- When the change is complete, open a PR targeting `master` (not `dev`). The
  user merges the PR themselves.
- While a PR is open, keep working on that branch; don't switch back to
  `master` until the PR is merged.
