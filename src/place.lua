local tiers = require("src.tiers")


---@param player LuaPlayer
---@param segments Segment[]
---@param mode "normal"|"alt"|"super_forced"
---@return nil
function place(player, segments, mode)
  if mode == "super_forced" then
    -- super forced blueprint building marks anything in the way for deconstruction
    place_using_blueprint(player, segments, defines.build_mode.superforced)
  elseif mode == "alt" or player.controller_type == defines.controllers.remote then
    -- remote view can only place ghosts, so it works like alt mode
    ---@type Node[]
    local nodes = {}
    for _, segment in pairs(segments) do
      for _, node in pairs(segment.nodes) do
        table.insert(nodes, node)
      end
    end
    place_ghosts(player, nodes)
  else
    place_using_inventory(player, segments)
  end
end

---@param player LuaPlayer
---@param segments Segment[]
---@param build_mode defines.build_mode?
function place_using_blueprint(player, segments, build_mode)
  ---@type Node[]
  local nodes = {}
  for _, segment in pairs(segments) do
    for _, node in pairs(segment.nodes) do
      table.insert(nodes, node)
    end
  end
  place_nodes_using_blueprint(player, nodes, build_mode)
end

---@param player LuaPlayer
---@param nodes Node[]
---@param build_mode defines.build_mode?
function place_nodes_using_blueprint(player, nodes, build_mode)
  local tier_info = tiers[get_state(player).current_tier]

  -- Create blueprint and collect all entities
  ---@type LuaEntity[]
  local blueprint_entities = {}

  ---@type {x: number, y: number, node: Node, name: string}[]
  local node_positions = {} -- Store expected positions

  -- First pass: collect all node positions
  for _, node in pairs(nodes) do
    local name = nil
    if node.belt_type == "above" or node.belt_type == "above_deconstruct" or node.belt_type == "blocked" then
      name = tier_info.entities.belt
    elseif node.belt_type == "down" or node.belt_type == "up" then
      name = tier_info.entities.underground_belt
    end

    if name then
      table.insert(node_positions, { x = node.x, y = node.y, node = node, name = name })
    end
  end

  if #node_positions == 0 then
    return
  end

  -- Calculate bounding box center
  ---@type number
  local min_x = node_positions[1].x
  ---@type number
  local max_x = node_positions[1].x
  ---@type number
  local min_y = node_positions[1].y
  ---@type number
  local max_y = node_positions[1].y

  for _, pos in pairs(node_positions) do
    if pos.x < min_x then min_x = pos.x end
    if pos.x > max_x then max_x = pos.x end
    if pos.y < min_y then min_y = pos.y end
    if pos.y > max_y then max_y = pos.y end
  end

  local center_x = (min_x + max_x) / 2
  local center_y = (min_y + max_y) / 2

  -- Second pass: create blueprint entities relative to center
  for i, pos_data in pairs(node_positions) do
    local node = pos_data.node
    local name = pos_data.name

    local bp_entity = {
      entity_number = i,
      name = name,
      position = { x = pos_data.x - center_x, y = pos_data.y - center_y },
      direction = node.direction
    }

    if node.belt_type == "down" then
      bp_entity.type = "input"
    elseif node.belt_type == "up" then
      bp_entity.type = "output"
    end

    table.insert(blueprint_entities, bp_entity)
  end

  -- Build all entities using blueprint
  if #blueprint_entities > 0 then
    player.cursor_stack.set_stack({ name = "blueprint", count = 1 })
    if player.cursor_stack and player.cursor_stack.valid_for_read then
      player.cursor_stack.set_blueprint_entities(blueprint_entities)
      player.build_from_cursor({
        surface = player.surface,
        force = player.force,
        position = { center_x, center_y },
        player = player,
        by_player = player,
        build_mode = build_mode or defines.build_mode.forced,
        raise_built = false
      })
      player.cursor_stack.set_blueprint_entities({}) -- Clear blueprint entities to prevent reuse
      player.cursor_stack.clear()
    end
  end
end

