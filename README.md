# Godot desktop client for shared monster-catching worlds

This repository contains OpenMMOGo, a GDScript client for the OpenMMO login and game protocols. The current target is a native Godot 4 desktop client using raw TCP, the OpenMMO encrypted session handshake, and the existing server's packet contract. A Web transport proxy remains future work.

The implemented foundation covers encrypted login, server discovery, game-node selection, game-session authentication, and character-list decoding. The existing local ROM reader and gameplay renderer remain the visual-content path while the remaining OpenMMO world, movement, chat, and battle packets are integrated.

No ROM, official asset, extracted asset, capture, generated map, or other third-party game data is included. The client reads the user-selected ROM directly and identifies the supported game from its GBA header and map-layout structure. Graphics-patched ROMs remain usable when those source structures are preserved.

## Requirements

- Godot 4.7 with GDScript.
- A running OpenMMO login and game server.
- The matching OpenMMO `game.public.pem` trust key.
- A compatible local FireRed or LeafGreen base ROM.

Set the login host, port, and root public-key path on the sign-in screen. The development login endpoint defaults to `127.0.0.1:2106`.

## Run and export

Open the project in Godot and run the main scene. Native desktop is the active protocol target. Existing export presets remain available, but Web networking requires a future TCP proxy.

Unknown game codes and incompatible map layouts are rejected. The selected ROM is read directly and is not uploaded.

## Project boundaries

The client implements the OpenMMO wire protocol independently in GDScript. The OpenMMO server remains a separate read-only dependency and is not bundled here.

See `docs/rom-content.md`, `docs/protocol.md`, and `docs/development.md` for focused guidance.
