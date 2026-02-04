local findLDivergencePoint = require("divergence")

---@alias Node {x: number, y: number, direction: defines.direction, render: LuaRenderObject? , belt: "above"|"down"|"up"|"under"?}


---@class Segment
---@field from {x: number, y: number}
---@field to {x: number, y: number}
---@field prev_to {x: number, y: number}?
---@field midpoint {x: number, y: number}
---@field orientation "horizontal"|"vertical"|nil
---@field self_id number|nil
---@field nodes Node[]
---@field surface LuaSurface
local Segment = {}
Segment.__index = Segment

---@param from {x: number, y: number}
---@param surface LuaSurface
---@param self_id number
---@return Segment
function Segment.new(from, first_node_direction, surface, self_id)
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
    }
  }
  self.surface = surface
  self:visualize()
  return self
end

function Segment:destroy()
  self:clear_visualization()
end

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

---@param pos {x: number, y: number}
function Segment:update_to(pos, update_orientation)
  -- Early return if position hasn't changed
  if self.to.x == pos.x and self.to.y == pos.y then
    return
  end

  -- Save old 'to' position and orientation before updating
  local prev_to = { x = self.to.x, y = self.to.y }
  local prev_orientation = self.orientation
  self.prev_to = prev_to
  self.to = pos

  local side_lengths = self:get_side_lengths()

  if self.orientation == nil then
    if side_lengths.x ~= side_lengths.y then
      self.orientation = side_lengths.y > side_lengths.x and "vertical" or "horizontal"
    end
  end

  if update_orientation then
    if self.orientation == "vertical" and side_lengths.y == 0 then
      self.orientation = "horizontal"
    elseif self.orientation == "horizontal" and side_lengths.x == 0 then
      self.orientation = "vertical"
    end
  end

  -- print("Updated segment to (" .. pos.x .. ", " .. pos.y .. ") with orientation: " .. tostring(self.orientation))

  -- print("Side lengths: x=" .. side_lengths.x .. " y=" .. side_lengths.y)

  -- print("Total length: " .. (side_lengths.x + side_lengths.y))

  self:update_midpoint()
  local divergence = self:update_nodes(prev_orientation)
  self:visualize(divergence and divergence.index or 0)
end

function Segment:clear_visualization()
  for _, node in pairs(self.nodes) do
    if node.render ~= nil then
      node.render.destroy()
      node.render = nil
    end
  end
end

function Segment:draw_arrow(node)
  local sprite = {
    sprite = "belt-planner-arrow",
    x_scale = 0.25,
    y_scale = 0.25,
    target = { x = node.x + 0.5, y = node.y + 0.5 },
    surface = self.surface,
    orientation = node.direction * 0.0625 - 0.25,
  }
  node.render = rendering.draw_sprite(sprite)
end

function Segment:draw_anchor(node)
  local sprite = {
    sprite = "belt-planner-anchor",
    x_scale = 0.25,
    y_scale = 0.25,
    target = { x = node.x + 0.5, y = node.y + 0.5 },
    surface = self.surface,
  }
  node.render = rendering.draw_sprite(sprite)
end

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
      node.render.target = { x = node.x + 0.5, y = node.y + 0.5 }
      if not is_anchor then
        node.render.orientation = node.direction * 0.0625 - 0.25
      end
    else
      -- Create new render object
      if is_anchor then
        self:draw_anchor(node)
      else
        self:draw_arrow(node)
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

function Segment:get_centered_positions()
  return {
    from = {
      x = (self.from.x + 0.5),
      y = (self.from.y + 0.5)
    },
    to = {
      x = (self.to.x + 0.5),
      y = (self.to.y + 0.5)
    }
  }
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
  self.prev_to = nil -- Reset cache to force full update
  self:update_midpoint()
  self:update_nodes()
  self:visualize()
end

--- @return {point: {x: number, y: number}, index: number}|nil
function Segment:update_nodes(prev_orientation)
  local divergence = findLDivergencePoint(self.from, self.prev_to, self.to, prev_orientation or self.orientation)
  local skip = divergence and divergence.index or 0

  -- Generate new path from divergence point
  local new_nodes = self:get_nodes(skip)

  -- Reuse old node tables where possible, append new ones
  local final_count = skip + #new_nodes

  -- Update nodes after divergence point
  for i = 1, #new_nodes do
    local target_idx = skip + i
    if self.nodes[target_idx] then
      -- Reuse existing table
      local node = self.nodes[target_idx]
      node.x = new_nodes[i].x
      node.y = new_nodes[i].y
      node.direction = new_nodes[i].direction
      -- Keep existing render object
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

  return divergence
end

---@param skip number? Number of nodes to skip from the start (default 0)
---@return Node[]
function Segment:get_nodes(skip)
  skip = skip or 0
  local belt_positions = {}
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
        belt_positions[count] = { x = from.x, y = y, direction = is_last and x_dir or y_dir, render = nil }
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
          belt_positions[count] = { x = x, y = to.y, direction = x_dir, render = nil }
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
        belt_positions[count] = { x = x, y = from.y, direction = is_last and y_dir or x_dir, render = nil }
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
          belt_positions[count] = { x = to.x, y = y, direction = y_dir, render = nil }
        end
        idx = idx + 1
        if y == to.y then break end
        y = y + y_step
      end
    end
  end
  return belt_positions
end

return Segment
