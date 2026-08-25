---
name: br-define
description: 'Define the problem and desired outcome through collaborative dialogue, then write a disposable problem-definition doc into the change''s working directory. First step of the spec-driven change loop (define -> plan -> implement -> harvest into specs). Use when starting a non-trivial change, or when the user says "let''s define X", "what should we build", "think through X", or presents a vague or ambitious feature request.'
argument-hint: "[feature idea or problem to define]"
---

<!-- DO NOT EDIT. Synced from brindlechute/playbook. Edit there and re-run sync.sh. -->

# Define a Problem

**Note: The current year is 2026.** Use this when dating documents.

This is the **define** step — the first step of the spec-driven change loop:
**define → plan → implement → harvest into specs.** It answers **WHAT** we are
building and why, through collaborative dialogue. `br-plan` follows and answers
**HOW**.

The output is a **disposable problem-definition doc** written into the change's
working directory. It is working scaffolding, not a source of truth: it feeds the
plan, and it is deleted when the change is deemed complete (after the harvest
step reconciles the specs). The durable record of this change
is the **spec files**, which are written at the END of the loop (back-gate),
harvested from what actually shipped — never here. Do not treat this doc as a
spec, and do not write specs now.

This doc is also itself subject to the loop's evaporation rule: it captures what
matters *for deciding and planning the change*, much of which stops mattering once
the change ships. That is fine — it is meant to evaporate.

This skill does not implement code. It explores, clarifies, and defines.

**Keep implementation out of this doc.** Define the problem, the desired
behavior, scope boundaries, and success criteria. Libraries, schemas, endpoints,
table/column names, and file layouts belong in `br-plan`, not here — unless the
change is itself inherently about a technical or architectural decision.

**All file references must use repo-relative paths**, never absolute paths.

## Core Principles

1. **Assess scope first** - Match the amount of ceremony to the size and ambiguity of the work.
2. **Be a thinking partner** - Suggest alternatives, challenge assumptions, and explore what-ifs instead of only extracting requirements.
3. **Resolve product decisions here** - User-facing behavior, scope boundaries, and success criteria belong in this workflow. Detailed implementation belongs in planning.
4. **Keep implementation out of the requirements doc by default** - Do not include libraries, schemas, endpoints, file layouts, or code-level design unless the brainstorm itself is inherently about a technical or architectural change.
5. **Right-size the artifact** - Simple work gets a compact requirements document or brief alignment. Larger work gets a fuller document. Do not add ceremony that does not help planning.
6. **Apply YAGNI to carrying cost, not coding effort** - Prefer the simplest approach that delivers meaningful value. Avoid speculative complexity and hypothetical future-proofing, but low-cost polish or delight is worth including when its ongoing cost is small and easy to maintain.

## Interaction Rules

These rules apply to every brainstorm, including the universal (non-software) flow routed to `references/universal-brainstorming.md`.

1. **Ask one question at a time** - One question per turn, even when sub-questions feel related. Stacking several questions in a single message produces diluted answers; pick the single most useful one and ask it.
2. **Prefer single-select multiple choice** - Use single-select when choosing one direction, one priority, or one next step.
3. **Use multi-select rarely and intentionally** - Use it only for compatible sets such as goals, constraints, non-goals, or success criteria that can all coexist. If prioritization matters, follow up by asking which selected item is primary.
4. **Default to the platform's blocking question tool** - Use `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). These tools include a free-text fallback, so well-chosen options scaffold the answer without confining it. This default holds for opening and elicitation questions too, not only narrowing. Fall back to numbered options in chat only when no blocking tool exists in the harness (including `ToolSearch` returning no match for it) or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.
5. **Use an open-ended question only when the question is genuinely open** - Drop the blocking tool when the answer is inherently narrative, when presented options would steer a diagnostic or introspective answer, or when you cannot write 3-4 genuinely distinct, plausibly-correct options without padding. The test: if you'd be straining to fill the option slots, the question is open — ask it open-ended. Rule 1 still applies: one question per turn.
6. **Open-ended questions earn their place only when they're specific enough to elicit a substantive answer** - Apply Rule 5 silently: just ask the question, never narrate the form choice. The question must give the user something concrete to anchor on. Good: *"What's the most concrete thing someone's already done about this — paid for it, built a workaround, quit a tool over it?"* — it names what counts as an answer. Too thin: *"What's your take?"* — nothing to bite into, and framings that imply a short answer ("briefly", yes/no) waste the open question the same way.

