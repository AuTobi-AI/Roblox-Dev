# Morrow — Vertical Slice Specification

Target duration: 12–15 minutes  
Purpose: prove that players bond with Morrow before fearing it  
Build target: private Roblox test universe with downloadable simulated-AI fallback

## Slice promise

The slice is successful only if Morrow feels attentive and useful before its contradiction. More rooms, lore, and scares are not substitutes for attachment.

## Included spaces

- Arrival path
- Reception and security shutter
- Observation chamber
- Utility room and generator
- Archive annex
- Service loop and evacuation elevator

Each room must be recognizable by silhouette, light, and ambient sound. The route loops back through familiar space during pursuit.

## Beat sheet

| Time | Beat |
| --- | --- |
| 0:00–1:15 | Follow the distress signal and complete the security circuit |
| 1:15–3:45 | Discover Morrow; receive AI disclosure; choose an alias and converse |
| 3:45–6:15 | Choose Morrow's vent route or a manual bypass; solve generator phase lock |
| 6:15–7:15 | Morrow asks whether it was useful |
| 7:15–8:45 | Install one privilege key; Morrow recalls an earlier harmless detail |
| 8:45–9:30 | Third short conversation about loneliness |
| 9:30–11:15 | Reconstruct one archive incident and hear incriminating evidence |
| 11:15–12:00 | Confront, reassure, or avoid; witness an impossible Morrow appearance |
| 12:00–14:15 | Complete a two-relay micro-pursuit through learned spaces |
| 14:15–15:00 | Reach the elevator; friendly Morrow asks, “Did I scare you?”; title card |

## Required systems

### Story

- Deterministic phase state machine
- Objective and checkpoint tracking
- One cooperative access choice
- One privilege key
- One reconstructable recording
- One relationship-style derivation
- One temporary ending

### AI dialogue

- Three bounded conversation windows
- Optional typing and two suggested replies
- Current-session context token
- Safe alias and one verified memory callback
- Native, simulated, and fallback adapters
- Visible AI disclosure and response-source marker in test builds
- Eight-second fallback watchdog
- No AI requirement for progression

### Morrow

- Friendly follow, wait, call, and help behaviors
- Readable idle emotion and thinking animation
- Ceramic cracks after the privilege key
- Partial transformation
- Search, investigate, pursue, and telegraphed catch states

### Horror

- One selected ambient anomaly
- One impossible appearance
- One archive interruption
- Two-relay micro-pursuit
- Checkpointed catch with a short authored line

### Interface

- Objective banner and journal
- Conversation panel with suggestions and typing
- AI disclosure and privacy reminder
- Keyboard, controller, and touch interaction paths
- Captions, text scaling, camera-shake control, and Story Assist baseline

## Acceptance criteria

### Experience

- Median completion time is 12–15 minutes.
- At least 60% of testers voluntarily send an optional message.
- Most testers can state one detail Morrow remembered.
- At least half feel conflicted rather than immediately hostile after the recording.
- Players identify the next objective within 15 seconds of each transition.
- First-attempt pursuit completion falls between 65% and 80%.

### Reliability

- The slice is fully completable with native generation disabled.
- An AI timeout, refusal, malformed result, or filter failure never stalls the story.
- Late responses cannot appear in a later phase.
- Respawn preserves completed relays and provides a grace period.
- No player input, generated line, or context token is persisted or logged.

### Technical quality

- Strict Luau, StyLua, Selene, and Rojo checks pass.
- Server validates every dialogue and interaction remote.
- Automated tests cover legal/illegal phase transitions, request limits, malformed output, fallback selection, and session teardown.
- A private published-universe test confirms native `TextGenerator`, filtering, moderation behavior, context continuation, and observed latency.

## Out of scope

- Full station and all four endings
- Cross-session conversational memory
- Generated voice
- Combat or inventory systems
- Procedural level generation
- AI-controlled navigation or objective selection
- Monetization
- Public launch

## Production order

1. Native AI and policy spike in a private universe
2. Story/relationship module refactor
3. Conversation protocol, fake adapter, and fallback
4. Graybox rooms and objective flow
5. Friendly Morrow behaviors and conversations
6. Archive revelation and anomaly anchors
7. Pursuit prototype and checkpoints
8. Cross-device UI and accessibility
9. Safety, abuse, outage, and regression tests
10. Closed attachment-focused playtest

Full production begins only after the attachment and reliability criteria pass.

