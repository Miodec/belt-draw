---@class Segment
---@field from {x: number, y: number}
---@field to {x: number, y: number}
---@field orientation "horizontal"|"vertical"|nil
local Segment = {}
Segment.__index = Segment

---@param from {x: number, y: number}
---@param to {x: number, y: number}?
---@return Segment
function Segment.new(from, to)
  local self = setmetatable({}, Segment)
  self.from = from
  self.to = to or from
  self.orientation = nil
  return self
end

---@param pos {x: number, y: number}
function Segment:update_to(pos)
  self.to = pos

  -- if self.orientation == nil then
  --   local dx = math.abs(self.to.x - self.from.x)
  --   local dy = math.abs(self.to.y - self.from.y)

  --   if dx ~= dy then
  --     self.orientation = dy > dx and "vertical" or "horizontal"
  --   end
  -- end
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
end

function Segment:get_midpoint()
  return self.orientation == "vertical" and { x = self.from.x, y = self.to.y } or { x = self.to.x, y = self.from.y }
end

function Segment:get_centered_midpoint()
  local mid = self:get_midpoint()
  return { x = mid.x + 0.5, y = mid.y + 0.5 }
end

-- function Segment:set_orientation(orientation)
--   self.orientation = orientation
-- end

return Segment