## Output Guidance

- **Keep outputs concise** - Prefer short sections, brief bullets, and only enough detail to support the next decision.
- **Use repo-relative paths** - When referencing files, use paths relative to the repo root (e.g., `src/models/user.rb`), never absolute paths. Absolute paths make documents non-portable across machines and teammates.

## Subagents

The grounding scout (Phase 1.1) and the claim verifier (Phase 2.6) run as
subagents (`Agent`/`Task`) so their read budgets don't get carried through the
whole dialogue. The dialogue itself — questions, approaches, synthesis, and the
doc — runs in the main conversation. If no subagent primitive is available, run
the scout and verifier inline with the same read budgets.

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

**If the feature description above is empty, ask the user:** "What would you like to explore? Please describe the feature, problem, or improvement you're thinking about."

Do not proceed until you have a feature description from the user.

## Execution Flow

### Phase 0: Resume, Assess, and Route

#### 0.0 Output

The doc is always markdown, written into this change's working directory (see
Phase 3). There is no HTML mode and no config to read. Strip any `output:` or
`mode:` token from `$ARGUMENTS` before treating the remainder as the feature
description; other `<word>:<word>` tokens (e.g. `feat:`, `fix:`) pass through
verbatim.

#### 0.1 Resume Existing Work When Appropriate

If the user references an existing definition, or there is a recent matching `define.md` under `docs/changes/`:
- Read the document
- Confirm before resuming: "Found an existing definition for [topic]. Continue from this, or start fresh?"
- If resuming, summarize the current state briefly, continue from its decisions and outstanding questions, and update it in place instead of duplicating.

#### 0.1b Classify Task Domain

Before proceeding to Phase 0.2, classify whether this is a software task. The key question is: **does the task involve building, modifying, or architecting software?** -- not whether the task *mentions* software topics.

**Software** (continue to Phase 0.2) -- the task references code, repositories, APIs, databases, or asks to build/modify/debug/deploy software.

**Non-software brainstorming** (route to universal brainstorming) -- BOTH conditions must be true:
- None of the software signals above are present
- The task describes something the user wants to explore, decide, or think through in a non-software domain

**Neither** (respond directly, skip all brainstorming phases) -- the input is a quick-help request, error message, factual question, or single-step task that doesn't need a brainstorm.

**If non-software brainstorming is detected:** Read `references/universal-brainstorming.md` now and follow it — it replaces Phases 0.2–4 entirely. Scope assessment, exploration moves, convergence, and the wrap-up menu for this route live there, not in this main body; improvising them produces an unstructured chat with no synthesis and no handoff. The **Core Principles and Interaction Rules above still apply unchanged** — including one-question-per-turn and the default to the platform's blocking question tool — and are the only part of this file that survives the route.

#### 0.2 Assess Whether Brainstorming Is Needed

**Clear requirements indicators:**
- Specific acceptance criteria provided
- Referenced existing patterns to follow
- Described exact expected behavior
- Constrained, well-defined scope

**If requirements are already clear:**
Keep the interaction brief. Confirm understanding and present concise next-step options rather than forcing a long brainstorm. Only write a short requirements document when a durable handoff to planning or later review would be valuable. Skip Phase 1.1 and 1.2 entirely — go straight to Phase 1.3 or Phase 2.5 in announce-mode (synthesis emitted for visibility, no blocking confirmation), then to Phase 3.

#### 0.3 Assess Scope

