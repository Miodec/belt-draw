script.on_event(defines.events.on_pre_build, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if not is_holding_bd_tool(player) then return end

  storage.dragging = true
  storage.starting_direction = event.direction or defines.direction.north
  set_tool(player)

  local pos = { x = event.position.x, y = event.position.y }

  if (pos.x % 1) ~= 0.5 or (pos.y % 1) ~= 0.5 then
    -- print("on_pre_build event fired with non-aligned position, ignoring (" .. pos.x .. ", " .. pos.y .. ")")
    return
  end

  if storage.current_segment == nil then
    add_segment(pos, player)
  else
    storage.current_segment:update_to(pos)
    player.surface.play_sound({
      path = "entity-build/entity-ghost",
      position = player.position,
    })
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  if not is_bd_entity(event.entity) then return end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  set_tool(player)
  event.entity.destroy()
end)
