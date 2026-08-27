# External content packs

The client consumes a `.monpack` ZIP selected by the user. Its required root entry is `manifest.json` with `schema_version`, `content_id`, `source`, and one or more map records containing `id`, `name`, `width`, and `height`.

The server publishes its expected manifest at `GET /api/v1/content`. The client compares `content_id` before opening a game session and the server compares it again when consuming the one-time WebSocket ticket.

Desktop selection uses Godot's native file dialog. Web selection uses a browser `<input type=file>` through the guarded `JavaScriptBridge` path because Web `FileDialog` cannot access the host filesystem. Web bytes are stored only in the client session's local sandbox long enough to read the pack.

Packs, ROMs, extracted assets, saves, and generated maps are ignored by Git. Operators should store them in a deployment/content directory outside the repository.
