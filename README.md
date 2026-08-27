# Ludolio Godot SDK

Official Godot 4 addon for Ludolio. This SDK provides a Steamworks-like API for Godot games to integrate with the Ludolio platform.

See [Docs/LudolioSDK.md](Docs/LudolioSDK.md) for the complete walkthrough, per-method API, export steps, and troubleshooting.

## Quick Reference

Initialize as early as possible, from the main scene `_ready` or an autoload. Connect signals before calling initialize. After initialization succeeds, call `authenticate`. Wait for authentication before using user data, achievements, or stats.

```gdscript
func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_init)
    Ludolio.authentication_complete.connect(_on_auth)
    Ludolio.initialize_with_app_id(YOUR_APP_ID) # From the Ludolio Developer Dashboard


func _on_init(success: bool, error: String) -> void:
    if success:
        Ludolio.authenticate()


func _on_auth(success: bool, error: String) -> void:
    if success:
        print("Ready to play! User: ", Ludolio.get_user_id())
```

Unlock an achievement (the string is the **API Name** from the developer dashboard):

```gdscript
Ludolio.unlock_achievement("ACH_FIRST_WIN")
```

Track stats (Steamworks-style):

```gdscript
Ludolio.request_stats()
# in stats_requested, when success:
var kills = Ludolio.get_stat_int("kills")
var next_kills := 1
if kills != null:
    next_kills = int(kills) + 1
Ludolio.set_stat_int("kills", next_kills)
Ludolio.store_stats()
```

**Important:** Always wait for `authentication_complete` with `success == true` before accessing user data or SDK features. In Godot this fires after you call `authenticate()`, not immediately after initialize.

## Features

- Automatic authentication with the Ludolio Desktop Client
- Achievements
- Stats tracking (Steamworks-style get/set/store)
- Current user information
- GDScript and C# through the same `Ludolio` Engine singleton

## Requirements

- Godot 4.3 or later
- Windows 64-bit or macOS
- Ludolio Desktop Client for launch and testing

Linux is not supported.

## Installation

Godot does not install addons from a git URL the way Unity Package Manager does. Copy the addon into the project.

1. Download a release or clone https://github.com/Ludolio/ludolio-godot-sdk
2. Copy `addons/ludolio_sdk` into your Godot project:

```text
YourGame/
  project.godot
  addons/
    ludolio_sdk/
      plugin.cfg
      ludolio.gdextension
      bin/windows/LudolioSDK.dll
      bin/macos/LudolioSDK.dylib
```

3. Confirm the native library and the GDExtension library for your platform exist:

```text
addons/ludolio_sdk/bin/windows/LudolioSDK.dll
addons/ludolio_sdk/bin/windows/ludolio_godot.windows.template_debug.x86_64.dll
addons/ludolio_sdk/bin/windows/ludolio_godot.windows.template_release.x86_64.dll
addons/ludolio_sdk/bin/macos/LudolioSDK.dylib
addons/ludolio_sdk/bin/macos/libludolio_godot.macos.template_debug.universal.dylib
addons/ludolio_sdk/bin/macos/libludolio_godot.macos.template_release.universal.dylib
```

4. Open the project in Godot. Enable **Ludolio SDK** under **Project > Project Settings > Plugins**.
5. Restart the editor if the `Ludolio` singleton is missing from the autocomplete list.

Pin a version by downloading that GitHub release tag (for example `v0.1.0`) instead of cloning `main`.

Games must be launched through the Ludolio Desktop Client. The client sets `LUDOLIO_SESSION` on the game process and also passes a session argument. Initialization fails without that session, including in the editor.

Embed PCK on or off both work. A sidecar `.pck` is optional.

## Quick Start

### 1. Basic setup (GDScript)

Add this script to a node in your first scene, or to an autoload:

```gdscript
extends Node

@export var app_id: int = 1000 # Your App ID from Ludolio

func _ready() -> void:
    # Connect signals BEFORE initializing. Initialize can finish in the same call.
    Ludolio.initialization_complete.connect(_on_initialization_complete)
    Ludolio.authentication_complete.connect(_on_authentication_complete)

    if Ludolio.initialize_with_app_id(app_id):
        print("Ludolio SDK initialization started...")
    else:
        push_error("Failed to initialize Ludolio SDK: %s" % Ludolio.get_last_error())


func _on_initialization_complete(success: bool, error: String) -> void:
    if not success:
        push_error("Ludolio initialize failed: %s" % error)
        return
    Ludolio.authenticate()


func _on_authentication_complete(success: bool, error: String) -> void:
    if success:
        print("Authenticated! User ID: ", Ludolio.get_user_id())
        # SDK is now ready - enable game features
    else:
        push_error("Authentication failed: %s" % error)


func _exit_tree() -> void:
    Ludolio.initialization_complete.disconnect(_on_initialization_complete)
    Ludolio.authentication_complete.disconnect(_on_authentication_complete)
```