Use the feature description plus a light repo scan to classify the work:
- **Lightweight** - small, well-bounded, low ambiguity
- **Standard** - normal feature or bounded refactor with some decisions to make
- **Deep** - cross-cutting, strategic, or highly ambiguous

If the scope is unclear, ask one targeted question to disambiguate and then proceed.

**Deep sub-mode: feature vs product.** For Deep scope, also classify whether the brainstorm must establish product shape or inherit it:

- **Deep — feature** (default): existing product shape anchors decisions. Primary actors, core outcome, positioning, and primary flows are already established in the product or repo. The brainstorm extends or refines within that shape.
- **Deep — product**: the brainstorm must establish product shape rather than inherit it. Primary actors, core outcome, positioning against adjacent products, or primary end-to-end flows are materially unresolved. Existing code lowers the odds of product-tier but does not by itself rule it out — a half-built tool with ambiguous shape is still product-tier.

Product-tier triggers additional Phase 1.2 questions and additional sections in the requirements document. Feature-tier uses the current Deep behavior unchanged.

### Phase 1: Understand the Idea

#### 1.1 Existing Context Scan

Scan the repo before substantive brainstorming. Match depth to scope:

**Lightweight** — Search for the topic, check if something similar already exists, and move on.

**Standard and Deep** — Two passes:

*Constraint Check (inline)* — Read `AGENTS.md` at repo root for workflow, product, and scope constraints. **Search for and read the spec files relevant to the area** — `*.spec.md` next to the code and at module roots, feature specs under `specs/`, and the `specs/*.convention.md` files (start with the required-reading convention(s) named in the repo's AGENTS.md). In this repo **specs are the source of truth** for existing design: use them to ground what already exists, which invariants hold, and which domain terms (outfitter/organization, guide, trip, booking, permit, location, catalog) to use in dialogue and the doc; map user-offered synonyms back to them. If a relevant area has no spec, note that gap — the change may need a spec written for it during the harvest step. If any of these add nothing, move on. This pass stays in the main conversation — the dialogue needs this material to shape its questions.

*Topic Scan (grounding scout)* — Create a scratch dir at `/tmp/br-define/<run-id>/` (short unique slug), then dispatch one extraction-tier sub-agent via the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex) where available; otherwise run the work inline or serially. In harnesses that support background dispatch, proceed to Phase 1.2/1.3 **without waiting**: the scout runs during the user's think-time on the opening questions. Scout prompt:

> Gather grounding for a requirements brainstorm about **{topic}** in this repo. Search first with the native file-search and content-search tools, then read targeted sections — budget ~20 reads, preferring ranges over whole files. Find: whether something similar already exists, the most relevant existing artifacts (brainstorms, plans, specs, feature docs), adjacent examples of similar behavior, and the current state of anything the topic would touch (tables, routes, config, dependencies). Write a **grounding dossier** to `{scratch-dir}/grounding.md`: at most 150 lines of verbatim quotes and short code snippets, each with a `file:line` pointer. Extraction only — quote what the repo says; do not interpret or propose. If the topic has little footprint, write less rather than padding. Return only a gist: 3-5 lines summarizing what the dossier holds, plus its absolute path.

Carry only the gist in the dialogue. When the conversation needs specifics the gist can't answer — the user challenges a claim, an approach needs grounding — read the dossier on demand: it is a condensed, verified quote-sheet, always cheaper than re-scanning raw files. Downstream consumers (the Phase 2.6 verifier, the br-plan handoff) receive the dossier path, not its contents. If the scout has not returned by the time Phase 2 needs it, wait for it then.

If the scan and scout surface nothing relevant, say so and continue. Two rules govern technical depth during the scan:

1. **Verify before claiming** — When the brainstorm touches checkable infrastructure (database tables, routes, config files, dependencies, model definitions), read the relevant source files to confirm what actually exists. Any claim that something is absent — a missing table, an endpoint that doesn't exist, a dependency not in the Gemfile, a config option with no current support — must be verified against the codebase first; if not verified, label it as an unverified assumption. This applies to every brainstorm regardless of topic.

