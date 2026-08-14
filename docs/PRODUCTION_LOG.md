# Morrow — Production Log

## v0.3.0 — AI foundation

Status: implemented; downloadable validation build

Delivered:

- Server-only bounded dialogue sessions
- Roblox `TextGenerator` adapter for private published experiences
- Deterministic simulated-AI adapter for downloaded local builds
- Authored fallback and safety routing
- Structured prompts, JSON output, output validation, and Roblox text filtering
- One-use request nonces, range checks, cooldowns, turn limits, expiry, watchdog, and stale-response rejection
- No persistent transcript or context token
- Cross-device conversation panel with free typing and suggested replies
- Visible AI disclosure and internal response-source badge
- Safe in-session alias memory demonstration
- Server-owned story, relationship, and verified-observation foundations
- Natural conversation integrated into the existing short gameplay shell

This build intentionally retains the prototype woodland and echo-shard loop. It proves the highest-risk AI interaction before environment production.

Next gate:

- Validate the conversation flow in Roblox Studio using simulated AI.
- Publish into a private universe and verify native AI access, filtering, latency, and fallback.
- Begin the Larkspur graybox after those results are recorded.
