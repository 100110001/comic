---
name: br-plan
description: "Create structured plans for multi-step tasks -- software features, research workflows, events, study plans, or any goal that benefits from breakdown. Also deepens existing plans with interactive sub-agent review. Use when the user says 'plan this', 'create a plan', 'how should we build', 'break this down', or when a brainstorm doc is ready for planning. Use 'deepen the plan' or 'deepening pass' for the deepening flow. For exploratory requests, prefer br-define first."
argument-hint: "[optional: define.md path, change description, plan path to deepen, or any task to plan]"
---

<!-- DO NOT EDIT. Synced from brindlechute/playbook. Edit there and re-run sync.sh. -->

# Create Technical Plan

**Note: The current year is 2026.** Use this when dating plans and searching for recent documentation.

`br-define` defines **WHAT** to build. `br-plan` defines **HOW** to build it. `br-work` executes the plan. A prior brainstorm is useful context but never required — `br-plan` works from any input: a requirements doc, a bug report, a feature idea, or a rough description.

**When directly invoked, always plan.** Never classify a direct invocation as "not a planning task" and abandon the workflow. If the input is unclear, ask clarifying questions or use the planning bootstrap (Phase 0.4) to establish enough context — but always stay in the planning workflow.

This workflow produces an implementation plan — the **HOW** — as **disposable working scaffolding**, written into the change's working directory at `specs/changes/<slug>/plan.md`, alongside the `define.md` it builds on. It is not a spec and not a source of truth: it is deleted when the change is deemed complete (after the harvest step reconciles the specs). In this repo **specs are the source of truth** for existing design — read the relevant `*.spec.md` / `specs/*.convention.md` (start with the required-reading convention(s) named in the repo's AGENTS.md) while planning, and ground the plan in them.

This skill does **not** implement code, run tests, or learn from execution-time results. If the answer depends on changing code and seeing what happens, that belongs in `br-work`, not here.

## Interaction Method

When asking the user a question, use the platform's blocking question tool: `AskUserQuestion` in Claude Code (call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded), `request_user_input` in Codex, `ask_user` in Gemini, `ask_user` in Pi (requires the `pi-ask-user` extension). Fall back to numbered options in chat only when no blocking tool exists in the harness or the call errors (e.g., Codex edit modes) — not because a schema load is required. Never silently skip the question.

Ask one question at a time. Prefer a concise single-select choice when natural options exist.

## Feature Description

<feature_description> #$ARGUMENTS </feature_description>

**If the feature description above is empty, ask the user:** "What would you like to plan? Describe the task, goal, or project you have in mind." Then wait for their response before continuing.

If the input is present but unclear or underspecified, do not abandon — ask one or two clarifying questions, or proceed to Phase 0.4's planning bootstrap to establish enough context. The goal is always to help the user plan, never to exit the workflow.

**IMPORTANT: All file references in the plan document must use repo-relative paths (e.g., `src/models/user.rb`), never absolute paths (e.g., `/Users/name/Code/project/src/models/user.rb`). This applies everywhere — implementation unit file lists, pattern references, origin document links, and prose mentions. Absolute paths break portability across machines, worktrees, and teammates.**

## Core Principles

1. **Use requirements as the source of truth** - If `br-define` produced a requirements document, planning should build from it rather than re-inventing behavior.
2. **Decisions, not code** - Capture approach, boundaries, files, dependencies, and risks. Do not pre-write implementation code or shell command choreography. Pseudo-code sketches or DSL grammars that communicate high-level technical design are welcome when they help a reviewer validate direction — but they must be explicitly framed as directional guidance, not implementation specification.
3. **Research before structuring** - Explore the codebase, institutional learnings, and external guidance when warranted before finalizing the plan.
4. **Right-size the artifact** - Small work gets a compact plan. Large work gets more structure. The philosophy stays the same at every depth.
5. **Separate planning from execution discovery** - Resolve planning-time questions here. Explicitly defer execution-time unknowns to implementation.
6. **Keep the plan portable** - The plan should work as a living document, review artifact, or issue body without embedding tool-specific executor instructions.
7. **Carry execution posture lightly when it matters** - If the request, origin document, or repo context clearly implies test-first, characterization-first, or another non-default execution posture, reflect that in the plan as a lightweight signal. Do not turn the plan into step-by-step execution choreography.
8. **Honor user-named resources** - When the user names a specific resource — a CLI, MCP server, URL, file, doc link, or prior artifact — treat it as authoritative input, not a suggestion. Discover it if unknown (`command -v`, fetch, read) before assuming it's unavailable. Use it in place of generic alternatives. If it fails or doesn't exist, say so explicitly rather than silently substituting.

## Plan Quality Bar

Every plan should contain:
- A clear problem frame and scope boundary
- Concrete requirements traceability back to the request or origin document
- Repo-relative file paths for the work being proposed (never absolute paths — see Planning Rules)
- Decisions with rationale, not just tasks
- Existing patterns or code references to follow
- Clear dependencies and sequencing

Plans do **not** mandate tests. We do not care about unit tests, so the default
is no test scenarios and no test file paths (see "Testing posture" in the shared
spec conventions). Include them only for the rare unit where a test genuinely
earns its place and won't force the code to be more complex.

A plan is ready when an implementer can start confidently without needing the plan to write the code for them.

## Workflow

### Phase 0: Resume, Source, and Scope

#### 0.0 Output

The plan is always markdown, written into the change's working directory (Phase 5.2). There is no HTML mode and no config to read. Strip any `output:`/`mode:` token from `$ARGUMENTS` before treating the remainder as the description; other `<word>:<word>` tokens (e.g. `feat:`, `fix:`) pass through verbatim. Read `references/markdown-rendering.md` for format principles — it is paired with `references/plan-sections.md` (what the plan contains).

#### 0.1 Resume Existing Plan Work When Appropriate

If the user references an existing plan, or there is a matching `plan.md` under `specs/changes/`:
- Read it
- Confirm whether to update it in place or start fresh
- If updating, revise only the still-relevant sections. During implementation `br-work` marks each unit done in this file and keeps a `learnings.md` alongside it; git (branches/PRs) remains the ground truth for what shipped.

**Deepen intent:** "deepen" / "deepening" in reference to a plan is the primary trigger for the deepening fast path (Phase 5.3 in interactive mode). When the user says "deepen the plan", "run a deepening pass", or similar, the target is a **`plan.md`** under `specs/changes/`, not a `define.md`. Use any path or context the user provides to identify it; if a path is given, verify it is a plan; if the match is not obvious, confirm first.

Words like "strengthen", "confidence", "gaps", and "rigor" are NOT sufficient on their own — they appear in normal editing requests ("strengthen that section", "there are gaps in the test scenarios"). Only treat them as deepening intent when the request targets the plan as a whole and names no specific section, and even then prefer to confirm.

Once the plan is identified and appears complete (all major sections present, implementation units defined), short-circuit to Phase 5.3 (Confidence Check and Deepening) in **interactive mode** — this avoids re-running the full workflow and gives the user control over which findings are integrated. A non-software plan (a simple `# Title` heading with a `Created:` date and no YAML frontmatter) routes instead to `references/universal-planning.md` and does not use the software confidence check.

Normal editing requests (e.g., "update the test scenarios", "add a new implementation unit") follow the standard resume flow, not the fast path. If the plan already has a `deepened: YYYY-MM-DD` field and there is no explicit re-deepen request, the fast path still applies the same confidence-gap evaluation — it does not force deepening.

#### 0.1a Recognize Approach-Altitude Requests

Some requests are better answered one level up: produce a grounded **approach-plan** — a plan for *how the deliverable will be made* — and hold there, rather than zero-shotting the deliverable. This runs **after** Phase 0.1's resume and deepen fast paths (so "deepen the plan" and resume short-circuit first) and **before** Phase 0.1b's domain split (so the capability is domain-general — it applies to software and knowledge-work alike).