--- How alt mode, remote view and out of reach nodes get built: belts already in the way get rotated
--- or marked for upgrade, the blueprint handles the rest (placing ghosts, landfill)
---@param player LuaPlayer
---@param nodes Node[]
---@param drawing {rotations: RotationRecord[], undo_count: integer}? when part of an inventory drawing: its rotations
--- and undo count, so everything ends up in one undo item. The caller attaches the rotations then
function place_ghosts(player, nodes, drawing)
  local stack = player.undo_redo_stack
  local undo_count = drawing and drawing.undo_count or stack.get_undo_item_count()

  local remaining, deferred, rotations = handle_existing_belts(player, nodes)

  -- everything goes into one undo item: the blueprint creates it, the rest is added to it
  place_nodes_using_blueprint(player, remaining)
  for _, action in ipairs(deferred) do
    -- 0 starts a new undo item, 1 adds to the latest
    action(stack.get_undo_item_count() > undo_count and 1 or 0)
  end

  if drawing then
    for _, rotation in pairs(rotations) do table.insert(drawing.rotations, rotation) end
  else
    attach_rotations_to_undo(player, rotations, undo_count)
  end
end

local ROTATIONS_TAG = "belt_draw_rotations"

--- What's stored in the undo tag for each rotated belt
---@alias RotationTag {surface: integer, x: number, y: number, steps: integer}