### 2. Using achievements

> **Identifier convention.** Every achievement is identified by its
> **API Name** as configured on the developer dashboard (e.g. `"ACH_10_KILLS"`).
> That same string is the `achievement_id` field on each dictionary from
> `request_achievements`. Always use the API Name when calling
> `unlock_achievement`, `is_achievement_unlocked`, or reconciling against
> `achievements_received` results.

Unlock achievements when players accomplish goals:

```gdscript
extends Node

var kill_count := 0

func on_enemy_killed() -> void:
    kill_count += 1
    if kill_count == 10:
        Ludolio.unlock_achievement("ACH_10_KILLS")
```

With a signal for confirmation:

```gdscript
func _ready() -> void:
    Ludolio.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_achievement_unlocked(achievement_id: String, success: bool, error: String) -> void:
    if success:
        print("Achievement unlocked: ", achievement_id)
    else:
        push_error("Failed to unlock %s: %s" % [achievement_id, error])
```

**Restoring unlock state on launch**

After authentication completes, call `request_achievements` once to learn which achievements the current user has already unlocked. The `achievement_id` field matches the API Name you used in `unlock_achievement`.

```gdscript
func _on_authentication_complete(success: bool, error: String) -> void:
    if not success:
        return
    Ludolio.achievements_received.connect(_on_achievements_received)
    Ludolio.request_achievements()


func _on_achievements_received(success: bool, achievements: Array, error: String) -> void:
    if not success:
        push_error(error)
        return
    for achievement in achievements:
        if achievement.get("unlocked", false):
            # achievement.achievement_id is the dashboard API Name
            MyGameProgress.mark_achievement_unlocked(str(achievement["achievement_id"]))
```

### 3. Using stats

Stats work like Steamworks: request from server, get/set locally, then store back.

`get_stat_int` and `get_stat_float` return the value, or `null` if the stat is missing or stats are not loaded yet. Check for `null` before arithmetic.

**Step 1: Load stats after authentication**

```gdscript
func _on_authentication_complete(success: bool, error: String) -> void:
    if not success:
        return
    Ludolio.stats_requested.connect(_on_stats_requested)
    Ludolio.request_stats()


func _on_stats_requested(success: bool, error: String) -> void:
    if not success:
        push_error("Failed to load stats: %s" % error)
        return
    print("Stats loaded successfully!")
    var kills = Ludolio.get_stat_int("kills")
    if kills != null:
        print("Total kills: ", kills)
```

**Step 2: Update stats during gameplay**

```gdscript
func on_enemy_killed() -> void:
    var current = Ludolio.get_stat_int("kills")
    var next_value := 1
    if current != null:
        next_value = int(current) + 1
    Ludolio.set_stat_int("kills", next_value)
    Ludolio.store_stats()
```

**Step 3: Store stats at key moments**

```gdscript
# Call store_stats when:
# - Player completes a level
# - Player pauses the game
# - At regular intervals during gameplay

func _ready() -> void:
    Ludolio.stats_stored.connect(_on_stats_stored)


func _on_stats_stored(success: bool, result_text: String) -> void:
    if success:
        print("Stats saved to server")
    else:
        push_error("Failed to store stats: %s" % result_text)
```

### 4. Getting user information

```gdscript
func _on_authentication_complete(success: bool, error: String) -> void:
    if not success:
        return
    print("User ID: ", Ludolio.get_user_id())
    Ludolio.user_info_received.connect(_on_user_info_received)
    Ludolio.request_user_info()


func _on_user_info_received(success: bool, user_info: Dictionary, error: String) -> void:
    if not success:
        push_error(error)
        return
    print("Welcome, ", user_info.get("user_name", ""))
```

**Important:** User data is only available after `authentication_complete` fires with `success == true`. Do not call these methods immediately after `initialize_with_app_id()`.

### C#

There is no separate C# assembly in this release. The same Engine singleton is available as `Engine.GetSingleton("Ludolio")`. Method and signal names stay snake_case.

```csharp
using Godot;

public partial class GameInitializer : Node
{
    [Export] public int AppId = 1000;

    public override void _Ready()
    {
        var ludolio = Engine.GetSingleton("Ludolio");
        ludolio.Connect("initialization_complete", Callable.From<bool, string>(OnInit));
        ludolio.Connect("authentication_complete", Callable.From<bool, string>(OnAuth));
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
        if (success)
        {
            GD.Print("Ready to play! User: ", Engine.GetSingleton("Ludolio").Call("get_user_id"));
        }
        else
        {
            GD.PrintErr(error);
        }
    }
}
```

