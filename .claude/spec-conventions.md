<!-- DO NOT EDIT. Synced from brindlechute/playbook. Edit there and re-run sync.sh. -->

# Spec conventions

This is the shared spec convention for Brindlechute repositories: the spec-file
format and the define → plan → implement → harvest change loop. It is synced
from `brindlechute/playbook` into each repo's `.claude/spec-conventions.md`; do
not edit it in place. Repo-specific rules (build/CI commands, required-reading
architecture conventions, commit trailers, and anything that constrains only one
repo) live in that repo's `AGENTS.md`, not here.

# Key convention: spec files

Files matching `*.spec.md` describe the design of modules, files, or features
they live alongside. Files matching `*.convention.md` describe cross-cutting
conventions that aren't tied to a single module, file, or feature.
Collectively these are referred to as **spec files**, and a spec file is the
**source of truth** for the design it describes — code is verified against
the spec, not the other way around.

When starting work in any area, search for relevant spec files first
(`*.spec.md` next to the code, at module roots, under `specs/`, and the
`*.convention.md` files under `specs/`) and rely on them as your primary
source of design intent. Only fall back to reading the code when no spec
exists, the spec is `partial` and doesn't cover the area you're touching,
or the spec lacks a detail you need. If you find yourself reading code to
answer a question the spec should have answered, that's a signal the spec
needs to be extended — flag it.

## Scope: this repository only

Spec files in a repository dictate the behavior of code in **that
repository only**. They are not the source of truth for any other
repository, and must not contain rules, contracts, or invariants that
constrain code living elsewhere.

External systems may still be referenced as context — e.g. a spec
describing which frontend screen calls an endpoint, or a note that
an event is consumed by a downstream service — but such references
describe the world the code lives in, not behavior this repo is
responsible for enforcing. If you find yourself writing a rule another
repo would have to obey, move it to that repo's spec instead.

## Spec file format

Every spec file begins with YAML frontmatter:

```yaml
---
status: complete         # complete | partial
scope: module            # module | file | feature | convention
---
```

`status` meanings:
- `complete`: the spec describes the entire public surface of its scope —
  every responsibility and entry point is covered. Behavioral detail may
  still be brief; what matters is that nothing in the interface is missing.
- `partial`: the spec covers only some of the functionality, with the rest
  to be filled in later. Code outside the described portions is not
  constrained by the spec.

`scope` meanings:
- `module`: applies to all files under the module the spec lives in. The
  spec lives at the module root as `<module>.spec.md`.
- `file`: applies to a single file. The spec lives next to it as
  `<filename>.spec.md`.
- `feature`: applies to a feature that may cross module boundaries. Lives
  under `specs/`.
- `convention`: applies to a cross-cutting concern that isn't tied to a
  single module, file, or feature — coding conventions, naming rules,
  architectural patterns, error-handling policy, auth/privacy rules, etc.
  Convention files use a distinct `.convention.md` extension and live
  under `specs/` as `<convention>.convention.md`. Conventions are looser
  than the other scopes: existing violations in the codebase are tolerated
  rather than treated as bugs that must be fixed immediately. Document a
  known gap between the convention and the code with a short note in the
  relevant section, so it stays visible. New code is still expected to
  follow the convention.

The frontmatter is `status` + `scope` only. Specs describe **shipped
reality** and carry no `[unimplemented]` markers, no `unimplemented`
frontmatter count, and no `Current:`/`Desired:`/`Backfill:` sub-bullets (see
"The change loop" below). Some older specs may still carry these legacy
markers; leave them in place, but if you encounter one while working in a
spec, warn the user that it carries a legacy marker so they can decide
whether to clean it up.

Standard sections — omit any that don't apply:

- `## Responsibilities` — what this is for, and what it is explicitly NOT
  for (non-goals).
- `## Public Contract` — signatures (functions, types, classes) plus
  semantic notes: preconditions, postconditions, invariants, error behavior,
  ordering guarantees. Signatures in the spec are canonical; code must match
  them.
- `## Invariants` — properties that must hold across the lifetime of the
  system or module.
- `## Notes` — rejected alternatives, open questions, links to related
  specs.

Spec files may reference file / class / method names and line numbers to
point at where logic lives. Agents should update stale references in passing
when they notice them.

In a `partial` spec, absence of a description does not imply anything about
the code. In a `complete` spec, the entire public surface is expected to be
covered; code in scope that isn't described is a spec bug, not a code bug.

## Writing style: goals and intent, not mechanics

Specs describe **what we want to be true**, not the code that implements
it. Aim for prose a reviewer would still recognize a year from now after
the implementation has been refactored. Specs are the source of truth and
must outlive any particular implementation.

Rules of thumb:

- Use domain language (outfitter, guide, trip, permit, location, payment,
  booking) — not code field names. A reader who has never opened the
  source file should still understand what the spec promises.
- State outcomes and invariants directly. Phrase failures as
  "rejected as invalid", not as "throws `XYZException`".
- Keep canonical contract: signatures, type names, constants whose exact
  value matters, and file/line anchors that help the reader navigate.
  Drop implementation detail: which fields a method touches, the
  delete-and-reinsert vs. patch choice, the precise exception subclass,
  the exact SQL filter — those belong in the code, not the spec.
