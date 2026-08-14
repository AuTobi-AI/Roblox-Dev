# Roblox Dev

A Codex-first workspace for building a Roblox experience with source-controlled Luau and downloadable Roblox place builds.

## Development workflow

1. You describe the game feature or change.
2. Codex implements it in the source-controlled Luau project.
3. Codex formats, lints, and builds the project.
4. Codex commits and pushes the tested source, publishes the `.rbxl` as a GitHub Release asset, and gives you its browser download link.
5. You open the file in Roblox Studio, press **Play**, and report what you want changed.

Roblox binary place files use the `.rbxl` extension. Generated builds are disposable and are not committed; the files in `src/` remain the source of truth.

## What is included

- `AGENTS.md` — the operating instructions Codex follows in this repository
- `src/shared` — modules replicated to both server and clients
- `src/server` — authoritative server scripts and services
- `src/client` — player-facing client scripts and UI
- `default.project.json` — maps source files into the Roblox data model
- `rokit.toml` — pinned toolchain versions
- StyLua and Selene configuration for consistent formatting and linting
- `docs/GAME_DESIGN.md` — authoritative full-game concept
- `docs/AI_NPC_DESIGN.md` — bounded native-AI architecture and safety model
- `docs/VERTICAL_SLICE.md` — the first production target and release gates
- `docs/DECISIONS.md` — locked defaults and creative checkpoints
- `docs/ROADMAP.md` — gated development sequence from AI spike through launch

## Testing a build

1. Download the `.rbxl` file from the GitHub Release link Codex provides.
2. Open it with Roblox Studio.
3. Use **Test > Play** to run the game.
4. Send Codex your observations, screenshots, or errors from Studio's **Output** window.

You do not need Rojo or the command-line tools to test builds. Those tools are only needed by Codex or a developer changing the source locally.

## Local developer setup

Install [Rokit](https://github.com/rojo-rbx/rokit), run `rokit install`, and use `rojo build -o build/RobloxDev.rbxl` to produce a place. Rojo live sync remains available for developers, but it is not part of the normal user testing workflow.

## Quality checks

```sh
stylua --check src
selene src
rojo build -o build/RobloxDev.rbxl
```

Run `stylua src` to format source files. Generated `.rbxl` files belong in `build/` and are not committed. Successful GitHub Actions runs also publish the place as a downloadable `RobloxDev-place` artifact.

## Current phase

The project is in pre-production. The design package in `docs/` is authoritative. Implementation resumes with the native-AI policy/API spike and vertical slice only after the active creative checkpoints are settled.
