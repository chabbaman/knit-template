# Repository Guidelines

## Project Structure & Module Organization

- `src/client` contains client runtime code, mainly Knit controllers (`src/client/Controllers`).
- `src/server` contains Knit services and server entrypoints (`src/server/Services`).
- `src/shared` holds constants and utilities replicated to both sides.
- Entry scripts are `src/client/Client.client.luau` and `src/server/Server.server.luau`.
- Rojo instance mapping lives in `default.project.json`.
- `Packages/` and `ServerPackages/` are dependency outputs managed by Wally; update them via tooling, not hand edits.

## Build, Test, and Development Commands

- `rokit install` installs pinned CLI tools from `rokit.toml` (`rojo`, `wally`).
- `wally install` resolves dependencies from `wally.toml` into package folders.
- `rojo serve` starts live sync between this repo and an open Studio session.

## Coding Style & Naming Conventions

- Language is Luau; use tabs for indentation (matching current files).
- Use PascalCase module names and keep role suffixes explicit (for example, `LuckyBlockService`, `LevelController`).
- Use camelCase locals/functions and UPPER_SNAKE_CASE for file-level constants.
- Keep shared gameplay constants in `src/shared/*Constants.luau`.
- Prefer explicit Luau type annotations on public service/controller methods.

## Testing Guidelines

- No automated test framework is currently configured in this repository.
- Validate changes in Roblox Studio using `rojo serve`, covering join/leave flow, plot assignment, block spawn/despawn, and XP/level updates.
- Include manual verification steps and outcomes in each PR.
