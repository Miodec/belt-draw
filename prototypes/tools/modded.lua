local util = require("util")
local base_tool = require("base")

-- these have their own tools and tiers
local base_game_belts = {
  ["transport-belt"] = true,
  ["fast-transport-belt"] = true,
  ["express-transport-belt"] = true,
  ["turbo-transport-belt"] = true,
}

--- Drawing and preview tools for the belts other mods add, src/tiers.lua turns them into tiers
local result = {}
for name, belt in pairs(data.raw["transport-belt"]) do
  if not base_game_belts[name] and not belt.hidden and string.sub(name, 1, 10) ~= "belt-draw-"
      and belt.related_underground_belt and data.raw["underground-belt"][belt.related_underground_belt] then
    local icons = { { icon = "__belt-draw__/graphics/tools/pencil.png", icon_size = 64 } }
    local belt_icons = belt.icons or (belt.icon and { { icon = belt.icon, icon_size = belt.icon_size } })
    if belt_icons then
      icons = util.combine_icons(icons, belt_icons, { scale = 0.5, shift = { 8, 8 } }, 64)
    end

    local tool = table.deepcopy(base_tool)
    tool.name = "belt-draw-" .. name
    tool.localised_name = { "item-name.belt-draw" }
    tool.order = "c[automated-construction]-d[belt-draw-" .. name .. "]"
    tool.icons = icons

    local preview_tool = table.deepcopy(base_tool)
    preview_tool.name = "belt-draw-" .. name .. "-preview"
    preview_tool.localised_name = { "item-name.belt-draw" }
    preview_tool.place_result = name
    preview_tool.order = "c[automated-construction]-d[belt-draw-" .. name .. "-preview]"
    preview_tool.icons = icons

    table.insert(result, tool)
    table.insert(result, preview_tool)
  end
end

return result
