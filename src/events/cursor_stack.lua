script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local current_stack = player.cursor_stack
  local ghost = player.cursor_ghost and player.cursor_ghost.name

  local cursor_entity_or_ghost_name = current_stack and current_stack.valid_for_read and current_stack.name or
      ghost and ghost.name or
      nil
  if cursor_entity_or_ghost_name then
    if settings.get_player_settings(player)["belt-draw-replace-belt-with-tool"].value then
      -- auto-switch to the tool when picking up a belt or ghost if enabled
      local tier = get_belt_tier_for_belt_name(cursor_entity_or_ghost_name)
      if tier then
        set_tool(player, tier, false)
      end
    else
      -- auto-update tier when picking up an entity or ghost
      local tier = get_belt_tier_for_entity_name(cursor_entity_or_ghost_name)
      if tier and storage.current_tier ~= tier then
        player.create_local_flying_text {
          text = { "belt-draw.tier-updated", { "belt-draw.tier-" .. tier } },
          position = player.position,
          create_at_cursor = true
        }
        storage.current_tier = tier
      end
    end
  end

  if not current_stack or not current_stack.valid_for_read then return end

  if current_stack.name == "belt-draw-generic" then
    set_tool(player, storage.current_tier, true)
  end

  if is_holding_bd_tool(player) then
    local belt_tier = get_belt_tier(current_stack.name)
    if belt_tier then
      storage.current_tier = belt_tier
    end

    if player.character then
      if storage.player_reach == nil then
        storage.player_reach = player.character_build_distance_bonus
      end
      player.character_build_distance_bonus = 1000000
    end
  else
    if player.character then
      if storage.player_reach then
        player.character_build_distance_bonus = storage.player_reach
        storage.player_reach = nil
      end
    end
    cleanup(player, false)
  end
end)
