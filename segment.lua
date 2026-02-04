local findLDivergencePoint = require("divergence")

---@alias BeltType "above"|"down"|"up"|"under"|"under_entity"|"blocked"|"above_connect"
---@alias Position {x: number, y: number}
---@alias Node {x: number, y: number, direction: defines.direction, render: LuaRenderObject? , belt_type: BeltType|nil}


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

---@param node Node
---@return LuaEntity|nil
function Segment:find_entity_at_node(node)
  local entity = self.player.surface.find_entities_filtered({
    area = { { node.x - 0.5, node.y - 0.5 }, { node.x + 0.5, node.y + 0.5 } }
  })[1]
  if entity and entity.type == "character" then
    return nil
  end
  return entity
end

---@param entity LuaEntity
---@param node Node
---@return "replace"|"block"|"connect"
function Segment:get_compatibility(entity, node)
  local type = entity.type == "entity-ghost" and entity.ghost_type or entity.type
  if type ~= "transport-belt" and type ~= "underground-belt" and type ~= "splitter" then
    return "block"
  end

  if (type == "splitter" or type == "underground-belt") then
    if (entity.direction == node.direction) then
      -- if (entity.direction == node.direction or entity.direction == (node.direction + 8) % 16) then
      return "connect"
    else
      return "block"
    end
  end


  if type == "transport-belt" then
    if (entity.belt_shape == "right" or entity.belt_shape == "left") and entity.belt_neighbours.outputs[1] and entity.belt_neighbours.inputs[1] then
      return "block"
    end
    if (entity.belt_shape == "straight" and entity.belt_neighbours.outputs[1] and entity.direction ~= node.direction and entity.direction ~= (node.direction + 8) % 16) then
      return "block"
    else
      return "replace"
    end
  end

  return "replace"
end

---@param node Node
---@return Position
function Segment:get_next_position(node)
  local pos = { x = node.x, y = node.y }
  if node.direction == defines.direction.north then
    pos.y = pos.y - 1
  elseif node.direction == defines.direction.south then
    pos.y = pos.y + 1
  elseif node.direction == defines.direction.east then
    pos.x = pos.x + 1
  elseif node.direction == defines.direction.west then
    pos.x = pos.x - 1
  end
  return pos
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
    sprite = "belt-draw-anchor",
    x_scale = scale,
    y_scale = scale,
    target = { x = node.x, y = node.y },
    surface = self.player.surface,
  }
  node.render = rendering.draw_sprite(sprite)
end

local function get_sprite_name_for_belt_type(belt_type)
  if belt_type == "above" then
    return "belt-draw-above"
  elseif belt_type == "under" or belt_type == "under_entity" or belt_type == "above_connect" then
    return "belt-draw-under"
  elseif belt_type == "down" or belt_type == "up" then
    return "belt-draw-entryexit"
  elseif belt_type == "blocked" then
    return "belt-draw-blocked"
  else
    return "belt-draw-empty"
  end
end

---@param node Node
function Segment:render_node(node)
  local sprite_name = nil
  sprite_name = get_sprite_name_for_belt_type(node.belt_type)

  if not sprite_name then
    return
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
    -- Create render if it doesn't exist
    self:render_node(node)
    return
  end

  node.render.orientation = node.direction * 0.0625 - 0.25
  local sprite_name = get_sprite_name_for_belt_type(node.belt_type)
  node.render.sprite = sprite_name
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

  for _, node in pairs(self.nodes) do
    node.belt_type = nil
  end

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
      -- Reuse existing table and preserve belt_type
      local old_belt_type = self.nodes[target_idx].belt_type
      local new_node = new_nodes[i]
      new_node.render = self.nodes[target_idx].render
      new_node.belt_type = old_belt_type
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

---@param node Node
---@return boolean
local function is_underground_type(node)
  local t = node.belt_type
  return t == "down" or t == "under" or t == "under_entity" or t == "up"
end

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
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "under" then
      min_idx = i
    else
      break
    end
  end

  -- Search forwards for exit
  for i = start_idx + 1, #self.nodes do
    if self.nodes[i].belt_type == "under" or self.nodes[i].belt_type == "up" then
      max_idx = i
    else
      break
    end
  end

  -- Invalidate all nodes in the underground
  for i = min_idx, max_idx do
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "up" then
      self.nodes[i].belt_type = "above"
    elseif self.nodes[i].belt_type == "under_entity" then
      self.nodes[i].belt_type = "blocked"
    elseif self.nodes[i].belt_type == "under" then
      self.nodes[i].belt_type = "above"
    end
    self:update_render(self.nodes[i])
  end
end

