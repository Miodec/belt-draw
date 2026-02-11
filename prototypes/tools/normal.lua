local base_tool = require("base")

local belt = table.deepcopy(data.raw["transport-belt"]["transport-belt"])
belt.name = "belt-draw-dummy-transport-belt"
belt.created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
belt.collision_mask = {
  layers = {
    transport_belt = true
  }
}
belt.next_upgrade = nil

local tool = table.deepcopy(base_tool)
tool.name = "belt-draw"
tool.place_result = "belt-draw-dummy-entity"
tool.order = "c[automated-construction]-d[belt-draw]"
tool.icon = "__belt-draw__/graphics/pencil.png"

local preview_tool = table.deepcopy(base_tool)
preview_tool.name = "belt-draw-preview"
preview_tool.place_result = "belt-draw-dummy-transport-belt"
preview_tool.order = "c[automated-construction]-d[belt-draw-preview]"
preview_tool.icon = "__belt-draw__/graphics/pencil.png"

return {
  tool,
  preview_tool,
  belt
}
