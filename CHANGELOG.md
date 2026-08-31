# Changelog

## 0.2.0

- Corrected the documented contract for `get_user_id` (available after initialize), `get_user_name` (after authenticate), `stats_stored` `result_text`, `unlocked_at`, and `clear_achievement_cache`.
- Documented that `get_stat_*` / `set_stat_*` require an existing dashboard API Name and matching INT or FLOAT/AVGRATE type.

## 0.1.0

- Added the Godot 4.3+ GDExtension addon for Windows x64 and macOS.
- Added the `Ludolio` Engine singleton for initialization, authentication, user information, achievements, and stats.
- Added the Basic Integration sample project.
- Games must be launched from the Ludolio desktop client. The client sets `LUDOLIO_SESSION`. Command-line `--ludolio-session` is a fallback.
