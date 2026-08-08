---
name: br-work
description: "Implement a plan one task at a time, opening a PR per task. The implement step of the spec-driven change loop (define -> plan -> implement -> harvest). Use when a plan.md is ready to build, or the user says 'implement this', 'work the plan', 'build it', 'br-work'."
argument-hint: "[optional: plan.md path; blank uses the most recent specs/changes/*/plan.md]"
---

<!-- DO NOT EDIT. Synced from brindlechute/playbook. Edit there and re-run sync.sh. -->

# Implement a Plan

**Note: The current year is 2026.**

This is the **implement** step of the spec-driven change loop:
**define → plan → implement → harvest into specs.** It executes a `plan.md`
produced by `br-plan`, **one implementation unit at a time, opening a PR per
unit**, in dependency order.

These per-unit PRs are the implement step's PRs in both the large and medium
shapes (see `.claude/spec-conventions.md`, "Where the PRs fall"); they branch
from the merged plan PR. Only the oneshot (trivial) path skips them — there the
whole change is a single PR and `br-work` is not used.

Two rules that hold for the whole loop:

- **Do not write or update spec files here.** Specs are written at the END of the
  loop (back-gate), by the harvest step — never during implementation. Carry the
  plan's `## Spec Impact` forward untouched so harvest knows what to write.
- **Do not delete the working directory** (`specs/changes/<slug>/`). It is
  disposable scaffolding, but it is deleted by the harvest step when the change
  is deemed complete — not here.

## Input

Resolve the plan:
- If a path was given, use it.
- Otherwise use the most recent `specs/changes/*/plan.md`.

Read it fully. The load-bearing sections are the **Implementation Units** (their
`U-ID`, **Dependencies**, **Files**, **Approach**, **Test scenarios**,
**Verification**), the **Scope Boundaries**, and **Spec Impact**. Treat the plan
as a decision artifact: implement what it says; do not re-litigate its decisions.

**Track progress in the working directory.** As each unit ships, mark it done in
`plan.md` with **its PR number** — a status marker on the unit heading carrying
the PR reference (e.g. `### U1. ✅ Name (PR #1234)` or a `**Status:** shipped —
PR #1234` line), not a list checkbox, so it stays compatible with the heading
form `br-plan` uses. Recording the PR number gives a back-reference from each
unit to the change that shipped it. Before starting, read those marks — and
sanity-check against git (branches, open/merged PRs) as the ground truth — then
resume from the next un-shipped unit. The plan is disposable
scaffolding, so marking it is fine; this is the one place a working-dir doc
carries state.

## The loop

Work the units **strictly in sequence** — one at a time, in dependency order.
Finish a unit's PR (open it) before starting the next unit; never implement units
in parallel or open several PRs at once. Each PR builds on the last, stays small,
and is reviewable on its own.

For each implementation unit, in dependency order:

1. **Branch.** Fetch and branch off the latest default branch. If the unit
   depends on a prior unit whose PR has not merged yet, branch off that unit's
   branch instead (stacked) so the work composes. Never implement on the default
   branch directly.
2. **Implement only that unit.** Touch the unit's **Files** and follow its
   **Approach**. Stay within the unit's scope — route anything tangential to the
   plan's deferred work, do not expand. Follow existing patterns and the repo's
   architecture convention (the required-reading convention named in AGENTS.md),
   and use the domain vocabulary from the specs.
3. **Tests are off by default.** We do not care about unit tests, so don't write
   them as a matter of course (see "Testing posture" in
   `.claude/spec-conventions.md`). When code simplicity and testability pull in
   different directions, choose the simpler code. Write a test only when the
   unit's plan explicitly calls for one or the user asks — for a genuinely tricky
   invariant or a high-value integration path — and even then only when it
   doesn't push the code toward more complexity. If you do write one, extend the
   test files that already cover the code you're touching rather than duplicating,
   and honor any `Execution note` (test-first / characterization-first).
4. **Record learnings and mark the unit done — as part of this unit's change.**
   Append anything the harvest step should weigh to
   `specs/changes/<slug>/learnings.md` (see below), and mark this unit done in
   `plan.md` with a status marker on its heading. These working-directory edits
   are part of the unit's work: they ride in the **same commit and the same PR**
   as the code — never a loose uncommitted change, never deferred into the next
   unit's PR. The PR number isn't known yet, so mark the unit done without it for
   now and backfill it in step 6.
5. **Commit.** One commit (or a tight cluster) covering **all of the unit
   together — the code, the `plan.md` mark-off, and the `learnings.md` append** —
   ending the message with the commit trailer required by the repo's AGENTS.md.
   Do not split the spec-loop bookkeeping into a separate commit or a separate PR.
6. **Open the PR.** Push the branch and open the PR. Ship code first: push and
   open the PR as soon as the implementation looks right — it is fine for the
   initial push to fail CI. The PR body states what the unit does and why, names
   its `U-ID`, links the plan, and ends with:
   `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
   Once the PR exists, backfill its number into the unit's `plan.md` mark (e.g.
   `### U1. ✅ Name (PR #1234)` or a `**Status:** shipped — PR #1234` line, so
   each unit back-references the PR that shipped it) and push to the **same
   branch** — it rides in the same still-open PR. This back-reference is the one
   piece of bookkeeping that can't precede the PR, so it's a follow-up commit, not
   a follow-up PR.
7. **React to CI only after pushing.** If CI fails, run the repo's build and
   checks (the CI gate commands named in AGENTS.md), fix, and push again. Do not
   run these as a precondition for the initial push.
8. **Report and continue.** State the PR for this unit, then move to the next
   un-shipped unit. The user can interrupt at any point.

## The learnings file

`specs/changes/<slug>/learnings.md` is a running, append-only capture of things
discovered **during** implementation that the harvest step should weigh. It is
raw input for harvest — not a polished doc — and it is deleted with the rest of
the scaffolding once harvest is done.

Append to it as you go. Capture:
- **Deviations from the plan** — where the real code diverged from the Approach, and why.
- **Design facts discovered while building** — invariants, contracts, or behaviors that became clear only in the code, including anything that confirms, contradicts, or adds to the plan's `## Spec Impact`.
- **Gotchas** — surprises worth knowing, framed as present-tense facts about how things are.
- **Code review — record everything.** Whenever a code review happens on a unit's
  PR — a human reviewer's comments, a review tool, `/code-review`, or your own
  review pass, including reviews that land after you've moved on — record *all* of
  it: every finding, comment, and suggestion, what you changed in response, and
  what you dismissed and why. Record it raw and complete. Do **not** judge here
  what's worth keeping — the reaper works that out. (A reviewer pointing at an
  undocumented convention is exactly the kind of thing reaper turns into a
  `.convention.md` update, so don't drop it.)

Do **not** pre-filter for durability here — that is harvest's job. Harvest applies
the "does it matter post-hoc?" test: durable facts fold into the specs named in
Spec Impact (as inline gotchas / invariants) — or into a convention or adjacent
spec the review surfaced — and the rest evaporates with the working directory.
Capture liberally now; harvest decides what survives.

## When all units have shipped

The change is **not done** — implementation is complete, but the durable record
is the specs. Hand off to the **harvest** step, which reads the plan's
`## Spec Impact` and `learnings.md`, writes/updates the named spec files (folding
in only what matters post-hoc), and then deletes the `specs/changes/<slug>/`
scaffolding. State plainly that implementation is finished and harvest is the
remaining step.

(The harvest step is not built yet. Until it is, say so and stop — do not write
specs or delete the scaffolding yourself; that is harvest's job.)