Two entries, with very different gating:

**Explicit (always honored, ungated).** When the user asks for the approach itself — "plan for a plan", "plan the approach", "plan how you'll do X", "don't do it yet -- just plan how you'd approach it" — enter approach altitude and hold at the approach. Do NOT begin the deliverable. Key on language that asks for *the approach to producing something*, not the something. This is a distinct signal from "deepen"/"strengthen" (the Phase 0.1 deepening fast path) and from a normal plan request.

**Proactive (rare, conservative).** When the user gives a plain request with no approach-language, offer an approach-plan **only when both of these are clearly high**:

- **Method uncertainty** — the *core* approach is genuinely unsettled: competing methodologies that would yield *different deliverables*, unclear how disparate sources or constraints combine, or an outcome stated only at the value level ("something I can actually use"). This is **not** satisfied by a task whose core method is obvious but whose *rollout, sequencing, scope, or ordering* has routine variants (big-bang vs. incremental, batch order, phased vs. one-shot) — those are ordinary plan decisions the Phase 0.7 scoping synthesis already surfaces as call-outs, not method-uncertainty. A large or mechanical change (a 40-endpoint migration, a wide rename, a framework bump) is typically **costly but method-obvious**; cost alone never fires the offer.
- **Cost of getting it wrong** — the deliverable is expensive or slow to produce and a wrong approach wastes real effort (heavy inputs to process, a long synthesis, a large or risky change).

If either is low, **stay silent and plan/do normally.** When borderline, stay silent. Assess this from request shape and input metadata only — do not read the inputs yet (recon happens after the offer is accepted). When the offer does fire, it is a **single dismissible line** naming the specific signal (e.g., "Three heavy sources are about to get synthesized and you might want them weighted differently -- want my approach first, or should I just go?") — never a blocking question, never a ceremony. Because the explicit path above is always available, a missed offer is cheap; the failure mode to avoid is the **new-hammer nag** — opening turns with "want me to plan the approach first?" when the method is obvious.

**Stay disjoint from the other approach surfaces (R16).** An investigative or analytical request with no approach-language and not-both-signals-high is NOT an approach-altitude request — it must pass through this gate untouched to Phase 0.1b, where answer-seeking's plan-of-attack handles it; the gate's earlier position must not intercept it. "Deepen the plan" and resume are already short-circuited by Phase 0.1. The Phase 0.7 / 5.1.5 scoping synthesis and the Phase 5.3 deepening pass operate on a deliverable already committed to; approach altitude operates *before* that commitment. Full distinctions: `references/approach-altitude.md`.

On entry (explicit, or an accepted offer), read `references/approach-altitude.md` and follow it. Otherwise continue to Phase 0.1b unchanged.

#### 0.1b Classify Task Domain

If the task asks to build, modify, refactor, deploy, or architect software (code, schemas, infrastructure), continue to Phase 0.2.

Classify by task-type, not topic. A request that merely *references* code, a repo, an API, or a database is not automatically software work: building or modifying code is software; investigating or analyzing it is an answer-seeking question. "How often does X star repos — is it a big deal?" or "how does our approach compare to Y?" route to `references/universal-planning.md` (answer-seeking), not the implementation-plan path.

If the domain is genuinely ambiguous (e.g., "plan a migration" with no other context), ask the user before routing.

Otherwise, read `references/universal-planning.md` and follow that workflow instead. Skip all subsequent phases. Named tools or source links don't change this routing — they're inputs, handled per Core Principle 8.

#### 0.2 Find Upstream Definition Doc

Before asking planning questions, locate the change's `define.md` — either the path the user passed, or the most recent/relevant `specs/changes/<slug>/define.md`. This is the upstream definition doc (the **WHAT**) carried as the plan's `origin:`, and the plan is written into that same `specs/changes/<slug>/` directory.

**Relevance criteria:** A requirements document is relevant if:
- The topic semantically matches the feature description
- It was created within the last 30 days (use judgment to override if the document is clearly still relevant or clearly stale)
- It appears to cover the same user problem or scope

If multiple source documents match, ask which one to use using the platform's blocking question tool when available (see Interaction Method). Otherwise, present numbered options in chat and wait for the user's reply before proceeding.

#### 0.3 Use the Source Document as Primary Input

If a relevant requirements document exists:
1. Read it thoroughly
2. Announce that it will serve as the origin document for planning
3. Carry forward all of the following:
   - Problem frame
   - Actors (A-IDs), Key Flows (F-IDs), and Acceptance Examples (AE-IDs) when present — preserve these as constraints that implementation units must honor
   - Requirements and success criteria
   - Scope boundaries (including "Deferred for later" and "Outside this product's identity" subsections when present)
   - Key decisions and rationale
   - Dependencies or assumptions
   - Outstanding questions, preserving whether they are blocking or deferred
4. Use the source document as the primary input to planning and research
5. Reference important carried-forward decisions in the plan with `(see origin: <source-path>)`
6. Do not silently omit source content — if the origin document discussed it, the plan must address it even if briefly. Before finalizing, scan each section of the origin document to verify nothing was dropped.

If no relevant requirements document exists, planning may proceed from the user's request directly.

#### 0.4 Planning Bootstrap (No Requirements Doc or Unclear Input)

If no relevant requirements document exists, or the input needs more structure:
- Assess whether the request is already clear enough for direct technical planning — if so, continue to Phase 0.5
- If the ambiguity is mainly product framing, user behavior, or scope definition, recommend `br-define` as a suggestion — but always offer to continue planning here as well
- If the user wants to continue here (or was already explicit about wanting a plan), run the planning bootstrap below

The planning bootstrap should establish:
- Problem frame
- Intended behavior
- Scope boundaries and obvious non-goals
- Success criteria
- Blocking questions or assumptions

Keep this bootstrap brief. It exists to preserve direct-entry convenience, not to replace a full brainstorm.

If the bootstrap uncovers major unresolved product questions:
- Recommend `br-define` again
- If the user still wants to continue, require explicit assumptions before proceeding

If the bootstrap reveals that a different workflow would serve the user better:

