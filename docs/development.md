# Client development

Keep gameplay presentation in scenes and scripts under `scripts/`. `GameState` coordinates login and game sessions, `OpenMMOContentProvider` owns local ROM selection, and `scripts/net/` owns OpenMMO framing, cryptography, and packet codecs. Do not place credentials or content data in project settings.

## Offline map tester

Run the project with `tests/content_test.gd` for headless ROM validation, or open `scenes/content_preview.tscn` for the interactive tester. Select a map, use Preview to inspect its decoded ROM rendering, or use Play to walk it with keyboard movement. Play mode applies map-grid collision, elevation, directional restrictions, ledges, object occupancy, warps, and source map connections. A temporary player sprite is used until the client character-art pipeline is complete.

Use synthetic server state only for local UI work. ROM reading stays in the client session and must not write ROM data into the repository. Native desktop is the current networking target; a Web TCP proxy is future work.

## Headless protocol validation

Run protocol fixtures in a separate Godot process without closing the editor:

```powershell
godot --headless --path . --script res://tests/protocol_test.gd
```

For an opt-in live smoke run, set `OPENMMOGO_ROOT_PUBLIC_KEY`, `OPENMMOGO_USERNAME`, `OPENMMOGO_PASSWORD`, and `OPENMMOGO_ROM`, optionally set `OPENMMOGO_LOGIN_ENDPOINT`, then run `res://tests/headless_smoke.tscn` in a separate headless Godot process. Credentials are read only from the process environment and are never printed.
