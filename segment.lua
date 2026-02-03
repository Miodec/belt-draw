---@class Segment
---@field from {x: number, y: number}
---@field to {x: number, y: number}
---@field prev_to {x: number, y: number}?
---@field midpoint {x: number, y: number}
---@field orientation "horizontal"|"vertical"|nil
---@field self_id number|nil
---@field nodes {x: number, y: number, direction: defines.direction, render: LuaRenderObject?}[]
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
  if self.prev_to and self.prev_to.x == pos.x and self.prev_to.y == pos.y then
    return
  end

  self.to = pos
  self.prev_to = { x = pos.x, y = pos.y }

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

  self:update_midpoint()
  self:update_nodes()
  self:visualize()
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
    orientation = node.direction / 16 - 0.25,
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

function Segment:visualize()
  local more_exist = self.self_id < self.max_segment_id
  local target_count = more_exist and (#self.nodes - 1) or #self.nodes

  -- Update existing render objects or create new ones
  for i = 1, target_count do
    local node = self.nodes[i]
    local is_anchor = (i == 1 and self.self_id ~= 1)
    local target_pos = { x = node.x + 0.5, y = node.y + 0.5 }

    if node.render and node.render.valid then
      -- Update existing render object
      node.render.target = target_pos
      if not is_anchor then
        node.render.orientation = node.direction / 16 - 0.25
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

function Segment:update_nodes()
  local old_nodes = self.nodes
  self.nodes = self:get_elements_with_direction()

  -- Transfer render objects from matching old nodes
  for i, new_node in ipairs(self.nodes) do
    if old_nodes[i] and old_nodes[i].x == new_node.x and old_nodes[i].y == new_node.y then
      new_node.render = old_nodes[i].render
      old_nodes[i].render = nil
    end
  end

  -- Clean up any remaining old render objects
  for _, old_node in ipairs(old_nodes) do
    if old_node.render and old_node.render.valid then
      old_node.render.destroy()
    end
  end
end

---@return {x: number, y: number, direction: defines.direction}[]
function Segment:get_elements_with_direction()
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
    while true do
      local is_last = (y == to.y) and has_horizontal
      belt_positions[#belt_positions + 1] = { x = from.x, y = y, direction = is_last and x_dir or y_dir }
      if y == to.y then break end
      y = y + y_step
    end

    -- Horizontal segment
    if has_horizontal then
      local x = from.x + x_step
      while true do
        belt_positions[#belt_positions + 1] = { x = x, y = to.y, direction = x_dir }
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
    while true do
      local is_last = (x == to.x) and has_vertical
      belt_positions[#belt_positions + 1] = { x = x, y = from.y, direction = is_last and y_dir or x_dir }
      if x == to.x then break end
      x = x + x_step
    end

    -- Vertical segment
    if has_vertical then
      local y = from.y + y_step
      while true do
        belt_positions[#belt_positions + 1] = { x = to.x, y = y, direction = y_dir }
        if y == to.y then break end
        y = y + y_step
      end
    end
  end
  return belt_positions
end

return Segment
