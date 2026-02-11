local tiers = require("tiers")


---@param player LuaPlayer
---@param segments Segment[]
---@param mode "normal"|"alt"
---@return nil
function place(player, segments, mode)
  if storage.player_reach and player.character then
    player.character_build_distance_bonus = storage.player_reach
    storage.player_reach = nil
  end

  if mode == "alt" then
    place_using_blueprint(player, segments)
  else
    place_using_inventory(player, segments)
  end
end

---@param player LuaPlayer
---@param segments Segment[]
function place_using_blueprint(player, segments)
  local tier_info = tiers[storage.current_tier]

  -- Create blueprint and collect all entities
  ---@type LuaEntity[]
  local blueprint_entities = {}

  ---@type {x: number, y: number, node: Node, name: string}[]
  local node_positions = {} -- Store expected positions

  -- First pass: collect all node positions
  for _, segment in pairs(segments) do
    for _, node in pairs(segment.nodes) do
      local name = nil
      if node.belt_type == "above" or (node.belt_type == "blocked") then
        name = tier_info.entities.belt
      elseif node.belt_type == "down" or node.belt_type == "up" then
        name = tier_info.entities.underground_belt
      end

      if name then
        table.insert(node_positions, { x = node.x, y = node.y, node = node, name = name })
      end
    end
  end

  if #node_positions == 0 then
    return
  end

  -- Calculate bounding box center
  local min_x, max_x = node_positions[1].x, node_positions[1].x
  local min_y, max_y = node_positions[1].y, node_positions[1].y

  for _, pos in pairs(node_positions) do
    min_x = math.min(min_x, pos.x)
    max_x = math.max(max_x, pos.x)
    min_y = math.min(min_y, pos.y)
    max_y = math.max(max_y, pos.y)
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
        build_mode = defines.build_mode.forced,
        raise_built = false
      })
      player.cursor_stack.set_blueprint_entities({}) -- Clear blueprint entities to prevent reuse
      player.cursor_stack.clear()
    end
  end
end

---@param player LuaPlayer
---@param segments Segment[]
function place_using_inventory(player, segments)
  local tier_info = tiers[storage.current_tier]


  local build_ghosts = false

  local inventory = player.get_main_inventory()
  if not inventory then
    build_ghosts = true
  end

  local built_at_least_one = false
  local missing_item_shown = false
  local cannot_reach_shown = false
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

      local dx = player.position.x - node.x
      local dy = player.position.y - node.y
      local distance_squared = dx * dx + dy * dy
      local reach_squared = player.build_distance * player.build_distance

      local can_reach = distance_squared < reach_squared

      if not can_reach then
        build_ghosts = true
      end

      local entity = {
        name = name,
        position = { x = node.x, y = node.y },
        direction = node.direction,
        force = player.force,
        player = player,
        raise_built = true,
      }

      if node.belt_type == "down" then
        entity.belt_to_ground_type = "input"
      elseif node.belt_type == "up" then
        entity.belt_to_ground_type = "output"
      end

      if build_ghosts then
        entity.create_build_effect_smoke = true
        entity.ghost_name = entity.name
        entity.name = "entity-ghost"
        if entity.belt_to_ground_type then
          entity.type = entity.belt_to_ground_type
          entity.belt_to_ground_type = nil
        end
      elseif inventory then
        inventory.remove({ name = entity.name, count = 1 })
        built_at_least_one = true
        if node.belt_type == "up" then
          entity.direction = (entity.direction + 8) % 16
        end
      end

      player.surface.create_entity(entity)
      player.surface.play_sound({
        path = "entity-build/" .. entity.name,
        position = player.position,
      })


      if inventory and player.character then
        if count == 0 then
          if not missing_item_shown and built_at_least_one then
            player.create_local_flying_text({
              text = { "belt-draw.missing-item" },
              position = { x = entity.position.x, y = entity.position.y },
            })
            player.surface.play_sound({
              path = "utility/cannot_build",
              position = player.position,
            })
            missing_item_shown = true
          end
        end
        if count > 0 and not can_reach then
          if not cannot_reach_shown then
            player.create_local_flying_text({
              text = { "belt-draw.cannot-reach" },
              position = { x = entity.position.x, y = entity.position.y },
            })
            cannot_reach_shown = true
          end
        end
      end
      ::continue::
    end
  end
end
