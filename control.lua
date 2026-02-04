local Segment = require("segment")

---@class StorageData
---@field rendering_target LuaEntity?
---@field starting_direction defines.direction?
---@field dragging boolean
---@field player_reach number?
---@field segments Segment[]
---@field current_segment Segment?

---@type StorageData
storage = storage


-- Initialize global state
script.on_init(function()
  storage.starting_direction = nil
  storage.dragging = false
  storage.player_reach = nil
  storage.segments = {}
  storage.current_segment = nil
end)

script.on_configuration_changed(function()
  storage.starting_direction = storage.starting_direction or nil
  storage.dragging = storage.dragging or false
  storage.player_reach = storage.player_reach or nil
  storage.segments = storage.segments or {}
  storage.current_segment = storage.current_segment or nil
end)

---@param tool_name string
---@return boolean
local function is_bp_tool(tool_name)
  return tool_name == "belt-draw" or tool_name == "belt-draw-preview"
end

---@param player LuaPlayer
---@return boolean
local function is_holding_bp_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then return false end
  if not cursor_stack.valid_for_read then return false end
  if not is_bp_tool(cursor_stack.name) then return false end
  return true
end


---@param entity LuaEntity
---@return boolean
local function is_bp_entity(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_name == "belt-draw-dummy-transport-belt" or entity.ghost_name == "belt-draw-dummy-entity"
  end
  return entity.name == "belt-draw-dummy-transport-belt" or entity.name == "belt-draw-dummy-entity"
end

---@param player LuaPlayer
local function set_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack then
    if not cursor_stack.valid_for_read or is_bp_tool(cursor_stack.name) or player.clear_cursor() then
      if storage.dragging == true then
        cursor_stack.set_stack({ name = "belt-draw", count = 1 })
      else
        cursor_stack.set_stack({ name = "belt-draw-preview", count = 1 })
      end
    end
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
---@param mode "normal"|"alt"|"reverse"
---@param node Node
---@return nil
local function place(player, mode, node)
  if storage.player_reach then
    player.character_build_distance_bonus = storage.player_reach
    storage.player_reach = nil
  end

  local inventory = player.get_inventory(defines.inventory.character_main)

  local name = nil

  if node.belt_type == "above" then
    name = "transport-belt"
  elseif node.belt_type == "down" or node.belt_type == "up" then
    name = "underground-belt"
  end

  if name == nil then
    return
  end

  local count = inventory and inventory.get_item_count(name) or 0

  local dx = player.position.x - node.x
  local dy = player.position.y - node.y
  local distance_squared = dx * dx + dy * dy
  local reach_squared = player.build_distance * player.build_distance

  local can_reach = distance_squared < reach_squared

  local entity = {
    name = name,
    position = { x = node.x, y = node.y },
    direction = node.direction,
    force = player.force,
    player = player,
    fast_replace = true
  }
  if node.belt_type == "down" then
    entity.belt_to_ground_type = "input"
  elseif node.belt_type == "up" then
    entity.belt_to_ground_type = "output"
  end

  if inventory and count > 0 and can_reach then
    if entity.belt_to_ground_type and entity.belt_to_ground_type == "output" then
      entity.direction = (entity.direction + 8) % 16
    end
    player.surface.create_entity(entity)
    inventory.remove({ name = name, count = 1 })
  else
    entity.name = "entity-ghost"
    entity.ghost_name = name
    if entity.belt_to_ground_type then
      entity.type = entity.belt_to_ground_type
      entity.belt_to_ground_type = nil
    end
    player.surface.create_entity(entity)
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

---@param pos Position
---@param player LuaPlayer
function add_segment(pos, player)
  local segment = Segment.new(pos, storage.starting_direction, player, #storage.segments + 1)
  table.insert(storage.segments, segment)
  storage.current_segment = segment

  for _, seg in pairs(storage.segments) do
    seg:update_max_segment_id(#storage.segments)
  end
end

script.on_event(defines.events.on_player_selected_area, function(event)
  if not is_bp_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  on_release(player, event, "normal")
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
  if not is_bp_tool(event.item) then return end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  on_release(player, event, "alt")
end)

script.on_event(defines.events.on_player_reverse_selected_area, function(event)
  if not is_bp_tool(event.item) then return end

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

  if is_holding_bp_tool(player) then
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

  if not is_holding_bp_tool(player) then return end
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

  if not is_holding_bp_tool(player) then return end
  if storage.current_segment == nil then return end

  add_segment(storage.current_segment.to, player)

  player.create_local_flying_text({
    text = { "belt-draw.anchored" },
    create_at_cursor = true
  })
end)

script.on_event(defines.events.on_pre_build, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if not is_holding_bp_tool(player) then return end

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
  if not is_bp_entity(event.entity) then return end
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  set_tool(player)
  event.entity.destroy()
end)
