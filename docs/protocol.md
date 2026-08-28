# Client protocol boundary

The native client connects directly to OpenMMO's login and game TCP endpoints. Frames use a little-endian inclusive `u16` length followed by the packet body.

Each connection performs the OpenMMO P-256 handshake. The client validates the server's `SHA256withECDSA` signature against the operator-provided `game.public.pem`, derives the shared session keys, and then applies AES-CTR, the negotiated checksum, and persistent raw-deflate compression in the same order as the server.

The login sequence authenticates the account, requests the server list, and resolves a game node. The game sequence sends `Join` (`0x01`), requests characters (`0x02`), selects a character (`0x04`), consumes the server startup state, and requests the player (`0x05`) after the map packet (`0x10`) has been decoded.

Packet fields are implemented from the OpenMMO source contract. There is no JSON, HTTP API, WebSocket, or compatibility fallback in the active online path.
