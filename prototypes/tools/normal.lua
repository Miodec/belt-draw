local tooltip = require("tooltip")

local transport_belt = table.deepcopy(data.raw["transport-belt"]["transport-belt"])
transport_belt.name = "belt-draw-dummy-transport-belt"
transport_belt.created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line


return {
  {
    type = "selection-tool",
    name = "belt-draw-preview",
    icon = "__belt-draw__/graphics/pencil.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    mouse_cursor = "arrow",
    order = "c[automated-construction]-d[belt-draw]",
    select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    alt_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    reverse_select = {
      mode = "deconstruct",
      border_color = { a = 0, r = 1 },
      cursor_box_type = "not-allowed",
    },
    alt_reverse_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    super_forced_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    place_result = "belt-draw-dummy-transport-belt",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    },
    custom_tooltip_fields = tooltip
  },
  {
    type = "selection-tool",
    name = "belt-draw",
    icon = "__belt-draw__/graphics/pencil.png",
    icon_size = 64,
    mouse_cursor = "arrow",
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[belt-draw]",
    select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    alt_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    reverse_select = {
      mode = "deconstruct",
      border_color = { a = 0, r = 1 },
      cursor_box_type = "not-allowed",
    },
    alt_reverse_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    super_forced_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    place_result = "belt-draw-dummy-entity",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    }
  },
  transport_belt
}
