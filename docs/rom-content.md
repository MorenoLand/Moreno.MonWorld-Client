# Direct ROM content

The client accepts a user-selected compatible FireRed or LeafGreen `.gba` base ROM. Both are Kanto sources for the same initial content contract. Desktop builds use Godot's native operating-system file dialog; Web builds use the browser file picker because Web cannot access the host filesystem directly.

The reader identifies FireRed and LeafGreen from their GBA header game codes (`BPRE` and `BPRF`) and Nintendo maker code (`01`). A graphics patch can therefore change ROM bytes without being rejected solely because its whole-file fingerprint changed.

After a valid Kanto ROM is selected, the client remembers its local path in `user://monworld-roms.json`. If the file is moved or removed, the client clears the stale path and opens Client Management so it can be selected again. ROM bytes are never written to the repository or uploaded to the server.

The current reader performs a structural FireRed map-layout check against the source-defined pointer tables, reads the ROM bytes into the client session, extracts the GBA header identifiers, and exposes the normalized Kanto map contract. The displayed SHA-1 is only a diagnostic fingerprint; it is not an acceptance gate. Unknown game codes and incompatible map layouts are rejected.

The server publishes the expected `content_id` at `GET /api/v1/content`. The client compares that identifier before opening a game session, and the server compares it again during the one-time WebSocket ticket exchange. ROM bytes never go to the server.

No ROM, extracted asset, generated map, or derived content file belongs in this repository. Optional extraction stages must keep their output outside Git and remain independent of the network protocol.

The offline tester exposes the Kanto towns, routes, Viridian Forest, and selected Pallet Town and Viridian City interiors. Preview renders the selected map directly from the local ROM. Play loads that same decoded map into the interactive map scene with temporary character sprites, ROM object events, collision, ledges, warps, and map connections. The tester does not require an account or server connection.
