---@class StorageData
---@field drag_start {x: number, y: number}?
---@field drag_last {x: number, y: number}?
---@field drag_rendering {[1]: LuaRenderObject, [2]: LuaRenderObject, [3]: LuaRenderObject?}?
---@field auto_orientation boolean
---@field orientation "horizontal"|"vertical"?

---@type StorageData
storage = storage

-- Initialize global state
script.on_init(function()
  storage.drag_start = nil
  storage.drag_last = nil
  storage.drag_rendering = nil
  storage.auto_orientation = true
  storage.orientation = nil
end)

script.on_configuration_changed(function()
  storage.drag_start = storage.drag_start or nil
  storage.drag_last = storage.drag_last or nil
  storage.drag_rendering = storage.drag_rendering or nil
  if storage.auto_orientation == nil then
    storage.auto_orientation = true
  end
  storage.orientation = storage.orientation or nil
end)

local function clear_rendering()
  if storage.drag_rendering then
    for _, rendering in pairs(storage.drag_rendering) do
      rendering.destroy()
    end
  end
end


local function render_line(player, from_pos, to_pos)
  -- draw 2 lines to make an L shape
  local mid_pos = storage.orientation == "vertical" and { x = from_pos.x, y = to_pos.y } or
      { x = to_pos.x, y = from_pos.y }
  local line1 = rendering.draw_line({
    color = { r = 1, g = 1, b = 1 },
    width = 3,
    from = from_pos,
    to = mid_pos,
    surface = player.surface,
    players = { player },
    time_to_live = 300
  })
  local line2 = rendering.draw_line({
    color = { r = 1, g = 1, b = 1 },
    width = 3,
    from = mid_pos,
    to = to_pos,
    surface = player.surface,
    players = { player },
    time_to_live = 300
  })
  storage.drag_rendering = { line1, line2 }
end

local function on_drag(player, position)
  if storage.drag_start == nil then
    storage.drag_start = { x = math.floor(position.x), y = math.floor(position.y) }
    player.print("Drag start set at (" .. math.floor(position.x) .. "," .. math.floor(position.y) .. ")")
  else
    storage.drag_last = { x = math.floor(position.x), y = math.floor(position.y) }
    player.print("Drag end set at (" .. math.floor(position.x) .. "," .. math.floor(position.y) .. ")")
  end


  local drag_start = storage.drag_start
  local start_x = math.floor(drag_start.x)
  local start_y = math.floor(drag_start.y)
  local end_x = math.floor(position.x)
  local end_y = math.floor(position.y)

  if storage.drag_rendering == nil then
    storage.drag_rendering = {}
  end

  if storage.drag_rendering then
    for _, rendering_id in pairs(storage.drag_rendering) do
      rendering_id.destroy()
    end
    storage.drag_rendering = nil
  end

  if storage.auto_orientation and storage.drag_last then
    local dx = math.abs(storage.drag_last.x - storage.drag_start.x)
    local dy = math.abs(storage.drag_last.y - storage.drag_start.y)
    if dx ~= dy then
      storage.orientation = dy > dx and "vertical" or "horizontal"
    end
  end

  render_line(player,
    { x = start_x + 0.5, y = start_y + 0.5 },
    { x = end_x + 0.5, y = end_y + 0.5 }
  )
end

local function on_release(player)
  local drag_start = storage.drag_start
  if not drag_start then
    print("No drag start recorded")
    return
  end
  local start_x = math.floor(storage.drag_start.x)
  local start_y = math.floor(storage.drag_start.y)

  local end_x = math.floor(storage.drag_last.x)
  local end_y = math.floor(storage.drag_last.y)

  if end_x == start_x and end_y == start_y then return end


  local belt_positions = {}

  -- Determine orientation based on longer side if auto
  local horizontal_length = math.abs(end_x - start_x)
  local vertical_length = math.abs(end_y - start_y)

  print("Horizontal length: " .. horizontal_length .. ", Vertical length: " .. vertical_length)

  if storage.orientation == "vertical" then
    local y_dir = end_y > start_y and defines.direction.south or defines.direction.north
    local x_dir = end_x > start_x and defines.direction.east or defines.direction.west
    local has_horizontal = start_x ~= end_x

    -- Vertical first
    if start_y < end_y then
      for y = start_y, end_y do
        local is_last = (y == end_y) and has_horizontal
        table.insert(belt_positions, { x = start_x, y = y, direction = is_last and x_dir or y_dir })
      end
    else
      for y = start_y, end_y, -1 do
        local is_last = (y == end_y) and has_horizontal
        table.insert(belt_positions, { x = start_x, y = y, direction = is_last and x_dir or y_dir })
      end
    end
    if start_x < end_x then
      for x = start_x, end_x do
        table.insert(belt_positions, { x = x, y = end_y, direction = x_dir })
      end
    else
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
    else
      for x = start_x, end_x, -1 do
        local is_last = (x == end_x) and has_vertical
        table.insert(belt_positions, { x = x, y = start_y, direction = is_last and y_dir or x_dir })
      end
    end
    if start_y < end_y then
      for y = start_y, end_y do
        table.insert(belt_positions, { x = end_x, y = y, direction = y_dir })
      end
    else
      for y = start_y, end_y, -1 do
        table.insert(belt_positions, { x = end_x, y = y, direction = y_dir })
      end
    end
  end

  for _, pos in pairs(belt_positions) do
    player.surface.create_entity({
      name = "entity-ghost",
      ghost_name = "transport-belt",
      position = { x = pos.x + 0.5, y = pos.y + 0.5 },
      direction = pos.direction,
      force = player.force,
      player = player,
    })
  end
