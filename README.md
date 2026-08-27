# Cross-platform multiplayer client for original worlds

This repository contains a standard Godot 4 client foundation for MonWorld. It uses GDScript only, Compatibility rendering, binary WebSocket transport, and a single-thread Web export so the same project can target Web, Linux, Windows, and macOS.

The client provides direct API authentication, character selection, authoritative multiplayer movement, chat, a separate battle presentation scene, and a local content-provider boundary. Desktop users select an external `.monpack`; Web users select and upload one through the browser. Pack bytes remain local to the client session and are never sent to the server.

No ROM, official asset, extracted asset, capture, generated map, or other third-party game data is included. The public `monworld-pack` tool accepts only the verified FireRed Rev1 SHA-1 and writes an external pack that is ignored by Git; the current importer emits the shared manifest/map foundation and does not place the ROM in the repository.

## Requirements

- Godot 4 with GDScript and Web export templates.
- A running Moreno.MonWorld-Server instance.
- An operator-provided `.monpack` when the server requires non-development content.

Set the server URL in the `monworld/server_url` project setting or use the field on the sign-in screen. The development server defaults to `http://127.0.0.1:8443`.

## Run and export

Open the project in Godot and run the main scene. The `Web`, `Linux`, `Windows`, and `macOS` export presets are in `export_presets.cfg`; Web is configured without threads.

To make an external pack from a user-owned verified dump, run the importer from `tools/monworld-pack` and choose an output path outside this repository:

```text
go run . -rom <path-to-user-owned-rom> -output <external-path>/monworld-firered-rev1.monpack
```

Patched and unknown ROMs are rejected by SHA-1. The resulting pack is selected in the client and is not uploaded.

## Project boundaries

The client protocol is an original MonWorld protocol and is not drop-in wire compatibility with another project. Reference material may inform behavior, but no reference source or proprietary data is copied into this repository.

See `docs/content-packs.md`, `docs/protocol.md`, and `docs/development.md` for focused guidance.
