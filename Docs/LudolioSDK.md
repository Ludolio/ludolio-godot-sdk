# Ludolio Godot SDK Documentation

Complete documentation for integrating the Ludolio SDK into a Godot 4 game.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [GDScript](#gdscript)
5. [C#](#c)
6. [API Reference](#api-reference)
7. [Export and upload](#export-and-upload)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

## Introduction

The Ludolio Godot SDK is a GDExtension addon that exposes a Steamworks-like API through the `Ludolio` Engine singleton. It handles:

- **Authentication** - Automatic user authentication via the Ludolio Desktop Client
- **Achievements** - Unlock and track player achievements
- **User Data** - Access current user information
- **Stats** - Steamworks-style request, get, set, and store
- **DRM** - Session validation from the Ludolio desktop client

GDScript and C# call the same singleton. There is no separate C# assembly in this release.

### How it works

1. The student launches your game from the Ludolio Desktop Client.
2. The client sets `LUDOLIO_SESSION` on the game process and starts the executable.
3. Your game initializes `Ludolio` with your App ID.
4. On initialization success you call `authenticate`.
5. After authentication succeeds, achievements, stats, and `request_user_info` are available. `get_user_id` is already valid after initialize.

Godot drops unknown `--` flags before they reach GDScript. The desktop client sets `LUDOLIO_SESSION` so the token reaches the game whether or not a `.pck` sits next to the executable. Command-line `--ludolio-session` is still read as a fallback (`OS.get_cmdline_user_args()`, then `OS.get_cmdline_args()`).

Unlike the Unity SDK, Godot does not authenticate inside initialize, and it does not quit the process when the session is missing. Handle `initialization_complete` and `authentication_complete` yourself.

### Godot compared with Unity

- Unity `Init` also authenticates. Godot `initialize_with_app_id` only starts the native SDK. You must call `authenticate()` after `initialization_complete` succeeds.
- Unity uses C# events. Godot uses signals on the `Ludolio` singleton.
- Unity reads `--ludolio-session` from argv. Godot reads `LUDOLIO_SESSION` first, then argv.
- Unity `GetStatInt` returns a bool and an `out` value. Godot `get_stat_int` / `get_stat_float` return the value or `null`.
- This SDK does not provide `OnClientDisconnected`.

## Installation

### Copy the addon

1. Download a tagged release from https://github.com/Ludolio/ludolio-godot-sdk/releases or clone the repository.
2. Copy `addons/ludolio_sdk` into `YourGame/addons/ludolio_sdk/`.
3. Confirm the native library and GDExtension library for your platform exist:

```text
addons/ludolio_sdk/bin/windows/LudolioSDK.dll
addons/ludolio_sdk/bin/windows/ludolio_godot.windows.template_debug.x86_64.dll
addons/ludolio_sdk/bin/windows/ludolio_godot.windows.template_release.x86_64.dll
addons/ludolio_sdk/bin/macos/LudolioSDK.dylib
addons/ludolio_sdk/bin/macos/libludolio_godot.macos.template_debug.universal.dylib
addons/ludolio_sdk/bin/macos/libludolio_godot.macos.template_release.universal.dylib
```

4. Open the project in Godot Editor.
5. Enable **Ludolio SDK** under **Project > Project Settings > Plugins**.
6. Restart the editor if `Ludolio` is missing from the global class list.

Pin a version by downloading that GitHub release tag instead of cloning `main`.

### Requirements

- Godot 4.3 or later
- Windows 64-bit or macOS
- Ludolio Desktop Client for launch

Linux is not supported.

Games must be launched through the Ludolio Desktop Client. Initialization fails without `LUDOLIO_SESSION` (or a `--ludolio-session` fallback), including in the editor.

## Quick Start

Initialize as early as possible. Connect signals before initialize. Call `authenticate` only after `initialization_complete` succeeds. Wait for `authentication_complete` before `request_user_info`, achievements, or stats. `get_user_id` is valid after initialize; `get_user_name` is not.

App ID, achievement API names, and stat API names come from the Ludolio Developer Dashboard.

### 1. Create an initializer

Add a node in your first scene, or an autoload, with this script:

```gdscript
extends Node

@export var app_id: int = 1000 # Your App ID from Ludolio

func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_init)
    Ludolio.authentication_complete.connect(_on_auth)
    if not Ludolio.initialize_with_app_id(app_id):
        push_error("Failed to initialize SDK: %s" % Ludolio.get_last_error())

func _on_init(success: bool, error: String) -> void:
    if success:
        Ludolio.authenticate()
    else:
        push_error("Initialize failed: %s" % error)

func _on_auth(success: bool, error: String) -> void:
    if success:
        print("Ready to play!")
    else:
        push_error("Authentication failed: %s" % error)
```

### 2. Set the App ID

Set `app_id` on the node, or change the default in the script, to the App ID from the Ludolio Developer Dashboard.

### 3. Test

Export Windows or macOS and launch the build from the Ludolio Desktop Client. Editor play without a session fails initialize on purpose.

## GDScript

Initialize from the main scene `_ready`, or from an autoload. Connect every signal you care about before `initialize_with_app_id`. Initialize can emit `initialization_complete` before the function returns.

```gdscript
extends Node

func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_init)
    Ludolio.authentication_complete.connect(_on_auth)
    Ludolio.user_info_received.connect(_on_user)
    Ludolio.achievements_received.connect(_on_achievements)
    Ludolio.achievement_unlocked.connect(_on_unlocked)
    Ludolio.stats_requested.connect(_on_stats)
    Ludolio.stats_stored.connect(_on_stored)
    Ludolio.initialize_with_app_id(1001)

func _on_init(success: bool, error: String) -> void:
    if not success:
        push_error(error)
        return
    Ludolio.authenticate()

func _on_auth(success: bool, error: String) -> void:
    if not success:
        push_error(error)
        return
    Ludolio.request_user_info()
    Ludolio.request_achievements()
    Ludolio.request_stats()
```

A working sample is `Samples/BasicIntegration`. Open this repository in Godot 4.3 or later (or `game-sdks/godot/` in the Ludolio monorepo).

## C#

There is no separate C# assembly. Call the Engine singleton. Method names and signal names stay snake_case.

```csharp
using Godot;

public partial class GameSDKManager : Node
{
    [Export] public int AppId = 1000;

    public override void _Ready()
    {
        var ludolio = Engine.GetSingleton("Ludolio");
        ludolio.Connect("initialization_complete", Callable.From<bool, string>(OnInit));
        ludolio.Connect("authentication_complete", Callable.From<bool, string>(OnAuth));
        ludolio.Connect("stats_requested", Callable.From<bool, string>(OnStats));
        ludolio.Call("initialize_with_app_id", AppId);
    }

    private void OnInit(bool success, string error)
    {
        if (!success)
        {
            GD.PrintErr(error);
            return;
        }
        Engine.GetSingleton("Ludolio").Call("authenticate");
    }

    private void OnAuth(bool success, string error)
    {
        if (!success)
        {
            GD.PrintErr(error);
            return;
        }
        Engine.GetSingleton("Ludolio").Call("request_stats");
    }

    private void OnStats(bool success, string error)
    {
        if (!success)
        {
            GD.PrintErr(error);
            return;
        }
        var ludolio = Engine.GetSingleton("Ludolio");
        Variant kills = ludolio.Call("get_stat_int", "kills");
        if (kills.VariantType != Variant.Type.Nil)
        {
            GD.Print("Total kills: ", kills.AsInt32());
        }
    }
}
```

If `Ludolio.SignalName` is generated in your project you can use it. If it is not, connect with the GDScript signal name string as shown above.

Unlock and store from C# the same way:

```csharp
var ludolio = Engine.GetSingleton("Ludolio");
ludolio.Call("unlock_achievement", "ACH_FIRST_WIN");
ludolio.Call("set_stat_int", "kills", 10);
ludolio.Call("store_stats");
```

## API Reference

All APIs live on the `Ludolio` Engine singleton.

### Initialization and session

##### `initialize_with_app_id(app_id: int) -> bool`

Initialize the SDK with your App ID. Connect `initialization_complete` first. This starts initialization only. Call `authenticate()` after the signal reports success.

```gdscript
Ludolio.initialization_complete.connect(_on_init)
var started := Ludolio.initialize_with_app_id(1000)
```

**Parameters:**

- `app_id` - Your game's App ID from the Ludolio Developer Dashboard. Must be greater than zero.

**Returns:** `true` if initialization started successfully. Success or failure is also reported on `initialization_complete`, including a missing session token.

**Note:** The signal can fire before this function returns. Subscribe first.

##### `initialize_with_game_id(game_id: String) -> bool`

Same flow using a game ID string instead of an integer App ID.

```gdscript
Ludolio.initialize_with_game_id("your-game-id")
```

##### `authenticate()`

Call after initialization succeeds. Result: `authentication_complete`.

```gdscript
func _on_init(success: bool, error: String) -> void:
    if success:
        Ludolio.authenticate()
```

##### `shutdown()`

Shut down the native SDK. The addon calls this when it unloads. You can call it from `_exit_tree` if you tear the singleton down yourself. The native library stays loaded for the process lifetime because native callbacks may outlive shutdown.

```gdscript
func _exit_tree() -> void:
    Ludolio.shutdown()
```

##### `is_initialized() -> bool`

`true` if the native SDK is initialized.

```gdscript
if Ludolio.is_initialized():
    print("SDK is initialized")
```

##### `is_authenticated() -> bool`

`true` if the user is authenticated.

```gdscript
if Ludolio.is_authenticated():
    print("User is authenticated")
```

##### `get_game_id() -> String`

Current game ID after initialize. Empty if not initialized.

```gdscript
print(Ludolio.get_game_id())
```

##### `get_last_error() -> String`

Last error message from the wrapper or native SDK.

```gdscript
push_error(Ludolio.get_last_error())
```

##### `initialization_complete(success: bool, error: String)`

Fired when initialize finishes. `error` is empty on success.

```gdscript
Ludolio.initialization_complete.connect(func(success: bool, error: String) -> void:
    if success:
        print("SDK initialized!")
        Ludolio.authenticate()
)
```

##### `authentication_complete(success: bool, error: String)`

Fired when authenticate finishes. Wait for `success == true` before `request_user_info`, achievements, or stats. `get_user_id` is already valid after initialize.

```gdscript
Ludolio.authentication_complete.connect(func(success: bool, error: String) -> void:
    if success:
        print("Authenticated!")
)
```

### User

> **Deprecated:** name and email are no longer populated. Use id as the player identifier.

##### `request_user_info()`

Request full user information. Asynchronous. Result: `user_info_received`. The user must be authenticated.

```gdscript
Ludolio.request_user_info()
```

##### `user_info_received(success: bool, user_info: Dictionary, error: String)`

```gdscript
func _on_user_info_received(success: bool, user_info: Dictionary, error: String) -> void:
    if not success:
        push_error(error)
        return
    print("User ID: ", user_info.get("user_id", ""))
```

**Dictionary keys:**

| Key | Type | Description |
|-----|------|-------------|
| `user_id` | `String` | Current user ID |
| `user_name` | `String` | Deprecated. No longer populated. |
| `email` | `String` | Deprecated. No longer populated. |

##### `get_user_id() -> String`

Synchronous accessor for the current user ID. After `initialize_with_app_id` succeeds, this is the user id from the session token. Empty if the SDK is not initialized.

```gdscript
var user_id := Ludolio.get_user_id()
```

##### `get_user_name() -> String`

Deprecated. No longer populated. Use `get_user_id()`.

```gdscript
var user_name := Ludolio.get_user_name()
```

**Important:** Wait for `authentication_complete` with `success == true` before `request_user_info`, achievements, or stats. `get_user_id` is already valid after initialize. `get_user_name` is not.

### Achievements

> **Identifier convention.** The string passed to `unlock_achievement`,
> `is_achievement_unlocked`, and the `achievement_unlocked` signal is the
> achievement's **API Name** as configured on the developer dashboard
> (e.g. `"first_win"`). On dictionaries returned by `request_achievements`,
> the same value is exposed as `achievement_id`. Do not confuse this with
> any internal database identifier.

##### `unlock_achievement(achievement_id: String)`

Unlock an achievement. `achievement_id` is the dashboard API Name. Result: `achievement_unlocked`.

```gdscript
Ludolio.unlock_achievement("first_win")
```

##### `achievement_unlocked(achievement_id: String, success: bool, error: String)`

Fired when an unlock attempt finishes. The first argument is the dashboard API Name.

```gdscript
Ludolio.achievement_unlocked.connect(func(achievement_id: String, success: bool, error: String) -> void:
    if success:
        print("Achievement unlocked: ", achievement_id)
        # Show achievement notification UI
    else:
        push_error(error)
)
```

##### `request_achievements()`

Get all achievements for the current game, including their unlock status for the current user. Useful for hydrating local state on launch. Result: `achievements_received`.

```gdscript
Ludolio.request_achievements()
```

##### `achievements_received(success: bool, achievements: Array, error: String)`

Each item in `achievements` is a dictionary.

```gdscript
func _on_achievements_received(success: bool, achievements: Array, error: String) -> void:
    if not success:
        push_error(error)
        return
    for achievement in achievements:
        print("%s (%s): %s" % [
            achievement.get("achievement_id", ""),
            achievement.get("name", ""),
            achievement.get("unlocked", false)
        ])
```

**Example: restoring unlock state on launch**

```gdscript
func _on_achievements_received(success: bool, achievements: Array, error: String) -> void:
    if not success:
        return
    for achievement in achievements:
        if achievement.get("unlocked", false):
            MyGameProgress.mark_achievement_unlocked(str(achievement["achievement_id"]))
```

**Dictionary keys:**

| Key | Type | Description |
|-----|------|-------------|
| `achievement_id` | `String` | Dashboard API Name — use this for `unlock_achievement` / `is_achievement_unlocked` |
| `game_id` | `String` | Game ID |
| `name` | `String` | Display name |
| `description` | `String` | Description |
| `locked_icon_url` | `String` | Icon URL when locked |
| `unlocked_icon_url` | `String` | Icon URL when unlocked |
| `unlocked` | `bool` | Whether the current user has unlocked it |
| `unlocked_at` | `Variant` | ISO-8601 timestamp when unlocked; `null` if locked. Check `unlocked`, not this field. |

##### `is_achievement_unlocked(achievement_id: String) -> bool`

Check if an achievement is unlocked (from cache). Pass the dashboard API Name.

```gdscript
if Ludolio.is_achievement_unlocked("first_win"):
    print("Achievement is unlocked")
```

The local cache used by this method is populated by `request_achievements` and by unlocks in this session. Call `request_achievements` once after authentication if you intend to rely on this method without first unlocking achievements during the session.

##### `clear_achievement_cache()`

Clear the native achievement cache. This does not fetch from the server. After a clear, `is_achievement_unlocked` returns `false` until you call `request_achievements` or unlock again in this session.

```gdscript
Ludolio.clear_achievement_cache()
Ludolio.request_achievements()
```

### Stats

Stats tracking API. Works like Steamworks stats: request from server, get/set locally, then store back.

##### `request_stats()`

Load stats from the server. Must be called before `get_stat_*` / `set_stat_*`. Result: `stats_requested`. The user must be authenticated.

```gdscript
Ludolio.request_stats()
```

##### `stats_requested(success: bool, error: String)`

Fired when stats load finishes.

```gdscript
Ludolio.stats_requested.connect(func(success: bool, error: String) -> void:
    if success:
        print("Stats loaded!")
)
```

##### `get_stat_int(stat_id: String) -> Variant`

Get an integer stat value. `request_stats` must complete first. The API Name must match an INT stat on the dashboard.

Returns the integer, or `null` if stats are not loaded, the API Name is unknown, or the stat is not INT. Use `get_stat_float` for FLOAT and AVGRATE. A stored `0` is a real value, not `null`.

```gdscript
var kills = Ludolio.get_stat_int("kills")
if kills != null:
    print("Total kills: ", kills)
```

##### `get_stat_float(stat_id: String) -> Variant`

Get a float stat value. `request_stats` must complete first. The API Name must match a FLOAT or AVGRATE stat on the dashboard.

Returns the float, or `null` if stats are not loaded, the API Name is unknown, or the stat is not FLOAT/AVGRATE.

```gdscript
var hours = Ludolio.get_stat_float("playtime")
if hours != null:
    print("Play time: ", hours, " hours")
```

##### `set_stat_int(stat_id: String, value: int) -> bool`

Set an integer stat that already exists on the dashboard. `request_stats` must have succeeded. This cannot create a new stat. Changes are cached locally until `store_stats`.

```gdscript
Ludolio.set_stat_int("kills", 10)
```

**Returns:** `true` if the local cache updated. `false` if stats are not loaded, the API Name is unknown, or the stat is not INT. Check the return value; a failed set is not stored.

##### `set_stat_float(stat_id: String, value: float) -> bool`

Set a FLOAT or AVGRATE stat that already exists on the dashboard. Same cache rules as `set_stat_int`.

```gdscript
Ludolio.set_stat_float("playtime", 2.5)
```

**Returns:** `true` if the local cache updated. `false` if stats are not loaded, the API Name is unknown, or the type is not FLOAT/AVGRATE.

##### `store_stats()`

Upload all modified stats to the server. Result: `stats_stored`.

```gdscript
Ludolio.store_stats()
```

##### `stats_stored(success: bool, result_text: String)`

Fired when a store attempt finishes. Branch on `success`. On success, `result_text` is a JSON payload from the native SDK (for example `{"results":[]}`), not an empty string. On failure it is an error message.

```gdscript
Ludolio.stats_stored.connect(func(success: bool, result_text: String) -> void:
    if success:
        print("Stats saved to server")
    else:
        push_error("Failed to store stats: %s" % result_text)
)
```

Call `store_stats` when the player completes a level, pauses, or at regular intervals during gameplay.

## Export and upload

Do not test with editor play. The editor does not receive a Ludolio session unless you are launching through the desktop client.

1. **Project > Export**, Windows Desktop or macOS.
2. Embed PCK can be on or off.
3. Confirm `LudolioSDK.dll` or `LudolioSDK.dylib` is in the export (Godot copies GDExtension dependencies listed in `ludolio.gdextension`).
4. Zip the export folder (executable, `.pck` if present, and addon binaries).
5. In the developer dashboard, leave **DRM-free** unchecked.
6. Upload the zip. Set the executable path to your game exe or `.app`.
7. Install and launch from the Ludolio Desktop Client.

DRM-free uploads do not receive `LUDOLIO_SESSION`. The SDK will fail to initialize.

## Best Practices

1. **Initialize early** - Initialize from the first scene `_ready` or an autoload.
2. **Connect first** - Always connect signals before calling `initialize_with_app_id`.
3. **Authenticate after init** - Call `authenticate()` only after `initialization_complete` succeeds.
4. **Wait for authentication** - Wait for `authentication_complete` before enabling SDK-backed gameplay.
5. **Load stats before get/set** - Call `request_stats` after authentication and wait for `stats_requested`.
6. **Check `null` on stats** - `get_stat_int` and `get_stat_float` return `null` when the stat is missing, not loaded, or the wrong type. A stored `0` is a real value.
7. **Use dashboard API Names** - Achievement and stat strings must match the developer dashboard. `set_stat_*` cannot create a stat.
8. **Store at key moments** - Call `store_stats` on level complete, pause, or a timer.
9. **Disconnect signals** - Disconnect in `_exit_tree` if the node can leave the tree while the singleton remains.
10. **Handle missing session** - Godot does not quit the process. Show an error if initialize fails.

## Troubleshooting

### SDK fails to initialize

**Problem:** `initialize_with_app_id` returns `false`, or `initialization_complete` receives `success == false`.

**Solutions:**

- Launch the exported game from the Ludolio Desktop Client
- Confirm the client is running
- Confirm DRM-free is unchecked on the upload
- Confirm `LUDOLIO_SESSION` is set on the game process (the client sets this for DRM launches)
- Check `Ludolio.get_last_error()` and the Godot output log

The usual missing-session message is: `Missing Ludolio session. Launch the game through the Ludolio desktop client.`

### Authentication fails

**Problem:** `authentication_complete` receives `success == false`.

**Solutions:**

- Confirm initialize succeeded first
- Confirm the Ludolio client is running
- Confirm the local API is reachable
- Check the Godot output log for the `error` string

### `Ludolio` is missing

**Problem:** GDScript reports `Ludolio` is not declared, or C# `Engine.GetSingleton("Ludolio")` fails.

**Solutions:**

- Enable **Ludolio SDK** under **Project > Project Settings > Plugins**
- Confirm `addons/ludolio_sdk/ludolio.gdextension` is in the project
- Confirm the platform GDExtension binary exists under `addons/ludolio_sdk/bin/`
- Restart the editor after the first import (Godot writes `.godot/extension_list.cfg`)

### Achievements not unlocking

**Problem:** `achievement_unlocked` receives `success == false`.

**Solutions:**

- Confirm the user is authenticated (`is_authenticated()`)
- Confirm the string is the dashboard **API Name**
- Confirm the Ludolio client is running
- Confirm DRM-free is off

### Stats return `null` or fail to store

**Problem:** `get_stat_int` returns `null`, or `stats_stored` fails.

**Solutions:**

- Wait for `stats_requested` with `success == true` before get/set
- Confirm the stat API Name exists on the dashboard
- Use `get_stat_int` for INT and `get_stat_float` for FLOAT or AVGRATE
- Confirm `set_stat_*` returned `true` before relying on `store_stats`
- Confirm you called `store_stats` after `set_stat_*`
- Branch on `stats_stored` `success`, not on whether `result_text` is empty
- Confirm the user is authenticated

### Native library missing in the export

**Problem:** The exported game cannot load the addon.

**Solutions:**

- Confirm `LudolioSDK.dll` or `LudolioSDK.dylib` is listed under `[dependencies]` in `ludolio.gdextension`
- Confirm the GDExtension library for debug or release matches the export type
- Confirm those files appear next to the exported executable / inside the `.app`

### Editor play fails

**Problem:** Pressing Play in Godot fails initialize.

This is expected. The editor does not receive `LUDOLIO_SESSION`. Export and launch from the Ludolio Desktop Client.

## Support

- GitHub issues: https://github.com/Ludolio/ludolio-godot-sdk/issues
- Sample: `Samples/BasicIntegration`
- Addon README: [../README.md](../README.md)