- **Bug-shaped prompt** (user describes broken behavior — "fix the bug where X", error message, regression, "doesn't work"). Surface `ce-debug` as a route-out option alongside continuing with `br-plan` whenever the bug surface is reachable (in cwd OR named repo found at another local path). Stay in `br-plan` silently when the named code can't be found anywhere local — paper-planning is the only useful output for unreachable surfaces.

  **When the bug is at another local path (not cwd):**
  - Announce the target explicitly **before** any cross-repo investigation: which path will be read AND where plan outputs will land (default: the target repo's `specs/changes/`, not cwd's).
  - Default: proceed from the target repo for both investigation and plan-write. The user can interrupt to redirect (switch context, paper-plan, abandon, etc.). No location menu — the announcement makes the cross-repo nature visible, and the user can speak up if they want something unusual.
  - **After** announcing and proceeding, fire the standard ce-debug routing menu (continue with `br-plan` vs switch to `ce-debug`) — same shape as the in-cwd case. Cross-repo location and ce-debug skill routing are orthogonal decisions; do not merge them into a single question.

  Reading code at another path is fine in principle — that's just file access. The harm to avoid is silent operation on the wrong repo, especially writing the plan doc somewhere it won't be discovered (a plan landing in another repo's `specs/changes/` is a discoverability disaster). The announcement requirement makes the target visible; defaulting to the target repo for both investigation and outputs respects the user's stated intent (they named that repo); the orthogonal ce-debug menu keeps the skill-choice question clean.

  The accessibility classification is conservative and may under-suggest in monorepos, dependency bugs, or after renames. Users can always invoke `/ce-debug` manually.

  **Headless mode**: skip the ce-debug suggestion menu entirely; default to continuing with `/br-plan` (the user's explicit invocation). There is no synchronous user to resolve a route-out choice, and auto-routing to ce-debug would change the skill mid-flight without authorization.

- **Clear task ready to execute** (known root cause, obvious fix, no architectural decisions) — suggest `br-work` as a faster alternative alongside continuing with planning. The user decides.

#### 0.5 Classify Outstanding Questions Before Planning

If the origin document contains `Resolve Before Planning` or similar blocking questions:
- Review each one before proceeding
- Reclassify it into planning-owned work **only if** it is actually a technical, architectural, or research question
- Keep it as a blocker if it would change product behavior, scope, or success criteria

If true product blockers remain:
- Surface them clearly
- Ask the user, using the platform's blocking question tool when available (see Interaction Method), whether to:
  1. Resume `br-define` to resolve them
  2. Convert them into explicit assumptions or decisions and continue
- Do not continue planning while true blockers remain unresolved

#### 0.6 Assess Plan Depth

Classify the work into one of these plan depths:

- **Lightweight** - small, well-bounded, low ambiguity
- **Standard** - normal feature or bounded refactor with some technical decisions to document
- **Deep** - cross-cutting, strategic, high-risk, or highly ambiguous implementation work

If depth is unclear, ask one targeted question and then continue.

#### 0.7 Solo-Mode Scoping Synthesis

Surface call-outs to the user — the specific forks in scope or approach where user input materially changes the plan — so scope can be corrected **before Phase 1 research is spent**. Sub-agent dispatch (repo-research-analyst, learnings-researcher, etc.) is the expensive next step this phase guards against wasted effort on.

Fires **only in solo invocation** — when Phase 0.2 found no upstream brainstorm doc AND Phase 0.4 stayed in br-plan (did not route to ce-debug, br-work, or universal-planning) AND Phase 0.5 cleared (no unresolved blockers) AND not on Phase 0.1 fast paths (resume normal, deepen-intent). Each guard is an explicit conditional. Skip Phase 0.7 entirely when any guard fails — brainstorm-sourced invocations defer to Phase 5.1.5 instead.

**Read `references/synthesis-summary.md` before composing the scoping synthesis.** It carries the affirmability test, keep-test criteria, detail test, summary shape budgets, granularity rules, anti-patterns, revision-vs-confirmation discipline, doc-shape routing, soft-cut behavior, self-redirect support, the worked PII compression example, and full headless-mode routing — all required for a well-shaped synthesis.

**Required gate output — do not skip; silent proceeding is not allowed.** Compose an internal three-bucket scope draft (Stated / Inferred / Out of scope — internal thinking that feeds plan-body routing at Phase 5.2, not the chat output below). Derive call-outs (specific forks where user input materially changes the plan), then emit one of the two literal templates below in chat before continuing to Phase 1.

**Synthesis is pre-plan-write.** The agent does NOT yet know how plan-write will sequence the work. Do not claim PR count ("one PR"), commit/branch shape, effort or time estimates, Implementation Unit boundaries, or exact file paths in the synthesis. The synthesis surfaces decisions knowable at THIS point — for the solo variant, that's the user's request plus the Phase 0.4 bootstrap dialogue plus the agent's own internal three-bucket draft. Phase 1 research has not happened yet and there is no upstream brainstorm; do not claim grounding from either. Plan-write produces the rest. This rule holds even when the agent has formed plan-write opinions earlier in the session — those stay internal until plan-write.

**Summary shape:** the summary is a **scope claim** — what the plan will target, what it will not — at affirm-or-redirect level. NOT an enumeration of Implementation Units. Form is prose, bullets, or mix; tier budgets are **ceilings, not targets** (Lightweight 1-3 lines; Standard up to 3-5 lines or 2-4 bullets; Deep up to 4-6 lines or 3-6 bullets). 1-2 lines per bullet, conversational not documentary. Less is correct when there isn't more to say. See reference for keep test, detail test, and source-vocabulary discipline.

**Do NOT enumerate the touch surface.** Sentences like "The touch surface is...", "This plan touches...", "The implementation reaches into..." are plan-pitch leaks. File paths, module names, directory introductions, and per-file change descriptions belong in the plan body (Implementation Units at Phase 5.2), not the synthesis. The synthesis names *what* the plan targets, not *where* the code lives.

**Pre-emit scans.** Before emitting the synthesis, scan the output:
- Bare ID references (`AE\d+`, `R\d+`, `F\d+`, `A\d+`, `U\d+`) → replace with plain names.
- File paths (`path/like.md`, `path/like.py`, etc.) → cut unless the path IS the topic of an explicit fork in the call-outs.

**Tier guard on auto-proceed:** the auto-proceed path (announce without waiting for confirmation) fires only when plan depth is **Lightweight AND zero call-outs survive**. Standard and Deep plans always fire the confirmation gate, even with zero call-outs — substance earns the checkpoint, not interaction history.

**Confirmation template (Standard/Deep regardless of call-out count, or any tier with one or more call-outs surviving):**

````text
Based on your request and our brief discussion, here's the scope I'm proposing to plan against:

[scope claim — what the plan will target, what it will not; affirm-or-redirect level; NOT an enumeration of Implementation Units]

**Call outs:** (omit this header when zero forks survived the keep test)
- [decision-level fork in 1-2 lines: name the choice and optional one-clause trade-off in parens. NO multi-sentence rationale, NO "my default is X" pitch]

Confirm and I'll proceed to research, drawing on this scope. (You can also redirect to /br-define if this is bigger than you initially thought — I'll stop here and load it for you.)
````

Wait for user confirmation before continuing to Phase 1.

**Auto-proceed template (Lightweight with zero call-outs only):**

````text
Planning: [1-3 line scope claim]

No open decisions to weigh in on — proceeding to research. Interrupt if I have the scope wrong.
````

Then continue to Phase 1 without a blocking question.

**Headless mode**: internal draft is composed but stage 2 (chat-time call-outs) is skipped — no synchronous user to confirm to. Continue to Phase 1 research as normal. At plan-write time (Phase 5.2), Inferred bets from the internal draft route to a `## Assumptions` section in the plan instead of Key Technical Decisions. See `references/synthesis-summary.md` Headless mode for the full routing.

### Phase 1: Gather Context

All specialist research and deepening prompts used in this phase are skill-local prompt assets under `references/agents/`. When dispatching one, read the matching file and seed a generic subagent with that prompt content plus the task-specific context below. Do not dispatch standalone agents by type/name.

Model tiering lives in this caller, not in prompt assets. Local prompt files have no frontmatter. Use the platform's mid-tier model for external/organizational research prompts such as `slack-researcher` and `web-researcher` when the current harness exposes a known override; otherwise omit the override and inherit. Use inherited model for high-judgment architecture, migration, and planning-deepening prompts unless the harness has an established cheaper capable tier.

#### 1.1 Local Research (Always Runs)

Prepare a concise planning context summary (a paragraph or two) to pass as input to the research agents:
- If an origin document exists, summarize the problem frame, requirements, and key decisions from that document
- Otherwise use the feature description directly
- Read the relevant **spec files** — `*.spec.md` next to the code and at module roots, feature specs under `specs/`, and `specs/*.convention.md` (start with the required-reading convention(s) named in the repo's AGENTS.md). In this repo specs are the source of truth for existing design; include the relevant invariants, contracts, and domain terms in the summary so research and planning are anchored to them, and plan with those terms rather than synonyms.

Run these agents in parallel:

- `references/agents/repo-research-analyst.md` — scope: technology, architecture, patterns. Pass the planning context summary.
- `references/agents/learnings-researcher.md` — pass the planning context summary.

**Agent-native planning triage** (conditional) — consider broadly, dispatch selectively. Dispatch a generic subagent with `references/agents/agent-native-planning-strategist.md` in parallel with the local research agents when the request, origin document, or repo research indicates any of:

- agent, assistant, chat, workflow automation, MCP, plugin, skill, tool registry, prompt, or autonomous-loop work
- a codebase with an existing agent surface where this feature changes user-visible capabilities
- a primary domain action that is repetitive, high-volume, complex, naturally language-shaped, or likely to need automation access
- a risk that the plan will widen the gap between UI/API actions and agent-accessible tools or context

Do **not** dispatch for cosmetic, layout-only, animation-only, brand, low-value preference, or narrow work in a product with no agent surface. If the signal is borderline, do not dispatch; carry only a short future parity consideration when it affects a high-value domain action. Include any resulting findings in consolidation as planning inputs, not as a standalone advice appendix.

Collect:
- Technology stack and versions (used in section 1.2 to make sharper external research decisions)
- Architectural patterns and conventions to follow
- Implementation patterns, relevant files, modules, and tests
- `AGENTS.md` guidance that materially affects the plan
- Existing design intent, invariants, and contracts from the relevant spec files (`*.spec.md`, `specs/*.convention.md`)
- Spec alignment — flag any plan decision that would contradict an existing spec's invariants or contracts. Specs are the source of truth: either the plan conforms, or the change must update that spec at the harvest step (record it in Spec Impact)
- Agent-native planning findings when the conditional triage dispatched: action/context parity decisions, tool/workspace/execution-lifecycle choices, scope boundaries, and verification scenarios

**Slack context** (opt-in) — never auto-dispatch. Route by condition:

- **Tools available + user asked**: Dispatch a generic subagent with `references/agents/slack-researcher.md` and the planning context summary in parallel with other Phase 1.1 agents. If the origin document has a Slack context section, pass it verbatim so the researcher focuses on gaps. Include findings in consolidation.
- **Tools available + user didn't ask**: Note in output: "Slack tools detected. Ask me to search Slack for organizational context at any point, or include it in your next prompt."
- **No tools + user asked**: Note in output: "Slack context was requested but no Slack tools are available. Install and authenticate the Slack plugin to enable organizational context search."

#### 1.1b Detect Execution Posture Signals

Decide whether the plan should carry a lightweight execution posture signal.

Look for signals such as:
- The user explicitly asks for TDD, test-first, or characterization-first work
- The origin document calls for test-first implementation or exploratory hardening of legacy code
- Local research shows the target area is legacy, weakly tested, or historically fragile, suggesting characterization coverage before changing behavior

When the signal is clear, carry it forward silently in the relevant implementation units.

Ask the user only if the posture would materially change sequencing or risk and cannot be responsibly inferred.

#### 1.2 Decide on External Research

Based on the origin document, user signals, and local findings, decide **whether** external research adds value and, if so, **what kind**. Resolve this in three stages: explicit-request priority, intent classification, then the implicit signals below.

**Stage 1 — An explicit request takes precedence.** If the user prompt **or** the origin requirements document explicitly asks for external input — a signal that the answer lives outside the repo, such as competitor/prior-art comparison, "what should we borrow", "from the web", "best practices", "official docs", "alternatives to", a market scan, or naming a specific external technology to consult — external research is **required**, regardless of how strong local patterns look. The list is illustrative; key on the signal, not the exact phrase — any wording that clearly points outside the repo qualifies. The skip conditions below do **not** apply to an explicit request. The only thing that overrides it is an explicit opt-out ("no web research", "skip external research"): honor that, skip, and note it. Improvement or quality verbs ("improve", "make better") carry no external signal on their own and never trigger research by themselves.

**Stage 2 — Classify the research intent** (whenever external research will run, from Stage 1 or the implicit signals below) so Phase 1.3 routes correctly. Use this mechanical test, not a fixed phrase list:
- **Implementation-guidance** — the approach or technology is already settled; the question is *how to build it well* (best practices, version-specific docs, API constraints, known pitfalls, deprecations).
- **Landscape / option-discovery** — the question is *what options or prior art exist* (competitor scans, build-vs-buy, library/provider selection, prior art, market signals, cross-domain analogies).
- **Mixed** — both: discover an unsettled external option set first, then research the shortlisted choice for implementation guidance.

**Stage 3 — Implicit signals** decide the call when no explicit request fired.

**Read between the lines.** Pay attention to signals from the conversation so far:
- **User familiarity** — Are they pointing to specific files or patterns? They likely know the codebase well.
- **User intent** — Do they want speed or thoroughness? Exploration or execution?
- **Topic risk** — Security, payments, external APIs warrant more caution regardless of user signals.
- **Uncertainty level** — Is the approach clear or still open-ended?

**Leverage the repo research prompt's technology context:**

The `repo-research-analyst` local prompt output includes a structured Technology & Infrastructure summary. Use it to make sharper external research decisions:

- If specific frameworks and versions were detected (e.g., Rails 7.2, Next.js 14, Go 1.22), pass those exact identifiers to the `framework-docs-researcher` local prompt so it fetches version-specific documentation
- If the feature touches a technology layer the scan found well-established in the repo (e.g., existing Sidekiq jobs when planning a new background job), lean toward skipping external research -- local patterns are likely sufficient
- If the feature touches a technology layer the scan found absent or thin (e.g., no existing proto files when planning a new gRPC service), lean toward external research -- there are no local patterns to follow
- If the scan detected deployment infrastructure (Docker, K8s, serverless), note it in the planning context passed to downstream agents so they can account for deployment constraints
- If the scan detected a monorepo and scoped to a specific service, pass that service's tech context to downstream research agents -- not the aggregate of all services. If the scan surfaced the workspace map without scoping, use the feature description to identify the relevant service before proceeding with research

**Always lean toward external research when:**
- The topic is high-risk: security, payments, privacy, external APIs, migrations, compliance
- The codebase lacks relevant local patterns -- fewer than 3 direct examples of the pattern this plan needs
- Local patterns exist for an adjacent domain but not the exact one -- e.g., the codebase has HTTP clients but not webhook receivers, or has background jobs but not event-driven pub/sub. Adjacent patterns suggest the team is comfortable with the technology layer but may not know domain-specific pitfalls. When this signal is present, frame the external research query around the domain gap specifically, not the general technology
- The user is exploring unfamiliar territory
- The technology scan found the relevant layer absent or thin in the codebase
- The plan's recommendations depend on a genuinely external, **unsettled** option set — which library, provider, or approach to adopt, or what competitors and prior art do — **even when local implementation patterns are strong** (intent: landscape). Bound this implicit landscape trigger by three gates: (a) the option set genuinely lives outside the repo, (b) the decision materially shapes the plan (a KTD, dependency, or architecture choice — not an incidental detail), and (c) no settled local or team choice already exists. Improvement verbs alone never satisfy this.

**Skip external research when** (only when Stage 1 found no explicit request — an explicit request is never skipped):
- The codebase already shows a strong local pattern -- multiple direct examples (not adjacent-domain), recently touched, following current conventions
- The user already knows the intended shape
- Additional external context would add little practical value
- The technology scan found the relevant layer well-established with existing examples to follow

When an explicit request *did* fire but a settled local or team choice already exists, **narrow the research rather than skipping it** — research the current pitfalls, docs, and practices for the chosen library/pattern instead of re-surveying the whole option set.

Announce the decision and the intent briefly before continuing. Examples:
- "Your codebase has solid patterns for this. Proceeding without external research."
- "This involves payment processing, so I'll research current best practices first (implementation-guidance)."
- "You asked what to borrow from competitors, so I'll run a landscape scan first (landscape/option-discovery)."

#### 1.3 External Research (Conditional)

If Step 1.2 indicates external research is useful, dispatch by the **intent** classified in Stage 2, using the platform's subagent primitive (`Agent`/`Task` in Claude Code, `spawn_agent` in Codex) where available; otherwise run the work inline or serially. Read the selected prompt asset from `references/agents/` and seed a generic subagent with it. For `web-researcher.md`, pass a focus hint plus the planning context summary and do **not** pass codebase content — it operates externally.

- **Implementation-guidance** — run in parallel:
  - `references/agents/best-practices-researcher.md` with the planning context summary.
  - `references/agents/framework-docs-researcher.md` with the planning context summary and exact frameworks/versions from Phase 1.1 where available.
- **Landscape / option-discovery** — `references/agents/web-researcher.md` with the focus hint and planning context summary. When the request targets projects on a code host (e.g., "competitors on GitHub"), name the discovery dimensions in the focus hint: project names and URLs, release recency and activity, CLI/UX shape, install path, docs and examples, plugin/extension surfaces, recurring issue themes, and license — treating star counts as a weak signal only.
- **Mixed** — **sequential, not parallel**: run the `web-researcher` local prompt first to map the landscape and produce a shortlist; then run the `framework-docs-researcher` and/or `best-practices-researcher` local prompts against the shortlisted technologies only when their details materially shape the plan.

**Tool-unavailable handling.** `web-researcher` self-checks for web tools and stops if they are missing. Never block on this: if it reports research unavailable, or any researcher fails, warn and proceed, and carry the gap into Phase 1.4 so the plan records it honestly — especially when the user explicitly requested external research, where a silent skip would leave the plan looking evidence-based when it is not.

#### 1.4 Consolidate Research

Summarize:
- Relevant codebase patterns and file paths
- Relevant institutional learnings
- Organizational context from Slack conversations, if gathered (prior discussions, decisions, or domain knowledge relevant to the feature)
- External references, prior art, competitor/landscape findings, and best practices, if gathered
- Related issues, PRs, or prior art
- Any constraints that should materially shape the plan

**Land external findings in decisions, not an appendix.** Any external research that ran must surface where it changes a choice — Key Technical Decisions rationale, Alternatives, Risks, or Sources & Research — not as a detached list with no bearing on the plan. If a finding shaped nothing, it was not load-bearing; do not pad the plan with it.

**Mark whether external research was load-bearing.** Record a single internal flag: did external findings materially shape a KTD, Alternative, Scope boundary, or Risk? This flag answers only that question — it does **not** gate whether research runs (Phase 1.2 owns that decision). Phase 5.3.2 reads it to decide whether to enter a confidence-scoring pass.

**Record requested-but-unavailable.** If the user explicitly requested external research but it could not run (web tools unavailable, researcher failed), state that in the plan as an assumption or open question rather than presenting the plan as externally grounded.

#### 1.4b Reclassify Depth When Research Reveals External Contract Surfaces

If the current classification is **Lightweight** and Phase 1 research found that the work touches any of these external contract surfaces, reclassify to **Standard**:

- Environment variables consumed by external systems, CI, or other repositories
- Exported public APIs, CLI flags, or command-line interface contracts
- CI/CD configuration files (`.github/workflows/`, `Dockerfile`, deployment scripts)
- Shared types or interfaces imported by downstream consumers
- Documentation referenced by external URLs or linked from other systems

This ensures flow analysis (Phase 1.5) runs and the confidence check (Phase 5.3) applies critical-section bonuses. Announce the reclassification briefly: "Reclassifying to Standard — this change touches [environment variables / exported APIs / CI config] with external consumers."

#### 1.5 Flow and Edge-Case Analysis (Conditional)

For **Standard** or **Deep** plans, or when user flow completeness is still unclear, run:

- `references/agents/spec-flow-analyzer.md` with the planning context summary and research findings.

Use the output to:
- Identify missing edge cases, state transitions, or handoff gaps
- Tighten requirements trace or verification strategy
- Add only the flow details that materially improve the plan

### Phase 2: Resolve Planning Questions

Build a planning question list from:
- Deferred questions in the origin document
- Gaps discovered in repo or external research
- Technical decisions required to produce a useful plan

For each question, decide whether it should be:
- **Resolved during planning** - the answer is knowable from repo context, documentation, or user choice
- **Deferred to implementation** - the answer depends on code changes, runtime behavior, or execution-time discovery

Ask the user only when the answer materially affects architecture, scope, sequencing, or risk and cannot be responsibly inferred. Use the platform's blocking question tool when available (see Interaction Method).

**Do not** run tests, build the app, or probe runtime behavior in this phase. The goal is a strong plan, not partial execution.

### Phase 3: Structure the Plan

#### 3.1 Title and File Naming

- Draft a clear, searchable title using conventional format such as `feat: Add user authentication` or `fix: Prevent checkout double-submit`
- Determine the plan type: `feat`, `fix`, or `refactor`
- The plan is written to `plan.md` inside the change's working directory: `specs/changes/<YYYY-MM-DD-slug>/plan.md` — the same directory as the `define.md` it builds on. If `br-define` already created that directory, reuse it; otherwise create `specs/changes/<YYYY-MM-DD-slug>/` (short kebab-case slug, 3-5 words).
  - One plan per change directory — the file is always named `plan.md`, with no date or sequence prefix (the directory already carries the date and slug).
  - The title drafted above lives inside the document; it does not affect the filename.

#### 3.2 Stakeholder and Impact Awareness

For **Standard** or **Deep** plans, briefly consider who is affected by this change — end users, developers, operations, other teams — and how that should shape the plan. For cross-cutting work, note affected parties in the System-Wide Impact section.

#### 3.3 Break Work into Implementation Units

Break the work into logical implementation units. Each unit should represent one meaningful change that an implementer could typically land as an atomic commit.

Good units are:
- Focused on one component, behavior, or integration seam
- Usually touching a small cluster of related files
- Ordered by dependency
- Concrete enough for execution without pre-writing code

Avoid:
- 2-5 minute micro-steps
- Units that span multiple unrelated concerns
- Units that are so vague an implementer still has to invent the plan

Each unit carries a stable plan-local **U-ID** assigned in Phase 3.5 (`U1`, `U2`, …). U-IDs survive reordering, splitting, and deletion: new units take the next unused number, gaps are fine, and existing IDs are never renumbered. This lets `br-work` reference units unambiguously across plan edits.

#### 3.4 High-Level Technical Design

When the plan's technical approach has shape that prose alone doesn't carry well — architecture across components, sequencing across processes, state machines, branching gates, lifecycles, quantitative comparisons — include a High-Level Technical Design section that conveys the shape. The exact form (component diagram, sequence, swim lane, flowchart, state machine, decision matrix, pseudo-code grammar, bar chart for sizing concerns) is the agent's call per artifact — pick what makes the content land fastest for the reader.

See `references/plan-sections.md` for the section catalog including HTD's "include when material" criterion. See `references/markdown-rendering.md` for how visualizations render (mermaid diagrams in markdown).

When the plan's approach is a one-paragraph pattern application that prose conveys directly, skip the section. The presence of HTD should earn its keep with content that genuinely benefits from visualization.

Plan diagrams render authoritative content alongside the prose — they are not "directional sketches." Do not add hedging captions like *"directional guidance for review, not implementation specification"* to plan diagrams; the prose-is-authoritative rule already governs disagreement, and the hedging weakens the diagram unnecessarily.

#### 3.4b Output Structure (Optional)

For greenfield plans that create a new directory structure (new plugin, service, package, or module), include an `## Output Structure` section with a file tree showing the expected layout. This gives reviewers the overall shape before diving into per-unit details.

**When to include it:**
- The plan creates 3+ new files in a new directory hierarchy
- The directory layout itself is a meaningful design decision

**When to skip it:**
- The plan only modifies existing files
- The plan creates 1-2 files in an existing directory — the per-unit file lists are sufficient

The tree is a scope declaration showing the expected output shape. It is not a constraint — the implementer may adjust the structure if implementation reveals a better layout. The per-unit `**Files:**` sections remain authoritative for what each unit creates or modifies.

#### 3.5 Define Each Implementation Unit

Each unit is a level-3 heading carrying a stable U-ID prefix matching the format used for R/A/F/AE in requirements docs: `### U1. [Name]`. Number sequentially within the plan starting at U1. Do not render units as bulleted list items or prefix them with `- [ ]` / `- [x]` checkbox markers. List-based unit titles fragment in every standard renderer because the per-unit fields (`**Goal:**`, `**Files:**`, `**Approach:**`, etc.) are written flush-left, which terminates CommonMark list continuation and detaches the fields from the unit they describe. Headings render correctly everywhere, are the right semantic match for sections containing multi-block content, and give each unit an anchor link. The plan is a decision artifact; execution progress is derived from git by `br-work` rather than stored in the plan body.

**Stability rule.** Once assigned, a U-ID is never renumbered. Reordering units leaves their IDs in place (e.g., U1, U3, U5 in their new order is correct; renumbering to U1, U2, U3 is not). Splitting a unit keeps the original U-ID on the original concept and assigns the next unused number to the new unit. Deletion leaves a gap; gaps are fine. This rule matters most during deepening (Phase 5.3), which is the most likely accidental-renumber vector.

For each unit, include:
- **Goal** - what this unit accomplishes
- **Requirements** - which requirements or success criteria it advances (cite R-IDs, and A/F/AE IDs when origin supplies them)
- **Dependencies** - what must exist first (cite by U-ID, e.g., "U1, U3")
- **Files** - repo-relative file paths to create, modify, or test (never absolute paths)
- **Approach** - key decisions, data flow, component boundaries, or integration notes
- **Execution note** - optional, only when the unit benefits from a non-default execution posture such as test-first or characterization-first
- **Technical design** - optional pseudo-code or diagram when the unit's approach is non-obvious and prose alone would leave it ambiguous. Frame explicitly as directional guidance, not implementation specification
- **Patterns to follow** - existing code or conventions to mirror
- **Test scenarios** - optional and off by default. We do not care about unit tests, so omit this field for almost every unit. Include it only when a test genuinely earns its place — a tricky invariant or a high-value integration path the user asked to cover — and writing it won't force the code to be more complex. When you do include it, name the input, action, and expected outcome for each scenario. See "Testing posture" in the shared spec conventions.
- **Verification** - how an implementer should know the unit is complete, expressed as outcomes rather than shell command scripts

Use `Execution note` sparingly. Good uses include:
- `Execution note: Start with a failing integration test for the request/response contract.`
- `Execution note: Add characterization coverage before modifying this legacy parser.`
- `Execution note: Implement new domain behavior test-first.`

Do not expand units into literal `RED/GREEN/REFACTOR` substeps.

#### 3.6 Keep Planning-Time and Implementation-Time Unknowns Separate

If something is important but not knowable yet, record it explicitly under deferred implementation notes rather than pretending to resolve it in the plan.

Examples:
- Exact method or helper names
- Final SQL or query details after touching real code
- Runtime behavior that depends on seeing actual test failures
- Refactors that may become unnecessary once implementation starts

#### 3.7 Anti-Expansion: Tangential Cleanup and Scope Creep Go to Deferred

Distinct from 3.6 (which is about *unknowns* at plan time): 3.7 is about *known but tangential* work that the agent notices while planning but that falls outside the user's confirmed scope. When research surfaces an adjacent refactor, a "while we're here" cleanup, or a scope-adjacent nice-to-have ("we could also add rate limiting"), route it to the existing `### Deferred to Follow-Up Work` subsection in Scope Boundaries (Phase 4.2 Core Plan Template), not into active Implementation Units.

This reinforces the synthesis discipline established at Phase 0.7 / Phase 5.1.5 — the user's confirmed scope is what the active plan executes; everything else is deferred. Does NOT impose architectural bias on extend-vs-invent decisions within confirmed scope — that judgment stays with the agent (and is surfaced via the Phase 5.1.5 synthesis when material). The user's explicit ask overrides this default — if the user explicitly requested a refactor, it's in-scope, not deferred.

#### 3.8 Spec Impact (harvest seed)

Because specs are written at the **END** of the loop (back-gate), the plan must record **which spec files the harvest step will create or update** when the change is deemed complete. This is the forcing function that keeps spec reconciliation from being forgotten: the change is not done until these specs are written.

Include a `## Spec Impact` section in the plan that lists, for each affected spec:
- the spec file path — an existing `*.spec.md` / `specs/*.convention.md`, or a new one to create
- whether it is **new**, **updated**, or a **convention** note
- a one-line note on the design intent / invariant / contract the harvest step will record there — in goals-and-intent terms, not mechanics

Derive these from the Implementation Units and the Phase 1 spec-alignment flags: any unit that establishes new behavior, changes an existing invariant or contract, or touches an area with no spec yet produces a Spec Impact entry. Mechanics that won't matter post-hoc (intermediate fields, renames, migration choreography) do **not** belong here — only the durable design facts the spec will carry. If the change genuinely alters no design intent (e.g. a pure refactor with no behavioral or contract change), state that explicitly: `Spec Impact: none — no design intent changes.`

### Phase 4: Write the Plan

**NEVER CODE during this skill.** Research, decide, and write the plan — do not start implementation.

Use one planning philosophy across all depths. Change the amount of detail, not the boundary between planning and execution.

#### 4.1 Plan Depth Guidance

**Lightweight**
- Keep the plan compact
- Usually 2-4 implementation units
- Omit optional sections that add little value

**Standard**
- Use the full core template, omitting optional sections (including High-Level Technical Design) that add no value for this particular work
- Usually 3-6 implementation units
- Include risks, deferred questions, and system-wide impact when relevant

**Deep**
- Use the full core template plus optional analysis sections where warranted
- Usually 4-8 implementation units
- Group units into phases when that improves clarity
- Include alternatives considered, documentation impacts, and deeper risk treatment when warranted

#### 4.1b Optional Deep Plan Extensions

For sufficiently large, risky, or cross-cutting work, add the sections that genuinely help:
- **Alternative Approaches Considered**
- **Success Metrics**
- **Dependencies / Prerequisites**
- **Risk Analysis & Mitigation**
- **Phased Delivery**
- **Documentation Plan**
- **Operational / Rollout Notes**
- **Future Considerations** only when they materially affect current design

Do not add these as boilerplate. Include them only when they improve execution quality or stakeholder alignment.

**Alternatives Considered — what to vary.** When this section is included, alternatives must differ on *how* the work is built: architecture, sequencing, boundaries, integration pattern, rollout strategy. Tiny implementation variants (which hash function, which serialization format) belong in Key Technical Decisions, not Alternatives. Product-shape alternatives (different actors, different core outcome, different positioning) belong in `br-define`, not here — surface them back upstream rather than re-litigating product questions during planning.

#### 4.2 Section Contract and Rendering

Compose the plan using two paired references:

- `references/plan-sections.md` — the section contract. Describes what the plan contains: the outcome the plan must enable for downstream consumers, the hard floor (Summary, Problem Frame, Requirements, KTDs, Implementation Units), the include-when-material catalog (HTD, Scope Boundaries, Open Questions, System-Wide Impact, Risks & Dependencies, Acceptance Examples, Documentation/Operational Notes, Sources & Research), the agency-driven escape hatch (introduce new sections when content warrants), and the ID/content rules.
- `references/markdown-rendering.md` — how to present the sections in markdown.

The section catalog is the same regardless of format. Format-specific principles (table-vs-prose by content shape, ID prefix format, diagram rendering, etc.) live in the rendering reference.

Omit "include when material" sections that don't carry information for this specific plan. Filling a section with placeholder prose is worse than omitting it.

#### 4.3 Planning Rules

- **Horizontal rules (`---`) between top-level sections** in Standard and Deep plans, mirroring the `br-define` requirements doc convention. Improves scannability of dense plans where many H2 sections sit close together. Omit for Lightweight plans where the whole doc fits on a single screen.
- **All file paths must be repo-relative** — never use absolute paths like `/Users/name/Code/project/src/file.ts`. Use `src/file.ts` instead. Absolute paths make plans non-portable across machines, worktrees, and teammates. When a plan targets a different repo than the document's home, state the target repo once at the top of the plan (e.g., `**Target repo:** my-other-project`) and use repo-relative paths throughout
- Prefer path plus class/component/pattern references over brittle line numbers
- Do not include implementation code — no imports, exact method signatures, or framework-specific syntax
- Pseudo-code sketches and DSL grammars are allowed in the High-Level Technical Design section and per-unit technical design fields when they communicate design direction. Frame them explicitly as directional guidance, not implementation specification
- Mermaid diagrams are encouraged when they clarify relationships or flows that prose alone would make hard to follow — ERDs for data model changes, sequence diagrams for multi-service interactions, state diagrams for lifecycle transitions, flowcharts for complex branching logic
- Do not include git commands, commit messages, or exact test command recipes
- Do not expand implementation units into micro-step `RED/GREEN/REFACTOR` instructions
- Do not pretend an execution-time question is settled just to make the plan look complete

### Phase 5: Final Review, Write File, and Handoff

#### 5.1 Review Before Writing

Before finalizing, check:
- The plan does not invent product behavior that should have been defined in `br-define`
- If there was no origin document, the bounded planning bootstrap established enough product clarity to plan responsibly
- Every major decision is grounded in the origin document or research
- Each implementation unit is concrete, dependency-ordered, and implementation-ready
- If test-first or characterization-first posture was explicit or strongly implied, the relevant units carry it forward with a lightweight `Execution note`
- A unit without test scenarios is **not** a defect — the default is no tests (see "Testing posture" in the shared spec conventions). Where a unit does carry test scenarios, they name specific inputs, actions, and expected outcomes without becoming test code, and the test earns its place without forcing the code to be more complex
- Deferred items are explicit and not hidden as fake certainty
- **High-Level Technical Design presence audit (load-bearing).** For each architecture trigger in Phase 3.4 that the plan content satisfies (3+ components with directed relationships, 3+ protocol steps, 3+ state machine states, lifecycle, 3+ decision points, 3+ data-flow stages, mode/flag combinations, DSL/API surface design, non-obvious single-component shape), verify a corresponding sketch/diagram is present in the High-Level Technical Design section. Count the firing triggers; count the sketches; the sketch count must be at least the count of distinct trigger categories that fired. Missing the section when a trigger fired, OR including the section but skipping a triggered sketch within it, is incomplete — return to Phase 3.4 and add the missing sketch. Token cost is not a valid reason to fail this check.
- If a High-Level Technical Design section is included, it uses the right medium for the work, carries the non-prescriptive framing, and does not contain implementation code (no imports, exact signatures, or framework-specific syntax)
- Per-unit technical design fields, if present, are concise and directional rather than copy-paste-ready
- If the plan creates a new directory structure, would an Output Structure tree help reviewers see the overall shape?
- If Scope Boundaries lists items that are planned work for a separate PR, issue, or repo, are they under `### Deferred to Follow-Up Work` rather than mixed with true non-goals?
- U-IDs are unique within the plan and follow the stability rule — no two units share an ID; reordering or splitting did not renumber existing units; gaps from deletions are preserved
- Would a visual aid (dependency graph, interaction diagram, comparison table) help a reader grasp the plan structure faster than scanning prose alone?

If the plan originated from a requirements document, re-read that document and verify:
- The chosen approach still matches the product intent
- Scope boundaries and success criteria are preserved
- Blocking questions were either resolved, explicitly assumed, or sent back to `br-define`
- Every section of the origin document is addressed in the plan — scan each section to confirm nothing was silently dropped
- If origin supplies A/F/AE IDs: every origin R/F/AE that *affects implementation* is referenced in Requirements, a U-ID unit, test scenarios, verification, scope boundaries, or explicitly deferred. Actors are carried forward when they affect behavior, permissions, UX, orchestration, handoff, or verification. The standard is preservation of product intent, not mandatory ID spam — irrelevant origin IDs may be omitted
- If origin was Deep-product (origin contains an `Outside this product's identity` subsection): the plan's Scope Boundaries preserves the three-way split — `Deferred for later` and `Outside this product's identity` carried verbatim from origin, `Deferred to Follow-Up Work` reserved for plan-local implementation sequencing

#### 5.1.5 Brainstorm-Sourced Scoping Synthesis

Surface plan-time call-outs to the user before Phase 5.2 commits the plan to disk — the latest cheap moment to catch plan-time scope errors. The brainstorm already validated WHAT to build; this phase surfaces HOW the plan will execute on the forks that matter.

Fires **only when the plan was sourced from an upstream `define.md`** (Phase 0.2 found one) AND not on Phase 0.1 fast paths (resume normal, deepen-intent). Skip Phase 5.1.5 in solo invocation — solo plans handled their synthesis in Phase 0.7.

**Read `references/synthesis-summary.md` before composing the scoping synthesis.** It carries the affirmability test, keep-test criteria, detail test, summary shape budgets, granularity rules, anti-patterns, revision-vs-confirmation discipline, doc-body reading rules, doc-shape routing, soft-cut behavior, self-redirect support, the worked PII compression example, and full headless-mode routing — all required for a well-shaped synthesis.

**Required gate output — do not skip; silent proceeding is not allowed.** Compose an internal three-bucket scope draft (Stated / Inferred / Out of scope — internal thinking that feeds plan-body routing at Phase 5.2, not the chat output below). Derive call-outs (specific forks where user input materially changes the plan), then emit one of the two literal templates below in chat before continuing to Phase 5.2.

**Synthesis is pre-plan-write.** The agent does NOT yet know how plan-write will sequence the work. Do not claim PR count ("one PR"), commit/branch shape, effort or time estimates, Implementation Unit boundaries, or exact file paths in the synthesis. The synthesis surfaces decisions knowable at THIS point (brainstorm + research + agent posture); plan-write produces the rest. This rule holds even when the agent has formed plan-write opinions earlier in the session — those stay internal until plan-write.

**Summary shape: two paragraphs.**

1. **Brainstorm-scope restatement** (1-2 sentences, prose). Restates the brainstorm's scope as orientation, in the brainstorm's own vocabulary. NOT an enumeration of Implementation Units, restated constraints, or listed acceptance examples — the user wrote those.
2. **Plan-specific scoping decisions** (prose, or bullets when multi-faceted). Scope-level commitments the agent made that the brainstorm did not: full brainstorm coverage vs. narrowed subset; adjacent refactors pulled in vs. held out; test scope at scenario level. Each item must be affirmable by the user without reading code. Form follows substance; tier budgets are **ceilings, not targets** (Lightweight 1-3 lines; Standard up to 3-5 lines or 2-4 bullets; Deep up to 4-6 lines or 3-6 bullets). 1-2 lines per bullet. Less is correct when there isn't more to say. See reference for keep test, detail test, and source-vocabulary discipline.

**Do NOT enumerate the touch surface.** Sentences like "The touch surface is...", "This plan touches...", "The implementation reaches into...", "Files modified include..." are plan-pitch leaks. File paths, module names, directory introductions, and per-file change descriptions belong in the plan body (Implementation Units at Phase 5.2), not the synthesis. The synthesis names *what* the plan targets, not *where* the code lives.

**Pre-emit scans.** Before emitting the synthesis, scan the output:
- Bare ID references (`AE\d+`, `R\d+`, `F\d+`, `A\d+`, `U\d+`) → replace with plain names.
- File paths (`path/like.md`, `path/like.py`, etc.) → cut unless the path IS the topic of an explicit fork in the call-outs.

**Tier guard on auto-proceed:** the auto-proceed path (announce without waiting for confirmation) fires only when plan depth is **Lightweight AND zero call-outs survive**. Standard and Deep plans always fire the confirmation gate, even with zero call-outs — substance earns the checkpoint, not interaction history.

**Confirmation template (Standard/Deep regardless of call-out count, or any tier with one or more call-outs surviving):**

````text
The brainstorm scopes [1-2 sentence restatement in the brainstorm's vocabulary as orientation; NOT an enumeration of Implementation Units, constraints, or acceptance examples].

This plan [plan-specific scoping decisions: full-brainstorm coverage vs. narrowed subset; adjacent refactors in or out; test scope at scenario level. NOT PR count, sequencing, IU lists, or file paths].

**Call outs:** (omit this header when zero forks survived the keep test)
- [plan-time fork in 1-2 lines: name the choice and optional one-clause trade-off in parens. NO multi-sentence rationale, NO "my default is X" pitch]

Confirm and I'll write the plan next, drawing on the brainstorm, research, and this synthesis.
````

Wait for user confirmation before continuing to Phase 5.2.

**Auto-proceed template (Lightweight with zero call-outs only):**

````text
Planning [brief brainstorm-scope restatement] — [plan-specific shape in one clause].

No open decisions to weigh in on — proceeding to plan-write. Interrupt if I have the scope wrong.
````

Then continue to Phase 5.2 without a blocking question.

**Headless mode**: internal draft is composed but stage 2 (chat-time call-outs) is skipped — no synchronous user to confirm to. Proceed to Phase 5.2 plan-write. Inferred bets from the internal draft route to a `## Assumptions` section in the plan instead of Key Technical Decisions. See `references/synthesis-summary.md` Headless mode for the full routing.

#### 5.2 Write Plan File

**REQUIRED: Write the plan file to disk before presenting any options.**

Use the Write tool to save the complete plan as markdown to the change's working directory:

```text
specs/changes/<YYYY-MM-DD-slug>/plan.md
```

Reuse the directory `br-define` created for this change (the one holding `define.md`); create `specs/changes/<YYYY-MM-DD-slug>/` if it does not exist. One plan per change directory, always named `plan.md` — no date or sequence prefix.

Compose the plan using the content from `references/plan-sections.md` and the format principles from `references/markdown-rendering.md`.

**Write tight.** A section being material is not license to pad it. Hold every kept section to the prose-economy discipline in `references/plan-sections.md`: one idea per sentence, a requirement or unit is intent plus at most one qualifier, defer forks to Open Questions rather than specifying both arms, resolve superseded text in place rather than stacking strata. Before declaring the plan written, run the named test there — could the implementer find a contradiction in each section in one pass?

Confirm (use absolute path so the reference is clickable in modern terminals):

```text
Plan written to <absolute path to plan>
```

#### 5.3 Confidence Check and Deepening

After writing the plan file, automatically evaluate whether the plan needs strengthening.

**Two deepening modes:**

- **Auto mode** (default during plan generation): Runs without asking the user for approval. The user sees what is being strengthened but does not need to make a decision. Sub-agent findings are synthesized directly into the plan.
- **Interactive mode** (activated by the re-deepen fast path in Phase 0.1): The user explicitly asked to deepen an existing plan. Sub-agent findings are presented individually for review before integration. The user can accept, reject, or discuss each agent's findings. Only accepted findings are synthesized into the plan.

Interactive mode exists because on-demand deepening is a different user posture — the user already has a plan they are invested in and wants to be surgical about what changes. This applies whether the plan was generated by this skill, written by hand, or produced by another tool.

This confidence check strengthens rationale, sequencing, risk treatment, and system-wide thinking when the plan is structurally sound but still needs stronger grounding.

**Pipeline mode:** This phase always runs in auto mode in pipeline/disable-model-invocation contexts. No user interaction needed.

##### 5.3.1 Classify Plan Depth and Topic Risk

Determine the plan depth from the document:
- **Lightweight** - small, bounded, low ambiguity, usually 2-4 implementation units
- **Standard** - moderate complexity, some technical decisions, usually 3-6 units
- **Deep** - cross-cutting, high-risk, or strategically important work, usually 4-8 units or phased delivery

Build a risk profile. Treat these as high-risk signals:
- Authentication, authorization, or security-sensitive behavior
- Payments, billing, or financial flows
- Data migrations, backfills, or persistent data changes
- External APIs or third-party integrations
- Privacy, compliance, or user data handling
- Cross-interface parity or multi-surface behavior
- Significant rollout, monitoring, or operational concerns

##### 5.3.2 Gate: Decide Whether to Deepen

- **Lightweight** plans usually do not need deepening unless they are high-risk
- **Standard** plans often benefit when one or more important sections still look thin
- **Deep** or high-risk plans often benefit from a targeted second pass
- **Thin local grounding override:** If Phase 1.2 triggered external research because local patterns were thin (fewer than 3 direct examples or adjacent-domain match), always proceed to scoring regardless of how grounded the plan appears. When the plan was built on unfamiliar territory, claims about system behavior are more likely to be assumptions than verified facts. The scoring pass is cheap — if the plan is genuinely solid, scoring finds nothing and exits quickly
- **Load-bearing external research override:** If Phase 1.4 marked external research as load-bearing (it materially shaped a KTD, Alternative, Scope boundary, or Risk), always proceed to scoring — **even when local implementation patterns are strong**. A landscape or prior-art finding can shape recommendations the local codebase cannot verify, and the thin-grounding override above would miss it. This enters the scoring pass only; it does not force deepening

If the plan already appears sufficiently grounded and neither the thin-grounding nor the load-bearing-external-research override applies, report "Confidence check passed — no sections need strengthening" and proceed to 5.4 (handoff).

##### 5.3.3–5.3.7 Deepening Execution

When deepening is warranted, read `references/deepening-workflow.md` for confidence scoring checklists, section-to-agent dispatch mapping, execution mode selection, research execution, interactive finding review, and plan synthesis instructions. Execute steps 5.3.3 through 5.3.7 from that file, then return here for 5.3.8.

##### 5.4 Final Checks and Handoff

Before handing off, do a quick final pass on the written plan:
- Every implementation unit is concrete, dependency-ordered, and implementation-ready.
- The `## Spec Impact` section is present and lists the specs the harvest step will create or update (or states `none — no design intent changes`).
- Deferred items are explicit; nothing is dressed up as fake certainty.

Then present the handoff with the platform's blocking question tool (`AskUserQuestion` — call `ToolSearch` with `select:AskUserQuestion` first if its schema isn't loaded; numbered-list fallback when no blocking tool is available).

**Question:** "Plan ready at `<absolute path to plan>`. What would you like to do next?" (use the absolute path so it is clickable)

1. **Start `br-work`** (recommended) — begin implementing this plan in the current session. Invoke the `br-work` skill via the platform's skill-invocation primitive, passing the plan path. Do not merely tell the user to type `/br-work` — fire it now.
2. **Deepen the plan** — run the interactive deepening pass (Phase 5.3) to strengthen rationale, sequencing, and risk treatment before implementing.
3. **More changes** — accept free-text revisions to the plan, apply them, then re-render this handoff.
4. **Done for now** — the plan is saved under `specs/changes/<slug>/` and can be resumed later.

**Routing.** Act on the selection — do not just announce it. Free-text targeting the plan's content is treated as option 3 (revise, then re-render).

The plan is disposable scaffolding: it is committed into `specs/changes/<slug>/` via the plan PR so the HOW can be reviewed, but it is never promoted to a spec or tracked as a separate issue, and the deepening pass — not a document-review step — is what strengthens it. Per `.claude/spec-conventions.md` ("Where the PRs fall"), the plan step lands `plan.md` in a PR: its **own** in the large-feature flow (`define.md` was already its own PR), or a **single combined PR with `define.md`** when the two were fused. Open that PR before handing to `br-work`, whose per-unit PRs branch from it. The durable record is the specs written at the harvest step (see `## Spec Impact`).

**Completion check:** This skill is not complete until the handoff has been presented, the user has selected an action, and the routing for that selection has been executed.
