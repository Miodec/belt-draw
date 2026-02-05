---@param player LuaPlayer
---@param event EventData.on_player_selected_area|EventData.on_player_alt_selected_area|EventData.on_player_reverse_selected_area
---@param mode "normal"|"alt"|"reverse"
local function on_release(player, event, mode)
  if mode == "reverse" then
    -- mark entities for deconstruction
    local entities = player.surface.find_entities_filtered({
      area = event.area,
      type = { "transport-belt", "underground-belt", "splitter" },
    })
    for _, e in pairs(entities) do
      e.order_deconstruction(player.force, player)
    end

    local ghosts = player.surface.find_entities_filtered({
      area = event.area,
      name = "entity-ghost"
    })
    for _, g in pairs(ghosts) do
      g.destroy()
    end
    cleanup(player, true)
    return
  end

  for _, segment in pairs(storage.segments) do
    for _, node in pairs(segment.nodes) do
      place(player, mode, node)
    end
  end
  cleanup(player, true)
end


script.on_event(defines.events.on_player_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  on_release(player, event, "normal")
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  on_release(player, event, "alt")
end)

script.on_event(defines.events.on_player_reverse_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  on_release(player, event, "reverse")
end)
