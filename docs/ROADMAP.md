# Morrow — Production Roadmap

The project advances by evidence, not by feature count. Each gate must be satisfied before the next expensive layer begins.

## Phase 0 — Pre-production

Deliverables:

- Full game design, AI design, vertical-slice specification, and decision register
- Originality guardrail and experience pillars
- Initial technical risks and release gates

Exit gate:

- The premise, Morrow's underlying truth, AI scope, full act structure, and vertical-slice goal are coherent.

## Phase 1 — Native AI spike

Deliverables:

- Private Roblox test universe
- Minimal server-only `TextGenerator` call
- Structured JSON output and context continuation
- Roblox text filtering and visible AI disclosure
- Simulated and fallback adapters in downloaded builds
- Latency, refusal, rate behavior, and failure observations

Exit gate:

- Twelve-turn bounded dialogue works in the private universe.
- A downloaded place demonstrates the same flow with simulated AI.
- An outage never prevents progression.

## Phase 2 — Architecture foundation

Deliverables:

- StoryDirector and legal phase transitions
- Relationship and verified-observation services
- Dialogue protocol, validation, limits, revisions, and teardown
- Modular Morrow presentation and navigation controllers
- Automated fake-AI and failure-path tests

Exit gate:

- No AI output has gameplay authority.
- All critical state is server-owned.
- Malicious or duplicate remotes cannot bypass budgets or progression.

## Phase 3 — Graybox vertical slice

Deliverables:

- Arrival, Reception, Observation, Utility, Archive Annex, and service loop
- Security and generator puzzles
- Vent/manual cooperation choice
- Objective, checkpoint, and journal flow
- Navigation across keyboard, controller, and mobile

Exit gate:

- A first-time tester completes the graybox in 12–15 minutes without developer instructions.
- Objectives become clear within 15 seconds.

## Phase 4 — Attachment slice

Deliverables:

- Three bounded AI conversation windows
- Alias and verified memory callback
- Friendly follow, wait, call, help, and thinking behaviors
- Suggested replies and accessible typing
- Authored fallback pools for every required intent

Exit gate:

- At least 60% of testers voluntarily send an optional message.
- Most testers recall something Morrow remembered.
- AI failure and simulated AI do not meaningfully alter completion.

## Phase 5 — Contradiction and pursuit

Deliverables:

- Archive reconstruction and incriminating recording
- Relationship-responsive confrontation
- Ambient anomaly director and two anchor scares
- Partial transformation
- Search, investigate, pursue, lunge, catch, and two-relay checkpoint loop
- Story Assist and intensity controls

Exit gate:

- At least half of testers feel conflicted after the revelation.
- First-attempt pursuit completion is 65–80%.
- Navigation remains fair and readable under pressure.

## Phase 6 — Closed vertical-slice test

Deliverables:

- Cross-device testing matrix
- Adversarial dialogue and remote test suite
- Privacy-safe operational analytics
- Moderation, outage, and late-response tests
- Structured player interview and one-tap attachment measures

Exit gate:

- All criteria in `VERTICAL_SLICE.md` pass.
- The team chooses to expand, revise attachment, or stop before full-content investment.

## Phase 7 — Full-game production

Content streams:

- Complete station and shortcuts
- Residential, Basement, Containment, Courtyard, and Tower puzzles
- Full evidence ladder and optional records
- Four AI windows across the complete story
- Relationship-specific anomalies and authored dialogue
- Three-relay full pursuit
- Purge, Release, Reinitialize, and Containment endings
- Continuity Run and ending replay
- Art, animation, sound, captions, and accessibility polish

Exit gate:

- Every ending is reachable intentionally.
- Essential evidence cannot be missed or contradicted.
- The complete run remains within the target duration.

## Phase 8 — Alpha and safety review

Deliverables:

- Complete device/performance matrix
- Live model red-team suite
- Maturity and compliance questionnaire review
- Safety Dashboard review process
- Save migration and failure recovery
- Analytics dashboards without conversational content

Exit gate:

- No blocker, progression loss, privacy leak, unfiltered text, or AI-authority violation remains.

## Phase 9 — Beta and launch

Deliverables:

- Private beta followed by controlled public rollout
- Store page accurately describing limited AI interaction
- Onboarding and disclosure validation
- Model-version and API-health monitoring
- Rollback switch to authored fallback mode

Exit gate:

- Completion, attachment, safety, fallback, and performance metrics are stable at real concurrency.

## Phase 10 — Post-launch

Priorities:

1. Fix reliability and moderation regressions.
2. Tune pacing from aggregate events—not transcripts.
3. Add anomaly and authored-dialogue variation.
4. Consider generated or authored voice only after text AI is proven.
5. Consider new chapters before considering persistent conversational memory.

## Explicit non-goals for initial launch

- Cross-session AI conversation memory
- Unlimited chatbot access
- Third-party LLM infrastructure
- Multiplayer story synchronization
- AI-authored objectives, scares, or navigation
- Combat, crafting, procedural maps, or live generated 3D content
- Monetization that interrupts the first complete story run

## Primary risks

| Risk | Control |
| --- | --- |
| Native model avoids horror | Use AI for attachment and authored systems for horror |
| Latency or outage | Short budget, watchdog, simulated adapter, authored fallback |
| Prompt injection | Strict authority boundary and structured validation |
| Personal disclosure | Never solicit, store, log, or reuse sensitive conversation |
| Weak attachment | Gate full production on vertical-slice player evidence |
| Unfair pursuit | Coherent map, warnings, checkpoints, assist mode, no in-view manifestation |
| Scope growth | Build only the vertical slice until its gates pass |
| Model/platform change | Adapter boundary, returned-model telemetry, regression suite |