--- Rotations can't be added to another undo item, so they are kept as a tag on the drawing's undo item instead
--- and turned back by the on_undo_applied handler
---@param player LuaPlayer
---@param rotations RotationRecord[]
---@param undo_count integer undo item count before the drawing was placed
function attach_rotations_to_undo(player, rotations, undo_count)
  if #rotations == 0 then return end
  local stack = player.undo_redo_stack

  if stack.get_undo_item_count() <= undo_count then
    -- only rotations happened, so there's no undo item to tag. Make one with a real rotation:
    -- turn one belt back a step quietly, then forward again by the player. Undoing that item turns it back a step itself,
    -- so its record only keeps the rest
    for _, record in pairs(rotations) do
      local entity = record.entity
      if record.steps ~= 0 and entity and entity.valid then
        entity.rotate({ reverse = record.steps > 0 })
        entity.rotate({ reverse = record.steps < 0, by_player = player })
        record.steps = record.steps - (record.steps > 0 and 1 or -1)
        break
      end
    end
    if stack.get_undo_item_count() <= undo_count then return end
  end

  ---@type RotationTag[]
  local tag = {}
  for _, record in pairs(rotations) do
    if record.steps ~= 0 then
      table.insert(tag, { surface = record.surface, x = record.x, y = record.y, steps = record.steps })
    end
  end
  if #tag == 0 then return end
  local item = stack.get_undo_item(1)
  stack.set_undo_tag(1, #item, ROTATIONS_TAG, tag --[[@as AnyBasic]])
end

---@param surface_index integer
---@param x number
---@param y number
---@return LuaEntity?
local function find_rotated_belt(surface_index, x, y)
  local surface = game.get_surface(surface_index)
  if not surface then return nil end
  -- by type, bots may have upgraded it to another tier since
  return surface.find_entities_filtered({ position = { x, y }, type = "transport-belt" })[1]
      or surface.find_entities_filtered({ position = { x, y }, ghost_type = "transport-belt" })[1]
end

---@param actions UndoRedoAction[]
---@param direction 1|-1 1 to redo the rotations, -1 to undo them
---@return RotationTag[]? records the rotations that were replayed
local function replay_rotations(actions, direction)
  ---@type RotationTag[]?
  local replayed = nil
  for _, action in pairs(actions) do
    local records = action.tags and action.tags[ROTATIONS_TAG] --[[@as RotationTag[]?]]
    if records then
      replayed = records
      for _, record in pairs(records) do
        local entity = find_rotated_belt(record.surface, record.x, record.y)
        if entity then
          ---@type integer
          local steps = record.steps * direction
          -- no by_player, replaying shouldn't add new undo items
          for _ = 1, math.abs(steps) do
            entity.rotate({ reverse = steps < 0 })
          end
        end
      end
    end
  end
  return replayed
end

-- tags don't move along when an item goes from the undo stack to the redo stack (or back),
-- so the rotations get tagged onto the item again, which is the latest one on the other stack

script.on_event(defines.events.on_undo_applied, function(event)
  local records = replay_rotations(event.actions, -1)
  local player = game.get_player(event.player_index)
  if not records or not player then return end
  local stack = player.undo_redo_stack
  if stack.get_redo_item_count() == 0 then return end
  stack.set_redo_tag(1, #stack.get_redo_item(1), ROTATIONS_TAG, records --[[@as AnyBasic]])
end)

script.on_event(defines.events.on_redo_applied, function(event)
  local records = replay_rotations(event.actions, 1)
  local player = game.get_player(event.player_index)
  if not records or not player then return end
  local stack = player.undo_redo_stack
  if stack.get_undo_item_count() == 0 then return end
  stack.set_undo_tag(1, #stack.get_undo_item(1), ROTATIONS_TAG, records --[[@as AnyBasic]])
end)

--- Rotate without leaving an undo item per step. Rotations can't be added to another undo item,
--- so they would have to be undone one by one. They get undone through attach_rotations_to_undo instead
---@param entity LuaEntity
---@param reverse boolean
---@param player LuaPlayer
local function rotate_step(entity, reverse, player)
  local stack = player.undo_redo_stack
  local count = stack.get_undo_item_count()
  local latest_size = count > 0 and #stack.get_undo_item(1) or 0
  -- by_player so the rotation event fires for other mods
  entity.rotate({ reverse = reverse, by_player = player })
  if stack.get_undo_item_count() > count then
    stack.remove_undo_item(1)
  elseif count > 0 and #stack.get_undo_item(1) > latest_size then
    stack.remove_undo_action(1, #stack.get_undo_item(1))
  end
end

---@alias RotationRecord {entity: LuaEntity, surface: integer, x: number, y: number, steps: integer}

---@param entity LuaEntity
---@param direction defines.direction
---@param player LuaPlayer
---@param rotations RotationRecord[] the rotation gets recorded here, for undo
local function rotate_to(entity, direction, player, rotations)
  -- rotate one step at a time like the player would
  ---@type integer
  local steps = ((direction - entity.direction) % 16) / 4
  if steps == 0 then return end
  if steps == 3 then
    rotate_step(entity, true, player)
    steps = -1
  else
    for _ = 1, steps do
      rotate_step(entity, false, player)
    end
  end
  table.insert(rotations, {
    entity = entity,
    surface = entity.surface.index,
    x = entity.position.x,
    y = entity.position.y,
    steps = steps,
  })
end

--- Belts the drawing goes over: the current tier gets rotated to the drawn direction (belt ghosts too),
--- other tiers get rotated and marked for upgrade/downgrade (ghosts get swapped).
--- A blueprint would replace them with a ghost or leave them alone instead
---@param player LuaPlayer
---@param nodes Node[]
---@return Node[] remaining the nodes that still need building
---@return fun(undo_index: integer)[] deferred actions to run after the blueprint, so they join its undo item
---@return RotationRecord[] rotations
function handle_existing_belts(player, nodes)
  local belt = tiers[get_state(player).current_tier].entities.belt
  ---@type Node[]
  local remaining = {}
  ---@type fun(undo_index: integer)[]
  local deferred = {}
  ---@type RotationRecord[]
  local rotations = {}
  for _, node in pairs(nodes) do
    local handled = false
    -- undergrounds can't be done by rotating or upgrading a belt
    if node.belt_type == "above" and node.direction then
      local position = { node.x, node.y }
      local direction = node.direction
      local existing = player.surface.find_entities_filtered({ position = position, type = "transport-belt" })[1]
      if existing and existing.name == belt then
        rotate_to(existing, direction, player, rotations)
        handled = true
      elseif existing then
        -- an upgrade order can't turn the belt, so rotate it now like the same tier
        rotate_to(existing, direction, player, rotations)
        table.insert(deferred, function(undo_index)
          if not existing.valid then return end
          existing.order_upgrade({
            -- keep the quality, only the tier changes
            target = { name = belt, quality = existing.quality.name },
            force = player.force,
            player = player,
            undo_index = undo_index,
          })
        end)
        -- rotated either way, a blueprint ghost on top would replace it
        handled = true
      else
        local ghost = player.surface.find_entities_filtered({ position = position, ghost_type = "transport-belt" })[1]
        if ghost and ghost.ghost_name == belt then
          rotate_to(ghost, direction, player, rotations)
          handled = true
        elseif ghost then
          -- ghosts can't be marked for upgrade, swap it for a ghost of the drawn tier
          handled = true
          table.insert(deferred, function(undo_index)
            if not ghost.valid then return end
            local quality = ghost.quality.name
            ghost.destroy({ raise_destroy = true, player = player, undo_index = undo_index })
            player.surface.create_entity({
              name = "entity-ghost",
              ghost_name = belt,
              quality = quality,
              position = position,
              direction = direction,
              force = player.force,
              player = player,
              raise_built = true,
              -- the destroy above is in the latest undo item now
              undo_index = 1,
            })
          end)
        end
      end
    end

    if not handled then
      table.insert(remaining, node)
    end
  end
  return remaining, deferred, rotations
end

--- The belt of this tier already at the node, if any
---@param surface LuaSurface
---@param name string
---@param node Node
---@return LuaEntity?
local function find_same_belt(surface, name, node)
  return surface.find_entities_filtered({ position = { node.x, node.y }, name = name })[1]
end

---@param player LuaPlayer
---@param segments Segment[]
function place_using_inventory(player, segments)
  local tier_info = tiers[get_state(player).current_tier]


  local build_ghosts = false

  local inventory = player.get_main_inventory()
  if not inventory then
    build_ghosts = true
  end

  local built_at_least_one = false
  local missing_item_shown = false
  local cannot_reach_shown = false
  -- nodes that can't be built from the inventory, they all go into one blueprint at the end
  ---@type Node[]
  local ghost_nodes = {}
  -- everything this drawing does goes into one undo item, rotations get tagged onto it at the end
  local undo_count = player.undo_redo_stack.get_undo_item_count()
  ---@type RotationRecord[]
  local rotations = {}
  -- build manually, one by one, from inventory
  for _, segment in pairs(segments) do
    for _, node in pairs(segment.nodes) do
      local name = nil
      if node.belt_type == "above" then
        name = tier_info.entities.belt
      elseif node.belt_type == "down" or node.belt_type == "up" then
        name = tier_info.entities.underground_belt
      end

      if not name then
        -- alt mode places these with the blueprint too, out of reach nodes work the same
        if node.belt_type == "blocked" and not can_reach(player.position, player.build_distance, node.x, node.y) then
          table.insert(ghost_nodes, node)
        end
        goto continue
      end

      local count = inventory and inventory.get_item_count(name) or 0
      if count == 0 then
        build_ghosts = true
      else
        build_ghosts = false
      end

      local in_reach = can_reach(player.position, player.build_distance, node.x, node.y)

      if not in_reach then
        build_ghosts = true
      end

      -- the same belt is already there: rotate it if needed, rather than building it again
      -- (a fast replace would give the old belt back, and drop what's on it)
      if not build_ghosts and node.belt_type == "above" then
        local existing = find_same_belt(player.surface, name, node)
        if existing then
          if node.direction then rotate_to(existing, node.direction, player, rotations) end
          goto continue
        end
      end

      local entity = {
        name = name,
        position = { x = node.x, y = node.y },
        direction = node.direction,
        force = player.force,
        player = player,
        raise_built = true,
        fast_replace = true
      }


      if node.belt_type == "down" then
        entity.belt_to_ground_type = "input"
      elseif node.belt_type == "up" then
        entity.belt_to_ground_type = "output"
      end

      if build_ghosts then
        -- a ghost created with fast replace takes the real belt underneath away (into the inventory, even when out of reach).
        -- the blueprint marks existing belts for upgrade/rotation/deconstruction instead, like the game does
        table.insert(ghost_nodes, node)
      else
        if node.belt_type == "up" then
          entity.direction = (entity.direction + 8) % 16
        end

        local built = player.surface.create_entity(entity)
        -- only take the item once it's actually built, a failed build would lose it
        if built and inventory then
          inventory.remove({ name = entity.name, count = 1 })
          built_at_least_one = true
        end
        player.play_sound({
          path = "entity-build/" .. entity.name,
          position = player.position,
        })
      end


      if inventory and player.character then
        if count == 0 then
          if not missing_item_shown and built_at_least_one then
            player.create_local_flying_text({
              text = { "belt-draw.missing-item" },
              position = { x = entity.position.x, y = entity.position.y },
            })
            player.play_sound({
              path = "utility/cannot_build",
              position = player.position,
            })
            missing_item_shown = true
          end
        end
        if count > 0 and not in_reach then
          if not cannot_reach_shown then
            player.create_local_flying_text({
              text = { "belt-draw.cannot-reach" },
              position = { x = entity.position.x, y = entity.position.y },
            })
            cannot_reach_shown = true
          end
        elseif in_reach then
          -- back in reach, so the next unreachable stretch gets its own notification
          cannot_reach_shown = false
        end
      end
      ::continue::
    end
  end

  if #ghost_nodes > 0 then
    place_ghosts(player, ghost_nodes, { rotations = rotations, undo_count = undo_count })
  end
  attach_rotations_to_undo(player, rotations, undo_count)
end
