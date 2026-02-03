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
  if not self.prev_to then
    -- First update, generate full path
    self.nodes = self:get_elements_with_direction()
    return
  end

  -- Calculate which parts of the L-shape changed
  local prev_to = self.prev_to
  local curr_to = self.to
  local from = self.from

  if self.orientation == "vertical" then
    -- Vertical leg (from.x, from.y) -> (from.x, to.y)
    -- Horizontal leg (from.x, to.y) -> (to.x, to.y)
    local vert_changed = prev_to.y ~= curr_to.y
    local horiz_changed = prev_to.x ~= curr_to.x

    if not vert_changed and not horiz_changed then
      return -- Nothing changed
    end

    if vert_changed and horiz_changed then
      -- Both legs changed, full rebuild
      self.nodes = self:get_elements_with_direction()
      return
    end

    local y_dir = curr_to.y > from.y and defines.direction.south or defines.direction.north
    local x_dir = curr_to.x > from.x and defines.direction.east or defines.direction.west
    local y_step = curr_to.y > from.y and 1 or -1
    local x_step = curr_to.x > from.x and 1 or -1

    if vert_changed then
      -- Vertical leg changed, update from knee onwards
      local old_vert_len = math.abs(prev_to.y - from.y) + 1
      local new_vert_len = math.abs(curr_to.y - from.y) + 1
      local has_horizontal = from.x ~= curr_to.x

      -- Update/create vertical nodes
      local y = from.y
      local i = 1
      while true do
        local is_last = (y == curr_to.y) and has_horizontal
        local dir = is_last and x_dir or y_dir

        if i <= #self.nodes then
          -- Update existing node
          self.nodes[i].direction = dir
        else
          -- Add new node
          self.nodes[i] = { x = from.x, y = y, direction = dir, render = nil }
        end

        if y == curr_to.y then break end
        y = y + y_step
        i = i + 1
      end

      -- Update horizontal leg positions (they moved to new y)
      if has_horizontal then
        local horiz_start_idx = new_vert_len + 1
        local x = from.x + x_step
        local j = horiz_start_idx
        while true do
          if j <= #self.nodes then
            self.nodes[j].y = curr_to.y
          else
            self.nodes[j] = { x = x, y = curr_to.y, direction = x_dir, render = nil }
          end
          if x == curr_to.x then break end
          x = x + x_step
          j = j + 1
        end

        -- Cleanup excess nodes
        for k = j + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
      else
        -- No horizontal leg, cleanup from new_vert_len + 1 onwards
        for k = new_vert_len + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
      end
    else
      -- Only horizontal leg changed
      local vert_len = math.abs(curr_to.y - from.y) + 1
      local old_horiz_len = math.abs(prev_to.x - from.x)
      local new_horiz_len = math.abs(curr_to.x - from.x)

      if new_horiz_len == 0 then
        -- No horizontal leg anymore, cleanup
        for k = vert_len + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
        -- Update last vertical node direction
        if #self.nodes > 0 then
          self.nodes[#self.nodes].direction = y_dir
        end
      else
        -- Update/create horizontal nodes
        local x = from.x + x_step
        local i = vert_len + 1
        while true do
          if i <= #self.nodes then
            self.nodes[i].x = x
          else
            self.nodes[i] = { x = x, y = curr_to.y, direction = x_dir, render = nil }
          end
          if x == curr_to.x then break end
          x = x + x_step
          i = i + 1
        end

        -- Cleanup excess nodes
        for k = i + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end

        -- Ensure knee node has correct direction
        if vert_len > 0 then
          self.nodes[vert_len].direction = x_dir
        end
      end
    end
  else
    -- Horizontal-first orientation
    local horiz_changed = prev_to.x ~= curr_to.x
    local vert_changed = prev_to.y ~= curr_to.y

    if not horiz_changed and not vert_changed then
      return
    end

    if horiz_changed and vert_changed then
      self.nodes = self:get_elements_with_direction()
      return
    end

    local x_dir = curr_to.x > from.x and defines.direction.east or defines.direction.west
    local y_dir = curr_to.y > from.y and defines.direction.south or defines.direction.north
    local x_step = curr_to.x > from.x and 1 or -1
    local y_step = curr_to.y > from.y and 1 or -1

    if horiz_changed then
      local new_horiz_len = math.abs(curr_to.x - from.x) + 1
      local has_vertical = from.y ~= curr_to.y

      local x = from.x
      local i = 1
      while true do
        local is_last = (x == curr_to.x) and has_vertical
        local dir = is_last and y_dir or x_dir

        if i <= #self.nodes then
          self.nodes[i].direction = dir
        else
          self.nodes[i] = { x = x, y = from.y, direction = dir, render = nil }
        end

        if x == curr_to.x then break end
        x = x + x_step
        i = i + 1
      end

      if has_vertical then
        local vert_start_idx = new_horiz_len + 1
        local y = from.y + y_step
        local j = vert_start_idx
        while true do
          if j <= #self.nodes then
            self.nodes[j].x = curr_to.x
          else
            self.nodes[j] = { x = curr_to.x, y = y, direction = y_dir, render = nil }
          end
          if y == curr_to.y then break end
          y = y + y_step
          j = j + 1
        end

        for k = j + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
      else
        for k = new_horiz_len + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
      end
    else
      local horiz_len = math.abs(curr_to.x - from.x) + 1
      local new_vert_len = math.abs(curr_to.y - from.y)

      if new_vert_len == 0 then
        for k = horiz_len + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end
        if #self.nodes > 0 then
          self.nodes[#self.nodes].direction = x_dir
        end
      else
        local y = from.y + y_step
        local i = horiz_len + 1
        while true do
          if i <= #self.nodes then
            self.nodes[i].y = y
          else
            self.nodes[i] = { x = curr_to.x, y = y, direction = y_dir, render = nil }
          end
          if y == curr_to.y then break end
          y = y + y_step
          i = i + 1
        end

        for k = i + 1, #self.nodes do
          if self.nodes[k].render and self.nodes[k].render.valid then
            self.nodes[k].render.destroy()
          end
          self.nodes[k] = nil
        end

        if horiz_len > 0 then
          self.nodes[horiz_len].direction = y_dir
        end
      end
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
