script.on_event("belt-draw-next-tier", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end
  if storage.dragging then
    player.create_local_flying_text({
      text = { "belt-draw.cannot-switch-tier-while-dragging" },
      create_at_cursor = true
    })
    return
  end

  if not is_holding_bd_tool(player) then return end

  local current_stack = player.cursor_stack


  if not current_stack or not current_stack.valid_for_read then return end

  local current_tier = get_belt_tier(current_stack.name)
  if not current_tier then return end
  local next_tier = get_next_belt_tier(current_tier)

  set_tool(player, next_tier, true)
end)


script.on_event("belt-draw-previous-tier", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end
  if storage.dragging then
    player.create_local_flying_text({
      text = { "belt-draw.cannot-switch-tier-while-dragging" },
      create_at_cursor = true
    })
    return
  end

  if not is_holding_bd_tool(player) then return end

  local current_stack = player.cursor_stack


  if not current_stack or not current_stack.valid_for_read then return end

  local current_tier = get_belt_tier(current_stack.name)
  if not current_tier then return end
  local previous_tier = get_previous_belt_tier(current_tier)

  set_tool(player, previous_tier, true)
end)