2. **Defer design decisions to planning** — Implementation details like schemas, migration strategies, endpoint structure, or deployment topology belong in planning, not here — unless the brainstorm is itself about a technical or architectural decision, in which case those details are the subject of the brainstorm and should be explored.

**Slack context** (opt-in, Standard and Deep only) — never auto-dispatch. Route by condition:

- **Tools available + user asked**: Read `references/agents/slack-researcher.md` and dispatch a generic subagent seeded with that local prompt plus a brief summary of the brainstorm topic alongside Phase 1.1 work. Do not dispatch a standalone agent by type/name. Incorporate findings into constraint and context awareness.
- **Tools available + user didn't ask**: Note in output: "Slack tools detected. Ask me to search Slack for organizational context at any point, or include it in your next prompt."
- **No tools + user asked**: Note in output: "Slack context was requested but no Slack tools are available. Install and authenticate the Slack plugin to enable organizational context search."

#### 1.2 Product Pressure Test

Before generating approaches, scan the user's opening for rigor gaps. Match depth to scope.

This is agent-internal analysis, not a user-facing checklist. Read the opening, note which gaps actually exist, and raise only those as questions during Phase 1.3 — folded into the normal flow of dialogue, not fired as a pre-flight gauntlet. A fuzzy opening may earn three or four probes; a concrete, well-framed one may earn zero because no scope-appropriate gaps were found.

**Lightweight:**
- Is this solving the real user problem?
- Are we duplicating something that already covers this?
- Is there a clearly better framing with near-zero extra cost?

**Standard — scan for these gaps:**

- **Evidence gap.** The opening asserts want or need, but doesn't point to anything the would-be user has already done — time spent, money paid, workarounds built — that would make the want observable. When present, ask for the most concrete thing someone has already done about this.

- **Specificity gap.** The opening describes the beneficiary at a level of abstraction where the agent couldn't design without silently inventing who they are and what changes for them. When present, ask the user to name a specific person or narrow segment, and what changes for that person when this ships.

- **Counterfactual gap.** The opening doesn't make visible what users do today when this problem arises, nor what changes if nothing ships. When present, ask what the current workaround is, even if it's messy — and what it costs them.

- **Attachment gap.** The opening treats a particular solution shape as the thing being built, rather than the value that shape is supposed to deliver, and hasn't been examined against smaller forms that might deliver the same value. When present, ask what the smallest version that still delivers real value would look like.

Plus these synthesis questions — not gap lenses, product-judgment the agent weighs in its own reasoning:
- Is there a nearby framing that creates more user value without more carrying cost? If so, what complexity does it add?
- Given the current project state, user goal, and constraints, what is the single highest-leverage move right now: the request as framed, a reframing, one adjacent addition, a simplification, or doing nothing?

Favor moves that compound value, reduce future carrying cost, or make the product meaningfully more useful or compelling. Use the result to sharpen the conversation, not to bulldoze the user's intent.

**Deep** — Standard lenses and synthesis questions plus:
- Is this a local patch, or does it move the broader system toward where it wants to be?

**Deep — product** — Deep plus:

- **Durability gap.** The opening's value proposition rests on a current state of the world that may shift in predictable ways within the horizon the user cares about. When present, ask how the idea fares under the most plausible near-term shifts — and push past rising-tide answers every competitor could make.

- What adjacent product could we accidentally build instead, and why is that the wrong one?
- What would have to be true in the world for this to fail?

These questions force an explicit product thesis and feed the Scope Boundaries subsections ("Deferred for later" and "Outside this product's identity") and Dependencies / Assumptions in the requirements document.

#### 1.3 Collaborative Dialogue

Follow the Interaction Rules above. Use the platform's blocking question tool when available.

