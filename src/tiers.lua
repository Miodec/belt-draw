--- the base game tiers, or the belt name for a tier from another mod
---@alias BeltTier "normal"|"fast"|"express"|"turbo"|string
---@alias BeltTierData {name: BeltTier, tool: string, preview_tool: string, string: string, entities: {belt: string, underground_belt: string, splitter: string?}, dummy: string?}

---@type table<BeltTier, BeltTierData>
local tiers = {
  normal = {
    name = "normal",
    tool = "belt-draw",
    preview_tool = "belt-draw-preview",
    string = "belt-draw.tier-normal",
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
    dummy = "belt-draw-dummy-turbo-transport-belt",
    entities = {
      belt = "turbo-transport-belt",
      underground_belt = "turbo-underground-belt",
      splitter = "turbo-splitter",
    }
  }
end

-- belts from other mods that got tools in prototypes/tools/modded.lua, after the base game tiers from slowest to fastest
---@type {speed: number, tier: BeltTierData}[]
local modded_tiers = {}
for name, belt in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "transport-belt" } })) do
  local underground_belt = belt.related_underground_belt
  if not belt.hidden and underground_belt and prototypes.item["belt-draw-" .. name .. "-preview"] then
    -- belts don't link to their splitter, so go by the base game naming
    local splitter = prototypes.entity[(string.gsub(name, "transport%-belt", "splitter"))]
    table.insert(modded_tiers, {
      speed = belt.belt_speed or 0,
      tier = {
        name = name,
        tool = "belt-draw-" .. name,
        preview_tool = "belt-draw-" .. name .. "-preview",
        string = "entity-name." .. name,
        entities = {
          belt = name,
          underground_belt = underground_belt.name,
          splitter = splitter and splitter.type == "splitter" and splitter.name or nil,
        }
      }
    })
  end
end
table.sort(modded_tiers, function(a, b)
  if a.speed ~= b.speed then return a.speed < b.speed end
  return a.tier.name < b.tier.name
end)
for _, modded in ipairs(modded_tiers) do
  tiers[modded.tier.name] = modded.tier
end

--- The most tiles this tier's undergrounds can cross, read from the game so it always matches the prototype
--- (its max distance counts both ends, so the gap is one less)
---@param tier BeltTier
---@return integer
function get_underground_reach(tier)
  return prototypes.entity[tiers[tier].entities.underground_belt].max_underground_distance - 1
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

---@param entity_name string
---@return BeltTier?
function get_belt_tier_for_belt_name(entity_name)
  for tier_name, tier in pairs(tiers) do
    if entity_name == tier.entities.belt then
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
