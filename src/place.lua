local tiers = require("tiers")


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
    place_using_blueprint(player, segments)
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

--- How out of reach (and out of items) nodes of an inventory drawing get built: as ghosts, through a blueprint.
--- A ghost created with fast replace would take the real belt underneath away (into the inventory, even out of reach)
---@param player LuaPlayer
---@param nodes Node[]
function place_ghosts(player, nodes)
  place_nodes_using_blueprint(player, nodes)
end

--- Whether this exact belt is already at the node
---@param surface LuaSurface
---@param name string
---@param node Node
---@return boolean
local function has_same_belt(surface, name, node)
  for _, e in pairs(surface.find_entities_filtered({ position = { node.x, node.y }, name = name })) do
    if e.direction == node.direction then return true end
  end
  return false
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

      -- nothing to do when the same belt is already there. Building it again fails after the item was taken
      if not build_ghosts and node.belt_type == "above" and has_same_belt(player.surface, name, node) then
        goto continue
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
        -- built with a blueprint at the end, see place_ghosts
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
    place_ghosts(player, ghost_nodes)
  end
end
