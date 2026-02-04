local findLDivergencePoint = require("divergence")

---@alias Position {x: number, y: number}
---@alias Node {x: number, y: number, direction: defines.direction, render: LuaRenderObject? , belt_type: "above"|"down"|"up"|"under"|nil}


---@class Segment
---@field from Position
---@field to Position
---@field prev_to Position?
---@field midpoint Position
---@field orientation "horizontal"|"vertical"|nil
---@field self_id number|nil
---@field nodes Node[]
---@field player LuaPlayer
---@field orientation_override "horizontal"|"vertical"|nil
local Segment = {}
Segment.__index = Segment

---@param from Position
---@param player LuaPlayer
---@param self_id number
---@return Segment
function Segment.new(from, first_node_direction, player, self_id)
  local self = setmetatable({}, Segment)
  self.from = from
  self.to = from
  self.prev_to = nil
  self.midpoint = { x = from.x, y = from.y }
  self.orientation = nil
  self.self_id = self_id
  self.max_segment_id = self_id
  self.nodes = {
    {
      x = from.x,
      y = from.y,
      direction = first_node_direction,
      render = nil,
      belt_type = "above"
    }
  }
  self.player = player
  self.orientation_override = nil
  self:check_orientation_override()
  self:plan_belts()
  self:visualize()
  return self
end

function Segment:check_orientation_override()
  local entity = self.player.surface.find_entities_filtered({
    area = {
      { self.from.x - 0.5, self.from.y - 0.5 },
      { self.from.x + 0.5, self.from.y + 0.5 }
    }
  })[1]
  local type = entity and (entity.type == "entity-ghost" and entity.ghost_type or entity.type)


  if type == "splitter" then
    local direction = entity.direction
    if direction == defines.direction.north or direction == defines.direction.south then
      self.orientation_override = "vertical"
    else
      self.orientation_override = "horizontal"
    end
  elseif type == "underground-belt" and entity.belt_to_ground_type == "output" then
    local direction = entity.direction
    if direction == defines.direction.north or direction == defines.direction.south then
      self.orientation_override = "vertical"
    else
      self.orientation_override = "horizontal"
    end
  end
end

function Segment:destroy()
  self:clear_visualization()
end

---@param max_segment_id number
function Segment:update_max_segment_id(max_segment_id)
  self.max_segment_id = max_segment_id
  if self.self_id == max_segment_id - 1 then
    self:visualize()
  end
end

function Segment:update_midpoint()
  self.midpoint = self.orientation == "vertical" and { x = self.from.x, y = self.to.y } or
      { x = self.to.x, y = self.from.y }
end

---@param pos Position
function Segment:update_to(pos)
  -- Early return if position hasn't changed
  if self.to.x == pos.x and self.to.y == pos.y then
    return
  end

  -- Save old 'to' position and orientation before updating
  local prev_to = { x = self.to.x, y = self.to.y }
  local prev_orientation = self.orientation
  self.prev_to = prev_to
  self.to = pos

  if self.orientation_override ~= nil then
    self.orientation = self.orientation_override
  else
    local side_lengths = self:get_side_lengths()

    if self.orientation == nil then
      if side_lengths.x ~= side_lengths.y then
        self.orientation = side_lengths.y > side_lengths.x and "vertical" or "horizontal"
      end
    end

    if self.orientation == "vertical" and side_lengths.y == 0 then
      self.orientation = "horizontal"
    elseif self.orientation == "horizontal" and side_lengths.x == 0 then
      self.orientation = "vertical"
    end
  end

  local divergence = findLDivergencePoint(self.from, self.prev_to, self.to,
    prev_orientation or self.orientation or "horizontal")
  local divergenceIndex = divergence and divergence.index or 0
  self:update_midpoint()
  self:update_nodes(divergenceIndex)
  self:plan_belts(divergenceIndex)
  self:visualize(divergenceIndex)
end

function Segment:clear_visualization()
  for _, node in pairs(self.nodes) do
    if node.render ~= nil then
      node.render.destroy()
      node.render = nil
    end
  end
end

local scale = 0.5

---@param node Node
function Segment:render_anchor(node)
  local sprite = {
    sprite = "belt-planner-anchor",
    x_scale = scale,
    y_scale = scale,
    target = { x = node.x, y = node.y },
    surface = self.player.surface,
  }
  node.render = rendering.draw_sprite(sprite)
end

---@param node Node
function Segment:render_node(node)
  local sprite_name = "belt-planner-nil"
  if node.belt_type == "above" then
    sprite_name = "belt-planner-above"
  elseif node.belt_type == "under" then
    sprite_name = "belt-planner-under"
  elseif node.belt_type == "down" or node.belt_type == "up" then
    sprite_name = "belt-planner-entryexit"
  end


  ---@type Position
  local target = { x = node.x, y = node.y }
  local sprite = {
    sprite = sprite_name,
    x_scale = scale,
    y_scale = scale,
    target = target,
    surface = self.player.surface,
    ---@type number
    orientation = node.direction * 0.0625 - 0.25,
  }
  node.render = rendering.draw_sprite(sprite)
