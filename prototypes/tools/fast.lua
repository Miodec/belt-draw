return {
  {
    type = "selection-tool",
    name = "belt-draw-fast-preview",
    icon = "__belt-draw__/graphics/fast-pencil.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    mouse_cursor = "arrow",
    order = "c[automated-construction]-d[belt-draw-fast]",
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
    place_result = "fast-transport-belt",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    }
  },
  {
    type = "selection-tool",
    name = "belt-draw-fast",
    icon = "__belt-draw__/graphics/fast-pencil.png",
    icon_size = 64,
    mouse_cursor = "arrow",
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[belt-draw-fast]",
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
}