If a generated `Ludolio.SignalName` type exists in your project, you can use it. If it does not, connect with the GDScript signal name string as shown above.

## API Reference

All APIs live on the `Ludolio` Engine singleton.

### State

| Method | Returns | Description |
|--------|---------|-------------|
| `initialize_with_app_id(app_id: int)` | `bool` | Initialize the SDK with your App ID |
| `initialize_with_game_id(game_id: String)` | `bool` | Initialize the SDK with a game ID string |
| `shutdown()` | `void` | Shut down the native SDK |
| `authenticate()` | `void` | Authenticate after initialization succeeds |
| `is_initialized()` | `bool` | `true` if the native SDK is initialized |
| `is_authenticated()` | `bool` | `true` if the user is authenticated |
| `get_game_id()` | `String` | Current game ID |
| `get_user_id()` | `String` | Current user ID (empty if not authenticated) |
| `get_user_name()` | `String` | Current user name (empty if not available) |
| `get_last_error()` | `String` | Last error message from the SDK |

### User

| Method | Description |
|--------|-------------|
| `request_user_info()` | Request full user info; result on `user_info_received` |

`user_info` dictionary keys: `user_id`, `user_name`, `email`.

### Achievements

| Method | Description |
|--------|-------------|
| `unlock_achievement(achievement_id: String)` | Unlock by dashboard API Name |
| `request_achievements()` | Load all achievements; result on `achievements_received` |
| `is_achievement_unlocked(achievement_id: String)` | Cached unlock check |
| `clear_achievement_cache()` | Clear the achievement cache |

Achievement dictionary keys: `achievement_id`, `game_id`, `name`, `description`, `locked_icon_url`, `unlocked_icon_url`, `unlocked`, `unlocked_at`.

### Stats

| Method | Returns | Description |
|--------|---------|-------------|
| `request_stats()` | `void` | Load stats from the server (call before get/set) |
| `get_stat_int(stat_id: String)` | `Variant` | Integer stat, or `null` if missing |
| `get_stat_float(stat_id: String)` | `Variant` | Float stat, or `null` if missing |
| `set_stat_int(stat_id: String, value: int)` | `bool` | Set integer stat (cached locally) |
| `set_stat_float(stat_id: String, value: float)` | `bool` | Set float stat (cached locally) |
| `store_stats()` | `void` | Upload modified stats; result on `stats_stored` |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `initialization_complete` | `success: bool`, `error: String` | Initialize finished |
| `authentication_complete` | `success: bool`, `error: String` | Authenticate finished |
| `user_info_received` | `success: bool`, `user_info: Dictionary`, `error: String` | User info result |
| `achievement_unlocked` | `achievement_id: String`, `success: bool`, `error: String` | Unlock result |
| `achievements_received` | `success: bool`, `achievements: Array`, `error: String` | Achievement list |
| `stats_requested` | `success: bool`, `error: String` | Stats loaded |
| `stats_stored` | `success: bool`, `result_text: String` | Stats stored |

This SDK does not emit a client-disconnected signal. Handle process lifetime in your game if you need to react to the desktop client closing.

## Complete Example

The following example demonstrates initializing the SDK, handling authentication, loading stats, and tracking gameplay events:

