# Client development

Keep gameplay presentation in scenes and scripts under `scripts/`. `GameState` owns API/session state, `MonWorldContentProvider` owns local ROM selection, and `MonWorldWebSocket` owns framing and transport. Do not place credentials or content data in project settings.

Use synthetic server state only for local UI work. ROM reading stays in the client session and must not write ROM data into the repository. Godot Web builds are single-threaded and use Compatibility rendering; avoid .NET, native extensions, and platform-specific assumptions.

## Headless handshake

Run the client smoke path in a separate Godot process without closing the editor. Set credentials only in the current PowerShell session:

```powershell
$env:MONWORLD_SERVER_URL = "http://127.0.0.1:8081"
$env:MONWORLD_USERNAME = "your-username"
$env:MONWORLD_PASSWORD = "your-password"
$env:MONWORLD_ROM = "D:\Roms\Gameboy\Pokemon - Fire Red Version.gba"
godot --headless --path . --scene res://tests/headless_smoke.tscn
```

To use credentials saved by the client’s Remember me option, set `$env:MONWORLD_USE_SAVED_CREDENTIALS = "1"` and omit the username/password variables. The runner reports the first failed stage and never prints credentials or tokens.
