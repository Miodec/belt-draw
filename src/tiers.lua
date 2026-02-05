---@alias BeltTier "normal"|"fast"
---@alias BeltTierData {name: BeltTier, tool: string, preview_tool: string, string: string, place: {belt: string, underground_belt: string}}

---@type table<BeltTier, BeltTierData>
local tiers = {
  normal = {
    name = "normal",
    tool = "belt-draw",
    preview_tool = "belt-draw-preview",
    string = "belt-draw-tiers.normal",
    max_underground_distance = 4,
    place = {
      belt = "transport-belt",
      underground_belt = "underground-belt",
    }
  },
  fast = {
    name = "fast",
    tool = "belt-draw-fast",
    preview_tool = "belt-draw-fast-preview",
    string = "belt-draw-tiers.fast",
    max_underground_distance = 7,
    place = {
      belt = "fast-transport-belt",
      underground_belt = "fast-underground-belt",
    }
  },
}

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
