---@alias BeltTier "normal"|"fast"
---@alias BeltTierData {name: BeltTier, tool: string, preview_tool: string, string: string, place: {belt: string, underground_belt: string}}
--- @type table<BeltTier, BeltTierData>
local tiers = {
  normal = {
    name = "normal",
    tool = "belt-draw",
    preview_tool = "belt-draw-preview",
    string = "belt-draw-tier-normal",
    place = {
      belt = "transport-belt",
      underground_belt = "underground-belt",
    }
  },
  fast = {
    name = "fast",
    tool = "belt-draw-fast",
    preview_tool = "belt-draw-fast-preview",
    string = "belt-draw-tier-fast",
    place = {
      belt = "fast-transport-belt",
      underground_belt = "fast-underground-belt",
    }
  },
}

return tiers
---@export BeltTier
---@export BeltTierData
