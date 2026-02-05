script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local current_stack = player.cursor_stack
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