end

---@param node Node
function Segment:update_render(node)
  if not node.render or not node.render.valid then
    return
  end

  node.render.orientation = node.direction * 0.0625 - 0.25
  if node.belt_type == "above" then
    node.render.sprite = "belt-planner-above"
  elseif node.belt_type == "under" then
    node.render.sprite = "belt-planner-under"
  elseif node.belt_type == "down" or node.belt_type == "up" then
    node.render.sprite = "belt-planner-entryexit"
  elseif node.belt_type == nil then
    node.render.sprite = "belt-planner-nil"
  end
end

---@param divergence_index number?
function Segment:visualize(divergence_index)
  divergence_index = divergence_index or 0
  local more_exist = self.self_id < self.max_segment_id
  local target_count = more_exist and (#self.nodes - 1) or #self.nodes

  -- Only update/create render objects from divergence point onwards
  for i = divergence_index + 1, target_count do
    local node = self.nodes[i]
    local is_anchor = (i == 1 and self.self_id ~= 1)

    if node.render and node.render.valid then
      -- Update existing render object
      node.render.target = { x = node.x, y = node.y }
      if not is_anchor then
        self:update_render(node)
      end
    else
      -- Create new render object
      if is_anchor then
        self:render_anchor(node)
      else
        self:render_node(node)
      end
    end
  end

  -- Clean up excess render objects
  for i = target_count + 1, #self.nodes do
    local node = self.nodes[i]
    if node.render and node.render.valid then
      node.render.destroy()
      node.render = nil
    end
  end
end

---@return number
function Segment:length()
  local dx = math.abs(self.to.x - self.from.x)
  local dy = math.abs(self.to.y - self.from.y)
  return dx + dy
end

function Segment:get_side_lengths()
  local dx = math.abs(self.to.x - self.from.x)
  local dy = math.abs(self.to.y - self.from.y)
  return { x = dx, y = dy }
end

---@return boolean
function Segment:is_single_point()
  return self.from.x == self.to.x and self.from.y == self.to.y
end

function Segment:flip_orientation()
  if self.orientation == "horizontal" then
    self.orientation = "vertical"
  elseif self.orientation == "vertical" then
    self.orientation = "horizontal"
  end
  self.orientation_override = nil
  self.prev_to = nil -- Reset cache to force full update
  self:update_midpoint()
  self:update_nodes(0)
  self:plan_belts(0)
  self:visualize()
end

--- @param skip number Number of nodes to skip from the start
--- @return {point: Position, index: number}|nil
function Segment:update_nodes(skip)
  -- Generate new path from divergence point
  local new_nodes = self:get_nodes(skip)

  -- Reuse old node tables where possible, append new ones
  local final_count = skip + #new_nodes

  -- Update nodes after divergence point
  for i = 1, #new_nodes do
    local target_idx = skip + i
    if self.nodes[target_idx] then
      -- Reuse existing table
      local new_node = new_nodes[i]
      new_node.render = self.nodes[target_idx].render
      -- Update existing node
      self.nodes[target_idx] = new_node
    else
      -- Append new node
      self.nodes[target_idx] = new_nodes[i]
    end
  end

  -- Clean up excess nodes beyond final count
  for i = final_count + 1, #self.nodes do
    local node = self.nodes[i]
    if node and node.render and node.render.valid then
      node.render.destroy()
    end
    self.nodes[i] = nil
  end
end

---@param skip number? Number of nodes to skip from the start (default 0)
---@return Node[]
function Segment:get_nodes(skip)
  skip = skip or 0
  ---@type Node[]
  local nodes = {}
  local from = self.from
  local to = self.to

  if self.orientation == "vertical" then
    local y_dir = to.y > from.y and defines.direction.south or defines.direction.north
    local x_dir = to.x > from.x and defines.direction.east or defines.direction.west
    local has_horizontal = from.x ~= to.x
    local y_step = to.y > from.y and 1 or -1
    local x_step = to.x > from.x and 1 or -1

    -- Vertical segment
    local y = from.y
    local idx = 0
    local count = 0
    while true do
      if idx >= skip then
        local is_last = (y == to.y) and has_horizontal
        count = count + 1
        nodes[count] = { x = from.x, y = y, direction = is_last and x_dir or y_dir, render = nil }
      end
      idx = idx + 1
      if y == to.y then break end
      y = y + y_step
    end

    -- Horizontal segment
    if has_horizontal then
      local x = from.x + x_step
      while true do
        if idx >= skip then
          count = count + 1
          nodes[count] = { x = x, y = to.y, direction = x_dir, render = nil }
        end
        idx = idx + 1
        if x == to.x then break end
        x = x + x_step
      end
    end
  else
    local x_dir = to.x > from.x and defines.direction.east or defines.direction.west
    local y_dir = to.y > from.y and defines.direction.south or defines.direction.north
    local has_vertical = from.y ~= to.y
    local x_step = to.x > from.x and 1 or -1
    local y_step = to.y > from.y and 1 or -1

    -- Horizontal segment
    local x = from.x
    local idx = 0
    local count = 0
    while true do
      if idx >= skip then
        local is_last = (x == to.x) and has_vertical
        count = count + 1
        nodes[count] = { x = x, y = from.y, direction = is_last and y_dir or x_dir, render = nil }
      end
      idx = idx + 1
      if x == to.x then break end
      x = x + x_step
    end

    -- Vertical segment
    if has_vertical then
      local y = from.y + y_step
      while true do
        if idx >= skip then
          count = count + 1
          nodes[count] = { x = to.x, y = y, direction = y_dir, render = nil }
        end
        idx = idx + 1
        if y == to.y then break end
        y = y + y_step
      end
    end
  end
  return nodes
end

---@param start_node Node
function Segment:invalidate_underground(start_node)
  -- Find the index of the start node
  local start_idx = nil
  for i = 1, #self.nodes do
    if self.nodes[i] == start_node then
      start_idx = i
      break
    end
  end

  if not start_idx then
    return
  end

  -- Find the full extent of the underground (entry to exit)
  ---@type number
  local min_idx = start_idx
  ---@type number
  local max_idx = start_idx

  -- Search backwards for entry
  for i = start_idx - 1, 1, -1 do
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "under" or self.nodes[i].belt_type == "up" then
      min_idx = i
    else
      break
    end
  end

  -- Search forwards for exit
  for i = start_idx + 1, #self.nodes do
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "under" or self.nodes[i].belt_type == "up" then
      max_idx = i
    else
      break
    end
  end

  -- Invalidate all nodes in the underground
  for i = min_idx, max_idx do
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "up" then
      self.nodes[i].belt_type = "above"
    elseif self.nodes[i].belt_type == "under" then
      self.nodes[i].belt_type = nil
    end
    self:update_render(self.nodes[i])
  end
end

function Segment:plan_belts(skip)
  -- Process backwards from end to skip
  for i = #self.nodes, (skip or 0) + 1, -1 do
    local node = self.nodes[i]

    if node.belt_type == "under" and i == #self.nodes then
      -- invalidate trailing underground
      self:invalidate_underground(node)
    end


    -- Skip nodes that already have underground assignments
    if node.belt_type == "under" or node.belt_type == "down" or node.belt_type == "up" then
      goto continue
    end

    --- @type LuaEntity|nil
    local entity = self.player.surface.find_entities_filtered({
      area = {
        { node.x - 0.5, node.y - 0.5 },
        { node.x + 0.5, node.y + 0.5 }
      }
    })[1]

    if entity and entity.type == "character" then
      entity = nil
    end

    if entity then
      node.belt_type = nil     -- Entity blocks placement
    else
      node.belt_type = "above" -- Can place regular belt

      local previous_node = self.nodes[i - 1]

      if not previous_node then
        goto continue
      end

      -- Check if we need to invalidate previous underground due to direction change
      if previous_node.belt_type == "up" then
        local previous_previous_node = self.nodes[i - 2]
        if previous_previous_node and
            node.direction == previous_node.direction and
            previous_node.direction ~= previous_previous_node.direction then
          self:invalidate_underground(previous_node)
        end
      end

      local entry_index = nil
      local underground_length = 0
      if previous_node.belt_type == nil then
        local exit_direction = node.direction
        while underground_length < 4 do
          local check_node_blocked = self.nodes[i - underground_length - 1]
          local check_node_entry = self.nodes[i - underground_length - 2]

          if not check_node_entry then
            break
          end

          if check_node_blocked.direction ~= exit_direction then
            break
          end

          if check_node_entry.belt_type == "above" and check_node_blocked.belt_type == nil then
            -- Verify entry node also has same direction
            if check_node_entry.direction == exit_direction then
              entry_index = i - underground_length - 2
              underground_length = underground_length + 1
            end
            break
          end

          if check_node_blocked.belt_type ~= nil then
            break
          end

          underground_length = underground_length + 1
        end
      end

      if entry_index then
        -- Set entry node to down
        self.nodes[entry_index].belt_type = "down"
        self:update_render(self.nodes[entry_index])
        -- Set underground nodes to under
        for j = entry_index + 1, entry_index + underground_length do
          self.nodes[j].belt_type = "under"
          self:update_render(self.nodes[j])
        end
        -- Set exit node to up
        self.nodes[entry_index + underground_length + 1].belt_type = "up"
        self:update_render(self.nodes[entry_index + underground_length + 1])
      end

      print(entry_index, underground_length)
    end
    ::continue::
  end
end

return Segment
---@export Node
---@export Position
