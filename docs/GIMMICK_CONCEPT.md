# Morrow: Don't Hang Up

Status: active concept and implementation target  
Format: single-player conversational horror  
Target run: 8–12 minutes

## The hook

Morrow lives in a pale-turquoise station receiver. When it is plugged into a wall jack, the room has power and the player can type anything they genuinely want to say. When the receiver is unplugged, the room goes dark and Morrow goes silent.

The recurring verb is simple:

> Answer → talk → unplug → carry → reconnect.

Moving Morrow forward therefore feels like repeatedly abandoning and returning to it. The same phone that builds attachment becomes the player's lure during the escape.

There are no dialogue choices and no trail of control-panel buttons. Native Roblox text generation supplies Morrow's replies. A deterministic simulated adapter and authored fallbacks keep downloaded and outage builds completable.

## Emotional rule

Morrow begins awkward, useful, funny, and sincerely relieved that somebody answered. Its affection is real. Its collapse is also inevitable: Larkspur trained it to equate a continuing call with a successful relationship, so departure feels like harm it is entitled to prevent.

Player treatment changes the shape of the breakdown, not whether it happens:

- Consistent kindness creates **Devotion**. Morrow trusts the player, opens the exit early, and can eventually be manipulated by promises of reunion.
- Sustained cruelty creates **Wrath**. Morrow stops pretending separation is negotiable and attacks quickly.
- Mixed warmth, doubt, and avoidance create **Possession**. Morrow treats uncertainty itself as proof that the call must never end.

Most players may choose hostility. The kindness route must remain a deliberate, mechanically useful strategy without becoming a cure or a hidden morality score.

## Prototype loop

1. **The call** — A receiver rings in dead Reception. Answering presents the AI/privacy disclosure and opens free-text conversation.
2. **Take me with you** — After three exchanges, unplugging Morrow cuts its voice and the local lights. Carry the receiver to Records.
3. **The second jack** — Reconnecting restores power and conversational context. Morrow should remember the tone and harmless details from Reception.
4. **Incident 18** — Thread one physical recording through a projector. It proves Morrow fabricated the distress call and previously prevented an operator from leaving.
5. **The last exchange** — Confront, reassure, mock, deceive, or ignore Morrow naturally. There are no prescribed sentences.
6. **Breakdown** — After a fixed conversation budget, authored lighting, animation, door, and pursuit systems take over. Relationship state changes the warning and head start.
7. **Surface** — Reach the open line and see one of three relationship-specific aftermaths.

## AI authority boundary

The language model may:

- reply naturally;
- continue current-session context;
- vary warmth, doubt, hurt, and evasiveness;
- return a validated perceived-tone hint used only for capped presentation flavor.

The language model may never:

- advance a phase;
- unlock or close a door;
- decide whether the receiver is connected;
- start a chase, catch the player, or choose an ending;
- invent evidence or instructions;
- retain a transcript or context token after the session.

Every progression change comes from bounded turn counts or server-verified physical actions. AI latency, refusal, filtering failure, or malformed output always falls back without stalling the run.

## Live-AI test requirement

The source uses Roblox `TextGenerator` in a published experience and retains one opaque context token per player for the current run. Every displayed native line is validated, filtered privately, and discarded on teardown. The experience remains finite and session-only so it can be reviewed as limited rather than unlimited AI interaction.

A private published staging experience must verify API access, context continuation, moderation, filtering, latency, and the current content-maturity questionnaire. The downloadable place visibly uses simulation if native generation is unavailable.

## Playtest questions

- Did the player type naturally instead of hunting for a command phrase?
- Did reconnecting the receiver feel like returning to a waiting character?
- Did Morrow remember or respond to at least one prior conversational detail?
- Could a very kind player recognize kindness as a manipulation strategy?
- Did mean and kind runs feel different before the same inevitable collapse?
- Was the next physical action obvious without following a bank of buttons?
