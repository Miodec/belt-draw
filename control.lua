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

local function is_bp_tool(tool_name)
  return tool_name == "belt-planner" or tool_name == "belt-planner-preview"
end

local function is_holding_bp_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then return false end
  if not cursor_stack.valid_for_read then return false end
  if not is_bp_tool(cursor_stack.name) then return false end
  return true
end


local function is_bp_entity(entity)
  if entity.type == "entity-ghost" then
    return entity.ghost_name == "belt-planner-dummy-transport-belt" or entity.ghost_name == "belt-planner-dummy-entity"
  end
  return entity.name == "belt-planner-dummy-transport-belt" or entity.name == "belt-planner-dummy-entity"
end

local function set_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack then
    if not cursor_stack.valid_for_read or is_bp_tool(cursor_stack.name) or player.clear_cursor() then
      if storage.dragging == true then
        cursor_stack.set_stack({ name = "belt-planner", count = 1 })
      else
        cursor_stack.set_stack({ name = "belt-planner-preview", count = 1 })
      end
    end
  end
end

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

local function place_ghost(player, item, pos)
  player.surface.create_entity({
    name = "entity-ghost",
    ghost_name = item,
    position = { x = pos.x, y = pos.y },
    direction = pos.direction,
    force = player.force,
    player = player,
    fast_replace = true
  })
end


local function place_from_inventory(player, item, pos)
  local inventory = player.get_inventory(defines.inventory.character_main)

  if not inventory then
    place_ghost(player, item, pos)
    return
  end

  local count = inventory.get_item_count(item)

  local dx = player.position.x - pos.x
  local dy = player.position.y - pos.y
  local distance_squared = dx * dx + dy * dy
  local reach_squared = player.build_distance * player.build_distance

  local can_reach = distance_squared < reach_squared

  if count > 0 and can_reach then
    player.surface.create_entity({
      name = item,
      position = { x = pos.x, y = pos.y },
      direction = pos.direction,
      force = player.force,
      player = player,
      fast_replace = true
    })
    inventory.remove({ name = item, count = 1 })
  else
    -- if not can_reach then
    --   player.create_local_flying_text({
    --     text = "Out of reach",
    --     create_at_cursor = true
    --   })
    -- end
    place_ghost(player, item, pos)
  end
end

--@param player LuaPlayer
--@param mode "normal"|"alt"
--@param pos {x: number, y: number, direction: defines.direction}
local function place(player, mode, pos)
  if storage.player_reach then
    player.character_build_distance_bonus = storage.player_reach
    storage.player_reach = nil
  end


  local existing = player.surface.find_entities_filtered({
    position = { x = pos.x, y = pos.y },
    radius = 0.5,
  })[1]

  if existing ~= nil and is_bp_entity(existing) then
    existing.destroy()
    existing = nil
  end

  if existing ~= nil and (existing.type == "resource" or existing.type == "character") then
    existing = nil
  end

  local item = "transport-belt"

  if existing ~= nil then
    --something is there
    if existing.type == "entity-ghost" then
      if existing.ghost_name == "transport-belt" then
        place_from_inventory(player, item, pos)
      end
    else
      if existing.name == "transport-belt" or mode == "alt" then
        place_from_inventory(player, item, pos)
      end
    end
  else
    --nothing is there
    place_from_inventory(player, item, pos)
  end
end

--@param player LuaPlayer
--@param event EventData
--@param mode "normal"|"alt"
local function on_release(player, event, mode)
  if mode == "reverse" then
    -- mark entities for deconstruction
    local entities = player.surface.find_entities_filtered({
      area = event.area,
      type = "transport-belt"
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
    if segment:is_single_point() then
      place(player, mode, {
        x = segment.from.x,
        y = segment.from.y,
        direction = storage.starting_direction or defines.direction.north
      })
      cleanup(player)
      return
    end

    for _, pos in pairs(segment.nodes) do
      place(player, mode, pos)
    end
    cleanup(player)
  end
end

function add_segment(pos, surface)
  local segment = Segment.new(pos, storage.starting_direction, surface, #storage.segments + 1)
  table.insert(storage.segments, segment)
  storage.current_segment = segment

  for _, seg in pairs(storage.segments) do
    seg:update_max_segment_id(#storage.segments)
  end
end

-- Handle selection area (drag and release)
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
    if storage.player_reach == nil then
      storage.player_reach = player.character_build_distance_bonus
    end
    player.character_build_distance_bonus = 1000000
  else
    if storage.player_reach then
      player.character_build_distance_bonus = storage.player_reach
      storage.player_reach = nil
    end
    cleanup(player, false)
  end
end)

script.on_event("belt-planner-flip-orientation", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bp_tool(player) then return end
  if storage.current_segment == nil then return end

  storage.current_segment:flip_orientation()
  player.create_local_flying_text({
    text = { "belt-planner.flipped" },
    create_at_cursor = true
  })
end)

script.on_event("belt-planner-anchor", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bp_tool(player) then return end
  if storage.current_segment == nil then return end

  add_segment(storage.current_segment.to, player.surface)

  player.create_local_flying_text({
    text = { "belt-planner.anchored" },
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
    add_segment(pos, player.surface)
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