- A spec describing only what the code does is a wasted spec. Ask "why
  does this rule exist?" or "what would break if we didn't enforce it?"
  and put that in.
- Prefer bullets over prose. Use prose only when a rule genuinely needs
  a sentence or two of context that bullets would mangle. Default to
  bullets for everything else.
- Don't redefine concepts that already have a canonical home. If
  "eligible", "available", "active", or any similar domain term is
  defined in another spec, just use the term — don't restate the
  definition where it's only being consumed.
- Don't document trivially-assumed edge cases. "Returns empty when
  there's no input" and similar tautologies add noise; only call out
  empty/short-circuit cases that encode an actual product decision
  (e.g. an opt-in feature flag).
- Document the end result, not the algorithm. Phases, passes, "first
  do X then do Y" framings are implementation detail. State the
  invariant the result satisfies and let the reader trust the code to
  reach it.

### Examples

Don't:

> Throws `ValidationFailedException` when `startPointId` or `endPointId`
> is null.

Do:

> A non-draft report is required to specify where the trip went; missing
> start or end is rejected as invalid.

---

Don't:

> No-ops when `(startPointId, endPointId, forecastCustomLocationId,
> tripType, isDraft)` are unchanged.

Do:

> When nothing relevant to permit assignment has changed — same start,
> same end, same operator-chosen location, same trip type, same draft
> status — the call is a no-op.

---

Don't:

> Org calls `confirmManualPayment` with `byGuide=false` → status becomes
> `SENT`. Guide calls with `byGuide=true` → status becomes `PAID`.

Do:

> The outfitter says they sent the money → payment is marked sent. The
> guide says they received it → payment is marked paid. Either side can
> confirm without the other.

---

Don't:

> Deletes all entries for `(orgId, reportId)` and re-inserts.

Do:

> After the call returns, the entries for this (organization, report) are
> the authoritative truth. No other code path is allowed to patch this
> set.

---

Don't:

> `permitId` resolution: unique valid outfitter permit; else the one
> referenced by the forecast custom location; else first valid; else
> `null`.

Do:

> Each entry records the most specific permit available: a permit the
> operator has explicitly linked to the trip's chosen location wins, then
> any linked custom location, then the unique held permit, then a
> deterministic pick from the held permits. No held permit at all means
> the entry is left without a permit — a deliberate signal that the trip
> isn't covered, not a placeholder.

### Convention files

Convention files describe coding patterns, so they have to talk about
code shapes (annotations, class structure, file locations). Even there,
prefer rule-form over narration: "Controllers must not access data tables
directly" rather than "the codebase wires controllers through facades". The
same do/don't spirit applies — say the rule, not how the code happens to
spell it out.

## The change loop

A change that touches — or should touch — a spec goes through a four-step loop.
The spec is written at the **end**, describing what actually shipped. There is no
spec-PR-first step, and specs are never aspirational.

1. **Define** (`br-define`) — work out *what* we're building and why, through
   dialogue. Output: a disposable `define.md` in a per-change working directory,
   `specs/changes/<YYYY-MM-DD-slug>/`. **Lands in its own PR** — except when fused
   with plan (below), where it shares the plan's PR.
