local Segment = require("segment")

---@param pos Position
---@param player LuaPlayer
function add_segment(pos, player)
  local segment = Segment.new(pos, storage.starting_direction, player, #storage.segments + 1, storage.current_tier)
  table.insert(storage.segments, segment)
  storage.current_segment = segment

  for _, seg in pairs(storage.segments) do
    seg:update_max_segment_id(#storage.segments)
  end
end

---@param player LuaPlayer
---@param setTool boolean?
local function cleanup(player, setTool)
  for _, segment in pairs(storage.segments) do
    segment:destroy()
  end
  storage.segments = {}
  storage.current_segment = nil
  storage.dragging = false
  if setTool == nil or setTool == true then
    set_tool(player)
  end
end


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
    cleanup(player)
    return
  end

  for _, segment in pairs(storage.segments) do
    for _, node in pairs(segment.nodes) do
      place(player, mode, node)
    end
  end
  cleanup(player)
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

script.on_event("belt-draw-flip-orientation", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bd_tool(player) then return end
  if storage.current_segment == nil then return end

  storage.current_segment:flip_orientation()
  player.create_local_flying_text({
    text = { "belt-draw.flipped" },
    create_at_cursor = true
  })
end)

script.on_event("belt-draw-anchor", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bd_tool(player) then return end
  if storage.current_segment == nil then return end

  add_segment(storage.current_segment.to, player)

  player.create_local_flying_text({
    text = { "belt-draw.anchored" },
    create_at_cursor = true
  })
end)

script.on_event("belt-draw-next-tier", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end
  if storage.dragging then return end

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
  if storage.dragging then return end

  if not is_holding_bd_tool(player) then return end

  local current_stack = player.cursor_stack


  if not current_stack or not current_stack.valid_for_read then return end

  local current_tier = get_belt_tier(current_stack.name)
  if not current_tier then return end
  local previous_tier = get_previous_belt_tier(current_tier)

  set_tool(player, previous_tier, true)
end)

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
