# Basic Integration

Open this repository in Godot 4.3 or later (or `game-sdks/godot/` in the Ludolio monorepo). That project already enables the Ludolio addon and runs this scene.

1. Confirm `addons/ludolio_sdk/bin/windows/LudolioSDK.dll` or `addons/ludolio_sdk/bin/macos/LudolioSDK.dylib` exists, along with the matching `ludolio_godot` GDExtension library for your platform.
2. Set `app_id` on the Main node to your dashboard App ID.
3. Optionally set `test_achievement_id` and `test_stat_id` to dashboard API names.
4. Export a Windows or macOS build. Embed PCK can be on or off.
5. Launch the export from the Ludolio Desktop Client.

Editor play without `LUDOLIO_SESSION` fails initialization on purpose. The sample does not quit the process; it shows the error in the status label.