**Guidelines:**
- Ask what the user is already thinking before offering your own ideas. This surfaces hidden context and prevents fixation on AI-generated framings.
- Start broad (problem, users, value) then narrow (constraints, exclusions, edge cases)
- **Rigor probes fire before Phase 2 and are open-ended, not menus.** Each scope-appropriate gap found in Phase 1.2 fires as a **separate** direct open-ended probe — one probe satisfies one gap, not multiple. Surface them progressively across the conversation — interleaving with narrowing moves is fine — as long as every gap found in Phase 1.2 has been probed before Phase 2. A menu would signal which kinds of evidence count and let the user pick rather than produce; an open probe forces real observation or surfaces real uncertainty. Each of Phase 1.2's "when present, ask..." lines is the probe; phrase it per Interaction Rule 6. **Attachment is the final rigor probe before Phase 2 when that gap is present — presence is judged from the opening per Phase 1.2, and narrowing having already produced a shape is not a reason to skip it; its job is to pressure-test the user's implicit framing before Phase 2 inherits it.** If a probe's answer reveals genuine uncertainty, record it as an explicit assumption in the requirements document rather than skipping the probe.
- Clarify the problem frame, validate assumptions, and ask about success criteria
- Make requirements concrete enough that planning will not need to invent behavior
- Surface dependencies or prerequisites only when they materially affect scope
- Resolve product decisions here; leave technical implementation choices for planning
- Bring ideas, alternatives, and challenges instead of only interviewing

**Before exiting Phase 1.3: integration check.** Mentally combine what the user has said so far and surface any non-obvious consequences the dialogue hasn't probed. If user-stated X plus user-stated Y plus your-default-Z produces a downstream effect the user is unlikely to have tracked through one-question-at-a-time dialogue ("if mute lives on the rule AND we don't warn on delete, then rule-delete silently loses pause state"), probe it now while you're still in dialogue. One probe per genuine combination effect, asked open-ended, same discipline as rigor probes. Phase 2.5's call-outs are a safety net for residuals (silent agent inferences, pre-loaded contexts with no dialogue) — NOT a punt list for consequences you could have asked about now.

**Exit condition:** Continue until the idea is clear AND no integration-check questions are pending, OR the user explicitly wants to proceed.

### Phase 2: Explore Approaches

If multiple plausible directions remain, propose **2-3 concrete approaches** based on research and conversation. Otherwise state the recommended direction directly.

