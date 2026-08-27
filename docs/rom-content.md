# Direct ROM content

The client accepts a user-selected verified FireRed Rev1 or LeafGreen Rev1 `.gba` ROM. Both are Kanto sources for the same initial content contract. Desktop builds use Godot's native operating-system file dialog; Web builds use the browser file picker because Web cannot access the host filesystem directly.

Accepted SHA-1 values are FireRed Rev1 `dd5945db9b930750cb39d00c84da8571feebf417` and LeafGreen Rev1 `7862c67bdecbe21d1d69ce082ce34327e1c6ed5e`. The LeafGreen value is recorded from the [OpenRetro Rev 1 record](https://openretro.org/gba/pokemon/pokemon-leaf-green-version/edit) and must be revalidated against an available local dump before release.

After a valid Kanto ROM is selected, the client remembers its local path in `user://monworld-roms.json`. If the file is moved or removed, the client clears the stale path and opens Client Management so it can be selected again. ROM bytes are never written to the repository or uploaded to the server.

The current reader validates SHA-1 `dd5945db9b930750cb39d00c84da8571feebf417`, reads the ROM bytes into the client session, extracts the GBA header identifiers, and exposes the normalized Pallet Town, Route 1, and Viridian City contract. Patched and unknown ROMs are rejected.

The server publishes the expected `content_id` at `GET /api/v1/content`. The client compares that identifier before opening a game session, and the server compares it again during the one-time WebSocket ticket exchange. ROM bytes never go to the server.

No ROM, extracted asset, generated map, or derived content file belongs in this repository. Optional extraction stages must keep their output outside Git and remain independent of the network protocol.
