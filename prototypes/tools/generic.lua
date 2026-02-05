local tooltip = require("tooltip")

return {
  {
    type = "item",
    name = "belt-draw-generic",
    icon = "__belt-draw__/graphics/pencil.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    mouse_cursor = "arrow",
    order = "c[automated-construction]-d[belt-draw-generic]",
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    },
    custom_tooltip_fields = tooltip
  },
}
