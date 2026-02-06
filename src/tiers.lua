---@alias BeltTier "normal"|"fast"|"express"|"turbo"
---@alias BeltTierData {name: BeltTier, tool: string, preview_tool: string, string: string, entities: {belt: string, underground_belt: string, splitter: string}, max_underground_distance: number, dummy: string}

---@type table<BeltTier, BeltTierData>
local tiers = {
  normal = {
    name = "normal",
    tool = "belt-draw",
    preview_tool = "belt-draw-preview",
    string = "belt-draw.tier-normal",
    max_underground_distance = 4,
    dummy = "belt-draw-dummy-transport-belt",
    entities = {
      belt = "transport-belt",
      underground_belt = "underground-belt",
      splitter = "splitter",
    }
  },
  fast = {
    name = "fast",
    tool = "belt-draw-fast",
    preview_tool = "belt-draw-fast-preview",
    string = "belt-draw.tier-fast",
    max_underground_distance = 7,
    dummy = "belt-draw-dummy-fast-transport-belt",
    entities = {
      belt = "fast-transport-belt",
      underground_belt = "fast-underground-belt",
      splitter = "fast-splitter",
    }
  },
  express = {
    name = "express",
    tool = "belt-draw-express",
    preview_tool = "belt-draw-express-preview",
    string = "belt-draw.tier-express",
    max_underground_distance = 9,
    dummy = "belt-draw-dummy-express-transport-belt",
    entities = {
      belt = "express-transport-belt",
      underground_belt = "express-underground-belt",
      splitter = "express-splitter",
    }
  }
}

if script.active_mods["space-age"] then
  tiers.turbo = {
    name = "turbo",
    tool = "belt-draw-turbo",
    preview_tool = "belt-draw-turbo-preview",
    string = "belt-draw.tier-turbo",
    max_underground_distance = 11,
    dummy = "belt-draw-dummy-turbo-transport-belt",
    entities = {
      belt = "turbo-transport-belt",
      underground_belt = "turbo-underground-belt",
      splitter = "turbo-splitter",
    }
  }
end

---@param tool_name string
---@return BeltTier?
function get_belt_tier(tool_name)
  for tier_name, tier in pairs(tiers) do
    if tool_name == tier.tool or tool_name == tier.preview_tool then
      return tier_name
    end
  end
  return nil
end

---@param entity_name string
---@return BeltTier?
function get_belt_tier_for_entity_name(entity_name)
  for tier_name, tier in pairs(tiers) do
    if entity_name == tier.entities.belt or entity_name == tier.entities.underground_belt or entity_name == tier.entities.splitter then
      return tier_name
    end
  end
  return nil
end

---@param current_tier BeltTier
---@return BeltTier?
function get_next_belt_tier(current_tier)
  ---@type BeltTier[]
  local tier_names = {}
  for tier_name, _ in pairs(tiers) do
    table.insert(tier_names, tier_name)
  end

  for i, tier_name in ipairs(tier_names) do
    if tier_name == current_tier then
      local next_index = (i % #tier_names) + 1
      return tier_names[next_index]
    end
  end
  return nil
end

---@param current_tier BeltTier
---@return BeltTier?
function get_previous_belt_tier(current_tier)
  ---@type BeltTier[]
  local tier_names = {}
  for tier_name, _ in pairs(tiers) do
    table.insert(tier_names, tier_name)
  end

  for i, tier_name in ipairs(tier_names) do
    if tier_name == current_tier then
      local next_index = (i - 2) % #tier_names + 1
      return tier_names[next_index]
    end
  end
  return nil
end

return tiers
---@export BeltTier
---@export BeltTierData