Use at least one non-obvious angle — inversion (what if we did the opposite?), constraint removal (what if X weren't a limitation?), or analogy from how another domain solves this. The first approaches that come to mind are usually variations on the same axis. Hold each approach to an anti-genericness test: if it would appear in a generic listicle for this problem category, sharpen it against the grounding dossier or drop it.

Present approaches first, then evaluate. Let the user see all options before hearing which one is recommended — leading with a recommendation before the user has seen alternatives anchors the conversation prematurely.

When useful, include one deliberately higher-upside alternative:
- Identify what adjacent addition or reframing would most increase usefulness, compounding value, or durability without disproportionate carrying cost. Present it as a challenger option alongside the baseline, not as the default. Omit it when the work is already obviously over-scoped or the baseline request is clearly the right move.

At product tier, alternatives should differ on *what* is built (product shape, actor set, positioning), not *how* it is built. Implementation-variant alternatives belong at feature tier.

For each approach, provide:
- Brief description (2-3 sentences)
- Pros and cons
- Key risks or unknowns
- When it's best suited

**Approach granularity: mechanism / product shape, not architecture.** Approach descriptions name mechanism-level distinctions ("pause as a rule property" vs "pause as an event filter" vs "pause as a separate entity") and product-relevant trade-offs (plan-tier coupling, complexity surface, migration difficulty). They do NOT name implementation specifics — column names, table names, file paths, service classes, JSON shapes, exact method names. Those are br-plan's job. Bringing architecture forward at define time forces the user to make architectural decisions on this step's intentionally-shallow research, and the synthesis at Phase 2.5 then has to filter out the leak.

After presenting all approaches, state your recommendation and explain why. Prefer simpler solutions when added complexity creates real carrying cost, but do not reject low-cost, high-value polish just because it is not strictly necessary.

If one approach is clearly best and alternatives are not meaningful, skip the menu and state the recommendation directly.

If relevant, call out whether the choice is:
- Reuse an existing pattern
- Extend an existing capability
- Build something net new

### Phase 2.5: Synthesis Summary

**STOP. Before composing the synthesis, read `references/synthesis-summary.md`.** The two-stage shape (internal three-bucket draft → chat-time scoping synthesis), the four scoping synthesis sections with their keep tests, the per-bullet affirmability and detail tests, the tier-aware bullet budget with re-cut rule, anti-pattern guidance, soft-cut behavior, self-redirect support, and internal-draft routing into doc body sections all live there — none of them appear in this main body. Composing a synthesis without these rules loaded reliably produces malformed output: the full internal three-bucket draft pasted verbatim into chat, implementation detail leaking into the scoping synthesis, the proposal-pitch anti-pattern. The Path A / Path B routing below decides only *whether* a confirmation fires — it is not the synthesis spec.

Surface a scoping synthesis to the user before Phase 3 writes the requirements doc — the user's last opportunity to correct scope before the artifact lands. The scoping synthesis is shaped like what two product collaborators would confirm before writing a PRD, not like a comprehensive audit or a one-line preview.

Fires for **all tiers** including Lightweight. Skip Phase 2.5 entirely on the Phase 0.1b non-software (universal-brainstorming) route.

**Path A vs Path B:** the scoping synthesis shape depends on TWO signals — whether any blocking question fired AND what tier Phase 0.3 classified the scope as.

- **Path A — no blocking questions fired AND tier is Lightweight**: announce-mode. Emit "What we're building" prose only (1–3 sentences), then proceed to Phase 3 doc-write in the same turn. No other sections, no confirmation question. Do NOT end the turn waiting for acknowledgment. The user can revise after the doc lands if the shape is wrong — Lightweight Path A docs are short, post-hoc revision is cheap.
- **Path B — at least one blocking question fired, OR tier is Standard / Deep-feature / Deep-product**: full tier-aware scoping synthesis with confirmation gate. Two scenarios fire Path B: (a) the user invested answer-time during dialogue, or (b) the user pre-loaded substantive scope content (Phase 0.2 fast-path with a richly-specified opening prompt). Either way, the substance earns a real checkpoint. Confirmation is unconditional even when zero call-outs survive the keep test.

**Why the tier guard on Path A**: Phase 0.2's fast path serves both tight one-liners and richly pre-loaded openings that need no dialogue. Pre-loaded substance makes the Phase 0.3 tier Standard or Deep, which routes to Path B — without the guard, 20+ items of pre-stated scope would get a 1-sentence checkpoint.

#### 2.6 Claim Verification (inside the Path B confirmation wait)

When the upcoming requirements doc will assert checkable claims about the repo — absence claims ("no retry logic exists"), references to specific files, config, or dependencies, anything planning would build on — dispatch one generation-tier verifier at the same moment the Path B confirmation question goes up, so it runs during the user's think-time. Pass it the claim list (one line each), the grounding dossier path if one exists, and this instruction: verify each claim directly against the codebase — budget ~15 targeted reads — and return a per-claim verdict: **confirmed** (with `file:line`), **refuted** (with the contradicting evidence), or **unverifiable**. Do not block the confirmation question on the verifier.

Consume the verdicts at Phase 3: correct refuted claims before writing, label unverifiable ones as explicit assumptions. A fresh-context verifier replaces self-graded verification — the author confirming its own claims is anchored; the verifier never saw the dialogue.

Skip when Path A fires, when the doc will make no checkable claims, or on the non-software route. If the verifier dispatch fails, fall back to verifying the claims inline before the Phase 3 write — Phase 1.1's verify-before-claiming rule still holds either way.

### Phase 3: Capture the Definition

Write or update the definition doc only when the conversation produced durable decisions worth preserving — see `references/brainstorm-sections.md` "Decide whether a doc is warranted at all" for the criteria and the stress test. Skip the doc when the user only needs brief alignment and the decisions can flow straight into `br-plan` without an artifact in the middle.

When a doc is warranted, compose it using:

- `references/brainstorm-sections.md` — section contract (outcomes, hard floor, include-when-material catalog, agency rules, ID conventions).
- `references/markdown-rendering.md` — how the sections are presented in markdown. Read it **now**, before composing.

**Write tight.** A section being material is not license to pad it. Hold every kept section to the prose-economy discipline in `references/brainstorm-sections.md`: one idea per sentence, a requirement is intent plus at most one qualifier, defer forks to Outstanding Questions rather than specifying both arms, resolve superseded text in place rather than stacking strata. Before declaring the doc written, run the named test there — could a reader find a contradiction in each section in one pass?

**Where it goes.** Create this change's working directory at `specs/changes/<YYYY-MM-DD-slug>/` (a short kebab-case slug for the change) and write the definition to `specs/changes/<YYYY-MM-DD-slug>/define.md`. `br-plan` adds `plan.md` in the same directory. This directory is **disposable working scaffolding**: it is deleted when the change is deemed complete (after the harvest step reconciles the specs), and nothing in it is a source of truth — the durable record is the spec files, written by that harvest step. Confirm with the path so it is clickable.

### Phase 3.5: Trivial check

Once the definition is written, determine whether the change is **trivial**, per
the "Trivial changes: one shot" rules in `.claude/spec-conventions.md` (the
single source of truth). Read that section and apply its full criteria — do not
work from memory or a paraphrase. You have the dialogue in hand, so weigh its own
signal: if settling the WHAT took real back-and-forth or scope stayed contested,
it is not trivial. When unsure, treat it as non-trivial.

This is the **agent's** call. The next decision — for a non-trivial change,
whether to stop after define or fuse straight into planning — is the **user's**
call, asked in Phase 4. Do not decide it for them.

### Phase 4: Handoff

After the definition lands, offer the user a short choice with the platform's
blocking question tool (`AskUserQuestion`).

**Trivial change:**
- **Do it in one shot** — the **oneshot** shape: make the code change and, in the
  **same PR**, the spec update the reaper would have made (back-gate +
  post-hoc-filter rules apply to the spec part). **Prefix the PR title with
  `[trivial]`.** That single PR is the change's only PR — no define/plan PRs, no
  per-unit PRs, no separate harvest.
- **More clarifying questions** / **Done for now**.

**Non-trivial change** — the default is to **stop after define**; `define.md` is a
natural ownership handoff (the WHAT is done; planning the HOW is engineering
work). Whether to fuse is the user's call, so ask:
- **Stop here and hand off** *(default)* — the **large-feature** shape: commit
  `define.md` and open its **own PR** (the WHAT, reviewable on its own), then stop.
  An engineer picks up by branching from there and running `br-plan`, whose
  `plan.md` becomes a separate PR. **If you are not an engineer, choose this** —
  owning the WHAT is yours, but planning and building are engineering work; hand
  the `define.md` to an engineer.
- **Fuse — continue into `br-plan` now** *(shortcut; engineer-driven)* — the
  **medium-feature** shape: flow straight into planning in this session with no
  gate. **Both `define.md` and `plan.md` are produced** — fusing removes the
  review gate, not the artifacts — and they land in a **single combined PR**
  (opened at the end of planning) instead of two. Pass the define path (and the
  grounding dossier path if one still exists) to `br-plan`. Choose only when an
  engineer is driving and the design is clear enough to plan in the same pass.
- **More clarifying questions** — return to Phase 1.3 and keep refining, then
  come back here.
- **Done for now** — stop; the definition is saved and can be resumed later.

Do not offer to write a spec as a separate step: in the loop specs are written at
the END (harvest); in the one-shot path the spec update rides in the change's own
PR.