2. **Plan** (`br-plan`) — work out *how*. Output: `plan.md` in the same
   directory, with implementation units (about a PR's worth each) and a
   `## Spec Impact` section naming the specs the change will create or update.
   **Lands in a PR** — its own in the standard flow, or one shared with `define.md`
   when the two are fused.
3. **Implement** (`br-work`) — build the units one at a time, **a PR per unit**.
   Keeps a running `learnings.md` in the working directory (deviations, design
   facts found while building, gotchas, and the full record of every code review).
   Does not touch specs.
4. **Harvest** (`br-reaper`) — once the code has shipped, reconcile the spec files
   to describe the new reality, then delete the working directory — **the spec
   updates and that deletion land in a final PR**. This is the change's
   **definition of done**: it is not finished until the reaper has run.

The working directory (`define.md`, `plan.md`, `learnings.md`) is **disposable
scaffolding** — it lives only for the change and is deleted at harvest. The
durable record is the specs plus git history.

These four steps are the **standard** flow for a non-trivial change. Two
shortcuts exist, both opt-in and neither the default: **fusing** define and plan
into one pass (below), and the one-shot **trivial** path (further below).

### Where the PRs fall

Every step that produces an artifact lands in a PR; what differs between changes
is only how those PRs are grouped. These are the **only** shapes:

- **Large feature** — `define → PR · plan → PR · work → PR per unit · harvest →
  PR`. The WHAT (`define.md`) and the HOW (`plan.md`) each get their own PR, so
  the define PR is a clean ownership boundary a non-engineer can own and merge
  before planning starts.
- **Medium feature** (the fusable case) — `define + plan → PR · work → PR per
  unit · harvest → PR`. Fusing lands `define.md` and `plan.md` together in one PR
  instead of two; everything downstream is identical to the large flow.
- **Oneshot** (trivial) — `define → judge triviality → PR`. A single
  `[trivial]`-prefixed PR carries the code change and its spec update together.
  There is no plan PR, no per-unit PRs, and no separate harvest PR.

The define and plan PRs commit the working-directory scaffolding into
`specs/changes/<slug>/` so the WHAT and HOW can be reviewed; the harvest PR
deletes that directory once its durable content has been folded into the specs.
Committing the scaffolding via PR is how it gets reviewed — it does not promote
the scaffolding to a source of truth, which remains the specs.

(A change that enters the loop at all takes one of these three shapes. A change
that touches no spec and adds no design intent — a pure internal refactor, a
dependency bump — never enters the loop; it is just a normal PR, see "What
survives into the specs" below.)

### What survives into the specs

Harvest applies one filter to everything captured during the change: **does it
still matter post-hoc, now that the change has shipped?**

- **Yes → it goes in a spec**, as present-tense current-state truth. Durable
  design facts become contracts and invariants; durable caveats become inline
  gotchas, phrased as facts about how things are — not as war stories. If a
  review surfaced a convention that wasn't written down, harvest documents it in
  the relevant `.convention.md`: harvest is **not** limited to the specs named in
  Spec Impact.
- **No → it evaporates** with the working directory. Intermediate fields,
  renames, migration choreography, the diff itself, dead-end review comments —
  none of it belongs in a spec. Capture was liberal during the change; harvest is
  where it gets cut down.

A change that touches nothing any spec describes and introduces no new design
intent — a pure internal refactor, a dependency bump — needs no spec work at
all; just make it.

### Shortcut: fusing define and plan

Normally define and plan are separate steps, with a handoff between them — and
that handoff is a natural **ownership boundary**: define settles the WHAT (a
non-engineer can drive it), while plan and everything after it is engineering
work. The default is to stop at that boundary after define and let an engineer
pick up planning.

As an opt-in **shortcut**, when an engineer is driving and the design is clear
enough to plan in the same breath as defining, the two can be **fused**: run
define and plan in one continuous pass with no review gate between them. Both
`define.md` and `plan.md` are still produced — fusing removes the gate, not the
artifacts — and they ride in a **single combined PR** instead of the two the
large flow opens. Everything downstream is unchanged — per-unit PRs and a
separate harvest PR.

Whether to fuse is the **user's call, not the agent's** — the agent asks at the
end of define rather than deciding. And the prompt must flag: **if you're not an
engineer, don't fuse — stop after define and hand the `define.md` to an
engineer**, who picks up at plan.

### Trivial changes: one shot

At the end of **define**, judge whether the change is **trivial**.

A change is **trivial** only when all of these hold:
- **No real design decision** — the WHAT and HOW were obvious from the start;
  define and plan would have been rubber stamps.
- **Small blast radius, easily reversible.**
- **About one small PR's worth** — single module, a handful of files.

It is **never trivial** if *any* of these is true:
- it involves a **data migration / schema change to existing data**;
- it **spans more than one repository or layer** (e.g. frontend and backend);
- it **changes a public contract** — a public API contract, an endpoint's
  request/response shape, or an event payload other code or clients consume;
- it touches **auth, permissions, or privacy**;
- it touches **money** — payments, payouts, billing, fees, refunds, invoices,
  bank connections, payment methods. This includes any messaging, display,
  calculation, processing, or storage of any of the above;
- it **creates a new spec or changes an existing invariant/contract** (adding a
  small clarifying gotcha to an existing spec is still fine — the disqualifier is
  new or changed *design intent*, not any spec edit);
- it **spans multiple modules** or introduces a new cross-module seam;
- it touches **a third-party integration** (e.g. payment, auth, or accounting
  providers, or event consumers);
- the **define dialogue had to do real work** — settling the WHAT took genuine
  back-and-forth, or scope was contested.

**When unsure, treat it as non-trivial and run the full loop.**

A trivial change skips the ceremony. Make the code change and the spec update
**together in a single PR** — that one PR carries the code plus whatever the
reaper would otherwise have harvested into the specs. No separate working
directory, no PR-per-unit, no separate harvest step. The post-hoc filter and the
back-gate spec-writing rules above still apply to the spec portion of that PR.

**Say so in the PR title** — prefix it with `[trivial]` — so a reviewer can see
at a glance that the change skipped the loop and that its spec update rides along
in the same PR.

## Testing posture

We do not care about unit tests. **The default for any change is no unit
tests.** Don't write them as a matter of course, and never treat a unit — in a
plan or in code — as incomplete merely because it has none.

**Code simplicity wins over testability, every time.** When a test would only
exist by making the code more complicated than it would otherwise be — extra
indirection, seams, dependency injection, or an abstraction introduced just so
something can be tested — keep the simpler code and skip the test.

Write a test only when it earns its place on its own merits — a genuinely tricky
invariant, or a high-value integration path the user has explicitly asked to
cover — and even then only when it doesn't push the code toward more complexity.
That is a deliberate exception, not the default.

## When code and a spec disagree

Update the code to match the spec. The exception is when the user explicitly
acknowledges the spec is wrong, in which case ask how to fix the spec
instead.
