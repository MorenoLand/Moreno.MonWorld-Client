# Cross-platform multiplayer client for original worlds

This repository contains a standard Godot 4 client foundation for MonWorld. It uses GDScript only, Compatibility rendering, binary WebSocket transport, and a single-thread Web export so the same project can target Web, Linux, Windows, and macOS.

The client provides direct API authentication, character selection, authoritative multiplayer movement, chat, a separate battle presentation scene, and a local ROM reader. Desktop users can select a verified FireRed Rev1 or LeafGreen Rev1 ROM through the operating system file picker; Web users can select one through the browser. ROM bytes remain local to the client session and are never sent to the server.

No ROM, official asset, extracted asset, capture, generated map, or other third-party game data is included. The client reads the user-selected ROM directly and currently validates verified FireRed Rev1 or LeafGreen Rev1 SHA-1 values before exposing the Kanto slice.

## Requirements

- Godot 4 with GDScript and Web export templates.
- A running Moreno.MonWorld-Server instance.
- A matching local FireRed Rev1 or LeafGreen Rev1 ROM.

Set the server URL in the `monworld/server_url` project setting or use the field on the sign-in screen. The development server defaults to `http://127.0.0.1:8081`.

## Run and export

Open the project in Godot and run the main scene. The `Web`, `Linux`, `Windows`, and `macOS` export presets are in `export_presets.cfg`; Web is configured without threads.

Patched and unknown ROMs are rejected by SHA-1. The resulting pack is selected in the client and is not uploaded.
Patched and unknown ROMs are rejected by SHA-1. The selected ROM is read directly and is not uploaded.

## Project boundaries

The client protocol is an original MonWorld protocol and is not drop-in wire compatibility with another project. Reference material may inform behavior, but no reference source or proprietary data is copied into this repository.

See `docs/rom-content.md`, `docs/protocol.md`, and `docs/development.md` for focused guidance.
