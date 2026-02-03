---@class Segment
---@field from {x: number, y: number}
---@field to {x: number, y: number}
---@field midpoint {x: number, y: number}
---@field orientation "horizontal"|"vertical"|nil
---@field self_id number|nil
---@field render_entity LuaEntity|nil
---@field surface LuaSurface
local Segment = {}
Segment.__index = Segment

---@param from {x: number, y: number}
---@param surface LuaSurface
---@param self_id number
---@param max_segment_id number|
---@return Segment
function Segment.new(from, surface, self_id, max_segment_id)
  local self = setmetatable({}, Segment)
  self.from = from
  self.to = from
  self.midpoint = { x = from.x, y = from.y }
  self.orientation = nil
  self.self_id = self_id or 1
  self.max_segment_id = max_segment_id
  self.render_entity = nil
  self.surface = surface
  return self
end

function Segment:update_max_segment_id(max_segment_id)
  self.max_segment_id = max_segment_id
end

function Segment:update_midpoint()
  self.midpoint = self.orientation == "vertical" and { x = self.from.x, y = self.to.y } or
      { x = self.to.x, y = self.from.y }
end

---@param pos {x: number, y: number}
function Segment:update_to(pos)
  self.to = pos

  if self.orientation == nil then
    local dx = math.abs(self.to.x - self.from.x)
    local dy = math.abs(self.to.y - self.from.y)

    if dx ~= dy then
      self.orientation = dy > dx and "vertical" or "horizontal"
    end
  end

  self:update_midpoint()
end

function Segment:clear_visualization()
  if self.render_entity ~= nil then
    self.render_entity.destroy()
    self.render_entity = nil
  end
end

function Segment:draw_arrow(pos, target_pos)
  local sprite = {
    sprite = "belt-planner-arrow",
    x_scale = 0.25,
    y_scale = 0.25,
    target = {
      entity = self.render_entity,
      offset = { x = pos.x + 0.5 - target_pos.x, y = pos.y + 0.5 - target_pos.y },
    },
    surface = self.surface,
    orientation = pos.direction / 16 - 0.25,
  }
  rendering.draw_sprite(sprite)
end

function Segment:draw_anchor(pos, target_pos)
  local sprite = {
    sprite = "belt-planner-anchor",
    x_scale = 0.25,
    y_scale = 0.25,
    target = {
      entity = self.render_entity,
      offset = { x = pos.x + 0.5 - target_pos.x, y = pos.y + 0.5 - target_pos.y },
    },
    surface = self.surface,
  }
  rendering.draw_sprite(sprite)
end

function Segment:visualize()
  self:clear_visualization()

  if self.render_entity == nil then
    self.render_entity = self.surface.create_entity({
      name = "belt-planner-dummy-entity",
      position = { x = 0, y = 0 },
    })
  end

  local elements = self:get_elements_with_direction()
  local render_target_pos = self.render_entity.position

  local more_exist = self.self_id < self.max_segment_id

  for i, pos in pairs(elements) do
    if (i == #elements and more_exist) then
      goto continue
    end
    if (self:is_single_point() or (i == 1 and self.self_id ~= 1)) then
      self:draw_anchor(pos, render_target_pos)
    else
      self:draw_arrow(pos, render_target_pos)
    end
    ::continue::
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
  self:update_midpoint()
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

-- function Segment:set_orientation(orientation)
--   self.orientation = orientation
-- end

return Segment