end

local function on_flip_orientation(player)
  if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == "belt-planner" then
    storage.auto_orientation = false
    if storage.orientation == "horizontal" then
      storage.orientation = "vertical"
    else
      storage.orientation = "horizontal"
    end
    -- player.create_local_flying_text({
    --   text = storage.orientation == "vertical" and "Vertical-first" or "Horizontal-first",
    --   create_at_cursor = true
    -- })
    clear_rendering()
    render_line(player,
      { x = storage.drag_start.x + 0.5, y = storage.drag_start.y + 0.5 },
      { x = storage.drag_last.x + 0.5, y = storage.drag_last.y + 0.5 }
    )
  end
end

local function set_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack then
    if not cursor_stack.valid_for_read or cursor_stack.name == "belt-planner" or player.clear_cursor() then
      cursor_stack.set_stack({ name = "belt-planner", count = 1 })
    end
    if player.controller_type == defines.controllers.character and player.character_build_distance_bonus < 1000000 then
      player.character_build_distance_bonus = player.character_build_distance_bonus + 1000000
    end
  end
end

-- Handle selection area (drag and release)
script.on_event(defines.events.on_player_selected_area, function(event)
  if event.item ~= "belt-planner" then return end

  print("Selected area from (" ..
    event.area.left_top.x ..
    "," .. event.area.left_top.y .. ") to (" .. event.area.right_bottom.x .. "," .. event.area.right_bottom.y .. ")")

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  clear_rendering()
  on_release(player)

  storage.drag_start = nil
  storage.drag_last = nil
  storage.auto_orientation = true
end)


script.on_event("belt-planner-flip-orientation", function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  on_flip_orientation(player)
end)


script.on_event(defines.events.on_player_rotated_entity, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == "belt-planner" then
    if storage.auto_orientation then
      -- Determine current auto orientation and flip it
      if storage.drag_start and storage.drag_last then
        local dx = math.abs(storage.drag_last.x - storage.drag_start.x)
        local dy = math.abs(storage.drag_last.y - storage.drag_start.y)
        local current_vertical = dy >= dx
        storage.orientation = current_vertical and "horizontal" or "vertical"
      else
        storage.orientation = "vertical"
      end
      storage.auto_orientation = false
    elseif storage.orientation == "horizontal" then
      storage.orientation = "vertical"
    else
      storage.orientation = "horizontal"
    end
    player.create_local_flying_text({
      text = storage.orientation == "vertical" and "Vertical-first" or "Horizontal-first",
      create_at_cursor = true
    })

    -- Redraw if currently dragging
    if storage.drag_start and storage.drag_last then
      local drag_start = storage.drag_start
      local drag_current = storage.drag_last

      clear_rendering()

      local renderings = render_line(player,
        { x = drag_start.x + 0.5, y = drag_start.y + 0.5 },
        { x = drag_current.x + 0.5, y = drag_current.y + 0.5 }
      )

      local belt_sprite = rendering.draw_sprite({
        sprite = "item/transport-belt",
        target = { x = drag_current.x + 0.5, y = drag_current.y + 0.5 },
        surface = player.surface,
        players = { player },
        time_to_live = 300,
        x_scale = 0.5,
        y_scale = 0.5
      })

      storage.drag_rendering = { renderings[1], renderings[2], belt_sprite }
    end
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  local entity = event.entity
  local name = entity.name
  if name == "entity-ghost" then
    name = entity.ghost_name
  end


  if name ~= "bp-dummy-entity" then return end
  local position, surface = entity.position, entity.surface
  entity.destroy()

  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  set_tool(player)

  on_drag(player, position)
end)
