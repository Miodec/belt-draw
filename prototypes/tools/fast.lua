local base_tool = require("base")

local transport_belt = table.deepcopy(data.raw["transport-belt"]["fast-transport-belt"])
transport_belt.name = "belt-draw-dummy-fast-transport-belt"
transport_belt.created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line

local tool = table.deepcopy(base_tool)
tool.name = "belt-draw-fast"
tool.place_result = "belt-draw-dummy-entity"
tool.order = "c[automated-construction]-d[belt-draw-fast]"
tool.icon = "__belt-draw__/graphics/fast-pencil.png"

local preview_tool = table.deepcopy(base_tool)
preview_tool.name = "belt-draw-fast-preview"
preview_tool.place_result = "belt-draw-dummy-fast-transport-belt"
preview_tool.order = "c[automated-construction]-d[belt-draw-fast-preview]"
preview_tool.icon = "__belt-draw__/graphics/fast-pencil.png"

return {
  tool,
  preview_tool,
  transport_belt
}
