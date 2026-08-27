# Contributing changes safely

Contributions should preserve the client/server boundary, cross-platform Godot target, and external-content rule.

Before opening a change:

- Keep the project standard Godot 4 and GDScript-only.
- Do not add ROMs, official or extracted assets, captures, generated packs, saves, or proprietary client code.
- Keep network authority on the server; the client sends intent and renders accepted state.
- Use synthetic fixtures for protocol and UI tests.
- Run the relevant Godot headless validation and Go tool tests when available.

Describe platform coverage, content-pack assumptions, and validation limits in the change summary. Do not include credentials, tokens, private keys, or user-owned dump paths in issues or patches.
