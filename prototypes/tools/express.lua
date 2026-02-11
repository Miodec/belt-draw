local base_tool = require("base")

local belt = table.deepcopy(data.raw["transport-belt"]["express-transport-belt"])
belt.name = "belt-draw-dummy-express-transport-belt"
belt.created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
belt.collision_mask = {
  layers = {
    transport_belt = true
  }
}
belt.next_upgrade = nil

local tool = table.deepcopy(base_tool)
tool.name = "belt-draw-express"
tool.place_result = "belt-draw-dummy-entity"
tool.order = "c[automated-construction]-d[belt-draw-express]"
tool.icon = "__belt-draw__/graphics/express-pencil.png"

local preview_tool = table.deepcopy(base_tool)
preview_tool.name = "belt-draw-express-preview"
preview_tool.place_result = "belt-draw-dummy-express-transport-belt"
preview_tool.order = "c[automated-construction]-d[belt-draw-express-preview]"
preview_tool.icon = "__belt-draw__/graphics/express-pencil.png"

return {
  tool,
  preview_tool,
  belt
}
