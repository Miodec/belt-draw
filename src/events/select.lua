---@param player LuaPlayer
---@param area BoundingBox
local function on_deconstruct(player, area)
  -- mark entities for deconstruction
  local entities = player.surface.find_entities_filtered({
    area = area,
    type = { "transport-belt", "underground-belt", "splitter", "entity-ghost" },
  })
  local num = 0
  for _, e in pairs(entities) do
    if e.type == "entity-ghost" then
      if e.ghost_name ~= "transport-belt" and e.ghost_name ~= "underground-belt" and e.ghost_name ~= "splitter" then
        goto continue
      end
    end
    e.order_deconstruction(player.force, player, (num == 0) and 0 or 1)
    num = num + 1
    ::continue::
  end

  cleanup(player, true)
end

---@param player LuaPlayer
---@param area BoundingBox
---@param mode "normal"|"alt"
local function on_release(player, area, mode)
  place(player, storage.segments, mode)

  cleanup(player, true)
end


script.on_event(defines.events.on_player_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if settings.startup["belt-draw-swap-left-right-click"].value then
    on_deconstruct(player, event.area)
  else
    on_release(player, event.area, "normal")
  end
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end


  if settings.startup["belt-draw-swap-left-right-click"].value then
    -- do nothing
  else
    on_release(player, event.area, "alt")
  end
end)

script.on_event(defines.events.on_player_reverse_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if settings.startup["belt-draw-swap-left-right-click"].value then
    on_release(player, event.area, "normal")
  else
    on_deconstruct(player, event.area)
  end
end)

script.on_event(defines.events.on_player_alt_reverse_selected_area, function(event)
  if not is_bd_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if settings.startup["belt-draw-swap-left-right-click"].value then
    on_release(player, event.area, "alt")
  else
    -- do nothing
  end
end)
