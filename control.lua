---@class StorageData
---@field drag_rendering {[1]: LuaRenderObject, [2]: LuaRenderObject, [3]: LuaRenderObject?}?
---@field auto_orientation boolean
---@field starting_direction defines.direction?
---@field dragging boolean
---@field player_reach number?
---@field segments LSegment[]
---@field current_segment_index number?

---@class LSegment
---@field from {x: number, y: number}
---@field to {x: number, y: number}
---@field orientation "horizontal"|"vertical"


---@type StorageData
storage = storage


-- Initialize global state
script.on_init(function()
  storage.drag_rendering = nil
  storage.auto_orientation = true
  storage.starting_direction = nil
  storage.dragging = false
  storage.player_reach = nil
  storage.segments = {}
  storage.current_segment_index = nil
end)

script.on_configuration_changed(function()
  storage.drag_rendering = storage.drag_rendering or nil
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

local function clear_rendering()
  if storage.drag_rendering then
    for _, rendering in pairs(storage.drag_rendering) do
      rendering.destroy()
    end
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

local function render_line(player, from_pos, to_pos)
  -- draw 2 lines to make an L shape
  local current_segment = get_current_segment()
  if current_segment == nil then return end
  local mid_pos = current_segment.orientation == "vertical" and { x = from_pos.x, y = to_pos.y } or
      { x = to_pos.x, y = from_pos.y }
  local line1 = rendering.draw_line({
    color = { r = 1, g = 1, b = 1 },
    width = 3,
    from = from_pos,
    to = mid_pos,
    surface = player.surface,
    players = { player },
    -- time_to_live = 300
  })
  local line2 = rendering.draw_line({
    color = { r = 1, g = 1, b = 1 },
    width = 3,
    from = mid_pos,
    to = to_pos,
    surface = player.surface,
    players = { player },
    -- time_to_live = 300
  })
  storage.drag_rendering = { line1, line2 }
end

local function on_drag(player, position)
  local current_segment = get_current_segment()

  if current_segment == nil or current_segment.from == nil then
    local pos = { x = math.floor(position.x), y = math.floor(position.y) }
    table.insert(storage.segments, {
      from = pos,
      to = pos,
      orientation = nil
    })
    storage.current_segment_index = #storage.segments

    print("Drag start set at (" .. pos.x .. "," .. pos.y .. ")")
    return
  end


  current_segment.to = { x = math.floor(position.x), y = math.floor(position.y) }

  print("Drag last set at (" .. math.floor(position.x) .. "," .. math.floor(position.y) .. ")")

  if current_segment.orientation == nil then
    -- determine starting orientation based on the second point
    local dx = math.abs(current_segment.to.x - current_segment.from.x)
    local dy = math.abs(current_segment.to.y - current_segment.from.y)

    if dx == dy then
      player.create_local_flying_text({
        text = "Equal distance dragged, waiting",
        create_at_cursor = true
      })
    else
      current_segment.orientation = dy > dx and "vertical" or "horizontal"
      player.create_local_flying_text({
        text = current_segment.orientation == "vertical" and "Vertical-first" or "Horizontal-first",
        create_at_cursor = true
      })
    end
  end


  local start_x = math.floor(current_segment.from.x)
  local start_y = math.floor(current_segment.from.y)
  local end_x = math.floor(position.x)
  local end_y = math.floor(position.y)

  if storage.drag_rendering == nil then
    storage.drag_rendering = {}
  end

  if storage.auto_orientation and current_segment.to then
    local dx = math.abs(current_segment.to.x - current_segment.from.x)
    local dy = math.abs(current_segment.to.y - current_segment.from.y)

    if current_segment.orientation == "vertical" and dy == 0 then
      current_segment.orientation = "horizontal"
    elseif current_segment.orientation == "horizontal" and dx == 0 then
      current_segment.orientation = "vertical"
    end
  end

  clear_rendering()
  render_line(player,
    { x = start_x + 0.5, y = start_y + 0.5 },
    { x = end_x + 0.5, y = end_y + 0.5 }
  )
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

local function place_from_inventory(player, item, pos)
  local inventory = player.get_inventory(defines.inventory.character_main)
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

local function on_release_cleanup(player, setTool)
  storage.segments = {}
  storage.current_segment_index = nil
  storage.auto_orientation = true
  storage.dragging = false
  clear_rendering()
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

  local current_segment = get_current_segment()

  if current_segment == nil or current_segment.from == nil then
    -- release without a drag start????
    on_release_cleanup(player)
    return
  end


  print(mode .. " selected area from (" ..
    event.area.left_top.x ..
    "," .. event.area.left_top.y .. ") to (" .. event.area.right_bottom.x .. "," .. event.area.right_bottom.y .. ")")



  if not current_segment.to or current_segment.from == current_segment.to then
    place(player, mode, {
      x = math.floor(current_segment.from.x),
      y = math.floor(current_segment.from.y),
      direction = storage.starting_direction or defines.direction.north
    })

    on_release_cleanup(player)
    return
  end

  local start_x = math.floor(current_segment.from.x)
  local start_y = math.floor(current_segment.from.y)

  local end_x = math.floor(current_segment.to.x)
  local end_y = math.floor(current_segment.to.y)

  if end_x == start_x and end_y == start_y then return end

  ---@type {x: number, y: number, direction: defines.direction}[]
  local belt_positions = {}

  -- Determine orientation based on longer side if auto
  local horizontal_length = math.abs(end_x - start_x)
  local vertical_length = math.abs(end_y - start_y)

  print("Horizontal length: " .. horizontal_length .. ", Vertical length: " .. vertical_length)

  if current_segment.orientation == "vertical" then
    local y_dir = end_y > start_y and defines.direction.south or defines.direction.north
    local x_dir = end_x > start_x and defines.direction.east or defines.direction.west
    local has_horizontal = start_x ~= end_x

    -- Vertical first
    if start_y < end_y then
      for y = start_y, end_y do
        local is_last = (y == end_y) and has_horizontal
        table.insert(belt_positions, { x = start_x, y = y, direction = is_last and x_dir or y_dir })
      end
    elseif start_y > end_y then
      for y = start_y, end_y, -1 do
        local is_last = (y == end_y) and has_horizontal
        table.insert(belt_positions, { x = start_x, y = y, direction = is_last and x_dir or y_dir })
      end
    end
    if start_x < end_x then
      for x = start_x, end_x do
        table.insert(belt_positions, { x = x, y = end_y, direction = x_dir })
      end
    elseif start_x > end_x then
      for x = start_x, end_x, -1 do
        table.insert(belt_positions, { x = x, y = end_y, direction = x_dir })
      end
    end
  else
    local x_dir = end_x > start_x and defines.direction.east or defines.direction.west
    local y_dir = end_y > start_y and defines.direction.south or defines.direction.north
    local has_vertical = start_y ~= end_y

    -- Horizontal first
    if start_x < end_x then
      for x = start_x, end_x do
        local is_last = (x == end_x) and has_vertical
        table.insert(belt_positions, { x = x, y = start_y, direction = is_last and y_dir or x_dir })
      end
    elseif start_x > end_x then
      for x = start_x, end_x, -1 do
        local is_last = (x == end_x) and has_vertical
        table.insert(belt_positions, { x = x, y = start_y, direction = is_last and y_dir or x_dir })
      end
    end
    if start_y < end_y then
      for y = start_y, end_y do
        table.insert(belt_positions, { x = end_x, y = y, direction = y_dir })
      end
    elseif start_y > end_y then
      for y = start_y, end_y, -1 do
        table.insert(belt_positions, { x = end_x, y = y, direction = y_dir })
      end
    end
  end

  for _, pos in pairs(belt_positions) do
    place(player, mode, pos)
  end

  on_release_cleanup(player)
end

local function on_flip_orientation(player)
  if not is_holding_bp_tool(player) then return end

  local current_segment = get_current_segment()

  if current_segment == nil then return end

  -- storage.auto_orientation = false
  if current_segment.orientation == "horizontal" then
    current_segment.orientation = "vertical"
  else
    current_segment.orientation = "horizontal"
  end
  -- player.create_local_flying_text({
  --   text = current_segment.orientation == "vertical" and "Vertical-first" or "Horizontal-first",
  --   create_at_cursor = true
  -- })
  clear_rendering()
  render_line(player,
    { x = current_segment.from.x + 0.5, y = current_segment.from.y + 0.5 },
    { x = current_segment.to.x + 0.5, y = current_segment.to.y + 0.5 }
  )
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

  on_flip_orientation(player)
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
  on_drag(player, event.position)
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
