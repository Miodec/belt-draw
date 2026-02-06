local findLDivergencePoint = require("divergence")
local tiers = require("tiers")

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
---@field belt_tier BeltTier
---@field last_segment Segment?
local Segment = {}
Segment.__index = Segment

---@param from Position
---@param player LuaPlayer
---@param self_id number
---@param belt_tier BeltTier
---@param last_segment Segment?
---@return Segment
function Segment.new(from, first_node_direction, player, self_id, belt_tier, last_segment)
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
  self.belt_tier = belt_tier
  self.last_segment = last_segment
  self:check_orientation_override()
  self:plan_belts()
  self:visualize()
  return self
end

---@param node Node
---@return LuaEntity|nil
function Segment:find_entity_at_node(node)
  ---@type LuaEntity?
  local entity = self.player.surface.find_entities_filtered({
    area = { { node.x - 0.5, node.y - 0.5 }, { node.x + 0.5, node.y + 0.5 } }
  })[1]

  if entity then
    if entity.type == "vehicle" or
        entity.type == "spider-vehicle" or
        entity.type == "character" or
        entity.type == "spider-leg"
    then
      entity = nil
    end
  end
  return entity
end

function Segment:find_tile_at_node(node)
  ---@type LuaTile?
  local tile = self.player.surface.find_tiles_filtered({
    area = { { node.x - 0.5, node.y - 0.5 }, { node.x + 0.5, node.y + 0.5 } }
  })[1]
  return tile
end

---@param entity LuaEntity
---@param node Node
---@return "replace"|"block"|"connect"
function Segment:get_compatibility(entity, node)
  local type = entity.type == "entity-ghost" and entity.ghost_type or entity.type
  if type ~= "transport-belt" and type ~= "underground-belt" and type ~= "splitter" then
    return "block"
  end

  local same_dir = entity.direction == node.direction
  local opposite_dir = entity.direction == (node.direction + 8) % 16
  local perpendicular = (entity.direction + 4) % 16 == node.direction or (entity.direction + 12) % 16 == node
      .direction

  if type == "splitter" then
    if same_dir then
      return "connect"
    else
      return "block"
    end
  end

  if (type == "underground-belt") then
    if same_dir or perpendicular then
      return "connect"
    elseif opposite_dir then
      return "replace"
    else
      return "block"
    end
  end


  if type == "transport-belt" then
    if (entity.belt_shape == "right" or entity.belt_shape == "left") and
        entity.belt_neighbours.outputs[1] and
        entity.belt_neighbours.inputs[1] and
        not same_dir
    then
      return "block"
    end
    if (entity.belt_shape == "straight" and entity.belt_neighbours.outputs[1] and not same_dir and not opposite_dir) then
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
  if self.last_segment then
    -- anchor
    local last_node_dir = self.last_segment.nodes[#self.last_segment.nodes].direction
    if last_node_dir == defines.direction.north or last_node_dir == defines.direction.south then
      self.orientation_override = "horizontal"
    else
      self.orientation_override = "vertical"
    end
    return
  end

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
  local divergenceIndex = (divergence and divergence.index or 0) - tiers[self.belt_tier].max_underground_distance
  if divergenceIndex < 0 then
    divergenceIndex = 0
  end
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
    if self.nodes[i].belt_type == "down" or self.nodes[i].belt_type == "under" or self.nodes[i].belt_type == "under_entity" then
      min_idx = i
    else
      break
    end
  end

  -- Search forwards for exit
  for i = start_idx + 1, #self.nodes do
    if self.nodes[i].belt_type == "up" or self.nodes[i].belt_type == "under" or self.nodes[i].belt_type == "under_entity" then
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
  skip = 0

  -- When replanning from start (skip=0), clear all belt_types to allow fresh planning
  if skip == 0 then
    for _, node in ipairs(self.nodes) do
      node.belt_type = nil
    end
  end

  -- Process backwards from end to skip
  for i = #self.nodes, skip + 1, -1 do
    local node = self.nodes[i]

    local can_place = self.player.surface.can_place_entity({
      name = "transport-belt",
      position = { x = node.x, y = node.y },
      direction = node.direction,
      force = self.player.force
    })

    local entity = self:find_entity_at_node(node)

    node.belt_type = "above"

    if not can_place then
      node.belt_type = "blocked"
    end

    if entity then
      local compat = self:get_compatibility(entity, node)
      if compat == "replace" then
        node.belt_type = "above"
      elseif compat == "connect" then
        node.belt_type = "above_connect"
      elseif compat == "block" then
        node.belt_type = "blocked"
      end
    end
  end

  local tier_data = tiers[self.belt_tier]

  for i = 1, #self.nodes do
    local node = self.nodes[i]

    if node.belt_type == "blocked" then
      -- Try to find underground entry for blocked node
      local entry_idx, exit_idx = self:find_underground(i)

      -- If we found both entry and exit, create underground
      if entry_idx and exit_idx then
        if (exit_idx - entry_idx - 1) > tier_data.max_underground_distance then
          -- Limit underground length to 4 belts
          goto continue
        end

        local entry_node = self.nodes[entry_idx]
        local exit_node = self.nodes[exit_idx]


        self.nodes[entry_idx].belt_type = "down"
        self:update_render(self.nodes[entry_idx])

        for j = entry_idx + 1, exit_idx - 1 do
          local under_node = self.nodes[j]
          if under_node.belt_type == "blocked" then
            under_node.belt_type = "under_entity"
          else
            under_node.belt_type = "under"
          end
          self:update_render(under_node)
        end

        self.nodes[exit_idx].belt_type = "up"
        self:update_render(self.nodes[exit_idx])


        if entry_node.direction ~= exit_node.direction then
          self:invalidate_underground(self.nodes[entry_idx])
          goto continue
        end

        if entry_idx > 1 and self.nodes[entry_idx - 1].direction ~= entry_node.direction then
          self:invalidate_underground(self.nodes[entry_idx])
          goto continue
        end
      end
    end
    -- in a loop, check previous nodes. if its blocked, continue, if its above, set it to down
    ::continue::
  end
end

function Segment:find_underground(node_index)
  local i = node_index
  local entry_idx = nil
  local exit_idx = nil

  -- Find exit (up) - search forward from blocked node
  for j = i + 1, #self.nodes do
    local exit_node = self.nodes[j]
    if exit_node.belt_type == "up" then
      exit_idx = j
      break
    end
    if exit_node.belt_type == "above" then
      exit_idx = j
      break
    end
  end

  -- Find entry (down) - search backward from blocked node
  for k = i - 1, 1, -1 do
    local entry_node = self.nodes[k]
    if entry_node.belt_type == "down" then
      entry_idx = k
      break
    end
    if entry_node.belt_type == "above" then
      entry_idx = k
      break
    end
  end
  return entry_idx, exit_idx
end

return Segment
---@export Node
---@export Position
---@export Segment
