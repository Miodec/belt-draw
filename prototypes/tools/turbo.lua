local base_tool = require("base")

local belt = table.deepcopy(data.raw["transport-belt"]["turbo-transport-belt"])
belt.name = "belt-draw-dummy-turbo-transport-belt"
belt.created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
belt.collision_mask = {
  layers = {
    transport_belt = true
  }
}

local tool = table.deepcopy(base_tool)
tool.name = "belt-draw-turbo"
tool.place_result = "belt-draw-dummy-entity"
tool.order = "c[automated-construction]-d[belt-draw-turbo]"
tool.icon = "__belt-draw__/graphics/turbo-pencil.png"

local preview_tool = table.deepcopy(base_tool)
preview_tool.name = "belt-draw-turbo-preview"
preview_tool.place_result = "belt-draw-dummy-turbo-transport-belt"
preview_tool.order = "c[automated-construction]-d[belt-draw-turbo-preview]"
preview_tool.icon = "__belt-draw__/graphics/turbo-pencil.png"

return {
  tool,
  preview_tool,
  belt
}
