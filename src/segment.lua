local findLDivergencePoint = require("divergence")
local tiers = require("tiers")

---@alias BeltType "above"|"down"|"up"|"under"|"under_entity"|"blocked"|"above_connect"|"above_deconstruct"
---@alias Position {x: number, y: number}
---@alias NodeInfo {can_place: boolean, entity: LuaEntity|false, tile_blocks: boolean?, can_cover: boolean?}
---@alias Drawn {sprite: string?, orientation: number?, x: number?, y: number?} what the render object currently shows, writing to it is an api call so unchanged values are skipped
---@alias Node {x: number, y: number, direction: defines.direction, render: LuaRenderObject? , drawn: Drawn?, belt_type: BeltType|nil, deconstruct_entity: LuaEntity?}


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
---@field earlier_tiles table<number, table<number, true>>? tiles used by the segments before this one, keyed by x then y
---@field shown_visibility string? which visibility the render objects were last set to, see apply_visibility
---@field highlights table<string|integer, LuaEntity>? highlight boxes around entities super forced will deconstruct, keyed by entity
local Segment = {}
Segment.__index = Segment
-- segments live in storage, so they need their methods back after a save is loaded
script.register_metatable("Segment", Segment)

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
  self.nodes = {
    {
      x = from.x,
      y = from.y,
      -- only known when the build key was pressed, shift drawing (alt select) doesn't press it
      direction = first_node_direction or defines.direction.north,
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

--- Surface lookups for a node, cached for the whole drawing. Every cursor move replans every node,
--- so without the cache the same tiles get queried over and over
--- Keyed by x, then y, then direction. Numbers, string keys are slow to build
---@param node Node
---@param state PlayerState? passed in by hot loops, saves looking it up per node
---@return NodeInfo
function Segment:node_info(node, state)
  state = state or get_state(self.player)
  -- kept in storage, a local cache would differ between players in multiplayer
  local cache = state.node_cache
  if not cache then
    cache = {}
    state.node_cache = cache
  end
  local column = cache[node.x]
  if not column then
    column = {}
    cache[node.x] = column
  end
  local by_direction = column[node.y]
  if not by_direction then
    by_direction = {}
    column[node.y] = by_direction
  end
  -- the first node has no direction when the build key press wasn't seen
  local direction = node.direction or -1
  local info = by_direction[direction]
  -- the entity may have been removed since, look again
  if info and info.entity and not info.entity.valid then
    info = nil
  end
  if not info then
    info = {
      can_place = self.player.surface.can_place_entity({
        name = "transport-belt",
        position = { x = node.x, y = node.y },
        direction = node.direction,
        force = self.player.force
      }),
      entity = self:find_entity_at_node(node) or false,
    }
    by_direction[direction] = info
  end
  return info
end

---@param node Node
---@return LuaEntity|nil
function Segment:find_entity_at_node(node)
  ---@type LuaEntity?
  local entity = self.player.surface.find_entities_filtered({
    area = { { node.x - 0.5, node.y - 0.5 }, { node.x + 0.5, node.y + 0.5 } },
    -- things that move or get out of the way, they shouldn't block or be undergrounded under
    type = {
      "vehicle",
      "spider-vehicle",
      "character",
      "spider-leg",
      "fish",
      "unit",
      "spider-unit",
      "segmented-unit",
      "segment",
      "corpse",
      "item-entity",
      "fire",
      "highlight-box", -- our own super forced highlights
    },
    invert = true,
  })[1]
  return entity
end

--- Whether the tile itself (water, void...) stops a belt from being built
---@param node Node
---@return boolean
function Segment:tile_blocks(node)
  local info = self:node_info(node)
  if info.tile_blocks == nil then
    info.tile_blocks = false
    local tile = self:find_tile_at_node(node)
    if not tile then
      info.tile_blocks = true
    else
      local belt_layers = prototypes.entity["transport-belt"].collision_mask.layers
      for layer in pairs(tile.prototype.collision_mask.layers) do
        if belt_layers[layer] then
          info.tile_blocks = true
          break
        end
      end
    end
  end
  return info.tile_blocks
end

--- Whether building over this tile automatically places a cover tile (landfill, foundation, ice platform...)
---@param node Node
---@return boolean
function Segment:can_cover_tile(node)
  local info = self:node_info(node)
  if info.can_cover == nil then
    local tile = self:find_tile_at_node(node)
    info.can_cover = tile ~= nil and self.player.surface.get_default_cover_tile(self.player.force, tile.name) ~= nil
  end
  return info.can_cover
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
  local same_dir = entity.direction == node.direction
  local opposite_dir = entity.direction == (node.direction + 8) % 16
  local perpendicular = (entity.direction + 4) % 16 == node.direction or (entity.direction + 12) % 16 == node
      .direction
  local belt_neighbours = entity.belt_neighbours or {}
  local belt_neighbours_outputs = belt_neighbours.outputs or {}
  local belt_neighbours_inputs = belt_neighbours.inputs or {}

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
    if #self.nodes == 1 then
      return "replace"
    end

    if (entity.belt_shape == "right" or entity.belt_shape == "left") and
        belt_neighbours_outputs[1] and
        belt_neighbours_inputs[1] and
        not same_dir
    then
      return "block"
    end
    if (entity.belt_shape == "straight" and belt_neighbours_outputs[1] and not same_dir and not opposite_dir) then
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

  self.player.play_sound({
    path = "entity-build/entity-ghost",
    position = self.player.position,
  })

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
  local divergenceIndex = (divergence and divergence.index or 0) - get_underground_reach(self.belt_tier)
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
    -- renders expire after a minute, so they can already be gone
    if node.render ~= nil and node.render.valid then
      node.render.destroy()
    end
    node.render = nil
  end
  self:clear_highlights()
end

function Segment:clear_highlights()
  for _, highlight in pairs(self.highlights or {}) do
    if highlight.valid then highlight.destroy() end
  end
  self.highlights = {}
end

--- Red corners around every entity super forced will mark for deconstruction.
--- Existing boxes are kept, recreating them every update makes them flicker
function Segment:update_highlights()
  local old = self.highlights or {}
  ---@type table<string|integer, LuaEntity>
  local new = {}

  if self:shows_preview() then
    for _, node in pairs(self.nodes) do
      local entity = node.deconstruct_entity
      -- multi tile entities can block several nodes, only highlight them once
      if node.belt_type == "above_deconstruct" and entity and entity.valid then
        -- LuaEntity wrappers differ per lookup, so key by something stable
        local key = entity.unit_number or (entity.name .. "@" .. entity.position.x .. "," .. entity.position.y)
        if not new[key] then
          local highlight = old[key]
          if highlight and highlight.valid then
            old[key] = nil
          else
            highlight = self.player.surface.create_entity({
              name = "highlight-box",
              position = entity.position,
              -- target only works for entities with health (not ghosts, items on ground...), otherwise use a fixed box
              target = entity.is_entity_with_health and entity or nil,
              bounding_box = not entity.is_entity_with_health and entity.selection_box or nil,
              box_type = "not-allowed",
              render_player_index = self.player.index,
              blink_interval = 0,
            })
          end
          new[key] = highlight
        end
      end
    end
  end

  -- whatever is left over is no longer in the way
  for _, highlight in pairs(old) do
    if highlight.valid then highlight.destroy() end
  end
  self.highlights = new
end

local scale = 0.5

-- these sprites have a "-alt" version used while drawing in alt mode
local HAS_ALT_SPRITE = {
  ["belt-draw-above"] = true,
  ["belt-draw-under"] = true,
  ["belt-draw-entryexit"] = true,
  ["belt-draw-anchor"] = true,
}

--- Whether the preview uses the alt sprites
---@return boolean
function Segment:uses_alt()
  -- super forced and remote view always build ghosts, so they get the alt look too
  local state = get_state(self.player)
  return state.draw_alt or state.super_forced or self.player.controller_type == defines.controllers.remote
end

---@param sprite_name string
---@param use_alt boolean from Segment:uses_alt, looked up once per update instead of per node
---@return string
local function with_alt(sprite_name, use_alt)
  if use_alt and HAS_ALT_SPRITE[sprite_name] then
    return sprite_name .. "-alt"
  end
  return sprite_name
end

---@param node Node
---@param sprite string
local function set_sprite(node, sprite)
  node.drawn = node.drawn or {}
  if node.drawn.sprite ~= sprite then
    node.render.sprite = sprite
    node.drawn.sprite = sprite
  end
end

--- Swap sprites to/from their alt versions, used when switching between normal and alt mode
function Segment:apply_alt_sprites()
  local use_alt = self:uses_alt()
  for _, node in pairs(self.nodes) do
    if node.render and node.render.valid then
      local base_name = string.gsub(node.drawn and node.drawn.sprite or node.render.sprite, "%-alt$", "")
      set_sprite(node, with_alt(base_name, use_alt))
    end
  end
end

---@param node Node
function Segment:render_anchor(node)
  local sprite_name = with_alt("belt-draw-anchor", self:uses_alt())
  local sprite = {
    sprite = sprite_name,
    x_scale = scale,
    y_scale = scale,
    visible = not get_state(self.player).hide_preview,
    target = { x = node.x, y = node.y },
    -- only the player drawing sees the preview
    players = { self.player },
    surface = self.player.surface,
    time_to_live = 60 * 60 -- 1 minute should be plenty, protects against orphaned render objects if something goes wrong
  }
  node.render = rendering.draw_sprite(sprite)
  node.drawn = { sprite = sprite_name, x = node.x, y = node.y }
end

local function get_sprite_name_for_belt_type(belt_type)
  if belt_type == "above" or belt_type == "above_deconstruct" then
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
---@param use_alt boolean?
---@param visible boolean?
function Segment:render_node(node, use_alt, visible)
  local sprite_name = nil
  sprite_name = get_sprite_name_for_belt_type(node.belt_type)

  if not sprite_name then
    return
  end

  if use_alt == nil then use_alt = self:uses_alt() end
  if visible == nil then visible = self:shows_preview() end

  sprite_name = with_alt(sprite_name, use_alt)
  local orientation = node.direction * 0.0625 - 0.25
  ---@type Position
  local target = { x = node.x, y = node.y }
  local sprite = {
    sprite = sprite_name,
    x_scale = scale,
    y_scale = scale,
    target = target,
    surface = self.player.surface,
    ---@type number
    orientation = orientation,
    visible = visible,
    players = { self.player },
    time_to_live = 60 * 60 -- 1 minute should be plenty, protects against orphaned render objects if something goes wrong
  }
  node.render = rendering.draw_sprite(sprite)
  node.drawn = { sprite = sprite_name, orientation = orientation, x = node.x, y = node.y }
end

--- Hidden until the player starts dragging, the preview tool already shows that belt
---@return boolean
function Segment:shows_preview()
  -- dragging is only set after this update, so also check the node count
  local state = get_state(self.player)
  if state.hide_preview then return false end
  return state.dragging or #self.nodes >= 2
end

---@param node Node
---@param use_alt boolean? looked up when not given
---@param visible boolean? for a newly created render, looked up when not given
function Segment:update_render(node, use_alt, visible)
  if use_alt == nil then use_alt = self:uses_alt() end
  if not node.render or not node.render.valid then
    -- Create render if it doesn't exist
    self:render_node(node, use_alt, visible)
    return
  end

  node.drawn = node.drawn or {}
  local orientation = node.direction * 0.0625 - 0.25
  if node.drawn.orientation ~= orientation then
    node.render.orientation = orientation
    node.drawn.orientation = orientation
  end
  set_sprite(node, with_alt(get_sprite_name_for_belt_type(node.belt_type), use_alt))
end

---@param divergence_index number?
function Segment:visualize(divergence_index)
  divergence_index = divergence_index or 0
  local target_count = #self.nodes
  local use_alt = self:uses_alt()
  local visible = self:shows_preview()

  -- Only update/create render objects from divergence point onwards
  for i = divergence_index + 1, target_count do
    local node = self.nodes[i]
    local is_anchor = (i == 1 and self.self_id ~= 1)

    if node.render and node.render.valid then
      -- Update existing render object
      node.drawn = node.drawn or {}
      if node.drawn.x ~= node.x or node.drawn.y ~= node.y then
        node.render.target = { x = node.x, y = node.y }
        node.drawn.x = node.x
        node.drawn.y = node.y
      end
      if not is_anchor then
        self:update_render(node, use_alt, visible)
      end
    else
      -- Create new render object
      if is_anchor then
        self:render_anchor(node)
      else
        self:render_node(node, use_alt, visible)
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

  self:apply_visibility()
end

function Segment:apply_visibility()
  local visible = self:shows_preview()
  local hide_preview = get_state(self.player).hide_preview and true or false
  -- new render objects are created with the right visibility, so existing ones only need touching when it changes
  local shown = tostring(visible) .. tostring(hide_preview)
  if shown ~= self.shown_visibility then
    self.shown_visibility = shown
    for i, node in pairs(self.nodes) do
      -- Anchors stay visible, they mark where the previous segment ended
      local is_anchor = (i == 1 and self.self_id ~= 1)
      if node.render and node.render.valid then
        node.render.visible = (is_anchor and not hide_preview) or visible
      end
    end
  end
  self:update_highlights()
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
      new_node.drawn = self.nodes[target_idx].drawn
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
  local state = get_state(self.player)
  local use_alt = self:uses_alt()

  -- When replanning from start (skip=0), clear all belt_types to allow fresh planning
  if skip == 0 then
    for _, node in ipairs(self.nodes) do
      node.belt_type = nil
    end
  end

  -- tiles taken by earlier segments of this drawing. Those don't change once this segment exists, so only collect them once
  local taken = self.earlier_tiles
  if not taken then
    taken = {}
    for _, segment in pairs(state.segments) do
      if segment == self then break end
      for _, other_node in pairs(segment.nodes) do
        local column = taken[other_node.x]
        if not column then
          column = {}
          taken[other_node.x] = column
        end
        column[other_node.y] = true
      end
    end
    self.earlier_tiles = taken
  end

  -- Process backwards from end to skip
  for i = #self.nodes, skip + 1, -1 do
    local node = self.nodes[i]

    local info = self:node_info(node, state)
    local can_place = info.can_place
    local entity = info.entity or nil

    node.belt_type = "above"

    if not can_place then
      node.belt_type = "blocked"
      if not entity and not self:tile_blocks(node) then
        -- only blocked by ignored entities (fish, biters...), build on top
        node.belt_type = "above"
      elseif (state.draw_alt or state.super_forced) and not entity and self:can_cover_tile(node) then
        -- alt and super forced build with a blueprint, which covers water etc. with landfill/foundation automatically
        node.belt_type = "above"
      end
    end

    local type = entity and (entity.type == "entity-ghost" and entity.ghost_type or entity.type)
    local is_belt = false
    if type == "transport-belt" or type == "underground-belt" or type == "splitter" then
      is_belt = true
    end

    if entity and is_belt then
      local compat = self:get_compatibility(entity, node)
      if compat == "replace" then
        node.belt_type = "above"
      elseif compat == "connect" then
        node.belt_type = "above_connect"
      elseif compat == "block" then
        node.belt_type = "blocked"
      end
    end

    -- super forced: whatever is in the way gets marked for deconstruction instead of undergrounded
    -- (nothing to deconstruct when the tile itself is blocking, so that still goes under)
    node.deconstruct_entity = nil
    if state.super_forced and entity and node.belt_type == "blocked" then
      node.belt_type = "above_deconstruct"
      node.deconstruct_entity = entity
    end

    -- check for collision with previous segments
    local taken_column = taken[node.x]
    if taken_column and taken_column[node.y] then
      node.belt_type = "blocked"
    end

    -- if this node is above, next is above_connect, and the one after is above
    -- set next node to blocked
    local next_node = self.nodes[i + 1]
    local next_next_node = self.nodes[i + 2]
    if node.belt_type == "above" and
        next_node and next_node.belt_type == "above_connect" and
        next_next_node and next_next_node.belt_type == "above" then
      next_node.belt_type = "blocked"
      self:update_render(next_node, use_alt)
    end
  end



  local underground_reach = get_underground_reach(self.belt_tier)

  local i = 0
  while i < #self.nodes do
    i = i + 1
    local node = self.nodes[i]

    if node.belt_type == "blocked" then
      -- Try to find underground entry for blocked node
      local entry_idx, exit_idx = self:find_underground(i)

      -- nothing was changed, so every blocked node up to the exit would find the same entry and exit.
      -- skip them, rescanning the whole obstacle for each of its tiles gets slow on long obstacles
      if not exit_idx then
        -- no exit anywhere ahead, no later node can get an underground either
        break
      end
      if not entry_idx then
        i = exit_idx - 1
        goto continue
      end

      -- If we found both entry and exit, create underground
      if entry_idx and exit_idx then
        if (exit_idx - entry_idx - 1) > underground_reach then
          -- further than the tier's undergrounds can reach
          i = exit_idx - 1
          goto continue
        end

        local entry_node = self.nodes[entry_idx]
        local exit_node = self.nodes[exit_idx]


        self.nodes[entry_idx].belt_type = "down"
        self:update_render(self.nodes[entry_idx], use_alt)

        for j = entry_idx + 1, exit_idx - 1 do
          local under_node = self.nodes[j]
          if under_node.belt_type == "blocked" then
            under_node.belt_type = "under_entity"
          else
            under_node.belt_type = "under"
          end
          self:update_render(under_node, use_alt)
        end

        self.nodes[exit_idx].belt_type = "up"
        self:update_render(self.nodes[exit_idx], use_alt)


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

--- Plan and redraw every node, e.g. after switching in/out of super forced mode
function Segment:replan()
  self:plan_belts(0)
  self:visualize()
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

function Segment:remove_last_node()
  local last_node = self.nodes[#self.nodes]
  if last_node and last_node.render and last_node.render.valid then
    last_node.render.destroy()
  end
  table.remove(self.nodes)
  self:update_highlights()
end

return Segment
---@export Node
---@export Position
---@export Segment