function Segment:plan_belts(skip)
  skip = skip or 0

  -- When replanning from start (skip=0), clear all belt_types to allow fresh planning
  if skip == 0 then
    for _, node in ipairs(self.nodes) do
      node.belt_type = nil
    end
  end

  -- Handle trailing underground at end
  local last_node = self.nodes[#self.nodes]
  if last_node and last_node.belt_type == "under" then
    self:invalidate_underground(last_node)
  end

  -- Process backwards from end to skip
  for i = #self.nodes, skip + 1, -1 do
    local node = self.nodes[i]
    local belt_type = node.belt_type

    -- Skip already assigned underground nodes
    if is_underground_type(node) then
      goto continue
    end

    -- Check for blocking entities
    local entity = self:find_entity_at_node(node)
    if entity then
      -- If it's a belt going in same direction, connect to it instead of blocking
      local compat = self:is_compatible_belt(entity, node.direction)
      if compat == "full" then
        node.belt_type = "above"
        goto continue
      end
      if compat == "partial" then
        node.belt_type = "under"
        goto continue
      end

      node.belt_type = "blocked"

      -- Invalidate any underground that starts after this blocked node
      local next_node = self.nodes[i + 1]
      if next_node and is_underground_type(next_node) then
        self:invalidate_underground(next_node)
      end

      goto continue
    end

    local prev = self.nodes[i - 1]
    if not prev then
      node.belt_type = "above"
      goto continue
    end

    -- Invalidate previous underground on direction change
    if prev.belt_type == "up" then
      local prev_prev = self.nodes[i - 2]
      if prev_prev and
          node.direction == prev.direction and
          prev.direction ~= prev_prev.direction then
        self:invalidate_underground(prev)
      end
    end

    -- Try to create underground belt if previous node is blocked
    local prev_is_blocked = prev.belt_type == "blocked"
    if not prev_is_blocked and prev.belt_type == nil then
      local prev_entity = self:find_entity_at_node(prev)
      if prev_entity then
        -- Don't consider it blocked if it's a compatible belt
        prev_is_blocked = not self:is_compatible_belt(prev_entity, prev.direction) == "full"
      end
    end

    if prev_is_blocked then
      -- Check if this is a gap between entities (entity before and after)
      local next_pos = self:get_next_position(node)
      local next_entity = self.player.surface.find_entities_filtered({
        area = { { next_pos.x - 0.5, next_pos.y - 0.5 }, { next_pos.x + 0.5, next_pos.y + 0.5 } }
      })[1]
      local is_gap = next_entity and next_entity.type ~= "character"

      if is_gap then
        node.belt_type = "blocked"
        goto continue
      end

      local entry_idx, length = self:find_underground_entry(i)
      if entry_idx then
        self:create_underground(entry_idx, length)
        i = entry_idx + 1 -- Skip to avoid reprocessing
        goto continue
      end
    end

    -- Default to above-ground belt
    node.belt_type = "above"

    ::continue::
  end
end

---@param exit_idx number Exit node index
---@return number?, number Entry index and underground length, or nil
function Segment:find_underground_entry(exit_idx)
  local exit_dir = self.nodes[exit_idx].direction
  local length = 0

  local best_entry_idx = nil
  local best_length = 0

  while length < 4 do
    local blocked_idx = exit_idx - length - 1
    local entry_idx = exit_idx - length - 2

    local blocked = self.nodes[blocked_idx]
    local entry = self.nodes[entry_idx]

    if not entry then
      break
    end

    if not blocked then
      break
    end

    -- Direction must match throughout underground
    if blocked.direction ~= exit_dir then
      break
    end

    -- Verify blocked node is actually blocked
    local is_blocked = blocked.belt_type == "blocked" or
        (blocked.belt_type == nil and self:find_entity_at_node(blocked))

    -- Entry must be available for use
    local entry_available = entry.belt_type == "above" or entry.belt_type == nil

    -- Check if we can use this as an entry/exit pair
    if entry_available and is_blocked and entry.direction == exit_dir then
      -- Skip if entry has entity blocking it
      if self:find_entity_at_node(entry) then
        length = length + 1
        goto continue_search
      end

      -- Check for direction conflicts with previous node
      local before_entry = self.nodes[entry_idx - 1]
      if before_entry and before_entry.belt_type == "above" and before_entry.direction ~= entry.direction then
        break
      end

      -- Valid entry found, continue searching for longer underground
      best_entry_idx = entry_idx
      best_length = length + 1
      length = length + 1
      goto continue_search
    end

    -- Stop if entry direction doesn't match
    if entry_available and is_blocked and entry.direction ~= exit_dir then
      break
    end

    -- Stop if blocked node is assigned to something else
    if blocked.belt_type ~= "blocked" and blocked.belt_type ~= nil then
      break
    end

    length = length + 1
    ::continue_search::
  end

  if best_entry_idx then
    return best_entry_idx, best_length
  end

  return nil, 0
end

---@param entry_idx number Entry node index
---@param exit_idx number Exit node index
function Segment:create_underground(entry_idx, exit_idx)
  self.nodes[entry_idx].belt_type = "down"
  self:update_render(self.nodes[entry_idx])

  for j = entry_idx + 1, exit_idx - 1 do
    self.nodes[j].belt_type = "under"
    self:update_render(self.nodes[j])
  end

  self.nodes[exit_idx].belt_type = "up"
  self:update_render(self.nodes[exit_idx])
end

return Segment
---@export Node
---@export Position
