local tooltip = require("tooltip")
return {
  type = "selection-tool",
  icon_size = 64,
  stack_size = 1,
  subgroup = "tool",
  mouse_cursor = "arrow",
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
  collision_mask = {
    layers = {
      ["belt-draw-layer"] = true
    }
  },
  custom_tooltip_fields = tooltip
}