```gdscript
extends Node

@export var app_id: int = 1000
var is_ready := false

func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_initialization_complete)
    Ludolio.authentication_complete.connect(_on_authentication_complete)
    Ludolio.achievement_unlocked.connect(_on_achievement_unlocked)
    Ludolio.stats_requested.connect(_on_stats_requested)
    Ludolio.stats_stored.connect(_on_stats_stored)

    if not Ludolio.initialize_with_app_id(app_id):
        push_error("Failed to initialize Ludolio SDK: %s" % Ludolio.get_last_error())


func _on_initialization_complete(success: bool, error: String) -> void:
    if not success:
        push_error("Initialize failed: %s" % error)
        return
    Ludolio.authenticate()


func _on_authentication_complete(success: bool, error: String) -> void:
    if not success:
        push_error("Authentication failed: %s" % error)
        return
    print("Authentication successful! User: ", Ludolio.get_user_id())
    Ludolio.request_stats()


func _on_stats_requested(success: bool, error: String) -> void:
    if not success:
        push_error("Failed to load stats: %s" % error)
        return
    is_ready = true
    print("Stats loaded - game ready!")
    var kills = Ludolio.get_stat_int("kills")
    if kills != null:
        print("Total kills: ", kills)


func _on_achievement_unlocked(achievement_id: String, success: bool, error: String) -> void:
    if success:
        print("Achievement unlocked: ", achievement_id)
    else:
        push_error("Unlock %s failed: %s" % [achievement_id, error])


func _on_stats_stored(success: bool, result_text: String) -> void:
    if success:
        print("Stats saved to server")
    else:
        push_error("Failed to store stats: %s" % result_text)


func on_enemy_killed() -> void:
    if not is_ready:
        return
    var current = Ludolio.get_stat_int("kills")
    var new_kills := 1
    if current != null:
        new_kills = int(current) + 1
    Ludolio.set_stat_int("kills", new_kills)
    Ludolio.store_stats()
    if new_kills == 10:
        Ludolio.unlock_achievement("ACH_10_KILLS")


func _exit_tree() -> void:
    if Ludolio.initialization_complete.is_connected(_on_initialization_complete):
        Ludolio.initialization_complete.disconnect(_on_initialization_complete)
    if Ludolio.authentication_complete.is_connected(_on_authentication_complete):
        Ludolio.authentication_complete.disconnect(_on_authentication_complete)
    if Ludolio.achievement_unlocked.is_connected(_on_achievement_unlocked):
        Ludolio.achievement_unlocked.disconnect(_on_achievement_unlocked)
    if Ludolio.stats_requested.is_connected(_on_stats_requested):
        Ludolio.stats_requested.disconnect(_on_stats_requested)
    if Ludolio.stats_stored.is_connected(_on_stats_stored):
        Ludolio.stats_stored.disconnect(_on_stats_stored)
```

A working sample is `Samples/BasicIntegration`. Open this repository in Godot (or `game-sdks/godot/` in the Ludolio monorepo).

## Common Pitfalls

### Incorrect: Calling `get_user_id()` immediately after initialize

```gdscript
func _ready() -> void:
    Ludolio.initialize_with_app_id(1000)
    print(Ludolio.get_user_id()) # Empty - authentication not complete
```

### Correct: Wait for `authentication_complete`

```gdscript
func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_init)
    Ludolio.authentication_complete.connect(_on_auth)
    Ludolio.initialize_with_app_id(1000)

func _on_init(success: bool, error: String) -> void:
    if success:
        Ludolio.authenticate()

func _on_auth(success: bool, error: String) -> void:
    if success:
        print(Ludolio.get_user_id()) # Now returns a valid user ID
```

### Incorrect: Connecting signals after initialize

`initialize_with_app_id` can emit `initialization_complete` before it returns. Connecting afterward misses the signal.

```gdscript
func _ready() -> void:
    Ludolio.initialize_with_app_id(1000)
    Ludolio.initialization_complete.connect(_on_init) # Too late
```

### Correct: Connect first, then initialize

```gdscript
func _ready() -> void:
    Ludolio.initialization_complete.connect(_on_init)
    Ludolio.initialize_with_app_id(1000)
```

### Incorrect: Using stats before `request_stats` completes

```gdscript
func _on_auth(success: bool, error: String) -> void:
    if success:
        Ludolio.request_stats()
        var kills = Ludolio.get_stat_int("kills") # null - stats not loaded yet
```

### Correct: Wait for `stats_requested`

```gdscript
func _on_auth(success: bool, error: String) -> void:
    if success:
        Ludolio.stats_requested.connect(_on_stats)
        Ludolio.request_stats()

func _on_stats(success: bool, error: String) -> void:
    if success:
        var kills = Ludolio.get_stat_int("kills")
        if kills != null:
            print(kills)
```

### Incorrect: Treating a missing stat as zero without checking `null`

```gdscript
var kills: int = Ludolio.get_stat_int("kills") # Type error / wrong if null
```

### Correct: Treat `null` as missing, then start from zero if you intend to

```gdscript
var current = Ludolio.get_stat_int("kills")
var next_value := 1
if current != null:
    next_value = int(current) + 1
Ludolio.set_stat_int("kills", next_value)
```

## Testing

1. Export Windows or macOS. Embed PCK can be on or off.
2. Zip the export folder (exe/app, pck if present, and addon binaries).
3. Upload in the developer dashboard. Leave DRM-free unchecked.
4. Install and play from the Ludolio Desktop Client.

Editor play without a Ludolio session fails initialization on purpose. The game process does not quit automatically; handle `initialization_complete` with `success == false`.

Contact us if you face issues during integration.

## Support

- Documentation: [Docs/LudolioSDK.md](Docs/LudolioSDK.md)
- Issues: https://github.com/Ludolio/ludolio-godot-sdk/issues
- Example: `Samples/BasicIntegration`
