# Codex workspace instructions

This repository is a Roblox experience developed with Rojo and Luau. Codex is the primary engineering agent for this workspace.

## Working agreement

- Read this file and `README.md` before making changes.
- Preserve user work and keep changes focused on the requested feature.
- Use strict Luau (`--!strict`) for new scripts and modules.
- Keep shared code in `src/shared`, server-only code in `src/server`, and client-only code in `src/client`.
- Treat every client request as untrusted. Validate remote payloads, permissions, rate limits, and game state on the server.
- Prefer small services/modules with explicit APIs over large scripts or hidden globals.
- Put tunable gameplay values in shared configuration modules rather than scattering literals.
- Do not add third-party packages unless they materially simplify the feature and the user approves the dependency.
- Never commit Roblox credentials, cookies, API keys, generated place files, or local Studio state.
- The user tests downloadable place files rather than using Rojo live sync. After every playable change, build a fresh `build/RobloxDev.rbxl` and provide a direct download link in the handoff.
- The user has authorized Codex to commit, push, and publish tested builds for this repository without requesting confirmation each time. Keep commits scoped and never include secrets or unrelated files.

## Definition of done

Before handing off a code change, run the checks available for the affected files:

```sh
stylua --check src
selene src
rojo build -o build/RobloxDev.rbxl
```

Confirm that `build/RobloxDev.rbxl` exists and is non-empty. If a tool is unavailable, state which check could not run. Update `README.md` when setup or workflow changes.

## Roblox conventions

- File suffixes determine script type: `.server.luau`, `.client.luau`, and `.luau` for modules.
- Use `WaitForChild` at network/replication boundaries; use direct indexing when the instance is guaranteed locally.
- Server code owns persistent data, rewards, purchases, inventory, damage, and progression.
- Disconnect event connections and clean up instances when their owning feature is destroyed.
- Avoid per-frame work unless required; prefer events and bounded update loops.
- Keep Studio-authored assets and terrain out of source control unless they are intentionally exported and documented.
