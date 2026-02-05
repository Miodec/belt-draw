local modules = {
  require("prototypes.tools.generic"),
  require("prototypes.tools.normal"),
  require("prototypes.tools.fast"),
  require("prototypes.other"),
  require("prototypes.entities"),
  require("prototypes.input"),
  require("prototypes.sprites"),
}

for _, module in pairs(modules) do
  data:extend(module)
end

if mods["space-age"] then
  for _, module in pairs({
    require("prototypes.tools.turbo"),
  }) do
    data:extend(module)
  end
end

data:extend({
  {
    type = "shortcut",
    name = "belt-draw-shortcut",
    action = "spawn-item",
    item_to_spawn = "belt-draw-generic",
    icon = "__belt-draw__/graphics/shortcut2.png",
    icon_size = 128,
    small_icon = "__belt-draw__/graphics/shortcut2.png",
    small_icon_size = 128,
    associated_control_input = "belt-draw-shortcut"
  },
})
