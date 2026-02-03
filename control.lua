local Segment = require("segment")

---@class StorageData
---@field rendering_target LuaEntity?
---@field auto_orientation boolean
---@field starting_direction defines.direction?
---@field dragging boolean
---@field player_reach number?
---@field segments Segment[]
---@field current_segment_index number?

---@type StorageData
storage = storage


-- Initialize global state
script.on_init(function()
  storage.auto_orientation = true
  storage.starting_direction = nil
  storage.dragging = false
  storage.player_reach = nil
  storage.segments = {}
  storage.current_segment_index = nil
end)

script.on_configuration_changed(function()
  if storage.auto_orientation == nil then
    storage.auto_orientation = true
  end
  storage.starting_direction = storage.starting_direction or nil
  storage.dragging = storage.dragging or false
  storage.player_reach = storage.player_reach or nil
  storage.segments = storage.segments or {}
  storage.current_segment_index = storage.current_segment_index or nil
end)

local function get_current_segment()
  if storage.current_segment_index == nil then
    return nil
  end
  return storage.segments[storage.current_segment_index]
end

local function clear_visualizations()
  for _, segment in pairs(storage.segments) do
    segment:clear_visualization()
  end
end

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
    -- if player.controller_type == defines.controllers.character and player.character_build_distance_bonus < 1000000 then
    --   player.character_build_distance_bonus = player.character_build_distance_bonus + 1000000
    -- end
  end
end

local function render_line(player, segment)
  -- draw 2 lines to make an L shape
  local centered_positions = segment:get_centered_positions()
  local mid_pos = segment.midpoint
  rendering.draw_line({
    color = { r = 1, g = 1, b = 1, a = 0.1 },
    width = 1,
    from = {
      entity = storage.rendering_target,
      offset = { x = centered_positions.from.x - storage.rendering_target.position.x, y = centered_positions.from.y - storage.rendering_target.position.y },
    },
    to = {
      entity = storage.rendering_target,
      offset = { x = mid_pos.x + 0.5 - storage.rendering_target.position.x, y = mid_pos.y + 0.5 - storage.rendering_target.position.y },
    },
    surface = player.surface,
    players = { player },
  })
  rendering.draw_line({
    color = { r = 1, g = 1, b = 1, a = 0.1 },
    width = 1,
    from = {
      entity = storage.rendering_target,
      offset = { x = mid_pos.x + 0.5 - storage.rendering_target.position.x, y = mid_pos.y + 0.5 - storage.rendering_target.position.y },
    },
    to = {
      entity = storage.rendering_target,
      offset = { x = centered_positions.to.x - storage.rendering_target.position.x, y = centered_positions.to.y - storage.rendering_target.position.y },
    },
    surface = player.surface,
    players = { player },
  })
end

local function place_ghost(player, item, pos)
  player.surface.create_entity({
    name = "entity-ghost",
    ghost_name = item,
    position = { x = pos.x + 0.5, y = pos.y + 0.5 },
    direction = pos.direction,
    force = player.force,
    player = player,
    fast_replace = true
  })
end

local function visualise_segments(player)
  local current_segment = get_current_segment()
  if current_segment ~= nil then
    current_segment:visualize()
  end
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
      position = { x = pos.x + 0.5, y = pos.y + 0.5 },
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
    position = { x = pos.x + 0.5, y = pos.y + 0.5 },
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

local function on_drag_start(player, position)
  local pos = { x = math.floor(position.x), y = math.floor(position.y) }
  local segment = Segment.new(pos, player.surface, #storage.segments + 1)
  table.insert(storage.segments, segment)
  storage.current_segment_index = #storage.segments

  print("Created new segment starting at (" .. pos.x .. "," .. pos.y .. ")")
end

local function on_drag(player, position, current_segment)
  local pos = { x = math.floor(position.x), y = math.floor(position.y) }
  current_segment:update_to(pos)
  -- if current_segment.orientation == nil then
  --   player.create_local_flying_text({
  --     text = "Equal distance dragged, waiting",
  --     create_at_cursor = true
  --   })
  -- else
  --   player.create_local_flying_text({
  --     text = current_segment.orientation == "vertical" and "Vertical-first" or "Horizontal-first",
  --     create_at_cursor = true
  --   })
  -- end

  local side_lengths = current_segment:get_side_lengths()
  if storage.auto_orientation then
    if current_segment.orientation == "vertical" and side_lengths.y == 0 then
      current_segment.orientation = "horizontal"
    elseif current_segment.orientation == "horizontal" and side_lengths.x == 0 then
      current_segment.orientation = "vertical"
    end
  end

  visualise_segments(player)
end

local function on_release_cleanup(player, setTool)
  clear_visualizations()
  storage.segments = {}
  storage.current_segment_index = nil
  storage.auto_orientation = true
  storage.dragging = false
  if setTool == nil or setTool == true then
    set_tool(player)
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
    on_release_cleanup(player)
    return
  end

  for _, segment in pairs(storage.segments) do
    print(mode .. " selected area from (" ..
      event.area.left_top.x ..
      "," .. event.area.left_top.y .. ") to (" .. event.area.right_bottom.x .. "," .. event.area.right_bottom.y .. ")")



    if segment:is_single_point() then
      place(player, mode, {
        x = segment.from.x,
        y = segment.from.y,
        direction = storage.starting_direction or defines.direction.north
      })

      on_release_cleanup(player)
      return
    end


    ---@type {x: number, y: number, direction: defines.direction}[]

    local segment_side_lengths = segment:get_side_lengths()

    -- Determine orientation based on longer side if auto

    print("Horizontal length: " .. segment_side_lengths.x .. ", Vertical length: " .. segment_side_lengths.y)


    local belt_positions = segment:get_elements_with_direction()

    for _, pos in pairs(belt_positions) do
      place(player, mode, pos)
    end
    on_release_cleanup(player)
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
    on_release_cleanup(player, false)
  end
end)

script.on_event("belt-planner-flip-orientation", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bp_tool(player) then return end

  local current_segment = get_current_segment()
  if current_segment == nil then return end

  current_segment:flip_orientation()
  visualise_segments(player)

  player.create_local_flying_text({
    text = "Flipped",
    create_at_cursor = true
  })
end)

script.on_event("belt-planner-anchor", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bp_tool(player) then return end

  local current_segment = get_current_segment()
  if current_segment == nil then return end

  local pos = current_segment.to
  local segment = Segment.new(pos, player.surface, #storage.segments + 1)
  table.insert(storage.segments, segment)
  storage.current_segment_index = #storage.segments

  visualise_segments(player)

  player.create_local_flying_text({
    text = "Anchored",
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

  local current_segment = get_current_segment()

  if current_segment == nil then
    on_drag_start(player, event.position)
    return
  else
    on_drag(player, event.position, current_segment)
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
