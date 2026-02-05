local normal_tools = require("prototypes.tools.normal")
local other_tools = require("prototypes.other")
local entities = require("prototypes.entities")
local input = require("prototypes.input")
local sprites = require("prototypes.sprites")

for _, prototype in pairs(normal_tools) do
  data:extend({ prototype })
end

for _, prototype in pairs(other_tools) do
  data:extend({ prototype })
end

for _, prototype in pairs(entities) do
  data:extend({ prototype })
end

for _, prototype in pairs(input) do
  data:extend({ prototype })
end

for _, prototype in pairs(sprites) do
  data:extend({ prototype })
end

data:extend({
  {
    type = "shortcut",
    name = "belt-draw-shortcut-fast",
    action = "spawn-item",
    item_to_spawn = "belt-draw-preview",
    icon = "__belt-draw__/graphics/shortcut-fast.png",
    icon_size = 128,
    small_icon = "__belt-draw__/graphics/shortcut-fast.png",
    small_icon_size = 128,
    associated_control_input = "belt-draw-shortcut"
  },
  {
    type = "shortcut",
    name = "belt-draw-shortcut-express",
    action = "spawn-item",
    item_to_spawn = "belt-draw-preview",
    icon = "__belt-draw__/graphics/shortcut-express.png",
    icon_size = 128,
    small_icon = "__belt-draw__/graphics/shortcut-express.png",
    small_icon_size = 128,
    associated_control_input = "belt-draw-shortcut"
  },
  {
    type = "shortcut",
    name = "belt-draw-shortcut-turbo",
    action = "spawn-item",
    item_to_spawn = "belt-draw-preview",
    icon = "__belt-draw__/graphics/shortcut-turbo.png",
    icon_size = 128,
    small_icon = "__belt-draw__/graphics/shortcut-turbo.png",
    small_icon_size = 128,
    associated_control_input = "belt-draw-shortcut"
  },
})
