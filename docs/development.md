# Client development

Keep gameplay presentation in scenes and scripts under `scripts/`. `GameState` owns API/session state, `MonWorldContentProvider` owns local pack selection, and `MonWorldWebSocket` owns framing and transport. Do not place credentials or content data in project settings.

Use synthetic manifest data for local UI work. An importer run is opt-in and must write its output outside the repository. Godot Web builds are single-threaded and use Compatibility rendering; avoid .NET, native extensions, and platform-specific assumptions.
