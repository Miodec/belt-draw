local tiers = require("tiers")

---@param player LuaPlayer
---@param mode "normal"|"alt"|"reverse"
---@param node Node
---@return nil
function place(player, mode, node)
  if storage.player_reach then
    player.character_build_distance_bonus = storage.player_reach
    storage.player_reach = nil
  end

  local inventory = player.get_inventory(defines.inventory.character_main)

  local tier_info = tiers[storage.current_tier]

  local name = nil
  if node.belt_type == "above" then
    name = tier_info.place.belt
  elseif node.belt_type == "down" or node.belt_type == "up" then
    name = tier_info.place.underground_belt
  end

  if name == nil then
    return
  end

  local count = inventory and inventory.get_item_count(name) or 0

  local dx = player.position.x - node.x
  local dy = player.position.y - node.y
  local distance_squared = dx * dx + dy * dy
  local reach_squared = player.build_distance * player.build_distance

  local can_reach = distance_squared < reach_squared

  local entity = {
    name = name,
    position = { x = node.x, y = node.y },
    direction = node.direction,
    force = player.force,
    player = player,
    fast_replace = true
  }
  if node.belt_type == "down" then
    entity.belt_to_ground_type = "input"
  elseif node.belt_type == "up" then
    entity.belt_to_ground_type = "output"
  end

  if inventory and count > 0 and can_reach then
    if entity.belt_to_ground_type and entity.belt_to_ground_type == "output" then
      entity.direction = (entity.direction + 8) % 16
    end
    player.surface.create_entity(entity)
    inventory.remove({ name = name, count = 1 })
  else
    entity.name = "entity-ghost"
    entity.ghost_name = name
    if entity.belt_to_ground_type then
      entity.type = entity.belt_to_ground_type
      entity.belt_to_ground_type = nil
    end
    player.surface.create_entity(entity)
  end
end
