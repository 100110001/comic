---
name: br-reaper
description: "Harvest a finished change into the spec files, then delete its working directory. The final step of the spec-driven change loop (define -> plan -> implement -> harvest). Use when a change's implementation has shipped and it's time to reconcile the specs, or the user says 'reap', 'harvest this', 'finish the change', 'reconcile the specs', 'br-reaper'."
argument-hint: "[optional: change slug or specs/changes/<slug>/ path; blank uses the most recent]"
---

<!-- DO NOT EDIT. Synced from brindlechute/playbook. Edit there and re-run sync.sh. -->

# Reap a Finished Change

**Note: The current year is 2026.**

This is the **harvest** step — the last step of the spec-driven change loop:
**define → plan → implement → harvest.** The implementation has shipped; the
durable record is the specs. `br-reaper` reconciles the spec files to describe
what now exists, then deletes the change's disposable working directory. **This
step is the loop's definition of done** — the change is not complete until the
reaper has run.

## The two principles that govern everything here

- **Back-gate.** Specs are written *now*, at the end, describing **shipped
  reality** — a clean present-tense view of how things are, in goals-and-intent
  terms, not mechanics. Not aspirational, not a diff. (See the repo's spec
  conventions in `.claude/spec-conventions.md` and `specs/*.convention.md` for
  the exact format.)
- **The post-hoc filter.** For every candidate fact ask: **does it still matter
  now that the change has shipped?** Durable current-state facts (invariants,
  contracts, behaviors, gotchas) go into the specs. Everything that only mattered
  in flight — intermediate fields, renames, migration choreography, the diff
  itself, dead-end review comments — **evaporates**. Capture was liberal during
  implementation; harvest is where it gets cut down.

## Inputs

Resolve the change directory (passed slug/path, or the most recent
`specs/changes/<slug>/`). Gather:

- `define.md` — the WHAT (problem, desired behavior, scope).
- `plan.md` — the HOW. Read its **`## Spec Impact`** (the specs the plan said
  would change) and the marked-off units.
- `learnings.md` — br-work's running capture: deviations from the plan, design
  facts found while building, gotchas, and the **raw code-review records**
  (recorded unfiltered by br-work — it is the reaper's job to decide what to
  keep).
- The **shipped code** — the merged diff for this change (via git). This is the
  reality the specs must describe; where `learnings.md` or the plan disagree with
  what actually shipped, the shipped code wins.

For a large change, gather in parallel: dispatch subagents to (a) summarize what
behavior/contracts the shipped diff changed, (b) read the existing specs named in
Spec Impact plus adjacent specs/conventions, and (c) distill `learnings.md` +
review records into a list of durable-fact candidates. Subagents return text; the
orchestrator writes the spec files.

## What to write

Determine the full set of spec files to create or update:

1. **Start from the plan's `## Spec Impact`** — the specs it predicted.
2. **But do not stop there.** Spec Impact is a starting list, not a ceiling. Add
   any spec the *shipped reality* or the *review records* turned up:
   - a new invariant/contract/behavior that emerged during implementation;
   - **an undocumented convention a reviewer pointed out** — update the relevant
     `specs/*.convention.md` (or create one) so the convention is now written
     down. A reviewer surfacing "we always do X" is exactly the signal a
     convention is missing; capture it.
   - an area the change touched that had no spec yet.

   Conversely, drop a Spec Impact entry that turned out to carry no durable
   design change (state that it was dropped and why).

For each spec, working in clean back-gate form:

- Describe the shipped behavior as present-tense current-state truth. Fold
  durable gotchas inline where they're relevant, phrased as facts about how
  things are — never as war stories ("we hit a bug where…").
- Follow the repo's spec format (`.claude/spec-conventions.md`): frontmatter
  (`status`, `scope`), domain language, goals-and-intent over mechanics. Specs
  describe shipped reality and carry no `[unimplemented]` markers.
- For convention files: when documenting a convention the codebase doesn't fully
  follow yet, note the known gap between the convention and the code in the
  relevant section so it stays visible, per the convention-file rules in
  `.claude/spec-conventions.md`. New code is still expected to follow the
  convention.

## Review before finishing

- Every durable fact from `learnings.md` (including review records) and from the
  shipped diff is either reflected in a spec or consciously dropped as
  non-durable. Nothing durable silently lost.
- Nothing non-durable smuggled into a spec — no diffs, no renames-as-history, no
  intermediate scaffolding.
- The specs read as a clean current-state view a reviewer would still recognize a
  year from now.

## Delete the scaffolding

Once the specs are reconciled, **delete the change's working directory**
(`specs/changes/<slug>/` — `define.md`, `plan.md`, `learnings.md`). It is
disposable scaffolding; its durable content now lives in the specs, and git
history retains the rest. This deletion is what marks the change **done**.

The spec updates and this deletion land together in the change's **final PR** —
the harvest PR (see `.claude/spec-conventions.md`, "Where the PRs fall"). In the
large and medium shapes this is the last of the change's PRs; the oneshot
(trivial) path has no harvest PR, because its single PR already carried the spec
update.

Confirm with the user before removing the directory — show what was harvested
into which specs first — unless they've already said to proceed.

## Report

State: which spec files were created/updated (and the one-line design fact each
now carries), which Spec Impact entries were dropped and why, any convention that
got newly documented, and that the working directory was deleted. That report is
the record that the change reached the loop's definition of done.
