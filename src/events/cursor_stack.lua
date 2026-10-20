script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local state = get_state(player)
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
      if tier and state.current_tier ~= tier then
        -- the checker reads the nested locale table as a LuaGuiElement
        ---@diagnostic disable-next-line: missing-fields
        local text = { "belt-draw.tier-updated", { "belt-draw.tier-" .. tier } } ---@type LocalisedString
        player.create_local_flying_text {
          text = text,
          position = player.position,
          create_at_cursor = true
        }
        state.current_tier = tier
      end
    end
  end

  if not current_stack or not current_stack.valid_for_read then return end

  if current_stack.name == "belt-draw-generic" then
    set_tool(player, state.current_tier, true)
  end

  if is_holding_bd_tool(player) then
    local belt_tier = get_belt_tier(current_stack.name)
    if belt_tier then
      state.current_tier = belt_tier
    end
  else
    cleanup(player, false)
  end
end)
