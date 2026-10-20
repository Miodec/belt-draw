# Factorio 2.1 behaviour the API docs don't tell you

Found the hard way while building Belt Draw 3.0. Each was confirmed in game or by `tests/run.sh`.

## Selection tools

- Swapping the cursor item during a selection cancels it; the game restarts the selection with the new item while the button is held. The mod relies on this to swap the preview tool for the real one at the second tile (`src/events/select.lua`).
- `on_player_start/change/cancel_selected_area` are best effort (can be dropped or arrive out of order) and only fire with `send_pre_selection_events = true`. The change event also fires when the selection mode changes, such as Shift pressed mid drag.
- In 2.1 the `"deconstruct"` selection mode no longer implies `"any-entity"`; list it explicitly.
- Selection tools can't place items, and custom inputs fire on press only.

## Building, blueprints and undo

- A blueprint built by script (`LuaPlayer.build_from_cursor`) does not rotate or upgrade existing belts. The same blueprint placed by a player's click does both. So the mod rotates and marks upgrades itself (`handle_existing_belts` in `src/place.lua`).
- `LuaEntity.rotate` has no `undo_index` and always makes its own undo item. `destroy`, `order_upgrade`, `order_deconstruction` and `create_entity` take `undo_index` (0 starts an item, 1 adds to the latest).
- Undo tags (`set_undo_tag`) don't move with an action from the undo stack to the redo stack or back; re-tag in `on_undo_applied` / `on_redo_applied`.
- Undoing a real built entity marks it for deconstruction, it isn't removed instantly.
- `create_entity` with `fast_replace = true` over a real entity removes that entity into the player's inventory, also for ghosts and out of reach. Ghosts must not be placed that way.
- `surface.get_default_cover_tile(force, tile)` returns nothing until a cover tile is set for that surface and force (`set_default_cover_tile`); researching landfill alone doesn't set it.
- Items on the ground, characters and biters don't stop a belt from being placed (`can_place_entity` stays true).
- Destroying a render object that already expired (`time_to_live`) is harmless.

## Multiplayer

- Every peer runs every mod event when the host schedules the input, so a non-host player's preview lags by their round trip. Nothing in a mod can predict locally.
- Keep all state in `storage`, per player (`get_state` in `src/storage.lua`). A Lua-local cache would desync.

## Test simulations (`tests/`)

- Main menu simulations are the only place with simulated input (`game.simulation`). Press the selection control together with the build control on the same key (`helpers.controls`), or the restarted selection after the tool swap never ends.
- A mod error inside a simulation shows an error screen and is never logged; the test runner catches errors with `xpcall` for that reason.
- Launching Factorio from a script needs `steam_appid.txt` in the working directory, or Steam relaunches it and drops the arguments.
